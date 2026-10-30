begin

-- call `mm-commissions-reporting.D2D.pr_comisiones_working_recl`(date_trunc(date_add (current_date (), interval -2 month), month));
declare err, desc_validacion, clave string;
--declare mes_pr date;
set clave = 'RECL';
--set mes_pr= '2023-01-01';

create or replace table `mm-commissions-reporting.D2D.comisiones_working_recl` as
select
clave||'_D2D_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
case
  when upper(marca) = 'PEPEPHONE' and c.tipo_concepto = 'ENRG' THEN '7100'
  when upper(marca) = 'PEPEPHONE' THEN '7000'
  else 'X001' end as sociedad,
billing_dealer as id_comisionista,
'DEA' as tipo_comisionista,
documento as CIF,
V.zona_fiscal,
tipo_concepto,
substr('Z - '||substr(a.concepto,5,length(a.concepto)-4),1,45) as descripcion_concepto,
unidades as uds,
importe,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'22' cod_canal,
case 
  when c.cod_producto is not null then c.cod_producto
  when c.tipo_concepto = 'ENRG' then '014' 
  when UPPER(c.concepto) like '%TV%' then '006'
  when UPPER(c.concepto) like '%TELEVI%' then '006'
  when origen_suscripcion like '%PORT%' then '040'
else '039'
end as cod_producto,
case
  when a.bundle_type = 'FMC' then (case when a.technology = 'ADSL' then '60' else '61' end)
  else  (case when a.technology = 'ADSL' then '62' else '63' end)
  end as cod_tipo_contrato,
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
'D2D' AS canal,
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
date('2023-02-01') as fecha,
case
  when a.bundle_type = 'FMC' then 'FMC'
  else '2P'
  end as agrupacion_cod_tipo_contrato,
case
  when upper(marca) = 'GUUK' then 'Residencial'
  when upper(marca) = 'LLAMAYA' then 'Residencial'
  when cod_segmento = '12' then 'Negocios'
  else 'Residencial' end as segmento,
v.vendor_name as razon_social,
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
from `mm-commissions-reporting.D2D.RECLAMACIONES` a
 inner join  `mm-commissions-reporting.D2D.v_dealers` b on a.dealer = b.billing_dealer
inner join `mm-commissions-reporting.D2D.v_conceptos_factura`  c on a.concepto = c.concepto
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = b.documento
where a.fecha_liquidacion = mes_pr
;


call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'D2D.comisiones_working_recl',
  'D2D.comisiones_working'
);


END