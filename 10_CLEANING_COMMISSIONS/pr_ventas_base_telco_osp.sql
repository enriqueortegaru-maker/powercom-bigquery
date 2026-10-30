BEGIN


-- PREPARA LA TABLA DE VENTAS DE ORANGE PARA EL COMISIONAMIENTO DE SUS SERVICIOS --


/*
CALL `mm-commissions-reporting.10_CLEANING_COMMISSIONS.pr_ventas_base_telco_osp`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE err, dia_string, qry, tabla_nombre STRING;


SET dia_string = REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '');


/* Creamos una tabla temporal que identifica, de las ventas de Jazztel, cuales corresponden a segundas residencias */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_jazztel_ventas`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      id_relacion
     ,id_promocion
     
     ,CASE
          WHEN id_promocion IN
                (
                19346,19347,19348,19349,19352,19353,
                19354,19355,19356,19357,19360,19361,
                19362,19363,19366,19367,19368,19371,
                19372,19373,19376,19377,19378,19381,
                19382,19383
                )
          THEN 'YES'
          ELSE NULL
      END AS segundaresidencia

FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.jzz_2102_ventas`
QUALIFY ROW_NUMBER() OVER (PARTITION BY id_relacion ORDER BY id_promocion) = 1 -- Elimina duplicidades de la tabla
)
;


/* Creamos una tabla temporal que permite traducir la clasificación de canales provenientes de Orange a la clasificación de MasOrange */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_maestro_canales_masorange`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
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
                          PARTITION BY sfid_sale_type_tdmk_a_des
                          ORDER BY canal_n0_masorange, canal_n1_masorange, canal_n2_masorange
                          ) = 1 -- Elimina duplicidades en la Google Sheet
)
;


/* Creamos una tabla temporal que permite traducir la clasificación de subcanales provenientes de Orange a la clasificación de MasOrange */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_maestro_segmento_canales_masorange`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      sfid_hijo
     ,campania_simplificada
     ,nro AS nombre_plataforma

FROM `mm-sales-reporting.MASTERS.maestro_segmento_canales_masorange`

WHERE sfid_hijo IS NOT NULL
      AND sfid_hijo != ''

QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_hijo ORDER BY campania_simplificada) = 1 -- Elimina duplicidades en la Google Sheet
)
;


/* Creamos una tabla temporal que contiene el detalle de cancelación de los servicios de Jazztel */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_seg_activ_comercial_jazztel`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      msisdn
     ,id_pedido
     ,motivo_cancelacion
     ,submotivo_cancelacion
     ,fecha_cancelacion
     ,id_expediente_cancelacion
FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.dwhu_hc_894_seg_activ_comercial_*`
QUALIFY ROW_NUMBER() OVER (PARTITION BY msisdn, id_pedido ORDER BY fecha_cancelacion DESC, id_expediente_cancelacion DESC) = 1 -- Elimina duplicidades en la tabla
)
;


/* Creamos una tabla temporal que contiene el listado de operadores donantes posibles y su detalle; para poder indentificar el operador padre de un servicio portado */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_port_in_operadores`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
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


/* Genera la tabla de ventas de Orange con la homogeneización de campos necesarios para el comisionamiento de sus servicios */
CREATE OR REPLACE TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      OSP.datasource_id
     ,OSP.data_source_ds
     ,OSP.brand_id
     ,OSP.brand_ds
     ,OSP.sub_brand_ds
     ,OSP.comm_brand_ds
     ,OSP.account_id
     ,OSP.customer_id
     ,OSP.service_id
     ,OSP.service_type
     ,OSP.phone_nm
     ,OSP.service_status_ds
     ,OSP.order_type_ds
     ,OSP.order_type_agg
     ,OSP.order_fix_id
     ,OSP.order_status_ds
     ,OSP.order_id
     ,OSP.order_date
     ,OSP.order_hour_id
     ,OSP.cancellation_date
     ,OSP.activation_date
     ,OSP.deactivation_date
     ,OSP.real_deactivation_date
     ,OSP.done_date
     ,OSP.segment_ds
     ,OSP.sub_segment_ds
     ,OSP.sell_tariff_id
     ,OSP.sell_tariff_ds
     ,OSP.sell_line_type_ds
     ,OSP.sell_bundle_id
     ,OSP.sell_bundle_name
     ,OSP.sell_bundle_type
     ,OSP.billing_type_ds
     ,OSP.contract_id
     ,OSP.sfid_id
     ,OSP.user_store
     ,OSP.seller
     ,CAST(NULL AS STRING) AS dealer_code
     ,CAST(NULL AS STRING) AS dealer_campaign_name
     ,OSP.subchannel_ds
     ,OSP.channel_ds
     ,OSP.superchannel_ds
     ,OSP.master_channel_ds
     ,OSP.channel_type_ds
     ,OSP.channel_segment_ds
     ,OSP.tariff_id
     ,OSP.tariff_ds
     ,OSP.line_type_ds
     ,OSP.bundle_id
     ,OSP.bundle_name
     ,OSP.bundle_type
     ,OSP.technology_ds

     ,CASE WHEN OSP.port_in_operator_ds = 'NO APLICA' THEN NULL ELSE OSP.port_in_operator_ds END AS port_in_operator_ds
     
     ,OSP.cancellation_reason_ds
     ,OSP.deactivation_reason_ds
     ,OSP.sell_type
     ,OSP.province
     ,OSP.zip_code
     ,OSP.terminal_model
     ,OSP.campaign
     ,OSP.main_service_id
     ,OSP.flag_data_sharing
     ,OSP.flag_new_order
     ,OSP.flag_order
     ,OSP.cancellation_reason_agg
     ,OSP.cancellation_subreason_agg
     ,OSP.customer_document
     ,OSP.pai
     ,OSP.payment_mode
     ,OSP.access_reuse_choice
     ,OSP.access_reuse
     ,OSP.current_sfid_id
     ,OSP.current_user_store
     ,OSP.first_territory_ds
     ,OSP.access_ds
     ,CAST(NULL AS STRING) AS iccid
     ,CAST(NULL AS INT64) AS customer_phone_nm
     ,OSP.customer_document_type
     ,CAST(NULL AS STRING) AS dig_signature_type_ds
     ,CAST(NULL AS STRING) AS user_cancellation_ds
     ,OSP.last_update
     ,OSP.last_update_acc_prov

     ,STRUCT(

        CASE
            WHEN OSP.service_type IN ('NO INFORMADO', 'NO APLICA', 'MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('%BANDA ANCHA MOVIL%') THEN 'BROADBAND' -- FIX LTE JAZZTEL (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('5G EN CASA') THEN 'BROADBAND' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND (OSP.sell_tariff_ds LIKE ('4G DE ORANGE EN%') OR OSP.sell_tariff_ds IN ('INTERNET EMPRESA ILIMITADO', 'INTERNET MOVIL 90GB EMPRESA', 'FIBRA ORO'))  THEN 'BROADBAND' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION LTE' THEN 'BROADBAND' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') THEN 'MOBILE'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') THEN 'BROADBAND'
            WHEN OSP.service_type IN ('NO INFORMADO') AND UPPER(OSP.sell_type) = 'DESCONOCIDO' AND UPPER(OSP.sell_tariff_ds) LIKE ('%ORANGE TV%') THEN 'TV'
            ELSE 'BROADBAND'
        END AS service_type

       ,CASE
            WHEN OSP.order_type_agg IN ('ALTA NUEVA', 'ALTA POR PORTABILIDAD MOVIL', 'ALTA PORTABILIDAD MOVIL') THEN 'ALTA NUEVA'
            WHEN OSP.order_type_agg = 'NUEVA'                                                                   THEN 'ALTA NUEVA'
            WHEN OSP.order_type_agg LIKE 'ALTA POR CAMBIO DE DOMIC%LIO'                                         THEN 'CAMBIO DE DOMICILIO'
            WHEN OSP.order_type_agg = 'ALTA POR PORTABILIDAD'                                                   THEN 'PORTABILIDAD'
            WHEN OSP.order_type_agg = 'ALTA POR PORTABILIDAD MOVIL'                                             THEN 'ALTA NUEVA'
            WHEN OSP.order_type_agg = 'PORTABILIDAD'                                                            THEN 'PORTABILIDAD'
            ELSE OSP.order_type_agg
        END AS order_type_agg

       ,CASE
            WHEN OSP.segment_ds = 'ENTERPRISE' AND OSP.sub_segment_ds = 'SOHO'     THEN 'SOHO'
            WHEN OSP.segment_ds = 'DESCONOCIDO' AND sub_segment_ds = 'DESCONOCIDO' THEN 'RESIDENCIAL'
            ELSE REPLACE(REPLACE(REPLACE(OSP.segment_ds, 'RESIDENTIAL', 'RESIDENCIAL'), 'RESIENCIAL', 'RESIDENCIAL'),' ENTERPRISE', 'BUSINESS')
        END AS segment_ds
     
       ,CASE
            WHEN OSP.service_type IN ('NO INFORMADO', 'NO APLICA', 'MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('%BANDA ANCHA MOVIL%') THEN 'MAIN' -- FIX LTE JAZZTEL (BAM)
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX' ,'BROADBAND') AND COALESCE(JAZZTEL_VENTAS.segundaresidencia, 'NO') = 'YES' THEN 'ADDITIONAL' -- SEGUNDA VIVIENDA JAZZTEL
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_tariff_ds) LIKE ('%SEGUNDA VIVIENDA%') THEN 'MAIN'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('5G EN CASA') THEN 'MAIN' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND (OSP.sell_tariff_ds LIKE ('4G DE ORANGE EN%') OR OSP.sell_tariff_ds IN ('INTERNET EMPRESA ILIMITADO', 'INTERNET MOVIL 90GB EMPRESA', 'FIBRA ORO')) THEN 'MAIN' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) IN ('STAND ALONE', 'STAND_ALONE') THEN 'MAIN'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION STAND ALONE' THEN 'ADDITIONAL'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') THEN OSP.sell_line_type_ds
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') THEN 'MAIN' --'BROADBAND'
            WHEN OSP.service_type IN ('NO INFORMADO') AND UPPER(OSP.sell_type) = 'DESCONOCIDO' AND UPPER(OSP.sell_tariff_ds) LIKE ('%ORANGE TV%') THEN 'MAIN' -- 'TV'
            ELSE NULL
        END AS sell_line_type_ds
     
       ,CASE
            WHEN OSP.service_type IN ('NO INFORMADO', 'NO APLICA', 'MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('PACK BANDA ANCHA MOVIL%') THEN 'FMC' -- FIX LTE JAZZTEL (BAM)
            WHEN OSP.service_type IN ('NO INFORMADO', 'NO APLICA', 'MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('%BANDA ANCHA MOVIL%') THEN '2P' -- FIX LTE JAZZTEL (BAM)
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_tariff_ds) LIKE ('%SEGUNDA VIVIENDA%')
                 AND OSP.comm_brand_ds = 'ORANGE' THEN 'FMC'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_tariff_ds) LIKE ('%SEGUNDA VIVIENDA%') THEN '2P'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'AMPLIACION CONVERGENTE' THEN 'FMC'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'AMPLIACION STAND ALONE'
                 AND OSP.comm_brand_ds = 'ORANGE' THEN 'FMC'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'AMPLIACION STAND ALONE' THEN '2P'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'AMPLIACION'
                 AND OSP.comm_brand_ds = 'ORANGE' THEN 'FMC'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'AMPLIACION' THEN '2P'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) IN ('DOBLE CAPTA', 'DOBLE CAPTACION') THEN 'FMC'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) IN ('STAND ALONE', 'STAND_ALONE') THEN '2P'
            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'XSELL' THEN 'FMC'

            WHEN OSP.service_type IN ('ADSL', 'FTTH', 'FIX', 'BROADBAND') AND UPPER(OSP.sell_type) = 'DESCONOCIDO' AND OSP.technology_ds = 'FTTH' THEN 'FMC'
            
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('5G EN CASA') THEN '2P' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND (OSP.sell_tariff_ds LIKE ('4G DE ORANGE EN%') OR OSP.sell_tariff_ds IN ('INTERNET EMPRESA ILIMITADO', 'INTERNET MOVIL 90GB EMPRESA', 'FIBRA ORO')) THEN '2P' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND OSP.sell_tariff_ds IN ('MI FIJO', 'PLAN MI FIJO') AND OSP.sell_type = 'DESCONOCIDO' THEN 'MO' -- MÓVILES CON NUMERACIÓN FIJA (ORANGE)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION CONVERGENTE' THEN 'FMC'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION LTE' THEN '2P' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION STAND ALONE' THEN 'MO'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION' THEN 'FMC'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) IN ('DOBLE CAPTA', 'DOBLE CAPTACION')  THEN 'FMC'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) IN ('STAND ALONE', 'STAND_ALONE') THEN 'MO'
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'XSELL' THEN 'FMC'
            
            WHEN OSP.service_type IN ('NO INFORMADO', 'NO APLICA') AND UPPER(OSP.sell_type) IN ('STAND ALONE', 'STAND_ALONE') THEN '2P' -- FIX LTE JAZZTEL (BAM)
            WHEN OSP.service_type IN ('NO INFORMADO') AND UPPER(OSP.sell_type) = 'XSELL' THEN 'FMC'
            
            WHEN OSP.sell_tariff_ds LIKE ('GO %') THEN 'MO'
            WHEN OSP.sell_tariff_ds LIKE ('LINEA SMARTPHONE EMPRESA SMART%') THEN 'MO'
            WHEN OSP.sell_tariff_ds LIKE ('LINEA SMARTPH%') THEN 'FMC'

            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) = 'NO INFORMADO' AND OSP.sell_tariff_ds LIKE ('TARIFA PACK%') THEN 'FMC'

            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND UPPER(OSP.sell_type) IN ('DESCONOCIDO', 'NO APLICA') THEN 'MO' -- Incidencia temporal
               
            ELSE 'OTROS'
          END AS sell_bundle_type

       ,COALESCE(OSP.billing_type_ds, 'POSTPAID') AS billing_type_ds
     
       ,UPPER(
          CASE
              WHEN CASE WHEN OSP.comm_brand_ds = 'UNKNOWN' THEN OSP.brand_ds ELSE COALESCE(OSP.comm_brand_ds, OSP.brand_ds) END != 'ORANGE' THEN 'RESIDENCIAL'
              WHEN UPPER(OSP.channel_ds) LIKE '%\\_EM'        THEN 'NEGOCIOS'
              WHEN UPPER(OSP.channel_ds) LIKE '%\\_RS'        THEN 'RESIDENCIAL'
              WHEN UPPER(OSP.channel_ds) LIKE 'SALESFORCE%'   THEN 'NEGOCIOS'
              ELSE 'RESIDENCIAL'
          END
        ) AS channel_segment_ds

       ,CASE
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('5G EN CASA') THEN 'FIX LTE' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL', 'MOBILE') AND (OSP.sell_tariff_ds LIKE ('4G DE ORANGE EN%') OR OSP.sell_tariff_ds IN ('INTERNET EMPRESA ILIMITADO', 'INTERNET MOVIL 90GB EMPRESA', 'FIBRA ORO')) THEN 'FIX LTE' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('MOVIL' ,'MOBILE') AND UPPER(OSP.sell_type) = 'AMPLIACION LTE' THEN 'FIX LTE' -- FIX LTE ORANGE (BAM)
            WHEN OSP.service_type IN ('NO INFORMADO', 'MOVIL', 'NO APLICA', 'MOBILE') AND OSP.sell_tariff_ds LIKE ('%BANDA ANCHA MOVIL%') THEN 'FIX LTE' -- FIX LTE JAZZTEL (BAM)
            ELSE REPLACE(OSP.technology_ds,'MOVIL', 'MOBILE')
        END AS technology_ds

       ,CASE
            WHEN OSP.service_type IN ('ADSL', 'FIX', 'FTTH', 'BROADBAND') AND UPPER(OSP.sell_type) IN ('XSELL') THEN 'CROSSELL'

            WHEN OSP.service_type IN ('ADSL', 'FIX', 'FTTH', 'BROADBAND')
                 AND UPPER(OSP.sell_type) IN ('DOBLE CAPTA', 'DOBLE CAPTACION', 'STAND_ALONE', 'STAND ALONE')
            THEN 'NEW SALE'
            
            WHEN OSP.service_type IN ('ADSL', 'FIX', 'FTTH', 'BROADBAND')
                 AND UPPER(OSP.sell_type) IN ('AMPLIACION', 'AMPLIACION CONVERGENTE', 'AMPLIACION STAND ALONE')
            THEN 'UPSELL'
            
            WHEN OSP.service_type IN ('MOBILE', 'MOVIL') AND UPPER(OSP.sell_type) IN ('XSELL') THEN 'CROSSELL'

            WHEN OSP.service_type IN ('MOBILE', 'MOVIL') AND OSP.sell_tariff_ds IN ('MI FIJO', 'PLAN MI FIJO') AND OSP.sell_type = 'DESCONOCIDO' THEN 'NEW SALE'

            WHEN OSP.service_type IN ('MOBILE', 'MOVIL')
                 AND UPPER(OSP.sell_type) IN ('DOBLE CAPTA', 'DOBLE CAPTACION', 'STAND_ALONE', 'STAND ALONE')
            THEN 'NEW SALE'
            
            WHEN OSP.service_type IN ('MOBILE', 'MOVIL')
                 AND UPPER(OSP.sell_type) IN ('AMPLIACION', 'AMPLIACION CONVERGENTE', 'AMPLIACION LTE', 'AMPLIACION STAND ALONE')
            THEN 'UPSELL'

            WHEN OSP.service_type IN ('NO INFORMADO', 'NO APLICA') AND UPPER(OSP.sell_type) IN ('STAND_ALONE', 'STAND ALONE') THEN 'NEW SALE'

            WHEN OSP.service_type IN ('NO INFORMADO') AND UPPER(OSP.sell_type) = 'XSELL' THEN 'CROSSELL'
              
            ELSE NULL
        END AS sell_type

      ) AS VBTO_CLEAN

     ,STRUCT(

        MAESTRO_CANALES.canal_n2

       ,MAESTRO_CANALES.canal_n1

       ,MAESTRO_CANALES.canal_n0
      
      ) AS MAESTRO_CANALES

     ,STRUCT(

        ACTIVIDAD.motivo_cancelacion

       ,ACTIVIDAD.submotivo_cancelacion
      
      ) AS ACTIVIDAD_JAZZTEL

     ,STRUCT(

        PORT_IN_OPERADORES.grupo_empresa1

       ,PORT_IN_OPERADORES.marca_unificada
      
      ) AS PORT_IN_OPERADORES

FROM `mm-datamart-kd.JV_ORANGE.ventas_base_telco_osp` OSP

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_jazztel_ventas` JAZZTEL_VENTAS
         ON OSP.order_id = CAST(JAZZTEL_VENTAS.id_relacion AS STRING)

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_maestro_canales_masorange` MAESTRO_CANALES
         ON UPPER(OSP.channel_ds) = MAESTRO_CANALES.sfid_sale_type_tdmk_a_des

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_maestro_segmento_canales_masorange` MAESTRO_SEGMENTO
         ON OSP.sfid_id = MAESTRO_SEGMENTO.sfid_hijo

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_seg_activ_comercial_jazztel` AS ACTIVIDAD
         ON ACTIVIDAD.msisdn = OSP.phone_nm
            AND CAST(ACTIVIDAD.id_pedido AS STRING) = OSP.order_id
            AND CASE WHEN OSP.comm_brand_ds = 'UNKNOWN' THEN OSP.brand_ds ELSE COALESCE(OSP.comm_brand_ds, OSP.brand_ds) END = 'JAZZTEL'

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.vbto_port_in_operadores` PORT_IN_OPERADORES
         ON OSP.port_in_operator_ds = PORT_IN_OPERADORES.OPERADOR

            AND CASE
                    WHEN COALESCE(DATE(OSP.order_date), DATE(OSP.activation_date)) < '2024-04-01' THEN 'GMM'
                    ELSE 'MASORANGE'
                END
                = PORT_IN_OPERADORES.origin

            AND OSP.order_type_agg = 'ALTA POR PORTABILIDAD'
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


/* Revisamos que el filtro utilizado por el equipo de ventas no haya cambiado para poder revisar posibles cambios en los criterios de limpieza de algunos campos */
ASSERT NOT EXISTS
(
SELECT
      OSP.row_count AS row_count_ventas
     ,COMMISSIONS.row_count AS row_count_commissions

FROM (
     SELECT CURRENT_DATE() AS check_date, COUNT(*) AS row_count
     FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1
     ) OSP

LEFT JOIN (
          SELECT CURRENT_DATE() AS check_date, COUNT(*) AS row_count
          FROM `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp`
          WHERE
               CASE
                   WHEN order_date IS NOT NULL THEN 1
                   WHEN order_date IS NULL AND sub_segment_ds NOT IN ('CORPORATE', 'SME') AND COALESCE(comm_brand_ds, brand_ds) = 'ORANGE' THEN 1
                   ELSE 0
               END = 1
        
               AND (
                   COALESCE(DATE(order_date), DATE(activation_date)) >= '2024-01-01'
                   OR
                   DATE(CASE WHEN deactivation_date > CURRENT_DATE() THEN NULL ELSE deactivation_date END) >= '2024-01-01'
                   )

               AND CASE WHEN comm_brand_ds = 'UNKNOWN' THEN brand_ds ELSE COALESCE(comm_brand_ds, brand_ds) END
                     IN ('GO', 'HOLIDAYS', 'JAZZTEL', 'MUNDO', 'ORANGE', 'SIMYO')
               
               AND (brand_ds != 'JAZZTEL' OR segment_ds != 'ENTERPRISE')

               AND (
                   flag_order = 'YES'
                   OR (
                      flag_order = 'NO'
                      AND order_type_agg LIKE ('ALTA POR CAMBIO DE DOMIC%LIO')
                      )
                   )
               
               AND COALESCE(DATE(order_date),DATE(activation_date)) < CURRENT_DATE()
          GROUP BY 1
          ) COMMISSIONS
         ON OSP.check_date = COMMISSIONS.check_date AND OSP.row_count = COMMISSIONS.row_count

WHERE COMMISSIONS.row_count IS NULL
) AS 'Se ha modificado el WHERE en la extracción de los datos de Orange para la tabla QUERY_INFORME_MULTIMARCA_GMM'
;


/* Revisamos la homogeneidad en los criterios de limpieza de los campos modificados entre la tabla del equipo de ventas y la tabla generada */
SET err =
(
WITH sales_field_grouping AS
(
SELECT
      'service_type' AS field_name
     ,service_type AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'order_type_agg' AS field_name
     ,order_type_agg AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'segment_ds' AS field_name
     ,segment_ds AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'sell_line_type_ds' AS field_name
     ,sell_line_type_ds AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'sell_bundle_type' AS field_name
     ,sell_bundle_type AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'billing_type_ds' AS field_name
     ,billing_type_ds AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'subchannel_ds' AS field_name
     ,subchannel_ds AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'channel_segment_ds' AS field_name
     ,channel_segment_ds AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'technology_ds' AS field_name
     ,technology_ds AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL
          
SELECT
      'sell_type' AS field_name
     ,sell_type AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL

SELECT
      'cancellation_reason_agg' AS field_name
     ,cancellation_reason_agg AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2

UNION ALL

SELECT
      'cancellation_subreason_agg' AS field_name
     ,cancellation_subreason_agg AS field_value
     ,COUNT(*) AS count
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
     WHERE data_source_ds = 'OSP'
     GROUP BY 1,2
)
,

commissions_table_filter AS
(
SELECT *
FROM `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp`
WHERE
     CASE
         WHEN order_date IS NOT NULL THEN 1
         WHEN order_date IS NULL AND sub_segment_ds NOT IN ('CORPORATE', 'SME') AND COALESCE(comm_brand_ds, brand_ds) = 'ORANGE' THEN 1
         ELSE 0
     END = 1
        
     AND (
         COALESCE(DATE(order_date), DATE(activation_date)) >= '2024-01-01'
         OR
         DATE(CASE WHEN deactivation_date > CURRENT_DATE() THEN NULL ELSE deactivation_date END) >= '2024-01-01'
         )

     AND CASE WHEN comm_brand_ds = 'UNKNOWN' THEN brand_ds ELSE COALESCE(comm_brand_ds, brand_ds) END
           IN ('GO', 'HOLIDAYS', 'JAZZTEL', 'MUNDO', 'ORANGE', 'SIMYO')
     
     AND (brand_ds != 'JAZZTEL' OR segment_ds != 'ENTERPRISE')

     AND (
         flag_order = 'YES'
         OR (
            flag_order = 'NO'
            AND order_type_agg LIKE ('ALTA POR CAMBIO DE DOMIC%LIO')
            )
         )
)
,

commissions_field_grouping AS
(
SELECT
      'service_type' AS field_name
     ,VBTO_CLEAN.service_type AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'order_type_agg' AS field_name
     ,VBTO_CLEAN.order_type_agg AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'segment_ds' AS field_name
     ,VBTO_CLEAN.segment_ds AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'sell_line_type_ds' AS field_name
     ,VBTO_CLEAN.sell_line_type_ds AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'sell_bundle_type' AS field_name
     ,VBTO_CLEAN.sell_bundle_type AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'billing_type_ds' AS field_name
     ,VBTO_CLEAN.billing_type_ds AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'subchannel_ds' AS field_name
     ,MAESTRO_CANALES.canal_n2 AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'channel_segment_ds' AS field_name
     ,VBTO_CLEAN.channel_segment_ds AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'technology_ds' AS field_name
     ,VBTO_CLEAN.technology_ds AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL
          
SELECT
      'sell_type' AS field_name
     ,VBTO_CLEAN.sell_type AS field_value
     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL

SELECT
      'cancellation_reason_agg' AS field_name

     ,CASE
          WHEN CASE WHEN comm_brand_ds = 'UNKNOWN' THEN brand_ds ELSE COALESCE(comm_brand_ds, brand_ds) END = 'JAZZTEL'
          THEN ACTIVIDAD_JAZZTEL.motivo_cancelacion
          
          ELSE cancellation_reason_agg
      END AS field_value

     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2

UNION ALL

SELECT
      'cancellation_subreason_agg' AS field_name

     ,CASE
          WHEN CASE WHEN comm_brand_ds = 'UNKNOWN' THEN brand_ds ELSE COALESCE(comm_brand_ds, brand_ds) END = 'JAZZTEL'
          THEN ACTIVIDAD_JAZZTEL.submotivo_cancelacion
            
          ELSE cancellation_subreason_agg
      END AS field_value

     ,COUNT(*) AS count
FROM commissions_table_filter
     GROUP BY 1,2
)
,

sales_commissions_field_match AS
(
SELECT
      SALES.field_name
     ,SALES.field_value
     ,SALES.count AS sales_count
     ,COMMISSIONS.count AS commissions_count

FROM sales_field_grouping SALES

LEFT JOIN commissions_field_grouping COMMISSIONS
         ON SALES.field_name = COMMISSIONS.field_name AND SALES.field_value = COMMISSIONS.field_value

WHERE ABS(SALES.count - COMMISSIONS.count) > 10

ORDER BY 1,2
)

SELECT STRING_AGG(CONCAT('[', field_name, ', ', field_value, ']'), ' ; ')
FROM sales_commissions_field_match
)
;

IF err IS NOT NULL THEN RAISE USING MESSAGE = 'Se han cambiado CASEs en la limpieza de los datos de Orange para los siguientes campos y valores: ' || err; END IF;


/* Montamos la query de creación de la tabla diaria */
SET tabla_nombre = CONCAT('`mm-commissions-reporting.10_CLEANING_COMMISSIONS.','ventas_base_telco_osp_', dia_string, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp`';
EXECUTE IMMEDIATE qry;


END