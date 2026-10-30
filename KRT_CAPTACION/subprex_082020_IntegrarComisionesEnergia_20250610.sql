BEGIN


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    (
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
    nombre_distribuidor_alta_ds,
    agente_alta_id,
    agente_creador_id,
    categoria_servicio_ds,
    segmento_ds,
    tecnologia_detalle_ds,
    grid,
    desc_mm,
    clase_mm,
    pedido,
    marco_retributivo_ds,
    orden_sap,
    importe,
    decomisionable,
    mes_comision_id
    )

    select distinct 
    marca,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdClienteDesdeClase`(clase),
    CAST(service_id AS INT64),
    tariff_ds,
    concepto,
    CAST(format_date("%Y%m%d",activation_date) AS INT64),
    CAST(format_date("%Y%m%d",sale_date) AS INT64),
    CAST(activation_date as TIMESTAMP),
    CAST(sale_date as TIMESTAMP),
    canal_ds,
    subcanal_ds,
    distribuidor,
    seller,
    seller,
    'ENERGIA',
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerSegmentoDesdeCodSegmentoMM`(CAST(cod_Segmento AS INT64)) ,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto),
    60,
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_comisionesv1`('ENERGIA', concepto, 0,60),
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_comisionesv1`('ENERGIA', concepto, 0,60)),
    serial_number,
    marco,
    --`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca, clase),
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca, tipo,clase),
    COMISION,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerDecomisionableDesdeClase`(clase),
    id_mes,
    from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_COMISIONES_CANALIZADAS_CTX`
    where tipo="CAPTACION";

END