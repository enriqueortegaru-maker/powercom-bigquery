BEGIN


-- PREPARA LA TABLA DE VENTAS DEL GRUPO MASMOVIL PARA EL COMISIONAMIENTO DE SUS SERVICIOS --


/*
CALL `mm-commissions-reporting.10_CLEANING_COMMISSIONS.pr_ventas_base_telco_net`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE mes_string, qry, tabla_nombre STRING;


SET mes_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Creamos una tabla temporal que permite traducir la clasificación antigua de canales provenientes del Grupo MasMovil a la clasificación de MasOrange */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbtn_maestro_canales_masorange`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      UPPER(channel_segment_ds) AS channel_segment_ds
     ,UPPER(sfid_sale_type_tdmk_a_des) AS sfid_sale_type_tdmk_a_des
     ,UPPER(sfid_sale_type_tdmk_b_des) AS sfid_sale_type_tdmk_b_des
     ,canal_n0_masorange AS canal_n0
     ,canal_n1_masorange AS canal_n1
     ,canal_n2_masorange AS canal_n2
     
FROM `mm-sales-reporting.MASTERS.maestro_canales_masorange`

WHERE sfid_sale_type_tdmk_a_des IS NOT NULL

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY COALESCE(channel_segment_ds, 'channel_segment_ds'), sfid_sale_type_tdmk_a_des, sfid_sale_type_tdmk_b_des
                          ORDER BY canal_n0_masorange, canal_n1_masorange, canal_n2_masorange
                          ) = 1 -- Elimina duplicidades en la Google Sheet
)
;


/* Creamos una tabla temporal que contiene el listado de operadores donantes posibles y su detalle; para poder indentificar el operador padre de un servicio portado */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbtn_port_in_operadores`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      'GMM' AS origin
     ,operador
     ,marca_unificada
     ,grupo_empresa1

FROM `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado`

QUALIFY ROW_NUMBER() OVER (PARTITION BY origin, operador ORDER BY grupo_empresa1) = 1 -- Elimina duplicidades en la Google Sheet

UNION ALL

SELECT
      'MASORANGE' AS origin
     ,operador
     ,marca_unificada
     ,grupo_empresa AS grupo_empresa1

FROM `mm-sales-reporting.SPREADSHEETS.port_in_operadores_MASORANGE`

QUALIFY ROW_NUMBER() OVER (PARTITION BY origin, operador ORDER BY grupo_empresa) = 1 -- Elimina duplicidades en la Google Sheet
)
;


/* Creamos una tabla temporal que permite recuperar el detalle de la venta en los casos donde se da de alta un servicio fijo con un número provisional y luego se modifica al definitivo y en MYSIM se generan dos eventos (dos service_id distintos). Cuando MYSIM da de alta */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbtn_cambio_numero`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT *

FROM (
     SELECT
           VENTAS_BASE.comm_brand_ds
          ,VENTAS_BASE.customer_id
          ,VENTAS_BASE.account_id AS account_id_original
           
          ,CASE
               WHEN VENTAS_BASE.deactivation_date IS NOT NULL AND VENTAS_BASE.deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
               THEN LEAD(VENTAS_BASE.account_id) OVER (
                                                      PARTITION BY VENTAS_BASE.comm_brand_ds, VENTAS_BASE.customer_id, VENTAS_BASE.service_type
                                                      ORDER BY VENTAS_BASE.activation_date ASC,
                                                               CASE
                                                                   WHEN VENTAS_BASE.deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
                                                                   THEN 1 ELSE 2
                                                               END ASC
                                                      )
           END AS account_id
         
          ,VENTAS_BASE.service_id AS service_id_original
           
          ,CASE
               WHEN VENTAS_BASE.deactivation_date IS NOT NULL AND VENTAS_BASE.deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
               THEN LEAD(VENTAS_BASE.service_id) OVER (
                                                      PARTITION BY VENTAS_BASE.comm_brand_ds, VENTAS_BASE.customer_id, VENTAS_BASE.service_type
                                                      ORDER BY VENTAS_BASE.activation_date ASC,
                                                               CASE
                                                                   WHEN VENTAS_BASE.deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
                                                                   THEN 1 ELSE 2
                                                               END ASC
                                                      )
           END AS service_id
         
          ,VENTAS_BASE.phone_nm AS phone_nm_original
           
          ,CASE
               WHEN VENTAS_BASE.deactivation_date IS NOT NULL AND VENTAS_BASE.deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
               THEN LEAD(VENTAS_BASE.phone_nm) OVER (
                                                    PARTITION BY VENTAS_BASE.comm_brand_ds, VENTAS_BASE.customer_id, VENTAS_BASE.service_type
                                                    ORDER BY VENTAS_BASE.activation_date ASC,
                                                             CASE
                                                                 WHEN VENTAS_BASE.deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
                                                                 THEN 1 ELSE 2
                                                             END ASC
                                                    )
           END AS phone_nm
     
          ,VENTAS_BASE.service_type
          ,VENTAS_BASE.sfid_id AS sfid_id_original
          ,VENTAS_BASE.user_store AS user_store_original
          ,VENTAS_BASE.seller AS seller_original
          ,VENTAS_BASE.subchannel_ds AS subchannel_ds_original
          ,VENTAS_BASE.channel_ds AS channel_ds_original
          ,VENTAS_BASE.superchannel_ds AS superchannel_ds_original
          ,VENTAS_BASE.master_channel_ds AS master_channel_ds_original
          ,VENTAS_BASE.channel_segment_ds AS channel_segment_ds_original
          ,VENTAS_BASE.current_sfid_id AS current_sfid_id_original
          ,VENTAS_BASE.current_user_store AS current_user_store_original
      
     FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS_BASE
     
     INNER JOIN (
                SELECT customer_id, comm_brand_ds, service_type
                FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                WHERE activation_date >= '2024-09-01'
                      AND deactivation_reason_ds = 'CAMBIO NUMERO A DEFINITIVO'
                GROUP BY 1,2,3
                ) CAMBIO_CUSTOMER
               ON VENTAS_BASE.customer_id = CAMBIO_CUSTOMER.customer_id AND VENTAS_BASE.comm_brand_ds = CAMBIO_CUSTOMER.comm_brand_ds
                  AND VENTAS_BASE.service_type = CAMBIO_CUSTOMER.service_type
     )

WHERE account_id IS NOT NULL
)
;


/* Genera la tabla de ventas del Grupo MasMovil con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_net`
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
     ,VENTAS_BASE_TELCO.phone_nm
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
     ,VENTAS_BASE_TELCO.last_update
     ,VENTAS_BASE_TELCO.last_update_acc_prov

     ,STRUCT(
        CASE
            WHEN VENTAS_BASE_TELCO.order_type_agg = 'NUEVA' THEN 'ALTA NUEVA'
            ELSE COALESCE(VENTAS_BASE_TELCO.order_type_agg, CASE WHEN operadores_unificado.MARCA_UNIFICADA IS NOT NULL THEN 'PORTABILIDAD' ELSE 'ALTA NUEVA' END) END AS order_type_agg
       
       ,CASE WHEN VENTAS_BASE_TELCO.subchannel_ds LIKE 'SFID UNKNOWN%' THEN 'DESCONOCIDO' ELSE VENTAS_BASE_TELCO.subchannel_ds END AS subchannel_ds

       ,CASE WHEN VENTAS_BASE_TELCO.channel_ds LIKE 'SFID UNKNOWN%' THEN 'DESCONOCIDO' ELSE VENTAS_BASE_TELCO.channel_ds END AS channel_ds

       ,CASE
            WHEN VENTAS_BASE_TELCO.channel_segment_ds LIKE 'SFID UNKNOWN%'                                  THEN 'DESCONOCIDO'
            WHEN VENTAS_BASE_TELCO.channel_ds LIKE 'PLAT%'                                                  THEN 'CVM'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'CARIN%'   THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'CAROUT%'  THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'DONL%'    THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'LB%'      THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'MASTER%'  THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'MI%'      THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'MR%'      THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'MP%'      THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'PH%'      THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'RETECAN%' THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'RONL%'    THEN 'RESIDENCIAL'
            WHEN VENTAS_BASE_TELCO.channel_segment_ds IS NULL AND VENTAS_BASE_TELCO.sfid_id LIKE 'TLVOU%'   THEN 'RESIDENCIAL'
            ELSE UPPER(COALESCE(VENTAS_BASE_TELCO.channel_segment_ds, 'DESCONOCIDO'))
        END AS channel_segment_ds

       ,CASE
            WHEN VENTAS_BASE_TELCO.sell_bundle_type IN ('2P', 'FMC', 'MO')                                           THEN VENTAS_BASE_TELCO.sell_bundle_type
            WHEN VENTAS_BASE_TELCO.sell_bundle_type LIKE '%M%' AND VENTAS_BASE_TELCO.sell_bundle_type LIKE '%B%'     THEN 'FMC'
            WHEN VENTAS_BASE_TELCO.sell_bundle_type LIKE '%M%' AND VENTAS_BASE_TELCO.sell_bundle_type NOT LIKE '%B%' THEN 'MO'
            WHEN VENTAS_BASE_TELCO.sell_bundle_type NOT LIKE '%M%' AND VENTAS_BASE_TELCO.sell_bundle_type LIKE '%B%' THEN '2P'
            ELSE 'OTROS'
        END AS sell_bundle_type

      ) AS VBTN_CLEAN

     ,STRUCT(
        VENTAS_BASE_TELCO.comm_brand_ds AS marca
      ) AS VBTN_CREATED

FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS_BASE_TELCO

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_maestro_canales_masorange` MAESTRO_CANALES
         ON UPPER(VENTAS_BASE_TELCO.channel_ds) = MAESTRO_CANALES.sfid_sale_type_tdmk_a_des

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_port_in_operadores` PORT_IN_OPERADORES
         ON VENTAS_BASE_TELCO.port_in_operator_ds = PORT_IN_OPERADORES.OPERADOR

            AND CASE
                    WHEN COALESCE(DATE(VENTAS_BASE_TELCO.order_date), DATE(VENTAS_BASE_TELCO.activation_date)) < '2024-04-01' THEN 'GMM'
                    ELSE 'MASORANGE'
                END
                = PORT_IN_OPERADORES.origin

            AND VENTAS_BASE_TELCO.order_type_agg = 'PORTABILIDAD'
)
;


/* Validamos que la tabla de ventas modificada de Orange contiene todos los campos de la tabla de ventas del Grupo MasMovil */
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
          WHERE table_name = 'ventas_base_telco_osp'
          ) VENTAS_BASE_TELCO_OSP
         ON VENTAS_BASE_TELCO.column_name = VENTAS_BASE_TELCO_OSP.column_name

WHERE VENTAS_BASE_TELCO_OSP.column_name IS NULL
) AS 'VENTAS BASE TELCO NET contiene columnas no contempladas en la tabla modificada de VENTAS BASE TELCO OSP'
;


/* Montamos la query de creación de la tabla diaria */
/*
SET tabla_nombre = CONCAT('`mm-commissions-reporting.10_CLEANING_COMMISSIONS.','ventas_base_telco_net_', mes_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_net`';
EXECUTE IMMEDIATE qry;
*/

END