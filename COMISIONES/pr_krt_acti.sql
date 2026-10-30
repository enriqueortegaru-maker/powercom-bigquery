begin

declare sql, prefijo, mes_string string;

set mes_string = CAST(id_mes_pr as string);

set prefijo = 'ACTI_KRT_';

set canales_pr = coalesce (canales_pr, 
(select array_agg (canal) from `mm-commissions-reporting.GS.CANALES` where plantilla_activaciones IN  ('Sin tramos', 'Con tramos'))
);

/*
call  COMISIONES.pr_krt_acti (202312,["DIS",'WOP','AUT','PDV']);
call  COMISIONES.pr_krt_acti (202311,["EML"]);
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
from `mm-commissions-reporting.COMISIONES.krt_activaciones` a
left join `mm-commissions-reporting.COMISIONES.v_tarifas` b 
on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id and a.id_mes=b.id_mes and a.canal=b.canal
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
cross join unnest (canales_pr) as canal_pr
where a.canal = canal_pr
and b.canal is null
and a.service_type in ('MOBILE', 'INTERNET','BROADBAND','FIX')
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
id_comisionista

     ,CASE
          WHEN service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          ELSE 'A - Servicio Fijo'
      END AS concepto,

'UPFR' AS tipo_concepto,
comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1') 
and (a.service_type in ('MOBILE','INTERNET','BROADBAND','FIX') AND  COALESCE(a.line_type_ds,'a') != 'MULTISIM')


-- Servicio Multisim --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
a.line_type_ds,
id_comisionista,
/*,CASE
       WHEN service_type = 'MOBILE' AND a.line_type_ds = 'MULTISIM' THEN 'B - Multisim'
       WHEN service_type = 'MOBILE'                                 THEN 'A - Servicio Movil Pospago'
       ELSE 'A - Servicio Fijo'
   END AS concepto,
*/
'B - Multisim' as concepto,
'UPFR' AS tipo_concepto,
-- CASE WHEN a.marca ='PEPEPHONE' AND a.line_type_ds = 'MULTISIM' THEN 25
-- END AS comision
comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
AND a.line_type_ds = 'MULTISIM' 

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
`mm-commissions-reporting.COMISIONES.f_comision_portabilidadkrt`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , false) comision
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
and a.canal NOT IN ('ECI', 'EDB', 'EML', 'EYG')

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
CASE WHEN traslados > 1 THEN traslados ELSE comision*traslados END as comision
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
CASE WHEN migraciones > 1 THEN migraciones ELSE comision*migraciones END as comision
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
id_comisionista

     ,CASE
          WHEN service_type = 'MOBILE' AND a.line_type_ds = 'MULTISIM' AND a.canal IN ('ECI', 'EDB', 'EYG', 'EML') THEN 'F - Multisim'
          WHEN service_type = 'MOBILE' AND a.line_type_ds <> 'MULTISIM'                                            THEN 'F - Servicio Movil Pospago'
          WHEN service_type <> 'MOBILE'                                                                            THEN 'F - Servicio Fijo'
      END AS concepto,

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

create or replace table `mm-commissions-reporting.TEMP.krt_acti_comisiones` as
select
--- primary key ---
prefijo||'_'||mes_string||'_'||a.canal||'_'||row_number () over () as commission_id,
--- comision ---
'calculado' AS estado,
id_mes_pr id_mes,
b.agrupacion_canal,
b.canal,
case when b.billing_type_ds = 'PREPAID' THEN replace (concepto, 'Pospago', 'Prepago') elSE CONCEPTO end as concepto,
tipo_concepto,
1 as unidades,

----Comision----
-- COALESCE(
-- `mm-commissions-reporting.COMISIONES.f_calculo_camp_cross_sell`
--  (
--  a.canal,
--  b.id_comisionista,
--  b.marca,
--  CASE WHEN b.billing_type_ds = 'PREPAID' THEN REPLACE(concepto, 'Pospago', 'Prepago') ELSE concepto END,
--  `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.seller, b.service_type)
--  ),

-- CASE
--     /* D2D */
--     WHEN b.agrupacion_canal = 'D2D' AND tariff_id = 'CONT29' AND cod_segmento = '12'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 30.00
--     WHEN b.agrupacion_canal = 'D2D' AND tariff_id = 'CONT29'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 25.00
--     WHEN b.agrupacion_canal = 'D2D' AND tariff_id = 'CONT28' AND cod_segmento = '12'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 10.00
--     WHEN b.agrupacion_canal = 'D2D' AND tariff_id = 'CONT28'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 25.00

--     /* NO EXCLUSIVO */
--     WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal = 'MP' AND b.portability_group_donor = 'GRUPO MASMOVIL'
--          AND concepto LIKE '%Portabilidad%'
--     THEN 0.00

--     /* EXCLUSIVO */
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'AJUSTNETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 25.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'AJUSTNETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'F - Servicio Movil Pospago'
--     THEN 3.75
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'FIJOALOPEPE1' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' AND order_type_agg = 'ALTA NUEVA'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 15.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'FIJOALOPEPE1' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' AND order_type_agg = 'ALTA NUEVA'
--          AND concepto = 'F - Servicio Movil Pospago'
--     THEN 0.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'INIMINETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 40.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'INIMINETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'F - Servicio Movil Pospago'
--     THEN 6.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 40.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
--          AND concepto = 'F - Servicio Movil Pospago'
--     THEN 6.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 25.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'F - Servicio Movil Pospago'
--     THEN 3.75
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'TNH25GBILIM1' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'A - Servicio Movil Pospago'
--     THEN 40.00
--     WHEN b.agrupacion_canal = 'Exclusivo' AND marca = 'PEPEPHONE' AND tariff_id = 'TNH25GBILIM1' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
--          AND concepto = 'F - Servicio Movil Pospago'
--     THEN 6.00

-- --     WHEN b.agrupacion_canal = 'Exclusivo' AND b.billing_tier IN ('DESCUENTO 100% DUO PRINCIPAL', 'DESCUENTO 100% INDEFINIDO DUO PRINCIPAL PRO') AND concepto NOT LIKE '%Portabilidad%'
-- --     THEN 0.00

--     ELSE comision
-- END) AS 
comision,
--- vendedor ---
--  case when substr (concepto,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista when substr (concepto,1,1) ='G' and b.agrupacion_canal = 'No Exclusivo' THEN G.id_comisionista else b.id_comisionista end id_comisionista,
b.id_comisionista,
coalesce ( distribuidor, b.id_comisionista ) as distribuidor,
sfid_id,
seller,
-- case when substr (concepto,1,1) in ('F','H')  THEN m.nombre_comercio when substr (concepto,1,1) ='G' THEN G.nombre_comercio else b.nombre_comercio end nombre_comercio,
-- case when substr (concepto,1,1) in ('F','H')  THEN m.razon_social when substr (concepto,1,1) ='G' THEN G.razon_social else b.razon_social end razon_social,
-- case when substr (concepto,1,1) in ('F','H')  THEN m.cif when substr (concepto,1,1) ='G' THEN G.cif else b.cif end cif,
-- case when substr (concepto,1,1) in ('F','H')  THEN m.zona_fiscal when substr (concepto,1,1) ='G' THEN G.zona_fiscal else b.zona_fiscal end zona_fiscal,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,


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
 `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell` (a.canal, b.marca, b.seller, b.service_type) as campaign_code,
 cast ( null as string ) process_code,
comments,
--- informacion contabilizacion ---
'C_MANUAL' as facturador
FROM `mm-commissions-reporting.TEMP.acti_conceptos` a
INNER JOIN `mm-commissions-reporting.COMISIONES.krt_activaciones` b using ( canal, marca, service_type, tariff_id)
inner join `mm-commissions-reporting.GS.CANALES` d on a.canal=d.canal
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` G on b.cif_gpv = g.cif
cross join unnest(canales_pr) as canal_pr
where 1=1
--and not (b.canal in ('EML','EDB','PH','EYG') and id_mes_pr = 202303 and b.marca = 'YOIGO')
and b.canal = canal_pr
and b.id_mes = id_mes_pr
and b.comisionamiento = 'Comisiona'
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'FIX' end = case when b.service_type = 'MOBILE' then b.line_type_ds else 'FIX' end
and coalesce (a.id_comisionista, b.id_comisionista ) = b.id_comisionista
and case
  when concepto in ('F - Portabilidad Movil Pospago', 'F - Portabilidad Fijo','A - Portabilidad Movil Pospago', 'A - Portabilidad Fijo' ,'G - Portabilidad Movil Pospago', 'G - Portabilidad Fijo') then 'PORTABILIDAD'
  --and not (b.portability_group_donor = 'MASMOVIL' and b.canal in ('MP')) then 'PORTABILIDAD'
  when concepto = 'A - Servicio Fijo Cambio de Domicilio'  then 'CAMBIO DOMICILIO'
  when concepto = 'A - Servicio Fijo Cambio de Tecnologia' then 'CAMBIO TECNOLOGIA'
  when concepto in ('A - Servicio Fijo', 'A - Servicio Movil Pospago','B - Multisim','F - Servicio Fijo', 'F - Servicio Movil Pospago','F - Multisim','G - Servicio Fijo', 'G - Servicio Movil Pospago') and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC', 'MULTISIM') then b.order_type_agg
  end = b.order_type_agg
and (not (coalesce (b.distribuidor,'NA') not in (select id_comisionista from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` ) and substr(a.concepto,1,1) = 'F') or b.distribuidor = 'BYMOVIL')
and not (b.cif_gpv is null and substr(a.concepto,1,1) = 'G')
and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC','CAMBIO DOMICILIO','CAMBIO TECNOLOGIA','MULTISIM','HLR')
and b.cif is not null
and not (b.canal = 'XI' and b.bundle_type = 'FMC' and b.service_type = 'MOBILE' and b.marca = 'YOIGO' and b.line_type_ds = 'MAIN')
and not (b.canal = 'EDB' and b.bundle_type = 'FMC' and b.service_type = 'MOBILE' and b.marca = 'YOIGO' and b.line_type_ds = 'MAIN'AND b.order_type_agg ='MYSIM')
AND NOT (
        b.canal = 'XS'
        AND b.marca = 'MASMOVIL'
        AND b.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
        AND `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type) = 'Lineas adicionales OUT'
        AND b.activation_date >= '2023-10-01'
        )
AND NOT (
        b.canal = 'XS'
        AND b.marca = 'YOIGO'
        AND b.id_comisionista IN ('CAROUT007', 'KO')
        AND `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type) = 'Lineas adicionales OUT'
        AND b.activation_date >= '2023-12-01'
        )
;

/*
assert not exists (
  select service_id
  from `mm-commissions-reporting.TEMP.acti_comisiones`
  group by marca, concepto, service_id
  having count(1)>1
);
*/ 

create or replace table `mm-commissions-reporting.TEMP.krt_acti_comisiones_final` as 
select *
from `mm-commissions-reporting.TEMP.krt_acti_comisiones`
where comision != 0 and comision is not null;

--- Insertar tabla final ----

call `mm-commissions-reporting.COMISIONES.pr_krt_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.krt_acti_comisiones_final'  , 'ACTUALIZAR');

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

-- --call `mm-commissions-reporting.COMISIONES.pr_fact`( id_mes_pr , canales_pr );

-- -- Clawback --

-- call `mm-commissions-reporting.COMISIONES.pr_cbsr`( id_mes_pr , canales_pr , ['C_MANUAL']);

-- -----

-- call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`( false );

--actualiar data de pre

create or replace table  `mm-commissions-reporting.COMISIONES.krt_visualizacion_comisiones`
partition by mes_liquidado
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
a.agrupacion_canal,
id_mes,
COMISIONES.f_mes_int(id_mes) as mes_liquidado,
canal,
id_comisionista,
 razon_social as nombre_comercio,
SUBSTR( commission_id , 1, 4) as proceso,
invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
cif,
cod_tipo_contrato,
cod_segmento,
cod_producto,
tipo_concepto,
agrupacion_servicio,
marca,
sfid_id,
case when unidades is not null then seller end as seller,
distribuidor,
tariff_id,
tariff_ds,
a.service_type,
a.line_type_ds as tipo_linea,
a.bundle_type,
case when date_diff(  date_trunc (deactivation_date, month) , date_trunc (activation_date, month) , month) between 0 and 6 then date_diff(  date_trunc (deactivation_date, month) , date_trunc (activation_date, month) , month) end as diferencia_alta_baja_meses,
sum(unidades) as unidades,
sum(comision) as comision,

from `mm-commissions-reporting.COMISIONES.krt_transacciones` a
inner join `mm-commissions-reporting.COMISIONES.v_krt_accesos_comisiones` b using (agrupacion_canal, service_type, marca)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32
;

--esto es para descargar traza
create or replace table `mm-commissions-reporting.COMISIONES.krt_visualizacion_trazabilidad`
partition by mes_liquidado
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
id_mes,
COMISIONES.f_mes_int(id_mes)  as mes_liquidado,
agrupacion_canal,
canal,
id_comisionista,
t.invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
--COALESCE(x.id_fichero_trazabilidad,y.id_fichero_trazabilidad) AS id_fichero_trazabilidad,
'' as id_fichero_trazabilidad,
cif,
nombre_comercio,
`mm-commissions-reporting.COMISIONES.f_clasificacion_concepto`(concepto) as agrupacion_concepto,
/*
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then sfid_id end as sfid_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then seller end as seller,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then marca end as marca,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then cod_segmento end as cod_segmento,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then service_id end as service_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then account_id end as account_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then customer_id end as customer_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then service_type end as service_type,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then bundle_type end as bundle_type,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then line_type_ds end as line_type_ds,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then phone_nm end as phone_nm,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then activation_date end as activation_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then deactivation_date end as deactivation_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then sale_date end as sale_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then order_id end as order_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then tariff_id end as tariff_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then tariff_ds end as tariff_ds,
*/
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

from `mm-commissions-reporting.COMISIONES.krt_transacciones` t, unnest(	emails_acceso_trazabilidad) email

-- left join (
--           select REPLACE(COALESCE(REGEXP_EXTRACT(filename, r'_(.*)'), filename), '.xlsx', '') AS invoice_id, fileid AS id_fichero_trazabilidad
--           FROM  `mm-commissions-reporting.REPORTED.FACTURAS_DRIVE`
--           WHERE filename LIKE '%xlsx%'
--           QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id) = 1
--           ) x
--          ON t.invoice_id = x.invoice_id AND t.estado = 'facturado' AND t.id_factura_drive IS NOT NULL

-- left join (
--           SELECT
--                 REPLACE(COALESCE(REGEXP_EXTRACT(filename, r'_(.*)'), filename), '.xlsx', '') AS fileid
--                ,REPLACE(COALESCE(REGEXP_EXTRACT(filename, r'(.*)_'), filename), '.xlsx', '') AS month
--                ,fileid AS id_fichero_trazabilidad
--           FROM  `mm-commissions-reporting.REPORTED.FACTURAS_DRIVE`
--           WHERE filename LIKE '%xlsx%'
--                 AND filename NOT LIKE 'F%'
--                 AND filename NOT LIKE 'F%'
--           QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month) = 1
--           ) y
--          ON t.id_comisionista = y.fileid AND t.id_mes = CAST(y.month AS INT64) AND t.agrupacion_canal LIKE '%B2B%'

where 1=1 --estado in ( 'facturado', 'publicado')
      -- and email NOT IN ('catalina.jariego@masmovil.com')
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35

union all

select
email,
id_mes,
COMISIONES.f_mes_int(id_mes)  as mes_liquidado,
a.agrupacion_canal,
canal,
id_comisionista,
a.invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
COALESCE(x.id_fichero_trazabilidad,y.id_fichero_trazabilidad) AS id_fichero_trazabilidad,
cif,
nombre_comercio,
`mm-commissions-reporting.COMISIONES.f_clasificacion_concepto`(concepto) as agrupacion_concepto,

case when unidades is not null then sfid_id end as sfid_id,
case when unidades is not null then seller end as seller,
case when unidades is not null then a.marca end as marca,
case when unidades is not null then cod_segmento end as cod_segmento,
case when unidades is not null then service_id end as service_id,
case when unidades is not null then account_id end as account_id,
case when unidades is not null then customer_id end as customer_id,
case when unidades is not null then a.service_type end as service_type,
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

from `mm-commissions-reporting.COMISIONES.krt_transacciones` a
inner join `mm-commissions-reporting.COMISIONES.v_krt_accesos_comisiones` b using (agrupacion_canal, service_type, marca)

left join (
          select REPLACE(COALESCE(REGEXP_EXTRACT(filename, r'_(.*)'), filename), '.xlsx', '') AS invoice_id, fileid AS id_fichero_trazabilidad
          FROM `mm-commissions-reporting.REPORTED.FACTURAS_DRIVE`
          WHERE filename LIKE '%xlsx%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id) = 1
          ) x
         ON a.invoice_id = x.invoice_id AND a.estado = 'facturado' AND a.id_factura_drive IS NOT NULL

left join (
          SELECT
                REPLACE(COALESCE(REGEXP_EXTRACT(filename, r'_(.*)'), filename), '.xlsx', '') AS fileid
               ,REPLACE(COALESCE(REGEXP_EXTRACT(filename, r'(.*)_'), filename), '.xlsx', '') AS month
               ,fileid AS id_fichero_trazabilidad
          FROM  `mm-commissions-reporting.REPORTED.FACTURAS_DRIVE`
          WHERE filename LIKE '%xlsx%'
                AND filename NOT LIKE 'F%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month) = 1
          ) y
         ON a.id_comisionista = y.fileid AND a.id_mes = CAST(y.month AS INT64) AND a.agrupacion_canal LIKE '%B2B%'


group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35
;

end