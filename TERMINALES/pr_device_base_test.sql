BEGIN

--Tabla temporal que sustituye a `mm-commissions-reporting.TERMINALES.v_device_base`

--CALL `mm-commissions-reporting.TERMINALES.pr_device_base_test`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.device_base_test`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT *
FROM (

     SELECT DISTINCT

        -- INFORMACIÓN DEL CANAL
        CASE WHEN DEVICE.sell_terminal_origin_ds <> 'RENUEVO' THEN 'CAPTACION' ELSE DEVICE.sell_terminal_origin_ds END AS sell_type

       ,COALESCE(RFM_YOIGO.channel_type_ds, DEVICE.channel_type_ds) AS channel_type_ds
       ,COALESCE(RFM_YOIGO.master_channel_ds, DEVICE.master_channel_ds) AS master_channel_ds
       ,COALESCE(RFM_YOIGO.channel_ds, DEVICE.channel_ds) AS channel_ds
       ,COALESCE(RFM_YOIGO.subchannel_ds, DEVICE.subchannel_ds) AS subchannel_ds
       ,COALESCE(DEALER.id_comisionista, RFM_YOIGO.sfid_id, DEVICE.sfid_id) AS sfid_id  --Si tenemos id_comisionista de DEALER y si no, tomamos lo que venga
       ,COALESCE(DEALER.sfid_id, RFM_YOIGO.sfid_id, DEVICE.user_store) AS user_store    --Si tenemos sfid_id de DEALER y si no, tomamos lo que venga
       ,COALESCE(DEALER.sfid_id, RFM_YOIGO.sfid_id, UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)])) AS seller   --Si tenemos sfid_id de DEALER y si no, tomamos lo que venga
       ,COALESCE(RFM_YOIGO.channel_segment_ds, SALES_CHANNEL.channel_segment_ds) AS channel_segment_ds
       ,DEVICE.segment_ds
       ,CAST(NULL AS STRING) AS channel_id
       ,CAST(NULL AS STRING)AS sfid_ifs
       --,COALESCE(DEALER.region_code,1) AS region_code
       
--       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1 WHEN DEALER.zona_fiscal = 'CAN' THEN 4 ELSE CAST(NULL AS INT64) END AS region_code
       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1 WHEN DEALER.zona_fiscal = 'CAN' THEN 4 ELSE 1 END AS region_code
          
       --DATOS DE LA VENTA
       ,DEVICE.brand_ds

       ,CASE WHEN RFM_YOIGO.sfid_id IS NOT NULL THEN 'RFM_YOIGO' ELSE 'MYSIM' END AS data_source

       ,DEVICE.id_subscription_terminal
       ,SALES.contract_id AS contract_id
       ,DEVICE.service_id
       ,DEVICE.account_id
       ,DEVICE.customer_id
       ,CAST(DEVICE.id_subscription_terminal AS STRING) AS order_id
       ,CAST(DEVICE.phone_nm AS STRING) phone_nm
       ,CAST(DEVICE.tariff_id AS STRING) AS tariff_id
       ,DEVICE.tariff_ds

       ,CASE WHEN DEVICE.sell_type = 'POSVENTA' AND DEVICE.sell_terminal_origin_ds in ('RENUEVO') THEN 'RENUEVO' ELSE DEVICE.order_type_agg END AS order_type_agg

       ,COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
       ,COALESCE(SALES.bundle_type,SALES.sell_bundle_type, 'MO') AS bundle_type -- JOHANNA 20260325: Agrego y doy prioridad al bundle_type por tener el del momento de la venta del dispositivo y no, el de la activación del servicio
       ,COALESCE(REPLACE(SALES.line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds
       ,COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
       ,DATE(DEVICE.order_date) AS order_date
       ,SALES.onboarding_status_agg AS status_servicio
       ,'C -' || SALES.cancellation_subreason_agg AS motivo_cancelacion

       ,COALESCE(
                CASE WHEN DEVICE.sell_terminal_origin_ds IN ('RENUEVO') AND RFM_YOIGO.billing_type_ds IS NOT NULL THEN
                     CASE
                          WHEN RFM_YOIGO.billing_type_ds = 'PREPAID'
                          THEN RFM_YOIGO.sell_date
          
                          WHEN RFM_YOIGO.financed_type = 'PAGO UNICO' AND RFM_YOIGO.order_status_ds = 'DELIVERED'
                          THEN COALESCE(DATE(RFM_YOIGO.logistic_done_status_date), DATE(RFM_YOIGO.dig_signature_signed_datetime), RFM_YOIGO.sell_date)
          
                          WHEN RFM_YOIGO.financed_type = 'PAGO UNICO' AND RFM_YOIGO.order_status_ds = 'ONGOING'
                          THEN COALESCE(DATE(RFM_YOIGO.logistic_done_status_date), DATE(RFM_YOIGO.dig_signature_signed_datetime))
          
                          WHEN RFM_YOIGO.financed_type = 'PAGO FINANCIADO' AND RFM_YOIGO.order_status_ds = 'DELIVERED'
                          THEN COALESCE(DATE(RFM_YOIGO.logistic_done_status_date), DATE(RFM_YOIGO.dig_signature_signed_datetime), RFM_YOIGO.sell_date)
          
                          WHEN RFM_YOIGO.financed_type = 'PAGO FINANCIADO' AND RFM_YOIGO.order_status_ds = 'ONGOING'
                          THEN COALESCE(DATE(RFM_YOIGO.logistic_done_status_date), DATE(RFM_YOIGO.dig_signature_signed_datetime))
                     END
                END
                ,PARSE_DATE('%Y%m%d', CAST(RFM_YOIGO.activation_date AS STRING))
                ,CASE WHEN DEVICE.sell_type = 'VENTA' THEN SALES.activation_date END
                ,DATE(DEVICE.order_date)
                ) AS activation_date

       ,COALESCE(RFM_YOIGO.end_date, SALES.real_deactivation_date) AS deactivation_date

       -- DATOS DEL TERMINAL
       ,DEVICE.terminal_status_ds
       ,DEVICE.product_code
       ,DEVICE.terminal_name
       ,COALESCE(RFM_YOIGO.product_ds, DEVICE.tech_description) AS product
       ,DEVICE.financed_months
       ,DEVICE.financed_monthly_quota
       ,DEVICE.financed_entity
       ,DEVICE.is_financed_desc
       ,DEVICE.financed_status
       ,CAST (NULL AS STRING) AS financed_type
       ,DEVICE.service_type AS technology_ds
       ,DEVICE.serial_number
       ,DEVICE.offer_segmentation

       -- DATOS DE IMPORTE PARA EL SUBSIDIO
       --,IF(DEALER.zona_fiscal = 'PEN', 1.21, 1.07) AS TAX  /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
       --,COALESCE(DEALER.tax, 21) tax-- IMPUESTO APLICAR A LA TIENDA 
       
       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 21 WHEN DEALER.zona_fiscal = 'CAN' THEN 7 ELSE CAST(NULL AS INT64) END AS tax

       ,DEVICE.tax_value -- IMPUESTO APLICADO A CLIENTE
       ,DEVICE.cost_price_without_vat AS purch_price -- COSTE DE TERMINAL SIN IMPUESTOS
       ,DEVICE.gross_subsidy_1 AS net_subsidy -- SUBSIDIO NETO CALCULADO POR NEGOCIO
       ,DEVICE.initial_payment AS end_user_price -- PAGO INICIAL DEL CLIENTE
       ,ROUND(
              (
              (DEVICE.cost_price_without_vat)
              *
              --((COALESCE(DEALER.tax, 21)/ 100) + 1) 
              IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS coste_device -- COSTE DE TERMINAL CON IMPUESTOS
          
       -- CACULAMOS CANTIDADES DE SUBSIDIOS
       ,ROUND(
              (
              DEVICE.gross_subsidy_1
              *
              --((COALESCE(DEALER.tax, 21) / 100) + 1) 
              IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS subsidy -- SUBSIDIO CALCULADO POR NEGOCIO 
          
       -- CALCULAMOS EL SUBSIDIO AJUSTANDO POR COSTE DE TERMINAL MENOS PAGO PLAZO Y PAGO FINAL DEL CLIENTE
       ,ROUND(
             (
             IF(DEVICE.financed_total_amount IS NULL, 0, DEVICE.financed_total_amount / (DEVICE.tax_value + 1)) 
             *
              --((COALESCE(DEALER.tax, 21) / 100) + 1) 
              IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS subsidy_payterm -- LLEVAMOS IMPORTE TOTAL CON IMPUESTO A TIENDA  
          
       -- PAGO A PLAZOS DEL CLIENTE 
          
       ,ROUND(
             (
             (DEVICE.q25_amount / (DEVICE.tax_value + 1))
             *
              --((COALESCE(DEALER.tax, 21) / 100) + 1) 
              IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS subsidy_pay25 -- LLEVAMOS IMPORTE TOTAL CON IMPUESTO A TIENDA

       ,AGRUPACION.agrupacion_canal AS agrupacion_canal
       ,DEALER.canal AS canal
       ,DEALER.distribuidor AS distribuidor
       ,DEALER.cif AS cif
       ,DEALER.razon_social AS razon_social
       ,DEALER.nombre_comercio AS nombre_comercio
       ,DEVICE.financed_init_date AS fecha_inicio_financiacion
       ,DEVICE.financed_end_date AS fecha_fin_financiacion
       ,AGRUPACION.codigo_canal_sap AS cod_canal
       ,COALESCE(DEVICE.original_cost_price, 0.0) AS original_cost_price
       ,DEVICE.total_pay_value
       ,DEVICE.courier
       ,DEVICE.flag_pay_penalty AS compromiso_permanencia
       , RANK () OVER (
                     PARTITION BY DEVICE.service_id, DEVICE.product_code
                     ORDER BY CASE WHEN SALES.order_day_id <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_day_id, '9999-12-31') END DESC,
                              CASE WHEN SALES.order_day_id > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_day_id, '9999-12-31') END ASC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END DESC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END ASC,
                              SALES.deactivation_date ASC,
                              CASE WHEN COALESCE(RFM_YOIGO.sfid_id, DEVICE.sfid_id) = DEALER.sfid_id THEN 1 ELSE 2 END ASC,
                              DEALER.creado DESC  --Tomamos la última actualización
                     ) AS RANK_BASE

              
FROM `mm-datamart-kd.SERVICES.devices_base_emysim` DEVICE

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` SALES
         ON CAST(DEVICE.service_id AS STRING) = SALES.service_id AND DEVICE.brand_ds = SALES.brand_ds AND SALES.data_source_ds = 'MYSIM' AND SALES.order_type_ds NOT IN ('MIGRACION CONTRATO')

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
          WHERE data_source_ds = 'MYSIM'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
          ) AS SALES_CHANNEL
         ON DEVICE.sfid_id = SALES_CHANNEL.sfid_id

LEFT JOIN TEMP.devices_base_qvantel RFM_YOIGO
         ON CAST(DEVICE.phone_nm AS STRING) = CAST(RFM_YOIGO.phone_nm AS STRING)
            AND DATE(DEVICE.order_date) = RFM_YOIGO.sell_date
            AND DEVICE.serial_number = RFM_YOIGO.serial
            AND DEVICE.brand_ds = 'YOIGO'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER 
         ON  (COALESCE(RFM_YOIGO.sfid_id, IF(LENGTH(DEVICE.sfid_id) = 2,NULL,DEVICE.sfid_id)) = DEALER.sfid_id 
                OR IF(LENGTH(DEVICE.user_store) = 2,NULL,UPPER(DEVICE.user_store)) = DEALER.sfid_id 
                OR IF(LENGTH(DEVICE.seller) = 2,NULL,UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)])) = DEALER.sfid_id 
             )

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(RFM_YOIGO.channel_segment_ds, SALES_CHANNEL.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND COALESCE(RFM_YOIGO.master_channel_ds, DEVICE.master_channel_ds) = AGRUPACION.master_channel_ds
            AND COALESCE(RFM_YOIGO.channel_ds, DEVICE.channel_ds) = AGRUPACION.channel_ds
            AND COALESCE(RFM_YOIGO.subchannel_ds, DEVICE.subchannel_ds) = AGRUPACION.subchannel_ds
            AND DEVICE.comm_brand_ds = AGRUPACION.comm_brand_ds

WHERE DEVICE.brand_ds IN ('MASMOVIL', 'YOIGO')

--  AND serial_number IN ('350811293210866','350811292534712','351981678936713','ABALBB5B19001668','356752800050714','5FTBB25B12102345','353578129823454')
  
  -- REVISAR PROBLEMA DE AUSENCIA --MISTERIO
  -- AND serial_number in ('353578129823454','48070/C31100364128','356752800050714','350811292534712','48070/C31100500236','601MARZ2HW66','ABALBB5B19001668','602MAWL0LB01','Z2532525090','602MAUA0LA74','C2534001097','602MABT0LA81','512MARZ0S982','48070/C31100490535','350811293210866','512MAMB0S827','H2539001819','512MAHU0S985','5FTBB25B12102345','0H183SJL200199','Z2544074270','351981678936713')

      AND (
              /*CAPTACION*/
           (
            DEVICE.sell_terminal_origin_ds IN ('CAPTACION', 'N.D.','AÃ±ADIR LINEA') --2024-12-04 INCLUYO AÑADIR LINEA, QUE GENERABA INCIDENCIAS
            AND COALESCE(DEVICE.terminal_status_ds, 'USADO') NOT IN ('CANCELADO','EXPEDICIÓN PENDIENTE DE CANCELACIÓN','LIBRE') --incluyo LIBRE 20250331
           ) 
          OR
           (      
              /*RENUEVO*/            
           DEVICE.sell_terminal_origin_ds IN ('RENUEVO')
           AND (
               expedition_status_ds = 'CONFIRMADA'
               OR DEVICE.terminal_status_ds = 'FINANCIACION EN CURSO'
               OR DEVICE.terminal_status_ds = 'AMORTIZACION PENDIENTE'
               OR DEVICE.terminal_status_ds = 'USADO'
               OR DEVICE.terminal_status_ds = 'EN FINANCIACION'  --2025-01 añadimos estado "EN FINANCIACION"
               )
           )
          )
)

 QUALIFY ROW_NUMBER () OVER (
            PARTITION BY service_id, product_code, serial_number
            ORDER BY RANK_BASE ASC  --Tomamos la última actualización
       ) = 1
       

UNION ALL


/* DATOS QVANTEL */
SELECT DISTINCT

       -- INFORMACIÓN DEL CANAL
        CASE WHEN UPPER(channel_id) LIKE 'RENEWAL%' THEN 'RENUEVO' ELSE 'CAPTACION' END AS sell_type

       ,DEVICE.channel_type_ds
       ,DEVICE.master_channel_ds AS master_channel_ds
       ,DEVICE.channel_ds AS channel_ds
       ,DEVICE.subchannel_ds AS subchannel_ds
       ,DEVICE.sfid_id AS sfid_id
       ,SALES.user_store AS user_store
       ,SALES.seller AS seller
       ,SALES_CHANNEL.channel_segment_ds AS channel_segment_ds
       ,DEVICE.segment_ds
       ,DEVICE.channel_id
       ,CAST(NULL AS STRING) AS sfid_ifs
       --,DEALER.zona_fiscal /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
       ,DEALER.REGION_CODE
          
       --DATOS DE LA VENTA 
       ,SALES.brand_ds
       ,'QVANTEL' AS data_source
       ,DEVICE.service_id AS id_subscription_terminal
       ,SALES.contract_id AS contract_id
       ,CAST(DEVICE.service_id AS STRING) AS service_id
       ,SALES.account_id
       ,CAST(DEVICE.customer_id AS STRING) AS customer_id
       ,CAST(DEVICE.order_id AS STRING) AS order_id
       ,CAST(DEVICE.phone_nm AS STRING) AS phone_nm
       ,CAST(DEVICE.tariff_order_id AS STRING) AS tariff_id
       ,DEVICE.tariff_order_ds AS tariff_ds
       ,DEVICE.order_type_agg
       ,COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
       ,COALESCE(SALES.sell_bundle_type, 'MO') AS bundle_type
       ,COALESCE(REPLACE(SALES.line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds
       ,COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
       ,DATE(DEVICE.sell_date) AS order_date
       ,SALES.onboarding_status_agg AS status_servicio
       ,'C -' || SALES.cancellation_subreason_agg AS motivo_cancelacion

       ,CASE 
            WHEN order_type = '2'              THEN sell_date
            WHEN order_type IN ('0', '1', '4') THEN PARSE_DATE('%Y%m%d', (CAST(DEVICE.activation_date AS STRING)))
            ELSE PARSE_DATE("%Y%m%d", (CAST(DEVICE.activation_date AS STRING)))
        END AS activation_date

       ,IF((DATE(SALES.real_deactivation_date)) IS NULL, '9999-12-31', (DATE(SALES.real_deactivation_date))) AS deactivation_date

       -- DATOS DEL TERMINAL
       ,DEVICE.order_status_ds AS terminal_status_ds
       ,DEVICE.product_code
       ,DEVICE.product_ds AS terminal_name
       ,DEVICE.product_ds AS product
       ,CAST(DEVICE.financed_months AS INTEGER) AS financed_months
       ,CAST(DEVICE.financed_monthly_quota AS INTEGER) AS financed_monthly_quota
       ,DEVICE.financed_entity
       ,DEVICE.financed_type AS is_financed_desc
       ,DEVICE.financed_type AS financed_status
       ,financed_type AS financed_type
       ,DEVICE.service_type AS technology_ds
       ,DEVICE.serial AS serial_number
       ,DEVICE.offer_segment AS offer_segmentation

       -- DATOS DE IMPORTE PARA EL SUBSIDIO
       --,IF(DEALER.zona_fiscal = 'PEN', 1.21, 1.07) AS TAX  /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
       ,COALESCE(DEALER.tax, 21) -- IMPUESTO APLICAR A LA TIENDA 
       ,DEVICE.tax_value -- IMPUESTO DEL CLIENTE
       ,DEVICE.cost AS purch_price -- COSTE DE TERMINAL SIN IMPUESTOS
       ,DEVICE.gross_subsidy_1 AS net_subsidy -- SUBSIDIO NETO CALCULADO POR NEGOCIO
       ,DEVICE.initial_payment AS end_user_price -- PAGO INICIAL DEL CLIENTE / AÑAIDO A 10 DE ENERO
       ,ROUND(
              (
              (DEVICE.cost)
              *
              ((COALESCE(DEALER.tax, 21) / 100) + 1) --IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS coste_device -- COSTE DE TERMINAL CON IMPUESTOS
          
       -- CACULAMOS CANTIDADES DE SUBSIDIOS
       ,ROUND(
              (
              DEVICE.gross_subsidy_1
              *
              ((COALESCE(DEALER.tax, 21) / 100) + 1) --IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS subsidy -- SUBSIDIO CALCULADO POR NEGOCIO 
          
       -- CALCULAMOS EL SUBSIDIO AJUSTANDO POR COSTE DE TERMINAL MENOS PAGO PLAZO Y PAGO FINAL DEL CLIENTE
       ,ROUND(
             (
             IF(DEVICE.financed_total_amount IS NULL, 0, DEVICE.financed_total_amount / (DEVICE.tax_value + 1)) 
             *
              ((COALESCE(DEALER.tax, 21) / 100) + 1) --IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS subsidy_payterm -- LLEVAMOS IMPORTE TOTAL CON IMPUESTO A TIENDA  
          
       -- PAGO A PLAZOS DEL CLIENTE 
          
       ,ROUND(
             (
             (DEVICE.q25_amount / (DEVICE.tax_value + 1))
             *
              ((COALESCE(DEALER.tax, 21) / 100) + 1) --IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
              )
             ,2
             ) AS subsidy_pay25 -- LLEVAMOS IMPORTE TOTAL CON IMPUESTO A TIENDA

       , CAST (NULL AS STRING) AS agrupacion_canal
       , CAST (NULL AS STRING) AS canal
       , CAST (NULL AS STRING) AS distribuidor
       , CAST (NULL AS STRING) AS cif
       , CAST (NULL AS STRING) AS razon_social
       , CAST (NULL AS STRING) AS nombre_comercio
       , CAST (NULL AS DATE) AS fecha_inicio_financiacion  --incluido en mar/25
       , CAST (NULL AS DATE) AS fecha_fin_financiacion     --incluido en mar/25
       , CAST (NULL AS STRING) AS cod_canal
       , CAST (NULL AS FLOAT64) AS original_cost_price
       , CAST (NULL AS FLOAT64) AS total_pay_value
       , CAST (NULL AS STRING) AS courier
       , CAST (NULL AS STRING) AS compromiso_permanencia

       , CAST (NULL AS INT64)AS RANK_BASE

FROM `mm-datamart-kd.SERVICES.devices_base_qvantel` DEVICE

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` SALES
         ON CAST(DEVICE.service_id AS STRING) = SALES.service_id AND DEVICE.phone_nm = SALES.phone_nm 
            AND DEVICE.order_id = SALES.order_id AND SALES.data_source_ds = 'QVANTEL'

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-datamart-kd.SERVICES.ventas_base_net`
          WHERE data_source_ds = 'QVANTEL'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
          ) AS SALES_CHANNEL
         ON DEVICE.sfid_id = SALES_CHANNEL.sfid_id

LEFT JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` DEALER
          --`mm-commissions-reporting.COMISIONES.v_dealer` DEALER /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */
         ON DEVICE.sfid_id = DEALER.customer_id -- DEALER.id_comisionista /* VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE */

WHERE order_status_id = '6'
      AND UPPER(DEVICE.channel_id) LIKE '%POS%'
      AND SUBSTR(DEVICE.sfid_id, 1, 3) NOT IN ('D2N', 'DEM', 'MKT')
      AND SUBSTR(DEVICE.sfid_id, 1, 2) NOT IN ('MP')
      AND DEVICE.sfid_id NOT LIKE ('%TEST%')
      AND order_type <> '6'
      AND device_type_id NOT IN ('4', '5')
      AND DEVICE.channel_type_ds = 'INDIRECTO'
      AND product_ds NOT LIKE '%SMART TV%'


UNION ALL

/* DATOS ORANGE, JAZZTEL Y SIMYO */

SELECT DISTINCT

        -- INFORMACIÓN DEL CANAL
        CASE WHEN DEVICE.sell_type = 'RENOVE' THEN 'RENUEVO' ELSE 'CAPTACION' END AS sell_type
       
       ,DEVICE.channel_type_ds AS channel_type_ds
       ,DEVICE.master_channel_ds AS master_channel_ds
       ,DEVICE.channel_ds AS channel_ds
       ,DEVICE.subchannel_ds AS subchannel_ds
       ,COALESCE(DEALER.id_comisionista, DEVICE.sfid_id) AS sfid_id  --Si tenemos id_comisionista de DEALER y si no, tomamos lo que venga
       ,COALESCE(DEALER.sfid_id, DEVICE.user_store) AS user_store    --Si tenemos sfid_id de DEALER y si no, tomamos lo que venga
       ,COALESCE(DEALER.sfid_id, UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)])) AS seller   --Si tenemos sfid_id de DEALER y si no, tomamos lo que venga
       ,SALES_CHANNEL.channel_segment_ds AS channel_segment_ds
       ,DEVICE.segment_ds
       ,CAST(NULL AS STRING) AS channel_id
       ,CAST(NULL AS STRING)AS sfid_ifs
       
--       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1 WHEN DEALER.zona_fiscal = 'CAN' THEN 4 ELSE CAST(NULL AS INT64) END AS region_code
       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1 WHEN DEALER.zona_fiscal = 'CAN' THEN 4 ELSE 1 END AS region_code
          
       --DATOS DE LA VENTA
       ,DEVICE.brand_ds
       ,DEVICE.data_source_ds AS data_source
       ,DEVICE.id_subscription_terminal
       ,SALES.contract_id AS contract_id
       ,CAST(DEVICE.service_id AS STRING) AS service_id
       ,CAST(DEVICE.account_id AS STRING) AS account_id
       ,CAST(DEVICE.customer_id AS STRING) AS customer_id
       ,CAST(DEVICE.id_subscription_terminal AS STRING) AS order_id
       ,CAST(DEVICE.phone_nm AS STRING) phone_nm
       ,CAST(DEVICE.tariff_key AS STRING) AS tariff_id
       ,DEVICE.tariff_ds

       ,CASE WHEN DEVICE.sell_type = 'RENOVE' THEN 'RENUEVO' ELSE DEVICE.order_type_agg END AS order_type_agg

       ,COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
       ,SALES.sell_bundle_type AS bundle_type
       ,COALESCE(REPLACE(SALES.sell_line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds
       ,COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
       ,DATE(DEVICE.order_date) AS order_date
       ,SALES.service_status_ds AS status_servicio
       ,'C -' || SALES.cancellation_subreason_agg AS motivo_cancelacion

       ,COALESCE(
                CASE WHEN DEVICE.sell_type IN ('ALTA NUEVA', 'PORTABILIDAD','MIGRACION') THEN SALES.activation_date END
                ,DATE(DEVICE.order_date)
                ) AS activation_date

       ,COALESCE(DATE(DEVICE.cancellation_date_ts),SALES.real_deactivation_date) AS deactivation_date

       -- DATOS DEL TERMINAL
       ,DEVICE.terminal_status_ds
       ,CAST(DEVICE.terminal_id AS STRING) AS product_code
       ,DEVICE.terminal_name
       ,DEVICE.terminal_model AS product
       ,DEVICE.financed_months
       ,DEVICE.financed_monthly_quota
       ,DEVICE.financed_entity
       ,DEVICE.is_financed_desc
       ,DEVICE.financed_status
       ,CAST (NULL AS STRING) AS financed_type
       ,DEVICE.service_type AS technology_ds
       ,DEVICE.serial_number
       ,DEVICE.offer_segmentation

       -- DATOS DE IMPORTE PARA EL SUBSIDIO
      
       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 21 WHEN DEALER.zona_fiscal = 'CAN' THEN 7 ELSE CAST(NULL AS INT64) END AS tax

       ,CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 0.21 WHEN DEALER.zona_fiscal = 'CAN' THEN 0.07 ELSE CAST(NULL AS INT64) END AS tax_value -- IMPUESTO APLICADO A CLIENTE
       
       ,CAST(NULL AS FLOAT64) AS purch_price -- COSTE DE TERMINAL SIN IMPUESTOS
       ,CAST(NULL AS FLOAT64) AS net_subsidy -- SUBSIDIO NETO CALCULADO POR NEGOCIO
       ,DEVICE.initial_payment AS end_user_price -- PAGO INICIAL DEL CLIENTE
       ,CAST(NULL AS FLOAT64) AS coste_device
          
       -- CACULAMOS CANTIDADES DE SUBSIDIOS
       ,CAST(NULL AS FLOAT64) AS subsidy

       -- CALCULAMOS EL SUBSIDIO AJUSTANDO POR COSTE DE TERMINAL MENOS PAGO PLAZO Y PAGO FINAL DEL CLIENTE
 
       ,CAST(NULL AS FLOAT64) AS subsidy_payterm       
          
       -- PAGO A PLAZOS DEL CLIENTE 
          
       ,CAST(NULL AS FLOAT64) AS subsidy_pay25

       ,AGRUPACION.agrupacion_canal AS agrupacion_canal
       ,DEALER.canal AS canal
       ,DEALER.distribuidor AS distribuidor
       ,DEALER.cif AS cif
       ,DEALER.razon_social AS razon_social
       ,DEALER.nombre_comercio AS nombre_comercio
       ,DEVICE.financed_init_date AS fecha_inicio_financiacion
       ,DEVICE.financed_end_date AS fecha_fin_financiacion
       ,AGRUPACION.codigo_canal_sap AS cod_canal
       ,CAST(NULL AS FLOAT64) AS original_cost_price
       ,DEVICE.total_pay_value
       ,DEVICE.courier
       ,DEVICE.flag_pay_penalty AS compromiso_permanencia

       , CAST (NULL AS INT64)AS RANK_BASE
       
              
FROM `mm-datamart-kd.SERVICES.devices_base_osp` DEVICE

LEFT JOIN `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp` SALES
         ON CAST(DEVICE.service_id AS STRING) = SALES.service_id AND DEVICE.brand_ds = SALES.brand_ds 

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp`
          WHERE brand_ds IN ('ORANGE','JAZZTEL')
          QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
          ) AS SALES_CHANNEL
         ON DEVICE.sfid_id = SALES_CHANNEL.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER 
         ON  (DEVICE.sfid_id = DEALER.sfid_id 
                OR DEVICE.user_store = DEALER.sfid_id 
                OR COALESCE(UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)]),DEVICE.seller) = DEALER.sfid_id 
             )

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE( SALES_CHANNEL.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND DEVICE.master_channel_ds = AGRUPACION.master_channel_ds
            AND DEVICE.channel_ds = AGRUPACION.channel_ds
            AND DEVICE.subchannel_ds = AGRUPACION.subchannel_ds
            AND DEVICE.comm_brand_ds = AGRUPACION.comm_brand_ds

WHERE DEVICE.brand_ds IN ('ORANGE', 'JAZZTEL')

     --  AND UPPER(DEVICE.terminal_name) NOT LIKE '%SMART TV%'
     --  AND UPPER(DEVICE.terminal_name) NOT LIKE '%TCL GOOGLE TV%'
     --  AND UPPER(DEVICE.terminal_name) NOT LIKE '%XIAOMI TV%'
     --  AND UPPER(DEVICE.terminal_name) NOT LIKE '%XIAOMI GOOGLE TV%'
     --  AND UPPER(DEVICE.terminal_name) NOT LIKE '%TCL ANDROID TV%'   

      AND (
              /*CAPTACION*/
           (
              (
               DEVICE.sell_type IN ('ALTA NUEVA', 'PORTABILIDAD','MIGRACION') 
               AND DEVICE.terminal_status_ds IN ('EN FINANCIACION','LIQUIDACION')
              )
              OR
              (
               DEVICE.sell_type IN ('TERMINAL SIN SERVICIO') 
               AND DEVICE.terminal_status_ds IS NULL
              )
              
           ) 
          OR
           (      
              /*RENUEVO*/            
           DEVICE.sell_type IN ('RENOVE')
           AND (
               expedition_status_ds IN ('CONFIRMACION ENTREGA','CONFIRMACIÓN ENTREGA','ENTREGADO')
               OR DEVICE.terminal_status_ds = 'EN FINANCIACION'
               OR DEVICE.terminal_status_ds = 'LIQUIDACION'
               )
           )
          )


QUALIFY RANK () OVER (
                     PARTITION BY DEVICE.service_id, DEVICE.terminal_id
                     ORDER BY CASE WHEN SALES.order_date <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_date, '9999-12-31') END DESC,
                              CASE WHEN SALES.order_date > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_date, '9999-12-31') END ASC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END DESC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END ASC,
                              SALES.deactivation_date ASC,
                              CASE WHEN DEVICE.sfid_id = DEALER.sfid_id THEN 1 ELSE 2 END ASC,
                              DEALER.creado DESC  --Tomamos la última actualización
                     ) = 1


;

END