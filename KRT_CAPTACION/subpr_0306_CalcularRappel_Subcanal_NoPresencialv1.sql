BEGIN
DECLARE
  ratio float64;
SET
  ratio = (
  SELECT
    COUNTIF(tipo_dia = 'LABORABLE' ) / COUNTIF(tipo_dia = 'LABORABLE'
      AND dia_dt < CURRENT_DATE()) ratio_laborales
  FROM
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
  WHERE
    mes_id IN (
    SELECT
      mes_id
    FROM
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
    WHERE
      dia_id = HASTA_ID)); --- Creo tabla de salida --- `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL`
CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL` AS 
  
  --- Tablas de entrada 
    --- `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` 
    --- `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_DISTRIBUIDORES_NP` 
    --- `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` 
    --- `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL

SELECT
  obj1.marca_ds,
  a.*,
  b.nivel
FROM (
  SELECT
    ifnull(np.nombre_distribuidor_unificado_ds,
      a.nombre_distribuidor_alta_ds) nombre_distribuidor_alta_ds,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.grupo_rappel_ds,
    SUM(bas) bas,
    SUM(ROUND(bas*ratio)) proyeccion
  FROM (
          SELECT
            *
          FROM
            `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL`
          WHERE
            tipo_canal_alta_ds = 'NO PRESENCIAL'
            AND canal_alta_ds <> 'WEB'
            AND marca_ds <> 'VIRGIN' 
            --- AÑADIDO
            AND ((marca_ds IN ('EUSKALTEL',
                  'RACC','R','TELECABLE')
                AND canal_alta_ds <> 'TELEVENTA')
              OR marca_ds NOT IN ('EUSKALTEL',
                'RACC','R','TELECABLE'))
            --- FIN AÑADIDO 
          ) a
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_DISTRIBUIDORES_NP` np
    --`dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_DISTRIBUIDORES_NP` np
  ON
    a.nombre_distribuidor_alta_ds = np.nombre_distribuidor_alta_ds
  LEFT JOIN (
    SELECT
      DISTINCT canal_ds,
      subcanal_ds,
      grupo_rappel
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL`) n
  ON
    a.canal_alta_ds = n.canal_ds
    AND a.subcanal_ds = n.subcanal_ds
    AND a.grupo_rappel_ds = n.grupo_rappel
  WHERE
    n.subcanal_ds <> 'X'
  GROUP BY
    1,
    2,
    3,
    4 ) a
LEFT JOIN
  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` obj1
ON
  a.nombre_distribuidor_alta_ds = obj1.nombre_distribuidor_alta_ds
  AND a.canal_alta_ds = obj1.canal_alta_ds
  AND a.subcanal_ds = obj1.subcanal_ds
  AND a.grupo_rappel_ds = obj1.grupo_rappel_ds
LEFT JOIN
  `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL` b
ON
  a.canal_alta_ds = b.canal_ds
  AND a.grupo_rappel_ds = b.grupo_rappel
  AND a.proyeccion BETWEEN b.BA_MIN
  AND b.BA_MAX
ORDER BY
  nombre_distribuidor_alta_ds,
  canal_alta_ds,
  subcanal_ds;
END