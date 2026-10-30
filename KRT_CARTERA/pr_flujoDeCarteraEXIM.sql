BEGIN


  -- ====================================================================
  -- Declaración de Variables
  -- ====================================================================
  DECLARE MES_COMISION, VERSION INT64;
  DECLARE SQL_DINAMICO STRING;
  --DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20251101;SET hasta=20251130;SET registro=1;SET binvocaciondesarrollo=1;

  -- ====================================================================
  -- 1. Obtener la versión correspondiente al mes
  -- ====================================================================
  SET MES_COMISION = CAST(FORMAT_DATE("%Y%m", date_trunc(parse_date('%Y%m%d', CAST(desde AS STRING)), month)) AS INT64);

  SET VERSION = (
    SELECT version
    FROM `mm-commissions-reporting.KRT_CARTERA.FLUJO_MESxVERSION`
    WHERE mes <= MES_COMISION
    ORDER BY mes DESC
    LIMIT 1
  );

  
  -- ====================================================================
  -- 2. Construir la sentencia de llamada dinámicamente
  -- ====================================================================
  -- Se concatena el nombre del procedimiento con la variable VERSION
  SET SQL_DINAMICO = CONCAT(
    "CALL `mm-commissions-reporting.KRT_CARTERA.pr_flujoDeCarterav", 
    CAST(VERSION AS STRING), 
    -- Se usan '?' como marcadores de posición para los parámetros
    "`(?, ?, ?, ?);"
  );

  -- ====================================================================
  -- 3. Ejecutar la sentencia dinámica
  -- ====================================================================
  -- Se pasa el SQL a ejecutar y se proporcionan las variables
  -- en el mismo orden que los marcadores '?' usando la cláusula USING.
  EXECUTE IMMEDIATE SQL_DINAMICO
    USING desde, hasta, registro, binvocaciondesarrollo;

END