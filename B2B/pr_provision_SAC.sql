BEGIN

-- CALL `mm-commissions-reporting.B2B.pr_provision_SAC`();

DELETE `mm-commissions-reporting.B2B.PROVISION_ASIENTO_SAC`
WHERE 1=1
  AND id_mes = 202604
;

INSERT INTO `mm-commissions-reporting.B2B.PROVISION_ASIENTO_SAC`

  SELECT 
    202604 AS id_mes,
    'OPEX' AS OPEX_CAPEX,
    'S3' AS CLASE_DOCUMENTO,
    'X001' AS SOCIEDAD_SAP,
    CASE
      WHEN tipo_servicio = 'BANDA ANCHA' THEN CONCAT(cuenta_cliente,' BA ',FORMAT_DATE('%Y',CURRENT_DATE()))
      WHEN tipo_servicio = 'MOVIL'       THEN CONCAT(cuenta_cliente,' MO ',FORMAT_DATE('%Y',CURRENT_DATE()))
      ELSE NULL
    END AS PROVEEDOR,
    SUM(PROVISION) AS IMPORTE ,
    '60722112' AS CUENTA_CONTABLE,
    CASE
      WHEN cuenta_cliente IN ('B2B - NETLLAR','B2B - OCEANS','AHIMAS CABLEMOVIL MO','AHIMAS CABLEMOVIL CONV') OR segmento LIKE '%NNS%' THEN 'X0NET010'
      WHEN cuenta_cliente = ('B2B - HITS') OR segmento LIKE '%HITS%' THEN 'X0HIT010'
      WHEN cuenta_cliente LIKE 'B2B - Populoos%' THEN '83AHI010'
      WHEN cuenta_cliente LIKE 'COMLOCAL%' THEN '6100SL'
      WHEN cuenta_cliente LIKE 'EMBOU%' THEN '21SL'
      ELSE 'X0SL'
    END AS CENTRO_COSTE,
    CAST(NULL AS STRING) AS ORDEN_INVERSION,
    CASE
      WHEN cuenta_cliente LIKE '%ALTERNA%' OR cuenta_cliente LIKE '%PTV%' THEN '39'
      ELSE '999'
    END AS CODIGO_PRODUCTO,
    CASE
      WHEN cuenta_cliente LIKE '%PTV%' THEN '63'
      WHEN cuenta_cliente LIKE '%B2B - POPULOOS%' THEN '64'
      WHEN tipo_servicio = 'BANDA ANCHA' THEN '61'
      WHEN tipo_servicio = 'MOVIL' THEN '20'
      ELSE '999' 
    END AS TIPO_CONTRATO, 
    '42' AS SEGMENTO_CLIENTE,
    '999' AS OPERADOR,
    CASE
      WHEN cuenta_cliente LIKE '%B2B - POPULOOS%' THEN '27'
      ELSE  '30'
    END  AS CANAL,
    CASE
      WHEN tipo_servicio = 'BANDA ANCHA' THEN '9'
      WHEN tipo_servicio = 'MOVIL' THEN '5'
      ELSE  NULL
    END  AS MARCA,
    CAST(NULL AS STRING)  AS SOCIEDAD_GL_SAP,
    CAST(NULL AS STRING) AS CATEGORIA_BUDGET,
    CAST(NULL AS STRING) AS ASIGNACION,
    'mes' AS TEXTO,
  FROM `mm-commissions-reporting.GS.PROVISION_HIST`
  GROUP BY ALL


;

CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.PROVISION_SAC_ASIENTO_INSERT_EXCEL` AS

  SELECT 
    202604 AS id_mes,
    OPEX_CAPEX,
    CLASE_DOCUMENTO,
    SOCIEDAD_SAP,
    PROVEEDOR,
    IFNULL(REPLACE(CAST(IMPORTE AS STRING),'.',','),'0') AS IMPORTE,
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
  FROM `mm-commissions-reporting.B2B.PROVISION_ASIENTO_SAC`
  WHERE 1=1
    AND (IMPORTE != 0 OR (texto = 'proyeccion' AND UPPER(PROVEEDOR) NOT LIKE 'ONLY%'))
  ORDER BY TEXTO ASC, PROVEEDOR ASC
;
END