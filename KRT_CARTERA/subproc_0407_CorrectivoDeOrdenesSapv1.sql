BEGIN

  -- 1. CONFIGURACIÓN INICIAL
  -- Definimos qué es un terminal con una sola variable (menos código repetido)
  DECLARE regex_terminal STRING DEFAULT r'(?i)equipamiento m|terminal|dispositivo';

  -- Cargamos parámetros en memoria (Más rápido que leer del disco repetidamente)
  CREATE OR REPLACE TEMP TABLE tmp_param_canal AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL`;
  CREATE OR REPLACE TEMP TABLE tmp_param_tvt AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS`;
  CREATE OR REPLACE TEMP TABLE tmp_param_corr AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP`;

  --------------------------------------------------------------------------------
  -- PASO 1: ASIGNACIÓN POR CANAL
  --------------------------------------------------------------------------------
  
  -- A. Detectar candidatos para Logs (Lectura optimizada)
  CREATE OR REPLACE TEMP TABLE tmp_logs_1 AS
  SELECT c.*, p.tipo as tipo_param
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  JOIN tmp_param_canal p 
    ON c.marca_ds = p.marca_ds AND c.canal = p.canal
    AND (p.subcanal = 'X' OR c.subcanal = p.subcanal)
    AND (p.marco_retributivo = 'X' OR c.marco_retributivo = p.marco_retributivo)
  WHERE c.orden_sap IS NULL;

  -- B. Generar Logs (Desde memoria, muy rápido)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_TERMINALES_ASIGNADOS_POR_CANAL_UPD` AS
  SELECT * EXCEPT(tipo_param) FROM tmp_logs_1 
  WHERE tipo_param = 'TERMINAL' 
    AND (REGEXP_CONTAINS(tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(clase_mm, 'T - ') OR CONTAINS_SUBSTR(desc_mm, 'T - '));

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_SERVICIOS_ASIGNADOS_POR_CANAL_UPD` AS
  SELECT * EXCEPT(tipo_param) FROM tmp_logs_1 
  WHERE tipo_param = 'SERVICIO' 
    AND NOT (REGEXP_CONTAINS(tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(clase_mm, 'T - ') OR CONTAINS_SUBSTR(desc_mm, 'T - '));

  -- C. Update Directo (Seguro porque tmp_param_canal es única)
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap = p.orden_sap
  FROM tmp_param_canal p
  WHERE c.marca_ds = p.marca_ds AND c.canal = p.canal
    AND (p.subcanal = 'X' OR c.subcanal = p.subcanal)
    AND (p.marco_retributivo = 'X' OR c.marco_retributivo = p.marco_retributivo)
    AND c.orden_sap IS NULL
    AND (
      (p.tipo = 'TERMINAL' AND (REGEXP_CONTAINS(c.tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') OR CONTAINS_SUBSTR(c.desc_mm, 'T - ')))
      OR 
      (p.tipo = 'SERVICIO' AND NOT (REGEXP_CONTAINS(c.tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') OR CONTAINS_SUBSTR(c.desc_mm, 'T - ')))
    );

  DROP TABLE IF EXISTS tmp_logs_1;

  --------------------------------------------------------------------------------
  -- PASO 2: ASIGNACIÓN MR TVT UPS
  --------------------------------------------------------------------------------

  -- A. Detectar candidatos
  CREATE TEMP TABLE tmp_logs_2 AS
  SELECT c.*, p.tipo as tipo_param
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  JOIN tmp_param_tvt p 
    ON c.marca_ds = p.marca_ds AND c.canal = p.canal
    AND (p.subcanal = 'X' OR c.subcanal = p.subcanal)
    AND (p.marco_retributivo = 'X' OR c.marco_retributivo = p.marco_retributivo)
  WHERE c.orden_sap IS NULL;

  -- B. Generar Logs
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_TERMINALES_ASIGNADOS_POR_MR_TVT_UPS_UPD` AS  
  SELECT * EXCEPT(tipo_param) FROM tmp_logs_2
  WHERE tipo_param = 'TERMINAL' 
    AND (REGEXP_CONTAINS(tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(clase_mm, 'T - ') OR CONTAINS_SUBSTR(desc_mm, 'T - '));

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_SERVICIOS_ASIGNADOS_POR_MR_TVT_UPS_UPD` AS  
  SELECT * EXCEPT(tipo_param) FROM tmp_logs_2
  WHERE tipo_param = 'SERVICIO' 
    AND NOT (REGEXP_CONTAINS(tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(clase_mm, 'T - ') OR CONTAINS_SUBSTR(desc_mm, 'T - '));

  -- C. Update Directo
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap = p.orden_sap
  FROM tmp_param_tvt p
  WHERE c.marca_ds = p.marca_ds AND c.canal = p.canal
    AND (p.subcanal = 'X' OR c.subcanal = p.subcanal)
    AND (p.marco_retributivo = 'X' OR c.marco_retributivo = p.marco_retributivo)
    AND c.orden_sap IS NULL
    AND (
      (p.tipo = 'TERMINAL' AND (REGEXP_CONTAINS(c.tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') OR CONTAINS_SUBSTR(c.desc_mm, 'T - ')))
      OR 
      (p.tipo = 'SERVICIO' AND NOT (REGEXP_CONTAINS(c.tipoMovimiento, regex_terminal) OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') OR CONTAINS_SUBSTR(c.desc_mm, 'T - ')))
    );

  DROP TABLE IF EXISTS tmp_logs_2;

  --------------------------------------------------------------------------------
  -- PASO 3: CORRECTIVO INDEPENDIENTE
  --------------------------------------------------------------------------------

  -- A. Log
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_COMISIONES_ASIGNADOS_POR_DESC_MM` AS  
  SELECT c.* FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  JOIN tmp_param_corr p
    ON c.marca_ds = p.marca_ds AND c.desc_mm = p.desc_mm 
    AND (p.segmento_ds = 'X' OR c.segmento = p.segmento_ds);

  -- B. Update
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap = p.orden_sap  
  FROM tmp_param_corr p
  WHERE c.marca_ds = p.marca_ds AND c.desc_mm = p.desc_mm 
    AND (p.segmento_ds = 'X' OR c.segmento = p.segmento_ds)
    AND (c.orden_sap IS DISTINCT FROM p.orden_sap); -- Evita updates innecesarios

END