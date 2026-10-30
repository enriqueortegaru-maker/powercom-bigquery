BEGIN

  --CALL `mm-commissions-reporting.KRT_MIG_PWC.audit_compare_tables`('mm-commissions-reporting', 'KRT_SAP', 'SAP_FACTURA_APUNTES_EX', 'mm-commissions-reporting',  'KRT_SAP', 'SAP_FACTURA_APUNTES');

  -- Declaramos variables
  DECLARE ref_a STRING;
  DECLARE ref_b STRING;
  DECLARE query_metrics STRING;
  DECLARE query_details STRING;

  -- Construimos referencias
  SET ref_a = FORMAT('`%s.%s.%s`', project_a, dataset_a, table_a);
  SET ref_b = FORMAT('`%s.%s.%s`', project_b, dataset_b, table_b);

  -- ---------------------------------------------------------
  -- 1. CONSULTA DE CONTABILIDAD (MÉTRICAS)
  -- NOTA: Usamos TO_JSON_STRING(t) para poder comparar Arrays
  -- ---------------------------------------------------------
  SET query_metrics = FORMAT("""
    SELECT
      'Resumen de Auditoría (Soporte Array)' as concepto,
      (SELECT COUNT(*) FROM %s) as total_registros_A,
      (SELECT COUNT(*) FROM %s) as total_registros_B,
      -- Registros en A que NO están en B (Comparando el JSON de la fila)
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t 
          EXCEPT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t
      )) as solo_en_A,
      -- Registros en B que NO están en A
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t 
          EXCEPT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t
      )) as solo_en_B,
      -- Registros idénticos
      (SELECT COUNT(*) FROM (
          SELECT TO_JSON_STRING(t) FROM %s AS t 
          INTERSECT DISTINCT 
          SELECT TO_JSON_STRING(t) FROM %s AS t
      )) as en_ambas_tablas
  """, ref_a, ref_b, ref_a, ref_b, ref_b, ref_a, ref_a, ref_b);

  EXECUTE IMMEDIATE query_metrics;

  -- ---------------------------------------------------------
  -- 2. CONSULTA DE DETALLE
  -- Devuelve la fila completa en formato JSON para evitar el error de Array
  -- ---------------------------------------------------------
  SET query_details = FORMAT("""
    SELECT 
        fila_json, 
        'SOLO EN TABLA A' as origen_diferencia 
    FROM (
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t
      EXCEPT DISTINCT
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t
    )
    UNION ALL
    SELECT 
        fila_json, 
        'SOLO EN TABLA B' as origen_diferencia 
    FROM (
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t
      EXCEPT DISTINCT
      SELECT TO_JSON_STRING(t) as fila_json FROM %s AS t
    )
    order by 1,2
  """, ref_a, ref_b, ref_b, ref_a);

  EXECUTE IMMEDIATE query_details;

END