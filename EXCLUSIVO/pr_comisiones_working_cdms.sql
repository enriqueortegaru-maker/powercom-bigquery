begin
-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_cdms`(date_trunc(date_add (current_date (), interval -1 month), month));

declare clave string;

set clave = 'CDMS';

create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_working_cdms` as

-- migraciones mySIM
select
clave||'_TLV_'||format_date('%Y%m', mes_pr)||row_number () over() AS id_registro,
'X001' sociedad,
billing_dealer as id_comisionista,
'DEA' as tipo_comisionista,
documento,
b.zona_fiscal,
'UPFR' as tipo_concepto,
case
  when order_type_agg = 'CAMBIO DOMICILIO' then 'A - Servicio Fijo Cambio de Domicilio'
  when order_type_agg = 'CAMBIO TECNOLOGIA' then 'A - Servicio Fijo Cambio de Tecnologia' 
end as descripcion_concepto,
1 as uds,
10 as importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'27' as cod_canal,
case
  when order_type_agg = 'CAMBIO DOMICILIO' then '039'
  when order_type_agg = 'CAMBIO TECNOLOGIA' then '041' 
end as cod_producto,
case
  when a.bundle_type = 'FMC' then (case when a.Technology_ds = 'ADSL' then '60' else '61' end)
  else  (case when a.Technology_Ds = 'ADSL' then '62' else '63' end)
  end as cod_tipo_contrato,
case
  when upper(Brand_Ds) = 'MASMOVIL' then '05'
  when upper(Brand_Ds) = 'PEPEPHONE' then '06'
  when upper(Brand_Ds) = 'GUUK' then '13'
  when upper(Brand_Ds) = 'LLAMAYA' then '04'
  when upper(Brand_Ds) = 'YOIGO' then '01'
  else '99'
end as cod_marca,
'999' as cod_operador,
case
  when segment_ds = 'NEGOCIOS' then '12'
  when upper(Brand_Ds) = 'GUUK' then '10'
  when upper(Brand_Ds) = 'LLAMAYA' then '10'
  when segment_ds = 'B2C' then '10'
  when segment_ds = 'SOHO' then '12'
  when segment_ds = 'B2B' then '12'
  when segment_ds = 'B2B' then '12'
else '10' end as cod_segmento,
'C_MANUAL' AS facturador,
'A - Servicio base' as clasificacion_concepto,
'LB' as canal,
service_id as subscription_id,
'INTERNET' as product_type,
bundle_type,
cast ( phone_nm as string ) as msisdn,
activation_date as fecha_activacion,
deactivation_date as fecha_baja,
account_id,	
customer_id,		
sfid_id as sale_dealer,
sfid_id as tienda,
distribuidor,
mes_pr as fecha,
CONTROL.f_cod_tipo_contrato_a_agrupacion_cod_tipo_contrato
(
case
  when a.bundle_type = 'FMC' then (case when a.technology_ds = 'ADSL' then '60' else '61' end)
  else  (case when a.technology_ds = 'ADSL' then '62' else '63' end)
  end
)
 as agrupacion_cod_tipo_contrato,
CONTROL.f_cod_segmento_a_segmento (case
  when segment_ds = 'NEGOCIOS' then '12'
  when upper(Brand_Ds) = 'GUUK' then '10'
  when upper(Brand_Ds) = 'LLAMAYA' then '10'
  when segment_ds = 'B2C' then '10'
  when segment_ds = 'SOHO' then '12'
  when segment_ds = 'B2B' then '12'
  when segment_ds = 'B2B' then '12'
else '10' end) as segmento,
razon_social,
nombre as nombre_comercio, 
brand_ds as marca,
order_fix_id as order_id,
tariff_ds as product_id,
TELEVENTA.f_clasificacion_m_t (tariff_ds) as product,
user_store as user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from `mm-datamart-kd.SERVICES.ventas_base_net` a
inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` b on substr(a.sfid_id,1,2) = b.billing_dealer
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = b.documento
where 1=1
and order_type_agg in ('CAMBIO DOMICILIO','CAMBIO TECNOLOGIA')
and channel_segment_ds = 'RESIDENCIAL'
and line_type_ds = 'FIX'
and DATE_TRUNC(activation_date, MONTH) = mes_pr
--and canal in ('WA', 'XS')
;

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'EXCLUSIVO.comisiones_working_cdms',
  'EXCLUSIVO.comisiones_working'
);


end