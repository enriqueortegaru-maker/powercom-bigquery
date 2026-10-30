BEGIN


  ---- IMPORTANTE REVISAR USUARIO CREADOR YA QEU NO ES ES EL USUARIO QUE CREA EL PRODUCTO EN EKTNET
  DECLARE DESDE_DT, HASTA_DT date;
  ---LOCAL
  --DECLARE DESDE, HASTA INT64; SET DESDE=20251001;SET HASTA=20251031;
  SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
  SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) ); 

	--- 20251106 se elimina causaBaja en filas 246 y 478

	-- =========================================================
	-- CTE 1: Terminales y Equipamientos Activos y Migrados
	-- =========================================================

  	/*PASO 1 CREO TABLA EVENTOS_CARTERA_EKTNET_INCR*/

  	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_TERMINALES` 
  	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS  

	---- PRODUCTOS DE TIPOPRODUCTO TERMINAL
	SELECT mmMarcaDesc, CAST(a.IdCatalogo AS STRING) CatalogoId, 
			a.NombreProducto, 
			a.des_canal_dis canal, 
			a.des_subcanal_dis subcanal, 
			a.des_distribuidor agente, 
			CAST( a.swCustomerId AS INT64) CLIENTE_ID, 
			CAST(a.swAntiguedad AS Date) ANTIGUEDAD, 
			a.swNIE, 
			a.marcaCartera, 
			a.concepto_ds, 
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
			canalId, 
			swCOInterno, 
			swName nombre_distribuidor, 
			filtroTerminales, 
			--- swInstProdIdOrigen: Atributo swInstProdId del primer producto de la cadena ---Si es nulo implica que 
			swInstProdIdOrigen, 
			--- ProdPrevio: Producto previo de la cadena (terminal analizado)
			swProdOrigId ProdPrevio,
			swCausaBaja, 
			CAST(NULL AS STRING) concepto_origen_ds, 
			CAST(NULL AS STRING) medio_conocimiento,
			"TERMINALES" origen,
			FROM ( 
					
					---- cpOrigen es la instancia del primer producto de la cadena				
					with cpOrigen as (
						with cp as (
							SELECT * 
							FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
							WHERE DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT /*and DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < DESDE*/								  
						)	
					
						SELECT cp.*,   catalogo.*,   
						--- FiltroTerminales: variable que toma valor 1 cuando el TipoProducto es TERNINAL y se activa en ventana de comisionado o el producto no es TERMINAL y se activa antes de la finalización de la ventana de comisionado (pued3e haberse activado antes del inicio de la ventana). 					
							--- Si el catalogo de producto es de tipo TERMINAL y se activa en la ventana de comisionado, entonces variable FiltroTerminales=1
							--- Si el catalogo de producto no es de tipo TERMINAL y la activación es previa al fin de la ventana de comisionado, entonces variable FiltroTerminales=1					
						CASE  WHEN (UPPER(TipoProducto) = 'TERMINAL' AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) THEN 1 
							  WHEN UPPER(TipoProducto) <> 'TERMINAL' AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) < HASTA_DT THEN 1 ELSE 0 
						END filtroTerminales,   
						--- FiltroMes: variable que toma valor 1 cuando ha habido un alta + cambio en el mismo mes. 
								--- Si hay cadena de productos (pp.swDateDateInstalled not null) y el producto inicial se activa con posterioridad al inicio de la ventana de comisionado, entonces variable FiltroMes=1
								--- Si no hay cadena de productos (pp.swDateDateInstalled null) y el producto se activa con posterioridad al inicio de ventana de comisionado, entonces variable FiltroMes=1					
						--- Esta variable aplica en el 
						---		Cálculo del TipoMovimiento en Servicios y terminales
						---		Valor de NombreProductoOrigen en productos con TipoProducto TERMINAL 
						---		Valor de Concepto_origen_ds en productos con TipoProducto TERMINAL 							
						CASE WHEN coalesce(CAST(pp.swDateInstalled AS DATE), CAST(cp.swDateInstalled AS DATE)) > DESDE_DT THEN 1 ELSE 0 
						END FiltroMes 
						FROM cp 
						INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl ON cl.swCustomerId = cp.swCustomerId 
						INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId 
						LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON catalogo.IdProdCat=CAST(cp.swProdReleaseId AS String)  AND sistema = 'EKTNET' AND UPPER(TipoProducto) NOT IN ('TERMINAL') 
									AND UPPER(CASE m.mmMarcaDesc   WHEN 'Euskaltel' THEN 'EUSKALTEL'   WHEN 'Virgin Telco' THEN 'VIRGIN'   WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' WHEN 'SIMple' THEN 'SIMPLE' END ) = UPPER(catalogo.marca_ds) 
									AND UPPER(catalogo.marca_ds) <> 'TELECABLE' 
						--- producto inicial
						LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` pp ON pp.swInstProdId=cp.swMasterInstProdId    --WHERE catalogo.IdProdCat <> 951
					
					), 

				
					---- cp es la instancia del producto que se analiza
					cp as (
						SELECT * FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
						---================================================
						--- VERSION 8
						--- ELIMINO 
						--- WHERE DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT 
						--- INSERTO
						WHERE ((DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) OR (DATE_TRUNC(CAST (swDateCreated AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT))
						---================================================						


						--- ELIMINO CONDICION QUE EXCLUYE MIGRADOS 						
						--AND (swFechaDesinstalacion IS NULL OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
						--- FIN ELIMINACION						
					)				
			
					SELECT CASE mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' WHEN 'SIMple' THEN 'SIMPLE' END mmMarcaDesc, 
					p.swProdReleaseId IdCatalogo, 
					CASE WHEN catalogo.TipoProducto = 'terminal' THEN cc.swCaractValor ELSE p.swReleaseName END NombreProducto, 
					c1.canal_agrupado1_ds des_canal_dis, 
					sc.subcanal_ds des_subcanal_dis, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS' THEN pe.swNombre ELSE ca.swVerticalFocus END des_distribuidor, 
					cl.swCustomerId, cp.swMarcaCartera, cl.swNIE, '1900-01-01' swAntiguedad, 
					cp.swMarcaCartera marcaCartera, 
					ct.modelo, 
					CASE WHEN ct.modelo IS NOT NULL THEN ct.concepto_ds ELSE catalogo.concepto END concepto_ds, 
					cp.swDateInstalled, 
					cp.swDateCreated, 
					--- INSERTO FECHA DESINSTALACION					
					cp.swFechaDesinstalacion,
					--- FIN INSERCCION					
					TRIM(cl.swSegmento) swSegmento, 
					/*swSubsegmento,*/ 
					pOrigen.swProdReleaseId idCatalogoOrigen, 
					cpOrigen.swInstProdId IdProductoOrigen, 
					pOrigen.swReleaseName NombreProductoOrigen, 
					cpOrigen.TipoProducto as TipoProductoOrigen, 
					cpOrigen.tipo_movimiento as subTipoProductoOrigen,
					--- INSERTO CADENA ORIGEN					
					cpOrigen.swMasterInstProdId as MasterInstProdIdProductoOrigen,
					cpOrigen.swProdOrigId as ProdOrigIdProductoOrigen,
					cpOrigen.swCopiaProdId as CopiaProdIdProductoOrigen,
					--- FIN INSERCCION					
					--- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN	
					CAST(cpOrigen.swDateInstalled AS Date) FECHA_ACTIVACION_ORIGEN, 				
					CAST(cpOrigen.swFechaDesinstalacion as Date) FECHA_DESINSTALACION_ORIGEN,
					--- FIN INSERCCION					
					
					
					--- TipoMovimiento es ALTA SI:
					---		Catálogo tipificado como "TERMINAL"
					---		El producto instanciado es el primero de la cadena (el campo master del producto es nulo o lo que es lo mismo, el cpOrigen.swInstProdId es nulo)
					---		Se registra alta + cambio en el mismo mes (FiltroMes=1)
					---		Hay cadena de productos y el catálogo de producto origen es Prepago para movil y catálogo de producto destino es otro
					--- TipoMovimiento es CAMBIO:
					---		Resto de los casos
					
					CONCAT(CASE WHEN cpOrigen.swInstProdId IS NULL 
									 OR filtroMes = 1 
									 --- catalogoDeProducto origen es "Prepago de Recargas para Movil" y el catáogo del servicio destino es distinto a "Prepago de Recargas para Movil"
									 OR (cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) 
									 --- Tipo de producto es terminal 
									 OR UPPER(catalogo.TipoProducto) = 'TERMINAL' 
								THEN 'Alta ' 
								ELSE 'Cambio ' 
							END , 
							catalogo.tipo_movimiento) TipoMovimiento, 
					
					catalogo.TipoProducto,
					catalogo.tipo_movimiento as subTipoProducto,
					cp.swInstProdId, 
					NULL cod_contrato, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN cp.swCreatedBy
						 ELSE coalesce(pe.swNombre,   cp.swCreatedBy) 
					END usuarioCreador,
					cp.swCreatedBy agente_creador_id, 
					--- La causa de la  baja se obtiene del producto previo de la cadena
					cpPrevio.swCausaBaja, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS'THEN cp.swCreatedBy 
					ELSE coalesce(pe.swNombre,   cp.swCreatedBy) 
					END swCreatedBy, 
					cl.mmMarcaId, 
					ca.swChnlPartnerId canalId, 
					ca.swCOInterno, 
					ca.swVerticalFocus, 
					ca.swChnlPartnerId, 
					ca.swName, 
					cpOrigen.filtroTerminales, 
					cpOrigen.swInstProdId swInstProdIdOrigen, 
					cp.swProdOrigId, 
					filtromes
					FROM cp
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON cp.swCustomerId = cl.swCustomerId
					INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m  ON m.mmMarcaId = cl.mmMarcaId
					INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo  ON CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat AND sistema = 'EKTNET' AND UPPER(tipoProducto) IN ( 'TERMINAL') AND UPPER(catalogo.marca_ds) = CASE m.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' WHEN 'SIMple' THEN 'SIMPLE' END AND UPPER(catalogo.marca_ds) <> 'TELECABLE'
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc  ON cp.swInstProdId = cc.swInstProdId AND cc.swCaractName = 'Modelo'
					LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES` ct  ON UPPER(cc.swCaractValor) = UPPER(ct.modelo) AND UPPER(ct.marca_ds) = UPPER(CASE m.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE'  WHEN 'SIMple' THEN 'SIMPLE' END )
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` p  ON cp.swProdReleaseId = p.swProdReleaseId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca  ON ca.swChnlPartnerId =cp.swChnlPartnerId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c  ON c.canal_id = cp.swChnlPartnerId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1  ON c.canal_agrupado1_id = c1.canal_agrupado1_id
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2  ON c.canal_agrupado2_id = c2.canal_agrupado2_id
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc  ON c.subcanal_id = sc.subcanal_id
					--LEFT JOIN ( SELECT swCustomerId, MIN(swDateInstalled) FechaActivacion FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Activo' GROUP BY 1) pActivos  ON pActivos.swCustomerId = cp.swCustomerId
					--LEFT JOIN ( SELECT swCustomerId, MAX(swFechaDesinstalacion) fechaUltimaBaja FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Inactivo' GROUP BY 1) pInactivoson  ON pInactivoson.swCustomerId = cp.swCustomerId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe  ON pe.swPersonalId= cp.swProviderGrpId AND pe.swObjectType='CHANNEL_PARTNER'
					---- cpOrigen es la instancia del producto origen de la cadena
					LEFT JOIN cpOrigen  ON cpOrigen.swInstProdId=cp.swMasterInstProdId
					---- cpPrevio es la instancia del producto previo de la cadena 
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` cpPrevio  ON cpPrevio.swInstProdId = cp.SwProdOrigId
					---- pOrigen es el catálogo de la instancia del producto origen de la cadena				
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` pOrigen  ON pOrigen.swProdReleaseId = cpOrigen.swProdReleaseId  
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente_sgto_canal` s  ON s.swCustomerId = cl.swCustomerId

					/*
					 ---- DESACTIVO					

					WHERE (cpOrigen.filtroTerminales = 1  OR cp.swMasterInstProdId IS NULL ) 
					AND (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",   'TC_MIGRA_MOV_202101',   'REPO_DATOS',   'MIGRAMASHFC_FTTH',   'EKT_MIGRA_202206',   'REPO_JUNIO_2022',   'EKT_MIGRA_202212'))
				  --    'MIG TV EKT 2023',
				  --    'MIG TV RACC 2023') --AND UPPER(cp.swCreatedBy) NOT LIKE 'IBSWP%' ) 

					---- FIN DESACTIVO
					*/

					--- INSERTO NUEVO FILTRO 
					WHERE  (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",   'TC_MIGRA_MOV_202101',   'REPO_DATOS',   'MIGRAMASHFC_FTTH',   'EKT_MIGRA_202206',   'REPO_JUNIO_2022',   'EKT_MIGRA_202212'))
					--- FIN INSERTO NUEVO FILTRO 

			) a
			--- Causa de baja de elemeto previo es nula y evento no creado por agente relacioando con migraciones, reposiciones o swaps
--			WHERE (swCausaBaja NOT IN ('Cambio de Segmento',   'Cambio de domicilio',   'Cambio de Titular' ) OR swCausaBaja IS NULL)
			WHERE (coalesce(swCausaBaja,"NOINFORMADO") NOT IN ('Cambio de Segmento',   'Cambio de domicilio',   'Cambio de Titular' ))
			AND (a.swCreatedBy NOT IN ("MIGRACIONTMK",   'TC_MIGRA_MOV_202101',   'REPO_DATOS',   'MIGRAMASHFC_FTTH',   'EKT_MIGRA_202206',   'REPO_JUNIO_2022',   'EKT_MIGRA_202212')
	  --    'MIG TV EKT 2023',
	  --    'MIG TV RACC 2023') --AND a.swCreatedBy NOT LIKE 'IBSWP%'
			)
			AND TRIM(UPPER(a.swSegmento)) IN ('RESIDENCIAL', 'SOHO', 'PYME');



	-- =========================================================
	-- CTE 2: Servicios Activos y Migrados
	-- =========================================================
   

  	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_SERVICIOS` 
  	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS  
			---- PRODUCTOS DE TIPOPRODUCTO DISTINTO A TERMINAL
			
	SELECT  mmMarcaDesc, CAST(a.IdCatalogo AS STRING) CatalogoId, 
			a.NombreProducto, 
			a.des_canal_dis canal, 
			a.des_subcanal_dis subcanal, 
			a.des_distribuidor agente, 
			CAST( a.swCustomerId AS INT64) CLIENTE_ID, 
			CAST(a.swAntiguedad AS Date) ANTIGUEDAD, 
			a.swNIE, 
			a.marcaCartera, 
			a.concepto_ds, 
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
			canalId, 
			swCOInterno, 
			swName nombre_distribuidor, 
			filtroTerminales, 
			swInstProdIdOrigen, 
			swProdOrigId ProdPrevio, 
			swCausaBaja, 
			concepto_origen_ds, 
			CAST(NULL AS STRING) medio_conocimiento,
			"SERVICIOS" origen,
			FROM (  
					with cpOrigen as (
					
						with cp as (
							SELECT * FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 
							WHERE DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT /*andDATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < DESDE*/ 				

						)
						SELECT cp.*,   catalogo.*,   
						CASE WHEN (UPPER(TipoProducto) = 'TERMINAL' AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) THEN 1 
							 WHEN UPPER(TipoProducto) <> 'TERMINAL' AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) < HASTA_DT THEN 1 
							 ELSE 0 
						END filtroTerminales,   
						CASE WHEN coalesce(CAST(pp.swDateInstalled AS DATE), CAST(cp.swDateInstalled AS DATE)) > DESDE_DT THEN 1
							 ELSE 0 
						END FiltroMes 
						FROM cp 
						INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl ON cp.swCustomerId = cl.swCustomerId 
						INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m ON m.mmMarcaId = cl.mmMarcaId 
						LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat AND sistema = 'EKTNET' AND UPPER(TipoProducto) NOT IN ('TERMINAL') AND UPPER(CASE m.mmMarcaDesc   WHEN 'Euskaltel' THEN 'EUSKALTEL'   WHEN 'Virgin Telco' THEN 'VIRGIN'   WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' WHEN 'SIMple' THEN 'SIMPLE' END ) = UPPER(catalogo.marca_ds) AND UPPER(catalogo.marca_ds) <> 'TELECABLE' 
						LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` pp ON cp.swMasterInstProdId = pp.swInstProdId -- --WHERE catalogo.IdProdCat <> 951 ----- AGRERGAR CAUSA DE BAJA PARA QUITAR LOS CAMBIOS DE DOMICILIO,TITULAR,CUENTA,ETC... 
					), cp as (
						SELECT * FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` 

							---================================================
							--- VERSION 8
							--- ELIMINO 
							--- WHERE DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT 
							--- INSERTO
							WHERE ((DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) OR (DATE_TRUNC(CAST (swDateCreated AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT))
							---================================================
						
								--- ELIMINO CONDICION QUE EXCLUYE MIGRADOS
								---						AND (swFechaDesinstalacion IS NULL OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT ) 				
					)
		
			
					SELECT CASE mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' WHEN 'SIMple' THEN 'SIMPLE' END mmMarcaDesc, 
					p.swProdReleaseId IdCatalogo, 
					p.swReleaseName NombreProducto, 
					c1.canal_agrupado1_ds des_canal_dis, 
					sc.subcanal_ds des_subcanal_dis, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS'THEN pe.swNombre ELSE ca.swVerticalFocus END des_distribuidor, 
					cl.swCustomerId, 
					cp.swMarcaCartera, 
					cl.swNIE, 
					'1900-01-01' swAntiguedad, 
					cp.swMarcaCartera marcaCartera, 
					catalogo.concepto concepto_ds, 
					cp.swDateInstalled, 
					cp.swDateCreated, 
					--- INSERTO FECHA DESINSTALACION DE PRODUCTO					
					cp.swFechaDesinstalacion,
					--- FIN INSERCCION					
					TRIM(cl.swSegmento) swSegmento, 
					pOrigen.swProdReleaseId idCatalogoOrigen, 
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


					
					--- NombreProductoOrigen es NULL Si
					---		Hay cadena de productos y el catálogo de producto origen es Prepago para movil y catálogo de producto destino es otro
					---		Hay secuencia de alta + cambio de producto en el mismo mes (TipoMes=1)
					
					CASE WHEN(cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) 
							   OR filtromes = 1 
						 THEN NULL 
						 ELSE pOrigen.swReleaseName 
					END NombreProductoOrigen, 
					
									
					cpOrigen.TipoProducto as TipoProductoOrigen, 
					cpOrigen.tipo_movimiento as subTipoProductoOrigen,

					--- TipoMovimiento es ALTA SI:
					---		Instancia de producto origen es nula
					---		Se registra alta + cambio en el mismo mes (FiltroMes=1)
					---		Hay cambio y catalogo de producto origen es Prepago para movil y catálogo de producto destino es otro (Creo que esta condicón está mal y debería aplicar al padre)
					--- TipoMovimiento es CAMBIO:
					---		Resto de los casos			
					
					CONCAT(CASE WHEN  cpOrigen.swInstProdId IS NULL 
									OR (cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) 
									OR filtroMes = 1 
								THEN 'Alta ' ELSE 'Cambio ' 
								END , 
								catalogo.tipo_movimiento) TipoMovimiento, 
					catalogo.TipoProducto,
					
					
					catalogo.tipo_movimiento as subTipoProducto,
					cp.swInstProdId, NULL cod_contrato, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN coalesce(pe.swNombre, cp.swCreatedBy) 
						 ELSE pe.swNombre 
					END usuarioCreador, 
					cp.swCreatedBy agente_creador_id, 
					cpOrigen.swCausaBaja, 
					CASE WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN coalesce(pe.swNombre, cp.swCreatedBy) ELSE pe.swNombre END swCreatedBy, 
					cl.mmMarcaId, 
					ca.swChnlPartnerId canalId, 
					ca.swCOInterno, 
					ca.swVerticalFocus, 
					ca.swChnlPartnerId, 
					ca.swName, 
					cpOrigen.filtroTerminales, 
					cpOrigen.swInstProdId swInstProdIdOrigen, 
					cp.swProdOrigId, 
					
					--- Concepto_origen_ds es NULL Si:
					---		Hay cadena de productos y el catálogo de producto origen es Prepago para movil y catálogo de producto destino es otro
					---		Hay secuencia de alta + cambio de producto en el mismo mes (TipoMes=1)
					
					CASE WHEN( cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) 
								OR filtromes = 1 
						 THEN NULL 
						 ELSE cpOrigen.concepto  
					END concepto_origen_ds, 
					
					
					FROM cp
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON cp.swCustomerId = cl.swCustomerId
					INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m  ON m.mmMarcaId = cl.mmMarcaId
					INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat AND sistema = 'EKTNET' AND UPPER(tipoProducto) NOT IN ('TERMINAL') AND UPPER(catalogo.marca_ds) = UPPER(CASE m.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' WHEN 'SIMple' THEN 'SIMPLE' END ) AND UPPER(catalogo.marca_ds) <> 'TELECABLE'
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` p  ON cp.swProdReleaseId = p.swProdReleaseId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca  ON ca.swChnlPartnerId =cp.swChnlPartnerId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c  ON c.canal_id = cp.swChnlPartnerId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1  ON c.canal_agrupado1_id = c1.canal_agrupado1_id
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2  ON c.canal_agrupado2_id = c2.canal_agrupado2_id
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc  ON c.subcanal_id = sc.subcanal_id
					--LEFT JOIN ( SELECT swCustomerId,   MIN(swDateInstalled) FechaActivacion FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Activo' GROUP BY 1) pActivos  ON pActivos.swCustomerId = cp.swCustomerId
					--LEFT JOIN ( SELECT swCustomerId,   MAX(swFechaDesinstalacion) fechaUltimaBaja FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` WHERE swStatus = 'Inactivo' GROUP BY 1) pInactivoson  ON pInactivoson.swCustomerId = cp.swCustomerId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe  ON pe.swPersonalId= cp.swProviderGrpId AND pe.swObjectType='CHANNEL_PARTNER'
					LEFT JOIN cpOrigen ON cp.swProdOrigId= cpOrigen.swInstProdId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` pOrigen  ON cpOrigen.swProdReleaseId = pOrigen.swProdReleaseId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente_sgto_canal` s  ON s.swCustomerId = cl.swCustomerId

					/* 					 
					 ---- DESACTIVO					
					
					WHERE (cpOrigen.filtroTerminales = 1 

						OR cpOrigen.swInstProdId IS NULL

					) 
					AND (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",   'TC_MIGRA_MOV_202101',   'REPO_DATOS',   'MIGRAMASHFC_FTTH',   'EKT_MIGRA_202206',   'REPO_JUNIO_2022',   'EKT_MIGRA_202212') 
					--AND UPPER(cp.swCreatedBy) NOT LIKE 'IBSWP%'  ) 
					 ---- FIN DESACTIVO					
					*/

					--- INSERTO NUEVO FILTRO 
					WHERE  UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",   'TC_MIGRA_MOV_202101',   'REPO_DATOS',   'MIGRAMASHFC_FTTH',   'EKT_MIGRA_202206',   'REPO_JUNIO_2022',   'EKT_MIGRA_202212') 
					--- FIN NUEVO FILTRO 

			) a
--			WHERE  (swCausaBaja NOT IN ('Cambio de Segmento',   'Cambio de domicilio',   'Cambio de Titular' ) or swCausaBaja is NULL)
			WHERE  (COALESCE(swCausaBaja,"NOINFORMADO") NOT IN ('Cambio de Segmento',   'Cambio de domicilio',   'Cambio de Titular' ))
			AND (coalesce(a.swCreatedBy, "NO INFORMADO" ) NOT IN ("MIGRACIONTMK",   'TC_MIGRA_MOV_202101',   'REPO_DATOS',   'MIGRAMASHFC_FTTH',   'EKT_MIGRA_202206',   'REPO_JUNIO_2022',   'EKT_MIGRA_202212') 
			/*'MIG TV EKT 2023', 'MIG TV RACC 2023') AND a.swCreatedBy NOT LIKE 'IBSWP%'  */)
			AND TRIM(UPPER(a.swSegmento)) IN ('RESIDENCIAL', 'SOHO', 'PYME'); 


	-- =========================================================
	-- CTE 3: Unificamos Terminales y Servicios
	-- =========================================================


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` 
  	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS  
	SELECT  DISTINCT * except(Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN), 
	Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_TERMINALES`  as terminales
	UNION ALL
	select DISTINCT * except(Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN), 
	Fecha_Desinstalacion, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN 
	from `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_SERVICIOS`  as  servicios;


	-- =========================================================
	-- CTE 4: Eventos Activos del Mes (sin migraciones ni bajas)
	-- =========================================================

	--- PASO 3: CLASIFICO EVENTOS 
	--- Productos activados en mes de comisionado y no migrados ni desactivados 

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT`  
	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	SELECT distinct * 

	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG`
	WHERE swInstProdIdOrigen is null 
	AND (Fecha_Desinstalacion IS NULL OR DATE_TRUNC(CAST (Fecha_Desinstalacion AS DATE), DAY) > HASTA_DT);



	-- =========================================================
	-- CTE 5: Migraciones en el mismo mes
	-- =========================================================


	  --- Productos activados y migrados en mes de comisionado, y cuyo destino permanece activo

	  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` 
	  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	  SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` 
	  WHERE swInstProdIdOrigen is not null 
	  AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) >= DESDE_DT
	  AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) <= HASTA_DT
	  AND MasterInstProdIdProductoOrigen is null
	  AND fecha_desinstalacion is null; 


	-- =========================================================
	-- CTE 6: Migraciones resto (excluye activas y mismo mes)
	-- =========================================================



	  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO` 
	  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	  SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` t
	  where not exists (
	  	select 1 
	  	from `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT` a
	  	where a.CLIENTE_ID=t.Cliente_id
	  	and a.productoId=t.ProductoId
	  ) and not exists (
	  	select 1 
	  	from `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` a
	  	where a.CLIENTE_ID=t.Cliente_id
	  	and a.ProductoId=t.ProductoId
	  );


	-- =========================================================
	-- CTE 7: Migraciones resto activas
	-- =========================================================



	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO_ACT` 
	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO` t
	WHERE(t.Fecha_Desinstalacion IS NULL OR DATE_TRUNC(CAST (t.Fecha_Desinstalacion AS DATE), DAY) > HASTA_DT);


	-- =========================================================
	-- CTE 8: Migraciones resto no activas
	-- =========================================================

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO_NOACT` 
	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO` t
	WHERE not exists (
		select 1 
	  	from `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO_ACT` a
	  	where a.CLIENTE_ID=t.Cliente_id
	  	and a.ProductoId=t.ProductoId
	);


	-- =========================================================
	-- CTE 9: Apuntes Migraciones mismo mes
	-- =========================================================

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_APUNTES_MIG_MISMO_MES` 
	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
	select distinct  f.mmMarcaDesc, 
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
	f.ProdPrevio,
	f.swCausaBaja, 
	i.concepto_ds as concepto_origen_ds, 
	i.medio_conocimiento
	from `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` f  
	left join `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT_Y_MIG` i on f.cliente_id= i.cliente_id and f.ProductoIdOrigen=i.productoId ;
	--left join `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_MISMO_MES` i on f.cliente_id= i.cliente_id and f.ProductoId=i.productoId ;


	-- =========================================================
	-- CTE 10: Crear fichero incremental final
	-- =========================================================

	  --- PASO 3 CREO TABLA DE LOG
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_INCR` AS
	SELECT distinct*  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN, origen)
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_ACT`
	UNION ALL 
	SELECT distinct *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_APUNTES_MIG_MISMO_MES` 
	UNION ALL 
	SELECT distinct *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN,origen)
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_MIG_RESTO_ACT`
	WHERE origen="SERVICIOS";	


	-- ==========================================================
	-- OUT 1: Inserto nuevos eventos en tabla final consolidada
	-- ==========================================================


	  --- PASO 4 INSERTO REGISTROS EN EVENTOS_CARTERA_EKTNET DE ACTIVACIONES EN MISMO MES
	INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`
	SELECT distinct * 
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET_INCR`;



	-- ==========================================================
	-- OUT 2: Crear tabla log de incremental de procedimiento
	-- ==========================================================

	  --- PASO 5 CREO TABLA DE LOG
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET` AS
	SELECT distinct *
	FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;


END