BEGIN

-- ======================================================
  -- PROCEDIMIENTO DE CREACION DE TABLA  ventas_comisiones
  -- ======================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` 
  PARTITION BY RANGE_BUCKET(id_mes_activacion, GENERATE_ARRAY(199500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, service_type, phone_nm
  AS
  
  -- ==========================================
  -- 1. PRECALCULO DE TABLAS MAESTRAS Y CTEs
  -- ==========================================

  WITH maestro_agrupacion_canal AS (
      -- Eliminación previa de duplicados
      SELECT DISTINCT a.*, agrupacion_canal
      FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal` a,
      UNNEST(SPLIT(agrupaciones_canal, ',')) AS agrupacion_canal
  ),

  canalizacion_krt AS (
      -- Precalcula y normaliza canalizacion para cruce con ventas krt
      SELECT 
          marca_ds,
          CAST(ct.sfid AS STRING) AS ct_sfid_str,
          CAST(agente.id AS STRING) AS agente_id_str
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mm`
  ),

  -- ==========================================
  -- 2. UNIFICAMOS TODOS LOS ORÍGENES DE DATOS
  -- ==========================================
  datos_unificados AS (

      -- [4] TELCO NET (KRT / MIG PWC) 
      SELECT distinct 
        comisionamiento, marca, brand_ds, service_id, account_id, customer_id, service_type, 
        line_type_ds, bundle_type, technology_ds, billing_type_ds, phone_nm, sale_date, 
        activation_date, deactivation_date, order_id, order_type_agg, port_in_operator_ds, 
        tariff_id, tariff_ds, cod_segmento, cod_marca, cod_tipo_contrato,
        
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
            service_type, brand_ds, order_type_agg, sell_type, cod_tipo_contrato
        ) AS cod_producto,
        
        cod_canal, agrupacion_canal, sfid_id, seller, channel_ds, order_fix_id, claim_code, 
        comments, contract_id, data_source_ds, portability_group_donor, portability_operator_donor, 
        flag_order, segment_ds, user_store, subchannel_ds, cancellation_day_id, sell_type, 
        province, zip_code, terminal_model, sva_tv, channel_segment_ds, master_channel_ds, 
        channel_type_ds, hash_document_number, cancellation_reason_agg, cancellation_subreason_agg, 
        max_appointment_date, billing_tier, qvantel_service_id, post_pre_flag,

        --- AÑADIDOS 20260818 ----
        deactivation_reason_ds,
        sub_segment_ds,
        --- FIN AÑADIDOS 20260818 ----


      FROM (
          SELECT distinct 
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
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(a.channel_ds, a.subchannel_ds) AS cod_canal,
            concat('KRT - ', initcap(b.marca_ds)) AS agrupacion_canal, a.sfid_id, a.seller, a.channel_ds, a.order_fix_id,
            CAST(NULL AS STRING) AS claim_code, CAST(NULL AS STRING) AS comments, a.contract_id, a.data_source_ds,
            CAST(NULL AS STRING) AS portability_group_donor, CAST(NULL AS STRING) AS portability_operator_donor,
            a.flag_order, a.segment_ds, a.user_store, a.subchannel_ds, a.cancellation_date AS cancellation_day_id,
            a.sell_type, CAST(a.province AS STRING) AS province, a.zip_code, a.terminal_model, CAST(NULL AS STRING) AS sva_tv,
            a.channel_segment_ds, a.master_channel_ds, a.channel_type_ds, CAST(NULL AS STRING) AS hash_document_number,
            a.cancellation_reason_agg, a.cancellation_subreason_agg, CAST(NULL AS DATE) AS max_appointment_date,
            CAST(NULL AS STRING) AS billing_tier, CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag,

            --- AÑADIDOS 20260818 ----
            deactivation_reason_ds,
            sub_segment_ds,
            --- FIN AÑADIDOS 20260818 ----

          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` a
          INNER JOIN canalizacion_krt b 
            ON a.brand_ds = b.marca_ds 
          
          WHERE (
              (a.brand_ds IN ("TELECABLE", "EUSKALTEL", "R", "RACC", "SIMPLE", "VIRGIN") 
               AND (b.ct_sfid_str = a.sfid_id OR b.ct_sfid_str = a.user_store))
              OR 
              (a.brand_ds = "R" AND b.agente_id_str = a.sfid_id)
          )
      )
  )

  -- =========================================================================
  -- 3. SELECT FINAL RESUELVE SOCIEDAD Y PERSONALIZA ALGUNOS CAMPOS
  -- =========================================================================
  SELECT distinct 
    comisionamiento,
    marca,
    brand_ds,
    service_id,
    account_id,
    customer_id,
    service_type,
    line_type_ds,
    bundle_type,
    technology_ds,
    billing_type_ds,
    phone_nm,
    sale_date,
    activation_date,
    deactivation_date,
    order_id,
    order_type_agg,
    port_in_operator_ds,
    tariff_id,
    tariff_ds,
    cod_segmento,
    cod_marca,
    cod_tipo_contrato,
    cod_producto,
    cod_canal,
    agrupacion_canal,
    sfid_id,
    seller,
    channel_ds,
    order_fix_id,
    claim_code,
    comments,
    contract_id,
    data_source_ds,
    portability_group_donor,
    portability_operator_donor,
    flag_order,
    segment_ds,
    user_store,
    subchannel_ds,
    cancellation_day_id,
    sell_type,
    province,
    zip_code,
    terminal_model,
    sva_tv,
    channel_segment_ds,
    master_channel_ds,
    channel_type_ds,
    hash_document_number,
    cancellation_reason_agg,
    cancellation_subreason_agg,
    max_appointment_date,
    billing_tier,
    qvantel_service_id,
    post_pre_flag,

    --- AÑADIDO 20260818---
    deactivation_reason_ds,
    --- FIN AÑADIDO 20260818---    

    --- AÑADIDO 202607 ---
      CASE
          WHEN marca = 'PEPEPHONE' THEN '7000'
          WHEN marca IN ('TELECABLE', 'R') THEN 'R000'
          WHEN marca IN ('EUSKALTEL', 'RACC', 'SIMPLE', 'VIRGIN', 'VIVA MOBILE') THEN 'ET00'          
          ELSE 'X001'
      END AS sociedad,
      
      CAST(FORMAT_DATE('%Y%m', activation_date) AS INT64) AS id_mes_activacion,

    --- AÑADIDO 20260818---
      CAST(FORMAT_DATE('%Y%m', deactivation_date) AS INT64) AS id_mes_desactivacion,
    --- FIN AÑADIDO 20260818---    
      CASE
          WHEN (REGEXP_CONTAINS(seller, '^([0-9A-Z][A-Z][0-9]{6})') AND channel_ds IN ('MASLIFE','EXCLUSIVO'))
                OR data_source_ds IN ('QVANTEL', 'MYSIM', 'HEOS')
          THEN SUBSTR(seller, 1, 2)
          WHEN seller LIKE 'DBL%' AND channel_ds IN ('MASLIFE','EXCLUSIVO') AND marca = 'YOIGO'
          THEN SUBSTR(seller, 1, 2)
      END AS seller_formato_tms,

    --- FIN AÑADIDO 202607 ---

    --- AÑADIDO 20260818---
    sub_segment_ds,
    --- FIN AÑADIDO 20260818---    

  FROM datos_unificados;

END