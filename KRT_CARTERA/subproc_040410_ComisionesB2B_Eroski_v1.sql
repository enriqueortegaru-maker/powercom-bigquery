BEGIN

	DECLARE DESDE_DT, HASTA_DT, DESDE_1M_DT, HASTA_1M_DT,DESDE_6M_DT date;
	DECLARE MES_COMISION INT64;	
	DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;   
	--DECLARE DESDE, HASTA INT64;	SET DESDE=20231201;SET HASTA=20231231;    
	SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
	SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
	SET MES_COMISION=CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


	--- PASO 1: DESCUBRO PRODUCTOS DE EROSKI Y CAPRABO: 10796 PRODUCTOS  (10644 Eroski y 152 Caprabo)

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040410_PRODUCTOS_EROSKI` AS 
    SELECT distinct CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' END marca_ds,
	CAST(cat.swProdReleaseId AS STRING) as IdCatalogo, cat.swReleaseName as NombreProducto, 	
    --cl.mmMarcaId, 
	'EROSKI CENTRAL' as nombre_distribuidor, 'B2B' as canal, 'EROSKI' as subcanal,
	CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS' THEN pe.swNombre ELSE ca.swVerticalFocus END agente,
	cl.swCustomerId as idFijo, CAST('1900-01-01' AS DATE) as Antiguedad ,cl.swNIE as DNI_CIF, 
	p.swMarcaCartera as Marca_Cartera, 
	EXTRACT(DATE FROM p.swDateInstalled) as Fecha_Activacion,EXTRACT(DATE FROM p.swDateCreated) as Fecha_Creacion,
	TRIM(cl.swSegmento) Segmento,CAST(NULL as STRING) as Subsegmento, CAST(NULL as STRING) as idCatalogoOrigen, CAST(NULL as INT64) as  idProductoOrigen, CAST(NULL as STRING) as NombreProductoOrigen, CAST(NULL as STRING) as TipoMovimiento,
	p.swInstProdId as IdProducto, CAST(p.swAgreementId AS STRING )as Contrato,p.swCreatedBy as usuarioCreador, p.swCreatedBy as agente_creador_id, "Airtime cartera" as concepto_ds,
	CAST(NULL as STRING) as concepto_origen_ds, CAST(NULL as STRING) as medio_conocimiento, 
	cat.swLineName as TipoProducto,
	NULL as clave_mr, CAST(NULL as STRING) as MARCO_RETRIBUTIVO,
	CAST(NULL as STRING) as tvt_ups_virgin,CAST(NULL as STRING) as televenta,
	CAST(NULL  AS FLOAT64) importe, CAST(NULL  AS STRING) nivel, CAST(NULL  AS FLOAT64) importe_nivel, CAST(NULL  AS FLOAT64) bono_comercial, CAST(NULL  AS FLOAT64) bono_calidad, CAST(NULL  AS FLOAT64) bono_extras, CAST(NULL  AS FLOAT64) total, 
	CAST(NULL  AS STRING) campana_id,  CAST(NULL as STRING) nombre_campana, 
	'N' decomisionable, 'N' decom_bono_extra,
	MES_COMISION as mes_comision_id,
	p.swAni as identificativo,
	p.swStatus,
	p.swProviderGrpId,
	ca.swType,
	ca.mnpTipoDistribuidor,
	--c1.canal_agrupado1_ds canal_cap,
	CASE WHEN c1.canal_agrupado1_ds is not null then c1.canal_agrupado1_ds 
			 ELSE CASE WHEN UPPER(cd.esES)="CANAL ONLINE" THEN "WEB"END
	END as canal_cap,
  --sc.subcanal_ds subcanal_cap,
	CASE WHEN sc.subcanal_ds is not null then sc.subcanal_ds 
			 ELSE CASE WHEN UPPER(cd.esES)="CANAL ONLINE" THEN "CANAL ONLINE"END
	END as subcanal_cap,
	CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN pe.swNombre 
		 ELSE CASE WHEN ca.swVerticalFocus is not null then ca.swVerticalFocus
					ELSE case when (contains_substr(cd.esES,"Canal Online") or contains_substr(cd.esES,"Configurador") ) THEN UPPER(cd.esES) END
		END
	END distribuidor_cap,
	cd.esES as proceso
    ---p.swInstProdId, p.swStatus, p.swDateCreated as FECHA_CREACION,  swFechaDesinstalacion as FECHA_DESACTIVACION, p.swAni as IDENTIFICATIVO, cl.swSegmento,  /*swSubsegmento,*/ 
    --ca.swChnlPartnerId canalId, ca.swCOInterno,  ca.swVerticalFocus,  ca.swChnlPartnerId,    
    --p.swProdOrigId
	FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p 
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON p.swCustomerId = cl.swCustomerId
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm ON mm.mmMarcaId=cl.mmMarcaId
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON p.swProdReleaseId = cat.swProdReleaseId
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca ON ca.swChnlPartnerId =p.swChnlPartnerId
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c ON c.canal_id = p.swChnlPartnerId
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON c.canal_agrupado1_id = c1.canal_agrupado1_id
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON c.canal_agrupado2_id = c2.canal_agrupado2_id
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON c.subcanal_id = sc.subcanal_id
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swPersonalId= p.swProviderGrpId AND pe.swObjectType='CHANNEL_PARTNER' 
	LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_codigos` cd  on p.swPdteArpa=cd.Orden AND cd.TipoCodigo='ProcesoOrigen'
	WHERE DATE_TRUNC(CAST(swDateInstalled AS DATE), DAY) < HASTA_DT AND (swFechaDesinstalacion IS NULL  OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
	and cat.swProdReleaseId in (9931,9932);			


	/*
	select marca_ds, fecha_activacion,idProducto, swProviderGrpId, canal_cap
	from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_PRODUCTOS_EROSKI`
	order by fecha_activacion asc;

	select proceso, count(idProducto) as nserv 
	from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_PRODUCTOS_EROSKI`
	group by 1
	order by 2 desc;
	*/

	-- 10473 clientes, 10794 contratos y 10795 servicios
	--select count(distinct idFijo) as ncl, count(distinct idContrato)  as nctr, count(distinct idProducto) as nserv from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_PRODUCTOS_EROSKI`; 


	--- PASO 2:GENERO LISTADO DE FACTURAS DE PRODUCTOS DE EROSKI Y CAPRABO: 10796 PRODUCTOS  (10644 Eroski y 152 Caprabo)
	---			LISTADO BASE PARA EROSKI Y CAPRABO

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040410_LISTADO_FACTURAS_CLIENTES_COMISIONES_EROSKI` AS 	
	Select distinct DESDE as fechaInicio, HASTA as fechaFin, 
	p.marca_ds as marca,p.idFijo as idCliente, p.Contrato, p.identificativo,
	p.idproducto as idProducto, p.Fecha_Creacion as fechaCreacion, p.Fecha_Activacion as fechaActivacion, p.swStatus as estado,
	p.swType as tipoCanal,p.distribuidor_cap as canal, 
	f.euskaltel_bill_no, 
	f.bill_total_elec, f.bill_total, f.services_amount,f.consumptions_amount,discounts_amount,taxable_amount_ppal, tax_amount_ppal, 
	f.bill_total_elec as importe, 0.04* f.bill_total_elec as descuentoConIva, (0.04* f.bill_total_elec)/1.21 as descuento, 
	f.bill_total as importe_total, 0.04* f.bill_total as descuentoConIva_total, (0.04* f.bill_total)/1.21 as descuento_total 
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040410_PRODUCTOS_EROSKI` p 
	inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_factura` f on f.swCustomerId=p.IdFijo and CAST(f.swAgreementId AS STRING)=p.Contrato and f.fecha_mes_ciclo_dt=desde_dt;





	--- PASO 3:GENERO LISTADO DE COMISIONES DE PRODUCTOS DE EROSKI Y CAPRABO: 
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040410_COMISIONES_EROSKI` AS 
	select p.* except(identificativo, swStatus,swProviderGrpId,swType,mnpTipoDistribuidor,canal_cap, subcanal_cap, distribuidor_cap, proceso),
	"C - Eroski (4%)" as desc_mm, "C - Calidad"  as clase_mm, 	
	from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_PRODUCTOS_EROSKI` p
	inner join `mm-commissions-reporting.KRT_CARTERA.LOG_040410_LISTADO_FACTURAS_CLIENTES_COMISIONES_EROSKI` f on p.marca_ds=f.marca and p.idFijo=f.idCliente and p.Contrato=f.Contrato and p.idproducto=f.idproducto;

	/*
	with dup as (
	  SELECT marca, idcliente, idcontrato, idproducto, count(importe) as nreg 
	  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040410_LISTADO_FACTURAS_CLIENTES_COMISIONES_EROSKI` 
	  group by 1,2,3,4 
	  having count(importe)  >1
	  order by count(importe) desc
	) select l.* 
	from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_LISTADO_FACTURAS_CLIENTES_COMISIONES_EROSKI` l 
	inner join dup d on d.marca=l.marca and d.idcliente=l.idcliente and d.idcontrato=l.idcontrato and d.idproducto=l.idproducto
	order by d.nreg desc;
	*/


	UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_040410_COMISIONES_EROSKI` c
	SET c.total=f.descuento  
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_040410_LISTADO_FACTURAS_CLIENTES_COMISIONES_EROSKI` as f 	
	WHERE c.marca_ds=f.marca 	
	and c.idFijo=f.idCliente 
	and c.Contrato=f.Contrato 
	and c.idproducto=f.idproducto
	and f.importe>0;	
	


	--- PASO 4:CREO TABLA COMISIONES B2B
/*	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040410_COMISIONES_EROSKI`;*/

	
	/*	
	--- PASO 3:GENERO RESUMEN DE COMISIONES DE PRODUCTOS DE EROSKI Y CAPRABO: 10796 PRODUCTOS  (10644 Eroski y 152 Caprabo)

	select marca, count(distinct idCliente) as ncl, count(distinct idContrato ) as nctr, count(idProducto) as nserv, 
	sum(importe) as importe, sum(descuentoConIva) as descuentoConIva, sum(descuento) as descuento,
	sum(importe_total) as importe_total, sum(descuentoConIva_total) as descuentoConIva_total, sum(descuento_total) as descuento_total	
	from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_LISTADO_FACTURAS_CLIENTES_COMISIONES_EROSKI` 
	group by 1; 
	
	
	select * from `mm-commissions-reporting.KRT_CARTERA.LOG_040410_COMISIONES_EROSKI` where marca='TELECABLE';
	*/	
	
END