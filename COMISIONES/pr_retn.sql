begin

declare importe_original, importe_resultado float64;
declare sql, mes_string, prefijo string;

set mes_string = cast(mes_int as string);

set prefijo = 'RETN';

-- call `mm-commissions-reporting.COMISIONES.pr_retn` (202605);

create or replace table `mm-commissions-reporting.TEMP.retn_base_comisiones` as
  select a.*
  from `mm-commissions-reporting.COMISIONES.transacciones` a
  where id_mes = mes_int
  and a.concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
  and a.cod_segmento = '12'
;

create or replace table `mm-commissions-reporting.TEMP.retn_extracomisiones`  as
select 
mes, id_comisionista, marca, extra_activacion, 'D - Bonus' as concepto, bonus as importe
from `mm-commissions-reporting.GS.TLV_NEGOCIOS_EXTRACOMISIONES`
where bonus != 0 AND mes = mes_int
union all
select 
mes, id_comisionista, marca, extra_activacion, 'D - SVA Digital' as concepto, sva_digital as importe
from `mm-commissions-reporting.GS.TLV_NEGOCIOS_EXTRACOMISIONES`
where sva_digital > 0 AND mes = mes_int
;

create or replace table `mm-commissions-reporting.TEMP.retn_unitario` as
select a.id_comisionista, b.concepto, b.importe, count(1) as eventos,
from `mm-commissions-reporting.TEMP.retn_base_comisiones` a
inner join `mm-commissions-reporting.TEMP.retn_extracomisiones`  b
on a.id_comisionista = b.id_comisionista and b.mes = mes_int 
group by 1,2,3
;

create or replace table `mm-commissions-reporting.TEMP.retn` as
select
    a.* except (unidades , tipo_concepto ,cod_tipo_contrato, service_type, cod_producto, cod_marca, cod_canal, marca, sociedad, cod_segmento, concepto,nombre_comercio ,cif, id_comisionista, zona_fiscal, razon_social, canal,facturador ,commission_id, comision ,distribuidor)
  ,case when substr(t.concepto,1,1) in ('F','H','Y') then m.cif else s.cif end as cif
  ,case when substr(t.concepto,1,1) in ('F','H','Y') then m.nombre_comercio else s.nombre_comercio end as nombre_comercio
  ,case when substr(t.concepto,1,1) in ('F','H','Y') then m.razon_social else s.razon_social end as razon_social
  ,case when substr(t.concepto,1,1) in ('F','H','Y') then m.zona_fiscal else s.zona_fiscal end as zona_fiscal
  ,case when substr(t.concepto,1,1) in ('F','H','Y') then m.id_comisionista else s.id_comisionista end as id_comisionista
  ,cast (null as int64) as unidades
  ,s.canal
  ,s.distribuidor
  ,t.concepto
  ,c.tipo_concepto
  ,coalesce (a.cod_segmento,'12') as cod_segmento
  ,coalesce (a.cod_tipo_contrato,'61') as cod_tipo_contrato
  ,coalesce (a.service_type,
  case when coalesce (a.cod_tipo_contrato,'61') = '61'  then 'INTERNET' else 'MOBILE' end
  ) as service_type
  ,coalesce (a.cod_producto,'040') as cod_producto
  ,coalesce (a.cod_marca, '05' ) as cod_marca
  ,'22' as cod_canal
  ,coalesce (a.marca, 'MASMOVIL') as marca
  ,'C_MANUAL' as facturador
  ,coalesce (a.sociedad , 'X001') as sociedad
,prefijo||'_'||mes_string||'_'||s.canal||'_'||row_number () over () as commission_id
  ,coalesce (round ( b.importe / b.eventos, 2) , t.importe) as comision
  from `mm-commissions-reporting.TEMP.retn_extracomisiones` t
  inner join `mm-commissions-reporting.GS.CONCEPTOS` c using (concepto)
  left join `mm-commissions-reporting.COMISIONES.v_dealer` s on t.id_comisionista = s.sfid_id and s.id_mes = mes_int
  left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on s.distribuidor = m.id_comisionista
  left join `mm-commissions-reporting.TEMP.retn_base_comisiones` a on a.id_comisionista = t.id_comisionista
  left join `mm-commissions-reporting.TEMP.retn_unitario` b on b.id_comisionista = t.id_comisionista and b.concepto=b.concepto
  
  where coalesce (round ( b.importe / b.eventos, 2) , t.importe) != 0
;

insert into `mm-commissions-reporting.TEMP.retn`
with
resultado as
(
select 
a.concepto, a.id_comisionista, round(sum(comision),2) as comision
from `mm-commissions-reporting.TEMP.retn` a
group by 1,2
),
datos_tienda as
(
select 
a.*
from `mm-commissions-reporting.TEMP.retn`  a
qualify row_number() over (partition by id_comisionista, concepto) = 1
),
importes_ajustes as
(
select
id_comisionista,
concepto ,
sum(importe) as importe
from `mm-commissions-reporting.TEMP.retn_extracomisiones`  
where mes = mes_int
group by 1,2
)
select a.* except (commission_id, comision)
, commission_id||'B'
, round(c.importe - b.comision,2) as comision
from datos_tienda a
inner join resultado b using(id_comisionista, concepto)
inner join importes_ajustes c using (id_comisionista, concepto)
where round(c.importe - b.comision,2) <> 0
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, (select array_agg(distinct canal) from TEMP.retn) , 'TEMP.retn', 'ACTUALIZAR' );

end