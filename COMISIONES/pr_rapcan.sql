BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'RPD2';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);


/*
CALL COMISIONES.pr_rapcan (202409,['D2D','D2N','DEM']);
*/



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_canarias_base` AS (

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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_canarias_contador`AS (
  SELECT 
  id_comisionista,
  SUM(UNIDADES) AS SERVICIOS

  FROM `mm-commissions-reporting.TEMP.rappel_canarias_base` 

  GROUP BY 1
  ORDER BY  2 DESC
  )
;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_canarias_config` AS (
 
  SELECT *

  FROM `mm-commissions-reporting.TEMP.rappel_canarias_contador` C

  LEFT JOIN   `mm-commissions-reporting.RappelD2D.RAP_CANARIAS` d

   ON d.CODIGO = C.id_comisionista
  
  WHERE cast(d.MES as string) = mes_string
  )

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_canarias` AS (
  SELECT  
  'RPD2'||'_'||mes_string||'_'||S.CANAL||'_'||'CAN'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE S.mes_liquidado 
    END AS mes_liquidado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Rappel Canarias' as concepto,
  S.tipo_concepto,
  S.unidades,
  20 AS comision,
  CASE 
    WHEN S.CANAL = 'D2N' THEN 'D2N01026' 
    WHEN S.CANAL = 'D2D' THEN 'D2D052'
  END AS id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  'UCOIP CANARIAS S.L.' AS nombre_comercio,
  'UCOIP CANARIAS S.L.' AS razon_social,
  'B76525567' AS cif,
  'CAN' AS zona_fiscal,
  S.marca,
  S.service_type,
  S.phone_nm,
  S.tariff_id,
  S.tariff_ds,
  S.service_id,
  S.account_id,
  S.customer_id,
  S.line_type_ds,
  S.bundle_type,
  S.technology_ds,
  S.billing_type_ds,
  S.sale_date,
  S.activation_date,
  S.deactivation_date,
  S.order_id,
  S.order_type_agg,
  S.cod_segmento,
  S.cod_marca,
  S.cod_tipo_contrato,
  S.cod_producto,
  S.cod_canal,
  S.claim_code,
  S.campaign_code,
  'RAPPEL_CAN'||S.CANAL||'_'||mes_string AS process_code,
  S.comments,
  S.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  S.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  S.creado,
  S.modificado,
  '' AS id_factura_drive,
  '' as emails_acceso_trazabilidad


  FROM `mm-commissions-reporting.TEMP.rappel_canarias_base` S

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_canarias_config` C
    ON S.ID_COMISIONISTA = C.id_comisionista 

  WHERE C.id_comisionista IS NOT NULL
   QUALIFY ROW_NUMBER() OVER (PARTITION BY S.phone_nm ORDER BY S.sale_date DESC) = 1
  

UNION ALL

--- CLAWBACKS---
SELECT  
  'RPD2'||'_'||mes_string||'_'||V.CANAL||'_'||'CLAW_CAN'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
   CASE 
    WHEN V.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(V.id_mes AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(V.id_mes AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE V.mes_liquidado 
    END AS mes_liquidado,
  CASE 
    WHEN V.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  T.agrupacion_canal,
  T.canal,
  'E - Clawback Rappel Canarias'as concepto,
  T.tipo_concepto,
  T.unidades,
  (T.comision) * -1 AS comision,
  T.id_comisionista,
  T.distribuidor,
  T.sfid_id,
  T.seller,
  T.nombre_comercio,
  T.razon_social,
  T.cif,
  T.zona_fiscal,
  T.marca,
  T.service_type,
  T.phone_nm,
  T.tariff_id,
  T.tariff_ds,
  T.service_id,
  T.account_id,
  T.customer_id,
  T.line_type_ds,
  T.bundle_type,
  T.technology_ds,
  T.billing_type_ds,
  T.sale_date,
  T.activation_date,
  T.deactivation_date,
  T.order_id,
  T.order_type_agg,
  T.cod_segmento,
  T.cod_marca,
  T.cod_tipo_contrato,
  T.cod_producto,
  T.cod_canal,
  T.claim_code,
  T.campaign_code,
  'RAPPEL_CLAW_CAN'||V.CANAL||'_'||mes_string AS process_code,
  T.comments,
  T.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  T.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  T.creado,
  T.modificado,
  '' AS id_factura_drive,
  '' as emails_acceso_trazabilidad
from `mm-commissions-reporting.COMISIONES.transacciones` T
left join `mm-commissions-reporting.COMISIONES.transacciones` V
on V.service_id = T.service_id
where T.concepto = 'D - Rappel Canarias'
AND V.concepto = 'E - Clawback Servicio Fijo'
AND CAST(V.id_mes AS STRING) = mes_string
AND T.commission_id NOT LIKE '%ABONO%' --DESCARTAMOS PROCESOS POSTERIORES 
AND T.commission_id NOT LIKE '%FACTURA%' --DESCARTAMOS PROCESOS POSTERIORES
AND T.commission_id NOT like '%REC%'
AND V.CANAL IN UNNEST (canales_pr)


  )
;

DELETE FROM `mm-commissions-reporting.TEMP.rappel_canarias`
WHERE comision is null

;
  INSERT INTO `mm-commissions-reporting.RappelD2D.Rappel_Fijo` (

   SELECT *
  
   FROM `mm-commissions-reporting.TEMP.rappel_canarias`
   
   )
;
END