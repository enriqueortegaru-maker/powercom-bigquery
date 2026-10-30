BEGIN

  DECLARE ratio FLOAT64;
  --DECLARE HASTA_ID INT64;SET HASTA_ID=20260831;

  /* 1. Cálculo unificado del Ratio Laboral */

---=================================================================================
---     APLICO CONTINGENCIA
---=================================================================================


  SET ratio = (
    --DECLARE HASTA_ID INT64;SET HASTA_ID=20260831;
    SELECT COUNTIF(tipo_dia = 'LABORABLE') / NULLIF(COUNTIF(tipo_dia = 'LABORABLE' AND dia_dt < CURRENT_DATE()), 0)
    FROM `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
    WHERE mes_id IN (SELECT mes_id FROM `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA` WHERE dia_id = HASTA_ID)
  );




---=================================================================================
---     FIN CONTINGENCIA
---=================================================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO` AS

  WITH 
  /* ========================================================================================================
     LÓGICA PRESENCIAL (CRITERIO: PORCENTUAL)
     ======================================================================================================== */
  ventas_presencial_subcanal AS (
      SELECT a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.grupo_rappel_ds,
             a.BAS, ROUND(a.BAS * ratio) AS proyeccion, obj.objetivo,
             IFNULL((SAFE_DIVIDE(ROUND(a.BAS * ratio), obj.objetivo)), 0) * 100 AS consecucion
      FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj 
          ON a.marca_ds = obj.marca_ds 
          AND UPPER(TRIM(a.nombre_distribuidor_alta_ds)) = UPPER(TRIM(obj.nombre_distribuidor_ds)) 
          AND UPPER(TRIM(a.canal_alta_ds)) = UPPER(TRIM(obj.canal_ds)) 
          AND UPPER(TRIM(a.subcanal_ds)) = UPPER(TRIM(obj.subcanal_ds))
      WHERE UPPER(TRIM(obj.subcanal_ds)) <> 'X'
  ),
  ventas_presencial_canal AS (
      SELECT a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.tipo_canal_alta_ds,
             SUM(a.BAS) AS BAS, SUM(ROUND(a.BAS * ratio)) AS proyeccion, MAX(obj.objetivo) as objetivo,
             IFNULL(SAFE_DIVIDE(SUM(ROUND(a.BAS * ratio)), MAX(obj.objetivo)), 0) * 100 AS consecucion
      FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj 
          ON a.marca_ds = obj.marca_ds 
          AND UPPER(TRIM(a.nombre_distribuidor_alta_ds)) = UPPER(TRIM(obj.nombre_distribuidor_ds)) 
          AND UPPER(TRIM(a.canal_alta_ds)) = UPPER(TRIM(obj.canal_ds))
      WHERE UPPER(TRIM(obj.subcanal_ds)) = 'X'
      GROUP BY 1, 2, 3, 4
   ),
   rappel_presencial_final AS (
      -- Resolución a nivel SUBCANAL
      SELECT vps.marca_ds, vps.nombre_distribuidor_alta_ds, vps.canal_alta_ds, vps.subcanal_ds, vps.tipo_canal_alta_ds, vps.grupo_rappel_ds, 
             vps.BAS, vps.proyeccion, vps.objetivo, vps.consecucion, np.nivel, 
             'porcentual' AS criterio_rappel
      FROM ventas_presencial_subcanal vps
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` np 
          ON vps.marca_ds = np.marca_ds AND vps.consecucion >= np.minimo AND vps.consecucion < np.maximo
      
      UNION ALL
      
      -- Resolución a nivel CANAL (Fallback con Anti-Join estricto)
      SELECT vpc.marca_ds, vpc.nombre_distribuidor_alta_ds, vpc.canal_alta_ds, rv.subcanal_ds, vpc.tipo_canal_alta_ds, rv.grupo_rappel_ds, 
             vpc.BAS, vpc.proyeccion, vpc.objetivo, vpc.consecucion, np.nivel, 
             'porcentual' AS criterio_rappel
      FROM ventas_presencial_canal vpc
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` rv 
          ON vpc.marca_ds = rv.marca_ds 
          AND UPPER(TRIM(vpc.nombre_distribuidor_alta_ds)) = UPPER(TRIM(rv.nombre_distribuidor_alta_ds)) 
          AND UPPER(TRIM(vpc.canal_alta_ds)) = UPPER(TRIM(rv.canal_alta_ds))
      LEFT JOIN ventas_presencial_subcanal vps_check 
          ON vpc.marca_ds = vps_check.marca_ds 
          AND UPPER(TRIM(vpc.nombre_distribuidor_alta_ds)) = UPPER(TRIM(vps_check.nombre_distribuidor_alta_ds)) 
          AND UPPER(TRIM(rv.canal_alta_ds)) = UPPER(TRIM(vps_check.canal_alta_ds))
          AND UPPER(TRIM(rv.subcanal_ds)) = UPPER(TRIM(vps_check.subcanal_ds))
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` np 
          ON vpc.marca_ds = np.marca_ds AND vpc.consecucion >= np.minimo AND vpc.consecucion < np.maximo
      WHERE vps_check.subcanal_ds IS NULL
  ),

  /* ========================================================================================================
     LÓGICA NO PRESENCIAL (CRITERIO: ABSOLUTO)
     ======================================================================================================== */
  ventas_no_presencial_base AS (
      SELECT 
          marca_ds, 
          COALESCE(np.nombre_distribuidor_unificado_ds, a.nombre_distribuidor_alta_ds) AS dist_unificado,
          canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, grupo_rappel_ds, BAS, ROUND(BAS * ratio) AS proyeccion
      FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` a
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_DISTRIBUIDORES_NP` np 
          ON a.nombre_distribuidor_alta_ds = np.nombre_distribuidor_alta_ds
      WHERE tipo_canal_alta_ds = 'NO PRESENCIAL' AND UPPER(TRIM(canal_alta_ds)) <> 'WEB' AND UPPER(TRIM(marca_ds)) <> 'VIRGIN' 
        AND ((marca_ds IN ('EUSKALTEL','RACC','R','TELECABLE') AND UPPER(TRIM(canal_alta_ds)) <> 'TELEVENTA') OR marca_ds NOT IN ('EUSKALTEL','RACC','R','TELECABLE'))
  ),
  ventas_np_subcanal AS (
      SELECT a.marca_ds, a.dist_unificado AS nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.grupo_rappel_ds, 
             a.bas AS BAS, a.proyeccion, CAST(NULL AS FLOAT64) AS objetivo, CAST(NULL AS FLOAT64) AS consecucion, b.nivel, 
             'absoluto' AS criterio_rappel
      FROM (
          SELECT marca_ds, dist_unificado, canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, grupo_rappel_ds, SUM(BAS) as bas, SUM(proyeccion) as proyeccion
          FROM ventas_no_presencial_base
          GROUP BY 1, 2, 3, 4, 5, 6
      ) a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` b 
          ON UPPER(TRIM(a.canal_alta_ds)) = UPPER(TRIM(b.canal_ds)) AND UPPER(TRIM(a.subcanal_ds)) = UPPER(TRIM(b.subcanal_ds)) AND UPPER(TRIM(a.grupo_rappel_ds)) = UPPER(TRIM(b.grupo_rappel)) AND a.proyeccion BETWEEN b.BA_MIN AND b.BA_MAX
  ),
  ventas_np_canal AS (
      SELECT a.marca_ds, a.dist_unificado AS nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.grupo_rappel_ds, 
             a.bas AS BAS, a.proyeccion_canal AS proyeccion, CAST(NULL AS FLOAT64) AS objetivo, CAST(NULL AS FLOAT64) AS consecucion, b.nivel, 
             'absoluto' AS criterio_rappel
      FROM (
          SELECT v.marca_ds, v.dist_unificado, v.canal_alta_ds, v.subcanal_ds, v.tipo_canal_alta_ds, v.grupo_rappel_ds, v.BAS as bas,
                 SUM(v.proyeccion) OVER(PARTITION BY v.marca_ds, v.dist_unificado, v.canal_alta_ds, v.grupo_rappel_ds) as proyeccion_canal
          FROM ventas_no_presencial_base v
      ) a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` b 
          ON UPPER(TRIM(a.canal_alta_ds)) = UPPER(TRIM(b.canal_ds)) AND UPPER(TRIM(b.subcanal_ds)) = 'X' AND UPPER(TRIM(a.grupo_rappel_ds)) = UPPER(TRIM(b.grupo_rappel)) AND a.proyeccion_canal BETWEEN b.BA_MIN AND b.BA_MAX
      LEFT JOIN ventas_np_subcanal sub_check
          ON a.marca_ds = sub_check.marca_ds 
          AND UPPER(TRIM(a.dist_unificado)) = UPPER(TRIM(sub_check.nombre_distribuidor_alta_ds)) 
          AND UPPER(TRIM(a.canal_alta_ds)) = UPPER(TRIM(sub_check.canal_alta_ds))
          AND UPPER(TRIM(a.subcanal_ds)) = UPPER(TRIM(sub_check.subcanal_ds))
      WHERE sub_check.subcanal_ds IS NULL
  ),
  rappel_np_final AS (
      SELECT * FROM ventas_np_subcanal
      UNION ALL
      SELECT * FROM ventas_np_canal
  )

  /* ========================================================================================================
     UNION FINAL Y CREACIÓN DE LA TABLA MAESTRA DE DETALLE
     ======================================================================================================== */
  SELECT DISTINCT 
      marca_ds, nombre_distribuidor_alta_ds, canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, grupo_rappel_ds, 
      BAS, proyeccion, objetivo, consecucion, nivel, criterio_rappel
  FROM rappel_presencial_final
  
  UNION ALL
  
  SELECT DISTINCT 
      marca_ds, nombre_distribuidor_alta_ds, canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, grupo_rappel_ds, 
      BAS, proyeccion, objetivo, consecucion, nivel, criterio_rappel
  FROM rappel_np_final;

END