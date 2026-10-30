BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION_MM.OUT_INFORME_COMISIONES` AS 
  SELECT
    DISTINCT marca_ds,
    Cliente_id,
    servicio_id,
    detalle_servicio_ds,
    CONCEPTO_DS,
    fecha_rfb_dt AS Fecha_activacion_flujo,
    fecha_venta_neta_dt,
    canal_alta_ds,
    subcanal_ds,
    tipo_canal_alta_ds,
    nombre_distribuidor_alta_ds,
    agente_alta_id,
    agente_creador_id,
    categoria_servicio_ds,
    cif_nif,
    CONCAT(c.swName,' ', c.swApellido, ' ', c.swSegundoApellido) Nombre_cliente,
    p.swContratoFisicoId Id_contrato,
    p.swANI,
    segmento_ds,
    equipo_ds,
    tecnologia_detalle_ds,
    portabilidad_in_lg,
    gb,
    Cambio Migracion,
    multiplicador,
    marco_retributivo_ds,
    importe_dealer,
    importe_gestor,
    importe_porta_dealer,
    importe_porta_gestor,
    importe_segmento,
    MAX(o.swOpportunityId) OVER (PARTITION BY cliente_id, marca_ds) id_oportunidad
  FROM
    `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES` a
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c
  ON
    a.cliente_id = c.swCustomerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
  ON
    a.servicio_id = p.swInstProdId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_oportunidad` o
  ON
    a.cliente_id = o.swCustomerId;

END