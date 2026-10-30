BEGIN

	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
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
	categoria_servicio_ds,
	segmento_ds,
	marco_retributivo_ds,
	orden_sap,
	importe,
	decomisionable,
	fecha_baja_dt,
	fecha_baja_id,
	mes_decomision_id,
	desc_mm,
	clase_mm
	)

	---LOCAL 
--	DECLARE DESDE, HASTA INT64; SET DESDE=20250201;SET HASTA=20250228;
	SELECT distinct 
	marca,
	--`mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdClienteDesdeClase`(clase),
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdClienteDesdeClase`(`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(concepto)),
    CAST(service_id AS INT64),
	tariff_ds,
	concepto,
	CAST(format_date('%Y%m%d',activation_date) AS INT64),
	CAST(format_date('%Y%m%d',sale_date) AS INT64),
  CAST(activation_date as TIMESTAMP),
  CAST(sale_date as TIMESTAMP),
	canal_ds,
	subcanal_ds,
	distribuidor,
	seller,
	'ENERGIA',
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerSegmentoDesdeCodSegmentoMM`(CAST(cod_Segmento AS INT64)),
	marco,
--	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca, clase),
--  `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(concepto)),
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca,
		tipo,
		`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)
		),
	--CAST(NULL AS INT64),
	COMISION,
--	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerDecomisionableDesdeClase`(clase),
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerDecomisionableDesdeClase`(`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(concepto)),	
	CAST(deactivation_date  as TIMESTAMP),
	CAST(format_date('%Y%m%d',deactivation_date) AS INT64),
	mes_decomision_id,
	`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisionesv1`('ENERGIA', concepto, CAST(format_date("%Y%m%d",deactivation_date) AS INT64), desde, hasta),
	`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisionesv1`('ENERGIA', concepto, CAST(format_date("%Y%m%d",deactivation_date) AS INT64), desde, hasta)),
	from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_DECOMISIONES_CANALIZADAS_CTX`
	where tipo="CAPTACION";

	---- PENDIENTE ACTUALIZACION ORDEN SAP E ID_CLIENTE A PARTIR DE FUNCIONES CREADAS

END