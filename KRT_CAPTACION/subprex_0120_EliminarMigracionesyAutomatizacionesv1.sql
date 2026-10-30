BEGIN

  ---DECLARE DESDE;HASTE IT64;SET DESDE=20230501;SET HASTA=20230531;

--- PASO 1: Borrar comisiones de agente migracion


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


--- PASO 2: Borrar comisiones de agente automatizacion

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_AUTOMATIZACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where agente_creador_id='TASCA';


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



  --- PASO 3: Borrar comisiones de proceso tasca
 

  --DECLARE DESDE,HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_PRODUCTOS_PROCESO_AUTOMATIZACION`  AS
  SELECT c.esES, p.swInstProdId, p.swParentInstProdId, p.swProdReleaseId, ct.swReleaseName,ct.swProductType,ct.swLineName,ct.swLineType
  FROM`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`p 
  inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_codigos` c on p.swPdteArpa=c.Orden AND c.TipoCodigo='ProcesoOrigen'
  left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` ct ON p.swProdReleaseId = ct.swProdReleaseId  
  where contains_substr(c.esES,'Tasca')
  and CAST(FORMAT_DATE("%Y%m%d",p.swDateInstalled) as integer) BETWEEN DESDE AND HASTA;

 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_PROCESO_AUTOMATIZACION`  AS
  SELECT *
  FROM  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_PRODUCTOS_PROCESO_AUTOMATIZACION` t
    where t.swInstProdId=v.servicio_id
  ) and v.marca_ds in ("EUSKALTEL", "VIRGIN","RACC");


  DELETE
  FROM  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_PROCESO_AUTOMATIZACION` t
    where t.servicio_id=v.servicio_id
  ) and v.marca_ds in ("EUSKALTEL", "VIRGIN","RACC");


--- PASO 4: Generar logs


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_CAPTACION` AS
  SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_AGENTE_MIGRACION`  AS
  SELECT * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0120_VENTAS_AGENTE_AUTOMATIZACION`  AS
  SELECT * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_AUTOMATIZACION`; 


END