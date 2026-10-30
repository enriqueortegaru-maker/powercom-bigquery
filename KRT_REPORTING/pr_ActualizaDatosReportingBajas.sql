BEGIN 


  --- PASO 0: ACTUALIZO TABLA BASE REPORTING DE BAJAS
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_REPORTING.T_reporting_bajas24M` as 
  select * from `mm-commissions-reporting.KRT_REPORTING.reporting_bajas24M`;

  --- PASO 1: DESCUBRO LISTADO DE PORTABILIDADES SALIENTES
/*  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_REPORTING.BAJAS24M_Y_PORTABILIDADES_SALIENTES_LIST` as 
  select distinct b.marca_ds, b.cliente_id, b.servicio_id, b.fecha_rfb_dt, b.fecha_baja_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds, fecha_ventana_cambio_dt,operador_receptor_ds,marca_operador_receptor_ds,grupo_operador_receptor_ds,agrup_operador_receptor_ds, date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt), DAY) as ndias, 
  from `mm-commissions-reporting.KRT_REPORTING.T_reporting_bajas24M_DES` b
  inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_120_portabilidad_fijo` p
  --on p.servicio_donante_id=b.servicio_id
  on p.cliente_donante_id=b.cliente_id
  where agrup_operador_donante_ds='GRUPO EUSKALTEL'
  and ABS(date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt),  DAY))<30
  and p.estado_portabilidad_fijo_ds="CONFIRMADA";

*/
  --- PASO 2: IDENTIFICO SERVICIOS CON MULTIPLES PORTABILIDADES SALIENTES



  --- PASO 3: CREO LISTADO COM PORTABILIDADES SALIENTES UNICAS
  


  /*

  select b.marca_ds, b.cliente_id, b.servicio_id, b.fecha_rfb_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds, fecha_ventana_cambio_dt,operador_receptor_ds,marca_operador_receptor_ds,grupo_operador_receptor_ds,agrup_operador_receptor_ds
  from `mm-commissions-reporting.KRT_REPORTING.T_reporting_bajas24M_DES` b
  inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_130_portabilidad_movil` p
  --on p.servicio_donante_id=b.servicio_id
  on p.cliente_donante_id=b.cliente_id
  where agrup_operador_donante_ds='GRUPO EUSKALTEL'
  and ABS(date_diff( EXTRACT(DATE FROM b.fecha_rfb_dt), fecha_ventana_cambio_dt, DAY))<30;

  */

END