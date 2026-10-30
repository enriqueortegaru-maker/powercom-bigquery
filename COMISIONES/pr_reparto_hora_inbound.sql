BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['WA','CI','BO','XI','XIBO','OSPNIN'];
END IF;



-- CALL COMISIONES.pr_reparto_hora_inbound (202609, ['WA','CI','XI','OSPNBO','XIBO','BO']);

DROP TABLE TEMP.reparto_hora_inbound;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.reparto_hora_inbound`
(
 mes_liquidado               DATE
,id_mes                      INT64
,agrupacion_canal            STRING
,canal                       STRING
,unidades                    INT64
,id_comisionista             STRING
,distribuidor                STRING
,sfid_id                     STRING
,seller                      STRING
,nombre_comercio             STRING
,razon_social                STRING
,cif                         STRING
,zona_fiscal                 STRING
,cond_pago                   STRING
,marca                       STRING
,service_type                STRING
,phone_nm                    STRING
,tariff_id                   STRING
,tariff_ds                   STRING
,service_id                  STRING
,account_id                  STRING
,customer_id                 STRING
,line_type_ds                STRING
,bundle_type                 STRING
,technology_ds               STRING
,billing_type_ds             STRING
,sale_date                   DATE
,activation_date             DATE
,deactivation_date           DATE
,order_id                    STRING
,order_type_agg              STRING
,cod_segmento                STRING
,cod_marca                   STRING
,cod_canal                   STRING
,campaign_code               STRING
,serial_number               STRING
,tax_base                    FLOAT64
-- ,claim_code                  STRING
,process_code                STRING
,proceso_sap                 STRING
,id_registro                 STRING
,invoice_id                  STRING
,sociedad                    STRING
,bp                          STRING
,cuenta_contable             STRING
,centro_coste                STRING
,documento_sap               STRING
,documento_sap_posicion      STRING
,fecha_contabilizacion       STRING
,creado                      TIMESTAMP
,modificado                  TIMESTAMP
,id_factura_drive            STRING
,emails_acceso_trazabilidad  ARRAY<STRING>
,estado                      STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comments                    STRING
,comision                    FLOAT64
,cod_producto                STRING
,cod_tipo_contrato           STRING
,claim_code                  STRING
)
;



--- HORAS TLV - CROSS-SELL (XI)
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('XI')) THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.conteo_servicios_hora_XI`  AS (
WITH base AS (
  SELECT  
    
    cif,
    CASE WHEN campaign_code = 'WHATSAPP CARTERA MM Y YOIGO' THEN 'MASMOVIL + YOIGO' ELSE marca END AS marca,
    campaign_code AS campaign,
    concepto,
    COUNT(*) AS unidades
  FROM `mm-commissions-reporting.COMISIONES.transacciones` ACT

  WHERE id_mes = id_mes_pr
    AND CANAL IN ('XI')
    AND CONCEPTO IN ('A - Servicio Fijo','A - Servicio Movil Pospago','A - Servicio Movil Prepago','B - Renuevo')
  GROUP BY ALL
),

conteo_servicios AS (
  SELECT *
  FROM base
  PIVOT (
    SUM(unidades)
    FOR CONCEPTO IN (
      'A - Servicio Fijo' AS INTERNET,
      'A - Servicio Movil Pospago' AS MOBILE,
      'B - Renuevo' AS RENUEVO,
      'A - Servicio Movil Prepago' AS PREPAGO
    )
  )
)

SELECT

  
  campaign,
  cif,
  marca,
  COALESCE(INTERNET, 0) AS INTERNET,
  COALESCE(MOBILE, 0) AS MOBILE,
  COALESCE(RENUEVO, 0) AS RENUEVO,
  COALESCE(PREPAGO, 0) AS PREPAGO   
FROM conteo_servicios
GROUP BY ALL
)

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.reparto_horas_resultado` AS (
-- 1. BASE: servicios + cálculo de peso ponderado

WITH base AS (
  SELECT
    -- campaign,
    
    campaign,
    marca,
    cif,
    COALESCE(INTERNET,0) AS internet,
    COALESCE(MOBILE,0) AS mobile,
    COALESCE(RENUEVO,0) AS renuevo,
    COALESCE(PREPAGO,0) AS prepago,

    -- Peso ponderado 
    (COALESCE(INTERNET,0) * 4) +
    (COALESCE(MOBILE,0) * 2) +
    (COALESCE(RENUEVO,0) * 0.5) +
    (COALESCE(PREPAGO,0) * 0.5) AS peso_total

  FROM `mm-commissions-reporting.TEMP.conteo_servicios_hora_XI`
  GROUP BY ALL
),


-- 2. TOTAL PESO POR CAMPAÑA

peso_campaign AS (
  SELECT
    
    campaign,
    marca,
    cif,
    SUM(peso_total) AS total_peso
  FROM base
  GROUP BY ALL
),


-- 3. Calculo precio hora + extra

horas AS (
  SELECT
    
    campaign,
    marca,
    cif,
    mes,
    horas,
    horas * (PRECIO_HORA + EXTRA_HORA_OBJETIVO) AS total_importe
  FROM `mm-commissions-reporting.GS.XI_HORAS`
  WHERE MES = id_mes_pr
),


-- 4. VALOR €/PESO

valor_peso AS (
  SELECT
    
    h.campaign,
    h.marca,
    h.cif,
    h.mes,
    SAFE_DIVIDE(h.total_importe, p.total_peso) AS importe_por_peso
  FROM horas h
  JOIN peso_campaign p USING(campaign,cif,marca)
)


-- 5. REPARTO FINAL

SELECT
  -- b.campaign,
  v.mes,
  b.campaign,
  b.cif,
  b.marca,

  -- volumen
  b.internet,
  b.mobile,
  b.renuevo,
  b.prepago,

  -- métricas base
  b.peso_total,
  v.importe_por_peso,

  -- importe por servicio
  -- b.internet * 4 * v.importe_por_peso AS importe_internet,
  -- b.mobile * 2 * v.importe_por_peso AS importe_mobile,
  -- (b.peso_total * v.importe_por_peso) -(b.internet * 4 * v.importe_por_peso)-(b.mobile * 2 * v.importe_por_peso) AS importe_renuevo,
  -- UNITARIOS
  4 * v.importe_por_peso AS unitario_internet,
  2 * v.importe_por_peso AS unitario_mobile,
  0.5 * v.importe_por_peso AS unitario_renuevo,
  0.5 * v.importe_por_peso AS unitario_prepago,
  -- IMPORTES
  b.internet * 4 * v.importe_por_peso AS importe_internet,
  b.mobile * 2 * v.importe_por_peso AS importe_mobile,
  b.renuevo * 0.5 * v.importe_por_peso AS importe_renuevo,
  b.prepago * 0.5 * v.importe_por_peso AS importe_prepago,
  -- total final
  -- b.peso_total * v.importe_por_peso AS importe_total
    -- TOTAL
  (
    b.internet * 4 * v.importe_por_peso +
    b.mobile * 2 * v.importe_por_peso +
    b.renuevo * 0.5 * v.importe_por_peso +
    b.prepago * 0.5 * v.importe_por_peso
  ) AS importe_total

FROM base b
JOIN valor_peso v USING(campaign,cif,marca))
;

INSERT INTO `mm-commissions-reporting.TEMP.reparto_hora_inbound` (
SELECT
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  TRANSACCIONES.agrupacion_canal,
  TRANSACCIONES.canal,
  1 AS unidades,
  TRANSACCIONES.id_comisionista,
  TRANSACCIONES.distribuidor,
  TRANSACCIONES.sfid_id,
  TRANSACCIONES.sfid_id AS seller,
  TRANSACCIONES.nombre_comercio,
  TRANSACCIONES.razon_social,
  TRANSACCIONES.cif,
  TRANSACCIONES.zona_fiscal,
  TRANSACCIONES.cond_pago,
  TRANSACCIONES.marca,

  CASE WHEN TRANSACCIONES.service_type = 'RENUEVO' THEN 'MOBILE' ELSE TRANSACCIONES.service_type END AS service_type,

  TRANSACCIONES.phone_nm,
  TRANSACCIONES.tariff_id,
  TRANSACCIONES.tariff_ds,
  TRANSACCIONES.service_id,
  TRANSACCIONES.account_id,
  TRANSACCIONES.customer_id,
  TRANSACCIONES.line_type_ds,
  TRANSACCIONES.bundle_type,
  TRANSACCIONES.technology_ds,
  TRANSACCIONES.billing_type_ds,
  TRANSACCIONES.sale_date,
  TRANSACCIONES.activation_date,
  TRANSACCIONES.deactivation_date,
  TRANSACCIONES.order_id,
  TRANSACCIONES.order_type_agg,

  TRANSACCIONES.cod_segmento,
   `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(TRANSACCIONES.marca) AS cod_marca,
  TRANSACCIONES.cod_canal,

  TRANSACCIONES.campaign_code,

  TRANSACCIONES.serial_number,
  TRANSACCIONES.tax_base,
  TRANSACCIONES.process_code,
  TRANSACCIONES.proceso_sap,
  TRANSACCIONES.id_registro,
  TRANSACCIONES.invoice_id,
  TRANSACCIONES.sociedad,
  TRANSACCIONES.bp,
  TRANSACCIONES.cuenta_contable,
  TRANSACCIONES.centro_coste,
  TRANSACCIONES.documento_sap,
  TRANSACCIONES.documento_sap_posicion,
  TRANSACCIONES.fecha_contabilizacion,
	CURRENT_TIMESTAMP() AS creado, 
	CURRENT_TIMESTAMP() AS modificado, 
  TRANSACCIONES.id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad,

  'calculado' AS estado,
  'D - Camp. Horas' AS concepto,
  CASE WHEN servicio.service_type = 'RENUEVO' THEN 'CURE' ELSE 'UPFR' END AS tipo_concepto,
  'C_MANUAL' AS facturador,

  TRANSACCIONES.comments,

  CASE 
  WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'B - Renuevo' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Prepago' 
    THEN servicio.unitario

END AS comision,

  TRANSACCIONES.cod_producto,
  TRANSACCIONES.cod_tipo_contrato,
  TRANSACCIONES.claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.reparto_horas_resultado` RESULTADO
  ON TRANSACCIONES.CIF = RESULTADO.cif
  AND TRANSACCIONES.campaign_code  = RESULTADO.campaign
  AND CASE WHEN TRANSACCIONES.campaign_code = 'WHATSAPP CARTERA MM Y YOIGO' THEN 'MASMOVIL + YOIGO' ELSE TRANSACCIONES.marca END = RESULTADO.marca

 
CROSS JOIN UNNEST([
  STRUCT(
    'A - Servicio Fijo' AS concepto,
    'INTERNET' AS service_type,
    RESULTADO.importe_internet AS importe,
    RESULTADO.unitario_internet AS unitario
  ),

  STRUCT(
    'A - Servicio Movil Pospago' AS concepto,
    'MOBILE' AS service_type,
    RESULTADO.importe_mobile AS importe,
    RESULTADO.unitario_mobile AS unitario
  ),

  STRUCT(
    'B - Renuevo' AS concepto,
    'RENUEVO' AS service_type,
    RESULTADO.importe_renuevo AS importe,
    RESULTADO.unitario_renuevo AS unitario
  ),

  STRUCT(
    'A - Servicio Movil Prepago' AS concepto, 
    'MOBILE' AS service_type, 
    RESULTADO.importe_prepago AS importe, 
    RESULTADO.unitario_prepago AS unitario
  )
]) AS servicio

WHERE servicio.importe > 0
AND TRANSACCIONES.id_mes = id_mes_pr
AND TRANSACCIONES.CANAL IN ('XI')
AND TRANSACCIONES.concepto = servicio.concepto
)

;

END IF;



---HORAS TLV - WEB (WA, CI)
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.conteo_servicios_hora_WA`  AS (
WITH base AS (
  SELECT  
    
    cif,
    case when campaign_code IN ('INBOUND CAPTACION ORANGE' , 'INBOUND CAPTACION MENSAJERIA ORANGE') THEN 'INBOUND CAPTACION ORANGE + INBOUND CAPTACION MENSAJERIA ORANGE' ELSE campaign_code END AS campaign,
    concepto,
    COUNT(*) AS unidades
  FROM `mm-commissions-reporting.COMISIONES.transacciones` ACT

  WHERE id_mes = id_mes_pr
    AND CANAL IN ('WA','CI')
    AND CONCEPTO IN ('A - Servicio Fijo','A - Servicio Movil Pospago','A - Servicio Movil Prepago' ,'B - Renuevo')
  GROUP BY ALL
),

conteo_servicios AS (
  SELECT *
  FROM base
  PIVOT (
    SUM(unidades)
    FOR CONCEPTO IN (
      'A - Servicio Fijo' AS INTERNET,
      'A - Servicio Movil Pospago' AS MOBILE,
      'B - Renuevo' AS RENUEVO,
      'A - Servicio Movil Prepago' AS PREPAGO
    )
  )
)

SELECT

  
  campaign,
  cif,
  COALESCE(INTERNET, 0) AS INTERNET,
  COALESCE(MOBILE, 0) AS MOBILE,
  COALESCE(RENUEVO, 0) AS RENUEVO,
  COALESCE(PREPAGO, 0) AS PREPAGO      
FROM conteo_servicios
GROUP BY ALL
)

;
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('WA','CI','BO')) THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.reparto_horas_resultado` AS (
-- 1. BASE: servicios + cálculo de peso ponderado

WITH base AS (
  SELECT
    -- campaign,
    
    campaign,
    cif,
    COALESCE(INTERNET,0) AS internet,
    COALESCE(MOBILE,0) AS mobile,
    COALESCE(RENUEVO,0) AS renuevo,
    COALESCE(PREPAGO,0) AS prepago,

    -- Peso ponderado 
    (COALESCE(INTERNET,0) * 4) +
    (COALESCE(MOBILE,0) * 2) +
    (COALESCE(RENUEVO,0) * 0.5) +
    (COALESCE(PREPAGO,0) * 0.5) AS peso_total
 
  FROM `mm-commissions-reporting.TEMP.conteo_servicios_hora_WA`
  GROUP BY ALL
),


-- 2. TOTAL PESO POR CAMPAÑA

peso_campaign AS (
  SELECT
    
    campaign,
    cif,
    SUM(peso_total) AS total_peso
  FROM base
  GROUP BY ALL
),


-- 3. Calculo precio hora + extra

horas AS (
  SELECT
    
    campaign,
    cif,
    mes,
    horas,
    horas * (PRECIO_HORA + EXTRA_HORA_OBJETIVO) AS total_importe
  FROM `mm-commissions-reporting.GS.WA_HORAS`
  WHERE MES = id_mes_pr
),


-- 4. VALOR €/PESO

valor_peso AS (
  SELECT
    
    h.campaign,
    h.cif,
    h.mes,
    SAFE_DIVIDE(h.total_importe, p.total_peso) AS importe_por_peso
  FROM horas h
  JOIN peso_campaign p USING(campaign,cif)
)


-- 5. REPARTO FINAL

SELECT

  v.mes,
  b.campaign,
  b.cif,

  -- volumen
  b.internet,
  b.mobile,
  b.renuevo,
  b.prepago,

  -- métricas base
  b.peso_total,
  v.importe_por_peso,

  -- UNITARIOS
  4 * v.importe_por_peso AS unitario_internet,
  2 * v.importe_por_peso AS unitario_mobile,
  0.5 * v.importe_por_peso AS unitario_renuevo,
  0.5 * v.importe_por_peso AS unitario_prepago,
  -- IMPORTES
  b.internet * 4 * v.importe_por_peso AS importe_internet,
  b.mobile * 2 * v.importe_por_peso AS importe_mobile,
  b.renuevo * 0.5 * v.importe_por_peso AS importe_renuevo,
  b.prepago * 0.5 * v.importe_por_peso AS importe_prepago,
  -- total final
  -- b.peso_total * v.importe_por_peso AS importe_total
    -- TOTAL
  (
    b.internet * 4 * v.importe_por_peso +
    b.mobile * 2 * v.importe_por_peso +
    b.renuevo * 0.5 * v.importe_por_peso +
    b.prepago * 0.5 * v.importe_por_peso
  ) AS importe_total

FROM base b
JOIN valor_peso v USING(campaign,cif))
;


INSERT INTO `mm-commissions-reporting.TEMP.reparto_hora_inbound` (
SELECT
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  TRANSACCIONES.agrupacion_canal,
  TRANSACCIONES.canal,
  1 AS unidades,
  TRANSACCIONES.id_comisionista,
  TRANSACCIONES.distribuidor,
  TRANSACCIONES.sfid_id,
  TRANSACCIONES.sfid_id AS seller,
  TRANSACCIONES.nombre_comercio,
  TRANSACCIONES.razon_social,
  TRANSACCIONES.cif,
  TRANSACCIONES.zona_fiscal,
  TRANSACCIONES.cond_pago,
  TRANSACCIONES.marca,

  CASE WHEN TRANSACCIONES.service_type = 'RENUEVO' THEN 'MOBILE' ELSE TRANSACCIONES.service_type END AS service_type,

  TRANSACCIONES.phone_nm,
  TRANSACCIONES.tariff_id,
  TRANSACCIONES.tariff_ds,
  TRANSACCIONES.service_id,
  TRANSACCIONES.account_id,
  TRANSACCIONES.customer_id,
  TRANSACCIONES.line_type_ds,
  TRANSACCIONES.bundle_type,
  TRANSACCIONES.technology_ds,
  TRANSACCIONES.billing_type_ds,
  TRANSACCIONES.sale_date,
  TRANSACCIONES.activation_date,
  TRANSACCIONES.deactivation_date,
  TRANSACCIONES.order_id,
  TRANSACCIONES.order_type_agg,

  TRANSACCIONES.cod_segmento,
   `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(marca) AS cod_marca,
  TRANSACCIONES.cod_canal,

  TRANSACCIONES.campaign_code,

  TRANSACCIONES.serial_number,
  TRANSACCIONES.tax_base,
  TRANSACCIONES.process_code,
  TRANSACCIONES.proceso_sap,
  TRANSACCIONES.id_registro,
  TRANSACCIONES.invoice_id,
  TRANSACCIONES.sociedad,
  TRANSACCIONES.bp,
  TRANSACCIONES.cuenta_contable,
  TRANSACCIONES.centro_coste,
  TRANSACCIONES.documento_sap,
  TRANSACCIONES.documento_sap_posicion,
  TRANSACCIONES.fecha_contabilizacion,
	CURRENT_TIMESTAMP() AS creado, 
	CURRENT_TIMESTAMP() AS modificado, 
  TRANSACCIONES.id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad,

  'calculado' AS estado,
  'D - Camp. Horas' AS concepto,
  CASE WHEN servicio.service_type = 'RENUEVO' THEN 'CURE' ELSE 'UPFR' END AS tipo_concepto,
  'C_MANUAL' AS facturador,

  TRANSACCIONES.comments,

  CASE 
  WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'B - Renuevo' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Prepago' 
    THEN servicio.unitario
END AS comision,

  TRANSACCIONES.cod_producto,
  TRANSACCIONES.cod_tipo_contrato,
  TRANSACCIONES.claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.reparto_horas_resultado` RESULTADO
  ON TRANSACCIONES.CIF = RESULTADO.cif
  AND CASE WHEN campaign_code IN ('INBOUND CAPTACION ORANGE' , 'INBOUND CAPTACION MENSAJERIA ORANGE') THEN 'INBOUND CAPTACION ORANGE + INBOUND CAPTACION MENSAJERIA ORANGE' ELSE TRANSACCIONES.campaign_code END = RESULTADO.campaign
 
CROSS JOIN UNNEST([
  STRUCT(
    'A - Servicio Fijo' AS concepto,
    'INTERNET' AS service_type,
    RESULTADO.importe_internet AS importe,
    RESULTADO.unitario_internet AS unitario
  ),

  STRUCT(
    'A - Servicio Movil Pospago' AS concepto,
    'MOBILE' AS service_type,
    RESULTADO.importe_mobile AS importe,
    RESULTADO.unitario_mobile AS unitario
  ),

  STRUCT(
    'B - Renuevo' AS concepto,
    'RENUEVO' AS service_type,
    RESULTADO.importe_renuevo AS importe,
    RESULTADO.unitario_renuevo AS unitario
  ),

  STRUCT(
    'A - Servicio Movil Prepago' AS concepto,
    'MOBILE' AS service_type,
    RESULTADO.importe_prepago AS importe,
    RESULTADO.unitario_prepago AS unitario
  )
]) AS servicio

WHERE servicio.importe > 0
AND TRANSACCIONES.id_mes = id_mes_pr
AND TRANSACCIONES.CANAL IN ('WA','CI','BO')
AND TRANSACCIONES.concepto = servicio.concepto

)
;
END IF
;


--- HORAS TLVN OSPNIN BO
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('OSPNIN','OSPNBO')) THEN

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.conteo_servicios_hora_OSPNIN`  AS (
WITH BASE AS 
(SELECT TRANSACCIONES.*, HORAS.CAMPAIGN, HORAS.DISTRIBUIDOR AS PLATAFORMA, HORAS.HORAS, HORAS.PRECIO_HORA
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN  `mm-commissions-reporting.GS.TLVN_HORAS`  HORAS

ON TRANSACCIONES.campaign_code IN UNNEST(SPLIT(HORAS.CAMPAIGN, '+'))
AND HORAS.DISTRIBUIDOR = TRANSACCIONES.nombre_comercio
AND HORAS.MES = id_mes_pr

WHERE CONCEPTO IN ('A - Servicio Fijo','A - Servicio Movil Pospago')
AND CANAL = 'OSPNIN'
AND id_mes = id_mes_pr
)

SELECT
    NOMBRE_COMERCIO,
    COUNT(*) AS NUM_SERVICIOS,
    HORAS,
    PRECIO_HORA,
    HORAS * PRECIO_HORA AS COSTE_TOTAL
FROM BASE
GROUP BY ALL
)
;


INSERT INTO `mm-commissions-reporting.TEMP.reparto_hora_inbound` (
SELECT
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  TRANSACCIONES.agrupacion_canal,
  TRANSACCIONES.canal,
  1 AS unidades,
  TRANSACCIONES.id_comisionista,
  TRANSACCIONES.distribuidor,
  TRANSACCIONES.sfid_id,
  TRANSACCIONES.seller,
  TRANSACCIONES.nombre_comercio,
  TRANSACCIONES.razon_social,
  TRANSACCIONES.cif,
  TRANSACCIONES.zona_fiscal,
  TRANSACCIONES.cond_pago,
  TRANSACCIONES.marca,
  TRANSACCIONES.service_type,
  TRANSACCIONES.phone_nm,
  TRANSACCIONES.tariff_id,
  TRANSACCIONES.tariff_ds,
  TRANSACCIONES.service_id,
  TRANSACCIONES.account_id,
  TRANSACCIONES.customer_id,
  TRANSACCIONES.line_type_ds,
  TRANSACCIONES.bundle_type,
  TRANSACCIONES.technology_ds,
  TRANSACCIONES.billing_type_ds,
  TRANSACCIONES.sale_date,
  TRANSACCIONES.activation_date,
  TRANSACCIONES.deactivation_date,
  TRANSACCIONES.order_id,
  TRANSACCIONES.order_type_agg,

  TRANSACCIONES.cod_segmento,
  TRANSACCIONES.cod_marca,
  TRANSACCIONES.cod_canal,

  TRANSACCIONES.campaign_code,

  TRANSACCIONES.serial_number,
  TRANSACCIONES.tax_base,
  TRANSACCIONES.process_code,
  TRANSACCIONES.proceso_sap,
  TRANSACCIONES.id_registro,
  TRANSACCIONES.invoice_id,
  TRANSACCIONES.sociedad,
  TRANSACCIONES.bp,
  TRANSACCIONES.cuenta_contable,
  TRANSACCIONES.centro_coste,
  TRANSACCIONES.documento_sap,
  TRANSACCIONES.documento_sap_posicion,
  TRANSACCIONES.fecha_contabilizacion,
	CURRENT_TIMESTAMP() AS creado, 
	CURRENT_TIMESTAMP() AS modificado, 
  TRANSACCIONES.id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad,

  'calculado' AS estado,
  'D - Camp. Horas BO' AS concepto,
  TRANSACCIONES.tipo_concepto,
  'C_MANUAL' AS facturador,

  TRANSACCIONES.comments,

  COSTE_TOTAL/NUM_SERVICIOS AS comision,

  TRANSACCIONES.cod_producto,
  TRANSACCIONES.cod_tipo_contrato,
  TRANSACCIONES.claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.conteo_servicios_hora_OSPNIN` RESULTADO
  ON TRANSACCIONES.nombre_comercio = RESULTADO.NOMBRE_COMERCIO
  

WHERE TRANSACCIONES.concepto IN ('A - Servicio Fijo','A - Servicio Movil Pospago')
AND TRANSACCIONES.canal = 'OSPNIN'
AND TRANSACCIONES.id_mes = id_mes_pr

UNION ALL --- HORAS SKILL MAJOREL

SELECT
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  'TLV - Negocios' AS agrupacion_canal,
  'OSPNBO'canal,
  1 AS unidades,
  '18250097'AS id_comisionista,
  CAST (NULL AS STRING) AS distribuidor,
  '18250097'AS sfid_id,
  '18250097'AS seller,
  'MAJOREL SP SOLUTIONS SA' AS nombre_comercio,
  'MAJOREL SP SOLUTIONS SA' AS razon_social,
  'A82112665' AS cif,
  'PEN' AS zona_fiscal,
  CAST (NULL AS STRING) AS cond_pago,
  'ORANGE' AS marca,
  'MOBILE' AS service_type,
  CAST (NULL AS STRING) AS phone_nm,
  CAST (NULL AS STRING) AS tariff_id,
  CAST (NULL AS STRING) AS tariff_ds,
  CAST (NULL AS STRING) AS service_id,
  CAST (NULL AS STRING) AS account_id,
  CAST (NULL AS STRING) AS customer_id,
  CAST (NULL AS STRING) AS line_type_ds,
  CAST (NULL AS STRING) AS bundle_type,
  CAST (NULL AS STRING) AS technology_ds,
  CAST (NULL AS STRING) AS billing_type_ds,
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS sale_date,
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS activation_date,
  CAST (NULL AS DATE) AS deactivation_date,
  CAST (NULL AS STRING) AS order_id,
  CAST (NULL AS STRING) AS order_type_agg,

  '12' AS cod_segmento,
  '29' AS cod_marca,
  '14' AS cod_canal,

  CAST (NULL AS STRING) AS campaign_code,

  CAST (NULL AS STRING) AS serial_number,
  CAST (NULL AS FLOAT64) AS tax_base,
  CAST (NULL AS STRING) AS process_code,
  CAST (NULL AS STRING) AS proceso_sap,
  CAST (NULL AS STRING) AS id_registro,
  CAST (NULL AS STRING) AS invoice_id,
  CAST (NULL AS STRING) AS sociedad,
  CAST (NULL AS STRING) AS bp,
  CAST (NULL AS STRING) AS cuenta_contable,
  CAST (NULL AS STRING) AS centro_coste,
  CAST (NULL AS STRING) AS documento_sap,
  CAST (NULL AS STRING) AS documento_sap_posicion,
  CAST (NULL AS STRING) AS fecha_contabilizacion,
	CURRENT_TIMESTAMP() AS creado, 
	CURRENT_TIMESTAMP() AS modificado, 
  CAST (NULL AS STRING) AS id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad,

  'calculado' AS estado,
  'D - Camp. Horas BO' AS concepto,
  'UPFR' AS tipo_concepto,
  'C_MANUAL' AS facturador,

  CAST (NULL AS STRING) AS comments,

  HORAS.HORAS * HORAS.PRECIO_HORA AS comision,

  CAST (NULL AS STRING) AS cod_producto,
  CAST (NULL AS STRING) AS cod_tipo_contrato,
  'HORAS SKILL MAJOREL '|| id_mes_pr AS claim_code

FROM `mm-commissions-reporting.GS.TLVN_HORAS` HORAS
  
WHERE HORAS.MES = id_mes_pr
AND HORAS.DISTRIBUIDOR = 'MAJOREL'
AND HORAS.CAMPAIGN = 'SKILL MAJOREL'
);

END IF;

--HORAS BACKOFFICE WEB (XIBO, BO, OSPNBO)
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('OSPNBO','XIBO','BO')) THEN


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.conteo_servicios_hora_BO`  AS (
WITH base AS (
  SELECT  
    
    cif,
    -- campaign_code AS campaign,
    concepto,
    COUNT(*) AS unidades
  FROM `mm-commissions-reporting.COMISIONES.transacciones` ACT

  WHERE id_mes = id_mes_pr
    AND CANAL IN ('XIBO','OSPNBO','BO')
    AND CONCEPTO IN ('A - Servicio Fijo','A - Servicio Movil Pospago','A - Servicio Movil Prepago' ,'B - Renuevo')
    AND id_comisionista IN ('18250064', '19140687','18250056', '19140686')
  GROUP BY ALL
),

conteo_servicios AS (
  SELECT *
  FROM base
  PIVOT (
    SUM(unidades)
    FOR CONCEPTO IN (
      'A - Servicio Fijo' AS INTERNET,
      'A - Servicio Movil Pospago' AS MOBILE,
      'B - Renuevo' AS RENUEVO,
      'A - Servicio Movil Prepago' AS PREPAGO
    )
  )
)

SELECT

  
  -- campaign,
  cif,
  COALESCE(INTERNET, 0) AS INTERNET,
  COALESCE(MOBILE, 0) AS MOBILE,
  COALESCE(RENUEVO, 0) AS RENUEVO,
  COALESCE(PREPAGO, 0) AS PREPAGO      
FROM conteo_servicios
GROUP BY ALL
)

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.reparto_horas_resultado` AS (
-- 1. BASE: servicios + cálculo de peso ponderado

WITH base AS (
  SELECT
    -- campaign,
    
    -- campaign,
    cif,
    COALESCE(INTERNET,0) AS internet,
    COALESCE(MOBILE,0) AS mobile,
    COALESCE(RENUEVO,0) AS renuevo,
    COALESCE(PREPAGO,0) AS prepago,

    -- Peso ponderado 
    (COALESCE(INTERNET,0) * 4) +
    (COALESCE(MOBILE,0) * 2) +
    (COALESCE(RENUEVO,0) * 0.5) +
    (COALESCE(PREPAGO,0) * 0.5) AS peso_total
 
  FROM `mm-commissions-reporting.TEMP.conteo_servicios_hora_BO` 
  GROUP BY ALL
),


-- 2. TOTAL PESO POR CAMPAÑA

peso_campaign AS (
  SELECT
    
    -- campaign,
    cif,
    SUM(peso_total) AS total_peso
  FROM base
  GROUP BY ALL
),


-- 3. Calculo precio hora + extra

horas AS (
  SELECT
    
    -- campaign,
    cif,
    mes,
    horas,
    horas * (PRECIO_HORA + EXTRA_HORA_OBJETIVO) AS total_importe
  FROM `mm-commissions-reporting.GS.WA_HORAS`
  WHERE MES = id_mes_pr
  AND CAMPAIGN = 'INBOUND CAPTACION ORANGE BO WEB'
),


-- 4. VALOR €/PESO

valor_peso AS (
  SELECT
    
    -- h.campaign,
    h.cif,
    h.mes,
    SAFE_DIVIDE(h.total_importe, p.total_peso) AS importe_por_peso
  FROM horas h
  JOIN peso_campaign p USING(cif)
)


-- 5. REPARTO FINAL

SELECT
  -- b.campaign,
  v.mes,
  -- b.campaign,
  b.cif,

  -- volumen
  b.internet,
  b.mobile,
  b.renuevo,
  b.prepago,

  -- métricas base
  b.peso_total,
  v.importe_por_peso,

  -- importe por servicio
  -- b.internet * 4 * v.importe_por_peso AS importe_internet,
  -- b.mobile * 2 * v.importe_por_peso AS importe_mobile,
  -- (b.peso_total * v.importe_por_peso) -(b.internet * 4 * v.importe_por_peso)-(b.mobile * 2 * v.importe_por_peso) AS importe_renuevo,
  -- UNITARIOS
  4 * v.importe_por_peso AS unitario_internet,
  2 * v.importe_por_peso AS unitario_mobile,
  0.5 * v.importe_por_peso AS unitario_renuevo,
  0.5 * v.importe_por_peso AS unitario_prepago,
  -- IMPORTES
  b.internet * 4 * v.importe_por_peso AS importe_internet,
  b.mobile * 2 * v.importe_por_peso AS importe_mobile,
  b.renuevo * 0.5 * v.importe_por_peso AS importe_renuevo,
  b.prepago * 0.5 * v.importe_por_peso AS importe_prepago,
  -- total final
  -- b.peso_total * v.importe_por_peso AS importe_total
    -- TOTAL
  (
    b.internet * 4 * v.importe_por_peso +
    b.mobile * 2 * v.importe_por_peso +
    b.renuevo * 0.5 * v.importe_por_peso +
    b.prepago * 0.5 * v.importe_por_peso
  ) AS importe_total

FROM base b
JOIN valor_peso v USING(cif))
;


INSERT INTO `mm-commissions-reporting.TEMP.reparto_hora_inbound` (
SELECT
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  TRANSACCIONES.agrupacion_canal,
  TRANSACCIONES.canal,
  1 AS unidades,
  TRANSACCIONES.id_comisionista,
  TRANSACCIONES.distribuidor,
  TRANSACCIONES.sfid_id,
  TRANSACCIONES.sfid_id AS seller,
  TRANSACCIONES.nombre_comercio,
  TRANSACCIONES.razon_social,
  TRANSACCIONES.cif,
  TRANSACCIONES.zona_fiscal,
  TRANSACCIONES.cond_pago,
  TRANSACCIONES.marca,

  CASE WHEN TRANSACCIONES.service_type = 'RENUEVO' THEN 'MOBILE' ELSE TRANSACCIONES.service_type END AS service_type,

  TRANSACCIONES.phone_nm,
  TRANSACCIONES.tariff_id,
  TRANSACCIONES.tariff_ds,
  TRANSACCIONES.service_id,
  TRANSACCIONES.account_id,
  TRANSACCIONES.customer_id,
  TRANSACCIONES.line_type_ds,
  TRANSACCIONES.bundle_type,
  TRANSACCIONES.technology_ds,
  TRANSACCIONES.billing_type_ds,
  TRANSACCIONES.sale_date,
  TRANSACCIONES.activation_date,
  TRANSACCIONES.deactivation_date,
  TRANSACCIONES.order_id,
  TRANSACCIONES.order_type_agg,

  TRANSACCIONES.cod_segmento,
   `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(marca) AS cod_marca,
  TRANSACCIONES.cod_canal,

  TRANSACCIONES.campaign_code,

  TRANSACCIONES.serial_number,
  TRANSACCIONES.tax_base,
  TRANSACCIONES.process_code,
  TRANSACCIONES.proceso_sap,
  TRANSACCIONES.id_registro,
  TRANSACCIONES.invoice_id,
  TRANSACCIONES.sociedad,
  TRANSACCIONES.bp,
  TRANSACCIONES.cuenta_contable,
  TRANSACCIONES.centro_coste,
  TRANSACCIONES.documento_sap,
  TRANSACCIONES.documento_sap_posicion,
  TRANSACCIONES.fecha_contabilizacion,
	CURRENT_TIMESTAMP() AS creado, 
	CURRENT_TIMESTAMP() AS modificado, 
  TRANSACCIONES.id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad,

  'calculado' AS estado,
  'D - Camp. Horas' AS concepto,
  CASE WHEN servicio.service_type = 'RENUEVO' THEN 'CURE' ELSE 'UPFR' END AS tipo_concepto,
  'C_MANUAL' AS facturador,

  TRANSACCIONES.comments,


  CASE 
  WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'B - Renuevo' 
    THEN servicio.unitario

  WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Prepago' 
    THEN servicio.unitario
END AS comision,

  TRANSACCIONES.cod_producto,
  TRANSACCIONES.cod_tipo_contrato,
  TRANSACCIONES.claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.reparto_horas_resultado` RESULTADO
  ON TRANSACCIONES.CIF = RESULTADO.cif

 
CROSS JOIN UNNEST([
  STRUCT(
    'A - Servicio Fijo' AS concepto,
    'INTERNET' AS service_type,
    RESULTADO.importe_internet AS importe,
    RESULTADO.unitario_internet AS unitario
  ),

  STRUCT(
    'A - Servicio Movil Pospago' AS concepto,
    'MOBILE' AS service_type,
    RESULTADO.importe_mobile AS importe,
    RESULTADO.unitario_mobile AS unitario
  ),

  STRUCT(
    'B - Renuevo' AS concepto,
    'RENUEVO' AS service_type,
    RESULTADO.importe_renuevo AS importe,
    RESULTADO.unitario_renuevo AS unitario
  ),

  STRUCT(
    'A - Servicio Movil Prepago' AS concepto,
    'MOBILE' AS service_type,
    RESULTADO.importe_prepago AS importe,
    RESULTADO.unitario_prepago AS unitario
  )
]) AS servicio

WHERE servicio.importe > 0
AND TRANSACCIONES.id_mes = id_mes_pr
AND TRANSACCIONES.CANAL IN ('BO','OSPNBO','XIBO')
AND TRANSACCIONES.concepto = servicio.concepto

)
;
END IF
;


CREATE OR REPLACE TABLE TEMP.repartos_hora_inbound_final AS
(
  SELECT
        *
      ,'RPHO' || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
  FROM TEMP.reparto_hora_inbound
  WHERE comision IS NOT NULL
  AND CONCEPTO IS NOT NULL
)

;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('RPHO', id_mes_pr, canales_pr , 'TEMP.repartos_hora_inbound_final' , 'ACTUALIZAR');



END