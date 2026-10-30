BEGIN
  /*
    Este procedimiento genera un inventario de la población de catálogos vigentes.
    Infiere la jerarquía de los catálogos a partir de las instancias en ci_producto
    para no duplicar registros por cliente, identificando el árbol, nivel, padre y raíz.
  */
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.AUDIT_EKTNET_ARBOL_CATALOGOS` AS
  WITH RECURSIVE
    -- 1) Universo de catálogos con filtros de Línea y Año
    cat_universo AS (
      SELECT DISTINCT
        swProdReleaseId,
        swReleaseName,
        swTipologiaProducto,
        swLineType,
        swLineName,
        SwProductType,
        SwNivelProd,
        swFacturable,
        swEstado,
        swDateCreated
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat`
      WHERE swEstado = "Vigente"
        AND (
          EXISTS (SELECT 1 FROM UNNEST(vLineName) AS v WHERE LOWER(TRIM(v)) IN ('total', 'todos', 'todas'))
          OR TRIM(swLineName) IN UNNEST(vLineName)
        )
        AND (
          IFNULL(VANNO, 0) <= 0 
          OR CAST(CAST(FORMAT_DATE("%Y", EXTRACT(DATE FROM swDateCreated)) AS STRING) AS INT64) = VANNO
        )
    ),

    -- 2) Extraer relaciones estructurales únicas de catálogos (Padre-Hijo) apoyándonos en ci_producto
    relaciones_cat AS (
      SELECT DISTINCT
        padre.swProdReleaseId AS swProdReleaseId_Padre,
        hijo.swProdReleaseId AS swProdReleaseId_Hijo
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` hijo
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` padre
        ON hijo.swParentInstProdId = padre.swInstProdId
      WHERE hijo.swProdReleaseId IS NOT NULL 
        AND padre.swProdReleaseId IS NOT NULL
    ),

    -- 3) Construcción de la jerarquía (Árbol de catálogos)
    jerarquia AS (
      -- ANCLA: Definimos las raíces (Catálogos del universo que NO aparecen como hijos de nadie)
      SELECT 
        1 AS lvl,
        c.swProdReleaseId AS idreg,                -- El ID de la raíz identifica al árbol completo
        c.swProdReleaseId,
        c.swReleaseName,
        CAST(NULL AS INT64) AS swProdReleaseId_Padre,
        CAST(NULL AS STRING) AS swReleaseName_Padre,
        c.swProdReleaseId AS swProdReleaseId_Raiz, -- Identificador de la raíz
        c.swReleaseName AS swReleaseName_Raiz      -- Nombre de la raíz
      FROM cat_universo c
      LEFT JOIN relaciones_cat r ON c.swProdReleaseId = r.swProdReleaseId_Hijo
      WHERE r.swProdReleaseId_Hijo IS NULL

      UNION ALL

      -- RECURSIÓN: Buscamos los hijos basándonos en las relaciones extraídas en el paso 2
      SELECT 
        j.lvl + 1 AS lvl,
        j.idreg,                                 -- Mantenemos el ID del árbol original
        c.swProdReleaseId,
        c.swReleaseName,
        j.swProdReleaseId AS swProdReleaseId_Padre,
        j.swReleaseName AS swReleaseName_Padre,
        j.swProdReleaseId_Raiz,
        j.swReleaseName_Raiz
      FROM jerarquia j
      INNER JOIN relaciones_cat rel ON rel.swProdReleaseId_Padre = j.swProdReleaseId
      INNER JOIN cat_universo c ON c.swProdReleaseId = rel.swProdReleaseId_Hijo
      WHERE j.lvl < 10 -- Límite de seguridad de profundidad
    )

  -- 4) Resultado final: Catálogos caracterizados con su posición en el árbol
  SELECT DISTINCT
    j.idreg,
    j.lvl,
    j.swProdReleaseId_Raiz,
    j.swReleaseName_Raiz,
    j.swProdReleaseId_Padre,
    j.swReleaseName_Padre,
    c.swProdReleaseId,
    c.swReleaseName,
    c.swLineName,
    c.swLineType,
    c.swTipologiaProducto,
    c.SwProductType,
    c.SwNivelProd,
    c.swFacturable,
    c.swDateCreated,
    FORMAT_DATE("%Y", c.swDateCreated) AS anio_catalogo
  FROM jerarquia j
  JOIN cat_universo c ON j.swProdReleaseId = c.swProdReleaseId
  ORDER BY j.idreg, j.lvl, c.swReleaseName;

END