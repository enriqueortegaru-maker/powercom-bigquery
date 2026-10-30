begin

declare importe_original, importe_resultado float64;
declare err, clave string;

set clave = 'AJMS';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_ajms` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajms` as
with
ajustes as
(
  select *
  from `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES`
  where lower(nivel) = 'master'
  and mes = mes_pr
),
repartos_residencial as
(
select
concepto,
'10' as cod_segmento,
split(reparto_cod_tipo_contrato_segmento_10) as arr
from ajustes
),
repartos_negocios as
(
select
concepto,
'12' as cod_segmento,
split(reparto_cod_tipo_contrato_segmento_12) as arr
from ajustes
),
repartos as
(
select
distinct
concepto,
cod_segmento,
cod_tipo_contrato
from repartos_residencial, unnest(arr) cod_tipo_contrato
union distinct
select
distinct
concepto,
cod_segmento,
cod_tipo_contrato
from repartos_negocios, unnest(arr) cod_tipo_contrato
),
base_comisiones as
(
  select b.concepto, a.*
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working` a
  inner join repartos b using (cod_segmento, cod_tipo_contrato)
  where 1=1
  and descripcion_concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
    and fecha = mes_pr
),
unitario as
(
select a.distribuidor, a.concepto, b.importe, count(1) as eventos,
from base_comisiones a
inner join ajustes b on b.tienda = a.distribuidor  and a.concepto=b.concepto
group by 1,2,3
)
select
  concat (clave,'_NOEX_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number () over () ) as id_registro,
  sociedad ,
  c.codigo as id_comisionista ,
  tipo_comisionista ,
  c.CIF ,
  c.zona_fiscal ,
  d.tipo_concepto as tipo_concepto ,
  d.concepto as descripcion_concepto ,
  null as uds,
  round(d.importe / eventos , 2) as importe_base ,
  moneda ,
  via_pago ,
  cond_pago ,
  cod_canal ,
  cod_producto ,
  cod_tipo_contrato ,
  cod_marca ,
  cod_operador ,
  cod_segmento ,
  'C_MANUAL' as facturador ,
  'Y - Ajustes Master' as clasificacion_concepto ,
  canal ,
  subscription_id ,
  product_type ,
  bundle_type ,
  msisdn ,
  fecha_activacion ,
  fecha_baja ,
  account_id ,
  customer_id ,
  sfid_unico ,
  a.tienda ,
  a.distribuidor ,
  fecha ,
  agrupacion_cod_tipo_contrato ,
  segmento ,
  c.razon_social ,
  c.nombre as nombre_comercio ,
  marca ,
  order_id,
Product_Id,
Product,
user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
  from base_comisiones a
  inner join unitario b using (distribuidor, concepto)
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` c on a.distribuidor=c.nombre
  inner join ajustes d on d.tienda = a.distribuidor and a.concepto = d.concepto
  ;

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajms` 
with resultado as
(
select 
a.descripcion_concepto, a.distribuidor, round(sum(importe_base),2) as importe_base
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajms` a
group by 1,2
)
select 
  concat (clave,'_NOEX_B_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number () over () ) as id_registro,
  'X001' sociedad ,
  c.codigo as id_comisionista ,
  'DEA' as tipo_comisionista ,
  c.CIF ,
  c.zona_fiscal ,
  d.tipo_concepto ,
  d.concepto as descripcion_concepto ,
  null as UDS,
  round(d.importe - a.importe_base,2) as importe_base ,
  'EUR' as moneda ,
  'C' as via_pago ,
  'Z001' as cond_pago,
  '29' as cod_canal,
  '040' as cod_producto ,
  '61' as cod_tipo_contrato ,
  '05' cod_marca ,
  '999' cod_operador ,
  case when d.reparto_cod_tipo_contrato_segmento_10 is not null then '10' else '12' end cod_segmento ,
  'C_MANUAL' facturador ,
  'Y - Ajustes Master' as clasificacion_concepto ,
  'MI' as canal ,
  cast (NULL as string) as subscription_id ,
  cast (NULL as string) as product_type ,
  cast (NULL as string) as bundle_type ,
  cast (NULL as string) as msisdn ,
  cast (NULL as date) as fecha_activacion ,
  cast (NULL as date) as fecha_baja ,
  cast (NULL as string) as account_id ,
  cast (NULL as string) as customer_id ,
  cast (NULL as string) as sfid_unico ,
  cast (NULL as string) as tienda ,
  distribuidor ,
  mes_pr as fecha ,
  'FMC' as agrupacion_cod_tipo_contrato ,
  'Residencial' as segmento ,
  c.razon_social as razon_social ,
  c.nombre as nombre_comercio ,
  'MASMOVIL' as marca ,
  cast (NULL as string) as order_id ,
  cast (NULL as string) as Product_Id ,
  cast (NULL as string) as Product ,
  cast (NULL as string) as user_id ,
  cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from resultado a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_MASTER` b on a.distribuidor=b.master
inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` c on a.distribuidor=c.nombre
inner join `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES` d on d.tienda = a.distribuidor and lower(nivel) = 'master' and d.mes = mes_pr and a.descripcion_concepto = d.concepto
where round(d.importe - a.importe_base,2)  <> 0;

-- Validacion de importes --

set importe_original = (
  select
  sum (importe)
  from `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES`
  where nivel = 'master'
  and mes = mes_pr
);

set importe_resultado = (
  select 
  round(sum(importe_base),2) as importe_base
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajms` a
);

if importe_original <>  importe_resultado then RAISE USING MESSAGE = 'Importes no cuadran: importe original: '
|| cast(importe_original as string)
|| ', importe resultado: '
|| cast(importe_resultado as string);
end if;

-- Actualización tabla final --

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_ajms',
  'NO_EXCLUSIVO.comisiones_working'
);


end