BEGIN

  DECLARE prefijo, mes_string STRING;
  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo    = 'NENRG_';

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_sve_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  -- ── EUSKALTEL brand ──────────────────────────────────────────────────────
  SELECT
    id_mes_pr AS id_mes,
    prefijo||'BNSVE_'||mes_string||'_'||b.agrupacion_canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY b.agrupacion_canal ORDER BY A.cups_code) AS commission_id,
    m.marco_energia,
    B.agrupacion_canal,
    B.canaln AS canal,
    CAST(NULL AS STRING) AS cod_canal,
    B.agrupacion_canal AS canal_ds,
    B.canaln AS subcanal_ds,
    'B - SVE' AS concepto,
    'CSEN' AS tipo_concepto,
    1 AS unidades,
    m.comision AS comision,
    B.id_comisionista,
    B.distribuidor,
    B.id_comisionista AS sfid_id,
    UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller,
    B.nombre_comercio,
    B.razon_social,
    B.cif,
    B.zona_fiscal,
    UPPER(TRIM(tenant_code)) AS marca,
    'ENERGY' AS service_type,
    CAST(NULL AS STRING) AS phone_nm,
    CAST(NULL AS STRING) AS tariff_id,
    initial_lucera_tariff_name AS tariff_ds,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdServicioDesdeCUPSyFechaActivacion`(cups_code, activation_date) AS service_id,
    cups_code AS account_id,
    CAST(NULL AS STRING) AS customer_id,
    CAST(NULL AS STRING) AS line_type_ds,
    CAST(NULL AS STRING) AS bundle_type,
    CAST(NULL AS STRING) AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    activation_date AS sale_date,
    activation_date,
    A.churn_date AS deactivation_date,
    CAST(NULL AS STRING) AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '10' AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '014' AS cod_producto,
    CAST(NULL AS STRING) AS cod_marca,
    CAST(NULL AS STRING) AS claim_code,
    '' AS campaign_code,
    cups_code AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments,
    'C_MANUAL' AS facturador,
    'calculado' AS estado
  FROM `mm-new-business-reporting.ENERGY.SVE` A
  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` B
    ON A.sfid_id = B.sfid_id
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
    ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(b.agrupacion_canal))
    AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(b.subcanal_gekt))
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` m
    ON  UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(m.marco_energia))
    AND m.concepto = 'B - SVE'
  WHERE A.sfid_id IS NOT NULL
    AND A.product = 'SVE'
    AND DATE_TRUNC(DATE(A.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND UPPER(TRIM(tenant_code)) = 'EUSKALTEL'
    AND A.churn_date IS NULL
    AND A.state = 'activa'
    AND m.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC) = 1

  UNION ALL

  -- ── R brand ──────────────────────────────────────────────────────────────
  SELECT
    id_mes_pr AS id_mes,
    prefijo||'RNSVE_'||mes_string||'_'||b.agrupacion_canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY b.agrupacion_canal ORDER BY A.cups_code) AS commission_id,
    m.marco_energia,
    B.agrupacion_canal,
    B.canaln AS canal,
    CAST(NULL AS STRING) AS cod_canal,
    B.agrupacion_canal AS canal_ds,
    B.canaln AS subcanal_ds,
    'B - SVE' AS concepto,
    'CSEN' AS tipo_concepto,
    1 AS unidades,
    m.comision AS comision,
    B.id_comisionista,
    B.distribuidor,
    B.sfid_id,
    UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller,
    B.nombre_comercio,
    B.razon_social,
    B.cif,
    B.zona_fiscal,
    UPPER(TRIM(tenant_code)) AS marca,
    'ENERGY' AS service_type,
    CAST(NULL AS STRING) AS phone_nm,
    CAST(NULL AS STRING) AS tariff_id,
    initial_lucera_tariff_name AS tariff_ds,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdServicioDesdeCUPSyFechaActivacion`(cups_code, activation_date) AS service_id,
    cups_code AS account_id,
    CAST(NULL AS STRING) AS customer_id,
    CAST(NULL AS STRING) AS line_type_ds,
    CAST(NULL AS STRING) AS bundle_type,
    CAST(NULL AS STRING) AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    activation_date AS sale_date,
    activation_date,
    A.churn_date AS deactivation_date,
    CAST(NULL AS STRING) AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '10' AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '014' AS cod_producto,
    CAST(NULL AS STRING) AS cod_marca,
    CAST(NULL AS STRING) AS claim_code,
    '' AS campaign_code,
    cups_code AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments,
    'C_MANUAL' AS facturador,
    'calculado' AS estado
  FROM `mm-new-business-reporting.ENERGY.SVE` A
  LEFT JOIN (
    SELECT DISTINCT
      id_mes_pr,
      channel_ds    AS agrupacion_canal,
      subchannel_ds AS subcanal_gekt,
      CAST(sfid_id AS STRING) AS sfid_id,
      vertical_focus_ds AS id_comisionista,
      vertical_focus_ds AS nombre_comercio,
      distributor_ds    AS distribuidor,
      distributor_ds    AS razon_social,
      subchannel_ds     AS canaln,
      `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`('R', distributor_ds) AS cif,
      'PEN' AS zona_fiscal
    FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL`
  ) B ON A.sfid_id = B.sfid_id
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
    ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(b.agrupacion_canal))
    AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(b.subcanal_gekt))
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` m
    ON  UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(m.marco_energia))
    AND m.concepto = 'B - SVE'
  WHERE A.sfid_id IS NOT NULL
    AND A.product = 'SVE'
    AND DATE_TRUNC(DATE(A.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND UPPER(TRIM(tenant_code)) = 'R'
    AND A.churn_date IS NULL
    AND A.state = 'activa'
    AND m.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC) = 1;

END