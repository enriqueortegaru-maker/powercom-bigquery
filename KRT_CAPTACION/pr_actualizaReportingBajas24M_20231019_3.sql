BEGIN
	DECLARE vMES_BAJA_DT DATE;
	DECLARE vMES_BAJA_ID INT64;
	DECLARE vMES_DECOMISION_ID INT64;
	--LOCAL
	--DECLARE NMESES INT64;SET NMESES=0;
	SET vMES_BAJA_DT=date_trunc(date_sub(CURRENT_DATE(), interval nmeses month),month);
	SET vMES_DECOMISION_ID=CAST(FORMAT_DATE("%Y%m",date_trunc(date_sub(CURRENT_DATE(),interval nmeses month),month)) as int64);

		/* PASO 1: RECUPERO EL FICHERO DE BAJAS DEL MES QUE SE VA A ACTUALIZAR  */
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_CARGA_REPORTING` AS	
	SELECT *	FROM  `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_HISTORICO` where mes_baja_dt=vMES_BAJA_DT;

		/* PASO 2: BORRO DEL FICHERO DE REPORTING LOS REGISTROS DE MES A ACTUALIZAR*/

	DELETE	FROM  `mm-commissions-reporting.KRT_CAPTACION.REPORTING_BAJAS24M` where mes_baja_dt=vMES_BAJA_DT;


		/* PASO 3: OBTENGO INDICADORES DE BAJAS A INSERTAR EN FICHERO DE REPORTING*/

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_REPORTING_BAJAS24M_CARGA_REGISTROS` AS 	
	with indbm as (
		with indb as (
			with i as (
					with s as (
						with sind as (
							with rd as (
									with l as (

										with port as (
							/* pr:bajas que cruzan con registro de portabilidad enriquecido con dato de operador receptor de la portabilidad */
												with pr as (
														with bf as (
														/* select distinct b.marca_ds, b.cliente_id, b.servicio_id, s.ani, b.fecha_rfb_dt, b.fecha_baja_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds, p.fecha_ventana_cambio_dt,operador_receptor_ds,p.marca_operador_receptor_ds,p.grupo_operador_receptor_ds,p.agrup_operador_receptor_ds, date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt), DAY) as ndias,
															from `mm-commissions-reporting.KRT_REPORTING.T_reporting_bajas24M` b
															left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on b.marca_ds=s.marca_ds and b.cliente_id=s.cliente_id and b.servicio_id=s.servicio_id
															inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_120_portabilidad_fijo` p on p.cliente_donante_id=b.cliente_id and p.servicio_donante_id=b.servicio_id  --on p.ani=s.ani
															where agrup_operador_donante_ds='GRUPO EUSKALTEL'
															and ABS(date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt),  DAY))<30
															and p.estado_portabilidad_fijo_ds="CONFIRMADA"*/

															select distinct b.marca_ds, b.cliente_id, b.servicio_id, b.fecha_rfb_dt, b.fecha_baja_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds, p.fecha_ventana_cambio_dt,operador_receptor_ds,p.marca_operador_receptor_ds,p.grupo_operador_receptor_ds,p.agrup_operador_receptor_ds, date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt), DAY) as ndias,
															from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_CARGA_REPORTING` b
															inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.cliente_id=b.cliente_id and s.servicio_id=b.servicio_id and not contains_substr(s.categoria_servicio_ds,'MOVIL')
															inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_120_portabilidad_fijo` p on /*p.servicio_donante_id=b.servicio_id**/ p.cliente_donante_id=b.cliente_id
															where agrup_operador_donante_ds='GRUPO EUSKALTEL'
															and ABS(date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt),  DAY))<30
															and p.estado_portabilidad_fijo_ds="CONFIRMADA"           
															and EXTRACT(DATE from date_trunc(b.fecha_baja_dt,month))=vMES_BAJA_DT

														), bm as (
															select distinct b.marca_ds, b.cliente_id, b.servicio_id,/* s.ani,*/ b.fecha_rfb_dt, b.fecha_baja_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds, p.fecha_ventana_cambio_dt,operador_receptor_ds,p.marca_operador_receptor_ds,p.grupo_operador_receptor_ds,p.agrup_operador_receptor_ds, date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt), DAY) as ndias, 
															from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_CARGA_REPORTING` b
															--left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on b.marca_ds=s.marca_ds and b.cliente_id=s.cliente_id and b.servicio_id=s.servicio_id
															inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.cliente_id=b.cliente_id and s.servicio_id=b.servicio_id and contains_substr(s.categoria_servicio_ds,'MOVIL')
															inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_130_portabilidad_movil` p on p.servicio_donante_id=b.servicio_id /* on p.cliente_donante_id=b.cliente_id  --on p.ani=s.ani*/
															where agrup_operador_donante_ds='GRUPO EUSKALTEL'
															and ABS(date_diff(fecha_ventana_cambio_dt, EXTRACT(DATE FROM b.fecha_baja_dt),  DAY))<30
															and p.estado_portabilidad_movil_ds="CONFIRMADA"
															and EXTRACT( DATE FROM date_trunc(b.fecha_baja_dt,month))=vMES_BAJA_DT
														) 
														select "fijo" as tipo, bf.*, row_number() over( partition By bf.marca_ds, bf.cliente_id,bf.servicio_id  ORDER BY date_diff(bf.fecha_ventana_cambio_dt, EXTRACT(DATE FROM bf.fecha_baja_dt), DAY) desc) as indice 
														from bf
														union all
														select "movil" as tipo, bm.*, row_number() over( partition By bm.marca_ds, bm.cliente_id,bm.servicio_id ORDER BY date_diff(bm.fecha_ventana_cambio_dt, EXTRACT(DATE FROM bm.fecha_baja_dt), DAY) desc) as indice 
														from bm
														/*where not exists(
															select 1 from bf
															where bf.cliente_id=bm.cliente_id and bf.servicio_id=bm.servicio_id
														)*/
												) 
												select distinct pr.*
												from pr
												where pr.indice=1
											), c as (
													SELECT mes_decomision_id, marca_ds, cliente_id, servicio_id,tipo_canal_alta_ds, canal_alta_ds,subcanal_ds,desc_mm,nombre_distribuidor_alta_ds,concepto_ds, 
																CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_rfb_dt)) as INT64) as mes_rfb_id,
																CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_baja_dt)) as INT64) as mes_baja_id,
																`mm-commissions-reporting.KRT_REPORTING.fmonths_between`(EXTRACT(DATE from fecha_baja_dt),EXTRACT(DATE from fecha_rfb_dt)) AS NMONTHS,
																--CAST(DATE_DIFF(EXTRACT(DATE from c.fecha_baja_dt),EXTRACT(DATE from c.fecha_rfb_dt),MONTH) AS INT64) AS NMONTHS, 
																CAST(DATE_DIFF(EXTRACT(DATE from fecha_baja_dt),EXTRACT(DATE from fecha_rfb_dt),DAY)  AS INT64)AS NDAYS 
													from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M_HISTORICO`
													 where mes_decomision_id=vmes_decomision_id 
											)
											select  c.*, port.marca_operador_receptor_ds,port.grupo_operador_receptor_ds,
											CASE WHEN Contains_substr(port.grupo_operador_receptor_ds,"DIGI SPAIN") THEN "DIGI" 
													WHEN Contains_substr(port.grupo_operador_receptor_ds,"ADAMO") THEN "ADAMO" 
													ELSE agrup_operador_receptor_ds END AS agrup_operador_receptor_ds,
											from  c
											left join port on c.cliente_id=port.cliente_id and c.servicio_id=port.servicio_id 
											where CONTAINS_SUBSTR(c.desc_mm,'Servicio') or CONTAINS_SUBSTR(c.desc_mm,'Portabilidad')  or CONTAINS_SUBSTR(c.desc_mm,'Television acceso') or CONTAINS_SUBSTR(c.desc_mm,'Terminal') or CONTAINS_SUBSTR(c.desc_mm,'Netflix') 
											or CONTAINS_SUBSTR(c.concepto_ds,'dazn')  or CONTAINS_SUBSTR(c.concepto_ds,'modulo pro') or CONTAINS_SUBSTR(c.concepto_ds,'alarma') or CONTAINS_SUBSTR(c.concepto_ds,'amazon')  or CONTAINS_SUBSTR(c.concepto_ds,'hegan')  
											or CONTAINS_SUBSTR(c.concepto_ds,' GB')  or CONTAINS_SUBSTR(c.concepto_ds,'mambo') or CONTAINS_SUBSTR(c.concepto_ds,'hegan') or CONTAINS_SUBSTR(c.concepto_ds,'llamadas') or CONTAINS_SUBSTR(c.concepto_ds,'ayud')  
											or CONTAINS_SUBSTR(c.concepto_ds,'bar')  or CONTAINS_SUBSTR(c.concepto_ds,'combi') 
											and c.mes_decomision_id=CAST(FORMAT_DATE("%Y%m",extract(DATE FROM port.fecha_baja_dt)) as INT64
										) 

									) select l.*, PERCENT_RANK() OVER (PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds ORDER BY ndays ASC) AS pDiario,
										case 
										when nmonths <7 then 0
										when nmonths <13 then 7
										when nmonths <19 then 13
										when nmonths <25 then 19
									END as grnmonths_id,
									case 
										when nmonths <7 then '0-6'
										when nmonths <13 then '7-12'
										when nmonths <19 then '13-18'
										when nmonths <25 then '19-24'
									END as grnmonths
									from l
									order by mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds,nmonths, ndays
							) select *, last_value(pDiario) OVER (PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds,nmonths ORDER BY nmonths ASC) AS pMensual,
							from rd
							order by mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds,nmonths, ndays
						) select distinct  c.* except(categoria_servicio_ds),
							sind.marca_operador_receptor_ds, sind.grupo_operador_receptor_ds, sind.agrup_operador_receptor_ds,
									case when (CONTAINS_SUBSTR(c.detalle_servicio_ds,'MAMBO AXIÑA') or CONTAINS_SUBSTR(c.detalle_servicio_ds,'HEGAN-COMBI YES'))=FALSE THEN c.categoria_servicio_ds ELSE 'BANDA ANCHA'END as categoria_servicio_ds,
									case when CONTAINS_SUBSTR(c.desc_mm,'Servicio acceso BA') then 1 else 0 END as Acceso_BA, 
									case when CONTAINS_SUBSTR(c.desc_mm,'Servicio') or CONTAINS_SUBSTR(c.desc_mm,'Portabilidad')  or CONTAINS_SUBSTR(c.desc_mm,'Television acceso') then 1 else 0 END as  Servicio, 
									case when CONTAINS_SUBSTR(c.desc_mm,'Servicio acceso BA') then 1 else 0 END as  Servicio_BA,
									case when CONTAINS_SUBSTR(c.desc_mm,'Servicio Fijo') or  CONTAINS_SUBSTR(c.desc_mm,'Portabilidad Fijo') then 1 else 0 END as  Servicio_TF,
									case when CONTAINS_SUBSTR(c.desc_mm,'Servicio Movil') or  CONTAINS_SUBSTR(c.desc_mm,'Portabilidad Movil') then 1 else 0 END as  Servicio_TM,
									case when CONTAINS_SUBSTR(c.desc_mm,'Television acceso') then 1 else 0 END as  Servicio_TV,
									case when CONTAINS_SUBSTR(c.desc_mm,'Terminal') then 1 else 0 END as  Terminal,
									case when CONTAINS_SUBSTR(c.desc_mm,'Netflix') then 1 else 0 END as  Netflix,
									EXTRACT(DATE FROM fecha_rfb_dt) as fechaAlta,
									CAST(FORMAT_DATE("%Y%m",EXTRACT(DATE FROM fecha_rfb_dt)) AS INT64) as mes_rfb_id,                
									EXTRACT(DATE FROM c.fecha_baja_dt) as fechaBaja,
									CAST(FORMAT_DATE("%Y%m",EXTRACT(DATE FROM fecha_baja_dt)) AS INT64) as mes_baja_id,                
						CAST(sind.NMONTHS AS INT64) as NMONTHS, sind.NDAYS,sind.pDiario, sind.pMensual, CAST(grnmonths_id AS INT64) grnmonths_id, sind.grnmonths,   
						from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M_HISTORICO` c
						left join sind on sind.marca_ds=c.marca_ds and sind.cliente_id=c.cliente_id and sind.servicio_id=c.servicio_id and  sind.tipo_canal_alta_ds=c.tipo_canal_alta_ds and sind.canal_alta_ds=c.canal_alta_ds and sind.subcanal_ds=c.subcanal_ds and sind.nombre_distribuidor_alta_ds=c.nombre_distribuidor_alta_ds
					) select s.*, 

					---Total por mes de baja y marca   
					---Total por mes de baja, marca y categoria de servicio             
					---Total por mes de baja, marca, categoria de servicio y distribuidor
					---Total por mes de baja, marca y canalizacion 
					---Total por mes de baja, marca, categoria de servicio y canalizacion
					---Total por mes de baja, marca, categoria de servicio, distribuidor y portabilidad
					---Total por mes de baja, marca, categoria de servicio, canalizacion y portabilidad

					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds ORDER BY mes_decomision_id, marca_ds ASC) as int64)  as nbaj_tot,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds ASC) as int64)  as nbaj_cat_tot,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_cat_dist_tot,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_can_dist_tot,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_dist_tot,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ASC) as int64)  as nbaj_cat_dist_port_tot,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_port_tot,

					---- Nueva denominación, borrar anteriores
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds ORDER BY mes_decomision_id, marca_ds ASC) as int64)  as nbajxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds ASC) as int64)  as nbaj_catxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds ASC) as int64)  as nbaj_cat_canalxmarca,        
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_cat_distxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_can_distxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_distxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64)  as nbaj_cat_dist_portxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_portxmarca,



					---Total por mes de baja y marca
					---Total por mes de baja, marca y categoria de servicio                     
					---Total por mes de baja, marca, categoria de servicio y distribuidor
					---Total por mes de baja, marca y canalizacion 
					---Total por mes de baja, marca, categoria de servicio y canalizacion
					---Total por mes de baja, marca, categoria de servicio, distribuidor y portabilidad
					---Total por mes de baja, marca, categoria de servicio, canalizacion y portabilidad

					
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds  ORDER BY marca_ds ASC) as int64) as nbaj_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds  ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds ASC) as int64) as nbaj_cat_mesxmarca,  
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ASC) as int64) as nbaj_cat_canal_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_dist_mesxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_can_dist_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_dist_mesxmarca,


					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_dist_port_mesxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_port_mesxmarca,



					---Total por mes de baja, diferencia de meses entre alta y baja y marca
					---Total por mes de baja, diferencia de meses entre alta y baja, marca y categoria de servicio                     
					---Total por mes de baja, diferencia de meses entre alta y baja, marca, categoria de servicio y distribuidor
					---Total por mes de baja, diferencia de meses entre alta y baja, marca y canalizacion 
					---Total por mes de baja, diferencia de meses entre alta y baja, marca, categoria de servicio y canalizacion
					---Total por mes de baja, diferencia de meses entre alta y baja, marca, categoria de servicio, distribuidor y portabilidad
					---Total por mes de baja, diferencia de meses entre alta y baja, marca, categoria de servicio, canalizacion y portabilidad

					
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, NMONTHS ASC) as int64) as nbaj_nmes_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, NMONTHS ASC) as int64) as nbaj_cat_nmes_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ASC) as int64) as nbaj_cat_canal_nmes_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds,  NMONTHS ASC) as int64) as nbaj_cat_dist_nmes_mesxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,NMONTHS ASC) as int64) as nbaj_can_dist_nmes_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ASC) as int64) as nbaj_cat_can_dist_nmes_mesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds,  NMONTHS ASC) as int64) as nbaj_cat_dist_port_nmes_mesxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, NMONTHS ASC) as int64) as nbaj_cat_can_dist_port_nmes_mesxmarca,



					---Total por mes de baja, marca, categoria de servicio y grupo de diferencia de meses entre baja y alta   
					---Total por mes de baja, marca, categoria de servicio, grupo de diferencia de meses entre baja y alta, y canalización 
					---Total por mes de baja, categoria, canalizacion y distribuidor
					---Total por mes de baja, marca, categoria de servicio, grupo de diferencia de meses y portabilidad entre baja y alta   
					---Total por mes de baja, categoria, canalizacion, distribuidor y portabilidad

					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, categoria_servicio_ds, GRNMONTHS_ID ASC) as int64) as nbaj_cat_grmesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, GRNMONTHS_ID ASC) as int64) as nbaj_cat_dist_grmesxmarca,            
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, GRNMONTHS ORDER BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, GRNMONTHS_ID ASC) as int64)  as nbaj_can_dist_grmesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,GRNMONTHS ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,  GRNMONTHS_ID ASC) as int64)  as nbaj_cat_can_dist_grmesxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, GRNMONTHS_ID ASC) as int64) as nbaj_cat_dist_port_grmesxmarca,            
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds,GRNMONTHS ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, GRNMONTHS_ID ASC) as int64)  as nbaj_cat_can_dist_port_grmesxmarca,



					---Total por mes de alta y marca
					---Total por mes de alta, marca y categoria de servicio                     
					---Total por mes de alta, marca, categoria de servicio y distribuidor
					---Total por mes de alta, marca y canalizacion 
					---Total por mes de alta, marca, categoria de servicio y canalizacion
					---Total por mes de alta, marca, categoria de servicio, distribuidor y portabilidad
					---Total por mes de alta, marca, categoria de servicio, canalizacion, distribuidor y portabilidad

					
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds  ORDER BY marca_ds ASC) as int64) as nbaj_mesAltaxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds  ORDER BY mes_decomision_id, mes_rfb_id, marca_ds,categoria_servicio_ds ASC) as int64) as nbaj_cat_mesAltaxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY  mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ASC) as int64) as nbaj_cat_canal_mesAltaxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_dist_mesAltaxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_can_dist_mesAltaxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY  mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_dist_mesAltaxmarca,
					CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_dist_port_mesAltaxmarca,      
					CAST(sum(s.Servicio) over(PARTITION BY  mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_port_mesAltaxmarca,


					from s
				) select *, 
					--- Porcentaje por distribuidor por mes (nbaj_can_dist_mesxmarca) y grupo de mes (nbaj_can_dist_grmesxmarca) respecto al total en 24 meses (nbaj_can_dist_tot)
					--- Porcentaje por distribuidor por mes (nbaj_cat_can_dist_mesxmarca) y grupo de mes (nbaj_cat_can_dist_grmesxmarca) respecto al total en 24 meses (nbaj_cat_can_dist_tot)


					--SAFE_DIVIDE(nbaj_can_distxmarca,nbaj_can_dist_tot) as pserv_can_distxmarca,  
					--SAFE_DIVIDE(nbaj_cat_distxmarca,nbaj_cat_dist_tot) as pserv_cat_distxmarca, 
					--SAFE_DIVIDE(nbaj_cat_can_distxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_distxmarca,


					SAFE_DIVIDE(nbaj_can_dist_mesxmarca,nbaj_can_dist_tot) as pserv_can_dist_mesxmarca,  
					SAFE_DIVIDE(nbaj_cat_dist_mesxmarca,nbaj_cat_dist_tot) as pserv_cat_dist_mesxmarca, 
					SAFE_DIVIDE(nbaj_cat_canal_mesxmarca,nbaj_cat_canalxmarca) as pserv_cat_canal_mesxmarca, 
					SAFE_DIVIDE(nbaj_cat_can_dist_mesxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_dist_mesxmarca,      
					SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_dist_port_tot) as pserv_cat_dist_port_mesxmarca,  
					SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_dist_port_tot) as pserv_cat_can_dist_port_mesxmarca,      


					SAFE_DIVIDE(nbaj_can_dist_nmes_mesxmarca,nbaj_can_dist_tot) as pserv_can_dist_nmes_mesxmarca,  
					SAFE_DIVIDE(nbaj_cat_dist_nmes_mesxmarca,nbaj_cat_dist_tot) as pserv_cat_dist_nmes_mesxmarca, 
					SAFE_DIVIDE(nbaj_cat_canal_nmes_mesxmarca,nbaj_cat_canalxmarca) as pserv_cat_canal_nmes_mesxmarca,         
					SAFE_DIVIDE(nbaj_cat_can_dist_mesxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_dist_nmes_mesxmarca,
					SAFE_DIVIDE(nbaj_cat_dist_port_nmes_mesxmarca,nbaj_cat_dist_port_tot) as pserv_cat_dist_port_nmes_mesxmarca,  
					SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_dist_port_tot) as pserv_cat_can_dist_port_nmes_mesxmarca,

					SAFE_DIVIDE(nbaj_cat_dist_grmesxmarca,nbaj_cat_dist_tot) as pserv_cat_dist_grmesxmarca,        
					SAFE_DIVIDE(nbaj_can_dist_grmesxmarca,nbaj_can_dist_tot) as pserv_can_dist_grmesxmarca,  
					SAFE_DIVIDE(nbaj_cat_can_dist_grmesxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_dist_grmesxmarca,
					SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_port_tot) as pserv_cat_dist_port_grmesxmarca,        
					SAFE_DIVIDE(nbaj_cat_can_dist_port_grmesxmarca,nbaj_cat_can_dist_port_tot) as pserv_cat_can_dist_port_grmesxmarca,

					--SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_distxmarca) as pserv_cat_dist_port_intramesxmarca
					--SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_grmesxmarca) as pserv_cat_dist_port_intragrmesxmarca

					--SAFE_DIVIDE(nbaj_can_dist_port_mesxmarca,nbaj_can_distxmarca) as pserv_can_dist_intramesxmarca,  
					SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_distxmarca) as pserv_cat_dist_intramesxmarca, 
					--SAFE_DIVIDE(nbaj_cat_canal_port_mesxmarca,nbaj_cat_canalxmarca) as pserv_cat_canal_intramesxmarca, 
					SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_distxmarca) as pserv_cat_can_dist_intramesxmarca,      
					SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_distxmarca) as pserv_cat_dist_port_intramesxmarca,  
					SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_distxmarca) as pserv_cat_can_dist_port_intramesxmarca,      

					--SAFE_DIVIDE(nbaj_can_dist_port_grmesxmarca,nbaj_can_dist_grmesxmarca) as pserv_can_dist_intramesxmarca,  
					SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_grmesxmarca) as pserv_cat_dist_intragrmesxmarca, 
					--SAFE_DIVIDE(nbaj_cat_canal_port_mesxmarca,nbaj_cat_canal_grmesxmarca) as pserv_cat_canal_intramesxmarca, 
					SAFE_DIVIDE(nbaj_cat_can_dist_port_grmesxmarca,nbaj_cat_can_dist_grmesxmarca) as pserv_cat_can_dist_intragrmesxmarca,      
					SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_grmesxmarca) as pserv_cat_dist_port_intragrmesxmarca,  
					SAFE_DIVIDE(nbaj_cat_can_dist_port_grmesxmarca,nbaj_cat_can_dist_grmesxmarca) as pserv_cat_can_dist_port_intragrmesxmarca,      

				from i
		), inda as (
				with la as (
					select distinct/*mes_comision_id,*/ CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_rfb_dt)) as INT64) as mes_alta_id,  
					marca_ds, categoria_servicio_ds, tipo_canal_alta_ds,  canal_alta_ds, subcanal_ds,nombre_distribuidor_alta_ds, fecha_rfb_dt,fecha_rfb_id, servicio_id
					from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO`
					--where (contains_substr(clase_mm,"A - " ) or contains_substr(clase_mm,"B - " ) or contains_substr(clase_mm,"R - " ) )

				) select distinct /*mes_comision_id,*/  marca_ds, categoria_servicio_ds, tipo_canal_alta_ds,  canal_alta_ds, subcanal_ds,nombre_distribuidor_alta_ds, mes_alta_id,fecha_rfb_id,  
					---Total por mes de alta y marca   
					---Total por mes de alta, marca, categoria de servicio y canalizacion
						---- REHACER EL TOTAL INCLUYENDO LIMITES TEMPORALES 
						CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds) as int64)  as nactxmarca,        
						CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds,categoria_servicio_ds) as int64)  as nact_catxmarca, 
						CAST(count (distinct servicio_id) over(PARTITION BY marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ) as int64)  as nact_cat_canalxmarca,                 
						CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)  as nact_cat_distxmarca,      
						CAST(count (distinct servicio_id) over(PARTITION BY marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ) as int64)  as nact_cat_can_distxmarca,      
						--CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)  as nact_cat_dist_portxmarca,      
						--CAST(count (distinct servicio_id) over(PARTITION BY marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ) as int64)  as nact_cat_can_dist_portxmarca,      


						----
						CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds) as int64)  as nact_mesAltaxmarca,      
						CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds) as int64)  as nact_cat_mesAltaxmarca, 
						CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds) as int64)  as nact_cat_canal_mesAltaxmarca,             
						CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds ) as int64)  as nact_cat_can_mesAltaxmarca,  
						CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)  as nact_cat_dist_mesAltaxmarca,                                              
						CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ) as int64)  as nact_cat_can_dist_mesAltaxmarca,      
						--CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)  as nact_cat_dist_port_mesAltaxmarca,                                              
						--CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ) as int64)  as nact_cat_can_dist_port_mesAltaxmarca,      

				from la
				order by 1 desc, 2 asc, 3 asc, 4 asc,5 asc, 6 asc, 7 asc
		) select distinct indb.*,
		--CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_baja_dt)) as INT64) as mes_baja_id,
		inda.mes_alta_id, 
		inda.nactxmarca,inda.nact_catxmarca,inda.nact_cat_distxmarca,inda.nact_cat_can_distxmarca, inda.nact_mesAltaxmarca,inda.nact_cat_mesAltaxmarca,inda.nact_cat_can_mesAltaxmarca,inda.nact_cat_dist_mesAltaxmarca,inda.nact_cat_can_dist_mesAltaxmarca,      
		--CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_rfb_dt)) as INT64) as mes_rfb_id,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_mesAltaxmarca) END as pact_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_mesAltaxmarca) END as pact_cat_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_canal_mesAltaxmarca) END as pact_cat_canal_mesAltaxmarca,  
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_can_mesAltaxmarca) END as pact_cat_can_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_dist_mesAltaxmarca) END as pact_cat_dist_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_can_dist_mesAltaxmarca) END as pact_cat_can_dist_mesAltaxmarca,
		--CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_dist_port_mesAltaxmarca) END as pact_cat_dist_port_mesAltaxmarca,
		--CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_can_dist_port_mesAltaxmarca) END as pact_cat_can_dist_port_mesAltaxmarca,

		SAFE_DIVIDE(nbajxmarca,nactxmarca) as pactxmarca,
		SAFE_DIVIDE(nbaj_catxmarca,nact_catxmarca) as pact_catxmarca,
		SAFE_DIVIDE(nbaj_cat_canalxmarca,nact_cat_canalxmarca) as pact_cat_canalxmarca,  
		SAFE_DIVIDE(nbaj_cat_distxmarca,nact_cat_distxmarca) as pact_cat_distxmarca,
		SAFE_DIVIDE(nbaj_cat_can_distxmarca,nact_cat_can_distxmarca) as pact_cat_can_distxmarca,  
		SAFE_DIVIDE(nbaj_cat_dist_portxmarca,nact_cat_distxmarca) as pact_cat_dist_portxmarca,
		SAFE_DIVIDE(nbaj_cat_can_dist_portxmarca,nact_cat_can_distxmarca) as pact_cat_can_dist_portxmarca,  
		from indb
		left join inda on indb.marca_ds=inda.marca_ds and indb.categoria_servicio_ds=inda.categoria_servicio_ds  and indb.tipo_canal_alta_ds=inda.tipo_canal_alta_ds and indb.canal_alta_ds=inda.canal_alta_ds and indb.subcanal_ds=inda.subcanal_ds and inda.nombre_distribuidor_alta_ds=indb.nombre_distribuidor_alta_ds and indb.FECHA_RFB_ID=inda.fecha_rfb_id and indb.mes_rfb_id=inda.mes_alta_id
	) select distinct EXTRACT(DATE FROM DATE_TRUNC(fecha_baja_dt,month)) as mes_baja_dt, *,
	CAST(SUM(100000000000000*pact_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds) as int64)/100000000000000  as pactac_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds) as int64)/100000000000000  as pactac_cat_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_canal_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds) as int64)/100000000000000  as pactac_cat_canal_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_can_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds) as int64)/100000000000000  as pactac_cat_can_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)/100000000000000  as pactac_cat_dist_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_can_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds) as int64)/100000000000000  as pactac_cat_can_dist_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)/100000000000000  as pactac_cat_dist_port_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_can_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)/100000000000000  as pactac_cat_can_dist_port_mesAltaxmarca,
	from indbm;




	/* PASO 4: INSERTO INDICADORES DE BAJAS A INSERTAR EN TABLADE REPORTING*/
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.REPORTING_BAJAS24M`
	SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_REPORTING_BAJAS24M_CARGA_REGISTROS`;


END