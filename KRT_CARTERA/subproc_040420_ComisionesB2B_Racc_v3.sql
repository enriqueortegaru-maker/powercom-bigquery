BEGIN

    DECLARE DESDE_DT, HASTA_DT, DESDE_1M_DT, HASTA_1M_DT,DESDE_6M_DT date;
		DECLARE MES_COMISION INT64;
    DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;
		DECLARE  COMISION_BA, COMISION_SOMO FLOAT64; 
		DECLARE VMARCO_RETRIBUTIVO STRING;
    ---DECLARE DESDE, HASTA INT64;	SET DESDE=20241001;SET HASTA=20241031;    
    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
		SET MES_COMISION=CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);
		SET COMISION_BA=3.0;	
		SET COMISION_SOMO=1.25;
		SET VMARCO_RETRIBUTIVO='MR Calidad Racc';


	
	--- PASO 1: OBTENGO CLIENTES Y CUENTAS DE RACC SOMO -> 4043 clientes 6084 servicios 7605 Euros -> 3925 clientes, 5950 servicios, 7437 euros ->4099 6257 7821

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_SOMO_RACC` AS
		--- Listado de clientes que tienen activo al menos un servicio de acceso móvil
	with pob as (
		--- Listado de clientes que tienen activo nos un servicio de acceso móvil
		select  distinct marca_ds,cliente_id--, contrato_id 
		from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
		where marca_ds="RACC"
		--and contains_substr(categoria_servicio_ds,"MOVILES")
		and categoria_servicio_ds="MOVILES POSTPAGO"
		and fecha_baja_id > HASTA
		and fecha_rfb_id < HASTA	
		--and cliente_id=1809304
	)	
	--- Listado de clientes que sólo tienen activo un servicio de acceso móvil
	select marca_ds, cliente_id, --contrato_id, ---categoria_servicio_ds,
	count(distinct /*tecnologia_ds*/categoria_servicio_ds) as nd, count(distinct servicio_id) as nserv 
	from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
	where marca_ds="RACC"
	and fecha_baja_id > HASTA
	and fecha_rfb_id <= HASTA
	and categoria_servicio_ds in ("BANDA ANCHA","TELEVISION","FIJA","MOVILES POSTPAGO")
	and exists(
		select 1
		from pob
		where pob.marca_ds=s.marca_ds and pob.cliente_id=s.cliente_id  --and pob.contrato_id=s.contrato_id
	) group by 1,2 --,3
	having count(distinct categoria_servicio_ds)=1
	order by 3 desc;
	--	select count(nserv) as ncontr, sum(nserv) as nserv, 1.25*sum(nserv) as importe  from  `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_SOMO_RACC` 


	CREATE OR REPLACE TABLE
		`mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_SOMO_RACC` AS
	SELECT
		DISTINCT s.marca_ds,
		s.Catalogo_id AS IdCatalogo,
		cat.swReleaseName AS NombreProducto,
		'RACC CENTRAL' AS nombre_distribuidor,
		'RAC0000000000' AS equipo,
		'B2B' AS Canal,
		'RACC' AS subcanal,
		equipo_ds AS agente,
		s.cliente_id AS IdFijo,
		CAST('1999-01-01' AS DATE) AS Antiguedad,
		cl.swNIE AS DNI_CIF,
		s.marca_cartera_ds AS Marca_Cartera,
		EXTRACT(DATE
		FROM
			s.fecha_rfb_dt) AS Fecha_Activacion,
		EXTRACT(DATE
		FROM
			s.fecha_venta_neta_dt) AS Fecha_Creacion,
		s.segmento_ds AS Segmento,
		CAST(NULL AS STRING) AS Subsegmento,
		CAST(NULL AS STRING) AS idCatalogoOrigen,
		CAST(NULL AS INT64) AS idProductoOrigen,
		CAST(NULL AS STRING) AS NombreProductoOrigen,
		CAST(NULL AS STRING) AS TipoMovimiento,
		s.servicio_id AS IdProducto,
		CAST(s.contrato_id AS STRING) AS Contrato,
		agente_creador_id AS UsuarioCreador,
		agente_creador_id AS agente_creador_id,
		"Airtime cartera" AS concepto_ds,
		CAST(NULL AS STRING) AS concepto_origen_ds,
		CAST(NULL AS STRING) AS medio_conocimiento,
		"Servicio" AS ClaseProducto,
		categoria_servicio_ds AS TipoProducto,
		NULL AS clave_mr,
		VMARCO_RETRIBUTIVO AS MARCO_RETRIBUTIVO,
		CAST(NULL AS STRING) AS tvt_ups_virgin,
		CAST(NULL AS STRING) AS televenta,
		CAST(NULL AS FLOAT64) importe,
		CAST(NULL AS STRING) nivel,
		CAST(NULL AS FLOAT64) importe_nivel,
		CAST(NULL AS FLOAT64) bono_comercial,
		CAST(NULL AS FLOAT64) bono_calidad,
		CAST(NULL AS FLOAT64) bono_extras,
		COMISION_SOMO total,
		CAST(NULL AS STRING) campana_id,
		CAST(NULL AS STRING) nombre_campana,
		'N' decomisionable,
		'N'decom_bono_extra,
		MES_COMISION AS mes_comision_id,
		"C - Racc SOMO" AS desc_mm,
		"C - Calidad" AS clase_mm,
		--s.categoria_servicio_ds
	FROM
		`dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
	INNER JOIN
		`mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_SOMO_RACC` pob
	ON
		pob.marca_ds=s.marca_ds
		AND pob.cliente_id=s.cliente_id 
		--AND pob.contrato_id=s.contrato_id
	INNER JOIN
		`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
	ON
		cl.swCustomerId = s.cliente_id
	INNER JOIN
		`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
	ON
		CAST(cat.swProdReleaseId AS STRING)= s.catalogo_id
	WHERE
		s.categoria_servicio_ds="MOVILES POSTPAGO"
		AND fecha_baja_id > HASTA
		AND fecha_rfb_id <= HASTA;



	--select * from `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_SOMO_RACC` where idProducto in(83088368,	142031514,	130530046,	130530050,	130456280,	130465098,	130455494,	130530059,	37408333)
	--select * from `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_SOMO_RACC` where idFIJO=4276691;

  --- PASO 2: OBTENGO CLIENTES Y CUENTAS DE RACC BA -> 11096 clientes 11267 servicios 33288 Euros


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_BA_RACC` AS
	with pob as(
		---- servicio con mínimo_id por contrato
		select marca_ds, cliente_id, contrato_id, min(servicio_id) as servicio_id ,count(distinct cliente_id) as ncl, count(contrato_id) as ncont, count(distinct servicio_id) as nserv 
		from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
		where marca_ds="RACC"
		and categoria_servicio_ds="BANDA ANCHA"
		and fecha_baja_id > HASTA
		and fecha_rfb_id <= HASTA
		group by 1,2,3
		order by 4 desc
	)		select marca_ds, cliente_id, min(contrato_id) as contrato_id, servicio_id ,ncl,ncont, sum(nserv) as nserv 
	from pob
	group by 1,2,4,5,6;



--	select  count(ncl) as ncl, count(nserv) as ncontr, sum(nserv) as nserv, 3*sum(ncl) as importe  from  `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_BA_RACC` 
	CREATE OR REPLACE TABLE
		`mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_BA_RACC` AS
	SELECT
		DISTINCT s.marca_ds,
		s.Catalogo_id AS IdCatalogo,
		cat.swReleaseName AS NombreProducto,
		'RACC CENTRAL' AS nombre_distribuidor,
		'RAC0000000000' AS equipo,		
		'B2B' AS Canal,
		'RACC' AS subcanal,
		s.agente_creador_id AS agente,
		s.cliente_id AS IdFijo,
		CAST('1999-01-01' AS DATE) AS Antiguedad,
		cl.swNIE AS DNI_CIF,
		s.marca_cartera_ds AS Marca_Cartera,
		EXTRACT(DATE
		FROM
			s.fecha_rfb_dt) AS Fecha_Activacion,
		EXTRACT(DATE
		FROM
			s.fecha_venta_neta_dt) AS Fecha_Creacion,
		s.segmento_ds AS Segmento,
		CAST(NULL AS STRING) AS Subsegmento,
		CAST(NULL AS STRING) AS idCatalogoOrigen,
		CAST(NULL AS INT64) AS idProductoOrigen,
		CAST(NULL AS STRING) AS NombreProductoOrigen,
		CAST(NULL AS STRING) AS TipoMovimiento,
		s.servicio_id AS IdProducto,
		CAST(s.contrato_id AS STRING) AS Contrato,
		agente_creador_id AS UsuarioCreador,
		agente_creador_id AS agente_creador_id,
		"Airtime cartera" AS concepto_ds,
		CAST(NULL AS STRING) AS concepto_origen_ds,
		CAST(NULL AS STRING) AS medio_conocimiento,
		"Móvil" AS ClaseProducto,
		categoria_servicio_ds AS TipoProducto,
		NULL AS clave_mr,
		VMARCO_RETRIBUTIVO AS MARCO_RETRIBUTIVO,
		CAST(NULL AS STRING) AS tvt_ups_virgin,
		CAST(NULL AS STRING) AS televenta,
		CAST(NULL AS FLOAT64) importe,
		CAST(NULL AS STRING) nivel,
		CAST(NULL AS FLOAT64) importe_nivel,
		CAST(NULL AS FLOAT64) bono_comercial,
		CAST(NULL AS FLOAT64) bono_calidad,
		CAST(NULL AS FLOAT64) bono_extras,
		COMISION_BA total,
		CAST(NULL AS STRING) campana_id,
		CAST(NULL AS STRING) nombre_campana,
		'N' decomisionable,
		'N'decom_bono_extra,
		MES_COMISION AS mes_comision_id,
		"C - Racc BA" AS desc_mm,
		"C - Calidad" AS clase_mm,
		---s.categoria_servicio_ds
	FROM
		`dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
	INNER JOIN
		`mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_BA_RACC` pob
	ON
		pob.marca_ds=s.marca_ds
		AND pob.cliente_id=s.cliente_id
		AND pob.contrato_id=s.contrato_id
		AND pob.servicio_id=s.servicio_id
	INNER JOIN
		`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
	ON
		cl.swCustomerId = s.cliente_id
	INNER JOIN
		`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
	ON
		CAST(cat.swProdReleaseId AS STRING)= s.catalogo_id
	WHERE
		CONTAINS_SUBSTR(s.categoria_servicio_ds,"BANDA ANCHA")
		AND fecha_baja_id > HASTA
		AND fecha_rfb_id < HASTA;
	
	/*
	select  count(distinct cliente_id) as ncl, count(distinct contrato_id) as ncontr, sum(nserv) as nserv, 3*sum(nserv) as importe  from  `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_BA_RACC` 
	UNION ALL 
	select count(distinct idFijo) as ncl, count(distinct contrato) as ncontr, count(distinct idProducto) as nserv, 3*count(distinct idProducto) as importe  from  `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_BA_RACC`; 
	*/



	--- PASO 4: INSERTO EN TABLA COMISIONES B2B

/*	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_SOMO_RACC`;
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_BA_RACC`;

*/

END