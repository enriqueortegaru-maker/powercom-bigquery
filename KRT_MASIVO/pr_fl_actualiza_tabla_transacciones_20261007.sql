BEGIN

--CALL `mm-commissions-reporting.KRT_MASIVO.pr_fl_actualiza_tabla_transacciones`(202608);

	DECLARE VCRM, VSEGMENTO_DS STRING;
	DECLARE VMES_FACTURA_DT DATE;
	DECLARE VHOY_ID INT64;
  --DECLARE VMES_ID INT64 DEFAULT 202608;

	SET VMES_FACTURA_DT = PARSE_DATE('%Y%m', CAST(VMES_ID AS STRING));
	SET VCRM = "MYSIM";
	SET VSEGMENTO_DS = "RESIDENCIAL";
	SET VHOY_ID = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE()) AS INT64);


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
	SELECT DISTINCT 	
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
		LPAD(CAST(ac.bp AS STRING),5,'0'),
		coalesce(IFNULL(segment_ds,''),'RESIDENCIAL'),
		orden,
		CAST(NULL AS STRING),
		concepto_marco,
		operacion,
		channel_ds,
		subchannel_ds,
		marco,
		distribuidor,
		clase,
		tipo,
		data_source_ds
	FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` h 
	LEFT JOIN `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac 
		ON ac.marca = h.brand_ds 
	   AND ac.nombre_acreedor = h.distribuidor
	WHERE mes_factura_dt = VMES_FACTURA_DT
	  AND comisiona = 1;


	--- PASO 4: ACTUALIZO TABLA TRANSACCIONES
	DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
	WHERE t.mes_factura_dt = VMES_FACTURA_DT
	  AND t.data_source_ds = VCRM
	  AND NOT EXISTS (
	    SELECT 1
	    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_PUBLICACION` p
	    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
	      AND UPPER(TRIM(p.tipo))     = UPPER(TRIM(t.tipo))
	      AND p.mes_comision_id       = VMES_ID
	      AND p.fecha_id IS NOT NULL
	      AND p.fecha_id < VHOY_ID				

	  );

	INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
	SELECT e.*
	FROM `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO` e
	WHERE NOT EXISTS (
	    SELECT 1
	    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_PUBLICACION` p
	    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
	      AND UPPER(TRIM(p.tipo))     = UPPER(TRIM(e.tipo))
	      AND p.mes_comision_id       = VMES_ID
	      AND p.fecha_id IS NOT NULL
	      AND p.fecha_id < VHOY_ID
	  );


END