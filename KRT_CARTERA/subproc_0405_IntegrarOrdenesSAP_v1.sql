BEGIN


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0405_COMISIONES_PREVIO` as 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` as 
  select distinct c.*, 
  case when contains_Substr(c.tipoMovimiento,'equipamiento') 
  --or contains_Substr(c.tipoMovimiento,'terminal')  
  --or contains_Substr(c.tipoMovimiento,'dispositivo') 
  Then ca.orden_sap_terminales else  ca.orden_sap_servicios end as orden_sap
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c 
  left join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`ca on ca.marca_ds=c.marca_ds and ca.canal=c.canal and ca.subcanal= c.subcanal 
  and ca.nombre_distribuidor=c.nombre_distribuidor and ca.agrupador_mr=c.MARCO_RETRIBUTIVO  and not contains_substr(c.canal,"B2B");

  --- INTEGRAR CODIGO SAP EN EXTRAS QUE NO SE DISTRIBUYEN

  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET c.orden_sap=e.orden_sap
  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS` e
  WHERE e.marca_ds=c.marca_ds
  and e.canal=c.canal
  and e.subcanal=c.subcanal
  and e.nombre_distribuidor=c.nombre_distribuidor
  and UPPER(TRIM(e.distribuir))="N"
  and c.clase_mm="D - Extracomision"
  and c.IdProducto is null
  and e.orden_sap > 0 
  and c.orden_sap is null
  and e.importe !=0 /*importe informado en parametrizacion*/
  and e.importe=c.bono_extras;
  



  -----PDTE GESTIONAR CODIGO SAP COMISIONES CARTERA B2B

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0405_COMISIONES` as 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;



END