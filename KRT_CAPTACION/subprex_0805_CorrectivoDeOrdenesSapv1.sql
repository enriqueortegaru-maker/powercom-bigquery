BEGIN

    ------------------------------------------------------------------------------
    ---
    ---   APLICA AL COMISIONADO DEº
    ---     SOMO: A - Servicio movil Postpago No Convergente (SOMO)
    ---         E - Clawback Servicio movil Postpago No Convergente (SOMO)
    ---     ALARMA  B - Alarma
    ---         PDTE DECOMISIONADO ALARMA 
    ------------------------------------------------------------------------------

    -- 1. Pre-cargar parámetros para evitar lecturas repetitivas y asegurar tipos
    CREATE OR REPLACE TEMP TABLE tmp_params AS
    SELECT DISTINCT
        marca_ds,
        desc_mm,
        segmento_ds,
        orden_sap
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP`;

    ------------------------------------------------------------------------------
    --- PASO 1 : UNITARIOS
    ------------------------------------------------------------------------------
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c
    SET c.orden_sap = p.orden_sap  
    FROM tmp_params p
    WHERE c.marca_ds = p.marca_ds 
      AND c.desc_mm = p.desc_mm 
      -- Optimización lógica: Booleanos en lugar de CASE WHEN
      AND (p.segmento_ds = 'X' OR c.segmento_ds = p.segmento_ds)
      -- Optimización de costes: Solo actualizar si el valor es diferente
      AND (c.orden_sap IS DISTINCT FROM p.orden_sap);

    ------------------------------------------------------------------------------
    --- PASO 2 : COMISIONES
    ------------------------------------------------------------------------------
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    SET c.orden_sap = p.orden_sap  
    FROM tmp_params p
    WHERE c.marca_ds = p.marca_ds 
      AND c.desc_mm = p.desc_mm 
      AND (p.segmento_ds = 'X' OR c.segmento_ds = p.segmento_ds)
      AND (c.orden_sap IS DISTINCT FROM p.orden_sap);

    ------------------------------------------------------------------------------
    --- PASO 3 : DECOMISIONES (CLAWBACK_6M)
    ------------------------------------------------------------------------------
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_6M` c
    SET c.orden_sap = p.orden_sap  
    FROM tmp_params p
    WHERE c.marca_ds = p.marca_ds 
      AND c.desc_mm = p.desc_mm 
      AND (p.segmento_ds = 'X' OR c.segmento_ds = p.segmento_ds)
      AND (c.orden_sap IS DISTINCT FROM p.orden_sap);

    ------------------------------------------------------------------------------
    --- PASO 4 : DECOMISIONES (CLAWBACK_24M)
    ------------------------------------------------------------------------------
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M` c
    SET c.orden_sap = p.orden_sap  
    FROM tmp_params p
    WHERE c.marca_ds = p.marca_ds 
      AND c.desc_mm = p.desc_mm 
      AND (p.segmento_ds = 'X' OR c.segmento_ds = p.segmento_ds)
      AND (c.orden_sap IS DISTINCT FROM p.orden_sap);

    ------------------------------------------------------------------------------
    --- PASO 5 : DECOMISIONES (CLAWBACK GENERAL)
    ------------------------------------------------------------------------------
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
    SET c.orden_sap = p.orden_sap  
    FROM tmp_params p
    WHERE c.marca_ds = p.marca_ds 
      AND c.desc_mm = p.desc_mm 
      AND (p.segmento_ds = 'X' OR c.segmento_ds = p.segmento_ds)
      AND (c.orden_sap IS DISTINCT FROM p.orden_sap);

END