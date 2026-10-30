begin

declare importe_original, importe_resultado float64;
declare clave string;

set clave = 'CALD';

-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_cald` (date_trunc(date_add (current_date (), interval -1 month), month));

create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_working_cald` as
select
  concat (clave,'_EXCL_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over ()) as id_registro,
  'X001' as sociedad,
  billing_dealer as id_comisionista,
  'DEA' as tipo_comisionista,
  s.documento,
  s.zona_fiscal,
  t.tipo_concepto ,
  t.concepto as descripcion_concepto ,
  null as uds,
  t.importe as importe_base,
  'EUR' as moneda,
  'C' as via_pago,
  'Z001' as cond_pago,
  '27' as cod_canal,
  '040' as cod_producto,
  '61' as cod_tipo_contrato,
  '01' as cod_marca,
  '999' as cod_operador,
  '10' as cod_segmento,
  'C_MANUAL' as facturador,
  CONTROL.f_clasificacion_concepto (t.concepto ) as clasificacion_concepto ,
  'LB' as canal ,
  cast (null as string) as subscription_id ,
  'INTERNET' as product_type,
  cast (null as string) as bundle_type ,
  cast (null as string) as msisdn ,
  cast (null as date) as fecha_activacion ,
  cast (null as date) as fecha_baja ,
  cast (null as string) as account_id ,
  cast (null as string) as customer_id ,
  t.tienda as sfid_unico,
  t.tienda as tienda,
  'BYMOVIL' as distribuidor,
  mes_pr as fecha,
  'FMC' agrupacion_cod_tipo_contrato,
  'Residencial' segmento,
  s.razon_social,
  s.nombre as nombre_comercio,
  'YOIGO' as marca,
  cast (null as string) as  order_id,
  cast (null as string) as Product_Id,
  cast (null as string) as  Product,
  cast (null as string) as  user_id,
  cast(null as string) campaign_code,
  t.claim_code claim_code,
  cast(null as string) process_code,
  cast(null as string) comments,
from `mm-commissions-reporting.EXCLUSIVO.v_calidad_tienda` t
inner join `mm-commissions-reporting.EXCLUSIVO.DEALERS` s on substr(t.tienda,1,2) = s.billing_dealer
;


-- Validacion de importes --

set importe_original = (
  select
  sum (round(importe,2)) as importe
  from `mm-commissions-reporting.EXCLUSIVO.v_calidad_tienda`
  where mes = mes_pr
);

set importe_resultado = (
  select 
  sum (importe_base) as importe_base
  from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_cald` a
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
  'EXCLUSIVO.comisiones_working_cald',
  'EXCLUSIVO.comisiones_working'
);

end