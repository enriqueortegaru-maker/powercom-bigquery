BEGIN


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` AS
	with eqxcan as (
		select distinct 
		tipo_canal_ds,
		canal_edw_ds,
		subcanal_edw_ds,
		codigo_canal_asociado
		from `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio` inv 
		order by 4
	), eqxag as (
		select distinct 
		codigo_canal_asociado,
		codigo_ventas,
		pe.swPersonalId
		from `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio` inv 
		inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe ON UPPER(TRIM(REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')))=UPPER(TRIM(REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(inv.codigo_Ventas), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')))
		where pe.swObjectType='CHANNEL_PARTNER'
		and pe.swEstado="Activo"
	), canxeqxag as (
		select distinct
		inv.tipo_canal_ds,
		inv.canal_edw_ds,
		inv.subcanal_edw_ds,
		inv.codigo_canal_asociado, 
		inv.equipo_edw_ds,
		ag.swPersonalId,  
		inv.codigo_ventas,
		from `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio` inv
		inner join eqxcan can using (tipo_canal_ds, canal_edw_ds,subcanal_edw_ds,codigo_canal_asociado) 
		inner join eqxag ag using(  codigo_canal_asociado,codigo_ventas) 
		where not contains_substr(subcanal_edw_ds,"EMPRESA")
		and inv.codigo_canal_asociado!=91
	), canxeqxag_un as (
		select *, count(equipo_edw_ds) over(partition by codigo_canal_asociado, swPersonalId) as nr
		from canxeqxag
		QUALIFY count(equipo_edw_ds) over(partition by codigo_canal_asociado, swPersonalId)=1
		order by nr desc
	) select 
		cn2.canal_agrupado2_id,
		cn2.canal_agrupado2_ds,
		cn1.canal_agrupado1_id,
		cn1.canal_agrupado1_ds,
		s.subcanal_id,
		s.subcanal_ds,
		cap.swChnlPartnerId as distribuidor_id,  
		cap.swCoInterno as distribuidor_ds,   

		m.codigo_canal_asociado as canal_id,  
		m.codigo_canal_asociado as canal_asociado_id,    
		ca.swCoInterno as canal_asociado_nombre,
		ca.swVerticalFocus as canal_asociado_descripcion,  

		m.equipo_edw_ds as equipo_ds,
		m.equipo_edw_ds as equipo_param_ctx,
		--- Cuando el canal de ventas es PUNTO DE VENTA, se importa como equipo el codigo del agente de ventas parametrizado en contextual   
		case when cn1.canal_agrupado1_ds="PUNTO DE VENTA" THEN m.codigo_ventas 
				when cn1.canal_agrupado1_ds="TASK FORCE" THEN m.codigo_ventas 
				when cn1.canal_agrupado1_ds="TELEVENTAS" THEN m.codigo_ventas        
		ELSE ca.swCoInterno 
	END AS funcion_equipo_ds ,
		m.swPersonalId as agente_alta_idnum,
		m.codigo_ventas as agente_alta_id,
		m.codigo_ventas as agente_alta_ds  


	from canxeqxag_un m
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca on ca.swChnlPartnerId=m.codigo_canal_asociado 
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` cap on cap.swChnlPartnerId=ca.swChnlPartnerCtralId 
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` cn1 on UPPER(TRIM(cn1.canal_agrupado1_ds))=UPPER(TRIM(m.canal_edw_ds))
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` cn2 on UPPER(TRIM(cn2.canal_agrupado2_ds))=UPPER(TRIM(m.tipo_canal_ds))
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` s on UPPER(TRIM(s.subcanal_ds))=UPPER(TRIM(m.subcanal_edw_ds))
	order by 2,4,6,8,11 asc;


/*

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` AS
	select distinct 
	m.codigo_canal_asociado as canal_id,
	m.codigo_ventas as agente_alta_id,
	cn1.canal_agrupado1_id,
	cn1.canal_agrupado1_ds,
	cn2.canal_agrupado2_id,
	cn2.canal_agrupado2_ds,
	s.subcanal_id,
	s.subcanal_ds,
	case when cn1.canal_agrupado1_ds="PUNTO DE VENTA" THEN m.codigo_ventas ELSE ca.swCoInterno END AS equipo_ds ,
	cap.swCoInterno as distribuidor_ds,	
	pe.swPersonalId as agente_alta_idnum
	--pt.swPersonalId as agente_alta_idnum_tcnet,
	--pe.swPersonalId as agente_alta_idnum_ektnet,
	--coalesce(pt.swPersonalId,pe.swPersonalId) as agente_alta_id,
	--ca.swStatus

	--pe2.swPersonalId as agente_alta_idnum2
	from  `dw-cloud-euskaltel-prod-283409.D10_CLEANING_EXTERNAL.clean_tr_t_30_maestro_canal`  m
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca on ca.swChnlPartnerId=m.codigo_canal_asociado	
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` cap on cap.swChnlPartnerId=ca.swChnlPartnerCtralId	
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` cn1 on UPPER(TRIM(cn1.canal_agrupado1_ds))=UPPER(TRIM(m.canal_edw_ds))
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` cn2 on UPPER(TRIM(cn2.canal_agrupado2_ds))=UPPER(TRIM(m.tipo_canal_ds))
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` s on UPPER(TRIM(s.subcanal_ds))=UPPER(TRIM(m.subcanal_edw_ds))
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pt  ON TRIM(REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pt.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'))= UPPER(TRIM(m.codigo_ventas)) AND pt.swObjectId=ca.swChnlPartnerId AND pt.swObjectType='CHANNEL_PARTNER' 
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe ON TRIM(REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'))  = UPPER(TRIM(m.codigo_ventas)) AND pe.swObjectId=ca.swChnlPartnerId AND pe.swObjectType='CHANNEL_PARTNER' 
	--left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe2  ON UPPER(TRIM(pe2.swNombreComercial)) = UPPER(TRIM(m.codigo_ventas)) AND pe.swObjectId=ca.swChnlPartnerId AND pe2.swObjectType='CHANNEL_PARTNER'		

	WHERE ca.swStatus<>'Excliente'
	and ca.swChnlPartnerId <> 91
	and coalesce(pe.swNombre, '') <> ''
	order by 1 asc, 2 asc;

*/


END