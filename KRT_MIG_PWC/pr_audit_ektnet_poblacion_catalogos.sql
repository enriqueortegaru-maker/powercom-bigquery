BEGIN
  /*
    Este procedimiento genera un inventario completo de la población de catálogos vigentes,
    caracterizando sus atributos y estableciendo la relación jerárquica entre ellos.
  */
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.AUDIT_EKTNET_POBLACION_CATALOGOS` AS
  WITH RECURSIVE
    -- 1) Universo de catálogos filtrado por los parámetros de entrada
    cat_universo AS (
      SELECT 
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
          -- Filtro flexible de vLineName
          EXISTS (SELECT 1 FROM UNNEST(vLineName) AS v WHERE LOWER(TRIM(v)) IN ('total', 'todos', 'todas'))
          OR TRIM(swLineName) IN UNNEST(vLineName)
        )
        AND (
          -- Filtro flexible de Año (VANNO)
          IFNULL(VANNO, 0) <= 0 
          OR CAST(CAST(FORMAT_DATE("%Y", EXTRACT(DATE FROM swDateCreated)) AS STRING) AS INT64) = VANNO
        )
    ),

    -- 2) Construcción de la jerarquía (Relación Padre-Hijo)
    jerarquia_cat AS (
      -- Raíces (Elementos sin padre o de nivel superior)
      SELECT 
        1 AS nivel,
        swProdReleaseId,
        swReleaseName,
        CAST(NULL AS INT64) AS swProdReleaseId_Padre,  -- ¡CORRECCIÓN AQUÍ: cambiado de STRING a INT64!
        CAST(NULL AS STRING) AS swReleaseName_Padre,
        swProdReleaseId AS swProdReleaseId_Raiz,
        swReleaseName AS swReleaseName_Raiz,
        swLineName,
        swTipologiaProducto
      FROM cat_universo
      -- WHERE swParentProdReleaseId IS NULL -- (Descomentar si existe el campo en catálogo)

      UNION ALL

      -- Relación recursiva para encontrar hijos
      SELECT 
        j.nivel + 1 AS nivel,
        c.swProdReleaseId,
        c.swReleaseName,
        j.swProdReleaseId AS swProdReleaseId_Padre,
        j.swReleaseName AS swReleaseName_Padre,
        j.swProdReleaseId_Raiz,
        j.swReleaseName_Raiz,
        c.swLineName,
        c.swTipologiaProducto
      FROM jerarquia_cat j
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` c 
        -- OJO: Modifica esta condición por la relación real Padre-Hijo en la tabla catálogo.
        -- Ej: ON c.swParentProdReleaseId = j.swProdReleaseId
        ON c.swProdReleaseId = j.swProdReleaseId 
      WHERE j.nivel < 5
    )

  -- 3) Resultado final: Población caracterizada
  SELECT DISTINCT
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
    
    -- Si logras vincular la parte jerárquica con el campo correcto de paternidad del catálogo, 
    -- puedes descomentar las líneas de abajo y cambiar la tabla del FROM a "jerarquia_cat":
    
    -- , c.swProdReleaseId_Padre
    -- , c.swReleaseName_Padre
    -- , c.nivel as nivel_jerarquico
    -- , c.swProdReleaseId_Raiz
    -- , c.swReleaseName_Raiz
  FROM cat_universo c
  -- Si usas jerarquia_cat, usa FROM jerarquia_cat c
  ORDER BY swLineName, swReleaseName;

END