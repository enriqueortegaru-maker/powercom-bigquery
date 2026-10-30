begin

declare sql string;

set sql = '';

set sql = sql || 'insert into `mm-commissions-reporting.CONTROL.procedimientos_almacenados` ';
set sql = sql || 'select a.* from `mm-commissions-reporting.'||nombre_schema||'.INFORMATION_SCHEMA.ROUTINES` a ';
set sql = sql || 'left join `mm-commissions-reporting.CONTROL.procedimientos_almacenados` b on ';
set sql = sql || 'a.routine_schema=b.routine_schema ';
set sql = sql || 'and a.routine_name = b.routine_name ';
set sql = sql || 'and a.routine_type = b.routine_type ';
set sql = sql || 'and a.last_altered = b.last_altered ';
set sql = sql || 'where b.routine_schema is null ';

execute immediate (sql);

end