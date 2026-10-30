BEGIN

  DECLARE desde, hasta, bdesarrollo INT64; 
  SET desde=CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval nmeses month),month)) as integer);
  SET hasta=CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(date_sub(CURRENT_DATE(), interval nmeses month))) as integer);
  SET bdesarrollo=1;
  call `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCartera`(desde, hasta, registro, bdesarrollo);
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_0107_TipificarLinea` (hasta);
  
END