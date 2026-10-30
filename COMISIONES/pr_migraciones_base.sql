BEGIN


--CALL `mm-commissions-reporting.COMISIONES.pr_migraciones_base`();


DECLARE max_date STRING;

SET max_date = REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -1 DAY) AS STRING), '-', '');

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.migraciones_base` AS

WITH usuario AS 
(
SELECT
      accountid
     ,DATE(createdate) AS createdate
     ,USERSYSTEM.login AS usuario
FROM (SELECT * FROM `mm-dwh-prod.00_SANDBOX_EMYSIM.APOLLO_PROP_ACCOUNTBUNDLE_*` WHERE _table_suffix = max_date) ACCOUNTBUNDLE
INNER JOIN (SELECT * FROM `mm-dwh-prod.00_SANDBOX_EMYSIM.APOLLO_PROP_USERSYSTEM_*` WHERE _table_suffix = max_date) USERSYSTEM 
          ON ACCOUNTBUNDLE.createusersystem = USERSYSTEM.usersystemid
QUALIFY ROW_NUMBER () OVER (PARTITION BY accountid, createdate ORDER BY createdate ASC) = 1
)


SELECT

---- Validacion comisionamiento ----
      `mm-commissions-reporting.COMISIONES.f_identificacion_comisionamiento`(
        MIGRATION.master_channel_ds
       ,MIGRATION.channel_ds
       ,MIGRATION.subchannel_ds
       ,COALESCE(USERSYSTEM.centerid, MIGRATION.sfid_id)
       ,MIGRATION.user_store
       ,MIGRATION.seller
       ,MIGRATION.sell_line_type_ds
       ,MIGRATION.brand_ds
       ,'INTERNET'
       ,COALESCE(MIGRATION.tariff_id, VENTAS.tariff_id, MIGRATION.sell_tariff_id, VENTAS.sell_tariff_id)
       ,COALESCE(MIGRATION.tariff_ds, VENTAS.tariff_ds, MIGRATION.sell_tariff_ds, VENTAS.sell_tariff_ds)
       ,MIGRATION.billing_type_ds
       ,COALESCE(MIGRATION.sell_bundle_type, VENTAS.sell_bundle_type)
      ) as comisionamiento

---- Detalle del servicio -----
     ,MIGRATION.comm_brand_ds AS marca
     ,MIGRATION.brand_ds
     ,MIGRATION.service_id
     ,MIGRATION.account_id
     ,CAST(MIGRATION.customer_id AS STRING) AS customer_id
     ,'INTERNET' AS service_type
     ,MIGRATION.line_type_ds
     ,MIGRATION.sell_bundle_type AS bundle_type
     ,MIGRATION.technology_destination_ds AS technology_ds
     ,MIGRATION.billing_type_ds
     ,CAST(MIGRATION.phone_nm_fix AS STRING) AS phone_nm
     ,DATE(MIGRATION.workorder_created_date, 'Europe/Madrid') AS sale_date
     ,DATE(MIGRATION.workorder_closed_date, 'Europe/Madrid') AS activation_date
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.real_deactivation_date AS STRING)) AS deactivation_date
     ,CAST(MIGRATION.workorder_id AS STRING) AS order_id
     ,MIGRATION.order_type_agg
     ,CAST(NULL AS STRING) AS port_in_operator_ds

---- Detalle de la tarifa ----
     ,COALESCE(MIGRATION.tariff_id, VENTAS.tariff_id, MIGRATION.sell_tariff_id, VENTAS.sell_tariff_id) AS tariff_id
     ,COALESCE(MIGRATION.tariff_ds, VENTAS.tariff_ds, MIGRATION.sell_tariff_ds, VENTAS.sell_tariff_ds) AS tariff_ds

---- Variables analiticas ----
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(MIGRATION.segment_ds, MIGRATION.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(MIGRATION.comm_brand_ds) AS cod_marca

     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
        MIGRATION.billing_type_ds
       ,MIGRATION.service_type
       ,MIGRATION.sell_bundle_type
       ,MIGRATION.technology_destination_ds
       ,MIGRATION.brand_ds
       ,MIGRATION.line_type_ds
      ) AS cod_tipo_contrato
      
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
        MIGRATION.service_type
       ,MIGRATION.brand_ds
       ,MIGRATION.order_type_agg
       ,MIGRATION.sell_type
       ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
        MIGRATION.billing_type_ds
       ,MIGRATION.service_type
       ,MIGRATION.sell_bundle_type
       ,MIGRATION.technology_destination_ds
       ,MIGRATION.brand_ds
       ,MIGRATION.line_type_ds
      )
      ) AS cod_producto
      
     ,AGRUPACION.codigo_canal_sap AS cod_canal
     --,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(MIGRATION.channel_segment_ds, MIGRATION.channel_ds, MIGRATION.subchannel_ds) AS agrupacion_canal
     ,AGRUPACION.agrupacion_canal
---- Detalle del vendedor ----
     ,COALESCE(
              CASE
                  WHEN MIGRATION.data_source_ds = 'QVANTEL' THEN SUBSTR(MIGRATION.seller,1,2)

                  WHEN MIGRATION.sfid_id IN ('C00001', 'MASSTACK-REPOS') AND LENGTH(MIGRATION.user_store) >= 8 THEN MIGRATION.user_store

                  WHEN MIGRATION.sfid_id = 'LB'
                       AND MIGRATION.seller LIKE '%@%'
                       AND (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])) NOT IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
                  THEN UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])

                  WHEN (MIGRATION.sfid_id LIKE 'MASTER%' OR MIGRATION.sfid_id IN ('C02142', 'C03400', 'PH000000'))
                       AND (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])) NOT IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
                       THEN UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])
              END,

              CASE
                  WHEN USERSYSTEM.centerid IN ('C00001', 'MASSTACK-REPOS')                    THEN NULL
                  WHEN USERSYSTEM.centerid LIKE 'MASTER%' AND LENGTH(USERSYSTEM.centerid) = 8 THEN NULL
                  ELSE USERSYSTEM.centerid
              END,

              CASE WHEN MIGRATION.sfid_id IN ('MASSTACK-REPOS')                            THEN NULL
                   WHEN MIGRATION.sfid_id LIKE 'MASTER%' AND LENGTH(MIGRATION.sfid_id) = 8 THEN NULL
                   ELSE MIGRATION.sfid_id
              END,

              MIGRATION.user_store
              ) AS sfid_id

     ,COALESCE(
              CASE
                  WHEN MIGRATION.sfid_id IN ('C00001', 'MASSTACK-REPOS') AND LENGTH(MIGRATION.user_store) >= 8 THEN MIGRATION.user_store

                  WHEN MIGRATION.sfid_id = 'LB'
                       AND MIGRATION.seller LIKE '%@%'
                       AND (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])) NOT IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
                  THEN UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])

                  WHEN (MIGRATION.sfid_id LIKE 'MASTER%' OR MIGRATION.sfid_id IN ('C02142', 'C03400', 'PH000000'))
                       AND (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])) NOT IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
                  THEN UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])
              END,

              CASE
                  WHEN (UPPER(SPLIT(USUARIO.usuario, "@")[OFFSET(0)])) IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
                  THEN NULL

                  WHEN USUARIO.usuario LIKE 'MASTER%' AND LENGTH(USUARIO.usuario) = 8                                 THEN NULL
                  WHEN USUARIO.usuario LIKE '%@%'                                                                     THEN (UPPER(SPLIT(USUARIO.usuario, "@")[OFFSET(0)]))
                  ELSE USUARIO.usuario
              END,

              CASE
                  WHEN (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)])) IN ('ANGEL.LOPEZL', 'GUUKOFFLINE', 'MASMOVIL', 'MASSTACK-REPOS', 'MMOFFLINE')
                  THEN NULL

                  WHEN MIGRATION.seller LIKE 'MASTER%' AND LENGTH(MIGRATION.seller) = 8                                THEN NULL
                  WHEN MIGRATION.seller LIKE '%@%'                                                                     THEN (UPPER(SPLIT(MIGRATION.seller, "@")[OFFSET(0)]))
                  ELSE MIGRATION.seller
              END,

              MIGRATION.user_store
              ) AS seller

     ,CAST(NULL AS STRING) AS channel_ds
     ,MIGRATION.workorder_id AS order_fix_id
     ,CAST(NULL AS STRING) AS claim_code
     ,'Migracion' AS comments
     ,VENTAS.contract_id AS contract_id
     ,MIGRATION.data_source_ds
     ,CAST(NULL AS STRING) AS portability_group_donor
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,CAST(NULL AS STRING) AS flag_order
     ,MIGRATION.segment_ds
     ,MIGRATION.user_store
     ,MIGRATION.subchannel_ds
     ,PARSE_DATE('%Y%m%d', CAST(MIGRATION.cancellation_day_id AS STRING)) AS cancellation_day_id
     ,MIGRATION.sell_type
     ,CAST(NULL AS STRING) AS province
     ,CAST(NULL AS STRING) AS zip_code
     ,CAST(NULL AS STRING) AS terminal_model
     ,CAST(NULL AS STRING) AS sva_tv
     ,MIGRATION.channel_segment_ds
     ,MIGRATION.master_channel_ds
     ,MIGRATION.channel_type_ds
     ,CAST(NULL AS STRING) AS hash_document_number
     ,cancellation_reason_provision_ds AS cancellation_reason_agg
     ,cancellation_reason_provision_ds AS cancellation_subreason_agg
     ,CAST(NULL AS DATE) AS max_appointment_date
     ,CAST(NULL AS STRING) AS billing_tier
     ,CAST(NULL AS STRING) AS qvantel_service_id
     ,0 AS post_pre_flag

FROM `mm-datamart-kd.SERVICES.migration_cd_base_net` MIGRATION

LEFT JOIN usuario USUARIO
         ON DATE(MIGRATION.workorder_closed_date) = USUARIO.createdate
            AND CAST(USUARIO.accountid AS STRING) = MIGRATION.account_id
            AND MIGRATION.brand_ds IN ('MASMOVIL', 'LLAMAYA', 'GUUK')

LEFT JOIN (SELECT * FROM `mm-dwh-prod.00_SANDBOX_EMYSIM.APOLLO_PROP_USERSYSTEM_*` WHERE _table_suffix = max_date) USERSYSTEM
          ON COALESCE(USUARIO.usuario, MIGRATION.seller) = USERSYSTEM.login

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` VENTAS
         ON MIGRATION.service_id = VENTAS.service_id
            AND VENTAS.service_type = 'FIX'
            AND (MIGRATION.workorder_id = VENTAS.order_fix_id OR DATE(workorder_closed_date, 'Europe/Madrid') = VENTAS.activation_date)

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(MIGRATION.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND MIGRATION.master_channel_ds = AGRUPACION.master_channel_ds
            AND MIGRATION.channel_ds = AGRUPACION.channel_ds
            AND MIGRATION.subchannel_ds = AGRUPACION.subchannel_ds
            AND MIGRATION.comm_brand_ds = AGRUPACION.comm_brand_ds
            
WHERE 1 = 1
      AND MIGRATION.billing_type_ds = 'POSTPAID'
      AND MIGRATION.brand_ds IN ('MASMOVIL', 'PEPEPHONE', 'YOIGO', 'LLAMAYA', 'GUUK')
      AND MIGRATION.workorder_name NOT IN ('MIG_COM')
      AND MIGRATION.order_type_agg IN ('CAMBIO DOMICILIO', 'CAMBIO TECNOLOGIA')

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY service_id, service_type, brand_ds, DATE_TRUNC(DATE(workorder_closed_date, 'Europe/Madrid'), MONTH)
                          ORDER BY activation_date DESC
                          ) = 1
;


END