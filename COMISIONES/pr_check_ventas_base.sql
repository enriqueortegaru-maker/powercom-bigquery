begin
--call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`(false);
declare meses array<string>;

set meses = (select split(valor) from `mm-commissions-reporting.GS.PARAMETROS` where parametro = 'meses_validacion_tarifas');

if actualizar_activaciones then

FOR mes_for IN (SELECT cast(m as int64) mes FROM UNNEST(meses) m)
DO
  call `mm-commissions-reporting.COMISIONES.pr_activaciones`(mes_for.mes);
END FOR;

end if;

create or replace table `mm-commissions-reporting.COMISIONES.check_ventas_base` as

with

ventas as
(
  select *,
  upper(comisionamiento) like 'COMISIONA%' as comisiona_venta
  from `mm-commissions-reporting.COMISIONES.activaciones`
  where id_mes IN (SELECT cast(m as int64) mes FROM UNNEST(meses) m)
  and order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC','CAMBIO DOMICILIO','CAMBIO TECNOLOGIA')
),


comisiones as
(
  select *, true as comisionado
  from `mm-commissions-reporting.COMISIONES.transacciones`
  where id_mes IN (SELECT cast(m as int64) mes FROM UNNEST(meses) m)
  and concepto in ('A - Servicio Fijo','A - Servicio Fijo 2da Vivienda','A - Servicio Movil Pospago','A - Servicio Movil Prepago','A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia')
  and comision > 0

)

SELECT
  a.id_mes,
  a.marca,
  a.service_id,
  a.service_type,
  b.concepto,
  case 
    when not a.comisiona_venta and b.comisionado is null then comisionamiento
    when not a.comisiona_venta and b.comisionado then 'No comisiona - Comisionado'
    when a.canal is null then 'No Cruza Dealer' 
    when b.comisionado then 'Comisiona - OK'
    when c.tramo_1 is null then 'Comisiona - Tarifa no creada'
    when c.tramo_1 = 0 then 'Comisiona - Tarifa importe 0'
    when e.plantilla_activaciones = 'Con tramos' and d.marca is null then 'Comisiona - Tramo no creado'
    when a.order_type_agg = 'CAMBIO DOMICILIO' and c.traslados = 0 then 'Comisiona - Traslado importe 0'
    when a.order_type_agg = 'CAMBIO TECNOLOGIA' and c.migraciones = 0 then 'Comisiona - Migracion importe 0'
  else 'Comisiona - no calculado' end as comisionamiento,
  
  case  when upper(comisionamiento) like 'COMISIONA%' then 1
        when upper(comisionamiento) like 'NO COMISIONA%' then 0
        when b.unidades = 1 then 1
        else 0 end as comisiona,
        
  coalesce ( a.agrupacion_canal, a.agrupacion_canal_ventas_base ) as agrupacion_canal,
  a.canal,
  coalesce ( b.unidades , 0) as comisionado,
  a.tariff_id,
  a.tariff_ds,
  a.sfid_id,
  a.seller,
  a.order_type_agg,
FROM ventas a
FULL OUTER JOIN comisiones b
USING
  (id_mes,
  marca,
    service_id,
    service_type,
id_mes)
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas` c on
a.canal = c.canal 
and a.id_mes=c.id_mes
and a.marca=c.marca
and a.service_type=c.service_type
and a.tariff_id=c.tariff_id
and case when a.service_type = 'MOBILE' then a.line_type_ds else 'FIX' end = case when c.service_type = 'MOBILE' then c.line_type_ds else 'FIX' end
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` d on a.id_mes=cast(d.mes as int64) and a.marca=d.marca and a.canal=d.canal and a.id_comisionista = d.id_comisionista
left join `mm-commissions-reporting.GS.CANALES` e on a.canal = e.canal
;

  end