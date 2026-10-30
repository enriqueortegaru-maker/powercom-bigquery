begin

declare sql string;

assert exists (select 1 from (select  SESSION_USER() as user) where user in ('nuno.adam@masmovil.com','enrique.ortegaru@masmovil.com'));

set agrupacion_canal_pr =
case when agrupacion_canal_pr is null or (select agg_pr from unnest(agrupacion_canal_pr) agg_pr limit 1)= 'Todos' then (select array_agg(distinct agrupacion_canal) from `mm-commissions-reporting.GS.CANALES` )
else agrupacion_canal_pr end;

if prefijo_pr is not null then


begin transaction;

assert abs((
  select sum(comision)
  from  `mm-commissions-reporting.COMISIONES.transacciones`,
  unnest (agrupacion_canal_pr) agg_canal
  where estado = 'validado'
  and agrupacion_canal = agg_canal
    and id_mes = id_mes_pr
  and substr ( commission_id, 1, length (prefijo_pr) ) = prefijo_pr
) - importe_pr) < 0.1 ;

update `mm-commissions-reporting.COMISIONES.transacciones` a
set a.estado = 'publicado',
modificado = current_timestamp()
from  unnest (agrupacion_canal_pr) agg_canal
where estado = 'validado'
and agrupacion_canal = agg_canal
  and id_mes = id_mes_pr
and substr ( commission_id, 1, length (prefijo_pr) ) = prefijo_pr
;

COMMIT TRANSACTION;



else



begin transaction;

assert abs((
  select sum(comision)
  from  `mm-commissions-reporting.COMISIONES.transacciones`,
  unnest (agrupacion_canal_pr) agg_canal
  where estado = 'validado'
  and agrupacion_canal = agg_canal
  and id_mes = id_mes_pr
) - importe_pr) < 0.1 ;

update `mm-commissions-reporting.COMISIONES.transacciones` a
set a.estado = 'publicado',
modificado = current_timestamp()
from  unnest (agrupacion_canal_pr) agg_canal
where estado = 'validado'
and agrupacion_canal = agg_canal
  and id_mes = id_mes_pr
;

COMMIT TRANSACTION;

end if;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;
    
end