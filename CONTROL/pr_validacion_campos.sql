begin

declare sql,err string;

-- validacion de campos --

set sql = 'create or replace temporary table validacion_campos as ';
set sql = sql || 'with validacion as ( select columna, valor from `mm-commissions-reporting.CONTROL.VALIDACION_CAMPOS`, unnest(split(valores)) valor ), tabla_final as ( ';
set sql = sql || 'SELECT distinct "sociedad" as columna, sociedad as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "tipo_comisionista" as columna, tipo_comisionista as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "zona_fiscal" as columna, zona_fiscal as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "tipo_concepto" as columna, tipo_concepto as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "moneda" as columna, moneda as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "via_pago" as columna, via_pago as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "cond_pago" as columna, cond_pago as valores from '||tabla||' union all ';
--set sql = sql || 'SELECT distinct "cod_canal" as columna, cod_canal as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "cod_producto" as columna, cod_producto as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "cod_tipo_contrato" as columna, cod_tipo_contrato as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "cod_marca" as columna, cod_marca as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "cod_operador" as columna, cod_operador as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "cod_segmento" as columna, cod_segmento as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "facturador" as columna, facturador as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "clasificacion_concepto" as columna, clasificacion_concepto as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "canal" as columna, canal as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "product_type" as columna, product_type as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "bundle_type" as columna, bundle_type as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "agrupacion_cod_tipo_contrato" as columna, agrupacion_cod_tipo_contrato as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "segmento" as columna, segmento as valores from '||tabla||' union all ';
set sql = sql || 'SELECT distinct "marca" as columna, marca as valores from '||tabla;
set sql = sql || ') select a.columna, a.valores from tabla_final a left join validacion b on a.columna=b.columna and a.valores=b.valor ';
set sql = sql || 'left join `mm-commissions-reporting.CONTROL.VALIDACION_CAMPOS` c on a.columna = c.columna and not c.acepta_nulo ';
set sql = sql || 'where a.columna is null ';
set sql = sql || 'or (a.valores is not null and b.columna is null) ';
set sql = sql || 'or (a.valores is null and c.columna is not null) ';

execute immediate (sql);

select sql;

set err = 

(

select STRING_AGG(concat(columna,': ',ifnull(valores,'Valor nulo'))) from validacion_campos

);

if err is not null then RAISE USING MESSAGE = 'Error validacion campos: '||err; end if;

end