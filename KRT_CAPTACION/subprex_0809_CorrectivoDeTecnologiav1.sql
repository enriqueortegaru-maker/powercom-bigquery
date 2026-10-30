BEGIN

    ------------------------------------------------------------------------------
    --- PASO 1 : CORRECTIVO UNIFICADO (Energía y Gas)
    ------------------------------------------------------------------------------
    
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    SET tecnologia_detalle_ds = CASE 
        WHEN detalle_Servicio_ds IN ('ELECTRICIDAD', 'SVE') THEN 'ELECTRICIDAD'
        WHEN detalle_Servicio_ds IN ('GAS', 'SVG') THEN 'GAS'
        -- La tercera condición (concepto "energia") se evalúa solo si no entró en las anteriores
        WHEN CONTAINS_SUBSTR(concepto_ds, 'energia') THEN 'ELECTRICIDAD'
        ELSE tecnologia_detalle_ds -- Por seguridad, aunque el WHERE filtra
    END
    WHERE (tecnologia_detalle_ds IS NULL OR LENGTH(tecnologia_detalle_ds) < 2)
    AND (
        detalle_Servicio_ds IN ('ELECTRICIDAD', 'SVE', 'GAS', 'SVG')
        OR CONTAINS_SUBSTR(concepto_ds, 'energia')
    );

    ------------------------------------------------------------------------------
    --- PASO 2 : RECUPERACIÓN DESDE MAESTRO DE SERVICIOS
    ------------------------------------------------------------------------------
    
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    SET c.tecnologia_detalle_ds = s.tecnologia_detalle_ds
    FROM ( 
        -- Mantenemos el DISTINCT por si el maestro tiene duplicados
        SELECT DISTINCT marca_ds, cliente_id, servicio_id, tecnologia_detalle_ds 
        FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`  
        WHERE tecnologia_detalle_ds IS NOT NULL 
          AND LENGTH(tecnologia_detalle_ds) >= 2 -- Filtramos origen sucio antes del JOIN
    ) s
    WHERE s.marca_ds = c.marca_ds
      AND s.cliente_id = c.cliente_id
      AND s.servicio_id = c.servicio_id
      AND (c.tecnologia_detalle_ds IS NULL OR LENGTH(c.tecnologia_detalle_ds) < 2);

END