BEGIN

  -- -------------------------------------------------------------------------
  -- 0. Declarations
  -- -------------------------------------------------------------------------
  DECLARE d_tr     DATE;
  DECLARE d_cierre DATE;
  DECLARE d_calc   DATE;

  DECLARE audit_table_ref STRING
    DEFAULT '`mm-commissions-reporting.KRT_SAP.AUDIT_PRECIERRE_LISTADO_ORDENES`';

  DECLARE query_build   STRING;
  DECLARE query_metrics STRING;

  -- -------------------------------------------------------------------------
  -- 1. Parse dates once in procedural scope (validates bad input early)
  -- -------------------------------------------------------------------------
  SET d_tr     = PARSE_DATE('%Y%m%d', CAST(VDESDE_TR     AS STRING));
  SET d_cierre = PARSE_DATE('%Y%m%d', CAST(VDESDE_CIERRE AS STRING));
  SET d_calc   = PARSE_DATE('%Y%m%d', CAST(VDIA_CIERRE   AS STRING));

  -- -------------------------------------------------------------------------
  -- 2. Build the audit table
  --    Dates are inlined as literals via %t so partition pruning fires on
  --    both TRANSACCIONES (partitioned on mes_factura_dt) and
  --    AGG_SAP_KPI_CIERRE (partitioned on fecha_calc_dt).
  -- -------------------------------------------------------------------------
  SET query_build = FORMAT("""
    CREATE OR REPLACE TABLE %s
    OPTIONS (
      expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY),
      description          = 'Auditoría precierre de comisiones por orden. Expira en 7 días.'
    ) AS
    WITH tr AS (
      SELECT
        sociedad,
        marca,
        orden,
        SUM(comision) AS comision
      FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
      WHERE mes_factura_dt              = DATE '%t'
        AND COALESCE(comision, 0.0)    != 0.0
      GROUP BY sociedad, marca, orden
    ),

    ci AS (
      SELECT
        sociedad,
        marca,
        orden,
        SUM(comision_est) AS comision_est
      FROM `mm-commissions-reporting.KRT_SAP.AGG_SAP_KPI_CIERRE`
      WHERE fecha_calc_dt               = DATE '%t'
        AND mes_factura_dt              = DATE '%t'
        AND COALESCE(comision_est, 0.0) != 0.0
      GROUP BY sociedad, marca, orden
    )

    SELECT
      COALESCE(tr.sociedad, ci.sociedad) AS sociedad,
      COALESCE(tr.marca,    ci.marca)    AS marca,
      COALESCE(tr.orden,    ci.orden)    AS orden,
      tr.comision,
      ci.comision_est,
      CASE
        WHEN ci.comision_est IS NULL
          THEN 'SOLO EN TRANSACCIONES'
        WHEN tr.comision IS NULL
          THEN 'SOLO EN CIERRE'
        WHEN ROUND(tr.comision, 2) = ROUND(ci.comision_est, 2)
          THEN 'COINCIDE'
        ELSE
          'DESVIACION'
      END AS causa
    FROM tr
    FULL OUTER JOIN ci
      ON  tr.sociedad = ci.sociedad
      AND tr.marca    = ci.marca
      AND tr.orden    = ci.orden
  """,
    audit_table_ref,
    d_tr,     -- %t → mes_factura_dt filter for TRANSACCIONES
    d_calc,   -- %t → fecha_calc_dt  filter for AGG_SAP_KPI_CIERRE (partition key)
    d_cierre  -- %t → mes_factura_dt filter for AGG_SAP_KPI_CIERRE
  );

  EXECUTE IMMEDIATE query_build;

  -- -------------------------------------------------------------------------
  -- 3. Metrics summary — single pass over the ~250-row audit table
  --    (mirrors the concepto/total_registros_A/B/solo_en_A/B/en_ambas schema
  --     of KRT_MIG_PWC.audit_compare_tables, result set 1)
  -- -------------------------------------------------------------------------
  SET query_metrics = FORMAT("""
    SELECT
      CONCAT(
        'Auditoría Precierre  TR:%d  Cierre:%d  Día:%d'
      )                                                   AS concepto,
      COUNTIF(comision     IS NOT NULL)                   AS total_registros_A,
      COUNTIF(comision_est IS NOT NULL)                   AS total_registros_B,
      COUNTIF(causa = 'SOLO EN TRANSACCIONES')            AS solo_en_A,
      COUNTIF(causa = 'SOLO EN CIERRE')                   AS solo_en_B,
      COUNTIF(causa IN ('COINCIDE','DESVIACION'))         AS en_ambas_tablas,
      COUNTIF(causa = 'COINCIDE')                         AS coinciden,
      COUNTIF(causa = 'DESVIACION')                       AS con_desviacion
    FROM %s
  """,
    VDESDE_TR, VDESDE_CIERRE, VDIA_CIERRE,
    audit_table_ref
  );

  EXECUTE IMMEDIATE query_metrics;

  -- -------------------------------------------------------------------------
  -- 4. Detail — console view of the full audit table
  --    (mirrors result set 3 of KRT_MIG_PWC.audit_compare_tables)
  -- -------------------------------------------------------------------------
  EXECUTE IMMEDIATE FORMAT(
    'SELECT * FROM %s ORDER BY causa, sociedad, marca, orden',
    audit_table_ref
  );

END