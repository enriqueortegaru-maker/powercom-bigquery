BEGIN
	DECLARE  MES_COMISION, VERSION INT64;
	SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( desde AS string)),month)) AS INT64);
	SET VERSION=(Select  version
	from  `mm-commissions-reporting.KRT_CAPTACION.FLUJO_MESxVERSION` 
	Where mes<=MES_COMISION
	Order by mes desc
	Limit 1);
	
	If VERSION=0 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv0`(desde, hasta, registro);
	Elseif VERSION=1 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv1`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=2 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv2`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=3 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv3`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=4 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv4`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=5 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv5`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=6 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv6`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=7 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv7`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=8 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv8`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=9 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv9`(desde, hasta, registro,bdesarrollo);
	Elseif VERSION=10 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv10`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=11 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv11`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=12 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv12`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=13 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv13`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=14 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv14`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=15 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv15`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=16 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv16`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=17 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv17`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=18 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv18`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=19 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv19`(desde, hasta, registro,bdesarrollo);		
	Elseif VERSION=20 then
		CALL `mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv20`(desde, hasta, registro,bdesarrollo);		

	End If;
END