BEGIN


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_MIGRACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
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



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_AGENTE_AUTOMATIZACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
  where agente_creador_id='TASCA';



  DELETE
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_MIGRACION` b
    where b.marca_ds=v.marca_ds
    and b.idFijo=v.idFijo
    and b.idProducto=v.idProducto
    and b.agente_creador_id=v.agente_creador_id
  );


  DELETE
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_AGENTE_AUTOMATIZACION` b
    where b.marca_ds=v.marca_ds
    and b.idFijo=v.idFijo
    and b.idProducto=v.idProducto
    and b.agente_creador_id=v.agente_creador_id
  );


  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
  --AS SELECT * except (agente_creador_id) FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES`
  AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;


END