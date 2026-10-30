BEGIN

  --- DECLARE id_mes_pr INT64 DEFAULT 202609;
  DECLARE prefijo, mes_string STRING;
  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo    = 'NENRG_';

  -- ── Stage 1: activations (EUSKALTEL + R, with concepto resolution) ──────

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_activations`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  (
    WITH CONCEPTOS AS (
      SELECT CONCEPTOS.* EXCEPT(proceso), proceso
      FROM `mm-commissions-reporting.KRT_MASIVO.CONCEPTOS` CONCEPTOS,
           UNNEST(SPLIT(proceso, ',')) proceso
    )

    -- ── EUSKALTEL brand ────────────────────────────────────────────────────
    SELECT
      prefijo||'BNEN_'||mes_string||'_'||DEALER.canaln||'_'||
        ROW_NUMBER() OVER (PARTITION BY DEALER.canaln ORDER BY LUCERA.cups_code) AS commission_id,
      'calculado' AS estado,
      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
      id_mes_pr AS id_mes,
      IMPORTE.marco_energia,
      DEALER.agrupacion_canal,
      DEALER.canaln AS canal,
      CONCEPTOS.concepto,
      CONCEPTOS.tipo_concepto,
      1 AS unidades,
      IMPORTE.comision,
      DEALER.id_comisionista,
      COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor,
      DEALER.sfid_id,
      UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller,
      DEALER.nombre_comercio,
      DEALER.razon_social,
      DEALER.cif,
      DEALER.zona_fiscal,
      'EUSKALTEL' AS marca,
      'ENERGY' AS service_type,
      CAST(LUCERA.phone AS STRING) AS phone_nm,
      CAST(NULL AS STRING) AS tariff_id,
      LUCERA.initial_lucera_tariff_name AS tariff_ds,
      CAST(LUCERA.id AS STRING) AS service_id,
      CAST(NULL AS STRING) AS account_id,
      CAST(NULL AS STRING) AS customer_id,
      CAST(NULL AS STRING) AS line_type_ds,
      CAST(NULL AS STRING) AS bundle_type,
      CAST(NULL AS STRING) AS technology_ds,
      CAST(NULL AS STRING) AS billing_type_ds,
      LUCERA.signup_date AS sale_date,
      LUCERA.activation_date,
      LUCERA.churn_date AS deactivation_date,
      CAST(NULL AS STRING) AS order_id,
      CAST(NULL AS STRING) AS order_type_agg,
      '10' AS cod_segmento,
      CAST(NULL AS STRING) AS cod_marca,
      '99' AS cod_tipo_contrato,
      '014' AS cod_producto,
      CAST(NULL AS STRING) AS cod_canal,
      CAST(NULL AS STRING) AS campaign_code,
      LUCERA.cups_code AS serial_number,
      CAST(NULL AS FLOAT64) AS tax_base,
      CAST(NULL AS STRING) AS claim_code,
      CAST(NULL AS STRING) AS process_code,
      CAST(NULL AS STRING) AS comments,
      'C_MANUAL' AS facturador,
      'X001' AS sociedad
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity` LUCERA
    LEFT JOIN CONCEPTOS
      ON  CONCEPTOS.proceso = 'ENRGN'
      AND SUBSTR(CONCEPTOS.concepto, 1, 1) = 'B'
      AND CASE
            WHEN (LUCERA.initial_lucera_tariff_name LIKE '%Batman%'
                  OR CONTAINS_SUBSTR(LUCERA.affiliate_code, 'batman'))
            THEN 'B - Energia Batman'
            ELSE 'B - Energia'
          END = CONCEPTOS.concepto
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` DEALER
      ON LUCERA.sfid_id = DEALER.sfid_id
    LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
      ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(DEALER.agrupacion_canal))
      AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(DEALER.canaln))
    LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` IMPORTE
      ON  UPPER(TRIM(CANAL.marco_energia))     = UPPER(TRIM(IMPORTE.marco_energia))
      AND UPPER(TRIM(CONCEPTOS.concepto))      = UPPER(TRIM(IMPORTE.concepto))
      AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
      AND IMPORTE.duplicado = 1
    WHERE UPPER(TRIM(LUCERA.tenant_code)) = 'EUSKALTEL'
      AND LUCERA.churn_date IS NULL
      AND DATE_TRUNC(DATE(LUCERA.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND DEALER.sfid_id IS NOT NULL
      AND IMPORTE.comision IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY LUCERA.cups_code ORDER BY LUCERA.sfid_id DESC) = 1

    UNION ALL

    -- ── R brand ────────────────────────────────────────────────────────────
    SELECT
      prefijo||'RNEN_'||mes_string||'_'||DEALER.canaln||'_'||
        ROW_NUMBER() OVER (PARTITION BY DEALER.canaln ORDER BY LUCERA.cups_code) AS commission_id,
      'calculado' AS estado,
      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
      id_mes_pr AS id_mes,
      IMPORTE.marco_energia,
      DEALER.agrupacion_canal,
      DEALER.canaln,
      CONCEPTOS.concepto,
      CONCEPTOS.tipo_concepto,
      1 AS unidades,
      IMPORTE.comision,
      DEALER.id_comisionista,
      COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor,
      DEALER.sfid_id,
      UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller,
      DEALER.nombre_comercio,
      DEALER.razon_social,
      DEALER.cif,
      DEALER.zona_fiscal,
      'R' AS marca,
      'ENERGY' AS service_type,
      CAST(LUCERA.phone AS STRING) AS phone_nm,
      CAST(NULL AS STRING) AS tariff_id,
      LUCERA.initial_lucera_tariff_name AS tariff_ds,
      CAST(LUCERA.id AS STRING) AS service_id,
      CAST(NULL AS STRING) AS account_id,
      CAST(NULL AS STRING) AS customer_id,
      CAST(NULL AS STRING) AS line_type_ds,
      CAST(NULL AS STRING) AS bundle_type,
      CAST(NULL AS STRING) AS technology_ds,
      CAST(NULL AS STRING) AS billing_type_ds,
      LUCERA.signup_date AS sale_date,
      LUCERA.activation_date,
      LUCERA.churn_date AS deactivation_date,
      CAST(NULL AS STRING) AS order_id,
      CAST(NULL AS STRING) AS order_type_agg,
      '10' AS cod_segmento,
      CAST(NULL AS STRING) AS cod_marca,
      '99' AS cod_tipo_contrato,
      '014' AS cod_producto,
      CAST(NULL AS STRING) AS cod_canal,
      CAST(NULL AS STRING) AS campaign_code,
      LUCERA.cups_code AS serial_number,
      CAST(NULL AS FLOAT64) AS tax_base,
      CAST(NULL AS STRING) AS claim_code,
      CAST(NULL AS STRING) AS process_code,
      CAST(NULL AS STRING) AS comments,
      'C_MANUAL' AS facturador,
      'X001' AS sociedad
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity` LUCERA
    LEFT JOIN CONCEPTOS
      ON  CONCEPTOS.proceso = 'ENRGN'
      AND SUBSTR(CONCEPTOS.concepto, 1, 1) = 'B'
      AND CASE
            WHEN (LUCERA.initial_lucera_tariff_name LIKE '%Batman%'
                  OR CONTAINS_SUBSTR(LUCERA.affiliate_code, 'batman'))
            THEN 'B - Energia Batman'
            ELSE 'B - Energia'
          END = CONCEPTOS.concepto
    LEFT JOIN (
      SELECT DISTINCT
        id_mes_pr,
        channel_ds AS agrupacion_canal,
        CAST(sfid_id AS STRING) AS sfid_id,
        vertical_focus_ds AS id_comisionista,
        vertical_focus_ds AS nombre_comercio,
        distributor_ds    AS distribuidor,
        distributor_ds    AS razon_social,
        subchannel_ds     AS canaln,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`('R', distributor_ds) AS cif,
        'PEN' AS zona_fiscal
      FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL`
    ) DEALER ON LUCERA.sfid_id = DEALER.sfid_id
    LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
      ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(DEALER.agrupacion_canal))
      AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(DEALER.canaln))
    LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` IMPORTE
      ON  UPPER(TRIM(CANAL.marco_energia))     = UPPER(TRIM(IMPORTE.marco_energia))
      AND UPPER(TRIM(CONCEPTOS.concepto))      = UPPER(TRIM(IMPORTE.concepto))
      AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
      AND IMPORTE.duplicado = 1
    WHERE UPPER(TRIM(LUCERA.tenant_code)) = 'R'
      AND LUCERA.churn_date IS NULL
      AND DATE_TRUNC(DATE(LUCERA.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND DEALER.sfid_id IS NOT NULL
      AND IMPORTE.comision IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY LUCERA.cups_code ORDER BY LUCERA.sfid_id DESC) = 1
  );

  -- ── Stage 2: flatten to ENERGY_LUZ_norte ────────────────────────────────

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT
    id_mes,
    commission_id,
    marco_energia,
    agrupacion_canal,
    canal,
    cod_canal,
    agrupacion_canal AS canal_ds,
    canal AS subcanal_ds,
    concepto,
    tipo_concepto,
    unidades,
    comision,
    id_comisionista,
    distribuidor,
    sfid_id,
    seller,
    nombre_comercio,
    razon_social,
    cif,
    zona_fiscal,
    marca,
    service_type,
    phone_nm,
    tariff_id,
    tariff_ds,
    service_id,
    account_id,
    customer_id,
    line_type_ds,
    bundle_type,
    technology_ds,
    billing_type_ds,
    sale_date,
    activation_date,
    deactivation_date,
    order_id,
    order_type_agg,
    cod_segmento,
    cod_tipo_contrato,
    cod_producto,
    cod_marca,
    claim_code,
    campaign_code,
    serial_number,
    tax_base,
    process_code,
    comments,
    facturador,
    estado
  FROM `mm-commissions-reporting.TEMP.enrgn_activations`;

  -- ── Stage 3: reparto (split commissions) ─────────────────────────────────

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_LUZ_reparto_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  WITH rep AS (
    SELECT DISTINCT
      a.agrupacion_canal,
      a.canal,
      a.distribuidor,
      a.sfid_id,
      -- F1: unit count per sfid (X = wildcard → count within own group)
      CASE
        WHEN UPPER(TRIM(r.sfid_id)) = 'X'
        THEN COUNT(a.service_id) OVER (PARTITION BY a.agrupacion_canal, a.canal, a.distribuidor, a.sfid_id)
        ELSE COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
      END AS nprxsfid,
      -- F2: share of pool amount for this sfid
      SAFE_DIVIDE(
        AVG(importe) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor),
        COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
      ) AS impxpr,
      SAFE_MULTIPLY(
        CASE
          WHEN UPPER(TRIM(r.sfid_id)) = 'X'
          THEN COUNT(a.service_id) OVER (PARTITION BY a.agrupacion_canal, a.canal, a.distribuidor, a.sfid_id)
          ELSE COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
        END,
        SAFE_DIVIDE(
          AVG(importe) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor),
          COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
        )
      ) AS impacxsfid
    FROM `mm-commissions-reporting.TEMP.enrgn_activations` a
    INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_REPARTO` r
      ON  a.agrupacion_canal = r.agrupacion_canal
      AND a.canal = r.canal
      AND CASE WHEN NOT UPPER(TRIM(r.distribuidor)) = 'X'
               THEN UPPER(TRIM(r.distribuidor)) = UPPER(TRIM(a.distribuidor))
               ELSE TRUE END
      AND CASE WHEN NOT UPPER(TRIM(r.sfid_id)) = 'X'
               THEN r.sfid_id = a.sfid_id
               ELSE TRUE END
  )

  SELECT
    id_mes,
    prefijo||'RPEN_'||mes_string||'_'||a.canal||'_'||
      ROW_NUMBER() OVER (PARTITION BY a.canal ORDER BY a.agrupacion_canal, a.distribuidor, a.sfid_id, a.service_id) AS commission_id,
    a.marco_energia,
    a.agrupacion_canal,
    a.canal,
    cod_canal,
    a.agrupacion_canal AS canal_ds,
    a.canal AS subcanal_ds,
    'D - Extra' AS concepto,
    tipo_concepto,
    unidades,
    ROUND(r.impxpr, 4) AS comision,
    id_comisionista,
    a.distribuidor,
    a.sfid_id,
    seller,
    nombre_comercio,
    razon_social,
    cif,
    zona_fiscal,
    marca,
    service_type,
    phone_nm,
    tariff_id,
    tariff_ds,
    service_id,
    account_id,
    customer_id,
    line_type_ds,
    bundle_type,
    technology_ds,
    billing_type_ds,
    sale_date,
    activation_date,
    deactivation_date,
    order_id,
    order_type_agg,
    cod_segmento,
    cod_tipo_contrato,
    cod_producto,
    cod_marca,
    claim_code,
    campaign_code,
    serial_number,
    tax_base,
    process_code,
    comments,
    facturador,
    estado
  FROM `mm-commissions-reporting.TEMP.enrgn_activations` a
  INNER JOIN rep r
    ON  a.agrupacion_canal = r.agrupacion_canal
    AND a.canal            = r.canal
    AND a.distribuidor     = r.distribuidor
    AND a.sfid_id          = r.sfid_id;

END