BEGIN

  DECLARE
    ratio float64;

  SET
    ratio = (
    SELECT
      COUNTIF(tipo_dia = 'LABORABLE' ) / COUNTIF(tipo_dia = 'LABORABLE'
        AND dia_dt < CURRENT_DATE()) ratio_laborales  --- Número total dede días laborables en mes de l que forma parte HASTA_ID entre el número de días de ese mes transcurridos hasta hoy
    FROM
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
    WHERE  --- Población de días a considerar es la del mes que contiene la fecha HASTA_ID 
      mes_id IN (
      SELECT
        mes_id
      FROM
        `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA`
      WHERE
        dia_id = HASTA_ID));

  --- Creo tabla de salida 
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL`
  

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL` AS

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` obj1
  ---   `mm-commissions-reporting.KRT_CAPTACION.OBJETIVOS` obj2 

  WITH objetivo_alcanzado as (
    SELECT
      obj1.marca_ds,
      obj1.nombre_distribuidor_alta_ds,
      obj1.canal_alta_ds,
      obj1.tipo_canal_alta_ds,
      SUM(obj1.BAS) BAS,
      SUM(ROUND(obj1.BAS*ratio)) proyeccion
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` obj1
    LEFT JOIN
      `mm-commissions-reporting.KRT_CAPTACION.OBJETIVOS` obj2
    ON
      obj1.marca_ds = obj2.marca_ds
      AND obj1.canal_alta_ds = obj2.canal_ds
      AND obj1.nombre_distribuidor_alta_ds = obj2.nombre_distribuidor_ds
    WHERE
      UPPER(obj2.subcanal_ds)='X'
    GROUP BY
      1,
      2,
      3,
      4
    ORDER BY
      1,
      2,
      3 ASC)
  SELECT
    objetivo_alcanzado.*,
    objetivo.objetivo,
    ifnull(SAFE_DIVIDE(objetivo_alcanzado.proyeccion,
        objetivo.objetivo ),
      1)*100 consecucion
  FROM objetivo_alcanzado
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.OBJETIVOS` objetivo
  ON
    objetivo_alcanzado.marca_ds = objetivo.marca_ds
    AND objetivo_alcanzado.nombre_distribuidor_alta_ds = objetivo.nombre_distribuidor_ds
    AND objetivo.canal_ds = objetivo_alcanzado.canal_alta_ds
  WHERE
    UPPER(objetivo.subcanal_ds) = 'X';

END