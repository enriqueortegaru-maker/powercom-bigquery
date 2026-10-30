BEGIN

DECLARE sql , prefijo , mes_string STRING;

DECLARE canales_pr ARRAY <STRING> DEFAULT ['EML','EYG','ENX','EDB','ENK'];

SET prefijo = 'EXRP';

SET mes_string = cast(mes_int as string);

-- CALL `mm-commissions-reporting.COMISIONES.pr_exrp`(202608);


CALL COMISIONES.pr_captaciones_sin_coste(mes_int,['ENK']);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.exrp` AS
SELECT *
FROM (
     --------------------------------
     -- OBJETIVO MÓVIL Y FIJO
     --------------------------------
     SELECT
           TRANSACCIONES.* EXCEPT (concepto, comision, commission_id, mes_liquidado, facturador, tipo_concepto, comments, id_mes, estado, tariff_id, tariff_ds,process_code)
     
          -- ,prefijo||'_'||mes_string||'_'||TRANSACCIONES.canal||'_'||row_number () OVER () AS commission_id
          
          ,CASE WHEN CONCEPTOS.concepto = 'D - Extracomision Objetivo Movil Pospago'   
                     AND TRANSACCIONES.canal = 'ENK'
                     AND TRANSACCIONES.service_type = 'MOBILE'
                     AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'A - Portabilidad Movil Pospago','D - Extracomision Segmentacion') 
                THEN (ENK.multiplicador_pospago - 1.0) * TRANSACCIONES.comision

                WHEN CONCEPTOS.concepto = 'D - Extracomision Objetivo Movil Pospago'   
                     AND TRANSACCIONES.canal != 'ENK'
                     AND TRANSACCIONES.service_type = 'MOBILE'
                     AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago') 
                THEN (COALESCE(EML.multiplicador_pospago, EYG.multiplicador_pospago) - 1.0) * TRANSACCIONES.comision
                
                WHEN CONCEPTOS.concepto = 'D - Extracomision Objetivo fijo'  
                     AND TRANSACCIONES.canal = 'ENK'
                     AND TRANSACCIONES.service_type = 'INTERNET'
                     AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Fijo 2da Vivienda', 'A - Portabilidad Fijo')
                THEN (ENK.multiplicador_ftth_adsl - 1.0) * TRANSACCIONES.comision

                WHEN CONCEPTOS.concepto = 'D - Extracomision Objetivo fijo'  
                     AND TRANSACCIONES.canal != 'ENK'
                     AND TRANSACCIONES.service_type = 'INTERNET'
                     AND TRANSACCIONES.concepto IN ('A - Servicio Fijo')
                THEN (COALESCE(EML.multiplicador_ftth_adsl, EYG.multiplicador_ftth_adsl) - 1.0) * TRANSACCIONES.comision

                ELSE 0.00
           END AS comision
           
          ,CONCEPTOS.concepto
          ,CONCEPTOS.tipo_concepto
          ,COMISIONES.f_mes_int (mes_int) AS mes_liquidado
          ,mes_int AS id_mes
          ,'C_MANUAL' AS facturador
          ,'calculado' AS estado
          ,CASE WHEN TRANSACCIONES.comments = 'Tarifa MAX Pepephone' THEN TRANSACCIONES.comments ELSE CAST(NULL AS STRING) END AS comments
          ,TRANSACCIONES.tariff_id
          ,TRANSACCIONES.tariff_ds
          ,TRANSACCIONES.commission_id AS process_code
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
     LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` ENK
              ON (TRANSACCIONES.sfid_id = ENK.id_comisionista OR TRANSACCIONES.seller = ENK.id_comisionista)
                 AND ENK.id_mes = mes_int
     
     LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_eml` EML
              ON (TRANSACCIONES.sfid_id = EML.id_comisionista OR TRANSACCIONES.seller = EML.id_comisionista)
                 AND EML.id_mes = mes_int
     
     LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_eyg` EYG
              ON (TRANSACCIONES.sfid_id = EYG.id_comisionista OR TRANSACCIONES.seller = EYG.id_comisionista)
                 AND EYG.id_mes = mes_int

     LEFT JOIN ( 
               SELECT DISTINCT ACT.phone_nm, ACT.activation_date
               FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING               
               
               INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` ACT
                    ON BILLING.phone_nm = CAST(ACT.phone_nm AS INT64) AND BILLING.service_id = ACT.service_id AND BILLING.brand_ds = ACT.marca AND BILLING.data_month_id = ACT.id_mes
               WHERE BILLING.data_month_id = mes_int
               AND ACT.concepto = 'A - Servicio Movil Pospago'
               AND BILLING.concept_type_ds IN ('Cuotas','Promociones') 
               AND ACT.tariff_id = '8205'
               AND ACT.agrupacion_canal = 'Exclusivo'
               AND concept_ds NOT IN ('Descuento 100% Dúo principal','C Descuento 100% Dúo principal')
               ) DUO
               ON TRANSACCIONES.phone_nm = DUO.phone_nm AND TRANSACCIONES.activation_date = DUO.activation_date        
     
     CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
     
     CROSS JOIN UNNEST(canales_pr) canal_pr
     
     WHERE TRANSACCIONES.canal = canal_pr
           AND CONCEPTOS.proceso LIKE '%EXRP%'
           AND CONCEPTOS.concepto IN ('D - Extracomision Objetivo Movil Pospago','D - Extracomision Objetivo fijo')
           AND TRANSACCIONES.id_mes = mes_int
          --  AND TRANSACCIONES.order_type_agg != 'MIGRACION PREPAGO A POSTPAGO' -- 20260901 SE EMPIEZA A PAGAR OBJETIVO DESDE 202606
           AND (EML.id_comisionista IS NOT NULL OR EYG.id_comisionista IS NOT NULL OR ENK.id_comisionista IS NOT NULL)
           AND (SUBSTR(TRANSACCIONES.commission_id,1,4) IN ('ACTI','EXEX','PNTE')
                OR TRANSACCIONES.marca = 'PEPEPHONE' AND SUBSTR(TRANSACCIONES.commission_id,1,4) = 'FACT')
          --  AND DUO.phone_nm IS NULL
     

     UNION ALL

     --------------------------------
     -- OBJETIVO TERMINALES POSPAGO
     --------------------------------

     SELECT
           TRANSACCIONES.* EXCEPT (concepto, comision, commission_id, mes_liquidado, facturador, tipo_concepto, comments, id_mes, estado, tariff_id, tariff_ds, process_code)
     
          -- ,prefijo||'_'||mes_string||'_'||TRANSACCIONES.canal||'_'||row_number () OVER () AS commission_id
          
          ,CASE 
                WHEN CONCEPTOS.concepto = 'D - Extracomision Objetivo Terminales'  
                     AND TRANSACCIONES.canal = 'ENK'
                     AND (
                          TRANSACCIONES.concepto IN ('B - Renuevo', 'D - Extracomision terminal')
                          OR
                          CAPTA_SIN_COSTE.serial_number IS NOT NULL
                         ) 
                THEN ENK.multiplicador_terminales

                ELSE 0.00
           END AS comision
           
          ,CONCEPTOS.concepto
          
          ,CASE
               WHEN TRANSACCIONES.concepto = 'D - Extracomision terminal' THEN 'UPFR'
               WHEN TRANSACCIONES.concepto = 'B - Renuevo'                THEN 'CURE' 
               WHEN CAPTA_SIN_COSTE.serial_number IS NOT NULL             THEN 'UPFR'
           END AS tipo_concepto 

          ,COMISIONES.f_mes_int (mes_int) AS mes_liquidado
          ,mes_int AS id_mes
          ,'C_MANUAL' AS facturador
          ,'calculado' AS estado
          ,CAST(NULL AS STRING) AS comments
          ,DEVICES.tariff_id
          ,DEVICES.tariff_ds
          ,TRANSACCIONES.process_code
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
     LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` ENK
              ON (TRANSACCIONES.sfid_id = ENK.id_comisionista OR TRANSACCIONES.seller = ENK.id_comisionista)
                 AND ENK.id_mes = mes_int

     LEFT JOIN ( 
               SELECT DISTINCT ACT.phone_nm, ACT.activation_date
               FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING               
               
               INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` ACT
                    ON BILLING.phone_nm = CAST(ACT.phone_nm AS INT64) AND BILLING.service_id = ACT.service_id AND BILLING.brand_ds = ACT.marca AND BILLING.data_month_id = ACT.id_mes
               WHERE BILLING.data_month_id = mes_int
               AND ACT.concepto = 'A - Servicio Movil Pospago'
               AND BILLING.concept_type_ds IN ('Cuotas','Promociones') 
               AND ACT.tariff_id = '8205'
               AND ACT.agrupacion_canal = 'Exclusivo'
               AND concept_ds NOT IN ('Descuento 100% Dúo principal','C Descuento 100% Dúo principal')
               ) DUO
               ON TRANSACCIONES.phone_nm = DUO.phone_nm AND TRANSACCIONES.activation_date = DUO.activation_date        
     
     LEFT JOIN `mm-commissions-reporting.TEMP.captaciones_sin_coste` CAPTA_SIN_COSTE
          ON TRANSACCIONES.serial_number = CAPTA_SIN_COSTE.serial_number

     LEFT JOIN `mm-commissions-reporting.TEMP.device_base` DEVICES
          ON TRANSACCIONES.serial_number = DEVICES.serial_number 
          AND (TRANSACCIONES.activation_date = DATE(DEVICES.order_date) OR TRANSACCIONES.sale_date = DATE(DEVICES.order_date))
          AND (TRANSACCIONES.seller = DEVICES.user_store OR TRANSACCIONES.seller = UPPER(SPLIT(DEVICES.user_store,'@')[SAFE_OFFSET(0)]) OR TRANSACCIONES.seller = UPPER(SPLIT(DEVICES.seller,'@')[SAFE_OFFSET(0)]))
          AND TRANSACCIONES.service_id = DEVICES.service_id
          AND TRANSACCIONES.account_id = DEVICES.account_id
     
     CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
     
     CROSS JOIN UNNEST(canales_pr) canal_pr
     
     WHERE TRANSACCIONES.canal = canal_pr
           AND CONCEPTOS.proceso LIKE '%EXRP%'
           AND CONCEPTOS.concepto IN ('D - Extracomision Objetivo Terminales')
           AND TRANSACCIONES.id_mes = mes_int
           AND ENK.id_comisionista IS NOT NULL
           AND (SUBSTR(TRANSACCIONES.commission_id,1,4) IN ('RENV','DCEX')
                OR CAPTA_SIN_COSTE.serial_number IS NOT NULL)
          --  AND DISPOSITIVO_PREPAGO.serial_number IS NULL 
          AND TRANSACCIONES.billing_type_ds = 'POSTPAID'
     QUALIFY ROW_NUMBER() OVER(PARTITION BY serial_number ORDER BY CAPTA_SIN_COSTE.order_date ASC) = 1


     UNION ALL

     --------------------------------
     -- OBJETIVO TERMINALES PREPAGO
     --------------------------------

     SELECT
           TRANSACCIONES.* EXCEPT (concepto, comision, commission_id, mes_liquidado, facturador, tipo_concepto, comments, id_mes, estado, tariff_id, tariff_ds, process_code)
     
          -- ,prefijo||'_'||mes_string||'_'||TRANSACCIONES.canal||'_'||row_number () OVER () AS commission_id
          
          ,CASE 
                WHEN CONCEPTOS.concepto = 'D - Extracomision Objetivo Terminales'  
                     AND TRANSACCIONES.canal = 'ENK'
                     AND TRANSACCIONES.concepto IN ('B - Renuevo', 'D - Extracomision terminal')
                THEN ENK.multiplicador_terminales

                ELSE 0.00
           END AS comision
           
          ,CONCEPTOS.concepto
          
          ,CASE
               WHEN TRANSACCIONES.concepto = 'D - Extracomision terminal' THEN 'UPFR'
               WHEN TRANSACCIONES.concepto = 'B - Renuevo'                THEN 'CURE'
               WHEN CAPTA_SIN_COSTE.serial_number IS NOT NULL             THEN 'UPFR' 
           END AS tipo_concepto 
           
          ,COMISIONES.f_mes_int (mes_int) AS mes_liquidado
          ,mes_int AS id_mes
          ,'C_MANUAL' AS facturador
          ,'calculado' AS estado
          ,CAST(NULL AS STRING) AS comments
          ,DEVICES.tariff_id
          ,DEVICES.tariff_ds 
          ,TRANSACCIONES.process_code   
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
     LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` ENK
              ON (TRANSACCIONES.sfid_id = ENK.id_comisionista OR TRANSACCIONES.seller = ENK.id_comisionista)
                 AND ENK.id_mes = mes_int       

     LEFT JOIN `mm-commissions-reporting.TEMP.device_base` DEVICES
          ON TRANSACCIONES.serial_number = DEVICES.serial_number 
          AND (TRANSACCIONES.activation_date = DATE(DEVICES.order_date) OR TRANSACCIONES.sale_date = DATE(DEVICES.order_date))
          AND (TRANSACCIONES.seller = DEVICES.user_store OR TRANSACCIONES.seller = UPPER(SPLIT(DEVICES.user_store,'@')[SAFE_OFFSET(0)]) OR TRANSACCIONES.seller = UPPER(SPLIT(DEVICES.seller,'@')[SAFE_OFFSET(0)]))
          AND TRANSACCIONES.service_id = DEVICES.service_id
          -- AND TRANSACCIONES.account_id = DEVICES.account_id -- No viene este dato en el tablón de PREPAGO
     
     CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
     
     CROSS JOIN UNNEST(['ENK']) canal_pr
     
     WHERE TRANSACCIONES.canal = canal_pr
           AND CONCEPTOS.proceso LIKE '%EXRP%'
           AND CONCEPTOS.concepto IN ('D - Extracomision Objetivo Terminales')
           AND TRANSACCIONES.id_mes = mes_int
           AND TRANSACCIONES.concepto IN ('B - Renuevo', 'D - Extracomision terminal')
           AND TRANSACCIONES.billing_type_ds = 'PREPAID'
           AND ENK.id_mes = mes_int
           AND ENK.id_comisionista IS NOT NULL
           AND SUBSTR(TRANSACCIONES.commission_id,1,4) IN ('PREP')
     QUALIFY ROW_NUMBER() OVER(PARTITION BY serial_number) = 1
     )

WHERE COALESCE(comision, 0.0) != 0.0

;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.exrp_DBL` AS

-- SELECT *
-- FROM (
--      SELECT
--            TRANSACCIONES.* EXCEPT (concepto, comision, commission_id, mes_liquidado, facturador, tipo_concepto, comments, id_mes, estado)          
--           ,RAPPEL.columna1/RAPPEL.cantidad AS comision
--           ,CONCEPTOS.concepto
--           ,CONCEPTOS.tipo_concepto
--           ,COMISIONES.f_mes_int (mes_int) AS mes_liquidado
--           ,mes_int AS id_mes
--           ,'C_MANUAL' AS facturador
--           ,'calculado' AS estado
--           ,'Rappel '||mes_string||' DBL' AS comments

--      FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

--      INNER JOIN `mm-commissions-reporting.GS.RAPPEL_DBL_DATA` RAPPEL
--                ON TRANSACCIONES.seller = RAPPEL.seller AND TRANSACCIONES.id_mes = RAPPEL.mes

--      LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA
--                ON TRANSACCIONES.phone_nm = CAST(INTRA.phone_nm AS STRING) AND TRANSACCIONES.marca = INTRA.brand_ds AND TRANSACCIONES.id_mes = INTRA.mes_activacion

--      CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          
--      WHERE TRANSACCIONES.id_mes = mes_int
--            AND TRANSACCIONES.tipo_concepto = 'UPFR'
--            AND CONCEPTOS.concepto = 'D - Rappel Fijo'
--            AND TRANSACCIONES.concepto IN ('A - Servicio Fijo')
--            AND TRANSACCIONES.tariff_ds LIKE '%PRO%'
--            AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
--      )

-- ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.exrp` AS

SELECT 
     prefijo||'_'||mes_string||'_'||canal||'_'||row_number () OVER () AS commission_id
     ,*
FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.exrp`
     -- UNION ALL
     -- SELECT * FROM `mm-commissions-reporting.TEMP.exrp_DBL`
     )
;


-- Inserta tabla final --
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, mes_int, canales_pr , 'TEMP.exrp' , 'ACTUALIZAR');

END