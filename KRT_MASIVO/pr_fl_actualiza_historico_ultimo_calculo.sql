BEGIN

  DECLARE vmes_factura_dt DATE;
  DECLARE vsrc_calc_dt    DATE;
  DECLARE vtgt_calc_dt    DATE;
  DECLARE vupd_com        BOOL DEFAULT FALSE;
  DECLARE vupd_dec        BOOL DEFAULT FALSE;

  SET vmes_factura_dt = PARSE_DATE('%Y%m', CAST(vmes_id AS STRING));

  --- ============================================================
  --- PASO 1: COMISIONES
  --- ============================================================

  SET vsrc_calc_dt = (
    SELECT MAX(fecha_calc_dt)
    FROM `mm-commissions-reporting.KRT_MASIVO.AGG_COMISIONES`
    WHERE mes_id = vmes_id
  );

  SET vtgt_calc_dt = (
    SELECT MAX(fecha_calc_dt)
    FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES`
    WHERE mes_factura_dt = vmes_factura_dt
  );

  IF vsrc_calc_dt IS NOT NULL
     AND (vtgt_calc_dt IS NULL OR vsrc_calc_dt > vtgt_calc_dt)
  THEN

    BEGIN TRANSACTION;

      DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES`
      WHERE mes_factura_dt = vmes_factura_dt;

      INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES`
      SELECT
          vmes_factura_dt AS mes_factura_dt,
          `mm-commissions-reporting.KRT_MASIVO.f_creaPrefijoIdComision`(vmes_id, c.brand_ds, c.tipo, "comision")
            || '_' || ROW_NUMBER() OVER() AS commission_id,
          CAST(NULL AS STRING) AS id_registro,
          CAST(NULL AS STRING) AS invoice_id,
          'calculado' AS estado,
          c.*
      FROM `mm-commissions-reporting.KRT_MASIVO.AGG_COMISIONES` AS c
      WHERE c.fecha_calc_dt = vsrc_calc_dt
        AND c.mes_id = vmes_id;

    COMMIT TRANSACTION;

    SET vupd_com = TRUE;

  END IF;

  --- ============================================================
  --- PASO 2: DECOMISIONES
  --- ============================================================

  SET vsrc_calc_dt = (
    SELECT MAX(fecha_calc_dt)
    FROM `mm-commissions-reporting.KRT_MASIVO.AGG_DECOMISIONES`
    WHERE mes_id = vmes_id
  );

  SET vtgt_calc_dt = (
    SELECT MAX(fecha_calc_dt)
    FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES`
    WHERE mes_factura_dt = vmes_factura_dt
  );

  IF vsrc_calc_dt IS NOT NULL
     AND (vtgt_calc_dt IS NULL OR vsrc_calc_dt > vtgt_calc_dt)
  THEN

    BEGIN TRANSACTION;

      DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES`
      WHERE mes_factura_dt = vmes_factura_dt;

      INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES`
      SELECT
          vmes_factura_dt AS mes_factura_dt,
          `mm-commissions-reporting.KRT_MASIVO.f_creaPrefijoIdComision`(vmes_id, c.brand_ds, c.tipo, "decomision")
            || '_' || ROW_NUMBER() OVER() AS commission_id,
          CAST(NULL AS STRING) AS id_registro,
          CAST(NULL AS STRING) AS invoice_id,
          'calculado' AS estado,
          c.*
      FROM `mm-commissions-reporting.KRT_MASIVO.AGG_DECOMISIONES` AS c
      WHERE c.fecha_calc_dt = vsrc_calc_dt
        AND c.mes_id = vmes_id;

    COMMIT TRANSACTION;

    SET vupd_dec = TRUE;

  END IF;

  --- ============================================================
  --- PASO 3: TOTAL 
  --- ============================================================

  IF vupd_com OR vupd_dec THEN

    BEGIN TRANSACTION;

      DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_TOTAL`
      WHERE mes_factura_dt = vmes_factura_dt;

      INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_TOTAL`
      SELECT mes_factura_dt, "COMISION" AS clase, * EXCEPT(mes_factura_dt)
      FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES`
      WHERE importe IS NOT NULL
        AND mes_factura_dt = vmes_factura_dt

      UNION ALL

      SELECT mes_factura_dt, "DECOMISION" AS clase, * EXCEPT(mes_factura_dt)
      FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES`
      WHERE importe IS NOT NULL
        AND mes_factura_dt = vmes_factura_dt;

    COMMIT TRANSACTION;

  END IF;

END