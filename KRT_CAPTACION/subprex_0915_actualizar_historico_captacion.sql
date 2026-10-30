BEGIN
  DECLARE target_table STRING;
  DECLARE sql_query STRING;
  DECLARE target_month_dt DATE;
  DECLARE execution_id STRING DEFAULT GENERATE_UUID();
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE duration_sec INT64;
  DECLARE rows_impacted INT64;

  -- Conversión segura a DATE
  SET target_month_dt = SAFE.PARSE_DATE('%Y%m%d', CAST(target_month AS STRING));

  -- Validación de parámetros de entrada
  IF target_month IS NULL OR target_month_dt IS NULL OR tipo_operacion_param NOT IN ('C', 'D') THEN
    SELECT ERROR('Parámetros de entrada incorrectos o nulos.');
  END IF;

  IF tipo_operacion_param = 'C' THEN
    SET target_table = '`mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO`';
  ELSE
    SET target_table = '`mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO`';
  END IF;

  SET sql_query = """
    MERGE INTO """ || target_table || """ T
    USING (
      WITH lote_entrante AS (
        SELECT 
          id_comision, mes_factura_dt, marca_ds, categoria_servicio_ds,
          detalle_servicio_ds, desc_mm, service_id, importe, clase_operacion
        FROM `mm-commissions-reporting.KRT_CAPTACION.STG_CAPTACION_LOTE`
        WHERE mes_factura_dt = @target_month
          AND clase_operacion = @tipo_operacion
      ),

      dimension_entrante_unica AS (
        SELECT DISTINCT marca_ds, categoria_servicio_ds, detalle_servicio_ds, desc_mm FROM lote_entrante
      ),

      dimension_con_udfs AS (
        SELECT
          *,
          `mm-commissions-reporting.KRT_SAP`.f_trans_crea_crm_desde_categoria_servicio(marca_ds, categoria_servicio_ds) AS crm_rec,
          `mm-commissions-reporting.KRT_CAPTACION`.f_trans_crea_service_type(categoria_servicio_ds, detalle_servicio_ds) AS st_rec
        FROM dimension_entrante_unica
      ),

      dimension_con_raiz AS (
        SELECT
          D.*,
          `mm-commissions-reporting.KRT_MIG_PWC`.f_cid_origen('P', D.crm_rec, D.st_rec) AS origen4,
          `mm-commissions-reporting.KRT_MIG_PWC`.f_cid_desc(COALESCE(D.desc_mm, CAST(NULL AS STRING))) AS desc3
        FROM dimension_con_udfs D
      ),

      dimension_raiz_completa AS (
        SELECT
          DR.*,
          `mm-commissions-reporting.KRT_MIG_PWC`.f_cid_raiz(
            DR.marca_ds, @tipo_operacion, 'P', @target_month, DR.origen4, DR.desc3
          ) AS raiz
        FROM dimension_con_raiz DR
      ),

      registros_existentes AS (
        -- Leemos directamente de las columnas físicas nativas
        SELECT raiz, hex6, MAX(nn) AS max_nn
        FROM """ || target_table || """
        WHERE mes_factura_dt = @target_month AND raiz IS NOT NULL
        GROUP BY 1, 2
      ),

      lote_con_raiz AS (
        SELECT
          L.*, R.raiz,
          `mm-commissions-reporting.KRT_MIG_PWC`.f_cid_hex6(CAST(L.service_id AS STRING), CAST(L.importe AS BIGNUMERIC)) AS hex6
        FROM lote_entrante L
        JOIN dimension_raiz_completa R
          ON L.marca_ds = R.marca_ds
         AND L.categoria_servicio_ds = R.categoria_servicio_ds
         AND L.detalle_servicio_ds = R.detalle_servicio_ds
         AND COALESCE(L.desc_mm, '') = COALESCE(R.desc_mm, '')
      ),

      lote_salado AS (
        SELECT *, MOD(ABS(FARM_FINGERPRINT(id_comision)), 4) AS salt FROM lote_con_raiz
      ),

      conteos_salados AS (
        SELECT raiz, hex6, salt, COUNT(*) AS cnt FROM lote_salado GROUP BY 1, 2, 3
      ),

      desplazamientos_acumulados AS (
        SELECT
          raiz, hex6, salt,
          COALESCE(SUM(cnt) OVER (
            PARTITION BY raiz, hex6 ORDER BY salt ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
          ), 0) AS salt_offset
        FROM conteos_salados
      ),

      secuencial_distribuido AS (
        SELECT
          LS.*,
          COALESCE(E.max_nn, 0) + O.salt_offset + ROW_NUMBER() OVER (
            PARTITION BY LS.raiz, LS.hex6, LS.salt ORDER BY LS.id_comision ASC
          ) AS nn
        FROM lote_salado LS
        JOIN desplazamientos_acumulados O
          ON LS.raiz = O.raiz AND LS.hex6 = O.hex6 AND LS.salt = O.salt
        LEFT JOIN registros_existentes E 
          ON LS.raiz = E.raiz AND LS.hex6 = E.hex6
      )

      SELECT
        SD.*,
        `mm-commissions-reporting.KRT_MIG_PWC`.f_cid_compone(raiz, hex6, nn) AS calculated_commission_id
      FROM secuencial_distribuido SD
    ) S
    -- CRUCE POR CLAVE PRIMARIA REAL: commission_id
    ON T.commission_id = S.calculated_commission_id AND T.mes_factura_dt = @target_month
    
    WHEN MATCHED THEN
      -- Sincronización de datos mutables aplicando SAFE_CAST a INT64 sobre servicio_id
      UPDATE SET 
        T.importe = S.importe,
        T.servicio_id = SAFE_CAST(S.service_id AS INT64)
        
    WHEN NOT MATCHED THEN
      -- Inserción utilizando el esquema real con el casteo correspondiente de tipos nativos
      INSERT (
        mes_factura_dt, servicio_id, importe, commission_id, raiz, hex6, nn
      )
      VALUES (
        S.mes_factura_dt, SAFE_CAST(S.service_id AS INT64), S.importe, S.calculated_commission_id, S.raiz, S.hex6, S.nn
      );
  """;

  BEGIN
    EXECUTE IMMEDIATE sql_query
    USING target_month_dt AS target_month, tipo_operacion_param AS tipo_operacion;

    SET rows_impacted = @@row_count;
    SET duration_sec = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND);

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_EJECUCION_PROCEDIMIENTOS` (
      id_log, nombre_procedimiento, target_month, tipo_operacion, estado, mensaje_error, sentencia_ejecutada, stack_trace, filas_afectadas, duracion_segundos
    )
    VALUES (execution_id, 'pr_actualizar_historico_captacion', target_month_dt, tipo_operacion_param, 'OK', 'Éxito.', sql_query, NULL, rows_impacted, duration_sec);

  EXCEPTION WHEN ERROR THEN
    SET duration_sec = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND);
    
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_EJECUCION_PROCEDIMIENTOS` (
      id_log, nombre_procedimiento, target_month, tipo_operacion, estado, mensaje_error, sentencia_ejecutada, stack_trace, filas_afectadas, duracion_segundos
    )
    VALUES (execution_id, 'pr_actualizar_historico_captacion', target_month_dt, tipo_operacion_param, 'ERROR', @@error.message, sql_query, @@error.formatted_stack_trace, 0, duration_sec);
    
    SELECT ERROR(CONCAT('Fallo en pr_actualizar_historico_captacion. Traza: ', execution_id));
  END;
END