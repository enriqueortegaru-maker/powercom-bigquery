BEGIN

  DECLARE DESDE_DT, HASTA_DT date;
  --LOCAL 
  --DECLARE DESDE, HASTA INT64; SET DESDE=20240501;SET HASTA=20240531;
  SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
  SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );  


--- PASO 1: CREO TABLA KRT_CARTERA.EVENTOS_CARTERA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_PREVIO` AS
  SELECT p.swProdReleaseId, catalogo.NombreProducto, ca1.canal_agrupado1_ds Canal, sc.subcanal_ds subcanal, pe.swNombreComercial distribuidor, CAST(p.swCustomerId AS INT64) IdFijo, 
  c.swAntiguedad, c.swNIE, p.swMarcaCartera, p.swDateInstalled, TRIM(c.swSegmento) swSegmento, c.swSubsegmento, 
  CAST(origen.idProdCat AS STRING) idCatalogoOrigen, CAST(origen.SwInstProdId AS INT64) IdProductoOrigen, origen.NombreProducto NombreProductoOrigen,  
  origen.TipoProducto as TipoProductoOrigen, origen.Tipo_Movimiento as subTipoProductoOrigen,
  CONCAT(CASE WHEN origen.concepto_origen IS NULL THEN 'Alta ' ELSE  'Cambio ' END , catalogo.tipo_movimiento) TipoMovimiento, 
  catalogo.TipoProducto,
  catalogo.tipo_movimiento as subTipoProducto,
  CAST(p.swInstProdId AS INT64) swInstProdId, p.swCreatedBy, origen.swCausaBaja, p.swDateCreated, 
  p.swChnlPartnerId canalId,  pe.swNombre, canal.swCoInterno nombre_distribuidor, catalogo.concepto concepto_ds, origen.concepto_origen concepto_origen_ds 
  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p 
  INNER JOIN (SELECT IdProdCat, concepto, NombreProducto, TipoProducto, tipo_movimiento 
              FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` 
              WHERE TipoProducto IN ('Servicio', 'SVA') AND Sistema = 'TCNET'
              ) catalogo 
  ON CAST(p.swProdReleaseId AS STRING) = catalogo.IdProdCat 
  LEFT JOIN ( SELECT p.SwInstProdId, p.swProdOrigId, p.swDateInstalled, p.swFechaDesinstalacion, p.swCopiaProdId, catalogo.concepto concepto_origen, catalogo.NombreProducto, catalogo.TipoProducto, catalogo.tipo_movimiento, 
      p.swCausaBaja, catalogo.idProdCat 
              FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p 
              INNER JOIN ( SELECT IdProdCat, concepto, NombreProducto, TipoProducto, tipo_movimiento, 
            FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` 
            WHERE UPPER(TipoProducto) IN ('SERVICIO', 'SVA') AND Sistema = 'TCNET'
              ) catalogo ON CAST(p.swProdReleaseId AS STRING) = catalogo.IdProdCat 
              WHERE swCopiaProdId IS NOT NULL
  ) origen ON p.swProdOrigId = origen.SwInstProdId 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` subcanal ON p.swChnlPartnerId = subcanal.swChnlPartnerId 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` canal ON canal.swChnlPartnerId = subcanal.swChnlPartnerCtralId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe ON p.swPedId = pe.swPersonalId 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_t_30_maestro_canal` tc ON tc.canal_id = p.swChnlPartnerId AND tc.agente_alta_id = REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` ca1 ON tc.canal_agrupado1_id = ca1.canal_agrupado1_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` ca2 ON tc.canal_agrupado2_id = ca2.canal_agrupado2_id 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON tc.subcanal_id = sc.subcanal_id 
  WHERE DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT 
  AND (p.swFechaDesinstalacion IS NULL OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT) --AND ( p.swMarcaCartera IS NULL OR p.swMarcaCartera = 'CARTERA') 
  AND TRIM(c.swSegmento) IN ('SOHO', 'Residencial') AND p.swCreatedBy NOT IN ('AltaMasiva', 'REPO_JUNIO_2022'); 


--- PASO 2: CREO TABLA KRT_CARTERA.EVENTOS_CARTERA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS
  SELECT DISTINCT 'TELECABLE' marca_ds, CAST(swProdReleaseId AS STRING) IdCatalogo, NombreProducto, nombre_distribuidor, Canal, subcanal, distribuidor agente, IdFijo, CAST(swAntiguedad AS Date) Antiguedad, swNIE DNI_CIF, swMarcaCartera Marca_Cartera, CAST(swDateInstalled AS Date) Fecha_Activacion, CAST(swDateCreated AS Date) Fecha_Creacion, TRIM(swSegmento) Segmento, swSubsegmento Subsegmento, 
  idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoProductoOrigen, subTipoProductoOrigen, TipoMovimiento, 
  TipoProducto, subTipoProducto, swInstProdId IdProducto, CAST(NULL AS STRING) Contrato, swCreatedBy UsuarioCreador, swCreatedBy agente_creador_id, concepto_ds, concepto_origen_ds, CAST(NULL AS STRING) as medio_conocimiento
  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_PREVIO`
  WHERE swCausaBaja IS NULL OR swCausaBaja NOT IN ('Cambio de Segmento', 'Cambio de Domicilio', 'Cambio de Titular', 'Cambio Domicilio'); --AND (concepto_origen_ds IS NULL OR concepto_ds <> concepto_origen_ds); 




  --- PASO 3: VUELCO REGISTROS A TABLA DE LOG
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA` AS
  SELECT *
  FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`; 
  END