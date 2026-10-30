BEGIN

declare clave string;

set clave = 'SEGR';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_segr` (date_trunc(date_add (current_date (), interval -1 month), month));


CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_segr` AS
select
'SEGR_NOEX_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
'X001' sociedad,
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
  else upper(comisionista)
end as CIF,
coalesce (zona_fiscal,'PEN') as zona_fiscal,
'CSSG' as tipo_concepto,
concepto as descripcion_concepto,
1 as uds,
base_amount AS importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'29' as cod_canal,
cod_producto,
'99' as cod_tipo_contrato,
'99' as cod_marca,
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
case subchannel
when 'MASINDIRECTO' then 'MI'
when 'NATIONAL RETAIL' then 'NR'
when 'MASPROXIMO' then 'MP'
when 'CANAL ALTERNATIVO' then 'NR'
when 'MASREGIONAL' then 'MR'
when 'CADENAS' then 'CA'
end as canal,
cast(null as string) as subscription_id,
'INSURANCE' AS product_type,
cast(null as string) AS bundle_type,
cast ( null as string ) as msisdn,
activation_date as fecha_activacion,
cast(null as date) as fecha_baja,
cast(null as string) as account_id,	
cast(null as string) as customer_id,		
sale_dealer AS sfid_unico,
sale_dealer AS tienda,
distribuidor,
mes_pr as fecha,
'Otros servicios' as agrupacion_cod_tipo_contrato,
case
  when segment_ds = '12' then 'Negocios'
else 'Residencial' end as segmento,
v.vendor_name as razon_social,
h.nombre_comercio as nombre_comercio,
'SEGUROS' AS marca,
cast(null as string) as order_id,
cast(null as string) product_id,
cast(null as string) product,
sale_dealer as user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.SVA.gs_sva_seguros` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` b on a.sale_dealer = b.sfid
left join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` c on a.concept = c.concepto
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = case comisionista when 'CIF PDV' then b.CIF_PDV when 'CIF MASTER' then b.CIF_MASTER when 'CIF GPV' then b.CIF_GPV else comisionista end
left join `mm-commissions-reporting.NO_EXCLUSIVO.v_detalle_cif` h on case comisionista when 'CIF PDV' then b.CIF_PDV when 'CIF MASTER' then b.CIF_MASTER when 'CIF GPV' then b.CIF_GPV else comisionista end = h.cif
;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_segr',
  'NO_EXCLUSIVO.comisiones_working'
);



END