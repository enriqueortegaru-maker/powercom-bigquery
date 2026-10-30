BEGIN

  -- ======================================================
  -- PROCEDIMIENTO DE CREACION DE TABLA  ventas_comisiones
  -- ======================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT` 
  PARTITION BY RANGE_BUCKET(id_mes_activacion, GENERATE_ARRAY(201500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, subchannel_ds, phone_nm
  AS

    WITH dev AS (
      SELECT
        d.*,
        ROW_NUMBER() OVER (ORDER BY device_subscription_id, order_id, serial_number) AS _dev_rk
      FROM `mm-datamart-kd.DEVICES.device_base_mo` d
      WHERE ((d.DEVICE_TYPE_ds IN ("PHONE")
                AND d.brand_ds IN ("EUSKALTEL","TELECABLE","RACC","SIMPLE"))
          OR (d.DEVICE_TYPE_ds IN ("TERMINAL MOVIL")
                AND d.brand_ds IN ("R")))
        AND CAST(FORMAT_DATE("%Y%m", d.order_date) AS INT64) >= id_mes_pr
    ),
    dev_v AS (
      SELECT
        dev.*,
        v.sell_type       AS v_sell_type,
        v.seller          AS v_seller,
        v.order_type_agg  AS v_order_type_agg
      FROM dev
      LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` v
        ON  v.service_type   = "MOBILE"
        AND v.brand_ds       = dev.brand_ds
        AND v.data_source_ds = dev.data_source_ds
        AND v.service_id     = dev.service_id
        AND v.account_id     = dev.account_id
        AND v.customer_id    = dev.customer_id
        AND v.phone_nm       = dev.phone_nm
      QUALIFY ROW_NUMBER() OVER (
        PARTITION BY dev._dev_rk
        ORDER BY
          IF(v.order_status_ds = "ANULADO", 1, 0),               
          IF(v.order_date = dev.order_date, 0, 1),               
          ABS(DATE_DIFF(v.order_date, dev.order_date, DAY)),     
          v.order_date DESC,
          v.order_id   DESC                                      
      ) = 1
    )
    SELECT
        dev.v_sell_type AS sell_type,
        mc.mm.channel_type_ds AS channel_type_ds,
        mc.mm.master_channel_ds AS master_channel_ds,
        mc.mm.channel_ds AS channel_ds,
        mc.mm.subchannel_ds AS subchannel_ds,
        dev.sfid_id AS sfid_id,
        "PENDIENTE" AS user_store,
        COALESCE(mc.agente.ds, dev.v_seller) AS seller,
        mc.mm.channel_segment_ds AS channel_segment_ds,
        dev.segment_ds AS segment_ds,
        mc.mm.channel_id AS channel_id,
        CAST(NULL AS STRING) AS sfid_ifs,
        CASE WHEN mc.mo.zona_fiscal = 'PEN' THEN 1
            WHEN mc.mo.zona_fiscal = 'CAN' THEN 4
            ELSE 1 END AS region_code,
        dev.brand_ds AS brand_ds,
        dev.data_source_ds AS data_source,
        dev.device_subscription_id AS id_subscription_terminal,
        CAST(NULL AS STRING) AS contract_id,
        dev.service_id AS service_id,
        dev.account_id AS account_id,
        dev.customer_id AS customer_id,
        dev.order_id AS order_id,
        dev.phone_nm AS phone_nm,
        CAST(NULL AS STRING) AS tariff_id,
        CAST(NULL AS STRING) AS tariff_ds,
        dev.v_order_type_agg AS order_type_agg,
        CAST(NULL AS STRING) AS sales_technology_ds,
        CAST(NULL AS STRING) AS bundle_type,
        CAST(NULL AS STRING) AS line_type_ds,
        'POSTPAID' AS billing_type_ds,
        dev.order_date AS order_date,
        CAST(NULL AS STRING) AS status_servicio,
        CAST(NULL AS STRING) AS motivo_cancelacion,
        COALESCE(dev.expedition_date, dev.order_date) AS activation_date,
        CAST(NULL AS DATE) AS deactivation_date,
        CAST(NULL AS STRING) AS terminal_status_ds,
        CAST(NULL AS STRING) AS product_code,
        dev.device_model_ds AS terminal_name,
        CAST(NULL AS STRING) AS product,
        dev.financed_months AS financed_months,
        dev.financed_monthly_quota AS financed_monthly_quota,
        dev.financed_entity_ds AS financed_entity,
        dev.is_financed_flg AS is_financed_desc,
        dev.financed_status_ds AS financed_status,
        CAST(NULL AS STRING) AS financed_type,
        CAST(NULL AS STRING) AS technology_ds,
        dev.serial_number AS serial_number,
        CAST(NULL AS STRING) AS offer_segmentation,
        CAST(NULL AS INT64) AS tax,
        dev.tax_value AS tax_value,
        CAST(NULL AS FLOAT64) AS purch_price,
        dev.net_subsidy AS net_subsidy,
        CAST(NULL AS FLOAT64) AS end_user_price,
        dev.cost_price AS coste_device,
        CAST(NULL AS FLOAT64) AS subsidy,
        CAST(NULL AS FLOAT64) AS subsidy_payterm,
        CAST(NULL AS FLOAT64) AS subsidy_pay25,
        CAST(NULL AS STRING) AS agrupacion_canal,
        mc.mo.n2id AS canal,
        mc.distribuidor.ds AS distribuidor,
        mc.mo.cif AS cif,
        mc.mo.razon_social AS razon_social,
        CASE WHEN mc.mm.channel_ds = "EXCLUSIVO MULTIMARCA"
            THEN mc.equipo.descripcion END AS nombre_comercio,
        dev.financed_init_date AS fecha_inicio_financiacion,
        dev.financed_end_date AS fecha_fin_financiacion,
        CAST(NULL AS STRING) AS cod_canal,
        dev.cost_original_price AS original_cost_price,
        dev.total_pay_value AS total_pay_value,
        dev.total_pay_value_without_vat AS total_pay_value_without_vat,
        CAST(NULL AS STRING) AS courier,
        CAST(NULL AS STRING) AS compromiso_permanencia,
        dev.sale_flg AS sale_flg,
        CAST(FORMAT_DATE('%Y%m', COALESCE(dev.expedition_date, dev.order_date)) AS INT64) AS id_mes_activacion
    FROM dev_v AS dev
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` mc
      ON dev.brand_ds = mc.marca_ds
    AND (dev.sfid_id = mc.mm.sfid OR dev.sfid_id = mc.mo.sfid);

END