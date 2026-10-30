begin

declare importe_original, importe_resultado float64;
declare err, clave string;


set clave = 'AEFC';
-- Solo Residencial
-- Producto 20 y 61

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_aefc` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_aefc` as
with base_comisiones as
(
  select *
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mcom`
  where 1=1
  and cod_tipo_contrato in ('20','61')
  and cod_segmento = '10'
  and descripcion_concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
  and fecha=mes_pr
),
unitario as
(
select a.distribuidor, b.acelerador_eficiencia_comercial, count(1) as eventos,
from base_comisiones a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_MASTER` b on a.distribuidor=b.master
where b.mes = mes_pr
group by 1,2
)
select
  concat (clave,'_NOEX_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number () over () ) as id_registro,
  sociedad ,
  c.codigo as id_comisionista ,
  tipo_comisionista ,
  c.CIF ,
  c.zona_fiscal ,
  'UPFR' as tipo_concepto ,
  'F - Acelerador Eficiencia Comercial' as descripcion_concepto ,
  null as uds,
  round(acelerador_eficiencia_comercial / eventos , 2) as importe_base ,
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
  'F - Gestión de canal' as clasificacion_concepto ,
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
  tienda ,
  distribuidor ,
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
  inner join unitario b using (distribuidor)
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` c on a.distribuidor=c.nombre
  ;

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_aefc` 
with resultado as
(
select 
a.distribuidor, round(sum(importe_base),2) as importe_base
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_aefc` a
group by 1
)
select 
  concat (clave,'_NOEX_B_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro ,
  'X001' sociedad ,
  c.codigo as id_comisionista ,
  'DEA' as tipo_comisionista ,
  c.CIF ,
  c.zona_fiscal ,
  'UPFR' as tipo_concepto ,
  'F - Acelerador Eficiencia Comercial' as descripcion_concepto ,
  null as UDS,
  round(b.acelerador_eficiencia_comercial - a.importe_base,2) as importe_base ,
  'EUR' as moneda ,
  'C' as via_pago ,
  'Z001' as cond_pago,
  '29' as cod_canal,
  '040' as cod_producto ,
  '61' as cod_tipo_contrato ,
  '05' cod_marca ,
  '999' cod_operador ,
  '10' cod_segmento ,
  'C_MANUAL' facturador ,
  'F - Gestión de canal' as clasificacion_concepto ,
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
where round(b.acelerador_eficiencia_comercial - a.importe_base,2)  <> 0
and b.mes = mes_pr;

-- Validacion de importes --

set importe_original = (
  select
  sum (acelerador_eficiencia_comercial)
  from  `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_MASTER` 
);

set importe_resultado = (
  select 
  round(sum(importe_base),2) as importe_base
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_aefc` a
);

set err = ( 

with
original as
(
select
  master as distribuidor, 
  sum (acelerador_eficiencia_comercial) as importe_original
  from  `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_MASTER` 
  where acelerador_eficiencia_comercial > 0
  and mes = mes_pr
  group by 1
),
calculado as
(
  select 
  distribuidor,
  round(sum(importe_base),2) as importe_cargado
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_aefc`
  group by 1
)
select STRING_AGG(concat(distribuidor,': ',importe_original))
from original 
full outer join calculado  using (distribuidor)
where ifnull(importe_original,0) <> ifnull(importe_cargado,0)

);

if err is not null then
if  importe_original <>  importe_resultado then RAISE USING MESSAGE = 'Importes no cuadran: importe original: '
|| cast(importe_original as string)
|| ', importe resultado: '
|| cast(importe_resultado as string)
|| ' Tiendas sin cargar: ' 
|| err; 

end if;
end if;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_aefc',
  'NO_EXCLUSIVO.comisiones_working'
);


end