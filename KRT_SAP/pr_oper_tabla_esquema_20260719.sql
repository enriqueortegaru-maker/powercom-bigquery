BEGIN
    DECLARE v_backup_name   STRING;
    DECLARE v_select_list   STRING;
    DECLARE v_ddl           STRING;
    DECLARE v_partition_by  STRING;
    DECLARE v_cluster_by    STRING;

    -- ── Guard clauses ────────────────────────────────────────────────
    IF p_operation NOT IN ('ADD','DELETE') THEN
        RAISE USING MESSAGE = "p_operation must be 'ADD' or 'DELETE'.";
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

    -- Block dropping partition / cluster keys
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

    -- ── STEP 1 · Mirror backup (data + partitions + clusters, 7-day TTL) ─
    --SET v_backup_name = FORMAT('%s_%s', p_table_name, FORMAT_DATE('%Y%m%d', CURRENT_DATE()));
    SET v_backup_name = FORMAT('%s_%s', p_table_name,FORMAT_TIMESTAMP('%Y%m%d_%H%M%S', CURRENT_TIMESTAMP(), 'Europe/Madrid' ));
    EXECUTE IMMEDIATE FORMAT("""
        CREATE TABLE `mm-commissions-reporting.KRT_SAP.%s`
        COPY `mm-commissions-reporting.KRT_SAP.%s`
        OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY))
    """, v_backup_name, p_table_name);

    -- ── STEP 2a · Build ordinal-accurate SELECT list ─────────────────
    IF p_operation = 'ADD' THEN
        -- Interleave: new col at pos P slots before the existing col at P (grp 0<1);
        -- ties among new cols broken by array offset. Renumbering is implicit via ORDER BY.
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
    ELSE  -- DELETE · keep survivors in order; gaps close automatically
        SET v_select_list = (
            SELECT STRING_AGG('`' || column_name || '`', ', ' ORDER BY ordinal_position)
            FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.COLUMNS`
            WHERE table_name = p_table_name
              AND column_name NOT IN (SELECT col_name FROM UNNEST(p_columns_config))
        );
    END IF;

    -- ── STEP 2b · Recover PARTITION BY / CLUSTER BY from source DDL ───
    SET v_ddl = (
        SELECT ddl FROM `mm-commissions-reporting.KRT_SAP.INFORMATION_SCHEMA.TABLES`
        WHERE table_name = p_table_name
    );
    SET v_partition_by = IFNULL(REGEXP_EXTRACT(v_ddl, r'(?im)^(PARTITION BY .+)$'), '');
    SET v_cluster_by   = IFNULL(REGEXP_EXTRACT(v_ddl, r'(?im)^(CLUSTER BY .+)$'),   '');

    -- ── STEP 2c · Atomic rebuild with reconstructed order + physical layout ─
    EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.%s`
        %s
        %s
        AS SELECT %s FROM `mm-commissions-reporting.KRT_SAP.%s`
    """, p_table_name, v_partition_by, v_cluster_by, v_select_list, p_table_name);

END