BEGIN

  DECLARE prefijo, mes_string STRING;
  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo    = 'NENRG_';

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_svg_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  WITH

  source_filtered AS (
    SELECT
      A.id,
      A.cups_code,
      A.sfid_id,
      A.signup_date_altas,
      A.author_id,
      A.tenant_code,
      B.data_inici,
      B.data_fi
    FROM `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
    INNER JOIN `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
      ON A.id = B.polissa_id
    WHERE DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', mes_string)
      AND A.product    = 'SVG'
      AND A.sfid_id    IS NOT NULL
      AND A.state      = 'activa'
      AND A.subchannel_ds NOT IN ('PENDIENTE DEFINIR', 'PLAT. FIDELIZACION/RETENCION', 'CANCELACIONES')
      AND UPPER(TRIM(A.tenant_code)) IN ('EUSKALTEL_SVG', 'R_SVG')
  ),

  sfid_lookup AS (
    SELECT * FROM (
      SELECT
        crm,
        marca_ds,
        mo.sfid               AS sfid_id,
        'mo'                  AS src,
        mo.N1                 AS agrupacion_canal,
        mo.N2                 AS canal,
        mo.bp                 AS id_comisionista,
        mo.nombre_acreedor_ds AS distribuidor,
        mo.nombre_acreedor_ds AS nombre_comercio,
        mo.razon_social,
        mo.CIF,
        equipo.descripcion
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`
      WHERE mo.sfid IS NOT NULL
      UNION ALL
      SELECT
        crm,
        marca_ds,
        ct.sfid,
        'ct',
        ct.canal_ds,
        ct.subcanal_ds,
        mo.bp,
        ct.distribuidor_ds,
        ct.distribuidor_ds,
        mo.razon_social,
        mo.CIF,
        equipo.descripcion
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`
      WHERE ct.sfid IS NOT NULL
    )
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY sfid_id
      ORDER BY CASE src WHEN 'mo' THEN 1 ELSE 2 END
    ) = 1
  )

  SELECT
    id_mes_pr                                                                AS id_mes,
    prefijo ||
      CASE WHEN UPPER(TRIM(A.tenant_code)) = 'EUSKALTEL_SVG' THEN 'BN' ELSE 'RN' END ||
      'SVG_' || mes_string || '_' || sl.agrupacion_canal || '_' ||
      ROW_NUMBER() OVER (
        PARTITION BY sl.agrupacion_canal, UPPER(TRIM(A.tenant_code))
        ORDER BY A.cups_code, CAST(A.id AS STRING)
      )                                                                       AS commission_id,
    m.marco_energia,
    sl.agrupacion_canal,
    sl.canal,
    CAST(NULL AS STRING)                                                     AS cod_canal,
    sl.agrupacion_canal                                                      AS canal_ds,
    sl.canal                                                                 AS subcanal_ds,
    'B - SVG'                                                                AS concepto,
    'CSEN'                                                                   AS tipo_concepto,
    1                                                                        AS unidades,
    m.comision,
    sl.id_comisionista,
    COALESCE(sl.distribuidor, CAST(sl.id_comisionista AS STRING))           AS distribuidor,
    A.sfid_id,
    UPPER(SPLIT(A.author_id, '@')[OFFSET(0)])                              AS seller,
    sl.nombre_comercio,
    sl.razon_social,
    sl.CIF                                                                   AS cif,
    'PEN'                                                                    AS zona_fiscal,
    sl.crm                                                                   AS crm,
    sl.marca_ds                                                              AS marca,
    'ENERGY'                                                                 AS service_type,
    CAST(NULL AS STRING)                                                     AS phone_nm,
    CAST(NULL AS STRING)                                                     AS tariff_id,
    CAST(NULL AS STRING)                                                     AS tariff_ds,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdServicioDesdeCUPSyFechaActivacion`(A.cups_code, A.data_inici) AS service_id,
    A.cups_code                                                              AS account_id,
    CAST(NULL AS STRING)                                                     AS customer_id,
    CAST(NULL AS STRING)                                                     AS line_type_ds,
    CAST(NULL AS STRING)                                                     AS bundle_type,
    CAST(NULL AS STRING)                                                     AS technology_ds,
    CAST(NULL AS STRING)                                                     AS billing_type_ds,
    A.signup_date_altas                                                      AS sale_date,
    A.data_inici                                                             AS activation_date,
    A.data_fi                                                                AS deactivation_date,
    CAST(NULL AS STRING)                                                     AS order_id,
    CAST(NULL AS STRING)                                                     AS order_type_agg,
    '10'                                                                     AS cod_segmento,
    '99'                                                                     AS cod_tipo_contrato,
    '014'                                                                    AS cod_producto,
    CAST(NULL AS STRING)                                                     AS cod_marca,
    CAST(NULL AS STRING)                                                     AS claim_code,
    CAST(NULL AS STRING)                                                     AS campaign_code,
    A.cups_code                                                              AS serial_number,
    CAST(NULL AS FLOAT64)                                                    AS tax_base,
    CAST(NULL AS STRING)                                                     AS process_code,
    CAST(NULL AS STRING)                                                     AS comments,
    'C_MANUAL'                                                               AS facturador,
    `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(sl.marca_ds) AS sociedad,
    'calculado'                                                              AS estado
  FROM source_filtered A
  INNER JOIN sfid_lookup sl ON A.sfid_id = sl.sfid_id
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
    ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(sl.agrupacion_canal))
    AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(sl.canal))
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` m
    ON  UPPER(TRIM(CANAL.marco_energia))    = UPPER(TRIM(m.marco_energia))
    AND m.concepto                          = 'B - SVG'
  WHERE m.comision IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC) = 1;

END