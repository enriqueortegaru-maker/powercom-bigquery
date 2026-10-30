begin

declare sql, prefijo, mes_string string;

set mes_string = CAST(id_mes_pr as string);

set prefijo = 'OSPACTI_';

set canales_pr = coalesce (canales_pr, 
(select array_agg (canal) from `mm-commissions-reporting.GS.CANALES` where plantilla_activaciones IN  ('Sin tramos', 'Con tramos'))
);

/*
call  COMISIONES.pr_actiOSP (202511, ['DO']);
*/


/* Generates KPIs to facilitate commission calculations */
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activationes_kpi` AS
(
SELECT
      * EXCEPT(kpi_d2d_pack_mobile_additional)

     ,CASE
          WHEN kpi_d2d_pack_mobile_additional IS NOT NULL
               AND SUM(COALESCE(kpi_d2d_pack_mobile_additional, 0)) OVER (PARTITION BY id_mes, id_comisionista, customer_id) >= 5
          THEN SUM(COALESCE(kpi_d2d_pack_mobile_additional, 0)) OVER (PARTITION BY id_mes, id_comisionista, customer_id)
      END AS kpi_d2d_pack_mobile_additional

FROM (
     SELECT
           *
     
          ,CASE
               WHEN comisionamiento = 'Comisiona'
                    AND (
                         (
                         canal IN ('D2D','D2N')
                         AND marca IN ('MASMOVIL')
                         AND (
                             tariff_ds LIKE '%60%'
                             OR tariff_ds LIKE '%35%'
                             OR tariff_ds LIKE '%20%'
                             )
                         )
                        OR
                         (
                         canal IN ('D2D','D2N')
                         AND marca IN ('YOIGO')
                         AND (
                             UPPER(tariff_ds) LIKE '%INFINITA%'
                             OR tariff_ds LIKE '%60%'
                             OR tariff_ds LIKE '%30%'
                             )
                         )
                        OR
                         (
                         canal IN ('DEM')
                         AND marca IN ('YOIGO')
                         AND (
                             UPPER(tariff_ds) LIKE '%INFINITA%'
                             OR tariff_ds LIKE '%60%'
                             OR tariff_ds LIKE '%30%'
                             )
                         )
                        )
                    AND bundle_type = 'FMC'
                    AND line_type_ds = 'ADDITIONAL'
                    AND cod_segmento = '12'
               THEN 1
           END AS kpi_d2d_pack_mobile_additional

     FROM `mm-commissions-reporting.COMISIONES.activaciones`
     )
)
;


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
CASE WHEN a.canal = 'XS' THEN a.campaign_code ELSE CAST(NULL AS STRING) END AS campaign_code,
'ACTI',
current_timestamp()
from `mm-commissions-reporting.COMISIONES.activaciones` a
left join `mm-commissions-reporting.COMISIONES.v_tarifas` b 
on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id and a.id_mes=b.id_mes and a.canal=b.canal
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
AND a.tariff_ds = b.tariff_ds
AND ((a.canal IN ('XS') AND a.campaign_code = b.campaign_code) -- Añadimos cruce por campaign_code
      OR
      (a.canal NOT IN ('XS'))  
    ) 
cross join unnest (canales_pr) as canal_pr
where a.canal = canal_pr
and b.canal is null
and a.service_type in ('MOBILE', 'INTERNET')
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
campaign_code

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
a.campaign_code,
tariff_id,
 tariff_ds,
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
and (a.service_type in ('MOBILE','INTERNET') AND  COALESCE(a.line_type_ds,'a') != 'MULTISIM')


-- Servicio Multisim --
union all
select
a.canal as canal,
a.marca,
a.service_type,
a.campaign_code,
tariff_id,
 tariff_ds,
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
a.campaign_code,
tariff_id,
 tariff_ds,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'A - Portabilidad Movil Pospago' else 'A - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , false, a.campaign_code) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal NOT IN ('ENK')


-- Portabilidad gestion canal--
union all
select
a.canal as canal,
a.marca,
a.service_type,
a.campaign_code,
tariff_id,
 tariff_ds,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'F - Portabilidad Movil Pospago' else 'F - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , true, a.campaign_code) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal NOT IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX','ENK')

--  traslados --
union all
select
a.canal as canal,
a.marca,
a.service_type,
a.campaign_code,
tariff_id,
 tariff_ds,
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
AND A.CANAL NOT IN ('XI','XO','XOF')

--  migraciones --
union all
select
a.canal as canal,
a.marca,
a.service_type,
a.campaign_code,
tariff_id,
 tariff_ds,
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
AND A.CANAL NOT IN ('XI','XO','XOF')

-- Gestion de canal --
union all
select
a.canal as canal,
a.marca,
a.service_type,
a.campaign_code,
tariff_id,
 tariff_ds,
a.line_type_ds,
id_comisionista

     ,CASE
          WHEN service_type = 'MOBILE' AND a.line_type_ds = 'MULTISIM' AND a.canal IN ('ECI', 'EDB', 'EYG', 'EML', 'ENX') THEN 'F - Multisim'
          WHEN service_type = 'MOBILE' AND a.line_type_ds <> 'MULTISIM'                                                   THEN 'F - Servicio Movil Pospago'
          WHEN service_type <> 'MOBILE'                                                                                   THEN 'F - Servicio Fijo'
      END AS concepto,

'UPFR' AS tipo_concepto,
gestion_canal as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string), 'tramo_1')
and a.canal in ('MI','CA','EML', 'GUUK', 'EYG', 'EDB', 'ECI', 'PH', 'ENX','ENK')

-- Gestion de canal GPV --
union all
select
a.canal as canal,
a.marca,
a.service_type,
a.campaign_code,
tariff_id,
 tariff_ds,
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
a.campaign_code,
tariff_id,
 tariff_ds,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'G - Portabilidad Movil Pospago' else 'G - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , true, a.campaign_code) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal in ('MI','CA')
)

select *
from marco
qualify row_number ()  over (partition by canal, marca, service_type, tariff_id,tariff_ds, line_type_ds, concepto,id_comisionista,campaign_code ) = 1
;

--- Calcular tabla de comisiones ---

create or replace table `mm-commissions-reporting.TEMP.acti_comisiones` as
select
--- primary key ---
prefijo||'_'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
--- comision ---
'calculado' AS estado,
id_mes_pr id_mes,
b.agrupacion_canal,
b.canal,
case when b.billing_type_ds = 'PREPAID' THEN replace (concepto, 'Pospago', 'Prepago') elSE CONCEPTO end as concepto,
tipo_concepto,
1 as unidades,

----Comision----
COALESCE(
`mm-commissions-reporting.COMISIONES.f_calculo_camp_cross_sell`
 (
 a.canal,
 b.id_comisionista,
 b.marca,
 CASE WHEN b.billing_type_ds = 'PREPAID' THEN REPLACE(concepto, 'Pospago', 'Prepago') ELSE concepto END,
 CASE
     WHEN b.activation_date < '2024-07-22'
     THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type), tlv_cross_sell.campaign)
     ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type))
 END
 ),

CASE
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('ORANGE','SIMYO') AND b.order_type_agg = 'PORTABILIDAD' THEN comision *2
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 11 then 19 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 13 then 22 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 15 then 25 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 22 then 37 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 23 then 39 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 24 then 40 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 26 then 44 
WHEN b.canal = 'DO' AND b.service_type NOT IN ('INTERNET') AND B.marca in ('JAZZTEL') AND b.order_type_agg = 'PORTABILIDAD' and comision= 25 then 41 
 
    /* D2D */
    WHEN b.agrupacion_canal = 'D2D' AND b.tariff_id = 'CONT29' AND cod_segmento = '12'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 30.00
    WHEN b.agrupacion_canal = 'D2D' AND b.tariff_id = 'CONT29'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 25.00
    WHEN b.agrupacion_canal = 'D2D' AND b.tariff_id = 'CONT28' AND cod_segmento = '12'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 10.00
    WHEN b.agrupacion_canal = 'D2D' AND b.tariff_id = 'CONT28'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 25.00

    /* NO EXCLUSIVO */
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal = 'MP' AND b.portability_group_donor = 'GRUPO MASMOVIL'
         AND concepto LIKE '%Portabilidad%'
    THEN 0.00
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal IN ('MP','MI','MR','CA','PH')  AND 
    b.marca = 'PEPEPHONE' AND b.tariff_id IN ('AJUSTNETFLIX','TNH23GBILAUX','TNH23GBILIMI',
    'TNH25GBILIM1') AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 25.00
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal IN ('MP','MI','MR','CA','PH') AND b.marca =
    'PEPEPHONE' AND b.tariff_id = 'INIMINETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 30.00
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal IN ('MP','MI','MR','CA','PH') AND b.marca =
    'PEPEPHONE' AND b.tariff_id IN
    ('AJUSTNETFLIX','TNH23GBILIMI') AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' and 
    technology_ds = 'ADSL'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 15.00
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal = 'NR' AND b.marca = 'PEPEPHONE' AND
    b.tariff_id IN ('AJUSTNETFLIX','TNH23GBILAUX','TNH23GBILIMI','TNH25GBILIM1') AND bundle_type =
    'FMC' AND a.line_type_ds = 'MAIN'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 31.00
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal = 'NR' AND b.marca = 'PEPEPHONE' AND 
    b.tariff_id = 'INIMINETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 36.00
    WHEN b.agrupacion_canal = 'No Exclusivo' AND b.canal = 'NR' AND b.marca = 'PEPEPHONE' AND 
    b.tariff_id IN ('AJUSTNETFLIX','TNH23GBILIMI') AND bundle_type = 'FMC' AND a.line_type_ds =
    'MAIN' and technology_ds = 'ADSL'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 21.00

    /* EXCLUSIVO */
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'AJUSTNETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 25.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'AJUSTNETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'F - Servicio Movil Pospago'
    THEN 3.75
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'FIJOALOPEPE1' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' AND order_type_agg = 'ALTA NUEVA'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 15.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'FIJOALOPEPE1' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' AND order_type_agg = 'ALTA NUEVA'
         AND concepto = 'F - Servicio Movil Pospago'
    THEN 0.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'INIMINETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 40.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'INIMINETFLIX' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'F - Servicio Movil Pospago'
    THEN 6.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 40.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
         AND concepto = 'F - Servicio Movil Pospago'
    THEN 6.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 25.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'F - Servicio Movil Pospago'
    THEN 3.75
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH25GBILIM1' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'A - Servicio Movil Pospago'
    THEN 40.00
    WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH25GBILIM1' AND bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
         AND concepto = 'F - Servicio Movil Pospago'
    THEN 6.00

    WHEN b.agrupacion_canal = 'Exclusivo' AND b.billing_tier IN ('DESCUENTO 100% DUO PRINCIPAL', 'DESCUENTO 100% INDEFINIDO DUO PRINCIPAL PRO') AND concepto NOT LIKE '%Portabilidad%'
    THEN 0.00

    WHEN b.agrupacion_canal = 'Exclusivo' AND b.tariff_ds = 'DUO PRINCIPAL' AND order_type_agg = 'ALTA NUEVA' AND concepto NOT LIKE '%Portabilidad%'
    THEN 0.00

    /* TLV RESIDENCIAL */

    /*
    WHEN b.agrupacion_canal IN ('TLV - DO', 'TLV - Outbound') AND b.tariff_id IN ('426','427','446') AND b.sale_date < '2024-01-24' AND concepto = 'A - Servicio Movil Pospago'
    THEN 30.00 
    WHEN b.agrupacion_canal IN ('TLV - DO', 'TLV - Outbound') AND b.tariff_id IN ('426','427','446') AND b.sale_date BETWEEN '2024-01-24' AND '2024-01-31' AND concepto = 'A - Servicio Movil Pospago'
    THEN 38.00  --'TARIFA MAS 20GB CONV'
    WHEN b.agrupacion_canal = 'TLV - Cross-sell' AND b.tariff_id IN ('361','426','446') AND b.sale_date BETWEEN '2024-01-01' AND '2024-01-23' AND concepto = 'A - Servicio Movil Pospago'
    THEN 15.90 
    WHEN b.agrupacion_canal = 'TLV - Cross-sell' AND b.tariff_id IN ('361','426','446') AND b.sale_date BETWEEN '2024-01-24' AND '2024-01-31' AND concepto = 'A - Servicio Movil Pospago'
    THEN 27.50
    WHEN b.agrupacion_canal IN ('TLV - DO', 'TLV - Outbound') AND b.tariff_id IN ('8228') AND b.sale_date < '2024-02-14' AND concepto = 'A - Servicio Movil Pospago'
    THEN 25
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8228') AND b.id_comisionista = 'RONL005' AND b.sale_date BETWEEN '2024-02-01' AND '2024-02-13' AND concepto = 'A - Servicio Movil Pospago'
    THEN 24.5
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8228') AND b.id_comisionista = 'RONL005' AND b.sale_date BETWEEN '2024-02-14' AND '2024-02-29' AND concepto = 'A - Servicio Movil Pospago'
    THEN 19.6
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8228') AND b.id_comisionista IN ('RONL006','RONL046') AND b.sale_date BETWEEN '2024-02-01' AND '2024-02-13' AND concepto = 'A - Servicio Movil Pospago'
    THEN 22.9 
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8228') AND b.id_comisionista IN ('RONL006','RONL046') AND b.sale_date BETWEEN '2024-02-14' AND '2024-02-29' AND concepto = 'A - Servicio Movil Pospago'
    THEN 18.32 
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8228') AND b.id_comisionista IN ('RONL020','RONL021','RONL026') AND b.sale_date BETWEEN '2024-02-01' AND '2024-02-13' AND concepto = 'A - Servicio Movil Pospago'
    THEN 21.4 
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8228') AND b.id_comisionista IN ('RONL020','RONL021','RONL026') AND b.sale_date BETWEEN '2024-02-14' AND '2024-02-29' AND concepto = 'A - Servicio Movil Pospago'
    THEN 17.12 -- LA SINFIN 500MB
    WHEN b.agrupacion_canal IN ('TLV - DO', 'TLV - Outbound') AND b.tariff_id IN ('8229') AND b.sale_date < '2024-02-14' AND concepto = 'A - Servicio Movil Pospago'
    THEN 12
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8229') AND b.id_comisionista = 'RONL005' AND b.sale_date BETWEEN '2024-02-01' AND '2024-02-13' AND concepto = 'A - Servicio Movil Pospago'
    THEN 13.48
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8229') AND b.id_comisionista = 'RONL005' AND b.sale_date BETWEEN '2024-02-14' AND '2024-02-29' AND concepto = 'A - Servicio Movil Pospago'
    THEN 11.03
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8229') AND b.id_comisionista IN ('RONL006','RONL046') AND b.sale_date BETWEEN '2024-02-01' AND '2024-02-13' AND concepto = 'A - Servicio Movil Pospago'
    THEN 12.59 
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8229') AND b.id_comisionista IN ('RONL006','RONL046') AND b.sale_date BETWEEN '2024-02-14' AND '2024-02-29' AND concepto = 'A - Servicio Movil Pospago'
    THEN 10.3
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8229') AND b.id_comisionista IN ('RONL020','RONL021','RONL026') AND b.sale_date BETWEEN '2024-02-01' AND '2024-02-13' AND concepto = 'A - Servicio Movil Pospago'
    THEN 11.77
    WHEN b.agrupacion_canal = 'TLV - Web' AND b.tariff_id IN ('8229') AND b.id_comisionista IN ('RONL020','RONL021','RONL026') AND b.sale_date BETWEEN '2024-02-14' AND '2024-02-29' AND concepto = 'A - Servicio Movil Pospago'
    THEN 9.63 --LA SINFIN 500MB_ADMO
    WHEN b.agrupacion_canal = 'TLV - Cross-sell' AND b. id_comisionista IN ('AC', 'AO', 'CARIN006', 'CARIN009','CARIN011') AND b.marca = 'YOIGO'AND b.activation_date >= '2024-03-01' AND concepto = 'A - Servicio Fijo' THEN comision + 25
    WHEN b.agrupacion_canal = 'TLV - Cross-sell' AND b. id_comisionista IN ('AC', 'AO', 'CARIN006', 'CARIN009','CARIN011') AND b.marca = 'YOIGO'AND b.activation_date >= '2024-03-01' AND concepto = 'A - Servicio Movil Pospago' THEN comision + 15
    WHEN b.agrupacion_canal = 'TLV - Cross-sell' AND b. id_comisionista IN ('AC', 'AO', 'CARIN006', 'CARIN009','CARIN011') AND b.marca = 'YOIGO' AND b.activation_date >= '2024-03-01' AND concepto IN ('A - Servicio Fijo Cambio de Domicilio','A - Servicio Fijo Cambio de Tecnologia') THEN comision - 15
    WHEN b.agrupacion_canal = 'TLV - Cross-sell' AND b. id_comisionista IN ('AB', 'KS', 'CARIN004', 'CARIN005','CARIN007') AND b.marca = 'YOIGO' AND b.activation_date >= '2024-03-01' AND concepto IN ('A - Servicio Fijo Cambio de Domicilio','A - Servicio Fijo Cambio de Tecnologia') THEN comision - 15
*/
        /* TLV NEGOCIOS */
    WHEN b.agrupacion_canal IN ('TLV - Negocios') AND b.canal IN ('OUN','DON') AND b.tariff_id IN ('1340','1345','1454','1455') AND b.sale_date < '2024-01-24' AND concepto = 'A - Servicio Fijo'
    THEN 180.00 
    WHEN b.agrupacion_canal IN ('TLV - Negocios') AND b.canal IN ('OUN','DON') AND b.tariff_id IN ('1340','1345','1454','1455') AND b.sale_date BETWEEN '2024-01-24' AND '2024-01-31' AND concepto = 'A - Servicio Fijo'
    THEN 188.00 -- FIBRA 1GB + MÓVIL 20GB RESI
    WHEN b.agrupacion_canal IN ('TLV - Negocios') AND b.canal IN ('OUN','DON') AND b.tariff_id IN ('1309','1310','1452','1453') AND b.sale_date < '2024-01-24' AND concepto = 'A - Servicio Fijo'
    THEN 160.00 
    WHEN b.agrupacion_canal IN ('TLV - Negocios') AND b.canal IN ('OUN','DON') AND b.tariff_id IN ('1309','1310','1452','1453') AND b.sale_date BETWEEN '2024-01-24' AND '2024-01-31' AND concepto = 'A - Servicio Fijo'
    THEN 168.00 -- FIBRA 300/500MB + MÓVIL 20GB RESI

    ELSE comision
END) AS comision,
--- vendedor ---
case when substr (concepto,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista when substr (concepto,1,1) ='G' and b.agrupacion_canal = 'No Exclusivo' THEN G.id_comisionista else b.id_comisionista end id_comisionista,
case when substr (concepto,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista when substr (concepto,1,1) ='G' and b.agrupacion_canal = 'No Exclusivo' THEN G.id_comisionista else coalesce (distribuidor,b.id_comisionista) end distribuidor,
sfid_id,
seller,
case when substr (concepto,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.nombre_comercio when substr (concepto,1,1) ='G' THEN G.nombre_comercio else b.nombre_comercio end nombre_comercio,
case when substr (concepto,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.razon_social when substr (concepto,1,1) ='G' THEN G.razon_social else b.razon_social end razon_social,
case when substr (concepto,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.cif when substr (concepto,1,1) ='G' THEN G.cif else b.cif end cif,
case when substr (concepto,1,1) in ('F','H')  and b.agrupacion_canal = 'No Exclusivo' THEN m.zona_fiscal when substr (concepto,1,1) ='G' THEN G.zona_fiscal else b.zona_fiscal end zona_fiscal,
--- servicio ---
b.marca,
b.service_type,
phone_nm,
b.tariff_id,
b.tariff_ds,
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
COALESCE(b.sfid_digo,order_id) AS order_id,
order_type_agg,
--- variables analiticas ---
cod_segmento,
cod_marca,
cod_tipo_contrato,
cod_producto,
coalesce (d.cod_canal, b.cod_canal) as cod_canal,
--- informacion adicional ---
-- CASE
--     WHEN b.activation_date < '2024-07-22'
--     THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type), tlv_cross_sell.campaign)
--     ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type))
-- END as campaign_code,
b.campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast ( null as string ) claim_code,
cast ( null as string ) process_code,
comments,
--- informacion contabilizacion ---
'C_MANUAL' as facturador,
FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.acti_conceptos` WHERE canal NOT IN ('ALTN', 'ALTNC','ALTNH')
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad
      
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'B - Multisim'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds = 'MULTISIM'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad_gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad_gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTN' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'B - Multisim'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds = 'MULTISIM'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad_gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad_gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'G - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad_gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad_gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds 
          ,bundle_type
          ,'G - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNC' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'G - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'A - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'B - Multisim'
          ,'UPFR' AS tipo_concepto
          ,comision
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds = 'MULTISIM'
           AND comision IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad_gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad_gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'F - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds 
          ,bundle_type
          ,'G - Portabilidad Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,portabilidad_gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND portabilidad_gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds 
          ,bundle_type
          ,'G - Servicio Fijo'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'INTERNET'
           AND gestion_canal IS NOT NULL
     UNION DISTINCT
     SELECT 
           'ALTNH' AS canal
          ,marca
          ,service_type
          ,CAST (NULL AS STRING) AS campaign_code
          ,tariff_id, tariff_ds
          ,line_type_ds
          ,bundle_type
          ,'G - Servicio Movil Pospago'
          ,'UPFR' AS tipo_concepto
          ,gestion_canal
     FROM `mm-commissions-reporting.GS.TARIFAS_ALTN`
     WHERE service_type = 'MOBILE'
           AND line_type_ds != 'MULTISIM'
           AND gestion_canal IS NOT NULL
     ) a
INNER JOIN `mm-commissions-reporting.TEMP.activationes_kpi` b
         ON a.canal=b.canal 
         AND a.marca = b.marca AND a.service_type = b.service_type AND a.tariff_id = b.tariff_id
         AND a.TARIFF_DS = b.TARIFF_DS

            AND
            COALESCE(CASE WHEN a.canal IN ('ALTN', 'ALTNC','ALTNH', 'XI','XO','XOF', 'WA') THEN a.id_comisionista END, b.bundle_type)
            =
            COALESCE(CASE WHEN b.canal IN ('XI','XO','XOF',  'WA') THEN b.id_comisionista END, b.bundle_type)
      
            AND (
              (b.canal = 'XS' AND a.campaign_code = b.campaign_code)
              OR
              (b.canal != 'XS')  
            ) --- 202507: Añadimos cruce por campaign code
            



inner join `mm-commissions-reporting.GS.CANALES` d on a.canal=d.canal
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` G on b.cif_gpv = g.cif
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell on b.id_comisionista = tlv_cross_sell.id_comisionista and b.canal = tlv_cross_sell.canal
-- left join `mm-commissions-reporting.GS.exclusivo_dealers` e on b.id_comisionista = e.id_comisionista -- JOHANNA 20250513
cross join unnest(canales_pr) as canal_pr
where 1=1
--and not (b.canal in ('EML','EDB','PH','EYG') and id_mes_pr = 202303 and b.marca = 'YOIGO')
and b.canal = canal_pr
and b.id_mes = id_mes_pr
and b.comisionamiento = 'Comisiona'
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'FIX' end = case when b.service_type = 'MOBILE' then b.line_type_ds else 'FIX' end
--and coalesce (a.id_comisionista, b.id_comisionista ) = b.id_comisionista
and case
  when concepto in ('F - Portabilidad Movil Pospago', 'F - Portabilidad Fijo','A - Portabilidad Movil Pospago', 'A - Portabilidad Fijo' ,'G - Portabilidad Movil Pospago', 'G - Portabilidad Fijo') then 'PORTABILIDAD'
  when concepto = 'A - Servicio Fijo Cambio de Domicilio'  then 'CAMBIO DOMICILIO'
  when concepto = 'A - Servicio Fijo Cambio de Tecnologia' then 'CAMBIO TECNOLOGIA'
  when concepto in ('A - Servicio Fijo', 'A - Servicio Movil Pospago','B - Multisim','F - Servicio Fijo', 'F - Servicio Movil Pospago','F - Multisim','G - Servicio Fijo', 'G - Servicio Movil Pospago') and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC', 'MULTISIM') then b.order_type_agg
  end = b.order_type_agg
and (not (coalesce (b.distribuidor,'NA') not in (select id_comisionista from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` ) and substr(a.concepto,1,1) = 'F') or b.distribuidor = 'BYMOVIL')
and not (b.cif_gpv is null and substr(a.concepto,1,1) = 'G')
and (
      b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC','CAMBIO DOMICILIO','CAMBIO TECNOLOGIA','MULTISIM','HLR')
    or
      (b.canal = 'ENK' and b.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO')
    )
and b.cif is not null
and not (b.canal IN ('XI','XO') and b.bundle_type = 'FMC' and b.service_type = 'MOBILE' and b.marca = 'YOIGO' and b.tariff_ds like '%CONV%' )
and not (b.canal = 'EDB' and b.bundle_type = 'FMC' and b.service_type = 'MOBILE' and b.marca = 'YOIGO' and b.line_type_ds = 'MAIN'AND b.order_type_agg ='MYSIM')
AND NOT (
        b.canal = 'XS'
        AND b.marca = 'MASMOVIL'
        AND b.id_comisionista IN ('CAROUT006', 'CAROUT013','CAROUT020','CAROUT021','CAROUT022')
        AND CASE
                WHEN b.activation_date < '2024-07-22'
                THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type), tlv_cross_sell.campaign)
                ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type))
            END = 'Lineas adicionales OUT'
        AND b.activation_date >= '2023-10-01'
        )
AND NOT (
        b.canal = 'XS'
        AND b.marca = 'YOIGO'
        AND b.id_comisionista IN ('CAROUT007', 'KO')
        AND CASE
                WHEN b.activation_date < '2024-07-22'
                THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type), tlv_cross_sell.campaign)
                ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(a.canal, b.marca, b.seller, b.service_type))
            END = 'Lineas adicionales OUT'
        AND b.activation_date BETWEEN '2023-12-01' AND '2024-02-29'
        )
AND NOT (
        b.canal = 'XS'
        AND b.id_comisionista IN ('CAROUT032','CAROUT033')
        )

;


assert not exists (
  select *
  from `mm-commissions-reporting.TEMP.acti_comisiones`
  QUALIFY COUNT(*) OVER (PARTITION BY phone_nm, service_id, marca, service_type, concepto) > 1

); -- Hay duplicados en ACTI!


create or replace table `mm-commissions-reporting.TEMP.acti_comisiones_final` as 
select *
from `mm-commissions-reporting.TEMP.acti_comisiones`
where comision is not null
      and (
          comision != 0
          OR
          (agrupacion_canal = 'Exclusivo' AND tariff_ds = 'DUO PRINCIPAL' AND order_type_agg = 'ALTA NUEVA' AND concepto NOT LIKE '%Portabilidad%')
          )
      AND CANAL NOT IN ('ALTN','ALTNC','ALTNH')  
      AND sfid_id IN(
        '19140513',
'19140561',
'19140560',
'19140539',
'19140579',
'19140598',
'19140548',
'19140546',
'19140541',
'19140542',
'19140543',
'19140550',
'19140552',
'19140553',
'19140555',
'19140558',
'19140559',
'19140565',
'19140566',
'19140281',
'19140282',
'19140503',
'I471185CDM',
'I286920CDM',
'DOACCOM001',
'I471185000',
'I286920000'
)
      
        ;

----- 'DOT' --- Multiplicador Comisiones
 IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DOT', 'DO')) THEN

UPDATE `mm-commissions-reporting.TEMP.acti_comisiones_final` af
SET af.comision = CAST(af.comision AS FLOAT64) * CAST (b.multiplicador AS FLOAT64)
FROM(

SELECT b.*,
CASE 
WHEN b.order_type_agg = 'ALTA NUEVA' THEN a.importe_pos
WHEN b.order_type_agg = 'PORTABILIDAD' THEN a.importe_pr
ELSE 1.0
END as multiplicador
FROM `mm-commissions-reporting.TEMP.acti_comisiones_final` b
LEFT JOIN(
WITH UNIDADES AS(
  SELECT
  cif,
  SUM(UNIDADES) as UNIDADES

  FROM `mm-commissions-reporting.TEMP.acti_comisiones_final`
--   WHERE canal IN ('DOT')
  WHERE marca = 'SIMYO' 
  AND concepto in ('A - Servicio Movil Pospago','A - Portabilidad Movil Pospago','A - Servicio Fijo','A - Portabilidad Fijo')
  GROUP BY cif
)

SELECT *
FROM UNIDADES a
LEFT JOIN  `mm-commissions-reporting.GS.tramos_dot` b
ON a.UNIDADES BETWEEN B.RANGO_INI AND B.RANGO_FIN 
    AND b.id_mes = id_mes_pr 
    ) a

ON a.cif = b.cif WHERE b.canal IN ('DO', 'DOT') AND b.id_mes = id_mes_pr
) b

WHERE b.commission_id = af.commission_id
and af.marca = 'SIMYO' AND af.service_type = 'MOBILE'
AND af.concepto in ('A - Servicio Movil Pospago','A - Portabilidad Movil Pospago')
;
END IF;

--- Insertar tabla final ----

-- call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.acti_comisiones_final'  , 'ACTUALIZAR');

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

-- -- if exists (select 1 from unnest(canales_pr) p where p in ('EML', 'EYG', 'ECI', 'EDB', 'ENX') ) then

-- -- call `mm-commissions-reporting.COMISIONES.pr_exrp`( id_mes_pr );

-- -- end if;

-- --calculos factura

-- -- call `mm-commissions-reporting.COMISIONES.pr_fact`( id_mes_pr , canales_pr ); 

-- -- Clawback --

-- -- call `mm-commissions-reporting.COMISIONES.pr_cbsr`( id_mes_pr , canales_pr );

-- -----

-- call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`( false );


end