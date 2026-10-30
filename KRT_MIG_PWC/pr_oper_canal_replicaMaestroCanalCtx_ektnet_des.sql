BEGIN

    --- PASO 1: CREO TABLA tr_crm_ektnet_canal_asociado
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado` AS 
    WITH recursive rec as ( 
      SELECT 
        cl.mmMarcaId,
        CASE UPPER(TRIM(m.mmMarcaDesc))  
            WHEN 'EUSKALTEL' THEN 'EUSKALTEL' 
            WHEN 'VIRGIN TELCO' THEN 'VIRGIN' 
            WHEN 'RACCTEL+' THEN 'RACC' 
            WHEN 'TELECABLE' THEN 'TELECABLE' 
            ELSE CASE WHEN m.mmMarcaId=7 THEN 'R' WHEN m.mmMarcaId=1 THEN 'VIVA MOBILE' END 
        END AS mmMarcaDesc,
        ca.swChnlPartnerId as id, 1 as lvl, ca.swChnlPartnerId as root, 
        ca.swCustomerId, cl.swName as swNameCl, cl.swAsociacion, cl.swSegmento, cl.swSegmento2,
        ca.swStatus as swStatusRoot, ca.swStartDate as swStartDateRoot, ca.swEndDate as swEndDateRoot, 
        ca.swStatus, ca.swStartDate, ca.swEndDate, ca.swChnlPartnerId, ca.swChnlPartnerCtralId, 
        ca.swCustomerId as swCustomerIdCa, ca.swType, ca.swCoInterno, ca.swName, ca.swNIE, 
        cl.swChnlPartnerId as swChnlPartnerCl, ca.swIntegraSAP, ca.swCodSAPSolic, ca.swCodSAPAcre, 
        mnpTipoDistribuidor, swVerticalFocus, swIndLiqComision, swCodSAPDesti, swCanalContratacion, swCanalContratacion_esES,
        CASE WHEN cl.swName=ca.swName THEN 1 ELSE 0 END as bSwNameCl_Ca,  
        CASE WHEN pe.swPersonalId is not null THEN 1 ELSE 0 END as bSwPersonalId,
        COUNT(DISTINCT pe.swPersonalId) OVER(PARTITION BY cl.mmMarcaId, ca.swChnlPartnerId) as nag_dist       
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swcustomerId=ca.swCustomerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId 
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swObjectId = ca.swChnlPartnerId and pe.swEstado="Activo"
      WHERE swChnlPartnerCtralId is null
      
      UNION ALL 
      
      SELECT 
        r.mmMarcaId, r.mmMarcaDesc,  
        rh.swChnlPartnerId as id, r.lvl+1 as lvl, r.root,
        r.swCustomerId, r.swNameCl, r.swAsociacion, r.swSegmento, r.swSegmento2,
        r.swStatusRoot, r.swStartDateRoot, r.swEndDateRoot, rh.swStatus, rh.swStartDate, rh.swEndDate, 
        rh.swChnlPartnerId, rh.swChnlPartnerCtralId, rh.swCustomerId, rh.swType, rh.swCoInterno, rh.swName, rh.swNIE,
        r.swChnlPartnerCl, rh.swIntegraSAP, rh.swCodSAPSolic, rh.swCodSAPAcre, 
        rh.mnpTipoDistribuidor, rh.swVerticalFocus, rh.swIndLiqComision, rh.swCodSAPDesti, rh.swCanalContratacion, rh.swCanalContratacion_esES ,
        CASE WHEN r.swName=rh.swName THEN 1 ELSE 0 END as bSwNameCl_Ca,
        CASE WHEN pe.swPersonalId is not null THEN 1 ELSE 0 END as bSwPersonalId,
        r.nag_dist       
      FROM rec r
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` rh on rh.swChnlPartnerCtralId=r.swChnlPartnerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swObjectId = rh.swChnlPartnerId       
    ), 
    vag as (
      SELECT 
        pe.swObjectId as swChnlPartnerId, 
        STRING_AGG(DISTINCT pe.swNombre, ",") as vag,
        COUNT(DISTINCT pe.swNombre) as nag_eq
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
      WHERE pe.swEstado="Activo"
      GROUP BY 1
    )
  
    SELECT DISTINCT 
      p.*, 
      COALESCE(vag.nag_eq, 0) as nag_eq,
      vag.vag,    
      c2.canal_agrupado2_ds as ctx_canal_agrupado2_ds,
      c1.canal_agrupado1_ds as ctx_canal_agrupado1_ds,
      sc.subcanal_ds as ctx_subcanal_ds,
      p.swNameCl as nombre_distribuidor_alta_ds,
      can_vb.channel_id,
      can_vb.ch_segment_id
    FROM rec as p    
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swObjectId = p.swChnlPartnerId and pe.swEstado="Activo"
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c ON c.canal_id = p.swChnlPartnerId 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON c.canal_agrupado1_id = c1.canal_agrupado1_id 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON c.canal_agrupado2_id = c2.canal_agrupado2_id 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON c.subcanal_id = sc.subcanal_id 
    LEFT JOIN vag ON vag.swChnlPartnerId = p.swChnlPartnerId
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_EKTNET` can_vb ON can_vb.brand_ds=p.mmMarcaDesc and can_vb.vertical_focus=p.swCoInterno;
    

    --- PASO 2: CREO TABLA tr_crm_ektnet_canal_asociado_ctx_kd_optico
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado_ctx_kd_optico` AS 
    WITH base_marcas AS (
      SELECT 
        c.*,
        UPPER(CASE UPPER(TRIM(m.mmMarcaDesc))  
            WHEN 'EUSKALTEL' THEN 'EUSKALTEL'  
            WHEN 'VIRGIN TELCO' THEN 'VIRGIN'  
            WHEN 'RACCTEL+' THEN 'RACC'  
            WHEN 'TELECABLE' THEN 'TELECABLE' 
            WHEN 'R' THEN 'R' 
        END) AS calc_marca
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=c.swCustomerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId
    )

    SELECT DISTINCT 
      STRUCT(
        c.swChnlPartnerId, c.swCustomerId, c.swStartDate, c.swEndDate, c.swRegion,
        c.swStatus, c.swType, c.swCoInterno, c.swProdReleaseId, c.swName, c.swNIE,
        c.swChnlPartnerCtralId,ca.nombre_distribuidor_alta_ds AS nombre_distribuidor_ds,  
        c.swIntegraSAP, c.swExpertise, c.swCodSAPSolic,
        c.swCodSAPAcre, c.mnpTipoDistribuidor, c.swVerticalFocus, c.swIndLiqComision,
        c.swCodSAPDesti, c.swSaldoRecarga, c.swContactId, c.swCommPref, c.swRegionId,
        c.swAcctMgrId, c.swRating, c.swCreatedBy, c.swDateCreated, c.swPagoUnico,
        c.swDireccionEmail, c.swCanalContratacion, c.swCanalContratacion_esES,
        c.calc_marca AS marca  
      ) AS crm,
      
      STRUCT(
        mc.canal_id, mc.canal_agrupado2_id, mc.canal_agrupado1_id, mc.subcanal_id,
        c2.canal_agrupado2_ds AS tipo_canal_ds,     
        c1.canal_agrupado1_ds AS canal_ds, 
        sc.subcanal_ds AS subcanal_ds
      ) AS ctx,
      
      STRUCT(
        kdch.channel_type_ds, kdch.master_channel_ds, kdch.superchannel_ds,
        kdch.channel_ds, kdch.subchannel_ds,
        kdek.brand_ds, kdek.vertical_focus, kdch.channel_id, kdek.ch_segment_id,
        kdsg.channel_segment_ds
      ) AS kd,
      
      STRUCT(
        op.key, CAST(op.canal_id AS INT64) as canal_id, op.canal, op.subcanal, op.distribuidor,
        op.sfid, op.tipo_pdv, op.baja, op.pdv_sfid
      ) AS optico 

    FROM base_marcas c
    -- Eliminado: LEFT JOIN a la tabla 'jd' ya que no se consumía en el SELECT
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_EKTNET` kdek 
        ON kdek.vertical_focus = c.swCoInterno AND kdek.brand_ds = c.calc_marca
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CHANNEL` kdch 
        ON kdch.channel_id = kdek.channel_id
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CH_SEGMENT` kdsg 
        ON kdsg.ch_segment_id = kdek.ch_segment_id 
    LEFT JOIN `mm-sales-reporting.TEMPORAL.k_optico_pdv` op 
        ON op.SFID = c.swCoInterno AND op.MARCA = c.calc_marca
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` mc  
        ON mc.canal_id = c.swChnlPartnerId
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado` ca 
        ON ca.swChnlPartnerId = c.swChnlPartnerId
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1  
        ON mc.canal_agrupado1_id = c1.canal_agrupado1_id
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2  
        ON mc.canal_agrupado2_id = c2.canal_agrupado2_id
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc  
        ON mc.subcanal_id = sc.subcanal_id;


    --- PASO 3: CREO TABLA tr_crm_ektnet_canalizacion_ct_mm
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm` AS
    SELECT 
        "EKTNET" as crm,
        e.crm.marca as marca_ds,
        -- Mantenemos todos los campos originales de tr_t_30_maestro_canal
        e.ctx.canal_agrupado2_id,
        e.ctx.tipo_canal_ds as canal_agrupado2_ds,
        e.ctx.canal_agrupado1_id,
        e.ctx.canal_ds as canal_agrupado1_ds,
        e.ctx.subcanal_id,
        e.ctx.subcanal_ds,
        e.crm.swChnlPartnerId as canal_id,
        e.crm.swCoInterno as equipo_ds,
        CAST(NULL as STRING) as agente_venta_id,      

        STRUCT(
            e.crm.swChnlPartnerCtralId as id, 
            e.crm.nombre_distribuidor_ds as ds, 
            CAST(NULL as STRING) as descripcion, 
            CAST(NULL as STRING) as estado, 
            CAST(NULL as DATE) as fechaCreacion, 
            CAST(NULL as DATE) as fechaAlta, 
            CAST(NULL as DATE) as fechaBaja
        ) as distribuidor,

        STRUCT(
            e.crm.swChnlPartnerId as id, 
            e.crm.swCoInterno as ds, 
            e.crm.swVerticalFocus as descripcion, 
            CAST(NULL as STRING) as estado, 
            EXTRACT(DATE FROM e.crm.swDateCreated) as fechaCreacion, 
            EXTRACT(DATE FROM e.crm.swStartDate)  as fechaAlta, 
            EXTRACT(DATE FROM e.crm.swEndDate) as fechaBaja
        ) as canal_asociado,

        STRUCT(
            e.crm.swChnlPartnerId as id, 
            e.crm.swCoInterno as ds, 
            e.crm.swVerticalFocus as descripcion, 
            CAST(NULL as STRING) as estado, 
            EXTRACT(DATE FROM e.crm.swDateCreated) as fechaCreacion, 
            EXTRACT(DATE FROM e.crm.swStartDate)  as fechaAlta, 
            EXTRACT(DATE FROM e.crm.swEndDate) as fechaBaja,
            CAST(NULL as STRING) as param_ctx  
        ) as equipo,

        STRUCT(
            CAST(NULL as INT64) as id, 
            CAST(NULL as STRING) as ds, 
            CAST(NULL as STRING) as estado, 
            CAST(NULL as DATE) as fechaCreacion, 
            CAST(NULL as DATE) as fechaAlta, 
            CAST(NULL as DATE) as fechaBaja
        ) as agente,
        STRUCT(
            e.ctx.tipo_canal_ds,
            e.ctx.canal_ds,
            e.ctx.subcanal_ds,
            e.crm.nombre_distribuidor_ds as distribuidor_ds,
            e.crm.swCoInterno as equipo_ds,
            CAST(NULL as STRING) as agente_venta_id,
            e.crm.swCoInterno as sfid        
        ) as ct,
        -- Creamos la estructura mm con los nuevos atributos descubiertos
        STRUCT(
            ch.channel_type_ds ,
            ch.master_channel_ds,
            ch.superchannel_ds,
            ch.channel_ds,
            ch.subchannel_ds,         -- Se mantiene tu naming solicitado 'subchanel'
            e.crm.nombre_distribuidor_ds as distribuidor_ds,
            e.crm.swCoInterno as sfid,
            ch.channel_id AS channel_id,
            seg.channel_segment_ds
        ) AS mm
    FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado_ctx_kd_optico` e
    -- Cruce con CHANNEL para recuperar los descriptivos del canal
    LEFT JOIN  `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CHANNEL` ch 
        ON ch.channel_id=e.kd.channel_id
    -- Cruce con SEGMENT para recuperar los descriptivos del segmento
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CH_SEGMENT` seg 
        ON seg.ch_segment_id= e.kd.ch_segment_id;


    --- PASO 4: CREO TABLA tr_crm_ektnet_canalizacion_ct_mo
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mo` AS 
    --OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    WITH sfid_k AS (
        ---- RELACIONES INFORMADAS EN LA PARAMETRIZACION DE EUSKALTEL
        SELECT 
          sfid_id, 
          channel_id, 
          CAST(NULL AS STRING) AS s_distributor, -- No usamos el distribuidor de ventas aquí
          'SALES' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_SALES_EUSKALTEL`
        --where sfid_id not like'%00000' and sfid_id not like '%EX'
        
        UNION ALL
        
        SELECT 
          sfid_id, 
          channel_id, 
          distribuidor AS s_distribuidor,          -- Sí usamos el distribuidor de operaciones
          'OPERATIONS' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_OPERATIONS_EUSKALTEL`
        --where sfid_id not like'%00000' and sfid_id not like '%EX'

        ---- RELACIONES INFORMADAS EN LA PARAMETRIZACION DE TELECABLE

        UNION ALL

        SELECT 
          sfid_id, 
          channel_id, 
          CAST(NULL AS STRING) AS s_distributor, -- No usamos el distribuidor de ventas aquí
          'SALES' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_SALES_TELECABLE`
        WHERE NOT REGEXP_CONTAINS(sfid_id, r'^[0-9]+-[0-9]+$')
        AND sfid_id NOT LIKE '%00000' AND sfid_id NOT LIKE '%EX'
      
        UNION ALL       
        
        SELECT 
          sfid_id, 
          channel_id, 
          distribuidor AS s_distributor, -- He unificado el alias
          'OPERATIONS' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_OPERATIONS_TELECABLE`
        WHERE NOT REGEXP_CONTAINS(sfid_id, r'^[0-9]+-[0-9]+$') 
        AND sfid_id NOT LIKE '%00000' AND sfid_id NOT LIKE '%EX'       

      ), sfid_k_uni as (
        select distinct *
        from sfid_k
        order by 1,2,3
      ), sfid_k_mo as (
        SELECT distinct origin_type,
        --mc.crm.marca as marca_ds,
        mc.marca_ds as marca_ds,
        c.N0,
        c.N1,
        c.N2,
        ac.nombre_acreedor,
        s.channel_id,
        s.sfid_id as sfid,
        from sfid_k_uni s 
        --left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado_ctx_kd_optico` mc on mc.crm.swCoInterno =s.sfid_id
        left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm` mc on mc.mm.sfid =s.sfid_id
        --left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` di on  di.marca=mc.crm.marca and di.nombre_distribuidor=mc.crm.nombre_distribuidor_ds
        left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` di on  di.marca=mc.marca_ds and di.nombre_distribuidor=mc.distribuidor.ds
        left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca =di.marca and ac.bp=di.bp
        --inner join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca in ("EUSKALTEL","RACC","SIMPLE","TELECABLE") and ac.codigo=left(s.sfid_id,3)
        left JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_CANALES` c ON c.channel_id = s.channel_id
        --LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_FUNCION_EQUIPO` fe ON fe.marca = ac.marca AND fe.N0 = c.N0 AND fe.N1 = c.N1 AND fe.N2 = c.N2 
        --where mc.crm.marca in("EUSKALTEL","RACC","SIMPLE","TELECABLE")
        --order by mc.crm.marca, c.N0, c.n1,c.n2
        order by mc.marca_ds, c.N0, c.n1,c.n2
      ) select distinct cmm.*, 
      STRUCT (
        sfid_k_mo.origin_type,
        sfid_k_mo.N0,
        sfid_k_mo.N1,
        sfid_k_mo.N2,
        sfid_k_mo.nombre_acreedor as nombre_acreedor_ds,
        sfid_k_mo.channel_id,
        sfid_k_mo.sfid as sfid                
      ) mo  
      from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm` cmm
      left join sfid_k_mo  on cmm.mm.sfid=sfid_k_mo.sfid and cmm.marca_ds=sfid_k_mo.marca_ds;


END