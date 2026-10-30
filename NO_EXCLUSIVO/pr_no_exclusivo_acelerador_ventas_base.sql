BEGIN


-- CALL `mm-commissions-reporting.NO_EXCLUSIVO.pr_no_exclusivo_acelerador_ventas_base`('20230501');


/* This additional sale incentive applies only to services sold through the MASPROXIMO and MASINDIRECTO channels */


CREATE TEMP FUNCTION fn_clean_sfid(tienda STRING, sfid_id STRING) AS
(
CASE WHEN LENGTH(tienda) > 4 AND tienda <> 'C00001' THEN tienda
     WHEN LENGTH(tienda) = 4 AND sfid_id NOT LIKE 'MP%' AND sfid_id <> 'MMS' THEN sfid_id || '-' || tienda
     WHEN sfid_id = 'MMS' THEN tienda
     ELSE sfid_id
END
);


-- Extracts activaction and deactivation kpis for all fix services sold in the inputed month
CREATE OR REPLACE TEMPORARY TABLE fix AS
(
SELECT
      month
     ,tienda
     ,sfid_id
     ,SUM(fix_orders_new_res) AS fix_orders_new_res
     ,SUM(fix_orders_new_bus) AS fix_orders_new_bus
     ,SUM(fix_deactivations_new_res) AS fix_deactivations_new_res
     ,SUM(fix_deactivations_new_bus) AS fix_deactivations_new_bus
     ,SUM(fix_orders_portability_res) AS fix_orders_portability_res
     ,SUM(fix_orders_portability_bus) AS fix_orders_portability_bus
     ,SUM(fix_deactivations_portability_res) AS fix_deactivations_portability_res
     ,SUM(fix_deactivations_portability_bus) AS fix_deactivations_portability_bus

FROM (
     SELECT
           PARSE_DATE('%Y%m%d', mes_pr) AS month
          ,user_store AS tienda
          ,sfid_id
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL' THEN 1 ELSE 0
           END AS fix_orders_new_res
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO') THEN 1 ELSE 0
           END AS fix_orders_new_bus
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL'
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS fix_deactivations_new_res
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO')
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS fix_deactivations_new_bus
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL' THEN 1 ELSE 0
           END AS fix_orders_portability_res
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO') THEN 1 ELSE 0
           END AS fix_orders_portability_bus
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL'
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS fix_deactivations_portability_res
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO')
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS fix_deactivations_portability_bus
     
     FROM `mm-datamart-kd.SERVICES.ventas_base_net` VENTAS

     --LEFT JOIN `mm-commissions-reporting.GS.PORTIN_OPERATORS` PORTIN --<---------------------- Comentar para Legacy
              --ON VENTAS.port_in_operator_ds = PORTIN.operator

     WHERE DATE_TRUNC(COALESCE(order_day_id, '1969-01-01'), MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
           AND flag_order = 'YES'
           AND sell_bundle_type <> 'TELEVISION'
           AND service_type = 'FIX'
           AND channel_segment_ds = 'RESIDENCIAL'
           AND channel_ds IN ('MASINDIRECTO', 'MASPROXIMO')
           --AND COALESCE(PORTIN.intragrupo, 2) <> 1 --<---------------------- Comentar para Legacy
     )
GROUP BY 1,2,3
)
;


-- Extracts activaction and deactivation kpis for all mobile services activated in the inputed month
CREATE OR REPLACE TEMPORARY TABLE mobile AS
(
SELECT
      month
     ,tienda
     ,sfid_id
     ,SUM(mobile_activations_postpaid_new_res) AS mobile_activations_postpaid_new_res
     ,SUM(mobile_activations_postpaid_new_bus) AS mobile_activations_postpaid_new_bus
     ,SUM(mobile_deactivations_postpaid_new_res) AS mobile_deactivations_postpaid_new_res
     ,SUM(mobile_deactivations_postpaid_new_bus) AS mobile_deactivations_postpaid_new_bus
     ,SUM(mobile_activations_postpaid_portability_res) AS mobile_activations_postpaid_portability_res
     ,SUM(mobile_activations_postpaid_portability_bus) AS mobile_activations_postpaid_portability_bus
     ,SUM(mobile_deactivations_postpaid_portability_res) AS mobile_deactivations_postpaid_portability_res
     ,SUM(mobile_deactivations_postpaid_portability_bus) AS mobile_deactivations_postpaid_portability_bus
     ,SUM(mobile_activations_prepaid_res) AS mobile_activations_prepaid_res
     ,SUM(mobile_activations_prepaid_bus) AS mobile_activations_prepaid_bus

FROM (
     SELECT
           PARSE_DATE('%Y%m%d', mes_pr) AS month
          ,user_store AS tienda
          ,sfid_id
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL' AND billing_type_ds = 'POSTPAID' THEN 1 ELSE 0
           END AS mobile_activations_postpaid_new_res
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO') AND billing_type_ds = 'POSTPAID' THEN 1 ELSE 0
           END AS mobile_activations_postpaid_new_bus
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL' AND billing_type_ds = 'POSTPAID'
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS mobile_deactivations_postpaid_new_res
     
          ,CASE WHEN order_type_agg NOT IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO') AND billing_type_ds = 'POSTPAID'
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS mobile_deactivations_postpaid_new_bus
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL' AND billing_type_ds = 'POSTPAID' THEN 1 ELSE 0
           END AS mobile_activations_postpaid_portability_res
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO') AND billing_type_ds = 'POSTPAID' THEN 1 ELSE 0
           END AS mobile_activations_postpaid_portability_bus
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds = 'RESIDENCIAL' AND billing_type_ds = 'POSTPAID'
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS mobile_deactivations_postpaid_portability_res
     
          ,CASE WHEN order_type_agg IN ('PORTABILIDAD') AND segment_ds IN ('BUSINESS', 'SOHO') AND billing_type_ds = 'POSTPAID'
                     AND (DATE_TRUNC(real_deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr) OR DATE_TRUNC(cancellation_day_id, MONTH) = PARSE_DATE('%Y%m%d', mes_pr))
                THEN 1 ELSE 0
           END AS mobile_deactivations_postpaid_portability_bus
     
          ,CASE WHEN segment_ds = 'RESIDENCIAL' AND billing_type_ds = 'PREPAID' THEN 1 ELSE 0
           END AS mobile_activations_prepaid_res
     
          ,CASE WHEN segment_ds IN ('BUSINESS', 'SOHO') AND billing_type_ds = 'PREPAID' THEN 1 ELSE 0
           END AS mobile_activations_prepaid_bus
     
     FROM `mm-datamart-kd.SERVICES.ventas_base_net` VENTAS

     --LEFT JOIN `mm-commissions-reporting.GS.PORTIN_OPERATORS` PORTIN --<---------------------- Comentar para Legacy
              --ON VENTAS.port_in_operator_ds = PORTIN.operator

     WHERE DATE_TRUNC(COALESCE(activation_date, '1969-01-01'), MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
           AND flag_order = 'YES'
           AND sell_bundle_type <> 'TELEVISION'
           AND service_type <> 'FIX'
           AND channel_segment_ds = 'RESIDENCIAL'
           AND channel_ds IN ('MASINDIRECTO', 'MASPROXIMO')
           AND order_type_ds NOT IN ('ALTA NUEVA-CAMBIO DE TITULAR', 'PORTABILIDAD-CAMBIO DE TITULAR')
           --AND COALESCE(PORTIN.intragrupo, 2) <> 1 --<---------------------- Comentar para Legacy
     )
GROUP BY 1,2,3
)
;


-- Extracts activaction and deactivation kpis for all tv services activated in the inputed month
CREATE OR REPLACE TEMPORARY TABLE tv AS
(
SELECT
      month
     ,tienda
     ,sfid_id
     ,SUM(tv_activations_res) AS tv_activations_res
     ,SUM(tv_activations_bus) AS tv_activations_bus
     ,SUM(tv_deactivations_res) AS tv_deactivations_res
     ,SUM(tv_deactivations_bus) AS tv_deactivations_bus

FROM (
     SELECT
           PARSE_DATE('%Y%m%d', mes_pr) AS month
          ,user_store AS tienda
          ,sfid_id
       
          ,CASE WHEN segment_ds = 'RESIDENCIAL' THEN 1 ELSE 0 END AS tv_activations_res
     
          ,CASE WHEN segment_ds <> 'RESIDENCIAL' THEN 1 ELSE 0 END AS tv_activations_bus
          
          ,CASE WHEN segment_ds = 'RESIDENCIAL'
                     AND DATE_TRUNC(deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
                THEN 1 ELSE 0
           END AS tv_deactivations_res
     
          ,CASE WHEN segment_ds <> 'RESIDENCIAL'
                     AND DATE_TRUNC(deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
                THEN 1 ELSE 0
           END AS tv_deactivations_bus

     FROM `mm-commissions-reporting.COMISIONES.v_servicio_television`

     WHERE DATE_TRUNC(activation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
           AND channel_ds IN ('MASINDIRECTO', 'MASPROXIMO')
     )

GROUP BY 1,2,3
)
;


-- Extracts activaction and deactivation kpis for all alarm services activated in the inputed month
CREATE OR REPLACE TEMPORARY TABLE alarms AS
(
SELECT
      month
     ,tienda
     ,sfid_id
     ,SUM(alarm_activations) AS alarm_activations
     ,SUM(alarm_deactivations) AS alarm_deactivations

FROM (
     SELECT
           PARSE_DATE('%Y%m%d', mes_pr) AS month
          ,user_store AS tienda
          ,sfid_id
       
          ,1 AS alarm_activations
          
          ,CASE WHEN DATE_TRUNC(fecha_baja, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
                THEN 1 ELSE 0
           END AS alarm_deactivations

     FROM `mm-sales-reporting.SPEEDUP.query_alarmas_multimarca`

     WHERE DATE_TRUNC(fecha_activacion, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
           AND channel_ds IN ('MASINDIRECTO', 'MASPROXIMO')
     )

GROUP BY 1,2,3
)
;


-- Extracts all energy services activated in the inputed month
CREATE OR REPLACE TEMPORARY TABLE energy_extraction AS
(
SELECT DISTINCT
        ENRG.master_channel_ds
       ,ENRG.channel_ds
       ,ENRG.subchannel_ds
       ,ENRG.sfid_id
       ,ENRG.user_store

       ,CASE WHEN CUSTOMERS.customer_segment = 'residential' THEN 'RESIDENCIAL'
             WHEN CUSTOMERS.customer_segment = 'freelance'   THEN 'SOHO'
             WHEN CUSTOMERS.customer_segment = 'company'     THEN 'SOHO'
             ELSE CUSTOMERS.customer_segment 
        END AS segment_ds

       ,CASE WHEN ENRG.tenant_code = 'masmovil' THEN 'MASMOVIL'
             WHEN ENRG.tenant_code = 'energygo' THEN 'YOIGO'
        END AS brand_ds

       ,CAST(ENRG.id AS STRING) AS service_id
       ,ENRG.signup_date AS order_date
       ,ENRG.activation_date
       ,ENRG.churn_date AS deactivation_date

FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity` ENRG

LEFT JOIN `mm-datamart-kd.ENERGY.lucera_customers` CUSTOMERS
         ON ENRG.notification_partner_id = CUSTOMERS.id

WHERE DATE_TRUNC(ENRG.activation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
      AND ENRG.channel_ds IN ('MASINDIRECTO', 'MASPROXIMO', 'NATIONAL RETAIL')

UNION ALL

SELECT DISTINCT
        ENRG.master_channel_ds
       ,ENRG.channel_ds
       ,ENRG.subchannel_ds
       ,sfid AS sfid_id
       ,sfid AS user_store
       ,'RESIDENCIAL'AS segment_ds
       ,'PEPEPHONE'AS brand_ds
       ,ENRG.id_servicio AS service_id
       ,CAST(fecha_venta AS DATE) AS order_date
       ,CAST(fecha_activacion AS DATE) AS activation_date
       ,CAST(IF(fecha_baja = '0000-00-00', NULL, fecha_baja) AS DATE) AS deactivation_date

FROM `mm-datamart-kd.ENERGY.pepeenergy_services_bi` ENRG

LEFT JOIN `mm-datamart-kd.ENERGY.pepeenergy_customer_traceability` CUSTOMERS
         ON ENRG.id_cliente_pph = CUSTOMERS.customer_id

WHERE DATE_TRUNC(CAST(IF(fecha_activacion = '0000-00-00', '1969-01-01', fecha_activacion) AS DATE), MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
      AND ENRG.channel_ds IN ('MASINDIRECTO', 'MASPROXIMO')
      AND CUSTOMERS.data_source_ds = 'HEOS'

QUALIFY RANK () OVER (PARTITION BY service_id ORDER BY CAST(fecha_venta AS DATE) DESC, CAST(fecha_activacion AS DATE) DESC) = 1
)
;


-- Extracts activaction and deactivation kpis for all energy services activated in the inputed month
CREATE OR REPLACE TEMPORARY TABLE energy AS
(
SELECT
      month
     ,tienda
     ,sfid_id
     ,SUM(energy_activations_res) AS energy_activations_res
     ,SUM(energy_activations_bus) AS energy_activations_bus
     ,SUM(energy_deactivations_res) AS energy_deactivations_res
     ,SUM(energy_deactivations_bus) AS energy_deactivations_bus

FROM (
     SELECT
           PARSE_DATE('%Y%m%d', mes_pr) AS month
          ,user_store AS tienda
          ,sfid_id
     
          ,CASE WHEN segment_ds = 'RESIDENCIAL' THEN 1 ELSE 0 END AS energy_activations_res
     
          ,CASE WHEN segment_ds <> 'RESIDENCIAL' THEN 1 ELSE 0 END AS energy_activations_bus
            
          ,CASE WHEN segment_ds = 'RESIDENCIAL'
                     AND DATE_TRUNC(deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
                THEN 1 ELSE 0
           END AS energy_deactivations_res
      
          ,CASE WHEN segment_ds <> 'RESIDENCIAL'
                     AND DATE_TRUNC(deactivation_date, MONTH) = PARSE_DATE('%Y%m%d', mes_pr)
                THEN 1 ELSE 0
           END AS energy_deactivations_bus

     FROM energy_extraction
     )
     
GROUP BY 1,2,3
)
;


-- Merges the different sold services and their kpis
CREATE OR REPLACE TEMPORARY TABLE merge_sales AS
(
SELECT
      month
     ,tienda
     ,sfid_id
     ,fn_clean_sfid(tienda, sfid_id) AS tienda_clean
     ,fix_orders_new_res
     ,fix_orders_new_bus
     ,fix_deactivations_new_res
     ,fix_deactivations_new_bus
     ,fix_orders_portability_res
     ,fix_orders_portability_bus
     ,fix_deactivations_portability_res
     ,fix_deactivations_portability_bus
     ,0 AS mobile_activations_postpaid_new_res
     ,0 AS mobile_activations_postpaid_new_bus
     ,0 AS mobile_deactivations_postpaid_new_res
     ,0 AS mobile_deactivations_postpaid_new_bus
     ,0 AS mobile_activations_postpaid_portability_res
     ,0 AS mobile_activations_postpaid_portability_bus
     ,0 AS mobile_deactivations_postpaid_portability_res
     ,0 AS mobile_deactivations_postpaid_portability_bus
     ,0 AS mobile_activations_prepaid_res
     ,0 AS mobile_activations_prepaid_bus
     ,0 AS tv_activations_res
     ,0 AS tv_activations_bus
     ,0 AS tv_deactivations_res
     ,0 AS tv_deactivations_bus
     ,0 AS alarm_activations
     ,0 AS alarm_deactivations
     ,0 AS energy_activations_res
     ,0 AS energy_activations_bus
     ,0 AS energy_deactivations_res
     ,0 AS energy_deactivations_bus

FROM fix

UNION ALL

SELECT
      month
     ,tienda
     ,sfid_id
     ,fn_clean_sfid(tienda, sfid_id) AS tienda_clean
     ,0 AS fix_orders_new_res
     ,0 AS fix_orders_new_bus
     ,0 AS fix_deactivations_new_res
     ,0 AS fix_deactivations_new_bus
     ,0 AS fix_orders_portability_res
     ,0 AS fix_orders_portability_bus
     ,0 AS fix_deactivations_portability_res
     ,0 AS fix_deactivations_portability_bus
     ,mobile_activations_postpaid_new_res
     ,mobile_activations_postpaid_new_bus
     ,mobile_deactivations_postpaid_new_res
     ,mobile_deactivations_postpaid_new_bus
     ,mobile_activations_postpaid_portability_res
     ,mobile_activations_postpaid_portability_bus
     ,mobile_deactivations_postpaid_portability_res
     ,mobile_deactivations_postpaid_portability_bus
     ,mobile_activations_prepaid_res
     ,mobile_activations_prepaid_bus
     ,0 AS tv_activations_res
     ,0 AS tv_activations_bus
     ,0 AS tv_deactivations_res
     ,0 AS tv_deactivations_bus
     ,0 AS alarm_activations
     ,0 AS alarm_deactivations
     ,0 AS energy_activations_res
     ,0 AS energy_activations_bus
     ,0 AS energy_deactivations_res
     ,0 AS energy_deactivations_bus

FROM mobile

UNION ALL

SELECT
      month
     ,tienda
     ,sfid_id
     ,fn_clean_sfid(tienda, sfid_id) AS tienda_clean
     ,0 AS fix_orders_new_res
     ,0 AS fix_orders_new_bus
     ,0 AS fix_deactivations_new_res
     ,0 AS fix_deactivations_new_bus
     ,0 AS fix_orders_portability_res
     ,0 AS fix_orders_portability_bus
     ,0 AS fix_deactivations_portability_res
     ,0 AS fix_deactivations_portability_bus
     ,0 AS mobile_activations_postpaid_new_res
     ,0 AS mobile_activations_postpaid_new_bus
     ,0 AS mobile_deactivations_postpaid_new_res
     ,0 AS mobile_deactivations_postpaid_new_bus
     ,0 AS mobile_activations_postpaid_portability_res
     ,0 AS mobile_activations_postpaid_portability_bus
     ,0 AS mobile_deactivations_postpaid_portability_res
     ,0 AS mobile_deactivations_postpaid_portability_bus
     ,0 AS mobile_activations_prepaid_res
     ,0 AS mobile_activations_prepaid_bus
     ,tv_activations_res
     ,tv_activations_bus
     ,tv_deactivations_res
     ,tv_deactivations_bus
     ,0 AS alarm_activations
     ,0 AS alarm_deactivations
     ,0 AS energy_activations_res
     ,0 AS energy_activations_bus
     ,0 AS energy_deactivations_res
     ,0 AS energy_deactivations_bus

FROM tv

UNION ALL

SELECT
      month
     ,tienda
     ,sfid_id
     ,fn_clean_sfid(tienda, sfid_id) AS tienda_clean
     ,0 AS fix_orders_new_res
     ,0 AS fix_orders_new_bus
     ,0 AS fix_deactivations_new_res
     ,0 AS fix_deactivations_new_bus
     ,0 AS fix_orders_portability_res
     ,0 AS fix_orders_portability_bus
     ,0 AS fix_deactivations_portability_res
     ,0 AS fix_deactivations_portability_bus
     ,0 AS mobile_activations_postpaid_new_res
     ,0 AS mobile_activations_postpaid_new_bus
     ,0 AS mobile_deactivations_postpaid_new_res
     ,0 AS mobile_deactivations_postpaid_new_bus
     ,0 AS mobile_activations_postpaid_portability_res
     ,0 AS mobile_activations_postpaid_portability_bus
     ,0 AS mobile_deactivations_postpaid_portability_res
     ,0 AS mobile_deactivations_postpaid_portability_bus
     ,0 AS mobile_activations_prepaid_res
     ,0 AS mobile_activations_prepaid_bus
     ,0 AS tv_activations_res
     ,0 AS tv_activations_bus
     ,0 AS tv_deactivations_res
     ,0 AS tv_deactivations_bus
     ,alarm_activations
     ,alarm_deactivations
     ,0 AS energy_activations_res
     ,0 AS energy_activations_bus
     ,0 AS energy_deactivations_res
     ,0 AS energy_deactivations_bus

FROM alarms

UNION ALL

SELECT
      month
     ,tienda
     ,sfid_id
     ,fn_clean_sfid(tienda, sfid_id) AS tienda_clean
     ,0 AS fix_orders_new_res
     ,0 AS fix_orders_new_bus
     ,0 AS fix_deactivations_new_res
     ,0 AS fix_deactivations_new_bus
     ,0 AS fix_orders_portability_res
     ,0 AS fix_orders_portability_bus
     ,0 AS fix_deactivations_portability_res
     ,0 AS fix_deactivations_portability_bus
     ,0 AS mobile_activations_postpaid_new_res
     ,0 AS mobile_activations_postpaid_new_bus
     ,0 AS mobile_deactivations_postpaid_new_res
     ,0 AS mobile_deactivations_postpaid_new_bus
     ,0 AS mobile_activations_postpaid_portability_res
     ,0 AS mobile_activations_postpaid_portability_bus
     ,0 AS mobile_deactivations_postpaid_portability_res
     ,0 AS mobile_deactivations_postpaid_portability_bus
     ,0 AS mobile_activations_prepaid_res
     ,0 AS mobile_activations_prepaid_bus
     ,0 AS tv_activations_res
     ,0 AS tv_activations_bus
     ,0 AS tv_deactivations_res
     ,0 AS tv_deactivations_bus
     ,0 AS alarm_activations
     ,0 AS alarm_deactivations
     ,energy_activations_res
     ,energy_activations_bus
     ,energy_deactivations_res
     ,energy_deactivations_bus

FROM energy
)
;



/* ----------------------------------
                 LEGACY
---------------------------------- */

-- Groups all sold services by their unique sellerID and identifies their incentive classification
CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.no_exclusivo_acelerador` AS
(
SELECT
      *
     ,CASE WHEN actos_comerciales BETWEEN 0 AND 3    THEN 'Resto'
           WHEN actos_comerciales BETWEEN 4 AND 17   THEN 'Resto'
           WHEN actos_comerciales BETWEEN 18 AND 44  THEN 'Basic'
           WHEN actos_comerciales BETWEEN 45 AND 104 THEN 'Medium'
           ELSE 'Plus'
      END AS acelerador

FROM (
     SELECT
           month
          ,sfid_unico

          ,(
             fix_orders_new_res - fix_deactivations_new_res
           + fix_orders_portability_res - fix_deactivations_portability_res
           + fix_orders_new_bus - fix_deactivations_new_bus
           + fix_orders_portability_bus - fix_deactivations_portability_bus
           ) AS fix_sales_net

          ,(
             mobile_activations_postpaid_new_res - mobile_deactivations_postpaid_new_res
           + mobile_activations_postpaid_portability_res - mobile_deactivations_postpaid_portability_res
           + mobile_activations_postpaid_new_bus - mobile_deactivations_postpaid_new_bus
           + mobile_activations_postpaid_portability_bus - mobile_deactivations_postpaid_portability_bus
           ) AS mobile_postpaid_activations_net
     
          ,(mobile_activations_prepaid_res + mobile_activations_prepaid_bus) AS mobile_prepaid_activations
     
          ,(
             tv_activations_res - tv_deactivations_res
           + tv_activations_bus - tv_deactivations_bus
           ) AS tv_activations_net
     
          ,(alarm_activations - alarm_deactivations) AS alarm_activations_net
     
          ,(
             energy_activations_res - energy_deactivations_res
           + energy_activations_bus - energy_deactivations_bus
           ) AS energy_activations_net

          ,(
             (fix_orders_new_res - fix_deactivations_new_res + fix_orders_portability_res - fix_deactivations_portability_res)
           + (fix_orders_new_bus - fix_deactivations_new_bus + fix_orders_portability_bus - fix_deactivations_portability_bus)

           + (mobile_activations_postpaid_new_res + mobile_activations_postpaid_new_bus)
           - (mobile_deactivations_postpaid_new_res + mobile_deactivations_postpaid_new_bus)

           + (mobile_activations_postpaid_portability_res + mobile_activations_postpaid_portability_bus)
           - (mobile_deactivations_postpaid_portability_res + mobile_deactivations_postpaid_portability_bus)

           + (tv_activations_res - tv_deactivations_res + tv_activations_bus - tv_deactivations_bus)
           + (alarm_activations - alarm_deactivations)
           + (energy_activations_res - energy_deactivations_res + energy_activations_bus - energy_deactivations_bus)
           ) AS actos_comerciales

     FROM (
          SELECT
                month
               ,COALESCE(OPTICO.sfid_id, tienda_clean) AS sfid_unico
               ,SUM(fix_orders_new_res) AS fix_orders_new_res
               ,SUM(fix_orders_new_bus) AS fix_orders_new_bus
               ,SUM(fix_deactivations_new_res) AS fix_deactivations_new_res
               ,SUM(fix_deactivations_new_bus) AS fix_deactivations_new_bus
               ,SUM(fix_orders_portability_res) AS fix_orders_portability_res
               ,SUM(fix_orders_portability_bus) AS fix_orders_portability_bus
               ,SUM(fix_deactivations_portability_res) AS fix_deactivations_portability_res
               ,SUM(fix_deactivations_portability_bus) AS fix_deactivations_portability_bus
               ,SUM(mobile_activations_postpaid_new_res) AS mobile_activations_postpaid_new_res
               ,SUM(mobile_activations_postpaid_new_bus) AS mobile_activations_postpaid_new_bus
               ,SUM(mobile_deactivations_postpaid_new_res) AS mobile_deactivations_postpaid_new_res
               ,SUM(mobile_deactivations_postpaid_new_bus) AS mobile_deactivations_postpaid_new_bus
               ,SUM(mobile_activations_postpaid_portability_res) AS mobile_activations_postpaid_portability_res
               ,SUM(mobile_activations_postpaid_portability_bus) AS mobile_activations_postpaid_portability_bus
               ,SUM(mobile_deactivations_postpaid_portability_res) AS mobile_deactivations_postpaid_portability_res
               ,SUM(mobile_deactivations_postpaid_portability_bus) AS mobile_deactivations_postpaid_portability_bus
               ,SUM(mobile_activations_prepaid_res) AS mobile_activations_prepaid_res
               ,SUM(mobile_activations_prepaid_bus) AS mobile_activations_prepaid_bus
               ,SUM(tv_activations_res) AS tv_activations_res
               ,SUM(tv_activations_bus) AS tv_activations_bus
               ,SUM(tv_deactivations_res) AS tv_deactivations_res
               ,SUM(tv_deactivations_bus) AS tv_deactivations_bus
               ,SUM(alarm_activations) AS alarm_activations
               ,SUM(alarm_deactivations) AS alarm_deactivations
               ,SUM(energy_activations_res) AS energy_activations_res
               ,SUM(energy_activations_bus) AS energy_activations_bus
               ,SUM(energy_deactivations_res) AS energy_deactivations_res
               ,SUM(energy_deactivations_bus) AS energy_deactivations_bus
          
          FROM merge_sales SALES

          LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` OPTICO
                   ON SALES.tienda_clean = OPTICO.sfid_id

          GROUP BY 1,2
          )
     )

WHERE actos_comerciales >= 1
)
;



/* ----------------------------------
                 POINTS
---------------------------------- */

/*
CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.no_exclusivo_acelerador_puntos_20230101` AS
(
SELECT *
FROM (
     SELECT
           month
          ,sfid_unico
     
          ,(
             fix_orders_new_res - fix_deactivations_new_res
           + fix_orders_portability_res - fix_deactivations_portability_res
           ) AS fix_res_sales_net
     
          ,(
             fix_orders_new_bus - fix_deactivations_new_bus
           + fix_orders_portability_bus - fix_deactivations_portability_bus
           ) AS fix_bus_sales_net
     
          ,(
             mobile_activations_postpaid_new_res - mobile_deactivations_postpaid_new_res
           + mobile_activations_postpaid_portability_res - mobile_deactivations_postpaid_portability_res
           + mobile_activations_postpaid_new_bus - mobile_deactivations_postpaid_new_bus
           + mobile_activations_postpaid_portability_bus - mobile_deactivations_postpaid_portability_bus
           ) AS mobile_postpaid_activations_net
          
          ,(mobile_activations_prepaid_res + mobile_activations_prepaid_bus) AS mobile_prepaid_activations
     
          ,(
             tv_activations_res - tv_deactivations_res
           + tv_activations_bus - tv_deactivations_bus
           ) AS tv_activations_net
     
          ,(alarm_activations - alarm_deactivations) AS alarm_activations_net
     
          ,(
             energy_activations_res - energy_deactivations_res
           + energy_activations_bus - energy_deactivations_bus
           ) AS energy_activations_net
     
          ,(
             ((fix_orders_new_res - fix_deactivations_new_res + fix_orders_portability_res - fix_deactivations_portability_res) * 3)

           + ((fix_orders_new_bus - fix_deactivations_new_bus + fix_orders_portability_bus - fix_deactivations_portability_bus) * 4)
     
           + (
               (mobile_activations_postpaid_new_res + mobile_activations_postpaid_new_bus)
             - (mobile_deactivations_postpaid_new_res + mobile_deactivations_postpaid_new_bus)
             + (mobile_activations_postpaid_portability_res + mobile_activations_postpaid_portability_bus)
             - (mobile_deactivations_postpaid_portability_res + mobile_deactivations_postpaid_portability_bus)
             )
     
           + ((mobile_activations_prepaid_res + mobile_activations_prepaid_bus) * .25)
     
           + ((tv_activations_res - tv_deactivations_res + tv_activations_bus - tv_deactivations_bus) * .5)

           + ((alarm_activations - alarm_deactivations) * .5)
           + ((energy_activations_res - energy_deactivations_res + energy_activations_bus - energy_deactivations_bus) * .25)
           ) AS puntos
     
          FROM (
               SELECT
                     month
                    ,COALESCE(OPTICO.sfid_id, tienda_clean) AS sfid_unico
                    ,SUM(fix_orders_new_res) AS fix_orders_new_res
                    ,SUM(fix_orders_new_bus) AS fix_orders_new_bus
                    ,SUM(fix_deactivations_new_res) AS fix_deactivations_new_res
                    ,SUM(fix_deactivations_new_bus) AS fix_deactivations_new_bus
                    ,SUM(fix_orders_portability_res) AS fix_orders_portability_res
                    ,SUM(fix_orders_portability_bus) AS fix_orders_portability_bus
                    ,SUM(fix_deactivations_portability_res) AS fix_deactivations_portability_res
                    ,SUM(fix_deactivations_portability_bus) AS fix_deactivations_portability_bus
                    ,SUM(mobile_activations_postpaid_new_res) AS mobile_activations_postpaid_new_res
                    ,SUM(mobile_activations_postpaid_new_bus) AS mobile_activations_postpaid_new_bus
                    ,SUM(mobile_deactivations_postpaid_new_res) AS mobile_deactivations_postpaid_new_res
                    ,SUM(mobile_deactivations_postpaid_new_bus) AS mobile_deactivations_postpaid_new_bus
                    ,SUM(mobile_activations_postpaid_portability_res) AS mobile_activations_postpaid_portability_res
                    ,SUM(mobile_activations_postpaid_portability_bus) AS mobile_activations_postpaid_portability_bus
                    ,SUM(mobile_deactivations_postpaid_portability_res) AS mobile_deactivations_postpaid_portability_res
                    ,SUM(mobile_deactivations_postpaid_portability_bus) AS mobile_deactivations_postpaid_portability_bus
                    ,SUM(mobile_activations_prepaid_res) AS mobile_activations_prepaid_res
                    ,SUM(mobile_activations_prepaid_bus) AS mobile_activations_prepaid_bus
                    ,SUM(tv_activations_res) AS tv_activations_res
                    ,SUM(tv_activations_bus) AS tv_activations_bus
                    ,SUM(tv_deactivations_res) AS tv_deactivations_res
                    ,SUM(tv_deactivations_bus) AS tv_deactivations_bus
                    ,SUM(alarm_activations) AS alarm_activations
                    ,SUM(alarm_deactivations) AS alarm_deactivations
                    ,SUM(energy_activations_res) AS energy_activations_res
                    ,SUM(energy_activations_bus) AS energy_activations_bus
                    ,SUM(energy_deactivations_res) AS energy_deactivations_res
                    ,SUM(energy_deactivations_bus) AS energy_deactivations_bus
               
               FROM merge_sales SALES

          LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` OPTICO
                   ON SALES.tienda_clean = OPTICO.sfid_id
     
               GROUP BY 1,2
               )
     )
     
WHERE puntos > 0
)
;*/

END