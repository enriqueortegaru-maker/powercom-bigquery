BEGIN
  -- 1. Declaración de Variables
  DECLARE FECHA_INICIO_DT, FECHA_FIN_DT, vMES_VENTA_DT, vFECHA_CALC DATE;
  DECLARE VDESDE_YYYYMM, VIMPORTE_MINIMO INT64;

  SET FECHA_INICIO_DT = PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING));
  SET FECHA_FIN_DT    = PARSE_DATE("%Y%m%d", CAST(vhasta AS STRING));
  SET vMES_VENTA_DT   = DATE_TRUNC(FECHA_INICIO_DT, MONTH); 
  SET VDESDE_YYYYMM   = CAST(FORMAT_DATE("%Y%m", FECHA_INICIO_DT) AS INT64);
  SET VIMPORTE_MINIMO = 0;
  
  -- Fijamos la fecha de cálculo actual para todo el proceso
  SET vFECHA_CALC     = CURRENT_DATE(); 

  --------------------------------------------------------------------
  -- 2. Cálculo de Incentivos
  --------------------------------------------------------------------
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS` AS
  WITH 
-- 1. Pre-procesamos parámetros de Incentivos (limpieza de strings y fechas)
Params_Incentivos AS (
  SELECT 
    UPPER(TRIM(marca)) AS marca_clean,
    UPPER(TRIM(modelo)) AS modelo_clean,
    PARSE_DATE("%Y%m%d", CAST(desde AS STRING)) AS fecha_desde,
    PARSE_DATE("%Y%m%d", CAST(hasta AS STRING)) AS fecha_hasta,    
    importe
  FROM `mm-commissions-reporting.GS.PARAM_KRT_TERMINAL_INCENTIVO_IMPORTE`
),

-- 2. Pre-procesamos exclusiones (manejo de 'X' como NULL para simplificar lógica)
Params_Exclusion AS (
  SELECT 
    UPPER(TRIM(marca)) AS marca_clean,
    -- Si es 'X', lo convertimos a NULL para usar lógica COALESCE más rápida
    CASE WHEN UPPER(TRIM(canal)) = 'X' THEN NULL ELSE UPPER(TRIM(canal)) END AS canal_clean,
    CASE WHEN UPPER(TRIM(subcanal)) = 'X' THEN NULL ELSE UPPER(TRIM(subcanal)) END AS subcanal_clean,
    PARSE_DATE("%Y%m%d", CAST(desde AS STRING)) AS fecha_desde,
    PARSE_DATE("%Y%m%d", CAST(hasta AS STRING)) AS fecha_hasta
  FROM `mm-commissions-reporting.GS.PARAM_KRT_TERMINAL_CANALES_EXCLUSION_INCENTIVO`
),

-- 3. Filtramos la tabla grande de ventas ANTES del join costoso
Ventas_Del_Mes AS (
  SELECT v.*
  FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES` v
  WHERE v.mes_venta_dt = vMES_VENTA_DT
)

-- 4. Consulta Principal
SELECT DISTINCT v.*, i.importe
FROM Ventas_Del_Mes v
INNER JOIN Params_Incentivos i 
  ON i.marca_clean = UPPER(TRIM(v.marca)) 
  AND i.modelo_clean = UPPER(TRIM(v.modelo))
  -- El mes de venta debe coincidir con el mes de inicio del parámetro (según lógica original)
  AND v.mes_venta_dt = DATE_TRUNC(i.fecha_desde, MONTH)

WHERE 
  -- Comprobación simple de fecha 
  --v.fecha_Creacion >= i.fecha_desde
    --- si la parametrizacion que se aplica es de n tramos por mes entonces se aplica esta condicion
  v.fecha_Creacion BETWEEN i.fecha_desde and i.fecha_hasta
  
  -- Lógica de Exclusión
  AND NOT EXISTS (
    SELECT 1
    FROM Params_Exclusion e
    WHERE e.marca_clean = UPPER(TRIM(v.marca_ds))
    -- Si el canal de exclusión es NULL (era X), coincide siempre. Si no, busca igualdad.
    AND (e.canal_clean IS NULL OR e.canal_clean = UPPER(TRIM(v.canal)))
    AND (e.subcanal_clean IS NULL OR e.subcanal_clean = UPPER(TRIM(v.subcanal)))
    AND v.fecha_Creacion BETWEEN e.fecha_desde AND e.fecha_hasta
  )
  AND i.importe IS NOT NULL

-- Filtro de ventana (Window Function)
QUALIFY SUM(i.importe) OVER(PARTITION BY v.marca_ds, v.usuarioCreador) >= VIMPORTE_MINIMO;




  --------------------------------------------------------------------
  -- 3. Actualización de Histórico (Foto única del mes)
  --------------------------------------------------------------------
  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS` 
  WHERE mes_venta_dt = vMES_VENTA_DT;
  
  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS`
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS`;

  --------------------------------------------------------------------
  -- 4. Actualización de Agregados (Histórico de ejecuciones diarias)
  --------------------------------------------------------------------
  
  -- Borramos si YA existe un cálculo para ESTE mes hecho HOY.
  -- Esto permite reprocesar varias veces en el día quedándose con la última versión.
  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TERMINALES_INCENTIVOS` 
  WHERE mes_venta_dt = vMES_VENTA_DT 
    AND fecha_calc_dt = vFECHA_CALC;

  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TERMINALES_INCENTIVOS` 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS`;

  --------------------------------------------------------------------
  -- 5. Registro de Modelos No Incentivados
  --------------------------------------------------------------------
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_MODELOS_NO_INCENTIVOS` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_ter_modelos_terminales_no_incentivados`(VDESDE_YYYYMM);

/*
  
  --- REGISTRO DE INCENTIVOS DE TERMINALES


	EXECUTE IMMEDIATE format("""
		CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.INCENTIVOS_VENTAS_TERMINALES_PT_POR_AGENTE`  
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
		SELECT * FROM
		(
			SELECT v.marca_ds as marca,	v.Canal as canal,	v.nombre_distribuidor,	v.UsuarioCreador as usuarioCreador, v.agente, concat(marca, ' - ',v.modelo) as modelo, v.idProducto, sum(v.importe) over(partition by marca, canal,  nombre_distribuidor,usuarioCreador, agente) as imp 	
			FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS` v
			WHERE mes_venta_dt=@vmes_venta
		)
		PIVOT
		(
		count(idProducto) 
		FOR modelo in %s
		)
		ORDER BY marca, canal, nombre_distribuidor, UsuarioCreador, agente ASC
		""", 
		(

			SELECT
			CONCAT('("', 
			STRING_AGG(DISTINCT concat(marca,' - ' ,replace(replace(replace(replace(replace(replace(modelo,'+',' '), '(', '' ),')',''),'"',''),',',' '),'.',' ')), '", "'	order by concat( marca,' - ' ,replace(replace(replace(replace(replace(replace(modelo,'+',' '), '(', '' ),')',''),'"',''),',',' '),'.',' '))) , '")'),
			FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS`
		)

	)
	USING PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING)) as vmes_venta;  

*/



END