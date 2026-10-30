BEGIN
--CALL `mm-commissions-reporting.KRT_MIG_PWC.audit_compare_tables_partition`('mm-commissions-reporting', 'KRT_SAP', 'SAP_FACTURA_APUNTES_EX', 'mm-commissions-reporting',  'KRT_SAP', 'SAP_FACTURA_APUNTES','mes_factura_dt','2026-01-01');

  DECLARE ref_a STRING;
  DECLARE ref_b STRING;
  DECLARE filter_clause STRING;
  DECLARE query_metrics STRING;
  DECLARE query_details STRING;

  -- 1. Construcción de referencias de tabla
  SET ref_a = FORMAT('`%s.%s.%s`', project_a, dataset_a, table_a);
  SET ref_b = FORMAT('`%s.%s.%s`', project_b, dataset_b, table_b);

  -- 2. Construcción del filtro de partición (CLAVE PARA LA OPTIMIZACIÓN)
  -- Formateamos la fecha para que sea un literal seguro en el SQL dinámico: "WHERE campo = '2023-01-01'"
  SET filter_clause = FORMAT("WHERE %s = '%t'", partition_field, analysis_date);

  -- ---------------------------------------------------------
  -- 3. CONSULTA DE MÉTRICAS (OPTIMIZADA)
  -- Se aplica el filtro WHERE dentro de cada sub-select para asegurar Partition Pruning
  -- ---------------------------------------------------------
  SET query_metrics = FORMAT("""
    SELECT
      'Auditoría Partición: %t' as concepto,
      -- Conteo A (filtrado)
      (SELECT COUNT(*) FROM %s %s) as total_registros_A,
      -- Conteo B (filtrado)
      (SELECT COUNT(*) FROM %s %s) as total_registros_B,
      
      -- Solo en A
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t %s 
          EXCEPT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t %s
      )) as solo_en_A,
      
      -- Solo en B
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t %s 
          EXCEPT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t %s
      )) as solo_en_B,
      
      -- En ambas
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t %s 
          INTERSECT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t %s
      )) as en_ambas_tablas
  """, 
    analysis_date,
    ref_a, filter_clause, 
    ref_b, filter_clause,
    ref_a, filter_clause, ref_b, filter_clause, -- Para Solo en A
    ref_b, filter_clause, ref_a, filter_clause, -- Para Solo en B
    ref_a, filter_clause, ref_b, filter_clause  -- Para En ambas
  );

  EXECUTE IMMEDIATE query_metrics;

  -- ---------------------------------------------------------
  -- 4. CONSULTA DE DETALLES (OPTIMIZADA)
  -- ---------------------------------------------------------
  SET query_details = FORMAT("""
    SELECT 
        fila_json, 
        'SOLO EN TABLA A' as origen_diferencia 
    FROM (
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t %s
      EXCEPT DISTINCT
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t %s
    )
    UNION ALL
    SELECT 
        fila_json, 
        'SOLO EN TABLA B' as origen_diferencia 
    FROM (
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t %s
      EXCEPT DISTINCT
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t %s
    )
  """, 
    ref_a, filter_clause, ref_b, filter_clause,
    ref_b, filter_clause, ref_a, filter_clause
  );

  EXECUTE IMMEDIATE query_details;

END