begin

declare sql, prefijo, mes_string string;

set mes_string = cast(mes_int as string);

set prefijo = 'CALD';

set canales_pr = coalesce ( canales_pr, ['MP','MR','MI','CA','EML','PH']);

/*
call  COMISIONES.pr_cald (202404,['MP','MR','MI','CA','EML','PH']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_status_heos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      id_factura

     ,CASE WHEN tipo_evento = "Impago" THEN 'REJECTED' ELSE 'PAID' END AS status

FROM `mm-commissions-reporting.COBROS.HEOS_IMPAGOS`
WHERE fecha IS NOT NULL
QUALIFY ROW_NUMBER () OVER (PARTITION BY id_factura ORDER BY fecha DESC) = 1
)
;


create or replace table `mm-commissions-reporting.TEMP.cald_facturacion` as
select marca, service_id, service_type, 'C - Calidad 6 meses' as concepto , sum(importe_facturado)/6 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -6 month)
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
      and marca not in ('SENIORTELECOM','OPERADORES')
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 12 meses' as concepto , sum(importe_facturado)/12 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -12 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
      and marca not in ('SENIORTELECOM','OPERADORES')
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 24 meses' as concepto , sum(importe_facturado)/24 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -24 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
      and marca not in ('SENIORTELECOM','OPERADORES')
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 36 meses' as concepto , sum(importe_facturado)/36 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -36 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
      and marca not in ('SENIORTELECOM','OPERADORES')
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 48 meses' as concepto , sum(importe_facturado)/48 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -48 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
      and marca not in ('SENIORTELECOM','OPERADORES')
group by 1,2,3
;

create or replace table `mm-commissions-reporting.TEMP.cald_base` as
select
--- primary key ---
prefijo||'_'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
'calculado' as estado,
canal.agrupacion_canal,

--- comision ---
mes_int id_mes,
B.canal,
--- vendedor ---
id_comisionista,
distribuidor,
a.sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
zona_fiscal,
--- servicio ---
a.marca,
a.service_type,
phone_nm,
a.tariff_id,
a.tariff_ds,
a.service_id,
account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
deactivation_date,
order_id,
order_type_agg,
--- variables analiticas ---
cod_segmento,
cod_marca,
a.cod_tipo_contrato,
a.cod_producto,
canal.cod_canal,
--- informacion adicional ---
cast ( null as string ) campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast ( null as string ) claim_code,
cast ( null as string ) process_code,
cast ( null as string ) comments,
--- informacion contabilizacion ---
'C_MANUAL' as facturador,
date_diff (COMISIONES.f_mes_int (mes_int), date_trunc(activation_date, month), month) as delta_meses,
from `mm-commissions-reporting.COMISIONES.v_ventas_base_calidad` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b on
     ( a.sfid_id = b.sfid_id 
  or (a.seller_formato_tms = b.sfid_id)
  or a.seller = b.sfid_id
  or a.sfid_id    || '-' || a.seller = replace ( b.sfid_id , ' ', '') )
  and b.id_mes = mes_int
  and b.comisiona
inner join `mm-commissions-reporting.GS.CANALES` canal on canal.canal = b.canal
cross join unnest(canales_pr) canpr 
where 1=1
and comisionamiento = 'Comisiona'
and coalesce ( deactivation_date , '2099-01-01') >= date_add ( COMISIONES.f_mes_int (mes_int) , interval 1 month)
and date_diff (COMISIONES.f_mes_int (mes_int), date_trunc(activation_date, month), month) in (6,12,24,36,48)
and b.canal = canpr
and not (a.marca in ('YOIGO') and b.canal = 'PH')
--and not (a.marca in ('PEPEPHONE') and b.agrupacion_canal = 'Exclusivo')
and a.order_type_agg in ('ALTA NUEVA', 'PORTABILIDAD', 'STC')
AND (a.seller NOT LIKE 'MLV%' OR a.seller NOT LIKE '%RPORT' OR a.seller NOT LIKE '%RBAJA')
qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by case when id_comisionista = seller then 1 else 0 end desc, length(b.id_comisionista) desc nulls last, comisiona desc ) = 1
;

create or replace table `mm-commissions-reporting.TEMP.cald` as
with
calculos as
(
  select a.*,
  c.concepto,
  c.tipo_concepto,
  1 as unidades,
  case
  when canal in ('MI','CA','NR','MR','MP','PH')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 6 meses','C - Calidad 12 meses')
      then case when t.importe_medio >= 18 then 10 when t.importe_medio >= 14 then 8 else 5 end
  when canal in ('MI','CA','NR','MR','MP')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 24 meses')
      then case when t.importe_medio >= 18 then 20 when t.importe_medio >= 14 then 16 else 10 end
  when canal in ('EML')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 6 meses','C - Calidad 12 meses')
      then case when t.importe_medio >= 25 then 8 when t.importe_medio >= 16 then 6 when t.importe_medio >= 8 then 3 else 0 end
  when canal in ('EML')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 48 meses')
      then case when t.importe_medio >= 25 then 12 when t.importe_medio >= 16 then 10 when t.importe_medio >= 8 then 6 else 0 end   
  end as comision
from `mm-commissions-reporting.TEMP.cald_base` a
inner join `mm-commissions-reporting.TEMP.cald_facturacion` as t on a.marca=t.marca and a.service_type=t.service_type and a.service_id=t.service_id
inner join `mm-commissions-reporting.GS.CONCEPTOS` c on t.concepto = c.concepto
where case delta_meses
  when 6 then 'C - Calidad 6 meses'
  when 12 then 'C - Calidad 12 meses'
  when 24 then 'C - Calidad 24 meses'
  when 36 then 'C - Calidad 36 meses'
  when 48 then 'C - Calidad 48 meses'
end = c.concepto
and t.importe_medio > 1
) 
select *
from calculos
where comision > 0
-- quito la calidad para todos los mediamark que no le corresponde
and cif  not in('A62348107',
'A63907463',
'A63907356',
'A62581988',
'A63905772',
'A63524656',
'A82037292',
'A65281988'
)

;

--- Insertar tabla final ----

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CALD_', mes_int, canales_pr , 'TEMP.cald' , 'ACTUALIZAR');

end