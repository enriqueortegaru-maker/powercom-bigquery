begin

begin transaction;

ASSERT (
SELECT ABS(SUM(COMISION) - importe_pr)
from `mm-commissions-reporting.COMISIONES.transacciones` 
cross join unnest (canales_pr) canal_pr
where facturador = 'C_IFS'
and process_code = reporting_id_pr
and canal = canal_pr
and estado = 'calculado'
) < 0.01
;

UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
set a.estado = 'validado'
from unnest (canales_pr) canal_pr
where facturador = 'C_IFS'
and process_code = reporting_id_pr
and canal = canal_pr
;

commit transaction;

-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('');

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;


end