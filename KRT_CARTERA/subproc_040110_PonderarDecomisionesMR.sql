BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040110_DECOMISIONES_PREV` AS
  SELECT *  from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` ;


  UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
  SET importe=`mm-commissions-reporting.KRT_CARTERA.f_pondera_importe_decomision_canal`(CAST(fechaDesinstalacion AS DATE), CAST(Fecha_Activacion AS DATE),importe), 
  importe_nivel=`mm-commissions-reporting.KRT_CARTERA.f_pondera_importe_decomision_canal`(CAST(fechaDesinstalacion AS DATE), CAST(Fecha_Activacion AS DATE),importe_nivel), 
  bono_comercial=`mm-commissions-reporting.KRT_CARTERA.f_pondera_importe_decomision_canal`(CAST(fechaDesinstalacion AS DATE), CAST(Fecha_Activacion AS DATE),bono_comercial),
  --bono_total=`mm-commissions-reporting.KRT_CARTERA.f_pondera_importe_decomision_canal`(CAST(fechaDesinstalacion AS DATE), CAST(Fecha_Activacion AS DATE),bono_total), 
  bono_extras=`mm-commissions-reporting.KRT_CARTERA.f_pondera_importe_decomision_canal`(CAST(fechaDesinstalacion AS DATE), CAST(Fecha_Activacion AS DATE),bono_extras),                 
  total=`mm-commissions-reporting.KRT_CARTERA.f_pondera_importe_decomision_canal`(CAST(fechaDesinstalacion AS DATE), CAST(Fecha_Activacion AS DATE),total) 
  where (contains_substr(MARCO_RETRIBUTIVO," fideliza") or contains_substr(MARCO_RETRIBUTIVO," atc") )
  and date_diff(fechaDesinstalacion,fecha_activacion,DAY)>60
  and coalesce(total,0)<0;


  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` 
  where  (contains_substr(MARCO_RETRIBUTIVO," fideliza") or contains_substr(MARCO_RETRIBUTIVO," atc") ) 
  and  date_diff(fechaDesinstalacion,fecha_activacion,DAY)> 90;



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040110_DECOMISIONES_FINAL` AS
  SELECT *  from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` ;



END