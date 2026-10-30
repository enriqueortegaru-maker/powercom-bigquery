BEGIN

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(
  
  -- COMISION UPFRONT 
    SELECT
    'Q25'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    -- IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo') AS agrupacion_canal,
    T.agrupacion_canal, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(EXT_CUSTOMER_NO,1,2)) AS canal,	
    T.canal, -- 20250526 JOHANNA
    'B - Comision Q25' AS concepto,	
    'QU25' AS tipo_concepto,	
    1 AS unidades,	
    `mm-commissions-reporting.TERMINALES.f_CONF_COMISION_Q25`(D.ADDON6,SUBSTR(d.EXT_CUSTOMER_NO,1,2)) AS comision,	
    COALESCE(T.sfid_id,EXT_CUSTOMER_NO) AS id_comisionista,	-- 20250526 JOHANNA
    COALESCE(T.distribuidor,`mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(EXT_CUSTOMER_NO,1,2))) AS distribuidor,	-- 20250526 JOHANNA
    COALESCE(T.sfid_id,SUBSTR(d.EXT_CUSTOMER_NO,1,2)) AS sfid_id,	-- 20250526 JOHANNA
    COALESCE(T.sfid_id,EXT_CUSTOMER_NO) AS seller,	-- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo')) AS nombre_comercio,	
    T.nombre_comercio, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo')) AS razon_social,
    T.razon_social, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CIF`(IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo')) AS cif,
    T.cif, -- 20250526 JOHANNA	   
    T.zona_fiscal AS ZONA_FISCAL,	
    --IF(M.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    'YOIGO' AS marca,	
    'MOBILE' AS service_type,	
    CAST(d.MSISDN AS STRING) AS PHONE_NM,	
    CAST(NULL AS STRING) AS tariff_id,	
    CAST(NULL AS STRING) AS tariff_ds,	
    CAST(NULL AS STRING) AS service_id,	
    CAST(NULL AS STRING) AS account_id,	
    CAST(NULL AS STRING) AS customer_id,	
    CAST(NULL AS STRING) AS line_type_ds,	
    CAST(NULL AS STRING) AS bundle_type,	
    CAST(NULL AS STRING) AS technology_ds,	
    CAST(NULL AS STRING) AS billing_type_ds,	
    EVENT_DATE AS sale_date,	
    EVENT_DATE AS activation_date,	
    CAST(NULL AS DATE) AS deactivation_date,	
    CAST(NULL AS STRING) order_id,	
    CAST(NULL AS STRING) order_type_agg,	
    '10' AS cod_segmento,	
    '01' AS cod_marca,	
    '99' AS cod_tipo_contrato,	
    '008' AS cod_producto,	
    -- `mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) AS cod_canal,
    CASE
        WHEN T.agrupacion_canal = 'Exclusivo'     THEN '27'
        WHEN T.agrupacion_canal = 'No Exclusivo'  THEN '29'
        ELSE '99'
    END AS cod_canal, -- 20250526 JOHANNA

    CAST(NULL AS STRING) AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
--    'QVANTEL' AS comments,	
    CASE WHEN MES_PR >= 202405 THEN 'MYSIM'
         WHEN MES_PR <= 202404 THEN 'QVANTEL'
         ELSE CAST(NULL AS STRING) END AS comments,
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
    CURRENT_TIMESTAMP()  AS creado,	
    CURRENT_TIMESTAMP()  AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,	
    CAST(d.IMEI AS STRING) AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    'Q25'||'-'||D.ADDON6 AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    CAST(NULL AS STRING) AS PRODUCT_CODE,	
    CAST(NULL AS STRING) AS TERMINAL_NAME,	
    d.CONTRACT_ID AS CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    NULL AS PURCH_PRICE,
    NULL AS NET_SUBSIDY,
    NULL AS END_USER_PRICE,
    NULL AS COSTE_DEVICE,
    CAST(NULL AS STRING) AS offer_segmentation,
    CAST(NULL AS STRING) AS installment_id,
    CAST(NULL AS STRING) AS financiado

    FROM `mm-commissions-reporting.TERMINALES.PAY_FINAL` d
/*
      INNER JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` M
        ON d.EXT_CUSTOMER_NO = M.CUSTOMER_ID

      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` T
        ON d.EXT_CUSTOMER_NO = T.id_comisionista AND SUBSTR(D.EXT_CUSTOMER_NO,1,2) = 'MP' AND T.id_mes = MES_PR
  
    INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` v
      ON  UPPER(TRIM(d.EXT_CUSTOMER_NO)) = UPPER(v.id_comisionista) 
      AND v.id_mes = MES_PR
      AND d.EXT_CUSTOMER_NO IS NOT NULL
*/

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` T
            ON UPPER(TRIM(d.EXT_CUSTOMER_NO)) = UPPER(T.sfid_id) AND T.id_mes = MES_PR AND d.EXT_CUSTOMER_NO IS NOT NULL

    WHERE d.EVENT_DATE BETWEEN ACTI_INI AND ACTI_FINAL
      AND d.ADDON6 IN ('RET_4','EXT_8','EXT_10')

--SE ELIMINA EL CÁLCULO DE GESTIÓN DE CANAL PARA AGOSTO/2025, PORQUE SE VA A CALCULAR TODA LA GESTIÓN DE CANAL POR FUERA
/*
  UNION ALL

  -- COMISION GESTIÓN CANAL
    SELECT
    'Q25_GSC'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    -- IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo') AS agrupacion_canal,	
    T.agrupacion_canal,
    -- `mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(EXT_CUSTOMER_NO,1,2)) AS canal,	
    T.canal,
    'F - Comision Q25' AS concepto,	
    'QU25' AS tipo_concepto,	
    1 AS unidades,	
    1 AS comision,	
    COALESCE(T.sfid_id,EXT_CUSTOMER_NO) AS id_comisionista,	-- 20250526 JOHANNA
    COALESCE(T.distribuidor,`mm-commissions-reporting.TERMINALES.f_CANAL_OFF_VENTAS`(SUBSTR(EXT_CUSTOMER_NO,1,2))) AS distribuidor,	-- 20250526 JOHANNA
    COALESCE(T.sfid_id,SUBSTR(d.EXT_CUSTOMER_NO,1,2)) AS sfid_id,	-- 20250526 JOHANNA
    COALESCE(T.sfid_id,EXT_CUSTOMER_NO) AS seller,	-- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo')) AS nombre_comercio,	
    T.nombre_comercio, -- 20250526 JOHANNA
    -- `mm-commissions-reporting.TERMINALES.f_DISTRIBUIDOR`(IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo')) AS razon_social,
    T.razon_social, -- 20250526 JOHANNA	
    -- `mm-commissions-reporting.TERMINALES.f_CIF`(IF(`mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) = '27','Exclusivo','No Exclusivo')) AS cif,
    T.cif, -- 20250526 JOHANNA	      
    T.zona_fiscal AS ZONA_FISCAL,	
    --IF(M.REGION_CODE = 1,'PEN','CAN') AS ZONA_FISCAL,
    'YOIGO' AS marca,	
    'MOBILE' AS service_type,	
    CAST(d.MSISDN AS STRING) AS PHONE_NM,	
    CAST(NULL AS STRING) AS tariff_id,	
    CAST(NULL AS STRING) AS tariff_ds,	
    CAST(NULL AS STRING) AS service_id,	
    CAST(NULL AS STRING) AS account_id,	
    CAST(NULL AS STRING) AS customer_id,	
    CAST(NULL AS STRING) AS line_type_ds,	
    CAST(NULL AS STRING) AS bundle_type,	
    CAST(NULL AS STRING) AS technology_ds,	
    CAST(NULL AS STRING) AS billing_type_ds,	
    EVENT_DATE AS sale_date,	
    EVENT_DATE AS activation_date,	
    CAST(NULL AS DATE) AS deactivation_date,	
    CAST(NULL AS STRING) order_id,	
    CAST(NULL AS STRING) order_type_agg,	
    '10' AS cod_segmento,	
    '01' AS cod_marca,	
    '99' AS cod_tipo_contrato,	
    '008' AS cod_producto,	
    -- `mm-commissions-reporting.TERMINALES.f_cod_canal_ifs_rev`(SUBSTR(EXT_CUSTOMER_NO,1,2)) AS cod_canal,	
    CASE
        WHEN T.agrupacion_canal = 'Exclusivo'     THEN '27'
        WHEN T.agrupacion_canal = 'No Exclusivo'  THEN '29'
        ELSE '99'
    END AS cod_canal, -- 20250526 JOHANNA

    CAST(NULL AS STRING) AS claim_code,
    -- 'COM-2989' AS claim_code,	
    CAST(NULL AS STRING) AS campaign_code,	
    PROCESO_PR AS process_code,	
--    'QVANTEL' AS comments,	
    CASE WHEN MES_PR >= 202405 THEN 'MYSIM'
         WHEN MES_PR <= 202404 THEN 'QVANTEL'
         ELSE CAST(NULL AS STRING) END AS comments,
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    CAST(NULL AS STRING) AS proceso_sap,	
    CAST(NULL AS STRING) AS id_registro,	
    CAST(NULL AS STRING) AS invoice_id,	
--    CAST(NULL AS STRING) AS sociedad,	
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
    CAST(d.IMEI AS STRING) AS IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, -- SE EJECUTA EN RUTINA POSTERIOR
    'Q25'||'-'||D.ADDON6 AS AFTER_SALE,	-- PENDIENTE DESARROLLO
    CAST(NULL AS STRING) AS PRODUCT_CODE,	
    CAST(NULL AS STRING) AS TERMINAL_NAME,	
    d.CONTRACT_ID AS CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    NULL AS PURCH_PRICE,
    NULL AS NET_SUBSIDY,
    NULL AS END_USER_PRICE,
    NULL AS COSTE_DEVICE,
    CAST(NULL AS STRING) AS offer_segmentation,
    CAST(NULL AS STRING) AS installment_id,
    CAST(NULL AS STRING) AS financiado

    FROM `mm-commissions-reporting.TERMINALES.PAY_FINAL` d


      -- INNER JOIN `mm-commissions-reporting.TERMINALES.MAESTRO_SFID_IFS` M
      --   ON d.EXT_CUSTOMER_NO = M.CUSTOMER_ID
      -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` T
      --   ON d.EXT_CUSTOMER_NO = T.id_comisionista AND SUBSTR(D.EXT_CUSTOMER_NO,1,2) = 'MP' AND T.id_mes = MES_PR 
      -- INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` v
      --   ON  UPPER(TRIM(d.EXT_CUSTOMER_NO)) = UPPER(v.id_comisionista) 
      --   AND v.id_mes = MES_PR
      --   AND d.EXT_CUSTOMER_NO IS NOT NULL


      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` T
              ON UPPER(TRIM(d.EXT_CUSTOMER_NO)) = UPPER(T.sfid_id) AND T.id_mes = MES_PR AND d.EXT_CUSTOMER_NO IS NOT NULL

    WHERE d.EVENT_DATE BETWEEN ACTI_INI AND ACTI_FINAL
      AND d.ADDON6 IN ('RET_4','EXT_8','EXT_10')
      AND SUBSTR(EXT_CUSTOMER_NO,1,2) NOT IN ('PH','MP')
*/      
  );

END