BEGIN


-- CALL `mm-commissions-reporting.B2B.pr_TRAFICO_DATOS_BOLSA_CDR`();  -- te calcula desde las fechas de inicio hasta el ultimo mes cerrado

  -----------------------------------------------------------------------------
  -- PASO 1: Crear la tabla destino (siempre limpia)
  -----------------------------------------------------------------------------

  CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_DATOS_BOLSA_V2` (
    mes_inicio INT64,
    id_mes INT64,
    agrupacion_canal STRING,
    id_comisionista STRING,
    nombre_comercio STRING,
    CIF STRING,
    datos_bolsa FLOAT64,
    iwona_grupo STRING,
    total_tarifa_na FLOAT64,
    min_incl FLOAT64,
    sms_incl FLOAT64,
    exceso_sms_ue FLOAT64,
    exceso_datos_ue FLOAT64,
    exceso_voz_ue FLOAT64,
    exceso_sms_nac FLOAT64,
    exceso_datos_nac FLOAT64,
    exceso_voz_nac FLOAT64,
    exceso_otros FLOAT64,
    acceso_looker STRING,
    acceso_looker_vista_general STRING,
    incremento_tipo STRING,
    incremento_valor FLOAT64
  );

  -----------------------------------------------------------------------------
  -- PASO 2: Insertar los valores iniciales (solo mes_inicio)
  -----------------------------------------------------------------------------

  INSERT INTO `mm-commissions-reporting.B2B.TRAFICO_DATOS_BOLSA_V2`
  SELECT
    CAST(mes_inicio AS INT64),
    CAST(mes_inicio AS INT64),
    agrupacion_canal,
    id_comisionista,
    nombre_comercio,
    CIF,
    CAST(REPLACE(datos_bolsa, ',', '.') AS FLOAT64),
    iwona_grupo,
    CAST(REPLACE(total_tarifa_na, ',', '.') AS FLOAT64),
    CAST(REPLACE(min_incl, ',', '.') AS FLOAT64),
    CAST(REPLACE(sms_incl, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_sms_ue, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_datos_ue, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_voz_ue, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_sms_nac, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_datos_nac, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_voz_nac, ',', '.') AS FLOAT64),
    CAST(REPLACE(exceso_otros, ',', '.') AS FLOAT64),
    acceso_looker,
    acceso_looker_vista_general,
    incremento_tipo,
    CAST(REPLACE(incremento_valor, ',', '.') AS FLOAT64)
  FROM `mm-commissions-reporting.GS.DEALERS_TRAFICO`
  WHERE datos_bolsa IS NOT NULL;

  -----------------------------------------------------------------------------
  -- PASO 3: Generar todos los meses siguientes
  -----------------------------------------------------------------------------

  INSERT INTO `mm-commissions-reporting.B2B.TRAFICO_DATOS_BOLSA_V2`
  WITH RECURSIVE meses AS (

    -- Base: los valores iniciales
    SELECT *
    FROM `mm-commissions-reporting.B2B.TRAFICO_DATOS_BOLSA_V2`

    UNION ALL

    -- Mes siguiente
    SELECT
      mes_inicio,
      CAST(
        CASE 
          WHEN MOD(id_mes, 100) = 12 
            THEN (((id_mes / 100) + 1) * 100) - 11
          ELSE id_mes + 1
        END AS INT64
      ) AS id_mes,
      agrupacion_canal,
      id_comisionista,
      nombre_comercio,
      CIF,
      CASE 
        WHEN incremento_tipo = 'fijo' THEN ROUND(datos_bolsa + incremento_valor, 2)
        WHEN incremento_tipo = 'porcentaje' THEN ROUND(datos_bolsa * (1 + incremento_valor), 2)
        ELSE datos_bolsa
      END AS datos_bolsa,
      iwona_grupo,
      total_tarifa_na,
      min_incl,
      sms_incl,
      exceso_sms_ue,
      exceso_datos_ue,
      exceso_voz_ue,
      exceso_sms_nac,
      exceso_datos_nac,
      exceso_voz_nac,
      exceso_otros,
      acceso_looker,
      acceso_looker_vista_general,
      incremento_tipo,
      incremento_valor
    FROM meses
    WHERE id_mes <
      CAST(
        FORMAT_DATE('%Y%m', DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH))
        AS INT64
      )

  )

  SELECT *
  FROM meses
  ORDER BY agrupacion_canal, id_mes;

END