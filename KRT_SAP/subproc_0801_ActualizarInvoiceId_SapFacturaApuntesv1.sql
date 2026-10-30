BEGIN

  /*
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_20250828` AS  SELECT * FROM  `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_20250828` AS  SELECT * FROM  `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`;
  */
  -- DECLARE VDESDE INT64; SET VDESDE=20250501;


  /* CONTROL
  with codigos_actualizar as (
  --  DECLARE VDESDE INT64; SET VDESDE=20250701;
    select distinct marca_ds, CAST(bp AS INT64) as bp, tipo_concepto as CODIGO, invoice_id, vdesde, PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING)) as mes_factura_dt, count(bp) as nr
    from `mm-commissions-reporting.KRT_SAP.f_vt_audit_factura_vs_sap_factura_apuntes_debug_listado_codigos_facturados_con_mismo_importe_en_apuntes_sap`(VDESDE,VDESDE)
    group by all
  ) SELECT count(codigo) as nc, count(distinct codigo) as ncd
  from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
  inner join codigos_actualizar using(marca_ds,mes_factura_dt,bp, codigo)

  */


  -- DECLARE VDESDE INT64; SET VDESDE=20250501;
  UPDATE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` a
  SET a.invoice_id=c.invoice_id
  FROM (
    select distinct marca_ds, CAST(bp AS INT64) as bp, tipo_concepto as CODIGO, invoice_id, vdesde, PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING)) as mes_factura_dt, count(bp) as nr
    from `mm-commissions-reporting.KRT_SAP.f_vt_audit_factura_vs_sap_factura_apuntes_debug_listado_codigos_facturados_con_mismo_importe_en_apuntes_sap`(VDESDE,VDESDE)
    group by all
  ) c
  where a.marca_ds=c.marca_ds 
  and a.mes_factura_dt=c.mes_factura_dt
  and a.bp=c.bp
  and a.codigo=c.codigo;

  UPDATE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`  
  SET estado='facturado' 
  where estado !='facturado' 
  and mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING))
  and TRIM(UPPER(autofactura))="SI";

/*
  DECLARE VDESDE INT64; SET VDESDE=20250601;

  with ids_actualizar as (
    select mes_factura_dt, marca_ds as marca,  invoice_id, com_id as commission_id
    from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` 
    CROSS JOIN unnest(commission_id) as com_id
    where mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING))
  ) select t. marca, t.commission_id, a.invoice_id
  from `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
  inner join ids_actualizar a on t.mes_factura_dt=a.mes_factura_dt and t.marca=a.marca and t.commission_id=a.commission_id 
  where t.mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING));

  
  DECLARE VDESDE INT64; SET VDESDE=20250601;
  UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
  SET t.invoice_id=a.invoice_id
  from (
    select mes_factura_dt, marca_ds as marca,  invoice_id, com_id as commission_id
    from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` 
    CROSS JOIN unnest(commission_id) as com_id
    where mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING))
  ) a
  where t.mes_factura_dt=a.mes_factura_dt 
  and t.marca=a.marca
  and t.commission_id=a.commission_id 
  and t.mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING));




  DECLARE VDESDE INT64; SET VDESDE=20250701;
  select invoice_id, com_id
  from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
  CROSS JOIN unnest(commission_id) as com_id
  where mes_factura_dt='2025-07-01';


  UPDATE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`  SET estado='facturado' where estado !='facturado'

  select distinct estado from `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`;

  update `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
  set estado='facturado' where invoice_id is not null and mes_factura_dt='2025-06-01'
*/
END