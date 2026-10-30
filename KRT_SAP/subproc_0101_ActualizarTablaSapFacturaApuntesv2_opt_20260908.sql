BEGIN
  DECLARE vmes_factura_id INT64;
  DECLARE vmes_factura_dt DATE;
  DECLARE vnull_rows      INT64  DEFAULT 0;
  DECLARE vnull_importe   FLOAT64 DEFAULT 0;

  SET vmes_factura_id = CAST(SAFE_DIVIDE(DESDE, 100) AS INT64);         -- yyyymm
  SET vmes_factura_dt = PARSE_DATE('%Y%m', CAST(vmes_factura_id AS STRING));

  -- PASO 1 — build the working set
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO` AS
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_factura_apuntes_desde_tr_en_proceso`(DESDE);

  -- PASO 1b — VALIDATION GATE (new) --------------------------------------------
  -- Persist offenders for traceability (always refreshed, even when empty).
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO_SIN_CODIGO` AS
  SELECT CURRENT_TIMESTAMP() AS detected_at, *
  FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO`
  WHERE (CODIGO IS NULL OR TRIM(CODIGO) = '')
    AND bp NOT IN (7856, 6634);

  SET (vnull_rows, vnull_importe) = (
    SELECT AS STRUCT COUNT(*), IFNULL(ROUND(SUM(importe), 2), 0)
    FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO_SIN_CODIGO`
  );

  IF vnull_rows > 0 THEN
    RAISE USING MESSAGE = FORMAT(
      'ABORT subproc_0101: %d apunte(s) sin CODIGO (importe %.2f) para %t. '
      || 'La carga NO se aplica y el mes previo se conserva. '
      || 'Ejecute pr_warn_preflight_traductor(%d) y revise PARAM_TRADUCTOR / f_generadorDeConceptoEnSap. '
      || 'Detalle: SAP_FACTURA_APUNTES_EN_PROCESO_SIN_CODIGO.',
      vnull_rows, vnull_importe, vmes_factura_dt, DESDE);
  END IF;

  -- PASO 3 — swap (reached only when the gate passes) ---------------------------
  DELETE FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
  WHERE mes_factura_dt = vmes_factura_dt;

  INSERT INTO `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO`;
END