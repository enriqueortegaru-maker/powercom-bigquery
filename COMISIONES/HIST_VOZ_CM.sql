BEGIN
  
  DECLARE table_name STRING;
  DECLARE sql_query STRING;
  DECLARE input_date DATE;
  
  SET input_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

  -- Generar el nombre de la tabla basado en la fecha proporcionada
  SET table_name = FORMAT("mm-dwh-prod.00_SANDBOX_XENA.XENA_HISTORICO_VOZ_%s", FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(input_date)));

  -- Construir la consulta
  SET sql_query = FORMAT("""
    CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.HISTORICO_VOZ_CABLEMOVIL` AS
    SELECT *
    FROM `%s`
  """, table_name);

  -- Ejecutar la consulta
  EXECUTE IMMEDIATE sql_query;
END