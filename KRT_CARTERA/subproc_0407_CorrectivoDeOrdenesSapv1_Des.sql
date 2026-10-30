BEGIN

  --------------------------------------------------------------------------------
  -- DEFINICIÓN DE LÓGICA DE TEXTO (REGEX)
  -- Unifica: equipamiento m, terminal, dispositivo, y prefijos 'T - ' en clase o desc
  --------------------------------------------------------------------------------
  DECLARE regex_terminal STRING DEFAULT r'(?i)equipamiento m|terminal|dispositivo';

  --------------------------------------------------------------------------------
  -- PASO 1: PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL
  --------------------------------------------------------------------------------
  
  -- 1.1. Calcular coincidencias en una tabla temporal (Lectura única de COMISIONES)
  CREATE TEMP TABLE tmp_matches_step1 AS
  SELECT 
    c.*,
    p.orden_sap AS new_orden_sap,
    -- Flag precalculado para saber si es terminal (TRUE) o servicio (FALSE)
    (
      REGEXP_CONTAINS(c.tipoMovimiento, regex_terminal) 
      OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') 
      OR CONTAINS_SUBSTR(c.desc_mm, 'T - ')
    ) AS is_terminal_flag,
    p.tipo AS param_tipo_requerido
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL` p 
    ON c.marca_ds = p.marca_ds 
    AND c.canal = p.canal
    AND (p.subcanal = "X" OR c.subcanal = p.subcanal)
    AND (p.marco_retributivo = "X" OR c.marco_retributivo = p.marco_retributivo)
  WHERE c.orden_sap IS NULL;

  -- 1.2. Generar Logs desde la temporal
  
  -- Log Terminales
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_TERMINALES_ASIGNADOS_POR_CANAL_UPD` AS
  SELECT * EXCEPT(new_orden_sap, is_terminal_flag, param_tipo_requerido)
  FROM tmp_matches_step1
  WHERE param_tipo_requerido = 'TERMINAL' AND is_terminal_flag = TRUE;

  -- Log Servicios
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_SERVICIOS_ASIGNADOS_POR_CANAL_UPD` AS
  SELECT * EXCEPT(new_orden_sap, is_terminal_flag, param_tipo_requerido)
  FROM tmp_matches_step1
  WHERE param_tipo_requerido = 'SERVICIO' AND is_terminal_flag = FALSE;

  -- 1.3. Actualizar COMISIONES usando la temporal (Un solo UPDATE para ambos casos)
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap = t.new_orden_sap
  FROM tmp_matches_step1 t
  WHERE 
    -- Unimos por todos los campos para asegurar unicidad de fila si no hay PK, 
    -- o idealmente usa una PK si existe (ej. id_comision)
    c.marca_ds = t.marca_ds 
    AND c.canal = t.canal 
    AND IFNULL(c.subcanal, 'NULL') = IFNULL(t.subcanal, 'NULL') -- Manejo de nulos por seguridad
    AND IFNULL(c.tipoMovimiento, 'NULL') = IFNULL(t.tipoMovimiento, 'NULL')
    AND IFNULL(c.desc_mm, 'NULL') = IFNULL(t.desc_mm, 'NULL')
    AND c.orden_sap IS NULL -- Seguridad extra
    AND (
         (t.param_tipo_requerido = 'TERMINAL' AND t.is_terminal_flag = TRUE)
      OR (t.param_tipo_requerido = 'SERVICIO' AND t.is_terminal_flag = FALSE)
    );

  -- Limpieza de tabla temporal paso 1
  DROP TABLE IF EXISTS tmp_matches_step1;


  --------------------------------------------------------------------------------
  -- PASO 2: PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS
  --------------------------------------------------------------------------------

  -- 2.1. Calcular coincidencias en tabla temporal
  CREATE TEMP TABLE tmp_matches_step2 AS
  SELECT 
    c.*,
    p.orden_sap AS new_orden_sap,
    (
      REGEXP_CONTAINS(c.tipoMovimiento, regex_terminal) 
      OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') 
      OR CONTAINS_SUBSTR(c.desc_mm, 'T - ')
    ) AS is_terminal_flag,
    p.tipo AS param_tipo_requerido
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS` p
    ON c.marca_ds = p.marca_ds 
    AND c.canal = p.canal
    AND (p.subcanal = "X" OR c.subcanal = p.subcanal)
    AND (p.marco_retributivo = "X" OR c.marco_retributivo = p.marco_retributivo)
  WHERE c.orden_sap IS NULL;

  -- 2.2. Generar Logs

  -- Log Terminales (TVT UPS)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_TERMINALES_ASIGNADOS_POR_MR_TVT_UPS_UPD` AS  
  SELECT * EXCEPT(new_orden_sap, is_terminal_flag, param_tipo_requerido)
  FROM tmp_matches_step2
  WHERE param_tipo_requerido = 'TERMINAL' AND is_terminal_flag = TRUE;

  -- Log Servicios (TVT UPS)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_SERVICIOS_ASIGNADOS_POR_MR_TVT_UPS_UPD` AS  
  SELECT * EXCEPT(new_orden_sap, is_terminal_flag, param_tipo_requerido)
  FROM tmp_matches_step2
  WHERE param_tipo_requerido = 'SERVICIO' AND is_terminal_flag = FALSE;

  -- 2.3. Actualizar COMISIONES
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap = t.new_orden_sap
  FROM tmp_matches_step2 t
  WHERE 
    c.marca_ds = t.marca_ds 
    AND c.canal = t.canal 
    AND IFNULL(c.tipoMovimiento, 'NULL') = IFNULL(t.tipoMovimiento, 'NULL')
    AND IFNULL(c.desc_mm, 'NULL') = IFNULL(t.desc_mm, 'NULL')
    AND c.orden_sap IS NULL
    AND (
         (t.param_tipo_requerido = 'TERMINAL' AND t.is_terminal_flag = TRUE)
      OR (t.param_tipo_requerido = 'SERVICIO' AND t.is_terminal_flag = FALSE)
    );

  DROP TABLE IF EXISTS tmp_matches_step2;


  --------------------------------------------------------------------------------
  -- PASO 3: PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP (Códigos SAP independientes)
  --------------------------------------------------------------------------------
  
  -- Para este paso, como es un solo update simple, usamos una CTE directa.
  -- 3.1 Generar Log
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_COMISIONES_ASIGNADOS_POR_DESC_MM` AS  
  SELECT c.* FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
    ON c.marca_ds = p.marca_ds 
    AND c.desc_mm = p.desc_mm 
    AND (p.segmento_ds = "X" OR c.segmento = p.segmento_ds);

  -- 3.2 Update Final
  -- Usamos logica estándar de JOIN para mejor performance que el UPDATE FROM original
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap = p.orden_sap  
  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
  WHERE c.marca_ds = p.marca_ds 
    AND c.desc_mm = p.desc_mm 
    AND (p.segmento_ds = "X" OR c.segmento = p.segmento_ds);

END