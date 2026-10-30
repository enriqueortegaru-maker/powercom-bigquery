BEGIN

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(
  
  -- UPFRONT

    SELECT
    'REP_UPF'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    -- IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo') AS agrupacion_canal,	
    DE.agrupacion_canal, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2)) AS canal,	
    DE.canal,-- 20250526 JOHANNA
    'B - Reparacion Terminal (Anovo)' AS concepto,	
    'COPM' AS tipo_concepto,	
    1 AS unidades,	
    5 AS comision,	
    COALESCE(DE.sfid_id,ID_CLIENTE) AS id_comisionista,	-- 20250526 JOHANNA
    COALESCE(DE.distribuidor,`mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2))) AS distribuidor,	-- 20250526 JOHANNA
    COALESCE(DE.sfid_id,SUBSTR(d.ID_CLIENTE,1,2)) AS sfid_id,	-- 20250526 JOHANNA
    COALESCE(DE.sfid_id,ID_CLIENTE) AS seller,	-- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS nombre_comercio,	
    DE.nombre_comercio, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS razon_social,	
    DE.razon_social, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_CIF`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS cif,	
    DE.cif, -- 20250526 JOHANNA
    -- IF(M.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    DE.zona_fiscal AS ZONA_FISCAL,
    'YOIGO' AS marca,	
    'MOBILE' AS service_type,	
    CAST(TELEFONO AS STRING) AS PHONE_NM,	
    CAST(NULL AS STRING) AS tariff_id,	
    CAST(NULL AS STRING) AS tariff_ds,	
    CAST(NULL AS STRING) AS service_id,	
    CAST(NULL AS STRING) AS account_id,	
    CAST(NULL AS STRING) AS customer_id,	
    CAST(NULL AS STRING) AS line_type_ds,	
    CAST(NULL AS STRING) AS bundle_type,	
    CAST(NULL AS STRING) AS technology_ds,	
    CAST(NULL AS STRING) AS billing_type_ds,	
    FECHA_EXPEDICION AS sale_date,	
    FECHA_EXPEDICION AS activation_date,	
    CAST(NULL AS DATE) AS deactivation_date,	
    CAST(NULL AS STRING) order_id,	-- ORDENES DE PEDIDO QVANTEL - EL ID_SUBSCRIPTION_TERMINAL PROVIENE DE MYSIM, ESTE SISTEMA ES EL PARÁMETRO DE PEDIDO, AL NO CONTENER NI CONTRACT_ID NI ORDER_ID
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
--    CAST(NULL AS STRING) AS sociedad,		 --Rellenamos la sociedad JG 2024-04-10
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
    IMEI AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    CAST(NULL AS STRING) AS PRODUCT_CODE,	
    ID_MODELO AS TERMINAL_NAME,	
    ID_ORDEN AS CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    NULL AS PURCH_PRICE,
    NULL AS NET_SUBSIDY,
    NULL AS END_USER_PRICE,
    NULL AS COSTE_DEVICE,
    CAST(NULL AS STRING) AS offer_segmentation,
    CAST(NULL AS STRING) AS installment_id,
    CAST(NULL AS STRING) AS financiado

    FROM `mm-commissions-reporting.TERMINALES.REPARACIONES` d

      -- INNER JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` M
      --   ON d.ID_CLIENTE = M.CUSTOMER_ID
    
    -- INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` M 
    --   ON  UPPER(d.ID_CLIENTE) = UPPER(M.sfid_id) 
    --   AND M.id_mes = MES_PR

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DE
       ON UPPER(d.ID_CLIENTE) = UPPER(DE.id_comisionista) AND DE.id_mes = MES_PR 

    WHERE d.FECHA_EXPEDICION BETWEEN ACTI_INI AND ACTI_FINAL

--SE ELIMINA EL CÁLCULO DE GESTIÓN DE CANAL PARA AGOSTO/2025, PORQUE SE VA A CALCULAR TODA LA GESTIÓN DE CANAL POR FUERA
/*
  UNION ALL

  -- GESTIÓN CANAL REPARACIONES
    SELECT
    'REP_CANAL'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    -- IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo') AS agrupacion_canal,	
    DE.agrupacion_canal, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2)) AS canal,	
    DE.canal,-- 20250526 JOHANNA	
    'F - Reparacion Terminal (Anovo)' AS concepto,	
    'COPM' AS tipo_concepto,	
    1 AS unidades,	
    1 AS comision,	
    COALESCE(DE.sfid_id,ID_CLIENTE) AS id_comisionista,	-- 20250526 JOHANNA
    COALESCE(DE.distribuidor,`mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(ID_CLIENTE,1,2))) AS distribuidor,	-- 20250526 JOHANNA
    COALESCE(DE.sfid_id,SUBSTR(d.ID_CLIENTE,1,2)) AS sfid_id,	-- 20250526 JOHANNA
    COALESCE(DE.sfid_id,ID_CLIENTE) AS seller,	-- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS nombre_comercio,	
    DE.nombre_comercio, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS razon_social,	
    DE.razon_social, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_CIF`(if(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(ID_CLIENTE,1,2)) = '27','Exclusivo','No Exclusivo')) AS cif,	
    DE.cif, -- 20250526 JOHANNA
    DE.zona_fiscal AS ZONA_FISCAL,	
    --IF(M.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    'YOIGO' AS marca,	
    'MOBILE' AS service_type,	
    CAST(TELEFONO AS STRING) AS PHONE_NM,	
    CAST(NULL AS STRING) AS tariff_id,	
    CAST(NULL AS STRING) AS tariff_ds,	
    CAST(NULL AS STRING) AS service_id,	
    CAST(NULL AS STRING) AS account_id,	
    CAST(NULL AS STRING) AS customer_id,	
    CAST(NULL AS STRING) AS line_type_ds,	
    CAST(NULL AS STRING) AS bundle_type,	
    CAST(NULL AS STRING) AS technology_ds,	
    CAST(NULL AS STRING) AS billing_type_ds,	
    FECHA_EXPEDICION AS sale_date,	
    FECHA_EXPEDICION AS activation_date,	
    CAST(NULL AS DATE) AS deactivation_date,	
    CAST(NULL AS STRING) order_id,	-- ORDENES DE PEDIDO QVANTEL - EL ID_SUBSCRIPTION_TERMINAL PROVIENE DE MYSIM, ESTE SISTEMA ES EL PARÁMETRO DE PEDIDO, AL NO CONTENER NI CONTRACT_ID NI ORDER_ID
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
--    CAST(NULL AS STRING) AS sociedad,		 --Rellenamos la sociedad JG 2024-04-10
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
    IMEI AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    CAST(NULL AS STRING) AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    CAST(NULL AS STRING) AS PRODUCT_CODE,	
    ID_MODELO AS TERMINAL_NAME,	
    ID_ORDEN AS CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    NULL AS PURCH_PRICE,
    NULL AS NET_SUBSIDY,
    NULL AS END_USER_PRICE,
    NULL AS COSTE_DEVICE,
    CAST(NULL AS STRING) AS offer_segmentation,
    CAST(NULL AS STRING) AS installment_id,
    CAST(NULL AS STRING) AS financiado

    FROM `mm-commissions-reporting.TERMINALES.REPARACIONES` d

      -- INNER JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` M
      --   ON d.ID_CLIENTE = M.CUSTOMER_ID
    
      -- INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` v 
      --   ON  UPPER(TRIM(d.ID_CLIENTE)) = UPPER(v.id_comisionista) 
      --   AND v.id_mes = MES_PR

      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DE
       ON UPPER(d.ID_CLIENTE) = UPPER(DE.id_comisionista) AND DE.id_mes = MES_PR 
    
    WHERE d.FECHA_EXPEDICION BETWEEN ACTI_INI AND ACTI_FINAL
*/
  );

END