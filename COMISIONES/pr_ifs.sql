begin

--call `mm-commissions-reporting.COMISIONES.pr_ifs` (['7687'], ['PH'], 202312, false);
--call `mm-commissions-reporting.COMISIONES.pr_ifs` (['794'],['PH','BY','ML','CI','DB'], 202311, false);

declare prefijo string default 'IFS_';

create or replace table TEMP.ifs as
select 
---- Cálculo de comisión -----
'IFS_'||transaction_id AS commission_id,
unidades,
comision,
mes_int as id_mes,
COMISIONES.f_mes_int ( mes_int) as mes_liquidado,
concepto,
a.tipo_concepto,
a.facturador,
---- Detalle del servicio -----
a.marca,
a.service_id,
coalesce ( v.account_id, a.account_id ) as account_id,
coalesce ( v.customer_id, a.customer_id ) as customer_id,
a.service_type,
v.line_type_ds,
coalesce ( v.bundle_type, a.bundle_type) as bundle_type,
v.technology_ds,
v.billing_type_ds,
coalesce ( v.phone_nm, a.phone_nm) as phone_nm,
v.sale_date,
coalesce (v.activation_date,a.activation_date) as activation_date,
coalesce (v.deactivation_date,a.deactivation_date) as deactivation_date,
coalesce (v.order_id,a.order_id) as order_id,
v.order_type_agg,
v.port_in_operator_ds,
---- Detalle de la tarifa ----
coalesce ( v.tariff_id, a.tariff_id) tariff_id,
coalesce ( v.tariff_ds, a.tariff_ds) tariff_ds,
---- Variables analiticas ----
coalesce ( v.cod_segmento, a.cod_segmento) as cod_segmento,
'01' as cod_marca,
coalesce ( v.cod_tipo_contrato, a.cod_tipo_contrato) as cod_tipo_contrato,
coalesce ( v.cod_producto, a.cod_producto) as cod_producto,
coalesce ( v.cod_canal, a.cod_canal) as cod_canal,
coalesce (v.agrupacion_canal,a.agrupacion_canal) as agrupacion_canal,
---- Detalle del vendedor ----
coalesce ( v.sfid_id, a.sfid_id) sfid_id,
coalesce ( v.seller, a.seller) seller,
---- Detalles adicionales ----
cast ( null as string ) as campaign_code,
a.claim_code,
CALCULATION_ID as process_code,
cast ( null as string ) as comments,
---- Detalle del comisionista ----
a.id_comisionista,
a.distribuidor,
a.cif,
a.zona_fiscal,
a.nombre_comercio,
a.razon_social,
a.canal,
'calculado' as estado

FROM `mm-commissions-reporting.COMISIONES.v_ifs` a
left join `mm-commissions-reporting.COMISIONES.v_ventas_base` v on
  a.service_id = v.service_id
  and a.service_type = v.service_type
  and v.brand_ds = 'YOIGO'
  AND A.REBATE_TYPE NOT like 'SUBS%' AND a.concepto NOT LIKE 'T%'
  and a.sfid_id=v.sfid_id

cross join unnest(pr_reporting_id) rep_id
cross join unnest(canales_pr) canal_id
WHERE REPORTING_ID = rep_id 
and hierarchy_id  = canal_id
--and a.concepto ='C - Cartera'
--and cif is not null
and hierarchy_id not in ('OUTBOUND')
-- DESCARTAMOS CONCEPTOS DE PH QUE NO DEBEN INSERTARSE. SE CALCULAN EN OTROS PROCESOS.
 AND CONCEPTO NOT IN ('B - Renuevo','B - Venta de sim saldo inicial (init-toup)')
 and concepto not like 'C%'
qualify row_number () over (partition by commission_id order by case when agrupacion_canal = 'No aplica' then 2 else 1 end asc nulls last) = 1
;

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, canales_pr, 'TEMP.ifs'  , 'ACTUALIZAR');
call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, canales_pr, 'TEMP.ifs'  , 'INSERTAR');

if confirmado_ifs then


  update `mm-commissions-reporting.COMISIONES.transacciones`
  set estado = 'confirmado_ifs'
  where commission_id like 'IFS_%'
  and facturador='C_IFS'
  and canal in (select * from unnest(canales_pr) c)
  and estado = 'calculado'
  and id_mes = mes_int
  and process_code in (select * from unnest(pr_reporting_id) d)
  ;

end if;

end