BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION_MM.OUT_COMISIONES` AS 
  SELECT
    marca_ds,
    Cliente_id,
    servicio_id,
    detalle_servicio_ds,
    CONCEPTO_DS,
    FECHA_RFB_ID,
    FECHA_VENTA_NETA_ID,
    fecha_rfb_dt,
    fecha_venta_neta_dt,
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
    NULL expediente_id,
    NULL clave,
    NULL marco_retributivo_ds,
    NULL flag_marca_cartera,
    NULL grupo_rappel_ds,
    NULL orden_sap,
    importe_dealer + importe_gestor + importe_porta_dealer + importe_porta_gestor + importe_segmento importe,
    'S' decomisionable,
    NULL VALOR
  FROM
    `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES`;

END