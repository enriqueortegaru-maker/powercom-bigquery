BEGIN

-- CALL SANDBOX.pr_check_servicio_base(date_trunc(date_add (current_date (), interval -1 month), month));

DECLARE table_name, qry, month_name STRING;


CREATE OR REPLACE TEMPORARY TABLE check_servicio_base AS

SELECT DISTINCT
        SALES.*
       ,COMMISSIONS.* EXCEPT (service_type)
       ,COMMISSIONS_PORTABILITY.portabilidad
       ,INTERNET.fix_service_id
       ,INTERNET.service_id AS internet_service_id
       ,SANDBOX.f_clasificacion_canales(SALES.channel_segment_ds, SALES.channel_ds, SALES.subchannel_ds) AS clasificacion_canal

       ,CASE WHEN COMISIONES_WORKING.commission_id IS NOT NULL THEN 1 ELSE 0 END AS comisionado

       ,CASE
            WHEN COMMISSIONS.subscription_id IS NOT NULL THEN 'Comisionado MCOM'
            WHEN EVENTS.subscriptionid IS NULL           THEN 'Falta Evento'
            ELSE 'Falta MCOM'
        END AS estado_MCOM

       ,CASE WHEN COMISIONES_WORKING.commission_id IS NOT NULL THEN 'En borrador liquidación' ELSE 'Falta borrador liquidación' END AS estado_Liquidacion

       ,CASE WHEN SALES.comisiona LIKE 'Comisiona%' AND REPORTED.subscription_id IS NULL                                             THEN 'Venta a comisionar'
             WHEN SALES.comisiona = 'No comisiona - falta informacion vendedor' AND COMISIONES_WORKING.commission_id IS NOT NULL     THEN 'Venta a comisionar'
             WHEN SALES.comisiona LIKE '%C0%' AND COMISIONES_WORKING.commission_id IS NOT NULL                                       THEN 'Venta a comisionar'
             ELSE 'Venta no comisiona'
        END AS clasificacion_venta

FROM (
     SELECT
           SALES.* EXCEPT(comisiona)

          ,CASE
               WHEN SALES.comisiona = 'Comisiona' AND channel_ds IN ('MASINDIRECTO', 'MASPROXIMO', 'NATIONAL RETAIL') AND NO_EXCLUSIVO_DEALERS.sfid IS NULL
               THEN 'No Comisiona - dealer no comisiona - ' || SALES.sfid_id

               WHEN SALES.comisiona = 'Comisiona' AND master_channel_ds IN ('WEB', 'TELESALES') AND TELEVENTA_DEALERS.billing_dealer IS NULL
               THEN 'No Comisiona - dealer no comisiona - ' || SALES.sfid_id

               WHEN SALES.comisiona = 'Comisiona' AND order_type_agg IN ('PORTABILIDAD') THEN
                    CASE
                        WHEN channel_ds = 'WEB' AND subchannel_ds = 'CARRITO INBOUND' THEN 'Comisiona - Solo Alta'

                        WHEN service_type = 'FIX' THEN
                             CASE
                                 WHEN channel_ds IN ('MASINDIRECTO', 'NATIONAL RETAIL')
                                 THEN 'Comisiona - Solo Alta'
                                 ELSE 'Comisiona - Alta y Portabilidad'
                             END

                        ELSE 'Comisiona - Alta y Portabilidad'
                    END

               WHEN SALES.comisiona = 'Comisiona' THEN 'Comisiona - Solo Alta'

               ELSE SALES.comisiona
           END AS comisiona

     FROM (
          SELECT
                *
               ,`mm-commissions-reporting.TELEVENTA.f_ventas_lisandro_camp`(sfid_id, seller, brand_ds) AS clasificacion_camp_xs

               ,COMISIONES.f_identificacion_comisionamiento (
                                                          master_channel_ds
                                                         ,channel_ds
                                                         ,subchannel_ds
                                                         ,sfid_id
                                                         ,user_store
                                                         ,seller
                                                         ,sell_line_type_ds
                                                         ,brand_ds
                                                         ,service_type
                                                         ,sell_tariff_id
                                                         ,sell_tariff_ds
                                                         ,billing_type_ds
                                                         ) AS comisiona

          FROM `mm-datamart-kd.SERVICES.ventas_base_net` 
          WHERE (DATE_TRUNC(activation_date, MONTH) = mes_pr OR DATE_TRUNC(COALESCE(order_day_id, '1969-01-01'), MONTH) = mes_pr)
                AND flag_order = 'YES'
                AND sell_bundle_type <> 'TELEVISION'
                AND channel_ds NOT LIKE 'SFID%'
                AND brand_ds IN ('YOIGO','MASMOVIL','LLAMAYA', 'PEPEPHONE')
                AND channel_segment_ds = 'RESIDENCIAL'
          ) SALES

     LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` NO_EXCLUSIVO_DEALERS
              ON CASE WHEN LENGTH(SALES.user_store) > 4 AND SALES.user_store <> 'C00001' THEN SALES.user_store
                      WHEN LENGTH(SALES.user_store) = 4 AND SALES.sfid_id <> 'MMS' THEN SALES.sfid_id || '-' || SALES.user_store
                      WHEN SALES.sfid_id = 'MMS' THEN SALES.user_store
                      ELSE SALES.sfid_id
                 END = NO_EXCLUSIVO_DEALERS.sfid
     
     LEFT JOIN `mm-commissions-reporting.TELEVENTA.DEALERS` TELEVENTA_DEALERS
               ON CASE WHEN SUBSTR(SALES.sfid_id, LENGTH(SALES.sfid_id) - 2, LENGTH(SALES.sfid_id)) = '_XS' THEN SUBSTR(SALES.sfid_id, 1, 2)
                       WHEN SALES.sfid_id LIKE 'CARIN%' THEN SALES.sfid_id
                       WHEN SALES.sfid_id LIKE 'CAROUT%' THEN SALES.sfid_id
                       WHEN SALES.sfid_id LIKE 'DONL%'THEN SALES.sfid_id
                       WHEN SALES.sfid_id LIKE 'RONL%'THEN SALES.sfid_id
                       WHEN SALES.sfid_id LIKE 'TLVOU%' THEN SALES.sfid_id
                       WHEN SALES.sfid_id NOT LIKE '%MKDXNEG%' THEN SUBSTR(SALES.sfid_id, 1, 2)
                  END = TELEVENTA_DEALERS.billing_dealer AND TELEVENTA_DEALERS.comisiona
     ) SALES

LEFT JOIN `mm-datamart-kd.SERVICES.internet_base_emysim` INTERNET
         ON SALES.data_source_ds = 'MYSIM' AND SALES.service_id = INTERNET.fix_service_id
    
LEFT JOIN (
          SELECT
                UPPER(brand) AS marca
               ,subscription_id
               ,msisdn
               ,commission_id
               ,channel

               ,CASE WHEN description = 'A - Servicio Fijo' THEN 'FIX' ELSE 'MOBILE' END AS service_type
               
               ,CASE 
                    WHEN campaign = 'CROSS-SELL_IN' AND UPPER(brand) = 'YOIGO'      THEN 'Cross-sell IN - Yoigo'
                    WHEN campaign = 'CROSS-SELL_IN' AND UPPER(brand) = 'MASMOVIL'   THEN 'Cross-sell IN - MM'
                    WHEN campaign = 'ADICIONALES_OUT' AND UPPER(brand) = 'YOIGO'    THEN 'Líneas adicionales OUT - Yoigo'
                    WHEN campaign = 'ADICIONALES_OUT' AND UPPER(brand) = 'MASMOVIL' THEN 'Líneas adicionales OUT - MM'
                    WHEN campaign = 'CROSS-SELL_OUT' AND UPPER(brand) = 'YOIGO'     THEN 'Cross-sell OUT - Yoigo'
                    WHEN campaign = 'CROSS-SELL_OUT' AND UPPER(brand) = 'MASMOVIL'  THEN 'Cross-sell OUT - MM'
                    WHEN campaign = 'TV_OUT' AND UPPER(brand) = 'YOIGO'             THEN 'TV OUT - Yoigo'
                    WHEN campaign = 'TV_OUT' AND UPPER(brand) = 'MASMOVIL'          THEN 'TV OUT - MM'
                    WHEN campaign = 'ENERGIA_OUT' AND UPPER(brand) = 'YOIGO'        THEN 'Energía OUT - Yoigo'
                    WHEN campaign = 'ENERGIA_OUT' AND UPPER(brand) = 'MASMOVIL'     THEN 'Energía OUT - MM'
                END AS clasificacion_camp_mcom

          FROM `mm-commissions-reporting.SANDBOX.v_mcom` 
          WHERE DATE_TRUNC(DATE(activation_date, 'Europe/Madrid'), MONTH) = mes_pr
                AND description in ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
                AND amount > 0
          ) COMMISSIONS
         ON (SALES.service_id = COMMISSIONS.subscription_id OR INTERNET.service_id = COMMISSIONS.subscription_id) AND SALES.brand_ds = COMMISSIONS.marca
         and SALES.service_type = COMMISSIONS.service_type

LEFT JOIN (
          SELECT
                UPPER(brand) AS marca
               ,subscription_id
               ,msisdn
               ,commission_id
               ,channel
               ,1 AS portabilidad

               ,CASE WHEN description = 'A - Portabilidad Fijo' THEN 'FIX' ELSE 'MOBILE' END AS service_type
                
          FROM `mm-commissions-reporting.SANDBOX.v_mcom` 
          WHERE DATE_TRUNC(DATE(activation_date, 'Europe/Madrid'), MONTH) = mes_pr
                AND description IN ('A - Portabilidad Fijo', 'A - Portabilidad Movil Pospago')
                AND amount > 0
          ) COMMISSIONS_PORTABILITY
         ON (SALES.service_id = COMMISSIONS_PORTABILITY.subscription_id OR INTERNET.service_id = COMMISSIONS_PORTABILITY.subscription_id)
            AND SALES.brand_ds = COMMISSIONS_PORTABILITY.marca AND SALES.service_type = COMMISSIONS.service_type

LEFT JOIN (
          SELECT REPLACE( REPLACE(id_registro, 'MCOM',''), '_', '') AS commission_id
          FROM `mm-commissions-reporting.TELEVENTA.comisiones_working`
          WHERE id_registro LIKE 'MCOM_%'
                AND importe_base > 0

          UNION ALL

          SELECT REPLACE(REPLACE(id_registro, 'MCOM',''), '_', '') AS commission_id
          FROM `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working`
          WHERE id_registro LIKE 'MCOM_%'
                AND importe_base > 0
          ) COMISIONES_WORKING
         ON CAST(COMMISSIONS.commission_id AS STRING) = COMISIONES_WORKING.commission_id

LEFT JOIN (
          SELECT DISTINCT UPPER(marca) marca, subscription_id, CASE WHEN descripcion_concepto = 'A - Servicio Fijo' THEN 'FIX' ELSE 'MOBILE' END AS service_type
          FROM `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*`
          WHERE descripcion_concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
          UNION ALL
          SELECT DISTINCT UPPER(marca) marca, subscription_id, CASE WHEN descripcion_concepto = 'A - Servicio Fijo' THEN 'FIX' ELSE 'MOBILE' END AS service_type
          FROM `mm-commissions-reporting.REPORTED.comisiones_televenta_*`
          WHERE descripcion_concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
          ) REPORTED
         ON (SALES.service_id = REPORTED.subscription_id OR INTERNET.service_id = REPORTED.subscription_id) AND SALES.brand_ds = REPORTED.marca
            AND SALES.service_type = REPORTED.service_type

LEFT JOIN (
          SELECT DISTINCT
                  tenant.name AS marca
                 ,subscriptiontype
                 ,b.subscriptionid
          FROM `mm-datamart-kd.KAFKA_DATA_EVENTS.activate_events`,  UNNEST (products) AS b
          WHERE DATE_TRUNC(DATE(date, 'Europe/Madrid'), MONTH) = mes_pr
          ) EVENTS
         ON (SALES.service_id = EVENTS.subscriptionid OR INTERNET.service_id = EVENTS.subscriptionid)
            AND EVENTS.marca = SALES.brand_ds
            AND EVENTS.subscriptiontype = SALES.service_type

WHERE SANDBOX.f_clasificacion_canales(SALES.channel_segment_ds, SALES.channel_ds, SALES.subchannel_ds)
      IN (
          'No Exclusivo',
          'TLV - Cross-sell',
          'TLV - DO',
          'TLV - Outbound',
          'TLV - Web'
         )
;


SET month_name = REPLACE(CAST(mes_pr AS STRING), '-', '');
SET table_name = CONCAT('`mm-commissions-reporting.SANDBOX.check_servicio_base_', month_name, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || table_name || ' AS SELECT * FROM ' || 'check_servicio_base';
EXECUTE IMMEDIATE qry;


END