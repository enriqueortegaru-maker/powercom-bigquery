BEGIN
DECLARE prefijo, mes_string STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'OUOCRP';

SET canales_pr = COALESCE(canales_pr, ['OUOC']);


/*
CALL COMISIONES.pr_rappel_OUOC (202609,['OUOC']);
*/


CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.RESULTADO_RAPPEL_OUOC`  AS (
WITH SUMA AS (
  SELECT
    PLATAFORMA,
    SUM(
      SAFE_CAST(REPLACE(PONDERACION_RAPPEL, ',', '.') AS FLOAT64)
    ) AS TOTAL_PONDERACION_RAPPEL
  FROM `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones`
  WHERE MES =  PARSE_DATE('%Y%m%d', CONCAT(CAST(id_mes_pr AS STRING), '01'))
    AND PONDERACION_RAPPEL IS NOT NULL
  GROUP BY PLATAFORMA
),

CALCULO AS (
  SELECT
    R.MES,
    R.DIAS,
    R.DISTRIBUIDOR,
    R.PUNTOS_DIA,
    R.OBJETIVO_MES,
    R.IMPORTE,
    S.TOTAL_PONDERACION_RAPPEL,
    SAFE_DIVIDE(S.TOTAL_PONDERACION_RAPPEL, R.DIAS) AS PUNTOS_DIARIOS_OBTENIDOS
  FROM `mm-commissions-reporting.GS.RAPPEL_OUOC` AS R
  LEFT JOIN SUMA AS S
    ON R.DISTRIBUIDOR = S.PLATAFORMA
  WHERE R.MES = id_mes_pr
),

TRAMO AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY MES, DISTRIBUIDOR
      ORDER BY PUNTOS_DIA DESC
    ) AS RN
  FROM CALCULO
  WHERE PUNTOS_DIA <= PUNTOS_DIARIOS_OBTENIDOS
)

SELECT
  MES,
  DIAS,
  DISTRIBUIDOR,
  TOTAL_PONDERACION_RAPPEL,
  ROUND(PUNTOS_DIARIOS_OBTENIDOS, 2) AS PUNTOS_DIARIOS_OBTENIDOS,
  PUNTOS_DIA AS PUNTOS_DIA_TRAMO,
  OBJETIVO_MES,
  IMPORTE AS IMPORTE_RAPPEL
FROM TRAMO
WHERE RN = 1

UNION ALL

SELECT
  R.MES,
  R.DIAS,
  R.DISTRIBUIDOR,
  S.TOTAL_PONDERACION_RAPPEL,
  ROUND(SAFE_DIVIDE(S.TOTAL_PONDERACION_RAPPEL, R.DIAS), 2),
  NULL,
  NULL,
  0 AS IMPORTE_RAPPEL
FROM `mm-commissions-reporting.GS.RAPPEL_OUOC` AS R
LEFT JOIN SUMA AS S
  ON R.DISTRIBUIDOR = S.PLATAFORMA
WHERE R.MES = id_mes_pr
  AND NOT EXISTS (
    SELECT 1
    FROM CALCULO AS C
    WHERE C.DISTRIBUIDOR = R.DISTRIBUIDOR
      AND C.PUNTOS_DIA <= SAFE_DIVIDE(S.TOTAL_PONDERACION_RAPPEL, R.DIAS)
  )
QUALIFY ROW_NUMBER() OVER (PARTITION BY R.MES, R.DISTRIBUIDOR ORDER BY R.PUNTOS_DIA) = 1
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALCULO_RAPPEL_OUOC` AS (
SELECT  
  'OUOCRP' ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id
  ,'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,BASE.agrupacion_canal
  ,BASE.canal
  ,'D - Rappel' as concepto
  ,BASE.tipo_concepto
  ,BASE.unidades
  ,CONFIG.IMPORTE_RAPPEL * SAFE_CAST( REPLACE(PONDERACIONES.PONDERACION_RAPPEL, ',', '.') AS FLOAT64) AS comision
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
  ,BASE.serial_number
  ,BASE.tax_base
  ,BASE.campaign_code
  ,'Tramo rappel: '|| CONFIG.IMPORTE_RAPPEL AS process_code
  ,BASE.comments
  ,'C_MANUAL' AS facturador
  ,BASE.sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado


  FROM `mm-commissions-reporting.COMISIONES.transacciones` BASE

  LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
  ON PONDERACION_RAPPEL IS NOT NULL
    AND CAST(PONDERACIONES.phone_nm AS STRING ) = BASE.phone_nm

  LEFT JOIN `mm-commissions-reporting.TEMP.RESULTADO_RAPPEL_OUOC` CONFIG
  ON BASE.nombre_comercio = CONFIG.DISTRIBUIDOR
  AND CONFIG.MES = ID_MES_PR


  CROSS JOIN UNNEST(canales_pr) AS canal_pr

  WHERE BASE.id_mes = id_mes_pr
  AND BASE.canal = canal_pr
  AND BASE.CONCEPTO = 'A - Servicio Fijo'
  AND PONDERACIONES.phone_nm IS NOT NULL
  AND CONFIG.DISTRIBUIDOR IS NOT NULL

  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id ORDER BY BASE.sale_date DESC) = 1)


;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo,id_mes_pr, canales_pr, 'TEMP.CALCULO_RAPPEL_OUOC', 'ACTUALIZAR');

END