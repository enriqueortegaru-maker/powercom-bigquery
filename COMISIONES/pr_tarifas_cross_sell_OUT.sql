begin

declare meses array<STRING>;
declare sql string;

set meses = (
SELECT split(valor)
FROM GS.PARAMETROS
where parametro = 'meses_validacion_tarifas'
limit 1
);

FOR canal IN (
    SELECT canal FROM UNNEST(canales) canal)
  DO

IF canal.canal IN ('XS','XSO') THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas_cross_sell_OUT` ';
  set sql = sql || 'select "';
  set sql = sql || canal.canal;
  set sql = sql || '", id_mes_pr, * except (id_mes_pr) , SESSION_USER(), CURRENT_TIMESTAMP() from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || 'XS_new';
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';



END IF;

END FOR;

execute immediate (sql);

end