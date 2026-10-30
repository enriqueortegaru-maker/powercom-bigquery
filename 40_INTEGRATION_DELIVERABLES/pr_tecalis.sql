BEGIN


/* GENERATES THE MONTHLY EXTRACTIONS FOR TECALIS DELIVERABLES */


/*
CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_tecalis`(202601, NULL, NULL, 1)
*/


/* Declares the variables to be used throughout the procedure */
DECLARE months ARRAY <DATE>;
DECLARE b INT64 DEFAULT 0;
DECLARE m INT64 DEFAULT 0;
DECLARE month_name, brand, loop_table_name, deliverable_table_name, copy_table_name, deliverable_qry, copy_qry STRING;
DECLARE month INT64;


/* If only the "start_month" variable is inputed, the procedure is executed for only one month. If the "end_month" variable is also introduced, the desired action is executed for all months between and including the "start_month" and the "end_month" */

IF end_month IS NULL THEN SET months = ARRAY(SELECT PARSE_DATE('%Y%m', CAST(start_month AS STRING)));
ELSE SET months = GENERATE_DATE_ARRAY(PARSE_DATE('%Y%m', CAST(start_month AS STRING)), PARSE_DATE('%Y%m', CAST(end_month AS STRING)), INTERVAL 1 MONTH);
END IF;


/* If the "brands" variable is null, the default values are inserted into the array */

IF ARRAY_LENGTH(brands) IS NULL THEN SET brands = ['GUUK', 'ENERGYGO', 'LLAMAYA', 'JAZZTEL', 'MASMOVIL', 'PEPEENERGY', 'PEPEPHONE', 'SIMYO', 'YOIGO','AP'];
END IF;


/* If the "nobackup" variable is null, the default value is 0 */

IF nobackup IS NULL THEN SET nobackup = 0;
END IF;


/* Validates concepts */
ASSERT NOT EXISTS
(
SELECT DISTINCT concepto
FROM (
     SELECT
           CASE
               WHEN TRANSACCIONES.concepto LIKE 'A%Portabilidad%Fijo%'                                  THEN 'ACTIVACIÓN FIJO'
               WHEN TRANSACCIONES.concepto LIKE 'A%Servicio%Fijo%'                                      THEN 'ACTIVACIÓN FIJO'
               WHEN TRANSACCIONES.concepto LIKE 'A%Extra%SOHO%'                                         THEN 'ACTIVACIÓN FIJO'
               -- WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%' AND TRANSACCIONES.service_type = 'INTERNET' THEN 'ACTIVACIÓN FIJO'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Portabilidad%Fijo%'                                  THEN 'ACTIVACIÓN FIJO'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Servicio%Fijo%'                                      THEN 'ACTIVACIÓN FIJO'
               WHEN TRANSACCIONES.concepto LIKE 'A%Portabilidad%Movil%'                                 THEN 'ACTIVACIÓN MOVIL'
               WHEN TRANSACCIONES.concepto LIKE 'A%Servicio%Movil%'                                     THEN 'ACTIVACIÓN MOVIL'
               -- WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%' AND TRANSACCIONES.service_type = 'MOBILE'   THEN 'ACTIVACIÓN MOVIL'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Portabilidad%Movil%'                                 THEN 'ACTIVACIÓN MOVIL'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Servicio%Movil%'                                     THEN 'ACTIVACIÓN MOVIL'
               WHEN TRANSACCIONES.concepto LIKE 'C%'                                                    THEN 'CARTERA'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Calidad%'                                            THEN 'CARTERA'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Cartera%'                                            THEN 'CARTERA'
               WHEN TRANSACCIONES.concepto LIKE 'E%'                                                    THEN 'CLAWBACK'
               WHEN TRANSACCIONES.concepto LIKE 'P%'                                                    THEN 'CLAWBACK'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Clawback%'                                           THEN 'CLAWBACK'
               WHEN TRANSACCIONES.concepto LIKE 'D%'                                                    THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE '%Extracomision%'                                       THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Acelerador%'                                         THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Apoyo%'                                              THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Blindaje%'                                           THEN 'INCENTIVOS Y APOYOS'
                    WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%'                                         THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Incentivo%'                                          THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Rappel%'                                             THEN 'INCENTIVOS Y APOYOS'
               WHEN TRANSACCIONES.concepto LIKE 'B%Renuevo%'                                            THEN 'RENOVE'
               WHEN TRANSACCIONES.concepto LIKE '%Renuevo%'                                             THEN 'RENOVE'
               WHEN TRANSACCIONES.concepto LIKE 'B%'                                                    THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE '%Alarmas%'                                             THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE '%Centralitas%'                                         THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE '%Energia%'                                             THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE '%energia%'                                             THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE '%SVG%'                                                 THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE 'Z%Television%'                                         THEN 'BONO'
               WHEN TRANSACCIONES.concepto LIKE 'T%'                                                    THEN 'TERMINAL'
               ELSE TRANSACCIONES.concepto
           END AS concepto
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     WHERE TRANSACCIONES.id_mes BETWEEN start_month AND end_month
           AND TRANSACCIONES.cif = 'B75728329'
     GROUP BY 1
     )
WHERE concepto LIKE '% - %'
) AS 'Hay conceptos que no están contemplados en la extracción'
;


WHILE m < ARRAY_LENGTH(months) DO -- Month Loop

/* Month Loop Counter */
SET m = m + 1;
SET b = 0;

SET month = CAST(SUBSTR(REPLACE(CAST(months[ORDINAL(m)] AS STRING), '-', ''), 1, 6) AS INT64);
SET month_name = REPLACE(CAST(months[ORDINAL(m)] AS STRING), '-', '');


WHILE b < ARRAY_LENGTH(brands) DO -- Brand Loop

/* Brand Loop Counter */
SET b = b + 1;

SET brand = LOWER(brands[ORDINAL(b)]);
SET loop_table_name = 'tecalis' || '_' || brand || '_' || month_name;


CREATE OR REPLACE TEMPORARY TABLE detalle AS
SELECT
      concepto
     ,id_comisionista
     ,phone_nm
     ,activation_date
     ,tariff_ds
     ,REPLACE(CAST(comision AS STRING), '.', ',') AS comision
     ,service_id
     ,importe_recarga
     ,porcentage_comision
     ,modalidad
     ,regularizacion
     ,invoice_id
     ,ROW_NUMBER() OVER () r

FROM (
     SELECT
           concepto
          ,id_comisionista
          ,phone_nm
          ,activation_date
          ,tariff_ds
          ,SUM(comision) AS comision
          ,service_id
          ,importe_recarga
          ,porcentage_comision
          ,modalidad
          ,regularizacion
          ,invoice_id
     
     FROM (
           SELECT
                 TRANSACCIONES.id_mes
               
                ,CASE
                     WHEN TRANSACCIONES.concepto LIKE 'A%Portabilidad%Fijo%'                                  THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Servicio%Fijo%'                                      THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Extra%SOHO%'                                         THEN 'ACTIVACIÓN FIJO'
                    --  WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%' AND TRANSACCIONES.service_type = 'INTERNET' THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Portabilidad%Fijo%'                                  THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Servicio%Fijo%'                                      THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Portabilidad%Movil%'                                 THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Servicio%Movil%'                                     THEN 'ACTIVACIÓN MOVIL'
                    --  WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%' AND TRANSACCIONES.service_type = 'MOBILE'   THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Portabilidad%Movil%'                                 THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Servicio%Movil%'                                     THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'C%'                                                    THEN 'CARTERA'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Calidad%'                                            THEN 'CARTERA'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Cartera%'                                            THEN 'CARTERA'
                     WHEN TRANSACCIONES.concepto LIKE 'E%'                                                    THEN 'CLAWBACK'
                     WHEN TRANSACCIONES.concepto LIKE 'P%'                                                    THEN 'CLAWBACK'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Clawback%'                                           THEN 'CLAWBACK'
                     WHEN TRANSACCIONES.concepto LIKE 'D%'                                                    THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE '%Extracomision%'                                       THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Acelerador%'                                         THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Apoyo%'                                              THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Blindaje%'                                           THEN 'INCENTIVOS Y APOYOS'
                         WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%'                                         THEN 'INCENTIVOS Y APOYOS'    
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Incentivo%'                                          THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Rappel%'                                             THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'B%Renuevo%'                                            THEN 'RENOVE'
                     WHEN TRANSACCIONES.concepto LIKE '%Renuevo%'                                             THEN 'RENOVE'
                     WHEN TRANSACCIONES.concepto LIKE 'B%'                                                    THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%Alarmas%'                                             THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%Centralitas%'                                         THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%Energia%'                                             THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%energia%'                                             THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%SVG%'                                                 THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Television%'                                         THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE 'T%'                                                    THEN 'TERMINAL'
                     ELSE TRANSACCIONES.concepto
                 END AS concepto
       
                ,TRANSACCIONES.order_id AS id_comisionista
                ,TRANSACCIONES.id_comisionista AS id_mm
                ,REPLACE(TRANSACCIONES.campaign_code, 'TECALIS ', '') AS mm_cif
     
               --  ,CASE WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes' THEN CAST(NULL AS STRING) ELSE TRANSACCIONES.phone_nm END AS phone_nm
                ,CASE WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes' THEN CAST(NULL AS STRING) 
                      WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil' THEN CAST(NULL AS STRING)
                    --   WHEN TRANSACCIONES.concepto LIKE '%Servicio%Fijo%' AND TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.account_id  
                      WHEN TRANSACCIONES.service_type LIKE '%INTERNET%' AND TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id  
                      WHEN TRANSACCIONES.concepto LIKE '%Trade Go to Market' THEN CAST(NULL AS STRING)
                         ELSE TRANSACCIONES.phone_nm END AS phone_nm
     
                ,CASE WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes' THEN CAST(NULL AS DATE) 
                      WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil' THEN CAST(NULL AS DATE)
                      WHEN TRANSACCIONES.concepto LIKE '%Trade Go to Market' THEN CAST(NULL AS DATE)
                         ELSE TRANSACCIONES.activation_date END AS activation_date
           
                ,CASE
                    --  WHEN TRANSACCIONES.concepto IN ('D - Extra Rappel Lotes', 'D - Extra Rappel Mensual') THEN 'Ajuste Tramo Apagón'
                    --  WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes' THEN CAST(NULL AS STRING)
                     WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes' THEN 'Lote Mensual'
                     WHEN TRANSACCIONES.concepto LIKE 'B -%' THEN TRANSACCIONES.concepto
                     WHEN TRANSACCIONES.concepto LIKE '%Dispositivo Financiado%' THEN TRANSACCIONES.concepto
                     WHEN TRANSACCIONES.tariff_ds IS NULL THEN TRANSACCIONES.concepto
                     WHEN TRANSACCIONES.service_type IN ('RENUEVO','ENERGY','SECURITY','TV') THEN TRANSACCIONES.concepto
                     WHEN TRANSACCIONES.concepto LIKE '%Calidad%' THEN TRANSACCIONES.concepto
                     WHEN TRANSACCIONES.concepto LIKE '%Cartera%' THEN TRANSACCIONES.concepto
                     WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil%' THEN 'INCENTIVO POSPAGO'
                     ELSE TRANSACCIONES.tariff_ds
                 END AS tariff_ds
           
                ,TRANSACCIONES.comision
     
                ,CASE WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes' THEN CAST(NULL AS STRING) 
                      WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil' THEN CAST(NULL AS STRING)
                      WHEN TRANSACCIONES.concepto LIKE '%Trade Go to Market' THEN CAST(NULL AS STRING) 
                         
                         ELSE TRANSACCIONES.service_id END AS service_id
     
                ,CAST(NULL AS INT64) AS importe_recarga
                ,CAST(NULL AS INT64) AS porcentage_comision
     
                ,CASE
                     WHEN UPPER(concepto) LIKE '%RENUE%' THEN 'Renove'
                     WHEN service_type = 'ENERGY'        THEN 'Energía'
                     WHEN service_type = 'INTERNET'      THEN 'Fijo'
                     WHEN service_type = 'MOBILE'        THEN 'Pospago'
                     WHEN service_type = 'SECURITY'      THEN 'Alarma'
                     WHEN service_type = 'TV'            THEN 'TV'
                     ELSE 'Pospago'
                 END AS modalidad
     
                ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) = 'Z' THEN 'X' END AS regularizacion
                ,TRANSACCIONES.invoice_id
                
           FROM (
                SELECT * EXCEPT(comision, marca), comision, marca
                FROM `mm-commissions-reporting.COMISIONES.transacciones`
               --  WHERE concepto NOT LIKE '%Rappel Lotes'
                WHERE NOT REGEXP_CONTAINS(concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                UNION ALL
                SELECT
                      * EXCEPT(comision, marca)
                     ,SUM(comision) OVER (PARTITION BY id_mes, concepto, order_id) AS comision
     
                    --  ,CASE WHEN marca IN ('JAZZTEL', 'ORANGE', 'SIMYO') THEN 'MASMOVIL' ELSE marca END AS marca
                     ,'AP' AS MARCA
     
                FROM `mm-commissions-reporting.COMISIONES.transacciones`
               --  WHERE concepto LIKE '%Rappel Lotes'
                WHERE REGEXP_CONTAINS(concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                QUALIFY ROW_NUMBER() OVER (
                                          PARTITION BY id_mes, concepto, order_id
                                          ORDER BY CASE 
                                                       WHEN marca = 'MASMOVIL'  THEN 1
                                                       WHEN marca = 'PEPEPHONE' THEN 2
                                                       ELSE 3
                                                   END ASC
                                          ) = 1
                ) TRANSACCIONES
     
           WHERE TRANSACCIONES.id_mes = month
          -- AND TRANSACCIONES.marca = UPPER(brand)
                AND (
                    (
                         TRANSACCIONES.marca = UPPER(brand)
                         AND NOT REGEXP_CONTAINS(TRANSACCIONES.concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                    )
                    OR (
                         LOWER(brand) = 'ap'
                         AND REGEXP_CONTAINS(TRANSACCIONES.concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                    )
                    )

                 AND TRANSACCIONES.estado IN ('facturado','publicado')
                 AND TRANSACCIONES.cif = 'B75728329'
           )
     
     GROUP BY 1,2,3,4,5,7,8,9,10,11,12
     )
;

IF (SELECT SUM(SAFE_CAST(REPLACE(comision, ',', '.') AS INT64)) FROM detalle) <> 0.0
THEN

IF /*REPLACE(loop_table_name, 'tecalis', 'tecalis_detalle') NOT IN (SELECT table_name FROM mm-commissions-reporting.60_EDW_DELIVERABLES.INFORMATION_SCHEMA.TABLES WHERE table_name = REPLACE(loop_table_name, 'tecalis', 'tecalis_detalle')) OR*/ nobackup = 1

THEN

/* Constructs query that creates the deliverable table where the information will be stored */
SET deliverable_table_name = CONCAT('`mm-commissions-reporting.60_EDW_DELIVERABLES.', REPLACE(loop_table_name, 'tecalis', 'tecalis_detalle'), '`');
SET deliverable_qry = 'CREATE OR REPLACE TABLE ' || deliverable_table_name || ' AS SELECT * FROM ' || 'detalle';
EXECUTE IMMEDIATE deliverable_qry;

ELSE

/* Copies the table that existed and replaces it with the latest execution */
SET copy_table_name = CONCAT('`mm-commissions-reporting.90_BACKUP_DELIVERABLES.', SUBSTR(REPLACE(loop_table_name, 'tecalis', 'tecalis_detalle'), 1, LENGTH(REPLACE(loop_table_name, 'tecalis', 'tecalis_detalle')) - 8), FORMAT_TIMESTAMP("%Y%m%d_%H%M", CURRENT_TIMESTAMP(), "Europe/Madrid"), '`');
SET deliverable_table_name = CONCAT('`mm-commissions-reporting.60_EDW_DELIVERABLES.', REPLACE(loop_table_name, 'tecalis', 'tecalis_detalle'), '`');
SET copy_qry = 'CREATE OR REPLACE TABLE ' || copy_table_name || ' AS SELECT * FROM ' || deliverable_table_name;
SET deliverable_qry = 'CREATE OR REPLACE TABLE ' || deliverable_table_name || ' AS SELECT * FROM ' || 'detalle';
EXECUTE IMMEDIATE copy_qry;
EXECUTE IMMEDIATE deliverable_qry;

END IF;
END IF;


CREATE OR REPLACE TEMPORARY TABLE suma AS
SELECT
      concepto
     ,id_comisionista
     ,nombre_comercio
     ,REPLACE(CAST(comision AS STRING), '.', ',') AS comision
     ,importe_recarga
     ,porcentage_comision

FROM (
     SELECT
           concepto
          ,id_comisionista
          ,nombre_comercio
          ,SUM(comision) AS comision
          ,importe_recarga
          ,porcentage_comision
     
     FROM (
           SELECT
                 TRANSACCIONES.id_mes
     
                ,CASE
                     WHEN TRANSACCIONES.concepto LIKE 'A%Portabilidad%Fijo%'                                  THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Servicio%Fijo%'                                      THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Extra%SOHO%'                                         THEN 'ACTIVACIÓN FIJO'
                    --  WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%' AND TRANSACCIONES.service_type = 'INTERNET' THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Portabilidad%Fijo%'                                  THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Servicio%Fijo%'                                      THEN 'ACTIVACIÓN FIJO'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Portabilidad%Movil%'                                 THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'A%Servicio%Movil%'                                     THEN 'ACTIVACIÓN MOVIL'
                    --  WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%' AND TRANSACCIONES.service_type = 'MOBILE'   THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Portabilidad%Movil%'                                 THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Servicio%Movil%'                                     THEN 'ACTIVACIÓN MOVIL'
                     WHEN TRANSACCIONES.concepto LIKE 'C%'                                                    THEN 'CARTERA'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Calidad%'                                            THEN 'CARTERA'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Cartera%'                                            THEN 'CARTERA'
                     WHEN TRANSACCIONES.concepto LIKE 'E%'                                                    THEN 'CLAWBACK'
                     WHEN TRANSACCIONES.concepto LIKE 'P%'                                                    THEN 'CLAWBACK'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Clawback%'                                           THEN 'CLAWBACK'
                     WHEN TRANSACCIONES.concepto LIKE 'D%'                                                    THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE '%Extracomision%'                                       THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Acelerador%'                                         THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Apoyo%'                                              THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Blindaje%'                                           THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Incentivo%'                                          THEN 'INCENTIVOS Y APOYOS'
                          WHEN TRANSACCIONES.concepto LIKE 'D%Panzer%'                                         THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Rappel%'                                             THEN 'INCENTIVOS Y APOYOS'
                     WHEN TRANSACCIONES.concepto LIKE 'B%Renuevo%'                                            THEN 'RENOVE'
                     WHEN TRANSACCIONES.concepto LIKE '%Renuevo%'                                             THEN 'RENOVE'
                     WHEN TRANSACCIONES.concepto LIKE 'B%'                                                    THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%Alarmas%'                                             THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%Centralitas%'                                         THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%Energia%'                                             THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%energia%'                                             THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE '%SVG%'                                                 THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE 'Z%Television%'                                         THEN 'BONO'
                     WHEN TRANSACCIONES.concepto LIKE 'T%'                                                    THEN 'TERMINAL'
                     ELSE TRANSACCIONES.concepto
                 END AS concepto
     
                ,TRANSACCIONES.order_id AS id_comisionista
                ,TRANSACCIONES.id_comisionista AS id_mm
                ,REPLACE(TRANSACCIONES.campaign_code, 'TECALIS ', '') AS mm_cif
     
                ,TRANSACCIONES.nombre_comercio
                ,TRANSACCIONES.comision
                ,CAST(NULL AS INT64) AS importe_recarga
                ,CAST(NULL AS INT64) AS porcentage_comision
                ,TRANSACCIONES.invoice_id
                
           FROM (
                SELECT * EXCEPT(comision, marca), comision, marca
                FROM `mm-commissions-reporting.COMISIONES.transacciones`
               --  WHERE concepto NOT LIKE '%Rappel Lotes'
                WHERE NOT REGEXP_CONTAINS(concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                UNION ALL
                SELECT
                      * EXCEPT(comision, marca)
                     ,SUM(comision) OVER (PARTITION BY id_mes, concepto, order_id) AS comision
     
                    --  ,CASE WHEN marca IN ('JAZZTEL', 'ORANGE', 'SIMYO') THEN 'MASMOVIL' ELSE marca END AS marca
                     ,'AP' AS MARCA
     
                FROM `mm-commissions-reporting.COMISIONES.transacciones`
               --  WHERE concepto LIKE '%Rappel Lotes'
                WHERE REGEXP_CONTAINS(concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                QUALIFY ROW_NUMBER() OVER (
                                          PARTITION BY id_mes, concepto, order_id
                                          ORDER BY CASE 
                                                       WHEN marca = 'MASMOVIL'  THEN 1
                                                       WHEN marca = 'PEPEPHONE' THEN 2
                                                       ELSE 3
                                                   END ASC
                                          ) = 1
                ) TRANSACCIONES
     
           WHERE TRANSACCIONES.id_mes = month
               --   AND TRANSACCIONES.marca = UPPER(brand)
                AND (
                    (
                         TRANSACCIONES.marca = UPPER(brand)
                         AND NOT REGEXP_CONTAINS(TRANSACCIONES.concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                    )
                    OR (
                         LOWER(brand) = 'ap'
                         AND REGEXP_CONTAINS(TRANSACCIONES.concepto, r'Trade Go to Market|Extracomision Volumen Movil|Rappel Lotes')
                    )
                    )
                    AND TRANSACCIONES.estado IN ('facturado','publicado')
                 AND TRANSACCIONES.cif = 'B75728329'
           )

     GROUP BY 1,2,3,5,6
     )
;

IF (SELECT SUM(SAFE_CAST(REPLACE(comision, ',', '.') AS INT64)) FROM suma) <> 0.0
THEN

IF /*REPLACE(loop_table_name, 'tecalis', 'tecalis_suma') NOT IN (SELECT table_name FROM mm-commissions-reporting.60_EDW_DELIVERABLES.INFORMATION_SCHEMA.TABLES WHERE table_name = REPLACE(loop_table_name, 'tecalis', 'tecalis_suma')) OR*/ nobackup = 1

THEN

/* Constructs query that creates the deliverable table where the information will be stored */
SET deliverable_table_name = CONCAT('`mm-commissions-reporting.60_EDW_DELIVERABLES.', REPLACE(loop_table_name, 'tecalis', 'tecalis_suma'), '`');
SET deliverable_qry = 'CREATE OR REPLACE TABLE ' || deliverable_table_name || ' AS SELECT * FROM ' || 'suma';
EXECUTE IMMEDIATE deliverable_qry;

ELSE

/* Copies the table that existed and replaces it with the latest execution */
SET copy_table_name = CONCAT('`mm-commissions-reporting.90_BACKUP_DELIVERABLES.', SUBSTR(REPLACE(loop_table_name, 'tecalis', 'tecalis_suma'), 1, LENGTH(REPLACE(loop_table_name, 'tecalis', 'tecalis_suma')) - 8), FORMAT_TIMESTAMP("%Y%m%d_%H%M", CURRENT_TIMESTAMP(), "Europe/Madrid"), '`');
SET deliverable_table_name = CONCAT('`mm-commissions-reporting.60_EDW_DELIVERABLES.', REPLACE(loop_table_name, 'tecalis', 'tecalis_suma'), '`');
SET copy_qry = 'CREATE OR REPLACE TABLE ' || copy_table_name || ' AS SELECT * FROM ' || deliverable_table_name;
SET deliverable_qry = 'CREATE OR REPLACE TABLE ' || deliverable_table_name || ' AS SELECT * FROM ' || 'suma';
EXECUTE IMMEDIATE copy_qry;
EXECUTE IMMEDIATE deliverable_qry;

END IF;
END IF;


CREATE OR REPLACE TEMPORARY TABLE commissionid AS

SELECT TRANSACCIONES.commission_id, TRANSACCIONES.order_id
           
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

-- LEFT JOIN (
--           SELECT
--                LIST.sfid
--               ,CLEAN.sfid_2
--               ,MAX(CLEAN.nombre_comercial_pdv) AS nombre_comercio
--           FROM (
--                SELECT
--                      sfid
--                     ,sfid_unico
--                FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`
--                GROUP BY 1,2
--                ) LIST
--           LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_cif_clean` CLEAN
--                    ON LIST.sfid_unico = CLEAN.sfid_unico
--           GROUP BY 1,2
--           ) SFID_ORANGE

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_sfid_filter` SFID_ORANGE
         ON TRANSACCIONES.id_comisionista = SFID_ORANGE.sfid

LEFT JOIN `mm-commissions-reporting.GS.gs_sfid_digo` SFID_DIGO
         ON TRANSACCIONES.id_comisionista = SFID_DIGO.id_mm

WHERE TRANSACCIONES.id_mes = month
      AND TRANSACCIONES.marca = UPPER(brand)
     --  AND TRANSACCIONES.estado NOT IN ('rechazado')
      AND TRANSACCIONES.estado IN ('facturado','publicado')
      AND TRANSACCIONES.cif = 'B75728329'
GROUP BY 1,2
;

IF /*REPLACE(loop_table_name, 'tecalis', 'tecalis_commission_id') NOT IN (SELECT table_name FROM mm-commissions-reporting.60_EDW_DELIVERABLES.INFORMATION_SCHEMA.TABLES WHERE table_name = REPLACE(loop_table_name, 'tecalis', 'tecalis_commission_id')) OR*/ nobackup = 1

THEN

/* Constructs query that creates the deliverable table where the information will be stored */
SET deliverable_table_name = CONCAT('`mm-commissions-reporting.60_EDW_DELIVERABLES.', REPLACE(loop_table_name, 'tecalis', 'tecalis_commission_id'), '`');
SET deliverable_qry = 'CREATE OR REPLACE TABLE ' || deliverable_table_name || ' AS SELECT * FROM ' || 'commissionid';
EXECUTE IMMEDIATE deliverable_qry;

ELSE

/* Copies the table that existed and replaces it with the latest execution */
SET copy_table_name = CONCAT('`mm-commissions-reporting.90_BACKUP_DELIVERABLES.', SUBSTR(REPLACE(loop_table_name, 'tecalis', 'tecalis_commission_id'), 1, LENGTH(REPLACE(loop_table_name, 'tecalis', 'tecalis_commission_id')) - 8), FORMAT_TIMESTAMP("%Y%m%d_%H%M", CURRENT_TIMESTAMP(), "Europe/Madrid"), '`');
SET deliverable_table_name = CONCAT('`mm-commissions-reporting.60_EDW_DELIVERABLES.', REPLACE(loop_table_name, 'tecalis', 'tecalis_commission_id'), '`');
SET copy_qry = 'CREATE OR REPLACE TABLE ' || copy_table_name || ' AS SELECT * FROM ' || deliverable_table_name;
SET deliverable_qry = 'CREATE OR REPLACE TABLE ' || deliverable_table_name || ' AS SELECT * FROM ' || 'commissionid';
EXECUTE IMMEDIATE copy_qry;
EXECUTE IMMEDIATE deliverable_qry;

END IF;


END WHILE;

END WHILE;

END