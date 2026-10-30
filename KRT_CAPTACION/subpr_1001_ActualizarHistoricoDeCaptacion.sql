BEGIN
	DECLARE vMES_COMISION_ID INT64;
--	DECLARE vMES_COMISION_ID, DESDE, HASTA,VERSION_FL INT64;
	DECLARE vMES_COMISION_DT DATE;	
--	SET DESDE=20220601;
--	SET HASTA=20220630;
--	SET VERSION_FL=3;	
	SET	vMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 
	SET vMES_COMISION_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month);

	--- COMISIONES

	DELETE
	FROM
		`mm-commissions-reporting.KRT_CAPTACION.ACC_CAPTACION_HISTORICO` AS h
	WHERE
		h.mes_comision_dt=vMES_COMISION_DT
		and h.VERSION=VERSION_FL;

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_1001_ACC_CAPTACION_HISTORICO_ADD` AS 
	SELECT vmes_comision_dt, mes_comision_id, version_fl, marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, fecha_rfb_dt, fecha_venta_neta_dt, canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, categoria_servicio_ds, cif_nif, segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb, expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid,  desc_mm,  clase_mm, CAST(NULL  AS STRING) AS  pedido, plays AS  nplays, plays AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p, clave, marco_retributivo_ds, flag_marca_cartera, grupo_rappel_ds, orden_sap, importe, decomisionable
	FROM
		`mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;


	INSERT INTO
		`mm-commissions-reporting.KRT_CAPTACION.ACC_CAPTACION_HISTORICO`
	SELECT 
		c.*
	FROM
		`mm-commissions-reporting.KRT_CAPTACION.LOG_1001_ACC_CAPTACION_HISTORICO_ADD` AS c; 
		
	--- CLAWBACK
	DELETE
	FROM
		`mm-commissions-reporting.KRT_CAPTACION.ACC_CLAWBACK_HISTORICO` AS h
	WHERE
		h.mes_decomision_id=vMES_COMISION_ID
		and h.VERSION=VERSION_FL;		
	INSERT INTO
		`mm-commissions-reporting.KRT_CAPTACION.ACC_CLAWBACK_HISTORICO`
	SELECT
		DISTINCT * ,VERSION_FL
	FROM
	`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`;


	
END