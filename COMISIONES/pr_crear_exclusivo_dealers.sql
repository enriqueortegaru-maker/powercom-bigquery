BEGIN

-- CALL pr_crear_exclusivo_dealers ();

CREATE OR REPLACE TABLE `mm-commissions-reporting.GS.exclusivo_dealers` AS

WITH base AS (

SELECT 
  id_comisionista,
  canal,
  comisiona,
  nombre_comercio,
  razon_social,
  documento,
  zona_fiscal,
  comentarios,
  cond_pago,
  ccc_jazztel AS sfid_jazztel,
  CAST(null AS STRING) AS sfid_jazztel_2,
  CAST(null AS STRING) AS distribuidor_espejo,
  CAST(null AS STRING) AS baja_futura,
  CAST(null AS STRING) AS padre_final,
  check_duplicados,
  canal_procedencia,
  fecha_firma,
  id_comisionista AS dealer
   
FROM `mm-commissions-reporting.GS.exclusivo_dealers_multibrand`

UNION ALL

SELECT 
  id_comisionista,
  canal,
  comisiona,
  nombre_comercio,
  razon_social,
  documento,
  zona_fiscal,
  comentarios,
  cond_pago,
  ccc_jazztel AS sfid_jazztel,
  ccc_jazztel_2 AS sfid_jazztel_2,
  distribuidor_espejo,
  baja_futura,
  padre_final,
  check_duplicados,
  CAST(null AS STRING) AS canal_procedencia,
  CAST(null AS INT64) AS fecha_firma,
  id_comisionista AS dealer
FROM `mm-commissions-reporting.GS.exclusivo_dealers_cex`
)

SELECT 
  id_comisionista,
  canal,
  comisiona,
  nombre_comercio,
  razon_social,
  documento,
  zona_fiscal,
  comentarios,
  cond_pago,
  CASE WHEN ccc_jazztel = id_comisionista THEN NULL ELSE ccc_jazztel END AS ccc_jazztel,
  distribuidor_espejo,
  baja_futura,
  padre_final,
  check_duplicados,
  canal_procedencia,
  fecha_firma  
FROM base
UNPIVOT (ccc_jazztel FOR columna IN (dealer, sfid_jazztel, sfid_jazztel_2))
WHERE ccc_jazztel IS NOT NULL
;

END