BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_postventas` ('DAILY', 202503, '2025-03-01', '2025-03-01','2025-03-31');

  insert into `mm-commissions-reporting.TERMINALES.TERMINALES`(

    SELECT
    
        'ESTIMACION_F1'||'_'||PROCESO_PR||'_'||MES_PR||'_'||row_number () over () AS commission_id,	
        'calculado' as estado,	
        MES_LIQUIDADO_PR AS mes_liquidado,	
        MES_PR as id_mes,	
        agrupacion_canal,	
        canal,	
        concepto,	
        tipo_concepto,	
        unidades,	
        comision,	
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
        order_id||'-'||'F1' AS ORDER_ID,	-- CONCATENO - f1 PARA DIFERENCIAR PEDIDOS ESTIMADOS.
        order_type_agg,	
        cod_segmento,	
        cod_marca,	
        cod_tipo_contrato,	
        cod_producto,	
        cod_canal,	
        CAST(NULL AS STRING) AS claim_code,	
        campaign_code,	
        PROCESO_PR as process_code,	
        comments,	
        'C_TERMINALES' as facturador,	
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
        [''] as emails_acceso_trazabilidad,	
        T.IMEI,	
        DUPLICATED_IMEI, 
        AFTER_SALE,	
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

    WHERE T.ID_MES = MES_PR
    AND T.tipo_concepto IN ('COPM','QU25','DOAC','DUSI')

  );

END