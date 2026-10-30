BEGIN

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050115_AUDIT_PENALIZACIONES_CONTEXTUAL_VS_DATAMARK_KD` AS
	with p_sc_nk as (
	  --- Penalizaciones que existen en contextual y no existen en datamarkd
	  --		Existen cuando la lógica se aplica sobre los mensajes de portabilidad registrados en contextual, 
	  --		No existen cuando la lógica se aplica sobre los mesajes de portabilida registrados en datamarkd	
	  SELECT distinct c.* FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_CONTEXTUAL_VS_PORTABILIDAD_EKNET` c
	  --left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_CONTEXTUAL` v on v.marca_ds=c.marca_ds and v.cliente_id=c.cliente_id and v.servicio_id=c.servicio_id and v.CONCEPTO_DS=c.concepto_ds
	  WHERE NOT EXISTS (
	    select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_DATAMARK_KD_VS_PORTABILIDAD_EKNET` k
	    where k.marca_ds=c.marca_ds and k.servicio_id=c.servicio_id and k.CONCEPTO_DS=c.concepto_ds 
	  )
	  order by c.marca_ds, c.cliente_id,c.servicio_id, c.concepto_ds 
	) 

	--- Penalizaciones registradas en contextual (ya enriquecidas con datos de portabilidad regisrtados en ektnet), enriquecidas con:
	---		Datos importados de las ventas cruzadas con portabilidades registradas en contextual
	---			Ani asociado al servicio 
	---			Caracterizacion de los datos de portabilidad registrados en contextual (Tipo de portabilidad, identificativo u nombre del operador donante ), del servicio que se comisiona
	---		Población de penalizaciones que existen segun portabilidades de contextual y no existen según portabilidades de datamarkd.
	--			bCoincide: Variable booleana que registra si una penalización existe segun portabilidades de contextual y datamarkd

	select distinct c.*, 
	vctx.ani_serv as ANI_SERV_CTX, 
	coalesce(vctx.OPERADOR_FIJO_ID,vctx.OPERADOR_MOVIL_ID) as OPERADOR_ID_CTX, 
	coalesce(vctx.OPERADOR_DONANTE_FIJO ,vctx.OPERADOR_DONANTE_MOVIL) as OPERADOR_DONANTE_CTX,
	coalesce(vctx.TIPO_PORTABILIDAD_FIJO, vctx.TIPO_PORTABILIDAD_MOVIL) as TIPO_PORTABILIDAD_CTX,	
	vctx.fecha_ventana_cambio_id as FECHA_VENTANA_CAMBIO_ID_CTX,
	case when CAST(coalesce(vctx.OPERADOR_FIJO_ID,vctx.OPERADOR_MOVIL_ID) AS INT64)=c.COD_OPERADOR_DONANTE_EKTNET THEN 1 ELSE 0 END AS B_CRUCE_OPERADOR_DONANTE_CTX_EKTNET,	
	vkd.ani_serv as ANI_SERV_KD,
	coalesce(vkd.OPERADOR_FIJO_ID,vkd.OPERADOR_MOVIL_ID) as OPERADOR_ID_KD, 
	coalesce(vkd.OPERADOR_DONANTE_FIJO ,vkd.OPERADOR_DONANTE_MOVIL) as OPERADOR_DONANTE_KD,
	coalesce(vkd.TIPO_PORTABILIDAD_FIJO, vkd.TIPO_PORTABILIDAD_MOVIL) as TIPO_PORTABILIDAD_KD,
	vkd.fecha_ventana_cambio_id  as FECHA_VENTANA_CAMBIO_ID_KD,		
	case when CAST(coalesce(vkd.OPERADOR_FIJO_ID,vkd.OPERADOR_MOVIL_ID) AS INT64)=c.COD_OPERADOR_DONANTE_EKTNET THEN 1 ELSE 0 END AS B_CRUCE_OPERADOR_DONANTE_KD_EKTNET,	
	case when k.servicio_id is not null then "SI_CTX_NO_KD" else "SI_CTX_SI_KD" end as CRUCE_PENALIZACION_CTX_KD,
	case when c.FECHA_VENTANA_CAMBIO_EKTNET is null then 0 else 1 end as BFVC_EKTNET_NOT_NULL,
	case when vctx.fecha_ventana_cambio_id is null then 0 else 1 end as BFVC_CTX_NOT_NULL,	
	case when vkd.fecha_ventana_cambio_id is null then 0 else 1 end as BFVC_KD_NOT_NULL,	
	from  `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_CONTEXTUAL_VS_PORTABILIDAD_EKNET` c
	left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_CONTEXTUAL` vctx on vctx.marca_ds=c.marca_ds and vctx.servicio_id=c.servicio_id --and v.CONCEPTO_DS=c.concepto_ds
	left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` vkd on vkd.marca_ds=c.marca_ds and vkd.servicio_id=c.servicio_id --and v.CONCEPTO_DS=k.concepto_ds	
	left join  p_sc_nk k on  k.marca_ds=c.marca_ds and k.servicio_id=c.servicio_id and k.CONCEPTO_DS=c.concepto_ds 
	order by c.marca_ds, c.cliente_id,c.servicio_id, c.concepto_ds; 


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050115_AUDIT_PENALIZACIONES_DATAMARK_KD_VS_CONTEXTUAL` AS
	with p_sk_nc as (
	  SELECT distinct k.* FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_DATAMARK_KD_VS_PORTABILIDAD_EKNET` k
	  --left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` v on v.marca_ds=k.marca_ds and v.cliente_id=k.cliente_id and v.servicio_id=k.servicio_id and v.CONCEPTO_DS=k.concepto_ds  
	  WHERE NOT EXISTS (
	    select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_CONTEXTUAL_VS_PORTABILIDAD_EKNET` c
	    where k.marca_ds=c.marca_ds and k.servicio_id=c.servicio_id and k.CONCEPTO_DS=c.concepto_ds 
	  )
	  order by k.marca_ds, k.cliente_id, k.servicio_id, k.concepto_ds 
	) select k.*, 
	vctx.ani_serv as ANI_SERV_CTX, 	
	coalesce(vctx.OPERADOR_FIJO_ID,vctx.OPERADOR_MOVIL_ID) as OPERADOR_ID_CTX, 
	coalesce(vctx.OPERADOR_DONANTE_FIJO ,vctx.OPERADOR_DONANTE_MOVIL) as OPERADOR_DONANTE_CTX,
	coalesce(vctx.TIPO_PORTABILIDAD_FIJO, vctx.TIPO_PORTABILIDAD_MOVIL) as TIPO_PORTABILIDAD_CTX,
	vctx.fecha_ventana_cambio_id as FECHA_VENTANA_CAMBIO_ID_CTX,
	case when CAST(coalesce(vctx.OPERADOR_FIJO_ID,vctx.OPERADOR_MOVIL_ID) AS INT64)=k.COD_OPERADOR_DONANTE_EKTNET THEN 1 ELSE 0 END AS B_CRUCE_OPERADOR_DONANTE_CTX_EKTNET,	
	vkd.ani_serv as ANIN_SERV_KD,
	coalesce(vkd.OPERADOR_FIJO_ID,vkd.OPERADOR_MOVIL_ID) as OPERADOR_ID_KD, 
	coalesce(vkd.OPERADOR_DONANTE_FIJO ,vkd.OPERADOR_DONANTE_MOVIL) as OPERADOR_DONANTE_KD,
	coalesce(vkd.TIPO_PORTABILIDAD_FIJO, vkd.TIPO_PORTABILIDAD_MOVIL) as TIPO_PORTABILIDAD_KD,
	vkd.fecha_ventana_cambio_id  as FECHA_VENTANA_CAMBIO_ID_KD,		
	case when CAST(coalesce(vkd.OPERADOR_FIJO_ID,vkd.OPERADOR_MOVIL_ID) AS INT64)=k.COD_OPERADOR_DONANTE_EKTNET THEN 1 ELSE 0 END AS B_CRUCE_OPERADOR_DONANTE_KD_EKTNET,	
	case when c.servicio_id is not null then "NO_CTX_SI_KD" else "SI_CTX_SI_KD" end as CRUCE_PENALIZACION_CTX_KD,	
	case when k.FECHA_VENTANA_CAMBIO_EKTNET is null then 0 else 1 end as BFVC_EKTNET_NOT_NULL,
	case when vctx.fecha_ventana_cambio_id is null then 0 else 1 end as BFVC_CTX_NOT_NULL,	
	case when vkd.fecha_ventana_cambio_id is null then 0 else 1 end as BFVC_KD_NOT_NULL,	
	from  `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_DATAMARK_KD_VS_PORTABILIDAD_EKNET` k
	left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_CONTEXTUAL` vctx on vctx.marca_ds=k.marca_ds and vctx.servicio_id=k.servicio_id --and v.CONCEPTO_DS=c.concepto_ds	
	left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` vkd on vkd.marca_ds=k.marca_ds and vkd.servicio_id=k.servicio_id --and v.CONCEPTO_DS=k.concepto_ds
	left join  p_sk_nc c on  k.marca_ds=c.marca_ds and k.servicio_id=c.servicio_id and k.CONCEPTO_DS=c.concepto_ds 
	order by k.marca_ds, k.cliente_id,k.servicio_id, k.concepto_ds; 

END