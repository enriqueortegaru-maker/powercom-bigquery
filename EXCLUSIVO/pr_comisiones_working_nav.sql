begin
-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_nav`(date_trunc(date_add (current_date (), interval -2 month), month));

declare clave string;

set clave = 'NAV';

create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_working_nav` as
with conceptos as
(
select * except (concepto_clawback, concepto_recalculo) from `mm-commissions-reporting.EXCLUSIVO.CONCEPTOS_FACTURA`
union all
select concepto_clawback, * except (concepto,concepto_clawback, concepto_recalculo) from `mm-commissions-reporting.EXCLUSIVO.CONCEPTOS_FACTURA`
union all
select concepto_recalculo, * except (concepto,concepto_clawback, concepto_recalculo) from `mm-commissions-reporting.EXCLUSIVO.CONCEPTOS_FACTURA`
),
navision as
(select *,
  case 
      when a.tipo_trazabilidad like '%BONUS MENSUAL%' then 'D - Bonus mensual'
      when a.tipo_trazabilidad like '%CALIDAD%' then  'C - Calidad '||REPLACE (a.categorizacion, 'M', '') ||' meses'
      when a.tipo_trazabilidad like '%RAPPEL MENSUAL' then 'D - Rappel mensual'
      WHEN a.tipo_mov_comision like '%PORTABILIDAD FIJO%' then 'A - Portabilidad Fijo'
      WHEN a.tipo_mov_comision like '%PORTABILIDAD MOVIL%' then 'A - Portabilidad Movil Pospago'
      WHEN a.tipo_mov_comision like '%GEST.CANAL%' then 'F - Gestion de canal'
     WHEN a.tipo_mov_comision like '%APOYO C.ML.%' then 'A - Servicio Movil Pospago'
     WHEN a.tipo_mov_comision like '%ANUL. APOYO C.ML%' then 'E - Clawback Servicio Movil Pospago'
     WHEN a.tipo_mov_comision like '%DEV.SIM%' then 'B - Devolucion SIM'
     WHEN a.tipo_mov_comision like '%RAPPEL%' then 'D - Rappel'
     WHEN a.tipo_mov_comision like '%ANUL.%' then 'E - Clawback Servicio Fijo'
     WHEN a.tipo_mov_comision like 'ALTA%' then 'A - Servicio Fijo'
     WHEN a.tipo_mov_comision like 'AGILE TV' then 'B - Television'
        WHEN a.tipo_mov_comision like 'PORTABILIDAD' then 'A - Portabilidad Prepago'
ELSE 'SIN CLASIFICAR'
END AS concepto,
from `mm-commissions-reporting.SANDBOX.comisiones_navision_*` a
where PARSE_DATE('%Y%m', SUBSTR(_table_suffix,1,6)) = mes_pr
)
select
'NAV_'||a.id_movimiento AS id_registro,
'X001' as sociedad,
b.nombre as id_comisionista,
'DEA' as tipo_comisionista,
b.documento as CIF,
b.zona_fiscal,
c.tipo_concepto,
 c.concepto descripcion_concepto,
1 as uds,
round(cast(a.importe as float64),2) as importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'27' as cod_canal,
  case 
     when c.cod_producto is not null then c.cod_producto
    when c.tipo_concepto = 'ENRG' then '014'
    when UPPER(c.concepto) like '%TV%' then '006'
    when UPPER(c.concepto) like '%TELEVI%' then '006'
     else a.codigo_producto
   end as cod_producto,
a.tipo_contrato as cod_tipo_contrato,
case 
  when a.marca = '05' then '05'
  when a.marca = '04' then '04'
  when a.marca = '16' then '13'
  when a.marca = '13' then '13'
ELSE  '05'
END as cod_marca,
a.operador as cod_operador,
a.segmento as cod_segmento,
concat('C_NAVISION') as facturador,
------ TRAZABILIDAD ------
case 
substr (c.concepto,1,1)
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

case 
when a.cod_Cliente LIKE 'LB' then 'LB'
ELSE 'LB'
end as canal,

a.suscription_Id as subscription_id,
case 
when a.cod_producto = '006' then 'TV'
when tipo_contrato = '99' then 'MOBILE'
when A.oferta_Convergente =0 then 'MOBILE'
when a.tipo_contrato = '20' then 'MOBILE'
when a.tipo_contrato in ('60', '61') and substr (a.msisdn,1,1) in ('6', '7') then 'MOBILE'
when a.tipo_contrato in ('60', '61') then 'INTERNET'
when tipo_contrato = '62' then 'INTERNET'
when tipo_contrato = '63' then 'INTERNET'
when tipo_contrato = '66' then 'MOBILE'
when tipo_contrato = '67' then 'MOBILE'
when tipo_contrato = '68' then 'MOBILE'
else 'MOBILE' end as product_type,
case 
when A.oferta_Convergente =0 then 'MO'
when a.tipo_contrato IN ('10','20') then 'MO'
when a.tipo_contrato = '60' then 'FMC'
when tipo_contrato = '61' then 'FMC'
when tipo_contrato = '62' then '2P'
when tipo_contrato = '63' then '2P'
when tipo_contrato = '66' then 'MO'
when tipo_contrato = '67' then 'MO'
when tipo_contrato = '68' then 'MO'
when tipo_contrato = '99' then 'MO'
else 'Otros servicios' end as bundle_type,
a.msisdn,
a.fecha_activacion as fecha_activacion,
a.fecha_baja,
a.num_contrato as account_id,
'' as customer_id,
a.cod_Cliente as sale_dealer,
CASE WHEN a.cod_cliente_punto_venta LIKE '%-%' THEN split(a.cod_cliente_punto_venta,'-')[OFFSET(0)] ELSE COALESCE(a.cod_cliente_punto_venta, a.cod_cliente) END as tienda,
distribuidor,
mes_pr as fecha,
--'20220801' as fecha,
case a.tipo_contrato
when '10' then 'Prepago'
when '20' then 'MO'
when '60' then 'FMC'
when '61' then 'FMC'
when '62' then '2P'
when '63' then '2P'
when '66' then 'Adicional'
when '67' then 'Adicional'
when '68' then 'Adicional'
else 'Otros servicios' end as agrupacion_cod_tipo_contrato,
case a.segmento 
when '10' then 'Residencial' else 'Negocios' end as segmento,
b.razon_social,
b.nombre as nombre_comercio,
CASE marca
WHEN '05' then 'MASMOVIL'
WHEN '04' then 'LLAMAYA'
WHEN '13' then 'GUUK'
else marca end as marca,
  cast (NULL as string) as order_id ,
  cast (NULL as string) as Product_Id ,
  a.tipo_paquete as Product ,
CASE WHEN a.cod_cliente_punto_venta LIKE '%-%' THEN split(a.cod_cliente_punto_venta,'-')[OFFSET(1)] ELSE COALESCE(a.cod_cliente_punto_venta, a.cod_cliente) END as user_id ,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from navision a
inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` b on a.cod_Cliente = b.billing_dealer
inner join conceptos c on a.concepto = c.concepto
WHERE (a.cod_Cliente LIKE 'LB%' )
AND round(cast(a.importe as float64),2) <> 0
and a.id_movimiento >=227958938
--and b.comisiona
;

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'EXCLUSIVO.comisiones_working_nav',
  'EXCLUSIVO.comisiones_working'
);

end