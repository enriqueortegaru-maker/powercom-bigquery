begin

declare sql string;

begin transaction;

assert abs((
  select sum(comision)
  from  `mm-commissions-reporting.COMISIONES.transacciones`
  where estado = 'calculado'
  and agrupacion_canal = agrupacion_canal_pr
  and split (commission_id,'_')[OFFSET(0)] = 'CMAN'
  and split (commission_id,'_')[OFFSET(1)] = id_proceso
) - importe_pr) < 0.01 ;

update `mm-commissions-reporting.COMISIONES.transacciones` a
set a.estado = 'validado',
modificado = current_timestamp()
where estado = 'calculado'
and agrupacion_canal = agrupacion_canal_pr
and split (commission_id,'_')[OFFSET(0)] = 'CMAN'
and split (commission_id,'_')[OFFSET(1)] = id_proceso
;

COMMIT TRANSACTION;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;
    
end