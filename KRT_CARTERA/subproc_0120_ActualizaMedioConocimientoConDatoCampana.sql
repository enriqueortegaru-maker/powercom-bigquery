BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0120_EVENTOS_CARTERA_CON CAMPANA_EKTNET_TCNET` AS
  Select e.marca_Ds, e.idFijo, c.NOMBRE_CAMPANA,fecha_Activacion,fecha_inicio_dt, DATE_DIFF(fecha_Creacion,fecha_inicio_dt, DAY) as ndias_crea, DATE_DIFF(fecha_Activacion,fecha_inicio_dt, DAY) as ndias_act  
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
  inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c on c.marca_ds=e.marca_ds and c.cliente_id=e.idFijo
  where e.canal="TELEVENTA"
  and e.fecha_creacion >= c.FECHA_INICIO_DT 
  --and e.fecha_activacion >= c.FECHA_INICIO_DT 
  --QUALIFY ROW_NUMBER() over(partition by e.marca_Ds, e.idFijo order by DATE_DIFF(fecha_Activacion,fecha_inicio_dt, DAY) asc )=1 
  QUALIFY ROW_NUMBER() over(partition by e.marca_Ds, e.idFijo order by DATE_DIFF(fecha_Creacion,fecha_inicio_dt, DAY) asc )=1; 

  update `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
  set e.medio_conocimiento=c.NOMBRE_CAMPANA
  From `mm-commissions-reporting.KRT_CARTERA.LOG_0120_EVENTOS_CARTERA_CON CAMPANA_EKTNET_TCNET`c
  where e.marca_ds=c.marca_ds
  and e.idFijo=c.idFijo
  and e.fecha_creacion >= c.FECHA_INICIO_DT; 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0120_EVENTOS_CARTERA`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e;
  

END