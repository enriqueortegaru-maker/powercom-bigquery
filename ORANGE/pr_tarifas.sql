begin

declare meses array<STRING>;
declare sql string;

set meses = (
SELECT split(valor)
FROM GS.PARAMETROS
where parametro = 'meses_validacion_tarifas'
limit 1
);

set sql = 'insert into `mm-commissions-reporting.ORANGE.tarifas` ';
set sql = sql || 'select "';
set sql = sql || canal_pr;
set sql = sql || '", id_mes_pr, * except (id_mes_pr) , SESSION_USER(), CURRENT_TIMESTAMP() from ';
set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
set sql = sql || canal_pr;
set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
set sql = sql || 'where tariff_id IS NOT NULL';

execute immediate (sql);

end