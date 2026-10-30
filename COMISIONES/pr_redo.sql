BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'REDO';


-- CALL `mm-commissions-reporting.COMISIONES.pr_redo`(202409);


ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.sfid_id
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_redo`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7
     ) REPARTOS
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON REPARTOS.sfid_id = DEALER.id_comisionista
            AND DEALER.id_mes = mes_int AND DEALER.agrupacion_canal = 'TLV - DO' AND comisiona
WHERE DEALER.id_comisionista IS NULL AND REPARTOS.importe <> 0
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_repartos` AS

WITH reparto_X001_10 AS
(
SELECT
      concepto
     ,tipo_concepto
     ,'10' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_10) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_redo`
     GROUP BY 1,2,3,4,5,6,7
     )
WHERE id_mes = mes_int
)
,

reparto_X001_12 AS
(
SELECT
      concepto
     ,tipo_concepto
     ,'12' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_12) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_redo`
     GROUP BY 1,2,3,4,5,6,7
     )
WHERE id_mes = mes_int
)

SELECT DISTINCT
        concepto
       ,tipo_concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_10, UNNEST(arr) cod_tipo_contrato
UNION DISTINCT
SELECT DISTINCT
        concepto
       ,tipo_concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_12, UNNEST(arr) cod_tipo_contrato

;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_base_comisiones` AS

SELECT
      REPARTOS.concepto
     ,mes_int AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,RAPPEL.sfid_id
     ,TRANSACCIONES.* EXCEPT(concepto,id_mes, sfid_id, mes_liquidado)
     
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.redo_repartos` REPARTOS
          ON TRANSACCIONES.tipo_concepto = REPARTOS.tipo_concepto AND TRANSACCIONES.cod_segmento = REPARTOS.cod_segmento
             AND TRANSACCIONES.sociedad = REPARTOS.sociedad AND TRANSACCIONES.cod_tipo_contrato = REPARTOS.cod_tipo_contrato

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_redo`
           GROUP BY 1,2,3,4,5,6,7
           ) RAPPEL
          ON (TRANSACCIONES.id_comisionista = RAPPEL.sfid_id OR TRANSACCIONES.sfid_id = RAPPEL.sfid_id) AND REPARTOS.concepto = RAPPEL.concepto AND RAPPEL.id_mes = mes_int AND RAPPEL.importe <> 0 AND TRANSACCIONES.marca = RAPPEL.marca

WHERE TRANSACCIONES.id_mes = mes_int
AND TRANSACCIONES.tipo_concepto = 'UPFR'
AND TRANSACCIONES.concepto IN ('A - Servicio Fijo','A - Servicio Movil Pospago')

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_unitario` AS

SELECT
      BASE.id_comisionista
     ,BASE.concepto
     ,RAPPEL.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.redo_base_comisiones` BASE

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_redo`
           GROUP BY 1,2,3,4,5,6,7
           ) RAPPEL
          ON BASE.id_mes = RAPPEL.id_mes
             AND BASE.id_comisionista = RAPPEL.sfid_id
             AND BASE.concepto = RAPPEL.concepto 
             AND BASE.marca = RAPPEL.marca

WHERE RAPPEL.importe <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,BASE.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision

     ,DEALER.id_comisionista
     ,BASE.distribuidor
     ,BASE.sfid_id
     ,BASE.seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,BASE.marca
     ,BASE.service_type
     ,BASE.phone_nm
     ,BASE.tariff_id
     ,BASE.tariff_ds
     ,BASE.service_id
     ,BASE.account_id
     ,BASE.customer_id
     ,BASE.line_type_ds
     ,BASE.bundle_type
     ,BASE.technology_ds
     ,BASE.billing_type_ds
     ,BASE.sale_date
     ,BASE.activation_date
     ,BASE.deactivation_date
     ,BASE.order_id
     ,BASE.order_type_agg
     ,BASE.cod_segmento
     ,BASE.cod_marca
     ,BASE.cod_tipo_contrato
     ,BASE.cod_producto
     ,BASE.cod_canal
     ,BASE.claim_code
     ,BASE.campaign_code
     ,CAST(NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,BASE.process_code
     ,BASE.comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.TEMP.redo_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (BASE.id_comisionista = DEALER.id_comisionista OR BASE.sfid_id = DEALER.sfid_id) AND DEALER.agrupacion_canal = 'TLV - DO' AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.TEMP.redo_unitario` UNITARIO
         ON COALESCE(BASE.id_comisionista, BASE.sfid_id) = UNITARIO.id_comisionista AND BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_correccion` AS

SELECT
      CALCULO.commission_id
     ,CALCULO.estado
     ,CALCULO.mes_liquidado
     ,CALCULO.id_mes
     ,CALCULO.agrupacion_canal
     ,CALCULO.canal
     ,CALCULO.concepto
     ,CALCULO.tipo_concepto
     ,CALCULO.unidades
     ,(UNITARIO.importe - CALCULO.comision) AS comision
     ,CALCULO.* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * EXCEPT(comision)
            ,SUM(comision) OVER (PARTITION BY id_comisionista, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.redo_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY id_comisionista, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.redo_unitario` UNITARIO
         ON COALESCE(CALCULO.id_comisionista, CALCULO.sfid_id) = UNITARIO.id_comisionista AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_cruzado` AS

SELECT
      commission_id
     ,estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
     ,concepto
     ,tipo_concepto
     ,unidades
     ,ROUND(SUM(comision) OVER (PARTITION BY concepto, service_id, marca, service_type),2) AS comision
     ,* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.redo_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.redo_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo_no_cruzado` AS
SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,RAPPEL.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,RAPPEL.importe AS comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id AS sfid_id
     ,COALESCE(RAPPEL.sfid_id, DEALER.sfid_id) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,RAPPEL.marca

     ,CASE WHEN COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') = '61' AND RAPPEL.tipo_concepto <> 'CURE' THEN 'INTERNET'
           ELSE 'MOBILE'
      END AS service_type

     ,CAST(NULL AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,CAST(NULL AS STRING) AS tariff_ds
     ,CAST(NULL AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,CAST(NULL AS DATE) AS sale_date
     ,CAST(NULL AS DATE) AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RAPPEL.marca) AS cod_marca
     ,COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') AS cod_tipo_contrato
     ,'040' AS cod_producto 
     ,'15' AS cod_canal
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS campaign_code
     ,CAST(NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_redo`
     GROUP BY 1,2,3,4,5,6,7
     ) RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON  RAPPEL.sfid_id = COALESCE(DEALER.id_comisionista,DEALER.sfid_id) AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.TEMP.redo_unitario` UNITARIO
         ON RAPPEL.sfid_id = UNITARIO.id_comisionista AND RAPPEL.concepto = UNITARIO.concepto

WHERE RAPPEL.id_mes = mes_int AND UNITARIO.id_comisionista IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.redo` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.redo_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.redo_no_cruzado`
     )
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.id_comisionista, REPARTO.marca
FROM (SELECT id_comisionista,marca, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.redo` GROUP BY 1,2) REPARTO
LEFT JOIN (SELECT sfid_id,marca, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_redo` WHERE id_mes = mes_int GROUP BY 1,2) GS
         ON REPARTO.id_comisionista = GS.sfid_id AND REPARTO.marca = GS.marca
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (
                                                                prefijo,
                                                                mes_int,
                                                                (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.redo WHERE canal IS NOT NULL),
                                                                'TEMP.redo',
                                                                'ACTUALIZAR'
                                                                )
;


END