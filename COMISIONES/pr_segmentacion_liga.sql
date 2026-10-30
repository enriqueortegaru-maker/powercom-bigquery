BEGIN

  DECLARE v_mes_purga INT64;

  -- id_mes de hace 3 meses (respeta el cambio de año)
  SET v_mes_purga =
    EXTRACT(YEAR  FROM DATE_SUB(DATE(DIV(pr_id_mes,100), MOD(pr_id_mes,100), 1), INTERVAL 3 MONTH)) * 100 +
    EXTRACT(MONTH FROM DATE_SUB(DATE(DIV(pr_id_mes,100), MOD(pr_id_mes,100), 1), INTERVAL 3 MONTH));

-- CALL `mm-commissions-reporting.COMISIONES.pr_segmentacion_liga`(202607,['D2D','D2N','DEM']);

  -- Crea la tabla copia la primera vez (vacia, misma estructura)
  CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.transacciones_copia_d2d_liga`
  CLUSTER BY id_mes, canal
  AS
  SELECT * EXCEPT(emails_acceso_trazabilidad)
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE FALSE;

  -- Copia solo si el mes NO esta ya en la tabla
  IF NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.TEMP.transacciones_copia_d2d_liga`
    WHERE id_mes = pr_id_mes
  ) THEN

    INSERT INTO `mm-commissions-reporting.TEMP.transacciones_copia_d2d_liga`
    SELECT * EXCEPT(emails_acceso_trazabilidad)
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE id_mes = pr_id_mes
      AND canal IN UNNEST(pr_canales);

  END IF;

  -- Purga del historico antiguo
  DELETE FROM `mm-commissions-reporting.TEMP.transacciones_copia_d2d_liga`
  WHERE id_mes <= v_mes_purga;

  -- Tabla de trabajo, leyendo siempre de la copia
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.segmento_liga_d2d` AS
  SELECT *
  FROM `mm-commissions-reporting.TEMP.transacciones_copia_d2d_liga`
  WHERE canal IN UNNEST(pr_canales)
    AND id_mes = pr_id_mes;

  -- Aplicacion del factor de liga
  -- UPDATE `mm-commissions-reporting.TEMP.segmento_liga_d2d` v
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` v
  SET comision = v.comision * f.porcentaje
  FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
  WHERE v.cif = f.cif
    AND f.id_mes = pr_id_mes
    AND v.activation_date >= '2026-07-01'
    AND NOT CONTAINS_SUBSTR(v.concepto, 'Cartera')
    AND v.concepto NOT IN (
      'P - Bajada Tarifa Fijo 3M Recalculo',
      'P - Bajada Tarifa Fijo 3M Deduccion'
      'P - Cartera'--,
      -- 'P - Penalizacion CIF',
      -- 'P - Penalizacion Venta Telefonica'
      )
    AND v.concepto NOT LIKE 'Z - %'
    AND v.estado = 'calculado'
    AND V.canal IN UNNEST(pr_canales);

END