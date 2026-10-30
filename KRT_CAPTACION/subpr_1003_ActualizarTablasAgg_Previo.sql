BEGIN

  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 then
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));        
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` c;	


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_DESCUENTOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_DESCUENTOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_DESCUENTOS` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_USUARIOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_USUARIOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_USUARIOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CATALOGOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CATALOGOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MARCO` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MARCO` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MULTIPLICADOR` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MULTIPLICADOR` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MULTIPLICADOR` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_NP` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_NP` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RETRASOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RETRASOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RETRASOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_TERMINALES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_TERMINALES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_TERMINALES` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_VALOR` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string)); 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_VALOR` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` c;


  end if;
    
  END