BEGIN


		-- 8.1.1 CREACION DE TABLA TEMPORAL DE CARGA PARAM_SAP_ZAGRUPACION_LOAD
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ZAGRUPACION_LOAD` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) as 
		select * from `mm-commissions-reporting.KRT_SAP.f_vt_param_sap_crea_tabla_PARAM_SAP_ZAGRUPACION`();

		-- 8.1.2 REGISTROS PARAMETRIZACIONES EN TABLAS AGG  
		
		DELETE FROM `mm-commissions-reporting.KRT_SAP.AGG_PARAM_SAP_ZAGRUPACION`  WHERE fecha_reg_dt=CURRENT_DATE();	
		
		INSERT INTO `mm-commissions-reporting.KRT_SAP.AGG_PARAM_SAP_ZAGRUPACION` 
		select current_date() as fecha_reg_dt,* 
		from `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ZAGRUPACION_LOAD`;

		-- 8.1.3 BORRO REGISTROS DE PARAMETRIZACIONES 

		DELETE FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ZAGRUPACION`  WHERE TRUE;	


		---- PASO 3 IMPORTO REGISTROS DE TABLAS GS 
		INSERT INTO `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ZAGRUPACION`
		select * from `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ZAGRUPACION_LOAD`  where Zagrupacion is not null;

END