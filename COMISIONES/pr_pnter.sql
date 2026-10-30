BEGIN

DECLARE prefijo, mes_string STRING;

SET prefijo = 'PNTER';

SET mes_string = CAST(id_mes_pr AS STRING);

SET canales_pr = COALESCE(canales_pr, ['ENK']);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_pnter`(202607, ['ENK']);
*/




DROP TABLE TEMP.pnter;

-- Borrar los cálculos que hayan de este pr en la liqui en curso para que no los incluya en SUM_TRANSACCIONES (esto es necesario si lanzamos más de una vez este cálculo)
DELETE
FROM `mm-commissions-reporting.COMISIONES.transacciones`
WHERE id_mes = id_mes_pr
AND agrupacion_canal = 'Exclusivo'
AND tipo_concepto NOT IN ('FINT','SUBS','SRCI')
AND estado NOT IN ('facturado','validado') 
AND commission_id LIKE 'PNTER%'
;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.pnter`
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



IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

-- Dúos y compartidas gratuitas

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.compartidas_gratuitas_pnter` AS 

-- SELECT data_month_id,A.phone_nm,A.service_id,A.brand_ds,A.tariff_id,concept_type_ds,concept_ds 
--           FROM `mm-commissions-reporting.COMISIONES.activaciones` A
--           LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_emysim` F
--                 ON A.service_id = F.service_id AND A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id
--           WHERE A.id_mes = id_mes_pr
--           AND A.agrupacion_canal = 'Exclusivo' 
--           AND (
--                A.tariff_id IN ('7126','7127')
--                AND F.concept_type_ds = 'Cuotas'
--                OR
--                A.tariff_id IN ('8205','8212','8145','8187') 
--                AND F.brand_ds = 'YOIGO'
--                AND F.concept_type_ds = 'Promociones'
--                AND UPPER(F.concept_ds) LIKE '%DESCUENTO 100%DÚO PRINCIPAL%'
--                OR
--                A.tariff_id IN ('7108')
--                AND F.brand_ds = 'MASMOVIL'
--                AND F.concept_type_ds = 'Promociones'
--                AND UPPER(F.concept_ds) LIKE 'MM_DTO TARIFA MAS COMPARTIDA_3 EUROS'
--                OR
--                A.tariff_id IN ('7115')
--                AND F.brand_ds = 'MASMOVIL'
--                AND F.concept_type_ds = 'Promociones'
--                AND UPPER(F.concept_ds) LIKE 'MM_DTO LINEA ADICIONAL COMPARTIDA PRO'
--                OR
--                A.tariff_id IN ('7169')
--                AND F.brand_ds = 'MASMOVIL'
--                AND UPPER(concept_ds) LIKE 'MM_DTO LINEA ADICIONAL COMPARTIDA PRO%'
--                )
--           AND data_month_id = id_mes_pr
--           QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm,service_id,brand_ds) = 1

-- ;

-- Duos y compartidas con coste y comisión 

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.compartidas_coste_pnter` AS

-- SELECT A.phone_nm, A.service_id, B.main_mobile_tariff_id, B.main_mobile_tariff_name, T.tramo_1 AS comision

--             FROM `mm-commissions-reporting.COMISIONES.activaciones` A
            
--             LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_emysim` F
--                ON A.service_id = F.service_id AND A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id

--             LEFT JOIN `mm-commissions-reporting.TEMP.disgregacion_bundles_exc` B
--                ON B.bundle_id = F.bundle_id 
            
--             LEFT JOIN (SELECT * EXCEPT(creado, creado_por) FROM `mm-commissions-reporting.COMISIONES.tarifas` GROUP BY ALL) T
--                ON T.tariff_id = B.main_mobile_tariff_id    
            
--             WHERE A.tariff_id IN ('8205','8212','7108','7115','8145','8187','7169')
--             AND A.agrupacion_canal = 'Exclusivo'
--             AND A.canal = 'ENK'
--             AND data_month_id = id_mes_pr
--             AND concept_type_ds = 'Cuotas'
--             AND A.service_id NOT IN (SELECT service_id FROM `mm-commissions-reporting.TEMP.compartidas_gratuitas_pnter` )
--             AND T.canal = 'ENK'
--             AND T.id_mes = id_mes_pr
-- QUALIFY ROW_NUMBER() OVER(PARTITION BY F.phone_nm, F.service_id, F.tariff_id ORDER BY DATE_DIFF(end_date,init_date,DAY) DESC) = 1

-- ;

INSERT INTO TEMP.pnter -- Penalizacion Portabilidades Intermarca EXCLUSIVO ENK
(
SELECT SERVICIOS.* EXCEPT(concepto,tipo_concepto,facturador, comision,comments,process_code)
       ,prefijo||'_'||mes_string||'_'||SERVICIOS.canal||'_'||ROW_NUMBER () OVER () AS commission_id
       ,SERVICIOS.concepto
       ,SERVICIOS.tipo_concepto
       ,SERVICIOS.facturador
       ,SERVICIOS.comision
       ,SERVICIOS.comments
       ,SERVICIOS.process_code
FROM 
     (
     SELECT
           TRANSACCIONES.* EXCEPT(id_mes, mes_liquidado, estado, commission_id, concepto, tipo_concepto, facturador, comision, comments, process_code, emails_acceso_trazabilidad)
           ,id_mes_pr AS id_mes
           ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
           ,'calculado' AS estado
           ,CASE
                WHEN TRANSACCIONES.service_type IN ('INTERNET')  THEN 'A - Portabilidad Fijo'
                WHEN TRANSACCIONES.service_type IN ('MOBILE')    THEN 'A - Portabilidad Movil Pospago'
            END AS concepto
           ,tipo_concepto
           ,facturador

           ,CASE 
               WHEN INTER.importe_comision > 0 THEN INTER.importe_comision
               WHEN INTER.importe_comision < 0 THEN
                    CASE 
                         WHEN SUM_TRANSACCIONES.comision < (INTER.importe_comision * -1)  THEN (SUM_TRANSACCIONES.comision * -1)  
                         WHEN SUM_TRANSACCIONES.comision >= (INTER.importe_comision * -1) THEN INTER.importe_comision
                    END
            END AS comision

           ,CONCAT('Portabilidad Intermarca') AS comments
           ,TRANSACCIONES.commission_id AS process_code
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

     INNER JOIN `mm-commissions-reporting.GS.exclusivo_portas_intermarca` INTER
               ON TRANSACCIONES.phone_nm = INTER.phone_nm AND TRANSACCIONES.account_id = INTER.account_id

     LEFT JOIN (
                SELECT service_id, phone_nm,SUM(comision) AS comision
                FROM `mm-commissions-reporting.COMISIONES.transacciones` 
                WHERE id_mes = id_mes_pr 
                AND agrupacion_canal = 'Exclusivo'
                AND canal = 'ENK' 
                AND tipo_concepto IN ('UPFR')
                AND concepto NOT IN ('D - Experiencia de Cliente', 'D - Plan Energia','D - Plan Lideres','Z - Plan Lideres')
                AND SUBSTR(commission_id,1,4) NOT IN ('EXRP','PNTE','PINT','CHRN','REEX')
                AND billing_type_ds = 'POSTPAID'
                AND DATE_TRUNC(activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
                AND (deactivation_date >= COALESCE(DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH), '9999-12-31') OR deactivation_date IS NULL)
                GROUP BY ALL
                ) SUM_TRANSACCIONES
          ON TRANSACCIONES.phone_nm = SUM_TRANSACCIONES.phone_nm AND TRANSACCIONES.service_id = SUM_TRANSACCIONES.service_id

     WHERE TRANSACCIONES.id_mes = id_mes_pr
           AND TRANSACCIONES.canal = 'ENK'
           AND TRANSACCIONES.concepto in ('A - Servicio Fijo','A - Servicio Fijo 2da Vivienda','A - Servicio Movil Pospago')
           AND TRANSACCIONES.activation_date >= PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
           AND TRANSACCIONES.deactivation_date >= COALESCE(DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH), '9999-12-31') 

     -- UNION ALL

     -- SELECT
     --       agrupacion_canal
     --      ,ACTIVACIONES.canal
     --      ,1 as unidades
     --      ,id_comisionista
     --      ,distribuidor
     --      ,ACTIVACIONES.sfid_id
     --      ,seller
     --      ,nombre_comercio
     --      ,razon_social
     --      ,ACTIVACIONES.cif
     --      ,zona_fiscal
     --      ,'Z005' AS cond_pago
     --      ,ACTIVACIONES.marca
     --      ,ACTIVACIONES.service_type
     --      ,ACTIVACIONES.phone_nm
     --      ,ACTIVACIONES.tariff_id
     --      ,ACTIVACIONES.tariff_ds
     --      ,ACTIVACIONES.service_id
     --      ,ACTIVACIONES.account_id
     --      ,ACTIVACIONES.customer_id
     --      ,ACTIVACIONES.line_type_ds
     --      ,bundle_type
     --      ,technology_ds
     --      ,billing_type_ds
     --      ,sale_date
     --      ,activation_date
     --      ,deactivation_date
     --      ,order_id
     --      ,order_type_agg
     --      ,cod_segmento
     --      ,cod_marca
     --      ,cod_tipo_contrato
     --      ,cod_producto
     --      ,cod_canal
     --      ,CAST(NULL AS STRING)  AS campaign_code
     --      ,CAST(NULL AS STRING)  AS serial_number
     --      ,CAST(NULL AS FLOAT64) AS tax_base
     --      ,CAST(NULL AS STRING)  AS claim_code
     --      ,CAST(NULL AS STRING) AS proceso_sap
     --      ,CAST(NULL AS STRING) AS id_registro
     --      ,CAST(NULL AS STRING) AS invoice_id
     --      ,sociedad
     --      ,CAST(NULL AS STRING) AS bp
     --      ,CAST(NULL AS STRING) AS cuenta_contable
     --      ,CAST(NULL AS STRING) AS centro_coste
     --      ,CAST(NULL AS STRING) AS documento_sap
     --      ,CAST(NULL AS STRING) AS documento_sap_posicion
     --      ,CAST(NULL AS STRING) AS fecha_contabilizacion
     --      ,CAST(NULL AS TIMESTAMP) AS creado
     --      ,CAST(NULL AS TIMESTAMP) AS modificado
     --      ,CAST(NULL AS STRING) AS id_factura_drive
     --      ,id_mes_pr AS id_mes
     --      ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     --      ,'calculado' AS estado
          
     --      ,CASE
     --           WHEN ACTIVACIONES.service_type = 'MOBILE'   THEN 'A - Portabilidad Movil Pospago'
     --           WHEN ACTIVACIONES.service_type = 'INTERNET' THEN 'A - Portabilidad Fijo' 
     --       END AS concepto

     --      ,'UPFR' AS tipo_concepto
     --      ,'C_MANUAL' AS facturador
       
     --      ,CASE 
     --           WHEN INTER.importe_comision > 0 THEN INTER.importe_comision
     --           WHEN INTER.importe_comision < 0 THEN
     --                CASE 
     --                     WHEN SUM_TRANSACCIONES.comision < (INTER.importe_comision * -1)  THEN (SUM_TRANSACCIONES.comision * -1)  
     --                     WHEN SUM_TRANSACCIONES.comision >= (INTER.importe_comision * -1) THEN INTER.importe_comision
     --                END
     --        END AS comision    

     --      ,'Portabilidad Intermarca' AS comments
     --      ,CAST(null AS STRING) AS process_code

     -- FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
     
     -- INNER JOIN `mm-commissions-reporting.GS.exclusivo_portas_intermarca` INTER
     --      ON ACTIVACIONES.phone_nm = INTER.phone_nm AND ACTIVACIONES.account_id = INTER.account_id
     
     -- LEFT JOIN `mm-commissions-reporting.TEMP.compartidas_coste_pnter` DUO_COSTE
     --      ON CAST(DUO_COSTE.phone_nm AS STRING) = ACTIVACIONES.phone_nm AND DUO_COSTE.service_id = ACTIVACIONES.service_id -- si falla intentar cruzar sólo por service_id y cambiar phone_nm por service_id en WHERE
     
     -- LEFT JOIN (
     --            SELECT service_id, phone_nm, SUM(comision) AS comision
     --            FROM `mm-commissions-reporting.COMISIONES.transacciones` 
     --            WHERE id_mes = id_mes_pr 
     --            AND agrupacion_canal = 'Exclusivo'
     --            AND canal = 'ENK' 
     --            AND tipo_concepto IN ('UPFR','TJTS','SUTS')
     --            AND concepto != 'D - Experiencia de Cliente'
     --            AND SUBSTR(commission_id,1,4) NOT IN ('EXRP','PNTE')
     --            AND billing_type_ds = 'POSTPAID'
     --            AND DATE_TRUNC(activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     --            AND deactivation_date >= COALESCE(DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH), '9999-12-31')
     --            GROUP BY ALL
     --            ) SUM_TRANSACCIONES
     --      ON ACTIVACIONES.phone_nm = SUM_TRANSACCIONES.phone_nm AND ACTIVACIONES.service_id = SUM_TRANSACCIONES.service_id 
     
     -- -- LEFT JOIN (
     -- --            SELECT CAST(ACT.phone_nm AS INT64) phone_nm, ACT.service_id, ACT.marca
     -- --            FROM `mm-datamart-kd.BILLING.billing_detail_net` BILLING
     -- --            INNER JOIN `mm-commissions-reporting.COMISIONES.activaciones` ACT
     -- --                 ON BILLING.phone_nm = CAST(ACT.phone_nm AS INT64) AND BILLING.service_id = ACT.service_id AND BILLING.brand_ds = ACT.marca AND BILLING.data_month_id = ACT.id_mes
     -- --            WHERE BILLING.data_month_id = id_mes_pr
     -- --            AND BILLING.concept_type_ds = 'Consumos' 
     -- --            AND ACT.tariff_id = '8205'
     -- --            AND ACT.agrupacion_canal = 'Exclusivo'
     -- --            AND ACT.order_type_agg LIKE '%PORTABILIDAD%'
     -- --           ) DUO
     -- --      ON DUO.phone_nm = CAST(ACTIVACIONES.phone_nm AS INT64) AND DUO.service_id = ACTIVACIONES.service_id AND DUO.marca = ACTIVACIONES.marca 
     
     -- WHERE ACTIVACIONES.id_mes = id_mes_pr 
     --       AND ACTIVACIONES.canal = 'ENK'
     --       AND ACTIVACIONES.service_type IN ('MOBILE','INTERNET')
     --       AND ACTIVACIONES.order_type_agg LIKE '%PORTABILIDAD%'
     --       AND (
     --           ACTIVACIONES.tariff_id IN ('7126','7127')
     --           OR
     --           ACTIVACIONES.tariff_id IN ('8205','8212','8145','8187') AND DUO_COSTE.phone_nm IS NULL
     --           )

     ) SERVICIOS

     LEFT JOIN `mm-sales-reporting.TEMPORAL.ex_optico` OPTICO
               ON  SERVICIOS.cif = OPTICO.NUMERO_DOCUMENTO AND SERVICIOS.seller = COALESCE(OPTICO.SFID_1,OPTICO.SFID_2,OPTICO.SFID_3)
     
     CROSS JOIN UNNEST(canales_pr) canal_pr
     

WHERE SERVICIOS.canal = canal_pr 
     AND comision <> 0.0
)
;


END IF;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr,'TEMP.pnter', 'ACTUALIZAR');

END