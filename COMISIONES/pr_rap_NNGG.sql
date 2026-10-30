BEGIN
DECLARE prefijo, mes_string, id_mes_2 STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET id_mes_2 = FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET prefijo = 'RPSV';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

/*
CALL COMISIONES.pr_rap_NNGG (202502,['D2D','D2N','DEM']);
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

  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_string
  AND TRANSACCIONES.CONCEPTO = 'A - Servicio Fijo' 
  AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.cod_segmento = '12'

  UNION ALL 

  SELECT * 
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_string
  AND (TRANSACCIONES.CONCEPTO = 'B - Centralitas Base' AND TRANSACCIONES.tariff_id LIKE 'BASE%') -- SE CONTABILIZAN LOS SERVICIOS FIJOS Y LAS CENTRALITAS
  AND (DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR TRANSACCIONES.deactivation_date IS NULL)
  )

;

--- CONTEO SERVICIOS FIJOS
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_contador`AS (
  SELECT 
  CIF.cif,
  SUM(BASE.UNIDADES) AS SERVICIOS

  FROM `mm-commissions-reporting.TEMP.rappel_fix_base` BASE

  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
    ON BASE.cif = CIF.cif

  GROUP BY 1
  ORDER BY  2 DESC
  )
;

--- KPI NNGG --- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.D2D_kpi_SVA` AS (
  SELECT 
  GS.*
  ,CONTADOR.SERVICIOS AS PACKS_RAPPEL_FIJO
  ,CASE WHEN GS.ATTACH BETWEEN 0.05 AND 0.1099 THEN 5
        WHEN GS.ATTACH BETWEEN 0.11 AND 0.1999 THEN 10
        WHEN GS.ATTACH > 0.20                  THEN 15
        ELSE 0
        END AS EXTRACOMISION

  ,CASE WHEN GS.ATTACH BETWEEN 0.05 AND 0.1099 THEN 5  * CONTADOR.SERVICIOS
        WHEN GS.ATTACH BETWEEN 0.11 AND 0.1999 THEN 10 * CONTADOR.SERVICIOS
        WHEN GS.ATTACH > 0.20                  THEN 15 * CONTADOR.SERVICIOS
        ELSE 0
        END AS TOTAL_EXTRACOMISION
  
  ,CASE WHEN GS.ATTACH BETWEEN 0.05 AND 0.1099 THEN 5  * CONTADOR.SERVICIOS / GS.PONDERACION_TOTAL
        WHEN GS.ATTACH BETWEEN 0.11 AND 0.1999 THEN 10 * CONTADOR.SERVICIOS / GS.PONDERACION_TOTAL
        WHEN GS.ATTACH > 0.20                  THEN 15 * CONTADOR.SERVICIOS / GS.PONDERACION_TOTAL
        ELSE 0
        END AS UNITARIO_POR_COMPUTADA


FROM  `mm-commissions-reporting.RappelD2D.RAP_NNGG` GS

  -- LEFT JOIN `mm-soho-reporting.SOHO_DS.d2d_optico` OPTICO
  --   ON GS.SFID = OPTICO.SFID_UNICO

  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
    ON GS.SFID = CIF.cif

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_contador` CONTADOR
    ON CIF.grupo_cif = CONTADOR.cif
)

;

--- RAPPEL ACTIVACIONES ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_NNGG` AS (
  SELECT  
  prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id,
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
  'D - Rappel NNGG' as concepto,
  S.tipo_concepto,
  S.unidades,
  CASE 
    WHEN S.concepto = 'B - Alarmas' THEN 
        CASE 
            WHEN KPI.ALARMA != 0  THEN (KPI.UNITARIO_POR_COMPUTADA * KPI.PONDERACION_ALARMA) / KPI.ALARMA ELSE 0 END
    WHEN S.concepto = 'B - Energia' THEN 
        CASE 
            WHEN KPI.ENERGIA != 0  THEN (KPI.UNITARIO_POR_COMPUTADA * KPI.PONDERACION_ENERGIA) / KPI.ENERGIA ELSE 0 END
    WHEN S.concepto = 'B - Solucion Digital' THEN 
        CASE 
            WHEN KPI.CIBER_RRSS != 0 THEN (KPI.UNITARIO_POR_COMPUTADA * KPI.PONCERACION_CIBER_RRSS) / KPI.CIBER_RRSS ELSE 0 END
    WHEN S.concepto = 'B - Lead Seguros' THEN 
        CASE 
            WHEN KPI.PONDERACION_SEGUROS_LEADS != 0 THEN (KPI.UNITARIO_POR_COMPUTADA * KPI.PONDERACION_SEGUROS_LEADS) / KPI.PONDERACION_SEGUROS_LEADS ELSE 0 END
  END AS comision,
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
  S.serial_number,
  S.tax_base,
  S.campaign_code,
  'RAPPEL_NNGG'||S.CANAL||'_'||mes_string AS process_code,
  S.comments,
  'C_MANUAL' AS facturador,
  S.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado



  FROM `mm-commissions-reporting.COMISIONES.transacciones` S

  LEFT JOIN `mm-commissions-reporting.TEMP.D2D_kpi_SVA` KPI
    ON S.cif = KPI.SFID AND S.id_mes = KPI.id_mes

  WHERE S.canal IN UNNEST (canales_pr)
      AND S.concepto IN ('B - Energia', 'B - Alarmas','B - Solucion Digital','B - Lead Seguros')
      AND S.id_mes = id_mes_pr
      AND(S.deactivation_date IS NULL OR DATE_TRUNC(S.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
      AND KPI.TOTAL_EXTRACOMISION > 0
      AND S.cod_segmento = '12'

   QUALIFY ROW_NUMBER() OVER (PARTITION BY S.account_id,S.phone_nm, S.customer_id ORDER BY S.sale_date DESC) = 1
)

;

-----INSERTAR D2D ID_MES_PR ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_NNGG_temp` AS(
SELECT *
FROM `mm-commissions-reporting.TEMP.rappel_NNGG`
WHERE CANAL IN ('D2D'))
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D'], 'mm-commissions-reporting.TEMP.rappel_NNGG_temp', 'ACTUALIZAR');


-----INSERTAR D2N y DEM ID_MES_PR +1----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_NNGG_temp` AS(
SELECT *
FROM `mm-commissions-reporting.TEMP.rappel_NNGG`
WHERE CANAL IN ('D2N','DEM'))
;
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, CAST (id_mes_2 AS INT64), ['D2N','DEM'], 'mm-commissions-reporting.TEMP.rappel_NNGG_temp', 'ACTUALIZAR');


END