BEGIN

  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 then
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.* except(PLAYS_RFB)
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));        
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES_MAS_TIPIFICACION` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES_MAS_TIPIFICACION` 
    SELECT parse_date ('%Y%m%d', CAST ( hasta AS string))  as fecha_calc_dt, c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES_MAS_TIPIFICACION` c;	

  end if;
    
  END