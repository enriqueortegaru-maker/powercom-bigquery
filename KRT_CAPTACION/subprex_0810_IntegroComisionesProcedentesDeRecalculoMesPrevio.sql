BEGIN


--  DECLARE vmes_comision_id INT64;
  --DECLARE DESDE INT64;
  --SET DESDE=20230301;
--  SET vmes_comision_id=CAST(DESDE/100 AS INT64);
  
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` 
  --SELECT c.* except(mes_comision_id), vmes_comision_id as mes_comision_id
  SELECT 
    marca_ds,
    Cliente_id,
    servicio_id,
    detalle_servicio_ds,
    CONCEPTO_DS,
    FECHA_RFB_ID,
    FECHA_VENTA_NETA_ID,
    --fecha_rfb_dt,
    --fecha_venta_neta_dt,
    `mm-commissions-reporting.KRT_REPORTING.f_validarTimestamp`(fecha_rfb_dt, fecha_rfb_id) as fecha_rfb_dt,
    `mm-commissions-reporting.KRT_REPORTING.f_validarTimestamp`(fecha_venta_neta_dt, fecha_venta_neta_id) as fecha_venta_neta_dt,
    canal_alta_ds,
    subcanal_ds,
    tipo_canal_alta_ds,
    nombre_distribuidor_alta_ds,
    agente_alta_id,
    agente_creador_id,
    categoria_servicio_ds,
    cif_nif,
    segmento_ds,
    subsegmento_ds,
    marca_cartera_ds,
    Antiguedad_Cliente,
    equipo_ds,
    territorio_ds,
    tecnologia_detalle_ds,
    portabilidad_in_lg,
    gb,
    expediente_id,
    expediente_padre_id,
    contrato_id,
    tipo_pedido_ds,
    pedido_id,
    tipo_producto_pedido_re_ds,
    visibilidad_pedido_lg,
    catalogo_id,
    grid,
    desc_mm,
    clase_mm,
    pedido,
    nplays,
    nplays_rfb,
    cat_plays,
    cat_plays_rfb,
    nplays_p,
    nplays_rfb_p,
    cat_plays_p,
    cat_plays_rfb_p,
    clave,
    marco_retributivo_ds,
    flag_marca_cartera,
    grupo_rappel_ds,
    orden_sap,
    importe,
    decomisionable,
    mes_comision_id,
  FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RECALCULO` as c;


END