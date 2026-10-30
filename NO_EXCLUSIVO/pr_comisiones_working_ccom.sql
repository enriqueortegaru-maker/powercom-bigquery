begin
--call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_ccom`(date_trunc(date_add (current_date (), interval -1 month), month));
declare err, desc_validacion, clave string;

set clave = 'CCOM';

-- Validacion de conceptos a clasificar --

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ccom` as
with
calculo as 
(
select
'CCOM_'||MIN(Commission_Id) AS id_registro,
case
  when upper(brand) = 'PEPEPHONE' and c.tipo_concepto = 'ENRG' THEN '7100'
  when upper(brand) = 'PEPEPHONE' THEN '7000'
  else 'X001' end as sociedad,
coalesce (h.codigo,  case comisionista
  when 'CIF PDV' then b.sfid_unico
  when 'CIF MASTER' then b.distribuidor
  when 'CIF GPV' then
  case 
  when b.CIF_GPV = 'B87430658' THEN 'MASTER01'
  when b.CIF_GPV = 'B94153343' THEN 'MASTER02'
  when b.CIF_GPV = 'B30898027' THEN 'MASTER03'
  when b.CIF_GPV = 'B14628440' THEN 'MASTER07'
  when b.CIF_GPV = 'E23773369' THEN 'MASTER08'
  when b.CIF_GPV = 'B90202623' THEN 'MASTER10'
  when b.CIF_GPV = 'B76754894' THEN 'MASTER12'
  when b.CIF_GPV = 'B26563676' THEN 'MASTER14'
  when b.CIF_GPV = 'B40643389' THEN 'MASTER18'
  when b.CIF_GPV = 'B52554821' THEN 'MASTER20'
  end 
end  ) as id_comisionista,
'DEA' as tipo_comisionista,
 case c.comisionista
  when 'CIF PDV' then b.CIF_PDV
  when 'CIF MASTER' then b.CIF_MASTER
  when 'CIF GPV' then b.CIF_GPV    
  else comisionista
end as CIF,
coalesce (g.zona_fiscal,'PEN') as zona_fiscal,
c.tipo_concepto, 
case
WHEN clawback then concepto_clawback
when ( date(date_trunc(date(activation_date, 'Europe/Madrid'), month)) < mes_pr or adjustment) and substr(c.concepto,1,1) in ('A','B','D','F','G') then
case substr(c.concepto,1,1) when 'A' then 'R' when 'B' then 'R' when 'D' then 'R' when 'E' then 'R' when 'F' then 'S' when 'H' then 'S' when 'G' then 'T' end  || right (c.concepto, length(c.concepto)-1)
else c.concepto end as descripcion_concepto,
1 as uds,
round(sum(Amount),2) as importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
d.cod_canal,
case 
  when c.cod_producto is not null then c.cod_producto
  when c.tipo_concepto = 'ENRG' then '014' 
  when UPPER(c.concepto) like '%TV%' then '006'
  when UPPER(c.concepto) like '%TELEVI%' then '006'
  when a.product_type in ('INTERNET', 'FIX') and i.service_id is not null then '041'
  when Subscription_Origin like '%PORT%' then '040'
else '039'
end as cod_producto,
case
  when c.tipo_contrato = 'Prepago' THEN '10'
  when a.Payment_Mode = 'PREPAID' THEN '10'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type in ('INTERNET', 'FIX') then (case when a.Technology = 'ADSL' then '62' else '63' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '66' else '67' end)
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type in ('ADDITIONAL', 'EXTRA') and upper(brand) = 'YOIGO' then '68'
  when a.product_type = 'MOBILE' then '20'
else '99' end as cod_tipo_contrato,
case
  when c.tipo_concepto = 'ENRG' and upper(Brand) = 'PEPEPHONE' then '19'
  when c.tipo_concepto = 'ENRG' and upper(Brand) = 'MASMOVIL' then '17'
  when c.tipo_concepto = 'ENRG' then '99'
  when upper(Brand) = 'MASMOVIL' then '05'
  when upper(Brand) = 'PEPEPHONE' then '06'
  when upper(Brand) = 'GUUK' then '13'
  when upper(Brand) = 'LLAMAYA' then '04'
  when upper(Brand) = 'YOIGO' then '01'
  else '99'
end as cod_marca,
'999' as cod_operador,
case
  when upper(Brand) = 'GUUK' then '10'
  when upper(Brand) = 'LLAMAYA' then '10'
  when segment = 'B2C' then '10'
  when segment = 'SOHO' then '12'
  when segment = 'B2B' then '12'
else '10' end as cod_segmento,
'C_MANUAL' as facturador,
------ TRAZABILIDAD ------
case
when clawback and substr (concepto_clawback,1,1) = 'E' then 'E - Clawback'
when clawback and substr (concepto_clawback,1,1) = 'H' then 'H - Clawback gestión de canal'
when ( date(date_trunc(date(activation_date, 'Europe/Madrid'), month)) < mes_pr or adjustment) and substr(c.concepto,1,1) in ('A','B','D','F','G') then
case
when substr(c.concepto,1,1) in ('A','B','D','E') then 'R - Recalculo periodo anterior'
when substr(c.concepto,1,1) in ('F','H') then 'S - Recalculo periodo anterior master'
when substr(c.concepto,1,1) in ('G') then 'T - Recalculo periodo anterior gestion GPV'
else c.Bloque end else c.Bloque end as clasificacion_concepto,
a.Channel as canal,
subscription_id,
product_type,
bundle_type,
msisdn,
date(activation_date, 'Europe/Madrid') as fecha_activacion,
date(unsubscription_date, 'Europe/Madrid') as fecha_baja,
account_id,
customer_id,
sfid_unico,
sfid_unico as tienda,
b.distribuidor as distribuidor,
case when date_trunc ( date(date(activation_date, 'Europe/Madrid')) , month ) > mes_pr then date_trunc ( date(date(activation_date, 'Europe/Madrid')) , month ) else mes_pr end as fecha,
case
  when c.tipo_contrato = 'Prepago' THEN 'Prepago'
  when a.Payment_Mode = 'PREPAID' THEN 'Prepago'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then 'FMC'
  when a.product_type in ('INTERNET', 'FIX') then '2P'
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then 'FMC'
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then 'Adicional'
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type in ('ADDITIONAL', 'EXTRA') and upper(brand) = 'YOIGO' then 'Adicional'
  when a.product_type = 'MOBILE' then 'MO'
else 'Otros servicios' end as agrupacion_cod_tipo_contrato,
case
  when upper(Brand) = 'GUUK' then 'Residencial'
  when upper(Brand) = 'LLAMAYA' then 'Residencial'
  when segment = 'B2C' then 'Residencial'
  when segment = 'SOHO' then 'Negocios'
  when segment = 'B2B' then 'Negocios'
else 'Residencial' end as segmento,
g.vendor_name as razon_social,
h.nombre_comercio as nombre_comercio,
upper(brand) as marca,
order_id,
Product_Id,
Product,
SFID_Origin as user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
FROM `mm-commissions-reporting.SANDBOX.v_mcom`   a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto`  b on a.sale_dealer = b.sfid
left join `mm-commissions-reporting.NO_EXCLUSIVO.NORMALIZACION_DESCRIPCION` e on a.Description = e.Description
inner join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` c on coalesce ( e.concepto , a.Description ) = c.concepto
inner join `mm-commissions-reporting.NO_EXCLUSIVO.CANALES` d on a.Channel = d.channel
left join `mm-commissions-reporting.REPORTED.mcom_reported` f on a.Commission_Id = f.id_registro_mcom
left join `mm-commissions-reporting.SAP.vendor_list` g 
  on case comisionista when 'CIF PDV' then b.CIF_PDV when 'CIF MASTER' then b.CIF_MASTER when 'CIF GPV' then b.CIF_GPV else comisionista end = g.tax_code
left join `mm-commissions-reporting.NO_EXCLUSIVO.v_detalle_cif` h
  on case comisionista when 'CIF PDV' then b.CIF_PDV when 'CIF MASTER' then b.CIF_MASTER when 'CIF GPV' then b.CIF_GPV else comisionista end = h.cif
left join 
  (
    SELECT distinct service_id
    FROM `mm-datamart-kd.SERVICES.ventas_base_net`
    WHERE order_type_agg = 'STC'
    and brand_ds = 'YOIGO'
    and activation_date >= mes_pr
  ) i on a.Subscription_Id = i.service_id and a.Brand = 'YOIGO'
where A.Channel  in ('MI','MP','MR','CA', 'NR')
and a.Description is not null
and f.id_registro_mcom is null
and substr(A.description,1,1) = 'C'
group by 2,3,4,5,6,7,8,9,
11,12,13,14,15,16,17,18,19,20,
21,22,23,24,25,26,27,28,29,30,
31,32,33,34,35,36,37,38,39,40,
41,42,43
)
select a.*
from calculo a
/*
inner join
  (
    select distinct cif from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mcom`
  ) j on a.cif = J.cif
where a.cif is not null
*/
where 
not (marca = 'YOIGO' and Distribuidor = 'PHONE HOUSE')
and a.product not in ('TARIFA MASXMENOS PRO 20GB CONV', 'TARIFA MASxMENOS 20GB CONV')
and a.importe_base > 0
;

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_ccom',
  'NO_EXCLUSIVO.comisiones_working'
);

end