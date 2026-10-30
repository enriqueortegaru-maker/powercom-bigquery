begin

declare sql, prefijo, mes_string string;

set mes_string = CAST(id_mes_pr as string);

set prefijo = 'ACTR';

set canales_pr = coalesce (canales_pr, 
(select array_agg (canal) from `mm-commissions-reporting.GS.CANALES` where plantilla_activaciones IN  ('Sin tramos', 'Con tramos'))
);

/*
call  NO_EXCLUSIVO.pr_acti (202211,["MI"]);
*/

-- Actualizar tarifas en el maestro --

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
'ACTI',
current_timestamp()
from `mm-commissions-reporting.COMISIONES.activaciones` a
left join `mm-commissions-reporting.COMISIONES.v_tarifas` b 
on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id and a.id_mes=b.id_mes and a.canal=b.canal
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
cross join unnest (canales_pr) as canal_pr
where a.canal = canal_pr
and b.canal is null
and a.service_type in ('MOBILE','INTERNET')
and a.id_mes = id_mes_pr
;

---------------------------------------

create or replace table `mm-commissions-reporting.TEMP.acti_conceptos` as
with
tarifas_tramos as
(
select
canal,
marca,
service_type,
tariff_id,
tariff_ds,
line_type_ds,
tramo,
comision,
traslados,
migraciones,
gestion_canal,

from `mm-commissions-reporting.COMISIONES.v_tarifas`
unpivot ( comision for tramo in (tramo_1,tramo_2,tramo_3,tramo_4,tramo_5))
where id_mes = id_mes_pr
),
marco as
(

-- Servicio fijo y movil --
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'A - Servicio Movil Pospago' else 'A - Servicio Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')

-- Portabilidad --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'A - Portabilidad Movil Pospago' else 'A - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , false) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')

-- Portabilidad gestion canal--
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'F - Portabilidad Movil Pospago' else 'F - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , true) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')

--  traslados --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
'A - Servicio Fijo Cambio de Domicilio' as concepto, 
'UPFR' AS tipo_concepto,
comision*traslados as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.service_type = 'INTERNET'

--  migraciones --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
'A - Servicio Fijo Cambio de Tecnologia' as concepto, 
'UPFR' AS tipo_concepto,
comision*migraciones as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.service_type = 'INTERNET'

-- Gestion de canal --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'F - Servicio Movil Pospago' else 'F - Servicio Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
gestion_canal as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal in ('MI','CA','EML', 'GUUK', 'EYG', 'EDB', 'ECI','PH')

-- Gestion de canal GPV --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'G - Servicio Movil Pospago' else 'G - Servicio Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
gestion_canal as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal in ('MI','CA')

-- Portabilidad gestion canal GPV--
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'G - Portabilidad Movil Pospago' else 'G - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , true) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal in ('MI','CA')


)
select *
from marco
qualify row_number ()  over (partition by canal, marca, service_type, tariff_id, line_type_ds, concepto,id_comisionista ) = 1
;

--- Calcular tabla de comisiones ---

create or replace table `mm-commissions-reporting.TEMP.acti_comisiones` as
select
--- primary key ---
prefijo||'_'||mes_string||'_'||a.canal||'_'||row_number () over () as commission_id,
--- comision ---
id_mes_pr id_mes,
b.agrupacion_canal,
a.canal,
case when b.billing_type_ds = 'PREPAID' THEN replace (concepto, 'Pospago', 'Prepago') elSE CONCEPTO end as concepto,
tipo_concepto,
1 as unidades,

----Comision----
case when b.agrupacion_canal = 'Exclusivo' and marca in ('MASMOVIL','LLAMAYA','GUUK', 'PEPEPHONE') and b.order_type_agg = 'PORTABILIDAD' and b.portability_group_donor = 'MASMOVIL' then 0.5 else 1 end
*
case
  when b.agrupacion_canal = 'D2D' and concepto = 'A - Servicio Movil Pospago' and tariff_id = 'CONT29' and cod_segmento = '12' then 30
  when b.agrupacion_canal = 'D2D' and concepto = 'A - Servicio Movil Pospago' and tariff_id = 'CONT29' then 25
  when b.agrupacion_canal = 'D2D' and concepto = 'A - Servicio Movil Pospago' and tariff_id = 'CONT28' and cod_segmento = '12' then 10
  when b.agrupacion_canal = 'D2D' and concepto = 'A - Servicio Movil Pospago' and tariff_id = 'CONT28' then 25
  when b.agrupacion_canal = 'Exclusivo' and concepto = 'A - Servicio Movil Pospago' and marca = 'PEPEPHONE' and tariff_id = 'INIMINETFLIX' and bundle_type = 'FMC' and a.line_type_ds = 'MAIN' then 40
  when b.agrupacion_canal = 'Exclusivo' and marca = 'PEPEPHONE' and concepto = 'A - Servicio Movil Pospago' and tariff_id = 'FIJOALOPEPE1' and b.bundle_type = 'MO' then 30
  when b.agrupacion_canal = 'Exclusivo' and marca = 'PEPEPHONE' and concepto = 'A - Servicio Movil Pospago' and tariff_id = 'FIJOALOPEPE1' then 10
  when b.agrupacion_canal = 'Exclusivo' and marca = 'PEPEPHONE' and concepto = 'F - Servicio Movil Pospago' and tariff_id = 'FIJOALOPEPE1' and b.bundle_type = 'MO' then 4.5
  when b.agrupacion_canal = 'Exclusivo' and marca = 'PEPEPHONE' and concepto = 'F - Servicio Movil Pospago' and tariff_id = 'FIJOALOPEPE1' then 0
else comision end as comision,
--- vendedor ---
case when substr (concepto,1,1) in ('F','H')  THEN m.id_comisionista when substr (concepto,1,1) ='G' THEN G.id_comisionista else b.id_comisionista end id_comisionista,
coalesce ( distribuidor, b.id_comisionista ) as distribuidor,
sfid_id,
seller,
case when substr (concepto,1,1) in ('F','H')  THEN m.nombre_comercio when substr (concepto,1,1) ='G' THEN G.nombre_comercio else b.nombre_comercio end nombre_comercio,
case when substr (concepto,1,1) in ('F','H')  THEN m.razon_social when substr (concepto,1,1) ='G' THEN G.razon_social else b.razon_social end razon_social,
case when substr (concepto,1,1) in ('F','H')  THEN m.cif when substr (concepto,1,1) ='G' THEN G.cif else b.cif end cif,
case when substr (concepto,1,1) in ('F','H')  THEN m.zona_fiscal when substr (concepto,1,1) ='G' THEN G.zona_fiscal else b.zona_fiscal end zona_fiscal,
--- servicio ---
b.marca,
b.service_type,
phone_nm,
tariff_id,
tariff_ds,
b.service_id,
account_id,
customer_id,
a.line_type_ds,
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
cod_tipo_contrato,
cod_producto,
coalesce (d.cod_canal, b.cod_canal) as cod_canal,
--- informacion adicional ---
cast ( null as string ) claim_code,
 `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell` (a.canal, b.seller) as campaign_code,
cast ( null as string ) process_code,
comments,
--- informacion contabilizacion ---
'C_MANUAL' as facturador,
from `mm-commissions-reporting.TEMP.acti_conceptos` a
inner join `mm-commissions-reporting.COMISIONES.activaciones` b using ( canal, marca, service_type, tariff_id)
inner join `mm-commissions-reporting.GS.CANALES` d on a.canal=d.canal
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` G on b.cif_gpv = g.cif
cross join unnest(canales_pr) as canal_pr
where 1=1
and not (b.canal in ('EML','EDB','PH','EYG') and id_mes_pr = 202304 and b.marca = 'YOIGO')
and b.canal = canal_pr
and b.id_mes = id_mes_pr
and b.comisionamiento = 'Comisiona'
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'FIX' end = case when b.service_type = 'MOBILE' then b.line_type_ds else 'FIX' end
and coalesce (a.id_comisionista, b.id_comisionista ) = b.id_comisionista
and case
  when concepto in ('F - Portabilidad Movil Pospago', 'F - Portabilidad Fijo','A - Portabilidad Movil Pospago', 'A - Portabilidad Fijo' ,'G - Portabilidad Movil Pospago', 'G - Portabilidad Fijo')
  and not (b.portability_group_donor = 'MASMOVIL' and b.canal in ('MP')) then 'PORTABILIDAD'
  when concepto = 'A - Servicio Fijo Cambio de Domicilio'  then 'CAMBIO DOMICILIO'
  when concepto = 'A - Servicio Fijo Cambio de Tecnologia' then 'CAMBIO TECNOLOGIA'
  when concepto in ('A - Servicio Fijo', 'A - Servicio Movil Pospago','F - Servicio Fijo', 'F - Servicio Movil Pospago','G - Servicio Fijo', 'G - Servicio Movil Pospago') and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC') then b.order_type_agg
  end = b.order_type_agg
and not (coalesce (b.distribuidor,'NA') not in (select id_comisionista from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` ) and substr(a.concepto,1,1) = 'F')
and not (b.cif_gpv is null and substr(a.concepto,1,1) = 'G')
and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC','CAMBIO DOMICILIO','CAMBIO TECNOLOGIA')
and b.cif is not null
and not (b.canal = 'XI' and b.bundle_type = 'FMC' and b.service_type = 'MOBILE' and b.marca = 'YOIGO' and b.line_type_ds = 'MAIN')
;

/*
assert not exists (
  select service_id
  from `mm-commissions-reporting.TEMP.acti_comisiones`
  group by marca, concepto, service_id
  having count(1)>1
);
*/ 

create or replace table `mm-commissions-reporting.TEMP.acti_comisiones_final` as 
select *
from `mm-commissions-reporting.TEMP.acti_comisiones`
where comision != 0 and comision is not null;

--- Insertar tabla final ----

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.acti_comisiones_final'  , 'ACTUALIZAR');

--- Procesos que dependen de ACTI ----

--rappel DO

-- if exists (select 1 from unnest(canales_pr) p where p = 'DO' ) then

-- call `mm-commissions-reporting.COMISIONES.pr_dorp`( id_mes_pr );

-- end if;

-- --rappel OU

-- if exists (select 1 from unnest(canales_pr) p where p = 'OU' ) then

-- call `mm-commissions-reporting.COMISIONES.pr_ourp`( id_mes_pr );

-- end if;

-- --rappel XI, XS

-- if exists (select 1 from unnest(canales_pr) p where p in ('XS','XI') ) then

-- call `mm-commissions-reporting.COMISIONES.pr_xsrp`( id_mes_pr );

-- end if;


-- --rappel EML, EYG, ECI, EDB

-- if exists (select 1 from unnest(canales_pr) p where p in ('EML', 'EYG', 'ECI', 'EDB') ) then

-- call `mm-commissions-reporting.COMISIONES.pr_exrp`( id_mes_pr );

-- end if;

-- --calculos factura

-- call `mm-commissions-reporting.COMISIONES.pr_fact`( id_mes_pr , canales_pr );

-- -- Clawback --

call `mm-commissions-reporting.COMISIONES.pr_cbsr`( id_mes_pr , 'MI' , ['C_MANUAL']);

-----

call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`( false );

end