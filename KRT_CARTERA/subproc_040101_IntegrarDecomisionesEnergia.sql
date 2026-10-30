BEGIN
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
	(
	marca_ds,
	NombreProducto,
	nombre_distribuidor,
	Canal,
	subcanal,
	agente,
	IdFijo,
	Fecha_Activacion,
	Fecha_Creacion,
	Segmento,
	IdProducto,
	Contrato,
	UsuarioCreador,
	concepto_ds,
	ClaseProducto,
	TipoProducto,
	MARCO_RETRIBUTIVO,
	importe,
	importe_nivel,
	total,
	decomisionable,
	mes_comision_id,
	orden_sap,
	desc_mm_com,
	clase_mm_com,
	FechaDesinstalacion,
	mes_decomision_id,
	desc_mm,
	clase_mm
	)
	SELECT distinct 
	marca,
	tariff_ds,
	distribuidor,
	canal_ds,
	subcanal_ds,
	seller,
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearIdClienteDesdeClase`(clase),
	activation_date,
	sale_date,
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerSegmentoDesdeCodSegmentoMM`(CAST(cod_Segmento AS INT64)),
	CAST(service_id AS INT64),
	serial_number,
	seller,
	concepto,
	'ENERGIA',
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto),
	marco,
	COMISION,
	COMISION,
	COMISION,
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerDecomisionableDesdeClase`(`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)),
	mes_comision_id,
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca, tipo, clase),

	
		`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(concat("Alta ", `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)), concepto,tariff_ds, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)),
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(concat("Alta ", `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)), concepto,tariff_ds, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto))		
		),	

	
	
	deactivation_date,
	mes_decomision_id,
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(concat("Alta ", `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)), concepto, tariff_ds, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto))),
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(concat("Alta ", `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)), concepto, tariff_ds, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)))),

	from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_DECOMISIONES_CANALIZADAS_CTX`
	where tipo="CARTERA";


END