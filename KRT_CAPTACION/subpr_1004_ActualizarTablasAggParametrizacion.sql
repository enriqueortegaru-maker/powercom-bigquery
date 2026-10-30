BEGIN

  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 then

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.CANALES` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_DESCUENTOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_DESCUENTOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.CANCELACIONES_DESCUENTOS` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_USUARIOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_USUARIOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.CANCELACIONES_USUARIOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CATALOGOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CATALOGOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* FROM `mm-commissions-reporting.KRT_CAPTACION.EXTRAS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MARCO` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MARCO` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MULTIPLICADOR` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MULTIPLICADOR` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.MULTIPLICADOR` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ASIGNADO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_NP` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_NP` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.NIVELES_PRESENCIAL` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.OBJETIVOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.POSTVENTA` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RETRASOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RETRASOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.RETRASOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_TERMINALES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_TERMINALES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.TERMINALES` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_VALOR` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_VALOR` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.VALOR` c;


  end if;
    
  END