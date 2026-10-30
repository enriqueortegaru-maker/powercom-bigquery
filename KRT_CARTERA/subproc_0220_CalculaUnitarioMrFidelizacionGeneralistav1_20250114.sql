BEGIN

	-----PENDIENTE INTEGRAR GETIO DE VERSION EN CREACION DE TABLA VENTAS_FIDGEN

	-- =======================================================================
	-- Declaración de Parámetros de Ejecución
	-- =======================================================================
	DECLARE v_servicios_principales ARRAY<STRING> DEFAULT ['TERMINALES', 'BANDA ANCHA', 'MOVILES POSTPAGO'];
	DECLARE v_mes_calculo DATE; 
	-- LOCAL
	--DECLARE vdesde INT64; SET vdesde=20251001;
	-- FIN LOCAL
	SET v_mes_calculo=PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING));

	-- MODIFICACIÓN: Se elimina el "CREATE OR REPLACE TABLE ... AS WITH" que englobaba todo.
	-- Ahora cada CTE se materializa en su propia tabla secuencialmente.

	-- =======================================================================
	-- Inicia la Lógica de Cálculo
	-- =======================================================================

	-- -----------------------------------------------------------------------
	-- CTE 0 -> Tabla: VENTAS_FIDGEN
	-- Filtra la tabla de ventas para el mes de cálculo.
	-- Calcula flags para saber si la VENTA o la ACTIVACIÓN ocurrieron en el mes.
	-- -----------------------------------------------------------------------
	-- declare vdesde int64;DECLARE v_mes_calculo DATE; set vdesde=20251001;SET v_mes_calculo=PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING));
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.VENTAS_FIDGEN` AS
	SELECT 
		distinct e.* except(fecha_calc_dt, desde, hasta,version),
		`mm-commissions-reporting.KRT_CARTERA.f_descubre_tipo_servicio`(ClaseProducto, TipoProducto, NombreProducto) as tipo_servicio,    
		-- Flag para ventas *realizadas* en el mes N
		COALESCE( (EXTRACT(YEAR FROM fecha_creacion) = EXTRACT(YEAR FROM v_mes_calculo) AND  EXTRACT(MONTH FROM fecha_creacion) = EXTRACT(MONTH FROM v_mes_calculo)) , FALSE ) AS es_venta_mes_n,
		-- Flag para ventas *activadas* en el mes N
		COALESCE( (EXTRACT(YEAR FROM fecha_activacion) = EXTRACT(YEAR FROM v_mes_calculo) AND     EXTRACT(MONTH FROM fecha_activacion) = EXTRACT(MONTH FROM v_mes_calculo)) , FALSE ) AS es_activacion_mes_n,
	FROM `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_CARTERA` e
    LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` v on v.marca_ds= E.marca_ds and v.mes_comision_id=CAST(FORMAT_DATE("%Y%m",date_trunc(PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)), MONTH)) AS INT64)            	
	--INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p on p.mes_comision_id=SAFE_DIVIDE(vdesde,100) and p.marca_ds=e.marca_ds
	WHERE EXISTS(
              select 1 
              from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
              where r.marca_ds=e.marca_ds
              and r.mes_comision_id = CAST(FORMAT_DATE("%Y%m",date_trunc(PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)), MONTH)) AS INT64)
              --and c.version=CAST((SELECT `mm-commissions-reporting.KRT_CARTERA.getVersion_nmonths`(NMESES) as vversion) as INT64)
        )
        and e.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST(v.fecha_id AS STRING))
        and e.desde=vdesde
		-- Optimización: Solo leer datos relevantes (mes N y mes N-1)
		and DATE_TRUNC(fecha_creacion, MONTH) >= DATE_SUB(v_mes_calculo, INTERVAL 1 MONTH)  AND DATE_DIFF(COALESCE(DATE_TRUNC(fecha_activacion, MONTH),PARSE_DATE('%Y%m%d','20991231')), v_mes_calculo, DAY)  >= 0
		--DATE_TRUNC(fecha_creacion, MONTH) >= DATE_SUB(v_mes_calculo, INTERVAL 1 MONTH)  AND DATE_DIFF(DATE_TRUNC(fecha_activacion, MONTH), v_mes_calculo, DAY)  >= 0
		and `mm-commissions-reporting.KRT_CARTERA.f_descubre_tipo_servicio`(ClaseProducto, TipoProducto, NombreProducto) in ('BANDA ANCHA', 'MOVILES POSTPAGO', 'SEGURO MOVIL','SVA', 'TELEVISION','TERMINALES')
		and idProducto is not null     
		and contains_substr(TipoMovimiento,'Alta ')
		and idProductoOrigen is NULL 
		--- A SUSTITUIR POR CRUCE CON PARAMETRIZACION DE CANALES 
		and UPPER(TRIM(equipo)) in (
		'IBE48FID05000',
		'LND48FID05000',
		'IBE48WB-02000',
		--'LND48FID06000',
		'INGECI',
		--'INWHCI',    
		'INGEUN',   
		'INGEAT',
		--- 20260108 INCLUYO OUUGCI
		'OUUGCI'		    
		)

		
	UNION ALL

	--declare vdesde int64;DECLARE v_mes_calculo DATE; set vdesde=20251001;SET v_mes_calculo=PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING));
	SELECT
		distinct e.* except(fecha_calc_dt, desde, hasta,version),
		`mm-commissions-reporting.KRT_CARTERA.f_descubre_tipo_servicio`(ClaseProducto, TipoProducto, NombreProducto) as tipo_servicio,    
		-- Flag para ventas *realizadas* en el mes N
		COALESCE( (EXTRACT(YEAR FROM fecha_creacion) = EXTRACT(YEAR FROM v_mes_calculo) AND  EXTRACT(MONTH FROM fecha_creacion) = EXTRACT(MONTH FROM v_mes_calculo)) , FALSE ) AS es_venta_mes_n,
		-- Flag para ventas *activadas* en el mes N
		COALESCE( (EXTRACT(YEAR FROM fecha_activacion) = EXTRACT(YEAR FROM v_mes_calculo) AND     EXTRACT(MONTH FROM fecha_activacion) = EXTRACT(MONTH FROM v_mes_calculo)) , FALSE ) AS es_activacion_mes_n,
	FROM `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_CARTERA` e
	--INNER  JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p on p.mes_comision_id=CAST(SAFE_DIVIDE(vdesde,100) AS INT64) and UPPER(TRIM(p.marca_ds))=UPPER(TRIM(e.marca_ds)) and PARSE_DATE('%Y%m%d',CAST(fecha_id AS STRING))=e.fecha_calc_dt
	WHERE NOT EXISTS(
              select 1 
              from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
              where r.marca_ds=e.marca_ds
              and r.mes_comision_id = CAST(FORMAT_DATE("%Y%m",date_trunc(PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)), MONTH)) AS INT64)
              --and c.version=CAST((SELECT `mm-commissions-reporting.KRT_CARTERA.getVersion_nmonths`(NMESES) as vversion) as INT64)
        )
        and e.fecha_calc_dt=CURRENT_DATE('Europe/Madrid') 
        and e.desde=vdesde
		-- Optimización: Solo leer datos relevantes (mes N y mes N-1)
		--DATE_TRUNC(fecha_creacion, MONTH) >= DATE_SUB(v_mes_calculo, INTERVAL 1 MONTH)  AND DATE_DIFF(DATE_TRUNC(fecha_activacion, MONTH), v_mes_calculo, DAY)  >= 0
		and DATE_TRUNC(fecha_creacion, MONTH) >= DATE_SUB(v_mes_calculo, INTERVAL 1 MONTH)  AND DATE_DIFF(COALESCE(DATE_TRUNC(fecha_activacion, MONTH),PARSE_DATE('%Y%m%d','20991231')), v_mes_calculo, DAY)  >= 0		
		and `mm-commissions-reporting.KRT_CARTERA.f_descubre_tipo_servicio`(ClaseProducto, TipoProducto, NombreProducto) in ('BANDA ANCHA', 'MOVILES POSTPAGO', 'SEGURO MOVIL','SVA', 'TELEVISION','TERMINALES')
		and idProducto is not null     
		and contains_substr(TipoMovimiento,'Alta ')
		and idProductoOrigen is NULL 
		--- A SUSTITUIR POR CRUCE CON PARAMETRIZACION DE CANALES 
		and UPPER(TRIM(equipo)) in (
		'IBE48FID05000',
		'LND48FID05000',
		'IBE48WB-02000',		
		--'LND48FID06000',
		'INGECI',
		--'INWHCI',    
		'INGEUN',   
		'INGEAT'    
		)
		and e.desde=vdesde
		--- 
	;



	-- -----------------------------------------------------------------------
	-- CTE 1 -> Tabla: CONT_VENTAS_FIDGEN_MARCAxDISTxTIPOSERV
	-- Agrega las ventas y activaciones del Mes N por Marca, Distribuidor y Servicio.
	-- -----------------------------------------------------------------------

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.CONT_VENTAS_FIDGEN_MARCAxDISTxTIPOSERV` AS
	WITH r as (
		SELECT
			v.marca_ds,
			v.nombre_distribuidor,
			v.tipo_servicio,
			COUNTIF(v.es_venta_mes_n) AS n_ventas_reales,
			COUNTIF(v.es_activacion_mes_n) AS n_activaciones_reales,
		-- MODIFICACIÓN: Lee de la tabla VENTAS_FIDGEN creada en el paso anterior.
		FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_FIDGEN` v  
		WHERE es_venta_mes_n OR es_activacion_mes_n -- Solo procesar filas relevantes para el mes N
		GROUP BY 1, 2,3
	)
	select r.*,  
		CAST(`mm-commissions-reporting.KRT_SAP.f_est_calculaEstimacionFlotante`(n_ventas_reales, ndc.nlaborables, ndt.nlaborables)  AS INT64) as n_ventas_estimadas,
		CAST(`mm-commissions-reporting.KRT_SAP.f_est_calculaEstimacionFlotante`(n_activaciones_reales, ndc.nlaborables, ndt.nlaborables)  AS INT64) as n_activaciones_estimadas,
	from r
	INNER JOIN `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesTranscurrido`(CAST(FORMAT_DATE("%Y%m%d", v_mes_calculo) AS INT64)) ndc on ndc.marca_ds=r.marca_ds 
	INNER JOIN `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesCompleto`(CAST(FORMAT_DATE("%Y%m%d", v_mes_calculo ) AS INT64)) ndt on ndt.marca_ds=r.marca_ds
	;

	-- -----------------------------------------------------------------------
	-- CTE 2 -> Tabla: CTRL_MARCAxDIST (Paso 1 de la lógica)
	-- Verifica qué duplas (Marca, Distribuidor) cumplen las 3 condiciones para ser retribuidas.
	-- -----------------------------------------------------------------------
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.CTRL_MARCAxDIST` AS
	with 
	resumen AS (
		SELECT
			obj.marca_ds,
			obj.nombre_distribuidor,
			obj.metrica,
			SUM(obj.objetivo) AS total_objetivo,
			SUM(COALESCE(agg.n_activaciones_estimadas, 0)) AS total_activaciones,
			SUM(COALESCE(agg.n_ventas_estimadas, 0)) AS total_ventas,

			SUM( IF(obj.tipo_servicio IN UNNEST(v_servicios_principales), LEAST(COALESCE(agg.n_activaciones_estimadas, 0), obj.objetivo * 1.2), 0) ) AS total_activaciones_svp,
			SUM( IF(obj.tipo_servicio IN UNNEST(v_servicios_principales), LEAST(COALESCE(agg.n_ventas_estimadas, 0), obj.objetivo * 1.2),  0) ) AS total_ventas_svp,
			SUM( IF(obj.tipo_servicio IN UNNEST(v_servicios_principales), COALESCE(obj.objetivo,  0),0)) AS total_objetivos_svp,

			CASE WHEN CONTAINS_SUBSTR(metrica, "ACTIVA")
				THEN SUM(COALESCE(agg.n_activaciones_estimadas, 0))
				ELSE SUM(COALESCE(agg.n_ventas_estimadas, 0))
			END AS contGlobal,

			CASE WHEN CONTAINS_SUBSTR(metrica, "ACTIVA")
				THEN SUM( IF(obj.tipo_servicio IN UNNEST(v_servicios_principales), LEAST(COALESCE(agg.n_activaciones_estimadas, 0), obj.objetivo * 1.2), 0) )
				ELSE SUM( IF(obj.tipo_servicio IN UNNEST(v_servicios_principales), LEAST(COALESCE(agg.n_ventas_estimadas, 0), obj.objetivo * 1.2),  0) )
			END AS contServPrincipal,

			MAX(bm.bonusMalus) AS max_bonus_malus
		FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_FIDGEN_OBJETIVOS` AS obj
		-- MODIFICACIÓN: Lee de la tabla CONT_VENTAS_FIDGEN_MARCAxDISTxTIPOSERV creada en el paso anterior.
		LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.CONT_VENTAS_FIDGEN_MARCAxDISTxTIPOSERV` AS agg
			ON obj.marca_ds = agg.marca_ds
			AND obj.nombre_distribuidor = agg.nombre_distribuidor
			AND obj.tipo_servicio = agg.tipo_servicio
		LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_FIDGEN_BONUS_MALUS` AS bm
			ON obj.marca_ds = bm.marca_ds
			AND obj.nombre_distribuidor = bm.nombre_distribuidor
		GROUP BY obj.marca_ds, obj.nombre_distribuidor, obj.metrica
	)
	SELECT
		marca_ds,
		nombre_distribuidor,
		SUM(resumen.contGlobal) as contGlobal,
		SUM(resumen.contServPrincipal) as contServPrincipal,
		SUM(resumen.total_objetivo) as total_objetivo,
		SUM(resumen.total_objetivos_svp) as total_objetivos_svp,
		SUM(resumen.max_bonus_malus) as sumBonusMalus,

		-- Cumple global
		SUM(resumen.contGlobal) >= SUM(resumen.total_objetivo) AS cumple_global,
		-- Cumple svp
		SUM(resumen.contServPrincipal) >= SUM(resumen.total_objetivos_svp) AS cumple_svp,
		-- Cumple Bonus malus
		SUM(resumen.max_bonus_malus) = 0 AS no_aplica_bonus_malus

	FROM resumen
	GROUP BY marca_ds, nombre_distribuidor
	;

	-- -----------------------------------------------------------------------
	-- CTE 3 -> Tabla: UNI_MARCAxDISTxTIPOSERV (Pasos 2 y 3 de la lógica)
	--    Calcula las "extra ventas" y el "importe retribuible" total 
	-- -----------------------------------------------------------------------
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.UNI_MARCAxDISTxTIPOSERV` AS
	SELECT
		agg.marca_ds,
		agg.nombre_distribuidor,
		agg.tipo_servicio,
		agg.n_ventas_reales,
		agg.n_ventas_estimadas,    
		obj.objetivo,
		agg.n_activaciones_reales, -- Denominador para Paso 4
		agg.n_activaciones_estimadas, -- Denominador para Paso 4    
		
		-- Paso 2: Cálculo de "Extra Ventas"
		CASE WHEN CONTAINS_SUBSTR(obj.metrica,"ACTIVA") THEN  GREATEST(0, coalesce(agg.n_activaciones_estimadas,0) - obj.objetivo) 
				ELSE GREATEST(0, agg.n_ventas_estimadas - obj.objetivo)
		END AS n_extra_ventas,
		
		-- Paso 3: Cálculo del Importe a Retribuir 
		CASE WHEN CONTAINS_SUBSTR(obj.metrica,"ACTIVA") THEN SAFE_MULTIPLY(GREATEST(0, coalesce(agg.n_activaciones_estimadas,0) - obj.objetivo),SAFE_MULTIPLY(imp.importe ,SAFE_DIVIDE( ndc.nlaborables,  ndt.nlaborables) ))
				ELSE SAFE_MULTIPLY(GREATEST(0, coalesce(agg.n_ventas_estimadas,0) - obj.objetivo),SAFE_MULTIPLY(imp.importe ,SAFE_DIVIDE( ndc.nlaborables,  ndt.nlaborables) ))
		END AS importe_retribuible_triplet
		
	-- MODIFICACIÓN: Lee de la tabla CONT_VENTAS_FIDGEN_MARCAxDISTxTIPOSERV
	FROM `mm-commissions-reporting.KRT_CARTERA.CONT_VENTAS_FIDGEN_MARCAxDISTxTIPOSERV` AS agg
	INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_FIDGEN_OBJETIVOS` AS obj
		ON agg.marca_ds = obj.marca_ds
		AND agg.nombre_distribuidor = obj.nombre_distribuidor
		AND agg.tipo_servicio = obj.tipo_servicio
	INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_FIDGEN_IMPORTE_VENTA` AS imp
		ON agg.marca_ds = imp.marca_ds
		AND agg.tipo_servicio = imp.tipo_servicio
	-- MODIFICACIÓN: Lee de la tabla CTRL_MARCAxDIST
	INNER JOIN `mm-commissions-reporting.KRT_CARTERA.CTRL_MARCAxDIST` AS elig
		ON agg.marca_ds = elig.marca_ds
		AND agg.nombre_distribuidor = elig.nombre_distribuidor
	INNER JOIN `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesTranscurrido`(CAST(FORMAT_DATE("%Y%m%d", v_mes_calculo) AS INT64)) ndc on ndc.marca_ds=agg.marca_ds 
	INNER JOIN `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesCompleto`(CAST(FORMAT_DATE("%Y%m%d", v_mes_calculo ) AS INT64)) ndt on ndt.marca_ds=agg.marca_ds    
	WHERE
		-- Aplicamos el filtro del Paso 1
		elig.cumple_global
		AND elig.cumple_svp
		AND elig.no_aplica_bonus_malus
	;

	-- -----------------------------------------------------------------------
	-- CTE 4 -> Tabla: CONT_NACTxMARCAxDIST (Preparación Paso 5)
	-- Calcula el denominador para el Paso 5
	-- -----------------------------------------------------------------------
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.CONT_NACTxMARCAxDIST` AS
	SELECT
		marca_ds,
		nombre_distribuidor,
		-- Suma todas las activaciones de las triplets que SÍ fueron retribuibles
		SUM(n_activaciones_reales) AS total_activaciones_retribuibles_dupla
	-- MODIFICACIÓN: Lee de la tabla UNI_MARCAxDISTxTIPOSERV
	FROM `mm-commissions-reporting.KRT_CARTERA.UNI_MARCAxDISTxTIPOSERV`
	WHERE
		importe_retribuible_triplet > 0 -- Solo de servicios retribuibles
	GROUP BY
		1, 2
	;

	-- =======================================================================
	-- SELECT Final -> Tabla: MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA
	-- Esta es la tabla de salida original, que ahora se construye
	-- a partir de las tablas intermedias generadas.
	-- =======================================================================
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS
	SELECT
		v.*,
		b.importe_retribuible_triplet,
		b.n_activaciones_reales AS activaciones_triplet_paso4,
		t.total_activaciones_retribuibles_dupla AS activaciones_dupla_paso5,
		c.importe,
		
		-- =====================================================================
		-- Paso 4: Asignación de la Retribución (Comisión)
		-- =====================================================================
		IF(
			b.n_activaciones_reales > 0, -- Evitar división por cero
			ROUND(b.importe_retribuible_triplet / b.n_activaciones_reales,4),
			0
		) AS comision_por_venta,
		
		-- =====================================================================
		-- Paso 5: Asignación del Coste del Servicio de Venta
		-- =====================================================================
		IF(
			t.total_activaciones_retribuibles_dupla > 0, -- Evitar división por cero
			ROUND(c.importe / t.total_activaciones_retribuibles_dupla,4),
			0
		) AS coste_por_venta
		
	-- MODIFICACIÓN: Lee de la tabla VENTAS_FIDGEN
	FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_FIDGEN` AS v

	-- MODIFICACIÓN: Lee de la tabla UNI_MARCAxDISTxTIPOSERV
	JOIN `mm-commissions-reporting.KRT_CARTERA.UNI_MARCAxDISTxTIPOSERV` AS b
		ON v.marca_ds = b.marca_ds
		AND v.nombre_distribuidor = b.nombre_distribuidor
		AND v.tipo_servicio = b.tipo_servicio
		
	-- MODIFICACIÓN: Lee de la tabla CONT_NACTxMARCAxDIST
	LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.CONT_NACTxMARCAxDIST` AS t
		ON v.marca_ds = t.marca_ds
		AND v.nombre_distribuidor = t.nombre_distribuidor
		
	-- Unimos con la tabla de costes fijos de la dupla (M,D)
	LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_FIDGEN_IMPORTE_LLAMADA` AS c
		ON v.marca_ds = c.marca_ds
		AND v.nombre_distribuidor = c.nombre_distribuidor

	WHERE
		v.es_activacion_mes_n
		AND b.importe_retribuible_triplet > 0
	;
		

END