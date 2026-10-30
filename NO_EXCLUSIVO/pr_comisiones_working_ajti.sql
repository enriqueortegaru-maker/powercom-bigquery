begin

declare importe_original, importe_resultado float64;
declare clave string;

set clave = 'AJTI';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_ajti` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajti` as
with
ajustes as
(
  select *
  from `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES`
  where lower(nivel) = 'tienda'
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
select a.tienda, a.concepto, b.importe, count(1) as eventos,
from base_comisiones a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_buscador_sfid_unico` c on c.sfid_unico = a.tienda
inner join ajustes b on b.tienda = c.sfid  and a.concepto=b.concepto
where b.mes = mes_pr
group by 1,2,3
)
select
  concat (clave,'_NOEX_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro,
  coalesce (sociedad , 'X001') as sociedad,
  coalesce (id_comisionista , s.sfid_unico) as id_comisionista,
  'DEA' as tipo_comisionista,
  coalesce (a.CIF , s.cif_pdv) as CIF,
  coalesce (zona_fiscal , case s.Provincia
  when 'Santa Cruz de Tenerife' then 'CAN'
  when 'Las Palmas' then 'CAN'
  when 'Melilla' then 'MEL'
  when 'Ceuta' then 'CEU'
else 'PEN' END) as zona_fiscal,
  t.tipo_concepto ,
  t.concepto as descripcion_concepto ,
  null as uds,
  coalesce (round(b.importe / eventos , 2),t.importe) as importe_base ,
  'EUR' as moneda,
  'C' as via_pago,
  'Z001' as cond_pago,
  '29' as cod_canal,
  coalesce (a.cod_producto,'040') as cod_producto,
  coalesce (a.cod_tipo_contrato, split(t.reparto_cod_tipo_contrato_segmento_10)[OFFSET(0)], split(t.reparto_cod_tipo_contrato_segmento_12)[OFFSET(0)],'61') as cod_tipo_contrato,
  coalesce (a.cod_marca,'05') as cod_marca,
  '999' as cod_operador,
  coalesce (cod_segmento, case when t.reparto_cod_tipo_contrato_segmento_10 is not null then '10' else '12' end) as cod_segmento,
  'C_MANUAL' as facturador,
  'Z - Ajustes' as clasificacion_concepto ,
  coalesce (canal,'MI') as canal ,
  subscription_id ,
  coalesce ( product_type , 'MOBILE') as product_type,
  bundle_type ,
  msisdn ,
  fecha_activacion ,
  a.fecha_baja ,
  account_id ,
  customer_id ,
  coalesce ( a.sfid_unico , s.sfid_unico) as sfid_unico,
  coalesce ( a.tienda , s.sfid_unico) as tienda,
  coalesce ( a.distribuidor , s.distribuidor) as distribuidor,
  mes_pr as fecha,
  coalesce (agrupacion_cod_tipo_contrato, 'FMC') agrupacion_cod_tipo_contrato,
  coalesce (segmento, 'Residencial') segmento,
  coalesce(a.razon_social,s.razon_social) as razon_social,
  coalesce (a.nombre_comercio,s.Nombre_Comercial_PDV) as nombre_comercio,
    coalesce ( a.marca , 'MASMOVIL' ) as marca,
    order_id,
Product_Id,
Product,
user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
  from ajustes t
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_buscador_sfid_unico` x on t.tienda = x.sfid
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.optico` s on x.sfid_unico = s.sfid_unico
  left join base_comisiones a on a.tienda=s.sfid_unico  and a.concepto=t.concepto
  left join unitario b on a.tienda=b.tienda  and a.concepto=b.concepto
  ;

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajti` 
with
resultado as
(
select 
a.descripcion_concepto, a.tienda, round(sum(importe_base),2) as importe_base
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajti` a
group by 1,2
),
datos_tienda as
(
select 
a.*, row_number() over (partition by tienda, descripcion_concepto) as rn
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajti` a
),
importes_ajustes as
(
select
tienda,
concepto ,
tipo_concepto,
sum(importe) as importe
from `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES`
where nivel = 'tienda'
and mes = mes_pr
group by 1,2,3
)
select 
  concat (clave,'_NOEX_B_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro ,
  sociedad ,
  id_comisionista ,
  tipo_comisionista ,
  CIF ,
  zona_fiscal ,
  c.tipo_concepto ,
  c.concepto as descripcion_concepto ,
  null as UDS,
  round(c.importe - b.importe_base,2) as importe_base ,
  moneda ,
  via_pago ,
  cond_pago,
  cod_canal,
  cod_producto ,
  cod_tipo_contrato ,
  cod_marca ,
  cod_operador ,
  cod_segmento ,
  'C_MANUAL' as facturador ,
  'Z - Ajustes' as clasificacion_concepto ,
  canal ,
  subscription_id ,
  product_type ,
  bundle_type ,
  msisdn ,
  fecha_activacion ,
  a.fecha_baja ,
  account_id ,
  customer_id ,
  a.sfid_unico ,
  a.tienda ,
  distribuidor ,
  fecha ,
  agrupacion_cod_tipo_contrato ,
  segmento ,
  razon_social ,
  nombre_comercio ,
  marca ,  
  order_id,
Product_Id,
Product,
user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from datos_tienda a
inner join resultado b using(tienda, descripcion_concepto)
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_buscador_sfid_unico` d on d.sfid_unico = a.tienda
inner join importes_ajustes c on c.tienda = d.sfid and b.descripcion_concepto = c.concepto
where round(c.importe - b.importe_base,2) <> 0
and a.rn = 1
;

-- Validacion de importes --

set importe_original = (
  select
  round(sum (importe),2) as importe
  from `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES`
  where nivel = 'tienda'
  and mes = mes_pr
);

set importe_resultado = (
  select 
  round(sum(importe_base),2) as importe_base
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajti` a
);

if importe_original <>  importe_resultado then RAISE USING MESSAGE = 'Importes no cuadran: importe original: '
|| cast(importe_original as string)
|| ', importe resultado: '
|| cast(importe_resultado as string);
end if;

-- Actualización tabla final --
call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_ajti',
  'NO_EXCLUSIVO.comisiones_working'
);


/*
with
importe_original as (
  select
  tienda,
  round(sum (importe),2) as importe_original
  from `mm-commissions-reporting.NO_EXCLUSIVO.AJUSTES`
  where nivel = 'tienda'
  and mes = date('2022-09-01')--mes_pr
  group by 1
), importe_resultado as (
  select 
  tienda,
  round(sum(importe_base),2) as importe
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ajustes_tienda` a
  group by 1
)
select *
from importe_original a
full outer join importe_resultado b on a.tienda=b.tienda
where importe_original != importe
or importe is null
*/

end