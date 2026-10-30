begin

--call `mm-commissions-reporting.COMISIONES.pr_manual_alarmas`(202407);


declare prefijo string;

set prefijo = 'R_ALRMS';

create or replace table TEMP.alarmas as 

--___________________________________ CONCEPTO B- ALARMAS -- TODOS LOS CANALES-- EXCEPTO CROSSELLL____________________________
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
CAST(NULL AS STRING) AS distribuidor,
b.id_comisionista as sfid_id,
coalesce(UPPER(split(sale_dealer,'@')[OFFSET(0)]),sale_dealer) as seller,  
 brand_ds as marca,
'SECURITY' as service_type,
cast(msisdn as string) as phone_nm,
sell_tariff_ds as tariff_id,
sell_tariff_ds as tariff_ds,
CAST(NULL AS STRING) AS  service_id,
account_id as account_id,
CAST(NULL AS STRING) AS customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
PARSE_DATE('%Y%m%d',sale_date)  as sale_date,
PARSE_DATE('%Y%m%d',activation_date)  as activation_date,
PARSE_DATE('%Y%m%d',deactivation_date) as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'012' as cod_producto,
CASE WHEN A.brand_ds ='YOIGO' THEN '01'
     WHEN A.brand_ds ='MASMOVIL' THEN '05'
     ELSE '01' END AS cod_marca,
C.COD_CANAL,
CASE
    WHEN a.activation_date < '2024-07-22'
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sale_dealer, 'SECURITY'), tlv_cross_sell.campaign)

    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sale_dealer, 'SECURITY'))
END AS campaign_code,
cast (null as string)  as serial_number,
cast (null as float64) as tax_base,
cast (null as string)  as claim_code,
cast (null as string)  as process_code,
cast (null as string)  as comments,
'C_MANUAL' as facturador,
'calculado' as estado,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,

FROM `mm-commissions-reporting.SVA.gs_sva_alarmas`  a
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b on (a.sale_dealer = b.sfid_id or substr(a.sale_dealer, 1,2) = b.sfid_id) and b.id_mes = id_mes_pr and a.channel = b.canal
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
ON b.id_comisionista = tlv_cross_sell.id_comisionista
AND b.canal = tlv_cross_sell.canal
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
            

;
END