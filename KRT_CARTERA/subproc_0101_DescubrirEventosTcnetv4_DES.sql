BEGIN

  --CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv4`(20250201,20250228)

  DECLARE DESDE_DT DATE;
  DECLARE HASTA_DT DATE;
  --DECLARE DESDE, HASTA INT64; SET DESDE=20250801;SET HASTA=20250831;
  SET DESDE_DT = PARSE_DATE('%Y%m%d', CAST(DESDE AS STRING));
  SET HASTA_DT = PARSE_DATE('%Y%m%d', CAST(HASTA AS STRING));

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS   
  WITH catalogo AS (
      SELECT IdProdCat, concepto, NombreProducto, TipoProducto, tipo_movimiento
      FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`
      WHERE UPPER(TipoProducto) IN ('SERVICIO', 'SVA') 
        AND Sistema = 'TCNET'
  ),

  origen AS (
      SELECT 
          p.SwInstProdId,
          p.swProdOrigId,
          p.swDateInstalled,
          p.swFechaDesinstalacion,
          p.swCopiaProdId,
          p.swMasterInstProdId,
          c.concepto concepto_origen,
          c.NombreProducto,
          c.TipoProducto,
          c.tipo_movimiento,
          p.swCausaBaja,
          c.idProdCat
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
      INNER JOIN catalogo c 
          ON CAST(p.swProdReleaseId AS STRING) = c.IdProdCat
      WHERE DATE_TRUNC(CAST(p.swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT
  ),

  servicios AS (
      SELECT 
          p.swProdReleaseId,
          c.NombreProducto,
          ca1.canal_agrupado1_ds Canal,
          sc.subcanal_ds subcanal,
          pe.swNombreComercial distribuidor,
          CAST(p.swCustomerId AS INT64) IdFijo,
          cli.swAntiguedad,
          cli.swNIE,
          p.swMarcaCartera,
          p.swDateInstalled,
          p.swFechaDesinstalacion FECHA_DESINSTALACION,
          TRIM(cli.swSegmento) swSegmento,
          cli.swSubsegmento,
          CAST(o.idProdCat AS STRING) idCatalogoOrigen,
          CAST(o.SwInstProdId AS INT64) IdProductoOrigen,
          o.NombreProducto NombreProductoOrigen,
          o.TipoProducto TipoProductoOrigen,
          o.tipo_movimiento subTipoProductoOrigen,
          o.swMasterInstProdId MasterInstProdIdProductoOrigen,
          o.swProdOrigId ProdOrigIdProductoOrigen,
          o.swCopiaProdId CopiaProdIdProductoOrigen,
          o.swDateInstalled FECHA_ACTIVACION_ORIGEN,
          o.swFechaDesinstalacion FECHA_DESINSTALACION_ORIGEN,
          CONCAT(CASE WHEN o.concepto_origen IS NULL THEN 'Alta ' ELSE 'Cambio ' END, c.tipo_movimiento) TipoMovimiento,
          c.TipoProducto,
          c.tipo_movimiento subTipoProducto,
          CAST(p.swInstProdId AS INT64) swInstProdId,
          p.swCreatedBy,
          o.swCausaBaja,
          p.swDateCreated,
          p.swChnlPartnerId canalId,
          pe.swNombre,
          canal.swCoInterno nombre_distribuidor,
          c.concepto concepto_ds,
          o.concepto_origen concepto_origen_ds
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
      INNER JOIN catalogo c 
          ON CAST(p.swProdReleaseId AS STRING) = c.IdProdCat
      LEFT JOIN origen o 
          ON p.swProdOrigId = o.SwInstProdId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` subcanal
          ON p.swChnlPartnerId = subcanal.swChnlPartnerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` canal
          ON canal.swChnlPartnerId = subcanal.swChnlPartnerCtralId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe
          ON p.swPedId = pe.swPersonalId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cli
          ON p.swCustomerId = cli.swCustomerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_t_30_maestro_canal` tc
          ON tc.canal_id = p.swChnlPartnerId
          AND tc.agente_alta_id = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(pe.swNombre),'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` ca1
          ON tc.canal_agrupado1_id = ca1.canal_agrupado1_id
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
          ON tc.subcanal_id = sc.subcanal_id
      WHERE DATE_TRUNC(CAST(p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT
          AND TRIM(cli.swSegmento) IN ('SOHO', 'Residencial')
          AND COALESCE(p.swCreatedBy,"NO INFORMADO") NOT IN ('AltaMasiva', 'REPO_JUNIO_2022')
  ),

  -- 4. Filtramos los servicios válidos como eventos
  eventos AS (
      SELECT *
      FROM servicios
      WHERE swCausaBaja IS NULL 
        OR swCausaBaja NOT IN ('Cambio de Segmento', 'Cambio de Domicilio', 'Cambio de Titular', 'Cambio Domicilio')
  ),


  -- 5. Servicios activados en mes de comisionado y no migrados ni desactivados

  eventos_act_nomig AS (
      select distinct *
      FROM eventos 
      WHERE  IdProductoOrigen is null 
      AND (Fecha_Desinstalacion IS NULL OR DATE_TRUNC(CAST (Fecha_Desinstalacion AS DATE), DAY) > HASTA_DT)

  ),

  -- 6. Servicios activados y migrados en mes de comisionado, con origen activo en mes de comisionado y destino permanece activo

  eventos_act_mig_or_mismo_mes_dest_activo AS (
    SELECT distinct * 
    FROM eventos  
    WHERE  IdProductoOrigen is not null 
    AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) >= DESDE_DT
    AND DATE_TRUNC(CAST (Fecha_Activacion_Origen AS DATE), DAY) <= HASTA_DT
    AND MasterInstProdIdProductoOrigen is null
    AND fecha_desinstalacion is null 
  ),

  -- 7. Servicios activados y migrados en mes de comisionado, con origen activo en mes previo a mes de comisionado y cuyo destino permanece activo
  eventos_act_mig_or_otro_mes_dest_activo AS (
      SELECT distinct * 
      FROM eventos s 
      where not exists (
          select 1 
          from eventos_act_nomig a
          where a.idFijo=s.idFijo
          and a.swInstProdId=s.swInstProdId
      ) and not exists (
          select 1 
          from  eventos_act_mig_or_mismo_mes_dest_activo a
          where a.idFijo=s.idFijo
          and a.swInstProdId=s.swInstProdId
        
      ) and (s.fecha_desinstalacion IS NULL OR DATE_TRUNC(CAST (s.fecha_desinstalacion AS DATE), DAY) > HASTA_DT)
  ),

  -- 8. eventos a registrar de servicios activados y migrados en mes de comisionado, con origen activo en mes de comisionado y destino permanece activo
  apuntes_eventos_act_mig_or_mismo_mes_dest_activo AS (
    select distinct 
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
    from eventos_act_mig_or_mismo_mes_dest_activo f  
    left join servicios i on f.idFijo= i.idFijo and f.idProductoOrigen=i.swInstProdId  
  ), 

  -- 9. Poblacion completa de eventos descubiertos 

  eventos_descubiertos as (

    SELECT distinct *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
    FROM  eventos_act_nomig
    UNION ALL 
    SELECT distinct *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
    FROM  eventos_act_mig_or_otro_mes_dest_activo
    UNION ALL 
    SELECT distinct *  except(FECHA_DESINSTALACION, MasterInstProdIdProductoOrigen, ProdOrigIdProductoOrigen, CopiaProdIdProductoOrigen, FECHA_ACTIVACION_ORIGEN, FECHA_DESINSTALACION_ORIGEN)
    FROM  apuntes_eventos_act_mig_or_mismo_mes_dest_activo

  ),

  -- 10. Consolidamos los eventos finales
  eventos_finales AS (
      SELECT DISTINCT
          'TELECABLE' AS marca_ds,
          CAST(swProdReleaseId AS STRING) AS IdCatalogo,
          NombreProducto,
          nombre_distribuidor,
          Canal,
          Subcanal,
          Distribuidor AS agente,
          IdFijo,
          CAST(swAntiguedad AS DATE) AS Antiguedad,
          swNIE AS DNI_CIF,
          swMarcaCartera AS Marca_Cartera,
          CAST(swDateInstalled AS DATE) AS Fecha_Activacion,
          CAST(swDateCreated AS DATE) AS Fecha_Creacion,
          TRIM(swSegmento) AS Segmento,
          swSubsegmento AS Subsegmento,
          idCatalogoOrigen,
          IdProductoOrigen,
          NombreProductoOrigen,
          TipoProductoOrigen,
          subTipoProductoOrigen,
          TipoMovimiento,
          TipoProducto,
          subTipoProducto,
          swInstProdId AS IdProducto,
          CAST(NULL AS STRING) AS Contrato,
          swCreatedBy AS UsuarioCreador,
          swCreatedBy AS agente_creador_id,
          concepto_ds,
          concepto_origen_ds,
          CAST(NULL AS STRING) AS medio_conocimiento
      FROM eventos_descubiertos 
      WHERE swCausaBaja IS NULL 
        OR swCausaBaja NOT IN (
              'Cambio de Segmento',
              'Cambio de Domicilio',
              'Cambio de Titular',
              'Cambio Domicilio'
          )
  )

  -- Resultado final
  SELECT * FROM eventos_finales;



  END