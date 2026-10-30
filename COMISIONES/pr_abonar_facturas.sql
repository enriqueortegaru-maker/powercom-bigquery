begin

begin transaction;

insert into `mm-commissions-reporting.COMISIONES.transacciones`
(
commission_id
,estado
,mes_liquidado
,id_mes
,agrupacion_canal
,canal
,concepto
,tipo_concepto
,unidades
,comision
,id_comisionista
,distribuidor
,sfid_id
,seller
,nombre_comercio
,razon_social
,cif
,zona_fiscal
,marca
,service_type
,phone_nm
,tariff_id
,tariff_ds
,service_id
,account_id
,customer_id
,line_type_ds
,bundle_type
,technology_ds
,billing_type_ds
,sale_date
,activation_date
,deactivation_date
,order_id
,order_type_agg
,cod_segmento
,cod_marca
,cod_tipo_contrato
,cod_producto
,cod_canal
,claim_code
,campaign_code
,process_code
,comments
,facturador
,sociedad
,creado
)
select
commission_id||'_ABONO'
,'calculado'
,COMISIONES.f_mes_int (mes_int)
,mes_int
,agrupacion_canal
,canal
,concepto
,tipo_concepto
,unidades
,-comision
,id_comisionista
,distribuidor
,sfid_id
,seller
,nombre_comercio
,razon_social
,cif
,zona_fiscal
,marca
,service_type
,phone_nm
,tariff_id
,tariff_ds
,service_id
,account_id
,customer_id
,line_type_ds
,bundle_type
,technology_ds
,billing_type_ds
,sale_date
,activation_date
,deactivation_date
,order_id
,order_type_agg
,cod_segmento
,cod_marca
,cod_tipo_contrato
,cod_producto
,cod_canal
,claim_code
,campaign_code
,'AJUSTE DEALER '||sfid_id_nuevo as process_code
,comments||' / Abono de factura: '|| invoice_id 
,'C_MANUAL' as facturador
,sociedad
,CURRENT_TIMESTAMP () as creado
from `mm-commissions-reporting.COMISIONES.transacciones` a,
unnest(facturas_pr) id_factura_pr
WHERE invoice_id = id_factura_pr
and a.estado = 'facturado'
--and a.concepto ='C - Calidad Cartera HOL'
;


if ( sfid_id_nuevo is not null) 
then
 insert into `mm-commissions-reporting.COMISIONES.transacciones`
  (
  commission_id
  ,estado
  ,mes_liquidado
  ,id_mes
  ,agrupacion_canal
  ,canal
  ,concepto
  ,tipo_concepto
  ,unidades
  ,comision
  ,id_comisionista
  ,distribuidor
  ,sfid_id
  ,seller
  ,nombre_comercio
  ,razon_social
  ,cif
  ,zona_fiscal
  ,marca
  ,service_type
  ,phone_nm
  ,tariff_id
  ,tariff_ds
  ,service_id
  ,account_id
  ,customer_id
  ,line_type_ds
  ,bundle_type
  ,technology_ds
  ,billing_type_ds
  ,sale_date
  ,activation_date
  ,deactivation_date
  ,order_id
  ,order_type_agg
  ,cod_segmento
  ,cod_marca
  ,cod_tipo_contrato
  ,cod_producto
  ,cod_canal
  ,claim_code
  ,campaign_code
  ,process_code
  ,comments
  ,facturador
  ,sociedad
  ,creado
  )
  select
  commission_id||'_CAMBIO_CIF'
  ,'calculado'
  ,COMISIONES.f_mes_int (mes_int)
  ,mes_int
  ,a.agrupacion_canal
  ,coalesce ( b.canal, a.canal)
  ,concepto
  ,tipo_concepto
  ,unidades
  ,comision
  ,sfid_id_nuevo
  ,a.distribuidor
  ,a.sfid_id
  ,seller
  ,b.nombre_comercio
  ,b.razon_social
  ,cif_nuevo
  ,b.zona_fiscal
  ,marca
  ,service_type
  ,phone_nm
  ,tariff_id
  ,tariff_ds
  ,service_id
  ,account_id
  ,customer_id
  ,line_type_ds
  ,bundle_type
  ,technology_ds
  ,billing_type_ds
  ,sale_date
  ,activation_date
  ,deactivation_date
  ,order_id
  ,order_type_agg
  ,cod_segmento
  ,cod_marca
  ,cod_tipo_contrato
  ,cod_producto
  ,cod_canal
  ,claim_code
  ,campaign_code
,'AJUSTE DEALER '||sfid_id_nuevo as process_code
  ,comments
  ,facturador
  ,sociedad
  ,CURRENT_TIMESTAMP () as creado
  from `mm-commissions-reporting.COMISIONES.transacciones` a,
  unnest(facturas_pr) id_factura_pr,
  --`mm-commissions-reporting.SAP.vendor_list` b
  `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
  WHERE invoice_id = id_factura_pr
  and b.sfid_id = sfid_id_nuevo
  and a.estado = 'facturado'
  ;

end if;

commit transaction;


EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;


end