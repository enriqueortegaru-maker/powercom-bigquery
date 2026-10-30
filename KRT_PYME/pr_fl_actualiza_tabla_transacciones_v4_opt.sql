BEGIN

	--CALL `mm-commissions-reporting.KRT_PYME.pr_fl_actualiza_tabla_transacciones_v4_opt`(202610);

	DECLARE VSEGMENTO_DS STRING;
	DECLARE VMES_FACTURA_DT DATE;
	DECLARE VHOY_ID INT64;
	SET VSEGMENTO_DS="BUSINESS";
	SET VMES_FACTURA_DT= PARSE_DATE('%Y%m',CAST(VMES_ID AS STRING));
	SET VHOY_ID = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE()) AS INT64);


	--- PASO 1: CREO TABLA INTERMEDIA
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_PYME_V4` AS
	SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V4` WHERE 1=0;


	--- PASO 2: INSERTO REGISTROS EN TABLA INTERMEDIA
	INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_PYME_V4`
	(commission_id,
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
	select
		commission_id,
		estado,
		mes_factura_dt,
		"KRT - Capt Task Force Pyme",
		concepto,
		CAST(NULL AS STRING),	-- tipo_concepto [v4]: CODIGO SAP, se resuelve en PASO 3 (fix A/D)
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
		VSEGMENTO_DS,
		h.orden,
		-- clase_concepto [v4]: descriptor SAP (fix A/D), argumentos alineados con f_vt (fix B)
		`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
			h.tipo_v4,
			`mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(tariff_ds, CAST(NULL AS STRING), concepto, concepto_marco),
			`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(h.orden),
			VSEGMENTO_DS,
			concepto,
			IF(h.tipo_v4 = 'CARTERA', CAST(NULL AS STRING), ''),
			g.DETALLE
		),
		concepto_marco,
		operacion,
		channel_ds,
		subchannel_ds,
		marco,
		distribuidor,
		clase,
		h.tipo_v4,
		data_source_ds

	from (
		SELECT h0.*,
		       coalesce(h0.tipo, case when contains_substr(h0.marco,"-CR") then "CARTERA"  when contains_substr(h0.marco,"-CR") then "CAPTACION" end) AS tipo_v4
		FROM `mm-commissions-reporting.KRT_PYME.HISTORICO_TOTAL` h0
	) h
	left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca=h.brand_ds and ac.nombre_acreedor =h.distribuidor
	left join (
		SELECT tipo, marca, orden, CANAL, DETALLE,
		  ROW_NUMBER() OVER (
		    PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
		    ORDER BY CANAL, DETALLE
		  ) AS rn
		FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
		WHERE ESTADO IN ("ACTIVO","PUBLICADA","INACTIVO")
	) g
	  ON UPPER(TRIM(g.tipo))  = UPPER(TRIM(h.tipo_v4))
	 AND UPPER(TRIM(g.MARCA)) = UPPER(TRIM(h.brand_ds))
	 AND g.ORDEN = h.orden
	 AND g.rn = 1
	where mes_factura_dt=VMES_FACTURA_DT
	and comisiona=1;


	--- PASO 3: RESUELVO CODIGO SAP Y COMMISSION_ID  [v4]
	CALL `mm-commissions-reporting.KRT_SAP.subproc_0113_ResolverCodigoSapYCommissionIdv4_opt`('TRANSACCIONES_EN_PROCESO_PYME_V4', VMES_ID * 100 + 1, 'TOTAL', 'P');


	--- PASO 4: ACTUALIZO TABLA TRANSACCIONES
	DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V4` t
	WHERE t.mes_factura_dt = VMES_FACTURA_DT
	  AND t.data_source_ds in ('EKTNET','R','TCNET')
		AND COALESCE(NULLIF(UPPER(TRIM(segmento)), ''),"NODEF")=VSEGMENTO_DS
	  AND NOT EXISTS (
	    SELECT 1
	    FROM `mm-commissions-reporting.KRT_PYME.PARAM_KRT_PYME_PUBLICACION` p
	    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
	      AND p.mes_comision_id       = VMES_ID
	      AND p.fecha_id IS NOT NULL
	      AND p.fecha_id < VHOY_ID
	  );


	INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V4`
	SELECT e.*
	FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_PYME_V4` e
	WHERE NOT EXISTS (
	    SELECT 1
	    FROM `mm-commissions-reporting.KRT_PYME.PARAM_KRT_PYME_PUBLICACION` p
	    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
	      AND p.mes_comision_id       = VMES_ID
	      AND p.fecha_id IS NOT NULL
	      AND p.fecha_id < VHOY_ID
	  );

END