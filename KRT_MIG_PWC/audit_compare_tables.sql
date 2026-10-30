BEGIN

  -- Declaramos variables
  DECLARE ref_a STRING;
  DECLARE ref_b STRING;
  DECLARE audit_table_ref STRING;
  
  DECLARE query_metrics STRING;
  DECLARE query_details STRING;
  
  DECLARE common_part STRING DEFAULT '';
  DECLARE i INT64 DEFAULT 1;

  -- Construimos referencias a las tablas de origen
  SET ref_a = FORMAT('`%s.%s.%s`', project_a, dataset_a, table_a);
  SET ref_b = FORMAT('`%s.%s.%s`', project_b, dataset_b, table_b);

  -- ---------------------------------------------------------
  -- 0. CALCULAR LA PARTE COMÚN DEL NOMBRE (SUFIJO/PREFIJO)
  -- ---------------------------------------------------------
  -- Comparamos carácter por carácter hasta encontrar la primera diferencia
  WHILE i <= LENGTH(table_a) AND i <= LENGTH(table_b) AND SUBSTR(table_a, i, 1) = SUBSTR(table_b, i, 1) DO
    SET common_part = CONCAT(common_part, SUBSTR(table_a, i, 1));
    SET i = i + 1;
  END WHILE;
  
  -- Limpiamos guiones bajos finales si la partición corta justo ahí (ej. SAP_FACTURA_APUNTES_)
  SET common_part = RTRIM(common_part, '_');
  
  -- Si por alguna razón no tienen nada en común, concatenamos los nombres
  IF common_part = '' THEN
    SET common_part = CONCAT(table_a, '_vs_', table_b);
  END IF;

  -- Construimos la referencia de la tabla de destino (se guarda en dataset_a)
  SET audit_table_ref = FORMAT('`%s.%s.AUDIT_%s`', project_a, dataset_a, common_part);

  -- ---------------------------------------------------------
  -- 1. CONSULTA DE CONTABILIDAD (MÉTRICAS)
  -- ---------------------------------------------------------
  SET query_metrics = FORMAT("""
    SELECT
      'Resumen de Auditoría (Soporte Array)' as concepto,
      (SELECT COUNT(*) FROM %s) as total_registros_A,
      (SELECT COUNT(*) FROM %s) as total_registros_B,
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t 
          EXCEPT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t
      )) as solo_en_A,
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t 
          EXCEPT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t
      )) as solo_en_B,
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t 
          INTERSECT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t
      )) as en_ambas_tablas
  """, ref_a, ref_b, ref_a, ref_b, ref_b, ref_a, ref_a, ref_b);

  EXECUTE IMMEDIATE query_metrics;

  -- ---------------------------------------------------------
  -- 2. CREACIÓN DE LA TABLA DE AUDITORÍA (CON CADUCIDAD DE 7 DÍAS)
  -- ---------------------------------------------------------
  -- Usamos NOT EXISTS comparando el JSON para que el SELECT * nos devuelva 
  -- el esquema original intacto (manteniendo Arrays, Structs, Dates, etc.)
  SET query_details = FORMAT("""
    CREATE OR REPLACE TABLE %s
    OPTIONS(
      expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY),
      description = 'Tabla de auditoría de diferencias. Expira en 7 días.'
    ) AS
    SELECT *, 'SOLO EN TABLA A' AS CAUSA
    FROM %s AS a
    WHERE NOT EXISTS (
        SELECT 1 FROM %s AS b 
        WHERE TO_JSON_STRING(a) = TO_JSON_STRING(b)
    )
    UNION ALL
    SELECT *, 'SOLO EN TABLA B' AS CAUSA
    FROM %s AS b
    WHERE NOT EXISTS (
        SELECT 1 FROM %s AS a 
        WHERE TO_JSON_STRING(b) = TO_JSON_STRING(a)
    )
  """, audit_table_ref, ref_a, ref_b, ref_b, ref_a);

  EXECUTE IMMEDIATE query_details;
  
  -- ---------------------------------------------------------
  -- 3. (OPCIONAL) MOSTRAR LOS DATOS DE LA NUEVA TABLA EN CONSOLA
  -- ---------------------------------------------------------
  -- Para que sigas viendo el detalle en la pestaña de resultados al ejecutarlo
  EXECUTE IMMEDIATE FORMAT('SELECT * FROM %s ORDER BY CAUSA', audit_table_ref);

END