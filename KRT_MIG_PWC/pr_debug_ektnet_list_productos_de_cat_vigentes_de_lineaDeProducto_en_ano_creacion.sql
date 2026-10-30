BEGIN
  -- DECLARE VANNO INT64;DECLARE VLINENAME STRING; SET VANNO=2025; SET VLINENAME="TELEVISION";
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.list_productos_de_cat_vigentes_de_lineaDeProducto_en_ano_creacion`   
  --OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE)) AS 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS   
    WITH RECURSIVE

    -- 1) catálogo filtrado (pre-procesado)
    cat_filtrado AS (
      SELECT DISTINCT
        FORMAT_DATE("%Y%m%d", swDateCreated) AS mesCreacionCatalogo,
        swTipologiaProducto, swLineType, swLineName, SwProductType, SwNivelProd,
        swProdReleaseId, swReleaseName, swFacturable, swEstado,
        swDateCreated  as swDateCreated_cat
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat`
      WHERE UPPER(TRIM(swLineName)) = UPPER(TRIM(vLineName))
      --AND EXTRACT(YEAR FROM swDateCreated) = vanno
      AND swEstado = "Vigente"

    ),

    -- 2) clientes que instancian productos de catálogos filtrados 
    cl_instancian_cat AS (
      SELECT distinct 
          p.swCustomerId,
          p.swProdReleaseId,
          cat.swTipologiaProducto,  cat.swLineType,  cat.swLineName,  cat.SwProductType,  cat.SwNivelProd,
          cat.swProdReleaseId,  cat.swReleaseName,  cat.swFacturable,  cat.swEstado,
          cat.swDateCreated_cat
    
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
      INNER JOIN cat_filtrado cat
        ON cat.swProdReleaseId = p.swProdReleaseId
      WHERE p.swStatus = "Activo"
      -- AND p.swCustomerId=7878408
    ),

    -- 4) conjunto base — raíces (nivel 1)
    base AS (
      SELECT distinct 
        p.swInstProdId AS idreg,
        1 AS lvl,
        p.swCustomerId,
        p.swAgreementId,
        p.swInstProdId,
        p.swProdReleaseId,
        p.swMasterInstProdId,
        p.swProdOrigId,
        p.swDateCreated,
        p.swDateInstalled,
        p.swFechaDesinstalacion,
        p.swParentInstProdId,
        CAST(NULL AS INT64) AS swProdReleaseIdParent,
        CAST(NULL AS STRING) AS swReleaseNameParent,
        p.swInstProdId AS swInstProdIdRoot,
        p.swProdReleaseId AS swProdReleaseIdRoot,
        cat.swReleaseName AS swReleaseNameRoot
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON cat.swProdReleaseId = p.swProdReleaseId

      inner join cl_instancian_cat using(swCustomerId)
      WHERE p.swParentInstProdId IS NULL
        AND p.swInstProdId IS NOT NULL    
    ),

    -- 5) término recursivo: expando hijos por swParentInstProdId
    rec AS (
      SELECT * FROM base

      UNION ALL

      SELECT
        r.idreg,
        r.lvl + 1 AS lvl,
        ph.swCustomerId,
        ph.swAgreementId,
        ph.swInstProdId,
        ph.swProdReleaseId,
        ph.swMasterInstProdId,
        ph.swProdOrigId,
        ph.swDateCreated,
        ph.swDateInstalled,
        ph.swFechaDesinstalacion,
        ph.swParentInstProdId,
        cat_padre.swProdReleaseId AS swProdReleaseIdParent,
        cat_padre.swReleaseName AS swReleaseNameParent,
        r.swInstProdIdRoot,
        r.swProdReleaseIdRoot,
        r.swReleaseNameRoot
      FROM rec r
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` ph
        ON ph.swParentInstProdId = r.swInstProdId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
        ON cat.swProdReleaseId = ph.swProdReleaseId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat_padre
        ON cat_padre.swProdReleaseId = r.swProdReleaseId
      -- Limito la profundidad aquí: uso < 10 para que el máximo nivel sea 10
      WHERE r.lvl < 10
    )

    -- Resultado final
    SELECT DISTINCT rec.* except(swProdReleaseId), cat_filtrado.* 
    FROM rec
    inner join cat_filtrado using(swProdReleaseId)
    ORDER BY idreg ASC, lvl ASC;
 -- );
END