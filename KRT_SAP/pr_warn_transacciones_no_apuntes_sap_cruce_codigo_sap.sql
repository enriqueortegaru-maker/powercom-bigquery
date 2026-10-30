BEGIN

  SELECT "CAPTACION", "COMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("COMISION", "CAPTACION", "EUSKALTEL", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CAPTACION", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("COMISION", "CAPTACION", "TELECABLE", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CAPTACION", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("COMISION", "CAPTACION", "R", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CAPTACION", "DECOMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("DECOMISION", "CAPTACION", "EUSKALTEL", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CAPTACION", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("DECOMISION", "CAPTACION", "TELECABLE", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CAPTACION", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("DECOMISION", "CAPTACION", "R", DESDE)  
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CARTERA", "COMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("COMISION", "CARTERA", "EUSKALTEL", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CARTERA", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("COMISION", "CARTERA", "TELECABLE", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CARTERA", "COMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("COMISION", "CARTERA", "R", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CARTERA", "DECOMISION",* 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("DECOMISION", "CARTERA", "EUSKALTEL", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CARTERA", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("DECOMISION", "CARTERA", "TELECABLE", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto"
  UNION ALL
  SELECT "CARTERA", "DECOMISION", * 
  FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_codigos_transacciones_vs_factura_apuntes`("DECOMISION", "CARTERA", "R", DESDE)
  where accion_batch_input !="5. Cuadre Contable Exacto";

END