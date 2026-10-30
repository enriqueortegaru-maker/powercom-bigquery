BEGIN

DECLARE prefijo, mes_string STRING;

SET prefijo = 'PINTR';

SET mes_string = CAST(id_mes_pr AS STRING);

SET canales_pr = COALESCE(canales_pr, ['D2D', 'D2N', 'DEM', 'ECI', 'EDB', 'EML', 'ENX' 'EYG', 'MP', 'OU', 'OUN']);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_pintr`(202607, ['EML']);
*/




DROP TABLE TEMP.pintr;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.pintr`
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
,commission_id               STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comision                    FLOAT64
,comments                    STRING
,process_code                STRING
)
;


-- Penalizacion Portabilidades Intragrupo D2D --

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D', 'D2N', 'DEM')) THEN

INSERT INTO TEMP.pintr -- Penalizacion Portabilidades Intragrupo D2D
(
SELECT DISTINCT
        TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad)
       ,id_mes_pr AS id_mes
       ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
       ,'calculado' AS estado
       ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id

       ,'P - Servicio Movil Pospago' AS concepto

       ,tipo_concepto
       ,facturador
     
       ,-15 AS comision
       ,'Penalizacion - Portabilidades Intragrupo' AS comments
       ,TRANSACCIONES.commission_id AS process_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

/*
LEFT JOIN (
          SELECT
                mes_activacion
               ,customer_id
               ,brand_ds
          FROM (
               SELECT
                     *
          
                    ,CASE
                         WHEN customer_id = '0' THEN flag_bundle_intragroup
                         ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                     END AS flag_customer_intragroup
          
               FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               WHERE mes_activacion = id_mes_pr
               )
          WHERE flag_customer_intragroup = 'Intragrupo'
          GROUP BY 1,2,3
          ) INTRA_CUSTOMER
         ON TRANSACCIONES.id_mes = INTRA_CUSTOMER.mes_activacion AND TRANSACCIONES.customer_id = INTRA_CUSTOMER.customer_id AND TRANSACCIONES.marca = INTRA_CUSTOMER.brand_ds

LEFT JOIN (
          SELECT
                mes_activacion
               ,account_id
               ,service_id
               ,brand_ds
          FROM (
               SELECT
                     *
          
                    ,CASE
                         WHEN customer_id = '0' THEN flag_bundle_intragroup
                         ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                     END AS flag_customer_intragroup
          
               FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               WHERE mes_activacion = id_mes_pr
               )
          WHERE flag_customer_intragroup = 'NO Intragrupo'
                AND servicio_movil_intragrupo = 1
          GROUP BY 1,2,3,4
          ) INTRA_SERVICE
         ON TRANSACCIONES.id_mes = INTRA_SERVICE.mes_activacion AND TRANSACCIONES.account_id = INTRA_SERVICE.account_id AND TRANSACCIONES.service_id = INTRA_SERVICE.service_id
            AND TRANSACCIONES.marca = INTRA_SERVICE.brand_ds

LEFT JOIN (
          SELECT
                mes_activacion
               ,account_id
               ,service_id
               ,brand_ds
               ,MAX(operador_donante_unificado) AS operador_donante_unificado
          FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
          GROUP BY 1,2,3,4
          ) INTRA_DONANTE
         ON TRANSACCIONES.id_mes = INTRA_DONANTE.mes_activacion 
         AND TRANSACCIONES.account_id = INTRA_DONANTE.account_id 
         AND TRANSACCIONES.service_id = INTRA_DONANTE.service_id
         AND TRANSACCIONES.marca = INTRA_DONANTE.brand_ds
*/
LEFT JOIN (
          SELECT
                mes_activacion,
                account_id,
                phone_nm,
                brand_ds
          FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               
          WHERE grupo_operador_donante_unificado in ('GRUPO MASMOVIL','GRUPO ORANGE','ORANGE')
          AND mes_activacion = id_mes_pr
          GROUP BY 1,2,3,4
          ) INTRA_SERVICE
         ON TRANSACCIONES.id_mes = INTRA_SERVICE.mes_activacion
         AND TRANSACCIONES.account_id = INTRA_SERVICE.account_id
         AND TRANSACCIONES.phone_nm = CAST(INTRA_SERVICE.phone_nm AS STRING)
         AND TRANSACCIONES.marca = INTRA_SERVICE.brand_ds

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal IN ('D2D', 'D2N', 'DEM')
      AND TRANSACCIONES.activation_date >= PARSE_DATE('%Y%m', mes_string)
      AND TRANSACCIONES.tariff_ds like '%PRO%'
      AND TRANSACCIONES.service_type = 'MOBILE'
      AND TRANSACCIONES.order_type_agg = 'PORTABILIDAD'
      AND TRANSACCIONES.deactivation_date >= DATE_ADD(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      AND INTRA_SERVICE.grupo_operador_donante_unificado in ('GRUPO MASMOVIL','GRUPO ORANGE','ORANGE')
      AND TRANSACCIONES.concepto IN (
                                     'A - Portabilidad Fijo',
                                     'A - Portabilidad Movil Pospago',
                                     'A - Servicio Fijo',
                                     'A - Servicio Fijo Cambio de Domicilio',
                                     'A - Servicio Movil Pospago',
                                     'A - Servicio Movil Prepago'
                                     'D - Servicio Movil PACK 5'
                                     'D - Servicio Movil PACK 15'
                                     'D - Servicio Movil PACK 25'
                                     )
     -- AND (INTRA_CUSTOMER.brand_ds IS NOT NULL OR INTRA_SERVICE.brand_ds IS NOT NULL    
     AND INTRA_SERVICE.brand_ds IS NOT NULL                           
)
;

END IF;


-- Penalizacion Portabilidades Intragrupo NO EXCLUSIVO MASPROXIMO --

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('MP')) THEN

INSERT INTO TEMP.pintr -- Penalizacion Portabilidades Intragrupo NO EXCLUSIVO MASPROXIMO
(
SELECT *

FROM (
     SELECT
           TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code,  emails_acceso_trazabilidad)
          ,id_mes_pr AS id_mes
          ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
          ,'calculado' AS estado
          ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id

          ,CASE
               WHEN SUBSTR(concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(concepto, 2, LENGTH(concepto)))
               ELSE CONCAT('Q', SUBSTR(concepto, 2, LENGTH(concepto)))
           END AS concepto

          ,tipo_concepto
          ,facturador
     
          ,CASE
               WHEN concepto IN ('D - Acelerador Puntos')
               THEN
                    CASE
                        WHEN TRANSACCIONES.service_type = 'INTERNET' AND TRANSACCIONES.cod_segmento IN ('12', '30')
                        THEN 4.5
                        WHEN TRANSACCIONES.service_type = 'INTERNET' AND TRANSACCIONES.cod_segmento NOT IN ('12', '30')
                        THEN 3.0
                        ELSE 1.0
                    END
               * PUNTOS.comision * -1
     
               WHEN concepto IN ('D - Blindaje "Panzer"')
               THEN
                    CASE
                        WHEN TRANSACCIONES.service_type = 'INTERNET' AND TRANSACCIONES.cod_segmento IN ('12', '30')
                        THEN 4.5
                        WHEN TRANSACCIONES.service_type = 'INTERNET' AND TRANSACCIONES.cod_segmento NOT IN ('12', '30')
                        THEN 3.0
                        ELSE 1.0
                    END
               * 5 * -1

               WHEN concepto NOT IN ('D - Acelerador Puntos', 'D - Blindaje "Panzer"')
               THEN TRANSACCIONES.comision * -.5
     
               ELSE 0.0
           END AS comision
     
          ,CONCAT('Penalizacion - Portabilidades Intragrupo') AS comments
          ,TRANSACCIONES.commission_id AS process_code
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
     INNER JOIN `mm-commissions-reporting.GS.no_exclusivo_portabilidades_intragrupo` INTRA
               ON TRANSACCIONES.id_comisionista = INTRA.seller AND INTRA.id_mes = id_mes_pr

     LEFT JOIN (
               SELECT
                     mes_activacion
                    ,customer_id
                    ,brand_ds
               FROM (
                    SELECT
                          *
               
                         ,CASE
                              WHEN customer_id = '0' THEN flag_bundle_intragroup
                              ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                          END AS flag_customer_intragroup
               
                    FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion_COMM`
                    WHERE mes_activacion = CAST(SUBSTR(REPLACE(CAST(DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH) AS STRING), '-', ''),1,6) AS INT64)
                    )
               WHERE flag_customer_intragroup = 'Intragrupo'
               GROUP BY 1,2,3
               ) INTRA_CUSTOMER
              ON TRANSACCIONES.id_mes = INTRA_CUSTOMER.mes_activacion AND TRANSACCIONES.customer_id = INTRA_CUSTOMER.customer_id AND TRANSACCIONES.marca = INTRA_CUSTOMER.brand_ds
     
     LEFT JOIN (
               SELECT
                     mes_activacion
                    ,account_id
                    ,service_id
                    ,brand_ds
               FROM (
                    SELECT
                          *
               
                         ,CASE
                              WHEN customer_id = '0' THEN flag_bundle_intragroup
                              ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                          END AS flag_customer_intragroup
               
                    FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion_COMM`
                    WHERE mes_activacion = CAST(SUBSTR(REPLACE(CAST(DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH) AS STRING), '-', ''),1,6) AS INT64)
                    )
               WHERE flag_customer_intragroup = 'NO Intragrupo'
                     AND servicio_movil_intragrupo = 1
               GROUP BY 1,2,3,4
               ) INTRA_SERVICE
              ON TRANSACCIONES.id_mes = INTRA_SERVICE.mes_activacion AND TRANSACCIONES.account_id = INTRA_SERVICE.account_id AND TRANSACCIONES.service_id = INTRA_SERVICE.service_id
                 AND TRANSACCIONES.marca = INTRA_SERVICE.brand_ds

     LEFT JOIN (
               SELECT
                     sfid AS sfid_id
                    ,comision
               
               FROM (
                    SELECT
                          * EXCEPT(puntos)
                         ,CASE
                              WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 0   AND SUM(puntos) OVER (PARTITION BY sfid) < 30  THEN 0
                              WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 30  AND SUM(puntos) OVER (PARTITION BY sfid) < 60  THEN 6
                              WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 60  AND SUM(puntos) OVER (PARTITION BY sfid) < 90  THEN 9
                              WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 90  AND SUM(puntos) OVER (PARTITION BY sfid) < 120 THEN 12
                              WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 120 AND SUM(puntos) OVER (PARTITION BY sfid) < 150 THEN 15
                              WHEN SUM(puntos) OVER (PARTITION BY sfid) >= 150                                                THEN 18
                          END AS comision
                    FROM `mm-sales-reporting.SPEEDUP.nex_ds_puntos_pdv_*`
                    WHERE _table_suffix = CONCAT(SUBSTR(REPLACE(CAST(DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH) AS STRING), '-', ''),1,6), '01')
                    )
               
               GROUP BY 1,2
               ) PUNTOS
              ON (TRANSACCIONES.seller = PUNTOS.sfid_id OR TRANSACCIONES.id_comisionista = PUNTOS.sfid_id)
     
     CROSS JOIN UNNEST(canales_pr) canal_pr
     
     WHERE TRANSACCIONES.id_mes = CAST(SUBSTR(REPLACE(CAST(DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH) AS STRING), '-', ''),1,6) AS INT64)
           AND TRANSACCIONES.canal = canal_pr
           AND TRANSACCIONES.activation_date >= DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH)
           AND TRANSACCIONES.deactivation_date >= PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
           AND TRANSACCIONES.concepto IN (
                                         'A - Portabilidad Fijo',
                                         'A - Portabilidad Movil Pospago',
                                         'A - Servicio Fijo',
                                         'A - Servicio Fijo Cambio de Domicilio',
                                         'A - Servicio Movil Pospago',
                                         'A - Servicio Movil Prepago',
                                         'D - Acelerador Puntos',
                                         'D - Blindaje "Panzer"',
                                         'F - Servicio Fijo',
                                         'F - Servicio Movil Pospago'
                                         )
           AND (INTRA_CUSTOMER.brand_ds IS NOT NULL OR INTRA_SERVICE.brand_ds IS NOT NULL)
     QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.commission_id) = 1
     )

WHERE comision <> 0.0
)
;

END IF;


-- Penalizacion Portabilidades Intragrupo TELEVENTA OUTBOUND --

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('OU')) THEN

INSERT INTO TEMP.pintr -- Penalizacion Portabilidades Intragrupo TELEVENTA OUTBOUND
(
SELECT DISTINCT
        TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad)
       ,id_mes_pr AS id_mes
       ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
       ,'calculado' AS estado
       ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id

       ,CASE
            WHEN SUBSTR(concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(concepto, 2, LENGTH(concepto)))
            ELSE CONCAT('Q', SUBSTR(concepto, 2, LENGTH(concepto)))
        END AS concepto

       ,tipo_concepto
       ,facturador
     
       ,(TRANSACCIONES.comision/-2) AS comision
       ,'Penalizacion - Portabilidades Intragrupo 50%' AS comments
       ,TRANSACCIONES.commission_id AS process_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT
                mes_activacion
               ,customer_id
               ,brand_ds
          FROM (
               SELECT
                     *
          
                    ,CASE
                         WHEN customer_id = '0' THEN flag_bundle_intragroup
                         ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                     END AS flag_customer_intragroup
          
               FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               WHERE mes_activacion = id_mes_pr
               )
          WHERE flag_customer_intragroup = 'Intragrupo'
          GROUP BY 1,2,3
          ) INTRA_CUSTOMER
         ON TRANSACCIONES.id_mes = INTRA_CUSTOMER.mes_activacion AND TRANSACCIONES.customer_id = INTRA_CUSTOMER.customer_id AND TRANSACCIONES.marca = INTRA_CUSTOMER.brand_ds

LEFT JOIN (
          SELECT
                mes_activacion
               ,account_id
               ,service_id
               ,brand_ds
          FROM (
               SELECT
                     *
          
                    ,CASE
                         WHEN customer_id = '0' THEN flag_bundle_intragroup
                         ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                     END AS flag_customer_intragroup
          
               FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               WHERE mes_activacion = id_mes_pr
               )
          WHERE flag_customer_intragroup = 'NO Intragrupo'
                AND servicio_movil_intragrupo = 1
          GROUP BY 1,2,3,4
          ) INTRA_SERVICE
         ON TRANSACCIONES.id_mes = INTRA_SERVICE.mes_activacion AND TRANSACCIONES.account_id = INTRA_SERVICE.account_id AND TRANSACCIONES.service_id = INTRA_SERVICE.service_id
            AND TRANSACCIONES.marca = INTRA_SERVICE.brand_ds

LEFT JOIN (
          SELECT
                mes_activacion
               ,account_id
               ,service_id
               ,brand_ds
               ,MAX(operador_donante_unificado) AS operador_donante_unificado
          FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
          GROUP BY 1,2,3,4
          ) INTRA_DONANTE
         ON TRANSACCIONES.id_mes = INTRA_DONANTE.mes_activacion AND TRANSACCIONES.account_id = INTRA_DONANTE.account_id AND TRANSACCIONES.service_id = INTRA_DONANTE.service_id
            AND TRANSACCIONES.marca = INTRA_DONANTE.brand_ds

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = 'OU'
      AND TRANSACCIONES.activation_date >= PARSE_DATE('%Y%m', mes_string)
      AND TRANSACCIONES.deactivation_date >= DATE_ADD(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      AND TRANSACCIONES.concepto NOT LIKE 'B%'
      AND TRANSACCIONES.concepto NOT LIKE 'P%'
      AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%ENERGIA%'
      AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%TELEVISION%'
      AND TRANSACCIONES.concepto NOT IN (
                                        'C - Cartera',
                                        'D - Camp. Apoyo Pre a Post',
                                        'D - Incentivo crecimiento 2023',
                                        'D - Incentivo vendedor'
                                        )
      AND TRANSACCIONES.id_comisionista NOT IN (
                                               'AI',
                                               'SL',
                                               'TLVOU001',
                                               'TLVOU003', -- todas sus activaciones provienen de prepago 11/06/24
                                               'TLVOU019',
                                               'TLVOU022',
                                               'TLVOU024',
                                               'TLVOU028',
                                               'TLVOU029'
                                               )
      AND NOT (TRANSACCIONES.id_comisionista = 'TLVOU004' AND COALESCE(INTRA_DONANTE.operador_donante_unificado,'Z') IN ('MASMOVIL'))
      AND NOT (TRANSACCIONES.id_comisionista = 'TLVOU007' AND COALESCE(INTRA_DONANTE.operador_donante_unificado,'Z') IN ('LLAMAYA','YOIGO'))
      AND NOT (TRANSACCIONES.id_comisionista = 'TLVOU0014' AND COALESCE(INTRA_DONANTE.operador_donante_unificado,'Z') IN ('MASMOVIL'))
      AND (INTRA_CUSTOMER.brand_ds IS NOT NULL OR INTRA_SERVICE.brand_ds IS NOT NULL)
)
;

END IF;


-- Penalizacion Portabilidades Intragrupo TELEVENTA NEGOCIOS OUTBOUND --

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('OUN')) THEN

INSERT INTO TEMP.pintr -- Penalizacion Portabilidades Intragrupo TELEVENTA NEGOCIOS OUTBOUND
(
SELECT DISTINCT
        TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad)
       ,id_mes_pr AS id_mes
       ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
       ,'calculado' AS estado
       ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id

       ,CASE
            WHEN SUBSTR(concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(concepto, 2, LENGTH(concepto)))
            ELSE CONCAT('Q', SUBSTR(concepto, 2, LENGTH(concepto)))
        END AS concepto

       ,tipo_concepto
       ,facturador
     
       ,(TRANSACCIONES.comision/-2) AS comision
       ,'Penalizacion - Portabilidades Intragrupo 50%' AS comments
       ,TRANSACCIONES.commission_id AS process_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT
                mes_activacion
               ,customer_id
               ,brand_ds
          FROM (
               SELECT
                     *
          
                    ,CASE
                         WHEN customer_id = '0' THEN flag_bundle_intragroup
                         ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                     END AS flag_customer_intragroup
          
               FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               WHERE mes_activacion = id_mes_pr
               )
          WHERE flag_customer_intragroup = 'Intragrupo'
          GROUP BY 1,2,3
          ) INTRA_CUSTOMER
         ON TRANSACCIONES.id_mes = INTRA_CUSTOMER.mes_activacion AND TRANSACCIONES.customer_id = INTRA_CUSTOMER.customer_id AND TRANSACCIONES.marca = INTRA_CUSTOMER.brand_ds

LEFT JOIN (
          SELECT
                mes_activacion
               ,account_id
               ,service_id
               ,brand_ds
          FROM (
               SELECT
                     *
          
                    ,CASE
                         WHEN customer_id = '0' THEN flag_bundle_intragroup
                         ELSE MIN(flag_bundle_intragroup) OVER (PARTITION BY mes_activacion, customer_id, brand_ds)
                     END AS flag_customer_intragroup
          
               FROM `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion`
               WHERE mes_activacion = id_mes_pr
               )
          WHERE flag_customer_intragroup = 'NO Intragrupo'
                AND servicio_movil_intragrupo = 1
          GROUP BY 1,2,3,4
          ) INTRA_SERVICE
         ON TRANSACCIONES.id_mes = INTRA_SERVICE.mes_activacion AND TRANSACCIONES.account_id = INTRA_SERVICE.account_id AND TRANSACCIONES.service_id = INTRA_SERVICE.service_id
            AND TRANSACCIONES.marca = INTRA_SERVICE.brand_ds

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = 'OUN'
      AND TRANSACCIONES.marca IN ('MASMOVIL', 'YOIGO')
      AND TRANSACCIONES.activation_date >= PARSE_DATE('%Y%m', mes_string)
      AND TRANSACCIONES.deactivation_date >= DATE_ADD(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      AND TRANSACCIONES.concepto NOT LIKE 'B%'
      AND TRANSACCIONES.concepto NOT LIKE 'P%'
      AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%ENERGIA%'
      AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%TELEVISION%'
      AND concepto NOT IN (
                          'D - Bonus'
                          )
      AND (INTRA_CUSTOMER.brand_ds IS NOT NULL OR INTRA_SERVICE.brand_ds IS NOT NULL)
)
;

END IF;


-- Penalizacion Portabilidades Intragrupo EXCLUSIVO --

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG','ENX')) THEN

INSERT INTO TEMP.pintr -- Penalizacion Portabilidades Intragrupo EXCLUSIVO
(
SELECT *

FROM (
     SELECT
           TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad)
          ,id_mes_pr AS id_mes
          ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
          ,'calculado' AS estado
          ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id

          ,CASE
               WHEN SUBSTR(concepto,1,1) <> 'F' THEN CONCAT('P', SUBSTR(concepto, 2, LENGTH(concepto)))
               ELSE CONCAT('Q', SUBSTR(concepto, 2, LENGTH(concepto)))
           END AS concepto

          ,tipo_concepto
          ,facturador
     
          ,CASE
               /*WHEN concepto IN ('D - Extracomision Objetivo fijo', 'D - Extracomision Objetivo Movil Pospago') AND cuenta_para_objetivos = 'NO'
               THEN comision * -1*/
     
               WHEN pago_comisiones < 1
               THEN (comision * (1 - pago_comisiones)) * -1
     
               ELSE 0.0
           END AS comision
     
          ,CONCAT('Penalizacion - Portabilidades Intragrupo (', CAST(((1 - pago_comisiones) * 100) AS STRING), '%)') AS comments
          ,TRANSACCIONES.commission_id AS process_code
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
     INNER JOIN `mm-commissions-reporting.GS.exclusivo_portabilidades_intragrupo` INTRA
               ON TRANSACCIONES.seller = INTRA.seller AND TRANSACCIONES.id_mes = INTRA.id_mes
     
     INNER JOIN (SELECT user_store, account_id FROM `mm-commissions-reporting.GS.exclusivo_intragrupos_x_account_id` GROUP BY 1,2) XACCOUNT
               ON TRANSACCIONES.seller = XACCOUNT.user_store AND TRANSACCIONES.account_id = XACCOUNT.account_id
     
     CROSS JOIN UNNEST(canales_pr) canal_pr
     
     WHERE TRANSACCIONES.id_mes = id_mes_pr
           AND TRANSACCIONES.canal = canal_pr
           AND TRANSACCIONES.activation_date >= PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
           AND TRANSACCIONES.deactivation_date >= COALESCE(DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH), '9999-12-31')
           AND TRANSACCIONES.concepto IN (
                                         'A - Cambio de Titularidad',
                                         'A - Portabilidad Fijo',
                                         'A - Portabilidad Movil Pospago',
                                         'A - Servicio Fijo',
                                         'A - Servicio Movil Pospago',
                                         'D - Extracomision fijo a lo Pepe',
                                         'D - Extracomision Objetivo Movil Pospago',
                                         'D - Extracomision Objetivo fijo',
                                         'D - Extracomision Segmentacion',
                                         'D - Extracomision terminal',
                                         'D - Servicio Movil PACK 25',
                                         'D - Servicio Movil PACK 15',
                                         'D - Servicio Movil PACK 5',
                                         'F - Servicio Fijo',
                                         'F - Servicio Movil Pospago'
                                         )
     )

WHERE comision <> 0.0
)
;

END IF;


-- -- Penalizacion Portabilidades Intermarca EXCLUSIVO ENK --

-- -- Dúos y compartidas gratuitas

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` AS 

-- SELECT data_month_id,A.phone_nm,A.service_id,A.brand_ds,A.tariff_id,concept_type_ds,concept_ds 
--           FROM `mm-commissions-reporting.COMISIONES.activaciones` A
--           LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_emysim` F
--                 ON A.service_id = F.service_id AND A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id
--           WHERE A.id_mes = id_mes_pr
--           AND A.agrupacion_canal = 'Exclusivo' 
--           AND concept_type_ds = 'Promociones'
--           AND (
--                A.tariff_id IN ('8205','8212') -- ¿INCLUIR 8145?
--                AND F.brand_ds = 'YOIGO'
--                AND UPPER(concept_ds) LIKE '%DESCUENTO 100%DÚO PRINCIPAL%'
--                OR
--                A.tariff_id IN ('7108')
--                AND F.brand_ds = 'MASMOVIL'
--                AND UPPER(concept_ds) LIKE 'MM_DTO TARIFA MAS COMPARTIDA_3 EUROS'
--                OR
--                A.tariff_id IN ('7115')
--                AND F.brand_ds = 'MASMOVIL'
--                AND UPPER(concept_ds) LIKE 'MM_DTO LINEA ADICIONAL COMPARTIDA PRO'
--                )
--           AND data_month_id = id_mes_pr
--           QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm,service_id,brand_ds) = 1

-- ;

-- -- Duos y compartidas con coste y comisión 

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.compartidas_coste_exc` AS

-- SELECT A.phone_nm, A.service_id, B.main_mobile_tariff_id, B.main_mobile_tariff_name, T.tramo_1 AS comision

--             FROM `mm-commissions-reporting.COMISIONES.activaciones` A
            
--             LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_emysim` F
--                ON A.service_id = F.service_id AND A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id

--             LEFT JOIN `mm-commissions-reporting.TEMP.disgregacion_bundles_exc` B
--                ON B.bundle_id = F.bundle_id 
            
--             LEFT JOIN (SELECT * EXCEPT(creado, creado_por) FROM `mm-commissions-reporting.COMISIONES.tarifas` GROUP BY ALL) T
--                ON T.tariff_id = B.main_mobile_tariff_id    
            
--             WHERE A.tariff_id IN ('8205','8212','7108','7115')
--             AND A.agrupacion_canal = 'Exclusivo'
--             AND A.canal = 'ENK'
--             AND data_month_id = id_mes_pr
--             AND concept_type_ds = 'Cuotas'
--             AND A.service_id NOT IN (SELECT service_id FROM `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` )
--             AND T.canal = 'ENK'
--             AND T.id_mes = id_mes_pr
-- QUALIFY ROW_NUMBER() OVER(PARTITION BY F.phone_nm, F.service_id, F.tariff_id ORDER BY DATE_DIFF(end_date,init_date,DAY) DESC) = 1

-- ;

-- IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

-- INSERT INTO TEMP.pintr -- Penalizacion Portabilidades Intermarca EXCLUSIVO ENK
-- (
-- SELECT SERVICIOS.* EXCEPT(concepto,tipo_concepto,facturador, comision,comments,process_code)
--        ,prefijo||'_'||mes_string||'_'||SERVICIOS.canal||'_'||ROW_NUMBER () OVER () AS commission_id
--        ,SERVICIOS.concepto
--        ,SERVICIOS.tipo_concepto
--        ,SERVICIOS.facturador
--        ,SERVICIOS.comision
--        ,SERVICIOS.comments
--        ,SERVICIOS.process_code

-- FROM 
--      (
--      SELECT
--            TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad)
--            ,id_mes_pr AS id_mes
--            ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
--            ,'calculado' AS estado
--            ,CONCAT('P', SUBSTR(concepto, 2, LENGTH(concepto))) AS concepto
--            ,tipo_concepto
--            ,facturador  
--            ,INTER.importe_comision AS comision    
--            ,CONCAT('Penalizacion - Portabilidades Intermarca') AS comments
--            ,TRANSACCIONES.commission_id AS process_code
     
--      FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

--      INNER JOIN `mm-commissions-reporting.GS.exclusivo_portas_intermarca` INTER
--                ON TRANSACCIONES.phone_nm = INTER.phone_nm AND TRANSACCIONES.account_id = INTER.account_id

--      WHERE TRANSACCIONES.id_mes = id_mes_pr
--            AND TRANSACCIONES.concepto in ('A - Servicio Fijo','A - Servicio Movil Pospago')
--            AND TRANSACCIONES.activation_date >= PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
--            AND TRANSACCIONES.deactivation_date >= COALESCE(DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH), '9999-12-31')

--      UNION ALL

--      SELECT
--            agrupacion_canal
--           ,ACTIVACIONES.canal
--           ,1 as unidades
--           ,id_comisionista
--           ,distribuidor
--           ,ACTIVACIONES.sfid_id
--           ,seller
--           ,nombre_comercio
--           ,razon_social
--           ,ACTIVACIONES.cif
--           ,zona_fiscal
--           ,'Z005' AS cond_pago
--           ,ACTIVACIONES.marca
--           ,ACTIVACIONES.service_type
--           ,ACTIVACIONES.phone_nm
--           ,ACTIVACIONES.tariff_id
--           ,ACTIVACIONES.tariff_ds
--           ,ACTIVACIONES.service_id
--           ,ACTIVACIONES.account_id
--           ,ACTIVACIONES.customer_id
--           ,ACTIVACIONES.line_type_ds
--           ,bundle_type
--           ,technology_ds
--           ,billing_type_ds
--           ,sale_date
--           ,activation_date
--           ,deactivation_date
--           ,order_id
--           ,order_type_agg
--           ,cod_segmento
--           ,cod_marca
--           ,cod_tipo_contrato
--           ,cod_producto
--           ,cod_canal
--           ,CAST(NULL AS STRING)  AS campaign_code
--           ,CAST(NULL AS STRING)  AS serial_number
--           ,CAST(NULL AS FLOAT64) AS tax_base
--           ,CAST(NULL AS STRING)  AS claim_code
--           ,CAST(NULL AS STRING) AS proceso_sap
--           ,CAST(NULL AS STRING) AS id_registro
--           ,CAST(NULL AS STRING) AS invoice_id
--           ,sociedad
--           ,CAST(NULL AS STRING) AS bp
--           ,CAST(NULL AS STRING) AS cuenta_contable
--           ,CAST(NULL AS STRING) AS centro_coste
--           ,CAST(NULL AS STRING) AS documento_sap
--           ,CAST(NULL AS STRING) AS documento_sap_posicion
--           ,CAST(NULL AS STRING) AS fecha_contabilizacion
--           ,CAST(NULL AS TIMESTAMP) AS creado
--           ,CAST(NULL AS TIMESTAMP) AS modificado
--           ,CAST(NULL AS STRING) AS id_factura_drive
--           ,id_mes_pr AS id_mes
--           ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
--           ,'calculado' AS estado
          
--           ,CASE
--                WHEN ACTIVACIONES.service_type = 'MOBILE'   THEN 'P - Servicio Movil Pospago'
--                WHEN ACTIVACIONES.service_type = 'INTERNET' THEN 'P - Servicio Fijo' 
--            END AS concepto

--           ,'UPFR' AS tipo_concepto
--           ,'C_MANUAL' AS facturador
       
--           ,CASE 
--                WHEN INTER.importe_comision > 0 THEN INTER.importe_comision
--                WHEN INTER.importe_comision < 0 THEN 0.0 -- HACER CASE CON LA SUMATORIA DE LAS COMISIONES CALCULADAS A DUO Y COMPARTIDAS CON COSTE PARA QUE EL DESCUENTO NO DÉ NEGATIVO 
--            END AS comision    

--           ,'Penalizacion - Portabilidades Intermarca' AS comments
--           ,CAST(null AS STRING) AS process_code

--      FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
     
--      INNER JOIN `mm-commissions-reporting.GS.exclusivo_portas_intermarca` INTER
--           ON ACTIVACIONES.phone_nm = INTER.phone_nm AND ACTIVACIONES.account_id = INTER.account_id
     
--      LEFT JOIN `mm-commissions-reporting.TEMP.compartidas_coste_exc` DUO_COSTE
--           ON DUO_COSTE.phone_nm = CAST(ACTIVACIONES.phone_nm AS INT64) AND DUO_COSTE.service_id = ACTIVACIONES.service_id -- si falla intentar cruzar sólo por service_id y cambiar phone_nm por service_id en WHERE
     
--      -- LEFT JOIN (
--      --            SELECT CAST(ACT.phone_nm AS INT64) phone_nm, ACT.service_id, ACT.marca
--      --            FROM `mm-datamart-kd.BILLING.billing_detail_net` BILLING
--      --            INNER JOIN `mm-commissions-reporting.COMISIONES.activaciones` ACT
--      --                 ON BILLING.phone_nm = CAST(ACT.phone_nm AS INT64) AND BILLING.service_id = ACT.service_id AND BILLING.brand_ds = ACT.marca AND BILLING.data_month_id = ACT.id_mes
--      --            WHERE BILLING.data_month_id = id_mes_pr
--      --            AND BILLING.concept_type_ds = 'Consumos' 
--      --            AND ACT.tariff_id = '8205'
--      --            AND ACT.agrupacion_canal = 'Exclusivo'
--      --            AND ACT.order_type_agg LIKE '%PORTABILIDAD%'
--      --           ) DUO
--      --      ON DUO.phone_nm = CAST(ACTIVACIONES.phone_nm AS INT64) AND DUO.service_id = ACTIVACIONES.service_id AND DUO.marca = ACTIVACIONES.marca 
     
--      WHERE ACTIVACIONES.id_mes = id_mes_pr 
--            AND ACTIVACIONES.canal = 'ENK'
--            AND ACTIVACIONES.service_type IN ('MOBILE','INTERNET')
--            AND ACTIVACIONES.order_type_agg LIKE '%PORTABILIDAD%'
--            AND (
--                ACTIVACIONES.tariff_id IN ('7126','7127')
--                OR
--                ACTIVACIONES.tariff_id = '8205' AND DUO.phone_nm IS NULL
--                )

--      ) SERVICIOS

--      LEFT JOIN `mm-sales-reporting.TEMPORAL.ex_optico` OPTICO
--                ON  SERVICIOS.cif = OPTICO.NUMERO_DOCUMENTO AND SERVICIOS.seller = COALESCE(OPTICO.SFID_1,OPTICO.SFID_2,OPTICO.SFID_3)
     
--      CROSS JOIN UNNEST(['ENK']) canal_pr
     

-- WHERE SERVICIOS.canal = canal_pr 
--      AND comision <> 0.0
-- )
-- ;

-- END IF;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr,'TEMP.pintr', 'ACTUALIZAR');


END