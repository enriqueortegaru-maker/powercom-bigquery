BEGIN
    DECLARE v_backup_name   STRING;
    DECLARE v_select_list   STRING;
    DECLARE v_ddl           STRING;
    DECLARE v_partition_by  STRING;
    DECLARE v_cluster_by    STRING;


    -- CALL `mm-commissions-reporting.KRT_SAP.pr_oper_tabla_esquema`('TRANSACCIONES_TEST', 'ADD', [STRUCT('data_source_ds','STRING', 86)]);

    -- ── Guard clauses ────────────────────────────────────────────────
    IF p_operation NOT IN ('ADD','DELETE','MODIFY') THEN
        RAISE USING MESSAGE = "p_operation must be 'ADD', 'DELETE' or 'MODIFY'.";
    END IF;

    IF ARRAY_LENGTH(p_columns_config) = 0 THEN
        RAISE USING MESSAGE = "p_columns_config is empty.";
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.TABLES`
        WHERE table_name = p_table_name
    ) THEN
        RAISE USING MESSAGE = FORMAT("Table %s not found in KRT_SAP.", p_table_name);
    END IF;

    -- DELETE: block dropping partition/cluster keys
    IF p_operation = 'DELETE'
       AND EXISTS (
            SELECT 1
            FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS`
            WHERE table_name = p_table_name
              AND column_name IN (SELECT col_name FROM UNNEST(p_columns_config))
              AND (is_partitioning_column = 'YES' OR clustering_ordinal_position IS NOT NULL)
       ) THEN
        RAISE USING MESSAGE = "Cannot drop a partitioning or clustering column.";
    END IF;

    -- MODIFY: ordinal must exist, and cannot target partition/cluster keys
    IF p_operation = 'MODIFY' THEN
        IF EXISTS (
            SELECT 1 FROM UNNEST(p_columns_config) m
            WHERE m.ordinal_pos NOT IN (
                SELECT ordinal_position
                FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS`
                WHERE table_name = p_table_name
            )
        ) THEN
            RAISE USING MESSAGE = "MODIFY: an ordinal_pos does not exist in the table.";
        END IF;

        IF EXISTS (
            SELECT 1
            FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS` c
            JOIN UNNEST(p_columns_config) m ON c.ordinal_position = m.ordinal_pos
            WHERE c.table_name = p_table_name
              AND (c.is_partitioning_column = 'YES' OR c.clustering_ordinal_position IS NOT NULL)
        ) THEN
            RAISE USING MESSAGE = "MODIFY: cannot alter a partitioning/clustering column.";
        END IF;
    END IF;

    -- ── STEP 1 · Mirror backup (data + partitions + clusters, 7-day TTL) ─
    SET v_backup_name = FORMAT('%s_%s', p_table_name, FORMAT_TIMESTAMP('%Y%m%d_%H%M%S', CURRENT_TIMESTAMP(), 'Europe/Madrid'));



    EXECUTE IMMEDIATE FORMAT("""
        CREATE TABLE `mm-commissions-reporting.KRT_SAP.%s`
        COPY `mm-commissions-reporting.KRT_SAP.%s`
        OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY))
    """, v_backup_name, p_table_name);

    -- ── STEP 2a · Build ordinal-accurate SELECT list ─────────────────
    IF p_operation = 'ADD' THEN
        SET v_select_list = (
            SELECT STRING_AGG(expr, ', ' ORDER BY pos, grp, off)
            FROM (
                SELECT '`' || column_name || '`' AS expr,
                       ordinal_position AS pos, 1 AS grp, 0 AS off
                FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS`
                WHERE table_name = p_table_name
                UNION ALL
                SELECT FORMAT('CAST(NULL AS %s) AS `%s`', c.col_type, c.col_name),
                       c.ordinal_pos, 0, o
                FROM UNNEST(p_columns_config) AS c WITH OFFSET o
            )
        );

    ELSEIF p_operation = 'DELETE' THEN
        SET v_select_list = (
            SELECT STRING_AGG('`' || column_name || '`', ', ' ORDER BY ordinal_position)
            FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS`
            WHERE table_name = p_table_name
              AND column_name NOT IN (SELECT col_name FROM UNNEST(p_columns_config))
        );

    ELSE  -- MODIFY · replace name/type at ordinal_pos, preserve data when castable
        SET v_select_list = (
            SELECT STRING_AGG(
                CASE
                    WHEN m.col_name IS NULL
                        THEN '`' || c.column_name || '`'
                    WHEN UPPER(c.data_type) = UPPER(m.col_type)                      -- pure rename
                        THEN FORMAT('`%s` AS `%s`', c.column_name, m.col_name)
                    WHEN REGEXP_CONTAINS(UPPER(m.col_type), r'^(STRUCT|ARRAY)')       -- complex type → reset
                      OR REGEXP_CONTAINS(UPPER(c.data_type), r'^(STRUCT|ARRAY)')
                        THEN FORMAT('CAST(NULL AS %s) AS `%s`', m.col_type, m.col_name)
                    ELSE FORMAT('SAFE_CAST(`%s` AS %s) AS `%s`',                      -- scalar recast
                                c.column_name, m.col_type, m.col_name)
                END,
                ', ' ORDER BY c.ordinal_position
            )
            FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS` c
            LEFT JOIN (SELECT col_name, col_type, ordinal_pos FROM UNNEST(p_columns_config)) m
                   ON c.ordinal_position = m.ordinal_pos
            WHERE c.table_name = p_table_name
        );
    END IF;

    -- ── STEP 2b · Recover PARTITION BY / CLUSTER BY from source DDL ───
    SET v_ddl = (
        SELECT ddl FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.TABLES`
        WHERE table_name = p_table_name
    );
    SET v_partition_by = TRIM(IFNULL(REGEXP_EXTRACT(v_ddl, r'(?im)^(PARTITION BY [^;\n]+)'), ''));
    SET v_cluster_by   = TRIM(IFNULL(REGEXP_EXTRACT(v_ddl, r'(?im)^(CLUSTER BY [^;\n]+)'),   ''));

    -- ── STEP 2c · Atomic rebuild with reconstructed order + physical layout ─
    EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.%s`
        %s
        %s
        AS SELECT %s FROM `mm-commissions-reporting.KRT_SAP.%s`
    """, p_table_name, v_partition_by, v_cluster_by, v_select_list, p_table_name);

END