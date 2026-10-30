BEGIN

	---- PASO 1:IDENTIFICO POBLACION

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CARTERA.LOG_0107_EVENTOS_CARTERA_UPD` AS
	SELECT 
		a.*	
	FROM 
	  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` a
	INNER JOIN 
	  `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` c
	ON 
	  a.idFijo = c.cliente_id
	  AND UPPER(a.marca_Ds ) = c.marca_ds
	  AND CAST(c.desde_dt AS date) <= a.Fecha_Activacion
	  AND CAST(c.hasta_dt AS date) > a.Fecha_Activacion
	WHERE 	
	  tipomovimiento LIKE '%servicios móviles'
	  AND clasificacion_ds ='SOMO'; ----CORRECCION AÑADIDA


	---- PASO 2:ACTUALIZA CARACTERISTICA
	UPDATE
	  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` a
	SET
	  a.concepto_ds = CONCAT(a.concepto_ds, ' SOMO'),
	  a.concepto_origen_ds = CONCAT(a.concepto_origen_ds, ' SOMO')
	FROM
	  `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` c
	WHERE
	  a.idFijo = c.cliente_id
	  AND UPPER(a.marca_Ds ) = c.marca_ds
	  AND CAST(c.desde_dt AS date) <= a.Fecha_Activacion
	  AND CAST(c.hasta_dt AS date) > a.Fecha_Activacion
	  AND tipomovimiento LIKE '%servicios móviles'
	  AND clasificacion_ds ='SOMO'; ----CORRECCION AÑADIDA


	---- PASO 3:GENERO LOG

	  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0107_EVENTOS_CARTERA` AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  END