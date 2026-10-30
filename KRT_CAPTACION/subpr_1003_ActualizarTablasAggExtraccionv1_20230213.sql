BEGIN

    DECLARE FECHA_CALC DATE;
    --DECLARE DESDE, HASTA, VERSION INT64;
    SET FECHA_CALC=CURRENT_DATE();
    --SET DESDE=20230201;
    --SET HASTA=20230214;
    --SET VERSION=5;


  --- VERSIONES PREVIAS 
  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 and version <6 then

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c where c.fecha_calc_dt=fecha_calc;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` 
    SELECT fecha_calc, desde, hasta,  NULL as version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid,  desc_mm,  clase_mm, CAST(NULL  AS STRING) AS  pedido,  PLAYS AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable, mes_comision_id
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` c where c.fecha_calc_dt=fecha_calc;    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` 
    SELECT fecha_calc,desde,hasta, version,  marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable,  fecha_baja_dt,  fecha_baja_id,  motivo_baja_agrup_ds,  motivo_baja_ds,  mes_decomision_id,  desc_mm,  clase_mm
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));        
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` 
    SELECT fecha_calc, desde, hasta, version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p   
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` 
    SELECT fecha_calc, desde,hasta, version, Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave, marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` 
    SELECT fecha_calc, desde, hasta, version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe 
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c;	


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` 
    SELECT fecha_calc, desde, hasta, version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid, CAST(NULL  AS STRING) AS  desc_mm, CAST(NULL  AS STRING) AS  clase_mm, CAST(NULL  AS STRING) AS  pedido, NULL AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c;	

  end if;

  --- VERSION 6
  if  REGISTRO > 0 and  BINVOCACIONDESARROLLO > 0 and version =6 then


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c where c.fecha_calc_dt=fecha_calc;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` 
    SELECT fecha_calc, desde, hasta,  NULL as version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido,   nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable, mes_comision_id
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` c where c.fecha_calc_dt=fecha_calc;    
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` 
    SELECT fecha_calc,desde,hasta, version,  marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable,  fecha_baja_dt,  fecha_baja_id,  motivo_baja_agrup_ds,  motivo_baja_ds,  mes_decomision_id,  desc_mm,  clase_mm
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c;	



    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));        
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` 
    SELECT fecha_calc, desde, hasta, version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p   
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` 
    SELECT fecha_calc, desde,hasta, version, Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,   expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave, marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_BAJA_PREVIA` c;	

    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` 
    SELECT fecha_calc, desde, hasta, version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe 
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c;	


    DELETE  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c where c.fecha_calc_dt=PARSE_DATE('%Y%m%d', CAST ( hasta AS string));     
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` 
    SELECT fecha_calc, desde, hasta, version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS,  FECHA_RFB_ID,  FECHA_VENTA_NETA_ID,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id,  expediente_padre_id, contrato_id,  tipo_pedido_ds, pedido_id,  tipo_producto_pedido_re_ds, visibilidad_pedido_lg,  catalogo_id, grid,  desc_mm,  clase_mm,  pedido, nplays, nplays_rfb,  cat_plays,  cat_plays_rfb, nplays_p, nplays_rfb_p,  cat_plays_p,  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable
    FROM `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` c;	

  end if;

    
  END