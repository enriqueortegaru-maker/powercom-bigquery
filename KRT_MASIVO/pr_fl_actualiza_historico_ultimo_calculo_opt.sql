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
    FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES_OPT`
    WHERE mes_factura_dt = vmes_factura_dt
  );

  IF vsrc_calc_dt IS NOT NULL
     AND (vtgt_calc_dt IS NULL OR vsrc_calc_dt > vtgt_calc_dt)
  THEN

    BEGIN TRANSACTION;

      DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES_OPT`
      WHERE mes_factura_dt = vmes_factura_dt;

      INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES_OPT`
      WITH base AS (
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
          AND c.mes_id = vmes_id
      ),
      k AS (
        SELECT b.*,
          `mm-commissions-reporting.KRT_MIG_PWC.f_cid_raiz`(
            b.brand_ds, "comision", b.tipo, b.mes_factura_dt,
            `mm-commissions-reporting.KRT_MIG_PWC.f_cid_origen`('M', b.data_source_ds, b.service_type),
            `mm-commissions-reporting.KRT_MIG_PWC.f_cid_desc`(b.concepto)
          ) AS __cid_raiz,
          `mm-commissions-reporting.KRT_MIG_PWC.f_cid_hex6`(b.service_id, b.importe) AS __cid_hex6
        FROM base b
      ),
      n AS (
        SELECT k.*,
          ROW_NUMBER() OVER (
            PARTITION BY __cid_raiz, __cid_hex6
            ORDER BY data_source_ds, id, orden, marco, concepto, concepto_marco, tipo, operacion, customer_id,
                     service_id, tariff_id, sale_date, activation_date, deactivation_date, importe, distribuidor,
                     sfid_id, seller, channel_ds, subchannel_ds, grupo_rappel
          ) AS __cid_nn
        FROM k
      )
      SELECT * EXCEPT(__cid_raiz, __cid_hex6, __cid_nn) REPLACE(
        IF(mes_factura_dt >= `mm-commissions-reporting.KRT_MIG_PWC.f_cid_mes_inicio`(),
           `mm-commissions-reporting.KRT_MIG_PWC.f_cid_compone`(__cid_raiz, __cid_hex6, __cid_nn),
           commission_id
        ) AS commission_id
      )
      FROM n;

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
    FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES_OPT`
    WHERE mes_factura_dt = vmes_factura_dt
  );

  IF vsrc_calc_dt IS NOT NULL
     AND (vtgt_calc_dt IS NULL OR vsrc_calc_dt > vtgt_calc_dt)
  THEN

    BEGIN TRANSACTION;

      DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES_OPT`
      WHERE mes_factura_dt = vmes_factura_dt;

      INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES_OPT`
      WITH base AS (
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
          AND c.mes_id = vmes_id
      ),
      k AS (
        SELECT b.*,
          `mm-commissions-reporting.KRT_MIG_PWC.f_cid_raiz`(
            b.brand_ds, "decomision", b.tipo, b.mes_factura_dt,
            `mm-commissions-reporting.KRT_MIG_PWC.f_cid_origen`('M', b.data_source_ds, b.service_type),
            `mm-commissions-reporting.KRT_MIG_PWC.f_cid_desc`(b.concepto)
          ) AS __cid_raiz,
          `mm-commissions-reporting.KRT_MIG_PWC.f_cid_hex6`(b.service_id, b.importe) AS __cid_hex6
        FROM base b
      ),
      n AS (
        SELECT k.*,
          ROW_NUMBER() OVER (
            PARTITION BY __cid_raiz, __cid_hex6
            ORDER BY data_source_ds, id, orden, marco, concepto, concepto_marco, tipo, operacion, customer_id,
                     service_id, tariff_id, sale_date, activation_date, deactivation_date, importe, distribuidor,
                     sfid_id, seller, channel_ds, subchannel_ds, grupo_rappel
          ) AS __cid_nn
        FROM k
      )
      SELECT * EXCEPT(__cid_raiz, __cid_hex6, __cid_nn) REPLACE(
        IF(mes_factura_dt >= `mm-commissions-reporting.KRT_MIG_PWC.f_cid_mes_inicio`(),
           `mm-commissions-reporting.KRT_MIG_PWC.f_cid_compone`(__cid_raiz, __cid_hex6, __cid_nn),
           commission_id
        ) AS commission_id
      )
      FROM n;

    COMMIT TRANSACTION;

    SET vupd_dec = TRUE;

  END IF;

  --- ============================================================
  --- PASO 3: TOTAL
  --- ============================================================

  IF vupd_com OR vupd_dec THEN

    BEGIN TRANSACTION;

      DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_TOTAL_OPT`
      WHERE mes_factura_dt = vmes_factura_dt;

      INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_TOTAL_OPT`
      SELECT mes_factura_dt, "COMISION" AS clase, * EXCEPT(mes_factura_dt)
      FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_COMISIONES_OPT`
      WHERE importe IS NOT NULL
        AND mes_factura_dt = vmes_factura_dt

      UNION ALL

      SELECT mes_factura_dt, "DECOMISION" AS clase, * EXCEPT(mes_factura_dt)
      FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_DECOMISIONES_OPT`
      WHERE importe IS NOT NULL
        AND mes_factura_dt = vmes_factura_dt;

    COMMIT TRANSACTION;

  END IF;

END