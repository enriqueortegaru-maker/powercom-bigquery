BEGIN
  INSERT INTO `mm-commissions-reporting.TEMP.ventas_borradas_d2d`
  SELECT * EXCEPT(emails_acceso_trazabilidad)
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE canal IN UNNEST(in_canales)
    AND id_mes = in_id_mes
    AND cod_segmento = '10'
    AND tariff_ds NOT LIKE '%PRO%'
    AND cif NOT IN ('B80108186')
    AND concepto NOT LIKE 'E - Claw%'
    AND concepto NOT IN (
      'P - Bajada Tarifa Fijo 3M Recalculo',
      'P - Bajada Tarifa Fijo 3M Deduccion',
      'C - Cartera','B - Television Premium','D - Dispositivo Captacion', 'P - Cartera'
    )
    AND concepto NOT LIKE 'Z - %'
    AND estado = 'calculado';

  DELETE FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE canal IN UNNEST(in_canales)
    AND id_mes = in_id_mes
    AND cod_segmento = '10'
    AND tariff_ds NOT LIKE '%PRO%'
    AND cif NOT IN ('B80108186')
    AND concepto NOT LIKE 'E - Claw%'
    AND concepto NOT IN (
      'P - Bajada Tarifa Fijo 3M Recalculo',
      'P - Bajada Tarifa Fijo 3M Deduccion',
      'C - Cartera','B - Television Premium','D - Dispositivo Captacion', 'P - Cartera'
    )
    AND concepto NOT LIKE 'Z - %'
    AND estado = 'calculado';
END