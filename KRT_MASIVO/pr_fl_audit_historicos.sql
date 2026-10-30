BEGIN

  --DECLARE vmes_id INT64 DEFAULT 202608;
  DECLARE vmes_factura_dt DATE;
  SET vmes_factura_dt=DATE_TRUNC(PARSE_DATE('%Y%m',CAST(vmes_id as STRING)), MONTH);
  --SELECT vmes_factura_dt;

  ---==================================================================================================
  --- AUDITORIA HISTORICO COMISIONADO ACTUALIZADO FRENTE A ULTIMO CALCULO HISTORICO COMISIONADO 
  ---==================================================================================================


  -- PASO 1: SELECCIONAMOS POBLACION OBJETO DE AUDITORIA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.LOG_HISTORICO_ULTIMO_CALCULO_TOTAL` 
  OPTIONS( expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) ) AS 
  SELECT distinct * except(fecha_Calc_dt, commission_id, estado, hash_document_number) 
  FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_TOTAL` 
  where mes_factura_dt=vmes_factura_dt 
  and data_source_ds="MYSIM";

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.LOG_HISTORICO_TOTAL` 
  OPTIONS( expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) ) AS 
  SELECT distinct * except(fecha_Calc_dt, commission_id, estado, hash_document_number) 
  FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` 
  where mes_factura_dt=vmes_factura_dt;


  -- PASO 2: REALIZAMOS AUDITORIA
  CALL `mm-commissions-reporting.KRT_MIG_PWC.audit_compare_tables`('mm-commissions-reporting', 'KRT_MASIVO', 'LOG_HISTORICO_ULTIMO_CALCULO_TOTAL', 
  'mm-commissions-reporting', 'KRT_MASIVO', 'LOG_HISTORICO_TOTAL');


  -- PASO 3: ACTUALIZMOS RESULTADO DE AUDITORIA

  DELETE FROM `mm-commissions-reporting.KRT_MASIVO.AUDIT_HISTORICO_TOTAL`
  WHERE mes_factura_dt=vmes_factura_dt;

  
  --DECLARE vmes_id INT64 DEFAULT 202608; DECLARE vmes_factura_dt DATE; SET vmes_factura_dt=DATE_TRUNC(PARSE_DATE('%Y%m',CAST(vmes_id as STRING)), MONTH);
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.AUDIT_HISTORICO_TOTAL` partition by mes_factura_dt AS 
  --select *, CAST(NULL AS STRING) CAUSA  from  `mm-commissions-reporting.KRT_MASIVO.HISTORICO_ULTIMO_CALCULO_TOTAL`  where 1=0;

  INSERT INTO `mm-commissions-reporting.KRT_MASIVO.AUDIT_HISTORICO_TOTAL`
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
    channel_segment_ds,
    channel_type_ds,
    master_channel_ds,
    channel_ds,
    subchannel_ds,
    agrupacion_canal_ventas_base,
    agrupacion_canal,
    canal,
    distribuidor,
    id_comisionista,
    nombre_comercio,
    user_store,
    sfid_id,
    service_type,
    technology_ds,
    tariff_id,
    tariff_ds,
    segment_ds,
    sub_segment_ds,
    customer_id,
    contract_id,
    account_id,
    hash_document_number,
    province,
    zip_code,
    line_type_ds,
    service_id,
    id,
    id_subscription_terminal,
    terminal_model,
    total_pay_value_without_vat,
    total_pay_value,
    phone_nm,
    sell_type,
    bundle_type,
    order_type_agg,
    flag_order,
    order_fix_id,
    order_id,
    campaign_code,
    tipo,
    operacion,
    seller,
    creado,
    creado_por,
    port_in_operator_ds,
    portability_group_donor,
    portability_operator_donor,
    comisiona,
    concepto_marco,
    concepto,
    marco,
    grupo_rappel,
    orden,
    importe,
    sale_date,
    cancellation_day_id,
    activation_date,
    deactivation_date,
    deactivation_reason_ds,
    grid,
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
    channel_segment_ds,
    channel_type_ds,
    master_channel_ds,
    channel_ds,
    subchannel_ds,
    agrupacion_canal_ventas_base,
    agrupacion_canal,
    canal,
    distribuidor,
    id_comisionista,
    nombre_comercio,
    user_store,
    sfid_id,
    service_type,
    technology_ds,
    tariff_id,
    tariff_ds,
    segment_ds,
    sub_segment_ds,
    customer_id,
    contract_id,
    account_id,
    CAST(NULL AS STRING),
    province,
    zip_code,
    line_type_ds,
    service_id,
    id,
    id_subscription_terminal,
    terminal_model,
    total_pay_value_without_vat,
    total_pay_value,
    phone_nm,
    sell_type,
    bundle_type,
    order_type_agg,
    flag_order,
    order_fix_id,
    order_id,
    campaign_code,
    tipo,
    operacion,
    seller,
    creado,
    creado_por,
    port_in_operator_ds,
    portability_group_donor,
    portability_operator_donor,
    comisiona,
    concepto_marco,
    concepto,
    marco,
    grupo_rappel,
    orden,
    importe,
    sale_date,
    cancellation_day_id,
    activation_date,
    deactivation_date,
    deactivation_reason_ds,
    grid,
    CAUSA
  FROM `mm-commissions-reporting.KRT_MASIVO.AUDIT_LOG_HISTORICO`
  WHERE mes_factura_dt=vmes_factura_dt;



END