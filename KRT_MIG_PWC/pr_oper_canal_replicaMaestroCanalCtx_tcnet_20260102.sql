BEGIN


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` AS
	with eqxcan as (
		select distinct 
		tipo_canal_ds,
		canal_edw_ds,
		subcanal_edw_ds,
		codigo_canal_asociado,
		from `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio` inv 
		order by 4
	),eqxag as (
		select distinct 
		codigo_canal_asociado,
		codigo_ventas,
		pe.swPersonalId, 
		struct (
				pe.swPersonalId as id,
				pe.swNombre as nombre,
				pe.swEstado as estado,
				EXTRACT(DATE FROM pe.swDateCreated) as fechaCreacion,
				EXTRACT(DATE FROM pe.swFechaAlta) as fechaAlta,		
				EXTRACT(DATE FROM pe.swFechaBaja) as fechaBaja
		) as agente 		

		from `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio` inv 
		inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe ON UPPER(TRIM(REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')))=UPPER(TRIM(REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(inv.codigo_Ventas), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')))
		where pe.swObjectType='CHANNEL_PARTNER'
		--and pe.swEstado="Activo"
	), canxeqxag as (
		select distinct
		inv.tipo_canal_ds,
		inv.canal_edw_ds,
		inv.subcanal_edw_ds,
		inv.codigo_canal_asociado, 
		inv.equipo_edw_ds,
		ag.swPersonalId, 
		ag.agente,
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
	) select distinct 
		cn2.canal_agrupado2_id,
		cn2.canal_agrupado2_ds,
		cn1.canal_agrupado1_id,
		cn1.canal_agrupado1_ds,
		s.subcanal_id,
		s.subcanal_ds,
		m.codigo_canal_asociado as canal_id,
		m.equipo_edw_ds as equipo_ds,
		m.codigo_ventas as agente_alta_id,		

		struct (
			cap.swChnlPartnerId as id,  
			cap.swCoInterno as nombre,
			cap.swVerticalFocus as descripcion,
			cap.swStatus as estado,
			EXTRACT(DATE FROM cap.swDateCreated) as fechaCreacion,
			EXTRACT(DATE FROM cap.swStartDate) as fechaAlta,		
			EXTRACT(DATE FROM cap.swEndDate) as fechaBaja		
		)
		as distribuidor,   

		struct (
			m.codigo_canal_asociado as id,    
			ca.swCoInterno as nombre,
			ca.swVerticalFocus as descripcion,
			ca.swStatus as estado,
			EXTRACT(DATE FROM ca.swDateCreated) as fechaCreacion,
			EXTRACT(DATE FROM ca.swStartDate) as fechaAlta,		
			EXTRACT(DATE FROM ca.swEndDate) as fechaBaja		

		) as canal_asociado,

		struct (
			ca.swChnlPartnerId as id,  
			ca.swCoInterno as nombre,
			ca.swVerticalFocus as descripcion,
			ca.swStatus as estado,
			EXTRACT(DATE FROM ca.swDateCreated) as fechaCreacion,
			EXTRACT(DATE FROM ca.swStartDate) as fechaAlta,		
			EXTRACT(DATE FROM ca.swEndDate) as fechaBaja,		
			m.equipo_edw_ds as param_ctx
			--- Cuando el canal de ventas es PUNTO DE VENTA, se importa como equipo el codigo del agente de ventas parametrizado en contextual   
			--case when cn1.canal_agrupado1_ds="PUNTO DE VENTA" THEN m.codigo_ventas 
			--		when cn1.canal_agrupado1_ds="TASK FORCE" THEN m.codigo_ventas 
			--		when cn1.canal_agrupado1_ds="TELEVENTAS" THEN m.codigo_ventas        
			--ELSE ca.swCoInterno 
			--END AS funcion
		
		)	as equipo, 
		m.agente


	from canxeqxag_un m
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca on ca.swChnlPartnerId=m.codigo_canal_asociado 
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` cap on cap.swChnlPartnerId=ca.swChnlPartnerCtralId 
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` cn1 on UPPER(TRIM(cn1.canal_agrupado1_ds))=UPPER(TRIM(m.canal_edw_ds))
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` cn2 on UPPER(TRIM(cn2.canal_agrupado2_ds))=UPPER(TRIM(m.tipo_canal_ds))
	left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` s on UPPER(TRIM(s.subcanal_ds))=UPPER(TRIM(m.subcanal_edw_ds))
	where ca.swStatus<>'Excliente' 
	and ca.swChnlPartnerId <> 91
	--and m.swestadoAgente ="Activo"
	order by 2,4,6,8,9 asc;


END