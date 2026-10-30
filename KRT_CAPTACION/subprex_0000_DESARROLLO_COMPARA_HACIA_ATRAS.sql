BEGIN


DECLARE fecha date;
DECLARE hasta_1m, vmes_comision_id_1m int64;
SET fecha="2023-01-31";
SET hasta_1m=20230131;
SET vmes_Comision_id_1m=CAST(hasta_1m/100 AS INT64);
--SELECT vmes_comision_id_1m;
select s.* from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION_1MP`s
inner join (select distinct marca_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds from `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` where hasta=HASTA_1M)c
on c.marca_ds=s.marca_ds and c.canal_alta_ds=s.canal_alta_ds and c.subcanal_ds=s.subcanal_ds and c.nombre_distribuidor_alta_ds=s.nombre_distribuidor_alta_ds  
where (UPPER(TRIM(s.marca_cartera_ds)) = "CAPTACION")
and not exists(
  select 1
  from `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS_BAJA_PREVIA` bp
  where bp.hasta=HASTA_1M
  and bp.marca_ds=s.marca_ds
  and bp.cliente_id=s.cliente_id
  and bp.categoria_servicio_ds=s.categoria_servicio_ds
  and bp.servicio_id=s.servicio_id
)
and not exists(
  select 1
  from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` h
  where h.mes_Comision_id=vmes_comision_id_1m
  and h.marca_ds=s.marca_ds
  and h.cliente_id=s.cliente_id
  and h.categoria_servicio_ds=s.categoria_servicio_ds
  and h.servicio_id=s.servicio_id
)and exists(
  select 1
  from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` h
  where h.mes_Comision_id=vmes_comision_id_1m
  and h.marca_ds=s.marca_ds
  and h.canal_alta_ds=s.canal_alta_ds
  and h.subcanal_ds=s.subcanal_ds
  and h.nombre_distribuidor_alta_ds=s.nombre_distribuidor_alta_ds
  and h.marca_cartera_ds=s.marca_cartera_ds
)
and s.servicio_id is not null
order by s.marca_ds,s.cliente_id, s.categoria_servicio_ds;

END