BEGIN

  --CALL `mm-commissions-reporting.KRT_SAP.pr_oper_actualiza_tabla_desde_gs`("PARAM_SAP_ACREEDORES",NULL);
  -- 1. Definición de variables base
  DECLARE target_dataset STRING DEFAULT 'KRT_SAP';
  DECLARE source_dataset STRING DEFAULT 'GS';
  DECLARE project_id STRING DEFAULT 'mm-commissions-reporting';
  
  -- Variables para rutas y nombres
  DECLARE source_table_name STRING;
  DECLARE full_target_path STRING;
  DECLARE full_backup_path STRING;
  DECLARE full_source_path STRING;
  
  -- Variables para validaciones
  DECLARE target_exists INT64 DEFAULT 0;
  DECLARE source_exists INT64 DEFAULT 0;
  DECLARE rows_to_insert INT64 DEFAULT 0;
  DECLARE backup_exists INT64 DEFAULT 0;
  DECLARE has_fecha_reg_dt INT64 DEFAULT 0;
  DECLARE schema_diff_count INT64 DEFAULT 0;

  -- 2. Asignación del nombre de la tabla origen (gestionando nulos o vacíos)
  IF source_table_param IS NULL OR TRIM(source_table_param) = '' THEN
    SET source_table_name = target_table_name;
  ELSE
    SET source_table_name = source_table_param;
  END IF;
  
  -- 3. Construcción de rutas completas
  SET full_target_path = FORMAT('`%s.%s.%s`', project_id, target_dataset, target_table_name);
  SET full_backup_path = FORMAT('`%s.%s.AGG_%s`', project_id, target_dataset, target_table_name);
  SET full_source_path = FORMAT('`%s.%s.%s`', project_id, source_dataset, source_table_name);

  ------------------------------------------------------------------------
  --- FASE DE VALIDACIONES PREVIAS                                     ---
  ------------------------------------------------------------------------

  -- A. Validar que la tabla destino existe
  EXECUTE IMMEDIATE FORMAT("""
    SELECT COUNT(1) 
    FROM `%s.%s.INFORMATION_SCHEMA.TABLES` 
    WHERE table_name = '%s'
  """, project_id, target_dataset, target_table_name) INTO target_exists;
  
  IF target_exists = 0 THEN
    RAISE USING MESSAGE = FORMAT('ERROR: La tabla destino %s no existe en el dataset.', target_table_name);
  END IF;

  -- B. Validar que la tabla origen (GS) existe
  EXECUTE IMMEDIATE FORMAT("""
    SELECT COUNT(1) 
    FROM `%s.%s.INFORMATION_SCHEMA.TABLES` 
    WHERE table_name = '%s'
  """, project_id, source_dataset, source_table_name) INTO source_exists;
  
  IF source_exists = 0 THEN
    RAISE USING MESSAGE = FORMAT('ERROR: La tabla externa origen %s no existe en el dataset.', source_table_name);
  END IF;

  -- C. Validar que la tabla origen tiene datos (ignorando filas 100%% nulas)
  EXECUTE IMMEDIATE FORMAT("""
    SELECT COUNT(1) 
    FROM %s AS t 
    WHERE NOT (t IS NULL)
  """, full_source_path) INTO rows_to_insert;
  
  IF rows_to_insert = 0 THEN
    RAISE USING MESSAGE = FORMAT('ERROR: La tabla origen %s está vacía o solo contiene filas nulas. Operación abortada por seguridad.', source_table_name);
  END IF;

  -- D. Validar que la tabla backup (AGG) existe y tiene el campo fecha_reg_dt
  EXECUTE IMMEDIATE FORMAT("""
    SELECT COUNT(1) 
    FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS` 
    WHERE table_name = 'AGG_%s' AND column_name = 'fecha_reg_dt'
  """, project_id, target_dataset, target_table_name) INTO has_fecha_reg_dt;
  
  IF has_fecha_reg_dt = 0 THEN
    RAISE USING MESSAGE = FORMAT('ERROR: La tabla de backup AGG_%s no existe o no contiene el campo obligatorio "fecha_reg_dt".', target_table_name);
  END IF;

  -- E. Validar que los esquemas coinciden exactamente (excluyendo fecha_reg_dt)
    EXECUTE IMMEDIATE FORMAT("""
    SELECT 
      (SELECT COUNT(1) FROM (
        SELECT column_name FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS` WHERE table_name = '%s'
        EXCEPT DISTINCT
        SELECT column_name FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS` WHERE table_name = 'AGG_%s' AND column_name != 'fecha_reg_dt'
      ))
      +
      (SELECT COUNT(1) FROM (
        SELECT column_name FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS` WHERE table_name = 'AGG_%s' AND column_name != 'fecha_reg_dt'
        EXCEPT DISTINCT
        SELECT column_name FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS` WHERE table_name = '%s'
      ))
  """, 
    project_id, source_dataset, source_table_name,
    project_id, target_dataset, target_table_name,
    project_id, target_dataset, target_table_name,
    project_id, source_dataset, source_table_name
  ) INTO schema_diff_count;

  IF schema_diff_count > 0 THEN
    RAISE USING MESSAGE = FORMAT('ERROR: Incompatibilidad de esquema. La tabla origen %s y el backup AGG_%s no tienen las mismas columnas.', source_table_name, target_table_name);
  END IF;


  ------------------------------------------------------------------------
  --- FASE DE EJECUCIÓN (BACKUP, LIMPIEZA Y CARGA)                     ---
  ------------------------------------------------------------------------

  --- PASO 1: GESTIÓN DEL BACKUP ---
  EXECUTE IMMEDIATE FORMAT("""
    DELETE FROM %s WHERE fecha_reg_dt = CURRENT_DATE()
  """, full_backup_path);

  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO %s
    SELECT CURRENT_DATE() AS fecha_reg_dt, * FROM %s
  """, full_backup_path, full_target_path);

  --- PASO 2: LIMPIEZA DE TABLA DESTINO ---
  EXECUTE IMMEDIATE FORMAT("""
    DELETE FROM %s WHERE TRUE
  """, full_target_path);

  --- PASO 3: IMPORTACIÓN DESDE EXTERNA (GS) CON FILTRO DE NULOS ---
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO %s
    SELECT * FROM %s AS t
    WHERE NOT (t IS NULL)
  """, full_target_path, full_source_path);
  
END