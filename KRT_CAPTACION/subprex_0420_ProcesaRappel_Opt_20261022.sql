BEGIN

    /* =========================================================================================
       PASO 1: UNIFICACIÓN DE BORRADOS (EXCLUSIONES POR CATÁLOGO Y POR OFERTA/PROMO)
       Agrupamos la lógica de los pasos 0420 y 0430 en una sola pasada de DELETE.
       ========================================================================================= */
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    WHERE (LOWER(c.concepto_ds) LIKE '%rappel teorico%' OR LOWER(c.concepto_ds) LIKE '%rappel diferencia%')
      AND (
          -- Condición 1: Exclusión por Ofertas y Promociones (Antiguo Paso 0430)
          c.grid IN (8, 9)
          
          -- Condición 2: Exclusión por Catálogo específico (Antiguo Paso 0420)
          OR EXISTS (
              SELECT 1 
              FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c2
              INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXCLUSION_RAPPELxCATALOGO` r
                  ON r.marca_ds = c2.marca_ds AND TRIM(r.catalogo_id) = TRIM(c2.catalogo_id)
              WHERE c2.marca_ds = c.marca_ds 
                AND c2.cliente_id = c.cliente_id 
                AND c2.servicio_id = c.servicio_id
          )
      );


    /* =========================================================================================
       PASO 2: ACTUALIZACIÓN DE PONDERACIONES (Antiguo Paso 0425)
       Actualizamos directamente cruzando con la tabla de parámetros, sin materializar logs.
       ========================================================================================= */
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    SET c.importe = c.importe * ponderacion_data.ponderacion   
    FROM (
        SELECT DISTINCT c2.marca_ds, c2.cliente_id, c2.servicio_id, r.ponderacion 
        FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c2
        INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_PONDERA_RAPPELxCANALxCATALOGO` r
            ON r.marca_ds = c2.marca_ds 
            AND (UPPER(TRIM(r.canal)) = 'X' OR UPPER(TRIM(r.canal)) = c2.canal_alta_ds)
            AND (UPPER(TRIM(r.subcanal)) = 'X' OR UPPER(TRIM(r.subcanal)) = c2.subcanal_ds)
            AND UPPER(TRIM(r.catalogo_id)) = UPPER(TRIM(c2.catalogo_id))
    ) ponderacion_data
    WHERE c.marca_ds = ponderacion_data.marca_ds 
      AND c.cliente_id = ponderacion_data.cliente_id 
      AND c.servicio_id = ponderacion_data.servicio_id 
      AND (LOWER(c.concepto_ds) LIKE '%rappel teorico%' OR LOWER(c.concepto_ds) LIKE '%rappel diferencia%');

END