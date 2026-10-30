begin


declare clave string;

set clave = 'GGPV';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_ggpv` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ggpv` as
with base_comisiones as
(
  select *
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working`
  where 1=1
  and descripcion_concepto like 'F - Gestion de canal%'
)
select
  concat (clave, '_NOEX_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number () over ()) as id_registro,
  sociedad ,
  c.codigo as id_comisionista ,
  tipo_comisionista ,
  c.CIF ,
  c.zona_fiscal ,
  tipo_concepto ,
  replace (descripcion_concepto, 'F - Gestion de canal', 'G - Gestion GPV') as descripcion_concepto ,
  a.uds,
  a.importe_base,
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
  'G - Gestión de canal GPV' as clasificacion_concepto ,
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
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` b on a.sfid_unico = b.sfid
  inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` c on b.cif_gpv = c.cif
  ;


-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_ggpv',
  'NO_EXCLUSIVO.comisiones_working'
);


end