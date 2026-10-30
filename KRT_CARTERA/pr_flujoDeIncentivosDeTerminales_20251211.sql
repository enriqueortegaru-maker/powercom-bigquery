BEGIN
  DECLARE FECHA_INICIO_DT, FECHA_FIN_DT, vMES_VENTA_DT DATE;
  DECLARE VDESDE_YYYYMM INT64;  
  DECLARE VIMPORTE_MINIMO INT64;    
  --DECLARE VDESDE, VHASTA INT64; SET VDESDE=20241201;SET VHASTA=20241231;
  SET FECHA_INICIO_DT=PARSE_DATE("%Y%m%d",CAST(VDESDE AS STRING));
  SET FECHA_FIN_DT=PARSE_DATE("%Y%m%d",CAST(VHASTA AS STRING));
  SET vMES_VENTA_DT=PARSE_DATE("%Y%m%d",CAST(VDESDE AS STRING));
  SET VDESDE_YYYYMM=CAST(FORMAT_DATE("%Y%m", PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING)))AS INT64);
  SET VIMPORTE_MINIMO=0;

  --SELECT VDESDE_YYYYMM;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS` AS
  --- Selecciono ventas incentivables dentro de ventana temporal especificada
  with pobVentas as (
    SELECT distinct v.*, i.importe
    FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES` v
    inner join  `mm-commissions-reporting.GS.PARAM_KRT_TERMINAL_INCENTIVO_IMPORTE` i 
    on UPPER(TRIM(i.marca))=UPPER(TRIM(v.marca)) and UPPER(TRIM(i.modelo))=UPPER(TRIM(v.modelo)) 
    and v.mes_venta_dt=DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(i.desde AS STRING)),MONTH)

    WHERE 
    /*VENTAS OBJETIVO DE INCENTIVO */
    v.mes_venta_dt=VMES_VENTA_DT 
    and DATE_DIFF(v.fecha_Creacion, PARSE_DATE("%Y%m%d",CAST(i.desde AS STRING)),DAY)>=0
    --- si una parametrizacion aplicada es de n tramos por mes, entonces se debe sustituir la anterior condicion poe esta otra
    ---   v.fecha_Creacion BETWEEN PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING)) and PARSE_DATE("%Y%m%d", CAST(vhasta AS STRING))
      

    --DATE_DIFF(v.fecha_Activacion, FECHA_INICIO_DT,DAY)>=0
    /*FALTA EXCLUIR VENTAS REALIZADAS EN RANGOS TEMPORALES NO CONTENIDOS */
    --AND  DATE_DIFF(v.fecha_Creacion,PARSE_DATE("%Y%m%d",CAST(i.desde AS STRING)), DAY )>=0
  )
  select distinct *
  from pobVentas p
  where not exists(
    select 1
    from `mm-commissions-reporting.GS.PARAM_KRT_TERMINAL_CANALES_EXCLUSION_INCENTIVO` e
    where UPPER(TRIM(e.marca))=UPPER(TRIM(p.marca_ds)) 
    and case when UPPER(TRIM(e.canal))='X' THEN TRUE ELSE UPPER(TRIM(e.canal))=UPPER(TRIM(p.canal)) END
    and case when UPPER(TRIM(e.subcanal))='X' THEN TRUE ELSE UPPER(TRIM(e.subcanal))=UPPER(TRIM(p.subcanal)) END
    and p.fecha_Creacion between PARSE_DATE("%Y%m%d",CAST(e.desde AS STRING)) AND PARSE_DATE("%Y%m%d",CAST(e.hasta AS STRING) )    
  )
  and importe is not null 
  --and idProducto=154792984
  --and p.canal="WEB"
  QUALIFY sum(importe) over(partition by marca_ds, usuarioCreador)>=VIMPORTE_MINIMO;

		
  --- REGISTRO EN HISTORICO_VENTAS_TERMINALES_INCENTIVOS
	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS` where mes_venta_dt=vMES_VENTA_DT;
	
	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS`
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS` 
  where mes_venta_dt=vMES_VENTA_DT;


  --- REGISTRO EN AGG_HISTORICO_VENTAS_TERMINALES_INCENTIVOS

	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TERMINALES_INCENTIVOS` g
  where exists (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS` i
    where i.fecha_calc_dt=g.fecha_calc_dt
  );
  

  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TERMINALES_INCENTIVOS` 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_INCENTIVOS`;



  --- REGISTRO DE MODELOS NO INCENTIVADOS

	CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.VENTAS_TERMINALES_MODELOS_NO_INCENTIVOS` 
	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
	SELECT  * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_ter_modelos_terminales_no_incentivados`(VDESDE_YYYYMM) ;

/*
  
  --- REGISTRO DE INCENTIVOS DE TERMINALES


	EXECUTE IMMEDIATE format("""
		CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.INCENTIVOS_VENTAS_TERMINALES_PT_POR_AGENTE`  
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
		SELECT * FROM
		(
			SELECT v.marca_ds as marca,	v.Canal as canal,	v.nombre_distribuidor,	v.UsuarioCreador as usuarioCreador, v.agente, concat(marca, ' - ',v.modelo) as modelo, v.idProducto, sum(v.importe) over(partition by marca, canal,  nombre_distribuidor,usuarioCreador, agente) as imp 	
			FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS` v
			WHERE mes_venta_dt=@vmes_venta
		)
		PIVOT
		(
		count(idProducto) 
		FOR modelo in %s
		)
		ORDER BY marca, canal, nombre_distribuidor, UsuarioCreador, agente ASC
		""", 
		(

			SELECT
			CONCAT('("', 
			STRING_AGG(DISTINCT concat(marca,' - ' ,replace(replace(replace(replace(replace(replace(modelo,'+',' '), '(', '' ),')',''),'"',''),',',' '),'.',' ')), '", "'	order by concat( marca,' - ' ,replace(replace(replace(replace(replace(replace(modelo,'+',' '), '(', '' ),')',''),'"',''),',',' '),'.',' '))) , '")'),
			FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_VENTAS_TERMINALES_INCENTIVOS`
		)

	)
	USING PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING)) as vmes_venta;  

*/



END