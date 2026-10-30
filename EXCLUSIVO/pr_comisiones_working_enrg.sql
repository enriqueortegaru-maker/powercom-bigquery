BEGIN

declare clave string;

set clave = 'ENRG';

-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_enrg` (date_trunc(date_add (current_date (), interval -1 month), month));


CREATE OR REPLACE TABLE `mm-commissions-reporting.EXCLUSIVO.comisiones_working_enrg` AS
select
clave||'_EXC_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
'X001' sociedad,
billing_dealer as id_comisionista,
'DEA' as tipo_comisionista,
documento as CIF,
b.zona_fiscal,
tipo_concepto,
concepto as descripcion_concepto,
1 as uds,
base_amount AS importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'27' cod_canal,
cod_producto,
'99' as cod_tipo_contrato,
CASE
            WHEN upper(brand_ds) = 'PEPEPHONE' THEN '19'
            WHEN upper(brand_ds) = 'MASMOVIL'  THEN '17'
            WHEN upper(brand_ds) = 'ENERGYGO'  THEN '17'
            WHEN upper(brand_ds) = 'YOIGO'  THEN '16'      
            ELSE '99'
        END AS cod_marca,
'999' as cod_operador,
case
  when upper(Brand_Ds) = 'GUUK' then '10'
  when upper(Brand_Ds) = 'LLAMAYA' then '10'
  when segment_ds = 'B2C' then '10'
  when segment_ds = 'SOHO' then '12'
  when segment_ds = 'B2B' then '12'
else '10' end as cod_segmento,
'C_MANUAL' AS facturador,
CASE SUBSTR(concept, 1, 1)
             WHEN 'A' THEN 'A - Servicio base'
             WHEN 'B' THEN 'B - SVA'
             WHEN 'C' THEN 'C - Calidad'
             WHEN 'D' THEN 'D - Extracomisión'
             WHEN 'E' THEN 'E - Clawback'
             WHEN 'F' THEN 'F - Gestión de canal'
             WHEN 'G' THEN 'G - Gestión de canal GPV'
             WHEN 'H' THEN 'H - Clawback gestión de canal'
             WHEN 'R' THEN 'R - Recalculo periodo anterior'
             WHEN 'S' THEN 'S - Recalculo periodo anterior master'
             WHEN 'P' THEN 'P - Penalización'
             WHEN 'Y' THEN 'Y - Ajustes Master'
             WHEN 'Z' THEN 'Z - Ajustes'
        END as clasificacion_concepto,
'LB' AS canal,
cast(service_id as string) as subscription_id,
product_type_ds AS product_type,
bundle_type,
cast ( msisdn as string ) as msisdn,
activation_date as fecha_activacion,
cast(null as date) as fecha_baja,
cups as account_id,	
cast(customer_id as string) as customer_id,		
sale_dealer AS sfid_unico,
sale_dealer AS tienda,
coalesce ( distribuidor, 'BYMOVIL') as distribuidor,
mes_pr as fecha,
'Otros servicios' as agrupacion_cod_tipo_contrato,
case
  when upper(Brand_Ds) = 'GUUK' then 'Residencial'
  when upper(Brand_Ds) = 'LLAMAYA' then 'Residencial'
  when segment_ds = 'B2C' then 'Residencial'
  when segment_ds = 'SOHO' then 'Negocios'
  when segment_ds = 'B2B' then 'Negocios'
else 'Residencial' end as segmento,
v.vendor_name as razon_social,
b.nombre as nombre_comercio,
UPPER(brand_ds) AS marca,
cast(null as string) as order_id,
cast(null as string) product_id,
cast(null as string) product,
CASE WHEN UPPER(brand_ds) = 'YOIGO' THEN user_id ELSE web_user END as user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.SVA.gs_sva_energia` a
inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` b on SUBSTR(a.sale_dealer, 1, 2) = b.billing_dealer
inner join `mm-commissions-reporting.EXCLUSIVO.v_conceptos_factura` c on a.concept = c.concepto
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = b.documento
where c.tipo_concepto = 'ENRG'
;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'EXCLUSIVO.comisiones_working_enrg',
  'EXCLUSIVO.comisiones_working'
);


END