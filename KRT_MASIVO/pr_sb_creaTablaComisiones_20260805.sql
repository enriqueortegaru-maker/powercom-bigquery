BEGIN    

    --DECLARE vid_mes INT64;set vid_mes=202605;
    -- call`mm-commissions-reporting.KRT_PYME.pr_sb_creaTablaComisiones`(202607); 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.COMISIONES` AS 
    --DECLARE vid_mes INT64;set vid_mes=202607;
    select distinct 
    vid_mes as mes_id,
    a.data_source_ds, 
    a. brand_ds, 
    a.master_channel_ds,
    a.channel_ds, 
    a.subchannel_ds,
    a.distribuidor, 
    a.sfid_id,
    a.service_type, 
    a.tariff_id, 
    a.tariff_ds, 
    a.customer_id,
    a.service_id, 
    --- AÑADIDO PROPIO TERMINAL
    a.service_id as id,
    CAST(NULL AS STRING) id_subscription_terminal,
    CAST(NULL AS FLOAT64) total_pay_value_without_vat,
    CAST(NULL AS FLOAT64) total_pay_value,
    --- AÑADIDO PROPIO TERMINAL
    a.phone_nm ,
    a. sell_type,
    a.order_type_agg,
    m.tipo, 
    m.operacion, 
    a.seller,
    m.comisiona,
    `mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(ct.concepto, service_type, line_type_ds, order_type_agg) as concepto_marco, 
    co.concepto,
    ca.marco, 
    ca.grupo_rappel,
    --*********PENDIENTE INTEGRACION ORDEN
    --ca.orden, 
    CAST(NULL AS  INT64) orden,
    --*********PENDIENTE INTEGRACION ORDEN    
    ma.importe,
    a.sale_date,
    a.activation_date,
    a.deactivation_date,

    --from ( select * from `mm-commissions-reporting.COMISIONES.activaciones_krt_INTEGRACION` TABLESAMPLE SYSTEM (1 PERCENT) ) a
    from `mm-commissions-reporting.COMISIONES.ACTIVACIONES_KRT` a
    inner join  `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` tr on tr.mo.sfid=a.sfid_id
    inner join `mm-commissions-reporting.GS.PARAM_KRT_MAS_MARCA_CARTERA` m using(data_source_ds, sell_type, order_type_agg) 
    inner join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CATALOGOS` ct using(data_source_ds, brand_ds, service_type, tariff_id)
    left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CANALES` ca 
    --on ca.brand_ds=a.brand_ds and ca.N1=a.channel_ds and ca.N0=a.subchannel_ds
    on UPPER(TRIM(ca.brand_ds))=UPPER(TRIM(a.brand_ds)) 
    and UPPER(TRIM(ca.N1))= UPPER(TRIM(tr.mo.N1))
    and UPPER(TRIM(ca.N0)) =UPPER(TRIM(tr.mo.N0))
    --and UPPER(TRIM(a.channel_ds))= UPPER(TRIM(tr.mm.channel_ds))
    --and UPPER(TRIM(a.subchannel_ds)) =UPPER(TRIM(tr.mm.subchannel_ds))
    and case when UPPER(TRIM(ca.distribuidor))='X' or UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) THEN TRUE ELSE FALSE END
    and case when UPPER(TRIM(ca.sfid))='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
    --and UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) 
    and UPPER(TRIM(ca.tipo))=UPPER(TRIM(m.tipo)) 
    --and case when UPPER(TRIM(ca.sfid))='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
    left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_MARCO` ma on ma.tipo=m.tipo and ma.marca=ca.brand_ds and ma.marco=ca.marco and ma.concepto=`mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(ct.concepto, service_type, line_type_ds, order_type_agg)   
    left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CONCEPTO` co --on co.concepto_marco=ct.concepto and LOWER(TRIM(co.operacion))="activacion"
    ON STRPOS(LOWER(TRIM(ct.concepto)), LOWER(TRIM(co.concepto_marco)) ) > 0  and LOWER(TRIM(co.operacion))="activacion"
    where a.id_mes=vid_mes
    AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.deactivation_date, DATE '2099-12-31')) AS INT64) > vid_mes
    and not contains_substr(a.master_channel_ds,"EMPRESA")
    and a.data_source_ds="MYSIM"
    --and a.service_id="72306397"
    and a.sfid_id=tr.mo.sfid
    and m.comisiona=1

    UNION ALL

    ----- COMSIONES DISPOSITIVOS DESARROLLO

    --- MPORTANTE DEVICE_SUBSCRIPTION_ID  es el ID DEL TERMINAL, MIENTRAS QUE SERVICE_ID ES EL ID DEL SERVICIO ASOCIADO:


    --DECLARE vid_mes INT64;set vid_mes=202607;
    select distinct 
    vid_mes as mes_id,
    CASE WHEN a. brand_ds='R' THEN 'R' ELSE 'EKTNET' END as data_source_ds, 
    a. brand_ds, 
    a.master_channel_ds,     
    a.channel_ds, 
    a.subchannel_ds,
    a.distribuidor, 
    a.sfid_id,
    'DEVICE' as service_type, 
    a.tariff_id, 
    a.tariff_ds,
    a.customer_id, 
    a.service_id, 
    --- AÑADIDO PROPIO TERMINAL
    a.id_subscription_terminal as id,
    a.id_subscription_terminal,
    a.total_pay_value_without_vat,
    a.total_pay_value,
    --- AÑADIDO PROPIO TERMINAL
    CAST(a.phone_nm AS STRING) phone_nm,
    v.sell_type,
    a.order_type_agg,
    case when  coalesce(v.sell_type,"NOINF")="NEW SALE" THEN "CAPTACION" ELSE "CARTERA" END as tipo,
    "ALTA" as operacion,
    a.seller,
    -- case when a.order_type_agg in ("PORTABILITY", "NEW SIGN UP" )  THEN 1  ELSE 0 END as comisiona
    `mm-commissions-reporting.KRT_PYME.f_com_excluir_seller`(a.channel_ds,a.seller) as comisiona, 
    -- m.operacion, m.comisiona as comisiona, ct.concepto, ca.marco, ca.orden, ma.importe
    g.gama as concepto_marco,
    co.concepto,
    ca.marco,
    ca.grupo_rappel,
    --*********PENDIENTE INTEGRACION ORDEN
    --ca.orden, 
    CAST(NULL AS  INT64) orden,
    --*********PENDIENTE INTEGRACION ORDEN    

    --*********PENDIENTE RESOLVER CONTRA QUE ATRIBUTO COMPARAR PAR DEERMINAR LA GAMA E IMPORTAR DESDE MARCO RETRIBUTIVO************************
    ---g.importe,
    0 importe,
    --**********************************
    a.order_date as sale_date,  
    a.activation_date,
    a.deactivation_date

    -- from ( select * from `mm-commissions-reporting.TEMP.device_base_krt_INTEGRACION` TABLESAMPLE SYSTEM (1 PERCENT) ) a
    from `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT`  a
    left join  `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` tr on tr.mo.sfid=a.sfid_id

    ---============================================================================================ 
    --- CRUCE PARA DETERMINAR SI LA VENTAS ES DE CAPTACION O CARTERA EN BASE A VENTA DE SERVICIO 
    ---============================================================================================
    left join `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` v on 
    v.data_source_ds=a.data_source 
    and v.brand_ds=a.brand_ds 
    -- and v.phone_nm =CAST(a.phone_nm AS STRING) 
    and v.service_id = a.service_id 
    and v.id_mes_activacion=vid_mes

    -- left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_MARCA_CARTERA` m on m.data_source_ds=v.data_source_ds and m.sell_type=v.sell_type and m.order_type_agg=v.order_type_agg
    ---======================================================================= 
    --- FIN CRUCE 
    ---=======================================================================

    left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CANALES` ca 
    on  UPPER(TRIM(ca.brand_ds))=UPPER(TRIM(a.brand_ds)) 
    and UPPER(TRIM(ca.N1))= UPPER(TRIM(tr.mo.N1))
    and UPPER(TRIM(ca.N0)) =UPPER(TRIM(tr.mo.N0))
    and UPPER(TRIM(ca.tipo))=case when  coalesce(v.sell_type,"NOINF")="NEW SALE" THEN "CAPTACION" ELSE "CARTERA" END
    and case when UPPER(TRIM(ca.distribuidor))='X' or UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) THEN TRUE ELSE FALSE END
    and case when UPPER(TRIM(ca.sfid))='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
    left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_GAMA_TERMINAL` g on coalesce(a.total_pay_value_without_vat,(a.total_pay_value/1.21))between g.minimo and g.maximo 
    left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CONCEPTO` co --on co.concepto_marco=g.gama and LOWER(TRIM(co.operacion))="activacion"
    ON STRPOS(LOWER(TRIM(g.gama)), LOWER(TRIM(co.concepto_marco)) ) > 0  and LOWER(TRIM(co.operacion))="activacion"    
    where a.id_mes_activacion=vid_mes
    AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.deactivation_date, DATE '2099-12-31')) AS INT64) > vid_mes        
    --and a.service_id="151425586"
    and not contains_substr(a.master_channel_ds,"EMPRESA")
    and data_source_ds="MYSIM"    
    QUALIFY  ROW_NUMBER() over (partition by data_source_ds, brand_ds, service_id order by order_date desc)=1;

END