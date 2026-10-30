BEGIN

  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.DESACTIVACIONES_KRT` 
  PARTITION BY RANGE_BUCKET(id_mes, GENERATE_ARRAY(201500, 206000, 1))
  CLUSTER BY brand_ds, service_type, channel_ds, phone_nm
  AS 
    -- DECLARE id_mes_pr INT64; SET id_mes_pr=202607;
    select
      id_mes_pr as id_mes,
      --CASE WHEN a.comisionamiento = 'Comisiona' AND NOT b.comisiona THEN CONCAT('No Comisiona - sfid: ', a.seller) ELSE a.comisionamiento END AS comisionamiento,      
      a.comisionamiento,
      a.marca ,
      a.brand_ds ,
      ---- AÑADIDO PARA DEBUG
      a.master_channel_ds,
      a.channel_ds,
      a.subchannel_ds,
      ---- FIN AÑADIDO PARA DEBUG
      a.service_id ,
      a.account_id ,
      a.customer_id ,
      a.service_type ,
      a.line_type_ds ,
      a.bundle_type ,
      a.technology_ds ,
      a.billing_type_ds ,
      a.phone_nm ,
      a.sale_date ,
      a.activation_date ,
      a.deactivation_date ,
      a.order_id ,
      --- AÑADIDO PARA DETERMINAR MARCA CAPTACION Y CARTERA
      a.sell_type,      
      --- FIN AÑADIDO PARA DETERMINAR MARCA CAPTACION Y CARTERA
      a.order_type_agg ,
      a.tariff_id ,
      -- a.tariff_ds ,
      --CASE WHEN PROV.ftth_territoryowner IN (SELECT Territory_Owner FROM `mm-commissions-reporting.COMISIONES.maestro_territoyowner` WHERE Tipo_Huella = 'INDIRECTA' AND  Territory_Owner NOT LIKE '%SURF') THEN 'INDIRECTA '||
      a.tariff_ds, 
      a.cod_segmento ,
      a.cod_marca ,
      a.cod_tipo_contrato ,
      a.cod_producto ,
      a.cod_canal ,

      ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
      -- tlv_cross_sell.campaign AS campaign_code,
      CAST(NULL AS STRING) AS campaign_code,
      a.seller,    
      a.order_fix_id ,
      a.claim_code ,
      a.comments ,
      a.data_source_ds ,
      a.sociedad ,
      a.seller_formato_tms ,
      a.agrupacion_canal as agrupacion_canal_ventas_base ,
      coalesce (concat('KRT - ', initcap(b.marca_ds)), a.agrupacion_canal) as agrupacion_canal,
      b.mo.bp as id_comisionista,
      b.distribuidor.ds as distribuidor,
      b.mo.n2id canal ,
      TRUE as comisiona,
      CASE WHEN b.mm.subchannel_ds="EXCLUSIVO MULTIMARCA" THEN
            CASE WHEN b.marca_ds in ("EUSKALTEL","RACC","SIMPLE","R")   THEN b.equipo.descripcion
                 WHEN b.marca_ds in ("TELECABLE")  and  b.crm="EKTNET" THEN b.equipo.descripcion            
                 WHEN b.marca_ds in ("TELECABLE")  and  b.crm="TCNET" THEN b.agente.ds
            END
      END
      
      as nombre_comercio ,
      b.mo.razon_social ,
      b.mo.cif ,
      b.mo.zona_fiscal ,
      CAST(NULL AS STRING) as comentarios ,
      b.mo.cif cif_gpv ,
      a.seller as creado_por,
      a.seller as creado,
      a.sfid_id as sfid_original,
      CASE WHEN not contains_substr(master_channel_ds,"EMPRESA") THEN coalesce ( b.mo.sfid, a.sfid_id) 
           WHEN contains_substr(master_channel_ds,"EMPRESA") THEN coalesce ( b.mm.sfid, a.sfid_id) 
      END as sfid_id,
      a.portability_group_donor ,
      a.portability_operator_donor ,
      a.billing_tier,
      --DIGO.sfid_digo
      CAST(NULL AS STRING) sfid_digo


      --- AÑADIDO 20260819
      ,a.port_in_operator_ds,
      a.contract_id,
      a.flag_order,
      a.segment_ds,
      a.user_store,
      a.cancellation_day_id,
      a.province,
      a.zip_code,
      a.terminal_model,
      a.channel_segment_ds,
      a.channel_type_ds,
      a.hash_document_number,
      a.cancellation_reason_agg,
      a.cancellation_subreason_agg,
      a.max_appointment_date,
      a.deactivation_reason_ds,
      a.sub_segment_ds,
      a.id_mes_activacion,
      a.id_mes_desactivacion,
      --- FIN AÑADIDO 20260819





    -- from `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` a
    --from ( select * from `mm-commissions-reporting.COMISIONES.ventas_comisiones_krt_INTEGRACION` TABLESAMPLE SYSTEM(1 PERCENT)) a
    from `mm-commissions-reporting.COMISIONES.BAJAS_COMISIONES_KRT` a
    INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` b 
    ON b.marca_ds = a.brand_ds 
    AND (
          ---- VENTAS DE CANALIZACIONES MASIVO
          CASE WHEN not contains_substr(master_channel_ds,"EMPRESA") THEN
                ((a.brand_ds IN ("TELECABLE", "EUSKALTEL", "R","RACC", "SIMPLE", "VIRGIN") 
                AND (CAST(b.ct.sfid AS STRING) = a.sfid_id OR CAST(b.ct.sfid AS STRING) = a.user_store  OR b.mo.sfid = a.sfid_id OR b.mo.sfid = a.user_store))
                OR 
                (a.brand_ds = "R" AND CAST(b.agente.id AS STRING) = a.sfid_id))

              WHEN contains_substr(master_channel_ds,"EMPRESA") THEN
                (
                  ( a.brand_ds IN ("TELECABLE", "EUSKALTEL", "R","RACC", "SIMPLE", "VIRGIN") 
                    AND (CAST(b.ct.sfid AS STRING) = a.sfid_id OR CAST(b.ct.sfid AS STRING) = a.user_store)
                  )
                  OR (a.brand_ds = "R" AND CAST(b.agente.id AS STRING) = a.sfid_id)
                )

          END
        )



    /* AL MENOS DE MOMENTO NO APLICAN
    LEFT JOIN  `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell 
      ON b.id_comisionista = tlv_cross_sell.id_comisionista 
      AND b.canal = tlv_cross_sell.canal

    LEFT JOIN `mm-datamart-kd.ACCESS_PROVISION.provision_base` AS PROV
          ON PROV.workorder_id = a.order_fix_id

    */
    LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo` I
    ON a.account_id = I.account_id
    AND a.phone_nm = CAST(I.phone_nm AS STRING)
    AND  I.mes_venta = id_mes_pr

    where 1=1
    and ( a.billing_type_ds = 'POSTPAID')
    --and (COALESCE(a.seller, 'a') NOT LIKE 'MLV%' OR COALESCE(a.seller, 'a')  NOT LIKE '%RPORT' OR COALESCE(a.seller, 'a')  NOT LIKE '%RBAJA') --<----- sfid de baja que se coge sin querer cuando se sacan los dealers de Exclusivo
    --and b.agrupacion_canal ='Guuk'
    --and b.comisiona

    and CAST(CAST(FORMAT_DATE('%Y%m',a.deactivation_date) AS STRING) AS INT64)=id_mes_pr
    --and date_trunc (a.activation_date, month) = COMISIONES.f_mes_int ( id_mes_pr )
    and (a.agrupacion_canal = concat('KRT - ', initcap(b.marca_ds))) 
    --AND NOT (order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' AND b.canal IN ('ENX','EML','EYG','EDB'))
    ---- CONDICION PARA TLV OUTBOUND (Excluimos prepago procedente de +O para los códigos TLVOU012 Y TLVOU018)
    --AND NOT (b.CANAL = 'OU' and b.id_comisionista in ('TLVOU012','TLVOU018')AND I.billing_type_donor = 'PREPAID'AND I.grupo_operador_donante_unificado = 'MASORANGE' AND A.service_type = 'MOBILE')
    --qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by case when id_comisionista = seller then 1 else 0 end desc, length(b.mo.bp) desc nulls last, comisiona desc) = 1
    -- and a.agrupacion_canal ='Exclusivo'  --eo

    --- CONDICION INTRODUCIDA PARA ELIMINAR DUPLICADOS EN OUTBOUND DE TEECABLE CON  REGISTRO ASIGNAOD A CANAL OC y OTRO A NULL 
    qualify row_number () over (partition by brand_ds, customer_id, service_id, service_type, activation_date order by canal desc nulls last) = 1

    and a.brand_ds in ('EUSKALTEL','SIMPLE','RACC','TELECABLE','R');


END