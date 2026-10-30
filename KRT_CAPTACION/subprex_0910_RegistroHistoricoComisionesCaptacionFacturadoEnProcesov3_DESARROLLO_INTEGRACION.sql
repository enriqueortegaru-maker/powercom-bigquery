BEGIN


	--- PASO1: CREO TABLAS INTERMEDIAS
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO` AS 	
	SELECT * 	FROM `mm-commissions-reporting.KRT_CAPTACION.f_vt_comisiones_en_proceso`(vdesde, vhasta);

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
	SELECT *
	FROM `mm-commissions-reporting.KRT_CAPTACION.f_vt_decomisiones_en_proceso`(vdesde, vhasta);


	--- PASO2: ACTUALIZO HISTORICO COMISIONES Y DECOMISIONES FACTURADAS
	--DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` where mes_comision_dt=vmes_comision_dt;
	DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` where mes_factura_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));	
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO`  
	SELECT 
		mes_factura_dt,
		mes_comision_dt,
		commission_id,
		id_registro,
		invoice_id,
		estado,
		fecha_calc_dt,
		desde,
		hasta,
		version,
		marca_ds,
		Cliente_id,
		servicio_id,
		detalle_servicio_ds,
		CONCEPTO_DS,
		FECHA_RFB_ID,
		FECHA_VENTA_NETA_ID,
		fecha_rfb_dt,
		fecha_venta_neta_dt,
		canal_alta_ds,
		subcanal_ds,
		tipo_canal_alta_ds,
		nombre_distribuidor_alta_ds,
		agente_alta_id,
		agente_creador_id,
		categoria_servicio_ds,
		cif_nif,
		segmento_ds,
		subsegmento_ds,
		marca_cartera_ds,
		Antiguedad_Cliente,
		equipo_ds,
		territorio_ds,
		tecnologia_detalle_ds,
		portabilidad_in_lg,
		gb,
		expediente_id,
		expediente_padre_id,
		contrato_id,
		tipo_pedido_ds,
		pedido_id,
		tipo_producto_pedido_re_ds,
		visibilidad_pedido_lg,
		catalogo_id,
		grid,
		desc_mm,
		clase_mm,
		pedido,
		nplays,
		nplays_rfb,
		cat_plays,
		cat_plays_rfb,
		nplays_p,
		nplays_rfb_p,
		cat_plays_p,
		cat_plays_rfb_p,
		clave,
		marco_retributivo_ds,
		flag_marca_cartera,
		grupo_rappel_ds,
		orden_sap,
		importe,
		decomisionable,
		mes_comision_id,
  	CAST(NULL AS STRING) AS raiz,
  	CAST(NULL AS STRING) AS hex6,
  	CAST(NULL AS INT64) AS nn
	FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO`;


	--DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO` where mes_decomision_dt=vmes_comision_dt;
	DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO` where mes_factura_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO`  
	SELECT 		
		mes_factura_dt,
		mes_decomision_dt,
		commission_id,
		id_registro,
		invoice_id,
		estado,
		fecha_calc_dt,
		desde,
		hasta,
		version,
		marca_ds,
		Cliente_id,
		servicio_id,
		detalle_servicio_ds,
		CONCEPTO_DS,
		FECHA_RFB_ID,
		FECHA_VENTA_NETA_ID,
		fecha_rfb_dt,
		fecha_venta_neta_dt,
		canal_alta_ds,
		subcanal_ds,
		tipo_canal_alta_ds,
		nombre_distribuidor_alta_ds,
		agente_alta_id,
		agente_creador_id,
		categoria_servicio_ds,
		cif_nif,
		segmento_ds,
		subsegmento_ds,
		marca_cartera_ds,
		Antiguedad_Cliente,
		equipo_ds,
		territorio_ds,
		clave,
		marco_retributivo_ds,
		flag_marca_cartera,
		grupo_rappel_ds,
		orden_sap,
		importe,
		decomisionable,
		fecha_baja_dt,
		fecha_baja_id,
		motivo_baja_agrup_ds,
		motivo_baja_ds,
		mes_decomision_id,
		desc_mm,
		clase_mm,
  	CAST(NULL AS STRING) AS raiz,
  	CAST(NULL AS STRING) AS hex6,
  	CAST(NULL AS INT64) AS nn	
 	FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`;

		
END