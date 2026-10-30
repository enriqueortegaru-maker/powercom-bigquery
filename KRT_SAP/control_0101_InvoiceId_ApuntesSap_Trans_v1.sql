BEGIN


  CALL `mm-commissions-reporting.KRT_SAP.subproc_0101_ActualizarTablaSapFacturaApuntesv1`(VDESDE);
  --DECLARE VDESDE INT64; SET VDESDE=20250601;  
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_audit_factura_apuntes_vs_historico`(VDESDE);

  --DECLARE VDESDE INT64; SET VDESDE=20250601;
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0801_AcualizarInvoiceId_SapFacturaApuntesv1`(VDESDE);
--DECLARE VDESDE INT64; SET VDESDE=20250701;
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0802_ActualizarInvoiceId_Transaccionesv1`(VDESDE);  
  --DECLARE VDESDE INT64; SET VDESDE=20250601;  
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_debug_trans_vs_sap_factura_apuntes_listado_trans_estado_publicado`(VDESDE) where comision is not null and autofactura="SI" and comision<>0;

END