BEGIN
  --DECLARE id_mes INT64;set id_mes=202605;
  
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_ventas_comisiones`();
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_activaciones_krt`(id_mes);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_device_base_krt`();

END