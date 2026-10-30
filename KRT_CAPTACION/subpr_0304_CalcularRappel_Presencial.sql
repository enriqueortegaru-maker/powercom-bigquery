BEGIN

  --- Creo tabla de salida 
  ---   D90_FINANCIERO.`mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL` AS

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_SUBCANAL` a
  ---   `mm-commissions-reporting.KRT_CAPTACION.NIVELES_PRESENCIAL` NP 

  SELECT
    a.*,
    np.nivel
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_SUBCANAL` a
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.NIVELES_PRESENCIAL` NP
  ON
    a.marca_ds = np.marca_ds
    AND a.consecucion >= np.minimo
    AND a.consecucion < NP.maximo;
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`
  SELECT
    DISTINCT n1.marca_ds,
    n1.nombre_distribuidor_alta_ds,
    n1.canal_alta_ds,
    n2.subcanal_ds,
    n1.tipo_canal_alta_ds,
    n2.grupo_rappel_ds,
    n1.BAS,
    n1.proyeccion,
    n1.objetivo,
    n1.consecucion,
    n1.nivel
  FROM (
    SELECT
      a.marca_ds,
      nombre_distribuidor_alta_ds,
      canal_alta_ds,
      tipo_canal_alta_ds,
      BAS,
      proyeccion,
      objetivo,
      consecucion,
      np.nivel
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL` a
    LEFT JOIN
      `mm-commissions-reporting.KRT_CAPTACION.NIVELES_PRESENCIAL` NP
    ON
      a.marca_ds = np.marca_ds
      AND a.consecucion >= np.minimo
      AND a.consecucion < NP.maximo ) n1
  LEFT JOIN (
    SELECT
      marca_ds,
      nombre_distribuidor_alta_ds,
      canal_alta_ds,
      tipo_canal_alta_ds,
      subcanal_ds,
      obj1.grupo_rappel_ds
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` obj1
    WHERE
      NOT EXISTS (
      SELECT
        1
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.OBJETIVOS` obj2
      WHERE
        obj1.canal_alta_ds = obj2.canal_ds
        AND obj1.subcanal_ds = obj2.subcanal_ds
        AND obj1.marca_ds = obj2.marca_ds) ) n2
  ON
    n1.marca_ds = n2.marca_ds
    AND n1.nombre_distribuidor_alta_ds = n2.nombre_distribuidor_alta_ds
    AND n1.canal_alta_ds = n2.canal_alta_ds
    AND n1.tipo_canal_alta_ds = n2.tipo_canal_alta_ds
  ORDER BY
    1,
    2;

END