BEGIN

  --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;
  --CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA`;  


  --- PASO 1: Identificar comisiones de agente migración masiva

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0109_EVENTOS_AGENTE_EXCLUIDO`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
  where exists (
    select 1 from  `mm-commissions-reporting.KRT_CARTERA.PARAM_EXCLUSION_AGENTE_VENTAS`  x
    where x.marca_ds= e.marca_ds and UPPER(TRIM(x.agente_creador_id))=UPPER(TRIM(e.agente_creador_id))
  );
  
  DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
  where exists (
    select 1 from  `mm-commissions-reporting.KRT_CARTERA.PARAM_EXCLUSION_AGENTE_VENTAS`  x
    where x.marca_ds= e.marca_ds and UPPER(TRIM(x.agente_creador_id))=UPPER(TRIM(e.agente_creador_id))   
  );


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0109_EVENTOS_CARTERA`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e;
  

END