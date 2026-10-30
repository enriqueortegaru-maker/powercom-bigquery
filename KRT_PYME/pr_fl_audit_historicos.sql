BEGIN

  --DECLARE vmes_id INT64 DEFAULT 202609;
  DECLARE vmes_factura_dt DATE;
  SET vmes_factura_dt=DATE_TRUNC(PARSE_DATE('%Y%m',CAST(vmes_id as STRING)), MONTH);
  --SELECT vmes_factura_dt;

  ---==================================================================================================
  --- AUDITORIA HISTORICO COMISIONADO ACTUALIZADO FRENTE A ULTIMO CALCULO HISTORICO COMISIONADO 
  ---==================================================================================================


  -- PASO 1: SELECCIONAMOS POBLACION OBJETO DE AUDITORIA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_PYME.LOG_HISTORICO_ULTIMO_CALCULO_TOTAL` 
  OPTIONS( expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) ) AS 
  SELECT distinct * except(fecha_Calc_dt, commission_id, estado) 
  FROM `mm-commissions-reporting.KRT_PYME.HISTORICO_ULTIMO_CALCULO_TOTAL` 
  where mes_factura_dt=vmes_factura_dt 
  and data_source_ds in ("EKTNET","TCNET","SIEBEL")
  and channel_ds="FFCC CANAL INDIRECTO" ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_PYME.LOG_HISTORICO_TOTAL` 
  OPTIONS( expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) ) AS 
  SELECT distinct * except(fecha_Calc_dt, commission_id, estado) 
  FROM `mm-commissions-reporting.KRT_PYME.HISTORICO_TOTAL` 
  where mes_factura_dt=vmes_factura_dt
  and data_source_ds in ("EKTNET","TCNET","SIEBEL")
  and channel_ds="FFCC CANAL INDIRECTO" ;  
  


  -- PASO 2: REALIZAMOS AUDITORIA
  CALL `mm-commissions-reporting.KRT_MIG_PWC.audit_compare_tables`('mm-commissions-reporting', 'KRT_PYME', 'LOG_HISTORICO_ULTIMO_CALCULO_TOTAL', 
  'mm-commissions-reporting', 'KRT_PYME', 'LOG_HISTORICO_TOTAL');


  -- PASO 3: ACTUALIZMOS RESULTADO DE AUDITORIA

  DELETE FROM `mm-commissions-reporting.KRT_PYME.AUDIT_HISTORICO_TOTAL`
  WHERE mes_factura_dt=vmes_factura_dt;

  
  --DECLARE vmes_id INT64 DEFAULT 202608; DECLARE vmes_factura_dt DATE; SET vmes_factura_dt=DATE_TRUNC(PARSE_DATE('%Y%m',CAST(vmes_id as STRING)), MONTH);
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_PYME.AUDIT_HISTORICO_TOTAL` partition by mes_factura_dt AS 
  --select *, CAST(NULL AS STRING) CAUSA  from  `mm-commissions-reporting.KRT_PYME.HISTORICO_ULTIMO_CALCULO_TOTAL`  where 1=0;

  INSERT INTO `mm-commissions-reporting.KRT_PYME.AUDIT_HISTORICO_TOTAL`
  (
    mes_factura_dt,
    clase,
    commission_id,
    id_registro,
    invoice_id,
    estado,
    fecha_calc_dt,
    mes_id,
    data_source_ds,
    brand_ds,
    channel_ds,
    subchannel_ds,
    distribuidor,
    sfid_id,
    service_type,
    tariff_id,
    tariff_ds,
    customer_id,
    service_id,
    id,
    id_subscription_terminal,
    total_pay_value_without_vat,
    total_pay_value,
    phone_nm,
    sell_type,
    order_type_agg,
    tipo,
    operacion,
    seller,
    comisiona,
    concepto_marco,
    concepto,
    marco,
    orden,
    importe,
    sale_date,
    activation_date,
    deactivation_date,
    CAUSA

  )
  SELECT
    mes_factura_dt,
    clase,
    CAST(NULL AS STRING),
    id_registro,
    invoice_id,
    CAST(NULL AS STRING),
    CAST(NULL AS DATE),
    mes_id,
    data_source_ds,
    brand_ds,
    channel_ds,
    subchannel_ds,
    distribuidor,
    sfid_id,
    service_type,
    tariff_id,
    tariff_ds,
    customer_id,
    service_id,
    id,
    id_subscription_terminal,
    total_pay_value_without_vat,
    total_pay_value,
    phone_nm,
    sell_type,
    order_type_agg,
    tipo,
    operacion,
    seller,
    comisiona,
    concepto_marco,
    concepto,
    marco,
    orden,
    importe,
    sale_date,
    activation_date,
    deactivation_date,
    CAUSA
  FROM `mm-commissions-reporting.KRT_PYME.AUDIT_LOG_HISTORICO`
  WHERE mes_factura_dt=vmes_factura_dt;



END