begin

-- call `mm-commissions-reporting.COMISIONES.pr_ventas_mes`(202608)

begin transaction;

delete `mm-commissions-reporting.COMISIONES.ventas_mes`
where id_mes = id_mes_pr;

INSERT INTO `mm-commissions-reporting.COMISIONES.ventas_mes` (

select
  id_mes_pr as id_mes,
  CASE WHEN a.comisionamiento = 'Comisiona' AND NOT b.comisiona THEN CONCAT('No Comisiona - sfid: ', a.seller) ELSE a.comisionamiento END AS comisionamiento,
  a.marca ,
  a.brand_ds ,
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
  COALESCE( a.deactivation_date , a.cancellation_day_id) AS deactivation_date,
  a.order_id ,
  a.order_type_agg ,
  a.tariff_id ,
  a.tariff_ds ,

  a.cod_segmento ,
  a.cod_marca ,
  a.cod_tipo_contrato ,
  a.cod_producto ,
  a.cod_canal ,


  TLV_CAMP.campaign AS campaign_code,

  CASE WHEN A.marca = 'SIMYO' AND b.CANAL= 'ALTN' THEN a.sfid_id ELSE a.seller END AS seller,

  
  a.order_fix_id ,
  a.claim_code ,
  a.comments ,
  a.data_source_ds ,
  a.sociedad ,
  a.seller_formato_tms ,
  a.agrupacion_canal as agrupacion_canal_ventas_base ,
  coalesce (b.agrupacion_canal , a.agrupacion_canal) as agrupacion_canal,
  b.id_comisionista,
  CASE WHEN B.CANAL = 'PH' THEN 'PHH00000' ELSE b.distribuidor END AS distribuidor,
  b.canal ,
  b.comisiona ,
  b.nombre_comercio ,
  b.razon_social ,
  b.cif ,
  b.zona_fiscal ,
  b.comentarios ,
  b.cif_gpv ,
  b.creado_por ,
  b.creado ,
  a.sfid_id as sfid_original,
  -- coalesce ( b.sfid_id , a.sfid_id) as sfid_id,
  CASE WHEN A.marca ='SIMYO' AND b.CANAL= 'ALTN' THEN a.user_store ELSE COALESCE ( b.sfid_id , a.sfid_id) END AS sfid_id,
  a.portability_group_donor ,
  a.portability_operator_donor ,
  a.billing_tier
  
from `mm-commissions-reporting.COMISIONES.ventas_comisiones` a
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`  b on
     ( a.sfid_id = b.sfid_id 
  or (a.seller_formato_tms = b.sfid_id AND a.agrupacion_canal NOT IN ('No Exclusivo'))
  or a.seller = b.sfid_id
  or a.sfid_id    || '-' || a.seller = replace ( b.sfid_id , ' ', '') 
  or a.user_store = b.sfid_id)



LEFT JOIN  `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
  ON b.id_comisionista = TLV_CAMP.id_comisionista 
  AND b.canal = TLV_CAMP.canal


LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo` I
ON a.account_id = I.account_id
AND a.phone_nm = CAST(I.phone_nm AS STRING)
AND  I.mes_venta = id_mes_pr

where 1=1
and ( a.billing_type_ds = 'POSTPAID' or (a.billing_type_ds = 'PREPAID' and b.canal in ('DOT','WA','BO','CI','XI','XIBO')))
and (COALESCE(a.seller, 'a') NOT LIKE 'MLV%' OR COALESCE(a.seller, 'a')  NOT LIKE '%RPORT' OR COALESCE(a.seller, 'a')  NOT LIKE '%RBAJA') 
and date_trunc (a.sale_date, month) = COMISIONES.f_mes_int ( id_mes_pr )
AND MARCA IN ('ORANGE','JAZZTEL','SIMYO')
AND b.agrupacion_canal IN ('TLV - Cross-sell','TLV - Outbound','TLV - Negocios')
AND NOT (order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' AND b.canal IN ('ENX','EML','EYG','EDB'))
qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by case when id_comisionista = seller then 1 else 0 end desc, length(b.id_comisionista) desc nulls last, comisiona desc) = 1
)
;

insert into COMISIONES.tarifas 
select 
distinct
a.canal,
a.id_mes,
a.marca,
a.service_type,
a.tariff_id, 
a.tariff_ds,
case when a.service_type = 'MOBILE' then a.line_type_ds end as line_type_ds,
b.pvp,
b.tramo_1,
b.tramo_2,
b.tramo_3,
b.tramo_4,
b.tramo_5,
b.migraciones,
b.traslados,
b.gestion_canal,
b.cuota,
b.consumo,
a.campaign_code,
'ACTI',
current_timestamp()


from `mm-commissions-reporting.COMISIONES.ventas_mes`  a
left join `mm-commissions-reporting.COMISIONES.v_tarifas` b 
on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id and a.id_mes=b.id_mes and a.canal=b.canal and a.tariff_ds = b.tariff_ds
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
where b.canal is null
and a.service_type in ('MOBILE','INTERNET')
and a.id_mes = id_mes_pr

;


UPDATE `mm-commissions-reporting.COMISIONES.ventas_mes` ACTIVACIONES
SET tariff_id = CAST(MAESTRO.TARIFF_KEY AS STRING)
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` VENTAS
LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tarifas_20260123` MAESTRO
  ON VENTAS.sell_service_tariff_id = MAESTRO.TARIFF_ID
 AND VENTAS.sell_tariff_ds = MAESTRO.TARIFF_DES
WHERE ACTIVACIONES.service_id = VENTAS.service_id
  AND ACTIVACIONES.id_mes = id_mes_pr
  AND ACTIVACIONES.tariff_id IS NULL
  AND MAESTRO.TARIFF_KEY IS NOT NULL

;

END