BEGIN
	DECLARE vMES_COMISION_ID INT64;
	DECLARE vMES_COMISION_DT DATE;
	--  VARIABLES LOCALES	
  --  DECLARE DESDE,HASTA, VERSION_FL INT64; SET DESDE=20230401;SET HASTA=20230430;SET VERSION_FL=7;	

	SET	vMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 
	SET vMES_COMISION_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month);

    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_AGENTE_MIGRACION` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_AGENTE_MIGRACION` select vmes_comision_id as mes_comision_id, v.* from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_MIGRACION` v;
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_AGENTE_AUTOMATIZACION` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_AGENTE_AUTOMATIZACION` select vmes_comision_id as mes_comision_id, v.* from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_AUTOMATIZACION` v;
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_PROCESO_AUTOMATIZACION` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_PROCESO_AUTOMATIZACION` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_PROCESO_AUTOMATIZACION` s;
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_ALTA_MAS_MIGRACION_MASIVA` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_ALTA_MAS_MIGRACION_MASIVA` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_ALTA_MAS_MIGRACION` s;

    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_ALTA_MAS_MIGRACION_MASIVA`  as select * from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_SERVICIOS_CARTERA_ALTA_MAS_MIGRACION_MASIVA` where 1=2;

        --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_PROCESO_AUTOMATIZACION`  as select * from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_AGENTE_MIGRACION` where 1=2;


END