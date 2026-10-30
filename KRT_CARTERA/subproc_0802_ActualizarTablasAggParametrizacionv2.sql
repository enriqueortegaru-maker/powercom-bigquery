BEGIN

  DECLARE VFECHA_CALC_DT DATE;
  DECLARE VDESDE INT64;
  --DECLARE VHASTA, REGISTRO, BINVOCACIONDESARROLLO INT64; SET VHASTA=20241031;SET REGISTRO=1;SET BINVOCACIONDESARROLLO=1;  
  SET VDESDE=CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(VHASTA AS STRING)), MONTH)) AS INT64);   
  SET VFECHA_CALC_DT=CURRENT_DATE('Europe/Madrid');


  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 then

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_BONUS_CALIDAD_COMERCIAL` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA; 
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_BONUS_CALIDAD_COMERCIAL` 
    SELECT VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_BONUS_CALIDAD_COMERCIAL` c;   

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CAMPANAS` c where c.fecha_calc_dt=vFECHA_CALC_DT  and c.desde=VDESDE and c.hasta=VHASTA; 
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CAMPANAS`     
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c;


    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CANALES` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA;
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CANALES` 
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    clave,
    marca_ds,
    TIPO_CANAL,
    nombre_distribuidor,
    --CAST(NULL) equipo,
    equipo,
    canal,
    subcanal,
    agente,
    agrupador_mr,
    marca_cartera,
    TELEVENTA,
    TVT_UPS_VIRGIN,
    NIVEL_TVT_UPS_VIRGIN,
    orden_sap_servicios,
    orden_sap_terminales,
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` c;


    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CATALOGO` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA;
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CATALOGO` 
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c;


    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_MARCO_RETRIBUTIVO` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA; 
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_MARCO_RETRIBUTIVO` 
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO` c;
        

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_MR_TVT_UPS` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA; 
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_MR_TVT_UPS` 
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_MR_TVT_UPS` c;

    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_NIVELCONSEGUIDO_TIPOMOVIMIENTO` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA;
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_NIVELCONSEGUIDO_TIPOMOVIMIENTO` 
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.*  
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_NIVELCONSEGUIDO_TIPOMOVIMIENTO` c;
    
    
    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_TERMINALES` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA; 
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_TERMINALES` 
    SELECT  VFECHA_CALC_DT as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.*  
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES` c;       
    
    
    DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_TRAMOS_RAPPEL_OBJETIVOS` c where c.fecha_calc_dt=vFECHA_CALC_DT and c.desde=VDESDE and c.hasta=VHASTA;
    INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_TRAMOS_RAPPEL_OBJETIVOS` 
    SELECT VFECHA_CALC_DT  as fecha_calc_dt, 
	  vDESDE,
	  vHASTA,
    c.* 
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_TRAMOS_RAPPEL_OBJETIVOS` c;   
    
  end if;
    
  END