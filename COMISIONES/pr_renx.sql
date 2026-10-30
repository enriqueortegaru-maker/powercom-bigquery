BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'RENX';


/*
CALL `mm-commissions-reporting.COMISIONES.pr_renx`(202608);
*/


ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.seller
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7,8,9,10,11
     ) REPARTOS
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON REPARTOS.seller = DEALER.sfid_id
            AND DEALER.id_mes = mes_int AND DEALER.agrupacion_canal = 'No Exclusivo' AND comisiona
WHERE DEALER.sfid_id IS NULL AND REPARTOS.importe <> 0
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_repartos` AS

WITH reparto_X001_10 AS
(
SELECT
      concepto
     ,'10' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_10) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7,8,9,10,11
     )
)
,

reparto_X001_12 AS
(
SELECT
      concepto
     ,'12' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_12) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7,8,9,10,11
     )
)
,

reparto_7000_10 AS
(
SELECT
      concepto
     ,'10' AS cod_segmento
     ,'7000' AS sociedad
     ,SPLIT(reparto_7000_10) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7,8,9,10,11
     )
)

SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_10, UNNEST(arr) cod_tipo_contrato
UNION DISTINCT
SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_12, UNNEST(arr) cod_tipo_contrato
UNION DISTINCT
SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_7000_10, UNNEST(arr) cod_tipo_contrato
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_base_comisiones` AS

SELECT
      REPARTOS.concepto
     ,mes_int AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,TRANSACCIONES.* EXCEPT(concepto, id_mes, mes_liquidado)
     
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.renx_repartos` REPARTOS
          ON TRANSACCIONES.cod_segmento = REPARTOS.cod_segmento AND TRANSACCIONES.sociedad = REPARTOS.sociedad --AND TRANSACCIONES.cod_tipo_contrato = REPARTOS.cod_tipo_contrato

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
           WHERE id_mes = mes_int
           GROUP BY 1,2,3,4,5,6,7,8,9,10,11
           ) RAPPEL
          ON (TRANSACCIONES.sfid_id = RAPPEL.seller OR TRANSACCIONES.seller = RAPPEL.seller) AND REPARTOS.concepto = RAPPEL.concepto AND RAPPEL.importe <> 0

WHERE TRANSACCIONES.id_mes = mes_int
      AND TRANSACCIONES.concepto IN (
                                    'A - Servicio Fijo',
                                    'A - Servicio Movil Pospago',
                                    'A - Portabilidad Movil Pospago'
                                    )
      AND TRANSACCIONES.claim_code IS NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_unitario` AS

SELECT
      BASE.sfid_id
     ,BASE.concepto
     ,RAPPEL.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.renx_base_comisiones` BASE

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
           WHERE id_mes = mes_int
           GROUP BY 1,2,3,4,5,6,7,8,9,10,11
           ) RAPPEL
          ON BASE.concepto = RAPPEL.concepto AND BASE.sfid_id = RAPPEL.seller

WHERE RAPPEL.importe <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,BASE.concepto
     ,CONCEPTOS.tipo_concepto
     ,BASE.unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) ELSE DEALER.id_comisionista END AS id_comisionista

     ,BASE.distribuidor
     ,BASE.sfid_id
     ,BASE.seller

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) ELSE DEALER.nombre_comercio END AS nombre_comercio

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.razon_social, DEALER.razon_social) ELSE DEALER.razon_social END AS razon_social

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.cif, DEALER.cif) ELSE DEALER.cif END AS cif

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) ELSE DEALER.zona_fiscal END AS zona_fiscal

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

FROM `mm-commissions-reporting.TEMP.renx_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON BASE.sfid_id = DEALER.sfid_id AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.renx_unitario` UNITARIO
         ON BASE.sfid_id = UNITARIO.sfid_id AND BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_correccion` AS

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
            ,SUM(comision) OVER (PARTITION BY sfid_id, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.renx_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.renx_unitario` UNITARIO
         ON CALCULO.sfid_id = UNITARIO.sfid_id AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_cruzado` AS

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
     SELECT * FROM `mm-commissions-reporting.TEMP.renx_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.renx_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx_no_cruzado` AS
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

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) ELSE DEALER.id_comisionista END AS id_comisionista

     ,DEALER.distribuidor
     ,DEALER.sfid_id
     ,DEALER.sfid_id AS seller

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) ELSE DEALER.nombre_comercio END AS nombre_comercio

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.razon_social, DEALER.razon_social) ELSE DEALER.razon_social END AS razon_social

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.cif, DEALER.cif) ELSE DEALER.cif END AS cif

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) ELSE DEALER.zona_fiscal END AS zona_fiscal

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
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7,8,9,10,11
     ) RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON RAPPEL.seller = DEALER.sfid_id AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.renx_unitario` UNITARIO
         ON RAPPEL.seller = UNITARIO.sfid_id AND RAPPEL.concepto = UNITARIO.concepto

WHERE UNITARIO.sfid_id IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renx` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.renx_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.renx_no_cruzado`
     )
WHERE comision IS NOT NULL
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.sfid_id
FROM (SELECT sfid_id, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.renx` GROUP BY 1) REPARTO
LEFT JOIN (SELECT seller, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda` WHERE id_mes = mes_int GROUP BY 1) GS
         ON REPARTO.sfid_id = GS.seller
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('RENX_', mes_int, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.renx), 'TEMP.renx', 'ACTUALIZAR');


END