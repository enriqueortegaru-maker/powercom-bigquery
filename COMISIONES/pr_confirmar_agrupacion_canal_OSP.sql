begin

/*
call COMISIONES.pr_rollback_confirmar_agrupacion_canal (202410 , 'MC_NOEXCL1040.');
call COMISIONES.pr_confirmar_agrupacion_canal_OSP (202608 ,['TLV - Negocios'] , null, 'MC_OSP2608.02', 'COMISIONES.confirmado_OSP_20260902');

*/

--drop table COMISIONES.confirmado_OSP_20260901
/*
 select *
 from COMISIONES.confirmado_OSP_20260901
*/
declare sql string;

assert exists (select 1 from (select  SESSION_USER() as user) where user in ('nuno.adam@masmovil.com','enrique.ortegaru@masmovil.com','javier.gonzalezm@masmovil.com','jessica.lifante@asesormasmovil.es','ainhoa.fernandezs@asesormasmovil.es'));

begin transaction;

-- assert exists (
-- select 1
-- from `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado`, unnest (agrupacion_canal_pr) as agg_canal
-- where id_mes = mes_pr
-- and estado = 'validado' and agrupacion_canal = agg_canal and case when process_code_pr is not null then process_code else 'NA' end = coalesce (process_code_pr, 'NA')
-- );

assert not exists (
select 1
from `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado`
where proceso_sap = proceso_sap_pr
);
-- update `mm-commissions-reporting.COMISIONES.transacciones` 
-- set campaign_code ='TECALIS '||cif,
-- cif ='B70186184' ,
-- zona_fiscal ='PEN'  
-- where id_mes = mes_pr
-- and agrupacion_canal ='No Exclusivo'
-- and estado ='validado'
-- and campaign_code ='TECALIS'
-- ;


-- UPDATE `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado` TRANSACCIONES
-- SET TRANSACCIONES.cond_pago = COALESCE(DEALER.cond_pago, 'F000') 
-- FROM `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado` 
-- WHERE TRANSACCIONES.id_mes = mes_pr
--       AND TRANSACCIONES.facturador = 'THADEA'
-- ;


create or replace temporary table tabla_temporal as
select
 COMISIONES.f_limpiar_caracteres(proceso_sap_pr)||'_'||row_number () over ()  as id_registro
,'RTMV' as sociedad
,CASE WHEN  agrupacion_canal ='Exclusivo' then 'BYMOVIL' ELSE
  MAX(id_comisionista) END  as id_comisionista 
,'DEA' tipo_comisionista
,CASE WHEN  agrupacion_canal ='Exclusivo' then 'B39688197' ELSE CIF END AS CIF
,CASE when cif ='03894589E' then 'PEN' ELSE zona_fiscal end as zona_fiscal
,tipo_concepto
,substr(COMISIONES.f_limpiar_caracteres (concepto),1,45) descripcion_concepto
,sum(unidades) as uds
,round(sum(comision),2) as importe_base
,'EUR' AS moneda
,'T' as via_pago
,'F000' AS cond_pago
-- ,cond_pago
,cod_canal
,cod_producto
,cod_tipo_contrato
,cod_marca
,'999' cod_operador
,cod_segmento
,facturador
,array_agg (commission_id) as commissions_id
from `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado` , unnest (agrupacion_canal_pr) as agg_canal
where id_mes = mes_pr
and estado in ('facturado')
and agrupacion_canal = agg_canal
and tipo_concepto NOT in ('FINT','SRCI','SUBS')
and case when process_code_pr is not null then process_code else 'NA' end = coalesce (process_code_pr, 'NA')
group by 2,4,5,6,7,8,11,12,13,14,15,16,17,18,19,20,agrupacion_canal
order by 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
;

update `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado`  a
set a.id_registro = b.id_registro,
proceso_sap = proceso_sap_pr,
    estado = 'facturado',
    modificado = current_timestamp()
from tabla_temporal b, unnest(commissions_id) comm_array
where a.commission_id = comm_array
;



commit transaction; 

set sql = 'create table ';
set sql = sql || tabla_sap;
set sql = sql || ' as select * from tabla_temporal ';

execute immediate sql;

-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('');

CALL`mm-commissions-reporting.TEMP.pr_carga_comisiones_osp`(process_code_pr,tabla_sap);
-- CALL`mm-commissions-reporting.TEMP.pr_carga_comisiones_osp`('MC_OSP2608.01','COMISIONES.confirmado_OSP_20260901');


end