BEGIN

-- call `mm-commissions-reporting.COMISIONES.pr_insert_hits`(202509)

begin transaction;

DELETE `mm-commissions-reporting.COMISIONES.transacciones` 
WHERE ESTADO = 'calculado'
and id_mes = mes_pr
and commission_id like 'COHITS%'
and canal = 'HICLI'
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
    'COHITS'||'_'||CAST(mes_pr AS string)||'_HICLI_'||ROW_NUMBER() OVER () as commission_id,
    'calculado' as estado,
    COMISIONES.f_mes_int(mes_pr) as mes_liquidado,
    mes_pr,
    'B2B - Hits' as agrupacion_canal,
    'HICLI' as canal,
    COMISIONES.f_limpiar_caracteres (concepto) as concepto,
    tipo_concepto,
    unidades,
    importe as comision,
    a.id_comisionista,
    'Hits' as distribuidor,
    a.id_comisionista AS  sfid_id,
    a.id_comisionista as seller,
    nombre_comercio,
    b.razon_social,
    b.documento as cif,
    zona_fiscal,
    'HITS' as marca,
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
    '09' as cod_marca,
    CASE WHEN a.concepto like '%Fibra CM%' OR a.concepto in ('D - Camp 3P','D - Camp 2P') THEN '61' else '20' end  as cod_tipo_contrato,
    '999' as cod_producto,
    '30' as cod_canal,
    cast(null as string) as campaign_code,
    cast(null as string) as serial_number,
    case when base_imponible > 0 then safe_cast(base_imponible as float64) end  as tax_base,
    cast (null as string) as claim_code,
    cast (null as string) as process_code,
    cast (null as string) as comments,
    'C_MANUAL' as facturador,
    'X001' as sociedad,
    CURRENT_TIMESTAMP () as creado
from COMISIONES.v_factura_hits a
left join `mm-commissions-reporting.GS.HITS_DEALERS` b on a.id_comisionista = b.id_comisionista
;

COMMIT TRANSACTION;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;  

END