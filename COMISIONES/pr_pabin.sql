BEGIN

DECLARE prefijo, mes_string STRING;
DECLARE fecha_mes, fecha_inicio, fecha_fin DATE;



SET prefijo = 'PABIN';

SET mes_string = CAST(id_mes_pr AS STRING);

SET fecha_mes = PARSE_DATE('%Y%m', mes_string);
SET fecha_inicio = DATE_SUB(fecha_mes, INTERVAL 180 DAY);
SET fecha_fin = DATE_ADD(fecha_mes, INTERVAL 180 DAY);


SET canales_pr = COALESCE(canales_pr, ['ENK']);



/*
CALL `mm-commissions-reporting.COMISIONES.pr_pabin`(202604, ['ENK']);
*/


DROP TABLE TEMP.pabin;
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.pabin`
(
 agrupacion_canal            STRING
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
,cod_tipo_contrato           STRING
,cod_producto                STRING
,cod_canal                   STRING
,campaign_code               STRING
,serial_number               STRING
,tax_base                    FLOAT64
,claim_code                  STRING
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
,id_mes                      INT64
,mes_liquidado               DATE
,estado                      STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comision                    FLOAT64
,comments                    STRING
,process_code                STRING
,commission_id               STRING
)

;

--- CREAMOS TABLA CON LAS COMISIONES DEL MES AÑADIENDO CUSTOMER HASHEADO --- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PABIN_altas_nuevas_fijo`
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)) AS (
SELECT DISTINCT
  PERSONAL.hash_id,
  PERSONAL.document_hash,
  VENTAS.*

FROM `mm-commissions-reporting.COMISIONES.transacciones` VENTAS
LEFT JOIN `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` PERSONAL
ON VENTAS.customer_id = PERSONAL.customer_id
 AND VENTAS.marca = PERSONAL.brand_ds

CROSS JOIN UNNEST(canales_pr) canal_pr

  WHERE VENTAS.canal = canal_pr
    AND VENTAS.id_mes = id_mes_pr

)

;

--- CREAMOS TABLA CON LAS PORTAS DEL MES A PARTIR DE TABLA ANTERIOR --- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PABIN_portabilidades_fijo`
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)) AS (
SELECT DISTINCT
  ALTAS.*

FROM `mm-commissions-reporting.TEMP.PABIN_altas_nuevas_fijo` ALTAS

CROSS JOIN UNNEST(canales_pr) canal_pr

  WHERE ALTAS.canal = canal_pr
    AND ALTAS.id_mes = id_mes_pr
    AND ALTAS.order_type_agg = 'PORTABILIDAD'
    AND ALTAS.concepto IN ('A - Servicio Fijo','A - Servicio Fijo 2da Vivienda')

)
;


--- CREAMOS TABLA CON LAS BAJAS CON VENTANA DE 180 DÍAS AÑADIENDO CUSTOMER HASHEADO --- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PABIN_bajas_intramarca_fijo` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)) AS (
SELECT DISTINCT
  PERSONAL.hash_id,
  PERSONAL.document_hash,
  VENTAS.*
FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` PERSONAL
ON VENTAS.customer_id = PERSONAL.customer_id
 AND VENTAS.marca = PERSONAL.brand_ds

  WHERE VENTAS.service_type IN ('INTERNET','MOBILE') 
  AND VENTAS.deactivation_date BETWEEN fecha_inicio AND fecha_fin
  AND VENTAS.activation_date IS NOT NULL
  AND PERSONAL.hash_id IN (
      SELECT DISTINCT
      PERSONAL.hash_id

      FROM `mm-commissions-reporting.COMISIONES.transacciones` VENTAS
      LEFT JOIN `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` PERSONAL
      ON VENTAS.customer_id = PERSONAL.customer_id
      AND VENTAS.marca = PERSONAL.brand_ds
      
      CROSS JOIN UNNEST(canales_pr) canal_pr

        WHERE VENTAS.canal = canal_pr
          AND VENTAS.id_mes = id_mes_pr

  )

)

;


-- Penalizacion Intermarca Exclusivo + Penalizacion Intramarca Exclusivo
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.pabin 
(SELECT
  * 
  ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id
FROM (
-- SELECT DISTINCT
--         TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad,hash_id, document_hash)
--        ,id_mes_pr AS id_mes
--        ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
--        ,'calculado' AS estado

--        ,CASE
--             WHEN SUBSTR(TRANSACCIONES.concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(TRANSACCIONES.concepto, 2, LENGTH(TRANSACCIONES.concepto)))
--             ELSE CONCAT('Q', SUBSTR(TRANSACCIONES.concepto, 2, LENGTH(TRANSACCIONES.concepto)))
--         END AS concepto

--        ,TRANSACCIONES.tipo_concepto
--        ,TRANSACCIONES.facturador
     
--        ,(TRANSACCIONES.comision * -1) AS comision
--        ,'Penalizacion - Alta Baja Intermarca' AS comments
--        ,TRANSACCIONES.commission_id AS process_code

-- FROM `mm-commissions-reporting.TEMP.PABIN_altas_nuevas_fijo` TRANSACCIONES

-- INNER JOIN `mm-commissions-reporting.TEMP.PABIN_bajas_intramarca_fijo` B
-- ON TRANSACCIONES.hash_id = B.hash_id
--   AND DATE(B.deactivation_date) BETWEEN DATE_SUB(DATE(TRANSACCIONES.activation_date), INTERVAL 30 DAY) AND DATE_ADD(DATE(TRANSACCIONES.activation_date), INTERVAL 30 DAY)

-- LEFT JOIN `mm-commissions-reporting.TEMP.PABIN_portabilidades_fijo` PORTABILIDADES
--   ON TRANSACCIONES.hash_id = PORTABILIDADES.hash_id

-- CROSS JOIN UNNEST(canales_pr) canal_pr

-- WHERE TRANSACCIONES.canal = canal_pr
-- AND B.service_type = 'INTERNET'
-- AND TRANSACCIONES.MARCA != B.brand_ds
-- AND TRANSACCIONES.order_type_agg = 'ALTA NUEVA'
-- AND PORTABILIDADES.hash_id IS NULL 
-- AND TRANSACCIONES.marca NOT IN ('PEPEPHONE','SIMYO')
-- AND TRANSACCIONES.concepto IN (
--                               'A - Servicio Fijo',
--                               'A - Servicio Fijo 2da Vivienda',
--                               'D - Extracomision Objetivo fijo'
--                               )
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.phone_nm, TRANSACCIONES.marca) = 1



-- UNION ALL


SELECT DISTINCT
        TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad,hash_id, document_hash)
       ,id_mes_pr AS id_mes
       ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
       ,'calculado' AS estado

       ,CASE
            WHEN SUBSTR(TRANSACCIONES.concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(TRANSACCIONES.concepto, 2, LENGTH(TRANSACCIONES.concepto)))
            ELSE CONCAT('Q', SUBSTR(TRANSACCIONES.concepto, 2, LENGTH(TRANSACCIONES.concepto)))
        END AS concepto

       ,TRANSACCIONES.tipo_concepto
       ,TRANSACCIONES.facturador
     
       ,(TRANSACCIONES.comision * -1) AS comision
       ,'Penalizacion - Alta Baja Intramarca' AS comments
       ,TRANSACCIONES.commission_id AS process_code

FROM `mm-commissions-reporting.TEMP.PABIN_altas_nuevas_fijo` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.PABIN_bajas_intramarca_fijo` B
ON TRANSACCIONES.hash_id = B.hash_id
  AND DATE(B.deactivation_date) BETWEEN DATE_SUB(DATE(TRANSACCIONES.activation_date), INTERVAL 30 DAY) AND DATE_ADD(DATE(TRANSACCIONES.activation_date), INTERVAL 30 DAY)

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE TRANSACCIONES.canal = canal_pr
AND B.service_type = 'INTERNET'
AND TRANSACCIONES.MARCA = B.brand_ds
AND TRANSACCIONES.concepto IN (
                              'A - Servicio Fijo',
                              'A - Servicio Fijo 2da Vivienda',
                              'A - Portabilidad Fijo',
                              'D - Extracomision Objetivo fijo'
                              )
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.phone_nm, TRANSACCIONES.marca, TRANSACCIONES.concepto, CAST(TRANSACCIONES.comision AS STRING)) =1
)

)
;
END IF
;


-- Penalizacion Intramarca TLV - Web + TLV - Cross-sell IN + DOL-- FIJO 
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('WA','XI','DO')) THEN

INSERT INTO TEMP.pabin 
(SELECT
  * EXCEPT(rn_alta,total_bajas)
  ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id
FROM (
SELECT DISTINCT
        TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad,hash_id, document_hash)
       ,id_mes_pr AS id_mes
       ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
       ,'calculado' AS estado

       ,CASE
            WHEN SUBSTR(TRANSACCIONES.concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(TRANSACCIONES.concepto, 2, LENGTH(TRANSACCIONES.concepto)))
            ELSE CONCAT('Q', SUBSTR(TRANSACCIONES.concepto, 2, LENGTH(TRANSACCIONES.concepto)))
        END AS concepto

       ,TRANSACCIONES.tipo_concepto
       ,TRANSACCIONES.facturador
     
       ,(TRANSACCIONES.comision * -1) AS comision
       ,'Penalizacion - Alta Baja Intramarca' AS comments
       ,TRANSACCIONES.commission_id AS process_code

       --  NUMERAMOS ALTAS POR CLIENTE
       ,ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.hash_id ORDER BY TRANSACCIONES.sale_date ASC,TRANSACCIONES.service_id ASC) AS rn_alta

       -- CONTAMOS BAJAS POR CLIENTE
       ,COUNT(DISTINCT B.service_id) OVER (PARTITION BY TRANSACCIONES.hash_id) AS total_bajas

FROM `mm-commissions-reporting.TEMP.PABIN_altas_nuevas_fijo` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.PABIN_bajas_intramarca_fijo` B
ON TRANSACCIONES.hash_id = B.hash_id
  AND DATE(B.deactivation_date) BETWEEN DATE_SUB(DATE(TRANSACCIONES.activation_date), INTERVAL 30 DAY) AND DATE_ADD(DATE(TRANSACCIONES.activation_date), INTERVAL 30 DAY)
  AND TRANSACCIONES.service_id != B.service_id

LEFT JOIN `mm-commissions-reporting.TEMP.PABIN_portabilidades_fijo` PORTABILIDADES
  ON TRANSACCIONES.hash_id = PORTABILIDADES.hash_id

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE TRANSACCIONES.canal = canal_pr
AND B.billing_type_ds = 'POSTPAID'
AND B.service_type = 'INTERNET'
AND TRANSACCIONES.order_type_agg = 'ALTA NUEVA'
AND TRANSACCIONES.MARCA != B.brand_ds
AND B.brand_ds IN ('YOIGO','MASMOVIL','ORANGE','JAZZTEL')
AND PORTABILIDADES.hash_id IS NULL 
AND TRANSACCIONES.concepto IN (
                              'A - Servicio Fijo',
                              'A - Portabilidad Fijo'
                              )
QUALIFY rn_alta <= total_bajas

)
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, phone_nm, marca) =1
)
;
END IF

;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr,'TEMP.pabin', 'ACTUALIZAR');


END