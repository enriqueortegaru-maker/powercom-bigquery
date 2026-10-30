begin

--call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_acng`(date_trunc(date_add (current_date (), interval -1 month), month));

declare err, desc_validacion, clave string;

set clave = 'ACNG';

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_acng` as
with
comisiones_base as
(
  select *
  from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working`
  where cod_segmento = '12'
  and descripcion_concepto = 'A - Servicio Fijo'
  and agrupacion_cod_tipo_contrato <> '2P'
  and canal in ('MP','MI', 'MR')
  and (date_trunc(fecha_baja,month)!=mes_pr or fecha_baja is null)
),
acelerador_alcanzado as
(
  select
  canal,
  tienda,
  case
    when count(1) <= 2 then 20
    when count(1) <= 4 then 40
    when count(1) <= 9 then 70
    when count(1) <= 14 and canal in ('MI','MR') then 70
    when count(1) <= 14 and canal = 'MP' then 120
    else 120 end
   as importe_base
  from comisiones_base
  group by 1,2
)
select

 clave||'_NOEX_A_'||row_number() over () as id_registro
,sociedad
,id_comisionista
,tipo_comisionista
,CIF
,zona_fiscal
,a.tipo_concepto
,'D - Acelerador Negocios' as descripcion_concepto
,uds
,cast ( b.importe_base as float64) as importe_base

,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,cod_segmento
,'C_MANUAL' as facturador
,'D - Extracomisión' as clasificacion_concepto
,canal
,subscription_id
,product_type
,bundle_type
,msisdn
,fecha_activacion
,fecha_baja
,account_id
,customer_id
,sfid_unico
,a.tienda
,distribuidor
,fecha
,agrupacion_cod_tipo_contrato
,segmento
,razon_social
,nombre_comercio
,marca
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
from comisiones_base a
inner join acelerador_alcanzado b using (canal, tienda)
; 

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_acng` 
select

 clave||'_NOEX_B_'||row_number() over () as id_registro
,sociedad
,b.nombre
,tipo_comisionista
,b.cif
,b.zona_fiscal
,a.tipo_concepto
,'F - Gestion de canal acelerador negocios' as descripcion_concepto
,uds
,20 as importe_base

,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,cod_segmento
,'C_MANUAL' as facturador
,'F - Gestión de canal' as clasificacion_concepto
,canal
,subscription_id
,product_type
,bundle_type
,msisdn
,fecha_activacion
,fecha_baja
,account_id
,customer_id
,sfid_unico
,a.tienda
,distribuidor
,fecha
,agrupacion_cod_tipo_contrato
,segmento
,b.razon_social
,b.nombre as nombre_comercio
,marca
,order_id
,Product_Id
,Product
,user_id
,campaign_code
,claim_code
,process_code
,comments
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_acng` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` b on a.distribuidor=b.nombre
where a.canal in ('MI')
; 

/*

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_acng`
select
 clave||'_NOEX_C_'||row_number() over () as id_registro
,sociedad

,coalesce (
case when descripcion_concepto = 'D - Acelerador Negocios'
then d.sfid_unico
else m.nombre end
,a.id_comisionista) as id_comisionista

,tipo_comisionista

,coalesce (
case when descripcion_concepto = 'D - Acelerador Negocios'
then d.cif_pdv
else m.cif end
,a.CIF) as id_comisionista

,coalesce (
case when descripcion_concepto = 'D - Acelerador Negocios'
then v.zona_fiscal
else m.zona_fiscal end
,a.zona_fiscal) as zona_fiscal

,a.tipo_concepto
,
case when descripcion_concepto = 'D - Acelerador Negocios'
then 'E - Clawback acelerador negocios'
else 'H - Clawback acelerador negocios' end as descripcion_concepto
,uds

, case
    when date_diff ( b.real_deactivation_date , a.fecha_activacion , day ) <= 60 then 1.0
    when date_diff ( b.real_deactivation_date , a.fecha_activacion , day ) <= 120 then 0.75
    else 0.5
  end * -a.importe_base as importe_base

,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,cod_segmento
,'C_MANUAL' as facturador

,case when descripcion_concepto = 'D - Acelerador Negocios'
then 'E - Clawback'
else 'H - Clawback gestión de canal' end as clasificacion_concepto

,canal
,subscription_id
,product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id

,coalesce ( d.sfid_unico , a.sfid_unico ) as sfid_unico

,a.tienda

,coalesce (
case when descripcion_concepto = 'D - Acelerador Negocios'
then d.distribuidor
else m.nombre end
,a.distribuidor) as distribuidor

,mes_pr as fecha

,agrupacion_cod_tipo_contrato
,segmento

,coalesce (
case when descripcion_concepto = 'D - Acelerador Negocios'
then v.vendor_name
else m.razon_social end
,a.razon_social) as razon_social

,coalesce (
case when descripcion_concepto = 'D - Acelerador Negocios'
then d.Nombre_Comercial_PDV
else m.nombre end
,a.nombre_comercio) as nombre_comercio

,marca
,order_id
,Product_Id
,Product
,user_id
,campaign_code
,invoice_id as claim_code
,process_code
,comments
from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
inner join `mm-commissions-reporting.CONTROL.v_ventas_base` b
  on a.marca=b.brand_ds
  and a.subscription_id=b.service_id
  and a.product_type = b.service_type
left join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid  
left join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = d.cif_pdv
left join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` m on a.distribuidor=m.nombre
where a.descripcion_concepto in ('D - Acelerador Negocios', 'F - Gestion de canal acelerador negocios')
and date_diff ( b.real_deactivation_date , a.fecha_activacion , day ) <= 180
and date_trunc (b.real_deactivation_date, month) = mes_pr
; 
*/

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_acng',
  'NO_EXCLUSIVO.comisiones_working'
);

end