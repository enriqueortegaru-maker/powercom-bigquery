BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


CALL `mm-commissions-reporting.COMISIONES.pr_enrg`(202312);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrg_extraccion` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
SELECT
      'calculado' AS estado
     ,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) AS agrupacion_canal
     ,DEALER.canal
     ,master_channel_ds
     ,channel_ds
     ,subchannel_ds
     ,channel_segment_ds
     ,'CSEN' AS tipo_concepto
     ,1 AS unidades
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,ENERGY.sfid_id AS sfid_id
     ,ENERGY.seller AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,ENERGY.brand_ds AS marca
     ,'ENERGY' as service_type
     ,CAST(ENERGY.phone AS STRING) phone_nm
     ,initial_lucera_tariff_code AS tariff_id
     ,ENERGY.initial_lucera_tariff_name AS tariff_ds
     ,ENERGY.electricity_contract_id AS service_id
     ,ENERGY.cups_code AS account_id
     ,ENERGY.customer_ids AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,ENERGY.electricity_order_day_id AS sale_date
     ,ENERGY.electricity_activation_date AS activation_date
     ,ENERGY.electricity_deactivation_date AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id

     ,CASE
          WHEN sale_type = 'new'        THEN 'ALTA NUEVA'
          WHEN sale_type = 'cross-sell' THEN 'CROSS-SELL'
      END AS order_type_agg

     ,'10' AS cod_segmento
     
     ,CASE
          WHEN ENERGY.brand_ds ='ENERGYGO'   THEN '16'
          WHEN ENERGY.brand_ds = 'MASMOVIL'  THEN '17'
          WHEN ENERGY.brand_ds ='PEPEENERGY' THEN '19'
          ELSE '16'
      END AS cod_marca

     ,'99' AS cod_tipo_contrato
     ,'014' AS cod_producto
     ,CANALES.cod_canal
     ,CAST(NULL AS STRING) AS claim_code
     ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, COALESCE(ENERGY.brand_ds, SALES.brand_ds), ENERGY.sfid_id, 'ENERGY') AS campaign_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador

FROM (
     SELECT
           ENERGY.* EXCEPT(master_channel_ds, channel_ds, subchannel_ds, channel_segment_ds)
          ,SALES.master_channel_ds
          ,SALES.channel_ds
          ,SALES.subchannel_ds
          ,SALES.channel_segment_ds
     
     FROM (
          SELECT
                * EXCEPT (sfid_id)
               ,CASE
                    WHEN sfid_id LIKE 'MASTER%' THEN UPPER(user_store)
                    WHEN sfid_id LIKE 'C0%'     THEN UPPER(user_store)
                    WHEN sfid_id LIKE 'M0%'     THEN UPPER(user_store)
                    WHEN sfid_id IN ('MP2')     THEN UPPER(user_store)
                    WHEN sfid_id = 'WEB'        THEN UPPER(user_store)
                    WHEN sfid_id = 'LB'         THEN UPPER(REPLACE(REPLACE(user_store, 'lm', 'lb'), 'lbe', 'lb'))
                    WHEN sfid_id = 'LBL'        THEN UPPER(REPLACE(REPLACE(user_store, 'lm', 'lb'), 'lbe', 'lb'))
                    ELSE UPPER(sfid_id)
                END AS sfid_id
           
          FROM `mm-sales-reporting.SPEEDUP.query_energia_multimarca`
          ) ENERGY
     
     LEFT JOIN (
               SELECT sfid_id, master_channel_ds, channel_segment_ds, channel_ds, subchannel_ds
               FROM `mm-datamart-kd.SERVICES.ventas_base_net`
               WHERE sfid_id IS NOT NULL
                     AND master_channel_ds IS NOT NULL
                     AND channel_segment_ds IN ('RESIDENCIAL', 'NEGOCIOS')
                     AND channel_ds IS NOT NULL
                     AND subchannel_ds IS NOT NULL
               QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
               ) SALES
              ON ENERGY.sfid_id = SALES.sfid_id AND ENERGY.sfid_id IS NOT NULL
     ) ENERGY

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (ENERGY.sfid_id = DEALER.sfid_id OR (ENERGY.brand_ds = 'YOIGO' AND SUBSTR(ENERGY.sfid_id, 1, 2) = DEALER.sfid_id))
            AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
            AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.CANALES` CANALES
         ON DEALER.canal = CANALES.canal


WHERE DATE_TRUNC(ENERGY.electricity_activation_date, MONTH) = PARSE_DATE('%Y%m', mes_string)
      AND electricity_activation_date <= COALESCE(ENERGY.electricity_deactivation_date, '9999-12-31')
;

      
/*
AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
AND DEALER.canal = canal_pr
AND DEALER.comisiona*/

END