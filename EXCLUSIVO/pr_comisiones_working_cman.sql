begin

declare err, clave string;

declare importe_sheets, importe_calculado float64;

set clave = 'CMAN';

-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_cman` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_working_cman` as
select
concat (clave, '_EXCL_',id) as id_registro,
case
  when upper(marca) = 'PEPEPHONE' and c.tipo_concepto = 'ENRG' THEN '7100'
  when upper(marca) = 'PEPEPHONE' THEN '7000'
  else 'X001' end as sociedad,
billing_dealer as id_comisionista,
'DEA' as tipo_comisionista,
documento as CIF,
b.zona_fiscal,
tipo_concepto,
a.concepto as descripcion_concepto,
1 as uds,
round(importe,2) as importe_base, 
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'27' cod_canal,
case 
  when c.cod_producto is not null then c.cod_producto
  when c.tipo_concepto = 'ENRG' then '014' 
  when UPPER(c.concepto) like '%TV%' then '006'
  when UPPER(c.concepto) like '%TELEVI%' then '006'
  when origen_suscripcion like '%PORT%' then '040'
else '039'
end as cod_producto,
case
  when a.billing_type = 'PREPAID' THEN '10'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type in ('INTERNET', 'FIX') then (case when a.Technology = 'ADSL' then '62' else '63' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '66' else '67' end)
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type = 'ADDITIONAL' and upper(marca) = 'YOIGO' then '68'
  when a.product_type = 'MOBILE' then '20'
else '99' end as cod_tipo_contrato,
case
  when c.tipo_concepto = 'ENRG' and upper(marca) = 'PEPEPHONE' then '19'
  when c.tipo_concepto = 'ENRG' and upper(marca) = 'MASMOVIL' then '17'
  when c.tipo_concepto = 'ENRG' then '99'
  when upper(marca) = 'MASMOVIL' then '05'
  when upper(marca) = 'PEPEPHONE' then '06'
  when upper(marca) = 'GUUK' then '13'
  when upper(marca) = 'LLAMAYA' then '04'
  when upper(marca) = 'YOIGO' then '01'
end as cod_marca,
'999' as cod_operador,
coalesce(cod_segmento,'10') as cod_segmento,
concat('C_MANUAL') as facturador,
------ TRAZABILIDAD ------
CONTROL.f_clasificacion_concepto (a.concepto) as clasificacion_concepto,
a.canal as canal,
service_id,
product_type,
bundle_type,
msisdn,
activation_date as fecha_activacion,
deactivation_date  as fecha_baja,
account_id,
customer_id,
Dealer as sfid_unico,
Dealer as tienda,
b.distribuidor as distribuidor,
mes_pr as fecha,
CONTROL.f_cod_tipo_contrato_a_agrupacion_cod_tipo_contrato (case
  when a.billing_type = 'PREPAID' THEN '10'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type in ('INTERNET', 'FIX') then (case when a.Technology = 'ADSL' then '62' else '63' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '66' else '67' end)
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type = 'ADDITIONAL' and upper(marca) = 'YOIGO' then '68'
  when a.product_type = 'MOBILE' then '20'
else '99' end) agrupacion_cod_tipo_contrato,
CONTROL.f_cod_segmento_a_segmento (coalesce(cod_segmento,'10')) as segmento,
razon_social,
nombre as nombre_comercio,
upper(marca) as marca,
cast ( null  as string ) as order_id,
cast ( null  as string ) as  Product_Id,
Product,
cast ( null  as string ) as  user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
FROM `mm-commissions-reporting.EXCLUSIVO.SUBIDA_MANUAL`  a
inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` b on SUBSTR(a.dealer, 1, 2) = b.billing_dealer
inner join `mm-commissions-reporting.EXCLUSIVO.v_conceptos_factura` c on a.concepto = c.concepto
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = b.documento
where a.fecha = mes_pr
;


-- Cuadre de importes --

set importe_sheets = 
    (
    select sum(Importe)
    from `mm-commissions-reporting.EXCLUSIVO.SUBIDA_MANUAL`
    );

set importe_calculado = 
    (
    select sum(Importe_base)
    from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_cman`
    where id_comisionista is not null
    );

SET err = cast((importe_sheets - importe_calculado) as string);

if abs(importe_sheets - importe_calculado) > 0.01 then RAISE USING MESSAGE = 'Importes no cuadran: '
|| err;
end if;


-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'EXCLUSIVO.comisiones_working_cman',
  'EXCLUSIVO.comisiones_working'
);


end