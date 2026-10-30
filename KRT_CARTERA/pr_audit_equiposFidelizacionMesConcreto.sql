BEGIN

  DECLARE vDESDE, vHASTA INT64; 
  --DECLARE VIDMES INT64;SET VIDMES=202412;
  SET vDESDE=CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval nmeses month),month)) as integer);  
  --SET HASTA=CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(PARSE_DATE("%Y%m",CAST(VIDMES AS STRING)), MONTH)) AS INT64);

  CALL `mm-commissions-reporting.KRT_CARTERA.pr_audit_equiposFidelizacion`( vdesde);

END