BEGIN

  -- Declaramos variables
  DECLARE mes_string, mes_liqui, sql, qry, tabla_nombre, tabla_cartera STRING;
  DECLARE mes DATE;

  SET mes =  DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
  SET mes_string = FORMAT_DATE('%Y%m', mes);     -- Ejemplo: 202509
  SET mes_liqui  = FORMAT_DATE('%Y%m%d', mes);   -- Ejemplo: 20250901
  SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','upfronts_base_arpa_', mes_liqui,'');
  SET tabla_cartera = CONCAT('mm-commissions-reporting.B2B.','comisiones_base_arpa_', mes_liqui, ''); 


  -- CALL `mm-commissions-reporting.B2B.pr_upfronts_base_arpa`() 
  
  --Si no existen transacciones para el mes, generamos la tabla
  IF NOT EXISTS(
      SELECT *
      FROM `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE canal = 'PAR'
        AND id_mes = CAST(mes_string AS INT64)
        AND (commission_id LIKE 'ARPA%'AND commission_id LIKE CONCAT("ARPA_",CAST(mes_string AS INT64),"_%"))
        AND mes_liquidado = mes
      GROUP BY ALL
  ) THEN

    
SET sql = '';
SET sql = sql || 'CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.upfronts_base_arpa` AS ';
SET sql = sql ||  'WITH base_upfront AS (';
SET sql = sql ||    'SELECT * EXCEPT(deactivation_date), ';
SET sql = sql ||      'CASE ';
SET sql = sql ||        "WHEN deactivation_date >= DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m','"|| mes_string || "'), INTERVAL 1 MONTH), MONTH) ";
SET sql = sql ||          'THEN "9999-12-31"';
SET sql = sql ||        'ELSE deactivation_date ';
SET sql = sql ||      'END AS deactivation_date ';
SET sql = sql ||    "FROM "|| tabla_cartera || " base ";
SET sql = sql ||    'WHERE 1 = 1 ';
SET sql = sql ||      'AND base.TIPO_PAQUETE = "FMC" ';
SET sql = sql ||      'AND service_type = "INTERNET" ';
SET sql = sql ||      "AND activation_date BETWEEN PARSE_DATE('%Y%m','"|| mes_string || "') ";
SET sql = sql ||                              "AND LAST_DAY(PARSE_DATE('%Y%m','"|| mes_string || "')) ";
SET sql = sql ||      "AND deactivation_date >= DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m','"|| mes_string || "'), INTERVAL 1 MONTH), MONTH) ";
SET sql = sql ||    'QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1 ';
SET sql = sql ||  ') ';
SET sql = sql ||  'SELECT * ';
SET sql = sql ||  'FROM base_upfront ';
SET sql = sql ||'' ;



EXECUTE IMMEDIATE sql;

    -- Y ahora creamos la tabla final
    SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ''' AS 
               SELECT * FROM `mm-commissions-reporting.TEMP.upfronts_base_arpa`''';

    EXECUTE IMMEDIATE qry;

  END IF;

END