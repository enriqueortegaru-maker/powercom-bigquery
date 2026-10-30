BEGIN

  DECLARE DESDE int64;
  --- LOCAL
  --- DECLARE HASTA,REGISTRO, BINVOCACIONDESARROLLO INT64; SET HASTA=20240331;SET REGISTRO=1;SET BINVOCACIONDESARROLLO=1;
  SET DESDE=CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(HASTA AS STRING)), MONTH)) AS INT64); 
  
  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 then

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_DESCUENTOS` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_DESCUENTOS` 
	SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_DESCUENTOS` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_USUARIOS` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANCELACIONES_USUARIOS` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_USUARIOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CATALOGOS` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CATALOGOS` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MARCO` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MARCO` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MULTIPLICADOR` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_MULTIPLICADOR` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MULTIPLICADOR` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,	
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_NP` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_NP` 
    SELECT CURRENT_DATE() as fecha_calc_dt,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,	
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RETRASOS` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RETRASOS` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RETRASOS` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_TERMINALES` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_TERMINALES` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_TERMINALES` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_VALOR` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_VALOR` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_PUBLICACION` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_PUBLICACION` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` c;


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANAL_PLAY` c where c.fecha_calc_dt=CURRENT_DATE() and c.desde=DESDE; 
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANAL_PLAY` 
    SELECT CURRENT_DATE() as fecha_calc_dt ,
	DESDE,
	HASTA,
	c.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` c;

  end if;
    
  END