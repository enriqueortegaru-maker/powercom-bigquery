BEGIN

    --- PASO 1: Maestro Canal
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` AS
    SELECT 
      sfid_id as agente_venta_id,
      channel_ds as canal_agrupado1_ds,  
      CASE 
        WHEN contains_substr(channel_ds, "TASK") OR contains_substr(channel_ds, "PUNTO DE VENTA") OR contains_substr(channel_ds, "CANALES ALTERNATIVO") 
        THEN "PRESENCIAL" 
        ELSE "NO PRESENCIAL" 
      END as canal_Agrupado2_ds,    
      distributor_ds as distribuidor_ds,  
      subchannel_ds as subcanal_ds,
      vertical_focus_ds as equipo_ds
    FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL`;


    --- PASO 2: Maestro Canal Siebel Agente Login
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal_siebel_agente_login` AS
    WITH s AS (
        SELECT 
          e.row_id, 
          TRIM(UPPER(u.LOGIN)) as login, 
          j.agente_venta_id, 
          TRIM(e.ATTRIB_09) as estado,
          EXTRACT(DATE FROM e.CREATED) as fecha_creacion, 
          u.USER_FLG as login_flag, 
          u.TRNG_DL_ADMIN_FLG as login_admin_flag, 
          CAST(NULL AS STRING) as tenderete_profile, 
          "SIEBEL" as origen,
          COUNT(DISTINCT u.login) OVER(PARTITION BY j.agente_venta_id) as nlogin,
          COUNT(DISTINCT j.agente_venta_id) OVER(PARTITION BY u.login) as nav
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
        INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u ON e.row_id = u.row_id 
        INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j ON TRIM(CAST(j.agente_venta_id AS STRING)) = TRIM(e.ATTRIB_07) 
        WHERE e.attrib_07 IS NOT NULL
    )
    SELECT 
        COALESCE(s.login, "NOINF") as login, 
        m.*,
        s.nlogin,
        s.nav,
        CONCAT(m.canal_agrupado1_ds, "_", m.subcanal_ds, "_", m.distribuidor_ds) as sfid,
        LENGTH(CAST(m.agente_venta_id AS STRING)) as dim,
        
        -- Optimizacion de extraccion de strings usando LPAD
        SUBSTR(LPAD(CAST(m.agente_venta_id AS STRING), 8, '0'), 1, 2) as codCa,
        SUBSTR(LPAD(CAST(m.agente_venta_id AS STRING), 8, '0'), 3, 3) as codDi,
        RIGHT(CAST(m.agente_venta_id AS STRING), 3) as codAg, 
        
        d.CIF,
        IF(d.CIF IS NOT NULL, 1, 0) as bdist,
        CAST(1 as INT64) as bExisteSiebel,          
        IF(COUNT(e.ATTRIB_09) = 0 OR (COUNT(e.ATTRIB_09) > 0 AND COUNT(e.ATTRIB_09) != COUNTIF(e.ATTRIB_09 = "Y")), 1, 0) as bactivo,
        
        ARRAY_AGG(u.login IGNORE NULLS) as vlogin,
        ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS) as vATTRIB_09,
        ARRAY_AGG(COALESCE(e.ATTRIB_10, 'NA') IGNORE NULLS) as vATTRIB_10,

        STRING_AGG(u.login, '/') as vslogin,
        STRING_AGG(e.ATTRIB_09, '/') as vsATTRIB_09,
        STRING_AGG(COALESCE(e.ATTRIB_10, 'NA'), '/') as vsATTRIB_10,
        
        COUNT(e.ATTRIB_09) as nreg_nonulo,
        COUNTIF(e.ATTRIB_09 = "Y") as nbaja_y, 
        COUNTIF(e.ATTRIB_09 = "N") as nbaja_n
    FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` m
    LEFT JOIN s USING(agente_venta_id)
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e ON TRIM(e.ATTRIB_07) = TRIM(CAST(m.agente_venta_id AS STRING)) 
    LEFT JOIN `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d ON TRIM(d.nombre_distribuidor) = TRIM(m.distribuidor_ds) AND d.marca = "R"  
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u ON u.row_id = e.row_id
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17;


    --- PASO 3: Maestro Siebel Agente Login (Unificacion Siebel/Tenderete)
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_siebel_agente_login` AS
    WITH s AS (
        SELECT 
          e.row_id, TRIM(UPPER(u.LOGIN)) as login, j.agente_venta_id, TRIM(e.ATTRIB_09) as estado,
          EXTRACT(DATE FROM e.CREATED) as fecha_creacion, u.USER_FLG as login_flag, 
          u.TRNG_DL_ADMIN_FLG as login_admin_flag, CAST(NULL AS STRING) as tenderete_profile, "SIEBEL" as origen
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
        INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u ON e.row_id = u.row_id 
        INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j ON TRIM(CAST(j.agente_venta_id AS STRING)) = TRIM(e.ATTRIB_07) 
        WHERE e.attrib_07 IS NOT NULL
    ), 
    t AS (
        SELECT 
          e.row_id, UPPER(TRIM(u.user_)) as login, j.agente_venta_id, e.ATTRIB_09 as estado,
          EXTRACT(DATE FROM e.CREATED) as fecha_creacion, CAST(NULL AS STRING) as login_flag, 
          CAST(NULL AS STRING) as login_admin_flag, p.Profile_name as tenderete_profile, "TENDERETE" as origen
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
        INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_users` u ON TRIM(UPPER(e.row_id)) = TRIM(UPPER(u.idsiebel)) 
        LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_profiles` p ON p.id_profile = u.id_profile
        INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j ON TRIM(CAST(j.agente_venta_id AS STRING)) = TRIM(e.ATTRIB_07) 
        LEFT JOIN s ON s.agente_venta_id = j.agente_venta_id AND s.login = UPPER(TRIM(u.user_))
        WHERE e.attrib_07 IS NOT NULL 
        AND s.agente_venta_id IS NULL -- Anti-join en lugar del NOT EXISTS
    ),
    m AS (
        SELECT DISTINCT * FROM s
        UNION ALL 
        SELECT DISTINCT * FROM t
    ) 
    SELECT DISTINCT 
      m.*, 
      ROW_NUMBER() OVER(PARTITION BY login ORDER BY origen ASC, fecha_creacion DESC) as orden
    FROM m;


    --- PASO 4: Maestro Tenderete Login
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_tenderete_login` AS
    SELECT DISTINCT 
      e.row_id,
      UPPER(TRIM(u.user_)) as login,
      UPPER(TRIM(u2.LOGIN)) as login_si, 
      j.agente_venta_id as agente_venta_id_si, 
      e.ATTRIB_09 as estado_si,
      EXTRACT(DATE FROM e.CREATED) as fecha_creacion_si, 
      p.Profile_name as profile,  
      u.* EXCEPT(user_, password, id_profile, idsiebel, id_admin_profile)
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_users` u ON TRIM(UPPER(e.row_id)) = TRIM(UPPER(u.idsiebel)) 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.eng_profiles` p ON p.id_profile = u.id_profile
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u2 ON e.row_id = u2.row_id 
    INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` j ON TRIM(CAST(j.agente_venta_id AS STRING)) = TRIM(e.ATTRIB_07); 


    --- PASO 5: Maestro Canal MM
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_siebel_canalizacion_ct_mm` AS
    SELECT DISTINCT
      "SIEBEL" as crm,
      j.brand_ds as marca_ds,
      CAST(NULL AS INT64) as canal_Agrupado2_id,
      CASE 
        WHEN contains_substr(j.channel_ds, "TASK") OR contains_substr(j.channel_ds, "PUNTO DE VENTA") OR contains_substr(j.channel_ds, "CANALES ALTERNATIVO") 
        THEN "PRESENCIAL" 
        ELSE "NO PRESENCIAL" 
      END as canal_Agrupado2_ds,    
      CAST(NULL AS INT64) as canal_Agrupado1_id,
      j.channel_ds as canal_agrupado1_ds,   
      CAST(NULL AS INT64) as subcanal_id,
      j.subchannel_ds as subcanal_ds,  
      CAST(NULL AS INT64) as canal_id,  
      j.vertical_focus_ds as equipo_ds,
      CAST(j.sfid_id AS STRING) as agente_venta_id,

      STRUCT (
        CAST(NULL AS INT64) as id, j.distributor_ds as ds, CAST(NULL AS STRING) as descripcion,
        CAST(NULL AS STRING) as estado, CAST(NULL AS DATE) as fechaCreacion, CAST(NULL AS DATE) as fechaAlta, CAST(NULL AS DATE) as fechaBaja 
      ) as distribuidor,   

      STRUCT (
        CAST(NULL AS INT64) as id, j.vertical_focus_ds as ds, j.vertical_focus_ds as descripcion,
        CAST(NULL AS STRING) as estado, CAST(NULL AS DATE) as fechaCreacion, CAST(NULL AS DATE) as fechaAlta, CAST(NULL AS DATE) as fechaBaja 
      ) as canal_asociado,

      STRUCT (
        CAST(NULL AS INT64) as id, j.vertical_focus_ds as ds, j.vertical_focus_ds as descripcion,
        CAST(NULL AS STRING) as estado, CAST(NULL AS DATE) as fechaCreacion, CAST(NULL AS DATE) as fechaAlta, 
        CAST(NULL AS DATE) as fechaBaja, CAST(NULL AS STRING) as param_ctx
      ) as equipo, 
      
      STRUCT (
        j.sfid_id as id, CAST(j.sfid_id AS STRING) as ds, CAST(NULL AS STRING) as estado,
        CAST(NULL AS DATE) as fechaCreacion, CAST(NULL AS DATE) as fechaAlta, CAST(NULL AS DATE) as fechaBaja
      ) as agente,

      STRUCT(
        CASE 
          WHEN contains_substr(j.channel_ds, "TASK") OR contains_substr(j.channel_ds, "PUNTO DE VENTA") OR contains_substr(j.channel_ds, "CANALES ALTERNATIVO") 
          THEN "PRESENCIAL" 
          ELSE "NO PRESENCIAL" 
        END as tipo_canal_ds,
        j.channel_ds as canal_ds, j.subchannel_ds as subcanal_ds, j.distributor_ds as distribuidor_ds,
        j.vertical_focus_ds as equipo_ds, CAST(j.sfid_id AS STRING) as agente_venta_id, CAST(j.sfid_id AS STRING) as sfid        
      ) as ct,
        
      STRUCT(
        c.channel_type_ds, 
        c.master_channel_ds, 
        c.superchannel_ds, 
        c.channel_ds, 
        c.subchannel_ds,        
        j.distributor_ds as distribuidor_ds, 
        CAST(j.sfid_id AS STRING) as sfid,
        c.channel_id AS channel_id,                
        s.channel_segment_ds as channel_segment_ds
      ) AS mm
    FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL` j
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CHANNEL` c USING (channel_id)
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_CH_SEGMENT` s ON s.ch_segment_id = j.ch_segment_id;


    --- PASO 4: CREO TABLA tr_crm_siebel_canalizacion_ct_mo
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_siebel_canalizacion_ct_mo` AS
    WITH sfid_r AS (
        SELECT 
          sfid_id, 
          channel_id, 
          CAST(NULL AS STRING) AS s_distributor, -- No usamos el distribuidor de ventas aquí
          'SALES' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_SALES_R`

        UNION ALL 
        
        SELECT 
          sfid_id, 
          channel_id, 
          distribuidor AS s_distribuidor,          -- Sí usamos el distribuidor de operaciones
          'OPERATIONS' AS origin_type 
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_OPERATIONS_R`
        
      ), sfid_r_mo as (
        SELECT distinct 
          s.origin_type,
          'R' marca_ds,
          c.N0, 
          c.N1, 
          c.N2,
          ac.sociedad,        
          ac.CIF,
          ac.ZONA_FISCAL as zona_fiscal,
          ac.bp,   
          ac.NOMBRE_ACREEDOR AS razon_social,     
          ac.nombre_acreedor,
          c.channel_id,
          CAST(j.sfid_id AS STRING) AS sfid,
          fe.CODGR as n2id
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL` j
        left JOIN sfid_r s ON j.sfid_id = s.sfid_id
        left join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` mc on mc.agente_venta_id =j.sfid_id
        LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_CANALES` c  ON c.channel_id = s.channel_id
        LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_FUNCION_EQUIPO` fe ON fe.N0 = c.N0 AND fe.N1 = c.N1 AND fe.N2 = c.N2                         
        left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` di on di.marca in('R') and di.nombre_distribuidor=mc.distribuidor_ds
        left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca in('R') and ac.bp=di.bp and ac.marca=di.marca
        
        where j.brand_ds='R' 
       
        UNION ALL

        SELECT distinct 
          s.origin_type,
          'TELECABLE' marca_ds,
          c.N0, 
          c.N1, 
          c.N2,
          ac.sociedad,        
          ac.CIF,
          ac.ZONA_FISCAL as zona_fiscal,   
          ac.bp,
          ac.NOMBRE_ACREEDOR AS razon_social,          
          ac.nombre_acreedor,
          c.channel_id,
          CAST(j.sfid_id AS STRING) AS sfid,
          fe.CODGR as n2id
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL` j
        left JOIN sfid_r s ON j.sfid_id = s.sfid_id
        left join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` mc on mc.agente_venta_id =j.sfid_id 
        LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MO_CANALES` c  ON c.channel_id = j.channel_id
        LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.PARAM_FUNCION_EQUIPO` fe ON fe.N0 = c.N0 AND fe.N1 = c.N1 AND fe.N2 = c.N2                 
        left join `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` di on di.marca in('TELECABLE') and di.nombre_distribuidor=mc.distribuidor_ds
        left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac on ac.marca in('TELECABLE') and ac.bp=di.bp and ac.marca=di.marca


        where j.brand_ds='TELECABLE'

        order by marca_ds, n0, n1 asc, n2 asc
      ) select distinct cmm.*, 
      STRUCT (
        sfid_r_mo.origin_type,
        sfid_r_mo.N0,
        sfid_r_mo.N1,
        sfid_r_mo.N2,
        sfid_r_mo.sociedad,        
        sfid_r_mo.CIF,
        sfid_r_mo.zona_fiscal,   
        sfid_r_mo.bp,
        sfid_r_mo.NOMBRE_ACREEDOR AS razon_social,        
        sfid_r_mo.nombre_acreedor as nombre_acreedor_ds,
        sfid_r_mo.channel_id,
        sfid_r_mo.sfid as sfid,
        sfid_r_mo.n2id                        
      ) mo  
      from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_siebel_canalizacion_ct_mm` cmm
      left join sfid_r_mo  on cmm.mm.sfid=sfid_r_mo.sfid and cmm.marca_ds=sfid_r_mo.marca_ds;



    --- PASO 6: Audit Jerarquía Comercial Siebel (Lógica fusionada y optimizada en 1 solo paso)
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_JERARQUIA_COMERCIAL_SIEBEL` AS
    WITH base_audit AS (
        SELECT 
          m.canal_agrupado1_ds, 
          m.canal_agrupado2_ds, 
          m.subcanal_ds,  
          m.distribuidor_ds,
          m.equipo_ds,
          m.agente_venta_id, 
          m.agente_venta_id as codigo_comercial,  
          CONCAT(m.canal_agrupado1_ds, "_", m.subcanal_ds, "_", m.distribuidor_ds) as sfid,
          LENGTH(CAST(m.agente_venta_id AS STRING)) as dim,
          
          -- Optimizacion de strings
          SUBSTR(LPAD(CAST(m.agente_venta_id AS STRING), 8, '0'), 1, 2) as codCa,
          SUBSTR(LPAD(CAST(m.agente_venta_id AS STRING), 8, '0'), 3, 3) as codDi,
          RIGHT(CAST(m.agente_venta_id AS STRING), 3) as codAg, 
          
          d.CIF,
          IF(d.CIF IS NOT NULL, 1, 0) as bdist,
          CAST(1 as INT64) as bExisteSiebel,
          IF(COUNT(e.ATTRIB_09) = 0 OR (COUNT(e.ATTRIB_09) > 0 AND COUNT(e.ATTRIB_09) != COUNTIF(e.ATTRIB_09 = "Y")), 1, 0) as bactivo,
          
          ARRAY_AGG(u.login IGNORE NULLS) as vlogin,
          ARRAY_AGG(e.ATTRIB_09 IGNORE NULLS) as vATTRIB_09,
          ARRAY_AGG(COALESCE(e.ATTRIB_10, 'NA') IGNORE NULLS) as vATTRIB_10,

          STRING_AGG(u.login, '/') as vslogin,
          STRING_AGG(e.ATTRIB_09, '/') as vsATTRIB_09,
          STRING_AGG(COALESCE(e.ATTRIB_10, 'NA'), '/') as vsATTRIB_10,
          
          COUNT(e.ATTRIB_09) as nreg_nonulo,
          COUNTIF(e.ATTRIB_09 = "Y") as nbaja_y, 
          COUNTIF(e.ATTRIB_09 = "N") as nbaja_n
        FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` m   
        LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` e ON TRIM(e.ATTRIB_07) = TRIM(CAST(m.agente_venta_id AS STRING)) 
        LEFT JOIN `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d ON TRIM(d.nombre_distribuidor) = TRIM(m.distribuidor_ds) AND d.marca = "R"      
        LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_user` u ON u.row_id = e.row_id
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,14,15
    )
    SELECT 
      distinct *,
      COUNT(DISTINCT sfid) OVER(PARTITION BY distribuidor_ds, equipo_ds) as nsfid
    FROM base_audit;

END