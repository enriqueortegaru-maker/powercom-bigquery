BEGIN



  DECLARE desde, hasta, bdesarrollo INT64; 
--  DECLARE desde, hasta, bdesarrollo, nmeses, registro INT64; 
--  SET nmeses=1;
--  SET registro=1;
  SET desde=CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval nmeses month),month)) as integer);
  if nmeses > 0 then
    SET hasta=CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(date_sub(CURRENT_DATE(), interval nmeses month))) as integer);
  else 
    SET hasta=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE()) as integer);
  end if;
  SET bdesarrollo=1; 
--  SELECT desde, hasta;
  
  call `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeIncentivosDeTerminales`(desde,hasta);
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_0107_TipificarLinea` (hasta);
END