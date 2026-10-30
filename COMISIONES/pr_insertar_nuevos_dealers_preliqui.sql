begin

declare sql, nombre_tabla string;
declare mes STRING;

/*
CALL `mm-commissions-reporting.COMISIONES.pr_insertar_nuevos_dealers_preliqui`('Exclusivo')
*/


set mes = (
SELECT 
valor
FROM `mm-commissions-reporting.GS.PARAMETROS` 
WHERE parametro ='mes_actual'
);


set nombre_tabla =
case  agrupacion_canal_pr
when 'Exclusivo' then 'exclusivo_dealers'
end
;


set sql = 'insert into COMISIONES.dealer select ';
set sql = sql || mes;
set sql = sql ||', "'; 
set sql = sql || agrupacion_canal_pr;
set sql = sql || '", a.id_comisionista  ,a.id_comisionista,   case when a.canal in ("EML","EYG","ECI","EDB", "ENX", "ENK", "GUUK") then "BYMOVIL" when a.id_comisionista = "KO" then "CAROUT007" else null end, a.canal, a.comisiona, a.nombre_comercio, a.razon_social, a.documento, a.zona_fiscal, a.comentarios, cast(null as string), a.cond_pago, SESSION_USER() , CURRENT_TIMESTAMP(), ';
set sql = sql || ' from `mm-commissions-reporting.GS.';
set sql = sql || nombre_tabla;
set sql = sql || '` a left join COMISIONES.dealer b on a.id_comisionista = b.id_comisionista where b.id_comisionista is null';

execute immediate sql;

end