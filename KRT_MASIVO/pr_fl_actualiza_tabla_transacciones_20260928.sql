BEGIN


	
	--CALL `mm-commissions-reporting.KRT_MASIVO.pr_fl_actualiza_tabla_transacciones`(202607);

	DECLARE VCRM, VSEGMENTO_DS STRING;
	DECLARE VMES_FACTURA_DT DATE;
	--- LOCAL 
  --DECLARE VMES_ID INT64 DEFAULT 202607;
	SET VMES_FACTURA_DT= PARSE_DATE('%Y%m',CAST(VMES_ID AS STRING));
	SET VCRM="MYSIM";
	--- PENDIENTE INTEGRAR SEGMENTO EN COMISIONES Y AGG_COMISIONES
	SET VSEGMENTO_DS="RESIDENCIAL";


	--- PASO 1: CREO TABLA INTERMEDIA
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO` AS 	
	SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` WHERE 1=0;


	--- PASO 2: INSERTO REGISTROS EN TABLA INTERMEDIA

	INSERT `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO`
	(
		commission_id,
		estado,
		mes_factura_dt,
		agrupacion_canal,
		concepto,
		tipo_concepto,
		comision,
		distribuidor,
		sfid_id,
		seller,
		marca,
		service_type,
		phone_nm,
		tariff_id,
		tariff_ds,
		service_id,
		customer_id,
		sale_date,
		activation_date,
		deactivation_date,
		order_type_agg,
		cod_segmento,
		cod_marca,
		id_registro,
		invoice_id,
		sociedad,
		bp,
		segmento,
		orden,
		clase_concepto,
		concepto_ds_gekt,
		operation,
		canal_gekt,
		subcanal_gekt,
		marco,
		distribuidor_gekt,
		clase,
		tipo,
		data_source_ds
	)
	  --DECLARE VMES_ID INT64 DEFAULT 202607;DECLARE VMES_FACTURA_DT DATE DEFAULT "2026-07-01";DECLARE VCRM DEFAULT 202607;
		
	select distinct 	
		commission_id,
		'calculado',
		mes_factura_dt,
		"PENDIENTE",
		concepto,
		`mm-commissions-reporting.KRT_SAP.f_trans_crea_tipo_concepto`(concepto),
		importe,
		distribuidor,
		sfid_id,
		seller,
		brand_ds,
		service_type,
		phone_nm,
		tariff_id,
		tariff_ds,
		service_id,
		customer_id,
		EXTRACT(DATE FROM sale_date),
		EXTRACT(DATE FROM activation_date),
		deactivation_date,
		order_type_agg,
		CAST(NULL AS STRING),
		CAST(NULL AS STRING),
		id_registro,
		invoice_id,
		`mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(UPPER(TRIM(brand_ds))),
		LPAD(CAST(ac.bp AS STRING),5,'0'), -- CAST(NULL AS STRING),
		segment_ds,
		orden,
		CAST(NULL AS STRING),
		concepto_marco,
		operacion,
		channel_ds,
		subchannel_ds,
		marco,
		distribuidor,
		clase,
		--coalesce(tipo, case when contains_substr(marco,"-CR") then "CARTERA"  when contains_substr(marco,"-CR") then "CAPTACION"end ),
		tipo,
		data_source_ds,

	from  `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` h 
	--from  `mm-commissions-reporting.KRT_MASIVO.COMISIONES` h 
	left join `mm-commissions-reporting.GS.PARAM_KRT_SAP_ACREEDORES` ac on ac.marca=h.brand_ds and ac.nombre_acreedor =h.distribuidor
	--where MES_ID=VMES_ID
	-- INCLUIR CUANDO TENGA HISTORICO
	where mes_factura_dt=VMES_FACTURA_DT
	---FIN 
	and comisiona=1;

	--- PASO 4: ACTUALIZO TABLA TRANSACCIONES
	
	DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` where mes_factura_dt=VMES_FACTURA_DT and data_source_ds=VCRM;	
	INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`  SELECT * FROM `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO`;
		
END