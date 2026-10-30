BEGIN
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION_MM.DECOMISIONES` AS
  WITH
    b AS (
    SELECT
      b.servicio_id,
      b.servicio_id_original,
      marca_ds,
      fecha_baja_dt,
      fecha_baja_id,
      motivo_baja_agrup_ds,
      motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` b
    WHERE
      b.fecha_baja_id BETWEEN DESDE
      AND HASTA
      AND operacion_baja_ds IN ('BAJA',
        'BAJA DOWNGRADE'))
  SELECT
    a.* EXCEPT (importe_dealer,
      importe_gestor,
      importe_porta_dealer,
      importe_porta_gestor,
      importe_segmento),
    -1 * a.importe_dealer *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe_dealer,
    -1 * a.importe_gestor *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe_gestor,
    -1 * a.importe_porta_dealer *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe_porta_dealer,
    -1 * a.importe_porta_gestor *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe_porta_gestor,
    -1 * a.importe_segmento *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe_segmento,
    --,a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM
    b
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES_HISTORICO` a
  ON
    a.servicio_id = b.servicio_id
    AND a.marca_ds = b.marca_ds
  WHERE
    DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0
    AND 180 ;

END