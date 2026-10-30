BEGIN


	
	--CALL `mm-commissions-reporting.KRT_PYME.pr_fl_actualiza_tabla_transacciones`(202610);

	DECLARE VSEGMENTO_DS STRING;
	DECLARE VMES_FACTURA_DT DATE;
		DECLARE VHOY_ID INT64;
	--- LOCAL 
  --DECLARE VMES_ID DEFAULT 202610;
	SET VSEGMENTO_DS="BUSINESS";
	SET VMES_FACTURA_DT= PARSE_DATE('%Y%m',CAST(VMES_ID AS STRING));
	SET VHOY_ID = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE()) AS INT64);	
	


	--- PASO 1: CREO TABLA INTERMEDIA
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_PYME.TRANSACCIONES_EN_PROCESO` AS 	
	SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` WHERE 1=0;


	--- PASO 2: INSERTO REGISTROS EN TABLA INTERMEDIA

	INSERT `mm-commissions-reporting.KRT_PYME.TRANSACCIONES_EN_PROCESO`
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
		--`mm-commissions-reporting.KRT_SAP.f_trans_crea_tipo_concepto`(concepto),
		`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
						h.tipo, 
						left(h.concepto,1), -- `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds,clase_mm, desc_mm, concepto_ds),
						`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(h.orden), 
						VSEGMENTO_DS, 
						concepto,
						service_type,
						g.DETALLE
					),



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
		VSEGMENTO_DS,
		h.orden,
		CAST(NULL AS STRING),
		concepto_marco,
		operacion,
		channel_ds,
		subchannel_ds,
		marco,
		distribuidor,
		clase,
		coalesce(h.tipo, case when contains_substr(marco,"-CR") then "CARTERA"  when contains_substr(marco,"-CR") then "CAPTACION"end ),
		data_source_ds,

	from  `mm-commissions-reporting.KRT_PYME.HISTORICO_TOTAL` h 
	left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca=h.brand_ds and ac.nombre_acreedor =h.distribuidor
  left join (

        SELECT tk                 AS tipo,
              UPPER(TRIM(p.MARCA)) AS marca,
              p.ORDEN,
              p.DETALLE
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS` p
        CROSS JOIN UNNEST((
          SELECT ARRAY_AGG(DISTINCT UPPER(TRIM(TIPO)) IGNORE NULLS)
          FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
        )) AS tk
        WHERE p.ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
          AND UPPER(TRIM(p.SEGMENTO)) IN ('PYME P', 'PYME M')
        QUALIFY ROW_NUMBER() OVER (
          PARTITION BY tk, UPPER(TRIM(p.MARCA)), p.ORDEN
          ORDER BY IF(UPPER(TRIM(p.TIPO)) = tk, 0, 1),                                  
                  CASE p.ESTADO WHEN 'ACTIVO' THEN 1 WHEN 'PUBLICADA' THEN 2 ELSE 3 END,
                  p.CANAL, p.DETALLE
        ) = 1
				
  ) g 
  ON UPPER(TRIM(g.tipo))=h.tipo
  AND UPPER(TRIM(g.MARCA))=UPPER(TRIM(h.brand_ds))
  AND g.ORDEN=h.orden
  --AND g.rn=1
	where mes_factura_dt=VMES_FACTURA_DT
	and comisiona=1;


	--- PASO 4: ACTUALIZO TABLA TRANSACCIONES
	
	/* DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` where mes_factura_dt=VMES_FACTURA_DT and COALESCE(segmento,"NODEF")=VSEGMENTO_DS;	
		 INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`  SELECT * FROM `mm-commissions-reporting.KRT_PYME.TRANSACCIONES_EN_PROCESO`;
	*/


	--- PASO 4: ACTUALIZO TABLA TRANSACCIONES
	DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
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


	INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
	SELECT e.*
	FROM `mm-commissions-reporting.KRT_PYME.TRANSACCIONES_EN_PROCESO` e
	WHERE NOT EXISTS (
	    SELECT 1
	    FROM `mm-commissions-reporting.KRT_PYME.PARAM_KRT_PYME_PUBLICACION` p
	    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
	      AND p.mes_comision_id       = VMES_ID
	      AND p.fecha_id IS NOT NULL
				AND p.fecha_id < VHOY_ID				
	  );

		
END