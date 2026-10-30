begin

declare sql string;

begin transaction;

update `mm-commissions-reporting.COMISIONES.transacciones` a
set a.estado = 'calculado',
modificado = current_timestamp()
where estado = 'validado'
and agrupacion_canal = agrupacion_canal_pr
and substr ( commission_id, 1, length (prefijo_pr) ) = prefijo_pr
;

assert abs((
  select sum(comision)
  from  `mm-commissions-reporting.COMISIONES.transacciones`
  where estado = 'calculado'
  and agrupacion_canal = agrupacion_canal_pr
  and substr ( commission_id, 1, length (prefijo_pr) ) = prefijo_pr
) - importe_pr) < 0.01 ;

COMMIT TRANSACTION;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;
    
end