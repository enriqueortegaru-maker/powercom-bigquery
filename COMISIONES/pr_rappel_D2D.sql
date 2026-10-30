BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'RP';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

/*
CALL COMISIONES.pr_rappel_D2D (202410,['D2D','D2N','DEM']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base` AS (


  SELECT 
  TRANSACCIONES.*

  FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

    LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA --- EXCLUIMOS PORTABILIDADES INTRAGRUPO
    ON TRANSACCIONES.phone_nm = CAST (INTRA.phone_nm AS STRING) 
        AND TRANSACCIONES.id_mes = INTRA.mes_activacion
        AND TRANSACCIONES.account_id = INTRA.account_id 
        AND TRANSACCIONES.marca = INTRA.brand_ds

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS
    ON TRANSACCIONES.service_id = VENTAS.service_id

  where TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES as string) = mes_string
  AND TRANSACCIONES.CONCEPTO = 'A - Servicio Fijo' -- SE CONTABILIZAN LOS SERVICIOS FIJOS
  AND TRANSACCIONES.SERVICE_TYPE IN ('INTERNET') 
  AND TRANSACCIONES.tariff_ds NOT LIKE '%ADSL%' -- NO COMISIONA ADSL
  AND TRANSACCIONES.BUNDLE_TYPE IN ('2P','FMC')
  AND TRANSACCIONES.commission_id NOT LIKE '%ABONO%' --DESCARTAMOS PROCESOS POSTERIORES 
  AND TRANSACCIONES.commission_id NOT LIKE '%FACTURA%' --DESCARTAMOS PROCESOS POSTERIORES
  -- AND DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup is null)

  )

--- EXCLUIMOS HASTA QUE HAYA UN CAMBIO DE MR ----
/*; 
CREATE OR REPLACE TABLE mm-commissions-reporting.TEMP.rappel_fix_base AS (
   SELECT 
  BASE.*

  FROM
  mm-commissions-reporting.TEMP.rappel_fix_base BASE

  INNER JOIN (SELECT A.customer_id, B.order_type_agg  ----- EXCLUIMOS CLIENTES QUE SEAN TODO ALTAS NUEVAS
              FROM mm-commissions-reporting.TEMP.rappel_fix_base A

              LEFT JOIN mm-commissions-reporting.COMISIONES.v_ventas_comisiones B
                ON A.customer_id = B.customer_id

              WHERE B.order_type_agg NOT LIKE 'ALTA NUEVA' OR (B.order_type_agg NOT LIKE 'ALTA NUEVA' AND B.billing_type_ds NOT LIKE 'PREPAID')
              GROUP BY 1,2) ALTAS
      ON BASE.customer_id = ALTAS.customer_id
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.phone_nm ORDER BY BASE.sale_date DESC) = 1 
      )
*/   
;

---- CONTEO DE SERVICIOS -----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_contador`AS (
  SELECT 
  BASE.id_comisionista,
  SUM(BASE.UNIDADES) AS SERVICIOS

  FROM `mm-commissions-reporting.TEMP.rappel_fix_base` BASE

  GROUP BY 1
  ORDER BY  2 DESC
  )
;

----- CÁLCULO TRAMO OBTENIDO ---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_config` AS (
 
  SELECT *

  FROM `mm-commissions-reporting.TEMP.rappel_fix_contador` CONTADOR

  LEFT JOIN `mm-commissions-reporting.RappelD2D.RAP_MARCO` MARCO

   ON CONTADOR.SERVICIOS BETWEEN MARCO.RANGO_INI AND MARCO.RANGO_FIN 
   AND MARCO.MES = id_mes_pr 
   AND MARCO.TIPO = 'MENSUAL'
  
  WHERE cast(MARCO.MES as string) = mes_string
  )

;
--- CÁLCULO RAPPEL FIX ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix` AS (
  SELECT  
  -- prefijo||'_'||mes_string||'_'||BASE.CANAL||'_'||'SIN_TRAMO'||'_'||row_number () over () AS commission_id,
  prefijo||'FIX_' ||BASE.CANAL||'_'||mes_string||'_'||row_number () over () AS commission_id,
  'calculado' AS estado
  ,CASE 
    WHEN BASE.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE BASE.mes_liquidado 
    END AS mes_liquidado
  ,CASE 
    WHEN BASE.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes
  ,BASE.agrupacion_canal
  ,BASE.canal
  ,'D - Rappel Fijo_'||CONFIG.CLASIFICACION as concepto
  ,BASE.tipo_concepto
  ,BASE.unidades
  ,CONFIG.PRECIO  AS comision
  ,BASE.id_comisionista
  ,BASE.distribuidor
  ,BASE.sfid_id
  ,BASE.seller
  ,BASE.nombre_comercio
  ,BASE.razon_social
  ,BASE.cif
  ,BASE.zona_fiscal
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
  ,CAST(NULL AS STRING)  AS campaign_code
  ,CAST(NULL AS STRING)  AS serial_number
  ,CAST(NULL AS FLOAT64) AS tax_base
  ,'RAPPEL_'||BASE.CANAL||'_'||'SIN_TRAMO'||'_'||mes_string AS process_code
  ,BASE.comments
  ,'C_MANUAL' AS facturador
  ,CAST(NULL AS STRING) AS proceso_sap
  ,CAST(NULL AS STRING) AS id_registro
  ,CAST(NULL AS STRING) AS invoice_id
  ,BASE.sociedad
  ,CAST(NULL AS STRING) AS bp
  ,CAST(NULL AS STRING) AS cuenta_contable
  ,CAST(NULL AS STRING) AS centro_coste
  ,CAST(NULL AS STRING) AS documento_sap
  ,CAST(NULL AS STRING) AS documento_sap_posicion
  ,CAST(NULL AS STRING) AS fecha_contabilizacion
  ,CAST(NULL AS TIMESTAMP) AS creado
  ,CAST(NULL AS TIMESTAMP) AS modificado
  ,CAST(NULL AS STRING) AS id_factura_drive
  ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad


  FROM `mm-commissions-reporting.TEMP.rappel_fix_base` BASE

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_config` CONFIG
    ON BASE.ID_COMISIONISTA = CONFIG.id_comisionista --AND CONFIG.CLASIFICACION IS NOT NULL
   QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.phone_nm ORDER BY BASE.sale_date DESC) = 1

UNION ALL

--- CÁLCULO CLAWBACKS RAPPEL FIX---
SELECT  
  -- prefijo||'_'||mes_string||'_'||T.CANAL||'_'||'CLAW'||'_'||row_number () over () AS commission_id,
  prefijo||'FIX_' ||T.CANAL||'_CLAW'||mes_string||'_'||row_number () over () AS commission_id,
  'calculado' AS estado
  , CASE 
    WHEN T.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE T.mes_liquidado 
    END AS mes_liquidado
  ,CASE 
    WHEN T.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes
  ,T.agrupacion_canal
  ,T.canal
  ,REPLACE(T.concepto, 'D - Rappel Fijo_', 'E - Clawback Rappel Fijo_') as concepto
  ,T.tipo_concepto
  ,T.unidades
  ,CAST((T.comision) * -1 AS FLOAT64) AS comision
  ,T.id_comisionista
  ,T.distribuidor
  ,T.sfid_id
  ,T.seller
  ,T.nombre_comercio
  ,T.razon_social
  ,T.cif
  ,T.zona_fiscal
  ,T.marca
  ,T.service_type
  ,T.phone_nm
  ,T.tariff_id
  ,T.tariff_ds
  ,T.service_id
  ,T.account_id
  ,T.customer_id
  ,T.line_type_ds
  ,T.bundle_type
  ,T.technology_ds
  ,T.billing_type_ds
  ,T.sale_date
  ,T.activation_date
  ,T.deactivation_date
  ,T.order_id
  ,T.order_type_agg
  ,T.cod_segmento
  ,T.cod_marca
  ,T.cod_tipo_contrato
  ,T.cod_producto
  ,T.cod_canal
  ,T.claim_code
  ,CAST(NULL AS STRING)  AS campaign_code
  ,CAST(NULL AS STRING)  AS serial_number
  ,CAST(NULL AS FLOAT64) AS tax_base
  ,'RAPPEL_CLAWBACK'||T.CANAL||'_'||mes_string AS process_code
  ,T.comments
  ,'C_MANUAL' AS facturador
  ,CAST(NULL AS STRING) AS proceso_sap
  ,CAST(NULL AS STRING) AS id_registro
  ,CAST(NULL AS STRING) AS invoice_id
  ,T.sociedad
  ,CAST(NULL AS STRING) AS bp
  ,CAST(NULL AS STRING) AS cuenta_contable
  ,CAST(NULL AS STRING) AS centro_coste
  ,CAST(NULL AS STRING) AS documento_sap
  ,CAST(NULL AS STRING) AS documento_sap_posicion
  ,CAST(NULL AS STRING) AS fecha_contabilizacion
  ,CAST(NULL AS TIMESTAMP) AS creado
  ,CAST(NULL AS TIMESTAMP) AS modificado
  ,CAST(NULL AS STRING) AS id_factura_drive
  ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad

from `mm-commissions-reporting.COMISIONES.transacciones` T
left join `mm-commissions-reporting.COMISIONES.transacciones` V
on V.service_id = T.service_id
where T.concepto like 'D - Rappel Fijo_%'
AND V.concepto = 'E - Clawback Servicio Fijo'
AND T.commission_id NOT LIKE '%ABONO%' --DESCARTAMOS PROCESOS POSTERIORES 
AND T.commission_id NOT LIKE '%FACTURA%' --DESCARTAMOS PROCESOS POSTERIORES'
AND T.commission_id NOT LIKE '%REC%' --DESCARTAMOS PROCESOS POSTERIORES'
AND V.CANAL IN UNNEST (canales_pr)
AND cast (V.id_mes AS STRING) = mes_string
--  QUALIFY ROW_NUMBER() OVER (PARTITION BY T.phone_nm ORDER BY T.sale_date DESC) = 1


  )
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_D2D` AS 
(
SELECT
      *
     --,prefijo|| CANAL || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM `mm-commissions-reporting.TEMP.rappel_fix`
where comision is not null
)
;

END