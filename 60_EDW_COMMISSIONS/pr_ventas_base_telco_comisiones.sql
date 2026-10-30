BEGIN


-- PREPARA LA TABLA DE VENTAS CONJUNTA PARA EL COMISIONAMIENTO DE LOS SERVICIOS DEL GRUPO MASORANGE --


/*
CALL `mm-commissions-reporting.60_EDW_COMMISSIONS.pr_ventas_base_telco_comisiones`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE dia_string, qry, tabla_nombre STRING;


SET dia_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Genera la tabla de ventas del Grupo MasOrange con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_comisiones`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      'VENTAS_BASE_TELCO_OSP' AS table_source
     ,VBTO.datasource_id
     ,VBTO.data_source_ds
     ,VBTO.brand_id
     ,VBTO.brand_ds
     ,VBTO.sub_brand_ds
     ,VBTO.comm_brand_ds
     ,VBTO.account_id
     ,VBTO.customer_id
     ,VBTO.service_id
     ,VBTO_CLEAN.service_type
     ,VBTO.phone_nm
     ,VBTO.service_status_ds
     ,VBTO.order_type_ds
     ,VBTO_CLEAN.order_type_agg
     ,VBTO.order_fix_id
     ,VBTO.order_status_ds
     ,VBTO.order_id
     ,VBTO.order_date
     ,VBTO.order_hour_id
     ,VBTO.cancellation_date
     ,VBTO.activation_date
     ,VBTO.deactivation_date
     ,VBTO.real_deactivation_date
     ,VBTO.done_date
     ,VBTO_CLEAN.segment_ds
     ,VBTO.sub_segment_ds
     ,VBTO.sell_tariff_id
     ,VBTO.sell_tariff_ds
     ,VBTO_CLEAN.sell_line_type_ds
     ,VBTO.sell_bundle_id
     ,VBTO.sell_bundle_name
     ,VBTO_CLEAN.sell_bundle_type
     ,VBTO_CLEAN.billing_type_ds
     ,VBTO.contract_id
     ,VBTO.sfid_id
     ,VBTO.user_store
     ,VBTO.seller
     ,VBTO.dealer_code
     ,VBTO.dealer_campaign_name
     ,MAESTRO_CANALES.canal_n2 AS subchannel_ds
     ,MAESTRO_CANALES.canal_n1 AS channel_ds
     ,VBTO.superchannel_ds
     ,MAESTRO_CANALES.canal_n0 AS master_channel_ds
     ,VBTO.channel_type_ds
     ,VBTO_CLEAN.channel_segment_ds
     ,VBTO.tariff_id
     ,VBTO.tariff_ds
     ,VBTO.line_type_ds
     ,VBTO.bundle_id
     ,VBTO.bundle_name
     ,VBTO.bundle_type
     ,VBTO_CLEAN.technology_ds
     ,PORT_IN_OPERADORES.grupo_empresa1 AS port_in_operator_ds
     ,VBTO.cancellation_reason_ds
     ,VBTO.deactivation_reason_ds
     ,VBTO_CLEAN.sell_type
     ,VBTO.province
     ,VBTO.zip_code
     ,VBTO.terminal_model
     ,VBTO.campaign
     ,VBTO.main_service_id
     ,VBTO.flag_data_sharing
     ,VBTO.flag_new_order
     ,VBTO.flag_order

     ,CASE
          WHEN CASE WHEN VBTO.comm_brand_ds = 'UNKNOWN' THEN VBTO.brand_ds ELSE COALESCE(VBTO.comm_brand_ds, VBTO.brand_ds) END = 'JAZZTEL'
          THEN ACTIVIDAD_JAZZTEL.motivo_cancelacion
          
          ELSE VBTO.cancellation_reason_agg
      END AS cancellation_reason_agg

     ,CASE
          WHEN CASE WHEN VBTO.comm_brand_ds = 'UNKNOWN' THEN VBTO.brand_ds ELSE COALESCE(VBTO.comm_brand_ds, VBTO.brand_ds) END = 'JAZZTEL'
          THEN ACTIVIDAD_JAZZTEL.submotivo_cancelacion
          
          ELSE VBTO.cancellation_subreason_agg
      END AS cancellation_subreason_agg

     ,VBTO.customer_document
     ,VBTO.pai
     ,VBTO.payment_mode
     ,VBTO.access_reuse_choice
     ,VBTO.access_reuse
     ,VBTO.current_sfid_id
     ,VBTO.current_user_store
     ,VBTO.first_territory_ds
     ,VBTO.access_ds
     ,VBTO.iccid
     ,VBTO.customer_phone_nm
     ,VBTO.customer_document_type
     ,VBTO.dig_signature_type_ds
     ,VBTO.last_update
     ,VBTO.last_update_acc_prov

     ,CASE WHEN VBTO.sell_tariff_ds LIKE ('MUNDO%') THEN 'MUNDO' ELSE COALESCE(VBTO.comm_brand_ds, VBTO.brand_ds) END AS marca

FROM `mm-commissions-reporting.10_CLEANING_COMMISSIONS.ventas_base_telco_osp_*` VBTO

WHERE _table_suffix = dia_string

UNION ALL

SELECT
      'MIGRATION_CD_BASE_NET' AS table_source
     ,MCBN.datasource_id
     ,MCBN.data_source_ds
     ,MCBN.brand_id
     ,MCBN.brand_ds
     ,MCBN.sub_brand_ds
     ,MCBN.comm_brand_ds
     ,MCBN.account_id
     ,MCBN.customer_id
     ,MCBN.service_id
     ,MCBN_CLEAN.service_type
     ,MCBN_CLEAN.phone_nm
     ,MCBN.service_status_ds
     ,MCBN.order_type_ds
     ,MCBN.order_type_agg
     ,MCBN_CLEAN.order_fix_id
     ,MCBN_CLEAN.order_status_ds
     ,MCBN.order_id
     ,MCBN_CLEAN.order_date
     ,MCBN.order_hour_id
     ,MCBN.cancellation_date
     ,MCBN_CLEAN.activation_date
     ,MCBN_CLEAN.deactivation_date
     ,MCBN.real_deactivation_date
     ,MCBN.done_date
     ,MCBN.segment_ds
     ,MCBN.sub_segment_ds
     ,MCBN.sell_tariff_id
     ,MCBN.sell_tariff_ds
     ,MCBN.sell_line_type_ds
     ,MCBN.sell_bundle_id
     ,MCBN.sell_bundle_name
     ,MCBN.sell_bundle_type
     ,MCBN.billing_type_ds
     ,VENTAS_BASE_TELCO_NET.contract_id
     ,MCBN_CLEAN.sfid_id
     ,MCBN.user_store
     ,MCBN_CLEAN.seller
     ,MCBN.dealer_code
     ,MCBN.dealer_campaign_name
     ,MCBN_CLEAN.subchannel_ds
     ,MCBN_CLEAN.channel_ds
     ,MCBN.superchannel_ds
     ,MCBN_CLEAN.master_channel_ds
     ,MCBN.channel_type_ds
     ,MCBN_CLEAN.channel_segment_ds
     ,MCBN.tariff_id
     ,MCBN.tariff_ds
     ,MCBN.line_type_ds
     ,MCBN.bundle_id
     ,MCBN.bundle_name
     ,MCBN.bundle_type
     ,MCBN_CLEAN.technology_ds
     ,MCBN.port_in_operator_ds
     ,MCBN.cancellation_reason_ds
     ,MCBN.deactivation_reason_ds
     ,MCBN.sell_type
     ,MCBN_CLEAN.province
     ,MCBN.zip_code
     ,MCBN.terminal_model
     ,MCBN.campaign
     ,MCBN.main_service_id
     ,MCBN.flag_data_sharing
     ,MCBN.flag_new_order
     ,MCBN.flag_order
     ,MCBN_CLEAN.cancellation_reason_agg
     ,MCBN_CLEAN.cancellation_subreason_agg
     ,MCBN.customer_document
     ,MCBN.pai
     ,MCBN.payment_mode
     ,MCBN.access_reuse_choice
     ,MCBN.access_reuse
     ,MCBN.current_sfid_id
     ,MCBN.current_user_store
     ,MCBN.first_territory_ds
     ,MCBN.access_ds
     ,MCBN.iccid
     ,MCBN.customer_phone_nm
     ,MCBN.customer_document_type
     ,MCBN.dig_signature_type_ds
     ,MCBN.last_update
     ,MCBN.last_update_acc_prov
     ,MCBN.comm_brand_ds AS marca

FROM `mm-commissions-reporting.10_CLEANING_COMMISSIONS.migration_cd_base_net_*` MCBN

WHERE _table_suffix = dia_string
)
;


/* Validamos que todos los datos de canalización, de la tabla de ventas de comisiones, estén contemplados y configurados en el maestro de agrupacion de canales */
ASSERT NOT EXISTS
(
SELECT
      VENTAS_BASE_COMISIONES.table_source
     ,VENTAS_BASE_COMISIONES.channel_segment_ds
     ,VENTAS_BASE_COMISIONES.master_channel_ds
     ,VENTAS_BASE_COMISIONES.channel_ds
     ,VENTAS_BASE_COMISIONES.subchannel_ds
     ,VENTAS_BASE_COMISIONES.comm_brand_ds

FROM (
     SELECT
           channel_segment_ds
          ,master_channel_ds
          ,channel_ds
          ,subchannel_ds
          ,comm_brand_ds
          ,table_source
     FROM `mm-commissions-reporting.60_EDW_COMMISSIONS.ventas_base_telco_comisiones_*`
     WHERE _table_suffix = dia_string
     GROUP BY 1,2,3,4,5,6
     ) VENTAS_BASE_COMISIONES

LEFT JOIN `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal` CONTROL
         ON COALESCE(VENTAS_BASE_COMISIONES.channel_segment_ds, 'channel_segment_ds') = COALESCE(CONTROL.channel_segment_ds, 'channel_segment_ds')
            AND COALESCE(VENTAS_BASE_COMISIONES.master_channel_ds, 'master_channel_ds') = COALESCE(CONTROL.master_channel_ds, 'master_channel_ds')
            AND VENTAS_BASE_COMISIONES.channel_ds = CONTROL.channel_ds
            AND VENTAS_BASE_COMISIONES.subchannel_ds = CONTROL.subchannel_ds
            AND VENTAS_BASE_COMISIONES.comm_brand_ds = CONTROL.comm_brand_ds

WHERE CONTROL.agrupaciones_canal IS NULL
      AND COALESCE(VENTAS_BASE_COMISIONES.channel_ds, 'DESCONOCIDO') NOT IN ('DESCONOCIDO', 'PENDIENTE DEFINIR')

GROUP BY 1,2,3,4,5,6
) AS 'Existen canales sin configurar en el maestro de agrupaciones de canales'
;


/* Montamos la query de creación de la tabla diaria */
SET tabla_nombre = CONCAT('`mm-commissions-reporting.60_EDW_COMMISSIONS.','ventas_base_telco_comisiones_', dia_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_comisiones`';
EXECUTE IMMEDIATE qry;


END