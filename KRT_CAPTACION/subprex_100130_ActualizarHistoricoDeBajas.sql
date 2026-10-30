BEGIN

	DECLARE vMES_BAJA_ID INT64;
	DECLARE vMES_BAJA_DT DATE;
--  VARIABLES LOCALES	
  --DECLARE  DESDE,HASTA, VERSION_FL INT64; SET DESDE=20230901;SET HASTA=20230930;SET VERSION_FL=11;
	SET	vMES_BAJA_ID= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 
	SET vMES_BAJA_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month);

  --select * from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_HISTORICO` v;
  --select vmes_baja_dt as mes_baja_dt, vmes_baja_id as mes_baja_id, v.* from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_ALTAS_24M` v;

  DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_HISTORICO` where mes_baja_dt=vmes_baja_dt;
  INSERT `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_HISTORICO` select vmes_baja_dt as mes_baja_dt, vmes_baja_id as mes_baja_id, v.* from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_ALTAS_24M` v;

  DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.BAJAS_TOT_24M_HISTORICO` where mes_baja_dt=vmes_baja_dt;
  INSERT `mm-commissions-reporting.KRT_CAPTACION.BAJAS_TOT_24M_HISTORICO` select vmes_baja_dt as mes_baja_dt, vmes_baja_id as mes_baja_id, v.* from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_TOT_ALTAS_24M` v;

END