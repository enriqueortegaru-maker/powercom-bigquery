begin

-- call COMISIONES.pr_maestro_calidad ();

create or replace table TEMP.maestro_calidad as
select
'MI' as canal, marca, service_type, tariff_id, calidad_6, calidad_12, calidad_18, calidad_24
from `mm-commissions-reporting.GS.MARCO_TARIFAS_MI`
union all 
select
'MP' as canal, marca, service_type, tariff_id, calidad_6, calidad_12, calidad_18, calidad_24
from `mm-commissions-reporting.GS.MARCO_TARIFAS_MP`
union all 
select
'MR' as canal, marca, service_type, tariff_id, calidad_6, calidad_12, calidad_18, calidad_24
from `mm-commissions-reporting.GS.MARCO_TARIFAS_MR`
union all
select
'NR' as canal, marca, service_type, tariff_id, calidad_6, calidad_12, calidad_18, calidad_24
from `mm-commissions-reporting.GS.MARCO_TARIFAS_NR`
union all
select
'CA' as canal, marca, service_type, tariff_id, calidad_6, calidad_12, calidad_18, calidad_24
from `mm-commissions-reporting.GS.MARCO_TARIFAS_CA`
;

CREATE or replace TABLE COMISIONES.maestro_calidad as

select
canal, marca, service_type, tariff_id, tipo_calidad, comision
from TEMP.maestro_calidad
unpivot (comision for tipo_calidad in (calidad_6, calidad_12, calidad_18, calidad_24 ))
where comision > 0
and comision is not null
;

end