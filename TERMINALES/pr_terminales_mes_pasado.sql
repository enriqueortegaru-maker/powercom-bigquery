BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_terminales_mes_pasado`('REAL', 202605, '2026-05-01', '2026-02-01','2026-04-30')

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(
  
  -- SUBSIDY
    SELECT
    'SUBSIDY_RECUPERA'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    d.agrupacion_canal AS agrupacion_canal,	
    d.canal AS canal,
    IF(D.SUBSIDY < 0,'X - Subsidio '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE)||' Negativo','T - Subsidio Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE)) AS concepto,	
    if(d.SELL_TYPE = 'CAPTACION','SUBS','SRCI') AS tipo_concepto,	
    1 AS unidades,	
    d.SUBSIDY AS comision,	
    d.user_store AS id_comisionista,	
    d.distribuidor AS distribuidor,
    SUBSTR(d.sfid_id,1,2) AS sfid_id,	
    d.user_store AS seller,	
    d.nombre_comercio AS nombre_comercio,
    d.razon_social AS razon_social,
    d.cif AS cif,
    CASE WHEN d.REGION_CODE = 1 THEN 'PEN'
         WHEN d.REGION_CODE = 4 THEN 'CAN'
         WHEN d.REGION_CODE = 3 THEN 'MEL'
    ELSE CAST(NULL AS STRING)  END AS ZONA_FISCAL,
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
       
          END AS cod_producto,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(d.channel_ds,d.subchannel_ds) AS cod_canal,	
    'RECUPERACION MES ANTERIOR' AS claim_code,	
    CAST(NULL AS STRING)  AS campaign_code,	
    PROCESO_PR AS process_code,	
    d.data_source AS comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING)  END AS sociedad,
    CAST(NULL AS STRING) AS bp,	
    CAST(NULL AS STRING) AS cuenta_contable,	
    CAST(NULL AS STRING) AS centro_coste,	
    CAST(NULL AS STRING) AS documento_sap,	
    CAST(NULL AS STRING) AS documento_sap_posicion,	
    CAST(NULL AS STRING) AS fecha_contabilizacion,	
    CURRENT_TIMESTAMP()  AS creado,	
    CURRENT_TIMESTAMP()  AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,	
    d.serial_number AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    'RECUPERACION MES ANTERIOR' AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    d.PRODUCT_CODE,	
    D.TERMINAL_NAME,	
    D.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    D.PURCH_PRICE,
    d.NET_SUBSIDY,
    d.END_USER_PRICE,
    d.COSTE_DEVICE,
    d.offer_segmentation,
    'PAYTERM'||'_'||D.financed_months||'_'||D.financed_monthly_quota AS INSTALLMENT_ID,
    CASE 
      WHEN D.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM `mm-commissions-reporting.TEMP.device_base_dealer` d  --`mm-commissions-reporting.TEMP.device_base` d  

    INNER JOIN `mm-commissions-reporting.TEMP.terminales_no_abonados_mes_pasado` t  --ASEGURARNOS DE EJECUTAR "TERMINALES_A_RECUPERAR_MES_PASADO" PARA CREAR ESTA TABLA TEMPORAL
      ON  t.IMEI = d.serial_number
      AND t.order_id = d.id_subscription_terminal
    
    WHERE
    d.activation_date BETWEEN ACTI_INI AND ACTI_FINAL
    AND d.SUBSIDY <> 0
    AND d.serial_number IS NOT NULL 
    AND d.seller NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    AND d.user_store NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    AND d.sfid_id NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
  
  UNION ALL

  -- SUBSIDY_PAYTERM
    SELECT
    'PAYTERM_RECUPERA'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	

    d.agrupacion_canal AS agrupacion_canal,	
    d.canal AS CANAL,
    'T - Pago a Plazos Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE) AS concepto,	
    'FINT' AS tipo_concepto,	
    1 AS unidades,	
    d.SUBSIDY_PAYTERM AS comision,	
    d.user_store AS id_comisionista,	
    d.distribuidor AS distribuidor,
    SUBSTR(d.sfid_id,1,2) AS sfid_id,	
    d.user_store AS seller,	
    d.nombre_comercio AS nombre_comercio,
    d.razon_social AS razon_social,
    d.cif AS cif,
    CASE WHEN d.REGION_CODE = 1 THEN 'PEN'
         WHEN d.REGION_CODE = 4 THEN 'CAN'
         WHEN d.REGION_CODE = 3 THEN 'MEL'
    ELSE CAST(NULL AS STRING)  END AS ZONA_FISCAL,
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
       
          END AS cod_producto,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(d.channel_ds,d.subchannel_ds) AS cod_canal,	
    'RECUPERACION MES ANTERIOR' AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    d.data_source AS comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING)  END AS sociedad,
    CAST(NULL AS STRING) AS bp,	
    CAST(NULL AS STRING) AS cuenta_contable,	
    CAST(NULL AS STRING) AS centro_coste,	
    CAST(NULL AS STRING) AS documento_sap,	
    CAST(NULL AS STRING) AS documento_sap_posicion,	
    CAST(NULL AS STRING) AS fecha_contabilizacion,	
    CURRENT_TIMESTAMP()  AS creado,	
    CURRENT_TIMESTAMP()  AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,
    d.serial_number AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    'RECUPERACION MES ANTERIOR' AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    d.PRODUCT_CODE,	
    D.TERMINAL_NAME,	
    D.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    D.PURCH_PRICE,
    d.NET_SUBSIDY,
    d.END_USER_PRICE,
    d.COSTE_DEVICE,
    d.offer_segmentation,
    'PAYTERM'||'_'||D.financed_months||'_'||D.financed_monthly_quota AS INSTALLMENT_ID,
    CASE 
      WHEN D.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM `mm-commissions-reporting.TEMP.device_base_dealer` d  --`mm-commissions-reporting.TEMP.device_base` d  
        
    INNER JOIN `mm-commissions-reporting.TEMP.terminales_no_abonados_mes_pasado` t
      ON  t.IMEI = d.serial_number
      AND t.order_id = d.id_subscription_terminal

    WHERE
    d.activation_date BETWEEN ACTI_INI AND ACTI_FINAL
    AND d.SUBSIDY_PAYTERM <> 0
    AND d.serial_number IS NOT NULL
    AND d.seller NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    AND d.user_store NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    AND d.sfid_id NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    
  UNION ALL

  -- SUBSIDY_SUBSIDY_PAY25
    SELECT
    'PAY25_RECUPERA'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    d.agrupacion_canal AS agrupacion_canal,	
    d.canal AS CANAL,
    'T - Pago Final Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE) AS concepto,	
    'FINT' AS tipo_concepto,	
    1 AS unidades,	
    d.SUBSIDY_PAY25 AS comision,	
    d.user_store AS id_comisionista,	
    d.distribuidor AS distribuidor,
    SUBSTR(d.sfid_id,1,2) AS sfid_id,	
    d.user_store AS seller,	
    d.nombre_comercio AS nombre_comercio,
    d.razon_social AS razon_social,
    d.cif AS cif,
    CASE WHEN d.REGION_CODE = 1 THEN 'PEN'
         WHEN d.REGION_CODE = 4 THEN 'CAN'
         WHEN d.REGION_CODE = 3 THEN 'MEL'
    ELSE CAST(NULL AS STRING)  END AS ZONA_FISCAL,
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
       
          END AS cod_producto,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(d.channel_ds,d.subchannel_ds) AS cod_canal,	
    'RECUPERACION MES ANTERIOR' AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    d.data_source AS comments,
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING)  END AS sociedad,
    CAST(NULL AS STRING) AS bp,	
    CAST(NULL AS STRING) AS cuenta_contable,	
    CAST(NULL AS STRING) AS centro_coste,	
    CAST(NULL AS STRING) AS documento_sap,	
    CAST(NULL AS STRING) AS documento_sap_posicion,	
    CAST(NULL AS STRING) AS fecha_contabilizacion,	
    CURRENT_TIMESTAMP()  AS creado,	
    CURRENT_TIMESTAMP()  AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,
    d.serial_number AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    'RECUPERACION MES ANTERIOR' AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    d.PRODUCT_CODE,	
    D.TERMINAL_NAME,	
    D.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    D.PURCH_PRICE,
    d.NET_SUBSIDY,
    d.END_USER_PRICE,
    d.COSTE_DEVICE,
    d.offer_segmentation,
    'PAYTERM'||'_'||D.financed_months||'_'||D.financed_monthly_quota AS INSTALLMENT_ID,
    CASE 
      WHEN D.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM `mm-commissions-reporting.TEMP.device_base_dealer` d  --`mm-commissions-reporting.TEMP.device_base` d  

    INNER JOIN `mm-commissions-reporting.TEMP.terminales_no_abonados_mes_pasado` t
      ON  t.IMEI = d.serial_number
      AND t.order_id = d.id_subscription_terminal

    WHERE
    d.activation_date BETWEEN ACTI_INI AND ACTI_FINAL
    AND d.SUBSIDY_PAY25 <> 0
    AND d.serial_number IS NOT NULL
    AND d.seller NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    AND d.user_store NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    AND d.sfid_id NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOATCV','TPMRETER')
    
  )
   ;

  END