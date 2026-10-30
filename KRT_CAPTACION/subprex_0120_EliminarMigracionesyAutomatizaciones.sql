BEGIN


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where CONTAINS_SUBSTR(agente_creador_id,'MIGR')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIG_')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIG ')
  --OR STARTS_WITH(TRIM(UPPER(agente_creador_id)),'MIG ')
  --OR CONTAINS_SUBSTR(agente_creador_id,'MIGR')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGTV')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGFT')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGBA')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGTF')
  OR  CONTAINS_SUBSTR(agente_creador_id,'REPO')
  OR  CONTAINS_SUBSTR(agente_creador_id,'MASIV')
  OR ENDS_WITH(agente_creador_id,'MIG')
  OR ENDS_WITH(agente_creador_id,'MIG1');



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_AUTOMATIZACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where agente_creador_id='TASCA';



  DELETE
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION` b
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
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_AUTOMATIZACION` b
    where b.marca_ds=v.marca_ds
    and b.cliente_id=v.cliente_id
    and b.categoria_servicio_ds=v.categoria_servicio_ds
    and b.servicio_id=v.servicio_id
    and b.agente_creador_id=v.agente_creador_id
  );


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_CAPTACION` AS
  SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_AGENTE_MIGRACION`  AS
  SELECT * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_AGENTE_AUTOMATIZACION`  AS
  SELECT * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_AUTOMATIZACION`; 


END