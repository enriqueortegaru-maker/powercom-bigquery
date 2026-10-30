BEGIN


	-- VALOR PARAMETRO VTIPO
	--	"TOTAL": 			Actualizacion Captacion + Cartera
	--	"CAPTACION": 	Actualizacion Captacion
	--	"CARTERA":		Actualizacion Cartera


	--CALL`mm-commissions-reporting.KRT_SAP.subproc_0110_ActualizarTablaTransaccionesv3`(20260901, "TOTAL")

	DECLARE VHASTA, VMES_ID, VHOY_ID INT64;
	DECLARE VMES_FACTURA_DT DATE;
	--DECLARE VDESDE INT64; DECLARE VTIPO STRING; SET VDESDE=20260701;SET VTIPO="TOTAL";
	SET VMES_FACTURA_DT= PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING));
	SET VHASTA=CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(PARSE_DATE("%Y%m%d",CAST(VHASTA AS STRING)))) AS INT64);
	SET VMES_ID=CAST(CAST(FORMAT_DATE("%Y%m", VMES_FACTURA_DT) AS STRING) AS INT64);
	SET VHOY_ID=CAST(CAST(FORMAT_DATE("%Y%m%d", CURRENT_DATE('Europe/Madrid')) AS STRING) AS INT64);

	IF contains_substr(VTIPO,"Total") OR contains_substr(VTIPO,"Captacion")  OR contains_substr(VTIPO,"Cartera") THEN



		--- PASO 1: CREO TABLA INTERMEDIA

		IF contains_substr(VTIPO,"Total") THEN
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` AS
				SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` WHERE 1=0;
			ELSEIF contains_substr(VTIPO,"Captacion") THEN
				--- REGISTRO EN TRANSACCIONES_EN_PROCESO LAS COMISIONES PROPIAS DE CARTERA
				---		TIPO CARTERA
				---		CRM  NO MYSIM
				---		SEGMENTO NO BUSINESS (AQUEL NO INFORMADO SE CONSIDERA RESIDENCIAL)

				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` AS
				SELECT * 
				FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` 
				WHERE mes_factura_dt=VMES_FACTURA_DT 
				and tipo="CARTERA"  
				and not contains_substr(coalesce(NULLIF(UPPER(TRIM(segmento)), ''),"RESIDENCIAL"),"BUSINESS") 
				and not contains_substr(data_source_ds,"MYSIM");

			ELSEIF contains_substr(VTIPO,"Cartera") THEN

				--- REGISTRO EN TRANSACCIONES_EN_PROCESO LAS COMISIONES PROPIAS DE CAPTACION
				---		TIPO CARTERA
				---		CRM  NO MYSIM
				---		SEGMENTO NO BUSINESS (AQUEL NO INFORMADO SE CONSIDERA RESIDENCIAL)

				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` AS
				SELECT * 
				FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` 
				WHERE mes_factura_dt=VMES_FACTURA_DT 
				and tipo="CAPTACION"  
				and not contains_substr(coalesce(NULLIF(UPPER(TRIM(segmento)), ''),"RESIDENCIAL"),"BUSINESS") 
				and not contains_substr(data_source_ds,"MYSIM");

		END IF;


		--- PASO 2: INSERTO REGISTROS DE CAPTACION EN TABLA INTERMEDIA
		IF contains_substr(VTIPO,"Total") OR contains_substr(VTIPO,"Captacion") THEN


			--- PASO 2.1: INSERTO COMISIONES
			INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
			(

				mes_factura_dt,
				mes_liquidado,
				commission_id,
				id_registro,
				invoice_id,
				estado,
				marca,
				customer_id,
				service_id,
				concepto_ds_gekt,
				tariff_ds,
				tipo_concepto,
				activation_date,
				sale_date,
				canal_gekt,
				subcanal,
				distribuidor,
				razon_social,
				seller,
				customer_dni,
				segmento,
				tariff_id,
				concepto,
				clase_concepto,
				order_id,
				account_id,
				bundle_type,
				marco,
				orden,
				comision,
				id_mes,
				sfid_id,
				agrupacion_canal,
				canal,
				subcanal_gekt,
				nombre_comercio,
				service_type,
				technology_ds,
				order_type_agg,
				bp,
				id_comisionista,
				cif,
				cod_marca,
				cod_segmento,
				sociedad,
				deactivation_date,
				unidades,
				zona_fiscal,
				billing_type_ds,
				operation,
				distribuidor_gekt,
				categoria_servicio_ds,
				clase,
				tipo,
				concepto_factura_ds,
				data_source_ds
			)

			select
				mes_factura_dt,
				--mes_comision_dt,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_rfb_dt),
				commission_id,
				id_registro,
				invoice_id,
				estado,
				marca_ds,
				CAST(Cliente_id AS STRING),
				CAST(servicio_id AS STRING),
				CAST(concepto_ds AS STRING),
				detalle_servicio_ds,
				`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds,clase_mm, desc_mm, concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap), segmento_ds, desc_mm,"",""),
				EXTRACT(DATE FROM fecha_rfb_dt),
				EXTRACT(DATE FROM fecha_venta_neta_dt),
				canal_alta_ds,
				subcanal_ds,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
				agente_alta_id,
				cif_nif,
				--coalesce(UPPER(TRIM(segmento_ds)),"RESIDENCIAL"),
				COALESCE(NULLIF(UPPER(TRIM(segmento_ds)), ''), 'RESIDENCIAL'),
				catalogo_id,
				desc_mm,
				clase_mm,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_id`(marca_ds, pedido),
				-----------------------------------
				-- MODIFICACION 20250702
				-- 	ELIMINO
				-- 	CAST(contrato_id AS STRING)
				--	AÑADO
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_account_id`(marca_ds, CAST(contrato_id AS STRING)),
				---
				---	FIN MODIFICACION
				-----------------------------------
				cat_plays_p,
				marco_Retributivo_ds,
				orden_sap,
				importe,
				------------------------------------
				-- MODIFICACION 20250910
				-- 	ELIMINO
				--  mes_comision_id,
				--	AÑADO
				CAST(FORMAT_DATE('%Y%m',mes_factura_dt) as INT64),
				---
				---	FIN MODIFICACION
				------------------------------------
				--`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id`(marca_ds, equipo_ds, agente_Alta_id),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id_v1`(marca_ds, categoria_servicio_ds, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo_ds, canal_alta_ds, subcanal_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_canal`(marco_retributivo_ds, canal_alta_ds, subcanal_ds),
				subcanal_ds,
				--`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comercio`(marca_ds, canal_alta_ds, equipo_ds,agente_Alta_id),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comerciov2`(marca_ds, canal_alta_ds, equipo_ds,agente_Alta_id, categoria_servicio_ds, canalizacion.EquipoDesc, canalizacion.AgenteComercial),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_service_type`(categoria_servicio_ds, detalle_servicio_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_technology`(categoria_servicio_ds, tecnologia_detalle_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_type_agg`(portabilidad_in_lg),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_marca`(marca_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_segmento`(segmento_ds),
				`mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_deactivation_date`(),
				1,
				'PEN',
				'POSTPAID',
				'ALTA',
				nombre_distribuidor_alta_ds,
				--categoria_servicio_ds,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_categoria_servicio`(categoria_servicio_ds, tecnologia_detalle_ds),
				'COMISION',
				'CAPTACION',
				`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds,clase_mm, desc_mm, concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap), segmento_ds, desc_mm,"",""),
				`mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, categoria_servicio_ds)
			from `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_DETALLADO`
			--from `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO`
			where mes_factura_dt=vmes_factura_dt
			--AÑADIDO
			and version=(SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerVersionDeFlujoVigenteEnMes`(PARSE_DATE('%Y%m%d',CAST(vdesde as STRING))));
			--FIN AÑADIDO


			--- PASO 2.2: INSERTO DECOMISIONES

			INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
			(
				mes_factura_dt,
				mes_liquidado,
				commission_id,
				id_registro,
				invoice_id,
				estado,
				marca,
				customer_id,
				service_id,
				concepto_ds_gekt,
				tariff_ds,
				tipo_concepto,
				activation_date,
				sale_date,
				canal,
				subcanal,
				canal_gekt,
				subcanal_gekt,
				distribuidor,
				razon_social,
				seller,
				customer_dni,
				segmento,
				marco,
				orden,
				comision,
				deactivation_date,
				causa_baja_agrup,
				causa_baja,
				id_mes,
				concepto,
				clase_concepto,
				sfid_id,
				agrupacion_canal,
				nombre_comercio,
				service_type,
				--technology_ds,
				--order_type_agg,
				bp,
				id_comisionista,
				cif,
				cod_marca,
				cod_segmento,
				sociedad,
				unidades,
				zona_fiscal,
				billing_type_ds,
				operation,
				distribuidor_gekt,
				categoria_servicio_ds,
				clase,
				tipo,
				concepto_factura_ds,
				data_source_ds

			)

			select
				mes_factura_dt,
				--mes_decomision_dt,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_baja_dt),
				commission_id,
				id_registro,
				invoice_id,
				estado,
				marca_ds,
				CAST(Cliente_id AS STRING),
				CAST(servicio_id AS STRING),
				CAST(concepto_ds AS STRING),
				detalle_servicio_ds,
				`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap), segmento_ds, desc_mm,"","") ,
				EXTRACT(DATE FROM fecha_rfb_dt),
				EXTRACT(DATE FROM fecha_venta_neta_dt),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_canal`(marco_retributivo_ds, canal_alta_ds, subcanal_ds),
				subcanal_ds,
				canal_alta_ds,
				subcanal_ds,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
				agente_alta_id,
				cif_nif,
				COALESCE(NULLIF(UPPER(TRIM(segmento_ds)), ''), 'RESIDENCIAL'),
				--coalesce(UPPER(TRIM(segmento_ds)),"RESIDENCIAL"),
				marco_retributivo_ds,
				orden_sap,
				importe,
				EXTRACT(DATE FROM fecha_baja_dt),
				motivo_baja_agrup_ds,
				motivo_baja_ds,
				------------------------------------

				-- MODIFICACION 20250910
				-- 	ELIMINO
				--  mes_decomision_id,
				--	AÑADO
				CAST(FORMAT_DATE('%Y%m',mes_factura_dt) as INT64),
				---
				---	FIN MODIFICACION
				------------------------------------
				desc_mm,
				clase_mm,
				--`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id`(marca_ds, equipo_ds, agente_Alta_id),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id_v1`(marca_ds, categoria_servicio_ds, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo_ds, canal_alta_ds, subcanal_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comerciov2`(marca_ds, canal_alta_ds, equipo_ds,agente_Alta_id, categoria_servicio_ds, canalizacion.EquipoDesc, canalizacion.AgenteComercial),
				-- `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comercio`(marca_ds,canal_alta_ds, equipo_ds,agente_Alta_id),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_service_type`(categoria_servicio_ds, detalle_servicio_ds),
				--`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_technology`(categoria_servicio_ds, tecnologia_detalle_ds),
				--`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_type_agg`(portabilidad_in_lg),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_marca`(marca_ds),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_segmento`(segmento_ds),
				`mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
				1,
				'PEN',
				'POSTPAID',
				'BAJA',
				nombre_distribuidor_alta_ds,
				categoria_servicio_ds,
				'DECOMISION',
				'CAPTACION',
				`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap), segmento_ds, desc_mm,"","") ,
				`mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, categoria_servicio_ds)

				from `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_DETALLADO`
				--from `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO`
				where mes_factura_dt=vmes_factura_dt
				--AÑADIDO
				and version=(SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerVersionDeFlujoVigenteEnMes`(PARSE_DATE('%Y%m%d',CAST(vdesde as STRING))));
				--FIN AÑADIDO


		END IF;


		--- PASO 3: INSERTO REGISTROS DE CARTERA EN TABLA INTERMEDIA
		IF contains_substr(VTIPO,"Total") OR contains_substr(VTIPO,"Cartera") THEN

			--- PASO 3.1: INSERTO COMISIONES
			INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
			(

				mes_factura_dt,
				commission_id,
				id_registro,
				invoice_id,
				estado,
				mes_liquidado,
				id_mes,
				marca,
				order_id,
				account_id,
				tariff_id,
				tariff_ds,
				distribuidor,
				razon_social,
				canal_gekt,
				subcanal,
				seller,
				customer_id,
				customer_dni,
				activation_date,
				segmento,
				tariff_id_origin,
				service_id_origin,
				tariff_ds_origin,
				operation_type,
				service_id,
				concepto_ds_gekt,
				concepto_lista_ds_gekt,
				concepto_origen_ds_gekt,
				marco,
				campaign_code,
				orden,
				tipo_concepto,
				comision,
				concepto,
				clase_concepto,
				sfid_id,
				agrupacion_canal,
				canal,
				subcanal_gekt,
				nombre_comercio,
				service_type,
				order_type_agg,
				bp,
				id_comisionista,
				cif,
				cod_marca,
				cod_segmento,
				sociedad,
				deactivation_date,
				unidades,
				zona_fiscal,
				billing_type_ds,
				operation,
				distribuidor_gekt,
				categoria_servicio_ds,
				clase,
				tipo,
				concepto_factura_ds,
				data_source_ds
			)


			select

				mes_factura_dt,
				commission_id,
				id_registro,
				invoice_id,
				estado,
				--mes_comision_dt,
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_Activacion,desc_mm),
				------------------------------------
				-- MODIFICACION 20250910
				-- 	ELIMINO
				--  mes_comision_id,
				--	AÑADO
				CAST(FORMAT_DATE('%Y%m',`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_Activacion,desc_mm)) as INT64),
				---
				---	FIN MODIFICACION
				------------------------------------
				marca_ds,
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_id`(marca_ds, claseProducto, contrato),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_account_id`(marca_ds, claseProducto, contrato),
				IdCatalogo,
				NombreProducto,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
				Canal,
				subcanal,
				agente,
				CAST(IdFijo AS STRING),
				DNI_CIF,
				Fecha_Activacion,
				--coalesce(UPPER(TRIM(Segmento)),"RESIDENCIAL"),
				COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'),
				CAST(idCatalogoOrigen AS STRING),
				CAST(IdProductoOrigen AS STRING),
				NombreProductoOrigen,
				tipoMovimiento,
				CAST(IdProducto AS STRING),
				concepto_ds,
				concepto_lista,
				concepto_origen_ds,
				MARCO_RETRIBUTIVO,
				coalesce(nombre_Campana,campana_id),
				orden_sap,
				`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CARTERA", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(nombreProducto, clase_mm, desc_mm, concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap), segmento, desc_mm, tipoMovimiento,""),
				importe,
				desc_mm,
				clase_mm,
				--`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id`(marca_ds, agente,usuarioCreador),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id_v1`(marca_ds, tipoProducto, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo, canal, subcanal),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_canal`(marco_retributivo, canal, subcanal),
				subcanal,
				--`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comercio`(marca_ds, canal, agente),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comerciov2`(marca_ds, canal, agente, ClaseProducto, canalizacion.equipoDesc, canalizacion.agenteComercial),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_service_type`(TipoProducto),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_type_agg`(TipoMovimiento,''),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_marca`(marca_ds),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_segmento`(segmento),
				`mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_deactivation_date`(),
				1,
				'PEN',
				'POSTPAID',
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_operacion`(TipoMovimiento),
				nombre_distribuidor,
				--TipoProducto,
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_categoria_servicio`(ClaseProducto,TipoProducto),
				'COMISION',
				'CARTERA',
				`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CARTERA", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(nombreProducto, clase_mm, desc_mm, concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap), segmento, desc_mm, tipoMovimiento,""),
				`mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, tipoProducto)


			from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO`
			--from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO`
			where mes_factura_dt=vmes_factura_dt
			--AÑADIDO
			And version=(SELECT `mm-commissions-reporting.KRT_CARTERA.f_obtenerVersionDeFlujoVigenteEnMes`(PARSE_DATE('%Y%m%d',CAST(vdesde as STRING))));
			--FIN AÑADIDO



			--- PASO 3.2: INSERTO DECOMISIONES

			INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
			(
				mes_factura_dt,
				mes_liquidado,
				id_mes,
				commission_id,
				id_registro,
				invoice_id,
				estado,
				marca,
				order_id,
				account_id,
				tariff_id,
				tariff_ds,
				distribuidor,
				razon_social,
				canal_gekt,
				subcanal,
				seller,
				customer_id,
				customer_dni,
				activation_date,
				segmento,
				tariff_id_origin,
				service_id_origin,
				tariff_ds_origin,
				operation_type,
				service_id,
				concepto_ds_gekt,
				concepto_origen_ds_gekt,
				marco,
				comision,
				campaign_code,
				causa_baja,
				causa_baja_agrup,
				concepto,
				clase_concepto,
				orden,
				sfid_id,
				agrupacion_canal,
				canal,
				subcanal_gekt,
				nombre_comercio,
				service_type,
				order_type_agg,
				bp,
				id_comisionista,
				cif,
				cod_marca,
				cod_segmento,
				sociedad,
				unidades,
				zona_fiscal,
				billing_type_ds,
				operation,
				distribuidor_gekt,
				categoria_servicio_ds,
				clase,
				tipo,
				data_source_ds

			)


			select

				mes_factura_dt,
				--mes_decomision_dt,
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fechaDesinstalacion, desc_mm),
				------------------------------------
				-- MODIFICACION 20250910
				-- 	ELIMINO
				--  mes_decomision_id,
				--	AÑADO
				CAST(FORMAT_DATE('%Y%m',`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fechaDesinstalacion, desc_mm)) as INT64),
				---
				---	FIN MODIFICACION
				------------------------------------
				commission_id,
				id_registro,
				invoice_id,
				estado,
				marca_ds,
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_id`(marca_ds, claseProducto, contrato),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_account_id`(marca_ds, claseProducto, contrato),
				IdCatalogo,
				NombreProducto,
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
				Canal,
				subcanal,
				agente,
				CAST(IdFijo AS STRING),
				DNI_CIF,
				Fecha_Activacion,
				--coalesce(UPPER(TRIM(Segmento)),"RESIDENCIAL"),
				COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'),
				idCatalogoOrigen,
				CAST(IdProductoOrigen AS STRING),
				NombreProductoOrigen,
				TipoMovimiento,
				CAST(IdProducto AS STRING),
				concepto_ds,
				concepto_origen_ds,
				MARCO_RETRIBUTIVO,
				total,
				campana_id,
				CausaBaja,
				CausaBajaGeneral,
				desc_mm,
				clase_mm,
				orden_sap,
				--`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id`(marca_ds, agente,usuarioCreador),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id_v1`(marca_ds, tipoProducto, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo, canal, subcanal),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_canal`(marco_retributivo, canal, subcanal),
				subcanal,
				--`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comercio`(marca_ds, canal, agente),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comerciov2`(marca_ds, canal, agente, ClaseProducto, canalizacion.equipoDesc, canalizacion.agenteComercial),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_service_type`(TipoProducto),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_type_agg`(TipoMovimiento,causaBaja),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_marca`(marca_ds),
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_segmento`(segmento),
				`mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
				1,
				'PEN',
				'POSTPAID',
				--`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_operacion`(TipoMovimiento),
				'BAJA',
				nombre_distribuidor,
				--TipoProducto,
				`mm-commissions-reporting.KRT_CARTERA.f_trans_crea_categoria_servicio`(ClaseProducto,TipoProducto),
				'DECOMISION',
				'CARTERA',
				`mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, tipoProducto)

			from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO`
			--from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO`
			where mes_factura_dt=vmes_factura_dt
			--AÑADIDO
			And version=(SELECT `mm-commissions-reporting.KRT_CARTERA.f_obtenerVersionDeFlujoVigenteEnMes`(PARSE_DATE('%Y%m%d',CAST(vdesde as STRING))));
			--FIN AÑADIDO

		END IF;

		
		--- PASO 4: ACTUALIZO TABLA TRANSACCIONES
		

		/*
		DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` 
		where mes_factura_dt=VMES_FACTURA_DT 
		and TRIM(UPPER(data_source_ds)) in ("EKTNET","TCNET","R") 
		and not contains_substr(coalesce(segmento,"RESIDENCIAL"),"BUSINESS");
		
		INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`  
		SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`;
		*/




		--- PASO 4: ACTUALIZO TABLA TRANSACCIONES

		--- PASO 4.1: CAPTACION
		DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
		WHERE t.mes_factura_dt = VMES_FACTURA_DT
			AND contains_substr(t.tipo,"CAPTACION")
			AND t.data_source_ds in ('EKTNET','R','TCNET')
			--- EL SEGMENTO NO ES BUSINESS
			AND NOT contains_substr(coalesce(NULLIF(UPPER(TRIM(segmento)), ''),"RESIDENCIAL"),"BUSINESS")
			--- Y NO SE CUMPLE LA CONDICION 
			AND NOT EXISTS (
				---- MES DE PUBLICACION ESTA INFORMADA
				---- FECHA DE DATOS ESTA INFORMADA
				---- FECHA DE DATOS ES DISTINTA DE HOY
				SELECT 1
				FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` p
				WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
					AND p.mes_comision_id       = VMES_ID
					AND p.fecha_id IS NOT NULL
					AND p.fecha_id <> VHOY_ID
			);


		INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
		--- DECLARE VMES_ID INT64 DEFAULT 202609; DECLARE VHOY_ID INT64 DEFAULT 20261002;
		SELECT e.*
		--SELECT sum(e.comision)
		FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` e
		WHERE contains_substr(e.tipo,"CAPTACION") 
		--AND clase="COMISION"
		--AND marca="TELECABLE"
		AND e.data_source_ds in ('EKTNET','R','TCNET')
		AND NOT EXISTS (
				SELECT 1
				FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p
				WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
					AND p.mes_comision_id       = VMES_ID
					AND p.fecha_id IS NOT NULL
					AND p.fecha_id <> VHOY_ID
			);




		--- PASO 4.2: CARTERA

		DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
		WHERE t.mes_factura_dt = VMES_FACTURA_DT
			AND contains_substr(t.tipo,"CARTERA")
			AND t.data_source_ds in ('EKTNET','R','TCNET')
			AND NOT contains_substr(coalesce(NULLIF(UPPER(TRIM(segmento)), ''),"RESIDENCIAL"),"BUSINESS")			
			AND NOT EXISTS (
				SELECT 1
				FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` p
				WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
					AND p.mes_comision_id       = VMES_ID
					AND p.fecha_id IS NOT NULL
					AND p.fecha_id < VHOY_ID
			);



		INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
		--- DECLARE VMES_ID INT64 DEFAULT 202609; DECLARE VHOY_ID INT64 DEFAULT 20261002;
		SELECT e.*
		--SELECT sum(e.comision)
		FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` e
		WHERE contains_substr(e.tipo,"CARTERA") 
		AND e.data_source_ds in ('EKTNET','R','TCNET')
		AND NOT EXISTS (
				SELECT 1
				FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p
				WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
					AND p.mes_comision_id       = VMES_ID
					AND p.fecha_id IS NOT NULL
					AND p.fecha_id < VHOY_ID
			);

		


	END IF;

END