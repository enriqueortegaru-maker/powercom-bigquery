BEGIN

    DECLARE DESDE_DT, HASTA_DT, DESDE_1M_DT, HASTA_1M_DT,DESDE_6M_DT date;
		DECLARE MES_COMISION INT64;
    DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;
		DECLARE  COMISION_BA, COMISION_SOMO FLOAT64; 
    --DECLARE DESDE, HASTA INT64;	SET DESDE=20231201;SET HASTA=20231231;    
    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
		SET MES_COMISION=CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);
		SET COMISION_BA=3.0;	
		SET COMISION_SOMO=1.25;


	
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


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_SOMO_RACC` AS
	Select  distinct s.marca_ds, s.Catalogo_id as IdCatalogo, cat.swReleaseName as NombreProducto, 'RACC CENTRAL' as nombre_distribuidor, 'B2B' as Canal, 'B2B' as subcanal, 
	equipo_ds as agente,	
	s.cliente_id as IdFijo, CAST('1999-01-01' AS DATE) as Antiguedad, cl.swNIE as DNI_CIF, s.marca_cartera_ds as Marca_Cartera, 
	EXTRACT(DATE FROM s.fecha_rfb_dt) as Fecha_Activacion, EXTRACT(DATE FROM s.fecha_venta_neta_dt) as Fecha_Creacion, 
	s.segmento_ds as Segmento, CAST(NULL as STRING) as Subsegmento, CAST(NULL as STRING) as idCatalogoOrigen, CAST(NULL as INT64) as  idProductoOrigen, CAST(NULL as STRING) as NombreProductoOrigen, CAST(NULL as STRING) as TipoMovimiento,
	s.servicio_id as IdProducto, 
	CAST(s.contrato_id AS STRING) as Contrato, 
	agente_creador_id as UsuarioCreador, agente_creador_id as agente_creador_id, "Airtime cartera" as concepto_ds, 
	CAST(NULL as STRING) as concepto_origen_ds, CAST(NULL as STRING) as medio_conocimiento, 
	categoria_servicio_ds as TipoProducto, 
	NULL as clave_mr, CAST(NULL as STRING) as MARCO_RETRIBUTIVO,
	CAST(NULL as STRING) as tvt_ups_virgin, CAST(NULL as STRING) as televenta,
	CAST(NULL  AS FLOAT64) importe, CAST(NULL  AS STRING) nivel, CAST(NULL  AS FLOAT64) importe_nivel, CAST(NULL  AS FLOAT64) bono_comercial, CAST(NULL  AS FLOAT64) bono_calidad, CAST(NULL  AS FLOAT64) bono_extras, 
	COMISION_SOMO total, 
	CAST(NULL  AS STRING) campana_id,  CAST(NULL as STRING) nombre_campana, 
	'N' decomisionable, 'N'decom_bono_extra,
	MES_COMISION as mes_comision_id,
	"C - Racc SOMO" as desc_mm	,
	"C - Calidad"  as clase_mm, 
	--s.categoria_servicio_ds
	from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
	inner join `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_SOMO_RACC` pob on pob.marca_ds=s.marca_ds and pob.cliente_id=s.cliente_id -- and pob.contrato_id=s.contrato_id
	inner JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON cl.swCustomerId = s.cliente_id
	inner JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON CAST(cat.swProdReleaseId AS STRING)= s.catalogo_id
	where s.categoria_servicio_ds="MOVILES POSTPAGO"
	and fecha_baja_id > HASTA
	and fecha_rfb_id <= HASTA;


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

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040420_COMISIONES_BA_RACC` AS
	Select  distinct s.marca_ds, s.Catalogo_id as IdCatalogo, cat.swReleaseName as NombreProducto,  'RACC CENTRAL' as nombre_distribuidor, 'B2B' as Canal, 'B2B' as subcanal, s.agente_creador_id as agente, 
	s.cliente_id as IdFijo, CAST('1999-01-01' AS DATE) as Antiguedad, cl.swNIE as DNI_CIF, s.marca_cartera_ds as Marca_Cartera, 
	EXTRACT(DATE FROM s.fecha_rfb_dt) as Fecha_Activacion, EXTRACT(DATE FROM s.fecha_venta_neta_dt) as Fecha_Creacion,	
	s.segmento_ds as Segmento, CAST(NULL as STRING) as Subsegmento, CAST(NULL as STRING) as idCatalogoOrigen, CAST(NULL as INT64) as  idProductoOrigen, CAST(NULL as STRING) as NombreProductoOrigen, CAST(NULL as STRING) as TipoMovimiento,
	s.servicio_id as IdProducto, 
	CAST(s.contrato_id AS STRING) as Contrato, 
	agente_creador_id as UsuarioCreador, agente_creador_id as agente_creador_id, "Airtime cartera" as concepto_ds, 
	CAST(NULL as STRING) as concepto_origen_ds, CAST(NULL as STRING) as medio_conocimiento, 
	categoria_servicio_ds as TipoProducto, 
	NULL as clave_mr, CAST(NULL as STRING) as MARCO_RETRIBUTIVO,CAST(NULL as STRING) as tvt_ups_virgin,CAST(NULL as STRING) as televenta,
	CAST(NULL  AS FLOAT64) importe, CAST(NULL  AS STRING) nivel, CAST(NULL  AS FLOAT64) importe_nivel, CAST(NULL  AS FLOAT64) bono_comercial, CAST(NULL  AS FLOAT64) bono_calidad, CAST(NULL  AS FLOAT64) bono_extras, 
	COMISION_BA total, 
	CAST(NULL  AS STRING) campana_id,  CAST(NULL as STRING) nombre_campana, 
	'N' decomisionable, 'N'decom_bono_extra,
	MES_COMISION as mes_comision_id,	
	"C - Racc BA" as desc_mm,"C - Calidad"  as clase_mm, 	
	---s.categoria_servicio_ds
	from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
	inner join `mm-commissions-reporting.KRT_CARTERA.LOG_040420_CONTRATOS_CLIENTES_BA_RACC` pob on pob.marca_ds=s.marca_ds and pob.cliente_id=s.cliente_id  and pob.contrato_id=s.contrato_id  and pob.servicio_id=s.servicio_id
	inner JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON cl.swCustomerId = s.cliente_id
	inner JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON CAST(cat.swProdReleaseId AS STRING)= s.catalogo_id
	where contains_substr(s.categoria_servicio_ds,"BANDA ANCHA")
	and fecha_baja_id > HASTA
	and fecha_rfb_id < HASTA;

	
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