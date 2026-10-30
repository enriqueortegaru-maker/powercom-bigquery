begin

declare prefijo string;

set prefijo = 'PLAC';

--call `mm-commissions-reporting.COMISIONES.pr_placas`(202310);
--call `mm-commissions-reporting.COMISIONES.pr_validar_agrupacion_canal`(null, 'PLAC', 125612.80)

create or replace table TEMP.placas as 
select 
id_mes_pr as id_mes,
prefijo||'_'||cast(id_mes_pr as string)||'_'||cast(record_id as string) as commission_id,
b.canal,
C.agrupacion_canal,
C.COD_CANAL,
concept as concepto,
concept_type as tipo_concepto,
qty as unidades,
base_amount as comision,
case when substr (concept,1,1) in ('F','H') and b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista else b.id_comisionista end id_comisionista,
distribuidor,
b.id_comisionista as sfid_id,
sale_dealer as seller,
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
cast (null as string) as account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
PARSE_DATE('%Y%m%d', sale_date) AS sale_date,
PARSE_DATE('%Y%m%d', activation_date) AS activation_date,
PARSE_DATE('%Y%m%d', deactivation_date) AS deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'017' as cod_producto,
'99' AS COD_MARCA,
cast (null as string) as claim_code,
case when  sale_dealer = 'CARIN003'  THEN 'Cross-sell IN' else cast (null as string) end campaign_code,
cast (null as string) as serial_number,
cast (null as float64) as tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from `mm-commissions-reporting.SVA.gs_sva_placas` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b on (a.sale_dealer = b.sfid_id or substr(a.sale_dealer, 1,2) = b.sfid_id) and b.id_mes = id_mes_pr and a.channel = b.canal
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
qualify row_number () over (partition by record_id order by b.cif nulls last) = 1
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, (select array_agg(distinct canal) from TEMP.placas) , 'TEMP.placas' , 'ACTUALIZAR');

end