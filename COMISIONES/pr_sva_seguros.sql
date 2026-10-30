BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','D2D','D2N','DEM','DO','ENK','EML','WA','XI','XS','XSO','OUO','OSPNIN','OSPNXSN','OUOV','OUOC'];
END IF;




-- CALL COMISIONES.pr_sva_seguros (202609,['XS']);

-- Borramos tabla de incentivos de TLV - Cross-sell para que no dé problemas para insertar cálculo de otros canales en Transacciones

-- DROP TABLE `mm-commissions-reporting.TEMP.sva_seguros_incentivo`; 


----- ACTIVACIONES -----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_seguros` AS (
     SELECT 
     'SEGRB'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,CASE 
          WHEN VENTAS.service = '1. SEGURO MOVIL' THEN 'B - Seguro Movil' 
          WHEN VENTAS.service = '2. SEGURO ROTURA PANTALLA' THEN 'B - Seguro Rotura Pantalla' 
          WHEN VENTAS.service = '5. SEGURO MULTIMEDIA' THEN 'B - Seguro Global Multimedia' 
      END AS concepto
     ,'CSMO' AS tipo_concepto
     ,1 AS unidades
     ,CASE 
       WHEN VENTAS.service = '1. SEGURO MOVIL' THEN --- SEGURO MOVIL
         CASE
          WHEN DEALER.canal IN ('ALTN','DO','DOT','WA','XI','XO','ENK','XS','OSPNIN','MKT_NR')      THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('XSO','OSPNXSN')AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') THEN VENTAS.premium*2
               WHEN DEALER.canal IN ('XSO','OUOP','OUOCC','OSPNXSN','OSPNOUN')
                         AND TLV_CAMP.campaign IN  (
                              --- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                              'COLD CALLING CAPTA SOHO',
                              'COLD CALLING CARTERA SOHO',
                              'COLD CALLING CAPTA RES',
                              'COLD CALLING CAPTA RES T EXTERNOS',
                              'COLD CALLING CAPTA RES NEW',
                              'COLD CALLING CAPTACION IA',


                              --- MR COLD CALLING CONTROLADO SOLO MARCA JAZZTEL ---

                              'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
                              'COLD CALLING CONTROLADO OFFSHORE',
                              'COLD CALLING CONTROLADO',
                              'COLD CALLING CONTROLADO TEMPL',
                              'COLD CALLING CONTROLADO CRECIMIENTOS',
                              'COLD CALLING CONTROLADO JE ',
                              'COLD CALLING CONTROLADO PL_EX',

                              --- MR LINEAS ADICIONALES SOLO MARCA JAZZTEL ---
                              'LINEAS ADICIONALES',


                              --- MR XSELLING SOLO MARCA JAZZTEL ---

                              'CROSS SELLING_MV',
                              'CROSS SELLING',
                              'CROSELLING_SEGUNDA RESIDENCIA'

                              ) THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('OUOV','OUOC') THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('XS') AND TLV_CAMP.campaign LIKE 'Multiproducto%' THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('EML')                            THEN VENTAS.premium_net*2
          WHEN DEALER.canal IN ('D2D','D2N','DEM')                THEN VENTAS.premium*4
         END 
       
       WHEN VENTAS.service = '2. SEGURO ROTURA PANTALLA' THEN --- SEGURO ROTURA PANTALLA
         CASE
          WHEN DEALER.canal IN ('DO','DOT','WA','XI','XO','XS','OSPNIN','MKT_NR')              THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('OUOV','OUOC') THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('XSO','OSPNXSN')AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('XSO','OUOP','OUOCC','OSPNXSN','OSPNOUN')
                         AND TLV_CAMP.campaign IN  (
                              --- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                              'COLD CALLING CAPTA SOHO',
                              'COLD CALLING CARTERA SOHO',
                              'COLD CALLING CAPTA RES',
                              'COLD CALLING CAPTA RES T EXTERNOS',
                              'COLD CALLING CAPTA RES NEW',
                              'COLD CALLING CAPTACION IA')
                              THEN VENTAS.premium*2
         END 

       WHEN VENTAS.service = '5. SEGURO MULTIMEDIA' THEN --- SEGURO GLOBAL MULTIMEDIA
         CASE
          WHEN DEALER.canal IN ('DO','DOT','WA','XI','XO','XS','ENK','OSPNIN','MKT_NR')              THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('OUOV','OUOC') THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('XSO','OSPNXSN')AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') THEN VENTAS.premium*2
          WHEN DEALER.canal IN ('XSO','OUOP','OUOCC','OSPNXSN','OSPNOUN')
                         AND TLV_CAMP.campaign IN  (
                              --- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                              'COLD CALLING CAPTA SOHO',
                              'COLD CALLING CARTERA SOHO',
                              'COLD CALLING CAPTA RES',
                              'COLD CALLING CAPTA RES T EXTERNOS',
                              'COLD CALLING CAPTA RES NEW',
                              'COLD CALLING CAPTACION IA')
                              THEN VENTAS.premium*2
         END          
             
      END AS comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id
     ,CASE WHEN VENTAS.agrupacion_canal = 'Exclusivo' THEN VENTAS.user_store ELSE VENTAS.sfid_id END AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,VENTAS.brand_ds AS marca
     ,'INSURANCE' AS service_type
     ,CAST(VENTAS.phone_nm  AS STRING) AS phone_nm
     ,CAST (NULL AS STRING) AS tariff_id
     ,VENTAS.service AS tariff_ds
     ,VENTAS.service_id
     ,VENTAS.policy_number AS account_id 
     ,VENTAS.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,DATE(VENTAS.sold_datetime) AS sale_date
     ,DATE(VENTAS.activated_datetime) AS activation_date
     ,DATE(VENTAS.terminated_datetime) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'061' AS cod_producto
     ,VENTAS.codigo_canal_sap AS cod_canal
     ,TLV_CAMP.campaign AS campaign_code
     ,VENTAS.imei AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(VENTAS.brand_ds) AS sociedad
  FROM (
     SELECT VENTAS.* EXCEPT(sfid_id, user_store), VENTAS.sfid_id, VENTAS.user_store, AGRUPACION.agrupacion_canal, AGRUPACION.codigo_canal_sap
     -- FROM `mm-sales-reporting.SPEEDUP.query_seguros_multimarca` VENTAS
     -- FROM `mm-datamart-kd.SERVICES.bibeseguros_subscriptions` VENTAS
     FROM `mm-commissions-reporting.COMISIONES.v_seguros` VENTAS -- 29/04/2026 Ainhoa: Cambiamos por tabla unificada para incluir marcas de Orange
     LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
   
              ON COALESCE(VENTAS.channel, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
                 AND VENTAS.master_channel_ds = AGRUPACION.master_channel_ds
                 AND VENTAS.channel_ds = AGRUPACION.channel_ds
                 AND VENTAS.subchannel_ds = AGRUPACION.subchannel_ds
                 AND VENTAS.brand_ds = AGRUPACION.comm_brand_ds
     
     UNION ALL
   
     SELECT VENTAS.* EXCEPT(sfid_id, user_store), DEVICES.sfid_id, DEVICES.user_store, AGRUPACION.agrupacion_canal, AGRUPACION.codigo_canal_sap
     FROM `mm-commissions-reporting.COMISIONES.v_seguros` VENTAS

     LEFT JOIN `mm-sales-reporting.SPEEDUP.query_devices_multimarca` DEVICES
              ON DEVICES.serial = VENTAS.imei 

     LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
   
              ON COALESCE(DEVICES.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
                 AND DEVICES.CANAL_N0 = AGRUPACION.master_channel_ds
                 AND DEVICES.CANAL_N1 = AGRUPACION.channel_ds
                 AND DEVICES.CANAL_N2 = AGRUPACION.subchannel_ds
                 AND DEVICES.brand_ds = AGRUPACION.comm_brand_ds
     
     WHERE VENTAS.master_channel_ds = 'DESCONOCIDO'
     AND DEVICES.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
        ) VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON (CASE WHEN COALESCE(VENTAS.agrupacion_canal,'Z') = 'Exclusivo' THEN VENTAS.seller ELSE VENTAS.sfid_id END = DEALER.sfid_id
            OR UPPER(SPLIT(VENTAS.seller, '@')[0]) = DEALER.sfid_id
            OR VENTAS.user_store = DEALER.sfid_id
            OR SPLIT(VENTAS.seller, '-')[OFFSET(0)] = DEALER.sfid_id
            )

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
  ON DEALER.id_comisionista = TLV_CAMP.id_comisionista 
  AND VENTAS.sfid_id = TLV_CAMP.sfid_id
  AND DEALER.canal = TLV_CAMP.canal

-- LEFT JOIN `mm-sales-reporting.SPEEDUP.query_devices_multimarca` DEVICES
--         ON DEVICES.serial = VENTAS.imei
--         AND DEVICES.phone_nm = VENTAS.phone_nm
--         AND DEVICES.brand_ds = VENTAS.brand_ds

-- Para evitar fraudes por imei
LEFT JOIN (SELECT DISTINCT serial_number
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE concepto IN ('B - Seguro Movil','B - Seguro movil' , 'B - Seguro Rotura Pantalla','B - Seguro Global Multimedia','F - Seguro Movil','Z - Seguro Movil')
           AND estado = 'facturado'
           AND id_mes < id_mes_pr
          ) TRANSACCIONES
          ON VENTAS.imei = TRANSACCIONES.serial_number
         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(VENTAS.activated_datetime, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND DATE_TRUNC(DATE(COALESCE(VENTAS.terminated_datetime, DATETIME '9999-12-31 00:00:00')),MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) -- 20260714 JD
-- AND DATE_DIFF(DEVICES.fecha_entrega, VENTAS.activation_date, DAY) BETWEEN 0 AND
--      CASE
--           WHEN VENTAS.service = '1. SEGURO MOVIL' THEN 90
--           WHEN VENTAS.service = '2. SEGURO ROTURA PANTALLA' THEN 730 
--           WHEN VENTAS.service = '5. SEGURO MULTIMEDIA' THEN 30 
--        END
AND DEALER.comisiona = true
AND DEALER.canal = canal_pr
AND (
    VENTAS.brand_ds IN ('MASMOVIL','YOIGO')
    OR (
        DEALER.CANAL IN ('DO','DOT','WA','XI','XO','OSPNIN','XSO','OSPNXSN','OUOP','OUOC','OUOCC','OUOV','MKT_NR')
        AND VENTAS.brand_ds IN ('MASMOVIL','YOIGO','ORANGE','JAZZTEL','SIMYO')
    )
)
AND TRANSACCIONES.serial_number IS NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY  VENTAS.service_id, concepto, VENTAS.imei ORDER BY VENTAS.activated_datetime DESC ) =  1 AND comision IS NOT NULL
)
;

----- GESTION DE CANAL -----

CREATE OR REPLACE TABLE TEMP.sva_seguros_gestion_canal AS (
  SELECT
      'SEGRF'||'_'|| mes_string ||'_'|| SEG.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,SEG.estado
     ,SEG.mes_liquidado
     ,SEG.id_mes
     ,SEG.agrupacion_canal
     ,SEG.canal
     ,REPLACE(SEG.concepto, 'B -', 'F -') AS concepto
     ,SEG.tipo_concepto
     ,unidades
     ,2 AS comision
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,SEG.sfid_id
     ,SEG.seller
     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,SEG.marca
     ,SEG.service_type
     ,SEG.phone_nm
     ,SEG.tariff_id
     ,SEG.tariff_ds
     ,SEG.service_id
     ,SEG.account_id
     ,SEG.customer_id
     ,SEG.line_type_ds
     ,SEG.bundle_type
     ,SEG.technology_ds
     ,SEG.billing_type_ds
     ,SEG.sale_date
     ,SEG.activation_date
     ,SEG.deactivation_date
     ,SEG.order_id
     ,SEG.order_type_agg
     ,SEG.cod_segmento
     ,SEG.cod_marca
     ,SEG.cod_tipo_contrato
     ,SEG.cod_producto
     ,SEG.cod_canal
     ,SEG.campaign_code
     ,SEG.serial_number
     ,SEG.tax_base
     ,SEG.claim_code
     ,SEG.process_code
     ,SEG.comments
     ,SEG.facturador
     ,SEG.sociedad

FROM `mm-commissions-reporting.TEMP.sva_seguros` SEG

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON SEG.sfid_id = DEALER.sfid_id 
            AND SEG.agrupacion_canal = DEALER.agrupacion_canal

LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

WHERE DEALER.distribuidor IS NOT NULL
AND SEG.agrupacion_canal != 'Exclusivo'

)
;

/*
---- INCENTIVO TLV - CROSS-SELL MARKTEL

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('XI','XS')) THEN
-- Borramos tabla de incentivos de TLV - Cross-sell para que no dé problemas para insertar cálculo de otros canales en Transacciones
DROP TABLE `mm-commissions-reporting.TEMP.sva_seguros_incentivo`; 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_seguros_incentivo` AS (
     SELECT
      'SEGRD'||'_'|| mes_string ||'_'||canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,agrupacion_canal
     ,'XI' AS canal
     ,'D - Incentivo venta seguro movil' AS concepto
     ,'CSMO' AS tipo_concepto
     ,1 AS unidades
     ,3.15 AS comision
     ,'CARIN003'AS id_comisionista
     ,distribuidor
     ,'CARIN003'AS sfid_id
     ,seller
     ,'MARKTEL IN' AS nombre_comercio
     ,'MARKTEL SERVICIOS DE MARKETING TELE' AS razon_social
     ,'A82236944' cif
     ,'PEN' AS zona_fiscal
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id 
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,order_id
     ,order_type_agg
     ,cod_segmento
     ,cod_marca
     ,cod_tipo_contrato
     ,cod_producto
     ,'15' AS cod_canal
     ,campaign_code
     ,serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,facturador
     ,sociedad 

FROM `mm-commissions-reporting.TEMP.sva_seguros` SEGUROS        

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(COALESCE(SEGUROS.deactivation_date,'9999-12-31'), MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND SEGUROS.canal = canal_pr
AND SEGUROS.tariff_ds = '1. SEGURO MOVIL'

QUALIFY ROW_NUMBER() OVER (PARTITION BY  SEGUROS.service_id ORDER BY SEGUROS.ACTIVATION_DATE DESC ) =  1 AND comision IS NOT NULL
)
;
END IF;
*/
---- CLAWBACK  ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_seguros_clawback_deactivation_date` AS
(
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date)
     ,DATE(DEACTIVATIONS.terminated_datetime) AS deactivation_Date
      
FROM (
     SELECT
           commission_id
          ,estado
          ,mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,concepto
          ,tipo_concepto
          ,unidades
          ,comision
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
          ,marca
          ,service_type
          ,phone_nm
          ,tariff_id
          ,tariff_ds
          ,service_id
          ,account_id
          ,customer_id
          ,line_type_ds
          ,bundle_type
          ,technology_ds
          ,billing_type_ds
          ,sale_date
          ,activation_date
          ,deactivation_date
          ,order_id
          ,order_type_agg
          ,cod_segmento
          ,cod_marca
          ,cod_tipo_contrato
          ,cod_producto
          ,cod_canal
          ,campaign_code
          ,serial_number
          ,tax_base
          ,claim_code
          ,process_code
          ,comments
          ,facturador
          ,sociedad
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones`
     WHERE (
            DATE_TRUNC(activation_date, MONTH) BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 7 MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
            OR
            DATE_TRUNC(sale_date, MONTH) BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 7 MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
           )
           AND concepto IN ('B - Seguro Movil','B - Seguro movil' , 'B - Seguro Rotura Pantalla','B - Seguro Global Multimedia','F - Seguro Movil','Z - Seguro movil')
           AND estado IN ('facturado','publicado')
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.sva_seguros`
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.sva_seguros_gestion_canal`
     ) TRANSACCIONES

-- LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguros_multimarca` DEACTIVATIONS
--  LEFT JOIN `mm-datamart-kd.SERVICES.bibeseguros_subscriptions` DEACTIVATIONS
   LEFT JOIN `mm-commissions-reporting.COMISIONES.v_seguros`  DEACTIVATIONS
          ON (
                  (CASE WHEN TRANSACCIONES.id_mes >= 202602 THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.customer_id END
                  =
                  CASE WHEN DATE_TRUNC(DATE(DEACTIVATIONS.activated_datetime), MONTH) >= '2026-02-01' THEN DEACTIVATIONS.service_id ELSE DEACTIVATIONS.policy_number END             
                  ) 

             OR

                  (CASE WHEN TRANSACCIONES.id_mes >= 202602 THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.customer_id END
                  =
                  CASE WHEN DATE_TRUNC(DATE(DEACTIVATIONS.activated_datetime), MONTH) >= '2026-02-01' THEN DEACTIVATIONS.service_id ELSE DEACTIVATIONS.imei END             
                  )
            ) -- Antes de feb26 las activaciones se metían manualmente sin service_id 
            AND (TRANSACCIONES.marca
                 =
                 CASE WHEN DATE_TRUNC(DATE(DEACTIVATIONS.activated_datetime), MONTH) >= '2026-02-01' THEN DEACTIVATIONS.brand_ds ELSE 'YOIGO' END             
                ) -- Antes de feb26 las activaciones se metían todas con marca YOIGO
            AND (TRANSACCIONES.customer_id = DEACTIVATIONS.policy_number OR TRANSACCIONES.customer_id = DEACTIVATIONS.imei OR TRANSACCIONES.account_id = DEACTIVATIONS.policy_number) -- Antes de feb26 el nro. de póliza o imei se ponía en el campo customer_id
            AND (TRANSACCIONES.sale_date = DATE(DEACTIVATIONS.sold_datetime) OR TRANSACCIONES.sale_date = DATE(DEACTIVATIONS.activated_datetime) OR TRANSACCIONES.activation_date = DATE(DEACTIVATIONS.activated_datetime)) -- Antes de feb26 sólo se rellenaba sale_date con fecha de activación
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE DATE_TRUNC(DEACTIVATIONS.terminated_datetime, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
      AND DATE(DEACTIVATIONS.terminated_datetime) <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,TRANSACCIONES.sale_date,'1969-01-01'), INTERVAL 180 DAY)
      AND TRANSACCIONES.canal = canal_pr


QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.activation_date = DATE(DEACTIVATIONS.activated_datetime) THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.terminated_datetime ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_seguros_clawback_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - Clawback ' ELSE 'E - Clawback ' END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     ,TRANSACCIONES.tipo_concepto
     ,CASE WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' THEN TRANSACCIONES.seller ELSE TRANSACCIONES.id_comisionista END AS id_comisionista
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,TRANSACCIONES.sociedad
     ,MAX(TRANSACCIONES.bundle_type) AS bundle_type
     ,MAX(TRANSACCIONES.campaign_code) AS campaign_code
     ,MAX(TRANSACCIONES.line_type_ds) AS line_type_ds
     ,MAX(TRANSACCIONES.order_id) AS order_id
     ,MAX(TRANSACCIONES.order_type_agg) AS order_type_agg
     ,MAX(TRANSACCIONES.serial_number) AS serial_number
     ,MAX(TRANSACCIONES.tariff_ds) AS tariff_ds
     ,MAX(TRANSACCIONES.tariff_id) AS tariff_id
     ,MAX(TRANSACCIONES.tax_base) AS tax_base
     ,MAX(TRANSACCIONES.technology_ds) AS technology_ds
     ,MAX(TRANSACCIONES.comments) AS comments
     ,SUM(TRANSACCIONES.comision) AS comision
     ,ARRAY_AGG(TRANSACCIONES.commission_id) AS commission_id
     
FROM `mm-commissions-reporting.TEMP.sva_seguros_clawback_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_seguros_clawback_dealer`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(
                            canal,
                            comision,
                            commission_id,
                            id_comisionista,
                            campaign_code
                            )
     
     ,'SEGRE' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int(id_mes_pr) AS mes_liquidado
     ,id_mes_pr as id_mes
     ,1 AS unidades

     ,COALESCE(DEALER.canal, TRANSACCIONES.canal) AS canal

     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback` (
        DATE_DIFF(TRANSACCIONES.deactivation_date, COALESCE(TRANSACCIONES.activation_date,TRANSACCIONES.sale_date), DAY) + 1
       ,COALESCE(DEALER.canal, TRANSACCIONES.canal)
       ,TRANSACCIONES.tariff_ds
      )
      * TRANSACCIONES.comision AS comision
     
     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'BYMOVIL'
          ELSE COALESCE(MASTER.id_comisionista, DEALER.id_comisionista)
      END AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.distribuidor
     ,TLV_CAMP.campaign AS campaign_code
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.sva_seguros_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
         ON DEALER.id_comisionista = TLV_CAMP.id_comisionista 
         AND TRANSACCIONES.SFID_ID = TLV_CAMP.sfid_id
         AND DEALER.canal = TLV_CAMP.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE (DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL)
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_seguros_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.* EXCEPT (SFID_ID)
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.sva_seguros_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.sva_seguros_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) SEG
          LEFT JOIN `mm-commissions-reporting.TEMP.sva_seguros_clawback_deactivation_date` TRANSACCIONES
                   ON REPLACE(SEG, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0
)
;

-- ASSERT NOT EXISTS (
--      SELECT DISTINCT serial_number
--      FROM `mm-commissions-reporting.TEMP.sva_seguros`
--      GROUP BY ALL
--      HAVING COUNT(1) > 1
-- ) AS 'Hay IMEIs duplicados en la tabla de seguros';


--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SEGRB', id_mes_pr, canales_pr, 'TEMP.sva_seguros', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SEGRF', id_mes_pr, canales_pr, 'TEMP.sva_seguros_gestion_canal', 'ACTUALIZAR');
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SEGRD', id_mes_pr, canales_pr, 'TEMP.sva_seguros_incentivo', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SEGRE', id_mes_pr, canales_pr, 'TEMP.sva_seguros_clawback', 'ACTUALIZAR');



END