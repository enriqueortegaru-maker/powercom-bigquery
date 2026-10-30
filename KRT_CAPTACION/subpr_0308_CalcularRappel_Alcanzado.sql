BEGIN

    -- Crear  tabla 
    -- `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO`

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO` AS


    --- Tablas de entrada
    ---  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL` 
    ---  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL` 
      
    SELECT
      marca_ds,
      nombre_distribuidor_alta_ds,
      canal_alta_ds,
      subcanal_ds,
      grupo_rappel_ds,
      nivel
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL`
    UNION ALL
    SELECT
      marca_ds,
      nombre_distribuidor_alta_ds,
      canal_alta_ds,
      subcanal_ds,
      grupo_rappel_ds,
      nivel
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`;


  END