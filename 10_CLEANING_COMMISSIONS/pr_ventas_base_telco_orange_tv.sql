BEGIN


-- PREPARA LA TABLA DE VENTAS DE ORANGE TV DEL GRUPO MASMOVIL PARA EL COMISIONAMIENTO DE SUS SERVICIOS --


/*
CALL `mm-commissions-reporting.10_CLEANING_COMMISSIONS.pr_ventas_base_telco_orange_tv`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE dia_string, qry, tabla_nombre STRING;


SET dia_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Genera la tabla de ventas de Orange TV con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_orange_tv`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      VENTAS_BASE_TELCO.datasource_id
     ,VENTAS_BASE_TELCO.data_source_ds
     ,VENTAS_BASE_TELCO.brand_id
     ,VENTAS_BASE_TELCO.brand_ds
     ,VENTAS_BASE_TELCO.sub_brand_ds
     ,VENTAS_BASE_TELCO.comm_brand_ds
     ,VENTAS_BASE_TELCO.account_id
     ,VENTAS_BASE_TELCO.customer_id
     ,VENTAS_BASE_TELCO.service_id
     ,VENTAS_BASE_TELCO.service_type
     ,CAST(VENTAS_BASE_TELCO.phone_nm AS STRING) AS phone_nm
     ,VENTAS_BASE_TELCO.service_status_ds
     ,VENTAS_BASE_TELCO.order_type_ds
     ,VENTAS_BASE_TELCO.order_type_agg
     ,VENTAS_BASE_TELCO.order_fix_id
     ,VENTAS_BASE_TELCO.order_status_ds
     ,VENTAS_BASE_TELCO.order_id
     ,VENTAS_BASE_TELCO.order_date
     ,VENTAS_BASE_TELCO.order_hour_id
     ,VENTAS_BASE_TELCO.cancellation_date
     ,VENTAS_BASE_TELCO.activation_date 
     ,VENTAS_BASE_TELCO.deactivation_date 
     ,VENTAS_BASE_TELCO.real_deactivation_date 
     ,VENTAS_BASE_TELCO.done_date
     ,VENTAS_BASE_TELCO.segment_ds
     ,VENTAS_BASE_TELCO.sub_segment_ds
     ,VENTAS_BASE_TELCO.sell_tariff_id
     ,VENTAS_BASE_TELCO.sell_tariff_ds
     ,VENTAS_BASE_TELCO.sell_line_type_ds
     ,VENTAS_BASE_TELCO.sell_bundle_id
     ,VENTAS_BASE_TELCO.sell_bundle_name
     ,VENTAS_BASE_TELCO.sell_bundle_type
     ,VENTAS_BASE_TELCO.billing_type_ds
     ,VENTAS_BASE_TELCO.contract_id
     ,VENTAS_BASE_TELCO.sfid_id
     ,VENTAS_BASE_TELCO.user_store
     ,VENTAS_BASE_TELCO.seller
     ,VENTAS_BASE_TELCO.dealer_code
     ,VENTAS_BASE_TELCO.dealer_campaign_name
     ,VENTAS_BASE_TELCO.subchannel_ds
     ,VENTAS_BASE_TELCO.channel_ds
     ,VENTAS_BASE_TELCO.superchannel_ds
     ,VENTAS_BASE_TELCO.master_channel_ds
     ,VENTAS_BASE_TELCO.channel_type_ds
     ,VENTAS_BASE_TELCO.channel_segment_ds
     ,VENTAS_BASE_TELCO.tariff_id
     ,VENTAS_BASE_TELCO.tariff_ds
     ,VENTAS_BASE_TELCO.line_type_ds
     ,VENTAS_BASE_TELCO.bundle_id
     ,VENTAS_BASE_TELCO.bundle_name
     ,VENTAS_BASE_TELCO.bundle_type
     ,VENTAS_BASE_TELCO.technology_ds
     ,VENTAS_BASE_TELCO.port_in_operator_ds
     ,VENTAS_BASE_TELCO.cancellation_reason_ds
     ,VENTAS_BASE_TELCO.deactivation_reason_ds
     ,VENTAS_BASE_TELCO.sell_type
     ,VENTAS_BASE_TELCO.province
     ,VENTAS_BASE_TELCO.zip_code
     ,VENTAS_BASE_TELCO.terminal_model
     ,VENTAS_BASE_TELCO.campaign
     ,VENTAS_BASE_TELCO.main_service_id
     ,VENTAS_BASE_TELCO.flag_data_sharing
     ,VENTAS_BASE_TELCO.flag_new_order
     ,VENTAS_BASE_TELCO.flag_order
     ,VENTAS_BASE_TELCO.cancellation_reason_agg
     ,VENTAS_BASE_TELCO.cancellation_subreason_agg
     ,VENTAS_BASE_TELCO.customer_document
     ,VENTAS_BASE_TELCO.pai
     ,VENTAS_BASE_TELCO.payment_mode
     ,VENTAS_BASE_TELCO.access_reuse_choice
     ,VENTAS_BASE_TELCO.access_reuse
     ,VENTAS_BASE_TELCO.current_sfid_id
     ,VENTAS_BASE_TELCO.current_user_store
     ,VENTAS_BASE_TELCO.first_territory_ds
     ,VENTAS_BASE_TELCO.access_ds
     ,VENTAS_BASE_TELCO.iccid
     ,VENTAS_BASE_TELCO.customer_phone_nm
     ,VENTAS_BASE_TELCO.customer_document_type
     ,VENTAS_BASE_TELCO.dig_signature_type_ds
     ,VENTAS_BASE_TELCO.user_cancellation_ds
     ,VENTAS_BASE_TELCO.last_update
     ,VENTAS_BASE_TELCO.last_update_acc_prov

     ,STRUCT(

        VENTAS_BASE_TELCO.sell_tariff_ds AS tariff_ds

       ,CASE
            WHEN AGRUPACION.agrupacion_canal = 'Exclusivo' AND VENTAS_BASE_TELCO.sfid_id IN ('LB', 'LBL')
            THEN UPPER(VENTAS_BASE_TELCO.user_store)

            WHEN AGRUPACION.agrupacion_canal = 'No Exclusivo'
                 AND (
                     (VENTAS_BASE_TELCO.sfid_id LIKE 'MASTER%' AND LENGTH(VENTAS_BASE_TELCO.sfid_id) <= 8)
                     OR VENTAS_BASE_TELCO.sfid_id IN ('C02142', 'C02203', 'M20', 'MRG', 'PH000000', 'TPH')
                     )
            THEN UPPER(VENTAS_BASE_TELCO.user_store)

            ELSE UPPER(VENTAS_BASE_TELCO.sfid_id)
        END AS sfid_id

       ,CASE
            WHEN AGRUPACION.agrupacion_canal = 'Exclusivo' AND VENTAS_BASE_TELCO.sfid_id IN ('LB', 'LBL')
            THEN UPPER(VENTAS_BASE_TELCO.user_store)
  
            WHEN AGRUPACION.agrupacion_canal = 'No Exclusivo'
                 AND (
                     (VENTAS_BASE_TELCO.sfid_id LIKE 'MASTER%' AND LENGTH(VENTAS_BASE_TELCO.sfid_id) <= 8)
                     OR VENTAS_BASE_TELCO.sfid_id IN ('C02142', 'C02203', 'M20', 'MRG', 'PH000000', 'TPH')
                     )
            THEN UPPER(VENTAS_BASE_TELCO.user_store)
  
            ELSE UPPER(VENTAS_BASE_TELCO.sfid_id)
        END AS seller

       ,CASE WHEN UPPER(VENTAS_BASE_TELCO.sell_tariff_ds) LIKE '%DEPORTE%' THEN 1 ELSE 0 END AS tv_premium

      ) AS VBT_CLEAN

     ,STRUCT(

        DETAILS.service_id

       ,CAST(DETAILS.phone_nm AS STRING) AS phone_nm

       ,CASE
            WHEN DETAILS.bundle_type IN ('2P', 'FMC', 'MO')                                THEN DETAILS.bundle_type
            WHEN DETAILS.bundle_type LIKE ('%M%') AND DETAILS.bundle_type LIKE ('%B%')     THEN 'FMC'
            WHEN DETAILS.bundle_type LIKE ('%M%') AND DETAILS.bundle_type NOT LIKE ('%B%') THEN 'MO'
            WHEN DETAILS.bundle_type NOT LIKE ('%M%') AND DETAILS.bundle_type LIKE ('%B%') THEN '2P'
        END AS bundle_type

       ,DETAILS.technology_ds
        
      ) AS SERVICE_DETAILS

FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS_BASE_TELCO

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(VENTAS_BASE_TELCO.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND VENTAS_BASE_TELCO.master_channel_ds = AGRUPACION.master_channel_ds
            AND VENTAS_BASE_TELCO.channel_ds = AGRUPACION.channel_ds
            AND VENTAS_BASE_TELCO.subchannel_ds = AGRUPACION.subchannel_ds
            AND VENTAS_BASE_TELCO.comm_brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` DETAILS
         ON VENTAS_BASE_TELCO.account_id = DETAILS.account_id AND VENTAS_BASE_TELCO.brand_ds = DETAILS.brand_ds
            AND DETAILS.data_source_ds = 'MYSIM'
            AND DETAILS.service_type IN ('BROADBAND', 'FIX', 'MOBILE')

WHERE VENTAS_BASE_TELCO.service_type IN ('ORANGE TV')
        
QUALIFY RANK() OVER (
                    PARTITION BY VENTAS_BASE_TELCO.service_id, VENTAS_BASE_TELCO.brand_ds
                    ORDER BY
                            CASE
                                WHEN DETAILS.service_type = 'BROADBAND' THEN 1
                                WHEN DETAILS.service_type = 'FIX'       THEN 2
                                ELSE 3
                            END ASC

                           ,CASE
                                WHEN COALESCE(VENTAS_BASE_TELCO.activation_date, VENTAS_BASE_TELCO.order_date) BETWEEN DETAILS.order_date
                                     AND COALESCE(DETAILS.deactivation_date, DETAILS.cancellation_date, '9999-12-31') THEN 1
                                ELSE 2
                            END ASC

                           ,ABS(DATE_DIFF(COALESCE(DETAILS.activation_date, DETAILS.order_date), COALESCE(VENTAS_BASE_TELCO.activation_date, VENTAS_BASE_TELCO.order_date), DAY)) ASC
                    ) = 1 -- Elimina duplicidades en la tabla
)
;


/* Validamos que la tabla modificada de servicios Orange TV, del Grupo MasMovil, contiene todos los campos de la tabla de ventas del Grupo MasMovil */
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
          WHERE table_name = 'ventas_base_telco_orange_tv'
          ) VENTAS_BASE_TELCO_ORANGE_TV
         ON VENTAS_BASE_TELCO.column_name = VENTAS_BASE_TELCO_ORANGE_TV.column_name

WHERE VENTAS_BASE_TELCO_ORANGE_TV.column_name IS NULL
) AS 'VENTAS BASE TELCO NET contiene columnas no contempladas en la tabla modificada de VENTAS BASE ORANGE TV'
;


/* Montamos la query de creación de la tabla diaria */
SET tabla_nombre = CONCAT('`mm-commissions-reporting.10_CLEANING_COMMISSIONS.','ventas_base_telco_orange_tv_', dia_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_orange_tv`';
EXECUTE IMMEDIATE qry;


END