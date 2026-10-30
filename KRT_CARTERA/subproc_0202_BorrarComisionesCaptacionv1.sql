BEGIN


		DECLARE vMES_COMISION_DT DATE;
		--LOCAL
		--DECLARE DESDE INT64;SET DESDE=20231101;
		SET vMES_COMISION_DT=parse_date('%Y%m%d',CAST(DESDE AS string));

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA` AS		
		SELECT a.* --FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL` a	
		FROM  `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` a
		WHERE
			EXISTS (
			SELECT  *
			FROM --`mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` b
				`mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` b
			WHERE a.marca_ds = b.marca_ds		
				AND a.dni_cif=b.cif_nif
				AND a.canal=b.canal_alta_ds
				AND a.subcanal=b.subcanal_ds
				AND a.nombre_distribuidor=b.nombre_distribuidor_alta_ds
				--AND a.TipoProducto=b.categoria_servicio_ds
				--AND ((a.TipoProducto=b.categoria_servicio_ds) or (a.idCatalogo=b.catalogo_id))
				--AND ((a.TipoProducto=b.categoria_servicio_ds) or (((split(catalogo_id,'/')[0]=b.catalogo_id)) or case when array_length(split(catalogo_id,'/')) >1 then split(catalogo_id,'/')[1] end=b.catalogo_id))			
				AND ((a.TipoProducto=b.categoria_servicio_ds) or (((split(TRIM(UPPER(b.catalogo_id)),'/')[0]=TRIM(UPPER(a.idcatalogo)))) or case when array_length(split(TRIM(UPPER(b.catalogo_id)),'/')) >1 then split(TRIM(UPPER(b.catalogo_id)),'/')[1] end=TRIM(UPPER(a.idcatalogo))))			
				AND ABS(a.IdProducto- b.servicio_id) <=20
				);


		INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA` 
		with pob as (
			select distinct expediente_padre_id 
			from `mm-commissions-reporting.KRT_CAPTACION.T_CAPTACION_HISTORICO` h 
			where marca_ds='R'
			and h.mes_comision_dt=vMES_COMISION_DT

		) select *
		--from `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL` t
		FROM  `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` t
		WHERE EXISTS(
			SELECT 1 FROM pob where pob.expediente_padre_id=t.contrato		
		) AND NOT EXISTS (
			SELECT 1 from `mm-commissions-reporting.KRT_CARTERA.LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA` c where c.idFijo=t.idFijo and c.idProducto=t.idProducto and c.marca_ds='R'
		);



	--- PASO 1: BORRO REGISTROS DE TABLA
	DELETE
	FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` a
	WHERE
	  EXISTS (
			SELECT  *
			FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA` b
			WHERE a.marca_ds = b.marca_ds
				AND a.dni_cif=b.dni_cif
				AND a.canal=b.canal
				AND a.subcanal=b.subcanal
				AND a.nombre_distribuidor=b.nombre_distribuidor
				AND a.TipoProducto=b.TipoProducto
				AND a.IdProducto = b.IdProducto
	);



	--- PASO 2: Creo LOG
	CREATE OR REPLACE TABLE
		`mm-commissions-reporting.KRT_CARTERA.LOG_0202_MARCO_RETRIBUTIVO_TIENDASxCANAL` AS

	SELECT * 
	FROM 
			`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`;

  END