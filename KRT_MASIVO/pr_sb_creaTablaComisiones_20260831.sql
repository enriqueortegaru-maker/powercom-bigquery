BEGIN

  --DECLARE vid_mes INT64 DEFAULT 202608;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.COMISIONES` AS
  --DECLARE vid_mes INT64 DEFAULT 202608;
  WITH
  catalogo_patron AS (
    SELECT data_source_ds, brand_ds, service_type, tariff_id, objeto, concepto
    FROM `mm-commissions-reporting.GS.PARAM_KRT_MAS_CATALOGOS`
    WHERE criterio = 'PATRON'
  ),
  catalogo_rango AS (
    SELECT data_source_ds, brand_ds, service_type, tariff_id, minimo, maximo, concepto
    FROM `mm-commissions-reporting.GS.PARAM_KRT_MAS_CATALOGOS`
    WHERE criterio = 'RANGO'
  ),
  catalogo_exacto AS (
    SELECT data_source_ds, brand_ds, service_type, tariff_id, concepto
    FROM `mm-commissions-reporting.GS.PARAM_KRT_MAS_CATALOGOS`
    WHERE criterio = 'CATALOGO'
  ),
  servicios_distintos AS (
    SELECT DISTINCT data_source_ds, brand_ds, service_type, tariff_id, tariff_ds
    FROM `mm-commissions-reporting.COMISIONES.ACTIVACIONES_KRT`
    WHERE id_mes = vid_mes
  ),
  catalogo_resuelto AS (
    SELECT
      s.data_source_ds,
      s.brand_ds,
      s.service_type,
      s.tariff_id,
      s.tariff_ds,
      COALESCE(p.concepto, r.concepto, e.concepto) AS concepto,
      CASE
        --WHEN p.concepto IS NOT NULL THEN 'PATRON'
        --WHEN r.concepto IS NOT NULL THEN 'RANGO'
        --WHEN e.concepto IS NOT NULL THEN 'CATALOGO'
        WHEN p.concepto IS NOT NULL THEN CAST(1 AS INT64)
        WHEN r.concepto IS NOT NULL THEN CAST(3 AS INT64)
        WHEN e.concepto IS NOT NULL THEN CAST(5 AS INT64)
      END AS grid
    FROM servicios_distintos s
    LEFT JOIN catalogo_patron p
      ON p.data_source_ds = s.data_source_ds
      AND p.brand_ds       = s.brand_ds
      AND p.service_type   = s.service_type
      AND STRPOS(
            REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(s.tariff_ds)), NFD), r"\pM|[^a-z0-9]", ""),
            REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(p.objeto)),    NFD), r"\pM|[^a-z0-9]", "")
          ) > 0
    LEFT JOIN catalogo_rango r
      ON r.data_source_ds = s.data_source_ds
      AND r.brand_ds       = s.brand_ds
      AND r.service_type   = s.service_type
      AND p.concepto IS NULL
      AND (
        CASE
          WHEN s.service_type = 'BROADBAND' THEN
            CASE
              WHEN CONTAINS_SUBSTR(s.tariff_ds, '1GBPS')    THEN 1000
              WHEN CONTAINS_SUBSTR(s.tariff_ds, '500MBPS') THEN 500
            END
          WHEN s.service_type = 'MOBILE' THEN
            CASE
              WHEN CONTAINS_SUBSTR(s.tariff_ds, 'INFINITY')
                OR CONTAINS_SUBSTR(s.tariff_ds, 'GB ILIM')
                OR CONTAINS_SUBSTR(s.tariff_ds, 'GBILIM')  THEN 999999
              WHEN CONTAINS_SUBSTR(s.tariff_ds, '50GB')    THEN 50000
            END
        END
      ) BETWEEN r.minimo AND r.maximo
    LEFT JOIN catalogo_exacto e
      ON e.data_source_ds = s.data_source_ds
      AND e.brand_ds       = s.brand_ds
      AND e.service_type   = s.service_type
      AND e.tariff_id      = s.tariff_id
      AND p.concepto IS NULL
      AND r.concepto IS NULL
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY s.data_source_ds, s.brand_ds, s.service_type, s.tariff_id, s.tariff_ds
      ORDER BY
        CASE WHEN p.concepto IS NOT NULL THEN 1 WHEN r.concepto IS NOT NULL THEN 2 ELSE 3 END,
        p.concepto, r.concepto, e.concepto
    ) = 1
  )

  select distinct
  vid_mes as mes_id,
  a.data_source_ds,
  a.brand_ds,

a.channel_segment_ds,
a.channel_type_ds,

  a.master_channel_ds,
  a.channel_ds,
  a.subchannel_ds,

a.agrupacion_canal_ventas_base,
a.agrupacion_canal,
a.canal,

  mo.nombre_acreedor_ds as distribuidor,

a.id_comisionista,
a.nombre_comercio,
a.user_store,

  a.sfid_id,
  a.service_type,

a.technology_ds,

  a.tariff_id,
  a.tariff_ds,
  `mm-commissions-reporting.KRT_MASIVO.f_creaSegmento`(a.cod_Segmento) segment_ds,

a.sub_segment_ds,

  a.customer_id,

a.contract_id,
a.account_id,
a.hash_document_number,
a.province,
a.zip_code,
a.line_type_ds,
a.service_id,

  a.service_id as id,
  CAST(NULL AS STRING) id_subscription_terminal,

CAST(NULL AS STRING) as terminal_model,

  CAST(NULL AS FLOAT64) total_pay_value_without_vat,
  CAST(NULL AS FLOAT64) total_pay_value,
  a.phone_nm,
  a.sell_type,
  
a.bundle_type,

  a.order_type_agg,

a.flag_order,
a.order_fix_id,
a.order_id,
a.campaign_code,

  m.tipo,
  m.operacion,
  a.seller,

a.creado,
a.creado_por,
a.port_in_operator_ds,
a.portability_group_donor,
a.portability_operator_donor,

  m.comisiona,
  `mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(ct.concepto, a.service_type, line_type_ds, order_type_agg) as concepto_marco,
  co.concepto,
  ca.marco,
  ca.grupo_rappel,
  st.orden,
  ma.importe,
  a.sale_date,

    a.cancellation_day_id,  

  a.activation_date,
  a.deactivation_date,

a.deactivation_reason_ds,
ct.grid

  from `mm-commissions-reporting.COMISIONES.ACTIVACIONES_KRT` a
  left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` tr on tr.mo.sfid=a.sfid_id
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_MARCA_CARTERA` m using(data_source_ds, sell_type, order_type_agg)
  left join catalogo_resuelto ct using(data_source_ds, brand_ds, service_type, tariff_id, tariff_ds)
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CANALES` ca
    on UPPER(TRIM(ca.brand_ds))=UPPER(TRIM(a.brand_ds))
    and UPPER(TRIM(ca.N1))= UPPER(TRIM(tr.mo.N1))
    and UPPER(TRIM(ca.N0)) =UPPER(TRIM(tr.mo.N0))
    and case when UPPER(TRIM(ca.distribuidor))='X' or UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) THEN TRUE ELSE FALSE END
    and case when UPPER(TRIM(ca.sfid))='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
    and UPPER(TRIM(ca.tipo))=UPPER(TRIM(m.tipo))
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_MARCO` ma on ma.tipo=m.tipo and ma.marca=ca.brand_ds and ma.marco=ca.marco and ma.concepto=`mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(ct.concepto, service_type, line_type_ds, order_type_agg)
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CONCEPTO` co
    ON STRPOS(
         REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(
           `mm-commissions-reporting.KRT_MASIVO.f_generadorDeConceptoMarco`(ct.concepto, service_type, line_type_ds, order_type_agg)
         )), NFD), r"\pM", ""),
         REGEXP_REPLACE(NORMALIZE(LOWER(TRIM(co.concepto_marco)), NFD), r"\pM", "")
       ) > 0
       and LOWER(TRIM(co.operacion))="activacion"
  left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxSERVICE_TYPE` st
    on st.brand_ds=a.brand_ds
    and st.tipo=m.tipo
    and st.subchannel_ds=a.subchannel_ds
    and st.service_type=a.service_type
    and st.segmento= `mm-commissions-reporting.KRT_MASIVO.f_creaSegmento`(a.cod_Segmento)
    and st.estado="ACTIVO"
    and st.detalle not in ("POSTVENTA")
  where a.id_mes=vid_mes
  AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.deactivation_date, DATE '2099-12-31')) AS INT64) > vid_mes
  and not contains_substr(a.master_channel_ds,"EMPRESA")
  and a.data_source_ds="MYSIM"
  and a.sfid_id=tr.mo.sfid
  and m.comisiona=1
  ---and a.service_id="73176925"




  UNION ALL

  --DECLARE vid_mes INT64 DEFAULT 202608;

  --- PENDIENTE 
  ---   1. VALIDAR CAUSA NINGUNA VENTA
  ---   2. INTEGRAR IMPORTE TRAS CRUCE CON MARCO
  ---   3.  

  select distinct
  vid_mes as mes_id,
  CASE WHEN a.brand_ds='R' THEN 'R' ELSE 'EKTNET' END as data_source_ds,
  a.brand_ds,

    a.channel_segment_ds,
    a.channel_type_ds,

  a.master_channel_ds,
  a.channel_ds,
  a.subchannel_ds,

    CAST(NULL AS STRING) as agrupacion_canal_ventas_base, 
    a.agrupacion_canal,
    a.canal,

  mo.nombre_acreedor_ds as distribuidor,

    CAST(NULL AS INT64) as id_comisionista, 
    a.nombre_comercio,
    a.user_store,


  a.sfid_id,
  'DEVICE' as service_type,

    a.technology_ds,

  a.tariff_id,
  a.tariff_ds,
  a.segment_ds,

    CAST(NULL AS STRING) as sub_segment_ds, 

  a.customer_id,

    a.contract_id,
    a.account_id,
    v.hash_document_number,
    v.province,
    v.zip_code,
    a.line_type_ds,

  a.service_id,

  a.service_id as id,
  a.id_subscription_terminal,
  a.terminal_name as terminal_model,
  a.total_pay_value_without_vat,
  a.total_pay_value,
  CAST(a.phone_nm AS STRING) phone_nm,
  v.sell_type,

    a.bundle_type,

  a.order_type_agg,

    v.flag_order,
    v.order_fix_id,
    a.order_id, 
    CAST(NULL AS STRING) as campaign_code, 

  case when coalesce(v.sell_type,"NOINF")="NEW SALE" THEN "CAPTACION" ELSE "CARTERA" END as tipo,
  "ALTA" as operacion,
  a.seller,

    CAST(NULL AS STRING) as creado, 
    CAST(NULL AS STRING) as creado_por,
    v.port_in_operator_ds,
    v.portability_group_donor,
    v.portability_operator_donor,


  -- `mm-commissions-reporting.KRT_PYME.f_com_excluir_seller`(a.channel_ds,a.seller) as comisiona,
  1 as comisiona,
  g.gama as concepto_marco,
  co.concepto,
  ca.marco,
  ca.grupo_rappel,
  st.orden,
  0 importe,
  a.order_date as sale_date,

    v.cancellation_day_id,

  a.activation_date,

  a.deactivation_date,

    v.deactivation_reason_ds,


  CAST(NULL AS INT64) AS grid

  from `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT` a
  left join `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` tr on tr.mo.sfid=a.sfid_id
  left join `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` v on
    v.data_source_ds=a.data_source
    and v.brand_ds=a.brand_ds
    and v.service_id = a.service_id
    and v.id_mes_activacion=vid_mes
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CANALES` ca
    on UPPER(TRIM(ca.brand_ds))=UPPER(TRIM(a.brand_ds))
    and UPPER(TRIM(ca.N1))= UPPER(TRIM(tr.mo.N1))
    and UPPER(TRIM(ca.N0)) =UPPER(TRIM(tr.mo.N0))
    and UPPER(TRIM(ca.tipo))=case when coalesce(v.sell_type,"NOINF")="NEW SALE" THEN "CAPTACION" ELSE "CARTERA" END
    and case when UPPER(TRIM(ca.distribuidor))='X' or UPPER(TRIM(a.distribuidor))=UPPER(TRIM(ca.distribuidor)) THEN TRUE ELSE FALSE END
    and case when UPPER(TRIM(ca.sfid))='X' or UPPER(TRIM(a.sfid_id))=UPPER(TRIM(ca.sfid)) THEN TRUE ELSE FALSE END
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_GAMA_TERMINAL` g on coalesce(a.total_pay_value_without_vat,(a.total_pay_value/1.21)) between g.minimo and g.maximo
  left join `mm-commissions-reporting.GS.PARAM_KRT_MAS_CONCEPTO` co
    ON STRPOS(LOWER(TRIM(g.gama)), LOWER(TRIM(co.concepto_marco))) > 0 and LOWER(TRIM(co.operacion))="activacion"
  left join `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxSERVICE_TYPE` st
    on st.brand_ds=a.brand_ds
    and st.subchannel_ds=a.subchannel_ds
    and st.service_type='DEVICE'
    and st.segmento= a.segment_ds
    and st.estado="ACTIVO"
    and st.detalle not in ("POSTVENTA")
  where a.id_mes_activacion=vid_mes
  AND CAST(FORMAT_DATE('%Y%m', COALESCE(a.deactivation_date, DATE '2099-12-31')) AS INT64) > vid_mes
  and not contains_substr(a.master_channel_ds,"EMPRESA")
  and data_source_ds="MYSIM"
  QUALIFY ROW_NUMBER() over (partition by data_source_ds, brand_ds, id_subscription_terminal order by order_date desc)=1;



END