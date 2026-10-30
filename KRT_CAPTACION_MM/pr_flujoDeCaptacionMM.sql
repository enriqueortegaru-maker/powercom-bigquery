BEGIN
	DECLARE  MES_COMISION, VERSION INT64;
	SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( desde AS string)),month)) AS INT64);
	SET VERSION=(Select  version
	from  `mm-commissions-reporting.KRT_CAPTACION_MM.FLUJO_MESxVERSION` 
	Where mes<=MES_COMISION
	Order by mes desc
	Limit 1);
	
	If VERSION=0 then
		CALL `mm-commissions-reporting.KRT_CAPTACION_MM.pr_flujoDeCaptacionMMv0`(desde, hasta, registro);
	End If;
END