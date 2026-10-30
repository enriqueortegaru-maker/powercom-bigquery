begin

-- call `mm-commissions-reporting.ORANGE.pr_activaciones`(202408)

begin transaction;

delete `mm-commissions-reporting.ORANGE.activaciones`
where id_mes = id_mes_pr;

insert into `mm-commissions-reporting.ORANGE.activaciones`
select
  id_mes_pr as id_mes,
  -- CASE WHEN a.comisionamiento = 'Comisiona' AND NOT b.comisiona THEN CONCAT('No Comisiona - sfid: ', a.seller) ELSE a.comisionamiento END AS comisionamiento,
    'Comisiona' as comisionamiento,
  a.brand_ds as marca ,
  a.brand_ds ,
  a.service_id ,
  a.account_id ,
  a.customer_id ,
  a.service_type ,
  a.line_type_ds ,
  a.bundle_type ,
  a.technology_ds ,
  a.billing_type_ds ,
  cast(a.phone_nm as string) as phone_nm,
  a.done_date as sale_date ,
  a.activation_date ,
  a.deactivation_date ,
  -- a.order_fix_id,
  a.order_type_agg ,
  coalesce ( a.sell_bundle_id , a.tariff_id) as tariff_id ,
  a.bundle_name AS tariff_ds ,
  case when a.segment_ds ='SOHO' then '12' ELSE '10' END AS  cod_segmento ,
  CASE WHEN a.brand_ds = 'TELECABLE' THEN '50'
       WHEN a.brand_ds = 'VIRGIN' THEN '51'
       WHEN a.brand_ds = 'RACC' THEN '52'
       WHEN a.brand_ds = 'EUSKALTEL'THEN '53'
            end as cod_marca,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato` (a.billing_type_ds,a.service_type,a.bundle_type,a.technology_ds, a.brand_ds , a.line_type_ds ) as cod_tipo_contrato ,
--  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(service_type, brand_ds, order_type_agg, sell_type )  as cod_producto ,
'' as cod_producto,
 `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal` (a.channel_ds, a.subchannel_ds )  as cod_canal ,
  a.seller ,
  a.order_fix_id ,
  '' as claim_code ,
  '' as comments ,
  a.data_source_ds ,
  'XX20' AS sociedad ,
  SUBSTRING(a.seller,1,2) as seller_formato_tms ,
  -- `mm-commissions-reporting.REPORTING.f_agrupacion_canal`(canal) as agrupacion_canal_ventas_base ,
  -- '' as agrupacion_canal
  --coalesce (b.agrupacion_canal , a.agrupacion_canal) as agrupacion_canal,
  b.agrupacion_canal,
  b.sfid,
  b.NOMBRE ,
  b.canal ,
'' as comisiona ,
  b.razon_social AS empresa,
  b.razon_social ,
  b.cif ,
  b.CODIGO_IMPUESTO_SAP ,
  '' as comentarios ,
'' as  cif_gpv ,
 '' as creado_por ,
  -- b.creado ,
  a.sfid_id as sfid_original,
  coalesce ( b.sfid , a.sfid_id) as sfid_id,
  a.port_in_operator_ds as portability_group_donor ,
  a.port_in_operator_ds as portability_operator_donor ,
  '' intercompany_portability
from `mm-datamart-kd.JV_ORANGE.ventas_base_telco_osp`  a
left join  `mm-commissions-reporting.COMISIONES.DEALER_ORANGE` b
on a.sfid_id=b.SFID
where a.sfid_id ='19140539'
-- and ( a.billing_type_ds = 'POSTPAID' or (a.billing_type_ds = 'PREPAID' and b.canal in ('WA','XI','XS','XO','XOF')))
-- and (a.seller NOT LIKE 'MLV%' OR a.seller NOT LIKE '%RPORT' OR a.seller NOT LIKE '%RBAJA') --<----- sfid de baja que se coge sin querer cuando se sacan los dealers de Exclusivo
--and b.agrupacion_canal ='Guuk'
--and b.comisiona
and date_trunc (a.activation_date, month) = COMISIONES.f_mes_int ( id_mes_pr )
-- and a.agrupacion_canal = b.agrupacion_canal
qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by case when sfid = sfid_id then 1 else 0 end desc, length(b.sfid) desc nulls last, comisiona desc) = 1
-- and a.agrupacion_canal ='Exclusivo'  --eo
;



insert into ORANGE.tarifas 
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
'ACTI',
current_timestamp()
from `mm-commissions-reporting.ORANGE.activaciones` a
left join `mm-commissions-reporting.ORANGE.v_tarifas` b 
on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id and a.id_mes=b.id_mes and a.canal=b.canal
and case when a.service_type = 'MOVIL' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
where b.canal is null
and a.service_type in ('MOVIL','FTTH')
and a.id_mes = id_mes_pr
-- and a.agrupacion_canal ='Exclusivo' --'eo'
;

commit transaction;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;

end