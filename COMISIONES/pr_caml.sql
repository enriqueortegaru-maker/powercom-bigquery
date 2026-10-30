begin


declare sql , prefijo , mes_string string;
declare id_mes_periodo_facturado int64;
declare mes_periodo_facturado date;

set prefijo = 'CAML';

set mes_string = cast(id_mes_pr as string);

set mes_periodo_facturado = date_add( parse_date ( '%Y%m', cast (id_mes_pr as string)) , interval  - 1 month );

set id_mes_periodo_facturado = cast ( format_date ('%Y%m', mes_periodo_facturado) as int64 );

--call COMISIONES.pr_caml (202308)

create or replace table TEMP.caml as

with

billing_status as
(
select invoice_no, status
--from `mm-datamart-kd.COBROS.payment_status_invoices` l
FROM `mm-commissions-reporting.TEMP.payment_status_invoices` l
where 1=1
qualify row_number () over (partition by invoice_no order by order_by desc ) = 1
),

billing as

(
SELECT 'YOIGO' as marca, service_id, coalesce (status,'PAID') as status,
case
when bill_id like '%CONVDISC%' then 'INTERNET'
when bill_id like 'FH%DISC%' then 'INTERNET'
when service_type = 'FIX' then 'INTERNET'
else 'MOBILE' END as service_type,
sum(imp_without_tax) as importe_facturado
FROM `mm-datamart-kd.BILLING.billing_detail_qvantel`
left join billing_status on invoice_id=invoice_no
where data_month_id = id_mes_periodo_facturado
--and ( bill_id like 'CONT%' or bill_id like '%DISC%' or bill_id like '1%'  or bill_id  = 'REJECTION_FEE' or bill_id = 'RECONNECTION') --or bill_id like 'AGILE%'
and service_type in ('MOBILE')
group by 1,2,3,4

union all 

select brand_ds as marca, service_id, coalesce (status,'PAID') as status,
service_type, sum(imp_without_tax) as importe_facturado
FROM `mm-datamart-kd.BILLING.billing_detail_emysim` a
left join billing_status on a.invoice_id=invoice_no
where data_month_id = id_mes_periodo_facturado
and service_type in ( 'MOBILE')
group by 1,2,3,4

)
select 
a.* except(sfid_id, agrupacion_canal),
b.*,
prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () as commission_id,
1 as unidades,
CASE WHEN billing_type_ds = 'POSTPAID' THEN importe_facturado * 0.06
     WHEN billing_type_ds = 'PREPAID'  THEN importe_facturado * 0.05 END as comision,
'C - Cartera' as concepto,
'AIRT' as tipo_concepto,
'C_MANUAL' as facturador,
--- informacion adicional ---
cast ( null as string ) as campaign_code,
cast ( null as string ) as process_code,
'calculado' as estado
from `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b
on seller_formato_tms = b.sfid_id and b.id_mes = id_mes_pr
and b.agrupacion_canal = 'Exclusivo'
left join billing c using (service_id, service_type, marca)
where 1=1
and a.marca = 'YOIGO'
and a.seller_formato_tms = 'BY'
and a.line_type_ds NOT IN ('INTERNET', 'FIX')
and coalesce (a.deactivation_date, '2100-01-01') >= date_add(mes_periodo_facturado, interval 1 month)
--and status in ('PAID', 'RECOLLECTED')
and canal in ( "EYG" )
;


call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['EYG'] , 'TEMP.caml' , 'ACTUALIZAR');

end