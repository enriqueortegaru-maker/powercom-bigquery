BEGIN

  DECLARE VMES_1M_DT,
  VMES_2M_DT,
  VMES_12M_DT,
  VMES_13M_DT,
  VMES_0M_FIN_DT DATE;
  --DECLARE id_mes_pr INT64; SET id_mes_pr=202608;
  SET VMES_1M_DT =
    DATE_SUB(PARSE_DATE("%Y%m", CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH);
  SET VMES_2M_DT =
    DATE_SUB(PARSE_DATE("%Y%m", CAST(id_mes_pr AS STRING)), INTERVAL 2 MONTH);
  SET VMES_12M_DT =
    DATE_SUB(PARSE_DATE("%Y%m", CAST(id_mes_pr AS STRING)), INTERVAL 12 MONTH);
  SET VMES_13M_DT =
    DATE_SUB(PARSE_DATE("%Y%m", CAST(id_mes_pr AS STRING)), INTERVAL 13 MONTH);
  SET VMES_1M_DT =
    DATE_SUB(PARSE_DATE("%Y%m", CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH);
  SET VMES_0M_FIN_DT =
    LAST_DAY(PARSE_DATE("%Y%m", CAST(id_mes_pr AS STRING)));
  

  -- ======================================================
  -- PROCEDIMIENTO DE CREACION DE TABLA  ventas_comisiones
  -- ======================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT` 
  PARTITION BY RANGE_BUCKET(id_mes_activacion, GENERATE_ARRAY(201500, 203000, 1))
  CLUSTER BY brand_ds, channel_ds, subchannel_ds, phone_nm
  AS

    WITH dev AS (
      --DECLARE VMES_2M_DT DATE DEFAULT '2026-07-01';
      SELECT
        d.*,
        --d.service_id,DATE(d.order_date),
        ROW_NUMBER() OVER (ORDER BY device_subscription_id, order_id, serial_number) AS _dev_rk
      FROM `mm-datamart-kd.DEVICES.device_base_mo` d
      WHERE d.DEVICE_TYPE_ds not in (
              'CENTRALITA',
              'DESCO TV DIXITAL',
              'DESCODIFICADOR TV DIXITAL 4K',
              'EQUIPAMIENTO ACCESORIOS',
              'EQUIPAMIENTO DATOS',
              'EQUIPAMIENTO MOVIL',
              'EQUIPAMIENTO TELEVISION',
              'EQUIPO TELEFONIA',
              'MODEM',
              'TARJETA',
              'TELEFONIA DIGITAL',
              'TERMINAL TELEFONICO ANALOGICO'
            )
            and device_model_ds is not null 
            and not contains_substr(device_model_ds,'FIBRA')
            and not contains_substr(device_model_ds,'LIVEBOX')
            and not contains_substr(device_model_ds,'ROUTER')
            and not contains_substr(device_model_ds,'ALQUILER')
            and not contains_substr(device_model_ds,'ONT')
            and not contains_substr(device_model_ds,'ANTENA')
            and not contains_substr(device_model_ds,'ZYXEL')
            and not contains_substr(device_model_ds,'WAN')
            and not contains_substr(device_model_ds,'SWITCH')
            and not contains_substr(device_model_ds,'TEEFONO')
            and not contains_substr(device_model_ds,'TERMINAL')
            and not contains_substr(device_model_ds,'STD')
            and not contains_substr(device_model_ds,'INST')
            and not contains_substr(device_model_ds,'TOMA')
            and not contains_substr(device_model_ds,'CONEXI')
            and not contains_substr(device_model_ds,'DECO')
            and not contains_substr(device_model_ds,'CABLEM')
            and not contains_substr(device_model_ds,'MODEM')
            and not contains_substr(device_model_ds,'VISITA')
            and not contains_substr(device_model_ds,'TARJETA')            
            and not contains_substr(device_model_ds,'MICROKEY')                        
            AND DATE(d.order_date)  BETWEEN VMES_2M_DT AND VMES_0M_FIN_DT 
            AND brand_ds in ("EUSKALTEL","R","TELECABLE","RACC","SIMPLE")
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
      -- Seleccione UN evento de pedido por fila de dispositivo. Sin esto, el historial
      -- completo de pedidos de la línea (hasta 63 eventos) se replica en cada dispositivo.        
      QUALIFY ROW_NUMBER() OVER (
        PARTITION BY dev._dev_rk
        ORDER BY
          IF(v.order_status_ds = "ANULADO", 1, 0),               -- la cancelación nunca gana
          IF(v.order_date = dev.order_date, 0, 1),               -- se prioriza la fecha exacta
          ABS(DATE_DIFF(v.order_date, dev.order_date, DAY)),     -- en caso contrario la más próxima
          v.order_date DESC,
          v.order_id   DESC                                      -- deterministico
      ) = 1
    )
    SELECT
        dev.v_sell_type AS sell_type,
        UPPER(mc.mm.channel_type_ds) AS channel_type_ds,
        UPPER(mc.mm.master_channel_ds) AS master_channel_ds,
        UPPER(mc.mm.channel_ds) AS channel_ds,
        UPPER(mc.mm.subchannel_ds) AS subchannel_ds,
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