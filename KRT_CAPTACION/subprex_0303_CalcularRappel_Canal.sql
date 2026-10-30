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
        dia_id = HASTA_ID));

  --- Creo tabla de salida 
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL`
  

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_CANAL` AS

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` obj1
  ---   `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj2 

  SELECT
    objetivo_alcanzado.*,
    objetivo.objetivo,
    ifnull(SAFE_DIVIDE(objetivo_alcanzado.proyeccion,
        objetivo.objetivo ),
      1)*100 consecucion
  FROM (
    SELECT
      marca_ds,
      nombre_distribuidor_alta_ds,
      canal_alta_ds,
      tipo_canal_alta_ds,
      SUM(BAS) BAS,
      SUM(ROUND(BAS*ratio)) proyeccion
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` obj1
    WHERE
      NOT EXISTS (
      SELECT
        1
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` obj2
      WHERE
        obj1.canal_alta_ds = obj2.canal_ds
        AND obj1.subcanal_ds = obj2.subcanal_ds
        AND obj1.marca_ds = obj2.marca_ds)
    GROUP BY
      1,
      2,
      3,
      4) objetivo_alcanzado
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` objetivo
  ON
    objetivo_alcanzado.marca_ds = objetivo.marca_ds
    AND objetivo_alcanzado.nombre_distribuidor_alta_ds = objetivo.nombre_distribuidor_ds
    AND objetivo.canal_ds = objetivo_alcanzado.canal_alta_ds
  WHERE
    objetivo.subcanal_ds = 'X';
 
END