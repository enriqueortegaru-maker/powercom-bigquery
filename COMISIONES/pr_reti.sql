begin

declare importe_original, importe_resultado float64;
declare sql, mes_string, prefijo string;

set mes_string = cast(mes_int as string);

set prefijo = 'RETI';

set agrupacion_canal_pr =coalesce ( agrupacion_canal_pr, ['TLV - Outbound']);

-- call `mm-commissions-reporting.COMISIONES.pr_reti` (202308, ['TLV - Outbound']);

create or replace table `mm-commissions-reporting.TEMP.reti` as
with
ajustes as
(
  select * except(importe), round(importe,2) as importe
  from `mm-commissions-reporting.COMISIONES.v_pagos_tienda`
  cross join unnest(agrupacion_canal_pr) agpcanal
  where agrupacion_canal = agpcanal
  and mes = mes_int
  and round(importe,2) <> 0
),
reparto_X001_10 as
(
select
agrupacion_canal,
concepto,
marca,
'10' as cod_segmento,
'X001' as sociedad,
split(reparto_X001_10) as arr
from ajustes
),
reparto_X001_12 as
(
select
agrupacion_canal,
concepto,
marca,
'12' as cod_segmento,
'X001' as sociedad,
split(reparto_X001_12) as arr
from ajustes
),
reparto_7000_10 as
(
select
agrupacion_canal,
concepto,
marca,
'10' as cod_segmento,
'7000' as sociedad,
split(reparto_7000_10) as arr
from ajustes
),
repartos as
(
select
distinct
agrupacion_canal,
concepto,
marca,
cod_segmento,
sociedad,
cod_tipo_contrato
from reparto_X001_10, unnest(arr) cod_tipo_contrato
union distinct
select
distinct
agrupacion_canal,
concepto,
marca,
cod_segmento,
sociedad,
cod_tipo_contrato
from reparto_X001_12, unnest(arr) cod_tipo_contrato
union distinct
select
distinct
agrupacion_canal,
concepto,
marca,
cod_segmento,
sociedad,
cod_tipo_contrato
from reparto_7000_10, unnest(arr) cod_tipo_contrato
),
base_comisiones as
(
  select b.concepto, a.* except (concepto)
  from `mm-commissions-reporting.COMISIONES.transacciones` a
  inner join repartos b using (cod_segmento, cod_tipo_contrato, sociedad,marca)
  where 1=1
  and a.concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
    and id_mes = mes_int
    and a.agrupacion_canal=b.agrupacion_canal
    and a.marca =b.marca
),
unitario as
(
select a.agrupacion_canal,a.marca, a.sfid_id, a.concepto, b.importe, count(1) as eventos,
from base_comisiones a
inner join ajustes b on a.concepto=b.concepto and a.sfid_id=b.id_comisionista and a.agrupacion_canal=b.agrupacion_canal and a.marca =b.marca
where b.mes = mes_int
group by 1,2,3,4,5
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
  ,a.agrupacion_canal
  ,COMISIONES.f_mes_int(mes_int) as mes_liquidado
  ,'calculado' as estado
  ,t.concepto
  ,cast ( null as int64 ) as unidades
  ,s.id_comisionista
  ,s.id_comisionista as sfid_id
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
  ,coalesce (round ( b.importe / b.eventos, 2) , t.importe) as comision
  from ajustes t
  inner join `mm-commissions-reporting.COMISIONES.v_dealer` s on t.id_comisionista = s.sfid_id and s.id_mes = mes_int
  left join base_comisiones a on a.sfid_id=t.id_comisionista  and a.concepto=t.concepto and a.agrupacion_canal=t.agrupacion_canal and a.marca=t.marca
  left join unitario b on a.sfid_id=b.sfid_id  and a.concepto=b.concepto and a.agrupacion_canal=b.agrupacion_canal and a.marca=b.marca
;

insert into `mm-commissions-reporting.TEMP.reti`
with
resultado as
(
select 
a.agrupacion_canal,a.marca, a.concepto, a.sfid_id, round(sum(comision),2) as comision
from `mm-commissions-reporting.TEMP.reti` a
group by 1,2,3,4
),
datos_tienda as
(
select 
a.*
from `mm-commissions-reporting.TEMP.reti`  a
qualify row_number() over (partition by agrupacion_canal,marca,sfid_id, concepto) = 1
),
importes_ajustes as
(
select
agrupacion_canal,
id_comisionista,
concepto ,
marca,
tipo_concepto,
sum(importe) as importe
from `mm-commissions-reporting.COMISIONES.v_pagos_tienda`
cross join unnest(agrupacion_canal_pr) agpcanal
where agrupacion_canal = agpcanal
and mes = mes_int
group by 1,2,3,4,5
)
select a.* except (commission_id, comision)
, commission_id||'B'
, round(c.importe - b.comision,2) as comision
from datos_tienda a
inner join resultado b using(sfid_id, concepto, agrupacion_canal,marca)
inner join importes_ajustes c on c.id_comisionista = a.sfid_id and b.concepto = c.concepto and a.agrupacion_canal=b.agrupacion_canal and c.marca =b.marca
where round(c.importe - b.comision,2) <> 0
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, (select array_agg(distinct canal) from TEMP.reti) , 'TEMP.reti', 'ACTUALIZAR' );

end