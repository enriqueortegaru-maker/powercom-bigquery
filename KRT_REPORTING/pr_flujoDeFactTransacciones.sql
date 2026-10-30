BEGIN


  DECLARE vmes_factura_dt DATE; 
  SET vmes_factura_dt=date_trunc(date_sub(CURRENT_DATE(), interval nmeses month),month);

  DELETE FROM  `mm-commissions-reporting.KRT_REPORTING.FACTTRANSACCIONES`  where mes_factura_dt=vmes_factura_dt;
  INSERT INTO `mm-commissions-reporting.KRT_REPORTING.FACTTRANSACCIONES`
  SELECT 
  commission_id,
  estado,
  mes_factura_dt,
  mes_liquidado,
  id_mes,
  agrupacion_canal,
  canal,
  subcanal,
  concepto,
  tipo_concepto,
  comision,
  id_comisionista,
  distribuidor,
  sfid_id,
  seller,
  nombre_comercio,
  cif,
  marca,
  service_type,
  tariff_id,
  tariff_ds,
  service_id,
  customer_id,
  technology_ds,
  sale_date,
  activation_date,
  deactivation_date,
  campaign_code,
  sociedad,
  bp,
  segmento,
  orden,
  clase_concepto,
  concepto_origen_ds_gekt,
  tariff_id_origin,
  tariff_ds_origin,
  service_id_origin,
  operation,
  operation_type,
  canal_gekt,
  subcanal_gekt,
  marco,
  distribuidor_gekt,
  categoria_servicio_ds,
  clase,
  tipo,
  FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
  where mes_factura_dt=vmes_factura_dt;


END