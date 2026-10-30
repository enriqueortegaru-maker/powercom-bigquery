BEGIN
  --DECLARE id_mes INT64;set id_mes=202605;
  
  --- call `mm-commissions-reporting.KRT_PYME.pr_fl_descubreEventos`(202605) 
  --- PASO 1 
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_ventas_comisiones`();
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_activaciones_krt`(id_mes);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_device_base_krt`();
  

END