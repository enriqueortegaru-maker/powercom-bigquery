BEGIN
		DECLARE vMES_COMISION_ID INT64;
		DECLARE vMES_COMISION_DT DATE;
	--  VARIABLES LOCALES	
  --  DECLARE DESDE,HASTA, VERSION_FL INT64; SET DESDE=20230401;SET HASTA=20230430;SET VERSION_FL=7;	

		SET	vMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 
		SET vMES_COMISION_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month);

    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_AGENTE_MIGRACION` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_AGENTE_MIGRACION` select vmes_comision_id as mes_comision_id, v.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_AGENTE_MIGRACION` v;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_AGENTE_AUTOMATIZACION` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_AGENTE_AUTOMATIZACION` select vmes_comision_id as mes_comision_id, v.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_AGENTE_AUTOMATIZACION` v;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_CANAL_NO_INF` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_CANAL_NO_INF` select vmes_comision_id, s.*  from `mm-commissions-reporting.KRT_CAPTACION.LOG_015005_SERVICIOS_CAPTACION_MIGRADOS_CAN_NO_INF` s;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_RECREADO_CANAL_NO_INF_ALTA` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_RECREADO_CANAL_NO_INF_ALTA` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_015005_SERVICIOS_CAPTACION_MIGRADOS_CAN_INF` s; 
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_NO_RECREADO_CANAL_NO_INF_NO_ALTA` where mes_comision_id=vmes_comision_id;
    INSERT`mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_NO_RECREADO_CANAL_NO_INF_NO_ALTA` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_015005_SERVICIOS_CAPTACION_MIGRADOS_CAN_INF_NO_ALTA` s; 
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERV_BASICOS_MIGRADOS_AGENTES_MIG` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERV_BASICOS_MIGRADOS_AGENTES_MIG` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_015010_SERV_BASICOS_MIGRADOS_AGENTES_MIG` s;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SVAS_MIGRADOS_AGENTES_MIG` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SVAS_MIGRADOS_AGENTES_MIG` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_015010_SVAS_MIGRADOS_AGENTES_MIG` s;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_ALTA_PREVIA_MIGRACION_PLATAFORMA_Y_MASIVA` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_SERVICIOS_CAPTACION_ALTA_PREVIA_MIGRACION_PLATAFORMA_Y_MASIVA` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_015020_SERVICIOS_CAPTACION_ALTA_Y_MIGRACION` s;

    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_PROCESO_AUTOMATIZACION`  as select * from `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_AGENTE_MIGRACION` where 1=2;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_PROCESO_AUTOMATIZACION` where mes_comision_id=vmes_comision_id;
    INSERT `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_VENTAS_PROCESO_AUTOMATIZACION` select vmes_comision_id, s.* from `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_PROCESO_AUTOMATIZACION` s;

END