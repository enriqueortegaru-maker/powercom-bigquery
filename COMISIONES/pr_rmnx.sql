BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'RMNX';


/*
CALL `mm-commissions-reporting.COMISIONES.pr_rmnx`(202410);
*/


ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.id_comisionista
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
     GROUP BY 1,2,3,4,5,6,7,8,9
     ) REPARTOS
LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON REPARTOS.id_comisionista = MASTER.id_comisionista
WHERE REPARTOS.id_mes = mes_int AND MASTER.id_comisionista IS NULL AND REPARTOS.importe <> 0
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_repartos` AS

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
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
     GROUP BY 1,2,3,4,5,6,7,8,9
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
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
     GROUP BY 1,2,3,4,5,6,7,8,9
     )
WHERE id_mes = mes_int
)
,

reparto_7000_10 AS
(
SELECT
      concepto
     ,tipo_concepto
     ,'10' AS cod_segmento
     ,'7000' AS sociedad
     ,SPLIT(reparto_7000_10) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
     GROUP BY 1,2,3,4,5,6,7,8,9
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
UNION DISTINCT
SELECT DISTINCT
        concepto
       ,tipo_concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_7000_10, UNNEST(arr) cod_tipo_contrato
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_base_comisiones` AS

SELECT
      MASTER.id_comisionista
     ,REPARTOS.concepto
     ,TRANSACCIONES.* EXCEPT(concepto, id_comisionista, cod_producto)

     ,CASE WHEN TRANSACCIONES.concepto = 'B - Alarmas' THEN '999' ELSE TRANSACCIONES.cod_producto END AS cod_producto
          
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON TRANSACCIONES.sfid_id = DEALER.sfid_id AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON (DEALER.cif_gpv = MASTER.cif OR DEALER.distribuidor = MASTER.id_comisionista)

INNER JOIN `mm-commissions-reporting.TEMP.rmnx_repartos` REPARTOS
          ON TRANSACCIONES.sociedad = REPARTOS.sociedad AND TRANSACCIONES.cod_segmento = REPARTOS.cod_segmento --AND TRANSACCIONES.cod_tipo_contrato = REPARTOS.cod_tipo_contrato

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
           GROUP BY 1,2,3,4,5,6,7,8,9
           ) COMISIONISTA
          ON MASTER.id_comisionista = COMISIONISTA.id_comisionista AND REPARTOS.concepto = COMISIONISTA.concepto AND COMISIONISTA.id_mes = mes_int AND COMISIONISTA.importe <> 0

WHERE TRANSACCIONES.id_mes = mes_int
      AND TRANSACCIONES.mes_liquidado = PARSE_DATE('%Y%m', CAST(mes_int AS STRING))
      AND (
           (
           TRANSACCIONES.concepto IN (
                                     'A - Portabilidad Fijo',
                                     'A - Portabilidad Movil Pospago',
                                     'A - Servicio Fijo',
                                     'A - Servicio Fijo Cambio de Domicilio',
                                     'A - Servicio Movil Pospago',
                                     'A - Portabilidad Movil Pospago',
                                     'A - Servicio Movil Prepago',
                                     'B - Alarmas',
                                     'B - Energia',
                                     'B - Leads Alarmas',
                                     'B - Renuevo',
                                     'B - Television',
                                     'B - Television Premium'
                                     )
           AND UPPER(REPARTOS.concepto) LIKE '%PUNTO%'
           )
          OR
           (
           TRANSACCIONES.concepto IN (
                                     'A - Portabilidad Fijo',
                                     'A - Portabilidad Movil Pospago',
                                     'A - Servicio Fijo',
                                     'A - Servicio Fijo Cambio de Domicilio',
                                     'A - Servicio Movil Pospago',
                                     'A - Portabilidad Movil Pospago',
                                     'A - Servicio Movil Prepago'
                                     )
           AND UPPER(REPARTOS.concepto) NOT LIKE '%PUNTO%'
           )
          )
      AND MASTER.id_comisionista IS NOT NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_unitario` AS

SELECT
      BASE.id_comisionista
     ,BASE.concepto
     ,COMISIONISTA.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.rmnx_base_comisiones` BASE

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
           GROUP BY 1,2,3,4,5,6,7,8,9
           ) COMISIONISTA
          ON BASE.concepto = COMISIONISTA.concepto AND BASE.id_comisionista = COMISIONISTA.id_comisionista AND BASE.id_mes = COMISIONISTA.id_mes

WHERE COMISIONISTA.importe <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||MASTER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,BASE.agrupacion_canal
     ,MASTER.canal
     ,BASE.concepto

     ,CASE
          WHEN BASE.service_type = 'SECURITY' THEN 'ALRM'
          WHEN BASE.service_type = 'TV'       THEN 'OTRS'
          ELSE CONCEPTOS.tipo_concepto
      END AS tipo_concepto

     ,BASE.unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision
     ,MASTER.id_comisionista
     ,MASTER.id_comisionista AS distribuidor
     ,BASE.sfid_id
     ,BASE.seller

     ,MASTER.nombre_comercio

     ,MASTER.razon_social
     ,MASTER.cif
     ,MASTER.zona_fiscal
     ,BASE.marca

     ,CASE WHEN BASE.service_type = 'FIX' THEN 'INTERNET' ELSE BASE.service_type END AS service_type

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
     ,'29' AS cod_canal
     ,BASE.campaign_code
     ,BASE.serial_number
     ,BASE.tax_base
     ,BASE.claim_code
     ,BASE.process_code
     ,BASE.comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.TEMP.rmnx_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

INNER JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
          ON BASE.id_comisionista = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.rmnx_unitario` UNITARIO
         ON BASE.id_comisionista = UNITARIO.id_comisionista and BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_correccion` AS

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
     ,CALCULO.* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, c, comision)

FROM (
     SELECT
           * EXCEPT(comision)
          ,comision AS c
          ,SUM(comision) OVER (PARTITION BY id_comisionista, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.rmnx_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY id_comisionista, concepto ORDER BY c DESC) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.rmnx_unitario` UNITARIO
         ON CALCULO.id_comisionista = UNITARIO.id_comisionista AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_cruzado` AS

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
     SELECT * FROM `mm-commissions-reporting.TEMP.rmnx_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.rmnx_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx_no_cruzado` AS
SELECT
      prefijo||'_'||mes_string||'_'||MASTER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,'No Exclusivo' AS agrupacion_canal
     ,MASTER.canal
     ,RAPPEL.concepto
     ,CONCEPTOS.tipo_concepto AS tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,RAPPEL.importe AS comision
     ,MASTER.id_comisionista
     ,MASTER.id_comisionista AS distribuidor
     ,CAST(NULL AS STRING) AS sfid_id
     ,CAST(NULL AS STRING) AS seller
     ,MASTER.nombre_comercio
     ,MASTER.razon_social
     ,MASTER.cif
     ,MASTER.zona_fiscal
     ,'MASMOVIL' AS marca

     ,CASE WHEN COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') = '61' THEN 'INTERNET' ELSE 'MOBILE' END AS service_type

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
     ,'05' AS cod_marca
     ,COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') AS cod_tipo_contrato
     ,'040' AS cod_producto
     ,'29' AS cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master`
     GROUP BY 1,2,3,4,5,6,7,8,9
     ) RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON RAPPEL.id_comisionista = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.rmnx_unitario` UNITARIO
         ON RAPPEL.id_comisionista = UNITARIO.id_comisionista AND RAPPEL.concepto = UNITARIO.concepto

WHERE RAPPEL.id_mes = mes_int AND UNITARIO.id_comisionista IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rmnx` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.rmnx_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.rmnx_no_cruzado`
     )
WHERE comision IS NOT NULL
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.id_comisionista
FROM (SELECT id_comisionista, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.rmnx` GROUP BY 1) REPARTO
LEFT JOIN (SELECT id_comisionista, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_master` WHERE id_mes = mes_int GROUP BY 1) GS
         ON REPARTO.id_comisionista = GS.id_comisionista
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('RMNX_', mes_int, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.rmnx), 'TEMP.rmnx', 'ACTUALIZAR');

end