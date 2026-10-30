BEGIN

  /*
  --- OPTIMIZACIÓN ---
  Se ha reemplazado el patrón de (CREATE LOG_EXCLUIR -> DELETE FROM TABLA)
  por un solo (CREATE OR REPLACE TABLA AS SELECT ... WHERE NOT EXISTS ...).
  Este enfoque es atómico y mucho más eficiente en BigQuery, ya que evita
  el uso de DML (DELETE) y reduce el número de operaciones de 6 a 2.
  */

  --- PASO 1: Reescribir MARCO_RETRIBUTIVO_TIENDASxCANAL excluyendo las ventas de agentes
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
  SELECT e.* -- Se recomienda listar columnas explícitamente en lugar de SELECT *
  FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS e
  WHERE NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_EXCLUSION_AGENTE_VENTAS` AS x
    WHERE
      x.marca_ds = e.marca_ds
      -- Lógica booleana simplificada (reemplaza el CASE WHEN ... THEN TRUE ELSE FALSE)
      AND (TRIM(UPPER(x.canal)) = "X" OR TRIM(UPPER(x.canal)) = TRIM(UPPER(e.canal)))
      AND (TRIM(UPPER(x.subcanal)) = "X" OR TRIM(UPPER(x.subcanal)) = TRIM(UPPER(e.subcanal)))
      AND (TRIM(UPPER(x.marco_retributivo)) = "X" OR TRIM(UPPER(x.marco_retributivo)) = TRIM(UPPER(e.marco_retributivo)))
      AND (TRIM(UPPER(x.agente)) = "X" OR TRIM(UPPER(x.agente)) = TRIM(UPPER(e.agente)))
      AND UPPER(TRIM(x.agente_creador_id)) = UPPER(TRIM(e.agente_creador_id))
  );

  --- PASO 2: Reescribir MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA excluyendo las ventas de agentes
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS
  SELECT e.* -- Se recomienda listar columnas explícitamente en lugar de SELECT *
  FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS e
  WHERE NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_EXCLUSION_AGENTE_VENTAS` AS x
    WHERE
      x.marca_ds = e.marca_ds
      AND (TRIM(UPPER(x.canal)) = "X" OR TRIM(UPPER(x.canal)) = TRIM(UPPER(e.canal)))
      AND (TRIM(UPPER(x.subcanal)) = "X" OR TRIM(UPPER(x.subcanal)) = TRIM(UPPER(e.subcanal)))
      AND (TRIM(UPPER(x.marco_retributivo)) = "X" OR TRIM(UPPER(x.marco_retributivo)) = TRIM(UPPER(e.marco_retributivo)))
      AND (TRIM(UPPER(x.agente)) = "X" OR TRIM(UPPER(x.agente)) = TRIM(UPPER(e.agente)))
      AND UPPER(TRIM(x.agente_creador_id)) = UPPER(TRIM(e.agente_creador_id))
  );

END