BEGIN

  -- 1. LOG PREVIO
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0405_COMISIONES_PREVIO` AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

  -- 2. RECREACIÓN DE TABLA CON LÓGICA UNIFICADA PARA ACTUALIZACION EN BASE A CANALES Y EXTRAS
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
  WITH 
    -- Preparamos param canales
    p_canales AS (
      SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`
      WHERE NOT CONTAINS_SUBSTR(canal, "B2B")
    ),
    -- Preparamos param extras
    p_extras AS (
      SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`
      WHERE UPPER(TRIM(distribuir)) = "N"
        AND importe != 0
        AND orden_sap > 0
    )
  SELECT DISTINCT 
      c.*,      
      
      COALESCE(
        -- 1. Intento por Canales 
        CASE 
          WHEN REGEXP_CONTAINS(c.tipoMovimiento, r'(?i)equipamiento|terminal|dispositivo')
               OR CONTAINS_SUBSTR(c.clase_mm, 'T - ') 
               OR CONTAINS_SUBSTR(c.desc_mm, 'T - ') 
          THEN ca.orden_sap_terminales 
          ELSE ca.orden_sap_servicios 
        END,
        
        -- 2. Intento por Extras 
        -- Solo aplica si el anterior devolvió NULL
        CASE 
          WHEN c.clase_mm = "D - Extracomision"
               AND c.IdProducto IS NULL
          THEN pe.orden_sap
          ELSE NULL 
        END
      ) as orden_sap

  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  
  -- Join Canales
  LEFT JOIN p_canales ca 
    ON ca.marca_ds = c.marca_ds 
    AND ca.canal = c.canal 
    AND ca.subcanal = c.subcanal 
    AND ca.nombre_distribuidor = c.nombre_distribuidor 
    AND ca.agrupador_mr = c.MARCO_RETRIBUTIVO
  
  -- Join Extras
  LEFT JOIN p_extras pe
    ON pe.marca_ds = c.marca_ds
    AND pe.canal = c.canal
    AND pe.subcanal = c.subcanal
    AND pe.nombre_distribuidor = c.nombre_distribuidor
    AND pe.importe = c.bono_extras;

  -- 3. LOG FINAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0405_COMISIONES` AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

END