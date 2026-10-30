begin

declare sql,  err string;

begin transaction;

assert ( cast ( mes_int as string ) >= COMISIONES.f_parametro ('mes_ejecucion') );

-- Validacion de campos --

set sql = 'assert not exists ( with valores as ( ';
set sql = sql || 'select distinct columna, valores from  ';
set sql = sql || tabla_origen;
set sql = sql || ' unpivot ( valores for columna in (';
set sql = sql || (select string_agg( column_name ) from `mm-commissions-reporting.GS.TABLA_TRANSACCIONES` where possible_values is not null and column_name not in ('estado', 'cod_canal', 'agrupacion_canal', 'cod_marca'));
set sql = sql || ')) ';
set sql = sql || '),valores_permitidos as ( select column_name columna, valor_permitido valores ';
set sql = sql || 'from `mm-commissions-reporting.GS.TABLA_TRANSACCIONES`, unnest(split(possible_values)) valor_permitido ) ';
set sql = sql || 'select a.* from valores a left join valores_permitidos b using (columna, valores) where b.valores is null); ';

execute immediate (sql);

/*-- Validación de ID Registro / fecha / campaña --

set sql =        'assert not exists ( select 1 from ';
set sql = sql || tabla_origen;
set sql = sql ||  ' where SUBSTR(commission_id,1, LENGTH(GREATEST("';
set sql = sql ||  clave;
set sql = sql ||  '",RPAD("';
set sql = sql ||  clave;
set sql = sql ||  '",5,"_")))) <> GREATEST("';
set sql = sql ||  clave;
set sql = sql ||  '",RPAD("';
set sql = sql ||  clave;
set sql = sql ||  '",5,"_"))';
set sql = sql ||  ' or id_mes != '||cast(mes_int as string);
set sql = sql ||  ' or ( agrupacion_canal = "TLV - Cross-sell" and campaign_code is null )';
set sql = sql ||  ' or ( tipo_concepto in ("UPFR") and service_type not in ("INTERNET", "MOBILE"))';
set sql = sql ||  ' or id_comisionista is null';
set sql = sql ||  ' or estado !="calculado"';
set sql = sql ||  ' or canal not in ( ';
set sql = sql ||  (select string_agg('"'||canal_pr||'"') from unnest(canales_pr) as canal_pr);  
set sql = sql ||  '  )';
set sql = sql ||  ' );';

execute immediate (sql);*/

-- Validación de Facturador Manual --

set sql =        'assert not exists ( select 1 from ';
set sql = sql || tabla_origen;
set sql = sql || ' where facturador != "C_MANUAL");';

if not
  ( clave = 'IFS_' or clave = 'IFS__' or clave = 'MCOM' or clave = 'NAV')
then
  execute immediate (sql);
end if;

-- Validacion gestion de canal --

set sql =        'assert not exists ( select 1 from ';
set sql = sql || tabla_origen;
set sql = sql || ' a left join `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` b on a.distribuidor=b.id_comisionista ';
set sql = sql || 'where substr(a.concepto,1,1) in ("F","H","Y") AND a.canal IN ("CA","MI","MP","MR","NR","PH")';
set sql = sql || 'and a.cif<>b.documento); ';

execute immediate (sql);


-- Validación de estado de liquidacion  --
set sql =        'assert not exists ( select 1 from ';
set sql = sql || 'COMISIONES.krt_transacciones ';
set sql = sql || 'where canal in (';
set sql = sql || (select string_agg('"'||canal_pr||'"') from unnest(canales_pr) as canal_pr);
set sql = sql || ') ';
set sql = sql || ' and commission_id like "';
set sql = sql ||  clave;
set sql = sql ||  '%" and id_mes =';
set sql = sql ||  cast(mes_int as string);
set sql = sql ||  ' and estado !="calculado"';
set sql = sql ||  ' );';

execute immediate (sql);


if modo != 'INSERTAR' then


-- Delete tabla destino --

set sql =         'delete ';
set sql = sql ||  'COMISIONES.krt_transacciones';
set sql = sql ||  ' where SUBSTR(commission_id,1, LENGTH(GREATEST("';
set sql = sql ||  clave;
set sql = sql ||  '",RPAD("';
set sql = sql ||  clave;
set sql = sql ||  '",5,"_")))) = GREATEST("';
set sql = sql ||  clave;
set sql = sql ||  '",RPAD("';
set sql = sql ||  clave;
set sql = sql ||  '",5,"_"))';
set sql = sql ||  ' and id_mes = ';
set sql = sql ||  cast(mes_int as string);
set sql = sql ||  ' and estado ="calculado" ';
set sql = sql ||  ' and canal in ( ';
set sql = sql || (select string_agg('"'||canal_pr||'"') from unnest(canales_pr) as canal_pr);
set sql = sql ||  '); ';

execute immediate (sql);

end if;

-- Insert tabla destino --
set sql = '';
set sql = sql || ' insert into ';
set sql = sql || ' COMISIONES.krt_transacciones';

set sql = sql || ' (commission_id,';
set sql = sql || ' estado,';
set sql = sql || ' mes_liquidado,';
set sql = sql || ' id_mes,';

set sql = sql || ' agrupacion_canal,';
set sql = sql || ' canal,';
set sql = sql || ' concepto,';
set sql = sql || ' tipo_concepto,';
set sql = sql || ' unidades,';
set sql = sql || ' comision,';
set sql = sql || ' id_comisionista,';
set sql = sql || ' distribuidor,';
set sql = sql || ' sfid_id,';
set sql = sql || ' seller,';
set sql = sql || ' nombre_comercio,';
set sql = sql || ' razon_social,';
set sql = sql || ' cif,';
set sql = sql || ' zona_fiscal,';
set sql = sql || ' marca,';
set sql = sql || ' service_type,';
set sql = sql || ' phone_nm,';
set sql = sql || ' tariff_id,';
set sql = sql || ' tariff_ds,';
set sql = sql || ' service_id,';
set sql = sql || ' account_id,';
set sql = sql || ' customer_id,';
set sql = sql || ' line_type_ds,';
set sql = sql || ' bundle_type,';
set sql = sql || ' technology_ds,';
set sql = sql || ' billing_type_ds,';
set sql = sql || ' sale_date,';
set sql = sql || ' activation_date,';
set sql = sql || ' deactivation_date,';
set sql = sql || ' order_id,';
set sql = sql || ' order_type_agg,';
set sql = sql || ' cod_segmento,';
set sql = sql || ' cod_marca,';
set sql = sql || ' cod_tipo_contrato,';
set sql = sql || ' cod_producto,';
set sql = sql || ' cod_canal,';
set sql = sql || ' claim_code,';
set sql = sql || ' campaign_code,';
set sql = sql || ' process_code,';
set sql = sql || ' comments,';
set sql = sql || ' facturador, sociedad, creado)';

set sql = sql || ' select ';
set sql = sql || ' commission_id,';
set sql = sql || ' "calculado",';
set sql = sql || ' COMISIONES.f_mes_int ('||mes_int||'),';
set sql = sql || mes_int|| ' ,';
set sql = sql || ' coalesce ( b.agrupacion_canal,a.agrupacion_canal), ';
set sql = sql || ' canal,';
set sql = sql || ' COMISIONES.f_limpiar_caracteres (concepto),';
set sql = sql || ' tipo_concepto,';
set sql = sql || ' unidades,';
set sql = sql || ' comision,';
set sql = sql || ' id_comisionista,';
set sql = sql || ' distribuidor,';
set sql = sql || ' sfid_id,';
set sql = sql || ' seller,';
set sql = sql || ' nombre_comercio,';
set sql = sql || ' razon_social,';
set sql = sql || ' cif,';
set sql = sql || ' zona_fiscal,';
set sql = sql || ' marca,';
set sql = sql || ' service_type,';
set sql = sql || ' phone_nm,';
set sql = sql || ' tariff_id,';
set sql = sql || ' tariff_ds,';
set sql = sql || ' service_id,';
set sql = sql || ' account_id,';
set sql = sql || ' customer_id,';
set sql = sql || ' line_type_ds,';
set sql = sql || ' bundle_type,';
set sql = sql || ' technology_ds,';
set sql = sql || ' billing_type_ds,';
set sql = sql || ' sale_date,';
set sql = sql || ' activation_date,';
set sql = sql || ' deactivation_date,';
set sql = sql || ' order_id,';
set sql = sql || ' order_type_agg,';
set sql = sql || ' cod_segmento,';
set sql = sql || ' coalesce ( c.cod_marca, a.cod_marca), ';
set sql = sql || ' cod_tipo_contrato,';
set sql = sql || ' cod_producto,';
set sql = sql || ' coalesce ( b.cod_canal, a.cod_canal ), ';
set sql = sql || ' claim_code,';
set sql = sql || ' campaign_code,';
set sql = sql || ' process_code,';
set sql = sql || ' comments,';
set sql = sql || ' facturador, `mm-commissions-reporting.COMISIONES.f_sociedad`(marca), CURRENT_TIMESTAMP ()';
set sql = sql || ' from ';
set sql = sql || tabla_origen;
set sql = sql || ' a left join `mm-commissions-reporting.GS.CANALES` b using (canal) ';
set sql = sql || ' left join `mm-commissions-reporting.COMISIONES.marca_service_type_cod_marca` c using(marca, service_type) ';

execute immediate (sql);

-- Validación de duplicados  --

assert not exists (
select commission_id
from `mm-commissions-reporting.COMISIONES.krt_transacciones`
group by 1
having count(1) > 1 );

commit transaction;

-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('');

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;
    
end