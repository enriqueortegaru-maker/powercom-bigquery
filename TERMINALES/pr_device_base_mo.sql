BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_device_base_mo`();

  /********************
  -- EN CONSTRUCCION --
  ********************/

  /***************************************************************
  * CAMPOS QUE FALTAN EN device_base_mo                          *
  * 01.-subchannel_ds (no fundamental)                           * 
  * 02.-user_store (no fundamental)                              *
  * 03.-tariff_id (no coincide master_tariff_id con info MySIM)  *
  * 04.-tariff_ds                                                *
  * 05.-order_type_agg                                           *
  * 06.-sell_type                                                *
  * 07.-sell_terminal_origin_ds                                  *
  * 08.-terminal_status_ds (FUNDAMENTAL)                         *
  * 09.-tech_description                                         *
  * 10.-offer_segmentation                                       *
  * 11.-courier                                                  *
  * 12.-flag_pay_penalty                                         *
  ***************************************************************/

  SELECT DISTINCT

          -- INFORMACIÓN DEL CANAL
          CASE WHEN DEVICE.order_type_ds = 'RENEWAL' THEN 'RENUEVO'
               WHEN DEVICE.order_type_ds IN ('NEW SIGN UP','PORTABILITY','MIGRATION') THEN 'CAPTACION'
               WHEN DEVICE.order_type_ds = 'TERMINAL WITHOUT SERVICE' THEN 'VENTA LIBRE SIN SERVICE_ID'
               ELSE DEVICE.order_type_ds END AS sell_type

        , COALESCE(RFM_YOIGO.channel_type_ds, 
            CASE WHEN DEALER.agrupacion_canal IS NOT NULL THEN 'INDIRECTO' ELSE 'DIRECTO' END
          ) AS channel_type_ds
        , COALESCE(RFM_YOIGO.master_channel_ds,UPPER(DEALER.agrupacion_canal),'TELESALES') AS master_channel_ds 
        , CASE WHEN RFM_YOIGO.channel_ds IS NOT NULL THEN RFM_YOIGO.channel_ds
               WHEN UPPER(DEALER.agrupacion_canal) = 'EXCLUSIVO' THEN 'EXCLUSIVO MULTIMARCA'
               WHEN UPPER(DEALER.agrupacion_canal) = 'NO EXCLUSIVO' THEN 'NATIONAL RETAIL'
               WHEN DEALER.agrupacion_canal IS NULL AND DEVICE.order_type_ds IN ('RENEWAL','MIGRATION') THEN 'RETENCION'
               WHEN DEALER.agrupacion_canal IS NULL AND DEVICE.order_type_ds NOT IN ('RENEWAL','MIGRATION') THEN 'ATENCION AL CLIENTE'
               WHEN DEALER.agrupacion_canal IS NULL AND DEVICE.order_type_ds IS NULL THEN 'ATENCION AL CLIENTE'
               ELSE DEALER.agrupacion_canal END AS channel_ds
        , COALESCE(RFM_YOIGO.subchannel_ds, DBMySIM.subchannel_ds) AS subchannel_ds      --REVISAR, LO ESTAMOS CRUZANDO CON device_base_mysim
        , COALESCE(DEALER.id_comisionista, RFM_YOIGO.sfid_id, DEVICE.sfid_id) AS sfid_id  
        , COALESCE(DEALER.sfid_id, RFM_YOIGO.sfid_id, DBMySIM.user_store) AS user_store  --REVISAR, LO ESTAMOS CRUZANDO CON device_base_mysim
        , COALESCE(DEALER.sfid_id, RFM_YOIGO.sfid_id, DBMySIM.user_store) AS seller      --REVISAR, LO ESTAMOS CRUZANDO CON device_base_mysim
        , CASE WHEN RFM_YOIGO.channel_segment_ds IS NOT NULL THEN RFM_YOIGO.channel_segment_ds
               WHEN DEVICE.segment_ds IN ('RESIDENTIAL') THEN 'RESIDENCIAL'
               WHEN DEVICE.segment_ds IN ('ENTERPRISE')  THEN 'EMPRESA'
               ELSE SALES_CHANNEL.channel_segment_ds END AS channel_segment_ds
        , CASE WHEN RFM_YOIGO.channel_segment_ds IS NOT NULL THEN RFM_YOIGO.channel_segment_ds
               WHEN DEVICE.segment_ds IN ('RESIDENTIAL') THEN 'RESIDENCIAL'
               WHEN DEVICE.segment_ds IN ('ENTERPRISE')  THEN 'EMPRESA'
               ELSE SALES_CHANNEL.channel_segment_ds END AS segment_ds
        , CAST(NULL AS STRING) AS channel_id
        , CAST(NULL AS STRING)AS sfid_ifs     --LO ELIMINO
        , CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1 WHEN DEALER.zona_fiscal = 'CAN' THEN 4 ELSE 1 END AS region_code

        --DATOS DE LA VENTA
        , UPPER(DEVICE.brand_ds) AS brand_ds
        , CASE WHEN RFM_YOIGO.sfid_id IS NOT NULL THEN 'RFM_YOIGO' ELSE UPPER(DEVICE.data_source_ds) END AS data_source
        , DEVICE.device_subscription_id AS id_subscription_terminal
        , SALES.contract_id AS contract_id
        , DEVICE.service_id
        , DEVICE.account_id
        , DEVICE.customer_id
        , CAST(DEVICE.device_subscription_id AS STRING) AS order_id
        , CAST(DEVICE.phone_nm AS STRING) phone_nm
        , CAST(DEVICE.master_tariff_id AS STRING) AS tariff_id  --No coincide con mm-datamart-kd.DEVICES.device_base_mysim
        , SALES.sell_tariff_id , SALES.sell_tariff_ds
        , 'PENDIENTE' AS tariff_ds
        , 'PENDIENTE' AS order_type_agg
        , COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
        , COALESCE(SALES.bundle_type,SALES.sell_bundle_type, 'MO') AS bundle_type
        , COALESCE(REPLACE(SALES.line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds
        , COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
        , DATE(DEVICE.order_date) AS order_date
        , SALES.onboarding_status_agg AS status_servicio
        , 'C -' || SALES.cancellation_subreason_agg AS motivo_cancelacion
--        ,CASE WHEN DEVICE.sell_type = 'POSVENTA' AND DEVICE.sell_terminal_origin_ds in ('RENUEVO') THEN 'RENUEVO' ELSE DEVICE.order_type_agg END AS order_type_agg
        , COALESCE(
                  CASE WHEN /*DEVICE.sell_terminal_origin_ds IN ('RENUEVO') AND*/ RFM_YOIGO.billing_type_ds IS NOT NULL THEN
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
                , PARSE_DATE('%Y%m%d', CAST(RFM_YOIGO.activation_date AS STRING))
                --,CASE WHEN DEVICE.sell_type = 'VENTA' THEN SALES.activation_date END
                , CASE WHEN DATE_DIFF (DEVICE.order_date,SALES.activation_date,DAY) > 30 THEN SALES.activation_date END
                , CASE WHEN DATE_DIFF (DEVICE.order_date,SALES.activation_date,DAY) < 30 THEN DEVICE.order_date END
                , DATE(DEVICE.order_date)
        ) AS activation_date
        , COALESCE(RFM_YOIGO.end_date, SALES.real_deactivation_date) AS deactivation_date

      -- DATOS DEL TERMINAL
--       , DEVICE.terminal_status_ds
       , TEST_MYSIM.terminal_status_ds
       , DEVICE.device_master_id AS product_code
       , COALESCE(MAESTRO.product_base,MAESTRO.product,DEVICE.device_model_ds) AS terminal_name
       , COALESCE(RFM_YOIGO.product_ds, CAST(NULL AS STRING)) AS product
       , DEVICE.financed_months
       , DEVICE.financed_monthly_quota
       , DEVICE.financed_entity_ds AS financed_entity
       , DEVICE.is_financed_flg AS is_financed_desc
       , DEVICE.financed_status_ds AS financed_status
       , CAST (NULL AS STRING) AS financed_type
       , CASE WHEN MAESTRO.family IN ('ROUTER','MODEM') THEN 'BROADBAND' 
              WHEN MAESTRO.family IN ('TERMINAL','SANITARIOS','SIM','GENÉRICA','WEARABLE','PORTATIL','PAPELERIA','ACCESORIOS','HOME','TABLET','SMWATCH','TERMINALNSPH','CONSOLAS','STOCK CONSIGNA') THEN 'MOBILE' 
              ELSE MAESTRO.family END AS technology_ds --construir un case con MAESTRO.family para probar. Son 'BROADBAND' o 'MOBILE' los valores originares
       , DEVICE.serial_number
       , CAST (NULL AS STRING) AS offer_segmentation

     -- DATOS DE IMPORTE PARA EL SUBSIDIO     
       , CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 21
              WHEN DEALER.zona_fiscal = 'CAN' THEN  7
              WHEN DEVICE.tax_value = 0.21    THEN 21
              WHEN DEVICE.tax_value = 0.07    THEN  7
              ELSE CAST(NULL AS INT64) END AS tax
       , DEVICE.tax_value -- IMPUESTO APLICADO A CLIENTE
       , DEVICE.cost_price_without_vat AS purch_price -- COSTE DE TERMINAL SIN IMPUESTOS
       , DEVICE.gross_subsidy_1 AS net_subsidy -- SUBSIDIO NETO CALCULADO POR NEGOCIO
       , DEVICE.initial_payment AS end_user_price -- PAGO INICIAL DEL CLIENTE
       , ROUND(
                (
                  (DEVICE.cost_price_without_vat)
                  *
                  --IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) -- VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE
                  CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1.21
                       WHEN DEALER.zona_fiscal = 'CAN' THEN 1.07
                       WHEN DEVICE.tax_value = 0.21    THEN 1.21
                       WHEN DEVICE.tax_value = 0.07    THEN 1.07
                       ELSE CAST(1.21 AS INT64) END 
                )
                ,2
              ) AS coste_device -- COSTE DE TERMINAL CON IMPUESTOS
       -- CACULAMOS CANTIDADES DE SUBSIDIOS
       , ROUND(
                (
                  DEVICE.gross_subsidy_1
                  *
                  --IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) -- VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE 
                  CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1.21
                       WHEN DEALER.zona_fiscal = 'CAN' THEN 1.07
                       WHEN DEVICE.tax_value = 0.21    THEN 1.21
                       WHEN DEVICE.tax_value = 0.07    THEN 1.07
                       ELSE CAST(1.21 AS INT64) END 
                )
                ,2
              ) AS subsidy -- SUBSIDIO CALCULADO POR NEGOCIO 
       -- PAGO A PLAZOS DEL CLIENTE 
       , ROUND(
                 (
                  IF(DEVICE.financed_total_amount IS NULL, 0, DEVICE.financed_total_amount / (DEVICE.tax_value + 1)) 
                  *
--                  IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) -- VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE 
                  CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1.21
                       WHEN DEALER.zona_fiscal = 'CAN' THEN 1.07
                       WHEN DEVICE.tax_value = 0.21    THEN 1.21
                       WHEN DEVICE.tax_value = 0.07    THEN 1.07
                       ELSE CAST(1.21 AS INT64) END 
                 )
               ,2
               ) AS subsidy_payterm -- LLEVAMOS IMPORTE TOTAL CON IMPUESTO A TIENDA           
       -- VALOR RESIDUAL (Q25)
       , ROUND( 
                (
                  (DEVICE.q25_amount / (DEVICE.tax_value + 1))
                  *
--              IF(DEALER.zona_fiscal = 'PEN',1.21,1.07) -- VOLVER A HABILITAR CUANDO ÓPTICO EXCLUSIVO SE AÑADA CORRECTAMENTE 
                  CASE WHEN DEALER.zona_fiscal = 'PEN' THEN 1.21
                       WHEN DEALER.zona_fiscal = 'CAN' THEN 1.07
                       WHEN DEVICE.tax_value = 0.21    THEN 1.21
                       WHEN DEVICE.tax_value = 0.07    THEN 1.07
                       ELSE CAST(1.21 AS INT64) END 
                )
                ,2
              ) AS subsidy_pay25 -- LLEVAMOS IMPORTE TOTAL CON IMPUESTO A TIENDA
       , COALESCE(AGRUPACION.agrupacion_canal, DEALER.agrupacion_canal, 'TELEVENTA') AS agrupacion_canal
       , DEALER.canal AS canal
       , DEALER.distribuidor AS distribuidor
       , DEALER.cif AS cif
       , DEALER.razon_social AS razon_social
       , DEALER.nombre_comercio AS nombre_comercio
       , DEVICE.financed_init_date AS fecha_inicio_financiacion
       , DEVICE.financed_end_date AS fecha_fin_financiacion
       , AGRUPACION.codigo_canal_sap AS cod_canal
       , COALESCE(DEVICE.cost_original_price, 0.0) AS original_cost_price
       , DEVICE.total_pay_value
       , CAST (NULL AS STRING) AS courier
       , CAST (NULL AS STRING) AS compromiso_permanencia

  FROM `mm-datamart-kd.DEVICES.device_base_mo` DEVICE

  LEFT JOIN TEMP.devices_base_qvantel RFM_YOIGO
          ON CAST(DEVICE.phone_nm AS STRING) = CAST(RFM_YOIGO.phone_nm AS STRING)
              AND DATE(DEVICE.order_date) = RFM_YOIGO.sell_date
              AND DEVICE.serial_number = RFM_YOIGO.serial
              AND DEVICE.brand_ds = 'YOIGO'

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER 
          ON  (COALESCE(RFM_YOIGO.sfid_id, IF(LENGTH(DEVICE.sfid_id) = 2,NULL,DEVICE.sfid_id)) = DEALER.sfid_id 
                  OR IF(LENGTH(DEVICE.sfid_id) = 2,NULL,UPPER(DEVICE.sfid_id)) = DEALER.sfid_id 
                  OR IF(LENGTH(DEVICE.create_user_id) = 2,NULL,UPPER(SPLIT(DEVICE.create_user_id, "@")[OFFSET(0)])) = DEALER.sfid_id 
              )
          AND CAST(FORMAT_DATE('%Y%m', SAFE_CAST(order_date AS DATE)) AS INT64) = DEALER.id_mes

  LEFT JOIN ( 
              SELECT UPPER(DBM.sfid_id) AS sfid_id, UPPER(DBM.user_store) AS user_store, DBM.master_channel_ds, DBM.superchannel_ds, DBM.channel_ds, DBM.subchannel_ds 
              FROM `mm-datamart-kd.DEVICES.device_base_mysim` DBM 
              QUALIFY ROW_NUMBER () OVER (
                        PARTITION BY DBM.sfid_id, DBM.user_store
                        ORDER BY DBM.order_date DESC) = 1
            ) DBMySIM
          ON DBMySIM.user_store = DEVICE.sfid_id

  LEFT JOIN (
              SELECT channel_segment_ds, sfid_id
              FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
              WHERE data_source_ds = 'MYSIM'
              QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
            ) AS SALES_CHANNEL
          ON DEVICE.sfid_id = SALES_CHANNEL.sfid_id

  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` SALES
          ON  CAST(DEVICE.service_id AS STRING) = SALES.service_id 
          AND DEVICE.brand_ds = SALES.brand_ds 
          AND SALES.data_source_ds = UPPER(DEVICE.data_source_ds)
          --AND SALES.order_type_ds NOT IN ('MIGRACION CONTRATO')

  LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` TEST_MYSIM
        ON  TEST_MYSIM.serial_number = DEVICE.serial_number
        AND TEST_MYSIM.service_id    = DEVICE.service_id

  LEFT JOIN `mm-datamart-kd.LOGISTICS.log_maestro_productos_completo` MAESTRO
        ON MAESTRO.reference = DEVICE.device_master_id

  LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
        ON COALESCE(RFM_YOIGO.channel_segment_ds, SALES_CHANNEL.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
          AND COALESCE(RFM_YOIGO.master_channel_ds, COALESCE(RFM_YOIGO.master_channel_ds,UPPER(DEALER.agrupacion_canal),'TELESALES'), CAST(NULL AS STRING)) = AGRUPACION.master_channel_ds
          AND COALESCE(RFM_YOIGO.channel_ds
            , CASE WHEN RFM_YOIGO.channel_ds IS NOT NULL THEN RFM_YOIGO.channel_ds
               WHEN UPPER(DEALER.agrupacion_canal) = 'EXCLUSIVO' THEN 'EXCLUSIVO MULTIMARCA'
               WHEN UPPER(DEALER.agrupacion_canal) = 'NO EXCLUSIVO' THEN 'NATIONAL RETAIL'
               WHEN DEALER.agrupacion_canal IS NULL AND DEVICE.order_type_ds IN ('RENEWAL','MIGRATION') THEN 'RETENCION'
               WHEN DEALER.agrupacion_canal IS NULL AND DEVICE.order_type_ds NOT IN ('RENEWAL','MIGRATION') THEN 'ATENCION AL CLIENTE'
               WHEN DEALER.agrupacion_canal IS NULL AND DEVICE.order_type_ds IS NULL THEN 'ATENCION AL CLIENTE'
               ELSE DEALER.agrupacion_canal END
            , CAST(NULL AS STRING)) = AGRUPACION.channel_ds
          AND COALESCE(RFM_YOIGO.subchannel_ds
            , COALESCE(RFM_YOIGO.subchannel_ds, DBMySIM.subchannel_ds)
            , CAST(NULL AS STRING)) = AGRUPACION.subchannel_ds
          AND DEVICE.comm_brand_ds = AGRUPACION.comm_brand_ds

  WHERE DEVICE.brand_ds IN ('MASMOVIL','YOIGO')
    AND DEVICE.order_date >= '2026-07-01'
    AND DEVICE.phone_nm IN (637132437,665190379)
  ;

  /*******************************************************************************************************
        SELECT dbm.serial_number, dbm.terminal_description_status, DEVICE.serial_number, DEVICE.sale_flg
        FROM `mm-datamart-kd.DEVICES.device_base_mysim` dbm
        LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mo` DEVICE 
        ON  DEVICE.serial_number = dbm.serial_number
        AND CAST(DEVICE.order_date AS DATE) = CAST(dbm.order_date AS DATE)
        WHERE dbm.order_date > '2026-07-01'
        LIMIT 1000
  ********************************************************************************************************/

END