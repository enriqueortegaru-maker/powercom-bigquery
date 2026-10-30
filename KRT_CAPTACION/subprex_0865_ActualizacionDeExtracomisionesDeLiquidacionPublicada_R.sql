BEGIN
	/*
	Este módulo tiene como objeto recalcular las extraconisiones de postventa, rappel diferencia y extras sobre los unitarios de la extracción publicada, aplicando la última parametrización empleada para el cálculo de las comisiones.
	El módulo utiliza los datos de 
	
	La parametrización del mes que se recalcula
	La extracción base de la liquidación

	Para ello se deben recuperar ñas parametrizaciones

		PARAM_RAPPEL_CANALES
		PARAM_RAPPEL_ASIGNADO
		PARAM_RAPPEL_ALCANZADO
		PARAM_POSTVENTA
		PARAM_EXTRAS




	*/


	--- PASO 0: DEFINO VARIABLES
	DECLARE fecha_parametrizacion_dt DATE;
	DECLARE fecha_publicacion_r_dt DATE;	
	DECLARE fecha_publicacion_r_id INT64;
	DECLARE mes_comision_id INT64;
	DECLARE vversion INT64;
	--LOCAL 
	--DECLARE vdesde, vhasta INT64; SET vdesde=20240801; SET vhasta=20240831;
	SET fecha_parametrizacion_dt = (select max(fecha_Calc_dt) from `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` p where p.desde=vdesde);
	SET fecha_publicacion_r_id =(SELECT fecha_id FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_PUBLICACION` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde and marca_ds='R' and mes_comision_id=CAST(TRUNC(vdesde/100) AS INT64));
	SET fecha_publicacion_r_dt=PARSE_DATE("%Y%m%d",CAST(fecha_publicacion_r_id AS STRING));
	SET vversion=(SELECT  max(version) FROM  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt=fecha_publicacion_r_dt  and desde=vdesde and marca_ds='R');
	
	---SELECT fecha_parametrizacion_dt, fecha_publicacion_r_id, fecha_publicacion_r_dt;


	--- PASO 1: RECUPERACION DE TABLA DE COMISIONADO EN FECHA PUBLICADA
	

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_IN`  AS 
	SELECT * except (fecha_calc_dt, desde, hasta, version)FROM  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt=fecha_publicacion_r_dt  and desde=vdesde and marca_ds='R'; 

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` AS 
	SELECT * except(decomisionable, mes_comision_id) 
	FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_IN`
	where not contains_substr(clase_mm,'Y - ') 
	and not contains_substr(clase_mm,'R -') 
	and not contains_substr(desc_mm,'D -')
	and not (contains_substr(desc_mm,'P - Penaliza') and contains_substr(desc_mm,'pondera') and contains_substr(desc_mm,'rappel'))
	and not (contains_substr(desc_mm,'P - Penaliza') and contains_substr(desc_mm,'portabilidad'));
	

	--- PASO 2: RECUPERACION DE TABLAS DE PARAMETRIZACION
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_POSTVENTA_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA` AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_POSTVENTA` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_EXTRAS_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS` AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta)  FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_EXTRAS` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_CANALES_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES`  AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_CANALES` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;

/*	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_RAPPEL_ALCANZADO`  AS 
	SELECT p.* FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_ALCANZADO` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;
*/
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_NIVEL_RAPPEL_ASIGNADO_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO`  AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVEL_RAPPEL_ASIGNADO` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;
/*
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_RAPPEL_ALCANZADO`  AS 
	SELECT p.* FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_RAPPEL_ALCANZADO` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;
*/
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_PUBLICACION_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION`  AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_PUBLICACION` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_OBJETIVOS_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS`  AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_OBJETIVOS` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_NIVELES_OBJETIVOS_P_OR` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P`  AS 
	SELECT p.* except(fecha_calc_dt, desde, hasta) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_NIVELES_OBJETIVOS_P` p where p.fecha_calc_dt=fecha_parametrizacion_dt and p.desde=vdesde;



	--- PASO 3: RECUPERACION DE TABLAS DE RAPPEL_VENTAS EN FECHA PUBLICADA
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RAPPEL_VENTAS_BACKUP` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RAPPEL_VENTAS_NO_PRESENCIAL_BACKUP` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`;
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` AS
	SELECT * except (fecha_calc_dt, desde, hasta, version) FROM  `mm-commissions-reporting.KRT_CAPTACION.AGG_RAPPEL_VENTAS` where fecha_calc_dt=fecha_publicacion_r_dt  and hasta=vhasta and marca_ds='R'; 
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`;

	
	--- PASO 2: CALCULA RAPPEL
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0302_CalcularRappel_Subcanalv1`(vhasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0303_CalcularRappel_Canalv2`(vhasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0304_CalcularRappel_Presencialv1`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0305_CalcularRappel_Ventas_NoPresencialv1`(desde , hasta);    
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0305_CalcularRappel_Ventas_NoPresencialv2`(desde , hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0306_CalcularRappel_Subcanal_NoPresencialv1`(vhasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0307_CalcularRappel_Canal_NoPresencialv1`(vhasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_0308_CalcularRappel_Alcanzado`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0402_InsertarRappel_Teoricov2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0403_InsertarRappel_Diferenciav3`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0420_ExcluirComisionesDeRappelPorCatalogov2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0425_PonderarComisionesDeRappelPorCanalyCatalogo`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0430_ExcluirComisionesDeRappelPorOfertasyPromociones`();

	--- PASO 3: CALCULA EXTRAS Y POSTVENTA
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_0503_CargarAjustesEventosDefinitivos`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtrasv3`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtrasv4`();  
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_050410_CrearApuntesDistribucionExtrasv1`();      
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0505_InsertarAjustesPostventav2`();
    CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0506_ActualizarConceptoOfertasYPromociones`(); 

	--- PASO 4: CALCULA COMISIONES SALIDA
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` AS 
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`;
	
	call `mm-commissions-reporting.KRT_CAPTACION.subprex_0801_CrearComisionesv2`(vdesde, vhasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0803_PenalizarRappelDeComisionesv2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0805_CorrectivoDeOrdenesSap`();

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_OUT` 
	AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;


	--- PASO 5: CALCULA INCREMENTO EN RAPPEL DIFERENCIA (RECALCULO)
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RECALCULO_RAPPEL_DIF_R_OUT` AS	
	with pb as (
			select distinct c1.*
			from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR3_COM_1M_LIST_COM_DIST_RAPPEL` dc
			inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
			on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.  clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
	), pa as (
			select distinct c2.* 
			from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR3_COM_1M_LIST_COM_DIST_RAPPEL` dc
			inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
			on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm

	) select pa.* except(importe, decomisionable, mes_comision_id), (pa.importe - pb.importe) as importe, pa.decomisionable, pa.mes_comision_id
	from pa 
	inner join pb using (marca_ds,cliente_id,categoria_servicio_ds,servicio_id,clase_mm,desc_mm)
	where pa.marca_ds="R";

	UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RECALCULO_RAPPEL_DIF_R_OUT`
	SET grid=CASE WHEN grid<0 THEN grid-200 ELSE grid+200 END  WHERE TRUE;



	--- PASO 6: CALCULA VARIACION EN PENALIZACION DE RAPPEL TRAS RECALCULO (RECALCULO)
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RECALCULO_PENALIZA_RAPPEL_R_OUT` AS 	
	with pb as (
			select distinct c1.*
			from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR32_COM_1M_LIST_COM_DIST_PENALIZA_RAPPEL` dc
			inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
			on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.  clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
	), pa as (
			select distinct c2.* 
			from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR32_COM_1M_LIST_COM_DIST_PENALIZA_RAPPEL` dc
			inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
			on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm

	) select pa.* except(importe, decomisionable, mes_comision_id), (pa.importe - pb.importe) as importe, pa.decomisionable, pa.mes_comision_id
	from pa 
	inner join pb using (marca_ds,cliente_id,categoria_servicio_ds,servicio_id,clase_mm,desc_mm)
	where pa.marca_ds="R"
	and (pa.importe - pb.importe)<>0;
	
	UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RECALCULO_PENALIZA_RAPPEL_R_OUT`
	SET grid=CASE WHEN grid<0 THEN grid-200 ELSE grid+200 END  WHERE TRUE;



	--- PASO 7: EXTRAE COMISIONES POSTVENTA TRAS CALCULO CON REPARAMETRIZACION (RECALCULO)
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_REPARAMETRIZACION_POSTVENTA_R` AS	
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_OUT` WHERE contains_substr(desc_mm,"D - POSTVENTA");
	
	UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_REPARAMETRIZACION_POSTVENTA_R`
	SET grid=CASE WHEN grid<0 THEN grid-200 ELSE grid+200 END WHERE TRUE;

	

	--- PASO 5: GUARDO EXTRACCION ORIGINAL EN FECHA DE PUBLICACION
/*
	CASE WHEN (SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES_EXTRACCION_ORIGINAL` WHERE fecha_calc_dt=fecha_publicacion_r_dt and desde=vdesde) = 0 
		THEN INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES_EXTRACCION_ORIGINAL` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt=fecha_publicacion_r_dt  and desde=vdesde;				
	END CASE;
*/



	--- PASO 6: BORRO LOS REGISROS DE EXTRACOMISIONES DE POSTVENTA EN AGG_COMISIONES`
	
	DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt=fecha_publicacion_r_dt  and desde=vdesde and marca_ds='R' and desc_mm="D - POSTVENTA"; 
	
	
	--- PASO 7: INSERTO LOS REGISROS DE EXTRACOMISIONES A ACTUALIZAR EN AGG_COMISIONES`

	
	--- 	PASO 7.1 INSERTO NUEVOS REGISTROS DE POSTVENTA
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES`
	SELECT fecha_publicacion_r_dt,
	vdesde,
	vhasta,
	vversion,
	c.* 
	FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_REPARAMETRIZACION_POSTVENTA_R` c;

	
	--- 	PASO 7.2 INSERTO NUEVOS REGISTROS CON DIFERENCIAS EN EXTRACOMISION DE RAPPEL DIFERENCIA
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES`
	SELECT fecha_publicacion_r_dt,
	vdesde,
	vhasta,
	vversion,
	c.* 
	FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RECALCULO_RAPPEL_DIF_R_OUT` c;


	--- PASO FINAL: REPONGO TABLAS ORIGINALES`
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RAPPEL_VENTAS_BACKUP`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_RAPPEL_VENTAS_NO_PRESENCIAL_BACKUP`;

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA` AS SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_POSTVENTA_OR`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_EXTRAS_OR`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_CANALES_OR`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_NIVEL_RAPPEL_ASIGNADO_OR`;	
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_PUBLICACION_OR`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_OBJETIVOS_OR`;
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_PARAM_NIVELES_OBJETIVOS_P_OR`;


	/* CONTROLES
	SELECT clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R`  
	group by 1,2 
	order by 1,2 ;


	SELECT clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  
	group by 1,2 
	order by 1,2 ;


	SELECT clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`  
	group by 1,2 
	order by 1,2 ;



	with p as (
		SELECT * except(decomisionable, mes_comision_id) 
		FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_IN`
		where not contains_substr(desc_mm,'D -')
		and not (contains_substr(desc_mm,'P - Penaliza') and contains_substr(desc_mm,'pondera') and contains_substr(desc_mm,'rappel'))
	) SELECT clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM p
	group by 1,2 
	order by 1,2 ;

	with pin as (
		SELECT * except(decomisionable, mes_comision_id) 
		FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_IN`

	), pout as (
		SELECT * except(decomisionable, mes_comision_id) 
		FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0865_COMISIONES_R_OUT`
	), evd as (
		SELECT * 
		FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
	), c801 as (
		SELECT * except(decomisionable, mes_comision_id) 
		FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES`
	), c803i as (
		SELECT * except(decomisionable, mes_comision_id) 
		FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_INI`
	), c803f as (
		SELECT * except(decomisionable, mes_comision_id) 
		FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_FIN`
	) 

	SELECT "PIN" as clase, clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM pin
	group by 1,2,3 
	UNION ALL 
	SELECT "EVD" as clase, clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM evd
	group by 1,2,3
	UNION ALL 
	SELECT "C801" as clase, clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM c801
	group by 1,2,3
	UNION ALL 
	SELECT "C803i" as clase, clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM c803i
	group by 1,2,3
	UNION ALL 
	SELECT "C803f" as clase, clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM c803f
	group by 1,2,3
	UNION ALL 
	SELECT "POUT" as clase, clase_mm, desc_mm, count(servicio_id) as nserv, CAST(sum(importe) AS INT64) as importe 
	FROM pout
	group by 1,2,3
	order by 1,2,3;

	*/


END