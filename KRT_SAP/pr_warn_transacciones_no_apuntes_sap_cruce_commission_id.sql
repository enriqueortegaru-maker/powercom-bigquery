BEGIN

  SELECT "CAPTACION", "COMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("COMISION", "CAPTACION", "EUSKALTEL", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CAPTACION", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("COMISION", "CAPTACION", "TELECABLE", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CAPTACION", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("COMISION", "CAPTACION", "R", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CAPTACION", "DECOMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("DECOMISION", "CAPTACION", "EUSKALTEL", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CAPTACION", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("DECOMISION", "CAPTACION", "TELECABLE", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CAPTACION", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("DECOMISION", "CAPTACION", "R", DESDE)  
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CARTERA", "COMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("COMISION", "CARTERA", "EUSKALTEL", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CARTERA", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("COMISION", "CARTERA", "TELECABLE", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CARTERA", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("COMISION", "CARTERA", "R", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CARTERA", "DECOMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("DECOMISION", "CARTERA", "EUSKALTEL", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CARTERA", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("DECOMISION", "CARTERA", "TELECABLE", DESDE)
  where estado_audit !="3. Cruzado Correctamente"
  UNION ALL
  SELECT "CARTERA", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_apuntes_transacciones_vs_codigos_factura_apuntes_cruce_commission_id`("DECOMISION", "CARTERA", "R", DESDE)
  where estado_audit !="3. Cruzado Correctamente";

END