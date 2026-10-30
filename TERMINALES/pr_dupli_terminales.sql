BEGIN

  INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES`(

/* EL RESULTADO DEBE DARNOS AQUELLOS IMEI QUE INCLUIMOS A LIQUIDACIÓN Y GENERAN DUPLICADO POR ESTAR EN VARIAS VENTAS, GENERANDO UN NEGATIVO/POSITIVO DE LAS TRANSACCIONES ASOCIADAS A LAS VENTAS DE IMEI POSTERIORES A LA INICIAL QUE QUEDA CÓMO RESULTADO VIVO POSITIVO*/

    SELECT  
    'DUPLI_IMEI'||'_'||PROCESO_PR||'_'||MES_PR||'_'||ROW_NUMBER () OVER () AS commission_id,	
    'calculado' AS estado,	
    MES_LIQUIDADO_PR AS mes_liquidado,	
    MES_PR AS id_mes,	
    agrupacion_canal,	
    canal,	
    REPLACE(t.concepto,'T -','X -') AS concepto,	
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
    order_id,	-- ORDENES DE PEDIDO QVANTEL - EL ID_SUBSCRIPTION_TERMINAL PROVIENE DE MYSIM, ESTE SISTEMA ES EL PARÁMETRO DE PEDIDO, AL NO CONTENER NI CONTRACT_ID NI ORDER_ID
    order_type_agg,	
    cod_segmento,	
    cod_marca,	
    cod_tipo_contrato,	
    cod_producto,	
    cod_canal,	
    claim_code,	
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
    'TRUE' AS DUPLICATED_IMEI, 
    AFTER_SALE,	-- PENDIENTE DESARROLLO
    PRODUCT_CODE,	
    TERMINAL_NAME,	
    CONTRACT_ID, -- CONTIENE EL CONTRACT_ID EN LAS NUEVAS ALTAS Y EL ID_SUBSCRIPTION_TERMINAL EN EL CASO DE RENUEVOS
    PURCH_PRICE,
    NET_SUBSIDY,
    END_USER_PRICE,
    COSTE_DEVICE,
    OFFER_SEGMENT,
    INSTALLMENT_ID,
    FINANCIADO
    
  FROM `mm-commissions-reporting.TERMINALES.TERMINALES` T

    INNER JOIN `mm-commissions-reporting.TERMINALES.V_TERMINALES_IMEI_DUPLI` I -- VALIDAMOS QUE LA VENTA TENGA UN IMEI DUPLICADO, SIENDO POSTERIOR A UNA VENTA EN NETO POSITIVO
      ON  T.IMEI = I.IMEI 
      AND CAST(T.ORDER_ID AS NUMERIC) <> I.ORDER_INI_VIVA

  WHERE
-- VALIDAMOS QUE ENTRE LOS DUPLICADOS DE ÓRDENES DISTINTAS DE LA ORDEN VIVA NO SE ENCUENTRE UNA VENTA ERRÓNEA, QUE EN REALIDAD LIBERA EL IMEI PARA UNA VENTA POSTERIOR E IFS LO MARCABA CÓMO WRONG_ADD
    T.IMEI||T.order_id NOT IN (
      SELECT w.imei||W.order_id FROM `mm-commissions-reporting.TERMINALES.V_TERMINALES_WRONG` W
    ) 
    AND T.sale_date >= '2022-01-01' -- DESCARTAMOS VENTAS VENDIDAS ANTES DE ENERO 2022, PUES LA INGESTA HISTÓRICA SE REALIZÓ DESDE PRIMEROS DE 2022 Y SON GAP POR LA INGESTA
  );
 
END