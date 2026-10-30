BEGIN

  DECLARE ratio FLOAT64;

  /* 1. Cálculo unificado del Ratio Laboral */
  SET ratio = (
    SELECT COUNTIF(tipo_dia = 'LABORABLE') / NULLIF(COUNTIF(tipo_dia = 'LABORABLE' AND dia_dt < CURRENT_DATE()), 0)
    FROM `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
    WHERE mes_id IN (SELECT mes_id FROM `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA` WHERE dia_id = HASTA_ID)
  );

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO_DES` AS

  WITH 
  /* --- LÓGICA PRESENCIAL (Ex 0302, 0303, 0304) --- */
  ventas_presencial_subcanal AS (
      SELECT a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.grupo_rappel_ds,
             a.BAS, ROUND(a.BAS * ratio) AS proyeccion, obj.objetivo,
             IFNULL((SAFE_DIVIDE(ROUND(a.BAS * ratio), obj.objetivo)), 0) * 100 AS consecucion
      FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj 
          ON a.marca_ds = obj.marca_ds AND UPPER(a.nombre_distribuidor_alta_ds) = UPPER(obj.nombre_distribuidor_ds) AND UPPER(a.canal_alta_ds) = UPPER(obj.canal_ds) AND UPPER(a.subcanal_ds) = UPPER(obj.subcanal_ds)
      WHERE UPPER(obj.subcanal_ds) <> 'X'
  ),
  ventas_presencial_canal AS (
      SELECT a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.tipo_canal_alta_ds,
             SUM(a.BAS) AS BAS, SUM(ROUND(a.BAS * ratio)) AS proyeccion, MAX(obj.objetivo) as objetivo,
             IFNULL(SAFE_DIVIDE(SUM(ROUND(a.BAS * ratio)), MAX(obj.objetivo)), 0) * 100 AS consecucion
      FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj 
          ON a.marca_ds = obj.marca_ds AND UPPER(a.nombre_distribuidor_alta_ds) = UPPER(obj.nombre_distribuidor_ds) AND UPPER(a.canal_alta_ds) = UPPER(obj.canal_ds)
      WHERE UPPER(obj.subcanal_ds) = 'X'
      GROUP BY 1, 2, 3, 4
  ),
  rappel_presencial_final AS (
      -- Resolucion a nivel SUBCANAL
      SELECT vps.marca_ds, vps.nombre_distribuidor_alta_ds, vps.canal_alta_ds, vps.subcanal_ds, vps.grupo_rappel_ds, np.nivel
      FROM ventas_presencial_subcanal vps
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` np 
          ON vps.marca_ds = np.marca_ds AND vps.consecucion >= np.minimo AND vps.consecucion < np.maximo

      UNION ALL
      
      -- Resolucion a nivel CANAL (Expandido a Subcanal y Grupo Rappel)
      SELECT vpc.marca_ds, vpc.nombre_distribuidor_alta_ds, vpc.canal_alta_ds, rv.subcanal_ds, rv.grupo_rappel_ds, np.nivel
      FROM ventas_presencial_canal vpc
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` rv 
          ON vpc.marca_ds = rv.marca_ds AND vpc.nombre_distribuidor_alta_ds = rv.nombre_distribuidor_alta_ds AND vpc.canal_alta_ds = rv.canal_alta_ds
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` np 
          ON vpc.marca_ds = np.marca_ds AND vpc.consecucion >= np.minimo AND vpc.consecucion < np.maximo
      WHERE NOT EXISTS (
          SELECT 1 FROM ventas_presencial_subcanal vps_check 
          WHERE vpc.marca_ds = vps_check.marca_ds AND vpc.nombre_distribuidor_alta_ds = vps_check.nombre_distribuidor_alta_ds AND rv.subcanal_ds = vps_check.subcanal_ds
      )
  ),

  /* --- LÓGICA NO PRESENCIAL (Ex 0306, 0307) --- */
  ventas_no_presencial_base AS (
      SELECT 
          marca_ds, 
          COALESCE(np.nombre_distribuidor_unificado_ds, a.nombre_distribuidor_alta_ds) AS dist_unificado,
          canal_alta_ds, subcanal_ds, grupo_rappel_ds, BAS, ROUND(BAS * ratio) AS proyeccion
      FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` a
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_DISTRIBUIDORES_NP` np 
          ON a.nombre_distribuidor_alta_ds = np.nombre_distribuidor_alta_ds
      WHERE tipo_canal_alta_ds = 'NO PRESENCIAL' AND canal_alta_ds <> 'WEB' AND marca_ds <> 'VIRGIN' 
        AND ((marca_ds IN ('EUSKALTEL','RACC','R','TELECABLE') AND canal_alta_ds <> 'TELEVENTA') OR marca_ds NOT IN ('EUSKALTEL','RACC','R','TELECABLE'))
  ),
  ventas_np_subcanal AS (
      SELECT a.marca_ds, a.dist_unificado AS nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds, a.grupo_rappel_ds, b.nivel
      FROM (
          SELECT marca_ds, dist_unificado, canal_alta_ds, subcanal_ds, grupo_rappel_ds, SUM(BAS) as bas, SUM(proyeccion) as proyeccion
          FROM ventas_no_presencial_base
          GROUP BY 1, 2, 3, 4, 5
      ) a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` b 
          ON a.canal_alta_ds = b.canal_ds AND a.subcanal_ds = b.subcanal_ds AND a.grupo_rappel_ds = b.grupo_rappel AND a.proyeccion BETWEEN b.BA_MIN AND b.BA_MAX
  ),
  ventas_np_canal AS (
      SELECT a.marca_ds, a.dist_unificado AS nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds, a.grupo_rappel_ds, b.nivel
      FROM (
          SELECT v.marca_ds, v.dist_unificado, v.canal_alta_ds, v.subcanal_ds, v.grupo_rappel_ds,
                 SUM(v.proyeccion) OVER(PARTITION BY v.marca_ds, v.dist_unificado, v.canal_alta_ds, v.grupo_rappel_ds) as proyeccion_canal
          FROM ventas_no_presencial_base v
      ) a
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` b 
          ON a.canal_alta_ds = b.canal_ds AND b.subcanal_ds = 'X' AND a.grupo_rappel_ds = b.grupo_rappel AND a.proyeccion_canal BETWEEN b.BA_MIN AND b.BA_MAX
      WHERE NOT EXISTS (
          SELECT 1 FROM ventas_np_subcanal sub_check
          WHERE sub_check.marca_ds = a.marca_ds AND sub_check.nombre_distribuidor_alta_ds = a.dist_unificado AND sub_check.subcanal_ds = a.subcanal_ds
      )
  ),
  rappel_np_final AS (
      SELECT * FROM ventas_np_subcanal
      UNION ALL
      SELECT * FROM ventas_np_canal
  )

  /* --- UNION FINAL Y CREACION DE LA TABLA (Ex 0308) --- */
  SELECT DISTINCT marca_ds, nombre_distribuidor_alta_ds, canal_alta_ds, subcanal_ds, grupo_rappel_ds, nivel
  FROM rappel_presencial_final
  UNION ALL
  SELECT DISTINCT marca_ds, nombre_distribuidor_alta_ds, canal_alta_ds, subcanal_ds, grupo_rappel_ds, nivel
  FROM rappel_np_final;

END