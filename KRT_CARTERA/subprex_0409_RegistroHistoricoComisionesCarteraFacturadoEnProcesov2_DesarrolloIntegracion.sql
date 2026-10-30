BEGIN
	
	--- PASO 1: CREO TABLAS HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO Y HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO
		
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO` AS 
--	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_comisiones_en_proceso`(vdesde, vhasta);
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_comisiones_listado_en_proceso`(vdesde, vhasta);

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO`AS 
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_decomisiones_en_proceso`(vdesde, vhasta);


	--- PASO 2: ACTUALIZO TABLAS HISTORICO_COMISIONES_CARTERA_FACTURADO y HISTORICO_DECOMISIONES_CARTERA_FACTURADO
	--DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` where mes_comision_dt=vmes_comision_dt and version=vversion;
	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` where mes_factura_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)) 
	--and version=CAST((SELECT `mm-commissions-reporting.KRT_CARTERA.getVersion_fecha_id`(vdesde) as vversion) as INT64)
	;
		
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO`  
	SELECT 
		mes_factura_dt,
		commission_id,
		id_registro,
		invoice_id,
		estado,
		fecha_calc_dt,
		mes_comision_dt,
		mes_comision_id,
		desde,
		hasta,
		version,
		marca_ds,
		IdCatalogo,
		NombreProducto,
		nombre_distribuidor,
		CAST(NULL AS STRING) equipo,
		Canal,
		subcanal,
		agente,
		IdFijo,
		Antiguedad,
		DNI_CIF,
		Marca_Cartera,
		Fecha_Activacion,
		Fecha_Creacion,
		Segmento,
		Subsegmento,
		idCatalogoOrigen,
		IdProductoOrigen,
		NombreProductoOrigen,
		TipoMovimiento,
		IdProducto,
		Contrato,
		UsuarioCreador,
		agente_creador_id,
		concepto_ds,
		concepto_origen_ds,
		medio_conocimiento,
		ClaseProducto,
		TipoProducto,
		clave_mr,
		MARCO_RETRIBUTIVO,
		tvt_ups_virgin,
		televenta,
		nivel,
		campana_id,
		nombre_campana,
		decomisionable,
		decom_bono_extra,
		orden_sap,
		concepto_lista,
		importe,
		desc_mm,
		clase_mm,
	
	FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO`;

	--DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO` where mes_decomision_dt=vmes_comision_dt;
	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO` where mes_factura_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));	
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO`;
		
END