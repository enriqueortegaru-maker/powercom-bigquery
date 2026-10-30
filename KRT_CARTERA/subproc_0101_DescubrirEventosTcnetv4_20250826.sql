BEGIN

  --CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv4`(20250201,20250228)

  DECLARE DESDE_DT, HASTA_DT date;
  --LOCAL 
  --DECLARE DESDE, HASTA INT64; SET DESDE=20250201;SET HASTA=20250228;
  SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
  SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );  



  -- =========================================================
  -- CTE 1: Servicios Activos y Migrados
  -- =========================================================
  --- PASO 1: CREO TABLA KRT_CARTERA.EVENTOS_CARTERA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT_Y_MIG` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS   
  with servicios as (

    with catalogo as (
        SELECT IdProdCat, concepto, NombreProducto, TipoProducto, tipo_movimiento 
        FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` 
         WHERE TipoProducto IN ('Servicio', 'SVA') AND Sistema = 'TCNET'
    ), Origen as (

        WITH catalogo as (
            SELECT IdProdCat, concepto, NombreProducto, TipoProducto, tipo_movimiento, 
            FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` 
            WHERE UPPER(TipoProducto) IN ('SERVICIO', 'SVA') AND Sistema = 'TCNET'
        )

        SELECT p.SwInstProdId, p.swProdOrigId, p.swDateInstalled, p.swFechaDesinstalacion, p.swCopiaProdId, 
        p.swMasterInstProdId,
        catalogo.concepto concepto_origen, catalogo.NombreProducto, catalogo.TipoProducto, catalogo.tipo_movimiento, 
        p.swCausaBaja, 
        catalogo.idProdCat 
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p 
        INNER JOIN catalogo ON CAST(p.swProdReleaseId AS STRING) = catalogo.IdProdCat 
        --- INTRODUZCO CONDICION TEMPORAL SOBRE  PRODUCTO ORIGEN
        WHERE DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT
        --- FIN CONDICION TEMPORAL           
        --- ELIMINO CONDICION QUE EXCLUYE MIGRADOS            
        --WHERE swCopiaProdId IS NOT NULL
        ---- FIN ELIMINACION           
    )

    SELECT p.swProdReleaseId, 
    catalogo.NombreProducto, 
    ca1.canal_agrupado1_ds Canal, 
    sc.subcanal_ds subcanal, 
    pe.swNombreComercial distribuidor, 
    CAST(p.swCustomerId AS INT64) IdFijo, 
    c.swAntiguedad, 
    c.swNIE, 
    p.swMarcaCartera, 
    p.swDateInstalled, 

--- INSERTO FECHA DESINSTALACION          
    p.swFechaDesinstalacion FECHA_DESINSTALACION,
--- FIN INSERCCION  

    TRIM(c.swSegmento) swSegmento, 
    c.swSubsegmento, 
    CAST(origen.idProdCat AS STRING) idCatalogoOrigen, 
    CAST(origen.SwInstProdId AS INT64) IdProductoOrigen, 
    origen.NombreProducto NombreProductoOrigen,  
    origen.TipoProducto as TipoProductoOrigen, 
    origen.Tipo_Movimiento as subTipoProductoOrigen,

  --- INSERTO CADENA ORIGEN         
    origen.swMasterInstProdId as MasterInstProdIdProductoOrigen,
    origen.swProdOrigId as ProdOrigIdProductoOrigen,
    origen.swCopiaProdId as CopiaProdIdProductoOrigen,
  --- FIN INSERCCION

  --- INSERTO FECHA ACTIVACION Y DESINSTALACION ORIGEN  
    origen.swDateInstalled FECHA_ACTIVACION_ORIGEN,
    origen.swFechaDesinstalacion FECHA_DESINSTALACION_ORIGEN,
  --- FIN INSERCCION

    CONCAT(CASE WHEN origen.concepto_origen IS NULL THEN 'Alta ' ELSE  'Cambio ' END , catalogo.tipo_movimiento) TipoMovimiento, 
    catalogo.TipoProducto,
    catalogo.tipo_movimiento as subTipoProducto,
    CAST(p.swInstProdId AS INT64) swInstProdId, 
    p.swCreatedBy, 
    origen.swCausaBaja, 
    p.swDateCreated, 
    p.swChnlPartnerId canalId,  
    pe.swNombre, 
    canal.swCoInterno nombre_distribuidor, 
    catalogo.concepto concepto_ds, 
    origen.concepto_origen concepto_origen_ds 
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p 
    INNER JOIN catalogo 
    ON CAST(p.swProdReleaseId AS STRING) = catalogo.IdProdCat 
    LEFT JOIN  origen ON p.swProdOrigId = origen.SwInstProdId 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` subcanal ON p.swChnlPartnerId = subcanal.swChnlPartnerId 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` canal ON canal.swChnlPartnerId = subcanal.swChnlPartnerCtralId
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe ON p.swPedId = pe.swPersonalId 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_t_30_maestro_canal` tc ON tc.canal_id = p.swChnlPartnerId AND tc.agente_alta_id = REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` ca1 ON tc.canal_agrupado1_id = ca1.canal_agrupado1_id
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` ca2 ON tc.canal_agrupado2_id = ca2.canal_agrupado2_id 
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON tc.subcanal_id = sc.subcanal_id 
    WHERE DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT 
  --- ELIMINO CONDICION QUE EXCLUYE MIGRADOS            
    --AND (p.swFechaDesinstalacion IS NULL OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT) --AND ( p.swMarcaCartera IS NULL OR p.swMarcaCartera = 'CARTERA') 
  --- FIN ELIMINACION             
    AND TRIM(c.swSegmento) IN ('SOHO', 'Residencial') 
    AND coalesce(p.swCreatedBy,"NO INFORMADO" ) NOT IN ('AltaMasiva', 'REPO_JUNIO_2022')    
  ) select distinct *
  from servicios
  where swCausaBaja IS NULL OR swCausaBaja NOT IN ('Cambio de Segmento', 'Cambio de Domicilio', 'Cambio de Titular', 'Cambio Domicilio');


  -- =========================================================
  -- CTE 2: Eventos Activos del Mes (sin migraciones ni bajas)
  -- =========================================================

  --- Productos activados en mes de comisionado y no migrados ni desactivados
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT`  
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT_Y_MIG` 
  WHERE  IdProductoOrigen is null 
  AND (Fecha_Desinstalacion IS NULL OR DATE_TRUNC(CAST (Fecha_Desinstalacion AS DATE), DAY) > HASTA_DT) ;



  -- =========================================================
  -- CTE 3: Migraciones en el mismo mes
  -- =========================================================

  --- Productos activados y migrados en mes de comisionado, y cuyo destino permanece activo
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_MISMO_MES` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT_Y_MIG` 
  WHERE  IdProductoOrigen is not null 
  AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) >= DESDE_DT
  AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) <= HASTA_DT
  AND MasterInstProdIdProductoOrigen is null
  AND fecha_desinstalacion is null; 



  -- =========================================================
  -- CTE 4: Migraciones resto (excluye activas y mismo mes)
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT_Y_MIG` t
  where not exists (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT` a
    where a.idFijo=t.idFijo
    and a.swInstProdId=t.swInstProdId
  ) and not exists (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_MISMO_MES` a
    where a.idFijo=t.idFijo
    and a.swInstProdId=t.swInstProdId
  );


  -- =========================================================
  -- CTE 5: Migraciones resto activas
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO_ACT` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO` t
  WHERE(t.fecha_desinstalacion IS NULL OR DATE_TRUNC(CAST (t.fecha_desinstalacion AS DATE), DAY) > HASTA_DT);


  -- =========================================================
  -- CTE 8: Migraciones resto no activas
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO_NOACT` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO` t
  WHERE not exists (
      select 1 
      from `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO_ACT` a
      where a.idFijo=t.idFijo
      and a.swInstProdId=t.swInstProdId
  );


  -- =========================================================
  -- CTE 9: Apuntes Migraciones mismo mes
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_APUNTES_MIG_MISMO_MES` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  select 
  f.swProdReleaseId as CatalogoId, 
  f.NombreProducto, 
  i.canal, 
  i.subcanal, 
  i.distribuidor , 
  f.idFijo, 
  i.swAntiguedad,   
  i.swNIE, 
  i.swMarcaCartera, 
  i.swDateInstalled Fecha_Activacion, 
--- INSERTO FECHA DESINSTALACION          
  f.FECHA_DESINSTALACION,
--- FIN INSERCCION          
  i.swSegmento, 
  i.swsubsegmento, 
  CAST(i.swProdReleaseId AS STRING) as idCatalogoOrigen, 
  CAST(i.swInstProdId AS INT64) IdProductoOrigen, 
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
  f.swInstProdId, 
  i.swCreatedBy, 
  f.swCausaBaja, 
  i.swDateCreated,   
  i.canalId,
  i.swNombre,
  i.nombre_distribuidor, 
  f.concepto_ds,   
  i.concepto_ds as concepto_origen_ds,  
  from `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_MISMO_MES` f  
  left join `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT_Y_MIG` i on f.idFijo= i.idFijo and f.idProductoOrigen=i.swInstProdId;  


  -- =========================================================
  -- CTE 10: Crear fichero incremental final
  -- =========================================================

  --- PASO 3 CREO TABLA DE LOG
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_INCR` AS
  SELECT *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
  FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_ACT`
  UNION ALL 
  SELECT *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
  FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_APUNTES_MIG_MISMO_MES`
  UNION ALL 
  SELECT *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
  FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_MIG_RESTO_ACT`;


  -- ==========================================================
  -- OUT 1: Crear tabla final consolidada
  -- ==========================================================

--- PASO 4: CREO TABLA KRT_CARTERA.EVENTOS_CARTERA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS
  SELECT DISTINCT 'TELECABLE' marca_ds, 
  CAST(swProdReleaseId AS STRING) IdCatalogo, 
  NombreProducto, 
  nombre_distribuidor, 
  Canal, 
  subcanal, 
  distribuidor agente, 
  IdFijo, 
  CAST(swAntiguedad AS Date) Antiguedad, 
  swNIE DNI_CIF, 
  swMarcaCartera Marca_Cartera, 
  CAST(swDateInstalled AS Date) Fecha_Activacion, 
  CAST(swDateCreated AS Date) Fecha_Creacion, 
  TRIM(swSegmento) Segmento, 
  swSubsegmento Subsegmento, 
  idCatalogoOrigen, 
  IdProductoOrigen, 
  NombreProductoOrigen, 
  TipoProductoOrigen, 
  subTipoProductoOrigen, 
  TipoMovimiento, 
  TipoProducto, 
  subTipoProducto, 
  swInstProdId IdProducto, 
  CAST(NULL AS STRING) Contrato, 
  swCreatedBy UsuarioCreador, 
  swCreatedBy agente_creador_id, 
  concepto_ds, 
  concepto_origen_ds, 
  CAST(NULL AS STRING) as medio_conocimiento
  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA_TCNET_INCR`
  WHERE swCausaBaja IS NULL OR swCausaBaja NOT IN ('Cambio de Segmento', 'Cambio de Domicilio', 'Cambio de Titular', 'Cambio Domicilio'); --AND (concepto_origen_ds IS NULL OR concepto_ds <> concepto_origen_ds); 


  -- ==========================================================
  -- OUT 2: Crear tabla log de incremental de procedimiento
  -- ==========================================================

  --- PASO 5 CREO TABLA DE LOG
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0101_EVENTOS_CARTERA` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS   
  SELECT *
  FROM  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;

  END