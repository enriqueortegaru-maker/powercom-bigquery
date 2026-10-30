BEGIN

	--DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES` where clasePRoducto="ENERGIA";


	---- INSERTO UNITARIOS

	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
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
	TipoMovimiento,	
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
	desc_mm,
	clase_mm,
	orden_sap

	)
	-- LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20250201; SET HASTA=20250228;	
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
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_crearTipoMovimientoDesdeConcepto`(concepto),
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
	id_mes,
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(concat("Alta ", `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)), concepto,tariff_ds, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)),
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(
	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(concat("Alta ", `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)), concepto,tariff_ds, `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto))		
		),	
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca, tipo, clase),
--	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca,`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto)),
	from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_COMISIONES_CANALIZADAS_CTX`
	where tipo="CARTERA"
	and not contains_substr(concepto, 'D - ');


/*
	---- ACTUALIZO VALOR BONO EXTRA DE COMISIONES PROCEDENTES DE REPARTO Y QUE TENGAN UN UNITARIO

	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	SET c.bono_extras=coalesce(c.bono_extras,0) + e.COMISION,
	c.total=coalesce(c.total,0) + e.COMISION,
	c.decom_bono_extra='N'
	from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_COMISIONES_CANALIZADAS_CTX` e
	where  c.ClaseProducto="ENERGIA"
	and e.tipo="CARTERA"
	and e.clase="REP"
	and contains_substr(e.concepto, 'D - Extra')
	and c.marca_ds=e.marca 
	and c.idProducto=CAST(e.service_id AS INT64);
*/



	---- INSERTO APUNTES DE REPARTO DE HORAS

	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
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
	TipoMovimiento,	
	IdProducto,
	Contrato,
	UsuarioCreador,
	concepto_ds,
	ClaseProducto,
	TipoProducto,
	MARCO_RETRIBUTIVO,
	--importe,
	--importe_nivel,
	bono_extras,
	total,
	decomisionable,
	mes_comision_id,
	desc_mm,
	clase_mm,
	orden_sap

	)

	-- LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20250101; SET HASTA=20250131;
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
	'Reparto de horas',
	CAST(service_id AS INT64),
	serial_number,
	seller,
	concepto,
	'ENERGIA',
	--`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(concepto),
	'ELECTRICIDAD',
	marco,
	COMISION,
	COMISION,
	'N',
	id_mes,
	'D - Extra',
	'D - Extracomision',	
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca,tipo,'ELECTRICIDAD'),
	from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_COMISIONES_CANALIZADAS_CTX` e
	where tipo="CARTERA"
	and clase="REP"
	and contains_substr(concepto, 'D - Extra')
	and not exists(
		select 1
		from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
		where c.marca_ds=e.marca and c.idProducto=CAST(e.service_id AS INT64)	and contains_substr(concepto_ds, 'D - Extra')
	);




	---- INSERTO APUNTES DE RAPPEL OBJETIVO

	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
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
	TipoMovimiento,	
	IdProducto,
	Contrato,
	UsuarioCreador,
	concepto_ds,
	ClaseProducto,
	TipoProducto,
	MARCO_RETRIBUTIVO,
	--importe,
	--importe_nivel,
	--bono_extras,
	total,
	decomisionable,
	mes_comision_id,
	desc_mm,
	clase_mm,
	orden_sap

	)

	-- LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20250101; SET HASTA=20250131;
	SELECT distinct 	--clase,
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
	'Rappel Energia',
	CAST(service_id AS INT64),
	serial_number,
	seller,
	concepto,
	'ENERGIA',
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerTipoServicioDesdeConcepto`(clase),
	marco,
	--COMISION,
	COMISION,
	'S',
	id_mes,
	'D - Rappel',
	'D - Extracomision',	
	`mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerOrdenSapDesdeClase`(marca,tipo,'ELECTRICIDAD'),
	from `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_COMISIONES_CANALIZADAS_CTX` e
	where tipo="CARTERA"
	--and clase=""
	and contains_substr(concepto, 'D - Rappel')
	and not exists(
		select 1
		from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
		where c.marca_ds=e.marca and c.idProducto=CAST(e.service_id AS INT64)	and contains_substr(concepto_ds, 'D - Rappel')
	);






END