BEGIN

	DECLARE nivel, nmeses,  vmes, vversion int64;
	DECLARE vmes_comision_dt, vmes_factura_dt DATE;
  --- LOCAL
  --DECLARE vDESDE, vHASTA INT64;SET VDESDE=20240901;SET VHASTA=20240930;
	SET nmeses=(DATE_DIFF(CURRENT_DATE(), PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)) , MONTH));
	SET vmes_comision_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));
	SET vmes_factura_dt=PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));	
	SET vmes=CAST(FORMAT_DATE("%Y%m",date_trunc(vmes_comision_dt, MONTH)) AS INT64); 
	SET vversion=CAST((SELECT `mm-commissions-reporting.KRT_CAPTACION.getVersion_nmonths`(NMESES) as vversion) as INT64) ;
	

	--- COMISION
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO` AS 
	SELECT vmes_factura_dt as mes_factura_dt, vmes_comision_dt as mes_comision_dt, 
	--'LIQUIDA'|| '_C_' || VMES ||'_'||row_number()over() as commission_id,
	`mm-commissions-reporting.KRT_CAPTACION.f_creaPrefijoIdComision`(vdesde, c.marca_ds,"captacion", "comision") ||'_'||row_number()over() as commission_id,	
	CAST(NULL AS STRING) as id_registro,
	CAST(NULL AS STRING) as invoice_id,
	'publicado' as estado, 		
	c.* 
	FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` as c
	LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` v on v.marca_ds= c.marca_ds and v.mes_comision_id=VMES	
	WHERE EXISTS(
	  select 1 
	  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
	  where r.marca_ds=c.marca_ds
	  and r.mes_comision_id = vmes
	  --and c.version=vversion    			
	)-- and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH)
	--and parse_date ('%Y%m%d', CAST ( c.desde AS string))=vmes_factura_dt
	and c.fecha_calc_dt=PARSE_DATE("%Y%m%d",CAST(v.fecha_id AS STRING)) 
	and c.desde=VDESDE 
	
	UNION ALL 
	
	SELECT vmes_factura_dt as mes_factura_dt, vmes_comision_dt as mes_comision_dt,
	--'LIQUIDA'|| '_C_' || VMES ||'_'||row_number()over() as commission_id,
	`mm-commissions-reporting.KRT_CAPTACION.f_creaPrefijoIdComision`(vdesde, c.marca_ds,"captacion", "comision") ||'_'||row_number()over() as commission_id,	
	CAST(NULL AS STRING) as id_registro,
	CAST(NULL AS STRING) as invoice_id,
	'calculado' as estado, 		
	c.* 
	FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` as c
	WHERE NOT EXISTS(
	  select 1 
	  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
	  where r.marca_ds=c.marca_ds
	  and r.mes_comision_id = vmes
	  --and c.version=vversion    
	) 
	and c.fecha_calc_dt=CURRENT_DATE()
	and c.desde=VDESDE
	order by marca_ds, cliente_id,servicio_id, clase_mm, desc_mm;					

	--- DECOMISION
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
	SELECT vmes_factura_dt as mes_factura_dt, vmes_comision_dt as mes_decomision_dt, 
	--'LIQUIDA'|| '_D_' || VMES ||'_'||row_number()over() as commission_id,
	`mm-commissions-reporting.KRT_CAPTACION.f_creaPrefijoIdComision`(vdesde, c.marca_ds,"captacion", "decomision") ||'_'||row_number()over() as commission_id,	
	CAST(NULL AS STRING) as id_registro,
	CAST(NULL AS STRING) as invoice_id,
	'publicado' as estado, 		
	c.* --except(fecha_calc_dt, desde, hasta, version)
	FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` as c
	LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` v on v.marca_ds= c.marca_ds and v.mes_comision_id=VMES	
	WHERE EXISTS(
	  select 1 
	  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
	  where r.marca_ds=c.marca_ds
	  and r.mes_comision_id = vmes
	  --and c.version=vversion    
	)--and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH)
	--and parse_date ('%Y%m%d', CAST ( c.desde AS string))=vmes_factura_dt 
	and c.fecha_calc_dt=PARSE_DATE("%Y%m%d",CAST(v.fecha_id AS STRING)) 
	and c.desde=VDESDE
	
	UNION ALL
	
	SELECT vmes_factura_dt as mes_factura_dt, vmes_comision_dt as mes_decomision_dt, 
	--'LIQUIDA'|| '_D_' || VMES ||'_'||row_number()over() as commission_id,
	`mm-commissions-reporting.KRT_CAPTACION.f_creaPrefijoIdComision`(vdesde, c.marca_ds,"captacion", "decomision") ||'_'||row_number()over() as commission_id,	
	CAST(NULL AS STRING) as id_registro,
	CAST(NULL AS STRING) as invoice_id,
	'calculado' as estado, 		
	c.* 
	FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` as c 
	WHERE NOT EXISTS(
	  select 1 
	  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
	  where r.marca_ds=c.marca_ds
	  and r.mes_comision_id = vmes
	  --and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
	  --and c.version=vversion    
	)--and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);
	--and parse_date ('%Y%m%d', CAST ( c.desde AS string))=vmes_factura_dt
	and c.fecha_calc_dt=CURRENT_DATE()
	and c.desde=VDESDE
	order by marca_ds, cliente_id,servicio_id, clase_mm, desc_mm;			


	--DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` where mes_comision_dt=vmes_comision_dt;
	DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` where mes_factura_dt=vmes_factura_dt;	
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO`;


	--DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO` where mes_decomision_dt=vmes_comision_dt;
	DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO` where mes_factura_dt=vmes_factura_dt;
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`;

		
END