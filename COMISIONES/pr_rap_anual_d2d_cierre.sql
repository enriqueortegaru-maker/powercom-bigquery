BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'C_RPAN';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);


/*
CALL COMISIONES.pr_rap_anual_d2d_cierre (202512,['D2D','D2N','DEM']);
*/



---- TABLA BASE INCLUYENDO BAJAS PARA LA CONSECUCION ---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappelD2D_anual_base_cierre` AS (
SELECT 
  TRANSACCIONES.*

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA --- EXCLUIMOS PORTABILIDADES INTRAGRUPO
  ON TRANSACCIONES.phone_nm = CAST (INTRA.phone_nm AS STRING) 
      AND TRANSACCIONES.id_mes = INTRA.mes_activacion
      AND TRANSACCIONES.account_id = INTRA.account_id 
      AND TRANSACCIONES.marca = INTRA.brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
  ON TRANSACCIONES.service_id = VENTAS.service_id

WHERE TRANSACCIONES.CANAL IN UNNEST(canales_pr)

  AND CAST(TRANSACCIONES.ID_MES AS STRING) IN (
  mes_string, 
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 2 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 3 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 4 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 5 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 6 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 7 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 8 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 9 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 10 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 11 MONTH)) AS STRING)
  )

  AND TRANSACCIONES.CONCEPTO IN ('A - Servicio Fijo','Z - Servicio Fijo')
  AND DATE_TRUNC(VENTAS.activation_date, MONTH) BETWEEN DATE_TRUNC(DATE_SUB('2026-01-01', INTERVAL 12 MONTH), MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
   AND (DATE_TRUNC(VENTAS.deactivation_date, MONTH) > DATE_TRUNC(VENTAS.activation_date, MONTH)  )
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.cod_segmento = '12'

    UNION ALL 

  SELECT * 
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND CAST(TRANSACCIONES.ID_MES AS STRING) IN (
  mes_string, 
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 2 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 3 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 4 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 5 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 6 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 7 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 8 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 9 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 10 MONTH)) AS STRING),
  CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 11 MONTH)) AS STRING)
  )

  AND (TRANSACCIONES.CONCEPTO IN ('B - Centralitas Base', 'Z - Centralitas Base') AND TRANSACCIONES.tariff_id LIKE 'BASE%') -- SE CONTABILIZAN LOS SERVICIOS FIJOS Y LAS CENTRALITAS
  AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) BETWEEN DATE_TRUNC(DATE_SUB('2026-01-01', INTERVAL 12 MONTH), MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))


  )

;

--- CONTADOR DE SERVICIOS ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappelD2D_anual_contador_cierre` AS (

    SELECT 
    BASE.cif,
    SUM(CASE WHEN EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))) = 1 THEN BASE.UNIDADES ELSE 0 END) AS SERVICIOS_Q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))) = 2 THEN BASE.UNIDADES ELSE 0 END) AS SERVICIOS_Q2,
    SUM(CASE WHEN EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))) = 3 THEN BASE.UNIDADES ELSE 0 END) AS SERVICIOS_Q3,
    SUM(CASE WHEN EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))) = 4 THEN BASE.UNIDADES ELSE 0 END) AS SERVICIOS_Q4,
    SUM(BASE.UNIDADES) AS TOTAL_SERVICIOS
  FROM `mm-commissions-reporting.TEMP.rappelD2D_anual_base_cierre` BASE
  GROUP BY BASE.cif
  ORDER BY TOTAL_SERVICIOS DESC
  )
;/*
---- CALCULO DEL PORCENTAJE DE CIF
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ventas_por_distribuidor_plan_anual` AS (


WITH total_ventas AS (
SELECT 
    CIF_EQUIV.grupo_cif, 
    COUNT(*) AS total

  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base_net` VENTAS
    ON TRANSACCIONES.account_id = VENTAS.account_id 
    AND TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) 
    AND TRANSACCIONES.customer_id = VENTAS.customer_id
    AND TRANSACCIONES.service_id = VENTAS.service_id

  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF_EQUIV
    ON TRANSACCIONES.cif = CIF_EQUIV.cif 

  WHERE TRANSACCIONES.id_mes BETWEEN 202501 and 202512
    AND TRANSACCIONES.CANAL IN UNNEST(canales_pr)
    AND TRANSACCIONES.concepto LIKE 'A - Servicio Fijo'
    -- AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    -- AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), MONTH)
    AND TRANSACCIONES.cod_segmento = '12'
  GROUP BY CIF_EQUIV.grupo_cif
)

SELECT 
  CIF_EQUIV.grupo_cif, 
  total_ventas.total,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'NIF' THEN VENTAS.service_id END) AS NIF,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'CIF' THEN VENTAS.service_id  END) AS CIF,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'DNI' THEN VENTAS.service_id  END) AS DNI,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'TR' THEN VENTAS.service_id  END) AS TR,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'NIF' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_nif,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'CIF' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_cif,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'DNI' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_dni,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'TR' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_tr

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base_net` VENTAS
  ON TRANSACCIONES.account_id = VENTAS.account_id 
  AND TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) 
  AND TRANSACCIONES.customer_id = VENTAS.customer_id
  AND TRANSACCIONES.service_id = VENTAS.service_id

LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF_EQUIV
  ON TRANSACCIONES.cif = CIF_EQUIV.cif  
  
LEFT JOIN total_ventas 
  ON CIF_EQUIV.grupo_cif = total_ventas.grupo_cif

WHERE TRANSACCIONES.id_mes  BETWEEN 202501 and 202512
  AND TRANSACCIONES.CANAL IN UNNEST(canales_pr)
  AND TRANSACCIONES.concepto LIKE 'A - Servicio Fijo'
  -- AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  -- AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), MONTH)
  AND TRANSACCIONES.cod_segmento = '12'

GROUP BY CIF_EQUIV.grupo_cif, total_ventas.total
ORDER BY CIF_EQUIV.grupo_cif, porcentaje_cif DESC
)
;

*/

--- CONFIGURACION UNITARIO POR DISTRIBUIDOR SEGÚN OBJETIVOS ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappelD2D_anual_config_cierre` AS (
 
  SELECT
  RAPPEL.RELACION
  ,RAPPEL.UNITARIO
  ,RAPPEL.Q1
  ,RAPPEL.Q2
  ,RAPPEL.Q3
  ,RAPPEL.Q4
  ,SUM(CONTADOR.SERVICIOS_Q1) AS SERVICIOS_Q1
  ,SUM(CONTADOR.SERVICIOS_Q2) AS SERVICIOS_Q2
  ,SUM(CONTADOR.SERVICIOS_Q3) AS SERVICIOS_Q3
  ,SUM(CONTADOR.SERVICIOS_Q4) AS SERVICIOS_Q4
  ,RAPPEL.PORCENTAJE_CIF
  ,RAPPEL.ACTIVOS_PAGANDO

  FROM `mm-commissions-reporting.TEMP.rappelD2D_anual_contador_cierre` CONTADOR

  LEFT JOIN `mm-commissions-reporting.RappelD2D.RAPPEL_ANUAL` RAPPEL
   ON CONTADOR.cif = RAPPEL.CIF



  WHERE RAPPEL.RELACION IS NOT NULL
   
  GROUP BY ALL
  )

;


---- SE RECREA TABLA BASE QUITANDO LAS BAJAS PARA EL PAGO ---- 

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappelD2D_anual_base_cierre` AS (
SELECT 
  TRANSACCIONES.*

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA --- EXCLUIMOS PORTABILIDADES INTRAGRUPO
  ON TRANSACCIONES.phone_nm = CAST (INTRA.phone_nm AS STRING) 
      AND TRANSACCIONES.id_mes = INTRA.mes_activacion
      AND TRANSACCIONES.account_id = INTRA.account_id 
      AND TRANSACCIONES.marca = INTRA.brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
  ON TRANSACCIONES.service_id = VENTAS.service_id

WHERE TRANSACCIONES.CANAL IN UNNEST(canales_pr)
  AND CAST(TRANSACCIONES.ID_MES AS STRING) IN (
    mes_string, 
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 2 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 3 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 4 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 5 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 6 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 7 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 8 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 9 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 10 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 11 MONTH)) AS STRING)
    )
  AND TRANSACCIONES.CONCEPTO IN ('A - Servicio Fijo','Z - Servicio Fijo')
  AND DATE_TRUNC(VENTAS.activation_date, MONTH) BETWEEN DATE_TRUNC(DATE_SUB('2026-01-01', INTERVAL 12 MONTH), MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > DATE_TRUNC('2026-01-01', MONTH) ---- ELIMINAMOS BAJAS
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.cod_segmento = '12'

    UNION ALL 

  SELECT * 
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND CAST(TRANSACCIONES.ID_MES AS STRING) IN (
    mes_string, 
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 2 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 2 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 3 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 4 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 5 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 6 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 7 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 8 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 9 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 10 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 11 MONTH)) AS STRING))
  AND (TRANSACCIONES.CONCEPTO IN ('B - Centralitas Base', 'Z - Centralitas Base')  AND TRANSACCIONES.tariff_id LIKE 'BASE%') -- SE CONTABILIZAN LOS SERVICIOS FIJOS Y LAS CENTRALITAS
  AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) BETWEEN DATE_TRUNC(DATE_SUB('2026-01-01', INTERVAL 12 MONTH), MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))


  )
;


---- TABLA PARA INSERTAR EN TRANSACCIONES ---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappelD2D_anual_trimestral_cierre` AS (
--   SELECT  
--   -- prefijo ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id,
--   'calculado' AS estado,
--     BASE.mes_liquidado AS mes_liquidado,
--     id_mes_pr AS id_mes,
--   BASE.agrupacion_canal,
--   BASE.canal,
--   'D - Rappel Objetivo Anual' AS concepto, 
--   CASE WHEN BASE.tipo_concepto = 'CENT' THEN 'OTRS' ELSE BASE.tipo_concepto END AS tipo_concepto,
--   BASE.unidades,
--   CASE 
--    WHEN base.cif = 'B55421127' and activation_date between '2025-01-01' and '2025-06-30' THEN CONFIG.UNITARIO  --arinero hay que pagarle entero Q1 y Q2
--    WHEN base.cif = 'B10786564' and activation_date between '2025-01-01' and '2025-09-30' THEN CONFIG.UNITARIO  -- zero grados hay que pagarle entero Q1,Q2,Q3
--    ELSE  CONFIG.UNITARIO /2
--   END AS comision,
--   BASE.id_comisionista,
--   BASE.distribuidor,
--   BASE.sfid_id,
--   BASE.seller,
--   BASE.nombre_comercio,
--   BASE.razon_social,
--   BASE.cif,
--   BASE.zona_fiscal,
--   BASE.marca,
--   BASE.service_type,
--   BASE.phone_nm,
--   BASE.tariff_id,
--   BASE.tariff_ds,
--   BASE.service_id,
--   BASE.account_id,
--   BASE.customer_id,
--   BASE.line_type_ds,
--   BASE.bundle_type,
--   BASE.technology_ds,
--   BASE.billing_type_ds,
--   BASE.sale_date,
--   BASE.activation_date,
--   BASE.deactivation_date,
--   BASE.order_id,
--   BASE.order_type_agg,
--   BASE.cod_segmento,
--   BASE.cod_marca,
--   BASE.cod_tipo_contrato,
--   BASE.cod_producto,
--   BASE.cod_canal,
--   BASE.claim_code,
--   BASE.serial_number,
--   BASE.tax_base,
--   BASE.campaign_code,
--   'RAPPEL_'||BASE.CANAL||'_ANUAL_'||mes_string AS process_code,
--   BASE.comments,
--  'C_MANUAL' AS facturador,
--   BASE.sociedad,
--   CURRENT_TIMESTAMP AS creado,
--   CURRENT_TIMESTAMP AS modificado



--   FROM `mm-commissions-reporting.TEMP.rappelD2D_anual_base_cierre` BASE
  

--   LEFT JOIN `mm-commissions-reporting.RappelD2D.RAPPEL_ANUAL`  RELACION
--     ON BASE.cif = RELACION.cif

--   LEFT JOIN `mm-commissions-reporting.TEMP.rappelD2D_anual_config_cierre` CONFIG
--     ON RELACION.RELACION = CONFIG.RELACION

--   WHERE (CONFIG.SERVICIOS_Q1 + CONFIG.SERVICIOS_Q2 + CONFIG.SERVICIOS_Q3 + CONFIG.SERVICIOS_Q4) >= (CONFIG.Q1 +  CONFIG.Q2 + CONFIG.Q3 + CONFIG.Q4)

--    QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id, BASE.concepto ORDER BY BASE.sale_date DESC) = 1

-- UNION ALL
-- ---Añado la parte de si cumple el primer criterio
-- SELECT  
--   -- prefijo ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id,
--   'calculado' AS estado,
--     BASE.mes_liquidado AS mes_liquidado,
--     id_mes_pr AS id_mes,
--   BASE.agrupacion_canal,
--   BASE.canal,
--   'D - Rappel Objetivo Anual CIF' AS concepto, 
--   CASE WHEN BASE.tipo_concepto = 'CENT' THEN 'OTRS' ELSE BASE.tipo_concepto END AS tipo_concepto,
--   BASE.unidades,
--   10 AS comision,
--   BASE.id_comisionista,
--   BASE.distribuidor,
--   BASE.sfid_id,
--   BASE.seller,
--   BASE.nombre_comercio,
--   BASE.razon_social,
--   BASE.cif,
--   BASE.zona_fiscal,
--   BASE.marca,
--   BASE.service_type,
--   BASE.phone_nm,
--   BASE.tariff_id,
--   BASE.tariff_ds,
--   BASE.service_id,
--   BASE.account_id,
--   BASE.customer_id,
--   BASE.line_type_ds,
--   BASE.bundle_type,
--   BASE.technology_ds,
--   BASE.billing_type_ds,
--   BASE.sale_date,
--   BASE.activation_date,
--   BASE.deactivation_date,
--   BASE.order_id,
--   BASE.order_type_agg,
--   BASE.cod_segmento,
--   BASE.cod_marca,
--   BASE.cod_tipo_contrato,
--   BASE.cod_producto,
--   BASE.cod_canal,
--   BASE.claim_code,
--   BASE.serial_number,
--   BASE.tax_base,
--   BASE.campaign_code,
--   'RAPPEL_'||BASE.CANAL||'_ANUAL_'||mes_string AS process_code,
--   BASE.comments,
--  'C_MANUAL' AS facturador,
--   BASE.sociedad,
--   CURRENT_TIMESTAMP AS creado,
--   CURRENT_TIMESTAMP AS modificado



--   FROM `mm-commissions-reporting.TEMP.rappelD2D_anual_base_cierre` BASE
  

--   LEFT JOIN `mm-commissions-reporting.RappelD2D.RAPPEL_ANUAL`  RELACION
--     ON BASE.cif = RELACION.cif

--   LEFT JOIN `mm-commissions-reporting.TEMP.rappelD2D_anual_config_cierre` CONFIG
--     ON RELACION.RELACION = CONFIG.RELACION

--   WHERE (CONFIG.SERVICIOS_Q1 + CONFIG.SERVICIOS_Q2 + CONFIG.SERVICIOS_Q3 + CONFIG.SERVICIOS_Q4) >= (CONFIG.Q1 +  CONFIG.Q2 + CONFIG.Q3 + CONFIG.Q4)
-- AND RELACION.PORCENTAJE_CIF >= RELACION.PORCENTAJE_CIF_OBJETIVO

--    QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id, BASE.concepto ORDER BY BASE.sale_date DESC) = 1
-- UNION ALL

-- ---- AÑADO 2º KPI// % DE ACTIVOS Y PAGANDO

SELECT  
  -- prefijo ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    BASE.mes_liquidado AS mes_liquidado,
    202601 AS id_mes,
  BASE.agrupacion_canal,
  BASE.canal,
  'D - Rappel Objetivo Anual Activos' AS concepto, 
  CASE WHEN BASE.tipo_concepto = 'CENT' THEN 'OTRS' ELSE BASE.tipo_concepto END AS tipo_concepto,
  BASE.unidades,
  10 AS comision,
  BASE.id_comisionista,
  BASE.distribuidor,
  BASE.sfid_id,
  BASE.seller,
  BASE.nombre_comercio,
  BASE.razon_social,
  BASE.cif,
  BASE.zona_fiscal,
  BASE.marca,
  BASE.service_type,
  BASE.phone_nm,
  BASE.tariff_id,
  BASE.tariff_ds,
  BASE.service_id,
  BASE.account_id,
  BASE.customer_id,
  BASE.line_type_ds,
  BASE.bundle_type,
  BASE.technology_ds,
  BASE.billing_type_ds,
  BASE.sale_date,
  BASE.activation_date,
  BASE.deactivation_date,
  BASE.order_id,
  BASE.order_type_agg,
  BASE.cod_segmento,
  BASE.cod_marca,
  BASE.cod_tipo_contrato,
  BASE.cod_producto,
  BASE.cod_canal,
  BASE.claim_code,
  BASE.serial_number,
  BASE.tax_base,
  BASE.campaign_code,
  'RAPPEL_'||BASE.CANAL||'_ANUAL_'||mes_string AS process_code,
  BASE.comments,
 'C_MANUAL' AS facturador,
  BASE.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado

  FROM `mm-commissions-reporting.TEMP.rappelD2D_anual_base_cierre` BASE
  

  LEFT JOIN `mm-commissions-reporting.RappelD2D.RAPPEL_ANUAL`  RELACION
    ON BASE.cif = RELACION.cif

  LEFT JOIN `mm-commissions-reporting.TEMP.rappelD2D_anual_config_cierre` CONFIG
    ON RELACION.RELACION = CONFIG.RELACION

  WHERE RELACION.CUMPLE_OBJ_VOL = 'SI'
AND RELACION.ACTIVOS_PAGANDO >= RELACION.ACTIVOS_PAGANDO_OBJETIVO

   QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id, BASE.concepto ORDER BY BASE.sale_date DESC) = 1

)

;
---- INSERT COMISIONES ------

---INSERTAR D2D ID_MES_PR ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappelD2D_anual_temp_cierre` AS(
SELECT 
prefijo ||'_'||'202601'||'_'||CANAL||'_'||row_number () over () AS commission_id,
*
FROM `mm-commissions-reporting.TEMP.rappelD2D_anual_trimestral_cierre`
where comision IS NOT NULL )
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D','D2N','DEM'], 'mm-commissions-reporting.TEMP.rappelD2D_anual_temp_cierre', 'ACTUALIZAR');



END