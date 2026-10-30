BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_WRONG_ADD`('REAL', 202603, '2026-03-01', '2026-03-01','2026-03-31')

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(

    SELECT   
    'WRONG_ADD_FRAUD'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    agrupacion_canal,	
    canal,	
    REPLACE(t.concepto,'T - ','X - ') AS concepto,	
    tipo_concepto,	
    unidades,	
    comision * -1 AS comision,	
    id_comisionista,	
    distribuidor,	
    sfid_id,	
    seller,	
    nombre_comercio,	
    razon_social,	
    cif,	
    zona_fiscal,	
    marca,	
    service_type,	
    phone_nm,	
    tariff_id,	
    tariff_ds,	
    service_id,	
    account_id,	
    customer_id,	
    line_type_ds,	
    bundle_type,	
    technology_ds,	
    billing_type_ds,	
    sale_date,	
    activation_date,	
    deactivation_date,	
    order_id,	
    order_type_agg,	
    cod_segmento,	
    cod_marca,	
    cod_tipo_contrato,	
    cod_producto,	
    cod_canal,	
    CONCAT('Auditoria Exclusivo_',CAST(MES_PR AS STRING)) AS claim_code,	
    campaign_code,	
    PROCESO_PR AS process_code,	
    comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    proceso_sap,	
    id_registro,	
    invoice_id,	
    sociedad,	
    bp,	
    cuenta_contable,	
    centro_coste,	
    documento_sap,	
    documento_sap_posicion,	
    fecha_contabilizacion,	
    CURRENT_TIMESTAMP() AS creado,	
    CURRENT_TIMESTAMP() AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,	
    T.IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, 
    'WRONG_ADD_FRAUD' AS AFTER_SALE,	
    PRODUCT_CODE,	
    TERMINAL_NAME,	
    T.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    PURCH_PRICE,
    NET_SUBSIDY,
    END_USER_PRICE,
    COSTE_DEVICE,
    OFFER_SEGMENT,
    INSTALLMENT_ID,
    FINANCIADO
    
  FROM `mm-commissions-reporting.TERMINALES.TERMINALES` T

    INNER JOIN `mm-commissions-reporting.TERMINALES.v_wrong_add` w

    ON  T.phone_nm = w.MSISDN 
    AND UPPER(T.id_comisionista) = UPPER(w.SFID)
    AND T.CONTRACT_ID = w.contract_id
  
  WHERE w.EVENT_DATE BETWEEN ACTI_INI AND ACTI_FINAL 
    AND w.ORDEN IS NULL
    AND w.tipo IN ('FRAUDE')  --INCLUIDO EN NOV/25
    AND w.SFID NOT LIKE 'MP%' --Elimino MP

  UNION ALL

    --INCLUIDO EN NOV/25
  SELECT   
    'WRONG_ADD'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    agrupacion_canal,	
    canal,	
    REPLACE(t.concepto,'T - ','X - ') AS concepto,	
    tipo_concepto,	
    unidades,	
    comision * -1 AS comision,	
    id_comisionista,	
    distribuidor,	
    sfid_id,	
    seller,	
    nombre_comercio,	
    razon_social,	
    cif,	
    zona_fiscal,	
    marca,	
    service_type,	
    phone_nm,	
    tariff_id,	
    tariff_ds,	
    service_id,	
    account_id,	
    customer_id,	
    line_type_ds,	
    bundle_type,	
    technology_ds,	
    billing_type_ds,	
    sale_date,	
    activation_date,	
    deactivation_date,	
    order_id,	
    order_type_agg,	
    cod_segmento,	
    cod_marca,	
    cod_tipo_contrato,	
    cod_producto,	
    cod_canal,	
    CONCAT('WRONG_ADD_',CAST(id_mes AS STRING)) AS claim_code,
--    CAST(NULL AS STRING) AS claim_code,
    campaign_code,	
    PROCESO_PR AS process_code,	
    comments,	
    'C_IFS' as facturador,	  --Eliminamos C_TERMINALES 2025/12/10
    proceso_sap,	
    id_registro,	
    invoice_id,	
    sociedad,	
    bp,	
    cuenta_contable,	
    centro_coste,	
    documento_sap,	
    documento_sap_posicion,	
    fecha_contabilizacion,	
    CURRENT_TIMESTAMP() AS creado,	
    CURRENT_TIMESTAMP() AS modificado,	
    CAST(NULL AS STRING) AS id_factura_drive,	
    [''] AS emails_acceso_trazabilidad,	
    T.IMEI,	
    CAST(NULL AS STRING) AS DUPLICATED_IMEI, 
    'WRONG_ADD' AS AFTER_SALE,	
    PRODUCT_CODE,	
    TERMINAL_NAME,	
    T.CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    PURCH_PRICE,
    NET_SUBSIDY,
    END_USER_PRICE,
    COSTE_DEVICE,
    OFFER_SEGMENT,
    INSTALLMENT_ID,
    FINANCIADO
    
  FROM `mm-commissions-reporting.TERMINALES.TERMINALES` T

    INNER JOIN `mm-commissions-reporting.TERMINALES.v_wrong_add` w

    ON  T.phone_nm = w.MSISDN 
    AND UPPER(T.id_comisionista) = UPPER(w.SFID)
    AND T.CONTRACT_ID = w.contract_id
    AND T.order_id = w.ORDEN
    AND w.SFID NOT LIKE 'MP%' --Elimino MP
  
  WHERE w.EVENT_DATE BETWEEN ACTI_INI AND ACTI_FINAL 
    AND w.ORDEN IS NOT NULL
    AND w.tipo IN ('WRONG_ADD')

  )
;
 
END