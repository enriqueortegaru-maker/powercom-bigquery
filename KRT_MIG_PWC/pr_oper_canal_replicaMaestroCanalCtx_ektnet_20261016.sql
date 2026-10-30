BEGIN

    --- PASO 1: CREO TABLA tr_crm_ektnet_canal_asociado
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado` AS 

    WITH RECURSIVE

    -- ── Pre-aggregate ci_personal_externo once (replaces both in-rec pe joins
    --    and the separate vag CTE). One row per swObjectId, Activo only.
    pe_agg AS (
      SELECT
        pe.swObjectId                              AS swChnlPartnerId,
        COUNT(DISTINCT pe.swPersonalId)            AS n_personal,   -- for nag_dist / bSwPersonalId
        COUNT(DISTINCT pe.swNombre)                AS nag_eq,
        STRING_AGG(DISTINCT pe.swNombre, ",")      AS vag
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
      WHERE pe.swEstado = "Activo"
      GROUP BY 1
    ),

    rec AS (

      -- ── ANCHOR: every genuinely unparented node is a root.
      --   Arm 1: no parent recorded           (original logic)
      --   Arm 2: self-referencing node        (FIX – covers 138, 23370, any future recurrence)
      --   Arm 3: orphan – parent id absent    (FIX – covers a future gap; 0 rows today)
      SELECT
        cl.mmMarcaId,
        CASE UPPER(TRIM(m.mmMarcaDesc))
            WHEN 'EUSKALTEL'    THEN 'EUSKALTEL'
            WHEN 'VIRGIN TELCO' THEN 'VIRGIN'
            WHEN 'RACCTEL+'     THEN 'RACC'
            WHEN 'TELECABLE'    THEN 'TELECABLE'
            ELSE CASE WHEN m.mmMarcaId = 7 THEN 'R'
                      WHEN m.mmMarcaId = 1 THEN 'VIVA MOBILE' END
        END                                                     AS mmMarcaDesc,
        ca.swChnlPartnerId                                      AS id,
        1                                                       AS lvl,
        ca.swChnlPartnerId                                      AS root,
        ca.swCustomerId,
        cl.swName                                               AS swNameCl,
        cl.swAsociacion,
        cl.swSegmento,
        cl.swSegmento2,
        ca.swStatus                                             AS swStatusRoot,
        ca.swStartDate                                          AS swStartDateRoot,
        ca.swEndDate                                            AS swEndDateRoot,
        ca.swStatus,
        ca.swStartDate,
        ca.swEndDate,
        ca.swChnlPartnerId,
        ca.swChnlPartnerCtralId,
        ca.swCustomerId                                         AS swCustomerIdCa,
        ca.swType,
        ca.swCoInterno,
        ca.swName,
        ca.swNIE,
        cl.swChnlPartnerId                                      AS swChnlPartnerCl,
        ca.swIntegraSAP,
        ca.swCodSAPSolic,
        ca.swCodSAPAcre,
        ca.mnpTipoDistribuidor,
        ca.swVerticalFocus,
        ca.swIndLiqComision,
        ca.swCodSAPDesti,
        ca.swCanalContratacion,
        ca.swCanalContratacion_esES,
        CASE WHEN cl.swName = ca.swName THEN 1 ELSE 0 END       AS bSwNameCl_Ca,
        -- bSwPersonalId / nag_dist from pre-aggregated pe_agg (no fan-out, Activo-consistent)
        CASE WHEN pa.swChnlPartnerId IS NOT NULL THEN 1 ELSE 0 END AS bSwPersonalId,
        COALESCE(pa.n_personal, 0)                              AS nag_dist,
        -- Internal cycle-guard: path carries visited ids; dropped from final SELECT
        [ca.swChnlPartnerId]                                    AS path
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente`     cl ON cl.swCustomerId = ca.swCustomerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas`   m  ON m.mmMarcaId = cl.mmMarcaId
      LEFT JOIN pe_agg pa ON pa.swChnlPartnerId = ca.swChnlPartnerId
      WHERE
          ca.swChnlPartnerCtralId IS NULL                          -- no parent recorded
        OR ca.swChnlPartnerCtralId = ca.swChnlPartnerId            -- self-referencing root (FIX)
        OR NOT EXISTS (                                             -- orphan – parent row absent (FIX)
            SELECT 1
            FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` p
            WHERE p.swChnlPartnerId = ca.swChnlPartnerCtralId
          )

      UNION ALL

      -- ── RECURSIVE MEMBER
      --   Cycle guard: rh.swChnlPartnerId NOT IN UNNEST(r.path)
      --   Handles self-loops (138→138) and multi-node cycles (A→B→A→…).
      SELECT
        r.mmMarcaId,
        r.mmMarcaDesc,
        rh.swChnlPartnerId                                      AS id,
        r.lvl + 1                                               AS lvl,
        r.root,
        r.swCustomerId,
        r.swNameCl,
        r.swAsociacion,
        r.swSegmento,
        r.swSegmento2,
        r.swStatusRoot,
        r.swStartDateRoot,
        r.swEndDateRoot,
        rh.swStatus,
        rh.swStartDate,
        rh.swEndDate,
        rh.swChnlPartnerId,
        rh.swChnlPartnerCtralId,
        rh.swCustomerId,
        rh.swType,
        rh.swCoInterno,
        rh.swName,
        rh.swNIE,
        r.swChnlPartnerCl,
        rh.swIntegraSAP,
        rh.swCodSAPSolic,
        rh.swCodSAPAcre,
        rh.mnpTipoDistribuidor,
        rh.swVerticalFocus,
        rh.swIndLiqComision,
        rh.swCodSAPDesti,
        rh.swCanalContratacion,
        rh.swCanalContratacion_esES,
        CASE WHEN r.swName = rh.swName THEN 1 ELSE 0 END        AS bSwNameCl_Ca,
        -- bSwPersonalId from pe_agg (Activo-consistent across all levels)
        CASE WHEN pa.swChnlPartnerId IS NOT NULL THEN 1 ELSE 0 END AS bSwPersonalId,
        -- nag_dist: original query propagated the root's count unchanged through
        -- the recursion; preserve that behaviour.
        r.nag_dist,
        ARRAY_CONCAT(r.path, [rh.swChnlPartnerId])              AS path
      FROM rec r
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` rh
              ON rh.swChnlPartnerCtralId = r.swChnlPartnerId
      LEFT  JOIN pe_agg pa ON pa.swChnlPartnerId = rh.swChnlPartnerId
      WHERE rh.swChnlPartnerId NOT IN UNNEST(r.path)            -- cycle guard (FIX)

    )

    SELECT DISTINCT
      p.mmMarcaId,
      p.mmMarcaDesc,
      p.id,
      p.lvl,
      p.root,
      p.swCustomerId,
      p.swNameCl,
      p.swAsociacion,
      p.swSegmento,
      p.swSegmento2,
      p.swStatusRoot,
      p.swStartDateRoot,
      p.swEndDateRoot,
      p.swStatus,
      p.swStartDate,
      p.swEndDate,
      p.swChnlPartnerId,
      p.swChnlPartnerCtralId,
      p.swCustomerIdCa,
      p.swType,
      p.swCoInterno,
      p.swName,
      p.swNIE,
      p.swChnlPartnerCl,
      p.swIntegraSAP,
      p.swCodSAPSolic,
      p.swCodSAPAcre,
      p.mnpTipoDistribuidor,
      p.swVerticalFocus,
      p.swIndLiqComision,
      p.swCodSAPDesti,
      p.swCanalContratacion,
      p.swCanalContratacion_esES,
      p.bSwNameCl_Ca,
      p.bSwPersonalId,
      p.nag_dist,
      -- pe_agg columns (replaces vag CTE and dead outer pe join)
      COALESCE(pe_agg.nag_eq, 0)                                AS nag_eq,
      pe_agg.vag,
      c2.canal_agrupado2_ds                                     AS ctx_canal_agrupado2_ds,
      c1.canal_agrupado1_ds                                     AS ctx_canal_agrupado1_ds,
      sc.subcanal_ds                                            AS ctx_subcanal_ds,
      p.swNameCl                                                AS nombre_distribuidor_alta_ds,
      can_vb.channel_id,
      can_vb.ch_segment_id
    FROM rec AS p
    -- pe_agg replaces the outer pe join (pe.* was unreferenced — that join only
    -- added fan-out that DISTINCT had to collapse)
    LEFT JOIN pe_agg                                                              ON pe_agg.swChnlPartnerId = p.swChnlPartnerId
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal`  c  ON c.canal_id = p.swChnlPartnerId
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON c.canal_agrupado1_id = c1.canal_agrupado1_id
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON c.canal_agrupado2_id = c2.canal_agrupado2_id
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal`             sc ON c.subcanal_id = sc.subcanal_id
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_EKTNET`      can_vb ON can_vb.brand_ds = p.mmMarcaDesc
                                                                                        AND can_vb.vertical_focus = p.swCoInterno;
    

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
            --e.crm.nombre_distribuidor_ds as distribuidor_ds,
            coalesce(e.crm.nombre_distribuidor_ds, e.optico.distribuidor )as distribuidor_ds,            
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
      ), sfid_k_mm_mo as (
        SELECT distinct origin_type,
        --mc.crm.marca as marca_ds,
        mc.marca_ds,
        c.N0,
        c.N1,
        c.N2,
        ac.sociedad,        
        ac.CIF,
        ac.ZONA_FISCAL as zona_fiscal,
        ac.bp,           
        ac.NOMBRE_ACREEDOR AS razon_social,     
        ac.nombre_acreedor,
        s.channel_id,
        s.sfid_id as sfid,
        fe.CODGR as n2id
        from sfid_k_uni s 
        --left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canal_asociado_ctx_kd_optico` mc on mc.crm.swCoInterno =s.sfid_id
        left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm` mc on mc.mm.sfid=s.sfid_id
        left JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_CANALES` c ON c.channel_id = s.channel_id
        LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_FUNCION_EQUIPO` fe ON fe.marca = mc.marca_ds AND fe.N0 = c.N0 AND fe.N1 = c.N1 AND fe.N2 = c.N2 
        left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` di on  di.marca=mc.marca_ds and di.nombre_distribuidor=mc.distribuidor.ds
        left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca =di.marca and ac.bp=di.bp
        --inner join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca in ("EUSKALTEL","RACC","SIMPLE","TELECABLE") and ac.codigo=left(s.sfid_id,3)
        --where mc.crm.marca in("EUSKALTEL","RACC","SIMPLE","TELECABLE")
        order by mc.marca_ds, c.N0, c.n1,c.n2

      ), sfid_new as (

        ---- subconsulta con relaciones sfid_ct, sfid_mo en tabla agents_k  

        select distinct sfid_viejo as sfid_old, equipo_sep as sfid_new
        from `mm-commissions-reporting.KRT_MIG_PWC.AGENTS_K_MAESTRO_CANALES`
        UNION ALL
        select distinct Codigo_dealer_viejo, padre
        from `mm-commissions-reporting.KRT_MIG_PWC.AGENTS_T_MAESTRO_AGENTES`

      )

      select distinct cmm.*, 
      STRUCT (
        sfid_k_mm_mo.origin_type,
        sfid_k_mm_mo.N0,
        sfid_k_mm_mo.N1,
        sfid_k_mm_mo.N2,
        sfid_k_mm_mo.sociedad,        
        sfid_k_mm_mo.CIF,
        sfid_k_mm_mo.zona_fiscal,
        sfid_k_mm_mo.bp,           
        sfid_k_mm_mo.NOMBRE_ACREEDOR AS razon_social,        
        sfid_k_mm_mo.nombre_acreedor as nombre_acreedor_ds,
        sfid_k_mm_mo.channel_id,
        sfid_new.sfid_new as sfid, 
        sfid_k_mm_mo.n2id              
      ) mo  
      from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm` cmm
      left join sfid_k_mm_mo  on cmm.mm.sfid=sfid_k_mm_mo.sfid and cmm.marca_ds=sfid_k_mm_mo.marca_ds
      left join sfid_new on sfid_new.sfid_old=sfid_k_mm_mo.sfid;

END