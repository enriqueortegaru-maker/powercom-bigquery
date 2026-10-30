BEGIN
    DECLARE i INT64 DEFAULT 0;
    DECLARE target_proj STRING;
    DECLARE target_data STRING;
    DECLARE sql_query STRING;

    WHILE i < ARRAY_LENGTH(targets) DO
        SET target_proj = targets[OFFSET(i)].project_id;
        SET target_data = targets[OFFSET(i)].dataset_id;

        DELETE FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE` 
        WHERE source_project = target_proj AND source_dataset = target_data;

        SET sql_query = FORMAT("""
            INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
            WITH 
            -- 1. GLOBAL SIGNATURES (Rutinas)
            Global_Signatures AS (
                SELECT 
                    specific_catalog AS project_name, specific_schema AS dataset_name, specific_name AS object_name,
                    ARRAY_AGG(parameter_name ORDER BY ordinal_position) AS param_names,
                    ARRAY_AGG(data_type ORDER BY ordinal_position) AS param_types
                FROM `%s.INFORMATION_SCHEMA.PARAMETERS`
                WHERE specific_catalog = '%s' AND parameter_name IS NOT NULL
                GROUP BY 1, 2, 3
            ),
            -- 2. TABLE SCHEMAS (NUEVO: Esquema de Tablas)
            Table_Schemas AS (
                SELECT 
                    table_catalog AS project_name, table_schema AS dataset_name, table_name AS object_name,
                    ARRAY_AGG(column_name ORDER BY ordinal_position) AS col_names,
                    ARRAY_AGG(data_type ORDER BY ordinal_position) AS col_types
                FROM `%s.INFORMATION_SCHEMA.COLUMNS`
                WHERE table_catalog = '%s'
                GROUP BY 1, 2, 3
            ),
            -- 3. OBJECT CATALOG
            Object_Catalog AS (
                SELECT table_schema AS dataset_name, table_name AS object_name, table_type AS object_type 
                FROM `%s.INFORMATION_SCHEMA.TABLES` WHERE table_catalog = '%s'
                UNION ALL
                SELECT routine_schema AS dataset_name, routine_name AS object_name, routine_type AS object_type 
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` WHERE routine_catalog = '%s'
            ),
            -- 4. ROUTINE DEFINITIONS
            Routine_Definitions AS (
                SELECT routine_catalog, routine_schema, routine_name, routine_definition
                FROM `%s.INFORMATION_SCHEMA.ROUTINES`
                WHERE routine_catalog = '%s'
            ),
            -- 5. RAW EXTRACTIONS
            Raw_extractions AS (
                -- CALL Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'CALL_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'(?i)\\bCALL\\s+[`]?([\\w\\-\\.]+)[`]?')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                -- CREATE Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'CREATE_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'(?i)\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TEMP\\s+|TEMPORARY\\s+)?TABLE\\s*(?:IF\\s+NOT\\s+EXISTS\\s+)?[`]?([\\w\\-\\.]+)[`]?')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                -- DATA Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'DATA_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'(?i)(?:\\bFROM\\s+|\\bJOIN\\s+)(?:[`]?([\\w\\-\\.]+)[`]?)')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                UNION ALL
                -- FUNC Context
                SELECT r.routine_schema, r.routine_name, r.routine_definition, 'FUNC_CTX' AS context, match AS raw_ref
                FROM `%s.INFORMATION_SCHEMA.ROUTINES` r, UNNEST(REGEXP_EXTRACT_ALL(REGEXP_REPLACE(r.routine_definition, r'--.*', ''), r'(?i)(?:[`]?([\\w\\-\\.]+)[`]?)\\s*\\(')) AS match
                WHERE r.routine_catalog = '%s' AND r.routine_schema = '%s' AND r.routine_type = 'PROCEDURE'
                AND NOT REGEXP_CONTAINS(match, r'(?i)\\b(IF|COUNT|SUM|AVG|MIN|MAX|CAST|EXTRACT|DATE|TIMESTAMP|SAFE_CAST|TRIM|UPPER|LOWER)\\b')
            ),
            -- 6. PARSING
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
            -- 7. RESOLUCIÓN
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
            -- 8. ENRIQUECIMIENTO (Ahora incluye ESQUEMAS)
            Deps_With_Params AS (
                SELECT 
                    rd.*, 
                    -- Parametros de Rutinas
                    COALESCE(sig.param_names, CAST([] AS ARRAY<STRING>)) AS dep_param_names, 
                    COALESCE(sig.param_types, CAST([] AS ARRAY<STRING>)) AS dep_param_types,
                    -- DDL de Hijos
                    def.routine_definition AS child_ddl,
                    -- Esquema de Tablas (NUEVO)
                    COALESCE(ts.col_names, CAST([] AS ARRAY<STRING>)) AS table_col_names,
                    COALESCE(ts.col_types, CAST([] AS ARRAY<STRING>)) AS table_col_types
                FROM Resolved_Deps rd
                LEFT JOIN Global_Signatures sig 
                    ON rd.project_name = sig.project_name AND rd.dataset_name = sig.dataset_name AND rd.object_name = sig.object_name
                LEFT JOIN Routine_Definitions def
                    ON rd.project_name = def.routine_catalog AND rd.dataset_name = def.routine_schema AND rd.object_name = def.routine_name
                LEFT JOIN Table_Schemas ts
                    ON rd.project_name = ts.project_name AND rd.dataset_name = ts.dataset_name AND rd.object_name = ts.object_name
            )
            -- 9. INSERCIÓN FINAL
            SELECT 
                CURRENT_TIMESTAMP() AS extraction_timestamp,
                '%s' AS source_project,
                '%s' AS source_dataset,
                -- Procedimiento Padre
                STRUCT('%s', '%s', dwp.parent_proc, 
                       STRUCT(COALESCE(ANY_VALUE(parent_sig.param_names), CAST([] AS ARRAY<STRING>)), COALESCE(ANY_VALUE(parent_sig.param_types), CAST([] AS ARRAY<STRING>))),
                       ANY_VALUE(dwp.routine_definition)
                ) AS procedimiento,
                
                -- Subprocedimientos
                ARRAY_AGG(CASE WHEN dwp.context = 'CALL_CTX' AND dwp.final_object_type = 'PROCEDURE' 
                    THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name, 
                                STRUCT(dwp.dep_param_names, dwp.dep_param_types),
                                dwp.child_ddl)
                    ELSE NULL END IGNORE NULLS) AS subprocedimiento,
                
                -- Tabla Creada (CON ESQUEMA)
                ARRAY_AGG(CASE WHEN dwp.context = 'CREATE_CTX' 
                    THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name,
                                STRUCT(dwp.table_col_names AS name, dwp.table_col_types AS type)) 
                    ELSE NULL END IGNORE NULLS) AS tabla_creada,
                
                -- Tabla Leida (CON ESQUEMA)
                ARRAY_AGG(CASE WHEN dwp.context = 'DATA_CTX' AND dwp.final_object_type IN ('BASE TABLE', 'VIEW', 'CLONE', 'EXTERNAL_TABLE_OR_VIEW') 
                    THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name,
                                STRUCT(dwp.table_col_names AS name, dwp.table_col_types AS type)) 
                    ELSE NULL END IGNORE NULLS) AS tabla_leida,
                
                -- Funciones de Tabla
                ARRAY_AGG(CASE WHEN dwp.final_object_type = 'TABLE FUNCTION' 
                    THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name, 
                                STRUCT(dwp.dep_param_names, dwp.dep_param_types),
                                dwp.child_ddl)
                    ELSE NULL END IGNORE NULLS) AS table_function,
                
                -- Funciones
                ARRAY_AGG(CASE WHEN dwp.context = 'FUNC_CTX' AND dwp.final_object_type = 'FUNCTION' 
                    THEN STRUCT(dwp.project_name, dwp.dataset_name, dwp.object_name, 
                                STRUCT(dwp.dep_param_names, dwp.dep_param_types),
                                dwp.child_ddl)
                    ELSE NULL END IGNORE NULLS) AS funcion,
                
                ANY_VALUE(dwp.routine_definition)
            FROM Deps_With_Params dwp
            LEFT JOIN Global_Signatures parent_sig ON dwp.parent_proc = parent_sig.object_name AND parent_sig.dataset_name = '%s'
            GROUP BY dwp.parent_proc
        """, 
        -- MAPEO DE 31 ARGUMENTOS
        -- 1. Global_Signatures (2)
        region_suffix, target_proj, 
        -- 2. Table_Schemas (2) - NUEVO
        region_suffix, target_proj,
        -- 3. Object_Catalog (4)
        region_suffix, target_proj, 
        region_suffix, target_proj,
        -- 4. Routine_Definitions (2)
        region_suffix, target_proj,
        -- 5. Raw_extractions (12)
        region_suffix, target_proj, target_data, -- CALL
        region_suffix, target_proj, target_data, -- CREATE
        region_suffix, target_proj, target_data, -- DATA
        region_suffix, target_proj, target_data, -- FUNC
        -- 6. Detailed_Parsed (1)
        target_proj, 
        -- 7. Resolved_Deps (3)
        target_proj, 
        target_proj, 
        target_proj, 
        -- 9. Select Final (5)
        target_proj, -- source_project
        target_data, -- source_dataset
        target_proj, -- STRUCT project
        target_data, -- STRUCT dataset
        target_data  -- JOIN dataset
        );

        EXECUTE IMMEDIATE sql_query;
        SET i = i + 1;
    END WHILE;
END