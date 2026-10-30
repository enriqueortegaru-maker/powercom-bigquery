BEGIN

declare clave string;

set clave = 'SEGR';

--CALL `mm-commissions-reporting.D2D.pr_comisiones_working_segr`(date_trunc(date_add (current_date (), interval -1 month), month));

CREATE OR REPLACE TABLE `mm-commissions-reporting.D2D.comisiones_working_segr` AS
select
clave||'_D2D_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
'X001' sociedad,
billing_dealer as id_comisionista,
'DEA' as tipo_comisionista,
documento as CIF,
substr(b.zona_fiscal,1,3) as zona_fiscal,
'CSSG' tipo_concepto,
a.concept as descripcion_concepto,
1 as uds,
base_amount AS importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'22' as cod_canal,
'999' cod_producto,
'99' as cod_tipo_contrato,
'99' AS cod_marca,
'999' as cod_operador,
segment_ds as cod_segmento,
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
'D2D' as canal,
cast ( null as string ) as subscription_id,
cast ( null as string ) AS product_type,
cast ( null as string ) as bundle_type,
cast ( null as string ) as msisdn,
activation_date as fecha_activacion,
cast(null as date) as fecha_baja,
cast ( null as string ) as account_id,	
cast ( null as string ) as customer_id,		
sale_dealer AS sfid_unico,
sale_dealer AS tienda,
distribuidor,
mes_pr as fecha,
'Otros servicios' as agrupacion_cod_tipo_contrato,
case
  when segment_ds = '12' then 'Negocios'
else 'Residencial' end as segmento,
v.vendor_name as razon_social,
b.nombre as nombre_comercio,
'SEGUROS' AS marca,
cast(null as string) as order_id,
cast(null as string) product_id,
cast(null as string) product,
a.sale_dealer as user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.SVA.gs_sva_seguros` a
inner join `mm-commissions-reporting.D2D.v_dealers` b on a.sale_dealer = b.billing_dealer
inner join `mm-commissions-reporting.D2D.v_conceptos_factura` c on a.concept = c.concepto
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = b.documento
;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'D2D.comisiones_working_segr',
  'D2D.comisiones_working'
);

END