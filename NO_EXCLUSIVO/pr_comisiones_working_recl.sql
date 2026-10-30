begin

declare err, desc_validacion, clave string;

declare importe_gs, importe_tabla FLOAT64;

set clave = 'RECL';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_recl` (date_trunc(date_add (current_date (), interval -1 month), month));


set importe_gs = (select sum(importe) from `mm-commissions-reporting.NO_EXCLUSIVO.RECLAMACIONES` where fecha_liquidacion = mes_pr);

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_recl` as
select
clave||'_NOEX_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
case
  when upper(marca) = 'PEPEPHONE' and c.tipo_concepto = 'ENRG' THEN '7100'
  when upper(marca) = 'PEPEPHONE' THEN '7000'
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
zona_fiscal,
tipo_concepto,
substr('Z - '||substr(a.concepto,5,length(a.concepto)-4),1,45) as descripcion_concepto,
unidades as uds,
importe as importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'29' as cod_canal,
case 
  when c.cod_producto is not null then c.cod_producto
  when c.tipo_concepto = 'ENRG' then '014' 
  when UPPER(c.concepto) like '%TV%' then '006'
  when UPPER(c.concepto) like '%TELEVI%' then '006'
  when origen_suscripcion like '%PORT%' then '040'
else '039'
end as cod_producto,
case
  when c.tipo_contrato = 'Prepago' THEN '10'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type in ('INTERNET', 'FIX') then (case when a.Technology = 'ADSL' then '62' else '63' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '66' else '67' end)
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type in ('ADDITIONAL', 'EXTRA') and upper(marca) = 'YOIGO' then '68'
  when a.product_type = 'MOBILE' then '20'
else '99' end as cod_tipo_contrato,
case
  when upper(marca) = 'MASMOVIL' then '05'
  when upper(marca) = 'PEPEPHONE' then '06'
  when upper(marca) = 'GUUK' then '13'
  when upper(marca) = 'LLAMAYA' then '04'
  when upper(marca) = 'YOIGO' then '01'
  else '99'
end as cod_marca,
'999' as cod_operador,
case
  when upper(marca) = 'GUUK' then '10'
  when upper(marca) = 'LLAMAYA' then '10'
  else cod_segmento end as cod_segmento,
'C_MANUAL' AS facturador,
'Z - Ajustes' as clasificacion_concepto,
case subchannel
when 'MASINDIRECTO' then 'MI'
when 'NATIONAL RETAIL' then 'NR'
when 'MASPROXIMO' then 'MP'
when 'CANAL ALTERNATIVO' then 'NR'
when 'MASREGIONAL' then 'MR'
when 'CADENAS' then 'CA'
end as canal,
cast(service_id as string) as subscription_id,
product_type,
bundle_type,
msisdn,
activation_date fecha_activacion,
deactivation_date as fecha_baja,
account_id,	
customer_id,		
dealer as sale_dealer,
dealer as tienda,
distribuidor,
mes_pr as fecha,
case
  when c.tipo_contrato = 'Prepago' THEN 'Prepago'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then 'FMC'
  when a.product_type in ('INTERNET', 'FIX') then '2P'
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then 'FMC'
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then 'Adicional'
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type in ('ADDITIONAL', 'EXTRA') and upper(marca) = 'YOIGO' then 'Adicional'
  when a.product_type = 'MOBILE' then 'MO'
else 'Otros servicios' end as agrupacion_cod_tipo_contrato,
case
  when upper(marca) = 'GUUK' then 'Residencial'
  when upper(marca) = 'LLAMAYA' then 'Residencial'
  when cod_segmento = '12' then 'Negocios'
  else 'Residencial' end as segmento,
h.razon_social,
vendor_name as nombre_comercio, 
marca,
cast(null as string) as order_id,
cast(null as string) as product_id,
product,
dealer as user_id,
cast(null as string) campaign_code,
com claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.NO_EXCLUSIVO.RECLAMACIONES` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` b on a.dealer = b.sfid
inner join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` c on a.concepto = c.concepto
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = case comisionista when 'CIF PDV' then b.CIF_PDV when 'CIF MASTER' then b.CIF_MASTER when 'CIF GPV' then b.CIF_GPV else comisionista end
left join `mm-commissions-reporting.NO_EXCLUSIVO.v_detalle_cif` h
  on case comisionista when 'CIF PDV' then b.CIF_PDV when 'CIF MASTER' then b.CIF_MASTER when 'CIF GPV' then b.CIF_GPV else comisionista end = h.cif
where a.fecha_liquidacion = mes_pr
;


set importe_tabla = (select sum(importe_base) from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_recl` );

if abs(importe_gs - importe_tabla) > 0.01
then RAISE USING MESSAGE = 'Importes no cuadran: , importe gs:'||cast ( importe_gs as string)||', importe tabla:'||cast ( importe_tabla as string);
end if;


call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_recl',
  'NO_EXCLUSIVO.comisiones_working'
);


END