BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_terminales_recuperados_manualmente`('REAL', 202609, '2026-09-01', '2026-08-01', '2026-10-30','COM-978_2');

--CALL `mm-commissions-reporting.TERMINALES.pr_device_base_dealer`();

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`( 
  
  -- SUBSIDY
    SELECT
--    'SUBSIDY_Ajuste_MAN'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'SUBSIDY_'||id_claim_code||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    d.agrupacion_canal AS agrupacion_canal,	
    d.canal AS CANAL,
    IF(D.SUBSIDY < 0,'X - Subsidio '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE)||' Negativo','T - Subsidio Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE)) AS concepto,	
    IF(d.SELL_TYPE = 'CAPTACION','SUBS','SRCI') AS tipo_concepto,	
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
    id_claim_code AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    d.data_source AS comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING) END AS sociedad,
    CAST(NULL AS STRING) AS bp,	
    CAST(NULL AS STRING) AS cuenta_contable,	
    CAST(NULL AS STRING) AS centro_coste,	
    CAST(NULL AS STRING) AS documento_sap,	
    CAST(NULL AS STRING) AS documento_sap_posicion,	
    CAST(NULL AS STRING) AS fecha_contabilizacion,	
    CURRENT_TIMESTAMP() AS creado,	
    CURRENT_TIMESTAMP() AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,	
    d.serial_number AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
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
      WHEN d.is_financed_desc = 'SI' THEN 'PAYTERM_YES'
      WHEN D.is_financed_desc = 'PAGO FINANCIADO' THEN 'PAYTERM_YES'
      ELSE 'PAYTERM_NO'
      END AS FINANCIADO

    FROM `mm-commissions-reporting.TEMP.device_base_dealer` d  -- `mm-commissions-reporting.TEMP.device_base` d
--    FROM `mm-commissions-reporting.TEMP.device_base_dealer_COM_796`  d

    INNER JOIN `mm-commissions-reporting.TEMP.terminales_no_abonados_carga_manual` t  --ASEGURARNOS DE EJECUTAR "TERMINALES_A_RECUPERAR_MES_PASADO" PARA CREAR ESTA TABLA TEMPORAL
      ON  t.IMEI = d.serial_number
--      AND t.PEDIDO = CAST(d.id_subscription_terminal AS STRING)
      AND t.phone_nm = d.phone_nm

    --  INNER JOIN `mm-commissions-reporting.TEMP.order_id_no_abonados_carga_manual` o  --2025-11  Para filtrar por una única orden
    --    ON CAST(d.id_subscription_terminal AS STRING) = o.order_id

    WHERE
    d.activation_date BETWEEN ACTI_INI AND ACTI_FINAL
    AND d.SUBSIDY <> 0
    AND d.serial_number IS NOT NULL 
    AND d.seller NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.user_store NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.sfid_id NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.terminal_status_ds IN ('FINANCIACION EN CURSO','USADO','AMORTIZACION PENDIENTE','FINANCIACION PENDIENTE','EN FINANCIACION','AMORTIZACIÓN PENDIENTE','FINANCIACION DESACTIVADA','MIGRACION CONTRATO')
    AND d.sfid_id IS NOT NULL

  UNION ALL

  -- SUBSIDY_PAYTERM
    SELECT
--    'PAYTERM_Ajuste_MAN'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'PAYTERM_'||id_claim_code||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
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

    -- CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
    --       ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,CAST(NULL AS STRING)) 
    --       END AS cod_producto,	

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
    id_claim_code AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    d.data_source AS comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING) END AS sociedad,
    CAST(NULL AS STRING) AS bp,	
    CAST(NULL AS STRING) AS cuenta_contable,	
    CAST(NULL AS STRING) AS centro_coste,	
    CAST(NULL AS STRING) AS documento_sap,	
    CAST(NULL AS STRING) AS documento_sap_posicion,	
    CAST(NULL AS STRING) AS fecha_contabilizacion,	
    CURRENT_TIMESTAMP() AS creado,	
    CURRENT_TIMESTAMP() AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,
    d.serial_number AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
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

    FROM `mm-commissions-reporting.TEMP.device_base_dealer` d  -- `mm-commissions-reporting.TEMP.device_base` d
--    FROM `mm-commissions-reporting.TEMP.device_base_dealer_COM_796`  d
    
    INNER JOIN `mm-commissions-reporting.TEMP.terminales_no_abonados_carga_manual` t
      ON  t.IMEI = d.serial_number
--      AND t.PEDIDO = CAST(d.id_subscription_terminal AS STRING)
      AND t.phone_nm = d.phone_nm

    --  INNER JOIN `mm-commissions-reporting.TEMP.order_id_no_abonados_carga_manual` o  --2025-11  Para filtrar por una única orden
    --    ON CAST(d.id_subscription_terminal AS STRING) = o.order_id

    WHERE
    d.activation_date BETWEEN ACTI_INI AND ACTI_FINAL
    AND d.SUBSIDY_PAYTERM <> 0
    AND d.serial_number IS NOT NULL
    AND d.seller NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.user_store NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.sfid_id NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.terminal_status_ds IN ('FINANCIACION EN CURSO','USADO','AMORTIZACION PENDIENTE','FINANCIACION PENDIENTE','EN FINANCIACION','AMORTIZACIÓN PENDIENTE','FINANCIACION DESACTIVADA','MIGRACION CONTRATO')
    AND d.sfid_id IS NOT NULL

/*    
  UNION ALL

  -- SUBSIDY_SUBSIDY_PAY25
    SELECT
--    'PAY25_Ajuste_MAN'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'PAY25_'||id_claim_code||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    d.agrupacion_canal AS agrupacion_canal,	
    d.canal AS CANAL,
    'X - Pago Final Terminal '||`mm-commissions-reporting.TERMINALES.f_AYU_CONCEPTO`(d.SELL_TYPE) AS concepto,	
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

    -- CASE WHEN d.SELL_TYPE = 'RENUEVO' THEN '050'  
    --       ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', D.brand_ds, D.order_type_agg,CAST(NULL AS STRING)) 
    --       END AS cod_producto,	

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
    id_claim_code AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    d.data_source AS comments,
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    CASE WHEN d.brand_ds IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE CAST(NULL AS STRING) END AS sociedad,
    CAST(NULL AS STRING) AS bp,	
    CAST(NULL AS STRING) AS cuenta_contable,	
    CAST(NULL AS STRING) AS centro_coste,	
    CAST(NULL AS STRING) AS documento_sap,	
    CAST(NULL AS STRING) AS documento_sap_posicion,	
    CAST(NULL AS STRING) AS fecha_contabilizacion,	
    CURRENT_TIMESTAMP() AS creado,	
    CURRENT_TIMESTAMP() AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,
    d.serial_number AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
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

    FROM `mm-commissions-reporting.TEMP.device_base_dealer` d  -- `mm-commissions-reporting.TEMP.device_base` d
--    FROM `mm-commissions-reporting.TEMP.device_base_dealer_COM_796`  d

    INNER JOIN `mm-commissions-reporting.TEMP.terminales_no_abonados_carga_manual` t
      ON  t.IMEI = d.serial_number
--      AND t.PEDIDO = CAST(d.id_subscription_terminal AS STRING)
--      AND t.Pedido = d.phone_nm

     INNER JOIN `mm-commissions-reporting.TEMP.order_id_no_abonados_carga_manual` o  --2025-11  Para filtrar por una única orden
       ON CAST(d.id_subscription_terminal AS STRING) = o.order_id

    WHERE
    d.activation_date BETWEEN ACTI_INI AND ACTI_FINAL
    AND d.SUBSIDY_PAY25 <> 0
    AND d.serial_number IS NOT NULL
    AND d.seller NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.user_store NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.sfid_id NOT IN ('PHJFIDER','TPFFOST','TPMATENFIDE','TPFOPRE','TPFOATCV','TPMRETER')
    AND d.terminal_status_ds IN ('FINANCIACION EN CURSO','USADO','AMORTIZACION PENDIENTE','FINANCIACION PENDIENTE','EN FINANCIACION','AMORTIZACIÓN PENDIENTE','FINANCIACION DESACTIVADA','MIGRACION CONTRATO')
    AND d.sfid_id IS NOT NULL
*/    
  )
  ;

  END