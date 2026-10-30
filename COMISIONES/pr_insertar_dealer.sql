begin

declare sql, nombre_tabla string;
declare meses array<STRING>;

/*
CALL `mm-commissions-reporting.COMISIONES.pr_insertar_dealer`('NATIONAL RETAIL')
*/

set meses = (
SELECT split(valor)
FROM GS.PARAMETROS
where parametro = 'meses_validacion_tarifas'
limit 1
);


set nombre_tabla =
case  agrupacion_canal_pr
when 'D2D' then 'd2d_dealers'
when 'Exclusivo' then 'exclusivo_dealers'
when 'Guuk' then 'guuk_dealers'
when 'TLV - Cross-sell' then 'tlv_cross_sell_dealers'
when 'TLV - DO' then 'tlv_do_dealers'
when 'TLV - Negocios' then 'tlv_negocios_dealers'
when 'TLV - Outbound' then 'tlv_outbound_dealers'
when 'TLV - Web' then 'tlv_web_dealers'
when 'FFCC' then 'FFCC_dealers'
when 'ENDESA' then 'ENDE_dealers'
when 'NATIONAL RETAIL' THEN 'national_retail_dealers'
when 'KRT - Web' then 'krt_web'
when 'KRT - Punto de Venta' then 'KRT_Punto_Venta'
when 'KRT - Telecable' THEN 'telecable_dealers'
when 'B2B - Parlem' THEN 'DEALERS_PARLEM'
when 'B2B - Alterna' THEN 'DEALERS_ALTERNA'
when 'B2B - NASH' THEN 'NASH_DEALERS'
when 'B2B - NETLLAR' THEN 'NETLLAR_DEALERS'
when 'B2B - HITS' THEN 'HITS_DEALERS'
/*when 'Exclusivo Orange' THEN 'exclusivo_orange_dealers'
when 'Multibrand Orange' THEN 'multibrand_orange_dealers'
when 'Fuerzas Comerciales' THEN 'ffcc_orange_dealers'
when 'By Movil' THEN 'bymovil_orange_dealers'
*/
end
;

/*
if id_mes_pr not in (202301, 202302,202303, 202304,202305, 202306,20230, 202308,202309, 202310,202311, 202312)
then RAISE USING message = FORMAT("Mes no válido");
end if;
*/

if agrupacion_canal_pr = 'Exclusivo' then CALL pr_crear_exclusivo_dealers ();
end if;

if agrupacion_canal_pr not in ('TLV - Cross-sell','TLV - DO','TLV - Web','TLV - Outbound','FFCC', 'ENDESA','NATIONAL RETAIL') then

set sql = 'insert into COMISIONES.dealer select id_mes_pr, "';
set sql = sql || agrupacion_canal_pr;

set sql = sql || '", id_comisionista  ,id_comisionista,   case when canal in ("EML","EYG","ECI","EDB", "ENX", "ENK", "GUUK") then "BYMOVIL" when id_comisionista = "KO" then "CAROUT007" when canal in ("EOCAR","EODED","EODHO","EOFRA","EOGNR","EOTP") then padre_final else null end, canal, comisiona, nombre_comercio, razon_social, documento, zona_fiscal, comentarios, cast(null as string), cond_pago, SESSION_USER() , CURRENT_TIMESTAMP(), ';
set sql = sql || ' from `mm-commissions-reporting.GS.';
set sql = sql || nombre_tabla;
set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr';
end if;


if agrupacion_canal_pr in ('TLV - Cross-sell','TLV - DO','TLV - Web','TLV - Outbound','Exclusivo', 'FFCC', 'ENDESA','NATIONAL RETAIL') then

set sql = 'insert into COMISIONES.dealer select id_mes_pr, "';
set sql = sql || agrupacion_canal_pr;

set sql = sql || '",CASE WHEN CANAL IN ("WA","BO","CI","DO","DOT","XO","XSO","XI","XIBO","OU","GB","OUO","OUOC","OUOV","OUOCC","OUOP","ENKO","ENXO","FFCC","EODHO","EOCAR","EOGNR","EOFRA","EODED","EOTP","FNAC_NR") THEN COALESCE(ccc_jazztel,id_comisionista) else id_comisionista END ,id_comisionista,   case when canal in ("EML","EYG","ECI","EDB", "ENX", "ENK", "GUUK","ENKO","ENXO") then "BYMOVIL" when id_comisionista = "KO" then "CAROUT007" when canal in ("EOCAR","EODED","EODHO","EOFRA","EOGNR","EOTP") then padre_final else null end, canal, comisiona, nombre_comercio, razon_social, documento, zona_fiscal, comentarios, cast(null as string), cond_pago, SESSION_USER() , CURRENT_TIMESTAMP(), ';
set sql = sql || ' from `mm-commissions-reporting.GS.';
set sql = sql || nombre_tabla;
set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr';
end if;

execute immediate sql;

end