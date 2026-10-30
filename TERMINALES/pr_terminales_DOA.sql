BEGIN

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(
  
    SELECT
    'DOA'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    -- if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo') AS agrupacion_canal,
    DE.agrupacion_canal, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2)) AS canal,	
    DE.canal, -- 20250526 JOHANNA
    'T - Doas' AS concepto,	
    'DOAC' AS tipo_concepto,	
    1 AS unidades,	
    c.COSTE_DEVICE AS comision,	
    COALESCE(DE.id_comisionista,d.ID_CLIENTE) AS id_comisionista,	-- 20250526 JOHANNA
    COALESCE(DE.distribuidor,`mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2))) AS distribuidor,	-- 20250526 JOHANNA
    COALESCE(DE.sfid_id,SUBSTR(d.ID_CLIENTE,1,2)) AS sfid_id,	-- 20250526 JOHANNA
    COALESCE(DE.id_comisionista,ID_CLIENTE) AS seller,	-- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS nombre_comercio,	
    DE.nombre_comercio, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS razon_social,
    DE.razon_social, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CIF`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS cif,
    DE.cif, -- 20250526 JOHANNA	   
    --IF(M.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    -- C.zona_fiscal AS ZONA_FISCAL,
    DE.zona_fiscal AS ZONA_FISCAL, -- 20250526 JOHANNA
    d.PHP_REP_MASTER_HUB_ORDEN_ID_ESQUEMA AS marca,	
    'MOBILE' AS service_type,	
    CAST(NULL AS STRING) AS PHONE_NM,	
    CAST(NULL AS STRING) AS tariff_id,	
    CAST(NULL AS STRING) AS tariff_ds,	
    CAST(NULL AS STRING) AS service_id,	
    CAST(NULL AS STRING) AS account_id,	
    CAST(NULL AS STRING) AS customer_id,	
    CAST(NULL AS STRING) AS line_type_ds,	
    CAST(NULL AS STRING) AS bundle_type,	
    CAST(NULL AS STRING) AS technology_ds,	
    CAST(NULL AS STRING) AS billing_type_ds,	
    FECHA_SISTEMA AS sale_date,	
    FECHA_SISTEMA AS activation_date,	
    CAST(NULL AS DATE) AS deactivation_date,	
    CAST(NULL AS STRING) order_id,	
    CAST(NULL AS STRING) order_type_agg,	
    '10' AS cod_segmento,	
    '01' AS cod_marca,	
    '99' AS cod_tipo_contrato,	
    '999' AS cod_producto,	
    -- `mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) AS cod_canal,	
    CASE
        WHEN DE.agrupacion_canal = 'Exclusivo'     THEN '27'
        WHEN DE.agrupacion_canal = 'No Exclusivo'  THEN '29'
        ELSE '99'
    END AS cod_canal, -- 20250526 JOHANNA
    
    CAST(NULL AS STRING) AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    'ANOVO' AS comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    'X001' AS sociedad,
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
    d.IMEI AS IMEI, 
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    D.MODEL_ID AS PRODUCT_CODE,	
    ID_MODELO AS TERMINAL_NAME,	
    ID_ORDEN AS CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    NULL AS PURCH_PRICE,
    NULL AS NET_SUBSIDY,
    NULL AS END_USER_PRICE,
    NULL AS COSTE_DEVICE,
    CAST(NULL AS STRING) AS offer_segmentation,
    CAST(NULL AS STRING) AS installment_id,
    CAST(NULL AS STRING) AS financiado

    FROM `mm-commissions-reporting.TERMINALES.DOAS` d

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DE
       ON UPPER(d.ID_CLIENTE) = UPPER(DE.id_comisionista) 
       AND DE.id_mes = MES_PR
       AND d.ID_CLIENTE IS NOT NULL

/*
      INNER JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` M
        ON trim(d.ID_CLIENTE) = M.CUSTOMER_ID

      INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` M 
        ON  UPPER(d.ID_CLIENTE) = UPPER(M.sfid_id) 
        AND M.id_mes = MES_PR
        AND ID_CLIENTE IS NOT NULL

      INNER JOIN (SELECT V.product_code,V.REGION_CODE, MAX(V.COSTE_DEVICE) AS COSTE_DEVICE FROM `mm-commissions-reporting.TERMINALES.v_device_base` V where master_channel_ds = 'EXCLUSIVO' AND v.order_date between ACTI_INI and ACTI_FINAL GROUP BY 1,2) c
*/
      INNER JOIN (
        SELECT V.product_code
          , CASE WHEN V.tax IN (21)                           THEN 'PEN'
                 WHEN V.tax IN (7)                            THEN 'CAN'
                 WHEN V.tax IS NULL AND V.tax_value IN (0.21) THEN 'PEN'
                 WHEN V.tax IS NULL AND V.tax_value IN (0.07) THEN 'CAN'
                 ELSE 'PEN' END AS zona_fiscal
          , MAX(V.coste_device) AS COSTE_DEVICE
        FROM `mm-commissions-reporting.TEMP.device_base` V
        WHERE V.master_channel_ds = 'EXCLUSIVO' 
          AND V.order_date BETWEEN '2023-03-01' AND ACTI_FINAL
         GROUP BY ALL
      ) C
          ON  d.MODEL_ID = c.product_code 
          AND DE.zona_fiscal = C.zona_fiscal
   
    WHERE d.FECHA_SISTEMA BETWEEN ACTI_INI AND ACTI_FINAL
  );

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(
  
    SELECT
    'DOA_UPF'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    -- if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo') AS agrupacion_canal,
    DE.agrupacion_canal, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2)) AS canal,	
    DE.canal, -- 20250526 JOHANNA
    'B - Doa' AS concepto,	
    'DOAC' AS tipo_concepto,	
    1 AS unidades,	
    5 AS comision,	
    COALESCE(DE.id_comisionista,d.ID_CLIENTE) AS id_comisionista,	-- 20250526 JOHANNA
    COALESCE(DE.distribuidor,`mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2))) AS distribuidor,	-- 20250526 JOHANNA
    COALESCE(DE.sfid_id,SUBSTR(d.ID_CLIENTE,1,2)) AS sfid_id,	-- 20250526 JOHANNA
    COALESCE(DE.id_comisionista,ID_CLIENTE) AS seller,	-- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS nombre_comercio,	
    DE.nombre_comercio, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS razon_social,
    DE.razon_social, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CIF`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS cif,
    DE.cif, -- 20250526 JOHANNA	   
    --IF(M.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    -- C.zona_fiscal AS ZONA_FISCAL,
    DE.zona_fiscal AS ZONA_FISCAL, -- 20250526 JOHANNA
    d.PHP_REP_MASTER_HUB_ORDEN_ID_ESQUEMA AS marca,	
    'MOBILE' AS service_type,	
    CAST(NULL AS STRING) AS PHONE_NM,	
    CAST(NULL AS STRING) AS tariff_id,	
    CAST(NULL AS STRING) AS tariff_ds,	
    CAST(NULL AS STRING) AS service_id,	
    CAST(NULL AS STRING) AS account_id,	
    CAST(NULL AS STRING) AS customer_id,	
    CAST(NULL AS STRING) AS line_type_ds,	
    CAST(NULL AS STRING) AS bundle_type,	
    CAST(NULL AS STRING) AS technology_ds,	
    CAST(NULL AS STRING) AS billing_type_ds,	
    FECHA_SISTEMA AS sale_date,	
    FECHA_SISTEMA AS activation_date,	
    CAST(NULL AS DATE) AS deactivation_date,	
    CAST(NULL AS STRING) order_id,	
    CAST(NULL AS STRING) order_type_agg,	
    '10' AS cod_segmento,	
    '01' AS cod_marca,	
    '99' AS cod_tipo_contrato,	
    '999' AS cod_producto,	
    -- `mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) AS cod_canal,	
    CASE
        WHEN DE.agrupacion_canal = 'Exclusivo'     THEN '27'
        WHEN DE.agrupacion_canal = 'No Exclusivo'  THEN '29'
        ELSE '99'
    END AS cod_canal, -- 20250526 JOHANNA
    
    CAST(NULL AS STRING) AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
    'ANOVO' AS comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
    'X001' AS sociedad,
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
    d.IMEI AS IMEI, 
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    D.MODEL_ID AS PRODUCT_CODE,	
    ID_MODELO AS TERMINAL_NAME,	
    ID_ORDEN AS CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    NULL AS PURCH_PRICE,
    NULL AS NET_SUBSIDY,
    NULL AS END_USER_PRICE,
    NULL AS COSTE_DEVICE,
    CAST(NULL AS STRING) AS offer_segmentation,
    CAST(NULL AS STRING) AS installment_id,
    CAST(NULL AS STRING) AS financiado

    FROM `mm-commissions-reporting.TERMINALES.DOAS` d

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DE
       ON UPPER(d.ID_CLIENTE) = UPPER(DE.id_comisionista) 
       AND DE.id_mes = MES_PR
       AND d.ID_CLIENTE IS NOT NULL

/*
      INNER JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` M
        ON trim(d.ID_CLIENTE) = M.CUSTOMER_ID

      INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` M 
        ON  UPPER(d.ID_CLIENTE) = UPPER(M.sfid_id) 
        AND M.id_mes = MES_PR
        AND ID_CLIENTE IS NOT NULL

      INNER JOIN (SELECT V.product_code,V.REGION_CODE, MAX(V.COSTE_DEVICE) AS COSTE_DEVICE FROM `mm-commissions-reporting.TERMINALES.v_device_base` V where master_channel_ds = 'EXCLUSIVO' AND v.order_date between ACTI_INI and ACTI_FINAL GROUP BY 1,2) c
*/
      INNER JOIN (
        SELECT V.product_code
          , CASE WHEN V.tax IN (21)                           THEN 'PEN'
                 WHEN V.tax IN (7)                            THEN 'CAN'
                 WHEN V.tax IS NULL AND V.tax_value IN (0.21) THEN 'PEN'
                 WHEN V.tax IS NULL AND V.tax_value IN (0.07) THEN 'CAN'
                 ELSE 'PEN' END AS zona_fiscal
          , MAX(V.coste_device) AS COSTE_DEVICE
        FROM `mm-commissions-reporting.TEMP.device_base` V
        WHERE V.master_channel_ds = 'EXCLUSIVO' 
          AND V.order_date BETWEEN '2023-03-01' AND ACTI_FINAL
         GROUP BY ALL
      ) C
          ON  d.MODEL_ID = c.product_code 
          AND DE.zona_fiscal = C.zona_fiscal
   
    WHERE d.FECHA_SISTEMA BETWEEN ACTI_INI AND ACTI_FINAL
      AND DE.canal = 'ENK'
  );

END