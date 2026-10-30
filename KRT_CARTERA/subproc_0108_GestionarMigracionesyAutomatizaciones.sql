BEGIN

  --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;
  --CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA`;  


  --- PASO 1: Identificar comisiones de agente migración masiva

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_MIGRACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` 
  where CONTAINS_SUBSTR(agente_creador_id,'MIGR')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIG_')
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

  --- PASO 1.1: Borrar comisiones de agente migración masiva

  DELETE
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_MIGRACION` b
    where b.marca_ds=v.marca_ds
    and b.idFijo=v.idFijo
    and b.idProducto=v.idProducto
    and b.agente_creador_id=v.agente_creador_id
  );


  --- PASO 2: Identificar comisiones de agente automatización de procesos usuario - producto
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_AUTOMATIZACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` 
  where agente_creador_id='TASCA';

  --- PASO 2.1: Borrar comisiones de agente automatización
  DELETE
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_AUTOMATIZACION` b
    where b.marca_ds=v.marca_ds
    and b.idFijo=v.idFijo
    and b.idProducto=v.idProducto
    and b.agente_creador_id=v.agente_creador_id
  );


  --- PASO 3: Identificar eventos de proceso tasca
  --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_PRODUCTOS_PROCESO_AUTOMATIZACION`  AS
  SELECT c.esES, p.swInstProdId, p.swParentInstProdId, p.swProdReleaseId, ct.swReleaseName,ct.swProductType,ct.swLineName,ct.swLineType
  FROM`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`p 
  inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_codigos` c on p.swPdteArpa=c.Orden AND c.TipoCodigo='ProcesoOrigen'
  left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` ct ON p.swProdReleaseId = ct.swProdReleaseId  
  where contains_substr(c.esES,'Tasca')
  and CAST(FORMAT_DATE("%Y%m%d",p.swDateInstalled) as integer) BETWEEN DESDE AND HASTA;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_PROCESO_AUTOMATIZACION`  AS
  SELECT *
  FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ev
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_PRODUCTOS_PROCESO_AUTOMATIZACION` t
    where t.swInstProdId=ev.idproducto
  ) and ev.marca_ds in ("EUSKALTEL", "VIRGIN","RACC");


  --- PASO 3.1: Borrar eventos de proceso tasca
  DELETE
  FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ev
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_PROCESO_AUTOMATIZACION` t
    where t.idProducto=ev.idProducto 
  ) and ev.marca_ds in ("EUSKALTEL", "VIRGIN","RACC");


  --SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_MIGRACION` 
  --SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_AUTOMATIZACION`
  --SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0108_PRODUCTOS_PROCESO_AUTOMATIZACION`;
  --SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_PROCESO_AUTOMATIZACION`;

  --- PASO 4: Crear tabla con registro de todos los eventos eliminados

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_EXCLUIDOS` AS 
  select "MIGRACION" as tipo, * from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_MIGRACION`
  UNION ALL
  select "AUTOMATIZACION" as tipo, * from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_PROCESO_AUTOMATIZACION`;


  --- PASO 6: Identificar comisiones de alta + migración por agente de migración masiva

    --- Accedo a producto origen y verifico fecha 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_ALTA_MAS_MIGRACION`  AS 
  select ev.*
  from `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_AGENTE_MIGRACION` ev
  inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on p.swInstProdId=ev.idProductoOrigen
  inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` pmig on pmig.swInstProdId=ev.idProducto
  where (p.swProdOrigId IS NULL 
            OR EXISTS (SELECT 1 FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p2
                       WHERE p2.swInstProdId = p.swMasterInstProdId 
                       and (EXTRACT(YEAR FROM p2.swDateInstalled)*10000 + EXTRACT(MONTH FROM p2.swDateInstalled) * 100 + EXTRACT(DAY FROM p2.swDateInstalled)) BETWEEN desde AND hasta                       )
          )
      --and cand.fecha_rfb_id>=desde
      --and cand.fecha_rfb_id<=hasta
  and (EXTRACT(YEAR FROM p.swDateInstalled)*10000 + EXTRACT(MONTH FROM p.swDateInstalled) * 100 + EXTRACT(DAY FROM p.swDateInstalled))  BETWEEN desde AND hasta
  AND (pmig.swFechaDesinstalacion IS NULL OR ( (EXTRACT(YEAR FROM pmig.swFechaDesinstalacion)*10000 + EXTRACT(MONTH FROM pmig.swFechaDesinstalacion) * 100 + EXTRACT(DAY FROM pmig.swFechaDesinstalacion))>hasta));


--- PASO 7: Inserto evento de alta + migración por agente de migración masiva
  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_ALTA_MAS_MIGRACION`; 

 
  
  --- PASO 8: Eventos  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0108_EVENTOS_CARTERA`
  AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


END