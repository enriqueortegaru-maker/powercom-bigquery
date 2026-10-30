begin

--call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_mult`(date_trunc(date_add (current_date (), interval -1 month), month));

declare err, desc_validacion, clave string;

set clave = 'MULT';

-- Validacion de conceptos a clasificar --

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mult` as
select
 clave||'_NOEX_A_'||row_number() over () as id_registro
,sociedad
,id_comisionista
,tipo_comisionista
,CIF
,zona_fiscal
,a.tipo_concepto
,
case nivel
when 0.1 then 'D - Multiplicador Residencial (10%)'
when 0.2 then 'D - Multiplicador Residencial (20%)'
when 0.3 then 'D - Multiplicador Residencial (30%)'
end as descripcion_concepto
,uds
,importe_base*nivel as importe_base
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
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.EXTRACOMISION_TIENDA` b ON a.sfid_unico = b.tienda
inner join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` C ON a.descripcion_concepto=C.concepto AND C.aplica_multiplicador = 1
where 1=1
and b.mes = mes_pr
and nivel in (0.1,0.2,0.3)
and not (cod_segmento = '12' and a.descripcion_concepto = 'A - Servicio Fijo' and a.agrupacion_cod_tipo_contrato = 'FMC')
and ( date_trunc(fecha_baja,month) != mes_pr or fecha_baja is null)
; 

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mult` 
select
 clave||'_NOEX_B_'||row_number() over () as id_registro
,sociedad
,m.nombre id_comisionista
,tipo_comisionista
,m.cif
,m.zona_fiscal
,a.tipo_concepto
,case descripcion_concepto
when 'D - Multiplicador Residencial (10%)' then 'F - Acelerador gestion de canal (10%)'
when 'D - Multiplicador Residencial (20%)' then 'F - Acelerador gestion de canal (20%)'
when 'D - Multiplicador Residencial (30%)' then 'F - Acelerador gestion de canal (30%)'
end as descripcion_concepto
,uds
,case descripcion_concepto
when 'D - Multiplicador Residencial (10%)' then 0.1
when 'D - Multiplicador Residencial (20%)' then 0.2
when 'D - Multiplicador Residencial (30%)' then 0.3
end * importe_base as importe_base
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
,m.razon_social
,m.nombre nombre_comercio
,marca
,order_id
,Product_Id
,Product
,user_id
,campaign_code
,claim_code
,process_code
,comments
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mult`  a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` m on a.distribuidor=m.nombre
; 

/*
insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_mult`
select
 clave||'_NOEX_C_'||row_number() over () as id_registro
,sociedad

,coalesce (
case when substr( descripcion_concepto , 1, 1) != ('F')
then d.sfid_unico
else m.nombre end
,a.id_comisionista) as id_comisionista

,tipo_comisionista

,coalesce (
case when substr( descripcion_concepto , 1, 1) != ('F')
then d.cif_pdv
else m.cif end
,a.CIF) as cif

,coalesce (
case when substr( descripcion_concepto , 1, 1) != ('F')
then v.zona_fiscal
else m.zona_fiscal end
,a.zona_fiscal) as zona_fiscal

,a.tipo_concepto
,
case when substr( descripcion_concepto , 1, 1) != ('F')
then 'E - Clawback Multiplicador Residencial'
else 'F - Clawback Acelerador gestion de canal' end as descripcion_concepto
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

,case when substr( descripcion_concepto , 1, 1) != ('F')
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
case when substr( descripcion_concepto , 1, 1) != ('F')
then d.distribuidor
else m.nombre end
,a.distribuidor) as distribuidor

,mes_pr as fecha

,agrupacion_cod_tipo_contrato
,segmento

,coalesce (
case when substr( descripcion_concepto , 1, 1) != ('F')
then v.vendor_name
else m.razon_social end
,a.razon_social) as razon_social

,coalesce (
case when substr( descripcion_concepto , 1, 1) != ('F')
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
where (a.descripcion_concepto like '%Multiplicador Residencial%'
or a.descripcion_concepto like '%Acelerador gestion de canal%')
and date_diff ( b.real_deactivation_date , a.fecha_activacion , day ) <= 180
and date_trunc ( b.real_deactivation_date , month ) = mes_pr
; 
*/

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_mult',
  'NO_EXCLUSIVO.comisiones_working'
);

end