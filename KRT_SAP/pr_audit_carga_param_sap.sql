BEGIN

  -- Creamos CODSAP como tabla normal y le damos 2 minutos de vida
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.CODSAP` 
  OPTIONS(
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
  ) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_param_sap_debug_ordenes_sap_x_codigo`("TODOS") ORDER BY orden, sociedad, marca, canal, estado;

  -- Creamos DESFAC como tabla normal y le damos 2 minutos de vida
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.DESFAC` 
  OPTIONS(
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
  ) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_param_sap_debug_ordenes_sap_x_desc_factura`("TODOS")   ORDER BY orden, sociedad, marca, canal, estado;

  -- Llamada a la auditoría
  CALL `mm-commissions-reporting.KRT_MIG_PWC.audit_compare_tables`('mm-commissions-reporting','KRT_SAP','CODSAP','mm-commissions-reporting','KRT_SAP','DESFAC');

END