BEGIN

	--- CALL `mm-commissions-reporting.KRT_MASIVO.pr_fl_actualiza_historicos`(202607);
	DECLARE vmes_factura_dt  DATE;
	--DECLARE vmes_id INT64 DEFAULT NULL;SET vmes_id=202607;
	SET vmes_factura_dt=PARSE_DATE('%Y%m',CAST(vmes_id AS STRING));


	--- PASO1: CREO TABLAS INTERMEDIAS
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.HISTORICO_COMISIONES_EN_PROCESO` OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 	
	SELECT * FROM `mm-commissions-reporting.KRT_MASIVO.f_vt_comisiones_en_proceso`(vmes_id);

	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.HISTORICO_DECOMISIONES_EN_PROCESO` OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	SELECT * FROM `mm-commissions-reporting.KRT_MASIVO.f_vt_decomisiones_en_proceso`(vmes_id);
	

	--- PASO2: ACTUALIZO HISTORICO COMISIONES Y DECOMISIONES FACTURADAS
	---- MIRAR OPTIMIZA
	DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_COMISIONES` where mes_factura_dt=vmes_factura_dt;	
	INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_COMISIONES`  
	SELECT * FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_COMISIONES_EN_PROCESO`;


	DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_DECOMISIONES` where mes_factura_dt=vmes_factura_dt;
	INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_DECOMISIONES`  
	SELECT * FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_DECOMISIONES_EN_PROCESO`;


	DELETE FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` where mes_factura_dt=vmes_factura_dt;
	INSERT INTO `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL`
	select mes_factura_dt, "COMISION" as clase, * except(mes_factura_dt)
	from `mm-commissions-reporting.KRT_MASIVO.HISTORICO_COMISIONES`
	where importe is not null
	and mes_factura_dt=vmes_factura_dt
	UNION ALL
	select  mes_factura_dt, "DECOMISION" as clase, * except(mes_factura_dt)
	from `mm-commissions-reporting.KRT_MASIVO.HISTORICO_DECOMISIONES`
	where importe is not null
	and mes_factura_dt=vmes_factura_dt

	;

END