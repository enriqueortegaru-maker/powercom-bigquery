BEGIN

--Procedimiento que transforma la pestaña EXTRA_CAMPANA en una tabla histórica mensual, aplicando una lógica general común.
--Recibe como parámetros de entrada el año-mes (YYYYMM) y el canal.

DECLARE canales_str,prefijo_tabla,tabla_nombre,tabla_nombre_gs,qry,sql STRING;


-- CALL `mm-commissions-reporting.B2B.pr_campanas_base_general`(202607, ['MB','MBA']);

SET canales_str = ARRAY_TO_STRING(canales_pr, ',');

SET prefijo_tabla = 
    CASE 
      WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('MB','MBA'))  THEN 'MB'
      WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('CM','CALT'))  THEN 'CM'
      WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('NASH', 'NTCLI', 'HICLI', 'OCE'))  THEN 'NNS'
      ELSE NULL
    END;

SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.EXTRA_CAMPANA_', prefijo_tabla, '_', CAST(mes_int AS STRING), '01');

SET tabla_nombre_gs = CONCAT('mm-commissions-reporting.GS.EXTRA_CAMPANA_', prefijo_tabla);

SET sql = '';
SET sql = sql ||'CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2BC_CAMPANA` ';
SET sql = sql ||'OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS ';
SET sql = sql ||    'SELECT * FROM ';
SET sql = sql ||    tabla_nombre_gs;
SET sql = sql ||    " WHERE fecha_campana = LAST_DAY(PARSE_DATE('%Y%m',CAST(";
SET sql = sql ||    mes_int; 
SET sql = sql ||    ' AS STRING)))';
EXECUTE IMMEDIATE (sql);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2BC_CAMPANA_ROW` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

  WITH

    --Inicio extracción y transformación inf Google Sheet campañas:
    ---C:No se utiliza
    campanas_PVP AS (
      SELECT *,
        ROW_NUMBER() OVER(PARTITION BY DEALER_SPLIT, TIPO_LINEA, FECHA_CAMPANA, CATEGORIZACION ORDER BY INCENTIVO_POR_ALTA ASC) AS n_control
      FROM `mm-commissions-reporting.TEMP.B2BC_CAMPANA`,
      UNNEST(SPLIT(REGEXP_REPLACE(DEALER, r', ', ','))) AS DEALER_SPLIT
      WHERE (PVP_BOOLEAN IS TRUE)
    ),
    --C:coge las campañas con N_activaciones minima, asigna un n_control para campañas con misma fecha de campaña, dealer, tipo de línea y concepto
    campanas_N_activaciones AS (
      SELECT *,
        ROW_NUMBER() OVER(PARTITION BY DEALER_SPLIT, TIPO_LINEA, FECHA_CAMPANA, CATEGORIZACION ORDER BY INCENTIVO_POR_ALTA ASC) AS n_control
      FROM `mm-commissions-reporting.TEMP.B2BC_CAMPANA`,
      UNNEST(SPLIT(REGEXP_REPLACE(DEALER, r', ', ','))) AS DEALER_SPLIT
      WHERE (N_ACTIVACIONES_DESDE IS NOT NULL)
    ),
    --C:formato casi de la GS, coge las campañas de PVP_bolean FALSE y n_activaciones_desde null. Hace CROSS JOIN por: tipo de linea, msisdn y gescales
    base_campana_ini AS (
      SELECT DISTINCT
        FECHA_CAMPANA,
        AGRUPACION_CANAL,
        CONCEPTO AS CONCEPTO,
        DEALER,
        OPERADORES_MASORANGE,
        OPERADORES_DONANTES,
        INCENTIVO_POR_ALTA,
        UPPER(TIPO_LINEA) AS TIPO_LINEA,
        INCENTIVO_TOTAL,
        PORCENTAJE_COMISION_FACTURACION,
        CAST(DESDE AS DATE) AS DESDE,
        CAST(HASTA AS DATE) AS HASTA,
        UPPER(REGEXP_REPLACE(CATEGORIZACION, r'^[DAZRE] - ', '')) AS CATEGORIZACION,
        TARIFF_ID,
        MSISDN,
        GESCAL,
        N_ACTIVACIONES_DESDE,
        CAST(NULL AS INT64) AS N_ACTIVACIONES_HASTA,
        PVP_BOOLEAN,
        PVP_DESDE,
        CAST(NULL AS FLOAT64) AS PVP_HASTA,
        CLAWBACK_PRORRATEADO,
        FECHA_PRORRATEO,
        CLAWBACK_N_MESES,
        CLAWBACK,
        NULL AS DUPLICADOS
        FROM `mm-commissions-reporting.TEMP.B2BC_CAMPANA` ,
        UNNEST(SPLIT(REGEXP_REPLACE(DEALER, r', ', ','))) AS DEALER,
        UNNEST(SPLIT(REGEXP_REPLACE(TIPO_LINEA, r', ', ','))) AS TIPO_LINEA
        WHERE 1=1
          AND (STRPOS(MSISDN, ';') = 0 OR MSISDN IS NULL)
          AND (STRPOS(GESCAL, ';') = 0 OR GESCAL IS NULL)
          AND (N_ACTIVACIONES_DESDE IS NULL AND PVP_BOOLEAN IS FALSE) 

      UNION ALL

      --Separamos los MSISDN que contengan ';'

      SELECT DISTINCT
        FECHA_CAMPANA,
        AGRUPACION_CANAL,
        CONCEPTO AS CONCEPTO,
        DEALER,
        OPERADORES_MASORANGE,
        OPERADORES_DONANTES,
        INCENTIVO_POR_ALTA,
        UPPER(TIPO_LINEA) AS TIPO_LINEA,
        INCENTIVO_TOTAL,
        PORCENTAJE_COMISION_FACTURACION,
        CAST(DESDE AS DATE) AS DESDE,
        CAST(HASTA AS DATE) AS HASTA,
        UPPER(REGEXP_REPLACE(CATEGORIZACION, r'^[DAZRE] - ', '')) AS CATEGORIZACION,        
        TARIFF_ID,
        MSISDN,
        GESCAL,
        N_ACTIVACIONES_DESDE,
        CAST(NULL AS INT64) AS N_ACTIVACIONES_HASTA,
        PVP_BOOLEAN,
        PVP_DESDE,
        CAST(NULL AS FLOAT64) AS PVP_HASTA,
        CLAWBACK_PRORRATEADO,
        FECHA_PRORRATEO,
        CLAWBACK_N_MESES,
        CLAWBACK,
        NULL AS DUPLICADOS
        FROM `mm-commissions-reporting.TEMP.B2BC_CAMPANA`,
        UNNEST(SPLIT(MSISDN,';')) AS MSISDN,
        UNNEST(SPLIT(REGEXP_REPLACE(DEALER, r', ', ','))) AS DEALER
        WHERE 1=1
          AND (N_ACTIVACIONES_DESDE IS NULL OR PVP_BOOLEAN IS FALSE)
          AND MSISDN IS NOT NULL
          --fecha_campana = last_day(PARSE_DATE('%Y%m',mes_string))

      UNION ALL

      --Separamos los GESCALES que contengan ';'

      SELECT DISTINCT
        FECHA_CAMPANA,
        AGRUPACION_CANAL,
        CONCEPTO AS CONCEPTO,
        DEALER,
        OPERADORES_MASORANGE,
        OPERADORES_DONANTES,
        INCENTIVO_POR_ALTA,
        UPPER(TIPO_LINEA) AS TIPO_LINEA,
        INCENTIVO_TOTAL,
        PORCENTAJE_COMISION_FACTURACION,
        CAST(DESDE AS DATE) AS DESDE,
        CAST(HASTA AS DATE) AS HASTA,
        UPPER(REGEXP_REPLACE(CATEGORIZACION, r'^[DAZRE] - ', '')) AS CATEGORIZACION,
        TARIFF_ID,
        MSISDN,
        GESCAL,
        N_ACTIVACIONES_DESDE,
        CAST(NULL AS INT64) AS N_ACTIVACIONES_HASTA,
        PVP_BOOLEAN,
        PVP_DESDE,
        CAST(NULL AS FLOAT64) AS PVP_HASTA,
        CLAWBACK_PRORRATEADO,
        FECHA_PRORRATEO,
        CLAWBACK_N_MESES,
        CLAWBACK,
        NULL AS DUPLICADOS
        FROM `mm-commissions-reporting.TEMP.B2BC_CAMPANA`,
        UNNEST(SPLIT(GESCAL,';')) AS GESCAL,
        UNNEST(SPLIT(REGEXP_REPLACE(DEALER, r', ', ','))) AS DEALER
        WHERE 1=1
          AND (N_ACTIVACIONES_DESDE IS NULL OR PVP_BOOLEAN IS FALSE)
          AND (GESCAL IS NOT NULL)
    ),

    base_campana_N_acti_pvp AS (
      SELECT 
        a.FECHA_CAMPANA,
        a.AGRUPACION_CANAL,
        a.CONCEPTO AS CONCEPTO,
        a.DEALER_SPLIT AS DEALER,
        a.OPERADORES_MASORANGE,
        a.OPERADORES_DONANTES,
        a.INCENTIVO_POR_ALTA,
        UPPER(a.TIPO_LINEA) AS TIPO_LINEA,
        a.INCENTIVO_TOTAL,
        a.PORCENTAJE_COMISION_FACTURACION,
        CAST(a.DESDE AS DATE) AS DESDE,
        CAST(a.HASTA AS DATE) AS HASTA,
        UPPER(REGEXP_REPLACE(a.CATEGORIZACION, r'^[DAZRE] - ', '')) AS CATEGORIZACION,
        a.TARIFF_ID,
        a.MSISDN,
        a.GESCAL,
        a.N_ACTIVACIONES_DESDE,
        CASE
          WHEN a.N_ACTIVACIONES_DESDE = b.N_ACTIVACIONES_DESDE THEN 0
          WHEN b.N_ACTIVACIONES_DESDE IS NULL THEN 999999
          ELSE b.N_ACTIVACIONES_DESDE-1
        END AS N_ACTIVACIONES_HASTA,
        a.PVP_BOOLEAN,
        a.PVP_DESDE AS PVP_DESDE, 
        CASE 
          WHEN b.PVP_DESDE > 1 THEN b.PVP_DESDE
          WHEN a.PVP_DESDE + b.PVP_DESDE = 2 THEN 9999
          ELSE 9999
          END AS PVP_HASTA,
        a.CLAWBACK_PRORRATEADO,
        a.FECHA_PRORRATEO,
        a.CLAWBACK_N_MESES,
        a.CLAWBACK,
        NULL AS DUPLICADOS, 
      FROM campanas_N_activaciones a
      LEFT JOIN campanas_N_activaciones b 
        ON a.n_control = b.n_control - 1 
        AND a.DEALER_SPLIT = b.DEALER_SPLIT 
        AND a.FECHA_CAMPANA = B.FECHA_CAMPANA 
        AND a.TIPO_LINEA = b.TIPO_LINEA
    ),


    base_campana_f AS (

      SELECT *
      FROM base_campana_ini

      UNION ALL

      --Modificamos N_ACTIVACIONES_HASTA para los casos en los que tienen campañas PVP y N_ACT que faltaba una excepción
      SELECT 
        FECHA_CAMPANA,
        AGRUPACION_CANAL,
        CONCEPTO,
        DEALER,
        OPERADORES_MASORANGE,
        OPERADORES_DONANTES,
        INCENTIVO_POR_ALTA,
        TIPO_LINEA,
        INCENTIVO_TOTAL,
        PORCENTAJE_COMISION_FACTURACION,
        DESDE,
        HASTA,
        CATEGORIZACION,
        TARIFF_ID,
        MSISDN,
        GESCAL,
        N_ACTIVACIONES_DESDE,
        CASE
          WHEN N_ACTIVACIONES_DESDE = 1 AND N_ACTIVACIONES_HASTA = 0 THEN 999999
          ELSE N_ACTIVACIONES_HASTA
        END AS N_ACTIVACIONES_HASTA,
        PVP_BOOLEAN,
        PVP_DESDE, 
        PVP_HASTA,
        CLAWBACK_PRORRATEADO,
        FECHA_PRORRATEO,
        CLAWBACK_N_MESES,
        CLAWBACK,
        DUPLICADOS
        
      FROM base_campana_N_acti_pvp
      WHERE N_ACTIVACIONES_HASTA IS NOT NULL
    ),

    campanas AS (
      SELECT 
        mes_int AS id_mes,
        *
      FROM base_campana_f
    )

    SELECT *
    FROM campanas
  ;
SET qry = 
'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || ' `mm-commissions-reporting.TEMP.B2BC_CAMPANA_ROW`';
EXECUTE IMMEDIATE qry;

END