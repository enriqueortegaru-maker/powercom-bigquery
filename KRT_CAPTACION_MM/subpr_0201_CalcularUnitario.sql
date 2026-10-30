BEGIN

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION_MM.UNITARIOS` AS
  WITH
    a AS (
    SELECT
      tmp.*,
      CASE
        WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CANALES` c WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds =UPPER(c.nombre_distribuidor_ds) ) = 1 THEN ( SELECT c.clave FROM `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CANALES` c WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds =UPPER(c.nombre_distribuidor_ds) )
    END
      clave --, importe
    FROM
      `mm-commissions-reporting.KRT_CAPTACION_MM.EVENTOS_CAPTACION` tmp)
  SELECT
    a.*,
    c.marco_retributivo_ds,
    importe_dealer,
    importe_gestor,
    CASE
      WHEN portabilidad_in_lg = 1 THEN importe_porta_dealer
    ELSE
    0
  END
    importe_porta_dealer,
    CASE
      WHEN portabilidad_in_lg = 1 THEN importe_porta_gestor
    ELSE
    0
  END
    importe_porta_gestor,
    CASE
      WHEN a.segmento_ds = 'RESIDENCIAL' THEN 0
    ELSE
    importe_segmento
  END
    importe_segmento
  FROM
    a
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CANALES` c
  ON
    c.clave = a.clave
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_MARCO` MR
  ON
    c.marco_retributivo_ds = mr.marco_retributivo_ds
    AND a.concepto_ds = mr.concepto_ds
    AND mr.marca_ds = c.marca_ds
    AND a.cambio = mr.cambio;


END