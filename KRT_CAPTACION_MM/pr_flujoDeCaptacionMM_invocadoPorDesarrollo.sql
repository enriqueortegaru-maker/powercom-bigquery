BEGIN

  DECLARE desde, hasta, bdesarrollo INT64; 
  SET desde=CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval nmeses month),month)) as integer);
  if nmeses > 0 then
    SET hasta=CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(date_sub(CURRENT_DATE(), interval nmeses month))) as integer);
  else 
    SET hasta=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE()) as integer);
  end if;
  SET bdesarrollo=1;
  call `mm-commissions-reporting.KRT_CAPTACION_MM.pr_flujoDeCaptacionMM`(desde , hasta, registro, bdesarrollo);
END