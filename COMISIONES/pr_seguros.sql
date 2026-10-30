begin

declare prefijo string;

set prefijo = '2H-SEGR';

--call `mm-commissions-reporting.COMISIONES.pr_seguros`(202607);
--call `mm-commissions-reporting.COMISIONES.pr_validar_agrupacion_canal`(null, 'SEGR', 16604.74.32);


create or replace table TEMP.seguros as 
select 
id_mes_pr as id_mes,
prefijo||'_'||cast(id_mes_pr as string)||'_'||cast(record_id as string) as commission_id,
'calculado' as estado,
b.canal,
C.agrupacion_canal,
concept as concepto,
a.concept_type AS tipo_concepto,
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
'YOIGO' as marca,
'INSURANCE' as service_type,
cast(msisdn as string) as phone_nm,
cast (null as string) as tariff_id,
cast (null as string) as tariff_ds,
cast (null as string) as service_id,
cast (null as string) as account_id,
customer_id,
cast (null as string) as line_type_ds,
cast (null as string) as bundle_type,
cast (null as string) as technology_ds,
billing_type_ds,
PARSE_DATE('%Y%m%d', sale_date) AS sale_date,
PARSE_DATE('%Y%m%d', activation_date) AS activation_date,
PARSE_DATE('%Y%m%d', deactivation_date) AS deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
CASE WHEN UPPER(CONCEPT) LIKE '%MOVIL%' THEN '061' ELSE '009' END AS cod_producto,
'01' AS COD_MARCA,
C.COD_CANAL,
CASE
    WHEN PARSE_DATE('%Y%m%d', a.activation_date) < '2024-07-22'  --<-- INCLUSION DE NUEVOS SFIDS Y CAMPAÑAS EN TLV CROSS-SELL - JULIO 2024
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell` (b.canal, a.brand_ds, sale_dealer, 'INSURANCE'), TLV_CROSS_SELL.campaign)

    ELSE COALESCE(TLV_CROSS_SELL.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell` (b.canal, a.brand_ds, sale_dealer, 'INSURANCE'))
END AS campaign_code,
cast (null as string) as serial_number,
cast (null as float64) as tax_base,
cast (null as string) as claim_code,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
from `mm-commissions-reporting.SVA.gs_sva_seguros` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b on (a.sale_dealer = b.sfid_id or substr(a.sale_dealer, 1,2) = b.sfid_id)
and b.id_mes = id_mes_pr 
and a.channel = b.canal
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON b.id_comisionista = TLV_CROSS_SELL.id_comisionista AND b.canal = TLV_CROSS_SELL.canal

inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
qualify row_number () over (partition by record_id order by b.cif nulls last) = 1
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('2H-SEGR', id_mes_pr, (select array_agg(distinct canal) from TEMP.seguros) , 'TEMP.seguros' , 'ACTUALIZAR');

end