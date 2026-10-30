BEGIN
	DECLARE  MES_COMISION, VERSION INT64;
	SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( desde AS string)),month)) AS INT64);
	SET VERSION=(Select  version
	from  `mm-commissions-reporting.KRT_CAPTACION.FLUJO_MESxVERSION` 
	Where mes<=MES_COMISION
	Order by mes desc
	Limit 1);
	
	If VERSION=0 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.pr_flujoDeCaptacionv0`(desde, hasta, registro);
	elseif VERSION=1 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.pr_flujoDeCaptacionv1`(desde, hasta, registro,bdesarrollo);
	elseif VERSION=2 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.pr_flujoDeCaptacionv2`(desde, hasta, registro,bdesarrollo);
	elseif VERSION=3 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.pr_flujoDeCaptacionv3`(desde, hasta, registro,bdesarrollo);
	elseif VERSION=4 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.pr_flujoDeCaptacionv4`(desde, hasta, registro,bdesarrollo);
	elseif VERSION=5 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.pr_flujoDeCaptacionv4`(desde, hasta, registro,bdesarrollo);


	End If;
END