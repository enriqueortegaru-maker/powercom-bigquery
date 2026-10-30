BEGIN

-- call `mm-commissions-reporting.COMISIONES.pr_insert_netllar`(202403)

begin transaction;

DELETE `mm-commissions-reporting.COMISIONES.transacciones` 
WHERE ESTADO = 'calculado'
and id_mes = mes_pr
and agrupacion_canal ='B2B - Netllar'
and commission_id like 'R_CMAN%'
and canal = 'NTCLI'
;

INSERT INTO
  `mm-commissions-reporting.COMISIONES.transacciones` (
    commission_id,
estado,
mes_liquidado,
id_mes,
agrupacion_canal,
canal,
concepto,
tipo_concepto,
unidades,
comision,
id_comisionista,
distribuidor,
sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
zona_fiscal,
marca,
service_type,
phone_nm,
tariff_id,
tariff_ds,
service_id,
account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
deactivation_date,
order_id,
order_type_agg,
cod_segmento,
cod_marca,
cod_tipo_contrato,
cod_producto,
cod_canal,
campaign_code,
serial_number,
tax_base,
claim_code,
process_code,
comments,
facturador,
sociedad,
creado
    )
SELECT
    'R_CMAN'||'_'||CAST(mes_pr AS string)||'_N2CLI_'||ROW_NUMBER() OVER () as commission_id,
    'calculado' as estado,
    COMISIONES.f_mes_int(mes_pr) as mes_liquidado,
    mes_pr,
    'B2B - Netllar' as agrupacion_canal,
    'NTCLI' as canal,
    COMISIONES.f_limpiar_caracteres (concepto) as concepto,
    tipo_concepto,
    unidades,
    importe as comision,
    a.id_comisionista,
    'Netllar' as distribuidor,
    cast ( null as string) sfid_id,
    cast ( null as string) as seller,
    nombre_comercio,
    b.razon_social,
    b.documento,
    zona_fiscal,
    'NETLLAR' as marca,
    service_type,
    cast ( null as string) as phone_nm,
    cast ( null as string) as tariff_id,
    cast ( null as string) as tariff_ds,
    cast ( null as string) as service_id,
    cast ( null as string) as account_id,
    cast ( null as string) as customer_id,
    cast ( null as string) as line_type_ds,
    cast ( null as string) as bundle_type,
    cast ( null as string) as technology_ds,
    cast ( null as string) as billing_type_ds,

    cast ( null as date) as sale_date,
    cast ( null as date) as activation_date,
    cast ( null as date) as deactivation_date,

    cast ( null as string) as order_id,
    cast ( null as string) as order_type_agg,

    '42' as cod_segmento,
    '05' as cod_marca,
   CASE WHEN (a.concepto IN ('A - Fibra','A - Fijo Migracion','D - Extracomision Fibra','D - Extracomision 2p','A - Servicio Fijo Migracion', 'Z - Ajustes', 'C - Cartera Fijo Fibra Indirecta', 'C - Cartera Fijo Fibra Directa','C - Cartera Fijo CM', 'D - Extracomision Fibra 2P', 'D - Extracomision Fibra 3P','C - Cartera Fijo Directa','C - Cartera Fijo Indirecta','D - Camp 3P','D - Camp 2P') OR a.concepto LIKE 'C - Cartera Fijo Fibra Indirecta %' OR a.concepto LIKE 'C - Cartera Fijo Fibra Directa %' OR a.concepto LIKE 'C - Cartera Fijo CM %' OR a.concepto LIKE 'C - Cartera Fijo Directa %' OR a.concepto LIKE 'C - Cartera Fijo Indirecta %') THEN '61' else '20' end  as cod_tipo_contrato,
    '999' as cod_producto,
    '30' as cod_canal,
    cast(null as string) as campaign_code,
    cast(null as string) as serial_number,
    case when base_imponible > 0 then safe_cast(base_imponible as float64) end as tax_base,
    cast (null as string) as claim_code,
    cast (null as string) as process_code,
    cast (null as string) as comments,
    'C_MANUAL' as facturador,
    'X001' as sociedad,
    CURRENT_TIMESTAMP () as creado
from COMISIONES.v_factura_netllar a
left join `mm-commissions-reporting.GS.NETLLAR_DEALERS` b on a.id_comisionista = b.id_comisionista
;

COMMIT TRANSACTION;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;  

END