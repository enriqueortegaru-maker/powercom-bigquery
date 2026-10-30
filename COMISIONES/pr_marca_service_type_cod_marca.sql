begin

create or replace table COMISIONES.marca_service_type_cod_marca as
with
marcas as
(
select
marca,
agrupacion_servicio,
cod_marca
from `mm-commissions-reporting.GS.MARCAS` 
unpivot (cod_marca for agrupacion_servicio in (telco, energy, insurance, telemedicine, security))
)
select 
marca,
service_type,
cod_marca,
agrupacion_servicio
from marcas
left join `mm-commissions-reporting.GS.SERVICIOS` using (agrupacion_servicio)
;

end