BEGIN

  --- CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_ventas_y_bajas_comisiones_krt`(202606);

  DECLARE VMES_1M_DT,  VMES_2M_DT, VMES_12M_DT, VMES_13M_DT DATE;
  --- LOCAL 
  --DECLARE VMES_ID INT64; SET VMES_ID=202606;
  SET VMES_1M_DT  = DATE_SUB(PARSE_DATE("%Y%m", CAST(vmes_id AS STRING)), INTERVAL 1 MONTH);
  SET VMES_2M_DT  = DATE_SUB(PARSE_DATE("%Y%m", CAST(vmes_id AS STRING)), INTERVAL 2 MONTH);
  SET VMES_12M_DT = DATE_SUB(PARSE_DATE("%Y%m", CAST(vmes_id AS STRING)), INTERVAL 12 MONTH);
  SET VMES_13M_DT = DATE_SUB(PARSE_DATE("%Y%m", CAST(vmes_id AS STRING)), INTERVAL 13 MONTH);

  -- ===============================================================================
  -- PROCEDIMIENTO DE CREACION DE TABLA ventas_comisiones y bajas comisiones
  -- ===============================================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT`
  PARTITION BY RANGE_BUCKET(id_mes_activacion, GENERATE_ARRAY(199500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, service_type, phone_nm
  AS

  -- ==========================================
  -- 1. PRECALCULO DE TABLAS MAESTRAS
  -- ==========================================
  -- NOTE: `maestro_agrupacion_canal` CTE removed — it was never referenced
  -- downstream (dead read of gs_control_agrupacion_canal).

  WITH canalizacion_krt AS (
      SELECT
          marca_ds,
          CAST(ct.sfid AS STRING) AS ct_sfid_str,
          CAST(agente.id AS STRING) AS agente_id_str,
          CAST(mo.sfid AS STRING) as mo_sfid
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`
  ),

  -- ==========================================
  -- 2. FUENTE UNICA: TELCO NET (KRT / MIG PWC)
  -- (colapsada la envoltura UNION heredada de cuando había varias fuentes)
  -- ==========================================
  datos_unificados AS (
      SELECT
        'Comisiona' AS comisionamiento, b.marca_ds AS marca, a.brand_ds, a.service_id, a.account_id,
        a.customer_id, a.service_type, a.line_type_ds,
        CASE
            WHEN a.sell_bundle_type IN ('2P', 'FMC', 'MO') THEN a.sell_bundle_type
            WHEN a.sell_bundle_type LIKE '%M%' AND a.sell_bundle_type LIKE '%B%' THEN 'FMC'
            WHEN a.sell_bundle_type LIKE '%M%' AND a.sell_bundle_type NOT LIKE '%B%' THEN 'MO'
            WHEN a.sell_bundle_type NOT LIKE '%M%' AND a.sell_bundle_type LIKE '%B%' THEN '2P'
            ELSE 'OTROS'
        END AS bundle_type,
        a.technology_ds, a.billing_type_ds, CAST(a.phone_nm AS STRING) AS phone_nm,
        a.order_date AS sale_date, a.activation_date, a.deactivation_date, a.order_id,
        a.order_type_agg, a.port_in_operator_ds, a.tariff_id, a.tariff_ds,
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(a.segment_ds, a.brand_ds) AS cod_segmento,
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(a.comm_brand_ds) AS cod_marca,

        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
            billing_type_ds, a.service_type, COALESCE(CASE WHEN sell_bundle_type = 'DESC' THEN bundle_type ELSE sell_bundle_type END, bundle_type),
            technology_ds, a.brand_ds, COALESCE(CASE WHEN sell_line_type_ds = 'DESC' THEN line_type_ds ELSE sell_line_type_ds END, line_type_ds)
        ) AS cod_tipo_contrato,

        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
            a.service_type, a.brand_ds, a.order_type_agg, a.sell_type,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
                billing_type_ds, a.service_type, COALESCE(CASE WHEN sell_bundle_type = 'DESC' THEN bundle_type ELSE sell_bundle_type END, bundle_type),
                technology_ds, a.brand_ds, COALESCE(CASE WHEN sell_line_type_ds = 'DESC' THEN line_type_ds ELSE sell_line_type_ds END, line_type_ds)
            )
        ) AS cod_producto,

        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(a.channel_ds, a.subchannel_ds) AS cod_canal,
        CONCAT('KRT - ', INITCAP(b.marca_ds)) AS agrupacion_canal, a.sfid_id, a.seller, a.channel_ds, a.order_fix_id,
        CAST(NULL AS STRING) AS claim_code, CAST(NULL AS STRING) AS comments, a.contract_id, a.data_source_ds,
        CAST(NULL AS STRING) AS portability_group_donor, CAST(NULL AS STRING) AS portability_operator_donor,
        a.flag_order, a.segment_ds, a.user_store, a.subchannel_ds, a.cancellation_date AS cancellation_day_id,
        a.sell_type, CAST(a.province AS STRING) AS province, a.zip_code, a.terminal_model, CAST(NULL AS STRING) AS sva_tv,
        a.channel_segment_ds, a.master_channel_ds, a.channel_type_ds, CAST(NULL AS STRING) AS hash_document_number,
        a.cancellation_reason_agg, a.cancellation_subreason_agg, CAST(NULL AS DATE) AS max_appointment_date,
        CAST(NULL AS STRING) AS billing_tier, CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag,
        a.deactivation_reason_ds,
        --- añadido 20260818
        a.sub_segment_ds
        --- fin añadido 20260818

      FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` a
      INNER JOIN canalizacion_krt b
        ON a.brand_ds = b.marca_ds
      WHERE (
          (a.brand_ds IN ('TELECABLE', 'EUSKALTEL', 'R', 'RACC', 'SIMPLE', 'VIRGIN')
           AND (b.ct_sfid_str = a.sfid_id OR b.ct_sfid_str = a.user_store OR b.mo_sfid = a.sfid_id OR b.mo_sfid = a.user_store))
          OR
          (a.brand_ds = 'R' AND b.agente_id_str = a.sfid_id)
        )
        AND (a.order_date >= VMES_2M_DT OR a.activation_date >= VMES_1M_DT
             OR a.deactivation_date >= VMES_13M_DT OR a.real_deactivation_date >= VMES_13M_DT)
  )

  -- ==========================================
  -- 3. SELECT FINAL RESUELVE SOCIEDAD
  -- ==========================================
  SELECT
      *,
      CASE
          WHEN marca IN ('TELECABLE', 'R') THEN 'R000'
          WHEN marca IN ('EUSKALTEL', 'RACC', 'SIMPLE', 'VIRGIN', 'VIVA MOBILE') THEN 'ET00'
          ELSE 'X001'
      END AS sociedad,

      CAST(FORMAT_DATE('%Y%m', activation_date) AS INT64) AS id_mes_activacion,
      CAST(FORMAT_DATE('%Y%m', deactivation_date) AS INT64) AS id_mes_desactivacion,

      CASE
          WHEN (REGEXP_CONTAINS(seller, '^([0-9A-Z][A-Z][0-9]{6})') AND channel_ds IN ('MASLIFE','EXCLUSIVO'))
                OR data_source_ds IN ('QVANTEL', 'MYSIM', 'HEOS')
          THEN SUBSTR(seller, 1, 2)
          WHEN seller LIKE 'DBL%' AND channel_ds IN ('MASLIFE','EXCLUSIVO') AND marca = 'YOIGO'
          THEN SUBSTR(seller, 1, 2)
      END AS seller_formato_tms

  FROM datos_unificados;

  -- ==========================================
  -- 4. CREACION DE VENTAS_COMISIONES_KRT
  -- ==========================================
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT`
  PARTITION BY RANGE_BUCKET(id_mes_activacion, GENERATE_ARRAY(199500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, service_type, phone_nm
  AS
  SELECT *
  FROM `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT`
  WHERE (sale_date >= VMES_1M_DT OR activation_date >= VMES_1M_DT);

  -- ==========================================
  -- 5. CREACION DE BAJAS_COMISIONES_KRT
  -- ==========================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.BAJAS_COMISIONES_KRT`
  PARTITION BY RANGE_BUCKET(id_mes_desactivacion, GENERATE_ARRAY(199500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, service_type, phone_nm
  AS
  SELECT *
  FROM `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT`
  WHERE (deactivation_date >= VMES_12M_DT);

END