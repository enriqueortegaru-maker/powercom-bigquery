BEGIN

  DECLARE vmes_id INT64; 
  SET vmes_id=CAST(FORMAT_DATE("%Y%m",date_trunc(date_sub(CURRENT_DATE(), interval vnmeses month),month)) as integer);

  if vnmeses > 0 then
    SET vmes_id=CAST(FORMAT_DATE("%Y%m",LAST_DAY(date_sub(CURRENT_DATE(), interval vnmeses month))) as integer);
  else 
    SET vmes_id=CAST(FORMAT_DATE("%Y%m",CURRENT_DATE()) as integer);
  end if;

  CALL `mm-commissions-reporting.KRT_PYME.fl_ejecutaFlujoComisiones`(vmes_id);

END