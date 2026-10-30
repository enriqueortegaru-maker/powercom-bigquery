BEGIN

---- IMPORTANTE REVISAR USUARIO CREADOR YA QEU NO ES ES EL USUARIO QUE CREA EL PRODUCTO EN EKTNET

DECLARE
  DESDE_DT,
  HASTA_DT date;
SET
  HASTA_DT = parse_date ('%Y%m%d',
    CAST ( HASTA AS string) );
SET
  DESDE_DT = parse_date ('%Y%m%d',
    CAST ( DESDE AS string) ); --- PASO 1 INSERTO REGISTROS EN TABLA DE EVENTOS_CARTERA_EKTNET
INSERT INTO
  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`
SELECT
  DISTINCT *
FROM (
  SELECT
    mmMarcaDesc,
    CAST(a.IdCatalogo AS STRING) CatalogoId,
    a.NombreProducto,
    a.des_canal_dis canal,
    a.des_subcanal_dis subcanal,
    a.des_distribuidor agente,
    CAST( a.swCustomerId AS INT64) CLIENTE_ID,
    CAST(a.swAntiguedad AS Date) ANTIGUEDAD,
    a.swNIE,
    a.marcaCartera,
    a.concepto_ds,
    CAST(a.swDateInstalled AS Date) FECHA_aCTIVACION,
    CAST(a.swDateCreated AS Date) FECHA_CREACION,
    TRIM(a.swSegmento),
    a.swSegmento subsegmento,
    CAST(a.idCatalogoOrigen AS STRING) CatalogoIdOrigen,
    CAST(a.IdProductoOrigen AS INT64) ProductoIdOrigen,
    a.NombreProductoOrigen,
    a.TipoMovimiento,
    CAST(a.swInstProdId AS INT64) productoId,
    CAST(a.cod_contrato AS STRING) contrato,
    usuarioCreador,
    agente_creador_id,
    canalId,
    swCOInterno,
    swName nombre_distribuidor,
    filtroTerminales,
    swInstProdIdOrigen,
    swProdOrigId ProdOrigen,
    swCausaBaja,
    NULL concepto_origen_ds,
    CAST(NULL AS STRING) medio_conocimiento
  FROM (
    SELECT
      CASE mmMarcaDesc
        WHEN 'Euskaltel' THEN 'EUSKALTEL'
        WHEN 'Virgin Telco' THEN 'VIRGIN'
        WHEN 'RACCTEL+' THEN 'RACC'
        WHEN 'Telecable' THEN 'TELECABLE'
    END
      mmMarcaDesc,
      p.swProdReleaseId IdCatalogo,
      CASE
        WHEN catalogo.TipoProducto = 'terminal' THEN cc.swCaractValor
      ELSE
      p.swReleaseName
    END
      NombreProducto,
      c1.canal_agrupado1_ds des_canal_dis,
      sc.subcanal_ds des_subcanal_dis,
      CASE
        WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS' THEN pe.swNombre
      ELSE
      ca.swVerticalFocus
    END
      des_distribuidor,
      cl.swCustomerId,
      cp.swMarcaCartera,
      cl.swNIE,
      '1900-01-01' swAntiguedad,
      cp.swMarcaCartera marcaCartera,
      ct.modelo,
      CASE
        WHEN ct.modelo IS NOT NULL THEN ct.concepto_ds
      ELSE
      catalogo.concepto
    END
      concepto_ds,
      cp.swDateInstalled,
      cp.swDateCreated,
      TRIM(cl.swSegmento) swSegmento,
      /*swSubsegmento,*/ pOrigen.swProdReleaseId idCatalogoOrigen,
      cpOrigen.swInstProdId IdProductoOrigen,
      pOrigen.swReleaseName NombreProductoOrigen,
      CONCAT(CASE
          WHEN cpOrigen.swInstProdId IS NULL OR filtroMes = 1 OR (cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) OR UPPER(catalogo.TipoProducto) = 'TERMINAL' THEN 'Alta '
        ELSE
        'Cambio '
      END
        , catalogo.tipo_movimiento) TipoMovimiento,
      cp.swInstProdId,
      NULL cod_contrato,
      CASE
        WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN cp.swCreatedBy
      ELSE
      coalesce(pe.swNombre,
        cp.swCreatedBy)
    END
      usuarioCreador,
      cp.swCreatedBy agente_creador_id,
      coOrigen2.swCausaBaja,
      CASE
        WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS'THEN cp.swCreatedBy
      ELSE
      coalesce(pe.swNombre,
        cp.swCreatedBy)
    END
      swCreatedBy,
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
    FROM (
      SELECT
        *
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
      WHERE
        DATE_TRUNC(CAST(swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
        AND HASTA_DT
        AND (swFechaDesinstalacion IS NULL
          OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )) cp
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
    ON
      cp.swCustomerId = cl.swCustomerId
    INNER JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m
    ON
      m.mmMarcaId = cl.mmMarcaId
    INNER JOIN
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo
    ON
      CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat
      AND sistema = 'EKTNET'
      AND UPPER(tipoProducto) IN ( 'TERMINAL')
      AND catalogo.marca_ds =
      CASE m.mmMarcaDesc
        WHEN 'Euskaltel' THEN 'EUSKALTEL'
        WHEN 'Virgin Telco' THEN 'VIRGIN'
        WHEN 'RACCTEL+' THEN 'RACC'
        WHEN 'Telecable' THEN 'TELECABLE'
    END
      AND UPPER(catalogo.marca_ds) <> 'TELECABLE'
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc
    ON
      cp.swInstProdId = cc.swInstProdId
      AND cc.swCaractName = 'Modelo'
    LEFT JOIN
      `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES` ct
    ON
      UPPER(cc.swCaractValor) = UPPER(ct.modelo)
      AND UPPER(ct.marca_ds) = UPPER(CASE m.mmMarcaDesc
          WHEN 'Euskaltel' THEN 'EUSKALTEL'
          WHEN 'Virgin Telco' THEN 'VIRGIN'
          WHEN 'RACCTEL+' THEN 'RACC'
          WHEN 'Telecable' THEN 'TELECABLE'
      END
        )
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` p
    ON
      cp.swProdReleaseId = p.swProdReleaseId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
    ON
      ca.swChnlPartnerId =cp.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c
    ON
      c.canal_id = cp.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1
    ON
      c.canal_agrupado1_id = c1.canal_agrupado1_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2
    ON
      c.canal_agrupado2_id = c2.canal_agrupado2_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
    ON
      c.subcanal_id = sc.subcanal_id
    LEFT JOIN (
      SELECT
        swCustomerId,
        MIN(swDateInstalled) FechaActivacion
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
      WHERE
        swStatus = 'Activo'
      GROUP BY
        1) pActivos
    ON
      pActivos.swCustomerId = cp.swCustomerId
    LEFT JOIN (
      SELECT
        swCustomerId,
        MAX(swFechaDesinstalacion) fechaUltimaBaja
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
      WHERE
        swStatus = 'Inactivo'
      GROUP BY
        1) pInactivoson
    ON
      pInactivoson.swCustomerId = cp.swCustomerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
    ON
      pe.swPersonalId= cp.swProviderGrpId
      AND pe.swObjectType='CHANNEL_PARTNER'
    LEFT JOIN (
      SELECT
        cp.*,
        catalogo.*,
        CASE
          WHEN (UPPER(TipoProducto) = 'TERMINAL' AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) THEN 1
          WHEN UPPER(TipoProducto) <> 'TERMINAL'
        AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) < HASTA_DT THEN 1
        ELSE
        0
      END
        filtroTerminales,
        CASE
          WHEN coalesce(CAST(pp.swDateInstalled AS DATE), CAST(cp.swDateInstalled AS DATE)) > DESDE_DT THEN 1
        ELSE
        0
      END
        FiltroMes
      FROM (
        SELECT
          *
        FROM
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
        WHERE
          DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT /*and DATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < DESDE*/) cp
      INNER JOIN
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
      ON
        cp.swCustomerId = cl.swCustomerId
      INNER JOIN
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m
      ON
        m.mmMarcaId = cl.mmMarcaId
      LEFT JOIN
        `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo
      ON
        CAST(cp.swProdReleaseId AS String) = catalogo.IdProdCat
        AND sistema = 'EKTNET'
        AND UPPER(TipoProducto) NOT IN ('TERMINAL')
        AND UPPER(CASE m.mmMarcaDesc
            WHEN 'Euskaltel' THEN 'EUSKALTEL'
            WHEN 'Virgin Telco' THEN 'VIRGIN'
            WHEN 'RACCTEL+' THEN 'RACC'
            WHEN 'Telecable' THEN 'TELECABLE'
        END
          ) = UPPER(catalogo.marca_ds)
        AND UPPER(catalogo.marca_ds) <> 'TELECABLE'
      LEFT JOIN
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` pp
      ON
        cp.swMasterInstProdId = pp.swInstProdId 
      --WHERE catalogo.IdProdCat <> 951
    ) cpOrigen
    ON
      cp.swMasterInstProdId= cpOrigen.swInstProdId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` coOrigen2
    ON
      coOrigen2.swInstProdId = cp.SwProdOrigId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` pOrigen
    ON
      cpOrigen.swProdReleaseId = pOrigen.swProdReleaseId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente_sgto_canal` s
    ON
      s.swCustomerId = cl.swCustomerId
    WHERE
      (cpOrigen.filtroTerminales = 1
        OR cp.swMasterInstProdId IS NULL)
      AND (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",
          'TC_MIGRA_MOV_202101',
          'REPO_DATOS',
          'MIGRAMASHFC_FTTH',
          'EKT_MIGRA_202206',
          'REPO_JUNIO_2022',
          'EKT_MIGRA_202212')
--          'MIG TV EKT 2023',
--          'MIG TV RACC 2023')
        --AND UPPER(cp.swCreatedBy) NOT LIKE 'IBSWP%'
        ) 
    ) a
  WHERE
    (swCausaBaja NOT IN ('Cambio de Segmento',
        'Cambio de domicilio',
        'Cambio de Titular' )
      OR swCausaBaja IS NULL)
    AND (a.swCreatedBy NOT IN ("MIGRACIONTMK",
        'TC_MIGRA_MOV_202101',
        'REPO_DATOS',
        'MIGRAMASHFC_FTTH',
        'EKT_MIGRA_202206',
        'REPO_JUNIO_2022',
        'EKT_MIGRA_202212')
--        'MIG TV EKT 2023',
--        'MIG TV RACC 2023')
      --AND a.swCreatedBy NOT LIKE 'IBSWP%'
    )
    AND TRIM(UPPER(a.swSegmento)) IN ('RESIDENCIAL',
      'SOHO',
      'PYME')
  UNION ALL
  SELECT
    mmMarcaDesc,
    CAST(a.IdCatalogo AS STRING) CatalogoId,
    a.NombreProducto,
    a.des_canal_dis canal,
    a.des_subcanal_dis subcanal,
    a.des_distribuidor agente,
    CAST( a.swCustomerId AS INT64) CLIENTE_ID,
    CAST(a.swAntiguedad AS Date) ANTIGUEDAD,
    a.swNIE,
    a.marcaCartera,
    a.concepto_ds,
    CAST(a.swDateInstalled AS Date) FECHA_aCTIVACION,
    CAST(a.swDateCreated AS Date) FECHA_CREACION,
    TRIM(a.swSegmento),
    a.swSegmento subsegmento,
    CAST(a.idCatalogoOrigen AS STRING) CatalogoIdOrigen,
    CAST(a.IdProductoOrigen AS INT64) ProductoIdOrigen,
    a.NombreProductoOrigen,
    a.TipoMovimiento,
    CAST(a.swInstProdId AS INT64) productoId,
    CAST(a.cod_contrato AS STRING) contrato,
    usuarioCreador,
    agente_creador_id,
    canalId,
    swCOInterno,
    swName nombre_distribuidor,
    filtroTerminales,
    swInstProdIdOrigen,
    swProdOrigId ProdOrigen,
    swCausaBaja,
    concepto_origen_ds,
    NULL medio_conocimiento
  FROM (
    SELECT
      CASE mmMarcaDesc
        WHEN 'Euskaltel' THEN 'EUSKALTEL'
        WHEN 'Virgin Telco' THEN 'VIRGIN'
        WHEN 'RACCTEL+' THEN 'RACC'
        WHEN 'Telecable' THEN 'TELECABLE'
    END
      mmMarcaDesc,
      p.swProdReleaseId IdCatalogo,
      p.swReleaseName NombreProducto,
      c1.canal_agrupado1_ds des_canal_dis,
      sc.subcanal_ds des_subcanal_dis,
      CASE
        WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA'AND sc.subcanal_ds <> 'STANDS'THEN pe.swNombre
      ELSE
      ca.swVerticalFocus
    END
      des_distribuidor,
      cl.swCustomerId,
      cp.swMarcaCartera,
      cl.swNIE,
      '1900-01-01' swAntiguedad,
      cp.swMarcaCartera marcaCartera,
      catalogo.concepto concepto_ds,
      cp.swDateInstalled,
      cp.swDateCreated,
      TRIM(cl.swSegmento) swSegmento,
      pOrigen.swProdReleaseId idCatalogoOrigen,
      cpOrigen.swInstProdId IdProductoOrigen,
      CASE WHEN(cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) OR filtromes = 1 THEN NULL
      ELSE
      pOrigen.swReleaseName
    END
      NombreProductoOrigen,
      CONCAT(CASE
          WHEN cpOrigen.swInstProdId IS NULL OR (cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) OR filtroMes = 1 THEN 'Alta '
        ELSE
        'Cambio '
      END
        , catalogo.tipo_movimiento) TipoMovimiento,
      cp.swInstProdId,
      NULL cod_contrato,
      CASE
        WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN coalesce(pe.swNombre, cp.swCreatedBy)
      ELSE
      pe.swNombre
    END
      usuarioCreador,
      cp.swCreatedBy agente_creador_id,
      cpOrigen.swCausaBaja,
      CASE
        WHEN c1.canal_agrupado1_ds <> 'PUNTO DE VENTA' AND sc.subcanal_ds <> 'STANDS' THEN coalesce(pe.swNombre, cp.swCreatedBy)
      ELSE
      pe.swNombre
    END
      swCreatedBy,
      cl.mmMarcaId,
      ca.swChnlPartnerId canalId,
      ca.swCOInterno,
      ca.swVerticalFocus,
      ca.swChnlPartnerId,
      ca.swName,
      cpOrigen.filtroTerminales,
      cpOrigen.swInstProdId swInstProdIdOrigen,
      cp.swProdOrigId,
      CASE WHEN( cpOrigen.IdProdCat = '951' AND p.swProdReleaseId <> 951) OR filtromes = 1 THEN NULL
      ELSE
      cpOrigen.concepto
    END
      concepto_origen_ds,
    FROM (
      SELECT
        *
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
      WHERE
        DATE_TRUNC(CAST(swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
        AND HASTA_DT
        AND (swFechaDesinstalacion IS NULL
          OR DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) > HASTA_DT ) ) cp
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
    ON
      cp.swCustomerId = cl.swCustomerId
    INNER JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m
    ON
      m.mmMarcaId = cl.mmMarcaId
    INNER JOIN
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo
    ON
      CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat
      AND sistema = 'EKTNET'
      AND UPPER(tipoProducto) NOT IN ('TERMINAL')
      AND UPPER(catalogo.marca_ds) = UPPER(CASE m.mmMarcaDesc
          WHEN 'Euskaltel' THEN 'EUSKALTEL'
          WHEN 'Virgin Telco' THEN 'VIRGIN'
          WHEN 'RACCTEL+' THEN 'RACC'
          WHEN 'Telecable' THEN 'TELECABLE'
      END
        )
      AND UPPER(catalogo.marca_ds) <> 'TELECABLE'
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` p
    ON
      cp.swProdReleaseId = p.swProdReleaseId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
    ON
      ca.swChnlPartnerId =cp.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c
    ON
      c.canal_id = cp.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1
    ON
      c.canal_agrupado1_id = c1.canal_agrupado1_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2
    ON
      c.canal_agrupado2_id = c2.canal_agrupado2_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
    ON
      c.subcanal_id = sc.subcanal_id
    LEFT JOIN (
      SELECT
        swCustomerId,
        MIN(swDateInstalled) FechaActivacion
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
      WHERE
        swStatus = 'Activo'
      GROUP BY
        1) pActivos
    ON
      pActivos.swCustomerId = cp.swCustomerId
    LEFT JOIN (
      SELECT
        swCustomerId,
        MAX(swFechaDesinstalacion) fechaUltimaBaja
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
      WHERE
        swStatus = 'Inactivo'
      GROUP BY
        1) pInactivoson
    ON
      pInactivoson.swCustomerId = cp.swCustomerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
    ON
      pe.swPersonalId= cp.swProviderGrpId
      AND pe.swObjectType='CHANNEL_PARTNER'
    LEFT JOIN (
      SELECT
        cp.*,
        catalogo.*,
        CASE
          WHEN (UPPER(TipoProducto) = 'TERMINAL' AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) THEN 1
          WHEN UPPER(TipoProducto) <> 'TERMINAL'
        AND DATE_TRUNC(CAST (cp.swDateInstalled AS DATE), DAY) < HASTA_DT THEN 1
        ELSE
        0
      END
        filtroTerminales,
        CASE
          WHEN coalesce(CAST(pp.swDateInstalled AS DATE), CAST(cp.swDateInstalled AS DATE)) > DESDE_DT THEN 1
        ELSE
        0
      END
        FiltroMes
      FROM (
        SELECT
          *
        FROM
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
        WHERE
          DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT /*andDATE_TRUNC(CAST (swDateInstalled AS DATE), DAY) < DESDE*/ ) cp
      INNER JOIN
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
      ON
        cp.swCustomerId = cl.swCustomerId
      INNER JOIN
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m
      ON
        m.mmMarcaId = cl.mmMarcaId
      LEFT JOIN
        `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo
      ON
        CAST(cp.swProdReleaseId AS string) = catalogo.IdProdCat
        AND sistema = 'EKTNET'
        AND UPPER(TipoProducto) NOT IN ('TERMINAL')
        AND UPPER(CASE m.mmMarcaDesc
            WHEN 'Euskaltel' THEN 'EUSKALTEL'
            WHEN 'Virgin Telco' THEN 'VIRGIN'
            WHEN 'RACCTEL+' THEN 'RACC'
            WHEN 'Telecable' THEN 'TELECABLE'
        END
          ) = UPPER(catalogo.marca_ds)
        AND UPPER(catalogo.marca_ds) <> 'TELECABLE'
      LEFT JOIN
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` pp
      ON
        cp.swMasterInstProdId = pp.swInstProdId --
      --WHERE catalogo.IdProdCat <> 951 ----- AGRERGAR CAUSA DE BAJA PARA QUITAR LOS CAMBIOS DE DOMICILIO,TITULAR,CUENTA,ETC... 
    ) cpOrigen
    ON
      cp.swProdOrigId= cpOrigen.swInstProdId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` pOrigen
    ON
      cpOrigen.swProdReleaseId = pOrigen.swProdReleaseId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente_sgto_canal` s
    ON
      s.swCustomerId = cl.swCustomerId
    WHERE
      (cpOrigen.filtroTerminales = 1
        OR cpOrigen.swInstProdId IS NULL)
      AND (UPPER(cp.swCreatedBy) NOT IN ("MIGRACIONTMK",
          'TC_MIGRA_MOV_202101',
          'REPO_DATOS',
          'MIGRAMASHFC_FTTH',
          'EKT_MIGRA_202206',
          'REPO_JUNIO_2022',
          'EKT_MIGRA_202212')
--          'MIG TV EKT 2023',
--          'MIG TV RACC 2023')
        --AND UPPER(cp.swCreatedBy) NOT LIKE 'IBSWP%' 
        ) ) a
  WHERE
    (swCausaBaja NOT IN ('Cambio de Segmento',
        'Cambio de domicilio',
        'Cambio de Titular' )
      OR swCausaBaja IS NULL)
    AND (a.swCreatedBy NOT IN ("MIGRACIONTMK",
        'TC_MIGRA_MOV_202101',
        'REPO_DATOS',
        'MIGRAMASHFC_FTTH',
        'EKT_MIGRA_202206',
        'REPO_JUNIO_2022',
        'EKT_MIGRA_202212')
--        'MIG TV EKT 2023',
--        'MIG TV RACC 2023')
      --AND a.swCreatedBy NOT LIKE 'IBSWP%' 
      )
    AND TRIM(UPPER(a.swSegmento)) IN ('RESIDENCIAL',
      'SOHO',
      'PYME') ); 

--- PASO 2 CREO TABLA DE LOG
CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET` AS
SELECT
  *
FROM
  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;

END