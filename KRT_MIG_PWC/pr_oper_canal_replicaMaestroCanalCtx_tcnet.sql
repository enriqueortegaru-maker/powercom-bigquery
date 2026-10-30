BEGIN

  -- ---------------------------------------------------------------------------
  -- 1. TABLA: CANAL X EQUIPO
  -- tr_t_fijo_canales_servicio: GoogleSheet KRT TRADUCTOR hoja tr_t_fijo_canales_servicio
  -- ---------------------------------------------------------------------------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_canalxequipo` AS
      SELECT DISTINCT 
        tipo_canal_ds,
        canal_edw_ds,
        subcanal_edw_ds,
        codigo_canal_asociado,
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio`
      ORDER BY codigo_canal_asociado;

  -- ---------------------------------------------------------------------------
  -- 2. TABLA: EQUIPO X AGENTE
  -- ---------------------------------------------------------------------------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_equipoxagente` AS
      WITH stg_personal AS (
        SELECT 
          swPersonalId, 
          swNombre,
          swEstado,
          swDateCreated,
          swFechaAlta,
          swFechaBaja,
          -- Normalizamos nombre una sola vez aquí
          UPPER(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'))) as key_nombre
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo`
        WHERE swObjectType='CHANNEL_PARTNER'
        -- and swEstado="Activo" 
      ),
      stg_inv AS (
        SELECT 
          codigo_canal_asociado,
          codigo_ventas,
          -- Normalizamos código ventas una sola vez aquí
          UPPER(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(codigo_ventas), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'))) as key_ventas
        FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio`
      )
      SELECT DISTINCT 
        inv.codigo_canal_asociado,
        inv.codigo_ventas,
        pe.swPersonalId, 
        STRUCT (
            pe.swPersonalId as id,
            pe.swNombre as ds,
            pe.swEstado as estado,
            EXTRACT(DATE FROM pe.swDateCreated) as fechaCreacion,
            EXTRACT(DATE FROM pe.swFechaAlta) as fechaAlta,   
            EXTRACT(DATE FROM pe.swFechaBaja) as fechaBaja
        ) as agente
      FROM stg_inv inv 
      INNER JOIN stg_personal pe ON pe.key_nombre = inv.key_ventas;

  -- ---------------------------------------------------------------------------
  -- 3. TABLA: CANAL X EQUIPO X AGENTE
    -- ---------------------------------------------------------------------------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_canalxequipoxagente` AS
      SELECT DISTINCT
        inv.tipo_canal_ds,
        inv.canal_edw_ds,
        inv.subcanal_edw_ds,
        inv.codigo_canal_asociado, 
        inv.equipo_edw_ds,
        ag.swPersonalId, 
        ag.agente,
        inv.codigo_ventas,
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_t_canales_servicio` inv
      INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_canalxequipo` can 
        USING (tipo_canal_ds, canal_edw_ds, subcanal_edw_ds, codigo_canal_asociado) 
      INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_equipoxagente` ag 
        USING (codigo_canal_asociado, codigo_ventas) 
      WHERE NOT CONTAINS_SUBSTR(subcanal_edw_ds, "EMPRESA")
        AND inv.codigo_canal_asociado != 91;
  
  -- ---------------------------------------------------------------------------
  -- 4. TABLA: CANAL X EQUIPO X AGENTE UNICO
  -- ---------------------------------------------------------------------------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_canalxequipoxagente_unico` AS
      SELECT 
        *,
        COUNT(equipo_edw_ds) OVER(PARTITION BY codigo_canal_asociado, swPersonalId) as nr
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_canalxequipoxagente`
      QUALIFY nr = 1
      ORDER BY nr DESC;

  -- ---------------------------------------------------------------------------
  -- 5. TABLA FINAL: MAESTRO CANAL
  -- ---------------------------------------------------------------------------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` AS
    SELECT DISTINCT 
      cn2.canal_agrupado2_id,
      cn2.canal_agrupado2_ds,
      cn1.canal_agrupado1_id,
      cn1.canal_agrupado1_ds,
      s.subcanal_id,
      s.subcanal_ds,
      m.codigo_canal_asociado as canal_id,
      m.equipo_edw_ds as equipo_ds,
      m.codigo_ventas as agente_alta_id,    

      STRUCT (
        cap.swChnlPartnerId as id,  
        cap.swCoInterno as ds,
        cap.swVerticalFocus as descripcion,
        cap.swStatus as estado,
        EXTRACT(DATE FROM cap.swDateCreated) as fechaCreacion,
        EXTRACT(DATE FROM cap.swStartDate) as fechaAlta,    
        EXTRACT(DATE FROM cap.swEndDate) as fechaBaja   
      ) as distribuidor,   

      STRUCT (
        m.codigo_canal_asociado as id,    
        ca.swCoInterno as ds,
        ca.swVerticalFocus as descripcion,
        ca.swStatus as estado,
        EXTRACT(DATE FROM ca.swDateCreated) as fechaCreacion,
        EXTRACT(DATE FROM ca.swStartDate) as fechaAlta,   
        EXTRACT(DATE FROM ca.swEndDate) as fechaBaja    
      ) as canal_asociado,

      STRUCT (
        ca.swChnlPartnerId as id,  
        ca.swCoInterno as ds,
        ca.swVerticalFocus as descripcion,
        ca.swStatus as estado,
        EXTRACT(DATE FROM ca.swDateCreated) as fechaCreacion,
        EXTRACT(DATE FROM ca.swStartDate) as fechaAlta,   
        EXTRACT(DATE FROM ca.swEndDate) as fechaBaja,   
        m.equipo_edw_ds as param_ctx
      ) as equipo, 
      m.agente

    FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_canalxequipoxagente_unico` m
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca 
      ON ca.swChnlPartnerId = m.codigo_canal_asociado 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` cap 
      ON cap.swChnlPartnerId = ca.swChnlPartnerCtralId 
    
    -- Optimizamos estos JOINS limpiando el texto en la comparación directa
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` cn1 
      ON UPPER(TRIM(cn1.canal_agrupado1_ds)) = UPPER(TRIM(m.canal_edw_ds))
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` cn2 
      ON UPPER(TRIM(cn2.canal_agrupado2_ds)) = UPPER(TRIM(m.tipo_canal_ds))
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` s 
      ON UPPER(TRIM(s.subcanal_ds)) = UPPER(TRIM(m.subcanal_edw_ds))
    
    WHERE ca.swStatus <> 'Excliente' 
      AND ca.swChnlPartnerId <> 91
    ORDER BY 2,4,6,8,9 ASC;


  -- ---------------------------------------------------------------------------
  -- 6. TABLA TRADUCTOR A JERARQUIA MM
  -- ---------------------------------------------------------------------------

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_tcnet_canalizacion_ct_mm` AS
    WITH maestro AS (
        SELECT 
          canal_agrupado2_id,
          canal_agrupado2_ds,
          canal_agrupado1_id,
          canal_agrupado1_ds,
          subcanal_id,
          subcanal_ds,
          canal_id,
          equipo_ds,
          agente_alta_id as agente_venta_id,    
          distribuidor,   
          canal_asociado,
          equipo, 
          agente   
        
        FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal`
    ),
    aux_tcnet AS (
        SELECT 
            CAST(user_store AS INT64) AS user_store,
            CAST(channel_id AS INT64) AS channel_id,
            CAST(ch_segment_id AS INT64) AS ch_segment_id
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_TCNET`
    ),
    aux_exception AS (
        SELECT 
            -- Separamos el string por el guion '-' y casteamos a enteros
            CAST(SPLIT(store_pers_id, '-')[OFFSET(0)] AS INT64) AS exc_canal_id,
            CAST(SPLIT(store_pers_id, '-')[OFFSET(1)] AS INT64) AS exc_agente_id,
            CAST(channel_id AS INT64) AS channel_id,
            CAST(ch_segment_id AS INT64) AS ch_segment_id
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_TCNET_EXCEPTION`
    ),
    canales AS (
        SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CHANNEL`
    ),
    segmentos AS (
        SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CH_SEGMENT`
    ),
    maestro_enriquecido AS (
        SELECT 
            m.*,
            -- Priorizamos la tabla de excepciones usando COALESCE
            COALESCE(exc.channel_id, aux.channel_id) AS channel_id_mm,
            COALESCE(exc.ch_segment_id, aux.ch_segment_id) AS ch_segment_id_mm
        FROM maestro m
        -- Cruce 1: Tabla de parámetros general (AUX_TCNET)
        LEFT JOIN aux_tcnet aux 
            ON m.canal_asociado.id = aux.user_store
        -- Cruce 2: Tabla de excepciones (AUX_TCNET_EXCEPTION)
        LEFT JOIN aux_exception exc 
            ON m.canal_asociado.id = exc.exc_canal_id 
            AND m.agente.id = exc.exc_agente_id
    )

    SELECT 
        "TCNET" as crm,
        "TELECABLE" as marca_ds,
        -- Mantenemos todos los campos originales de tr_t_30_maestro_canal
        e.* EXCEPT(channel_id_mm, ch_segment_id_mm),
        
        STRUCT(
            e.canal_agrupado2_ds as tipo_canal_ds,
            e.canal_agrupado1_ds as canal_ds,
            e.subcanal_ds as subcanal_ds,
            e.distribuidor.ds as distribuidor_ds,
            e.equipo_ds,
            e.agente_venta_id,
            CONCAT(cast(COALESCE(equipo.id,666666 )as string),'-', CAST(coalesce(agente.id,666666 )as string)) as sfid        
        ) as ct,
        -- Creamos la estructura mm con los nuevos atributos descubiertos
        STRUCT(
            ch.channel_type_ds ,
            ch.master_channel_ds,
            ch.superchannel_ds,
            ch.channel_ds,
            ch.subchannel_ds,         -- Se mantiene tu naming solicitado 'subchanel'
            e.distribuidor.ds as distribuidor_ds,
            CONCAT(cast(COALESCE(equipo.id,666666 )as string),'-', CAST(coalesce(agente.id,666666 )as string)) as sfid,        
            ch.channel_id AS channel_id,
            seg.channel_segment_ds
        ) AS mm
    FROM maestro_enriquecido e
    -- Cruce con CHANNEL para recuperar los descriptivos del canal
    LEFT JOIN canales ch 
        ON e.channel_id_mm = ch.channel_id
    -- Cruce con SEGMENT para recuperar los descriptivos del segmento
    LEFT JOIN segmentos seg 
        ON e.ch_segment_id_mm = seg.ch_segment_id;



  -- ---------------------------------------------------------------------------
  -- 6. TABLA TRADUCTOR A JERARQUIA MO
  -- ---------------------------------------------------------------------------

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_tcnet_canalizacion_ct_mo` AS
    WITH sfid_t AS (
        --- Filtrado de jerarquias propias de TCNET
        SELECT 
          sfid_id, 
          channel_id, 
          CAST(NULL AS STRING) AS s_distributor, -- No usamos el distribuidor de ventas aquí
          'SALES' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_SALES_TELECABLE`
        --where sfid_id not like'%00000' and sfid_id not like '%EX'
        WHERE REGEXP_CONTAINS(sfid_id, r'^[0-9]+-[0-9]+$')
        
        UNION ALL 
        SELECT 
          sfid_id, 
          channel_id, 
          distribuidor AS s_distribuidor,          -- Sí usamos el distribuidor de operaciones
          'OPERATIONS' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_OPERATIONS_TELECABLE`
        --where sfid_id not like'%00000' and sfid_id not like '%EX'
        WHERE REGEXP_CONTAINS(sfid_id, r'^[0-9]+-[0-9]+$')        
      ), sfid_t_mo as (
        SELECT distinct origin_type,
        ac.marca as marca_ds,
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
        from sfid_t s 
        left join `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` mc on concat(CAST(canal_id AS STRING),'-', CAST(mc.agente.id AS  STRING)) =s.sfid_id
        inner JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_CANALES` c ON c.channel_id = s.channel_id        
        LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_FUNCION_EQUIPO` fe ON fe.N0 = c.N0 AND fe.N1 = c.N1 AND fe.N2 = c.N2         
        left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` di on di.marca in('TELECABLE') and di.nombre_distribuidor=mc.distribuidor.ds
        inner join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca in ("TELECABLE") and ac.bp=di.bp
        order by ac.marca, c.N0, c.n1,c.n2
      ) select distinct cmm.*, 
      STRUCT (
        sfid_t_mo.origin_type,
        sfid_t_mo.N0,
        sfid_t_mo.N1,
        sfid_t_mo.N2,
        sfid_t_mo.sociedad,        
        sfid_t_mo.CIF,
        sfid_t_mo.zona_fiscal, 
        sfid_t_mo.bp,          
        sfid_t_mo.NOMBRE_ACREEDOR AS razon_social,        
        sfid_t_mo.nombre_acreedor as nombre_acreedor_ds,
        sfid_t_mo.channel_id,
        sfid_t_mo.sfid as sfid, 
        sfid_t_mo.n2id    
      ) mo  
      from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_tcnet_canalizacion_ct_mm` cmm
      left join sfid_t_mo  on cmm.mm.sfid=sfid_t_mo.sfid and cmm.marca_ds=sfid_t_mo.marca_ds;

END