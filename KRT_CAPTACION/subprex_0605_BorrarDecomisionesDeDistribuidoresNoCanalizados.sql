BEGIN 

-- 1.LISTADO DE DISTRIBUIDORES
  CREATE TEMP TABLE LOG_0605_LISTA_BLANCA_TMP AS
  SELECT marca_ds, nombre_distribuidor_ds as nombre 
  FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES`
  UNION DISTINCT -- Usamos DISTINCT para reducir el volumen de comparaciones
  SELECT marca_ds, nombre_distribuidor as nombre 
  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`;

  -- 2. REGISTROS A BORRAR.
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0605_CLAWBACK_BORRADO_DECOMISIONES_NO_CANALIZADAS` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT c.*
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  WHERE NOT EXISTS (
    SELECT 1
    FROM LOG_0605_LISTA_BLANCA_TMP AS p
    WHERE p.marca_ds = c.marca_ds 
    AND `mm-commissions-reporting.KRT_CAPTACION.f_comparar_cadenas_normalizadas`(p.nombre, c.nombre_distribuidor_alta_ds)
  );

  -- 3. BORRADO
  DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  WHERE EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0605_CLAWBACK_BORRADO_DECOMISIONES_NO_CANALIZADAS` l
    WHERE c.marca_ds = l.marca_ds 
    AND c.nombre_distribuidor_alta_ds = l.nombre_distribuidor_alta_ds
    AND (c) = (l) 
  );

END