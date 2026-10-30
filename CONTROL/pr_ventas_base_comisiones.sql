begin

-- call `mm-commissions-reporting.CONTROL.pr_ventas_base_comisiones` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.CONTROL.ventas_base_comisiones` as
with
ventas as
(
select

---- Validacion comisionamiento ----
`mm-commissions-reporting.CONTROL.f_identificacion_comisionamiento`(master_channel_ds , channel_ds , subchannel_ds , sfid_id , user_store , seller , sell_line_type_ds , brand_ds , service_type , sell_tariff_id , sell_tariff_ds , billing_type_ds ) as comisionamiento,
---- Detalle del servicio -----
comm_brand_ds as marca,
service_id,
account_id,
customer_id,
service_type,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
phone_nm,
brand_ds,
order_day_id as sale_date,
activation_date,
real_deactivation_date as deactivation_date,
order_id,
---- Detalle de la tarifa ----
tariff_id,
tariff_ds,
/*
b.tariff_ds,
tariff_fee_without_iva,
tariff_fee_fix,
tariff_fee_internet,
tariff_fee_mobile,
tariff_fee_promo,
*/
---- Variables analiticas ----
`mm-commissions-reporting.CONTROL.f_ventas_base_cod_segmento`(segment_ds, brand_ds) as cod_segmento,
`mm-commissions-reporting.CONTROL.f_ventas_base_cod_marca`(comm_brand_ds) as cod_marca,
`mm-commissions-reporting.CONTROL.f_ventas_base_cod_tipo_contrato` (billing_type_ds , service_type , bundle_type , technology_ds , brand_ds, line_type_ds ) as cod_tipo_contrato,
`mm-commissions-reporting.CONTROL.f_ventas_base_cod_producto`(service_type , brand_ds , order_type_agg ) as cod_producto,
`mm-commissions-reporting.CONTROL.f_ventas_base_cod_canal`(channel_ds, subchannel_ds) as cod_canal,
`mm-commissions-reporting.CONTROL.f_clasificacion_canales`(channel_segment_ds , channel_ds , subchannel_ds ) as agrupacion_canal,
---- Detalle del vendedor ----
sfid_id,
seller,
---- Detalle campaña ----
`mm-commissions-reporting.TELEVENTA.f_ventas_lisandro_camp`(sfid_id, seller, brand_ds) as campaign_code
from `mm-datamart-kd.SERVICES.ventas_base_net` a
--left join `mm-datamart-kd.SERVICES.dm_historic_master_tariff` b using (tariff_id, brand_ds, data_source_ds, comm_brand_ds)
where flag_new_order = 'YES'
and billing_type_ds = 'POSTPAID'
--and a.order_day_id between b.init_date and b.end_date
and date_trunc ( a.activation_date, month ) = mes_pr
qualify row_number () over (partition by service_id, service_type, brand_ds order by activation_date desc) = 1
)
select a.*,
b.* except (sfid_id)
from ventas a
left join `mm-commissions-reporting.CONTROL.v_dealers` b on
    a.sfid_id = b.sfid_id 
  or (a.marca = 'YOIGO' and substr(a.sfid_id,1,2) = b.sfid_id)
  or a.seller = b.sfid_id
  or a.sfid_id    || '-' || a.seller = replace ( b.sfid_id , ' ', '')
qualify row_number () over (partition by service_id, service_type, brand_ds order by activation_date desc, id_comisionista asc nulls last) = 1
;

end