BEGIN

DECLARE canales_pr ARRAY<STRING> DEFAULT ['ENK'];

-- CALL COMISIONES.pr_tarifas_exclusivo(202605);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tarifas_exclusivo_corregidas` AS
-- OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

-----------------------------------------------------------------------
/* TARIFAS MÓVILES */
-----------------------------------------------------------------------

SELECT 
  * EXCEPT(capacidad)
  ,CASE
      WHEN tariff_ds LIKE '%GRATIS%'           THEN 0.0
      WHEN tariff_ds LIKE '%COMPARTIDA 0%'     THEN 0.0
      WHEN tariff_ds LIKE '%MB%'               THEN 25.0
      WHEN tariff_ds LIKE '%MULTISIM%'         THEN 25.0 
      WHEN capacidad = 0   THEN
          CASE
              WHEN tariff_ds LIKE '%FIJO%'     THEN 40.0
              WHEN tariff_ds LIKE '%MULTISIM%' THEN 25.0
              ELSE 0.0
          END
      WHEN capacidad = 1         THEN 50.0
      -- WHEN capacidad <= 25    THEN 15
      WHEN capacidad <= 40       THEN 25.0 -- DESDE 202605 PASA DE 20 A 25 EUROS
      -- WHEN capacidad <= 50    THEN 25
      WHEN capacidad <= 90       THEN 30.0
      WHEN capacidad >  90       THEN 40.0
      ELSE 0.0
   END AS tramo_1   
  ,0.0 AS tramo_2
  ,0.0 AS tramo_3
  ,0.0 AS tramo_4
  ,0.0 AS tramo_5
  ,0.0 AS migraciones  
  ,0.0 AS traslados
  ,0.0 AS gestion_canal
  ,0.0 AS cuota
  ,0.0 AS consumo
  ,CAST(null AS STRING) AS campaign_code
  ,'PR_TARIFAS_EXC' AS creado_por
  ,CURRENT_TIMESTAMP() AS creado

FROM (
      SELECT DISTINCT
          canal,
          id_mes,
          marca,
          service_type,
          tariff_id,
          tariff_ds,
          line_type_ds,
          pvp,
          IF(SAFE_CAST(REGEXP_EXTRACT(tariff_ds, r'(\d+)\s?GB') AS INT64) IS NULL, 
            IF(SAFE_CAST(REGEXP_EXTRACT(tariff_ds, r'(\d+)\s?MB') AS INT64) IS NULL, 
              IF((tariff_ds LIKE '%INFINI%' 
                  OR tariff_ds LIKE '%INFGB%' 
                  OR tariff_ds LIKE '%ILIMITADOS%' 
                  OR tariff_ds = 'DATOS Y LLAMADAS ILIMITADAS'
                  OR tariff_ds = 'VOZ_ILIM_DATOS_ILIM'
                 ),1 ,0), 
            SAFE_CAST(REGEXP_EXTRACT(tariff_ds, r'(\d+)\s?MB') AS INT64)), 
          SAFE_CAST(REGEXP_EXTRACT(tariff_ds, r'(\d+)\s?GB') AS INT64)) AS capacidad
      FROM `mm-commissions-reporting.COMISIONES.tarifas`
      CROSS JOIN UNNEST(canales_pr) AS canal_pr
      WHERE id_mes = mes_pr
        AND canal = canal_pr
        AND (tramo_1 = 0.0 OR tramo_1 IS NULL)
        AND service_type = 'MOBILE'
        AND tariff_ds NOT LIKE '%PRE%'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY tariff_id, service_type, marca, canal, CAST(tramo_1 AS STRING) ORDER BY creado DESC) = 1
      ORDER BY tariff_id, marca 
    )

UNION ALL

-----------------------------------------------------------------------
/* TARIFAS FIJOS */
-----------------------------------------------------------------------

SELECT 
  * EXCEPT(capacidad,tariff_extract)
  ,CASE 
      WHEN capacidad IS NULL THEN
          CASE
              WHEN tariff_ds = 'INTERNET MOVIL EN CASA' AND marca = 'YOIGO'     THEN 85.0
              WHEN tariff_ds = 'INTERNET MOVIL EN CASA' AND marca = 'MASMOVIL'  THEN 65.0
              WHEN tariff_ds = 'INTERNET MOVIL EN CASA' AND marca = 'PEPEPHONE' THEN 55.0
              WHEN tariff_ds = 'INTERNET MOVIL EN CASA: SEGUNDA RESIDENCIA'     THEN 30.0
              ELSE 0.0
          END
      WHEN capacidad = 10 AND marca = 'YOIGO' THEN 145.0 -- PASA DE 160 A 145 EN 202605
      WHEN capacidad = 5 AND marca = 'YOIGO'  THEN 140.0
      WHEN capacidad = 2 AND marca = 'YOIGO'  THEN 135.0
      WHEN capacidad = 1 THEN
          CASE 
              WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 70.0
              WHEN marca = 'YOIGO'     THEN 125.0
              WHEN marca = 'MASMOVIL'  THEN 105.0
              WHEN marca = 'PEPEPHONE' THEN 95.0

          END
      -- WHEN capacidad = 2 AND cod_segmento = '12' THEN
      --     CASE 
      --         WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 70
      --         WHEN marca = 'YOIGO'  THEN 125
      --         WHEN marca IN ('MASMOVIL','PEPEPHONE') THEN 95
      --     END
      WHEN capacidad IN (600,500) THEN
          CASE 
              WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 50.0
              WHEN marca = 'YOIGO'     THEN 105.0
              WHEN marca = 'MASMOVIL'  THEN 85.0
              WHEN marca = 'PEPEPHONE' THEN 75.0
          END
      WHEN capacidad = 300 THEN
          CASE 
              WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 30.0
              WHEN marca = 'YOIGO'     THEN 85.0
              WHEN marca = 'MASMOVIL'  THEN 65.0
              WHEN marca = 'PEPEPHONE' THEN 55.0
          END
      ELSE 0.0
   END AS tramo_1
  ,0.0 AS tramo_2
  ,0.0 AS tramo_3
  ,0.0 AS tramo_4
  ,0.0 AS tramo_5
  ,CASE      
      WHEN capacidad = 10 AND tariff_extract LIKE '%GB%'         THEN 96.0
      WHEN capacidad = 2 AND tariff_extract LIKE '%GB%'          THEN 84.0
      WHEN capacidad = 1 AND tariff_extract LIKE '%GB%'          THEN 70.0
      WHEN capacidad IN (600,500) AND tariff_extract LIKE '%MB%' THEN 50.0
      WHEN capacidad = 300 AND tariff_extract LIKE '%MB%'        THEN 30.0
      ELSE 0.0
   END AS migraciones  

  ,CASE      
      WHEN capacidad = 10 AND tariff_extract LIKE '%GB%'         THEN 96.0
      WHEN capacidad = 2 AND tariff_extract LIKE '%GB%'          THEN 84.0
      WHEN capacidad = 1 AND tariff_extract LIKE '%GB%'          THEN 70.0
      WHEN capacidad IN (600,500) AND tariff_extract LIKE '%MB%' THEN 50.0
      WHEN capacidad = 300 AND tariff_extract LIKE '%MB%'        THEN 30.0
      ELSE 0.0
   END AS traslados

  ,0.0 AS gestion_canal
  ,0.0 AS cuota
  ,0.0 AS consumo
  ,CAST(null AS STRING) AS campaign_code
  ,'PR_TARIFAS_EXC' AS creado_por
  ,CURRENT_TIMESTAMP() AS creado     

FROM (
      SELECT DISTINCT
          canal,
          id_mes,
          marca,
          service_type,
          tariff_id,
          tariff_ds,
          line_type_ds,
          pvp,
          TRIM(SPLIT(tariff_ds, '+')[SAFE_OFFSET(0)]) AS tariff_extract,
          SAFE_CAST(REGEXP_EXTRACT(TRIM(SPLIT(tariff_ds, '+')[SAFE_OFFSET(0)]), r'(\d+)') AS INT64) AS capacidad,
      FROM `mm-commissions-reporting.COMISIONES.tarifas`
      CROSS JOIN UNNEST(canales_pr) AS canal_pr
      WHERE id_mes = mes_pr
        AND canal = canal_pr
        AND (tramo_1 = 0.0 OR tramo_1 IS NULL)
        AND service_type = 'INTERNET'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY tariff_id, service_type, marca, canal, CAST(tramo_1 AS STRING) ORDER BY creado DESC) = 1
      ORDER BY tariff_id, marca
    )

;

UPDATE `mm-commissions-reporting.COMISIONES.tarifas` a
SET a.tramo_1 = b.tramo_1, a.tramo_2 = b.tramo_2, a.tramo_3 = b.tramo_3, a.tramo_4 = b.tramo_4, a.tramo_5 = b.tramo_5, a.migraciones = b.migraciones, a.traslados = b.traslados, a.gestion_canal = b.gestion_canal, a.cuota = b.cuota, a.consumo = b.consumo, a.creado_por = b.creado_por, a.creado = b.creado
FROM (
      SELECT 
        DISTINCT * 
      FROM `mm-commissions-reporting.TEMP.tarifas_exclusivo_corregidas`

      CROSS JOIN UNNEST(canales_pr) AS canal_pr

      WHERE id_mes = mes_pr
        AND canal = canal_pr
        AND tramo_1 IS NOT NULL
        AND tramo_1 != 0.0

      QUALIFY ROW_NUMBER() OVER(PARTITION BY tariff_id, tariff_ds, service_type, marca, canal, CAST(tramo_1 AS STRING) ORDER BY creado DESC) = 1
    ) b
WHERE a.id_mes = mes_pr
  AND a.tariff_id = b.tariff_id
  AND a.tariff_ds = b.tariff_ds
  AND a.canal = b.canal
  AND a.marca = b.marca
  AND a.service_type = b.service_type
  AND (a.tramo_1 = 0.0 OR a.tramo_1 IS NULL)
;

END