BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CANCELACIONES_CAPTACION`  AS 			
  select distinct marca_ds,  Cliente_id, servicio_id ,  detalle_servicio_ds,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds, segmento_ds, equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,CASE WHEN categoria_servicio_ds = 'BANDA ANCHA' THEN velocidad_mb  ELSE  gb END gb
, fecha_venta_neta_id, fecha_operacion_alta_id, fecha_rfb_id, fecha_baja_id, fecha_cancelacion_id, fecha_venta_neta_dt, fecha_operacion_alta_dt, fecha_rfb_dt, fecha_baja_dt, fecha_cancelacion_dt  
  from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
  where fecha_venta_neta_id >=DESDE and fecha_venta_neta_id<=HASTA
  and fecha_cancelacion_id <99991200;

END