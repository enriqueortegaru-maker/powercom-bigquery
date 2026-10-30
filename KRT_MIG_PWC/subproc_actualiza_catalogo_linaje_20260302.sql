BEGIN
    DECLARE i INT64 DEFAULT 0;
    DECLARE target_proj STRING;
    DECLARE target_data STRING;
    DECLARE sql_query STRING;

    WHILE i < ARRAY_LENGTH(targets) DO
        SET target_proj = targets[OFFSET(i)].project_id;
        SET target_data = targets[OFFSET(i)].dataset_id;

        -- Limpieza previa
        DELETE FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE` 
        WHERE source_project = target_proj AND source_dataset = target_data 
          AND DATE(extraction_timestamp) = CURRENT_DATE();

        SET sql_query = FORMAT("""
            INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
            WITH 
            -- 1. GLOBAL SIGNATURES
            Global_Signatures AS (
                SELECT 
                    specific_catalog AS project_name, specific_schema AS dataset_name, specific_name AS object_name,
                    ARRAY_AGG(parameter_name ORDER BY ordinal_position) AS param_names,
                    ARRAY_AGG(data_type ORDER BY ordinal_position) AS param_types
                FROM `%s.%s.INFORMATION_SCHEMA.PARAMETERS`
                WHERE specific_catalog = '%s' AND parameter_name IS NOT NULL
                GROUP BY 1, 2, 3
            ),
            -- 2. TABLE SCHEMAS
            Table_Schemas AS (
                SELECT 
                    table_catalog AS project_name, table_schema AS dataset_name, table_name AS object_name,
                    ARRAY_AGG(column_name ORDER BY ordinal_position) AS col_names,
                    ARRAY_AGG(data_type ORDER BY ordinal_position) AS col_types
                FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS`
                WHERE table_catalog = '%s'
                GROUP BY 1, 2, 3
            ),
            -- 3. OBJECT CATALOG
            Object_Catalog AS (
                SELECT table_schema AS dataset_name, UPPER(table_name) AS object_name, table_type AS object_type 
                FROM `%s.%s.INFORMATION_SCHEMA.TABLES` WHERE table_catalog = '%s'
                UNION ALL
                SELECT routine_schema AS dataset_name, UPPER(routine_name) AS object_name, routine_type AS object_type 
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES` WHERE routine_catalog = '%s'
            ),
            -- 4. ROUTINE FULL INFO
            Routine_Full_Info AS (
                SELECT routine_catalog, routine_schema, routine_name, routine_definition, created, last_altered
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES`
                WHERE routine_catalog = '%s'
            ),
            -- 5. TABLE METADATA (CON VOLUMETRÍA)
            Table_Metadata AS (
                SELECT 
                    t.table_catalog AS project_name, 
                    t.table_schema AS dataset_name, 
                    t.table_name AS object_name, 
                    t.creation_time, 
                    t.table_type,
                    s.total_rows AS row_count, 
                    s.total_logical_bytes AS size_bytes 
                FROM `%s.%s.INFORMATION_SCHEMA.TABLES` t
                LEFT JOIN `%s.%s.INFORMATION_SCHEMA.TABLE_STORAGE` s
                  ON t.table_schema = s.table_schema AND t.table_name = s.table_name
                WHERE t.table_catalog = '%s'
            ),
            -- 6. RAW EXTRACTIONS
            Raw_extractions AS (
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'CALL_CTX' AS context, match AS raw_ref
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'/\\*[\\s\\S]*?\\*/', ''), r'(?i)\\bCALL\\s+[`]?([\\w\\-\\.]+)[`]?')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'CREATE_CTX' AS context, match AS raw_ref
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'/\\*[\\s\\S]*?\\*/', ''), r'(?i)\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TEMP\\s+|TEMPORARY\\s+)?TABLE\\s*(?:IF\\s+NOT\\s+EXISTS\\s+)?[`]?([\\w\\-\\.]+)[`]?')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'DML_CTX' AS context, match AS raw_ref
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'/\\*[\\s\\S]*?\\*/', ''), r'(?i)(?:\\bINSERT\\s+INTO\\s+|\\bUPDATE\\s+|\\bDELETE\\s+FROM\\s+|\\bMERGE\\s+(?:INTO\\s+)?|\\bTRUNCATE\\s+TABLE\\s+)(?:[`]?([\\w\\-\\.]+)[`]?)')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'DATA_CTX' AS context, match AS raw_ref
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'/\\*[\\s\\S]*?\\*/', ''), r'(?i)(?:\\bFROM\\s+|\\bJOIN\\s+|\\bUSING\\s+)(?:[`]?([\\w\\-\\.\\`]+)[`]?)')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'FUNC_CTX' AS context, match AS raw_ref
                FROM `%s.%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'/\\*[\\s\\S]*?\\*/', ''), r'(?i)(?:[`]?([\\w\\-\\.]+)[`]?)\\s*\\(')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                AND NOT REGEXP_CONTAINS(match, r'(?i)\\b(IF|COUNT|SUM|AVG|MIN|MAX|CAST|EXTRACT|DATE|TIMESTAMP|SAFE_CAST|TRIM|UPPER|LOWER)\\b')
            ),
            -- 7. PARSING
            Parsed_References AS (
                SELECT src.*, SPLIT(REPLACE(src.raw_ref, '`', ''), '.') AS parts, ARRAY_LENGTH(SPLIT(src.raw_ref, '.')) AS num_parts
                FROM Raw_extractions src
            ),
            Detailed_Parsed AS (
                SELECT *,
                    CASE WHEN num_parts >= 3 THEN TRIM(parts[OFFSET(0)]) ELSE '%s' END AS inferred_project,
                    CASE WHEN num_parts >= 3 THEN TRIM(parts[OFFSET(1)]) WHEN num_parts = 2 THEN TRIM(parts[OFFSET(0)]) ELSE routine_schema END AS inferred_dataset,
                    UPPER(TRIM(parts[OFFSET(num_parts - 1)])) AS inferred_object_upper,
                    TRIM(parts[OFFSET(num_parts - 1)]) AS inferred_object_original
                FROM Parsed_References
            ),
            -- 8. RESOLUCIÓN
            Resolved_Deps AS (
                SELECT DISTINCT p.routine_name AS parent_proc, p.routine_definition, p.context, p.inferred_project AS project_name, p.inferred_dataset AS dataset_name, p.inferred_object_original AS object_name,
                CASE 
                    WHEN p.context = 'CREATE_CTX' THEN 'CREATED_TABLE'
                    WHEN p.context = 'DML_CTX' THEN 'MODIFIED_TABLE'
                    WHEN p.inferred_project != '%s' THEN 
                        CASE WHEN p.context = 'CALL_CTX' THEN 'PROCEDURE' WHEN p.context = 'DATA_CTX' THEN 'EXTERNAL_TABLE_OR_VIEW' WHEN p.context = 'FUNC_CTX' THEN 'FUNCTION' END
                    ELSE 
                        CASE 
                            WHEN cat.object_type = 'EXTERNAL' THEN 'EXTERNAL_TABLE_OR_VIEW'
                            WHEN cat.object_type IS NOT NULL THEN cat.object_type
                            WHEN p.context = 'DATA_CTX' AND p.num_parts > 1 THEN 'EXTERNAL_TABLE_OR_VIEW'
                            ELSE NULL 
                        END
                END AS final_object_type
                FROM Detailed_Parsed p
                LEFT JOIN Object_Catalog cat ON p.inferred_dataset = cat.dataset_name AND p.inferred_object_upper = cat.object_name
                WHERE (p.inferred_project != '%s') 
                   OR (p.inferred_project = '%s' AND (
                        cat.object_name IS NOT NULL 
                        OR p.context IN ('CREATE_CTX', 'DML_CTX')
                        OR (p.context = 'DATA_CTX' AND p.num_parts > 1)
                   ))
            ),
            -- 9. ENRIQUECIMIENTO
            Deps_With_Params AS (
                SELECT 
                    rd.*, 
                    COALESCE(sig.param_names, CAST([] AS ARRAY<STRING>)) AS dep_param_names, 
                    COALESCE(sig.param_types, CAST([] AS ARRAY<STRING>)) AS dep_param_types,
                    rm.routine_definition AS child_ddl,
                    DATE(rm.created) AS rout_created,
                    DATE(rm.last_altered) AS rout_modified,
                    DATE_DIFF(CURRENT_DATE(), DATE(rm.created), DAY) AS rout_ndays_cr,
                    DATE_DIFF(CURRENT_DATE(), DATE(rm.last_altered), DAY) AS rout_ndays_mod,
                    COALESCE(ts.col_names, CAST([] AS ARRAY<STRING>)) AS table_col_names,
                    COALESCE(ts.col_types, CAST([] AS ARRAY<STRING>)) AS table_col_types,
                    DATE(tm.creation_time) AS tab_created,
                    DATE_DIFF(CURRENT_DATE(), DATE(tm.creation_time), DAY) AS tab_ndays_cr,
                    tm.row_count AS tab_rows,
                    tm.size_bytes AS tab_size
                FROM Resolved_Deps rd
                LEFT JOIN Global_Signatures sig ON rd.project_name = sig.project_name AND rd.dataset_name = sig.dataset_name AND rd.object_name = sig.object_name
                LEFT JOIN Routine_Full_Info rm ON rd.project_name = rm.routine_catalog AND rd.dataset_name = rm.routine_schema AND rd.object_name = rm.routine_name
                LEFT JOIN Table_Schemas ts ON rd.project_name = ts.project_name AND rd.dataset_name = ts.dataset_name AND rd.object_name = ts.object_name
                LEFT JOIN Table_Metadata tm ON rd.project_name = tm.project_name AND rd.dataset_name = tm.dataset_name AND rd.object_name = tm.object_name
            ),

            -- 10. LISTA DE OBJETOS TOCADOS
            Touched_Objects_List AS (
                SELECT DISTINCT dataset_name, object_name
                FROM Resolved_Deps
                WHERE final_object_type IN ('CREATED_TABLE', 'MODIFIED_TABLE', 'BASE TABLE', 'VIEW', 'CLONE', 'EXTERNAL_TABLE_OR_VIEW', 'MATERIALIZED VIEW')
            ),

            -- 11. INVENTARIO ESTÁTICO (TOTAL)
            Static_Inventory AS (
                SELECT 
                    tm.project_name, tm.dataset_name, tm.object_name, tm.table_type,
                    COALESCE(ts.col_names, CAST([] AS ARRAY<STRING>)) AS table_col_names,
                    COALESCE(ts.col_types, CAST([] AS ARRAY<STRING>)) AS table_col_types,
                    DATE(tm.creation_time) AS tab_created,
                    DATE_DIFF(CURRENT_DATE(), DATE(tm.creation_time), DAY) AS tab_ndays_cr,
                    tm.row_count AS tab_rows, tm.size_bytes AS tab_size
                FROM Table_Metadata tm
                LEFT JOIN Table_Schemas ts ON tm.project_name = ts.project_name AND tm.dataset_name = ts.dataset_name AND tm.object_name = ts.object_name
            )

            -- 12. SALIDA FINAL
            -- PARTE A: LINAJE DE PROCEDIMIENTOS
            SELECT 
                CURRENT_TIMESTAMP() AS extraction_timestamp,
                '%s' AS source_project,
                '%s' AS source_dataset,
                STRUCT(
                    '%s' AS project_name, 
                    '%s' AS dataset_name, 
                    dwp.parent_proc AS object_name,
                    'PROCEDIMIENTO' AS tipo_objeto,
                    STRUCT(COALESCE(ANY_VALUE(parent_sig.param_names), CAST([] AS ARRAY<STRING>)) AS name, COALESCE(ANY_VALUE(parent_sig.param_types), CAST([] AS ARRAY<STRING>)) AS type) AS arguments,
                    ANY_VALUE(dwp.routine_definition) AS definition,
                    STRUCT(
                        DATE(ANY_VALUE(parent_rm.created)) AS created, DATE(ANY_VALUE(parent_rm.last_altered)) AS last_altered, 
                        DATE_DIFF(CURRENT_DATE(), DATE(ANY_VALUE(parent_rm.created)), DAY) AS days_created, DATE_DIFF(CURRENT_DATE(), DATE(ANY_VALUE(parent_rm.last_altered)), DAY) AS days_altered
                    ) AS metadata
                ) AS objeto_padre,
                
                ARRAY_AGG(
                    CASE 
                        WHEN dwp.final_object_type IN ('CREATED_TABLE', 'MODIFIED_TABLE', 'BASE TABLE', 'VIEW', 'CLONE', 'EXTERNAL_TABLE_OR_VIEW', 'MATERIALIZED VIEW') THEN
                            STRUCT(
                                dwp.project_name, dwp.dataset_name, dwp.object_name,
                                CASE 
                                    WHEN dwp.context = 'CREATE_CTX' THEN 'CREADA'
                                    WHEN dwp.context = 'DML_CTX' THEN 'MODIFICADA'
                                    WHEN dwp.context = 'DATA_CTX' THEN 'LEIDA'
                                    ELSE 'DESCONOCIDA'
                                END AS tipo_relacion,
                                STRUCT(dwp.table_col_names AS name, dwp.table_col_types AS type) AS columns,
                                STRUCT(dwp.tab_created AS created, CAST(NULL AS DATE) AS last_altered, dwp.tab_ndays_cr AS days_created, CAST(NULL AS INT64) AS days_altered, dwp.tab_rows AS num_rows, dwp.tab_size AS size_bytes) AS metadata
                            )
                        ELSE NULL 
                    END IGNORE NULLS
                ) AS dependencias_tablas,

                ARRAY_AGG(
                    CASE 
                        WHEN dwp.final_object_type IN ('PROCEDURE', 'FUNCTION', 'TABLE FUNCTION') THEN
                            STRUCT(
                                dwp.project_name, dwp.dataset_name, dwp.object_name,
                                CASE 
                                    WHEN dwp.context = 'CALL_CTX' THEN 'CALL'
                                    WHEN dwp.context = 'FUNC_CTX' THEN 'FUNCTION_CALL'
                                    WHEN dwp.final_object_type = 'TABLE FUNCTION' THEN 'TABLE_FUNCTION'
                                    ELSE 'OTRA_RUTINA'
                                END AS tipo_relacion,
                                STRUCT(dwp.dep_param_names AS name, dwp.dep_param_types AS type) AS arguments,
                                dwp.child_ddl AS definition,
                                STRUCT(dwp.rout_created AS created, dwp.rout_modified AS last_altered, dwp.rout_ndays_cr AS days_created, dwp.rout_ndays_mod AS days_altered) AS metadata
                            )
                        ELSE NULL 
                    END IGNORE NULLS
                ) AS dependencias_rutinas,
                
                ANY_VALUE(dwp.routine_definition) AS routine_definition_debug
            FROM Deps_With_Params dwp
            LEFT JOIN Global_Signatures parent_sig ON dwp.parent_proc = parent_sig.object_name AND parent_sig.dataset_name = '%s'
            LEFT JOIN Routine_Full_Info parent_rm ON dwp.parent_proc = parent_rm.routine_name AND parent_rm.routine_schema = '%s'
            GROUP BY dwp.parent_proc

            UNION ALL

            -- PARTE B: TABLAS HUERFANAS (CORREGIDO FILTRO DE DATASET)
            SELECT 
                CURRENT_TIMESTAMP() AS extraction_timestamp,
                '%s' AS source_project, 
                '%s' AS source_dataset,
                -- OBJETO PADRE: SIEMPRE EL MISMO PARA AGRUPARLAS LOGICAMENTE
                STRUCT(
                    '%s' AS project_name, '%s' AS dataset_name, 
                    'TABLAS_HUERFANAS' AS object_name, 'CONTENEDOR_HUERFANAS' AS tipo_objeto,
                    STRUCT(CAST([] AS ARRAY<STRING>) AS name, CAST([] AS ARRAY<STRING>) AS type) AS arguments,
                    'Contenedor de tablas no detectadas en el linaje de procedimientos' AS definition,
                    STRUCT(CAST(NULL AS DATE) AS created, CAST(NULL AS DATE) AS last_altered, CAST(NULL AS INT64) AS days_created, CAST(NULL AS INT64) AS days_altered) AS metadata
                ) AS objeto_padre,
                
                -- ARRAY DE 1 SOLO ELEMENTO (LA TABLA ACTUAL)
                [STRUCT(
                        si.project_name, si.dataset_name, si.object_name,
                        'HUERFANA' AS tipo_relacion,
                        STRUCT(si.table_col_names AS name, si.table_col_types AS type) AS columns,
                        STRUCT(si.tab_created AS created, CAST(NULL AS DATE) AS last_altered, si.tab_ndays_cr AS days_created, CAST(NULL AS INT64) AS days_altered, si.tab_rows AS num_rows, si.tab_size AS size_bytes) AS metadata
                )] AS dependencias_tablas,

                CAST([] AS ARRAY<STRUCT<project_name STRING, dataset_name STRING, object_name STRING, tipo_relacion STRING, arguments STRUCT<name ARRAY<STRING>, type ARRAY<STRING>>, definition STRING, metadata STRUCT<created DATE, last_altered DATE, days_created INT64, days_altered INT64>>>) AS dependencias_rutinas,
                
                'INVENTARIO_HUERFANAS' AS routine_definition_debug
            FROM Static_Inventory si
            LEFT JOIN Touched_Objects_List tol 
              ON si.object_name = tol.object_name AND si.dataset_name = tol.dataset_name
            WHERE tol.object_name IS NULL -- Solo las que NO fueron tocadas
            AND si.dataset_name = '%s' -- CORRECCIÓN CRÍTICA: Asegurar que solo insertamos las del dataset actual
        """, 
        -- LISTA DE ARGUMENTOS (55 en total - Se añadió 1 extra al final)
        -- 1. Global (3)
        target_proj, region_suffix, target_proj, 
        -- 2. Schemas (3)
        target_proj, region_suffix, target_proj,
        -- 3. Object Cat (6)
        target_proj, region_suffix, target_proj, target_proj, region_suffix, target_proj, 
        -- 4. Routine Info (3)
        target_proj, region_suffix, target_proj,
        -- 5. Table Meta (5)
        target_proj, region_suffix, target_proj, region_suffix, target_proj, 
        -- 6. Raw Extractions (20)
        target_proj, region_suffix, target_proj, target_data, 
        target_proj, region_suffix, target_proj, target_data, 
        target_proj, region_suffix, target_proj, target_data, 
        target_proj, region_suffix, target_proj, target_data, 
        target_proj, region_suffix, target_proj, target_data, 
        -- 7. Parsing Logic (1)
        target_proj, 
        -- 8. Resolution Logic (3)
        target_proj, target_proj, target_proj, 
        -- 9. Output A (Linaje) (6)
        target_proj, target_data, target_proj, target_data, target_data, target_data, 
        -- 10. Output B (Orphans) (5 - SE AÑADE target_data AL FINAL)
        target_proj, target_data, target_proj, target_data, target_data 
        );

        EXECUTE IMMEDIATE sql_query;
        SET i = i + 1;
    END WHILE;
END