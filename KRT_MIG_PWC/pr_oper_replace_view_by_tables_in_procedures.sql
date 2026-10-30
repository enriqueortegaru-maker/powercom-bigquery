BEGIN
  DECLARE old_view STRING DEFAULT 'v_ventas_comisiones';
  DECLARE new_table STRING DEFAULT 'ventas_comisiones';
  DECLARE VSQL, QUERY_STR STRING;
 

  /*   	SELECT routine_name, routine_definition
        FROM `mm-commissions-reporting.COMISIONES.INFORMATION_SCHEMA.ROUTINES`
        WHERE routine_type = 'PROCEDURE'
        AND routine_definition LIKE CONCAT('%', old_view, '%')
  */  


  set VSQL=(SELECT view_definition
  FROM `mm-commissions-reporting.COMISIONES.INFORMATION_SCHEMA.VIEWS`
  WHERE table_name= old_view);


  set QUERY_STR=CONCAT("CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.",new_table,'` as ', vsql,';');
  EXECUTE IMMEDIATE QUERY_STR;
END