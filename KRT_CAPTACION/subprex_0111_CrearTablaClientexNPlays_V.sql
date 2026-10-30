BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` AS
  SELECT marca_ds, cliente_id,coalesce(count(distinct desc_mm),0 ) as NPLAYS, NULL as NPLAYS_PBA 
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where (clase_mm='A - Servicio base' or (clase_mm='B - SVA' and desc_mm='B - Television acceso')) 
  group by 1,2;
  
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` cv
  SET cv.NPLAYS_PBA=c.NPLAYS_PBA
  FROM (
    with cba as (
      SELECT distinct marca_ds, cliente_id
      FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  
      WHERE categoria_servicio_ds='BANDA ANCHA'
    ) select cba.marca_ds, cba.cliente_id,
    coalesce(count(distinct v.desc_mm),0 ) as NPLAYS_PBA  
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 
    inner join cba
    on v.marca_ds=cba.marca_ds and v.cliente_id=cba.cliente_id 
    where (v.clase_mm='A - Servicio base' or (v.clase_mm='B - SVA' and v.desc_mm='B - Television acceso'))
    group by 1,2
    order by 1 asc, 3 desc
  ) as c
  where cv.marca_ds=c.marca_ds and cv.cliente_id=c.cliente_id; 


    
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` AS
  SELECT marca_ds, cliente_id,
  case when TRIM(marca_ds)!='R' THEN CAST(pedido_id AS STRING) ELSE expediente_padre_id END pedido_id,
  coalesce(count(distinct desc_mm),0 ) as NPLAYS, NULL as NPLAYS_PBA  
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where (clase_mm='A - Servicio base' or (clase_mm='B - SVA' and desc_mm='B - Television acceso')) 
  group by 1,2,3
  order by 1 asc, 4 desc;

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` pv
  SET pv.NPLAYS_PBA=p.NPLAYS_PBA
  FROM (
    with pba as (
      SELECT distinct marca_ds, cliente_id, case when TRIM(marca_ds)!='R' THEN CAST(pedido_id AS STRING) ELSE expediente_padre_id END pedido_id,
      FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  
      WHERE categoria_servicio_ds='BANDA ANCHA'
    ) select pba.marca_ds, pba.cliente_id,
    pba.pedido_id,
    coalesce(count(distinct v.desc_mm),0 ) as NPLAYS_PBA  
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 
    inner join pba
    on v.marca_ds=pba.marca_ds and v.cliente_id=pba.cliente_id and (CAST(v.pedido_id AS STRING)=pba.pedido_id or expediente_padre_id=pba.pedido_id)
    where (v.clase_mm='A - Servicio base' or (v.clase_mm='B - SVA' and v.desc_mm='B - Television acceso'))
    group by 1,2,3
    order by 1 asc, 4 desc
  ) as p
  where pv.marca_ds=p.marca_ds and pv.cliente_id=p.cliente_id and pv.pedido_id=p.pedido_id; 

END