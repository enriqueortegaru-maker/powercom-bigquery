begin

declare importe_original, importe_resultado float64;
declare err,clave string;

set clave = 'IDTI';

-- Residencial
-- Producto 20 y 61

-- Empresas
-- Producto 61

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_idti` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_idti` as
with base_comisiones as
(
  select *
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working`
  where 1=1
  and descripcion_concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
  and (
    (cod_tipo_contrato in ('20','61') and cod_segmento = '10')
    or
    (cod_tipo_contrato in ('61') and cod_segmento = '12')
  )
    and fecha = mes_pr
),
unitario as
(
select a.tienda, b.imagen, count(1) as eventos,
from base_comisiones a
--inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_buscador_sfid_unico` c on c.sfid_unico = a.tienda
inner join `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_TIENDA` b on b.tienda = a.tienda -- c.sfid
where b.imagen is not null
and b.mes = mes_pr
group by 1,2
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
  'UPFR' as tipo_concepto ,
  'D - Identificacion Tienda' as descripcion_concepto ,
  null as uds,
  coalesce (round(b.imagen / eventos , 2),t.imagen) as importe_base ,
  'EUR' as moneda,
  'C' as via_pago,
  'Z001' as cond_pago,
  '29' as cod_canal,
  coalesce (a.cod_producto,'040') as cod_producto,
  coalesce (a.cod_tipo_contrato, '61') as cod_tipo_contrato,
  coalesce (a.cod_marca,'05') as cod_marca,
  '999' as cod_operador,
  coalesce (cod_segmento,'10') as cod_segmento,
  'C_MANUAL' as facturador,
  'D - Extracomisión' as clasificacion_concepto ,
  coalesce (canal, case channel when 'NATIONAL RETAIL' then 'NR' when 'MASPROXIMO' then 'MP' else 'MI' end ) as canal ,
  subscription_id ,
  product_type ,
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
  from `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_TIENDA` t
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` s on t.tienda = s.sfid
  left join base_comisiones a on a.tienda=s.sfid_unico
  left join unitario b on a.tienda=b.tienda
  where t.imagen <> 0
  and t.mes = mes_pr
  ;

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_idti` 
with
resultado as
(
select 
a.tienda, round(sum(importe_base),2) as importe_base
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_idti` a
group by 1
),
datos_tienda as
(
select 
a.*, row_number() over (partition by tienda) as rn
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_idti` a
)
select 
  concat (clave,'_NOEX_B_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro ,
  sociedad ,
  id_comisionista ,
  tipo_comisionista ,
  CIF ,
  zona_fiscal ,
  'UPFR' as tipo_concepto ,
  'D - Identificacion Tienda' as descripcion_concepto ,
  null as UDS,
  round(c.imagen - b.importe_base,2) as importe_base ,
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
   'D - Extracomisión' as clasificacion_concepto ,
  coalesce (canal, 'MI' ) as canal  ,
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
inner join resultado b using(tienda)
--inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_buscador_sfid_unico` d on d.sfid_unico = a.tienda
inner join `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_TIENDA` c on c.tienda = a.tienda -- d.sfid
where round(c.imagen - b.importe_base,2) <> 0
and a.rn = 1
and c.mes = mes_pr
;

-- Validacion de importes por tienda --

set err = (
  with 
  gs as
  (
  select
  tienda,
  sum (imagen) as importe_gs
  from  `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_TIENDA` 
  where mes = mes_pr
  and imagen > 0
  group by 1
  ),
  pr as
  (
 select 
 tienda,
  round(sum(importe_base),2) as importe_pr
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_idti`
  group by 1
  )
  select string_agg(tienda)
  from gs full outer join pr using (tienda)
  where importe_gs <> importe_pr
);

if err is not null then RAISE USING MESSAGE = 'Existen importes por tienda no cuadran, ejemplo: ' || err; end if;

-- Validacion de importes --

set importe_original = (
  select
  sum (imagen)
  from  `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_TIENDA` 
  where mes = mes_pr
);

set importe_resultado = (
  select 
  round(sum(importe_base),2) as importe_base
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_idti` a
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
  'NO_EXCLUSIVO.comisiones_working_idti',
  'NO_EXCLUSIVO.comisiones_working'
);



end