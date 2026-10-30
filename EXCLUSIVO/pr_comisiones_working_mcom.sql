begin
-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_mcom`(date('2023-01-01'))
declare clave string;
set clave = 'MCOM';

create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_working_mcom` as
select
'MCOM_'||Commission_Id AS id_registro,
case
  when upper(brand) = 'PEPEPHONE' and c.tipo_concepto = 'ENRG' THEN '7100'
  when upper(brand) = 'PEPEPHONE' THEN '7000'
  else 'X001' end as sociedad,
b.nombre as id_comisionista,
'DEA' as tipo_comisionista,
b.documento as CIF,
b.zona_fiscal,
c.tipo_concepto, 
case
when a.clawback then concepto_clawback
--when ( date(date_trunc(date(activation_date, 'Europe/Madrid'), month)) < mes_pr or adjustment) then c.concepto_recalculo
else c.concepto
end as descripcion_concepto,
1 as uds, --case when upper(factura_unidades) = 'SI' then 1 else null end as uds,
round(Amount,2) as importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'27' cod_canal,
case 
  when c.cod_producto is not null then c.cod_producto
  when c.tipo_concepto = 'ENRG' then '014' 
  when UPPER(c.concepto) like '%TV%' then '006'
  when UPPER(c.concepto) like '%TELEVI%' then '006'
 -- when a.product_type in ('INTERNET', 'FIX') and e.service_id is not null then '041'
  when Subscription_Origin like '%PORT%' then '040'
else '039'
end as cod_producto,
case
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
concat('C_MCOM') as facturador,
------ TRAZABILIDAD ------
case 
substr (case
when a.clawback then concepto_clawback
--when ( date(date_trunc(date(activation_date, 'Europe/Madrid'), month)) < mes_pr or adjustment) then c.concepto_recalculo
else c.concepto
end,1,1)
when 'A' then 'A - Servicio base'
when 'B' then 'B - SVA'
when 'C' then 'C - Calidad'
when 'D' then 'D - Extracomisión'
when 'E' then 'E - Clawback'
when 'F' then 'F - Gestión de canal'
when 'G' then 'G - Gestión de canal GPV'
when 'H' then 'H - Clawback gestión de canal'
when 'R' then 'R - Recalculo periodo anterior'
when 'S' then 'S - Recalculo periodo anterior master'
when 'P' then 'P - Penalización'
when 'Y' then 'Y - Ajustes Master'
when 'Z' then 'Z - Ajustes'
end as clasificacion_concepto,
'LB'as canal,
subscription_id,
'INSURANCE' AS product_type,
bundle_type,
msisdn,
date(activation_date, 'Europe/Madrid') as fecha_activacion,
date(unsubscription_date, 'Europe/Madrid') as fecha_baja,
account_id,
customer_id,
sale_dealer,
sale_dealer as tienda,
b.distribuidor,
case when date_trunc ( date(date(activation_date, 'Europe/Madrid')) , month ) > mes_pr then date_trunc ( date(date(activation_date, 'Europe/Madrid')) , month ) else mes_pr end as fecha,
--mes_pr as fecha,
case
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
b.razon_social,
b.nombre as nombre_comercio,
upper(brand) as marca,
order_id,
Product_Id,
Product,
SFID_Origin as user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
-- from `mm-mas-commissions-prod.ZZ_COMMISSIONS.SETTLEMENT_PREVIEW`  a
from `mm-commissions-reporting.SANDBOX.v_mcom` a
inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` b on substr(a.Billing_Dealer,1,2) = b.billing_dealer
inner join `mm-commissions-reporting.EXCLUSIVO.CONCEPTOS_FACTURA` c on a.Description = c.concepto
where Description like '%Go%'
and date_trunc ( date(date(activation_date, 'Europe/Madrid')) , month ) = mes_pr
;



-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'EXCLUSIVO.comisiones_working_mcom',
  'EXCLUSIVO.comisiones_working'
);



end