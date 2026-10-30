BEGIN

	--CALL `mm-commissions-reporting.KRT_SAP.subproc_0113_ResolverCodigoSapYCommissionIdv4_opt`("TRANSACCIONES_EN_PROCESO_V4", 20261001, "CAPTACION", "A");

	DECLARE VFQ_TABLA, VMES, VTIPOS_SQL, VSQL STRING;
	DECLARE VTIPOS ARRAY<STRING>;
	DECLARE VMES_FACTURA_DT DATE;
	DECLARE VNN_MAX, VDUPS INT64;

	--- PASO 0.0: VALIDACION DE PARAMETROS (se inyectan como literales: solo valores de lista blanca)
	IF vtabla IS NULL OR vtabla NOT IN ('TRANSACCIONES_EN_PROCESO_V4', 'TRANSACCIONES_EN_PROCESO_MASIVO_V4', 'TRANSACCIONES_EN_PROCESO_PYME_V4') THEN
		RAISE USING MESSAGE = FORMAT('subproc_0113: tabla no permitida [%s]', IFNULL(vtabla, 'NULL'));
	END IF;
	IF vcod_flujo IS NULL OR vcod_flujo NOT IN ('A', 'M', 'P') THEN
		RAISE USING MESSAGE = FORMAT('subproc_0113: vcod_flujo no permitido [%s]', IFNULL(vcod_flujo, 'NULL'));
	END IF;
	IF vdesde IS NULL THEN
		RAISE USING MESSAGE = 'subproc_0113: vdesde NULL';
	END IF;

	SET VFQ_TABLA = CONCAT('`mm-commissions-reporting.KRT_SAP.', vtabla, '`');

	--- mes (0112: DATE_TRUNC(vdesde, MONTH); 0114: mes de vdesde)
	SET VMES_FACTURA_DT = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING)), MONTH);
	SET VMES = FORMAT("DATE '%t'", VMES_FACTURA_DT);

	--- tipos a procesar (0112 v2 + semántica CONTAINS_SUBSTR de 0110 v3)
	SET VTIPOS = CASE
		WHEN vtipo IS NULL OR UPPER(TRIM(vtipo)) IN ('TODOS', 'TODAS', 'TOTAL') THEN ['CAPTACION', 'CARTERA']
		WHEN UPPER(TRIM(vtipo)) IN ('CAPTACION', 'CARTERA')                    THEN [UPPER(TRIM(vtipo))]
		WHEN CONTAINS_SUBSTR(vtipo, 'Total')                                   THEN ['CAPTACION', 'CARTERA']
		WHEN CONTAINS_SUBSTR(vtipo, 'Captacion')                               THEN ['CAPTACION']
		WHEN CONTAINS_SUBSTR(vtipo, 'Cartera')                                 THEN ['CARTERA']
		ELSE CAST([] AS ARRAY<STRING>)
	END;
	--- W0 [MEJORA v4]: vtipo no soportado -> error (0112 hacía no-op silencioso)
	IF ARRAY_LENGTH(VTIPOS) = 0 THEN
		RAISE USING MESSAGE = FORMAT(
			'W0_VTIPO_NO_SOPORTADO: subproc_0113 recibió vtipo [%s]; admitidos NULL, TODOS, TODAS, TOTAL, CAPTACION, CARTERA',
			IFNULL(vtipo, 'NULL'));
	END IF;
	SET VTIPOS_SQL = (SELECT STRING_AGG(FORMAT("'%s'", t), ', ') FROM UNNEST(VTIPOS) t);


	--- PASO 0: CORRECTIVO DE ORDENES SAP (réplica de subproc_0112_ActualizarOrdenesSapEnTablaTransaccionesv2)
	---   En producción 0112 corre tras 0110 y antes de 0114 y f_vt lee la orden ya corregida -> el CODIGO
	---   depende de la orden corregida. Columnas de parámetros con prefijo p_ (sin ambigüedad con t).
	---   Un único UPDATE equivale al bucle FOR de 0112: las filas de cada tipo son disjuntas (t.tipo = p.p_tipo).
	SET VSQL = """
	UPDATE @@TABLA@@ t
	SET orden    = p.p_orden_nueva,
	    segmento = CASE WHEN TRIM(IFNULL(t.segmento, '')) = '' THEN 'RESIDENCIAL' ELSE t.segmento END
	FROM (
		SELECT DISTINCT
			p.tipo                   AS p_tipo,
			UPPER(TRIM(p.marca))     AS p_marca,
			UPPER(TRIM(canal_split)) AS p_canal,
			UPPER(TRIM(srv_split))   AS p_service_type,
			UPPER(TRIM(seg_split))   AS p_segmento,
			UPPER(TRIM(marc_split))  AS p_marco,
			UPPER(TRIM(op_split))    AS p_operacion,
			p.orden_previa           AS p_orden_antigua,
			p.orden                  AS p_orden_nueva
		FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ORDENxCANAL` p
		CROSS JOIN UNNEST(SPLIT(p.canal)) canal_split
		CROSS JOIN UNNEST(SPLIT(p.service_type)) srv_split
		CROSS JOIN UNNEST(SPLIT(p.segmento)) seg_split
		CROSS JOIN UNNEST(SPLIT(p.marco)) marc_split
		CROSS JOIN UNNEST(SPLIT(p.operacion)) op_split
		WHERE p.tipo IN (@@TIPOS@@)
		  AND p.ESTADO = 'PUBLICAR'
		  AND UPPER(TRIM(op_split)) IN UNNEST(CASE p.tipo WHEN 'CAPTACION' THEN ['ALTA','BAJA']
		                                                  WHEN 'CARTERA'   THEN ['ALTA','BAJA','CAMBIO']
		                                                  ELSE CAST([] AS ARRAY<STRING>) END)
		QUALIFY ROW_NUMBER() OVER(
			PARTITION BY UPPER(TRIM(p.tipo)), UPPER(TRIM(p.marca)), UPPER(TRIM(canal_split)), UPPER(TRIM(srv_split)),
			             UPPER(TRIM(seg_split)), UPPER(TRIM(op_split)), p.orden_previa
			ORDER BY CASE WHEN UPPER(TRIM(marc_split)) != 'X' THEN 1 ELSE 0 END DESC
		) = 1
	) p
	WHERE t.mes_factura_dt = @@MES@@
	  AND t.tipo = p.p_tipo
	  AND UPPER(TRIM(t.marca)) = p.p_marca
	  AND UPPER(TRIM(t.canal_gekt)) = p.p_canal
	  AND UPPER(TRIM(t.service_type)) = p.p_service_type
	  AND UPPER(TRIM(COALESCE(NULLIF(TRIM(t.segmento), ''), 'RESIDENCIAL'))) = p.p_segmento
	  AND UPPER(TRIM(t.operation)) = p.p_operacion
	  AND (p.p_marco = 'X' OR UPPER(TRIM(t.marco)) = p.p_marco)
	  AND t.orden IN (p.p_orden_antigua, p.p_orden_nueva)
	  AND (t.orden != p.p_orden_nueva OR TRIM(IFNULL(t.segmento, '')) = '')
	  AND NOT CONTAINS_SUBSTR(t.concepto_ds_gekt, 'POSTVENTA')
	""";
	EXECUTE IMMEDIATE REPLACE(REPLACE(REPLACE(VSQL, '@@TABLA@@', VFQ_TABLA), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL);


	--- PASO A + B: CODIGO SAP Y COMMISSION_ID (una sola reescritura de la tabla de staging)
	---   SELECT * REPLACE conserva esquema y orden de columnas (el escritor hace SELECT e.* posicional).
	SET VSQL = """
	CREATE OR REPLACE TABLE @@TABLA@@ AS
	WITH g_dedup AS (
		-- mismo criterio que f_vt_factura_apuntes_desde_tr_en_proceso / 0110 v3
		SELECT UPPER(TRIM(tipo)) AS k_tipo, UPPER(TRIM(marca)) AS k_marca, orden AS k_orden, DETALLE
		FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
		WHERE ESTADO IN ("ACTIVO","PUBLICADA","INACTIVO")
		QUALIFY ROW_NUMBER() OVER (
			PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
			ORDER BY CANAL, DETALLE
		) = 1
	),
	o_dedup AS (
		-- 0114: solo CODIGO de 4 caracteres · [INVARIANT-FANOUT]: dedup defensivo de la clave f_vt
		SELECT UPPER(TRIM(TIPO)) AS k_tipo, UPPER(TRIM(MARCA)) AS k_marca, ORDEN AS k_orden,
		       UPPER(TRIM(CONCEPTO)) AS k_concepto, CODIGO
		FROM `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`
		WHERE LENGTH(TRIM(CODIGO)) = 4
		QUALIFY ROW_NUMBER() OVER (
			PARTITION BY UPPER(TRIM(TIPO)), UPPER(TRIM(MARCA)), ORDEN, UPPER(TRIM(CONCEPTO))
			ORDER BY CODIGO
		) = 1
	),
	od AS (
		-- catálogo + atributos de terna (se evalúan una vez por fila de catálogo)
		SELECT o.k_tipo, o.k_marca, o.k_orden, o.k_concepto, o.CODIGO,
		       STARTS_WITH(CAST(o.k_orden AS STRING), '2') AS digito2,
		       CASE WHEN LOWER(IFNULL(g.DETALLE,'')) LIKE '%plataforma cancelacion%' THEN 'Extracomision Plataforma Cancelacion '
		            WHEN LOWER(IFNULL(g.DETALLE,'')) LIKE '%postventa%'              THEN 'Extracomision Postventa '
		            WHEN LOWER(IFNULL(g.DETALLE,'')) LIKE '%gestion%'                THEN 'Extracomision Gestion '
		       END AS mid_capt
		FROM o_dedup o
		LEFT JOIN g_dedup g USING (k_tipo, k_marca, k_orden)
	),
	src AS (
		SELECT e.*,
		       -- [MEJORA v4] CODIGO solo para los tipos de la llamada (0114 recalculaba ambos tipos)
		       IFNULL(e.mes_factura_dt = @@MES@@ AND e.tipo IN (@@TIPOS@@), FALSE) AS __ambito_codigo,
		       IFNULL(e.mes_factura_dt = @@MES@@ AND e.tipo IN (@@TIPOS@@), FALSE) AS __ambito_id
		FROM @@TABLA@@ e
	),
	-- PASO A: CODIGO (equi-join por terna natural; el descriptor es filtro residual)
	cod AS (
		SELECT s.*, od.CODIGO AS __codigo
		FROM src s
		LEFT JOIN od
		  ON  s.__ambito_codigo
		  AND od.k_tipo  = UPPER(TRIM(s.tipo))
		  AND od.k_marca = UPPER(TRIM(s.marca))
		  AND od.k_orden = s.orden
		  AND od.k_concepto = UPPER(TRIM(CASE
		        WHEN s.tipo = 'CAPTACION' AND od.mid_capt IS NOT NULL AND STARTS_WITH(s.clase_concepto, 'D - ')
		          THEN REGEXP_REPLACE(s.clase_concepto, r'^D - .*?Capt\\. ', CONCAT('D - ', od.mid_capt, 'Capt. '))
		        WHEN s.tipo = 'CARTERA' AND od.digito2 AND STARTS_WITH(s.clase_concepto, 'D - Extracomision ')
		             AND NOT CONTAINS_SUBSTR(s.concepto, 'Plataforma Pad')
		          THEN REGEXP_REPLACE(s.clase_concepto, r'^D - Extracomision (?:Altas|Terminales) ',
		                 IF(COALESCE(s.categoria_servicio_ds, 'NODEF') IN ('DISPOSITIVOS','TERMINALES','CPE'),
		                    'D - Extracomision Terminales ', 'D - Extracomision Altas '))
		        ELSE s.clase_concepto
		      END))
	),
	-- PASO B: COMMISSION_ID (solo filas generadas en esta ejecución)
	idk AS (
		SELECT c.*,
		       IFNULL(c.__codigo, c.tipo_concepto) AS __codigo_final,   -- 0114: sin match conserva el valor previo
		       CONCAT(
		         CASE WHEN CONTAINS_SUBSTR(c.marca, 'EUSKALTEL') THEN 'K'
		              WHEN UPPER(TRIM(c.marca)) = 'R'            THEN 'R'
		              WHEN CONTAINS_SUBSTR(c.marca, 'TELECABLE') THEN 'T'
		              WHEN CONTAINS_SUBSTR(c.marca, 'RACC')      THEN 'RA'
		              WHEN CONTAINS_SUBSTR(c.marca, 'VIRGIN')    THEN 'V'
		              ELSE 'N' END,
		         '_',
		         CASE WHEN CONTAINS_SUBSTR(c.clase, 'decomision') THEN 'D'
		              WHEN CONTAINS_SUBSTR(c.clase, 'comision') AND NOT CONTAINS_SUBSTR(c.clase, 'decomisi') THEN 'C'
		              ELSE 'N' END,
		         '@@FLUJO@@',
		         CASE WHEN CONTAINS_SUBSTR(c.tipo, 'capta') THEN 'P'
		              WHEN CONTAINS_SUBSTR(c.tipo, 'carte') THEN 'R'
		              ELSE 'N' END,
		         FORMAT_DATE('%y%m', c.mes_factura_dt),
		         '_',
		         IFNULL(IFNULL(c.__codigo, c.tipo_concepto), 'NCOD')
		       ) AS __raiz,
		       UPPER(LPAD(FORMAT('%x', CAST(MOD(MOD(ROUND(
		           (COALESCE(SAFE_CAST(c.service_id AS BIGNUMERIC), CAST(FARM_FINGERPRINT(c.service_id) AS BIGNUMERIC), 0)
		            + IFNULL(CAST(c.comision AS BIGNUMERIC), 0)) * 100
		         ), 16777216) + 16777216, 16777216) AS INT64)), 6, '0')) AS __hex6,
		       CONCAT(IFNULL(c.marca,'~'),'|',IFNULL(CAST(c.orden AS STRING),'~'),'|',IFNULL(c.marco,'~'),'|',
		              IFNULL(c.concepto,'~'),'|',IFNULL(c.clase_concepto,'~'),'|',IFNULL(c.concepto_ds_gekt,'~'),'|',
		              IFNULL(c.concepto_lista_ds_gekt,'~'),'|',IFNULL(c.customer_id,'~'),'|',IFNULL(c.service_id,'~'),'|',
		              IFNULL(c.account_id,'~'),'|',IFNULL(c.order_id,'~'),'|',IFNULL(c.tariff_id,'~'),'|',
		              IFNULL(c.tariff_id_origin,'~'),'|',IFNULL(c.service_id_origin,'~'),'|',IFNULL(c.operation_type,'~'),'|',
		              IFNULL(CAST(c.activation_date AS STRING),'~'),'|',IFNULL(CAST(c.sale_date AS STRING),'~'),'|',
		              IFNULL(CAST(c.deactivation_date AS STRING),'~'),'|',IFNULL(c.causa_baja,'~'),'|',
		              IFNULL(CAST(c.comision AS STRING),'~')) AS __clave
		FROM cod c
	),
	nn AS (
		SELECT i.*,
		       IF(i.__ambito_id,
		          ROW_NUMBER() OVER (
		            PARTITION BY i.__ambito_id, i.__raiz, i.__hex6
		            ORDER BY i.__clave, i.distribuidor_gekt, i.subcanal, i.canal_gekt, i.sfid_id, i.seller,
		                     i.mes_liquidado, i.unidades, i.nombre_comercio, i.agrupacion_canal, i.canal,
		                     i.phone_nm, i.bp, i.cif, i.razon_social
		          ),
		          NULL) AS __nn
		FROM idk i
	)
	SELECT * EXCEPT(__ambito_codigo, __ambito_id, __codigo, __codigo_final, __raiz, __hex6, __clave, __nn)
	         REPLACE(
	           IF(__ambito_codigo, __codigo_final, tipo_concepto) AS tipo_concepto,
	           IF(__ambito_id, CONCAT(__raiz, '_', __hex6, LPAD(CAST(__nn AS STRING), 2, '0')), commission_id) AS commission_id,
	           -- id heredado -> id_registro, salvo que la fila ya tenga id v4 (re-ejecución: conserva el heredado)
	           IF(__ambito_id AND NOT REGEXP_CONTAINS(IFNULL(commission_id, ''), r'^[A-Z]{1,2}_[CDN][AMP][PRN][0-9]{4}_'),
	              commission_id, id_registro) AS id_registro
	         ),
	       __nn AS __nn_gate
	FROM nn
	""";
	SET VSQL = REPLACE(REPLACE(REPLACE(REPLACE(VSQL, '@@TABLA@@', VFQ_TABLA), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL), '@@FLUJO@@', vcod_flujo);

	EXECUTE IMMEDIATE VSQL;


	--- GATE 1: NN > 99 (el sufijo de 2 dígitos no admite más de 99 posiciones por raíz+HEX6)
	EXECUTE IMMEDIATE REPLACE("SELECT IFNULL(MAX(__nn_gate), 0) FROM @@TABLA@@", '@@TABLA@@', VFQ_TABLA) INTO VNN_MAX;

	--- retiro la columna técnica del gate (vuelve al esquema exacto de TRANSACCIONES)
	EXECUTE IMMEDIATE REPLACE("ALTER TABLE @@TABLA@@ DROP COLUMN __nn_gate", '@@TABLA@@', VFQ_TABLA);

	IF VNN_MAX > 99 THEN
		RAISE USING MESSAGE = FORMAT('subproc_0113: NN=%d > 99 en %s — revisar clave de identidad', VNN_MAX, vtabla);
	END IF;

	--- GATE 2: UNICIDAD DE COMMISSION_ID EN LA TABLA DE STAGING
	EXECUTE IMMEDIATE REPLACE("SELECT COUNT(*) - COUNT(DISTINCT commission_id) FROM @@TABLA@@", '@@TABLA@@', VFQ_TABLA) INTO VDUPS;
	IF VDUPS > 0 THEN
		RAISE USING MESSAGE = FORMAT('subproc_0113: %d commission_id duplicados en %s', VDUPS, vtabla);
	END IF;


	--- AVISOS (no bloqueantes)
	--- W1: filas del mes sin CODIGO (clase A2/C — nunca se fuerza)
	EXECUTE IMMEDIATE REPLACE(REPLACE(REPLACE("""
	SELECT 'W1_SIN_CODIGO' AS aviso, tipo, clase, marca, orden, clase_concepto,
	       COUNT(*) AS filas, ROUND(SUM(IFNULL(comision,0)),2) AS importe
	FROM @@TABLA@@
	WHERE tipo_concepto IS NULL AND mes_factura_dt = @@MES@@ AND tipo IN (@@TIPOS@@)
	GROUP BY ALL
	ORDER BY importe DESC
	LIMIT 50
	""", '@@TABLA@@', VFQ_TABLA), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL);

	--- W2: filas con CODIGO sin distribuidor/acreedor (mismo filtro INNER que f_vt; no llegarían a SAP_FACTURA_APUNTES)
	EXECUTE IMMEDIATE REPLACE(REPLACE(REPLACE("""
	SELECT 'W2_SIN_ACREEDOR' AS aviso, tipo, marca, distribuidor_gekt,
	       COUNT(*) AS filas, ROUND(SUM(IFNULL(comision,0)),2) AS importe
	FROM @@TABLA@@ e
	WHERE e.tipo_concepto IS NOT NULL AND e.mes_factura_dt = @@MES@@ AND e.tipo IN (@@TIPOS@@)
	  AND NOT EXISTS (
	    SELECT 1
	    FROM `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d
	    JOIN `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` a
	      ON a.SOCIEDAD=d.SOCIEDAD AND UPPER(TRIM(a.CIF))=UPPER(TRIM(d.CIF)) AND a.BP=d.BP AND a.marca=d.marca
	    WHERE d.marca=e.marca AND UPPER(TRIM(d.nombre_distribuidor))=UPPER(TRIM(e.distribuidor_gekt))
	  )
	GROUP BY ALL
	ORDER BY importe DESC
	LIMIT 50
	""", '@@TABLA@@', VFQ_TABLA), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL);

END