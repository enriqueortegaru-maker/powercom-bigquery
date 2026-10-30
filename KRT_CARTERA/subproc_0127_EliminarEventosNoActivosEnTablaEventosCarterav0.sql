BEGIN

  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
  WHERE Fecha_Activacion is null 
  OR Fecha_Activacion NOT BETWEEN PARSE_DATE('%Y%m%d',CAST(DESDE AS STRING)) AND PARSE_DATE('%Y%m%d',CAST(HASTA AS STRING));
  

END