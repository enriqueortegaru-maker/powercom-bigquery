BEGIN

-- ============================================================================
-- KRT_MASIVO — Decomisiones (Clawback) Procedures
-- Date  : 2026-08-31
-- Schema: mm-commissions-reporting.KRT_MASIVO
--
-- DELIVERS
--   1. pr_sb_creaTablaDecomisiones(vid_mes INT64)
--      Builds DECOMISIONES_BAJAS (7-day temp) → DECOMISIONES (permanent).
--   2. pr_fl_calcula_decomisiones(vid_mes INT64)
--      Thin wrapper — mirrors KRT_PYME pattern exactly.
--      fl_ejecutaFlujoComisiones line-11 CALL left commented; activation
--      into the live monthly flow is a separate, deliberate decision.
--
-- FUNCTIONAL TEMPLATE
--   Flow  : KRT_PYME.pr_sb_creaTablaDecomisiones  (structural reference)
--   Params: KRT_MASIVO.pr_sb_creaTablaComisiones   (authoritative join mechanics)
--
-- DIVERGENCES FROM PYME (naive port breaks on all four)
--   1. PARAM_KRT_MAS_CANALES keys on N0/N1 hierarchy — no master_channel_ds,
--      no subchannel_ds, no orden column. PYME join predicates do not translate.
--   2. MASIVO marco literals are FDV/PRESENCIAL/TELEVENTA/INBOUND+WEB OPERADOR/
--      MR Tiendas — the PYME -CR/-CP suffix convention does not exist.
--   3. PARAM_KRT_MAS_CATALOGOS requires 3-criterion resolution (PATRON/RANGO/
--      CATALOGO); PYME's catalog is a flat single-criterion lookup.
--   4. HISTORICO_COMISIONES.distribuidor is the canonical acreedor string
--      (tr.mo.nombre_acreedor_ds). DESACTIVACIONES_KRT.distribuidor is free
--      text: 12.5% divergent, measured 2026-08-31. The inner join on service_id
--      must use the same canonical form on both sides — identical to the defect
--      patched in pr_sb_creaTablaComisiones on 2026-08-31.
--
-- KNOWN OPEN ITEM — Class A2 catalog gap (business action required, not code)
--   PARAM_KRT_MAS_CONCEPTO holds 9 'activacion' tokens but only ONE
--   'desactivacion' row: Gama → E - Clawback Terminal movil.
--   Eight 'desactivacion' registrations are MISSING:
--     Fibra, Fijo, Linea, TV, Amazon, Netflix, Disney, Hbo Max.
--   HISTORICO_COMISIONES currently has zero DEVICE rows, so concepto = NULL
--   on 100% of output rows (verified 5/5 for mes_id 202608). The validation
--   gate surfaces this baseline. Never force-assign a concepto — quarantine
--   per CLAUDE.md §4 Class A2.
--
-- SCOPE: CRM-side only. SAP flat-file builders and PARAM_SAP_Z* schemas
--        remain untouched per CLAUDE.md §2 locked constraints.
-- ============================================================================


-- ============================================================================
-- PROCEDURE A — pr_sb_creaTablaDecomisiones
-- ============================================================================


  -- DECLARE vid_mes INT64; SET vid_mes = 202608;
  -- CALL `mm-commissions-reporting.KRT_MASIVO.pr_sb_creaTablaDecomisiones`(202608);

  -- ==========================================================================
  -- STEP 1 — DECOMISIONES_BAJAS
  -- Eligible bajas that originated from commissionable MASIVO activations.
  -- 7-day auto-expiry; rebuilt idempotently on each run.
  -- ==========================================================================
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.DECOMISIONES_BAJAS`
  OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY))
  AS

  WITH
  -- --------------------------------------------------------------------------
  -- Catalog CTEs — resolve tariff → concepto via 3-criterion priority
  -- (ported verbatim from pr_sb_creaTablaComisiones; only servicios_distintos
  -- swapped to DESACTIVACIONES_KRT as the deactivation source)
  -- --------------------------------------------------------------------------
  catalogo_patron AS (
    SELECT data_source_ds, brand_ds, service_type, tariff_id, objeto, concepto
    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CATALOGOS`
    WHERE criterio = 'PATRON'
  ),
  catalogo_rango AS (
    SELECT data_source_ds, brand_ds, service_type, tariff_id, minimo, maximo, concepto
    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CATALOGOS`
    WHERE criterio = 'RANGO'
  ),
  catalogo_exacto AS (
    SELECT data_source_ds, brand_ds, service_type, tariff_id, concepto
    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CATALOGOS`
    WHERE criterio = 'CATALOGO'
  ),
  servicios_distintos AS (
    SELECT DISTINCT data_source_ds, brand_ds, service_type, tariff_id, tariff_ds
    FROM `mm-commissions-reporting.COMISIONES.DESACTIVACIONES_KRT`
    WHERE id_mes = vid_mes
      AND NOT CONTAINS_SUBSTR(master_channel_ds, "EMPRESA")
      AND data_source_ds = "MYSIM"
  ),
  catalogo_resuelto AS (
    SELECT
      s.data_source_ds,
      s.brand_ds,
      s.service_type,
      s.tariff_id,
      s.tariff_ds,
      COALESCE(p.concepto, r.concepto, e.concepto) AS concepto,
      CASE
        WHEN p.concepto IS NOT NULL THEN CAST(1 AS INT64)
        WHEN r.concepto IS NOT NULL THEN CAST(3 AS INT64)
        WHEN e.concepto IS NOT NULL THEN CAST(5 AS INT64)
      END AS grid
    FROM servicios_distintos s
    LEFT JOIN catalogo_patron p
      ON  p.data_source_ds = s.data_source_ds
      AND p.brand_ds       = s.brand_ds
      AND p.service_type   = s.service_type
      AND STRPOS(
            REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(s.tariff_ds)), NFD), r"\pM|[^a-z0-9]", ""),
            REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(p.objeto)),    NFD), r"\pM|[^a-z0-9]", "")
          ) > 0
    LEFT JOIN catalogo_rango r
      ON  r.data_source_ds = s.data_source_ds
      AND r.brand_ds       = s.brand_ds
      AND r.service_type   = s.service_type
      AND p.concepto IS NULL
      AND (
        CASE
          WHEN s.service_type = 'BROADBAND' THEN
            CASE
              WHEN CONTAINS_SUBSTR(s.tariff_ds, '1GBPS')   THEN 1000
              WHEN CONTAINS_SUBSTR(s.tariff_ds, '500MBPS') THEN 500
            END
          WHEN s.service_type = 'MOBILE' THEN
            CASE
              WHEN CONTAINS_SUBSTR(s.tariff_ds, 'INFINITY')
                OR CONTAINS_SUBSTR(s.tariff_ds, 'GB ILIM')
                OR CONTAINS_SUBSTR(s.tariff_ds, 'GBILIM') THEN 999999
              WHEN CONTAINS_SUBSTR(s.tariff_ds, '50GB')   THEN 50000
            END
        END
      ) BETWEEN r.minimo AND r.maximo
    LEFT JOIN catalogo_exacto e
      ON  e.data_source_ds = s.data_source_ds
      AND e.brand_ds       = s.brand_ds
      AND e.service_type   = s.service_type
      AND e.tariff_id      = s.tariff_id
      AND p.concepto IS NULL
      AND r.concepto IS NULL
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY s.data_source_ds, s.brand_ds, s.service_type, s.tariff_id, s.tariff_ds
      ORDER BY
        CASE WHEN p.concepto IS NOT NULL THEN 1
             WHEN r.concepto IS NOT NULL THEN 2
             ELSE 3 END,
        p.concepto, r.concepto, e.concepto
    ) = 1
  )

  -- --------------------------------------------------------------------------
  -- BRANCH 1 — SERVICE (telco lines: MOBILE / BROADBAND / FIX / TV / OTT)
  -- Source: COMISIONES.DESACTIVACIONES_KRT
  -- Filter: MYSIM scope, non-EMPRESA, activated before vid_mes, age < 365 days.
  --
  -- SPEC CHANGES vs PYME
  --   channel filter : NOT CONTAINS_SUBSTR(master_channel_ds, "EMPRESA")
  --                    (PYME filters FOR EMPRESA; MASIVO excludes it)
  --   comisiona      : CAST(a.comisiona AS INT64) from source directly
  --                    (PYME calls f_com_excluir_seller; function absent in KRT_MASIVO)
  --   distribuidor   : tr.mo.nombre_acreedor_ds (canonical acreedor)
  --                    (required so the HISTORICO inner join resolves correctly;
  --                     free-text a.distribuidor is 12.5% divergent — measured)
  -- --------------------------------------------------------------------------
  SELECT DISTINCT
    vid_mes                                                                          AS mes_id,
    a.data_source_ds,
    a.brand_ds,
    a.channel_segment_ds,
    a.channel_type_ds,
    a.master_channel_ds,
    a.channel_ds,
    a.subchannel_ds,
    a.agrupacion_canal_ventas_base,
    a.agrupacion_canal,
    a.canal,
    -- Canonical acreedor — same form stored in HISTORICO_COMISIONES.distribuidor
    tr.mo.nombre_acreedor_ds                                                         AS distribuidor,
    a.id_comisionista,
    a.nombre_comercio,
    a.user_store,
    a.sfid_id,
    a.service_type,
    a.technology_ds,
    a.tariff_id,
    a.tariff_ds,
    a.segment_ds,
    a.sub_segment_ds,
    a.customer_id,
    a.contract_id,
    a.account_id,
    a.hash_document_number,
    a.province,
    a.zip_code,
    a.line_type_ds,
    a.service_id,
    a.service_id                                                                     AS id,
    CAST(NULL AS STRING)                                                             AS id_subscription_terminal,
    CAST(NULL AS STRING)                                                             AS terminal_model,
    CAST(NULL AS FLOAT64)                                                            AS total_pay_value_without_vat,
    CAST(NULL AS FLOAT64)                                                            AS total_pay_value,
    a.phone_nm,
    a.sell_type,
    a.bundle_type,
    a.order_type_agg,
    a.flag_order,
    a.order_fix_id,
    a.order_id,
    a.campaign_code,
    m.tipo,
    "BAJA"                                                                           AS operacion,
    a.seller,
    a.creado,
    a.creado_por,
    a.port_in_operator_ds,
    a.portability_group_donor,
    a.portability_operator_donor,
    -- Spec change: sourced from DESACTIVACIONES_KRT.comisiona (BOOL → INT64 cast).
    CAST(a.comisiona AS INT64)                                                       AS comisiona,
    -- concepto_marco: analytical column for standalone BAJAS queries;
    -- DECOMISIONES uses c.concepto_marco from HISTORICO, not this field.
    `mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(
      ct.concepto, a.service_type, a.line_type_ds, a.order_type_agg)               AS concepto_marco,
    ca.marco,
    ca.grupo_rappel,
    ma.importe,
    -- DATE → DATETIME cast: HISTORICO carries DATETIME; source has DATE.
    CAST(a.sale_date AS DATETIME)                                                    AS sale_date,
    a.cancellation_day_id,
    CAST(a.activation_date AS DATETIME)                                              AS activation_date,
    a.deactivation_date,
    a.deactivation_reason_ds

  FROM `mm-commissions-reporting.COMISIONES.DESACTIVACIONES_KRT` a
  -- tr provides the canonical acreedor string and the N0/N1 keys needed for
  -- PARAM_KRT_MAS_CANALES. SELECT DISTINCT is load-bearing: tr fans out ~1.23×.
  INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` tr
    ON tr.mo.sfid = a.sfid_id
  INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_MARCA_CARTERA` m
    USING (data_source_ds, sell_type, order_type_agg)
  LEFT JOIN catalogo_resuelto ct
    USING (data_source_ds, brand_ds, service_type, tariff_id, tariff_ds)
  -- N0/N1 hierarchy join — MASIVO-specific; no master_channel_ds/subchannel_ds here.
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CANALES` ca
    ON  UPPER(TRIM(ca.brand_ds)) = UPPER(TRIM(a.brand_ds))
    AND UPPER(TRIM(ca.N1))       = UPPER(TRIM(tr.mo.N1))
    AND UPPER(TRIM(ca.N0))       = UPPER(TRIM(tr.mo.N0))
    AND UPPER(TRIM(ca.tipo))     = UPPER(TRIM(m.tipo))
    -- Distribuidor wildcard: use canonical acreedor (patch pattern from 2026-08-31)
    AND CASE WHEN UPPER(TRIM(ca.distribuidor)) = 'X'
               OR UPPER(TRIM(tr.mo.nombre_acreedor_ds)) = UPPER(TRIM(ca.distribuidor))
             THEN TRUE ELSE FALSE END
    AND CASE WHEN UPPER(TRIM(ca.sfid)) = 'X'
               OR UPPER(TRIM(a.sfid_id)) = UPPER(TRIM(ca.sfid))
             THEN TRUE ELSE FALSE END
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_MARCO` ma
    ON  ma.tipo     = m.tipo
    AND ma.marca    = ca.brand_ds
    AND ma.marco    = ca.marco
    AND ma.concepto = `mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(
                        ct.concepto, a.service_type, a.line_type_ds, a.order_type_agg)

  WHERE a.id_mes = vid_mes
    AND NOT CONTAINS_SUBSTR(a.master_channel_ds, "EMPRESA")  -- MASIVO scope: exclude EMPRESA
    AND a.data_source_ds = "MYSIM"
    AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.activation_date, DATE '2099-12-31')) AS INT64) < vid_mes
    AND DATE_DIFF(
          COALESCE(a.deactivation_date, DATE '2099-12-31'),
          COALESCE(a.activation_date,   DATE '2099-12-31'),
          DAY) < 365
    AND m.comisiona = 1   -- eligibility filter from PARAM_KRT_MAS_MARCA_CARTERA
                          -- (distinct from the comisiona output column)

  UNION ALL

  -- --------------------------------------------------------------------------
  -- BRANCH 2 — DEVICE (terminal clawbacks — MYSIM scope)
  -- DORMANT / PREVENTIVE
  --   DEVICE_BASE_KRT holds 0 deactivations today (0 of 19,326 rows, 2026-08-31).
  --   HISTORICO_COMISIONES holds 0 DEVICE rows.
  --   Branch produces 0 rows by design until device sales go live.
  --   The single existing 'desactivacion' catalog entry (Gama → E - Clawback
  --   Terminal movil) is specifically registered for this branch.
  -- PENDIENTE: validate and activate importe join (PARAM_KRT_MAS_MARCO) once
  --   device deactivations enter scope. Current importe is 0 as a placeholder.
  -- --------------------------------------------------------------------------
  SELECT DISTINCT
    vid_mes                                                                          AS mes_id,
    CASE WHEN a.brand_ds = 'R' THEN 'R' ELSE 'EKTNET' END                          AS data_source_ds,
    a.brand_ds,
    a.channel_segment_ds,
    a.channel_type_ds,
    a.master_channel_ds,
    a.channel_ds,
    a.subchannel_ds,
    CAST(NULL AS STRING)                                                             AS agrupacion_canal_ventas_base,
    a.agrupacion_canal,
    a.canal,
    tr.mo.nombre_acreedor_ds                                                         AS distribuidor,
    CAST(NULL AS INT64)                                                              AS id_comisionista,
    a.nombre_comercio,
    a.user_store,
    a.sfid_id,
    'DEVICE'                                                                         AS service_type,
    a.technology_ds,
    a.tariff_id,
    a.tariff_ds,
    a.segment_ds,
    CAST(NULL AS STRING)                                                             AS sub_segment_ds,
    a.customer_id,
    a.contract_id,
    a.account_id,
    v.hash_document_number,
    v.province,
    v.zip_code,
    a.line_type_ds,
    a.service_id,
    a.id_subscription_terminal                                                       AS id,
    a.id_subscription_terminal,
    a.terminal_name                                                                  AS terminal_model,
    a.total_pay_value_without_vat,
    a.total_pay_value,
    CAST(a.phone_nm AS STRING)                                                       AS phone_nm,
    v.sell_type,
    a.bundle_type,
    a.order_type_agg,
    v.flag_order,
    v.order_fix_id,
    a.order_id,
    CAST(NULL AS STRING)                                                             AS campaign_code,
    CASE WHEN COALESCE(v.sell_type, "NOINF") = "NEW SALE"
         THEN "CAPTACION" ELSE "CARTERA" END                                         AS tipo,
    "BAJA"                                                                           AS operacion,
    a.seller,
    CAST(NULL AS STRING)                                                             AS creado,
    CAST(NULL AS STRING)                                                             AS creado_por,
    v.port_in_operator_ds,
    v.portability_group_donor,
    v.portability_operator_donor,
    1                                                                                AS comisiona,
    g.gama                                                                           AS concepto_marco,
    ca.marco,
    ca.grupo_rappel,
    CAST(0 AS FLOAT64)                                                               AS importe,
    CAST(a.order_date AS DATETIME)                                                   AS sale_date,
    CAST(NULL AS DATE)                                                               AS cancellation_day_id,
    a.activation_date,
    a.deactivation_date,
    v.deactivation_reason_ds

  FROM `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT` a
  LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` tr
    ON tr.mo.sfid = a.sfid_id
  LEFT JOIN `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` v
    ON  v.data_source_ds    = a.data_source
    AND v.brand_ds          = a.brand_ds
    AND v.service_id        = a.service_id
    AND v.id_mes_activacion = vid_mes
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CANALES` ca
    ON  UPPER(TRIM(ca.brand_ds)) = UPPER(TRIM(a.brand_ds))
    AND UPPER(TRIM(ca.N1))       = UPPER(TRIM(tr.mo.N1))
    AND UPPER(TRIM(ca.N0))       = UPPER(TRIM(tr.mo.N0))
    AND UPPER(TRIM(ca.tipo))     = CASE WHEN COALESCE(v.sell_type, "NOINF") = "NEW SALE"
                                        THEN "CAPTACION" ELSE "CARTERA" END
    -- Preventive: same canonical distribuidor predicate as Branch 1
    AND CASE WHEN UPPER(TRIM(ca.distribuidor)) = 'X'
               OR UPPER(TRIM(tr.mo.nombre_acreedor_ds)) = UPPER(TRIM(ca.distribuidor))
             THEN TRUE ELSE FALSE END
    AND CASE WHEN UPPER(TRIM(ca.sfid)) = 'X'
               OR UPPER(TRIM(a.sfid_id)) = UPPER(TRIM(ca.sfid))
             THEN TRUE ELSE FALSE END
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_GAMA_TERMINAL` g
    ON COALESCE(a.total_pay_value_without_vat, (a.total_pay_value / 1.21))
       BETWEEN g.minimo AND g.maximo

  WHERE CAST(FORMAT_DATE('%Y%m', a.deactivation_date) AS INT64) = vid_mes
    AND NOT CONTAINS_SUBSTR(a.master_channel_ds, "EMPRESA")
    AND data_source_ds = "MYSIM"  -- unqualified: resolves via SELECT alias (matches pr_sb_creaTablaComisiones)

  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CASE WHEN a.brand_ds = 'R' THEN 'R' ELSE 'EKTNET' END,
                 a.brand_ds,
                 a.id_subscription_terminal
    ORDER BY a.order_date DESC
  ) = 1;


  -- ==========================================================================
  -- STEP 2 — DECOMISIONES
  -- Clawback commission entries: HISTORICO rows matched to eligible bajas,
  -- penalized by tramo and assigned a SAP concepto (desactivacion).
  -- All 70 HISTORICO_COMISIONES attributes are projected with targeted overrides.
  -- ==========================================================================
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.DECOMISIONES` AS

  SELECT
/*    -- ---- billing / audit (carried from HISTORICO unchanged) ----
    c.mes_factura_dt,
    c.commission_id,
    c.id_registro,
    c.invoice_id,
    c.estado,
    c.fecha_calc_dt,
  */  -- ---- override: clawback billing month ----
    vid_mes                                                                          AS mes_id,
    -- ---- channel ----
    c.data_source_ds,
    c.brand_ds,
    c.channel_segment_ds,
    c.channel_type_ds,
    c.master_channel_ds,
    c.channel_ds,
    c.subchannel_ds,
    c.agrupacion_canal_ventas_base,
    c.agrupacion_canal,
    c.canal,
    c.distribuidor,
    c.id_comisionista,
    c.nombre_comercio,
    c.user_store,
    c.sfid_id,
    -- ---- product ----
    c.service_type,
    c.technology_ds,
    c.tariff_id,
    c.tariff_ds,
    c.segment_ds,
    c.sub_segment_ds,
    -- ---- customer ----
    c.customer_id,
    c.contract_id,
    c.account_id,
    c.hash_document_number,
    c.province,
    c.zip_code,
    c.line_type_ds,
    c.service_id,
    c.id,
    c.id_subscription_terminal,
    c.terminal_model,
    c.total_pay_value_without_vat,
    c.total_pay_value,
    c.phone_nm,
    -- ---- transaction ----
    c.sell_type,
    c.bundle_type,
    c.order_type_agg,
    c.flag_order,
    c.order_fix_id,
    c.order_id,
    c.campaign_code,
    c.tipo,
    -- ---- override: operation type ----
    "BAJA"                                                                           AS operacion,
    c.seller,
    c.creado,
    c.creado_por,
    c.port_in_operator_ds,
    c.portability_group_donor,
    c.portability_operator_donor,
    -- ---- override: comisiona flag from the baja record ----
    b.comisiona,
    -- ---- classification ----
    c.concepto_marco,
    -- ---- override: SAP clawback concepto via PARAM_KRT_MAS_CONCEPTO
    --   Match: STRPOS(normalized concepto_marco, normalized catalog key) > 0
    --          AND operacion = 'desactivacion'.
    --   KNOWN BASELINE: concepto = NULL on 100% of current rows.
    --   Root cause: 8 'desactivacion' registrations missing from catalog
    --   (Fibra / Fijo / Linea / TV / Amazon / Netflix / Disney / Hbo Max).
    --   This is a Class A2 catalog-completeness gap per CLAUDE.md §4 — the
    --   validation gate below surfaces the count. Business must register the
    --   missing entries; never force-assign a literal. ----
    co.concepto,
    c.marco,
    c.grupo_rappel,
    c.orden,
    -- ---- override: clawback amount (sign-negated, tramo-penalized) ----
    SAFE_NEGATE(SAFE_MULTIPLY(c.importe, p.penalizacion))                            AS importe,
    -- ---- dates ----
    c.sale_date,
    c.cancellation_day_id,
    c.activation_date,
    -- ---- override: deactivation date from the baja event ----
    b.deactivation_date,
    c.deactivation_reason_ds,
    c.grid

  FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_COMISIONES` c

  -- Inner join: only HISTORICO rows with a matching eligible baja become clawbacks.
  -- Join key includes distribuidor (canonical form on both sides — ensured in Step 1).
  INNER JOIN `mm-commissions-reporting.KRT_MASIVO.DECOMISIONES_BAJAS` b
    USING (data_source_ds, brand_ds, channel_ds, subchannel_ds,
           distribuidor, sfid_id, service_type, tariff_id, service_id)

  -- Tramo: penalty coefficient indexed by months between activation and deactivation.
  INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_TRAMOS_DECOMISION` p
    ON p.nmeses = DATE_DIFF(
                    DATE_TRUNC(b.deactivation_date,           MONTH),
                    DATE_TRUNC(DATE(b.activation_date), MONTH),
                    MONTH)

  -- Concepto: accent-normalized substring match (consistent with the activacion
  -- branch in pr_sb_creaTablaComisiones; MASIVO concepto_marco contains accented
  -- chars — e.g. "línea móvil MAMBO AXIÑA", "ilimitado ó 50 GB.").
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CONCEPTO` co
    ON STRPOS(
         REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(c.concepto_marco)), NFD), r"\pM", ""),
         REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(co.concepto_marco)), NFD), r"\pM", "")
       ) > 0
   AND LOWER(TRIM(co.operacion)) = "desactivacion"

  -- Only clawback bajas posterior to marco retributivo implantation (per PYME precedent)
  WHERE DATE(b.activation_date) >= "2026-07-01";


  -- ==========================================================================
  -- VALIDATION GATE — CLAUDE.md §3 control pattern
  -- Surface null concepto / importe counts immediately after each rebuild
  -- so regressions are visible before downstream consumers run.
  -- Expected baseline for 202608:
  --   null_concepto_count  = total_rows (100% — Class A2 gap, 8 missing tokens)
  --   null_importe_count   = 0
  --   total_rows           = 5
  -- Promote COUNTIF(concepto IS NULL) to RAISE USING MESSAGE once the 8
  -- missing 'desactivacion' registrations are formally agreed and registered.
  -- ==========================================================================
  SELECT
    COUNTIF(concepto IS NULL)                                      AS null_concepto_count,
    COUNTIF(importe  IS NULL AND comisiona = 1)                    AS null_importe_comisionable,
    COUNT(*)                                                       AS total_rows,
    ROUND(
      COUNTIF(concepto IS NULL) / NULLIF(COUNT(*), 0) * 100,
      2)                                                           AS pct_null_concepto
  FROM `mm-commissions-reporting.KRT_MASIVO.DECOMISIONES`
  WHERE mes_id = vid_mes;

END