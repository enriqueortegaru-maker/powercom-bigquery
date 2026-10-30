BEGIN

  DECLARE prefijo, mes_string STRING;
  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo    = 'NENRG_';

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_GAS_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  -- ── EUSKALTEL brand ──────────────────────────────────────────────────────
  SELECT
    id_mes_pr AS id_mes,
    prefijo||'BNGAS_'||mes_string||'_'||b.agrupacion_canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY b.agrupacion_canal ORDER BY A.cups_code) AS commission_id,
    c.marco_energia,
    B.agrupacion_canal,
    B.canaln AS canal,
    CAST(NULL AS STRING) AS cod_canal,
    B.agrupacion_canal AS canal_ds,
    B.canaln AS subcanal_ds,
    'B - Gas' AS concepto,
    'CSEN' AS tipo_concepto,
    1 AS unidades,
    c.comision AS comision,
    b.id_comisionista,
    b.distribuidor,
    b.id_comisionista AS sfid_id,
    UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller,
    b.nombre_comercio,
    b.razon_social,
    b.cif,
    b.zona_fiscal,
    'EUSKALTEL' AS marca,
    'ENERGY' AS service_type,
    CAST(phone AS STRING) AS phone_nm,
    CAST(NULL AS STRING) AS tariff_id,
    initial_lucera_tariff_name AS tariff_ds,
    CAST(id AS STRING) AS service_id,
    cups_code AS account_id,
    CAST(NULL AS STRING) AS customer_id,
    CAST(NULL AS STRING) AS line_type_ds,
    CAST(NULL AS STRING) AS bundle_type,
    CAST(NULL AS STRING) AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    signup_date AS sale_date,
    activation_date,
    churn_date AS deactivation_date,
    CAST(NULL AS STRING) AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '10' AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '014' AS cod_producto,
    CAST(NULL AS STRING) AS cod_marca,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS campaign_code,
    cups_code AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments,
    'C_MANUAL' AS facturador,
    'calculado' AS estado
  FROM `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` B
    ON A.sfid_id = B.sfid_id
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
    ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(b.agrupacion_canal))
    AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(b.subcanal_gekt))
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` c
    ON  UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(c.marco_energia))
    AND c.concepto = 'B - Gas'
  WHERE DATE_TRUNC(DATE(activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND UPPER(TRIM(tenant_code)) = 'EUSKALTEL'
    AND A.sfid_id IS NOT NULL
    AND state = 'activa'
    AND channel_ds NOT IN ('PENDIENTE DEFINIR', 'PLAT. FIDELIZACION/RETENCION', 'CANCELACIONES')
    AND c.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC) = 1

  UNION ALL

  -- ── R brand ──────────────────────────────────────────────────────────────
  SELECT
    id_mes_pr AS id_mes,
    prefijo||'RNGAS_'||mes_string||'_'||b.agrupacion_canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY b.agrupacion_canal ORDER BY A.cups_code) AS commission_id,
    c.marco_energia,
    B.agrupacion_canal,
    B.canaln AS canal,
    CAST(NULL AS STRING) AS cod_canal,
    B.agrupacion_canal AS canal_ds,
    B.canaln AS subcanal_ds,
    'B - Gas' AS concepto,
    'CSEN' AS tipo_concepto,
    1 AS unidades,
    c.comision AS comision,
    b.id_comisionista,
    b.distribuidor,
    b.sfid_id,
    UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller,
    b.nombre_comercio,
    b.razon_social,
    b.cif,
    b.zona_fiscal,
    'R' AS marca,
    'ENERGY' AS service_type,
    CAST(phone AS STRING) AS phone_nm,
    CAST(NULL AS STRING) AS tariff_id,
    initial_lucera_tariff_name AS tariff_ds,
    CAST(id AS STRING) AS service_id,
    cups_code AS account_id,
    CAST(NULL AS STRING) AS customer_id,
    CAST(NULL AS STRING) AS line_type_ds,
    CAST(NULL AS STRING) AS bundle_type,
    CAST(NULL AS STRING) AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    signup_date AS sale_date,
    activation_date,
    churn_date AS deactivation_date,
    CAST(NULL AS STRING) AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '10' AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '014' AS cod_producto,
    CAST(NULL AS STRING) AS cod_marca,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS campaign_code,
    cups_code AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments,
    'C_MANUAL' AS facturador,
    'calculado' AS estado
  FROM `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
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
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` c
    ON  UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(c.marco_energia))
    AND c.concepto = 'B - Gas'
  WHERE DATE_TRUNC(DATE(activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND UPPER(TRIM(tenant_code)) = 'R'
    AND A.sfid_id IS NOT NULL
    AND state = 'activa'
    AND channel_ds NOT IN ('PENDIENTE DEFINIR', 'PLAT. FIDELIZACION/RETENCION', 'CANCELACIONES')
    AND c.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC) = 1;

END