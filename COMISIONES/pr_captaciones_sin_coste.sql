BEGIN

IF canales_pr IS NULL THEN SET canales_pr = ['ENK'];

END IF;


/*
CALL COMISIONES.pr_captaciones_sin_coste(202507,['ENK']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.captaciones_sin_coste` AS

  SELECT DISTINCT
       DEVICE.master_channel_ds 
      ,DEVICE.channel_ds
      ,DEVICE.subchannel_ds
      ,AGRUPACION.codigo_canal_sap AS cod_canal
      ,DEVICE.sfid_id
      ,DEVICE.user_store AS user_store
      ,COALESCE(DEVICE.user_store,UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)])) as seller
      ,SALES_CHANNEL.channel_segment_ds AS channel_segment_ds
      ,DEVICE.segment_ds
      ,DEVICE.brand_ds
      ,DEVICE.service_id
      ,DEVICE.tariff_id
      ,DEVICE.tariff_ds
      ,COALESCE(SALES.sell_bundle_type, 'MO') AS bundle_type
      ,COALESCE(REPLACE(SALES.line_type_ds, 'DESC', 'MAIN'), SALES.line_type_ds) AS line_type_ds
      ,COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
      ,COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
      ,DEVICE.service_type AS technology_ds
      ,CAST(DEVICE.phone_nm AS STRING) phone_nm
      ,DATE(DEVICE.order_date) AS order_date
      
      ,CASE 
           WHEN SALES.activation_date < DATE(DEVICE.order_date) THEN DATE(DEVICE.order_date) 
           ELSE COALESCE(SALES.activation_date,DATE(DEVICE.order_date)) 
       END AS activation_date

      ,DATE(DEVICE.cancellation_date_ts) AS deactivation_date
      ,DEVICE.account_id
      ,DEVICE.customer_id
      ,DEVICE.id_subscription_terminal AS order_id
      ,DEVICE.device_type_ds AS device_type
      ,DEVICE.product_code AS product_id
      ,DEVICE.terminal_name AS product
      ,CASE WHEN DEVICE.is_financed_desc = 'SI' THEN 'PAGO FINANCIADO' ELSE 'NO FINANCIADO' END AS financed_type
      ,DEVICE.flag_pay_penalty
      ,DEVICE.cost_price
      ,DEVICE.serial_number
      ,DEVICE.data_source_ds AS data_source
      ,DEVICE.financed_end_date
      ,DEVICE.total_pay_value
      ,DEVICE.courier
      ,DEVICE.terminal_status_ds
      ,DEVICE.terminal_name
      ,DEVICE.not_financed_price
      ,DEVICE.q25_amount
      ,DEVICE.financed_total_amount
      ,DEVICE.order_type_agg
      ,DEVICE.original_cost_price
      ,DEVICE.tax_value

FROM `mm-datamart-kd.DEVICES.device_base_mysim` DEVICE

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` SALES
         ON CAST(DEVICE.service_id AS STRING) = SALES.service_id AND DEVICE.brand_ds = SALES.brand_ds AND SALES.data_source_ds = 'MYSIM'
            AND DEVICE.data_source_ds = 'MYSIM'

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
          WHERE data_source_ds = 'MYSIM'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
          ) AS SALES_CHANNEL
         ON DEVICE.sfid_id = SALES_CHANNEL.sfid_id

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE( SALES_CHANNEL.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND DEVICE.master_channel_ds = AGRUPACION.master_channel_ds
            AND  DEVICE.channel_ds = AGRUPACION.channel_ds
            AND  DEVICE.subchannel_ds = AGRUPACION.subchannel_ds
            AND DEVICE.comm_brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
          ON DEVICE.user_store = DEALER.id_comisionista AND DEALER.comisiona = TRUE

CROSS JOIN UNNEST(canales_pr) AS canal_pr


WHERE DEVICE.master_channel_ds = 'EXCLUSIVO' -- 09/09/25
AND DEALER.canal = canal_pr
-- AND DEVICE.is_financed_desc = 'NO'
AND DEVICE.total_pay_value_without_vat = 0
AND DEVICE.brand_ds IN ('MASMOVIL', 'YOIGO')
      AND (
          expedition_status_ds = 'CONFIRMADA'
          OR (expedition_status_ds IS NULL)
          OR (DEVICE.terminal_status_ds = 'USADO')
          )
      AND DEVICE.terminal_status_ds NOT IN ('CANCELADO','DESISTIDO','LIBRE')
      AND DEVICE.sell_terminal_origin_ds = 'CAPTACION' --08/09/25
      AND SALES.billing_type_ds = 'POSTPAID'
AND DATE(DATE_TRUNC(DEVICE.picking_date_ts, MONTH)) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND DATE(DATE_TRUNC(SALES.activation_date, MONTH)) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND SALES.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD','MIGRACION PREPAGO A POSTPAGO')
-- AND DEVICE.device_type_ds NOT IN ('ROUTER', 'Hotspotwifi', 'STB')

QUALIFY RANK () OVER (
                     PARTITION BY /*DEVICE.service_id,*/ DEVICE.serial_number, DEVICE.product_code
                     ORDER BY DEVICE.order_date ASC,
                              CASE WHEN SALES.order_date <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_date, '9999-12-31') END DESC,
                              CASE WHEN SALES.order_date > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_date, '9999-12-31') END ASC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END DESC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END ASC,
                              SALES.deactivation_date ASC
                     ) = 1
;

END