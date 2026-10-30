begin

declare importe_original, importe_resultado float64;
declare clave string;

set clave = 'PGTI';

-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_pgti` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_working_pgti` as
with
ajustes as
(
  select * except(importe), round(importe,2) as importe
  from `mm-commissions-reporting.EXCLUSIVO.v_pagos_tienda`
  where mes = mes_pr
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
  from `mm-commissions-reporting.EXCLUSIVO.comisiones_working` a
  inner join repartos b using (cod_segmento, cod_tipo_contrato)
  where 1=1
  and descripcion_concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
    and fecha = mes_pr
),
unitario as
(
select a.tienda, a.concepto, b.importe, count(1) as eventos,
from base_comisiones a
inner join ajustes b on a.concepto=b.concepto and a.tienda=b.tienda
where b.mes = mes_pr
group by 1,2,3
)
select
  concat (clave,'_EXCL_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro,
  coalesce (sociedad , 'X001') as sociedad,
  billing_dealer as id_comisionista,
  'DEA' as tipo_comisionista,
  s.documento,
  s.zona_fiscal,
  t.tipo_concepto ,
  t.concepto as descripcion_concepto ,
  null as uds,
  coalesce (round(b.importe / eventos , 2),t.importe) as importe_base ,
  'EUR' as moneda,
  'C' as via_pago,
  'Z001' as cond_pago,
  '27' as cod_canal,
  coalesce (t.cod_producto, a.cod_producto,'040') as cod_producto,
  coalesce (a.cod_tipo_contrato, split(t.reparto_cod_tipo_contrato_segmento_10)[OFFSET(0)], split(t.reparto_cod_tipo_contrato_segmento_12)[OFFSET(0)],'61') as cod_tipo_contrato,
  coalesce (a.cod_marca,'01') as cod_marca,
  '999' as cod_operador,
  coalesce (cod_segmento, case when t.reparto_cod_tipo_contrato_segmento_10 is not null then '10' else '12' end) as cod_segmento,
  'C_MANUAL' as facturador,
  CONTROL.f_clasificacion_concepto (t.concepto ) as clasificacion_concepto ,
  coalesce (canal,'LB') as canal ,
  subscription_id ,
  coalesce ( product_type , 'MOBILE') as product_type,
  bundle_type ,
  msisdn ,
  fecha_activacion ,
  a.fecha_baja ,
  account_id ,
  customer_id ,
  t.tienda as sfid_unico,
  t.tienda as tienda,
  s.distribuidor,
  mes_pr as fecha,
  coalesce (agrupacion_cod_tipo_contrato, 'FMC') agrupacion_cod_tipo_contrato,
  coalesce (segmento, 'Residencial') segmento,
  s.razon_social,
  s.nombre as nombre_comercio,
    coalesce ( a.marca , 'YOIGO' ) as marca,
    order_id,
Product_Id,
Product,
user_id,
cast(null as string) campaign_code,
t.claim_code claim_code,
cast(null as string) process_code,
cast(null as string) comments,
  from ajustes t
  inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` s on substr(t.tienda,1,2) = s.billing_dealer
  left join base_comisiones a on a.tienda=t.tienda  and a.concepto=t.concepto
  left join unitario b on a.tienda=b.tienda  and a.concepto=b.concepto
  ;

insert into `mm-commissions-reporting.EXCLUSIVO.comisiones_working_pgti` 
with
resultado as
(
select 
a.descripcion_concepto, a.tienda, round(sum(importe_base),2) as importe_base
from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_pgti` a
group by 1,2
),
datos_tienda as
(
select 
a.*, row_number() over (partition by tienda, descripcion_concepto) as rn
from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_pgti` a
),
importes_ajustes as
(
select
tienda,
concepto ,
tipo_concepto,
sum(importe) as importe
from `mm-commissions-reporting.EXCLUSIVO.v_pagos_tienda`
where mes = mes_pr
group by 1,2,3
)
select 
  concat (clave,'_EXCL_B_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro ,
  sociedad ,
  id_comisionista ,
  tipo_comisionista ,
  s.documento ,
  s.zona_fiscal ,
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
CONTROL.f_clasificacion_concepto (C.concepto ) as clasificacion_concepto ,
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
  s.distribuidor ,
  fecha ,
  agrupacion_cod_tipo_contrato ,
  segmento ,
  s.razon_social,
  s.nombre,
  marca ,  
  order_id,
Product_Id,
Product,
user_id,
cast(null as string) campaign_code,
claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from datos_tienda a
inner join resultado b using(tienda, descripcion_concepto)
  inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` s on substr(a.tienda,1,2) = s.billing_dealer
inner join importes_ajustes c on c.tienda = a.tienda and b.descripcion_concepto = c.concepto
where round(c.importe - b.importe_base,2) <> 0
and a.rn = 1
;

-- Validacion de importes --

set importe_original = (
  select
  sum (round(importe,2)) as importe
  from `mm-commissions-reporting.EXCLUSIVO.v_pagos_tienda`
  where mes = mes_pr
);

set importe_resultado = (
  select 
  sum (importe_base) as importe_base
  from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_pgti` a
);

if abs(importe_original -  importe_resultado) > 0.01 then RAISE USING MESSAGE = 'Importes no cuadran: importe original: '
|| cast(importe_original as string)
|| ', importe resultado: '
|| cast(importe_resultado as string);
end if;

-- Actualización tabla final --
call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'EXCLUSIVO.comisiones_working_pgti',
  'EXCLUSIVO.comisiones_working'
);


/*
with
importe_original as (
  select
  tienda,
  round(sum (importe),2) as importe_original
  from `mm-commissions-reporting.EXCLUSIVO.v_pagos_tienda`
  where mes = date('2023-01-01')--mes_pr
  group by 1
), importe_resultado as (
  select 
  tienda,
  round(sum(importe_base),2) as importe
  from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_pgti` a
  group by 1
)
select *
from importe_original a
full outer join importe_resultado b on a.tienda=b.tienda
where importe_original != importe
or importe is null
*/

end