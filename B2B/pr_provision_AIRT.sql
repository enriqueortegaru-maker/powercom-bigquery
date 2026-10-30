BEGIN

-- call `mm-commissions-reporting.B2B.pr_provision_AIRT`();


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PROVISION_AIRT_VARIACION` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 

    -- 1. Todos los meses disponibles ordenados
    meses AS (
      SELECT DISTINCT id_mes
      FROM `mm-commissions-reporting.B2B.PROVISION_ASIENTO_AIRT`
      ORDER BY id_mes
    ),

    -- 2. Identificar los dos últimos meses (n-1 y n-2)
    ultimos_meses AS (
      SELECT
        id_mes,
        ROW_NUMBER() OVER (ORDER BY id_mes DESC) AS rn
      FROM meses
    ),

    mes_n1 AS (SELECT id_mes FROM ultimos_meses WHERE rn = 1),
    mes_n2 AS (SELECT id_mes FROM ultimos_meses WHERE rn = 2),

    -- 3. Total de meses existentes (para detectar históricos)
    total_meses AS (
      SELECT COUNT(DISTINCT id_mes) AS total
      FROM `mm-commissions-reporting.B2B.PROVISION_ASIENTO_AIRT`
    ),

    -- 4. Importes de cada concepto en n-1 y n-2
    importes AS (
      SELECT
        p.PROVEEDOR,
        p.CODIGO_PRODUCTO,
        p.TIPO_CONTRATO,
        MAX(CASE WHEN p.id_mes = (SELECT id_mes FROM mes_n1) THEN p.importe END) AS importe_n1,
        MAX(CASE WHEN p.id_mes = (SELECT id_mes FROM mes_n2) THEN p.importe END) AS importe_n2,
        COUNT(DISTINCT p.id_mes) AS meses_presentes
      FROM `mm-commissions-reporting.B2B.PROVISION_ASIENTO_AIRT` p
      GROUP BY ALL
    ),

    -- 5. Clasificar y proyectar
    proyeccion AS (
      SELECT
        i.PROVEEDOR,
        i.CODIGO_PRODUCTO,
        i.TIPO_CONTRATO,
        i.importe_n2,
        i.importe_n1,
        i.meses_presentes,
        tm.total,

        CASE 
          WHEN i.meses_presentes = tm.total THEN TRUE 
          ELSE FALSE 
        END AS es_historica,

        CASE
          WHEN i.importe_n2 IS NOT NULL AND i.importe_n2 != 0
          THEN ROUND((i.importe_n1 - i.importe_n2) / i.importe_n2 * 100, 2)
          ELSE 0
        END AS pct_variacion,

        CASE
          -- Solo existe en n-1, no hay n-2 con el que comparar
          WHEN i.importe_n2 IS NULL OR i.importe_n2 = 0
            THEN i.importe_n1

          -- Sin cambio entre n-2 y n-1 → se mantiene
          WHEN i.importe_n1 = i.importe_n2
            THEN i.importe_n1

          -- Hay variación → aplica el mismo % para proyectar n
          ELSE
            ROUND(i.importe_n1 * (1 + (i.importe_n1 - i.importe_n2) / i.importe_n2), 2)
        END AS importe_proyectado_n

      FROM importes i
      CROSS JOIN total_meses tm
    )

    SELECT
      PROVEEDOR,
      CODIGO_PRODUCTO,
      TIPO_CONTRATO,
      importe_n2,
      importe_n1,
      pct_variacion        AS pct_variacion_pct,
      es_historica,
      importe_proyectado_n
    FROM proyeccion
    ORDER BY es_historica DESC, PROVEEDOR;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PROVISION_AIRT_VARIACION_FINAL`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  --PROVISIONES HISTÓRICAS NO MENSUALES
  SELECT 
    b.* EXCEPT(PROVEEDOR),
    a.PROVEEDOR,
    a.importe_proyectado_n
  FROM `mm-commissions-reporting.TEMP.PROVISION_AIRT_VARIACION`  a
  LEFT JOIN `mm-commissions-reporting.B2B.PROVISION_ASIENTO_AIRT` b ON a.PROVEEDOR = b.PROVEEDOR AND a.CODIGO_PRODUCTO = b.CODIGO_PRODUCTO AND a.TIPO_CONTRATO = b.TIPO_CONTRATO
  WHERE 1=1
    AND id_mes = 202603
  
  -- UNION ALL

  -- --PROVISIONES CALCULADAS CON EL PR 

  -- SELECT 
  --   202604 AS id_mes,	
  --   OPEX_CAPEX,
  --   CLASE_DOCUMENTO,
  --   CASE
  --     WHEN agrupacion_canal IN ('B2B - Nash','B2B - Populoos') THEN '8300'
  --     ELSE 'X001'
  --   END AS SOCIEDAD_SAP,
  --   agrupacion_canal AS PROVEEDOR,
  --   provision AS importe_proyectado_n,	
  --   '60722113' AS CUENTA_CONTABLE,
  --   CASE
  --     WHEN agrupacion_canal IN ('B2B - Netllar','B2B - Oceans') THEN 'X0NET010'
  --     WHEN agrupacion_canal IN ('B2B - Nash','B2B - Populoos') THEN '83AHI010'
  --     WHEN agrupacion_canal= 'B2B - Hits' THEN 'X0HIT010'
  --     ELSE 'X0SL'
  --   END AS CENTRO_COSTE,
  --   ORDEN_INVERSION,
  --   cod_producto AS CODIGO_PRODUCTO,
  --   cod_tipo_contrato AS TIPO_CONTRATO,
  --   cod_segmento AS SEGMENTO_CLIENTE,
  --   '999' AS OPERADOR,
  --   cod_marca AS CANAL,
  --   cod_marca AS MARCA,
  --   CASE
  --     WHEN agrupacion_canal = 'B2B - Onlycable' THEN '8318'
  --     WHEN agrupacion_canal = 'B2B - Embou' THEN '2100'

  --   END AS SOCIEDAD_GL_SAP,
  --   CATEGORIA_BUDGET,
  --   ASIGNACION,
  --   TEXTO,

  --   tipo_concepto,
  --   cod_tipo_contrato,
  --   cod_segmento,
  --   cod_canal,
  --   cod_marca,
  --   SUM(provision) AS provision 
  -- FROM `mm-commissions-reporting.COMISIONES.visualizacion_transacciones_prov_b2b`
  -- WHERE 1=1
  --   AND id_mes = 202604
  --   AND tipo_concepto = 'AIRT'
  -- GROUP BY ALL
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PROVISION_AIRT_ASIENTO_INSERT_EXCEL` AS

  SELECT 
    202605 AS id_mes,	
    OPEX_CAPEX,
    CLASE_DOCUMENTO,
    SOCIEDAD_SAP,
    PROVEEDOR,
    IFNULL(REPLACE(CAST(importe_proyectado_n AS STRING),'.',','),'0') AS IMPORTE,	
    CUENTA_CONTABLE,
    CENTRO_COSTE,
    ORDEN_INVERSION,
    CODIGO_PRODUCTO,
    TIPO_CONTRATO,
    SEGMENTO_CLIENTE,
    OPERADOR,
    CANAL,
    MARCA,
    SOCIEDAD_GL_SAP,
    CATEGORIA_BUDGET,
    ASIGNACION,
    TEXTO,
  FROM `mm-commissions-reporting.TEMP.PROVISION_AIRT_VARIACION_FINAL`

  UNION ALL

  --Agregamos las contrapartidas de INGRESOS de aquellas líneas que tengan social en la columna SOCIEDAD_GL_SAP
  SELECT 
    202605 AS id_mes,	
    OPEX_CAPEX,
    CLASE_DOCUMENTO,
    SOCIEDAD_GL_SAP AS SOCIEDAD_SAP,
    PROVEEDOR,
    IFNULL(REPLACE(CAST(CONCAT('-',importe_proyectado_n) AS STRING),'.',','),'0') AS IMPORTE,	
    '70525000' AS CUENTA_CONTABLE,
    CENTRO_COSTE,
    ORDEN_INVERSION,
    CODIGO_PRODUCTO,
    TIPO_CONTRATO,
    SEGMENTO_CLIENTE,
    OPERADOR,
    CANAL,
    MARCA,
    SOCIEDAD_SAP AS SOCIEDAD_GL_SAP,
    CATEGORIA_BUDGET,
    ASIGNACION,
    TEXTO,
  FROM `mm-commissions-reporting.TEMP.PROVISION_AIRT_VARIACION_FINAL`
  WHERE 1=1
    AND SOCIEDAD_GL_SAP IS NOT NULL
  ORDER BY PROVEEDOR
  ;
END