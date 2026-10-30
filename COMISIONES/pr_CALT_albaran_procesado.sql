BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_CALT_albaran_procesado`(202508)

--Tramo

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALT_tramo_row` AS 

    SELECT 
      id_mes,
      fecha_mes,
      nombre_marca,
      SUM(importe_neto) AS fact_clif
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE 1=1
      AND id_mes = mes_int
      AND (tipo_cargo = 'Consumos' OR tipo_cargo = 'Cuota')
    GROUP BY ALL
  ;
  DELETE `mm-commissions-reporting.B2B.CALT_tramo`
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_tramo`

  SELECT 
    id_mes,
    fecha_mes,
    nombre_marca,
    CASE
      WHEN fact_clif < 2000 THEN 'Estandar'
      WHEN fact_clif < 5000 THEN 'Bronce'
      WHEN fact_clif < 15000 THEN 'Plata'
      WHEN fact_clif < 35000 THEN 'Oro'
      ELSE 'Diamante'
    END AS tramo
  FROM `mm-commissions-reporting.TEMP.CALT_tramo_row`
  WHERE id_mes = mes_int
  GROUP BY ALL
  ;

--Customer_Personal_Info

  DELETE `mm-commissions-reporting.B2B.CALT_customer_personal_info`
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_customer_personal_info`

    SELECT 
      id_mes,
      fecha_mes,
      ROW_NUMBER() OVER() as CPI_ID, 
      tipo_documento,
      documento,
      cliente,
      id_externo_cliente,  
      iban_cliente,
      customerDataContactPhone,
      email_cliente,
      direccion_cliente,
      direccion_tipo_via,
      direccion_nombre_via,
      direccion_numero_via,
      direccion_info_adicional,
      direccion_municipio,
      direccion_provincia,
      codigo_postal
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;

-- Customer_Invoice_Info

  DELETE `mm-commissions-reporting.B2B.CALT_customer_invoice_info`
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_customer_invoice_info` 

    SELECT
      id_mes,
      fecha_mes,
      ROW_NUMBER() OVER() as CII_ID, -- //Como yo la regenero el ID de tabla lo dejo sin significado real
      id_externo_cliente,
      tipo_impuesto,
      valor_impuesto,
      invoiceDataFiscalId,
      invoiceDataName,
      invoiceDataSurname1,
      invoiceDataSurname2,
      invoiceDataCompanyName,
      invoiceDataFiscalIdType,
      invoiceDataEmail,
      invoiceDataContactPhone,
      direccion_facturacion_tipo_via,
      direccion_facturacion_nombre_via,
      direccion_facturacion_numero_via,
      direccion_facturacion_info_adicional,
      direccion_facturacion_municipio,
      direccion_facturacion_provincia,
      direccion_facturacion
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;

-- Marca_Info

  DELETE `mm-commissions-reporting.B2B.CALT_marca_info`
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_marca_info`
    
    SELECT
      id_mes,
      fecha_mes,
      id_marca,
      nombre_marca,
      IF(id_marca = '9999' or id_marca = '177','BUTIK','DEALERS') AS cat_marca
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;

-- Dealer_Info

  DELETE `mm-commissions-reporting.B2B.CALT_dealer_info`
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_dealer_info`
    
    SELECT
      id_mes,
      fecha_mes,
      id_marca,
      id_dealer,
      nombre_dealer
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;
-- Shop_Info

  DELETE `mm-commissions-reporting.B2B.CALT_shop_info`
  WHERE id_mes = mes_int 

  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_shop_info`
    
    SELECT
      id_mes,
      fecha_mes,
      id_marca,
      id_dealer,
      id_shop,
      nombre_shop
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;

--Account info

  DELETE `mm-commissions-reporting.B2B.CALT_account_info`
  WHERE id_mes = mes_int

  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_account_info` 
    
    SELECT
      id_mes,
      fecha_mes,
      id_marca,
      id_dealer,
      id_shop,
      id_account_manager,
      nombre_account_manager
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;

-- Parque

  DELETE `mm-commissions-reporting.B2B.CALT_parque_info` 
  WHERE id_mes = mes_int

  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_parque_info` 
    
    SELECT
      id_mes,
      fecha_mes,
      id_marca,
      id_dealer,
      id_shop,
      id_account_manager,
      venta_online,
      tipo_contrato,
      tipo_paquete,
      IF(UPPER(tipo_paquete) LIKE '%P%','CONV','OM') AS GRUPO,
      tecnologia,
      tipo_linea,
      linea,
      tipo_producto,
      parque_ID,
      producto,
      tipo_cargo,
      fecha_alta,
      fecha_baja,
      contractId,
      subscriptionId,
      bundleId,
      subscriptionBundleId,
      productInstanceId
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE tipo_cargo = 'Cuota'
      AND id_mes = mes_int
    GROUP BY ALL
;

--Facturación

  DELETE `mm-commissions-reporting.B2B.CALT_facturas`
  WHERE id_mes = mes_int

  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_facturas`

    SELECT
      id_mes,
      fecha_mes,
      CONCAT(ROW_NUMBER() OVER(),'_',id_mes) as Facturacion_ID,
      fecha_inicio,
      fecha_fin,
      tipo_producto as tipo_producto_factura,
      parque_ID,
      producto as producto_factura,
      RESUMEN_N1,
      RESUMEN_N2,
      RESUMEN_N3,
      RESUMEN_N4,
      tipo_cargo,
      minutos,
      megabytes,
      sms,
      importe_neto,
      impuestos,
      importe_total,
      invoiceId,
      invoiceNumber,
      ratio_periodo
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL
;

--Comisiones

  DELETE `mm-commissions-reporting.B2B.CALT_comisiones`
  WHERE id_mes = mes_int

  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_comisiones`

    SELECT
      id_mes,
      fecha_mes,
      CONCAT(ROW_NUMBER() OVER(),'_',id_mes) as Facturacion_ID,
      PVPR,
      Ratio_periodo,
      Facturacion_para_escalado,
      Ratio_dealer,
      coste_cesion
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
    WHERE id_mes = mes_int
    GROUP BY ALL

;
END