BEGIN 

  DECLARE FECHA_CALC DATE;
  DECLARE HORA_CALC TIME;
  DECLARE BEXISTE INT64;
  SET FECHA_CALC=CURRENT_DATE('Europe/Madrid');
  SET HORA_CALC=CURRENT_TIME('Europe/Madrid');

  --DELETE FROM `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` t where fecha_calc_dt!=FECHA_CALC and nombre=vtabla; --and t.desde=vdesde and t.hasta=vhasta and t.version=vversion;
  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` t where nombre=vtabla and (date_DIFF(FECHA_CALC,t.fecha_calc_dt,DAY)!=0 or t.desde!=vdesde or t.hasta!=vhasta or t.version=vversion);  
  SET BEXISTE=(SELECT COUNT(FECHA_CALC_DT) FROM  `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` t WHERE date_DIFF(FECHA_CALC,t.fecha_calc_dt,DAY)=0 AND t.nombre=vtabla and t.desde=vdesde and t.hasta=vhasta and t.version=vversion);
  IF BEXISTE=0 THEN 
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` VALUES (FECHA_CALC, HORA_CALC, vtabla, vdesde, vhasta, vversion);
  END IF;

END