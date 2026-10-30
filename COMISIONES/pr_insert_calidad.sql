begin

--call `mm-commissions-reporting.COMISIONES.pr_insert_calidad`(202405);


declare prefijo string;

set prefijo = 'CALD_';

create or replace table TEMP.insert_calidad as 
select 
estado,	mes_liquidado,id_mes,	agrupacion_canal,	canal,	tipo_concepto,	unidades,	id_comisionista,	distribuidor,	sfid_id,	seller,	nombre_comercio,	razon_social,	cif,	zona_fiscal,	marca,	service_type,	phone_nm,	tariff_id,	tariff_ds,	service_id,	account_id,	customer_id,	line_type_ds,	bundle_type,	technology_ds,	billing_type_ds,	sale_date,	activation_date,	deactivation_date,	order_id,	order_type_agg,	cod_segmento,	cod_marca,	cod_tipo_contrato,	cod_producto,	cod_canal,	campaign_code,	serial_number,	tax_base,	claim_code,	process_code,	comments,	facturador,	proceso_sap,	id_registro,	invoice_id,	sociedad,	bp,	cuenta_contable,	centro_coste,	documento_sap,	documento_sap_posicion,	fecha_contabilizacion,	creado,	modificado,	id_factura_drive,	COMMISSION_ID,	concepto,	comision
from `mm-commissions-reporting.CALIDAD_INSERT.calidad_mayo2024` a

;

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (CALD_, 202405, (select array_agg(distinct canal) from TEMP.insert_calidad) , 'TEMP.insert_calidad' , 'ACTUALIZAR');

end