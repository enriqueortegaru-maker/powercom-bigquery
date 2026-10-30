begin

declare importe_original, importe_resultado float64;
declare sql, mes_string, prefijo string;

set mes_string = format_date ('%Y%m', mes_pr);

set prefijo = 'PTNX';

-- call `mm-commissions-reporting.COMISIONES.pr_ptnx` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.TEMP.ptnx` as
with
ajustes as
(
  select * except(importe), round(importe,2) as importe
  from `mm-commissions-reporting.COMISIONES.v_no_exclusivo_pagos_tienda`
  where mes = mes_pr
  and round(importe,2) <> 0
),
reparto_X001_10 as
(
select
concepto,
'10' as cod_segmento,
'X001' as sociedad,
split(reparto_X001_10) as arr
from ajustes
),
reparto_X001_12 as
(
select
concepto,
'12' as cod_segmento,
'X001' as sociedad,
split(reparto_X001_12) as arr
from ajustes
),
reparto_7000_10 as
(
select
concepto,
'10' as cod_segmento,
'7000' as sociedad,
split(reparto_7000_10) as arr
from ajustes
),
repartos as
(
select
distinct
concepto,
cod_segmento,
sociedad,
cod_tipo_contrato
from reparto_X001_12, unnest(arr) cod_tipo_contrato
union distinct
select
distinct
concepto,
cod_segmento,
sociedad,
cod_tipo_contrato
from reparto_X001_12, unnest(arr) cod_tipo_contrato
union distinct
select
distinct
concepto,
cod_segmento,
sociedad,
cod_tipo_contrato
from reparto_X001_12, unnest(arr) cod_tipo_contrato
),
base_comisiones as
(
  select b.concepto, a.* except (concepto)
  from `mm-commissions-reporting.COMISIONES.transacciones` a
  inner join repartos b using (cod_segmento, cod_tipo_contrato, sociedad)
  where 1=1
  and a.concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
    and mes_liquidado = mes_pr
),
unitario as
(
select a.sfid_id, a.concepto, b.importe, count(1) as eventos,
from base_comisiones a
inner join ajustes b on a.concepto=b.concepto and a.sfid_id=b.sfid_unico
where b.mes = mes_pr
group by 1,2,3
)
select
   a.* except (
      agrupacion_canal,
      mes_liquidado, 
      estado, 
      unidades, 
      concepto,
      id_comisionista,
      sfid_id,
      zona_fiscal,
      distribuidor,
      nombre_comercio,
      razon_social, 
      cif, 
      canal,
      tipo_concepto,
      cod_segmento,
      cod_tipo_contrato,
      cod_producto,
      cod_marca,
      cod_canal,
      marca,
      sociedad,
      facturador,
      commission_id,
      comision)
  ,'No Exclusivo' as agrupacion_canal
  ,mes_pr as mes_liquidado
  ,'calculado' as estado
  ,t.concepto
  ,cast ( null as int64 ) as unidades
  ,s.id_comisionista
  ,s.sfid_unico as sfid_id
  ,s.zona_fiscal
  ,s.distribuidor
  ,s.nombre_comercio
  ,s.razon_social
  ,s.cif
  ,s.canal
  ,t.tipo_concepto
  ,coalesce (a.cod_segmento,'10') as cod_segmento
  ,coalesce (a.cod_tipo_contrato, split(t.reparto_X001_10)[OFFSET(0)], split(t.reparto_X001_12)[OFFSET(0)],'61') as cod_tipo_contrato
  ,coalesce (a.cod_producto,'040') as cod_producto
  ,coalesce (a.cod_marca, '05' ) as cod_marca
  ,'27' as cod_canal
  ,coalesce (a.marca, 'MASMOVIL') as marca
  ,'C_MANUAL' as facturador
  ,coalesce (a.sociedad , 'X001') as sociedad
  ,prefijo||'_'||mes_string||'_'||s.canal||'_'||row_number () over () as commission_id
  ,coalesce (round ( b.importe / b.eventos) , t.importe) as comision
  from ajustes t
  inner join `mm-commissions-reporting.COMISIONES.v_dealers` s on t.sfid_unico = s.sfid_id
  left join base_comisiones a on a.sfid_id=t.sfid_unico  and a.concepto=t.concepto
  left join unitario b on a.sfid_id=b.sfid_id  and a.concepto=b.concepto
;

insert into `mm-commissions-reporting.TEMP.ptnx`
with
resultado as
(
select 
a.concepto, a.sfid_id, round(sum(comision),2) as comision
from `mm-commissions-reporting.TEMP.ptnx` a
group by 1,2
),
datos_tienda as
(
select 
a.*
from `mm-commissions-reporting.TEMP.ptnx`  a
qualify row_number() over (partition by sfid_id, concepto) = 1
),
importes_ajustes as
(
select
sfid_unico,
concepto ,
tipo_concepto,
sum(importe) as importe
from `mm-commissions-reporting.COMISIONES.v_no_exclusivo_pagos_tienda`
where mes = mes_pr
group by 1,2,3
)
select a.* except (commission_id, comision)
, commission_id||'B'
, round(c.importe - b.comision,2) as comision
from datos_tienda a
inner join resultado b using(sfid_id, concepto)
inner join importes_ajustes c on c.sfid_unico = a.sfid_id and b.concepto = c.concepto
where round(c.importe - b.comision,2) <> 0
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_pr, ['MI','MP','MR','CA','NR'] , 'TEMP.ptnx' );

end