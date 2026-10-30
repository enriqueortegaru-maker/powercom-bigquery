BEGIN

  DECLARE DESDE_1M INT64;
  SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);

  --- CREA TABLA EVENTOS CAPTACION -------
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.EVENTOS_CAPTACION` AS
  select distinct *
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`; 


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_EVENTOS_CAPTACION` AS
  SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`;

  
  --- CREA TABLA SERVICIOS CAPTACION -------
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS
  select distinct * --except(expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg,catalogo_id, grid, desc_mm, clase_mm)
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where fecha_rfb_id is not null
  and fecha_rfb_id>=desde and fecha_rfb_id<=hasta;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_SERVICIOS_CAPTACION` AS
  SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`;


  --- CREA TABLA SERVICIOS CAPTACION 1M -------
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION_1MP` AS
  select distinct * --except(expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg,catalogo_id, grid, desc_mm, clase_mm)
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where fecha_rfb_id is not null
  and fecha_rfb_id>=desde_1m and fecha_rfb_id<desde;



  --- CREA TABLA VENTAS CAPTACION -------
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS
  select distinct *
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  --where fecha_venta_neta_id>=desde_1m and fecha_venta_neta_id<=hasta;
  where fecha_venta_neta_id>=desde and fecha_venta_neta_id<=hasta;
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_VENTAS_CAPTACION` AS
  SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;





  --- INSERTA EN SERVICIOS CAPTACION LOS SERVICIOS PROCEDENTES DE MIGRACIONES EN EL MISMO MES -------

--INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
--  select cand.marca_ds, cand.Cliente_id, cand.servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, cand.FECHA_RFB_ID, cand.FECHA_VENTA_NETA_ID, cand.fecha_rfb_dt, cand.fecha_venta_neta_dt, s.canal_alta_ds, s.subcanal_ds, s.tipo_canal_alta_ds, s.nombre_distribuidor_alta_ds, s.agente_alta_id, s.agente_creador_id, cand.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, cand.marca_cartera_ds, cand.Antiguedad_Cliente, s.equipo_ds, cand.territorio_ds, cand.tecnologia_detalle_ds, cand.portabilidad_in_lg, cand.gb, s.expediente_id, s.expediente_padre_id, s.contrato_id, cand.tipo_pedido_ds, cand.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, SAFE_NEGATE(cand.grid) as grid, cand.desc_mm, cand.clase_mm, cand.pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p
-- from `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_SERVICIOS_CAPTACION` cand
 -- left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
--  on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
--  where (cand.canal_alta_ds is null or cand.canal_alta_ds in('DESCONOCIDO','OTROS', 'RETENCION')) and cand.grid<5
  --and s.categoria_servicio_ds="BANDA ANCHA"
  --and s.marca_ds="EUSKALTEL"
--  and s.fecha_rfb_id>=desde
--  and s.fecha_rfb_id<=hasta;


END