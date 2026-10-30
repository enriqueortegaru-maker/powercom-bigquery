BEGIN

 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_AGENTE_MIGRACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where CONTAINS_SUBSTR(agente_creador_id,'MIG_')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIG ')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGR')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGTV')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGFT')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGBA')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGTF')
  OR  CONTAINS_SUBSTR(agente_creador_id,'REPO')
  OR  CONTAINS_SUBSTR(agente_creador_id,'MASIV')
  OR ENDS_WITH(agente_creador_id,'MIG')
  OR ENDS_WITH(agente_creador_id,'MIG1');



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_AGENTE_AUTOMATIZACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where agente_creador_id='TASCA';

  --- AÑADIDO

 --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_PRODUCTOS_PROCESO_AUTOMATIZACION`  AS
  SELECT c.esES, p.swInstProdId, p.swParentInstProdId
  FROM`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`p 
  inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_codigos` c
  on p.swPdteArpa=c.Orden AND c.TipoCodigo='ProcesoOrigen'
  where contains_substr(c.esES,'Tasca')
  and CAST(FORMAT_DATE("%Y%m%d",p.swDateInstalled) as integer) BETWEEN DESDE AND HASTA;
 

 CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_PROCESO_AUTOMATIZACION`  AS
 select v.*  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
 where exists(
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_PRODUCTOS_PROCESO_AUTOMATIZACION` p
    --where p.swParentInstProdId=v.servicio_id
    where (p.swInstProdId=v.servicio_id)
 ) UNION ALL
  select v.*  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
 where exists(
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_PRODUCTOS_PROCESO_AUTOMATIZACION` p
    --where p.swParentInstProdId=v.servicio_id
    where (p.swParentInstProdId=v.servicio_id)
 );


  ------- FIN AÑADIDO


  DELETE
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_AGENTE_MIGRACION` b
    where b.marca_ds=v.marca_ds
    and b.cliente_id=v.cliente_id
    and b.categoria_servicio_ds=v.categoria_servicio_ds
    and b.servicio_id=v.servicio_id
    and b.agente_creador_id=v.agente_creador_id
  );


  DELETE
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_AGENTE_AUTOMATIZACION` b
    where b.marca_ds=v.marca_ds
    and b.cliente_id=v.cliente_id
    and b.categoria_servicio_ds=v.categoria_servicio_ds
    and b.servicio_id=v.servicio_id
    and b.agente_creador_id=v.agente_creador_id
  );

  --- AÑADIDO
  DELETE
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_PROCESO_AUTOMATIZACION` b
    where b.marca_ds=v.marca_ds
    and b.cliente_id=v.cliente_id
    and b.categoria_servicio_ds=v.categoria_servicio_ds
    and b.servicio_id=v.servicio_id
    and b.agente_creador_id=v.agente_creador_id
  );

  --- FIN AÑADIDO



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_CAPTACION`
  AS SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;

END