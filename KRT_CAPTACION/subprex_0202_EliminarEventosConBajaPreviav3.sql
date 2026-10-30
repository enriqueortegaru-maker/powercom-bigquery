BEGIN
  
  DECLARE desde_id INT64;

  -- ----------------------------------------------------------------------
  -- Declaración de variables para fijar los umbrales por categoría
  -- ----------------------------------------------------------------------
  DECLARE vUmbral_BANDA_ANCHA INT64 DEFAULT 8;
  DECLARE vUmbral_MOVILES_POSTPAGO INT64 DEFAULT 16;
  DECLARE vUmbral_TERMINALES INT64 DEFAULT 16;
  DECLARE vUmbral_FIJA INT64 DEFAULT 8;
  DECLARE vUmbral_TELEVISION INT64 DEFAULT 8;
  
  -- Cálculo de fecha: Primer día del mes anterior a la fecha DESDE
  SET desde_id = CAST(FORMAT_DATE("%Y%m%d", DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m%d', CAST(DESDE AS STRING)), INTERVAL 1 MONTH), MONTH)) AS INT64);
  
  --- PASO 0: Creo Log previo
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0202_MARCO_RETRIBUTIVOxCANAL_PREV` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;
  
  --- PASO 1: Identifico registros específicos a borrar (Lógica 1 a 1 con control de umbrales)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` AS  
  WITH ConteoBajasPrevias AS (
    -- 1. Contamos cuántas bajas previas exactas tuvo el cliente por marca y categoría.
    SELECT 
      cliente_id,
      marca_ds,
      categoria_servicio_ds,
      COUNT(*) as num_bajas
    FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
    WHERE fecha_rfb_id < desde_id 
      AND fecha_baja_id BETWEEN desde_id AND HASTA 
      AND fecha_rfb_id < fecha_baja_id 
      AND servicio_id_destino < 0 
      AND CONTAINS_SUBSTR(operacion_baja_ds, "baja")
    GROUP BY 1, 2, 3
    -- Aplicamos los umbrales configurados por variable. Si el count es >= al umbral, 
    -- esa agrupación se descarta y no provocará borrado.
    HAVING COUNT(*) < CASE categoria_servicio_ds
                        WHEN 'BANDA ANCHA' THEN vUmbral_BANDA_ANCHA
                        WHEN 'MOVILES POSTPAGO' THEN vUmbral_MOVILES_POSTPAGO
                        WHEN 'TERMINALES' THEN vUmbral_TERMINALES
                        WHEN 'FIJA' THEN vUmbral_FIJA
                        WHEN 'TELEVISION' THEN vUmbral_TELEVISION
                        -- Para el resto no consideramos umbral (la condición siempre será TRUE)
                        ELSE COUNT(*) + 1 
                      END
  ),
  
  AltasRankeadas AS (
    -- 2. Numeramos las altas del mes en MARCO_RETRIBUTIVOxCANAL. 
    -- Priorizamos fecha_hora_venta, si es NULL usamos fecha_hora_activacion.
    SELECT
      A.*,
      ROW_NUMBER() OVER (
        PARTITION BY A.cliente_id, A.marca_ds, A.categoria_servicio_ds 
        ORDER BY COALESCE(A.fecha_venta_neta_dt, A.fecha_rfb_dt) DESC
      ) as rn
    FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` A
    -- Filtramos previamente solo los clientes que sabemos que tienen bajas para optimizar el OVER()
    WHERE EXISTS (
        SELECT 1 FROM ConteoBajasPrevias B 
        WHERE A.cliente_id = B.cliente_id 
          AND A.marca_ds = B.marca_ds 
          AND A.categoria_servicio_ds = B.categoria_servicio_ds
    )
  )
  -- 3. Nos quedamos SOLO con las altas cuyo número de ranking sea menor o igual al número de bajas
  -- Ejemplo: Si tuvo 1 baja y 2 altas, solo el alta con rn=1 (la de fecha más reciente) pasa a esta tabla.
  SELECT R.* EXCEPT(rn)
  FROM AltasRankeadas R
  JOIN ConteoBajasPrevias B
    ON R.cliente_id = B.cliente_id
   AND R.marca_ds = B.marca_ds
   AND R.categoria_servicio_ds = B.categoria_servicio_ds
  WHERE R.rn <= B.num_bajas;
  
  --- PASO 2: Ejecuto borrado selectivo de registros
  DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` uni
  WHERE EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` bp
    -- IMPORTANTE: Para que el borrado respete el 1 a 1, debes usar el identificador único del servicio.
    -- Sustituye 'servicio_id' por el campo único que utilices en la tabla MARCO_RETRIBUTIVOxCANAL.
    WHERE uni.servicio_id = bp.servicio_id 
  );
  
  --- PASO 3: Vuelco LOGS 
  -- Log de fichero completo      
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0202_MARCO_RETRIBUTIVOxCANAL` AS
  SELECT *
  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;
  
  -- Log de incremento (Borrados exactos)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0202_MARCO_RETRIBUTIVOxCANAL_DEL` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA`;
  
  --- PASO 4: Creo tabla UNITARIOS
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` AS
  SELECT *
  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;
    
END