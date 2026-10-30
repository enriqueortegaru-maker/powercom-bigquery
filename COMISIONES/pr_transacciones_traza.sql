BEGIN


create or replace table `mm-commissions-reporting.COMISIONES.transacciones_traza`
cluster by agrupacion_canal, id_mes, invoice_id, id_comisionista
as
select
id_mes,
agrupacion_canal,
canal,
id_comisionista,
invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
cif,

case when unidades is not null then sfid_id end as sfid_id,
case when unidades is not null then seller end as seller,
case when unidades is not null then marca end as marca,
case when unidades is not null then cod_segmento end as cod_segmento,
case when unidades is not null then service_id end as service_id,
case when unidades is not null then account_id end as account_id,
case when unidades is not null then customer_id end as customer_id,
case when unidades is not null then service_type end as service_type,
case when unidades is not null then bundle_type end as bundle_type,
case when unidades is not null then line_type_ds end as line_type_ds,
case when unidades is not null then phone_nm end as phone_nm,
case when unidades is not null then activation_date end as activation_date,
case when unidades is not null then deactivation_date end as deactivation_date,
case when unidades is not null then sale_date end as sale_date,
case when unidades is not null then order_id end as order_id,
case when unidades is not null then tariff_id end as tariff_id,
case when unidades is not null then tariff_ds end as tariff_ds,

sum(unidades) as unidades,
sum(comision) as comision,

from `mm-commissions-reporting.COMISIONES.transacciones`
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30
;

create or replace table COMISIONES.transacciones_traza_email
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
id_mes,
agrupacion_canal,
canal,
id_comisionista,
invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
cif,

case when unidades is not null then sfid_id end as sfid_id,
case when unidades is not null then seller end as seller,
case when unidades is not null then marca end as marca,
case when unidades is not null then cod_segmento end as cod_segmento,
case when unidades is not null then service_id end as service_id,
case when unidades is not null then account_id end as account_id,
case when unidades is not null then customer_id end as customer_id,
case when unidades is not null then service_type end as service_type,
case when unidades is not null then bundle_type end as bundle_type,
case when unidades is not null then line_type_ds end as line_type_ds,
case when unidades is not null then phone_nm end as phone_nm,
case when unidades is not null then activation_date end as activation_date,
case when unidades is not null then deactivation_date end as deactivation_date,
case when unidades is not null then sale_date end as sale_date,
case when unidades is not null then order_id end as order_id,
case when unidades is not null then tariff_id end as tariff_id,
case when unidades is not null then tariff_ds end as tariff_ds,

sum(unidades) as unidades,
sum(comision) as comision,

from `mm-commissions-reporting.COMISIONES.transacciones`, unnest(	emails_acceso_trazabilidad) email
where estado = 'facturado'
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
;

END