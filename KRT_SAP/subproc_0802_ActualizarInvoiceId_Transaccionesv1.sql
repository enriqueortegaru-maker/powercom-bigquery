BEGIN

  /*
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_20250828` AS  SELECT * FROM  `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_20250828` AS  SELECT * FROM  `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`;

  -- DECLARE VDESDE INT64; SET VDESDE=20250501;

  with ids_actualizar as (
    select mes_factura_dt, marca_ds as marca,  invoice_id, com_id as commission_id
    from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` 
    CROSS JOIN unnest(commission_id) as com_id
    where mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING))
    and UPPER(TRIM(autofactura))="SI"    
  ) select t. marca, t.commission_id, a.invoice_id
  from `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
  inner join ids_actualizar a on t.mes_factura_dt=a.mes_factura_dt 
  and t.marca=a.marca 
  and t.commission_id=a.commission_id 
  where t.mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING));
  */

  
  --DECLARE VDESDE INT64; SET VDESDE=20250601;
  UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
  SET t.invoice_id=a.invoice_id
  from (
    --DECLARE VDESDE INT64; SET VDESDE=20250601;    
    select mes_factura_dt, marca_ds as marca,  invoice_id, com_id as commission_id
    from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` 
    CROSS JOIN unnest(commission_id) as com_id
    where mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING))
    and UPPER(TRIM(autofactura))="SI"
  ) a
  where t.mes_factura_dt=a.mes_factura_dt 
  and t.marca=a.marca
  and t.commission_id=a.commission_id 
  and t.mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING));



  update `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
  set estado='facturado' 
  where invoice_id is not null 
  and mes_factura_dt=PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING));


END