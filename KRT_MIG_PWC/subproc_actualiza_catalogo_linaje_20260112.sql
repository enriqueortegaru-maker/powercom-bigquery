BEGIN
    DECLARE i INT64 DEFAULT 0;
    DECLARE target_proj STRING;
    DECLARE target_data STRING;
    DECLARE sql_query STRING;

    WHILE i < ARRAY_LENGTH(targets) DO
        SET target_proj = targets[OFFSET(i)].project_id;
        SET target_data = targets[OFFSET(i)].dataset_id;

        -- 1. Limpieza previa
        DELETE FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE` 
        WHERE source_project = target_proj AND source_dataset = target_data;

        -- 2. Query Dinámica
        SET sql_query = FORMAT("""
            INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
            WITH 
            -- 1. GLOBAL SIGNATURES
            Global_Signatures AS (
                SELECT 
                    specific_catalog AS project_name, specific_schema AS dataset_name, specific_name AS object_name,
                    ARRAY_AGG(parameter_name ORDER BY ordinal_position) AS param_names,
                    ARRAY_AGG(data_type ORDER BY ordinal_position) AS param_types
                FROM `%s.INFORMATION_SCHEMA.PARAMETERS`
                WHERE specific_catalog = '%s' AND parameter_name IS NOT NULL
                GROUP BY 1, 2, 3
            ),
            -- 2. OBJECT CATALOG
            Object_Catalog AS (
                SELECT table_schema AS dataset_name, table_name AS object_name, table_type AS object_type 
                FROM `%s.INFORMATION_SCHEMA.TABLES` WHERE table_catalog = '%s'
                UNION ALL
                SELECT routine_schema AS dataset_name, routine_name AS object_name, routine_type AS object_type 
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` WHERE routine_catalog = '%s'
            ),
            -- 3. RAW EXTRACTIONS
            Raw_extractions AS (
                -- CALL Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'CALL_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(r.routine_definition, r'(?i)\\bCALL\\s+[`]?([\\w\\-\\.]+)[`]?')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                
                UNION ALL
                
                -- CREATE Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'CREATE_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(r.routine_definition, r'(?i)\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TEMP\\s+|TEMPORARY\\s+)?TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?[`]?([\\w\\-\\.]+)[`]?')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'

                UNION ALL
                
                -- DATA Context (Lectura)
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'DATA_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(r.routine_definition, r'(?i)(?:\\bFROM\\s+|\\bJOIN\\s+)(?:[`]?([\\w\\-\\.]+)[`]?)')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                
                UNION ALL
                
                -- FUNC Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'FUNC_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(r.routine_definition, r'(?i)(?:[`]?([\\w\\-\\.]+)[`]?)\\s*\\(')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                AND NOT REGEXP_CONTAINS(match, r'(?i)\\b(IF|COUNT|SUM|AVG|MIN|MAX|CAST|EXTRACT|DATE|TIMESTAMP|SAFE_CAST|TRIM|UPPER|LOWER)\\b')
            ),
            -- 4. PARSING
            Parsed_References AS (
                SELECT src.*, SPLIT(src.raw_ref, '.') AS parts, ARRAY_LENGTH(SPLIT(src.raw_ref, '.')) AS num_parts
                FROM Raw_extractions src
            ),
            Detailed_Parsed AS (
                SELECT *,
                    CASE WHEN num_parts >= 3 THEN TRIM(parts[OFFSET(0)]) ELSE '%s' END AS inferred_project,
                    CASE WHEN num_parts >= 3 THEN TRIM(parts[OFFSET(1)]) WHEN num_parts = 2 THEN TRIM(parts[OFFSET(0)]) ELSE routine_schema END AS inferred_dataset,
                    TRIM(parts[OFFSET(num_parts - 1)]) AS inferred_object
                FROM Parsed_References
            ),
            -- 5. RESOLUCIÓN
            Resolved_Deps AS (
                SELECT DISTINCT p.routine_name AS parent_proc, p.routine_definition, p.context, p.inferred_project AS project_name, p.inferred_dataset AS dataset_name, p.inferred_object AS object_name,
                CASE 
                    WHEN p.context = 'CREATE_CTX' THEN 'CREATED_TABLE' 
                    WHEN p.inferred_project != '%s' THEN 
                        CASE WHEN p.context = 'CALL_CTX' THEN 'PROCEDURE' WHEN p.context = 'DATA_CTX' THEN 'EXTERNAL_TABLE_OR_VIEW' WHEN p.context = 'FUNC_CTX' THEN 'FUNCTION' END
                    ELSE cat.object_type 
                END AS final_object_type
                FROM Detailed_Parsed p
                LEFT JOIN Object_Catalog cat ON p.inferred_dataset = cat.dataset_name AND p.inferred_object = cat.object_name
                WHERE (p.inferred_project != '%s') 
                   OR (p.inferred_project = '%s' AND (cat.object_name IS NOT NULL OR p.context = 'CREATE_CTX'))
            ),
            -- 6. ENRIQUECIMIENTO
            Deps_With_Params AS (
                SELECT rd.*, COALESCE(sig.param_names, CAST([] AS ARRAY<STRING>)) AS dep_param_names, COALESCE(sig.param_types, CAST([] AS ARRAY<STRING>)) AS dep_param_types
                FROM Resolved_Deps rd
                LEFT JOIN Global_Signatures sig ON rd.project_name = sig.project_name AND rd.dataset_name = sig.dataset_name AND rd.object_name = sig.object_name
            )
            -- 7. INSERCIÓN FINAL (NOMBRES ACTUALIZADOS)
            SELECT 
                CURRENT_TIMESTAMP() AS extraction_timestamp,
                '%s' AS source_project,
                '%s' AS source_dataset,
                -- Procedimiento Padre
                STRUCT('%s', '%s', dwp.parent_proc, STRUCT(COALESCE(ANY_VALUE(parent_sig.param_names), CAST([] AS ARRAY<STRING>)), COALESCE(ANY_VALUE(parent_sig.param_types), CAST([] AS ARRAY<STRING>)))) AS procedimiento,
                
                -- Subprocedimientos
                ARRAY_AGG(CASE WHEN dwp.context = 'CALL_CTX' AND dwp.final_object_type = 'PROCEDURE' THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name, STRUCT(dwp.dep_param_names, dwp.dep_param_types)) ELSE NULL END IGNORE NULLS) AS subprocedimiento,
                
                -- CAMBIO 1: tabla_creada (Outputs)
                ARRAY_AGG(CASE WHEN dwp.context = 'CREATE_CTX' THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name) ELSE NULL END IGNORE NULLS) AS tabla_creada,
                
                -- CAMBIO 2: tabla_leida (Inputs)
                ARRAY_AGG(CASE WHEN dwp.context = 'DATA_CTX' AND dwp.final_object_type IN ('BASE TABLE', 'VIEW', 'CLONE', 'EXTERNAL_TABLE_OR_VIEW') THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name) ELSE NULL END IGNORE NULLS) AS tabla_leida,
                
                -- Funciones de Tabla
                ARRAY_AGG(CASE WHEN dwp.final_object_type = 'TABLE FUNCTION' THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name, STRUCT(dwp.dep_param_names, dwp.dep_param_types)) ELSE NULL END IGNORE NULLS) AS table_function,
                
                -- Funciones
                ARRAY_AGG(CASE WHEN dwp.context = 'FUNC_CTX' AND dwp.final_object_type = 'FUNCTION' THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name, STRUCT(dwp.dep_param_names, dwp.dep_param_types)) ELSE NULL END IGNORE NULLS) AS funcion,
                
                ANY_VALUE(dwp.routine_definition)
            FROM Deps_With_Params dwp
            LEFT JOIN Global_Signatures parent_sig ON dwp.parent_proc = parent_sig.object_name AND parent_sig.dataset_name = '%s'
            GROUP BY dwp.parent_proc
        """, 
        -- MAPEO DE 27 ARGUMENTOS
        region_suffix, target_proj, 
        region_suffix, target_proj, 
        region_suffix, target_proj,
        region_suffix, target_proj, target_data,
        region_suffix, target_proj, target_data, 
        region_suffix, target_proj, target_data, 
        region_suffix, target_proj, target_data, 
        target_proj, 
        target_proj, 
        target_proj, 
        target_proj, 
        target_proj, 
        target_data, 
        target_proj, 
        target_data, 
        target_data 
        );

        EXECUTE IMMEDIATE sql_query;
        SET i = i + 1;
    END WHILE;
END