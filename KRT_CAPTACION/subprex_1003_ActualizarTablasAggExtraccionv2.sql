BEGIN


    DECLARE FECHA_CALC DATE;
    DECLARE DESDE_1M INT64;
    --LOCAL
    --DECLARE vDESDE, vHASTA, vVERSION, REGISTRO,BINVOCACIONDESARROLLO INT64;SET vDESDE=20230201;SET vHASTA=20230213;SET vVERSION=6;SET REGISTRO=1;SET BINVOCACIONDESARROLLO=1;
    SET FECHA_CALC=CURRENT_DATE();
    SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( vDESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);

---CONDICION VIEJA
--- VERSIONES PREVIAS 
---  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 and version <6 then



  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 and vversion <6 then
    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid,  desc_mm,  clase_mm, CAST(NULL  AS STRING) AS  pedido,  PLAYS AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable, mes_comision_id
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` c where  c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;   
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` 
    SELECT fecha_calc, vdesde, vhasta, vversion,  marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable,  fecha_baja_dt,  fecha_baja_id,  motivo_baja_agrup_ds,  motivo_baja_ds,  mes_decomision_id,  desc_mm,  clase_mm
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p   
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds, Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave, marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe 
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c;	


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c;	

  end if;

if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 and vversion>=6 then

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` 
    SELECT fecha_calc, vdesde, vhasta,  vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido,   nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable, mes_comision_id
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` 
    SELECT fecha_calc,vdesde,vhasta, vversion,  marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable,  fecha_baja_dt,  fecha_baja_id,  motivo_baja_agrup_ds,  motivo_baja_ds,  mes_decomision_id,  desc_mm,  clase_mm
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c;	


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_VENTAS_CAPTACION` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_VENTAS_CAPTACION` 
    SELECT fecha_calc, vdesde, vhasta,  vversion, marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, fecha_rfb_dt, fecha_venta_neta_dt, canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, categoria_servicio_ds, cif_nif, segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb, expediente_id, expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg, catalogo_id, grid, desc_mm, clase_mm, pedido, nplays, nplays_rfb, cat_plays, cat_plays_rfb, nplays_p, nplays_rfb_p, cat_plays_p, cat_plays_rfb_p
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;        
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p   
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds, Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,   expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave, marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` c where  c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe 
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c;	


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c where  c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` 
    SELECT fecha_calc, vdesde, vhasta, vversion, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c;	

  end if;

    
  END