BEGIN

  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_importaParametrizaciones`();

  --- PENDIENTE DE CONTROL PARA VERIFICAR SI ES NECESARIO INTEGRAR ACTIVACIONES
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_activaciones_krt`(vmes_id);
  CALL `mm-commissions-reporting.COMISIONES.pr_fl_crea_desactivaciones_krt`(vmes_id);
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_calcula_comisiones`(vmes_id);
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_calcula_extras`(vmes_id);
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_calcula_decomisiones`(vmes_id); 
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_importa_retrasos`(vmes_id);  
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_actualiza_tablas_agg_krt`(vmes_id,"TOTAL");
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_actualiza_historicos`(vmes_id);
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_actualiza_historico_ultimo_calculo`(vmes_id);    
  CALL `mm-commissions-reporting.KRT_PYME.pr_fl_actualiza_tabla_transacciones`(vmes_id);
END