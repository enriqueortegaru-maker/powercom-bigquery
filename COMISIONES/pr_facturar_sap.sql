begin

--call `mm-commissions-reporting.COMISIONES.pr_facturar_sap`()

BEGIN TRANSACTION;

update `mm-commissions-reporting.COMISIONES.transacciones` a
set
 a.estado = 'facturado'
,a.cod_segmento =b.cod_segmento
,a.cod_marca =b.cod_marca
,a.cod_tipo_contrato =b.cod_tipo_contrato
,a.cod_producto =b.cod_producto
,a.cod_canal =b.cod_canal
,a.invoice_id =b.invoice_id
,a.sociedad =b.sociedad
,a.id_comisionista = case when a.cif=b.cif then a.id_comisionista else  b.id_comisionista end
,a.zona_fiscal = b.zona_fiscal
,a.bp =b.bp
,a.cuenta_contable =b.cuenta_contable
,a.centro_coste =b.centro_coste
,a.documento_sap =b.documento_sap
,a.documento_sap_posicion = b.documento_sap_posicion
,a.fecha_contabilizacion =b.fecha_contabilizacion
,a.cif=b.cif
,a.modificado = CURRENT_TIMESTAMP()
,a.proceso_sap = b.proceso_sap
from `mm-commissions-reporting.COMISIONES.v_sap` b
where 1=1
--and a.proceso_sap = b.proceso_sap
and a.id_registro = b.id_registro
and a.estado = 'confirmado'
and b.invoice_id IS NOT NULL
;

assert not exists (
with
tabla_transacciones as
(
SELECT 
proceso_sap,
sum(comision) as importe_transacciones
from `mm-commissions-reporting.COMISIONES.transacciones`
where estado = 'facturado'
and proceso_sap NOT IN ('MCOM 1222.R1')
group by 1
),
tabla_sap as
(
select 
proceso_sap, sum(comision) as importe_sap
from `mm-commissions-reporting.COMISIONES.v_sap`
where fecha_contabilizacion >= '20250101'
group by 1
)
select *, round(importe_transacciones-importe_sap,0) as delta
from tabla_transacciones
full outer join tabla_sap USING (proceso_sap)
where proceso_sap like 'MCOM%'
and abs(round(importe_transacciones-importe_sap,0))>10
);


assert not exists (
with
tabla_transacciones as
(
SELECT 
id_registro,
sum(comision) as importe_transacciones,
from `mm-commissions-reporting.COMISIONES.transacciones`
where estado = 'facturado'
and fecha_contabilizacion >= '20250101'
group by 1
),
tabla_sap as
(
select 
id_registro, sum(comision) as importe_sap
from `mm-commissions-reporting.COMISIONES.v_sap`
where fecha_contabilizacion >= '20250101'
group by 1
)
select *, round(importe_transacciones-importe_sap,0) as delta
from tabla_transacciones a
full outer join tabla_sap b USING (id_registro)
where (a.id_registro like 'MCOM%' or b.id_registro like 'MCOM%')
and abs(round(coalesce ( importe_transacciones , 0 ) - coalesce ( importe_sap , 0 ) ,0))>10
);


COMMIT TRANSACTION;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;
    

end