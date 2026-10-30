BEGIN

----- PASO 1: INFORMAR CODIGOS SAP NO REGISTRADOS

	---- COMISIONES

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_TERMINALES_ASIGNADOS_POR_CANAL_UPD` AS
	SELECT c.*
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL` p 
	on c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="TERMINAL" 
	and (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end
	and c.orden_sap is null;
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_SERVICIOS_ASIGNADOS_POR_CANAL_UPD` AS
	SELECT c.*
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL` p 
	on c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="SERVICIO"  
	and not (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end
	and c.orden_sap is null;
	


	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	SET c.orden_sap=p.orden_sap  
	FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL` p 
	where c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="TERMINAL" 
	and (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end
	and c.orden_sap is null;

	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	SET c.orden_sap=p.orden_sap  
	FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_POR_CANAL` p 
	where c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="SERVICIO"  
	and not (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end
	and c.orden_sap is null;


	---- COMISIONES_LISTADO

----- PASO 2: ACTUALIZAR LA ORDEN SAP DE VENTAS EN MARCO RETRIBUTIVO TLT UPS DE TELECABLE SIN ORDEN SAP INFORMADA

	--- COMISIONES

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_TERMINALES_ASIGNADOS_POR_MR_TVT_UPS_UPD` AS  
	SELECT c.* 
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS` p
	on  c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="SERVICIO" 
	--and not contains_substr(tipoMovimiento,"equipamiento m") then true else false end
	and not (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end

	and c.orden_sap is null;		

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_SERVICIOS_ASIGNADOS_POR_MR_TVT_UPS_UPD` AS  
	SELECT c.*
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS` p 
	on c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="TERMINAL" 
	--and contains_substr(tipoMovimiento,"equipamiento m") then true else false end
	and (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end	
	and c.orden_sap is null;



	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	SET c.orden_sap=p.orden_sap  
	FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS` p 
	where c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="SERVICIO" 
	--and not contains_substr(tipoMovimiento,"equipamiento m") then true else false end
	and not (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end
	and c.orden_sap is null;


	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	SET c.orden_sap=p.orden_sap  
	FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_ASIGNACION_ORDEN_SAP_MR_TVT_UPS` p 
	where c.marca_ds=p.marca_ds and c.canal=p.canal 
	and case when p.subcanal="X" then true else c.subcanal=p.subcanal end  
	and case when p.marco_retributivo="X" then true else c.marco_retributivo=p.marco_retributivo end 
	and case when p.tipo="TERMINAL" 
	--and contains_substr(tipoMovimiento,"equipamiento m") then true else false end
	and (contains_substr(tipoMovimiento,"equipamiento m")   
				or contains_Substr(c.tipoMovimiento,'terminal')  
				or contains_Substr(c.tipoMovimiento,'dispositivo') 
				or contains_Substr(c.clase_mm,'T - ') 
				or contains_Substr(c.desc_mm,'T - ') 
	) then true else false end
	and c.orden_sap is null;


  ---- COMISIONES_LISTADO 
	---- DECOMISIONES
	---- DECOMISIONES_HISTORICO
  ---- CARTERA_HISTORICO



  ----- PASO 3: COREGIR ASIGNACION DE CODIGOS SAP INDEPENDIENTES DE CANAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0407_COMISIONES_ASIGNADOS_POR_DESC_MM` AS  
  SELECT c.* 
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
	on c.marca_ds=p.marca_ds 
	and c.desc_mm=p.desc_mm 
	and case when p.segmento_ds="X" then true else c.segmento=p.segmento_ds end;



	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
	SET c.orden_sap=p.orden_sap  
	FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
	where c.marca_ds=p.marca_ds 
	and c.desc_mm=p.desc_mm 
	and case when p.segmento_ds="X" then true else c.segmento=p.segmento_ds end;

	----- ACTUALIZACION DE HISTORICOS

  ---- COMISIONES_LISTADO 
	---- DECOMISIONES
	---- DECOMISIONES_HISTORICO
  ---- CARTERA_HISTORICO

END