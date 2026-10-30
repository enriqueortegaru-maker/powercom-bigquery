BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'RPD2';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);


/*
CALL COMISIONES.pr_rap_trimestral (202503,['D2D','D2N','DEM']);
*/



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_trimestral` AS (
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

WHERE TRANSACCIONES.CANAL IN UNNEST(canales_pr)
  AND CAST(TRANSACCIONES.ID_MES AS STRING) IN (
    mes_string, 
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING),
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 2 MONTH)) AS STRING))
  AND TRANSACCIONES.CONCEPTO IN ('A - Servicio Fijo','Z - Servicio Fijo')
  AND DATE_TRUNC(VENTAS.activation_date, MONTH) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH), MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.cod_segmento = '12'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.phone_nm ORDER BY TRANSACCIONES.sale_date DESC) = 1
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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_trim_contador`AS (
  SELECT 
  id_comisionista,
  SUM(UNIDADES) AS SERVICIOS

  FROM `mm-commissions-reporting.TEMP.rappel_trimestral` 

  GROUP BY 1
  ORDER BY  2 DESC
  )
;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_trim_config` AS (
 
  SELECT *

  FROM `mm-commissions-reporting.TEMP.rappel_trim_contador` C

  LEFT JOIN `mm-commissions-reporting.RappelD2D.RAP_MARCO` d

   ON C.SERVICIOS BETWEEN d.RANGO_INI AND d.RANGO_FIN 
   AND d.MES = id_mes_pr 
   AND D.TIPO = 'TRIMESTRAL'
  
  WHERE cast(d.MES as string) = mes_string
  )

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_trimestral_final` AS (
  SELECT  
  'RPD2'||'_'||mes_string||'_'||S.CANAL||'_'||'PREMIO_TRIMESTRAL'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE S.mes_liquidado 
    END AS mes_liquidado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Incentivo Trimestral 2024'as concepto,
  S.tipo_concepto,
  S.unidades,
  C.PRECIO/C.SERVICIOS AS comision,
  s.id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  S.nombre_comercio,
  S.razon_social,
  S.cif,
  S.zona_fiscal,
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
  'RAPPEL_'||S.CANAL||'_'||'PREMIO_TRIMESTRAL'||'_'||mes_string AS process_code,
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


  FROM `mm-commissions-reporting.TEMP.rappel_trimestral` S

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_trim_config` C
    ON S.ID_COMISIONISTA = C.id_comisionista --AND C.CLASIFICACION IS NOT NULL

)
-- ;

--   INSERT INTO `mm-commissions-reporting.RappelD2D.Rappel_Fijo` (

--    SELECT *
--    FROM `mm-commissions-reporting.TEMP.rappel_trimestral_final`
--    WHERE comision is not null
   
--    )
;
END