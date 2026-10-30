BEGIN
  -- ====================================================================
  -- Declaración de Variables
  -- ====================================================================
  DECLARE MES_COMISION, VERSION INT64;
  DECLARE SQL_DINAMICO STRING;
  DECLARE NOMBRE_PROCEDIMIENTO STRING;

  -- ====================================================================
  -- 1. Obtener la versión correspondiente al mes
  -- ====================================================================
  SET MES_COMISION = CAST(FORMAT_DATE("%Y%m", date_trunc(parse_date('%Y%m%d', CAST(desde AS STRING)), month)) AS INT64);

  SET VERSION = (
    SELECT version
    FROM `mm-commissions-reporting.KRT_CAPTACION.FLUJO_MESxVERSION`
    WHERE mes <= MES_COMISION
    ORDER BY mes DESC
    LIMIT 1
  );

  -- ====================================================================
  -- 2. Construir el nombre del procedimiento dinámicamente
  -- ====================================================================
  SET NOMBRE_PROCEDIMIENTO = CONCAT(
    "`mm-commissions-reporting.KRT_CAPTACION.prex_flujoDeCaptacionv", 
    CAST(VERSION AS STRING), 
    "`"
  );

  -- ====================================================================
  -- 3. Ejecutar la llamada con la firma de parámetros correcta
  -- ====================================================================
  
  -- Se usa un IF para manejar la excepción de v0, que tiene 3 parámetros
  IF VERSION = 0 THEN
    
    -- Construye el CALL para 3 parámetros
    SET SQL_DINAMICO = CONCAT("CALL ", NOMBRE_PROCEDIMIENTO, "(?, ?, ?);");
    
    EXECUTE IMMEDIATE SQL_DINAMICO
      USING desde, hasta, registro;
      
  ELSE
  
    -- Construye el CALL para 4 parámetros (para v1, v2, v3...)
    SET SQL_DINAMICO = CONCAT("CALL ", NOMBRE_PROCEDIMIENTO, "(?, ?, ?, ?);");
    
    EXECUTE IMMEDIATE SQL_DINAMICO
      USING desde, hasta, registro, bdesarrollo;
      
  END IF;

END