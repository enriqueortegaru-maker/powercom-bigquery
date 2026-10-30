BEGIN


-- PREPARA LA TABLA DE CAMBIOS DE DOMICILIO Y CAMBIOS DE TECNOLOGÍA DEL GRUPO MASMOVIL PARA EL COMISIONAMIENTO DE SUS SERVICIOS --


/*
CALL `mm-commissions-reporting.10_CLEANING_COMMISSIONS.pr_migration_cd_base_net`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE dia_string, qry, tabla_nombre STRING;


SET dia_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Genera la tabla de cambios de domicilio y cambios de tecnología del Grupo MasMovil con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.migration_cd_base_net`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      MIGRATION.datasource_id
     ,MIGRATION.data_source_ds
     ,MIGRATION.brand_id
     ,MIGRATION.brand_ds
     ,MIGRATION.sub_brand_ds
     ,MIGRATION.comm_brand_ds
     ,MIGRATION.account_id
     ,CAST(MIGRATION.customer_id AS STRING) AS customer_id
     ,MIGRATION.service_id
     ,MIGRATION.service_type
     ,CAST(NULL AS INT64) AS phone_nm
     ,CAST(NULL AS STRING) AS service_status_ds
     ,MIGRATION.order_type_ds
     ,MIGRATION.order_type_agg
     ,CAST(NULL AS STRING) AS order_fix_id
     ,CAST(NULL AS STRING) AS order_status_ds
     ,CAST(NULL AS STRING) AS order_id
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.order_day_id AS STRING)) AS order_date
     ,CAST(NULL AS STRING) AS order_hour_id
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.cancellation_day_id AS STRING)) AS cancellation_date
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.activation_date AS STRING)) AS activation_date 
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.deactivation_date AS STRING)) AS deactivation_date 
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.real_deactivation_date AS STRING)) AS real_deactivation_date 
     ,CAST(NULL AS DATE) AS done_date
     ,MIGRATION.segment_ds
     ,CAST(NULL AS STRING) AS sub_segment_ds
     ,MIGRATION.sell_tariff_id
     ,MIGRATION.sell_tariff_ds
     ,MIGRATION.sell_line_type_ds
     ,CAST(NULL AS STRING) AS sell_bundle_id
     ,CAST(NULL AS STRING) AS sell_bundle_name
     ,MIGRATION.sell_bundle_type
     ,MIGRATION.billing_type_ds
     ,CAST(NULL AS STRING) AS contract_id
     ,MIGRATION.sfid_id
     ,MIGRATION.user_store
     ,MIGRATION.seller
     ,MIGRATION.dealer_code
     ,MIGRATION.dealer_campaign_name
     ,MIGRATION.subchannel_ds
     ,MIGRATION.channel_ds
     ,MIGRATION.superchannel_ds
     ,MIGRATION.master_channel_ds
     ,MIGRATION.channel_type_ds
     ,MIGRATION.channel_segment_ds
     ,MIGRATION.tariff_id
     ,MIGRATION.tariff_ds
     ,MIGRATION.line_type_ds
     ,CAST(NULL AS INT64) AS bundle_id
     ,CAST(NULL AS STRING) AS bundle_name
     ,MIGRATION.bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS port_in_operator_ds
     ,CAST(NULL AS STRING) AS cancellation_reason_ds
     ,CAST(NULL AS STRING) AS deactivation_reason_ds
     ,MIGRATION.sell_type
     ,CAST(NULL AS STRING) AS province
     ,CAST(NULL AS STRING) AS zip_code
     ,CAST(NULL AS STRING) AS terminal_model
     ,CAST(NULL AS STRING) AS campaign
     ,CAST(NULL AS STRING) AS main_service_id
     ,CAST(NULL AS INT64) AS flag_data_sharing
     ,MIGRATION.flag_new_order
     ,MIGRATION.flag_order
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
     ,CAST(NULL AS STRING) AS dig_signature_type_ds
     ,CAST(NULL AS STRING) AS user_cancellation_ds
     ,CAST(NULL AS DATE) AS last_update
     ,CAST(NULL AS DATE) AS last_update_acc_prov

     ,STRUCT(
        
        'BROADBAND' AS service_type

       ,CAST(MIGRATION.phone_nm_fix AS INT64) AS phone_nm

       ,MIGRATION.workorder_id AS order_fix_id

       ,MIGRATION.workorder_status_ds AS order_status_ds

       ,DATE(MIGRATION.workorder_created_date, 'Europe/Madrid') AS order_date

       ,DATE(MIGRATION.workorder_closed_date, 'Europe/Madrid') AS activation_date

       ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.real_deactivation_date AS STRING)) AS deactivation_date

       ,MIGRATION.user_store AS sfid_id

       ,COALESCE(
          CASE
              WHEN MIGRATION.sfid_id = 'LB'
                   AND MIGRATION.seller LIKE '%@%'
                   AND (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)]))
                       NOT IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
              THEN UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])

              WHEN (MIGRATION.sfid_id LIKE 'MASTER%' OR MIGRATION.sfid_id IN ('C02142', 'C03400', 'PH000000'))
                   AND MIGRATION.seller LIKE '%@%'
                   AND (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)]))
                       NOT IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
              THEN UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])
          END,

          MIGRATION.user_store
        ) AS seller

       ,CASE WHEN MIGRATION.subchannel_ds LIKE 'SFID UNKNOWN%' THEN 'DESCONOCIDO' ELSE MIGRATION.subchannel_ds END AS subchannel_ds

       ,CASE WHEN MIGRATION.channel_ds LIKE 'SFID UNKNOWN%' THEN 'DESCONOCIDO' ELSE MIGRATION.channel_ds END AS channel_ds

       ,CASE WHEN MIGRATION.master_channel_ds LIKE 'SFID UNKNOWN%' THEN 'DESCONOCIDO' ELSE MIGRATION.master_channel_ds END AS master_channel_ds

       ,CASE
            WHEN MIGRATION.channel_segment_ds = ""                 THEN 'DESCONOCIDO'
            WHEN MIGRATION.channel_segment_ds LIKE 'SFID UNKNOWN%' THEN 'DESCONOCIDO'
            ELSE MIGRATION.channel_segment_ds
        END AS channel_segment_ds

       --,COALESCE(MIGRATION.tariff_id, MIGRATION.sell_tariff_id) AS tariff_id
       --,COALESCE(MIGRATION.tariff_ds, MIGRATION.sell_tariff_ds) AS tariff_ds
       --,MIGRATION.sell_bundle_type AS bundle_type
       ,MIGRATION.technology_destination_ds AS technology_ds

       ,MIGRATION.install_province AS province

       ,MIGRATION.cancellation_reason_provision_ds AS cancellation_reason_agg

       ,MIGRATION.cancellation_reason_provision_ds AS cancellation_subreason_agg

      ) AS MCBN_CLEAN

     ,STRUCT(

        VENTAS_BASE_TELCO.contract_id
        
      ) AS VENTAS_BASE_TELCO_NET

FROM `mm-datamart-kd.SERVICES.migration_cd_base_net` MIGRATION

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS_BASE_TELCO
         ON CASE WHEN MIGRATION.comm_brand_ds = 'PEPEPHONE' THEN CAST(MIGRATION.service_id AS STRING) ELSE CAST(MIGRATION.phone_nm_fix AS STRING) END
            =
            CASE WHEN VENTAS_BASE_TELCO.comm_brand_ds = 'PEPEPHONE' THEN CAST(VENTAS_BASE_TELCO.service_id AS STRING) ELSE CAST(VENTAS_BASE_TELCO.phone_nm AS STRING) END
            AND MIGRATION.brand_ds = VENTAS_BASE_TELCO.brand_ds
            AND MIGRATION.cancellation_day_id IS NULL
            AND MIGRATION.workorder_closed_date IS NOT NULL
            AND VENTAS_BASE_TELCO.activation_date IS NOT NULL
            AND DATE(MIGRATION.workorder_closed_date, 'Europe/Madrid') <= VENTAS_BASE_TELCO.activation_date 
            AND VENTAS_BASE_TELCO.service_type = 'BROADBAND'

WHERE MIGRATION.order_type_agg IN ('CAMBIO DOMICILIO', 'CAMBIO TECNOLOGIA')
      AND MIGRATION.comm_brand_ds IN ('MASMOVIL', 'PEPEPHONE', 'YOIGO', 'LLAMAYA', 'GUUK')
      AND MIGRATION.billing_type_ds = 'POSTPAID'
      AND MIGRATION.phone_nm_fix IS NOT NULL
      AND MIGRATION.workorder_name NOT IN ('MIG_COM')

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY MIGRATION.service_id, MCBN_CLEAN.phone_nm, MIGRATION.comm_brand_ds, DATE_TRUNC(COALESCE(MCBN_CLEAN.activation_date, '1969-01-01'), MONTH)
                          ORDER BY COALESCE(MCBN_CLEAN.activation_date, '1969-01-01') DESC,
                                   MCBN_CLEAN.order_date DESC,

                                   CASE
                                       WHEN PARSE_DATE('%Y%m%d', CAST(MIGRATION.cancellation_day_id AS STRING)) IS NULL THEN 1 ELSE 2
                                   END ASC,

                                   ABS(DATE_DIFF(DATE(workorder_closed_date, 'Europe/Madrid'), VENTAS_BASE_TELCO.activation_date, DAY)) ASC,
                                   
                                   CASE
                                       WHEN VENTAS_BASE_TELCO.service_status_ds = 'SUSPENDIDO O PROHIBIDO' THEN 2 ELSE 1
                                   END ASC,

                                   COALESCE(VENTAS_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                   VENTAS_BASE_TELCO.service_id DESC   
                          ) = 1  -- Elimina duplicidades en la tabla
)
;


/* Validamos que la tabla de cambios de domicilio y cambios de tecnología modificada del Grupo MasMovil contiene todos los campos de la tabla de ventas del Grupo MasMovil */
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
          WHERE table_name = 'migration_cd_base_net'
          ) MIGRATION_CD_BASE_NET
         ON VENTAS_BASE_TELCO.column_name = MIGRATION_CD_BASE_NET.column_name

WHERE MIGRATION_CD_BASE_NET.column_name IS NULL
) AS 'VENTAS BASE TELCO NET contiene columnas no contempladas en la tabla modificada de MIGRATION CD BASE NET'
;


/* Montamos la query de creación de la tabla diaria */
SET tabla_nombre = CONCAT('`mm-commissions-reporting.10_CLEANING_COMMISSIONS.','migration_cd_base_net_', dia_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.migration_cd_base_net`';
EXECUTE IMMEDIATE qry;


END