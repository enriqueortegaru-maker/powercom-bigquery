begin

/*
call COMISIONES.pr_rollback_confirmar_agrupacion_canal (202301 , 'MCOM 0223.16');
call COMISIONES.pr_confirmar_agrupacion_b2b (202506 , ['B2B - Marblanca Alterna'], null, 'MC_B2BMBA0625.32', 'COMISIONES.confirmado_20250732');
*/

declare sql string;

assert exists (select 1 from (select  SESSION_USER() as user) where user in ('nuno.adam@masmovil.com','enrique.ortegaru@masmovil.com','javier.gonzalezm@masmovil.com','jessica.lifante@asesormasmovil.es'));

begin transaction;

assert exists (
select 1
from `mm-commissions-reporting.COMISIONES.transacciones`, unnest (agrupacion_canal_pr) as agg_canal
where id_mes = mes_pr
and estado = 'validado' and agrupacion_canal = agg_canal and case when process_code_pr is not null then process_code else 'NA' end = coalesce (process_code_pr, 'NA')
);

assert not exists (
select 1
from `mm-commissions-reporting.COMISIONES.transacciones`
where proceso_sap = proceso_sap_pr
);

create or replace temporary table tabla_temporal as
select
 COMISIONES.f_limpiar_caracteres(proceso_sap_pr)||'_'||row_number () over ()  as id_registro
,sociedad
,id_comisionista
,'DEA' tipo_comisionista
,CIF
,zona_fiscal
,tipo_concepto
,substr(COMISIONES.f_limpiar_caracteres (concepto),1,45) descripcion_concepto
-- ,sum(unidades) as uds
-- , CASE
-- WHEN agrupacion_canal in ('B2B - Adamo','B2B - Cablemovil','B2B - Cablemovil Alterna','B2B - Marblanca','B2B - Marblanca Alterna', 'B2B - Parlem') THEN COUNT(DISTINCT PHONE_NM) 
-- ELSE SUM(unidades) END AS uds
,COUNT(DISTINCT PHONE_NM) AS uds
 ,round(sum(comision),2) as importe_base
,'EUR' AS moneda
,case 
when id_comisionista = 'F25152' then 'C'
when agrupacion_canal in ('B2B - Adamo','B2B - Cablemovil','B2B - Cablemovil Alterna','B2B - Marblanca','B2B - Marblanca Alterna', 'B2B - Parlem') then 'Y' 
else 'C' END as via_pago
,case 
when id_comisionista = 'F25152' THEN 'Z020'
when cif in ('B23548951','B54496930','B03894003','B54603576','B26314443','B54776265','B18919597','B93299709','B13565924','B82999798','B98260334','A53118279','B93542017','B90061938','B18932855','B98822992','B97688329','B88567896','B93538445','B02547149','B14826077','B54957527','B14912505','B72318124','B19567999','B76633379','B93230258','B01989474','G36216406') THEN 'ZP60'
 when agrupacion_canal in ('B2B - Adamo','B2B - Cablemovil','B2B - Cablemovil Alterna','B2B - Marblanca','B2B - Marblanca Alterna', 'B2B - Parlem') THEN 'Z005' 
 ELSE 'Z020' END as cond_pago
,cod_canal
,cod_producto
,cod_tipo_contrato
,cod_marca
,'999' cod_operador
,cod_segmento
,facturador
,array_agg (commission_id) as commissions_id
from `mm-commissions-reporting.COMISIONES.transacciones`, unnest (agrupacion_canal_pr) as agg_canal
where id_mes = mes_pr
and estado in ('validado')
--and agrupacion_canal = 'B2B - Cablemovil'
and agrupacion_canal = agg_canal
and case when process_code_pr is not null then process_code else 'NA' end = coalesce (process_code_pr, 'NA')
group by  2,3,4,5,6,7,8,11,12,13,14,15,16,17,18,19,20
order by 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
;

update `mm-commissions-reporting.COMISIONES.transacciones` a
set a.id_registro = b.id_registro,
proceso_sap = proceso_sap_pr,
    estado = 'confirmado',
    modificado = current_timestamp()
from tabla_temporal b, unnest(commissions_id) comm_array
where a.commission_id = comm_array
;

commit transaction; 

set sql = 'create table ';
set sql = sql || tabla_sap;
set sql = sql || ' as select * from tabla_temporal ';

execute immediate sql;

call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('');


end