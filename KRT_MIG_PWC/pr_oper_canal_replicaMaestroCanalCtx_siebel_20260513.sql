BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` AS
  select 
  sfid_id as  agente_venta_id,
  channel_ds as   canal_agrupado1_ds,  
  CASE WHEN contains_substr(channel_ds, "TASK") or contains_substr(channel_ds, "PUNTO DE VENTA")  or contains_substr(channel_ds, "CANALES ALTERNATIVO") THEN "PRESENCIAL" ELSE "NO PRESENCIAL" END  canal_Agrupado2_ds,    
  distributor_ds  distribuidor_ds,  
  subchannel_ds  subcanal_ds,
  vertical_focus_ds  equipo_ds
  from `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL`;




  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal_siebel_agente_login` AS
  with s as (
      ---- login en siebel
      select e.row_id, TRIM(UPPER(u.LOGIN)) as login, j.agente_venta_id, TRIM(e.ATTRIB_09) as estado,EXTRACT(DATE FROM e.CREATED) as fecha_creacion, u.USER_FLG as login_flag, u.TRNG_DL_ADMIN_FLG as login_admin_flag, CAST(NULL AS STRING) as tenderete_profile, "SIEBEL" as origen,
			
			count(distinct u.login) over(partition by agente_venta_id) as nlogin,
			count(distinct j.agente_venta_id) over(partition by u.login) as nav,
      from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u on e.row_id= u.row_id 
      inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j on TRIM(CAST(j.agente_venta_id  AS STRING))=TRIM(e.ATTRIB_07) 
      where e.attrib_07 is not null
      order by j.agente_venta_id asc , login  asc
  )
	select coalesce(s.login,"NOINF") as login, 
	m.* ,
	s.nlogin,
	s.nav,

			concat(m.canal_agrupado1_ds,"_",m.subcanal_ds,"_",m.distribuidor_ds) as sfid,
			LENGTH(CAST(agente_venta_id AS STRING)) as dim,
			CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN CONCAT("0",LEFT(CAST(agente_venta_id AS STRING),1)) 
				 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN LEFT(CAST(agente_venta_id AS STRING),2) 
			END as codCa,
			CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN RIGHT(LEFT(CAST(agente_venta_id AS STRING),4),3 )
				 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN RIGHT(LEFT(CAST(agente_venta_id AS STRING),5),3 )
			END as codDi,
			CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN RIGHT(CAST(agente_venta_id AS STRING),3)
				 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN RIGHT(CAST(agente_venta_id AS STRING),3)
			END as codAg,	
			--TRIM(e.ATTRIB_42) as grupoGenerico,      
			d.CIF,
			case when d.CIF is not null Then 1 else 0 END as bdist,
			CAST(1 as INT64) as bExisteSiebel,			---- modificado						
			case when (count(e.ATTRIB_09)=0 or (count(e.ATTRIB_09)>0 and count(e.ATTRIB_09)!=count(if(e.ATTRIB_09="Y",ATTRIB_09, NULL)) )) then 1 else 0 END as bactivo,			---- modificado
			
			ARRAY_AGG(u.login IGNORE NULLS)as vlogin,
			ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS) vATTRIB_09,
			ARRAY_AGG(coalesce(e.ATTRIB_10,'NA') IGNORE NULLS) as vATTRIB_10,

			ARRAY_TO_STRING(ARRAY_AGG(u.login IGNORE NULLS),'/') as vslogin,
			ARRAY_TO_STRING(ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS),'/') as vsATTRIB_09,
			ARRAY_TO_STRING(ARRAY_AGG(coalesce(e.ATTRIB_10,'NA') IGNORE NULLS),'/') as vsATTRIB_10,
			
			count(e.ATTRIB_09) as nreg_nonulo,
			count(if(e.ATTRIB_09="Y",ATTRIB_09, NULL)) as nbaja_y, 
			count(if(e.ATTRIB_09="N",ATTRIB_09, NULL)) as nbaja_n,
			--e.ATTRIB_42 as grupo, e.ATTRIB_37 as tipo

	from	 `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` m
	left join s using(agente_venta_id)
	--inner join rdup using(equipo_ds, distribuidor_ds)
	--left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`  e on TRIM(e.ATTRIB_07)=TRIM(CAST(m.agente_venta_id  AS STRING))
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`  e on TRIM(e.ATTRIB_07)=TRIM(CAST(m.agente_venta_id  AS STRING)) 
	left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d on TRIM(d.nombre_distribuidor)=TRIM(m.distribuidor_ds) and d.marca="R"	
	left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user`  u on u.row_id=e.row_id
	group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
	order by 5,4,6;



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_siebel_agente_login` AS
  with m as (
    with s as (
      ---- login en siebel
      select e.row_id, TRIM(UPPER(u.LOGIN)) as login, j.agente_venta_id, TRIM(e.ATTRIB_09) as estado,EXTRACT(DATE FROM e.CREATED) as fecha_creacion, u.USER_FLG as login_flag, u.TRNG_DL_ADMIN_FLG as login_admin_flag, CAST(NULL AS STRING) as tenderete_profile, "SIEBEL" as origen
      from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u on e.row_id= u.row_id 
      inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j on TRIM(CAST(j.agente_venta_id  AS STRING))=TRIM(e.ATTRIB_07) 
      where e.attrib_07 is not null
      order by j.agente_venta_id asc , login  asc
    ), t as (
      ---- login en tenderete y no en siebel      
      select e.row_id,UPPER(TRIM(u.user_)) as login, j.agente_venta_id, e.ATTRIB_09 as estado,EXTRACT(DATE FROM e.CREATED) as fecha_creacion, CAST(NULL AS STRING) as login_flag, CAST(NULL AS STRING) as login_admin_flag, p.Profile_name as tenderete_profile, "TENDERETE" as origen
      from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_users` u on TRIM(UPPER(e.row_id))= TRIM(UPPER(u.idsiebel)) 
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_profiles` p on p.id_profile= u.id_profile
      inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j on TRIM(CAST(j.agente_venta_id  AS STRING))=TRIM(e.ATTRIB_07) 
      where e.attrib_07 is not null
      and not exists (
          select 1
          from (
            select j.agente_venta_id, TRIM(UPPER(u.LOGIN)) as login  from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
            inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u on e.row_id= u.row_id 
            inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j on TRIM(CAST(j.agente_venta_id  AS STRING))=TRIM(e.ATTRIB_07) 
            where e.attrib_07 is not null
          ) t
          where t.agente_venta_id=j.agente_venta_id and UPPER(TRIM(u.user_))=t.login
      )
      order by j.agente_venta_id asc , u.user_ asc
    ) select distinct *
    from s
    union all 
    select distinct *
    from t
  ) select distinct m.*, ROW_NUMBER() over( partition by login order by origen asc, fecha_creacion desc) as orden
  from m
  --where m.login="RFVSTAND.1"
  order by 2 asc, 3 asc;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_tenderete_login` AS
  select distinct e.row_id,UPPER(TRIM(u.user_)) as login,UPPER(TRIM(u2.LOGIN)) as login_si, j.agente_venta_id as agente_venta_id_si, e.ATTRIB_09 as estado_si,EXTRACT(DATE FROM e.CREATED) as fecha_creacion_si, 
  p.Profile_name as profile,  
  u.* except(user_, password, id_profile,idsiebel,id_admin_profile),
  from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
  inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_users` u on TRIM(UPPER(e.row_id))= TRIM(UPPER(u.idsiebel)) 
  left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_profiles` p on p.id_profile= u.id_profile
  left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u2 on e.row_id= u2.row_id 
  inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j on TRIM(CAST(j.agente_venta_id  AS STRING))=TRIM(e.ATTRIB_07); 



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal_mm` AS
  select distinct
	"SIEBEL" as crm,
	CAST(NULL AS INT64) as canal_Agrupado2_id,
  CASE WHEN contains_substr(j.channel_ds, "TASK") or contains_substr(j.channel_ds, "PUNTO DE VENTA")  or contains_substr(j.channel_ds, "CANALES ALTERNATIVO") THEN "PRESENCIAL" ELSE  "NO PRESENCIAL" END  canal_Agrupado2_ds,    
  CAST(NULL AS INT64) as canal_Agrupado1_id,
	j.channel_ds as   canal_agrupado1_ds,  	
  CAST(NULL AS INT64) as subcanal_id,
  j.subchannel_ds  subcanal_ds,  
  CAST(NULL AS INT64) as canal_id,	
  j.vertical_focus_ds  equipo_ds,
	CAST(j.sfid_id AS STRING) as  agente_venta_id,


  STRUCT (
    CAST(NULL AS INT64) as id,  
    j.distributor_ds as ds,
    CAST(NULL AS STRING) as descripcion,
    CAST(NULL AS STRING) as estado,
    CAST(NULL AS DATE) as fechaCreacion,
    CAST(NULL AS DATE) as fechaAlta,    
    CAST(NULL AS DATE) as fechaBaja   
  ) as distribuidor,   

  STRUCT (
    CAST(NULL AS INT64) as id,    
    j.vertical_focus_ds as ds,
    j.vertical_focus_ds as descripcion,
    CAST(NULL AS STRING) as estado,
    CAST(NULL AS DATE) as fechaCreacion,
    CAST(NULL AS DATE) as fechaAlta,    
    CAST(NULL AS DATE) as fechaBaja   
  ) as canal_asociado,

  STRUCT (
    CAST(NULL AS INT64) as id,  
    j.vertical_focus_ds as ds,
    j.vertical_focus_ds as descripcion,
    CAST(NULL AS STRING) as estado,
    CAST(NULL AS DATE) as fechaCreacion,
    CAST(NULL AS DATE) as fechaAlta,    
    CAST(NULL AS DATE) as fechaBaja,   
		CAST(NULL AS STRING) as param_ctx
  ) as equipo, 
  
  STRUCT (
    CAST(NULL AS INT64) as id,
    CAST(j.sfid_id  AS STRING) as ds,
    CAST(NULL AS STRING) as estado,
    CAST(NULL AS DATE) as fechaCreacion,
    CAST(NULL AS DATE) as fechaAlta,   
    CAST(NULL AS DATE) as fechaBaja
  ) as agente,

  STRUCT(
      CASE WHEN contains_substr(j.channel_ds, "TASK") or contains_substr(j.channel_ds, "PUNTO DE VENTA")  or contains_substr(j.channel_ds, "CANALES ALTERNATIVO") THEN "PRESENCIAL" ELSE  "NO PRESENCIAL" END as tipo_canal_ds,
    j.channel_ds  as canal_ds,
    j.subchannel_ds as subcanal_ds,
    j.distributor_ds as distribuidor_ds,
    j.vertical_focus_ds as equipo_ds,
    CAST(j.sfid_id  AS STRING) as agente_venta_id,
    CAST(j.sfid_id  AS STRING) as sfid        
  ) as ct,
    
  STRUCT(
    c.channel_type_ds ,
    c.master_channel_ds,
    c.superchannel_ds,
    c.channel_ds,
    c.subchannel_ds,         -- Se mantiene tu naming solicitado 'subchanel'
    j.distributor_ds as distribuidor_ds,
    CAST(j.sfid_id  AS STRING) as sfid,        
    CAST(NULL AS INT64) AS channel_id,
    s.channel_segment_ds as channel_segment_ds
  ) AS mm

  from `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL` j
  left join `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CHANNEL` c using (channel_id)
  LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CH_SEGMENT` s  ON s.ch_segment_id=j.ch_segment_id;



		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_JERARQUIA_COMERCIAL_SIEBEL` as
		select m.canal_agrupado1_ds, m.canal_agrupado2_ds, m.subcanal_ds,  m.distribuidor_ds,m.equipo_ds,m.agente_venta_id, m.agente_venta_id as codigo_comercial,  
		concat(m.canal_agrupado1_ds,"_",m.subcanal_ds,"_",m.distribuidor_ds) as sfid,
		LENGTH(CAST(agente_venta_id AS STRING)) as dim,
		CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN CONCAT("0",LEFT(CAST(agente_venta_id AS STRING),1)) 
			 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN LEFT(CAST(agente_venta_id AS STRING),2) 
		END as codCa,
		CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN RIGHT(LEFT(CAST(agente_venta_id AS STRING),4),3 )
			 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN RIGHT(LEFT(CAST(agente_venta_id AS STRING),5),3 )
		END as codDi,
		CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN RIGHT(CAST(agente_venta_id AS STRING),3)
			 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN RIGHT(CAST(agente_venta_id AS STRING),3)
		END as codAg,	
		--TRIM(e.ATTRIB_42) as grupoGenerico,      
		d.CIF,
		case when d.CIF is not null Then 1 else 0 END as bdist,
		CAST(1 as INT64) as bExisteSiebel,		---- modificado					
		case when (count(e.ATTRIB_09)=0 or (count(e.ATTRIB_09)>0 and count(e.ATTRIB_09)!=count(if(e.ATTRIB_09="Y",ATTRIB_09, NULL)) )) then 1 else 0 END as bactivo,		---- modificado
		
		ARRAY_AGG(u.login IGNORE NULLS)as vlogin,
		ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS) vATTRIB_09,
		ARRAY_AGG(coalesce(e.ATTRIB_10,'NA') IGNORE NULLS) as vATTRIB_10,

		ARRAY_TO_STRING(ARRAY_AGG(u.login IGNORE NULLS),'/') as vslogin,
		ARRAY_TO_STRING(ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS),'/') as vsATTRIB_09,
		ARRAY_TO_STRING(ARRAY_AGG(coalesce(e.ATTRIB_10,'NA') IGNORE NULLS),'/') as vsATTRIB_10,
		
		count(e.ATTRIB_09) as nreg_nonulo,
		count(if(e.ATTRIB_09="Y",ATTRIB_09, NULL)) as nbaja_y, 
		count(if(e.ATTRIB_09="N",ATTRIB_09, NULL)) as nbaja_n,
		--e.ATTRIB_42 as grupo, e.ATTRIB_37 as tipo
		--from `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` m
		from `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` m		
		--inner join rdup using(equipo_ds, distribuidor_ds)
		--left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`  e on TRIM(e.ATTRIB_07)=TRIM(CAST(m.agente_venta_id  AS STRING))
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`  e on TRIM(e.ATTRIB_07)=TRIM(CAST(m.agente_venta_id  AS STRING)) 
		--left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_DISTRIBUIDORES` d on TRIM(d.nombre_distribuidor)=TRIM(m.distribuidor_ds) and d.marca="R"	
		left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d on TRIM(d.nombre_distribuidor)=TRIM(m.distribuidor_ds) and d.marca="R"			
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user`  u on u.row_id=e.row_id
		group by 1,2,3,4,5,6,7,8,9,10,11,12,13
		order by 5,4,6;

			


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AUDIT_JERARQUIA_COMERCIAL_SIEBEL`
		with cand as (
				select m.canal_agrupado1_ds, m.canal_agrupado2_ds, m.subcanal_ds,  m.distribuidor_ds,m.equipo_ds,m.agente_venta_id, m.agente_venta_id as codigo_comercial, 
				concat(m.canal_agrupado1_ds,"_",m.subcanal_ds,"_",m.distribuidor_ds) as sfid,
				LENGTH(CAST(agente_venta_id AS STRING)) as dim,
				CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN CONCAT("0",LEFT(CAST(agente_venta_id AS STRING),1)) 
					 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN LEFT(CAST(agente_venta_id AS STRING),2) 
				END as codCa,
				CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN RIGHT(LEFT(CAST(agente_venta_id AS STRING),4),3 )
					 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN RIGHT(LEFT(CAST(agente_venta_id AS STRING),5),3 )
				END as codDi,
				CASE WHEN LENGTH(CAST(agente_venta_id AS STRING))=7 THEN RIGHT(CAST(agente_venta_id AS STRING),3)
					 WHEN LENGTH(CAST(agente_venta_id AS STRING))=8 THEN RIGHT(CAST(agente_venta_id AS STRING),3)
				END as codAg,	
				--TRIM(e.ATTRIB_42) as grupoGenerico,      
				d.CIF,
				case when d.CIF is not null Then 1 else 0 END as bdist,
				CAST(1 as INT64) as bExisteSiebel,			---- modificado						
				case when (count(e.ATTRIB_09)=0 or (count(e.ATTRIB_09)>0 and count(e.ATTRIB_09)!=count(if(e.ATTRIB_09="Y",ATTRIB_09, NULL)) )) then 1 else 0 END as bactivo,			---- modificado
				
				ARRAY_AGG(u.login IGNORE NULLS)as vlogin,
				ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS) vATTRIB_09,
				ARRAY_AGG(coalesce(e.ATTRIB_10,'NA') IGNORE NULLS) as vATTRIB_10,

				ARRAY_TO_STRING(ARRAY_AGG(u.login IGNORE NULLS),'/') as vslogin,
				ARRAY_TO_STRING(ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS),'/') as vsATTRIB_09,
				ARRAY_TO_STRING(ARRAY_AGG(coalesce(e.ATTRIB_10,'NA') IGNORE NULLS),'/') as vsATTRIB_10,


				count(e.ATTRIB_09) as nreg_nonulo,
				count(if(e.ATTRIB_09="Y",ATTRIB_09, NULL)) as nbaja_y, 
				count(if(e.ATTRIB_09="N",ATTRIB_09, NULL)) as nbaja_n,
				--e.ATTRIB_42 as grupo, e.ATTRIB_37 as tipo
--				from `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` m
				from `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` m
				--inner join rdup using(equipo_ds, distribuidor_ds)
				--left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`  e on TRIM(e.ATTRIB_07)=TRIM(CAST(m.agente_venta_id  AS STRING))
				left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`  e on TRIM(e.ATTRIB_07)=TRIM(CAST(m.agente_venta_id  AS STRING)) 
				--left join `mm-commissions-reporting.GS.TRADUCTOR_KRT_DISTRIBUIDORES` d on TRIM(d.nombre_distribuidor)=TRIM(m.distribuidor_ds) and d.marca="R"	
				left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d on TRIM(d.nombre_distribuidor)=TRIM(m.distribuidor_ds) and d.marca="R"					
				left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user`  u on u.row_id=e.row_id
				group by 1,2,3,4,5,6,7,8,9,10,11,12,13
				order by 5,4,6 

		) select cand.*
		from cand 
		where not exists (
				select 1
				from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_JERARQUIA_COMERCIAL_SIEBEL` s
				where cand.agente_venta_id=s.agente_venta_id		
		)			
		order by 5,4,6;


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_JERARQUIA_COMERCIAL_SIEBEL` as 
		select * , count(distinct sfid) over(PARTITION BY distribuidor_ds, equipo_ds ) as nsfid
		from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_JERARQUIA_COMERCIAL_SIEBEL`;


END