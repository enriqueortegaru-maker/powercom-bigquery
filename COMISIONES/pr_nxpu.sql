BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'NXPU';


-- CALL `mm-commissions-reporting.COMISIONES.pr_nxpu`(202412);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_calculo_comision` AS
SELECT
      mes_liquidado
     ,sfid_id
     ,concepto
     ,SUM(comision) AS comision

FROM (
     SELECT
           PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
           ,sfid AS sfid_id
          ,'D - Acelerador Puntos' AS concepto
          ,SUM(comision) AS comision
     
     FROM (
          SELECT
                *
               ,CASE
                    WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 0   AND SUM(puntos) OVER (PARTITION BY sfid) < 30  THEN puntos * 0
                    WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 30  AND SUM(puntos) OVER (PARTITION BY sfid) < 60  THEN puntos * 6
                    WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 60  AND SUM(puntos) OVER (PARTITION BY sfid) < 90  THEN puntos * 9
                    WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 90  AND SUM(puntos) OVER (PARTITION BY sfid) < 120 THEN puntos * 12
                    WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 120 AND SUM(puntos) OVER (PARTITION BY sfid) < 150 THEN puntos * 15
                    WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 150                                                THEN puntos * 18
                END AS comision
          FROM `mm-sales-reporting.SPEEDUP.nex_ds_puntos_pdv_*`
          WHERE _table_suffix = CONCAT(mes_string, '01')
          )
     
     GROUP BY 1,2,3
     
     UNION ALL
     
     SELECT
           PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
          ,sfid AS sfid_id
          ,'D - Blindaje "Panzer"' AS concepto
          ,SUM(puntos) * 5 AS comision
     
     FROM `mm-sales-reporting.SPEEDUP.nex_ds_puntos_pdv_*` PUNTO
     
     LEFT JOIN (
               SELECT
                     seller

                    ,CASE WHEN seller like 'MP%' THEN 'PANZER' ELSE MAX(exclusividad) END AS exclusividad
               FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
               WHERE id_mes = mes_int
               GROUP BY 1
               ) PANZER
              ON PUNTO.sfid = PANZER.seller AND PANZER.exclusividad = 'PANZER'
     
     WHERE _table_suffix = CONCAT(mes_string, '01')
           AND (PANZER.exclusividad IS NOT NULL OR PUNTO.sfid LIKE 'MP%')
           AND puntos > 0
     
     GROUP BY 1,2,3
)

WHERE comision <> 0.0

GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_base_comisiones` AS

SELECT
      REPARTOS.concepto
     ,mes_int AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,TRANSACCIONES.* EXCEPT(concepto, id_mes, mes_liquidado)
     
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.nxpu_calculo_comision` REPARTOS
          ON TRANSACCIONES.seller = REPARTOS.sfid_id

WHERE TRANSACCIONES.id_mes = mes_int
      AND TRANSACCIONES.tipo_concepto = 'UPFR'
      AND TRANSACCIONES.concepto LIKE 'A%'
      AND TRANSACCIONES.billing_type_ds = 'POSTPAID'

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_unitario` AS

SELECT
      BASE.seller
     ,BASE.concepto
     ,CALCULO.comision
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.nxpu_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.TEMP.nxpu_calculo_comision` CALCULO
          ON BASE.seller = CALCULO.sfid_id AND BASE.concepto = CALCULO.concepto

WHERE CALCULO.comision <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||BASE.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,BASE.concepto
     ,CONCEPTOS.tipo_concepto

     ,CASE WHEN DEALER.id_comisionista LIKE 'MASTER%' AND LENGTH(DEALER.id_comisionista) = 8 THEN 1 END AS unidades
     
     ,(ROUND((UNITARIO.comision / UNITARIO.eventos),2)) AS comision
     ,DEALER.id_comisionista AS id_comisionista
     ,BASE.distribuidor
     ,BASE.sfid_id
     ,BASE.seller
     ,DEALER.nombre_comercio AS nombre_comercio
     ,DEALER.razon_social AS razon_social
     ,DEALER.cif AS cif
     ,DEALER.zona_fiscal AS zona_fiscal
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
     ,'29' AS cod_canal
     ,BASE.campaign_code
     ,BASE.serial_number
     ,BASE.tax_base
     ,BASE.claim_code
     ,BASE.process_code
     ,BASE.comments
     ,'C_MANUAL' AS facturador

     ,CASE
          WHEN BASE.marca = 'PEPEPHONE' THEN '7000'
          WHEN BASE.marca = 'GUUK'      THEN '8100'
          ELSE 'X001'
      END AS sociedad


FROM `mm-commissions-reporting.TEMP.nxpu_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (BASE.sfid_id = DEALER.sfid_id OR BASE.seller = DEALER.sfid_id) AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.TEMP.nxpu_unitario` UNITARIO
         ON BASE.seller = UNITARIO.seller AND BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_correccion` AS

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
     ,(UNITARIO.comision - CALCULO.comision) AS comision
     ,CALCULO.* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * EXCEPT(comision)
           ,SUM(comision) OVER (PARTITION BY seller, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.nxpu_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY seller, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.nxpu_unitario` UNITARIO
         ON CALCULO.seller = UNITARIO.seller AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.comision - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_cruzado` AS

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
     SELECT * FROM `mm-commissions-reporting.TEMP.nxpu_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.nxpu_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu_no_cruzado` AS
SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,CALCULO.concepto
     ,CONCEPTOS.tipo_concepto

     ,CASE WHEN DEALER.id_comisionista LIKE 'MASTER%' AND LENGTH(DEALER.id_comisionista) = 8 THEN 1 END AS unidades

     ,CALCULO.comision AS comision

     ,DEALER.id_comisionista AS id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id AS sfid_id
     ,COALESCE(CALCULO.sfid_id, DEALER.sfid_id) AS seller
     ,DEALER.nombre_comercio AS nombre_comercio
     ,DEALER.razon_social AS razon_social
     ,DEALER.cif AS cif
     ,DEALER.zona_fiscal AS zona_fiscal
     
     ,'YOIGO' AS marca
     ,'MOBILE' AS service_type
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
     ,'01' AS cod_marca
     ,'20' AS cod_tipo_contrato
     ,'040' AS cod_producto
     ,'29' AS cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL'            AS facturador
     ,'X001'                AS sociedad

FROM `mm-commissions-reporting.TEMP.nxpu_calculo_comision` CALCULO

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CALCULO.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON CALCULO.sfid_id = DEALER.sfid_id AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.TEMP.nxpu_unitario` UNITARIO
         ON CALCULO.sfid_id = UNITARIO.seller AND CALCULO.concepto = UNITARIO.concepto

WHERE UNITARIO.seller IS NULL AND CALCULO.comision <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nxpu` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.nxpu_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.nxpu_no_cruzado`
     )
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('NXPU_', mes_int, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.nxpu), 'TEMP.nxpu', 'ACTUALIZAR');


END