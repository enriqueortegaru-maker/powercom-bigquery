BEGIN

  -- ======================================================
  -- PROCEDIMIENTO DE CREACION DE TABLA  ventas_comisiones
  -- ======================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT` 
  PARTITION BY RANGE_BUCKET(id_mes_activacion, GENERATE_ARRAY(201500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, subchannel_ds, phone_nm
  AS
    
  select 
      CAST(NULL AS STRING) as sell_type,
      mc.mm.channel_type_ds AS channel_type_ds,
      mc.mm.master_channel_ds AS master_channel_ds,
      mc.mm.channel_ds AS channel_ds,
      mc.mm.subchannel_ds AS subchannel_ds,
      dev.sfid_id AS sfid_id,
      "PENDIENTE" AS user_store,
      mc.agente.ds AS seller,
      mc.mm.channel_segment_ds AS channel_segment_ds,
      dev.segment_ds AS segment_ds,
      mc.mm.channel_id AS channel_id,
      CAST(NULL AS STRING) as sfid_ifs,
      CASE WHEN mc.mo.zona_fiscal = 'PEN' THEN 1 WHEN mc.mo.zona_fiscal = 'CAN' THEN 4 ELSE 1 END AS region_code,
      dev.brand_ds AS brand_ds,
      dev.data_source_ds AS data_source,
      dev.device_subscription_id AS id_subscription_terminal,
      CAST(NULL AS STRING) as contract_id,
      dev.service_id AS service_id,
      dev.account_id AS account_id,
      dev.customer_id AS customer_id,
      dev.order_id AS order_id,
      dev.phone_nm AS phone_nm,
      CAST(NULL AS STRING) as tariff_id,
      CAST(NULL AS STRING) as tariff_ds,
      dev.order_type_ds AS order_type_agg,
      CAST(NULL AS STRING) as sales_technology_ds,
      CAST(NULL AS STRING) as bundle_type,
      CAST(NULL AS STRING) as line_type_ds,
      'POSTPAID' as billing_type_ds,
      dev.order_date AS order_date,
      CAST(NULL AS STRING) as status_servicio,
      CAST(NULL AS STRING) as motivo_cancelacion,
      COALESCE(expedition_date, dev.order_date) AS activation_date,
      CAST(NULL AS DATE) as deactivation_date,
      CAST(NULL AS STRING) as terminal_status_ds,
      CAST(NULL AS STRING) as product_code,
      dev.device_model_ds AS terminal_name,
      CAST(NULL AS STRING) as product,
      dev.financed_months AS financed_months,
      dev.financed_monthly_quota AS financed_monthly_quota,
      dev.financed_entity_ds AS financed_entity,
      dev.is_financed_flg AS is_financed_desc,
      dev.financed_status_ds AS financed_status,
      CAST(NULL AS STRING) as financed_type,
      CAST(NULL AS STRING) as technology_ds,
      dev.serial_number AS serial_number,
      CAST(NULL AS STRING) as offer_segmentation,
      CAST(NULL AS INT64) as tax,
      dev.tax_value AS tax_value,
      CAST(NULL AS FLOAT64) as purch_price,
      dev.net_subsidy AS net_subsidy,
      CAST(NULL AS FLOAT64) as end_user_price,
      dev.cost_price AS coste_device,
      CAST(NULL AS FLOAT64) as subsidy,
      CAST(NULL AS FLOAT64) as subsidy_payterm,
      CAST(NULL AS FLOAT64) as subsidy_pay25,
      CAST(NULL AS STRING) as agrupacion_canal,
      mc.mo.n2id AS canal,
      mc.distribuidor.ds AS distribuidor,
      mc.mo.cif AS cif,
      mc.mo.razon_social AS razon_social,
      case when mc.mm.channel_ds="EXCLUSIVO MULTIMARCA" THEN mc.equipo.descripcion END AS nombre_comercio,
      dev.financed_init_date AS fecha_inicio_financiacion,
      dev.financed_end_date AS fecha_fin_financiacion,
      CAST(NULL AS STRING) as cod_canal,
      dev.cost_original_price AS original_cost_price,
      dev.total_pay_value AS total_pay_value,
      --- AÑADIDO PERSONALIZADO POR REQEURIMIENTO MR
      dev.total_pay_value_without_vat AS total_pay_value_without_vat,
      --- FIN AÑADIDO 
      CAST(NULL AS STRING) as courier,
      CAST(NULL AS STRING) as compromiso_permanencia,
      --- AÑADIDO PERSONALIZADO PARA 
      sale_flg,
      CAST(FORMAT_DATE('%Y%m',COALESCE(expedition_date, dev.order_date) ) AS INT64) AS id_mes_activacion,
      --- FIN AÑADIDO 

    FROM `mm-datamart-kd.DEVICES.device_base_mo` as dev
  left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` mc on dev.brand_ds=mc.marca_ds and (dev.sfid_id=mc.mm.sfid or dev.sfid_id=mc.mo.sfid)
  where ((DEVICE_TYPE_ds IN ("PHONE" )   and brand_ds IN ("EUSKALTEL","TELECABLE","RACC","SIMPLE"))
    OR (DEVICE_TYPE_ds IN ("TERMINAL MOVIL")   and brand_ds IN ("R") ))
  and CAST(CAST(FORMAT_DATE('%Y%m',order_date) AS STRING) AS INT64)>= id_mes_pr;--DATE_TRUNC(CURRENT_DATE(),MONTH);


END