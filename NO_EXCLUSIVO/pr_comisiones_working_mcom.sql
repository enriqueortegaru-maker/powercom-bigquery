begin
-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_mcom`(date_trunc(date_add (current_date (), interval -1 month), month));
declare err, desc_validacion, clave string;

set clave = 'MCOM';

-- Validacion de conceptos a clasificar --

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mcom` as
with 
calculo as 
(
select
'MCOM_'||Commission_Id AS id_registro,
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
when ( date(date_trunc(date(activation_date, 'Europe/Madrid'), month)) < mes_pr or adjustment) and substr(c.concepto,1,1) in ('A','B','D','F','G','H') then
case substr(c.concepto,1,1) when 'A' then 'R' when 'B' then 'R' when 'D' then 'R' when 'E' then 'R' when 'F' then 'S' when 'H' then 'S' when 'G' then 'T' end  || right (c.concepto, length(c.concepto)-1)
else c.concepto end as descripcion_concepto,
case when upper(factura_con_unidades) = 'SI' then 1 else null end as uds,
round(Amount,2) as importe_base,
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
  when j.service_id is not null then '12'
  when upper(Brand) = 'GUUK' then '10'
  when upper(Brand) = 'LLAMAYA' then '10'
  when segment = 'B2C' then '10'
  when segment = 'SOHO' then '12'
  when segment = 'B2B' then '12'
else '10' end as cod_segmento,
concat('C_MCOM') as facturador,
------ TRAZABILIDAD ------
case
when clawback and substr (concepto_clawback,1,1) = 'E' then 'E - Clawback'
when clawback and substr (concepto_clawback,1,1) = 'H' then 'H - Clawback gestión de canal'
when ( date(date_trunc(date(activation_date, 'Europe/Madrid'), month)) < mes_pr or adjustment) and substr(c.concepto,1,1) in ('A','B','D','F','G','H') then
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
case when upper(criterio_fecha) = 'VENTA' then date(sale_date, 'Europe/Madrid') else date(activation_date, 'Europe/Madrid') end as fecha_activacion,
case when upper(criterio_fecha) = 'VENTA' then null else date(unsubscription_date, 'Europe/Madrid') end as fecha_baja,
account_id,
customer_id,
sfid_unico,
sfid_unico as tienda,
b.distribuidor as distribuidor,
case
when forzar_mcom = 1 then mes_pr
when clawback then date_trunc (date(unsubscription_date, 'Europe/Madrid'), month) else date_trunc (date(activation_date, 'Europe/Madrid'), month) end as fecha,
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
CONTROL.f_cod_segmento_a_segmento (case
  when j.service_id is not null then '12'
  when upper(Brand) = 'GUUK' then '10'
  when upper(Brand) = 'LLAMAYA' then '10'
  when segment = 'B2C' then '10'
  when segment = 'SOHO' then '12'
  when segment = 'B2B' then '12'
else '10' end ) as segmento,
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
left join 
  (
    SELECT distinct a.brand_ds as marca, coalesce(b.service_id,a.service_id)  service_id
    FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
    left join `mm-datamart-kd.SERVICES.internet_base_emysim` b on a.service_id = b.fix_service_id
    WHERE a.segment_ds != 'RESIDENCIAL'
  ) j on a.Subscription_Id = j.service_id and upper(a.Brand) = j.marca
where A.Channel  in ('MI','MP','MR','CA', 'NR')
and a.Description is not null
and c.calculo = 'MCOM'
and f.id_registro_mcom is null
)
select a.*
from calculo a
where a.cif is not null
and not (marca = 'YOIGO' and Distribuidor = 'PHONE HOUSE')
and coalesce (a.product,'NULO') not in ('TARIFA MASXMENOS PRO 20GB CONV', 'TARIFA MASxMENOS 20GB CONV')
and a.fecha = mes_pr
;

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_mcom',
  'NO_EXCLUSIVO.comisiones_working'
);

end