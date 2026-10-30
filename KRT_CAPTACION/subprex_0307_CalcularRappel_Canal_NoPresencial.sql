BEGIN

  DECLARE
    ratio float64;

  SET
    ratio = (
    SELECT
      COUNTIF(tipo_dia = 'LABORABLE') / COUNTIF(tipo_dia = 'LABORABLE'
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
        dia_id = HASTA_ID));

  -- Registro datos en tabla 
  -- `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL_NO_PRESENCIAL`

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL`

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL`
  ---   `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_DISTRIBUIDORES_NP`
  ---   `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP`
  ---   

  SELECT
    a.*,
    b.nivel
  FROM (
    SELECT
      obj1.marca_ds,
      n1.nombre_distribuidor_2_ds,
      n1.canal_alta_ds,
      obj1.subcanal_ds,
      n1.grupo_rappel_ds,
      n1.bas,
      ROUND(proyeccion) proyeccion
    FROM (
      SELECT
        a.*,
        ifnull(b.nombre_distribuidor_alta_ds,
          a.nombre_distribuidor_ds) nombre_distribuidor_2_ds
      FROM (
        SELECT
          ifnull(np.nombre_distriudor_unificado_ds,
            a.nombre_distribuidor_alta_ds) nombre_distribuidor_ds,
          a.canal_alta_ds,
          a.grupo_rappel_ds,
          SUM(bas) bas,
          SUM(bas*ratio) proyeccion
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
                  'RACC')
                AND canal_alta_ds <> 'TELEVENTA')
              OR marca_ds NOT IN ('EUSKALTEL',
                'RACC'))
            --- FIN AÑADIDO 
          ) a
        LEFT JOIN
          `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_DISTRIBUIDORES_NP` np
        ON
          a.nombre_distribuidor_alta_ds = np.nombre_distribuidor_alta_ds
        LEFT JOIN (
          SELECT
            DISTINCT canal_ds,
            subcanal_ds,
            grupo_rappel
          FROM
            `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP`) n
        ON
          a.canal_alta_ds = n.canal_ds
          AND a.grupo_rappel_ds = n.grupo_rappel
        WHERE
          n.subcanal_ds = 'X'
        GROUP BY
          1,
          2,
          3) a
      LEFT JOIN
        `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_DISTRIBUIDORES_NP` b
      ON
        a.nombre_distribuidor_ds = nombre_distriudor_unificado_ds) n1
    LEFT JOIN
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` obj1
    ON
      n1.nombre_distribuidor_2_ds = obj1.nombre_distribuidor_alta_ds
      AND n1.canal_alta_ds = obj1.canal_alta_ds
      AND n1.grupo_rappel_ds = obj1.grupo_rappel_ds ) a
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` b
  ON
    a.canal_alta_ds = b.canal_ds
    AND a.grupo_rappel_ds = b.grupo_rappel
    AND a.proyeccion BETWEEN b.BA_MIN
    AND b.BA_MAX
  ORDER BY
    nombre_distribuidor_2_ds,
    canal_alta_ds,
    subcanal_ds;

END