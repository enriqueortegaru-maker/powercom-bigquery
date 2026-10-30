BEGIN

  --- Creo tabla de salida 
  ---   D90_FINANCIERO.`mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL` AS

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_SUBCANAL` a
  ---   `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` NP 

  SELECT
    a.*,
    np.nivel
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_SUBCANAL` a
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` NP
  ON
    a.marca_ds = np.marca_ds
    AND a.consecucion >= np.minimo
    AND a.consecucion < NP.maximo;



  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`
  
  WITH RVxOBJ AS (
      SELECT
        obj1.marca_ds,
        obj1.nombre_distribuidor_alta_ds,
        obj1.canal_alta_ds,
        obj1.tipo_canal_alta_ds,
        obj1.subcanal_ds,
        obj1.grupo_rappel_ds,
        --obj2.objetivo
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` obj1
      INNER JOIN
        `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj2    
      ON obj1.marca_ds = obj2.marca_ds 
        AND obj1.canal_alta_ds = obj2.canal_ds  
        AND (obj1.subcanal_ds=obj2.subcanal_ds OR UPPER(obj2.subcanal_ds)='X')
      GROUP BY 1,2,3,4,5,6
      ORDER BY 1,2,3,4,5,6
  ), RCxNIVP as (
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
      `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` NP
    ON
      a.marca_ds = np.marca_ds
      AND a.consecucion >= np.minimo
      AND a.consecucion < NP.maximo 
)
 SELECT
    DISTINCT RCxNIVP.marca_ds,
    RCxNIVP.nombre_distribuidor_alta_ds,
    RCxNIVP.canal_alta_ds,
    RVxOBJ.subcanal_ds,
    RCxNIVP.tipo_canal_alta_ds,
    RVxOBJ.grupo_rappel_ds,
    RCxNIVP.BAS,
    RCxNIVP.proyeccion,
    RCxNIVP.objetivo,
    RCxNIVP.consecucion,
    RCxNIVP.nivel
  FROM  
    RCxNIVP
  LEFT JOIN 
    RVxOBJ
  ON
    RCxNIVP.marca_ds = RVxOBJ.marca_ds
    AND RCxNIVP.nombre_distribuidor_alta_ds = RVxOBJ.nombre_distribuidor_alta_ds
    AND RCxNIVP.canal_alta_ds = RVxOBJ.canal_alta_ds
    AND RCxNIVP.tipo_canal_alta_ds = RVxOBJ.tipo_canal_alta_ds
  ORDER BY
    1,
    2;

END