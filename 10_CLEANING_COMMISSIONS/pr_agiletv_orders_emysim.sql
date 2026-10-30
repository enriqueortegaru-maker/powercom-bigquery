BEGIN


-- PREPARA LA TABLA DE VENTAS DE AGILE TV DEL GRUPO MASMOVIL PARA EL COMISIONAMIENTO DE SUS SERVICIOS --


/*
CALL `mm-commissions-reporting.10_CLEANING_COMMISSIONS.pr_agiletv_orders_emysim`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE dia_string, qry, tabla_nombre STRING;


SET dia_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Genera la tabla de ventas de Agile TV con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.agiletv_orders_emysim`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      AGILETV.datasource_id
     ,AGILETV.data_source_ds
     ,AGILETV.brand_id
     ,AGILETV.brand_ds
     ,AGILETV.sub_brand_ds
     ,AGILETV.comm_brand_ds
     ,AGILETV.account_id
     ,AGILETV.customer_id
     ,AGILETV.service_id
     ,CAST(NULL AS STRING) AS service_type
     ,CAST(AGILETV.phone_nm AS STRING) AS phone_nm
     ,AGILETV.service_status_ds
     ,CAST(NULL AS STRING) AS order_type_ds
     ,CAST(NULL AS STRING) AS order_type_agg
     ,CAST(NULL AS STRING) AS order_fix_id
     ,CAST(NULL AS STRING) AS order_status_ds
     ,CAST(NULL AS STRING) AS order_id
     ,PARSE_DATE('%Y%m%d', CAST(AGILETV.order_day_id AS STRING)) AS order_date
     ,CAST(NULL AS STRING) AS order_hour_id
     ,AGILETV.cancellation_date
     ,PARSE_DATE('%Y%m%d', CAST(AGILETV.activation_date AS STRING)) AS activation_date 
     ,PARSE_DATE('%Y%m%d', CAST(AGILETV.deactivation_date AS STRING)) AS deactivation_date 
     ,CAST(NULL AS DATE) AS real_deactivation_date 
     ,CAST(NULL AS DATE) AS done_date
     ,AGILETV.segment_ds
     ,CAST(NULL AS STRING) AS sub_segment_ds
     ,AGILETV.sell_tariff_id
     ,AGILETV.sell_tariff_ds
     ,CAST(NULL AS STRING) AS sell_line_type_ds
     ,CAST(NULL AS STRING) AS sell_bundle_id
     ,CAST(NULL AS STRING) AS sell_bundle_name
     ,AGILETV.sell_bundle_type
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,CAST(NULL AS STRING) AS contract_id
     ,AGILETV.sfid_id
     ,AGILETV.user_store
     ,AGILETV.seller_ds AS seller
     ,AGILETV.dealer_code
     ,AGILETV.dealer_campaign_name
     ,AGILETV.subchannel_ds
     ,AGILETV.channel_ds
     ,AGILETV.superchannel_ds
     ,AGILETV.master_channel_ds
     ,AGILETV.channel_type_ds
     ,CAST(NULL AS STRING) AS channel_segment_ds
     ,AGILETV.tariff_id
     ,AGILETV.tariff_ds
     ,AGILETV.line_type_ds
     ,AGILETV.bundle_id
     ,AGILETV.bundle_name
     ,AGILETV.bundle_type
     ,AGILETV.technology_ds
     ,CAST(NULL AS STRING) AS port_in_operator_ds
     ,AGILETV.cancellation_reason AS cancellation_reason_ds
     ,CAST(NULL AS STRING) AS deactivation_reason_ds
     ,AGILETV.sell_type
     ,AGILETV.province
     ,AGILETV.zip_code
     ,CAST(NULL AS STRING) AS terminal_model
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
     ,AGILETV.current_sfid_id
     ,AGILETV.current_user_store
     ,CAST(NULL AS STRING) AS first_territory_ds
     ,CAST(NULL AS STRING) AS access_ds
     ,CAST(NULL AS STRING) AS iccid
     ,CAST(NULL AS INT64) AS customer_phone_nm
     ,CAST(NULL AS STRING) AS customer_document_type
     ,CAST(NULL AS STRING) AS dig_signature_type_ds
     ,CAST(NULL AS STRING) AS user_cancellation_ds
     ,CAST(NULL AS DATE) AS last_update
     ,CAST(NULL AS DATE) AS last_update_acc_prov

     ,STRUCT(

        'TV' AS service_type

       ,ot_actual_bus AS order_fix_id

       ,estado_ot_actual_bus AS order_status_ds

       ,'POSTPAID' AS billing_type_ds

       ,CASE
            WHEN AGRUPACION.agrupacion_canal = 'No Exclusivo'
                 AND (AGILETV.sfid_id LIKE 'MASTER%' OR AGILETV.sfid_id IN ('C02142', 'C02203', 'PH000000'))
            THEN UPPER(SPLIT(AGILETV.seller_ds, '@')[0])

            WHEN AGRUPACION.agrupacion_canal = 'Exclusivo'
                 AND SUBSTR(AGILETV.sfid_id,1,2) <> SUBSTR(AGILETV.user_store,1,2)
            THEN AGILETV.user_store

            ELSE AGILETV.sfid_id
        END AS sfid_id

       ,CASE
            WHEN AGILETV.seller_ds IN ('guukoffline', 'ygoffline', 'ygonline', 'masmovil', 'mmoffline') THEN AGILETV.user_store
            ELSE UPPER(SPLIT(AGILETV.seller_ds, '@')[0])
        END AS seller

       ,CASE WHEN AGILETV.tariff_modality LIKE '%EXT%' THEN 1 ELSE 0 END AS tv_premium

      ) AS ATV_CLEAN

     ,STRUCT(

        VENTAS_BASE_TELCO.channel_segment_ds
        
      ) AS VENTAS_BASE_TELCO_NET

FROM `mm-datamart-kd.SERVICES.agiletv_orders_emysim` AGILETV

LEFT JOIN (
          SELECT sfid_id, channel_segment_ds
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
          WHERE channel_segment_ds IN ('RESIDENCIAL', 'NEGOCIOS')
          GROUP BY 1,2
          ) VENTAS_BASE_TELCO
         ON AGILETV.sfid_id = VENTAS_BASE_TELCO.sfid_id

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(VENTAS_BASE_TELCO.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND AGILETV.master_channel_ds = AGRUPACION.master_channel_ds
            AND AGILETV.channel_ds = AGRUPACION.channel_ds
            AND AGILETV.subchannel_ds = AGRUPACION.subchannel_ds
            AND AGILETV.comm_brand_ds = AGRUPACION.comm_brand_ds

QUALIFY ROW_NUMBER() OVER (PARTITION BY AGILETV.service_id, AGILETV.brand_ds ORDER BY CASE WHEN AGILETV.mac_address_tv IS NOT NULL THEN 1 ELSE 2 END ASC) = 1  -- Elimina duplicidades en la tabla
)
;


/* Validamos que la tabla modificada de servicios Agile TV, del Grupo MasMovil, contiene todos los campos de la tabla de ventas del Grupo MasMovil */
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
          WHERE table_name = 'agiletv_orders_emysim'
          ) AGILETV_ORDERS_EMYSIM
         ON VENTAS_BASE_TELCO.column_name = AGILETV_ORDERS_EMYSIM.column_name

WHERE AGILETV_ORDERS_EMYSIM.column_name IS NULL
) AS 'VENTAS BASE TELCO NET contiene columnas no contempladas en la tabla modificada de AGILE TV ORDERS EMYSIM'
;


/* Montamos la query de creación de la tabla diaria */
SET tabla_nombre = CONCAT('`mm-commissions-reporting.10_CLEANING_COMMISSIONS.','agiletv_orders_emysim', dia_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.agiletv_orders_emysim`';
EXECUTE IMMEDIATE qry;


END