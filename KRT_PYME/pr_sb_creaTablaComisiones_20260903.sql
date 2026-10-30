BEGIN    

    --DECLARE vid_mes INT64;set vid_mes=202605;
    -- call`mm-commissions-reporting.KRT_PYME.pr_sb_creaTablaComisiones`(202605); 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_PYME.COMISIONES` AS 
    --DECLARE vid_mes INT64;set vid_mes=202607;
    select distinct 
    vid_mes as mes_id,
    a.data_source_ds, 
    a. brand_ds, 
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
    coalesce(m.tipo, case when contains_substr(ca.marco,"-CR") then "CARTERA"  when contains_substr(ca.marco,"-CP") then "CAPTACION"end ) as tipo, 
    m.operacion, 
    a.seller,
    `mm-commissions-reporting.KRT_PYME.f_com_excluir_seller`(a.channel_ds,a.seller) as comisiona, 
    ct.concepto as concepto_marco, 
    co.concepto,
    ca.marco, 
    ca.orden, 
    ma.importe,
    a.sale_date,
    a.activation_date,
    a.deactivation_date
    --from ( select * from `mm-commissions-reporting.COMISIONES.activaciones_krt_INTEGRACION` TABLESAMPLE SYSTEM (1 PERCENT) ) a
    from `mm-commissions-reporting.COMISIONES.ACTIVACIONES_KRT` a
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_MARCA_CARTERA` m using(data_source_ds, sell_type, order_type_agg) 
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_CATALOGOS` ct using(data_source_ds, brand_ds, service_type, tariff_id)
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_CANALES` ca on ca.brand_ds=a.brand_ds and ca.master_channel_ds=a.master_channel_ds and ca.subchannel_ds=a.subchannel_ds
    and UPPER(TRIM(ca.tipo))=UPPER(TRIM(m.tipo))
    and case when UPPER(TRIM(a.distribuidor))!='X' or UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) THEN TRUE ELSE FALSE END
    and case when UPPER(TRIM(a.sfid_id))!='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_MARCO` ma using(marco,concepto)
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_CONCEPTO` co on co.concepto_marco=ct.concepto and LOWER(TRIM(co.operacion))="activacion"
    where a.id_mes=vid_mes
    AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.deactivation_date, DATE '2099-12-31')) AS INT64) > vid_mes
    and contains_substr(a.master_channel_ds,"EMPRESA")
    and m.comisiona=1

    UNION ALL

    ----- COMSIONES DISPOSITIVOS DESARROLLO

    --- MPORTANTE DEVICE_SUBSCRIPTION_ID  es el ID DEL TERMINAL, MIENTRAS QUE SERVICE_ID ES EL ID DEL SERVICIO ASOCIADO:


    --DECLARE vid_mes INT64;set vid_mes=202607;
    select distinct 
    vid_mes as mes_id,
    CASE WHEN a. brand_ds='R' THEN 'R' ELSE 'EKTNET' END as data_source_ds, 
    a. brand_ds, 
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
    ca.orden ,
    g.importe,
    a.order_date as sale_date,  
    a.activation_date,
    a.deactivation_date

    -- from ( select * from `mm-commissions-reporting.TEMP.device_base_krt_INTEGRACION` TABLESAMPLE SYSTEM (1 PERCENT) ) a
    from `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT`  a

    ---============================================================================================ 
    --- CRUCE PARA DETERMINAR SI LA VENTAS ES DE CAPTACION O CARTERA EN BASE A VENTA DE SERVICIO 
    ---============================================================================================
    left join `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` v on 
    v.data_source_ds=a.data_source 
    and v.brand_ds=a.brand_ds 
    -- and v.phone_nm =CAST(a.phone_nm AS STRING) 
    and v.service_id = a.service_id 
    and v.id_mes_activacion=vid_mes

    -- left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_MARCA_CARTERA` m on m.data_source_ds=v.data_source_ds and m.sell_type=v.sell_type and m.order_type_agg=v.order_type_agg
    ---======================================================================= 
    --- FIN CRUCE 
    ---=======================================================================

    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_CANALES` ca on ca.brand_ds=a.brand_ds and ca.master_channel_ds=a.master_channel_ds and ca.subchannel_ds=a.subchannel_ds
    and UPPER(TRIM(ca.tipo))=case when  coalesce(v.sell_type,"NOINF")="NEW SALE" THEN "CAPTACION" ELSE "CARTERA" END
    and case when UPPER(TRIM(a.distribuidor))!='X' or UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) THEN TRUE ELSE FALSE END
    and case when UPPER(TRIM(a.sfid_id))!='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_GAMA_TERMINAL` g on coalesce(a.total_pay_value_without_vat,(a.total_pay_value/1.21))between g.minimo and g.maximo 
    left join `mm-commissions-reporting.GS.PARAM_KRT_PYME_CONCEPTO` co on co.concepto_marco=g.gama and LOWER(TRIM(co.operacion))="activacion"
    where a.id_mes_activacion=vid_mes
    AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.deactivation_date, DATE '2099-12-31')) AS INT64) > vid_mes        
    --and a.service_id="151425586"
    and contains_substr(a.master_channel_ds,"EMPRESA")
    QUALIFY  ROW_NUMBER() over (partition by data_source_ds, brand_ds, service_id order by order_date desc)=1;

END