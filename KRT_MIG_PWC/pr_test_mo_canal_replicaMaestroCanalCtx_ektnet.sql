BEGIN

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
      ), sfid_k_mo as (
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

      ) select distinct cmm.*, 
      STRUCT (
        sfid_k_mo.origin_type,
        sfid_k_mo.N0,
        sfid_k_mo.N1,
        sfid_k_mo.N2,
        sfid_k_mo.sociedad,        
        sfid_k_mo.CIF,
        sfid_k_mo.zona_fiscal,
        sfid_k_mo.bp,           
        sfid_k_mo.NOMBRE_ACREEDOR AS razon_social,        
        sfid_k_mo.nombre_acreedor as nombre_acreedor_ds,
        sfid_k_mo.channel_id,
        sfid_k_mo.sfid as sfid, 
        sfid_k_mo.n2id              
      ) mo  
      from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm` cmm
      left join sfid_k_mo  on cmm.mm.sfid=sfid_k_mo.sfid and cmm.marca_ds=sfid_k_mo.marca_ds;

  END