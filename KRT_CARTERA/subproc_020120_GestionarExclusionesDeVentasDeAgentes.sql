BEGIN

  --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;
  --CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_MARCO_RETRIBUTIVO_TIENDASxCANAL`;  


  --- PASO 1: Identificar activaciones de agentes a excluir 

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020220_UNITARIOS_AGENTE_EXCLUIR`  AS 
	SELECT * 
	from `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` e
	where exists (
		--select 1 from  `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_VENTAS_EXCLUIR_AGENTE`  x
		select 1 from  `mm-commissions-reporting.KRT_CARTERA.PARAM_EXCLUSION_AGENTE_VENTAS`  x
		where x.marca_ds= e.marca_ds 
		and CASE when TRIM(UPPER(x.canal))="X" or TRIM(UPPER(x.canal))=TRIM(UPPER(e.canal)) THEN TRUE ELSE FALSE END
		and CASE when TRIM(UPPER(x.subcanal))="X" or TRIM(UPPER(x.subcanal))=TRIM(UPPER(e.subcanal)) THEN TRUE ELSE FALSE END    
		and CASE when TRIM(UPPER(x.marco_retributivo))="X" or TRIM(UPPER(x.marco_retributivo))=TRIM(UPPER(e.marco_retributivo)) THEN TRUE ELSE FALSE END        
		and CASE when TRIM(UPPER(x.agente))="X" or TRIM(UPPER(x.agente))=TRIM(UPPER(e.agente)) THEN TRUE ELSE FALSE END        
		and UPPER(TRIM(x.agente_creador_id))=UPPER(TRIM(e.agente_creador_id))
  );

  --- PASO 1: Borrar activaciones de agentes a excluir 
	DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` e
	where exists (
    select 1 from `mm-commissions-reporting.KRT_CARTERA.LOG_020220_UNITARIOS_AGENTE_EXCLUIR` x
    where x.marca_ds= e.marca_ds 
	  and x.idFijo=e.idFijo   	
	  and x.idProducto=e.idProducto   
  );

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020220_UNITARIOS_CARTERA`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` e;


END