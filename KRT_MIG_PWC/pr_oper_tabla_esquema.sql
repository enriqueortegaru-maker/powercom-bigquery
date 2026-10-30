BEGIN
    DECLARE v_suffix        STRING DEFAULT FORMAT_TIMESTAMP('%Y%m%d_%H%M%S', CURRENT_TIMESTAMP(), 'Europe/Madrid');
    DECLARE v_backup_name   STRING;
    DECLARE v_select_list   STRING;
    DECLARE v_ddl           STRING;
    DECLARE v_partition_by  STRING;
    DECLARE v_cluster_by    STRING;
    DECLARE v_cnt           INT64 DEFAULT 0;


    -- CALL `mm-commissions-reporting.KRT_MIG_PWC.pr_oper_tabla_esquema`('KRT_SAP','TRANSACCIONES_TEST', 'ADD', [STRUCT('data_source_ds','STRING', 86)]);

    -- ── Guard clauses ────────────────────────────────────────────────
    IF p_operation NOT IN ('ADD','DELETE','MODIFY') THEN
        RAISE USING MESSAGE = "p_operation must be 'ADD', 'DELETE' or 'MODIFY'.";
    END IF;
    IF ARRAY_LENGTH(p_columns_config) = 0 THEN
        RAISE USING MESSAGE = "p_columns_config is empty.";
    END IF;

    -- Table exists in the target dataset
    EXECUTE IMMEDIATE FORMAT("""
        SELECT COUNT(1) FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.TABLES`
        WHERE table_name = ?
    """, P_dataset) INTO v_cnt USING p_table_name;
    IF v_cnt = 0 THEN
        RAISE USING MESSAGE = FORMAT("Table %s not found in dataset %s.", p_table_name, P_dataset);
    END IF;

    -- DELETE: block dropping partition/cluster keys
    IF p_operation = 'DELETE' THEN
        EXECUTE IMMEDIATE FORMAT("""
            SELECT COUNT(1) FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS`
            WHERE table_name = ?
              AND column_name IN (SELECT col_name FROM UNNEST(?))
              AND (is_partitioning_column = 'YES' OR clustering_ordinal_position IS NOT NULL)
        """, P_dataset) INTO v_cnt USING p_table_name, p_columns_config;
        IF v_cnt > 0 THEN
            RAISE USING MESSAGE = "Cannot drop a partitioning or clustering column.";
        END IF;
    END IF;

    -- MODIFY: ordinal must exist, and cannot target partition/cluster keys
    IF p_operation = 'MODIFY' THEN
        EXECUTE IMMEDIATE FORMAT("""
            SELECT COUNT(1) FROM UNNEST(?) m
            WHERE m.ordinal_pos NOT IN (
                SELECT ordinal_position FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS`
                WHERE table_name = ?)
        """, P_dataset) INTO v_cnt USING p_columns_config, p_table_name;
        IF v_cnt > 0 THEN
            RAISE USING MESSAGE = "MODIFY: an ordinal_pos does not exist in the table.";
        END IF;

        EXECUTE IMMEDIATE FORMAT("""
            SELECT COUNT(1)
            FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS` c
            JOIN UNNEST(?) m ON c.ordinal_position = m.ordinal_pos
            WHERE c.table_name = ?
              AND (c.is_partitioning_column = 'YES' OR c.clustering_ordinal_position IS NOT NULL)
        """, P_dataset) INTO v_cnt USING p_columns_config, p_table_name;
        IF v_cnt > 0 THEN
            RAISE USING MESSAGE = "MODIFY: cannot alter a partitioning/clustering column.";
        END IF;
    END IF;

    -- ── STEP 1 · Mirror backup in the SAME dataset (unique name, COPY, 7-day TTL) ─
    SET v_backup_name = FORMAT('%s_%s', p_table_name, v_suffix);
    EXECUTE IMMEDIATE FORMAT("""
        CREATE TABLE `mm-commissions-reporting.%s.%s`
        COPY `mm-commissions-reporting.%s.%s`
        OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY))
    """, P_dataset, v_backup_name, P_dataset, p_table_name);

    -- ── STEP 2a · Build ordinal-accurate SELECT list (dynamic dataset) ─
    IF p_operation = 'ADD' THEN
        EXECUTE IMMEDIATE FORMAT("""
            SELECT STRING_AGG(expr, ', ' ORDER BY pos, grp, off)
            FROM (
                SELECT '`' || column_name || '`' AS expr, ordinal_position AS pos, 1 AS grp, 0 AS off
                FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS`
                WHERE table_name = ?
                UNION ALL
                SELECT 'CAST(NULL AS ' || c.col_type || ') AS `' || c.col_name || '`', c.ordinal_pos, 0, o
                FROM UNNEST(?) AS c WITH OFFSET o
            )
        """, P_dataset) INTO v_select_list USING p_table_name, p_columns_config;

    ELSEIF p_operation = 'DELETE' THEN
        EXECUTE IMMEDIATE FORMAT("""
            SELECT STRING_AGG('`' || column_name || '`', ', ' ORDER BY ordinal_position)
            FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS`
            WHERE table_name = ?
              AND column_name NOT IN (SELECT col_name FROM UNNEST(?))
        """, P_dataset) INTO v_select_list USING p_table_name, p_columns_config;

    ELSE  -- MODIFY
        EXECUTE IMMEDIATE FORMAT("""
            SELECT STRING_AGG(
                CASE
                    WHEN m.col_name IS NULL
                        THEN '`' || c.column_name || '`'
                    WHEN UPPER(c.data_type) = UPPER(m.col_type)
                        THEN '`' || c.column_name || '` AS `' || m.col_name || '`'
                    WHEN REGEXP_CONTAINS(UPPER(m.col_type), r'^(STRUCT|ARRAY)')
                      OR REGEXP_CONTAINS(UPPER(c.data_type), r'^(STRUCT|ARRAY)')
                        THEN 'CAST(NULL AS ' || m.col_type || ') AS `' || m.col_name || '`'
                    ELSE 'SAFE_CAST(`' || c.column_name || '` AS ' || m.col_type || ') AS `' || m.col_name || '`'
                END,
                ', ' ORDER BY c.ordinal_position)
            FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS` c
            LEFT JOIN (SELECT col_name, col_type, ordinal_pos FROM UNNEST(?)) m
                   ON c.ordinal_position = m.ordinal_pos
            WHERE c.table_name = ?
        """, P_dataset) INTO v_select_list USING p_columns_config, p_table_name;
    END IF;

    -- ── STEP 2b · Recover PARTITION BY / CLUSTER BY from DDL ─────────
    EXECUTE IMMEDIATE FORMAT("""
        SELECT ddl FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.TABLES` WHERE table_name = ?
    """, P_dataset) INTO v_ddl USING p_table_name;
    SET v_partition_by = TRIM(IFNULL(REGEXP_EXTRACT(v_ddl, r'(?im)^(PARTITION BY [^;\n]+)'), ''));
    SET v_cluster_by   = TRIM(IFNULL(REGEXP_EXTRACT(v_ddl, r'(?im)^(CLUSTER BY [^;\n]+)'),   ''));

    -- ── STEP 2c · Atomic rebuild — order + physical layout retained ──
    EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `mm-commissions-reporting.%s.%s`
        %s
        %s
        AS SELECT %s FROM `mm-commissions-reporting.%s.%s`
    """, P_dataset, p_table_name, v_partition_by, v_cluster_by, v_select_list, P_dataset, p_table_name);

END