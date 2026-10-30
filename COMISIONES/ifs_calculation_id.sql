begin

--call `mm-commissions-reporting.COMISIONES.ifs_calculation_id` (['7628','	7629','7630'], ['PH'], NULL, 202310);


--call `mm-commissions-reporting.COMISIONES.ifs_calculation_id` (['7629'], ['EYG', 'ECI', 'EDB', 'EML'], 202309);


declare prefijo string default 'IFS__';

create or replace table TEMP.ifs as
select 
---- Cálculo de comisión -----
'IFS__'||transaction_id AS commission_id,
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
'calculado' as estado,
CAST(NULL AS STRING) as serial_number,
CAST(NULL AS FLOAT64) as tax_base
FROM `mm-commissions-reporting.COMISIONES.v_ifs` a
left join `mm-commissions-reporting.COMISIONES.v_ventas_base` v on
  a.service_id = v.service_id
  and a.service_type = v.service_type
  and v.brand_ds = 'YOIGO'
  and a.sfid_id=v.sfid_id
cross join unnest(pr_calculation_id) calc_id
cross join unnest(canales_pr) canal_id
cross join unnest(conceptos_pr) concept_pr
WHERE CALCULATION_ID = calc_id 
and canal  = canal_id
and concepto = concept_pr
--and cif is not null
--and A.hierarchy_id  IN ('CT','RC','TO')
AND A.sfid_id NOT LIKE 'PH888%'
--AND REPORTING_ID = '776'
--and concepto = 'E - Clawback Reparacion Terminal (Anovo)'
qualify row_number () over (partition by commission_id order by case when agrupacion_canal = 'No aplica' then 2 else 1 end asc nulls last) = 1
;

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, canales_pr, 'TEMP.ifs'  , 'INSERTAR');

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('IFS', 202309, ["PH"], 'TEMP.ifs'  , 'INSERTAR');

end