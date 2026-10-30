BEGIN
  DECLARE v_tablas   ARRAY<STRING>;
  DECLARE v_tab      STRING;
  DECLARE v_pred     STRING;
  DECLARE v_ctas_sql STRING;
  DECLARE v_origen   INT64;
  DECLARE v_dest     INT64;
  DECLARE i          INT64 DEFAULT 0;
  DECLARE v_errores  ARRAY<STRING> DEFAULT [];

  IF (tablas IS NOT NULL AND ARRAY_LENGTH(tablas) > 0) AND (prefijo IS NOT NULL AND TRIM(prefijo) != '') THEN
    RAISE USING MESSAGE = 'pr_fl_importaParametrizaciones_opt: supply either prefijo or tablas, not both.';
  END IF;
  IF dataset_origen IS NULL OR TRIM(dataset_origen) = '' THEN
    RAISE USING MESSAGE = 'dataset_origen is required.';
  END IF;
  IF dataset_destino IS NULL OR TRIM(dataset_destino) = '' THEN
    RAISE USING MESSAGE = 'dataset_destino is required.';
  END IF;

  IF tablas IS NOT NULL AND ARRAY_LENGTH(tablas) > 0 THEN
    SET v_tablas = tablas;
  ELSEIF prefijo IS NOT NULL AND TRIM(prefijo) != '' THEN
    EXECUTE IMMEDIATE FORMAT("""
      SELECT ARRAY_AGG(table_name ORDER BY table_name)
      FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.TABLES`
      WHERE STARTS_WITH(table_name, @pref)
    """, dataset_origen)
    INTO v_tablas
    USING prefijo AS pref;
  ELSE
    RAISE USING MESSAGE = 'pr_fl_importaParametrizaciones_opt: supply either prefijo or tablas.';
  END IF;

  IF v_tablas IS NULL OR ARRAY_LENGTH(v_tablas) = 0 THEN
    RAISE USING MESSAGE = FORMAT('No tables found in dataset %s matching the supplied criteria.', dataset_origen);
  END IF;

  WHILE i < ARRAY_LENGTH(v_tablas) DO
    SET v_tab = v_tablas[OFFSET(i)];

    IF NOT REGEXP_CONTAINS(v_tab, r'^[A-Za-z][A-Za-z0-9_]*$') THEN
      INSERT INTO `mm-commissions-reporting`.KRT_MIG_PWC.LOG_REPLICA_PARAM
        (ts, dataset_origen, dataset_destino, tabla, estado, mensaje_error)
      VALUES (CURRENT_TIMESTAMP(), dataset_origen, dataset_destino, v_tab, 'SKIP_INVALID_NAME', FORMAT('Rejected identifier: %s', v_tab));
      SET v_errores = ARRAY_CONCAT(v_errores, [v_tab]);
    ELSE
      BEGIN
        -- Construcción defensiva del predicado para tolerar literales "None" en tipos de fecha
        EXECUTE IMMEDIATE FORMAT("""
          SELECT STRING_AGG(
            CASE WHEN data_type = 'STRING'
                 THEN FORMAT('(`%%s` IS NULL OR TRIM(`%%s`) IN ("", "None"))', column_name, column_name)
                 WHEN data_type IN ('DATETIME', 'DATE', 'TIMESTAMP')
                 THEN FORMAT('(`%%s` IS NULL OR TRIM(CAST(`%%s` AS STRING)) IN ("", "None"))', column_name, column_name)
                 ELSE FORMAT('`%%s` IS NULL', column_name)
            END,
            ' AND ' ORDER BY ordinal_position)
          FROM `mm-commissions-reporting.%s.INFORMATION_SCHEMA.COLUMNS`
          WHERE table_name = @tab
        """, dataset_origen)
        INTO v_pred
        USING v_tab AS tab;

        EXECUTE IMMEDIATE FORMAT('SELECT COUNT(*) FROM `mm-commissions-reporting.%s.%s`', dataset_origen, v_tab) INTO v_origen;

        IF v_origen = 0 THEN
          INSERT INTO `mm-commissions-reporting`.KRT_MIG_PWC.LOG_REPLICA_PARAM
            (ts, dataset_origen, dataset_destino, tabla, filas_origen, estado, mensaje_error)
          VALUES (CURRENT_TIMESTAMP(), dataset_origen, dataset_destino, v_tab, 0, 'SKIP_ZERO_SOURCE', 'Source returned 0 rows. Existing snapshot preserved.');
          SET v_errores = ARRAY_CONCAT(v_errores, [v_tab]);
        ELSE
          IF v_pred IS NOT NULL THEN
            SET v_ctas_sql = FORMAT("""
              CREATE OR REPLACE TABLE `mm-commissions-reporting.%s.%s` AS
              SELECT * FROM `mm-commissions-reporting.%s.%s`
              WHERE NOT (%s)
            """, dataset_destino, v_tab, dataset_origen, v_tab, v_pred);
          ELSE
            SET v_ctas_sql = FORMAT("""
              CREATE OR REPLACE TABLE `mm-commissions-reporting.%s.%s` AS
              SELECT * FROM `mm-commissions-reporting.%s.%s`
            """, dataset_destino, v_tab, dataset_origen, v_tab);
          END IF;

          EXECUTE IMMEDIATE v_ctas_sql;

          EXECUTE IMMEDIATE FORMAT('SELECT COUNT(*) FROM `mm-commissions-reporting.%s.%s`', dataset_destino, v_tab) INTO v_dest;

          INSERT INTO `mm-commissions-reporting`.KRT_MIG_PWC.LOG_REPLICA_PARAM
            (ts, dataset_origen, dataset_destino, tabla, filas_origen, filas_destino, filas_purgadas, predicado_purga, estado)
          VALUES (CURRENT_TIMESTAMP(), dataset_origen, dataset_destino, v_tab, v_origen, v_dest, v_origen - v_dest, v_pred, IF(v_pred IS NOT NULL, 'OK', 'OK_NO_PRED'));
        END IF;

      EXCEPTION WHEN ERROR THEN
        INSERT INTO `mm-commissions-reporting`.KRT_MIG_PWC.LOG_REPLICA_PARAM
          (ts, dataset_origen, dataset_destino, tabla, estado, mensaje_error)
        VALUES (CURRENT_TIMESTAMP(), dataset_origen, dataset_destino, v_tab, 'ERROR', @@error.message);
        SET v_errores = ARRAY_CONCAT(v_errores, [v_tab]);
      END;
    END IF;

    SET i = i + 1;
  END WHILE;

  IF ARRAY_LENGTH(v_errores) > 0 THEN
    RAISE USING MESSAGE = FORMAT(
      'pr_fl_importaParametrizaciones_opt: %d table(s) failed or skipped: [%s]. See KRT_MIG_PWC.LOG_REPLICA_PARAM.',
      ARRAY_LENGTH(v_errores), ARRAY_TO_STRING(v_errores, ', '));
  END IF;
END