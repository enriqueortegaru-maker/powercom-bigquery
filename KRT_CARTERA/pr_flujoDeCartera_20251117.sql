BEGIN
	DECLARE  MES_COMISION, VERSION INT64;
	DECLARE LANZA_FLUJO_BQ STRING;
	SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( desde AS string)),month)) AS INT64);
	SET VERSION=(Select  version
	from  `mm-commissions-reporting.KRT_CARTERA.FLUJO_MESxVERSION` 
	Where mes<=MES_COMISION
	Order by mes desc
	Limit 1);
	

--	SET LANZA_FLUJO_BQ=CONCAT("CREATE OR REPLACE TABLE `CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav", VERSION,"`(desde, hasta, registro,binvocaciondesarrollo);");
--  EXECUTE IMMEDIATE LANZA_FLUJO_BQ;

	If VERSION=0 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav0`(desde, hasta, registro,binvocaciondesarrollo);
  Elseif VERSION=1 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav1`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=2 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav2`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=3 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav3`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=4 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav4`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=5 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav5`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=6 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav6`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=7 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav7`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=8 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav8`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=9 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav9`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=10 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav10`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=11 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav11`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=12 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav12`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=13 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav13`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=14 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav14`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=15 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav15`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=16 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav16`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=17 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav17`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=18 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav18`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=19 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav19`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=20 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav20`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=21 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav21`(desde, hasta, registro,binvocaciondesarrollo);
	Elseif VERSION=22 then
		CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav21`(desde, hasta, registro,binvocaciondesarrollo);


End If;


END