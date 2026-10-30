begin

/*
call COMISIONES.pr_rollback_confirmar_agrupacion_canal (202301 , 'MCOM 0223.16');
call COMISIONES.pr_confirmar_agrupacion_canal_terminales (202301 , ['TLV - Outbound','TLV - Cross-sell'], null, 'MCOM 0223.16', 'COMISIONES.confirmado_20230116');
*/

declare sql string;

assert exists (select 1 from (select  SESSION_USER() as user) where user in ('nuno.adam@masmovil.com','enrique.ortegaru@masmovil.com','javier.gonzalezm@masmovil.com'));

begin transaction;

assert exists (
select 1
from `mm-commissions-reporting.COMISIONES.transacciones`, unnest (agrupacion_canal_pr) as agg_canal
where id_mes = mes_pr
and estado in ('validado','calculado') and agrupacion_canal = agg_canal and case when process_code_pr is not null then process_code else 'NA' end = coalesce (process_code_pr, 'NA')
);

assert not exists (
select 1
from `mm-commissions-reporting.COMISIONES.transacciones`
where proceso_sap = proceso_sap_pr
);


UPDATE `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
SET TRANSACCIONES.cond_pago = COALESCE(DEALER.cond_pago, 'Z001')
FROM (
     SELECT id_comisionista, agrupacion_canal, cond_pago
     FROM `mm-commissions-reporting.COMISIONES.dealer`, UNNEST(agrupacion_canal_pr) AS agg_canal
     WHERE agrupacion_canal = agg_canal
     QUALIFY ROW_NUMBER() OVER (PARTITION BY id_comisionista ORDER BY id_mes DESC, creado DESC) = 1
     ) DEALER
WHERE TRANSACCIONES.id_mes = mes_pr
      AND TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal
      AND TRANSACCIONES.id_comisionista = DEALER.id_comisionista
;


create or replace temporary table tabla_temporal as
select
 COMISIONES.f_limpiar_caracteres(proceso_sap_pr)||'_'||row_number () over ()  as id_registro
,sociedad
,CASE WHEN CIF = 'B39688197' THEN 'BYMOVIL' 
      ELSE MAX(id_comisionista) END AS id_comisionista
,'DEA' tipo_comisionista
,CIF
,CASE when cif ='03894589E' then 'PEN' ELSE zona_fiscal end as zona_fiscal
,tipo_concepto
,substr(COMISIONES.f_limpiar_caracteres (concepto),1,45) descripcion_concepto
,sum(unidades) as uds
,round(sum(comision),2) as importe_base
,'EUR' AS moneda
,'C' as via_pago
,'Z001' AS cond_pago
,cod_canal
,cod_producto
,cod_tipo_contrato
,cod_marca
,'999' cod_operador
,cod_segmento
,'C_IFS' AS facturador
,array_agg (commission_id) as commissions_id
from `mm-commissions-reporting.COMISIONES.transacciones`, unnest (agrupacion_canal_pr) as agg_canal
where id_mes = mes_pr
and estado in ('validado','calculado')
and agrupacion_canal = agg_canal
and case when process_code_pr is not null then process_code else 'NA' end = coalesce (process_code_pr, 'NA')
and tipo_concepto in ('FINT','SRCI','SUBS')
group by 2,4,5,6,7,8,11,12,13,14,15,16,17,18,19,20
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