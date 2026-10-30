begin

-- call `mm-commissions-reporting.COMISIONES.pr_prov`(null);
-- call `mm-commissions-reporting.COMISIONES.pr_prov`(['ACTIVACIONES']);
-- call `mm-commissions-reporting.COMISIONES.pr_prov`(['TV','RENUEVO']);
-- call `mm-commissions-reporting.COMISIONES.pr_prov`(['SOLO VISTAS']);

declare tipo_concepto_pr array<string> default ['UPFR', 'TJTV' ,'TJTS'];

declare tipos_conceptos_analizados array<string> default ['UPFR', 'TJTV' ,'TJTS','GENE','ICOX','DUSI','CSFI', 'OTRS','AIRT','CURE'];

declare sql string;

declare mes_int int64;

declare canales_pr array<string>;

set procesos_pr = coalesce (procesos_pr, ['ACTIVACIONES', 'TV', 'CALIDAD', 'AIML', 'RENUEVO']);

set mes_int = cast(format_date('%Y%m', date_add(current_date(), interval - 1 month)) as int64);


set canales_pr =  ['MP','MR','MI','CA','PH','NR','EML','EYG'] ;

--- servicios internet y mobil ---

if exists (select 1 from unnest(procesos_pr) p where p = 'ACTIVACIONES' ) then

call COMISIONES.pr_activaciones (cast ( format_date ('%Y%m', current_date()) as int64));

-- Ventas canalizadas del mes n-1 y mes n --

create or replace table TEMP.prov_ventas_base as
  SELECT
    activation_date, 
    deactivation_date,
    service_id,
    cod_canal,
    cod_marca,
    cod_segmento,
    cod_tipo_contrato,
    cod_producto,
    agrupacion_canal,
    canal,
    marca,
    coalesce (bundle_type,'NA') as bundle_type,
    coalesce (service_type,'NA') as service_type,
    case
      when service_type = 'INTERNET' then 'MAIN'
      --when marca = 'YOIGO' and canal in ('EML','EYG','EDB','ECI','PH') then 'MAIN'
      when marca = 'YOIGO' and canal in ('PH') then 'MAIN'
      else coalesce (line_type_Ds,'MAIN') end as line_type_Ds,
  FROM
    `mm-commissions-reporting.COMISIONES.activaciones` a
where  a.activation_date >= date_add(date_trunc(current_date(), month), interval -1 month)
--and upper(comisionamiento) like 'COMISIONA%' 
and service_type in ('INTERNET', 'MOBILE')
    --and date_trunc(activation_date, month) != date_trunc(deactivation_date, month)
    and comisiona
    and order_type_agg in ('ALTA NUEVA', 'PORTABILIDAD', 'STC')
    and billing_type_ds = 'POSTPAID'
;


create or replace table TEMP.prov_unitarios as
with
  ventas_totales as
  (
   select
agrupacion_canal,
canal,
marca,
bundle_type,
service_type,
line_type_Ds,
-- case when cod_producto in ('041','040') then cod_producto else '039' end as cod_producto,
CASE
    WHEN service_type = 'INTERNET'                                                                        THEN '054'
    when cod_producto in ('041','040') then cod_producto else '039' end as cod_producto,

count(1) as ventas,
from TEMP.prov_ventas_base
where agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and date_trunc ( activation_date , month ) = date_add(date_trunc(current_date(), month), interval -1 month)
group by 1,2,3,4,5,6,7
  ),
comision as
(
select
tipo_concepto,
agrupacion_canal,
canal,
marca,
    coalesce (bundle_type,'NA') as bundle_type,
    coalesce (case when service_type = 'MOBILE' then 'MOBILE' else 'INTERNET' end ,'NA') as service_type,
    case
      when service_type = 'INTERNET' then 'MAIN'
      --when marca = 'YOIGO' and canal in ('EML','EYG','EDB','ECI','PH') then 'MAIN'
      when marca = 'YOIGO' and canal in ('PH') then 'MAIN'
      else coalesce (line_type_Ds,'MAIN') end as line_type_Ds,
-- case when cod_producto in ('041','040') then cod_producto else '039' end as cod_producto,    
CASE
    WHEN service_type = 'INTERNET'                                                                        THEN '054'
    when cod_producto in ('041','040') then cod_producto else '039' end as cod_producto,
sum(comision) as comision,
sum(case when substr(concepto,1,1) in ('F','H') then comision else 0 end) as comision_gestion_canal
from `mm-commissions-reporting.COMISIONES.transacciones` a
cross join unnest(tipo_concepto_pr) concepto_pr
where tipo_concepto = concepto_pr
and lower(concepto) not like '%anual%'
and lower(concepto) not like '%trimestral%'
and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and id_mes = cast(format_date('%Y%m',date_add(date_trunc(current_date(), month), interval -1 month)) as int64)
and COALESCE(billing_type_ds, 'POSTPAID') = 'POSTPAID' --<---- billing_type_ds nulo en IFS PH
and a.concepto NOT LIKE ('Y%')
and a.concepto NOT LIKE ('Z%')
group by 1,2,3,4,5,6,7,8
)
select 
tipo_concepto,
agrupacion_canal,
canal,
marca,
bundle_type,
service_type,
line_type_Ds,
cod_producto,
comision,
ventas,
comision/ventas as unitario,
comision_gestion_canal/ventas as unitario_gestion_canal
from ventas_totales a
left join comision b using (
agrupacion_canal,
canal,
marca,
bundle_type,
service_type,
line_type_Ds,
cod_producto)
;


create or replace table TEMP.prov as

-- Ventas del mes n aplicando el unitario --

    select cast(format_date('%Y%m',current_date()) as int64) as id_mes, tipo_concepto, 'real' as tipo, a.*, c.unitario as comision, c.unitario_gestion_canal as comision_gestion_canal
    from TEMP.prov_ventas_base a
    cross join `mm-commissions-reporting.COMISIONES.fechas_provision` b left join TEMP.prov_unitarios c
    using (agrupacion_canal,canal,marca,bundle_type,service_type,line_type_Ds,cod_producto)
    where b.fecha = current_date()
    and activation_date between inicio_real and fin_real
    and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')

-- Estimación de ventas del mes n aplicando el unitario --

    union all
    select cast(format_date('%Y%m',current_date()) as int64) as id_mes, tipo_concepto, 'estimacion' as tipo, a.*, c.unitario, c.unitario_gestion_canal as comision_gestion_canal
    from TEMP.prov_ventas_base a
    cross join `mm-commissions-reporting.COMISIONES.fechas_provision` b left join TEMP.prov_unitarios c
    using (agrupacion_canal,canal,marca,bundle_type,service_type,line_type_Ds,cod_producto)
    where b.fecha = current_date()
    and activation_date between inicio_estimado and fin_estimado
    and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
;

end if;

if exists (select 1 from unnest(procesos_pr) p where p = 'TV' ) then

create or replace table TEMP.prov_ventas_base_tv as
  SELECT
    activation_date, 
    deactivation_date,
    service_id,
    a.cod_canal,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento,
    '99' AS cod_tipo_contrato,
    '999' AS cod_producto,
    b.AGRUPACION_CANAL AS agrupacion_canal,
    case
      when b.canal is not null then b.canal
      when substr(seller,1,2) in ('MI','MP','MR', 'PH') then substr(seller,1,2)
      when substr(a.sfid_id,1,3) in ('D2D','D2N','DEM') then substr(a.sfid_id,1,3)
      when substr(seller,1,2) = 'MK' then 'NR'
      when seller = 'guukoffline' THEN 'GUUK'
    end as canal,
    brand_ds as marca,
    'TV' as service_type, 
  FROM
    `mm-commissions-reporting.COMISIONES.v_servicio_television` a
    left join `mm-commissions-reporting.COMISIONES.v_dealer` b on
     ( a.sfid_id = b.sfid_id 
  OR (a.brand_ds = 'YOIGO' AND SUBSTR(a.sfid_id, 1, 2) = b.sfid_id)
  or a.seller = b.sfid_id
  or a.sfid_id    || '-' || a.seller = replace ( b.sfid_id , ' ', '') )
where  a.activation_date >= date_add(date_trunc(current_date(), month), interval -1 month)
    --and date_trunc(activation_date, month) != date_trunc(deactivation_date, month)
    and coalesce (b.comisiona, true) = true
  qualify row_number ()  over (partition by marca, service_type, service_id, activation_date order by length(b.id_comisionista) desc nulls last , comisiona desc) = 1
;



create or replace table TEMP.prov_unitarios_tv as
with
  ventas_totales as
  (
   select
agrupacion_canal,
canal,
marca,
count(1) as ventas,
from TEMP.prov_ventas_base_tv
where agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and date_trunc ( activation_date , month ) = date_add(date_trunc(current_date(), month), interval -1 month)
group by 1,2,3
  ),
comision as
(
select
agrupacion_canal,
canal,
marca,
sum(comision) as comision,
sum(case when substr(concepto,1,1) in ('F','H') then comision else 0 end) as comision_gestion_canal
from `mm-commissions-reporting.COMISIONES.transacciones` a
where 1=1
and service_type = 'TV'
and lower(concepto) not like '%anual%'
and lower(concepto) not like '%trimestral%'
and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and id_mes = cast(format_date('%Y%m',date_add(date_trunc(current_date(), month), interval -1 month)) as int64)
and a.concepto NOT LIKE ('Y%')
and a.concepto NOT LIKE ('Z%')
group by 1,2,3
)
select 
agrupacion_canal,
canal,
marca,
comision,
ventas,
comision/ventas as unitario,
comision_gestion_canal/ventas as unitario_gestion_canal
from ventas_totales a
left join comision b using (
agrupacion_canal,
canal,
marca)
;




create or replace table TEMP.tv_prov as

-- Ventas del mes n aplicando el unitario --

    select cast(format_date('%Y%m',current_date()) as int64) as id_mes, 'OTRS' as tipo_concepto, 'real' as tipo, a.*, c.unitario as comision, c.unitario_gestion_canal as comision_gestion_canal
    from TEMP.prov_ventas_base_tv a
    cross join `mm-commissions-reporting.COMISIONES.fechas_provision` b left join TEMP.prov_unitarios_tv c
    using (agrupacion_canal,canal,marca)
    where b.fecha = current_date()
    and activation_date between inicio_real and fin_real
    and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')

-- Estimación de ventas del mes n aplicando el unitario --

    union all
    select cast(format_date('%Y%m',current_date()) as int64) as id_mes, 'OTRS' as tipo_concepto, 'estimacion' as tipo, a.*, c.unitario, c.unitario_gestion_canal as comision_gestion_canal
    from TEMP.prov_ventas_base_tv a
    cross join `mm-commissions-reporting.COMISIONES.fechas_provision` b left join TEMP.prov_unitarios_tv c
    using (agrupacion_canal,canal,marca)
    where b.fecha = current_date()
    and activation_date between inicio_estimado and fin_estimado
    and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
;

end if;

---RENUEVOS ---

if exists (select 1 from unnest(procesos_pr) p where p = 'RENUEVO' ) then

create or replace table TEMP.prov_ventas_base_renuevo as
  SELECT
    activation_date, 
    deactivation_date,
    service_id,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento,
    `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca,
    CASE
        WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
        WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN '61'
        WHEN bundle_type = 'FMC'                                                                                    THEN '67'
        WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
        ELSE '20'
    END AS cod_tipo_contrato,
    '050' AS cod_producto,
    a.cod_canal,
    b.AGRUPACION_CANAL AS agrupacion_canal,
    case
      when b.canal is not null then b.canal
      when substr(seller,1,2) in ('MI','MP','MR', 'PH') then substr(seller,1,2)
      when substr(a.sfid_id,1,3) in ('D2D','D2N','DEM') then substr(a.sfid_id,1,3)
      when substr(seller,1,2) = 'MK' then 'NR'
      when seller = 'guukoffline' THEN 'GUUK'
    end as canal,
    brand_ds as marca,
    'RENUEVO' as service_type, 
  FROM
    -- `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` a
   `mm-commissions-reporting.TEMP.device_base` a
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` b
         ON a.sfid_id = b.sfid_id 
            OR (a.brand_ds = 'YOIGO' AND SUBSTR(a.sfid_id, 1, 2) = b.sfid_id)
            OR a.seller = b.sfid_id
            OR a.sfid_id || '-' || a.seller = REPLACE(b.sfid_id, ' ', '')
where  a.activation_date >= date_add(date_trunc(current_date(), month), interval -1 month)
    --and date_trunc(activation_date, month) != date_trunc(deactivation_date, month)
    and coalesce (b.comisiona, true) = true
    and a.sell_type = 'RENUEVO'
  qualify row_number ()  over (partition by marca, service_type, service_id, activation_date order by length(b.id_comisionista) desc nulls last , comisiona desc) = 1
;



create or replace table TEMP.prov_unitarios_renuevos as
with
  ventas_totales as
  (
   select
agrupacion_canal,
canal,
marca,
count(1) as ventas,
from TEMP.prov_ventas_base_renuevo
where agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and date_trunc ( activation_date , month ) = date_add(date_trunc(current_date(), month), interval -1 month)
group by 1,2,3
  ),
comision as
(
select
agrupacion_canal,
canal,
marca,
sum(comision) as comision,
sum(case when substr(concepto,1,1) in ('F','H') then comision else 0 end) as comision_gestion_canal
from `mm-commissions-reporting.COMISIONES.transacciones` a
where 1=1
and tipo_concepto = 'CURE'
and lower(concepto) not like '%anual%'
and lower(concepto) not like '%trimestral%'
and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and id_mes = cast(format_date('%Y%m',date_add(date_trunc(current_date(), month), interval -1 month)) as int64)
and a.concepto NOT LIKE ('Y%')
and a.concepto NOT LIKE ('Z%')
group by 1,2,3
)
select 
agrupacion_canal,
canal,
marca,
comision,
ventas,
comision/ventas as unitario,
comision_gestion_canal/ventas as unitario_gestion_canal
from ventas_totales a
left join comision b using (
agrupacion_canal,
canal,
marca)
;




create or replace table TEMP.renuevo_prov as

-- Ventas del mes n aplicando el unitario --

    select cast(format_date('%Y%m',current_date()) as int64) as id_mes, 'CURE' as tipo_concepto, 'real' as tipo, a.*, c.unitario as comision, c.unitario_gestion_canal as comision_gestion_canal
    from TEMP.prov_ventas_base_renuevo a
    cross join `mm-commissions-reporting.COMISIONES.fechas_provision` b left join TEMP.prov_unitarios_renuevos c
    using (agrupacion_canal,canal,marca)
    where b.fecha = current_date()
    and activation_date between inicio_real and fin_real
    and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')

-- Estimación de ventas del mes n aplicando el unitario --

    union all
    select cast(format_date('%Y%m',current_date()) as int64) as id_mes, 'CURE' as tipo_concepto, 'estimacion' as tipo, a.*, c.unitario, c.unitario_gestion_canal as comision_gestion_canal
    from TEMP.prov_ventas_base_renuevo a
    cross join `mm-commissions-reporting.COMISIONES.fechas_provision` b left join TEMP.prov_unitarios_renuevos c
    using (agrupacion_canal,canal,marca)
    where b.fecha = current_date()
    and activation_date between inicio_estimado and fin_estimado
    and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
;

--- CALIDAD ---

end if;

if exists (select 1 from unnest(procesos_pr) p where p = 'CALIDAD' ) then


create or replace table `mm-commissions-reporting.TEMP.cald_facturacion_prov` as
select marca, service_id, service_type, 'C - Calidad 6 meses' as concepto , sum(importe_facturado)/5 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes`
where mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -4 month) and COMISIONES.f_mes_int ( mes_int )
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 12 meses' as concepto , sum(importe_facturado)/11 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes`
where mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -10 month) and COMISIONES.f_mes_int ( mes_int )
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 24 meses' as concepto , sum(importe_facturado)/23 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes`
where mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -22 month) and COMISIONES.f_mes_int ( mes_int )
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 36 meses' as concepto , sum(importe_facturado)/35 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes`
where mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -34 month) and COMISIONES.f_mes_int ( mes_int )
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 48 meses' as concepto , sum(importe_facturado)/47 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes`
where mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -46 month) and COMISIONES.f_mes_int ( mes_int )
group by 1,2,3
;

create or replace table `mm-commissions-reporting.TEMP.cald_base_prov` as
select
canal.agrupacion_canal,

--- comision ---
cast(format_date('%Y%m', current_date()) as int64) as id_mes,
COMISIONES.f_mes_int(cast(format_date('%Y%m', current_date()) as int64)) as fecha,
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
cast ( null as string ) claim_code,
cast ( null as string ) campaign_code,
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
and coalesce ( deactivation_date , '2099-01-01') >= date_add ( COMISIONES.f_mes_int (mes_int) , interval 1 month)
and date_diff (COMISIONES.f_mes_int (mes_int), date_trunc(activation_date, month), month) in (4,10,22,34,46)
and b.canal = canpr
and not (a.marca in ('PEPEPHONE','YOIGO') AND mes_int = 202302 and b.agrupacion_canal = 'Exclusivo')
and a.order_type_agg in ('ALTA NUEVA', 'PORTABILIDAD', 'STC')
qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by length(b.id_comisionista) desc nulls last, comisiona desc ) = 1
;

create or replace table `mm-commissions-reporting.TEMP.cald_prov` as
with
calculos as
(
  select a.*,
  c.concepto,
  c.tipo_concepto,
  1 as unidades,
  case
  when canal in ('MI','CA','NR','MR','MP')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 6 meses','C - Calidad 12 meses')
      then case when t.importe_medio >= 18 then 10 when t.importe_medio >= 14 then 8 else 5 end
  when canal in ('MI','CA','NR','MR','MP')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 24 meses')
      then case when t.importe_medio >= 18 then 20 when t.importe_medio >= 14 then 16 else 10 end
  when canal in ('EML', 'EYG')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 6 meses','C - Calidad 12 meses')
      then case when t.importe_medio >= 25 then 8 when t.importe_medio >= 16 then 6 when t.importe_medio >= 8 then 3 else 0 end
  when canal in ('EML', 'EYG')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 48 meses')
      then case when t.importe_medio >= 25 then 12 when t.importe_medio >= 16 then 10 when t.importe_medio >= 8 then 6 else 0 end   
  end as comision
from `mm-commissions-reporting.TEMP.cald_base_prov` a
inner join `mm-commissions-reporting.TEMP.cald_facturacion_prov` as t on a.marca=t.marca and a.service_type=t.service_type and a.service_id=t.service_id
inner join `mm-commissions-reporting.GS.CONCEPTOS` c on t.concepto = c.concepto
where case delta_meses
  when 4 then 'C - Calidad 6 meses'
  when 10 then 'C - Calidad 12 meses'
  when 22 then 'C - Calidad 24 meses'
  when 34 then 'C - Calidad 36 meses'
  when 46 then 'C - Calidad 48 meses'
end = c.concepto
)
select *
from calculos
where comision > 0
;

--- AIML ---

end if;

if exists (select 1 from unnest(procesos_pr) p where p = 'AIML' ) then

create or replace table TEMP.airtime_exclusivo_ml_prov as

with

billing_status as
(
select invoice_no, status
-- from `mm-datamart-kd.COBROS.payment_status_invoices` l
from `mm-commissions-reporting.COBROS.payment_status_invoices` l
where 1=1
qualify row_number () over (partition by invoice_no order by order_by desc ) = 1
),

billing_status_heos as

(
select id_factura, case when tipo_evento = "Impago" then 'REJECTED' else 'PAID' end as status
--  FROM `mm-datamart-kd.COBROS.HEOS_IMPAGOS` a
from `mm-commissions-reporting.COBROS.HEOS_IMPAGOS` a
where fecha is not null
qualify row_number() over (partition by id_factura order by fecha desc) = 1
),

billing as

(
SELECT 'YOIGO' as marca, service_id, coalesce (status,'PAID') as status,
case
when bill_id like '%CONVDISC%' then 'INTERNET'
when bill_id like 'FH%DISC%' then 'INTERNET'
when service_type IN ('FIX','BROADBAND') then 'INTERNET'
else 'MOBILE' END as service_type,
sum(imp_without_tax) as importe_facturado
FROM `mm-datamart-kd.BILLING.billing_detail_qvantel`
left join billing_status on invoice_id=invoice_no
where data_month_id = mes_int
and ( bill_id like 'CONT%' or bill_id like '%DISC%' or bill_id like '1%'  or bill_id  = 'REJECTION_FEE' or bill_id = 'RECONNECTION') --or bill_id like 'AGILE%'
and service_type in ('INTERNET', 'MOBILE','FIX','BROADBAND')
group by 1,2,3,4

union all 

select brand_ds as marca, service_id, coalesce (status,'PAID') as status,
case 
when service_type = 'BROADBAND' then 'INTERNET'
else service_type end as service_type, 
sum(imp_without_tax) as importe_facturado
FROM `mm-datamart-kd.BILLING.billing_detail_emysim` a
left join billing_status on a.invoice_id=invoice_no
where data_month_id = mes_int
and service_type in ('INTERNET', 'MOBILE','FIX', 'BROADBAND')
group by 1,2,3,4

union all 

select brand_ds as marca, service_id, coalesce (status,'PAID') as status,
case service_type
when 'FIX' then 'INTERNET' else 'MOBILE' END as service_type, sum(imp_without_tax) as importe_facturado
FROM `mm-datamart-kd.BILLING.billing_detail_heos` a
left join billing_status_heos b on a.invoice_id=b.id_factura
where data_month_id = mes_int
and service_type in ('INTERNET', 'MOBILE','FIX', 'BROADBAND')
group by 1,2,3,4

)
select 
a.* except(sfid_id, agrupacion_canal),
cast(format_date('%Y%m', current_date()) as int64) as id_mes,
COMISIONES.f_mes_int(cast(format_date('%Y%m', current_date()) as int64)) as fecha,
b.* except(id_mes),
1 as unidades,
importe_facturado*0.03 as comision,
'C - Airtime 3%' as concepto,
'AIRT' as tipo_concepto,
'C_MANUAL' as facturador,
--- informacion adicional ---
cast ( null as string ) as campaign_code,
cast ( null as string ) as process_code,
from `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b
on seller_formato_tms = b.sfid_id and b.id_mes = mes_int
and b.agrupacion_canal = 'Exclusivo'
left join billing c using (service_id, service_type, marca)
where 1=1
and a.order_type_agg in ('ALTA NUEVA', 'PORTABILIDAD', 'STC')
and a.billing_type_ds = 'POSTPAID'
and date_trunc ( a.activation_Date, month) >= date('2023-01-01')
and coalesce (a.deactivation_date, '2100-01-01') >= date_add(COMISIONES.f_mes_int(mes_int), interval 1 month)
and status in ('PAID', 'RECOLLECTED')
and canal in ( "EML" )
;

end if;

--- tabla_final ---

set sql = 'create or replace table COMISIONES.provision_';
set sql = sql || format_date('%Y%m%d', current_date());
set sql = sql || ' as ';

set sql = sql || ' select id_mes, tipo_concepto, tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, bundle_type, service_type,';
set sql = sql || ' line_type_ds, comision, comision_gestion_canal , "ACTIVACIONES" as proceso from TEMP.prov union all';

set sql = sql || ' select id_mes, tipo_concepto, tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, "NA", service_type,';
set sql = sql || ' "NA", comision ,comision_gestion_canal, "TV" from TEMP.tv_prov union all';

set sql = sql || ' select id_mes, tipo_concepto, tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, "NA", service_type,';
set sql = sql || ' "NA", comision ,comision_gestion_canal, "RENUEVO" from TEMP.renuevo_prov union all';

set sql = sql || ' select id_mes, tipo_concepto, "estimacion" as tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, "NA", service_type,';
set sql = sql || ' "NA", comision , case when substr(concepto,1,1) in ("F","H") then comision else 0 end, "CALIDAD" from TEMP.cald_prov  union all';

set sql = sql || ' select id_mes, tipo_concepto, "estimacion" as tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, "NA", service_type,';
set sql = sql || ' "NA", comision , case when substr(concepto,1,1) in ("F","H") then comision else 0 end, "AIML" from TEMP.airtime_exclusivo_ml_prov union all';

set sql = sql || ' select id_mes, tipo_concepto, "estimacion" as tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, "NA", service_type,';
set sql = sql || ' "NA", comision , case when substr(concepto,1,1) in ("F","H") then comision else 0 end, "AIML_MARZO" from TEMP.airtime_exclusivo_ml_prov ';

/*
set sql = sql || ' UNION ALL select '||cast(format_date('%Y%m', current_date()) as int64)||', tipo_concepto, "estimacion" as tipo, activation_date, deactivation_date, service_id, cod_canal, cod_marca,';
set sql = sql || ' cod_segmento, cod_tipo_contrato, cod_producto, agrupacion_canal, canal, marca, "NA", service_type,';
set sql = sql || ' "NA", comision , case when substr(concepto,1,1) in ("F","H") then comision else 0 end, "IFS" from `mm-commissions-reporting.COMISIONES.v_ifs` where REPORTING_ID in ("725","726") and tipo_concepto not in ("UPFR","48500002") ;';
*/

execute immediate sql;

--declare tipos_conceptos_analizados array<string> default ['UPFR', 'TJTV' ,'TJTS','GENE','ICOX','DUSI','CSFI', 'OTRS','AIRT'];

--- tabla de visualización ---

create or replace table COMISIONES.visualizacion_controlling as
WITH calculos as
(
select 
'provision' as calculo,
id_mes,
COMISIONES.f_mes_int(id_mes) as fecha,
tipo_concepto,
agrupacion_canal,
case when agrupacion_canal = 'TLV - Negocios'
then
	case
    when Canal = 'OUN' then 'TLV - Outbound'
    when Canal = 'XSN' then 'TLV - Cross-sell'
    when Canal = 'XIN' then 'TLV - Cross-sell'
    when Canal = 'DON' then 'TLV - DO'
    when Canal = 'CIN' then 'TLV - Web'
	end
else agrupacion_canal
end as agrupacion_canal_controlling,
canal,
cod_segmento,
cod_canal,
cod_producto,
cod_tipo_contrato,
cod_marca,
service_type,
bundle_type,
line_type_ds,
proceso as proceso_provision,
count(1) as ventas,
sum(comision) as comision,
sum(comision_gestion_canal) as comision_gestion_canal
from `mm-commissions-reporting.COMISIONES.provision_*`
where _table_suffix = (select max(substr(table_name, 11,10)) from `mm-commissions-reporting.COMISIONES.INFORMATION_SCHEMA.TABLES` where table_name like 'provision_________' )
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
union all
select
'real' as calculo,
id_mes,
COMISIONES.f_mes_int(id_mes) as fecha,
tipo_concepto,
agrupacion_canal,
case when agrupacion_canal = 'TLV - Negocios'
then
	case
    when Canal = 'OUN' then 'TLV - Outbound'
    when Canal = 'XSN' then 'TLV - Cross-sell'
    when Canal = 'XIN' then 'TLV - Cross-sell'
    when Canal = 'DON' then 'TLV - DO'
    when Canal = 'CIN' then 'TLV - Web'
	end
else agrupacion_canal
end as agrupacion_canal_controlling,
canal,
cod_segmento,
cod_canal,
-- case when cod_producto in ('041','040') then cod_producto else '039' end as cod_producto,    
CASE
    WHEN service_type = 'INTERNET'                                                                        THEN '054'
    when cod_producto in ('041','040') then cod_producto else '039' end as cod_producto,
cod_tipo_contrato,
cod_marca,
coalesce (case when service_type = 'MOBILE' then 'MOBILE' else 'INTERNET' end ,'NA') as service_type,
coalesce (bundle_type,'NA') as bundle_type,
case
  when service_type = 'INTERNET' then 'MAIN'
  --when marca = 'YOIGO' and canal in ('EML','EYG','EDB','ECI','PH') then 'MAIN'
  else coalesce (line_type_Ds,'MAIN') end as line_type_Ds,
case
    when commission_id like 'AIML%' then 'AIML'
    when tipo_concepto in ('UPFR', 'TJTV' ,'TJTS') then 'ACTIVACIONES'
    when tipo_concepto in ('OTRS') then 'TV'
     when tipo_concepto in ('CURE') then 'RENUEVO'
    when tipo_concepto in ('GENE','ICOX','DUSI','CSFI') then 'IGUAL_MES_ANTERIOR'
end as proceso_provision,
countif ( concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago') ) as ventas,
sum(comision) as comision,
sum(case when substr(concepto,1,1) in ("F","H") then comision else 0 end) as comision_gestion_canal
from `mm-commissions-reporting.COMISIONES.transacciones`
where id_mes < cast(format_date('%Y%m', current_date()) as int64)
and lower(concepto) not like '%anual%'
and lower(concepto) not like '%trimestral%'
and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and tipo_concepto in (select * from unnest(tipos_conceptos_analizados))
AND BILLING_TYPE_DS = 'POSTPAID'
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
union all
select
'provision' as calculo,
cast(format_date('%Y%m', current_date()) as int64) as id_mes,
COMISIONES.f_mes_int(cast(format_date('%Y%m', current_date()) as int64)) as fecha,
tipo_concepto,
agrupacion_canal,
case when agrupacion_canal = 'TLV - Negocios'
then
	case
    when Canal = 'OUN' then 'TLV - Outbound'
    when Canal = 'XSN' then 'TLV - Cross-sell'
    when Canal = 'XIN' then 'TLV - Cross-sell'
    when Canal = 'DON' then 'TLV - DO'
    when Canal = 'CIN' then 'TLV - Web'
	end
else agrupacion_canal
end as agrupacion_canal_controlling,
canal,
cod_segmento,
cod_canal,
cod_producto,
cod_tipo_contrato,
cod_marca,
coalesce (case when service_type = 'MOBILE' then 'MOBILE' else 'INTERNET' end ,'NA') as service_type,
coalesce (bundle_type,'NA') as bundle_type,
case
  when service_type = 'INTERNET' then 'MAIN'
  --when marca = 'YOIGO' and canal in ('EML','EYG','EDB','ECI','PH') then 'MAIN'
  else coalesce (line_type_Ds,'MAIN') end as line_type_Ds,
'IGUAL_MES_ANTERIOR' as proceso_provision,
countif ( concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago') and date_trunc (activation_date, month) = date_trunc(date_add(current_date(), interval - 1 month),month) ) as ventas,
sum(comision) as comision,
sum(case when substr(concepto,1,1) in ("F","H") then comision else 0 end) as comision_gestion_canal
from `mm-commissions-reporting.COMISIONES.transacciones`
where id_mes = cast(format_date('%Y%m', date_add(current_date(), interval - 1 month)) as int64)
and lower(concepto) not like '%anual%'
and lower(concepto) not like '%trimestral%'
and agrupacion_canal in ('D2D','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell','TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
and tipo_concepto in ('GENE','ICOX','DUSI','CSFI')
AND BILLING_TYPE_DS = 'POSTPAID'
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
)
select a.*, b.sociedad, b.cuenta_contable, b.ceco
from calculos a
inner join `mm-commissions-reporting.GS.MAESTRO_CUENTAS_CONTABLES` b on a.tipo_concepto=b.tipo_concepto and case when a.cod_marca='06' then '7000' when a.cod_marca='13' then '8100' else 'X001' end = b.sociedad
;

---------- vs ventas daily ------------

create or replace table COMISIONES.visualizacion_controlling_daily as
with comisiones as 
(
select 
id_mes,
cod_segmento,
cod_marca,
cod_tipo_contrato,
CASE WHEN cod_producto = '041' and cod_marca != '01' and service_type != 'INTERNET' then '039' else cod_producto end as cod_producto,
cod_canal,
--case when agrupacion_canal_controlling like 'TLV%' then 'Televenta' else agrupacion_canal_controlling end as agrupacion_canal,
agrupacion_canal_controlling as agrupacion_canal,
service_type, 
sum(comision) as comision,
sum(ventas) as ventas_comisiones,
from COMISIONES.visualizacion_controlling 
where tipo_concepto in ('UPFR','GENE')
and id_mes >= 202301
group by 1,2,3,4,5,6,7,8
),
daily as
(
select * except(service_type),
case when service_type = 'FIX' then 'INTERNET' else service_type end as service_type
FROM `mm-datamart-kd.INTERFAZ_FINANCIERO.daily_activations`
where periodo >= '2023-01-01' 
and service_type in ('MOBILE', 'FIX')
),
ventas_daily as
(
SELECT
cast ( format_date ('%Y%m', activation_date) as int64) as id_mes,
`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment, brand) as cod_segmento,
`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(d.comm_brand) as cod_marca,
`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato` (
    billing_type , 
    service_type , 
    bundle_type , 
    technology , 
    brand, 
    line_type ) as cod_tipo_contrato,

CASE
    WHEN service_type = 'INTERNET'                                                                        THEN '054'
    when operator_donor is not null then '040' else '039' end as cod_producto,
AGRUPACION.codigo_canal_sap as cod_canal,
--`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds , channel_ds , subchannel_ds ) as agrupacion_canal,
AGRUPACION.agrupacion_canal,
service_type,
sum(kpi_gross_add) as ventas,
--sum(ventas) as ventas_provision
FROM daily d

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(d.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND d.master_channel_ds = AGRUPACION.master_channel_ds
            AND d.channel_ds = AGRUPACION.channel_ds
            AND d.subchannel_ds = AGRUPACION.subchannel_ds
            AND d.comm_brand = AGRUPACION.comm_brand_ds

group by 1,2,3,4,5,6,7,8
union all
SELECT
cast ( format_date ('%Y%m', current_date()) as int64) as id_mes,
`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment, brand) as cod_segmento,
`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(d.comm_brand) as cod_marca,
`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato` (
    billing_type , 
    service_type , 
    bundle_type , 
    technology , 
    brand, 
    line_type ) as cod_tipo_contrato,
-- case
-- when sale_type = 'CROSSELL' and service_type='INTERNET' AND BRAND = 'YOIGO' then '041'
-- when operator_donor is not null then '040' else '039' end as cod_producto,
case
when sale_type = 'CROSSELL' and service_type='INTERNET' AND BRAND = 'YOIGO' then '054'
WHEN service_type = 'INTERNET'                                                                        THEN '054'
when operator_donor is not null and service_type = 'INTERNET' then '054'
 when operator_donor is not null then '040' else '039' end as cod_producto,
AGRUPACION.codigo_canal_sap as cod_canal,
--`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(d.channel_segment_ds , d.channel_ds , d.subchannel_ds ) as agrupacion_canal,
AGRUPACION.agrupacion_canal,
service_type,
sum(kpi_gross_add) as ventas
FROM daily d
cross join `mm-commissions-reporting.COMISIONES.fechas_provision`

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(d.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND d.master_channel_ds = AGRUPACION.master_channel_ds
            AND d.channel_ds = AGRUPACION.channel_ds
            AND d.subchannel_ds = AGRUPACION.subchannel_ds
            AND d.comm_brand = AGRUPACION.comm_brand_ds

    where fecha = current_date()
    and activation_date between inicio_estimado and fin_estimado
group by 1,2,3,4,5,6,7,8
),
ventas_provision as
(
select 
id_mes,
cod_segmento,
cod_marca,
cod_tipo_contrato,
cod_producto,
cod_canal,
service_type,
--case when agrupacion_canal like 'TLV%' then 'Televenta' else agrupacion_canal end as agrupacion_canal,
agrupacion_canal,
sum(ventas) as ventas
from ventas_daily
group by 1,2,3,4,5,6,7,8
)
select
*,
COMISIONES.f_mes_int (id_mes) as mes
from comisiones
full outer join ventas_provision
using (id_mes, cod_segmento, cod_marca, cod_tipo_contrato, cod_producto, cod_canal, agrupacion_canal,service_type)
where cod_tipo_contrato != '10'
and cod_segmento in ('10','12')
and cod_marca in ('01','05','06')
;

--create or replace table COMISIONES.provisiones_reportadas_20230626 as select * from COMISIONES.visualizacion_controlling;

end