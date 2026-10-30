BEGIN

  DECLARE vMES_COMISION_DT DATE;
  SET vMES_COMISION_DT = PARSE_DATE('%Y%m%d', CAST(DESDE AS STRING));

  /*
  --- OPTIMIZACIÓN ---
  Se ha reemplazado el patrón (CREATE LOG -> INSERT LOG -> DELETE FROM TABLA)
  por un solo (CREATE OR REPLACE TABLA AS SELECT ... WHERE NOT (logica_1 OR logica_2)).
  Este enfoque es atómico y mucho más eficiente en BigQuery.

  La tabla de log 'LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA' (que
  contenía solo las filas a borrar) ya no es necesaria y se ha eliminado.
  */

  --- PASO 1: Reescribir la tabla principal, excluyendo los registros en un solo paso
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
  SELECT a.* -- Se recomienda listar columnas explícitamente en lugar de SELECT *
  FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS a
  WHERE (
    
    -- Lógica de exclusión 1 (del primer CREATE TABLE LOG...)
    NOT EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_DETALLADO` AS b
      WHERE a.marca_ds = b.marca_ds 
        AND a.dni_cif = b.cif_nif
        AND a.canal = b.canal_alta_ds
        AND a.subcanal = b.subcanal_ds
        AND a.nombre_distribuidor = b.nombre_distribuidor_alta_ds
        -- Lógica compleja del catálogo (Corregida a sintaxis BQ Standard SQL)
        AND (
          (a.TipoProducto = b.categoria_servicio_ds) OR
          (
            (SPLIT(TRIM(UPPER(b.catalogo_id)),'/')[SAFE_OFFSET(0)] = TRIM(UPPER(a.idcatalogo))) OR
            (CASE 
               WHEN ARRAY_LENGTH(SPLIT(TRIM(UPPER(b.catalogo_id)),'/')) > 1 
               THEN SPLIT(TRIM(UPPER(b.catalogo_id)),'/')[SAFE_OFFSET(1)] 
             END = TRIM(UPPER(a.idcatalogo)))
          )
        )
        AND ABS(a.IdProducto - b.servicio_id) <= 20
    )

  );


  --- PASO 2: Crear el LOG snapshot de la tabla ya filtrada
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0202_MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`;



  --- PASO 3: Reescribir la tabla principal, excluyendo los registros en un solo paso
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS
  SELECT a.* -- Se recomienda listar columnas explícitamente en lugar de SELECT *
  FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS a
  WHERE (
    
    -- Lógica de exclusión 1 (del primer CREATE TABLE LOG...)
    NOT EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_DETALLADO` AS b
      WHERE a.marca_ds = b.marca_ds 
        AND a.dni_cif = b.cif_nif
        AND a.canal = b.canal_alta_ds
        AND a.subcanal = b.subcanal_ds
        AND a.nombre_distribuidor = b.nombre_distribuidor_alta_ds
        -- Lógica compleja del catálogo (Corregida a sintaxis BQ Standard SQL)
        AND (
          (a.TipoProducto = b.categoria_servicio_ds) OR
          (
            (SPLIT(TRIM(UPPER(b.catalogo_id)),'/')[SAFE_OFFSET(0)] = TRIM(UPPER(a.idcatalogo))) OR
            (CASE 
               WHEN ARRAY_LENGTH(SPLIT(TRIM(UPPER(b.catalogo_id)),'/')) > 1 
               THEN SPLIT(TRIM(UPPER(b.catalogo_id)),'/')[SAFE_OFFSET(1)] 
             END = TRIM(UPPER(a.idcatalogo)))
          )
        )
        AND ABS(a.IdProducto - b.servicio_id) <= 20
    )

  );


  --- PASO 2: Crear el LOG snapshot de la tabla ya filtrada
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0202_MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA`;


END