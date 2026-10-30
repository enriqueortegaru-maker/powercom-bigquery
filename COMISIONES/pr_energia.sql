begin

--call `mm-commissions-reporting.COMISIONES.pr_energia`(202403);
--call `mm-commissions-reporting.COMISIONES.pr_validar_agrupacion_canal`(null, 'ENRG', 203947.32);

declare prefijo string;

set prefijo = 'C_ENRG';

create or replace table TEMP.energia as 
select 
id_mes_pr as id_mes,
prefijo||'_'||cast(id_mes_pr as string)||'_'||cast(record_id as string) as commission_id,
b.canal,
C.agrupacion_canal,
concept as concepto,
concept_type as tipo_concepto,
qty as unidades,
base_amount as comision,
case when substr (concept,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista else b.id_comisionista end id_comisionista,
distribuidor,
b.id_comisionista as sfid_id,
coalesce(UPPER(split(seller,'@')[OFFSET(0)]),sale_dealer) as seller,
case when substr (concept,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.nombre_comercio else b.nombre_comercio end nombre_comercio,
case when substr (concept,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.razon_social else b.razon_social end razon_social,
case when substr (concept,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.cif else b.cif end cif,
case when substr (concept,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.zona_fiscal else b.zona_fiscal end zona_fiscal,
brand_ds as marca,
'ENERGY' as service_type,
cast(msisdn as string) as phone_nm,
sell_tariff_ds as tariff_id,
sell_tariff_ds as tariff_ds,
service_id,
cups as account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
PARSE_DATE('%Y%m%d',sale_date)  as sale_date,
PARSE_DATE('%Y%m%d',activation_date)  as activation_date,
PARSE_DATE('%Y%m%d',deactivation_date) as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
CASE WHEN a.concept like '%Gas%' then '016'
     WHEN a.concept like '%gas%' then '016'
else '014' end as cod_producto,
case when a.brand_ds ='MASMOVIL' then '17'
     when a.brand_ds ='ENERGYGO' then '16'
     when a.brand_ds ='PEPEENERGY' then '19'
     else '16'
end  COD_MARCA,
C.COD_CANAL,
`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell` (b.canal, a.brand_ds, coalesce(UPPER(split(seller,'@')[OFFSET(0)]),sale_dealer), 'ENERGY') as campaign_code,
cast (null as string)  as serial_number,
cast (null as float64) as tax_base,
cast (null as string)  as claim_code,
cast (null as string)  as process_code,
cast (null as string)  as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from `mm-commissions-reporting.SVA.gs_sva_energia` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b on (a.sale_dealer = b.sfid_id or substr(a.sale_dealer, 1,2) = b.sfid_id) and b.id_mes = id_mes_pr and a.channel = b.canal
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
WHERE NOT (
            b.canal = 'XS'
            AND brand_ds = 'MASMOVIL'
            AND b.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
            AND `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell` (b.canal, a.brand_ds, sale_dealer, 'ENERGY') = 'Lineas adicionales OUT'
            AND a.concept NOT LIKE '%Clawback%'
            )
AND NOT (
            b.canal = 'WA'
            AND b.id_comisionista IN ('RONL004', 'RONL025', 'RONL050', 'MW','3W')
            AND a.concept NOT LIKE '%Clawback%'
            )
AND NOT (
            b.canal = 'OU'
            AND b.id_comisionista IN ('TLVOU009', 'TLVOU022')
            AND a.concept NOT LIKE '%Clawback%'
            )
AND NOT (
            b.canal = 'DO'
            AND b.id_comisionista IN ('DONL003', 'NE')
            AND a.concept NOT LIKE '%Clawback%'
            )
qualify row_number () over (partition by record_id order by b.cif nulls last) = 1
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, (select array_agg(distinct canal) from TEMP.energia) , 'TEMP.energia' , 'ACTUALIZAR');

end