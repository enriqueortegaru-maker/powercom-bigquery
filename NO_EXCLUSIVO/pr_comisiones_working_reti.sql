begin

--call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_reti`();

declare err, desc_validacion, clave string;

set clave = 'RETI';

-- Validacion de conceptos a clasificar --

-- Recálculo del multiplicador --

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` as
select
 clave||'_NOEX_A_'||row_number() over () as id_registro
,sociedad
,d.sfid_unico as id_comisionista
,tipo_comisionista
,d.cif_pdv as CIF
,v.zona_fiscal
,a.tipo_concepto
,
case nivel
when 0.1 then 'R - Multiplicador Residencial (10%) ' ||format_date ('%Y%m', fecha)
when 0.2 then 'R - Multiplicador Residencial (20%) ' ||format_date ('%Y%m', fecha)
when 0.3 then 'R - Multiplicador Residencial (30%) ' ||format_date ('%Y%m', fecha)
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
,coalesce (cod_segmento, '10') as cod_segmento
,'C_MANUAL' as facturador
,'R - Recalculo periodo anterior' as clasificacion_concepto
,canal
,subscription_id
,coalesce(product_type, 'INTERNET') as product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id
,d.sfid_unico
,d.sfid_unico as tienda
,d.distribuidor
,date('2023-01-01') as fecha
,agrupacion_cod_tipo_contrato
,coalesce (segmento, 'Residencial') as segmento
,v.vendor_name as razon_social
,d.razon_social as nombre_comercio
,coalesce (marca, 'MASMOVIL') as marca
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
invoice_id claim_code,
format_date ('%Y%m', fecha) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.HISTORICO_ACELERADOR` b ON a.sfid_unico = b.tienda and a.fecha=b.mes
inner join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` C ON a.descripcion_concepto=C.concepto AND C.aplica_multiplicador = 1
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid
inner join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = d.cif_pdv
where 1=1
and nivel in (0.1,0.2,0.3)
and not (cod_segmento = '12' and a.descripcion_concepto = 'A - Servicio Fijo' and a.agrupacion_cod_tipo_contrato = 'FMC')
and ( date_trunc(a.fecha_baja,month) != fecha or a.fecha_baja is null)
and a.fecha >= '2022-06-01'
;

-- Retroacción del calculo anterior --

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti`
select
 clave||'_NOEX_B_'||row_number() over () as id_registro
,sociedad
,d.sfid_unico as id_comisionista
,tipo_comisionista
,d.cif_pdv as CIF
,v.zona_fiscal
,a.tipo_concepto
,
'R - M. Residencial calculo anterior '||format_date ('%Y%m', fecha) as descripcion_concepto
,cast(null as int64) as uds
,-importe_base as importe_base
,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,coalesce (cod_segmento, '10') as cod_segmento
,'C_MANUAL' as facturador
,'R - Recalculo periodo anterior' as clasificacion_concepto
,canal
,subscription_id
,coalesce(product_type, 'INTERNET') as product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id
,d.sfid_unico
,d.sfid_unico as tienda
,d.distribuidor
,date('2023-01-01') as fecha
,agrupacion_cod_tipo_contrato
,coalesce (segmento, 'Residencial') as segmento
,v.vendor_name as razon_social
,d.razon_social as nombre_comercio
,coalesce (marca, 'MASMOVIL')
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
invoice_id claim_code,
format_date ('%Y%m', fecha) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid
inner join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = d.cif_pdv
where a.descripcion_concepto like '%Multiplicador Residencial%'
and a.fecha >= '2022-06-01'
; 

-- Recalculo acelerador negocios --

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti`
with
comisiones_base as
(
  select *
  from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
  where cod_segmento = '12'
  and descripcion_concepto = 'A - Servicio Fijo'
  and agrupacion_cod_tipo_contrato <> '2P'
  and canal in ('MP','MI', 'MR')
  and (date_trunc(fecha_baja,month)!=fecha or fecha_baja is null)
  and a.fecha >= '2022-06-01'
),
acelerador_alcanzado as
(
  select
  fecha,
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
  group by 1,2,3
)
select
 clave||'_NOEX_C_'||row_number() over () as id_registro
,sociedad
,d.sfid_unico as id_comisionista
,tipo_comisionista
,d.cif_pdv as CIF
,v.zona_fiscal
,a.tipo_concepto
,'R - Acelerador Negocios ' ||format_date ('%Y%m', fecha) as descripcion_concepto
,uds
,b.importe_base
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
,'R - Recalculo periodo anterior' as clasificacion_concepto
,canal
,subscription_id
,product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id
,d.sfid_unico
,d.sfid_unico as tienda
,d.distribuidor
,date('2023-01-01') as fecha
,agrupacion_cod_tipo_contrato
,segmento
,v.vendor_name as razon_social
,d.razon_social as nombre_comercio
,marca
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
invoice_id claim_code,
format_date ('%Y%m', fecha) process_code,
cast(null as string) comments,
from comisiones_base a
inner join acelerador_alcanzado b using (canal, tienda, fecha)
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid
inner join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = d.cif_pdv
; 

-- Retroacción calculo de acelerador negocios --

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti`
select
 clave||'_NOEX_D_'||row_number() over () as id_registro
,sociedad
,d.sfid_unico as id_comisionista
,tipo_comisionista
,d.cif_pdv as CIF
,v.zona_fiscal
,a.tipo_concepto
,
'R - A. Negocios calculo anterior '||format_date ('%Y%m', fecha) as descripcion_concepto
,cast(null as int64) as uds
,-importe_base as importe_base
,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,coalesce (cod_segmento, '10') as cod_segmento
,'C_MANUAL' as facturador
,'R - Recalculo periodo anterior' as clasificacion_concepto
,canal
,subscription_id
,coalesce(product_type, 'INTERNET') as product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id
,d.sfid_unico
,d.sfid_unico as tienda
,d.distribuidor
,date('2023-01-01') as fecha
,agrupacion_cod_tipo_contrato
,coalesce (segmento, 'Residencial') as segmento
,v.vendor_name as razon_social
,d.razon_social as nombre_comercio
,coalesce (marca, 'MASMOVIL')
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
invoice_id claim_code,
format_date ('%Y%m', fecha) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid
inner join `mm-commissions-reporting.SAP.vendor_list` v on v.tax_code = d.cif_pdv
where a.descripcion_concepto like '%Acelerador Negocios%'
and a.fecha >= '2022-06-01'
; 

-- Recalculo F - Acelerador gestion de canal  --

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` 
select
 clave||'_NOEX_E_'||row_number() over () as id_registro
,sociedad
,m.nombre id_comisionista
,tipo_comisionista
,m.cif
,m.zona_fiscal
,a.tipo_concepto
,case substr(descripcion_concepto,1,35)
when 'R - Multiplicador Residencial (10%)' then 'S - Acelerador gestion de canal (10%) '||process_code
when 'R - Multiplicador Residencial (20%)' then 'S - Acelerador gestion de canal (20%) '||process_code
when 'R - Multiplicador Residencial (30%)' then 'S - Acelerador gestion de canal (30%) '||process_code
end as descripcion_concepto
,uds
,case substr(descripcion_concepto,1,35)
when 'R - Multiplicador Residencial (10%)' then 0.1
when 'R - Multiplicador Residencial (20%)' then 0.2
when 'R - Multiplicador Residencial (30%)' then 0.3
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
,'S - Recalculo periodo anterior master' as clasificacion_concepto
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
,sfid_unico as tienda
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
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` m on a.distribuidor=m.nombre
where a.descripcion_concepto like 'R - Multiplicador Residencial%'
; 


-- Retroacción F - Acelerador gestion de canal --

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti`
select
 clave||'_NOEX_F_'||row_number() over () as id_registro
,sociedad
,a.id_comisionista
,tipo_comisionista
,a.cif
,a.zona_fiscal
,a.tipo_concepto
,
'S - A. gestion canal calculo anterior '||format_date ('%Y%m', fecha) as descripcion_concepto
,cast(null as int64) as uds
,-importe_base as importe_base
,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,coalesce (cod_segmento, '10') as cod_segmento
,'C_MANUAL' as facturador
,'S - Recalculo periodo anterior master' as clasificacion_concepto
,canal
,subscription_id
,coalesce(product_type, 'INTERNET') as product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id
,d.sfid_unico
,d.sfid_unico as tienda
,a.distribuidor
,date('2023-01-01') as fecha
,agrupacion_cod_tipo_contrato
,coalesce (segmento, 'Residencial') as segmento
,a.razon_social
,a.nombre_comercio
,coalesce (marca, 'MASMOVIL')
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
invoice_id claim_code,
format_date ('%Y%m', fecha) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid
where a.descripcion_concepto like '%Acelerador%_estion de canal%'
and a.fecha >= '2022-06-01'
; 

-- Recalculo GC acelerador negocios

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` 
select
 clave||'_NOEX_G_'||row_number() over () as id_registro
,sociedad
,m.nombre id_comisionista
,tipo_comisionista
,m.cif
,m.zona_fiscal
,a.tipo_concepto
,'S - Gestion de canal acelerador negocios '||process_code  as descripcion_concepto
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
,'S - Recalculo periodo anterior master' as clasificacion_concepto
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
,sfid_unico as tienda
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
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` m on a.distribuidor=m.nombre
where a.descripcion_concepto like '%Acelerador Negocios%'
and a.fecha >= '2022-06-01'
; 

-- Retroacción H - Acelerador gestion de canal --

insert into `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti`
select
 clave||'_NOEX_H_'||row_number() over () as id_registro
,sociedad
,a.id_comisionista
,tipo_comisionista
,a.cif
,a.zona_fiscal
,a.tipo_concepto
,
'S - G.C.A. Negocios calculo anterior '||format_date ('%Y%m', fecha) as descripcion_concepto
,cast(null as int64) as uds
,-importe_base as importe_base
,moneda
,via_pago
,cond_pago
,cod_canal
,a.cod_producto
,cod_tipo_contrato
,cod_marca
,cod_operador
,coalesce (cod_segmento, '10') as cod_segmento
,'C_MANUAL' as facturador
,'S - Recalculo periodo anterior master' as clasificacion_concepto
,canal
,subscription_id
,coalesce(product_type, 'INTERNET') as product_type
,bundle_type
,msisdn
,fecha_activacion
,a.fecha_baja
,account_id
,customer_id
,d.sfid_unico
,d.sfid_unico as tienda
,a.distribuidor
,date('2023-01-01') as fecha
,agrupacion_cod_tipo_contrato
,coalesce (segmento, 'Residencial') as segmento
,a.razon_social
,a.nombre_comercio
,coalesce (marca, 'MASMOVIL')
,order_id
,Product_Id
,Product
,user_id,
cast(null as string) campaign_code,
invoice_id claim_code,
format_date ('%Y%m', fecha) process_code,
cast(null as string) comments,
from `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*` a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` d on a.tienda = d.sfid
where a.descripcion_concepto like '%Gestion de canal acelerador negocios%'
and a.fecha >= '2022-06-01'
; 

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.recalculo_aceleradores_H22022`
as
select a.*, case when b.sfid_unico is not null then 'Ajuste no aplicado' else 'Ajuste aplicado' end as resultado
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` a
left join 
(
  (select
sfid_unico
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` 
group by 1
having sum(importe_base) <= 0)
) b on a.sfid_unico = b.sfid_unico
;

-- Eliminamos sfid con saldo negativo --

delete `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti`
where substr(descripcion_concepto, 1,1) ||'-'|| sfid_unico in (
(select
 substr(descripcion_concepto, 1,1) ||'-'|| sfid_unico
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_reti` 
group by 1
having sum(importe_base) <= 0)
)
or cif = 'B26563676';


call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_reti',
  'NO_EXCLUSIVO.comisiones_working'
);

end