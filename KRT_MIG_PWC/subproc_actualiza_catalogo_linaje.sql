BEGIN
    -- Declarations must come before any executable statement in BigQuery.
    DECLARE i          INT64  DEFAULT 0;
    DECLARE target_proj STRING;
    DECLARE target_data STRING;
    DECLARE sql_query  STRING;

    WHILE i < ARRAY_LENGTH(targets) DO
        SET target_proj = targets[OFFSET(i)].project_id;
        SET target_data = targets[OFFSET(i)].dataset_id;

        -- F6: fault-isolated block; loop continues regardless of per-target errors
        BEGIN
            DELETE FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
            WHERE source_project = target_proj
              AND source_dataset = target_data
              AND DATE(extraction_timestamp) = CURRENT_DATE();

            SET sql_query = """
                INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
                WITH

                -- 1. GLOBAL SIGNATURES
                Global_Signatures AS (
                    SELECT
                        specific_catalog AS project_name,
                        specific_schema  AS dataset_name,
                        specific_name    AS object_name,
                        ARRAY_AGG(parameter_name ORDER BY ordinal_position) AS param_names,
                        ARRAY_AGG(data_type       ORDER BY ordinal_position) AS param_types
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.PARAMETERS`
                    WHERE specific_catalog = '@@PROJECT@@' AND parameter_name IS NOT NULL
                    GROUP BY 1, 2, 3
                ),

                -- 2. TABLE & VIEW SCHEMAS
                Table_Schemas AS (
                    SELECT
                        table_catalog AS project_name, table_schema AS dataset_name, table_name AS object_name,
                        ARRAY_AGG(column_name           ORDER BY ordinal_position) AS col_names,
                        ARRAY_AGG(data_type             ORDER BY ordinal_position) AS col_types,
                        ARRAY_AGG(ordinal_position      ORDER BY ordinal_position) AS ordinal_positions,
                        ARRAY_AGG(COALESCE(is_partitioning_column = 'YES', FALSE) ORDER BY ordinal_position) AS is_partitioning_columns,
                        ARRAY_AGG(COALESCE(clustering_ordinal_position, 0)        ORDER BY ordinal_position) AS clustering_positions
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.COLUMNS`
                    WHERE table_catalog = '@@PROJECT@@'
                    GROUP BY 1, 2, 3
                ),

                -- 3. OBJECT CATALOG
                Object_Catalog AS (
                    SELECT table_schema   AS dataset_name, UPPER(table_name)   AS object_name, table_type   AS object_type
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.TABLES`
                    WHERE table_catalog = '@@PROJECT@@'
                    UNION ALL
                    SELECT routine_schema AS dataset_name, UPPER(routine_name) AS object_name, routine_type AS object_type
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.ROUTINES`
                    WHERE routine_catalog = '@@PROJECT@@'
                ),

                -- 4. PARENT FULL INFO (routines + views)
                Parent_Full_Info AS (
                    SELECT routine_catalog AS catalog, routine_schema AS schema, routine_name AS name,
                           routine_definition AS definition, created, last_altered, 'ROUTINE' AS parent_type,
                           ARRAY_LENGTH(SPLIT(routine_definition, '\\n')) AS lines_of_code
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.ROUTINES`
                    WHERE routine_catalog = '@@PROJECT@@'
                    UNION ALL
                    SELECT v.table_catalog, v.table_schema, v.table_name, v.view_definition,
                           t.creation_time AS created, CAST(NULL AS TIMESTAMP) AS last_altered, 'VIEW' AS parent_type,
                           ARRAY_LENGTH(SPLIT(v.view_definition, '\\n')) AS lines_of_code
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.VIEWS` v
                    INNER JOIN `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.TABLES` t
                      ON v.table_catalog = t.table_catalog
                     AND v.table_schema  = t.table_schema
                     AND v.table_name    = t.table_name
                    WHERE v.table_catalog = '@@PROJECT@@'
                ),

                -- 5. TABLE METADATA (F2: catalog predicate added to storage join)
                Table_Metadata AS (
                    SELECT
                        t.table_catalog AS project_name, t.table_schema AS dataset_name, t.table_name AS object_name,
                        t.creation_time, t.table_type,
                        s.total_rows          AS row_count,
                        s.total_logical_bytes AS size_bytes
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.TABLES` t
                    LEFT JOIN `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.TABLE_STORAGE` s
                      ON  t.table_catalog = s.project_id
                      AND t.table_schema  = s.table_schema
                      AND t.table_name    = s.table_name
                    WHERE t.table_catalog = '@@PROJECT@@'
                ),

                -- 6. CLEANED CODE (comments stripped; FROM-function false-positive neutralised)
                Cleaned_Code AS (
                    SELECT routine_schema AS obj_schema, routine_name AS obj_name,
                           routine_type  AS obj_type,  'ROUTINE'       AS obj_class,
                           REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(routine_definition,
                               r'--.*', ''),
                               r'/\\*[\\s\\S]*?\\*/', ''),
                               r'(?i)\\b(EXTRACT|SUBSTRING|TRIM|LTRIM|RTRIM)\\s*\\([^)]+?\\bFROM\\b',
                               r'\\1_FUNC_FROM') AS clean_def
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.ROUTINES`
                    WHERE routine_catalog = '@@PROJECT@@'
                    UNION ALL
                    SELECT table_schema AS obj_schema, table_name AS obj_name,
                           'VIEW'       AS obj_type,  'VIEW'       AS obj_class,
                           REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(view_definition,
                               r'--.*', ''),
                               r'/\\*[\\s\\S]*?\\*/', ''),
                               r'(?i)\\b(EXTRACT|SUBSTRING|TRIM|LTRIM|RTRIM)\\s*\\([^)]+?\\bFROM\\b',
                               r'\\1_FUNC_FROM') AS clean_def
                    FROM `@@PROJECT@@.@@REGION@@.INFORMATION_SCHEMA.VIEWS`
                    WHERE table_catalog = '@@PROJECT@@'
                ),

                -- 7. RAW EXTRACTIONS (scoped to @@DATASET@@ parents - main lineage)
                Raw_extractions AS (
                    -- CALL
                    SELECT obj_schema AS parent_schema, obj_name AS parent_name,
                           clean_def AS definition, 'CALL_CTX' AS context, match AS raw_ref
                    FROM Cleaned_Code c,
                         UNNEST(REGEXP_EXTRACT_ALL(c.clean_def,
                             r'(?i)\\bCALL\\s+[`]?([\\w\\-\\.]+)[`]?')) AS match
                    WHERE c.obj_class = 'ROUTINE' AND c.obj_schema = '@@DATASET@@'
                      AND c.obj_type IN ('PROCEDURE', 'TABLE FUNCTION', 'FUNCTION')
                    UNION ALL
                    -- CREATE TABLE
                    SELECT obj_schema, obj_name, clean_def, 'CREATE_CTX', match
                    FROM Cleaned_Code c,
                         UNNEST(REGEXP_EXTRACT_ALL(c.clean_def,
                             r'(?i)\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TEMP\\s+|TEMPORARY\\s+)?TABLE\\s*(?:IF\\s+NOT\\s+EXISTS\\s+)?[`]?([\\w\\-\\.]+)[`]?')) AS match
                    WHERE c.obj_class = 'ROUTINE' AND c.obj_schema = '@@DATASET@@'
                      AND c.obj_type IN ('PROCEDURE', 'TABLE FUNCTION', 'FUNCTION')
                    UNION ALL
                    -- DML (INSERT / UPDATE / DELETE / MERGE / TRUNCATE)
                    SELECT obj_schema, obj_name, clean_def, 'DML_CTX', match
                    FROM Cleaned_Code c,
                         UNNEST(REGEXP_EXTRACT_ALL(c.clean_def,
                             r'(?i)(?:\\bINSERT\\s+INTO\\s+|\\bUPDATE\\s+|\\bDELETE\\s+FROM\\s+|\\bMERGE\\s+(?:INTO\\s+)?|\\bTRUNCATE\\s+TABLE\\s+)(?:[`]?([\\w\\-\\.]+)[`]?)')) AS match
                    WHERE c.obj_class = 'ROUTINE' AND c.obj_schema = '@@DATASET@@'
                      AND c.obj_type IN ('PROCEDURE', 'TABLE FUNCTION', 'FUNCTION')
                    UNION ALL
                    -- DATA (FROM / JOIN / USING) - routines and views
                    SELECT obj_schema, obj_name, clean_def, 'DATA_CTX', match
                    FROM Cleaned_Code c,
                         UNNEST(REGEXP_EXTRACT_ALL(c.clean_def,
                             r'(?i)(?:\\bFROM\\s+|\\bJOIN\\s+|\\bUSING\\s+)(?:[`]?([\\w\\-\\.\\`]+)[`]?)')) AS match
                    WHERE c.obj_schema = '@@DATASET@@'
                      AND (c.obj_type IN ('PROCEDURE', 'TABLE FUNCTION', 'FUNCTION') OR c.obj_class = 'VIEW')
                    UNION ALL
                    -- FUNCTION calls
                    SELECT obj_schema, obj_name, clean_def, 'FUNC_CTX', match
                    FROM Cleaned_Code c,
                         UNNEST(REGEXP_EXTRACT_ALL(c.clean_def,
                             r'(?i)(?:[`]?([\\w\\-\\.]+)[`]?)\\s*\\(')) AS match
                    WHERE c.obj_schema = '@@DATASET@@'
                      AND (c.obj_type IN ('PROCEDURE', 'TABLE FUNCTION', 'FUNCTION') OR c.obj_class = 'VIEW')
                      AND NOT REGEXP_CONTAINS(match,
                              r'(?i)\\b(IF|COUNT|SUM|AVG|MIN|MAX|CAST|EXTRACT|DATE|TIMESTAMP|SAFE_CAST|TRIM|UPPER|LOWER)\\b')
                ),

                -- F3: PROJECT-WIDE touched objects for orphan detection.
                -- No @@DATASET@@ filter on parent - covers all routines/views in @@PROJECT@@.
                -- UPPER() normalised on both sides of the anti-join.
                Proj_Touched AS (
                    SELECT DISTINCT
                        CASE
                            WHEN ARRAY_LENGTH(SPLIT(REPLACE(raw_ref, '`', ''), '.')) >= 3
                                THEN TRIM(SPLIT(REPLACE(raw_ref, '`', ''), '.')[OFFSET(1)])
                            WHEN ARRAY_LENGTH(SPLIT(REPLACE(raw_ref, '`', ''), '.')) = 2
                                THEN TRIM(SPLIT(REPLACE(raw_ref, '`', ''), '.')[OFFSET(0)])
                            ELSE c.obj_schema
                        END AS ref_dataset,
                        UPPER(TRIM(SPLIT(REPLACE(raw_ref, '`', ''), '.')[SAFE_OFFSET(
                            ARRAY_LENGTH(SPLIT(REPLACE(raw_ref, '`', ''), '.')) - 1
                        )])) AS ref_object_upper
                    FROM Cleaned_Code c,
                         UNNEST(REGEXP_EXTRACT_ALL(c.clean_def,
                             r'(?i)(?:\\bFROM\\s+|\\bJOIN\\s+|\\bINSERT\\s+INTO\\s+|\\bUPDATE\\s+|\\bDELETE\\s+FROM\\s+|\\bMERGE\\s+(?:INTO\\s+)?|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TEMP\\s+|TEMPORARY\\s+)?TABLE\\s*(?:IF\\s+NOT\\s+EXISTS\\s+)?)[`]?([\\w][\\w\\-\\.`]*)[`]?'
                         )) AS raw_ref
                    WHERE raw_ref IS NOT NULL AND TRIM(raw_ref) != ''
                ),

                -- 8. PARSING
                Parsed_References AS (
                    SELECT src.*,
                           SPLIT(REPLACE(src.raw_ref, '`', ''), '.') AS parts,
                           ARRAY_LENGTH(SPLIT(src.raw_ref, '.'))      AS num_parts
                    FROM Raw_extractions src
                ),
                Detailed_Parsed AS (
                    SELECT *,
                        CASE WHEN num_parts >= 3 THEN TRIM(parts[OFFSET(0)]) ELSE '@@PROJECT@@' END AS inferred_project,
                        CASE WHEN num_parts >= 3 THEN TRIM(parts[OFFSET(1)])
                             WHEN num_parts = 2  THEN TRIM(parts[OFFSET(0)])
                             ELSE parent_schema END AS inferred_dataset,
                        UPPER(TRIM(parts[OFFSET(num_parts - 1)])) AS inferred_object_upper,
                        TRIM(parts[OFFSET(num_parts - 1)])        AS inferred_object_original
                    FROM Parsed_References
                ),

                -- 9. RESOLVED DEPS
                -- F1: QUALIFY partitioned by (parent, project, dataset, object, RELATION_CLASS)
                --     so a table that is both READ and WRITTEN generates two rows.
                --     Within the INVOKE class, CALL_CTX wins over FUNC_CTX.
                Resolved_Deps AS (
                    SELECT
                        p.parent_name, p.context,
                        p.inferred_project AS project_name,
                        p.inferred_dataset AS dataset_name,
                        p.inferred_object_original AS object_name,
                        CASE
                            WHEN p.context = 'CREATE_CTX' THEN 'CREATED_TABLE'
                            WHEN p.context = 'DML_CTX'    THEN 'MODIFIED_TABLE'
                            WHEN p.inferred_project != '@@PROJECT@@' THEN
                                CASE
                                    WHEN p.context = 'CALL_CTX'  THEN 'PROCEDURE'
                                    WHEN p.context = 'DATA_CTX'  THEN 'EXTERNAL_TABLE_OR_VIEW'
                                    WHEN p.context = 'FUNC_CTX'  THEN 'FUNCTION'
                                END
                            ELSE
                                CASE
                                    WHEN cat.object_type = 'EXTERNAL'            THEN 'EXTERNAL_TABLE_OR_VIEW'
                                    WHEN cat.object_type IS NOT NULL             THEN cat.object_type
                                    WHEN p.context = 'DATA_CTX' AND p.num_parts > 1 THEN 'EXTERNAL_TABLE_OR_VIEW'
                                    ELSE NULL
                                END
                        END AS final_object_type
                    FROM Detailed_Parsed p
                    LEFT JOIN Object_Catalog cat
                      ON p.inferred_dataset = cat.dataset_name AND p.inferred_object_upper = cat.object_name
                    WHERE (p.inferred_project != '@@PROJECT@@')
                       OR (p.inferred_project = '@@PROJECT@@' AND (
                               cat.object_name IS NOT NULL
                            OR p.context IN ('CREATE_CTX', 'DML_CTX')
                            OR (p.context = 'DATA_CTX' AND p.num_parts > 1)
                          ))
                    QUALIFY ROW_NUMBER() OVER(
                        PARTITION BY
                            p.parent_name,
                            p.inferred_project,
                            p.inferred_dataset,
                            p.inferred_object_original,
                            CASE p.context
                                WHEN 'CREATE_CTX' THEN 'CREATE'
                                WHEN 'DML_CTX'    THEN 'DML'
                                WHEN 'DATA_CTX'   THEN 'DATA'
                                ELSE 'INVOKE'
                            END
                        ORDER BY CASE p.context WHEN 'CALL_CTX' THEN 1 WHEN 'FUNC_CTX' THEN 2 ELSE 1 END
                    ) = 1
                ),

                -- 10. ENRICHMENT
                Deps_With_Params AS (
                    SELECT
                        rd.*,
                        COALESCE(sig.param_names, CAST([] AS ARRAY<STRING>)) AS dep_param_names,
                        COALESCE(sig.param_types, CAST([] AS ARRAY<STRING>)) AS dep_param_types,
                        rm.definition    AS child_ddl,
                        rm.lines_of_code AS rout_lines_of_code,
                        DATE(rm.created)      AS rout_created,
                        DATE(rm.last_altered) AS rout_modified,
                        DATE_DIFF(CURRENT_DATE(), DATE(rm.created),      DAY) AS rout_ndays_cr,
                        DATE_DIFF(CURRENT_DATE(), DATE(rm.last_altered), DAY) AS rout_ndays_mod,
                        COALESCE(ts.col_names,              CAST([] AS ARRAY<STRING>)) AS table_col_names,
                        COALESCE(ts.col_types,              CAST([] AS ARRAY<STRING>)) AS table_col_types,
                        COALESCE(ts.ordinal_positions,      CAST([] AS ARRAY<INT64>))  AS table_ordinal_positions,
                        COALESCE(ts.is_partitioning_columns,CAST([] AS ARRAY<BOOL>))   AS table_is_partitioning_columns,
                        COALESCE(ts.clustering_positions,   CAST([] AS ARRAY<INT64>))  AS table_clustering_positions,
                        DATE(tm.creation_time) AS tab_created,
                        DATE_DIFF(CURRENT_DATE(), DATE(tm.creation_time), DAY) AS tab_ndays_cr,
                        tm.row_count  AS tab_rows,
                        tm.size_bytes AS tab_size
                    FROM Resolved_Deps rd
                    LEFT JOIN Global_Signatures sig
                      ON rd.project_name = sig.project_name AND rd.dataset_name = sig.dataset_name AND rd.object_name = sig.object_name
                    LEFT JOIN Parent_Full_Info rm
                      ON rd.project_name = rm.catalog AND rd.dataset_name = rm.schema AND rd.object_name = rm.name
                    LEFT JOIN Table_Schemas ts
                      ON rd.project_name = ts.project_name AND rd.dataset_name = ts.dataset_name AND rd.object_name = ts.object_name
                    LEFT JOIN Table_Metadata tm
                      ON rd.project_name = tm.project_name AND rd.dataset_name = tm.dataset_name AND rd.object_name = tm.object_name
                ),

                -- 12. STATIC INVENTORY (for orphan detection)
                Static_Inventory AS (
                    SELECT
                        tm.project_name, tm.dataset_name, tm.object_name, tm.table_type,
                        COALESCE(ts.col_names,               CAST([] AS ARRAY<STRING>)) AS table_col_names,
                        COALESCE(ts.col_types,               CAST([] AS ARRAY<STRING>)) AS table_col_types,
                        COALESCE(ts.ordinal_positions,       CAST([] AS ARRAY<INT64>))  AS table_ordinal_positions,
                        COALESCE(ts.is_partitioning_columns, CAST([] AS ARRAY<BOOL>))   AS table_is_partitioning_columns,
                        COALESCE(ts.clustering_positions,    CAST([] AS ARRAY<INT64>))  AS table_clustering_positions,
                        DATE(tm.creation_time) AS tab_created,
                        DATE_DIFF(CURRENT_DATE(), DATE(tm.creation_time), DAY) AS tab_ndays_cr,
                        tm.row_count  AS tab_rows,
                        tm.size_bytes AS tab_size
                    FROM Table_Metadata tm
                    LEFT JOIN Table_Schemas ts
                      ON tm.project_name = ts.project_name AND tm.dataset_name = ts.dataset_name AND tm.object_name = ts.object_name
                )

                -- ==================================================================
                -- PROJECTION A: ACTIVE LINEAGE
                -- F5: driven from Parent_Full_Info - every routine/view in @@DATASET@@
                --     appears even when it has zero resolvable dependencies.
                -- ==================================================================
                SELECT
                    CURRENT_TIMESTAMP() AS extraction_timestamp,
                    '@@PROJECT@@' AS source_project,
                    '@@DATASET@@' AS source_dataset,

                    STRUCT(
                        '@@PROJECT@@' AS project_name,
                        '@@DATASET@@' AS dataset_name,
                        parent_rm.name AS object_name,
                        IF(ANY_VALUE(parent_rm.parent_type) = 'VIEW', 'VISTA_PADRE', 'RUTINA_PADRE') AS tipo_objeto,
                        STRUCT(
                            COALESCE(ANY_VALUE(parent_sig.param_names), CAST([] AS ARRAY<STRING>)) AS name,
                            COALESCE(ANY_VALUE(parent_sig.param_types), CAST([] AS ARRAY<STRING>)) AS type
                        ) AS arguments,
                        STRUCT(
                            COALESCE(ANY_VALUE(parent_ts.col_names),               CAST([] AS ARRAY<STRING>)) AS name,
                            COALESCE(ANY_VALUE(parent_ts.col_types),               CAST([] AS ARRAY<STRING>)) AS type,
                            COALESCE(ANY_VALUE(parent_ts.ordinal_positions),       CAST([] AS ARRAY<INT64>))  AS ordinal_position,
                            COALESCE(ANY_VALUE(parent_ts.is_partitioning_columns), CAST([] AS ARRAY<BOOL>))   AS is_partitioning_column,
                            COALESCE(ANY_VALUE(parent_ts.clustering_positions),    CAST([] AS ARRAY<INT64>))  AS clustering_ordinal_position
                        ) AS columns,
                        ANY_VALUE(parent_rm.definition) AS definition,
                        STRUCT(
                            DATE(ANY_VALUE(parent_rm.created))      AS created,
                            DATE(ANY_VALUE(parent_rm.last_altered)) AS last_altered,
                            DATE_DIFF(CURRENT_DATE(), DATE(ANY_VALUE(parent_rm.created)),      DAY) AS days_created,
                            DATE_DIFF(CURRENT_DATE(), DATE(ANY_VALUE(parent_rm.last_altered)), DAY) AS days_altered,
                            ANY_VALUE(parent_rm.lines_of_code) AS lines_of_code
                        ) AS metadata
                    ) AS objeto_padre,

                    ARRAY_AGG(
                        CASE
                            WHEN dwp.final_object_type IN
                                ('CREATED_TABLE','MODIFIED_TABLE','BASE TABLE','VIEW','CLONE','EXTERNAL_TABLE_OR_VIEW','MATERIALIZED VIEW') THEN
                                STRUCT(
                                    dwp.project_name, dwp.dataset_name, dwp.object_name,
                                    CASE
                                        WHEN dwp.context = 'CREATE_CTX' THEN 'TABLA_CREADA'
                                        WHEN dwp.context = 'DML_CTX'    THEN 'TABLA_MODIFICADA'
                                        WHEN dwp.context = 'DATA_CTX' AND dwp.final_object_type = 'VIEW' THEN 'VISTA_LEIDA'
                                        WHEN dwp.context = 'DATA_CTX'   THEN 'TABLA_LEIDA'
                                        ELSE 'DESCONOCIDA'
                                    END AS tipo_relacion,
                                    STRUCT(
                                        dwp.table_col_names               AS name,
                                        dwp.table_col_types               AS type,
                                        dwp.table_ordinal_positions       AS ordinal_position,
                                        dwp.table_is_partitioning_columns AS is_partitioning_column,
                                        dwp.table_clustering_positions    AS clustering_ordinal_position
                                    ) AS columns,
                                    STRUCT(
                                        dwp.tab_created        AS created,
                                        CAST(NULL AS DATE)     AS last_altered,
                                        dwp.tab_ndays_cr       AS days_created,
                                        CAST(NULL AS INT64)    AS days_altered,
                                        dwp.tab_rows           AS num_rows,
                                        dwp.tab_size           AS size_bytes
                                    ) AS metadata
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
                                        WHEN dwp.final_object_type = 'TABLE FUNCTION' THEN 'TABLE_FUNCTION'
                                        WHEN dwp.context = 'CALL_CTX'                 THEN 'PROCEDIMIENTO_LLAMADO'
                                        WHEN dwp.context = 'FUNC_CTX'                 THEN 'FUNCION_LLAMADA'
                                        ELSE 'OTRA_RUTINA'
                                    END AS tipo_relacion,
                                    STRUCT(dwp.dep_param_names AS name, dwp.dep_param_types AS type) AS arguments,
                                    dwp.child_ddl AS definition,
                                    STRUCT(
                                        dwp.rout_created    AS created,
                                        dwp.rout_modified   AS last_altered,
                                        dwp.rout_ndays_cr   AS days_created,
                                        dwp.rout_ndays_mod  AS days_altered,
                                        dwp.rout_lines_of_code AS lines_of_code
                                    ) AS metadata
                                )
                            ELSE NULL
                        END IGNORE NULLS
                    ) AS dependencias_rutinas,

                    ANY_VALUE(parent_rm.definition) AS routine_definition_debug

                FROM Parent_Full_Info parent_rm
                LEFT JOIN Global_Signatures parent_sig
                  ON parent_sig.object_name  = parent_rm.name
                 AND parent_sig.dataset_name = '@@DATASET@@'
                 AND parent_sig.project_name = '@@PROJECT@@'
                LEFT JOIN Table_Schemas parent_ts
                  ON parent_ts.object_name  = parent_rm.name
                 AND parent_ts.dataset_name = '@@DATASET@@'
                 AND parent_ts.project_name = '@@PROJECT@@'
                LEFT JOIN Deps_With_Params dwp ON dwp.parent_name = parent_rm.name
                WHERE parent_rm.schema  = '@@DATASET@@'
                  AND parent_rm.catalog = '@@PROJECT@@'
                GROUP BY parent_rm.name

                UNION ALL

                -- ==================================================================
                -- PROJECTION B: ORPHAN CONTAINER
                -- F4: collapses to ONE row per dataset (ARRAY_AGG over all orphans).
                -- F3: anti-join uses Proj_Touched (project-wide, UPPER() normalised).
                -- ==================================================================
                SELECT
                    CURRENT_TIMESTAMP() AS extraction_timestamp,
                    '@@PROJECT@@' AS source_project,
                    '@@DATASET@@' AS source_dataset,
                    STRUCT(
                        '@@PROJECT@@' AS project_name,
                        '@@DATASET@@' AS dataset_name,
                        'TABLAS_HUERFANAS' AS object_name,
                        'CONTENEDOR_HUERFANAS' AS tipo_objeto,
                        STRUCT(CAST([] AS ARRAY<STRING>) AS name, CAST([] AS ARRAY<STRING>) AS type) AS arguments,
                        STRUCT(
                            CAST([] AS ARRAY<STRING>) AS name,
                            CAST([] AS ARRAY<STRING>) AS type,
                            CAST([] AS ARRAY<INT64>)  AS ordinal_position,
                            CAST([] AS ARRAY<BOOL>)   AS is_partitioning_column,
                            CAST([] AS ARRAY<INT64>)  AS clustering_ordinal_position
                        ) AS columns,
                        'Contenedor de tablas no detectadas en el linaje' AS definition,
                        STRUCT(
                            CAST(NULL AS DATE)  AS created,       CAST(NULL AS DATE)  AS last_altered,
                            CAST(NULL AS INT64) AS days_created,  CAST(NULL AS INT64) AS days_altered,
                            CAST(NULL AS INT64) AS lines_of_code
                        ) AS metadata
                    ) AS objeto_padre,

                    ARRAY_AGG(
                        STRUCT(
                            si.project_name, si.dataset_name, si.object_name,
                            'HUERFANA' AS tipo_relacion,
                            STRUCT(
                                si.table_col_names               AS name,
                                si.table_col_types               AS type,
                                si.table_ordinal_positions       AS ordinal_position,
                                si.table_is_partitioning_columns AS is_partitioning_column,
                                si.table_clustering_positions    AS clustering_ordinal_position
                            ) AS columns,
                            STRUCT(
                                si.tab_created      AS created,       CAST(NULL AS DATE)  AS last_altered,
                                si.tab_ndays_cr     AS days_created,  CAST(NULL AS INT64) AS days_altered,
                                si.tab_rows         AS num_rows,      si.tab_size          AS size_bytes
                            ) AS metadata
                        )
                    ) AS dependencias_tablas,

                    CAST([] AS ARRAY<STRUCT<
                        project_name STRING, dataset_name STRING, object_name STRING,
                        tipo_relacion STRING,
                        arguments STRUCT<name ARRAY<STRING>, type ARRAY<STRING>>,
                        definition STRING,
                        metadata STRUCT<created DATE, last_altered DATE, days_created INT64, days_altered INT64, lines_of_code INT64>
                    >>) AS dependencias_rutinas,

                    'INVENTARIO_HUERFANAS' AS routine_definition_debug

                FROM Static_Inventory si
                LEFT JOIN Proj_Touched pt
                  ON UPPER(si.object_name) = pt.ref_object_upper
                 AND si.dataset_name       = pt.ref_dataset
                WHERE pt.ref_object_upper IS NULL
                  AND si.dataset_name = '@@DATASET@@'
            """;

            SET sql_query = REPLACE(sql_query, '@@REGION@@',  region_suffix);
            SET sql_query = REPLACE(sql_query, '@@PROJECT@@', target_proj);
            SET sql_query = REPLACE(sql_query, '@@DATASET@@', target_data);

            EXECUTE IMMEDIATE sql_query;

            -- F6: log successful run
            INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.LOG_LINAJE_EJECUCION`
              (run_timestamp, target_project, target_dataset, status, error_message, rows_inserted)
            VALUES (CURRENT_TIMESTAMP(), target_proj, target_data, 'OK', NULL, @@row_count);

        EXCEPTION WHEN ERROR THEN
            -- F6: record failure; loop continues with next target
            INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.LOG_LINAJE_EJECUCION`
              (run_timestamp, target_project, target_dataset, status, error_message, rows_inserted)
            VALUES (CURRENT_TIMESTAMP(), target_proj, target_data, 'ERROR', @@error.message, 0);
        END;

        SET i = i + 1;
    END WHILE;
END