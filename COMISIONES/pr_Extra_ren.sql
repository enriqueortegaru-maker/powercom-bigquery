begin

declare prefijo, mes_string string;

set mes_string = cast(id_mes_pr as string);

set prefijo = 'REEXCO_';




--call COMISIONES.pr_Extra_ren(202411, null);



create or replace table TEMP.Extracomision_renuevo as (



select * except(commission_id,estado,concepto,comision),

replace (commission_id, substring(commission_id,1,5), prefijo) AS COMMISSION_ID, 
'D - Extracomision Comercial renuevo' as concepto,
'calculado'as estado,

case 
  when B.Categoria = 'Plus MASlife' then 5
  when B.Categoria = 'Plus MASlife +' then 15
  when B.Categoria = 'Plus MASlife ++' then 20
  when B.Categoria = 'Plus MASlife +++' then 25
else 0
END as comision 
from `mm-commissions-reporting.COMISIONES.transacciones` A
left join `mm-commissions-reporting.COMISIONES.Extracomision_renuevos`  B
on A.sfid_id = B.Matricula
where id_mes = id_mes_pr and concepto in ('B - Renuevo', 'Z - Renuevo') and canal in ('EML','ENX') and B.MES = id_mes_pr);


--CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('REEXCO_', 202411, ['EML','ENX'] , 'TEMP.Extracomision_renuevo' , 'ACTUALIZAR');
end