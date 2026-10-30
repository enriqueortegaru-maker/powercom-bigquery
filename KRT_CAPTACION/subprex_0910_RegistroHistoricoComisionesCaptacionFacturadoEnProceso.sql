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
	
	--SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerNivelDePublicacionDatosHistoricos`(desde)

	--DECLARE desde int64; SET desde=20240601;
	
	--- Recrear HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO
	case 	when nivel=0 THEN --SET nmeses=1;

				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_comision_dt, CURRENT_DATE() as fecha_calc_dt, desde, hasta, vversion as version, c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` as c;


				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_decomision_dt, CURRENT_DATE() as fecha_calc_dt, desde, hasta, vversion as version, c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` as c;

	

			when nivel=1 THEN ---SET nmeses=1;

				--- COMISION
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO` AS 
				SELECT vmes_comision_dt as mes_comision_dt, c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id=c.mes_comision_id
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    			
				) and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH)
				
				UNION ALL 
				
				SELECT vmes_comision_dt as mes_comision_dt, CURRENT_DATE() as fecha_calc_dt, desde, hasta, vversion as version, c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` as c
				WHERE NOT EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id=c.mes_comision_id				  
				  and r.mes_comision_id = vmes_comision_id
				  --and c.version=vversion    
				);


				--- DECOMISION
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_decomision_dt, c.* --except(fecha_calc_dt, desde, hasta, version)
				FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id=c.mes_decomision_id
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    
				)and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH)
				
				UNION ALL
				
				SELECT vmes_comision_dt as mes_decomision_dt, CURRENT_DATE() as fecha_calc_dt, desde, hasta, vversion as version, c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` as c 
				WHERE NOT EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id=c.mes_decomision_id				  
				  and r.mes_comision_id = vmes_comision_id
				  --and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  --and c.version=vversion    
				);--and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);




    
			when nivel=2 THEN ---SET nmeses=1;

				--- COMISION			
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_comision_dt,c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id=c.mes_comision_id				  
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    
				)and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);

				--- DECOMISION			
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`AS 
				SELECT vmes_comision_dt as mes_decomision_dt, c.* 
				FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` as c
				WHERE EXISTS(
				  select 1 
				  from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
				  where r.marca_ds=c.marca_ds
				  and r.mes_comision_id=c.mes_decomision_id				  				  
				  and r.mes_comision_id = vmes_comision_id
				  and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
				  and c.version=vversion    
				);--and parse_date ('%Y%m%d', CAST ( c.desde AS string) )=date_trunc(date_sub(c.fecha_calc_dt, interval nmeses month),MONTH);

	END CASE;



	DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` where mes_comision_dt=vmes_comision_dt;
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO_EN_PROCESO`;


	DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO` where mes_decomision_dt=vmes_comision_dt;
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO`  
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_FACTURADO_EN_PROCESO`;

		
END