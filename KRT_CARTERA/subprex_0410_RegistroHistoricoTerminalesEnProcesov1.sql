BEGIN
	
	--- PASO 1: CREO TABLAS HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO Y HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO
	-- LOCAL: DECLARE VDESDE, VHASTA, VVERSION INT64; SET VDESDE=20250101;SET VHASTA=20250131;SET VVERSION=16;	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_EN_PROCESO` AS 
--	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_comisiones_en_proceso`(vdesde, vhasta);
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_ventas_terminales_en_proceso`(vdesde, vhasta,vversion);
	--SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_ventas_terminales_en_proceso`(vdesde,vhasta);

	--- PASO 2: ACTUALIZO TABLAS HISTORICO_COMISIONES_CARTERA_FACTURADO y HISTORICO_DECOMISIONES_CARTERA_FACTURADO
	--DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` where mes_comision_dt=vmes_comision_dt and version=vversion;
	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES` where mes_activacion_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)) 
	--and version=CAST((SELECT `mm-commissions-reporting.KRT_CARTERA.getVersion_fecha_id`(vdesde) as vversion) as INT64)
	;
	
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES`  
	SELECT 
	--* except(equipo) 
		mes_venta_dt,
		mes_activacion_dt,
		fecha_calc_dt,
		desde,
		hasta,
		version,
		marca_ds,
		IdCatalogo,
		NombreProducto,
		nombre_distribuidor,
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
		marcaModelo,
		marca,
		modelo,
	FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_EN_PROCESO`;
		
END