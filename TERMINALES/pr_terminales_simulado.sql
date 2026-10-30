BEGIN

  CALL `mm-commissions-reporting.TERMINALES.pr_device_base`();
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_simulado`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  
  -- SUBSIDY
    SELECT
    'SUBSIDY'||'_'||PROCESO_PR||'_'||MES_PR||'_'||row_number () over () AS commission_id,	
    'calculado' as estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR as id_mes,	
--    `mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS) as agrupacion_canal,	
    d.agrupacion_canal AS agrupacion_canal,	
--    `mm-commissions-reporting.TERMINALES.f_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS,d.user_store) AS canal,	
    d.canal AS CANAL,
    IF(D.SUBSIDY < 0,'X - Subsidio '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE)||' Negativo','T - Subsidio Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE)) as concepto,	
    if(d.SELL_TYPE = 'CAPTACION','SUBS','SRCI') as tipo_concepto,	
    1 AS unidades,	
    d.SUBSIDY AS comision,	
    d.user_store AS id_comisionista,	
--    `mm-commissions-reporting.TERMINALES.f_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS,d.user_store) AS distribuidor,	
    d.distribuidor AS distribuidor,
    SUBSTR(d.sfid_id,1,2) AS sfid_id,	
    d.user_store AS seller,	
--    `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as nombre_comercio,	
    d.nombre_comercio AS nombre_comercio,
--    `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as razon_social,	
    d.razon_social AS razon_social,
--    `mm-commissions-reporting.TERMINALES.f_CIF`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as cif,	
    d.cif AS cif,
    --d.zona_fiscal,	
    --IF(d.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    CASE WHEN d.REGION_CODE = 1 THEN 'PEN'
         WHEN d.REGION_CODE = 4 THEN 'CAN'
         WHEN d.REGION_CODE = 3 THEN 'MEL'
    ELSE CAST(NULL AS STRING) END AS ZONA_FISCAL,
    d.brand_ds AS marca,	
    'MOBILE' AS service_type,	
    D.phone_nm,	
    D.tariff_id,	
    D.tariff_ds,	
    D.service_id,	
    D.account_id,	
    D.customer_id,	
    D.line_type_ds,	
    D.bundle_type,	
    D.technology_ds,	
    D.billing_type_ds,	
    D.order_date AS sale_date,	
    D.activation_date,	
    D.deactivation_date,	
    D.order_id,	-- ORDENES DE PEDIDO QVANTEL - EL ID_SUBSCRIPTION_TERMINAL PROVIENE DE MYSIM, ESTE SISTEMA ES EL PARÁMETRO DE PEDIDO, AL NO CONTENER NI CONTRACT_ID NI ORDER_ID
    D.order_type_agg,	
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(D.segment_ds,D.brand_ds) AS cod_segmento,	
    `mm-commissions-reporting.COMISIONES.f_cod_marca`(brand_ds,'MOBILE') AS cod_marca,	
        CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, 'MOBILE', bundle_type, technology_ds, brand_ds, line_type_ds)
          END AS cod_tipo_contrato,	
/*
    CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,cast(null as string)) 
          END as cod_producto,	
*/
     --2024/04/18 Nuevos parámetros de la f_ventas_base_net_cod_producto [FREDY]
     CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,d.sell_type, CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, 'MOBILE', bundle_type, technology_ds, brand_ds, line_type_ds)
          END)
       
          END as cod_producto,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(d.channel_ds,d.subchannel_ds) as cod_canal,	
    'COM-3450' as claim_code,
    cast(null as string) as campaign_code,	
    PROCESO_PR as process_code,	
    d.data_source as comments,	
    'C_TERMINALES' as facturador,	
    cast(null as string) as proceso_sap,	
    cast(null as string) as id_registro,	
    cast(null as string) as invoice_id,	
--    cast(null as string) as sociedad,	 --Rellenamos la sociedad JG 2024-04-10
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING) END AS sociedad,
    cast(null as string) as bp,	
    cast(null as string) as cuenta_contable,	
    cast(null as string) as centro_coste,	
    cast(null as string) as documento_sap,	
    cast(null as string) as documento_sap_posicion,	
    cast(null as string) as fecha_contabilizacion,	
    CURRENT_TIMESTAMP() as creado,	
    CURRENT_TIMESTAMP() as modificado,	
    cast(null as string) as id_factura_drive,	
    [''] as emails_acceso_trazabilidad,	
    d.serial_number AS IMEI,	
    cast(null as string) as DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    cast(null as string) as AFTER_SALE,	-- PENDIENTE DESARROLLO
    d.PRODUCT_CODE,	
    D.TERMINAL_NAME,	
    D.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    D.PURCH_PRICE,
    d.NET_SUBSIDY,
    --d.END_USER_PRICE,
    d.pago_inicial AS END_USER_PRICE,
    d.COSTE_DEVICE,
    d.offer_segmentation,
    'PAYTERM'||'_'||D.financed_months||'_'||D.financed_monthly_quota AS INSTALLMENT_ID,
    CASE 
      WHEN D.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM
--    `mm-commissions-reporting.TERMINALES.v_device_base` d
    `mm-commissions-reporting.TEMP.device_base` d
    where
    d.activation_date between ACTI_INI and ACTI_FINAL
    and d.SUBSIDY <> 0
    AND d.serial_number is not null 
    and d.seller not in ('PHJFIDER','TPFFOST') and d.user_store not in ('PHJFIDER','TPFFOST') and sfid_id not in ('PHJFIDER','TPFFOST')
  
  union all

  -- SUBSIDY_PAYTERM
    SELECT
    'PAYTERM'||'_'||PROCESO_PR||'_'||MES_PR||'_'||row_number () over () AS commission_id,	
    'calculado' as estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR as id_mes,	
--    `mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS) as agrupacion_canal,	
    d.agrupacion_canal AS agrupacion_canal,	
--    `mm-commissions-reporting.TERMINALES.f_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS,d.user_store) AS canal,	
    d.canal AS CANAL,
    'T - Pago a Plazos Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE) as concepto,	
    'FINT' as tipo_concepto,	
    1 AS unidades,	
    d.SUBSIDY_PAYTERM AS comision,	
    d.user_store AS id_comisionista,	
--    `mm-commissions-reporting.TERMINALES.f_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS,d.user_store) AS distribuidor,	
    d.distribuidor AS distribuidor,
    SUBSTR(d.sfid_id,1,2) AS sfid_id,	
    d.user_store AS seller,	
--    `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as nombre_comercio,	
    d.nombre_comercio AS nombre_comercio,
--    `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as razon_social,	
    d.razon_social AS razon_social,
--    `mm-commissions-reporting.TERMINALES.f_CIF`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as cif,	
    d.cif AS cif,
    --d.zona_fiscal,	
    --IF(d.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    CASE WHEN d.REGION_CODE = 1 THEN 'PEN'
         WHEN d.REGION_CODE = 4 THEN 'CAN'
         WHEN d.REGION_CODE = 3 THEN 'MEL'
    ELSE CAST(NULL AS STRING) END AS ZONA_FISCAL,
    d.brand_ds AS marca,	
    'MOBILE' AS service_type,	
    D.phone_nm,	
    D.tariff_id,	
    D.tariff_ds,	
    D.service_id,	
    D.account_id,	
    D.customer_id,	
    D.line_type_ds,	
    D.bundle_type,	
    D.technology_ds,	
    D.billing_type_ds,	
    D.order_date AS sale_date,	
    D.activation_date,	
    D.deactivation_date,	
    D.order_id,	-- ORDENES DE PEDIDO QVANTEL - EL ID_SUBSCRIPTION_TERMINAL PROVIENE DE MYSIM, ESTE SISTEMA ES EL PARÁMETRO DE PEDIDO, AL NO CONTENER NI CONTRACT_ID NI ORDER_ID
    D.order_type_agg,	
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(D.segment_ds,D.brand_ds) AS cod_segmento,	
    `mm-commissions-reporting.COMISIONES.f_cod_marca`(brand_ds,'MOBILE') AS cod_marca,	
        CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, 'MOBILE', bundle_type, technology_ds, brand_ds, line_type_ds)
          END AS cod_tipo_contrato,	
/*
    CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,cast(null as string)) 
          END as cod_producto,	
*/
     --2024/04/18 Nuevos parámetros de la f_ventas_base_net_cod_producto [FREDY]
     CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,d.sell_type, CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, 'MOBILE', bundle_type, technology_ds, brand_ds, line_type_ds)
          END)
       
          END as cod_producto,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(d.channel_ds,d.subchannel_ds) as cod_canal,	
    'COM-3450' as claim_code,	
    cast(null as string) as campaign_code,	
    PROCESO_PR as process_code,	
    d.data_source as comments,	
    'C_TERMINALES' as facturador,	
    cast(null as string) as proceso_sap,	
    cast(null as string) as id_registro,	
    cast(null as string) as invoice_id,	
--    cast(null as string) as sociedad,	 --Rellenamos la sociedad JG 2024-04-10
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING) END AS sociedad,
    cast(null as string) as bp,	
    cast(null as string) as cuenta_contable,	
    cast(null as string) as centro_coste,	
    cast(null as string) as documento_sap,	
    cast(null as string) as documento_sap_posicion,	
    cast(null as string) as fecha_contabilizacion,	
    CURRENT_TIMESTAMP() as creado,	
    CURRENT_TIMESTAMP() as modificado,	
    cast(null as string) as id_factura_drive,	
    [''] as emails_acceso_trazabilidad,
    d.serial_number AS IMEI,	
    cast(null as string) as DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    cast(null as string) as AFTER_SALE,	-- PENDIENTE DESARROLLO
    d.PRODUCT_CODE,	
    D.TERMINAL_NAME,	
    D.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    D.PURCH_PRICE,
    d.NET_SUBSIDY,
    --d.END_USER_PRICE,
    d.pago_inicial AS END_USER_PRICE,
    d.COSTE_DEVICE,
    d.offer_segmentation,
    'PAYTERM'||'_'||D.financed_months||'_'||D.financed_monthly_quota AS INSTALLMENT_ID,
    CASE 
      WHEN D.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM
--    `mm-commissions-reporting.TERMINALES.v_device_base` d
    `mm-commissions-reporting.TEMP.device_base` d
    
    where
    d.activation_date between ACTI_INI and ACTI_FINAL
    and d.SUBSIDY_PAYTERM <> 0
    AND d.serial_number is not null
    and d.seller not in ('PHJFIDER','TPFFOST') and d.user_store not in ('PHJFIDER','TPFFOST') and sfid_id not in ('PHJFIDER','TPFFOST')
    
  union all

  -- SUBSIDY_SUBSIDY_PAY25
    SELECT
    'PAY25'||'_'||PROCESO_PR||'_'||MES_PR||'_'||row_number () over () AS commission_id,	
    'calculado' as estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR as id_mes,	
--    `mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS) as agrupacion_canal,	
    d.agrupacion_canal AS agrupacion_canal,	
--    `mm-commissions-reporting.TERMINALES.f_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS,d.user_store) AS canal,	
    d.canal AS CANAL,
    'T - Pago Final Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE) as concepto,	
    'FINT' as tipo_concepto,	
    1 AS unidades,	
    d.SUBSIDY_PAY25 AS comision,	
    d.user_store AS id_comisionista,	
--    `mm-commissions-reporting.TERMINALES.f_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS,d.user_store) AS distribuidor,	
    d.distribuidor AS distribuidor,
    SUBSTR(d.sfid_id,1,2) AS sfid_id,	
    d.user_store AS seller,	
--    `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as nombre_comercio,	
    d.nombre_comercio AS nombre_comercio,
--    `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as razon_social,	
    d.razon_social AS razon_social,
--    `mm-commissions-reporting.TERMINALES.f_CIF`(`mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(d.CHANNEL_TYPE_DS, d.MASTER_CHANNEL_DS,d.CHANNEL_DS, d.SUBCHANNEL_DS)) as cif,	
    d.cif AS cif,
    --d.zona_fiscal,	
    --IF(d.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    CASE WHEN d.REGION_CODE = 1 THEN 'PEN'
         WHEN d.REGION_CODE = 4 THEN 'CAN'
         WHEN d.REGION_CODE = 3 THEN 'MEL'
    ELSE CAST(NULL AS STRING) END AS ZONA_FISCAL,
    d.brand_ds AS marca,	
    'MOBILE' AS service_type,	
    D.phone_nm,	
    D.tariff_id,	
    D.tariff_ds,	
    D.service_id,	
    D.account_id,	
    D.customer_id,	
    D.line_type_ds,	
    D.bundle_type,	
    D.technology_ds,	
    D.billing_type_ds,	
    D.order_date AS sale_date,	
    D.activation_date,	
    D.deactivation_date,	
    D.order_id,	-- ORDENES DE PEDIDO QVANTEL - EL ID_SUBSCRIPTION_TERMINAL PROVIENE DE MYSIM, ESTE SISTEMA ES EL PARÁMETRO DE PEDIDO, AL NO CONTENER NI CONTRACT_ID NI ORDER_ID
    D.order_type_agg,	
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(D.segment_ds,D.brand_ds) AS cod_segmento,	
    `mm-commissions-reporting.COMISIONES.f_cod_marca`(brand_ds,'MOBILE') AS cod_marca,	
        CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, 'MOBILE', bundle_type, technology_ds, brand_ds, line_type_ds)
          END AS cod_tipo_contrato,	
/*
    CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,cast(null as string)) 
          END as cod_producto,	
*/
     --2024/04/18 Nuevos parámetros de la f_ventas_base_net_cod_producto [FREDY]
     CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,d.sell_type, CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END  
          ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, 'MOBILE', bundle_type, technology_ds, brand_ds, line_type_ds)
          END)
       
          END as cod_producto,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(d.channel_ds,d.subchannel_ds) as cod_canal,	
    'COM-3450' as claim_code,	
    cast(null as string) as campaign_code,	
    PROCESO_PR as process_code,	
    d.data_source as comments,
    'C_TERMINALES' as facturador,	
    cast(null as string) as proceso_sap,	
    cast(null as string) as id_registro,	
    cast(null as string) as invoice_id,	
--    cast(null as string) as sociedad,	 --Rellenamos la sociedad JG 2024-04-10
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING) END AS sociedad,
    cast(null as string) as bp,	
    cast(null as string) as cuenta_contable,	
    cast(null as string) as centro_coste,	
    cast(null as string) as documento_sap,	
    cast(null as string) as documento_sap_posicion,	
    cast(null as string) as fecha_contabilizacion,	
    CURRENT_TIMESTAMP() as creado,	
    CURRENT_TIMESTAMP() as modificado,	
    cast(null as string) as id_factura_drive,	
    [''] as emails_acceso_trazabilidad,
    d.serial_number AS IMEI,	
    cast(null as string) as DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    cast(null as string) as AFTER_SALE,	-- PENDIENTE DESARROLLO
    d.PRODUCT_CODE,	
    D.TERMINAL_NAME,	
    D.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    D.PURCH_PRICE,
    d.NET_SUBSIDY,
    --d.END_USER_PRICE,
    d.pago_inicial AS END_USER_PRICE,
    d.COSTE_DEVICE,
    d.offer_segmentation,
    'PAYTERM'||'_'||D.financed_months||'_'||D.financed_monthly_quota AS INSTALLMENT_ID,
    CASE 
      WHEN D.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM
--    `mm-commissions-reporting.TERMINALES.v_device_base` d
    `mm-commissions-reporting.TEMP.device_base` d
    
    where
    d.activation_date between ACTI_INI and ACTI_FINAL
    and d.SUBSIDY_PAY25 <> 0
    AND d.serial_number is not null
    and d.seller not in ('PHJFIDER','TPFFOST') and d.user_store not in ('PHJFIDER','TPFFOST') and sfid_id not in ('PHJFIDER','TPFFOST')

  ;
END