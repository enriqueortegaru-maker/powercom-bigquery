BEGIN


-- PREPARA LA TABLA DE VENTAS DE RENUEVOS DEL GRUPO MASMOVIL PARA EL COMISIONAMIENTO DE SUS SERVICIOS --


/*
CALL `mm-commissions-reporting.10_CLEANING_COMMISSIONS.pr_devices_base_emysim_renuevos`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE dia_string, qry, tabla_nombre STRING;


SET dia_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Genera la tabla de ventas de renuevos con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.devices_base_emysim_renuevos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      DEVICES.datasource_id
     ,DEVICES.data_source_ds
     ,DEVICES.brand_id
     ,DEVICES.brand_ds
     ,DEVICES.sub_brand_ds
     ,DEVICES.comm_brand_ds
     ,DEVICES.account_id
     ,DEVICES.customer_id
     ,DEVICES.service_id
     ,DEVICES.service_type
     ,CAST(DEVICES.phone_nm AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS service_status_ds
     ,DEVICES.order_type_ds
     ,DEVICES.order_type_agg
     ,CAST(NULL AS STRING) AS order_fix_id
     ,CAST(NULL AS STRING) AS order_status_ds
     ,CAST(NULL AS STRING) AS order_id
     ,DATE(DEVICES.order_date) AS order_date
     ,CAST(NULL AS STRING) AS order_hour_id
     ,CAST(NULL AS DATE) AS cancellation_date
     ,CAST(NULL AS DATE) AS activation_date 
     ,CAST(NULL AS DATE) AS deactivation_date 
     ,CAST(NULL AS DATE) AS real_deactivation_date 
     ,CAST(NULL AS DATE) AS done_date
     ,DEVICES.segment_ds
     ,CAST(NULL AS STRING) AS sub_segment_ds
     ,CAST(NULL AS STRING) AS sell_tariff_id
     ,CAST(NULL AS STRING) AS sell_tariff_ds
     ,CAST(NULL AS STRING) AS sell_line_type_ds
     ,CAST(NULL AS STRING) AS sell_bundle_id
     ,CAST(NULL AS STRING) AS sell_bundle_name
     ,CAST(NULL AS STRING) AS sell_bundle_type
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,CAST(NULL AS STRING) AS contract_id
     ,DEVICES.sfid_id
     ,DEVICES.user_store
     ,DEVICES.seller
     ,DEVICES.dealer_code
     ,DEVICES.dealer_campaign_name
     ,DEVICES.subchannel_ds
     ,DEVICES.channel_ds
     ,DEVICES.superchannel_ds
     ,DEVICES.master_channel_ds
     ,DEVICES.channel_type_ds
     ,CAST(NULL AS STRING) AS channel_segment_ds
     ,DEVICES.tariff_id
     ,DEVICES.tariff_ds
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS INT64) AS bundle_id
     ,CAST(NULL AS STRING) AS bundle_name
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS port_in_operator_ds
     ,CAST(NULL AS STRING) AS cancellation_reason_ds
     ,CAST(NULL AS STRING) AS deactivation_reason_ds
     ,DEVICES.sell_type
     ,CAST(NULL AS STRING) AS province
     ,CAST(NULL AS STRING) AS zip_code
     ,DEVICES.terminal_model
     ,CAST(NULL AS STRING) AS campaign
     ,CAST(NULL AS STRING) AS main_service_id
     ,CAST(NULL AS INT64) AS flag_data_sharing
     ,CAST(NULL AS STRING) AS flag_new_order
     ,CAST(NULL AS STRING) AS flag_order
     ,CAST(NULL AS STRING) AS cancellation_reason_agg
     ,CAST(NULL AS STRING) AS cancellation_subreason_agg
     ,CAST(NULL AS STRING) AS customer_document
     ,CAST(NULL AS STRING) AS pai
     ,CAST(NULL AS STRING) AS payment_mode
     ,CAST(NULL AS STRING) AS access_reuse_choice
     ,CAST(NULL AS STRING) AS access_reuse
     ,CAST(NULL AS STRING) AS current_sfid_id
     ,CAST(NULL AS STRING) AS current_user_store
     ,CAST(NULL AS STRING) AS first_territory_ds
     ,CAST(NULL AS STRING) AS access_ds
     ,CAST(NULL AS STRING) AS iccid
     ,CAST(NULL AS INT64) AS customer_phone_nm
     ,CAST(NULL AS STRING) AS customer_document_type
     ,DEVICES.dig_signature_type_ds
     ,CAST(NULL AS STRING) AS user_cancellation_ds
     ,CAST(NULL AS DATE) AS last_update
     ,CAST(NULL AS DATE) AS last_update_acc_prov

     ,STRUCT(
   
        DATE(DEVICES.order_date) AS activation_date
       ,DEVICES.id_subscription_terminal AS order_id
       ,CAST(DEVICES.id_subscription_terminal AS STRING) AS contract_id

       ,CASE
            WHEN AGRUPACION.agrupacion_canal = 'Exclusivo'
                 AND LENGTH(DEVICES.user_store) > 2
                 AND SUBSTR(DEVICES.sfid_id, 1, 2) <> SUBSTR(DEVICES.user_store, 1, 2)
            THEN DEVICES.user_store

            ELSE UPPER(DEVICES.sfid_id)
        END AS sfid_id

       ,UPPER(DEVICES.user_store) AS user_store

       ,CASE
            WHEN (DEVICES.seller LIKE '%migration%' OR DEVICES.seller LIKE '%ygonline%' OR DEVICES.seller LIKE '%masmovil%')
                 AND (
                     LENGTH(DEVICES.user_store) > 2
                     OR
                     AGRUPACION.agrupacion_canal != 'Exclusivo'
                     )
            THEN DEVICES.user_store

            WHEN DEVICES.seller LIKE '%@asesormasmovil.es'
                 AND AGRUPACION.agrupacion_canal = 'Exclusivo'
                 AND UPPER(SUBSTR(DEVICES.seller, 1, 2)) IN ('AX', 'BY', 'DB', 'DX', 'KH', 'LB', 'LM', 'LX', 'LY', 'MD', 'ML', 'MP', 'MY', 'TA')
            THEN UPPER(SPLIT(DEVICES.seller, '@')[0])
                    
            ELSE DEVICES.seller
        END AS seller

       ,DEVICES.service_type AS technology_ds
       ,COALESCE(DEVICES.original_cost_price, 0.0) AS original_cost_price
       ,DEVICES.total_pay_value
       ,DEVICES.serial_number
       ,DEVICES.financed_init_date
       ,DEVICES.financed_end_date
       ,DEVICES.courier

       ,CASE WHEN DEVICES.is_financed_desc = 'SI' THEN 'PAGO FINANCIADO' ELSE CAST (NULL AS STRING) END AS financed_type

      ) AS DBE_CLEAN

     ,STRUCT(

        SALES_CHANNEL.channel_segment_ds
        
      ) AS SALES_CHANNEL

     ,STRUCT(
        COALESCE(VENTAS_BASE_TELCO.sell_bundle_type, 'MO') AS bundle_type
       ,COALESCE(REPLACE(VENTAS_BASE_TELCO.line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds
       ,COALESCE(VENTAS_BASE_TELCO.billing_type_ds, 'POSTPAID') AS billing_type_ds
       ,COALESCE(VENTAS_BASE_TELCO.technology_ds, 'MOBILE') AS sales_technology_ds
     ) AS SALES_DETAILS

     ,STRUCT(
        DEVICES.serial_number AS serial_number
       ,DEVICES.product_code AS product_code
       ,DEVICES.terminal_name AS terminal_name
       ,VENTAS_BASE_TELCO.contract_id AS contract_id
       ,DEVICES.terminal_status_ds AS terminal_status_ds
       ,DEVICES.tax_value AS tax_value
       ,DEVICES.cost_price_without_vat AS cost_price_without_vat
       ,DEVICES.total_pay_value AS total_pay_value
       ,DEVICES.not_financed_price AS not_financed_price
       ,DEVICES.financed_total_amount AS financed_total_amount
       ,DEVICES.q25_amount AS q25_amount
       ,DEVICES.gross_subsidy_1 AS gross_subsidy_1
     ) AS DEVICE

FROM `mm-datamart-kd.SERVICES.devices_base_emysim` DEVICES

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
          WHERE data_source_ds = 'MYSIM'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
          ) AS SALES_CHANNEL
         ON DEVICES.sfid_id = SALES_CHANNEL.sfid_id

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(SALES_CHANNEL.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND DEVICES.master_channel_ds = AGRUPACION.master_channel_ds
            AND DEVICES.channel_ds = AGRUPACION.channel_ds
            AND DEVICES.subchannel_ds = AGRUPACION.subchannel_ds
            AND DEVICES.comm_brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS_BASE_TELCO
         ON CAST(DEVICES.service_id AS STRING) = VENTAS_BASE_TELCO.service_id AND DEVICES.brand_ds = VENTAS_BASE_TELCO.brand_ds
            AND VENTAS_BASE_TELCO.data_source_ds = 'MYSIM'
            AND DEVICES.data_source_ds = 'MYSIM'

WHERE DEVICES.brand_ds IN ('MASMOVIL', 'YOIGO')
      AND DEVICES.sell_terminal_origin_ds = 'RENUEVO'
      AND (
          expedition_status_ds = 'CONFIRMADA'
          OR (DEVICES.terminal_status_ds = 'FINANCIACION EN CURSO')
          OR (DEVICES.terminal_status_ds = 'USADO')
          )
      AND DEVICES.terminal_status_ds != 'FINANCIACION PENDIENTE' -- 20250616 JOHANNA
        
QUALIFY RANK () OVER (
                     PARTITION BY DEVICES.service_id, DEVICES.serial_number, DEVICES.product_code -- 20250616 JOHANNA: AGREGO SERIAL_NUM PARA ESPECIFICAR CASOS DE 2 DISPOSITIVOS CON MISMO SERVICE_ID
                     ORDER BY CASE
                                  WHEN (DEVICES.terminal_status_ds = 'USADO' OR DEVICES.terminal_status_ds = 'FINANCIACION EN CURSO')
                                  THEN DEVICES.order_date
                              END ASC, -- 20250529 JOHANNA
                                   
                              CASE
                                  WHEN VENTAS_BASE_TELCO.order_date <= DATE(DEVICES.order_date)
                                  THEN COALESCE(VENTAS_BASE_TELCO.order_date, '9999-12-31')
                              END DESC,

                              CASE
                                  WHEN VENTAS_BASE_TELCO.order_date > DATE(DEVICES.order_date)
                                  THEN COALESCE(VENTAS_BASE_TELCO.order_date, '9999-12-31')
                              END ASC,

                              CASE
                                  WHEN COALESCE(VENTAS_BASE_TELCO.activation_date, '9999-12-31') <= DATE(DEVICES.order_date)
                                  THEN COALESCE(VENTAS_BASE_TELCO.activation_date, '9999-12-31')
                              END DESC,

                              CASE
                                  WHEN COALESCE(VENTAS_BASE_TELCO.activation_date, '9999-12-31') > DATE(DEVICES.order_date)
                                  THEN COALESCE(VENTAS_BASE_TELCO.activation_date, '9999-12-31')
                              END ASC,

                              VENTAS_BASE_TELCO.deactivation_date ASC
                     ) = 1 -- Elimina duplicidades en la tabla
)
;


/* Validamos que la tabla modificada de servicios renuevos, del Grupo MasMovil, contiene todos los campos de la tabla de ventas del Grupo MasMovil */
ASSERT NOT EXISTS
(
SELECT
      VENTAS_BASE_TELCO.*

FROM (
     SELECT *
     FROM `mm-datamart-kd.SERVICES.INFORMATION_SCHEMA.COLUMNS`
     WHERE table_name = 'ventas_base_telco_net'
     ) VENTAS_BASE_TELCO

LEFT JOIN (
          SELECT *
          FROM `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.INFORMATION_SCHEMA.COLUMNS`
          WHERE table_name = 'devices_base_emysim_renuevos'
          ) DEVICES_BASE_EMYSIM_RENUEVOS
         ON VENTAS_BASE_TELCO.column_name = devices_base_emysim_renuevos.column_name

WHERE DEVICES_BASE_EMYSIM_RENUEVOS.column_name IS NULL
) AS 'VENTAS BASE TELCO NET contiene columnas no contempladas en la tabla modificada de DEVICES BASE EMYSIM RENUEVOS'
;


/* Montamos la query de creación de la tabla diaria */
SET tabla_nombre = CONCAT('`mm-commissions-reporting.10_CLEANING_COMMISSIONS.','devices_base_emysim_renuevos_', dia_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.devices_base_emysim_renuevos`';
EXECUTE IMMEDIATE qry;


END