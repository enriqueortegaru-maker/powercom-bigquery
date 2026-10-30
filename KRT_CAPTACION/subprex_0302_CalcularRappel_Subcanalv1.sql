BEGIN
  ---- PARCHE VERSION 2 - > PUBLICADO 20221118
      -- PARCHE VERSION 2
      -- ELIMINO       
      --1)*100 consecucion
      --AÑADO
      --  0)*100 consecucion      
  --- FIN PARCHE VERSION 2

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


  --- Creo tabla de salida 
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_SUBCANAL`

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_SUBCANAL` AS

  --- Tablas de entrada
  ---   `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`  -> SALIDA PASO ANTERIOR
  ---   `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS`
  ---   


    SELECT
      objetivo_alcanzado.*,
      objetivo.objetivo,
      ifnull((safe_divide(objetivo_alcanzado.proyeccion,
            objetivo.objetivo) ),
        0)*100 consecucion
    FROM (
      SELECT
        *,
        ROUND(BAS*ratio) proyeccion
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`) objetivo_alcanzado
    LEFT JOIN
      `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` objetivo
    ON
      objetivo_alcanzado.marca_ds = objetivo.marca_ds
      AND UPPER(objetivo_alcanzado.nombre_distribuidor_alta_ds) = UPPER(objetivo.nombre_distribuidor_ds)
      AND UPPER(objetivo.canal_ds) = UPPER(objetivo_alcanzado.canal_alta_ds)
      AND UPPER(objetivo.subcanal_ds) = UPPER(objetivo_alcanzado.subcanal_ds)
    WHERE
      UPPER(objetivo.subcanal_ds) <> 'X';
      
END