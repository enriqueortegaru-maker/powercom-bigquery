BEGIN

			DECLARE vmes_factura_id INT64;
			DECLARE vmes_factura_dt DATE;
      --DECLARE DESDE INT64;SET DESDE=20240801;
			SET vmes_factura_id=CAST(SAFE_DIVIDE(DESDE,100) AS INT64);
			SET vmes_factura_dt= parse_date ('%Y%m', CAST (vmes_factura_id AS string));
      --select vmes_factura_dt, vmes_factura_id;


			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_DES` AS
			with ccap as (
			  SELECT "COMISION" as clase, "CAPTACION" as tipo, vmes_factura_dt as mes_factura_dt, c.marca_ds, c.orden_sap,
			  --clase_mm, 
			  --`mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(desc_mm)as tr,
			  --`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.desc_mm), c.segmento_ds, c.desc_mm,"") as conceptoFactura,
			  `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.detalle_servicio_ds, c.clase_mm, c.desc_mm, c.concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap), c.segmento_ds, c.desc_mm,"") as conceptoFactura,
			  d.bp,
			  a.autofactura,		  
			  --segmento_ds,
			  --c.nombre_distribuidor_alta_ds, 
			  a.nombre_acreedor as nombre_distribuidor_alta_ds, 
			  count(servicio_id) as ncom, count(distinct cliente_id) as ncl, count(distinct servicio_id) as nserv, sum(coalesce(c.importe,0)) as importe
			  FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO`c 
			  left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_DISTRIBUIDORES`d ON d.marca=c.marca_ds and UPPER(TRIM(d.nombre_distribuidor))=UPPER(TRIM(c.nombre_distribuidor_alta_ds))
			  inner join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ACREEDORES` a ON a.SOCIEDAD=d.SOCIEDAD and UPPER(TRIM(a.CIF))=UPPER(TRIM(d.CIF)) and a.BP=d.BP and a.marca=d.marca		  
			  WHERE c.mes_factura_dt = vmes_factura_dt
			  --and marca_ds="TELECABLE"
			  --and orden_sap=180000010292
			  --and c.nombre_distribuidor_alta_ds="XENTIA CUSTOMER SERVICES, S.L."
			  group by 1,2,3,4,5,6,7,8,9

			), dcap as (
			  SELECT "DECOMISION" as clase, "CAPTACION" as tipo, vmes_factura_dt as mes_factura_dt, c.marca_ds, c.orden_sap,
			  --clase_mm, 
			  --`mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(desc_mm)as tr,
			  `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.detalle_servicio_ds, c.clase_mm, c.desc_mm, c.concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap), c.segmento_ds, c.desc_mm,"") as conceptoFactura,		  
			  --`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CAPTACION", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.desc_mm), c.segmento_ds, c.desc_mm,"") as conceptoFactura,
			  d.bp,    
			  a.autofactura,		  
			  --segmento_ds,
			  --c.nombre_distribuidor_alta_ds, 
			  a.nombre_acreedor as nombre_distribuidor_alta_ds,		  
			  count(servicio_id) as ncom, count(distinct cliente_id) as ncl, count(distinct servicio_id) as nserv, sum(coalesce(c.importe,0)) as importe
			  FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO` c
			  left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_DISTRIBUIDORES`d ON d.marca=c.marca_ds and UPPER(TRIM(d.nombre_distribuidor))=UPPER(TRIM(c.nombre_distribuidor_alta_ds))
			  inner join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ACREEDORES` a ON a.SOCIEDAD=d.SOCIEDAD and UPPER(TRIM(a.CIF))=UPPER(TRIM(d.CIF)) and a.BP=d.BP and a.marca=d.marca		  
			  WHERE c.mes_factura_dt = vmes_factura_dt
			  group by 1,2,3,4,5,6,7,8,9

			), ccar as (
			  SELECT  "COMISION" as clase, "CARTERA" as tipo, vmes_factura_dt as mes_factura_dt, c.marca_ds, c.orden_sap,
			  --clase_mm, 
			  --`mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(desc_mm)as tr,
			  --`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CARTERA", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.desc_mm), c.segmento, c.desc_mm, c.tipoMovimiento) as conceptoFactura,
			  `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CARTERA", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.nombreProducto, c.clase_mm, c.desc_mm, c.concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap), c.segmento, c.desc_mm, c.tipoMovimiento) as conceptoFactura,
			  d.bp,  
			  a.autofactura,		  
			  --segmento_ds,
			  --c.nombre_distribuidor, 
			  a.nombre_acreedor as nombre_distribuidor_alta_ds,		  
			  count(idProducto) as ncom, count(distinct idFijo) as ncl, count(distinct idProducto) as nserv, sum(coalesce(c.importe,0)) as importe
			  FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` c
			  left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_DISTRIBUIDORES`d ON UPPER(TRIM(d.marca))=UPPER(TRIM(c.marca_ds)) and UPPER(TRIM(d.nombre_distribuidor))=UPPER(TRIM(c.nombre_distribuidor))
			  inner join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ACREEDORES` a ON a.SOCIEDAD=d.SOCIEDAD and UPPER(TRIM(a.CIF))=UPPER(TRIM(d.CIF)) and a.BP=d.BP and a.marca=d.marca		  
			  WHERE c.mes_factura_dt = vmes_factura_dt
			  group by 1,2,3,4,5,6,7,8,9
			), dcar as (

			  SELECT "DECOMISION" as clase, "CARTERA" as tipo, vmes_factura_dt as mes_factura_dt, c.marca_ds, c.orden_sap,
			  --clase_mm, 
			  --`mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(desc_mm)as tr,
			  --`mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CARTERA", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.desc_mm), c.segmento, c.desc_mm,"") as conceptoFactura,
			  `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`("CARTERA", `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.nombreProducto, c.clase_mm, c.desc_mm, c.concepto_ds),`mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap), c.segmento, c.desc_mm,"") as conceptoFactura,
			  d.bp,
			  a.autofactura,		  
			  --segmento_ds,
			  --c.nombre_distribuidor, 
			  a.nombre_acreedor as nombre_distribuidor_alta_ds,		  
			  count(idProducto) as ncom, count(distinct idFijo) as ncl, count(distinct idProducto) as nserv, sum(coalesce(c.total,0)) as importe
			  FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO` c
			  left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_DISTRIBUIDORES`d ON d.marca=c.marca_ds and UPPER(TRIM(d.nombre_distribuidor))=UPPER(TRIM(c.nombre_distribuidor))    
			  inner join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ACREEDORES` a ON a.SOCIEDAD=d.SOCIEDAD and UPPER(TRIM(a.CIF))=UPPER(TRIM(d.CIF)) and a.BP=d.BP and a.marca=d.marca		  
			  WHERE c.mes_factura_dt = vmes_factura_dt
			  group by 1,2,3,4,5,6,7,8,9

			)    
				
			select distinct ccap.*,  `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(ccap.marca_ds) as IDSOCIEDAD, o.CODIGO
			from ccap  
			--left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`o on TRIM(o.orden_sap)=TRIM(cast(ccap.orden_sap AS STRING)) and TRIM(ccap.marca_ds)=TRIM(o.marca) 
			left join `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` o on o.orden=ccap.orden_sap and TRIM(ccap.marca_ds)=TRIM(o.marca) 
			--and TRIM(o.descripcion)=TRIM(dcap.conceptoFactura)    
			and UPPER(TRIM(o.concepto))=UPPER(TRIM(ccap.conceptoFactura))

			UNION ALL

			select distinct dcap.*,  `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(dcap.marca_ds) as IDSOCIEDAD, o.CODIGO
			from dcap 
			--left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`o on TRIM(o.orden_sap)=TRIM(cast(dcap.orden_sap AS STRING)) and TRIM(dcap.marca_ds)=TRIM(o.marca) 
			left join `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` o on o.orden=dcap.orden_sap and TRIM(dcap.marca_ds)=TRIM(o.marca)     
			and UPPER(TRIM(o.concepto))=UPPER(TRIM(dcap.conceptoFactura))

			UNION ALL

			select distinct ccar.*,  `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(ccar.marca_ds) as IDSOCIEDAD, o.CODIGO
			from ccar 
			--left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`o on TRIM(o.orden_sap)=TRIM(cast(ccar.orden_sap AS STRING)) and TRIM(ccar.marca_ds)=TRIM(o.marca) 
			left join `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` o on o.orden=ccar.orden_sap and TRIM(ccar.marca_ds)=TRIM(o.marca) 
			and UPPER(TRIM(o.concepto))=UPPER(TRIM(ccar.conceptoFactura))

			UNION ALL

			select distinct dcar.*, `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(dcar.marca_ds) as IDSOCIEDAD, o.CODIGO
			from dcar 
			--left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`o on TRIM(o.orden_sap)=TRIM(cast(dcar.orden_sap AS STRING)) and TRIM(dcar.marca_ds)=TRIM(o.marca) 
			left join `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` o on o.orden=dcar.orden_sap and TRIM(dcar.marca_ds)=TRIM(o.marca)     
			and UPPER(TRIM(o.concepto))=UPPER(TRIM(dcar.conceptoFactura));


		--- PASO 2: CREACION TABLA SAP_FACTURA_APUNTES_PUBLICADOS

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_PUBLICADOS_DES` AS 
			select a.idsociedad as sociedad, a.conceptoFactura, c.cuenta, a.clase, a.tipo, a.marca_ds, a.bp,c.segmento, c.codigo, a.orden_sap as orden, c.concepto, c.detalle, a.nombre_distribuidor_alta_ds, a.autofactura,
			sum(a.ncom) as ncom,
			sum(a.ncl) as ncl,
			sum(a.nserv) as nserv,			
			sum(a.importe) as importe
--			from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_CORRECTIVO_CARGA` a
			from `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` a
--			left join `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`c on  UPPER(TRIM(a.codigo))= UPPER(TRIM(c.codigo)) and a.idsociedad=c.sociedad and a.orden=c.orden 
			left join `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP`c on  UPPER(TRIM(c.codigo))= UPPER(TRIM(a.codigo)) and c.sociedad=a.idsociedad and c.marca=a.marca_ds and c.orden=a.orden_sap  and c.concepto=a.conceptofactura
			--where a.marca_ds="TELECABLE" 
			--and contains_substr(a.nombre_distribuidor_alta_ds,"EULEN")
			group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14
			order by 1,2,3;




END