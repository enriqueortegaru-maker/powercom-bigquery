BEGIN

 	  -- CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecablev11`(20260501,20260531);

	  DECLARE DESDE_DT, HASTA_DT date; 
	  -- LOCAL
	  --DECLARE DESDE,HASTA INT64;SET DESDE=20250201;SET HASTA=20250228;
	  SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );SET  DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) ); 


	-- =========================================================
	-- CTE 1: Terminales y Equipamientos Activos y Migrados
	-- =========================================================


	  --- PASO 1: CREO TABLA LOG_0102_TERMINALES_CARTERA_EKTNET
	  	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_TERMINALES_ACT_Y_MIG` 
	    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
			--- PARTE DEDICADA A TERMINALES Y EQUIPAMIENTOS
			SELECT -- distinct CASE mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' END mmMarcaDesc, 
			distinct CASE UPPER(TRIM(mmMarcaDesc)) WHEN 'EUSKALTEL' THEN 'EUSKALTEL' WHEN 'VIRGIN TELCO' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'TELECABLE' THEN 'TELECABLE' END mmMarcaDesc, 
			CAST(a.IdCatalogo AS STRING) CatalogoId, 
			a.NombreProducto, 
			a.des_canal_dis canal, 
			a.des_subcanal_dis subcanal, 
			a.des_distribuidor agente, 
			CAST( a.swCustomerId AS INT64) CLIENTE_ID, 
			CAST(a.swAntiguedad AS Date) ANTIGUEDAD, 
			a.swNIE, a.marcaCartera, 
			a.concepto_ds, 
			CAST(a.swDateInstalled AS Date) FECHA_aCTIVACION,
			CAST(a.swDateCreated AS Date) FECHA_CREACION, 
--- INSERTO FECHA DESINSTALACION					
			CAST(a.swFechaDesinstalacion AS Date) FECHA_DESINSTALACION,
--- FIN INSERCCION							
			TRIM(a.swSegmento) swSegmento, 
			a.swSegmento subsegmento, 
			CAST(a.idCatalogoOrigen AS STRING) CatalogoIdOrigen, 
			CAST(a.IdProductoOrigen AS INT64) ProductoIdOrigen, 
			a.NombreProductoOrigen, 
			a.TipoProductoOrigen, 
            a.subTipoProductoOrigen,
--- INSERTO CADENA ORIGEN
			a.MasterInstProdIdProductoOrigen,
			a.ProdOrigIdProductoOrigen,
			a.CopiaProdIdProductoOrigen,
--- FIN INSERCCION			

--- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN	
			a.FECHA_ACTIVACION_ORIGEN,
			a.FECHA_DESINSTALACION_ORIGEN,
--- FIN INSERCCION
            a.TipoMovimiento, 
            a.TipoProducto,
            a.subTipoProducto, 
			CAST(a.swInstProdId AS INT64) productoId, CAST(a.cod_contrato AS STRING) contrato, 
			usuarioCreador, 
			agente_creador_id, 
			canalId, 
			swCOInterno, 
			swName nombre_distribuidor, 
			filtroTerminales, 
			swInstProdIdOrigen, 
			swProdOrigId ProdOrigen, 
			swCausaBaja, 
			CAST(NULL AS STRING) concepto_origen_ds, 
			CAST(NULL AS STRING) medio_conocimiento,
			case when contains_substr(a.TipoProducto,"terminal") THEN "TERMINALES" 
				 when contains_substr(a.TipoProducto,"equipamiento") THEN "DISPOSITIVOS" 
				 when contains_substr(a.TipoProducto,"dispositivo") THEN "DISPOSITIVOS" 			
			END as origen,
			FROM ( 
		  
				  SELECT p.swProdReleaseId IdCatalogo, 

					---=====================================================================
					---- Se actualiza el nombre del catálogo con la denominación del modelo informado en la característica del producto en los catálogos del TipoProducto Terminal:
					----	Esto afecta s
					---- 		Los terminales 
					----		Los dispositivos que se instancian con catalogos de pago a plazos o sin subvencion qeu también utilizan los terminales, y que por ese motivo esos productos registran el tipoProducto "Terminal"
					----
					---=====================================================================

				  CASE WHEN (contains_substr(catalogo.TipoProducto,'terminal') )  THEN cc.swCaractValor ELSE p.swReleaseName END NombreProducto, 
			

					---=====================================================================
					---- Se actualiza el TipoProducto asociado al terminal, con el importado de de la parametrización "terminal" :
					----		Si la marca y modelo parametrizados coinciden con la del producto. 
					---- 		En caso contrario se mantiene la del catálogo 
					----
					---=====================================================================
				  CASE WHEN ct.modelo IS NOT NULL THEN ct.clase
							 ELSE catalogo.TipoProducto
				  END TipoProducto, 

					---=====================================================================
					---- Se actualiza el subTipoProducto asociado al terminal, con el importado de de la parametrización "terminal" :
					----		Si la marca y modelo parametrizados coincidan con la del producto. 
					---- 		En caso contrario se mantiene la del catálogo 
					----
					---=====================================================================

					CASE WHEN ct.modelo IS NOT NULL THEN ct.tipo
							 ELSE catalogo.tipo_movimiento
					END subTipoProducto, 
				  
				  -- catalogo.tipo_movimiento as subTipoProducto, 

				  cp.swInstProdId,
				  cp.swANI Imei,				  
				  cp.swDateInstalled, 
				  cp.swDateCreated, 
--- INSERTO FECHA DESINSTALACION					
				  cp.swFechaDesinstalacion,
--- FIN INSERCCION					

				  cp.swProdOrigId,
				  
				  				  
				  c1.canal_agrupado1_ds des_canal_dis, 
				  sc.subcanal_ds des_subcanal_dis, 
				  CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN pe.swNombre ELSE ca.swVerticalFocus END des_distribuidor, 
				  cicl.swCustomerId, cp.swMarcaCartera, cicl.swNIE, cicl.swAntiguedad, cp.swMarcaCartera marcaCartera, 
				  ct.modelo, 
				  CASE WHEN ct.modelo IS NOT NULL THEN ct.concepto_ds ELSE catalogo.concepto END concepto_ds, 
				  
				  TRIM(cl.swSegmento) swSegmento, NULL/*swSubsegmento,*/, 


				  pOrigen.swProdReleaseId idCatalogoOrigen, 			  
				  pOrigen.swReleaseName NombreProductoOrigen, 
				  cpOrigen.TipoProducto as TipoProductoOrigen, 
				  cpOrigen.tipo_movimiento as subTipoProductoOrigen,
				  cpOrigen.swInstProdId swInstProdIdOrigen,  				  
				  cpOrigen.swInstProdId IdProductoOrigen, 

--- INSERTO CADENA ORIGEN					
				  cpOrigen.swMasterInstProdId as MasterInstProdIdProductoOrigen,
				  cpOrigen.swProdOrigId as ProdOrigIdProductoOrigen,
				  cpOrigen.swCopiaProdId as CopiaProdIdProductoOrigen,
--- FIN INSERCCION					
--- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN	
				  CAST(cpOrigen.swDateInstalled AS Date) FECHA_ACTIVACION_ORIGEN, 				
				  CAST(cpOrigen.swFechaDesinstalacion as Date) FECHA_DESINSTALACION_ORIGEN,
--- FIN INSERCCION					



				  cpOrigen.swANI ImeiOrigen,
				  cpOrigen.swDateInstalled as swDateInstalledOrig, 
				  cpOrigen.swDateCreated as swDateCreatedOrig, 				  
				  cpOrigen.swProdOrigId as swProdOrigIdOrigen,				  
				  

					---=====================================================================
					---- Se actualiza el TipoMovimiento asociado al terminal, con el importado de de la parametrización "terminal" :				
					--- TipoMovimiento es ALTA SI:
					---		Catálogo tipificado como "TERMINAL" o "DISPOSITIVO"
					---		El producto instanciado es el primero de la cadena (el campo master del producto es nulo o lo que es lo mismo, el cpOrigen.swInstProdId es nulo)
					--- TipoMovimiento es CAMBIO:
					---		Resto de los casos
					---	Se concatena	
					---		Prefijo de operación
					--- 	Sufijo: 
					----		campo tipo de parametrizacion de terminal Si la marca y modelo parametrizados coinciden con el del producto. 
					---- 		campo tipo_movimiento del catálogo en caso contrario
					---
					---=====================================================================

				 -- CONCAT(CASE  WHEN cpOrigen.swInstProdId IS NULL OR UPPER(catalogo.TipoProducto) = 'TERMINAL' THEN 'Alta ' ELSE 'Cambio ' END , catalogo.tipo_movimiento) TipoMovimiento, 

   	 			  CONCAT(CASE WHEN cpOrigen.swInstProdId IS NULL 
									 OR contains_substr(catalogo.TipoProducto, 'TERMINAL') 
									 OR contains_substr(catalogo.TipoProducto, 'Dispositivo') 									 
								THEN 'Alta ' 
								ELSE 'Cambio ' 								
							END , 
							CASE WHEN ct.modelo IS NOT NULL THEN ct.tipo 
									 ELSE catalogo.tipo_movimiento
							END							
							) TipoMovimiento, 

				  
				  NULL cod_contrato, 
				  CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN cp.swCreatedBy ELSE pe.swNombre END usuarioCreador, 
				  cp.swCreatedBy as agente_creador_id, 
				  coOrigen2.swCausaBaja, 
				  CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS'THEN cp.swCreatedBy ELSE pe.swNombre END swCreatedBy, 
				  cl.mmMarcaId, 
				  ca.swChnlPartnerId canalId, 
				  ca.swCOInterno, 
				  ca.swVerticalFocus, 
				  ca.swChnlPartnerId, 
				  ca.swName, 
				  cpOrigen.filtroTerminales, 

				  FROM ( SELECT * 
						  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
							---================================================
							--- VERSION 10
							--- ELIMINO 
							--- WHERE DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT 
							--- INSERTO
							WHERE ((DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) OR (DATE_TRUNC(CAST (swDateCreated AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT))
							---================================================
						  --AND (swFechaDesinstalacion IS NULL  OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
				  ) cp 
				  INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat  AND sistema = 'EKTNET' AND UPPER(tipoProducto) IN ( 'TERMINAL','EQUIPAMIENTO','DISPOSITIVO') AND UPPER(catalogo.marca_ds) = 'TELECABLE' 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl ON cp.swCustomerId = cl.swCustomerId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc ON cp.swInstProdId = cc.swInstProdId AND cc.swCaractName = 'Modelo'
				  LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES` ct ON UPPER(cc.swCaractValor) = UPPER(ct.modelo) AND ct.marca_ds = 'TELECABLE' 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` p ON cp.swProdReleaseId = p.swProdReleaseId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca ON ca.swChnlPartnerId =cp.swChnlPartnerId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c ON c.canal_id = cp.swChnlPartnerId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON c.canal_agrupado1_id = c1.canal_agrupado1_id 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON c.canal_agrupado2_id = c2.canal_agrupado2_id 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON c.subcanal_id = sc.subcanal_id 
				  LEFT JOIN ( SELECT swCustomerId, MIN(swDateInstalled) FechaActivacion FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Activo' GROUP BY 1) pActivos ON pActivos.swCustomerId = cp.swCustomerId 
				  LEFT JOIN ( SELECT swCustomerId, MAX(swFechaDesinstalacion) fechaUltimaBaja FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Inactivo' GROUP BY 1) pInactivoson ON pInactivoson.swCustomerId = cp.swCustomerId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swPersonalId= cp.swProviderGrpId AND pe.swObjectType='CHANNEL_PARTNER' 
				  LEFT JOIN (  SELECT cp.*, catalogo.*, 
									CASE  WHEN (TipoProducto = 'terminal' AND DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) THEN 1  
									WHEN UPPER(TipoProducto) <> 'TERMINAL' AND DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < HASTA_DT THEN 1 ELSE 0 END filtroTerminales 
								FROM ( SELECT  * 
									  FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
									  WHERE  DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT
									   /*and DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < DESDE_DT*/
								) cp 
								INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl ON cp.swCustomerId = cl.swCustomerId 
								INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId 
								LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo  ON CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat AND sistema = 'EKTNET' AND UPPER(TipoProducto) IN ('TERMINAL','EQUIPAMIENTO','DISPOSITIVO') 
								AND UPPER(CASE UPPER(TRIM(m.mmMarcaDesc))  WHEN 'EUSKALTEL' THEN 'EUSKALTEL'  WHEN 'VIRGIN TELCO' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'TELECABLE' THEN 'TELECABLE' END  ) = UPPER(catalogo.marca_ds) AND UPPER(catalogo.marca_ds) = 'TELECABLE' /*AGRERGAR CAUSA DE BAJA PARA QUITAR LOS CAMBIOS DE DOMICILIO, TITULAR, CUENTA, ETC...*/ 
							  ) cpOrigen ON cp.swMasterInstProdId = cpOrigen.swInstProdId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` coOrigen2 ON coOrigen2.swInstProdId = cp.SwProdOrigId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` pOrigen ON cpOrigen.swProdReleaseId = pOrigen.swProdReleaseId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cicl ON cl.swParentId = cicl.swCustomerId 
				  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente_sgto_canal` s ON s.swCustomerId = cl.swCustomerId 
				  --- Se consideran terminales aquellos productos que no tengan origen, o que en caso de tenerlo, éste sea un producto de tipo terminal


 				 /*
				 ---- DESACTIVO					

				  WHERE ( cpOrigen.filtroTerminales = 1 OR cp.swMasterInstProdId IS NULL) 
				  AND (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",  'TC_MIGRA_MOV_202101',  'REPO_DATOS',  'MIGRAMASHFC_FTTH',  'EKT_MIGRA_202206',  'REPO_JUNIO_2022',  'EKT_MIGRA_202212') 
					  AND UPPER(cp.swCreatedBy) NOT LIKE 'MIGRA%' ) 

				 ---- FIN DESACTIVO
				 */
				 --- INSERTO NUEVO FILTRO 
				  WHERE (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",  'TC_MIGRA_MOV_202101',  'REPO_DATOS',  'MIGRAMASHFC_FTTH',  'EKT_MIGRA_202206',  'REPO_JUNIO_2022',  'EKT_MIGRA_202212') 
				  AND UPPER(cp.swCreatedBy) NOT LIKE 'MIGRA%') 
				 --- FIN FILTRO 			  

			) a
			INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = a.mmMarcaId
			WHERE (swCausaBaja NOT IN ('Cambio de Segmento', 'Cambio de domicilio', 'Cambio de Titular' )OR swCausaBaja IS NULL) /*AND (a.swAntiguedad IS NULL OR DATE_DIFF(CAST(swAntiguedad AS DATE), CAST(swDateInstalled AS DATE), DAY) < -15)*/ 
			AND (coalesce(a.swCreatedBy,"NO INFORMADO") NOT IN ("MigracionTMK", 'TC_MIGRA_MOV_202101', 'REPO_DATOS', 'MIGRAMASHFC_FTTH', 'EKT_MIGRA_202206', 'REPO_JUNIO_2022', 'EKT_MIGRA_202212') /*AND a.swCreatedBy NOT LIKE 'IBSWP%'*/ )  
			AND TRIM(a.swSegmento) IN ('Residencial','SOHO') 
			-- AND m.mmMarcaDesc = 'Telecable';
			AND UPPER(TRIM(m.mmMarcaDesc)) = 'TELECABLE';
			


	-- =========================================================
	-- CTE 2: Servicios Activos y Migrados
	-- =========================================================
			
		--- PASO 2: CREO TABLA LOG_0102_SERVICIOS_CARTERA_EKTNET			
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_SERVICIOS_ACT_Y_MIG` 
	  	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 				
		  SELECT distinct CASE UPPER(TRIM(mmMarcaDesc)) WHEN 'EUSKALTEL' THEN 'EUSKALTEL' WHEN 'VIRGIN TELCO' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'TELECABLE' THEN 'TELECABLE' END mmMarcaDesc, 
		  CAST(a.IdCatalogo AS STRING) CatalogoId, 
		  a.NombreProducto, 
		  a.des_canal_dis canal, 
		  a.des_subcanal_dis subcanal, 
		  a.des_distribuidor agente, 
		  CAST( a.swCustomerId AS INT64) CLIENTE_ID, 
		  CAST(a.swAntiguedad AS Date) ANTIGUEDAD, 
		  a.swNIE, 
		  a.marcaCartera, 
		  CAST(a.concepto_ds AS STRING) concepto_ds, 
		  --- AÑADIDO TEMPORAL
		  --a.FECHA_RFB_ID_ORIGEN,
		  --- FIN AÑADIDO
		  CAST(a.swDateInstalled AS Date) FECHA_ACTIVACION, 
		  CAST(a.swDateCreated AS Date) FECHA_CREACION, 
--- INSERTO FECHA DESINSTALACION					
		  CAST(a.swFechaDesinstalacion AS Date) FECHA_DESINSTALACION,
--- FIN INSERCCION							

		  TRIM(a.swSegmento) swSegmento, 
		  a.swSegmento subsegmento, 
		  CAST(a.idCatalogoOrigen AS STRING) CatalogoIdOrigen, 
		  CAST(a.IdProductoOrigen AS INT64) ProductoIdOrigen, 
		  a.NombreProductoOrigen, 
		  a.TipoProductoOrigen, 
		  a.subTipoProductoOrigen,
--- INSERTO CADENA ORIGEN
   		  a.MasterInstProdIdProductoOrigen,
		  a.ProdOrigIdProductoOrigen,
		  a.CopiaProdIdProductoOrigen,
--- FIN INSERCCION			

--- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN	
		  a.FECHA_ACTIVACION_ORIGEN,
		  a.FECHA_DESINSTALACION_ORIGEN,
--- FIN INSERCCION

		  a.TipoMovimiento, 
		  a.TipoProducto,
		  a.subTipoProducto, 
		  CAST(a.swInstProdId AS INT64) productoId, 
		  CAST(a.cod_contrato AS STRING) contrato, 
		  usuarioCreador, 
		  agente_creador_id, 
		  canalId, swCOInterno, 
		  swName nombre_distribuidor, 
		  filtroTerminales, 
		  swInstProdIdOrigen, 
		  swProdOrigId ProdOrigen, 
		  swCausaBaja, concepto_origen_ds, 
		  CAST(NULL AS STRING) medio_conocimiento,
		  "SERVICIOS" as origen,
		  FROM ( 
		  
					SELECT p.swProdReleaseId IdCatalogo, CASE WHEN catalogo.TipoProducto = 'terminal' THEN cc.swCaractValor ELSE p.swReleaseName END NombreProducto, 
					c1.canal_agrupado1_ds des_canal_dis, 
					sc.subcanal_ds des_subcanal_dis, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS'THEN pe.swNombre ELSE ca.swVerticalFocus END des_distribuidor, 
					cicl.swCustomerId, 
					cp.swMarcaCartera, 
					cicl.swNIE, 
					cicl.swAntiguedad,
					cp.swMarcaCartera marcaCartera, 
					catalogo.concepto AS concepto_ds, 
					cp.swDateInstalled, 
					cp.swDateCreated, 
--- INSERTO FECHA DESINSTALACION					
					cp.swFechaDesinstalacion,
--- FIN INSERCCION					

					TRIM(cl.swSegmento) swSegmento, /*swSubsegmento,*/ 
					/*  PARCHE 1
						SI EL AGENTE CREADOR DEL TRAMO ES UN CORRECTIVO (AGENTE CREADOR CON NOMBRE CONTENIENDO STRING OPIT) Y EL PRODUCTO ORIGEN SE HA CREADO EN EL MES DE COMISIONADO 
						ENTONCES SE HA EJECUTADO UNA OPERACION DE ALTA 
						EN CASO CONTRARIO SE HA EJECUTADO UNA OPERACION DE CAMBIO (EL PRODUCTO ORIGEN FUE COMISIONADO EN MES PREVIO)                
					*/
						
							  --AÑADIDO TEMPORAL
								--FECHA_RFB_ID_ORIGEN,
								--FIN AÑADIDO				
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null else pOrigen.swProdReleaseId END idCatalogoOrigen, 
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null ELSE cpOrigen.swInstProdId END IdProductoOrigen, 
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null ELSE pOrigen.swReleaseName END NombreProductoOrigen, 
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null ELSE cpOrigen.TipoProducto END TipoProductoOrigen, 
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null ELSE cpOrigen.tipo_movimiento END subTipoProductoOrigen,

					CASE WHEN starts_with(cp.swCreatedBy, "OPIT")  AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN CONCAT('Alta ', catalogo.tipo_movimiento) 
						 ELSE CONCAT(CASE  WHEN cpOrigen.swInstProdId IS NULL THEN 'Alta ' ELSE 'Cambio ' END , catalogo.tipo_movimiento) 
					END TipoMovimiento, 
					/*  FIN SECCION PARCHE 1*/
					catalogo.TipoProducto,
					catalogo.tipo_movimiento as subTipoProducto, 
					cp.swInstProdId, NULL cod_contrato, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN cp.swCreatedBy ELSE pe.swNombre END usuarioCreador, 
					cp.swCreatedBy as agente_creador_id, 
						
					/*  PARCHE 1*/                
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN NULL ELSE cpOrigen.swCausaBaja END swCausaBaja, 
					/*  FIN SECCION PARCHE 1*/
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN cp.swCreatedBy ELSE pe.swNombre END swCreatedBy, 
					cl.mmMarcaId, 
					ca.swChnlPartnerId canalId, 
					ca.swCOInterno, 
					ca.swVerticalFocus, 
					ca.swChnlPartnerId, 
					ca.swName,
					/*  PARCHE 1*/                
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null ELSE cpOrigen.filtroTerminales END filtroTerminales,                                
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN null ELSE cpOrigen.swInstProdId END  swInstProdIdOrigen, 

--- INSERTO CADENA ORIGEN					
					cpOrigen.swMasterInstProdId as MasterInstProdIdProductoOrigen,
					cpOrigen.swProdOrigId as ProdOrigIdProductoOrigen,
					cpOrigen.swCopiaProdId as CopiaProdIdProductoOrigen,
--- FIN INSERCCION					
--- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN	
					CAST(cpOrigen.swDateInstalled AS Date) FECHA_ACTIVACION_ORIGEN, 				
					CAST(cpOrigen.swFechaDesinstalacion as Date) FECHA_DESINSTALACION_ORIGEN,
--- FIN INSERCCION					

					cp.swProdOrigId, 
					CASE WHEN starts_with(cp.swCreatedBy, "OPIT") AND cpOrigen.FECHA_RFB_ID_ORIGEN BETWEEN DESDE AND HASTA THEN  null ELSE cpOrigen.concepto END concepto_origen_ds 
					/*  FIN SECCION PARCHE 1*/                 
					FROM ( SELECT * FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
									---================================================
									--- VERSION 10
									--- ELIMINO 
									--- WHERE DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT 
									--- INSERTO
									WHERE ((DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) OR (DATE_TRUNC(CAST (swDateCreated AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT))
									---================================================

									--- ELIMINO CONDICION QUE EXCLUYE MIGRADOS 						
								  --- AND (swFechaDesinstalacion IS NULL  OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT ) 
					) cp 
					INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON CAST(cp.swProdReleaseId AS String) = catalogo.IdProdCat  AND sistema = 'EKTNET' AND UPPER(tipoProducto) NOT IN ('TERMINAL','EQUIPAMIENTO','DISPOSITIVO') AND UPPER(catalogo.marca_ds) = 'TELECABLE' 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl ON cp.swCustomerId = cl.swCustomerId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc ON cp.swInstProdId = cc.swInstProdId AND cc.swCaractName = 'Modelo' 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` p ON cp.swProdReleaseId = p.swProdReleaseId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca ON ca.swChnlPartnerId =cp.swChnlPartnerId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c ON c.canal_id = cp.swChnlPartnerId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON c.canal_agrupado1_id = c1.canal_agrupado1_id 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON c.canal_agrupado2_id = c2.canal_agrupado2_id 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON c.subcanal_id = sc.subcanal_id 
					LEFT JOIN ( SELECT swCustomerId, MIN(swDateInstalled) FechaActivacion FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Activo' GROUP BY 1) pActivos ON pActivos.swCustomerId = cp.swCustomerId 
					LEFT JOIN ( SELECT swCustomerId, MAX(swFechaDesinstalacion) fechaUltimaBaja FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Inactivo' GROUP BY 1) pInactivoson ON pInactivoson.swCustomerId = cp.swCustomerId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swPersonalId= cp.swProviderGrpId AND pe.swObjectType='CHANNEL_PARTNER' 
					/*LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T_MOVIL.distribuidores` d ON cp.cod_canal_dis = d.cod_canal_dis AND cp.cod_subcanal_dis = d.cod_subcanal_dis AND cp.cod_distribuidor = d.cod_distribuidor 
																											  AND cp.fecha_entrada BETWEEN d.fec_desde -- --AND d.fec_hasta */
					LEFT JOIN ( SELECT cp.*,CAST(FORMAT_DATE("%Y%m%d",CAST(swDateInstalled AS Date)) AS INTEGER) FECHA_RFB_ID_ORIGEN, catalogo.*, 
									  CASE  WHEN (UPPER(TipoProducto) = 'TERMINAL' AND DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) THEN 1  
											WHEN UPPER(TipoProducto) <> 'TERMINAL' AND DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < HASTA_DT THEN 1 ELSE 0 END filtroTerminales 
									  FROM ( SELECT  * 
											FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
											WHERE  DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT /*andDATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < DESDE_DT*/ 
									  ) cp 
									  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl ON cp.swCustomerId = cl.swCustomerId 
									  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId 
									  LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON CAST(cp.swProdReleaseId AS String) = catalogo.IdProdCat AND sistema = 'EKTNET' AND UPPER(TipoProducto) NOT IN ('TERMINAL','EQUIPAMIENTO','DISPOSITIVO') AND UPPER(catalogo.marca_ds) = 'TELECABLE' 
									  AND UPPER(CASE UPPER(TRIM(m.mmMarcaDesc))  WHEN 'EUSKALTEL' THEN 'EUSKALTEL'  WHEN 'VIRGIN TELCO' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'TELECABLE' THEN 'TELECABLE' END  ) = UPPER(catalogo.marca_ds) 
									  /* AGRERGAR CAUSA DE BAJA PARA QUITAR LOS CAMBIOS DE DOMICILIO, TITULAR, CUENTA, ETC...*/
					) cpOrigen ON cp.swProdOrigId= cpOrigen.swInstProdId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` pOrigen ON cpOrigen.swProdReleaseId = pOrigen.swProdReleaseId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cicl ON cl.swParentId = cicl.swCustomerId 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente_sgto_canal` s ON s.swCustomerId = cl.swCustomerId 

 				 /*
				 ---- DESACTIVO					

					WHERE (cpOrigen.filtroTerminales = 1 OR cpOrigen.swInstProdId IS NULL) 
					AND (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",  'TC_MIGRA_MOV_202101',  'REPO_DATOS',  'MIGRAMASHFC_FTTH',  'EKT_MIGRA_202206',  'REPO_JUNIO_2022',  'EKT_MIGRA_202212')  ) 
 				 
				 ---- DESACTIVO */					
	
				 --- INSERTO NUEVO FILTRO 
				  WHERE (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",  'TC_MIGRA_MOV_202101',  'REPO_DATOS',  'MIGRAMASHFC_FTTH',  'EKT_MIGRA_202206',  'REPO_JUNIO_2022',  'EKT_MIGRA_202212')  ) 
				 --- FIN FILTRO 			  

			  ) a
			  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m  ON m.mmMarcaId = a.mmMarcaId --
			  --LEFT JOIN -- `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_COMISIONAMIENTO_RFS_CANAL_SERVICIOS_TMP_TELECABLE_SOMO` somo --
			  --ON -- a.id_cliente_tcnet = somo.cliente_id
			  WHERE (swCausaBaja NOT IN ('Cambio de Segmento', 'Cambio de domicilio', 'Cambio de Titular' ) OR swCausaBaja IS NULL) /* AND (a.swAntiguedad IS NULL OR DATE_DIFF(CAST(swAntiguedad AS DATE), CAST(swDateInstalled AS DATE), DAY) < -15)*/ 
			  AND (coalesce(a.swCreatedBy,"NO INFORMADO") NOT IN ("MIGRACIONTMK", 'TC_MIGRA_MOV_202101', 'REPO_DATOS', 'MIGRAMASHFC_FTTH', 'EKT_MIGRA_202206', 'REPO_JUNIO_2022', 'EKT_MIGRA_202212') /*AND a.swCreatedBy NOT LIKE 'IBSWP%'*/  AND UPPER(swCreatedBy) NOT LIKE 'MIGRA%') 
			  AND TRIM(a.swSegmento) IN ('Residencial', 'SOHO') 
			  AND UPPER(TRIM(m.mmMarcaDesc)) = 'TELECABLE' 
		 --- AÑADIDO TEMPORAL
		 --- AND STARTS_WITH(agente_creador_id,"OPIT")
			;		


	-- =========================================================
	-- CTE 3: Unificamos Terminales y Servicios
	-- =========================================================

	  --- PASO 3: CREO TABLA LOG_0102_EVENTOS_CARTERA_EKTNET
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` 
	  	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 		
		SELECT DISTINCT *
		FROM ( 
				SELECT DISTINCT * except(Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN, origen), 
				Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN,origen
				FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_SERVICIOS_ACT_Y_MIG`
				UNION ALL
				SELECT DISTINCT *  except(Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN, origen), 
				Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN,origen
				FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_TERMINALES_ACT_Y_MIG`
		); 


	-- =========================================================
	-- CTE 4: Eventos Activos del Mes (sin migraciones ni bajas)
	-- =========================================================

		--- Productos activados en mes de comisionado y no migrados ni desactivados -- 63505  66585
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT`  
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		SELECT distinct * 
		FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` 
		WHERE  swInstProdIdOrigen is null 
		AND (Fecha_Desinstalacion IS NULL OR DATE_TRUNC(CAST (Fecha_Desinstalacion AS DATE), DAY) > HASTA_DT) ;

	-- =========================================================
	-- CTE 5: Migraciones en el mismo mes
	-- =========================================================

	  	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` 
	  	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` 
		WHERE  swInstProdIdOrigen is not null 
		AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) >= DESDE_DT
		AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) <= HASTA_DT
		AND MasterInstProdIdProductoOrigen is null
		AND fecha_desinstalacion is null; 

	-- =========================================================
	-- CTE 6: Migraciones resto (excluye activas y mismo mes)
	-- =========================================================

    	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` t
		  where not exists (
		  	select 1 
		  	from `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT` a
		  	where a.CLIENTE_ID=t.Cliente_id
		  	and a.productoId=t.ProductoId
		) and not exists (
		  	select 1 
		  	from `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` a
		  	where a.CLIENTE_ID=t.Cliente_id
		  	and a.ProductoId=t.ProductoId
		);

	-- =========================================================
	-- CTE 7: Migraciones resto activas
	-- =========================================================


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO_ACT` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO` t
		WHERE(t.Fecha_Desinstalacion IS NULL OR DATE_TRUNC(CAST (t.Fecha_Desinstalacion AS DATE), DAY) > HASTA_DT);


	-- =========================================================
	-- CTE 8: Migraciones resto no activas
	-- =========================================================

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO_NOACT` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO` t
		WHERE not exists (
			select 1 
		  	from `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO_ACT` a
		  	where a.CLIENTE_ID=t.Cliente_id
		  	and a.ProductoId=t.ProductoId
		);


	-- =========================================================
	-- CTE 9: Apuntes Migraciones mismo mes
	-- =========================================================

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_APUNTES_MIG_MISMO_MES` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		select f.mmMarcaDesc, 
		f.CatalogoId, 
		f.NombreProducto, 
		i.canal, 
		i.subcanal, 
		i.agente, 
		f.CLIENTE_ID, 
		i.ANTIGUEDAD, 
		i.swNIE, 
		i.marcaCartera, 
		f.concepto_ds, 
		i.FECHA_ACTIVACION, 
		i.FECHA_CREACION, 
		--- INSERTO FECHA DESINSTALACION					
		f.FECHA_DESINSTALACION,
		--- FIN INSERCCION					
		i.swSegmento, 
		i.subsegmento, 
		i.CatalogoId as CatalogoIdOrigen, 
		CAST(i.ProductoId AS INT64) ProductoIdOrigen, 
		i.nombreProducto as NombreProductoOrigen,
		i.TipoProducto as TipoProductoOrigen, 
		i.subTipoProductoOrigen as subTipoProductoOrigen,
		--- INSERTO CADENA ORIGEN
		f.MasterInstProdIdProductoOrigen,
		f.ProdOrigIdProductoOrigen,
		f.CopiaProdIdProductoOrigen,
		--- FIN INSERCCION			

		--- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN	
		f.FECHA_ACTIVACION_ORIGEN,
		f.FECHA_DESINSTALACION_ORIGEN,
		--- FIN INSERCCION

		i.TipoMovimiento, 
		i.TipoProducto,
		i.subTipoProducto,
		f.productoId, 
		i.contrato, 
		i.usuarioCreador, 
		i.agente_creador_id, 
		i.canalId, 
		i.swCOInterno, 
		i.nombre_distribuidor, 
		i.filtroTerminales, 
		f.swInstProdIdOrigen, 
		f.ProdOrigen,
		f.swCausaBaja, 
		i.concepto_ds as concepto_origen_ds, 
		i.medio_conocimiento
		from `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` f  
		left join `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` i on f.cliente_id= i.cliente_id and f.ProductoIdOrigen=i.productoId ;


	-- =========================================================
	-- CTE 10: Crear fichero incremental final
	-- =========================================================

		--- PASO 3 CREO TABLA DE LOG
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_INCR` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
		SELECT *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN, origen)
		FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_ACT`
		UNION ALL 
		SELECT *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
		FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_APUNTES_MIG_MISMO_MES`
		UNION ALL 
		SELECT 
			mmMarcaDesc,
			CatalogoId,
			NombreProducto,
			canal,
			subcanal,
			agente,
			CLIENTE_ID,
			ANTIGUEDAD,
			swNIE,
			marcaCartera,
			concepto_ds,
			FECHA_ACTIVACION,
			FECHA_CREACION,
			swSegmento,
			subsegmento,
			CatalogoIdOrigen,
			ProductoIdOrigen,
			NombreProductoOrigen,
			TipoProductoOrigen,
			subTipoProductoOrigen,
			TipoMovimiento,
			TipoProducto,
			subTipoProducto,
			productoId,
			contrato,
			usuarioCreador,
			agente_creador_id,
			canalId,
			swCOInterno,
			nombre_distribuidor,
			filtroTerminales,
			swInstProdIdOrigen,
			ProdOrigen,
			swCausaBaja,
			concepto_origen_ds,
			medio_conocimiento
		FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_MIG_RESTO_ACT`
  		where origen="SERVICIOS";

	-- ==========================================================
	-- OUT 1: Crear tabla final consolidada
	-- ==========================================================

		--- PASO 4 INSERTO REGISTROS EN EVENTOS_CARTERA_EKTNET DE ACTIVACIONES EN MISMO MES
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS     
		SELECT * 
		FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET_INCR`;



	-- ==========================================================
	-- OUT 2: Crear tabla log de incremental de procedimiento
	-- ==========================================================

		--- PASO 5 CREO TABLA DE LOG
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0102_EVENTOS_CARTERA_EKTNET` 
		OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 		
		SELECT *
		FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;
		
END