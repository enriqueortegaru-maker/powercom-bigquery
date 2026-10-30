BEGIN

  DECLARE prefijo, mes_string STRING;
  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo    = 'NENRG_';

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_svg_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  -- ── EUSKALTEL brand ──────────────────────────────────────────────────────
  SELECT
    id_mes_pr AS id_mes,
    prefijo||'BNSVG_'||mes_string||'_'||C.agrupacion_canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY C.agrupacion_canal ORDER BY A.cups_code, CAST(A.id AS STRING)) AS commission_id,
    m.marco_energia,
    C.agrupacion_canal,
    C.canaln AS canal,
    CAST(NULL AS STRING) AS cod_canal,
    C.agrupacion_canal AS canal_ds,
    C.canaln AS subcanal_ds,
    'B - SVG' AS concepto,
    'CSEN' AS tipo_concepto,
    1 AS unidades,
    m.comision AS comision,
    C.id_comisionista,
    C.distribuidor,
    C.sfid_id,
    UPPER(SPLIT(A.author_id, "@")[OFFSET(0)]) AS seller,
    C.nombre_comercio,
    C.razon_social,
    C.cif,
    C.zona_fiscal,
    'EUSKALTEL' AS marca,
    'ENERGY' AS service_type,
    CAST(NULL AS STRING) AS phone_nm,
    CAST(NULL AS STRING) AS tariff_id,
    CAST(NULL AS STRING) AS tariff_ds,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdServicioDesdeCUPSyFechaActivacion`(cups_code, B.data_inici) AS service_id,
    A.cups_code AS account_id,
    CAST(NULL AS STRING) AS customer_id,
    CAST(NULL AS STRING) AS line_type_ds,
    CAST(NULL AS STRING) AS bundle_type,
    CAST(NULL AS STRING) AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    A.signup_date_altas AS sale_date,
    B.data_inici AS activation_date,
    B.data_fi AS deactivation_date,
    CAST(NULL AS STRING) AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '10' AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '014' AS cod_producto,
    CAST(NULL AS STRING) AS cod_marca,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS campaign_code,
    A.cups_code AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments,
    'C_MANUAL' AS facturador,
    'calculado' AS estado
  FROM `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
  INNER JOIN `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
    ON A.id = B.polissa_id
  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` C
    ON A.sfid_id = C.sfid_id
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
    ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(c.agrupacion_canal))
    AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(c.subcanal_gekt))
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` m
    ON  UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(m.marco_energia))
    AND m.concepto = 'B - SVG'
  WHERE DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND A.product = 'SVG'
    AND UPPER(TRIM(A.tenant_code)) = 'EUSKALTEL_SVG'
    AND A.subchannel_ds NOT IN ('PENDIENTE DEFINIR', 'PLAT. FIDELIZACION/RETENCION', 'CANCELACIONES')
    AND A.sfid_id IS NOT NULL
    AND A.state = 'activa'
    AND m.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC) = 1

  UNION ALL

  -- ── R brand ──────────────────────────────────────────────────────────────
  SELECT
    id_mes_pr AS id_mes,
    prefijo||'RNSVG_'||mes_string||'_'||C.agrupacion_canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY C.agrupacion_canal ORDER BY A.cups_code, CAST(A.id AS STRING)) AS commission_id,
    m.marco_energia,
    C.agrupacion_canal,
    C.canaln AS canal,
    CAST(NULL AS STRING) AS cod_canal,
    C.agrupacion_canal AS canal_ds,
    C.canaln AS subcanal_ds,
    'B - SVG' AS concepto,
    'CSEN' AS tipo_concepto,
    1 AS unidades,
    m.comision AS comision,
    C.id_comisionista,
    C.distribuidor,
    C.sfid_id,
    UPPER(SPLIT(A.author_id, "@")[OFFSET(0)]) AS seller,
    C.nombre_comercio,
    C.razon_social,
    C.cif,
    C.zona_fiscal,
    'R' AS marca,
    'ENERGY' AS service_type,
    CAST(NULL AS STRING) AS phone_nm,
    CAST(NULL AS STRING) AS tariff_id,
    CAST(NULL AS STRING) AS tariff_ds,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdServicioDesdeCUPSyFechaActivacion`(cups_code, B.data_inici) AS service_id,
    A.cups_code AS account_id,
    CAST(NULL AS STRING) AS customer_id,
    CAST(NULL AS STRING) AS line_type_ds,
    CAST(NULL AS STRING) AS bundle_type,
    CAST(NULL AS STRING) AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    A.signup_date_altas AS sale_date,
    B.data_inici AS activation_date,
    B.data_fi AS deactivation_date,
    CAST(NULL AS STRING) AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '10' AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '014' AS cod_producto,
    CAST(NULL AS STRING) AS cod_marca,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS campaign_code,
    A.cups_code AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments,
    'C_MANUAL' AS facturador,
    'calculado' AS estado
  FROM `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
  INNER JOIN `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
    ON A.id = B.polissa_id
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
  ) C ON A.sfid_id = C.sfid_id
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
    ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(c.agrupacion_canal))
    AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(c.subcanal_gekt))
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` m
    ON  UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(m.marco_energia))
    AND m.concepto = 'B - SVG'
  WHERE DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND A.product = 'SVG'
    AND UPPER(TRIM(A.tenant_code)) = 'R_SVG'
    AND A.subchannel_ds NOT IN ('PENDIENTE DEFINIR', 'PLAT. FIDELIZACION/RETENCION', 'CANCELACIONES')
    AND A.sfid_id IS NOT NULL
    AND A.state = 'activa'
    AND m.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC) = 1;

END