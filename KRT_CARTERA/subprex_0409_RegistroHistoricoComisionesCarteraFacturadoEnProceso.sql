BEGIN

	DECLARE nivel, nmeses,  vmes_comision_id, vversion int64;
	DECLARE vmes_comision_dt DATE;
	--- LOCAL
	--DECLARE DESDE, HASTA INT64;SET DESDE=20240601;SET HASTA=20240630;SET VVERSION=14;
	SET nivel=(SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerNivelDePublicacionDatosHistoricos`(desde));
	SET nmeses=(DATE_DIFF(CURRENT_DATE(), PARSE_DATE("%Y%m%d", CAST(desde AS STRING)) , MONTH));
	SET vmes_comision_dt=PARSE_DATE("%Y%m%d", CAST(DESDE AS STRING));
	SET vmes_comision_id=CAST(FORMAT_DATE("%Y%m",date_trunc(vmes_comision_dt, MONTH)) AS INT64); 
	SET vversion=CAST((SELECT `mm-commissions-reporting.KRT_CAPTACION.getVersion_nmonths`(NMESES) as vversion) as INT64) ;
	
	
	--DECLARE desde int64; SET desde=20240601;
	
	--- PASO 1: CREO TABLAS HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO Y HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO
	
	case 	when nivel=0 THEN --SET nmeses=1;
				----- COMISIONES
				--- ver como resolver caso en que el mismo dia se ejecuten fujos de dos versiones sobre misma ventana temporal
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO`AS 
				SELECT CURRENT_DATE() as fecha_calc_dt, vmes_comision_dt as mes_comision_dt, vmes_comision_id, desde, hasta, vversion as version, 
				c.* except(mes_comision_id)
				FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES_LISTADO` as c
				where mes_comision_id=vmes_comision_id;

				----- DECOMISIONES
				--- ver como resolver caso en que el mismo dia se ejecuten fujos de dos versiones sobre misma ventana temporal
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_decomision_dt, c.mes_decomision_id as mes_decomision_id, CURRENT_DATE() as fecha_calc_dt,  desde, hasta, vversion as version, 
				c.* except(orden_sap, mes_decomision_id), c.orden_sap 
				FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` as c;


			when nivel=1 THEN ---SET nmeses=1;
				----- COMISIONES
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO` AS 
				SELECT c.* 
				FROM `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    			
				) and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH)
				
				UNION ALL 
				
				SELECT CURRENT_DATE() as fecha_calc_dt, vmes_comision_dt as mes_comision_dt, vmes_comision_id, desde, hasta, vversion as version, 
				c.* except(mes_comision_id)				
				FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES_LISTADO` as c
				WHERE NOT EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id = vmes_comision_id
				  --and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  --and c.version=vversion    
				);


				----- DECOMISIONES
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_decomision_dt, c.mes_decomision_id as mes_decomision_id,
				c.* except(mes_decomision_id),
				FROM `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    
				)--and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH) 

				UNION ALL 

				SELECT vmes_comision_dt as mes_decomision_dt, c.mes_decomision_id as mes_decomision_id, CURRENT_DATE() as fecha_calc_dt,  desde, hasta, vversion as version, 
				c.* except(orden_sap, mes_decomision_id), c.orden_sap 
				FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` as c 
				WHERE NOT EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id = vmes_comision_id
				  --and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  --and c.version=vversion    
				);---and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);
				
				
				    
			when nivel=2 THEN ---SET nmeses=1;
				----- COMISIONES			
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO`AS 
				SELECT c.* --except(fecha_calc_dt, desde, hasta, version)
				FROM `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    
				)and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);

				----- DECOMISIONES
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO`AS 

				SELECT vmes_comision_dt as mes_decomision_dt, c.mes_decomision_id as mes_decomision_id,
				c.* except(mes_decomision_id),
				FROM `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    
				);--and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);

	END CASE;


	--- PASO 2: ACTUALIZO TABLAS HISTORICO_COMISIONES_CARTERA_FACTURADO y HISTORICO_DECOMISIONES_CARTERA_FACTURADO
	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` where mes_comision_dt=vmes_comision_dt and version=vversion;
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO_EN_PROCESO`;

	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO` where mes_decomision_dt=vmes_comision_dt;
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO_EN_PROCESO`;
	

		
END