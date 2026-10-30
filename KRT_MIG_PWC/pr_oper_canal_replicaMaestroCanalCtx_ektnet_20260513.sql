BEGIN


		--- PASO 1: CREO TABLA  tr_crm_ektnet_canal_asociado
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado` AS 
		with recursive rec as (	
			select 
			cl.mmMarcaId,CASE m.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' ELSE CASE WHEN m.mmMarcaId=7 THEN 'R'  WHEN m.mmMarcaId=1 THEN 'VIVA MOBILE' END END mmMarcaDesc,
			ca.swChnlPartnerId as id, 1 as lvl, ca.swChnlPartnerId as root, 
			ca.swCustomerId,cl.swName as swNameCl/*cl.swApellido,*/,cl.swAsociacion,/*cl.swCodigoAsociado, cl.swColaborador,*/ cl.swSegmento,cl.swSegmento2, /*cl.swSubSegmentoMkt,*/ 
			ca.swStatus as swStatusRoot, ca.swStartDate as swStartDateRoot, ca.swEndDate as swEndDateRoot, ca.swStatus, ca.swStartDate, ca.swEndDate, 
			ca.swChnlPartnerId, ca.swChnlPartnerCtralId, ca.swCustomerId as swCustomerIdCa, ca.swType, ca.swCoInterno, ca.swName, ca.swNIE, 
			cl.swChnlPartnerId as swChnlPartnerCl, ca.swIntegraSAP, ca.swCodSAPSolic, ca.swCodSAPAcre, 
			mnpTipoDistribuidor, swVerticalFocus, swIndLiqComision, swCodSAPDesti, swCanalContratacion, swCanalContratacion_esES,
			CASE WHEN cl.swName=ca.swName THEN 1 ELSE 0 END as bSwNameCl_Ca,	
			CASE WHEN pe.swPersonalId is not null THEN 1 ELSE 0 END as bSwPersonalId,
			count(distinct if(pe.swPersonalId is not NULL, pe.swPersonalId,NULL)) over(partition by cl.mmMarcaId, ca.swChnlPartnerId) as nag_dist, 			
			from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swcustomerId=ca.swCustomerId
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId 
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swObjectId = ca.swChnlPartnerId and pe.swEstado="Activo"
			where swChnlPartnerCtralId is null
			--order by swChnlPartnerId asc
			union all 
			select r.mmMarcaId, r.mmMarcaDesc,	
			rh.swChnlPartnerId as id, r.lvl+1 as lvl,r.root ,
			r.swCustomerId, r.swNameCl/*cl.swApellido,*/,r.swAsociacion,/*cl.swCodigoAsociado, cl.swColaborador,*/ r.swSegmento,r.swSegmento2, /*cl.swSubSegmentoMkt,*/ 
			r.swStatusRoot,r.swStartDateRoot, r.swEndDateRoot, rh.swStatus,rh.swStartDate, rh.swEndDate, 
			rh.swChnlPartnerId, rh.swChnlPartnerCtralId, rh.swCustomerId, rh.swType, rh.swCoInterno, rh.swName, rh.swNIE,
			--rh.swChnlPartnerCtralId, 
			r.swChnlPartnerCl, rh.swIntegraSAP, rh.swCodSAPSolic, rh.swCodSAPAcre, 
			rh.mnpTipoDistribuidor, rh.swVerticalFocus, rh.swIndLiqComision, rh.swCodSAPDesti, rh.swCanalContratacion, rh.swCanalContratacion_esES ,
			CASE WHEN r.swName=rh.swName THEN 1 ELSE 0 END as bSwNameCl_Ca,
			CASE WHEN pe.swPersonalId is not null THEN 1 ELSE 0 END as bSwPersonalId,
			r.nag_dist 			
			from rec r
			inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` rh on rh.swChnlPartnerCtralId=r.swChnlPartnerId
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swObjectId = rh.swChnlPartnerId 			
		), vag as (
			select pe.swObjectId as swChnlPartnerId, ARRAY_TO_STRING(ARRAY_AGG(distinct pe.swNombre order by pe.swNombre),"," ) as vag  
			from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
			Where pe.swEstado="Activo"
			group by 1
			order by 1 asc
		)
	
		select distinct p.*, 
		ARRAY_LENGTH(SPLIT(vag.vag,",")) as nag_eq,
		vag.vag, 		
		c2.canal_agrupado2_ds as ctx_canal_agrupado2_ds,
		c1.canal_agrupado1_ds as ctx_canal_agrupado1_ds,
		sc.subcanal_ds as ctx_subcanal_ds,
		p.swNameCl as nombre_distribuidor_alta_ds,
		can_vb.channel_id,
		can_vb.ch_segment_id,		
		
		
		/* Campo adicional si se quiere inte
		CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN pe.swNombre ELSE p.swVerticalFocus END ctx_nombre_distribuidor_alta_ds,		
		*/
		--count(distinct if(pe.swPersonalId is not NULL, pe.swPersonalId,NULL)) over(partition by P.mmMarcaId, p.id) as nag_eq, 

		from rec as p    
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swObjectId = p.swChnlPartnerId and pe.swEstado="Activo"
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c ON c.canal_id = p.swChnlPartnerId 
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON c.canal_agrupado1_id = c1.canal_agrupado1_id 
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON c.canal_agrupado2_id = c2.canal_agrupado2_id 
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON c.subcanal_id = sc.subcanal_id 
		left join vag ON vag.swChnlPartnerId = p.swChnlPartnerId
		left join `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_EKTNET` can_vb ON can_vb.brand_ds=p.mmMarcaDesc and can_vb.vertical_focus=p.swCoInterno
		order by 5 asc, 4 asc, 3 asc;
		

		--- PASO 2: CREO TABLA  tr_crm_ektnet_canal_asociado

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado_ctx_kd_optico` AS 
		 select * from  `mm-commissions-reporting.KRT_MIG_PWC.f_vt_audit_canalizacion_ektnet_ctx_kd_optico`();

END