BEGIN

  --DECLARE vmes_id INT64 DEFAULT 202609;
  DECLARE tipo STRING DEFAULT "TOTAL";
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_ventas_y_bajas_comisiones_krt`(vmes_id);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_device_base_krt`(vmes_id);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_ventas_retramitadas_krt`(vmes_id);    
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_activaciones_krt`(vmes_id);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_desactivaciones_krt`(vmes_id);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_actualiza_tablas_agg_krt`(vmes_id, tipo);


END