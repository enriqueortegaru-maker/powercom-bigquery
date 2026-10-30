BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'PTWF';

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','ALTNC','ALTNH','ENK','D2D','D2N','OUN','DON','CIN','XIN','XSN'];
END IF;

/*
CALL COMISIONES.pr_punto_wifi(202505, null);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.punto_wifi` AS (

----- ACTIVACIONES -----

     SELECT
      prefijo||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal

     ,CASE 
          WHEN VENTAS.sva_modality IN ('MASWIFI' , 'PUNTOWIFI')  THEN 'B - Punto Wifi'
          WHEN VENTAS.sva_modality IN ('MASWIFI PREMIUM')        THEN 'B - Punto Wifi Premium'
      END AS concepto 

     ,'INTERNET' AS tipo_concepto
     ,1 AS unidades
     ,CASE 
        WHEN DEALER.canal = 'ENX' THEN
         CASE
          WHEN VENTAS.sva_modality IN ('MASWIFI' , 'PUNTOWIFI')  THEN 25.00
          WHEN VENTAS.sva_modality IN ('MASWIFI PREMIUM')        THEN 30.00
         END

        WHEN DEALER.canal IN ('ALTN','ALTNC','ALTNH') THEN
         CASE
          WHEN VENTAS.sva_modality IN ('MASWIFI' , 'PUNTOWIFI')  THEN 25.00
          WHEN VENTAS.sva_modality IN ('MASWIFI PREMIUM')        THEN 33.00
         END
        
        WHEN DEALER.canal IN ('D2D','D2N','OUN','DON','CIN','XIN','XSN') THEN
         CASE
          WHEN VENTAS.sva_modality IN ('MASWIFI' , 'PUNTOWIFI')  THEN 27.00
          WHEN VENTAS.sva_modality IN ('MASWIFI PREMIUM')        THEN 36.00
         END
      ELSE 0.0
      END AS comision
     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,COALESCE(VENTAS.seller, DEALER.id_comisionista) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,VENTAS.brand_ds AS marca
     ,VENTAS.service_type
     ,VENTAS.phone_nm
     ,VENTAS.service_type AS tariff_id
     ,VENTAS.sva_modality AS tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id 
     ,VENTAS.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,VENTAS.contract_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'999' AS cod_producto
     ,AGRUPACION.codigo_canal_sap AS cod_canal
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,CAST (NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(VENTAS.brand_ds) AS sociedad 

FROM `mm-soho-reporting.TEMPORALES_SOHO.sva_unificado` VENTAS


LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_emysim` BASE
ON VENTAS.service_id = BASE.service_id 
   AND BASE.service_type ='BROADBAND'
   AND VENTAS.customer_id = BASE.customer_id 
   AND VENTAS.account_id = BASE.account_id 


LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(VENTAS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND VENTAS.master_channel_ds = AGRUPACION.master_channel_ds
            AND VENTAS.channel_ds = AGRUPACION.channel_ds
            AND VENTAS.subchannel_ds = AGRUPACION.subchannel_ds
            AND VENTAS.brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            REPLACE(BASE.sfid_id, 'LB', '') = DEALER.sfid_id
            OR UPPER(SPLIT(BASE.seller, '@')[0]) = DEALER.sfid_id
            OR BASE.user_store = DEALER.sfid_id
            OR BASE.sfid_id || '-' || BASE.seller = REPLACE(DEALER.sfid_id, ' ', '')
            )
            AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal
         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(VENTAS.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND VENTAS.sva_modality IN ('MASWIFI','MASWIFI PREMIUM','PUNTOWIFI' )
AND DEALER.comisiona = true
AND DEALER.canal = canal_pr

QUALIFY ROW_NUMBER() OVER (PARTITION BY  VENTAS.service_id ORDER BY VENTAS.sfid_id DESC ) =  1 
)
;

--- GESTION DE CANAL ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.punto_wifi_gestion_canal`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      'PTWFF'||'_'|| mes_string ||'_'|| VENTAS.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,VENTAS.canal
     ,REPLACE(concepto, 'B -', 'F -') AS concepto
     ,tipo_concepto
     ,unidades

     ,CASE 
          WHEN CONCEPTO = 'B - Punto Wifi'         THEN 2.00
          WHEN CONCEPTO = 'B - Punto Wifi Premium' THEN 3.00
      END AS comision 

     ,VENTAS.id_comisionista
     ,distribuidor
     ,sfid_id
     ,seller
     ,MASTER.nombre_comercio
     ,MASTER.razon_social
     ,MASTER.cif
     ,MASTER.zona_fiscal
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
FROM `mm-commissions-reporting.TEMP.punto_wifi` VENTAS

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER 
 ON VENTAS.distribuidor = MASTER.id_comisionista

WHERE VENTAS.CANAL IN ('ALTN','ALTNC','ALTNH')
AND MASTER.id_comisionista IS NOT NULL

)


;


-- DESACTIVACIONES -- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.punto_wifi_clawback_deactivation_date`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date)
     ,DEACTIVATIONS.deactivation_date
      
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
     WHERE DATE_TRUNC(activation_date, MONTH) BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 7 MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND estado = 'facturado'
      AND CONCEPTO IN ('B - Punto Wifi','B - Punto Wifi Premium')
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.punto_wifi` 
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.punto_wifi_gestion_canal` 
     ) TRANSACCIONES

LEFT JOIN `mm-soho-reporting.TEMPORALES_SOHO.sva_unificado` DEACTIVATIONS
         ON TRANSACCIONES.service_id = DEACTIVATIONS.service_id
            AND TRANSACCIONES.marca = DEACTIVATIONS.brand_ds
            AND TRANSACCIONES.account_id = DEACTIVATIONS.account_id
            AND TRANSACCIONES.customer_id = DEACTIVATIONS.customer_id
            AND TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
      AND DEACTIVATIONS.deactivation_date <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,'1969-01-01'), INTERVAL 180 DAY)
      AND TRANSACCIONES.canal = canal_pr

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.deactivation_date ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.punto_wifi_clawback_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - Clawback ' ELSE 'E - Clawback ' END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_comisionista
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
     
FROM `mm-commissions-reporting.TEMP.punto_wifi_clawback_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.punto_wifi_clawback_dealer`
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
     
     ,'PTWFE' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int(id_mes_pr) AS mes_liquidado
     ,id_mes_pr as id_mes
     ,1 AS unidades

     ,COALESCE(DEALER.canal, TRANSACCIONES.canal) AS canal

     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback` (
        DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) + 1
       ,COALESCE(DEALER.canal, TRANSACCIONES.canal)
       ,TRANSACCIONES.tariff_ds
      )
      * TRANSACCIONES.comision AS comision
     
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.distribuidor
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.punto_wifi_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.punto_wifi_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.punto_wifi_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.punto_wifi_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) STRE
          LEFT JOIN `mm-commissions-reporting.TEMP.punto_wifi_clawback_deactivation_date` TRANSACCIONES
                   ON REPLACE(STRE, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0)

;

CREATE OR REPLACE TABLE TEMP.punto_wifi AS
(
SELECT * 
FROM TEMP.punto_wifi
WHERE comision > 0.0
)
;

--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('PTWFB', id_mes_pr, canales_pr, 'TEMP.punto_wifi', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('PTWFF', id_mes_pr, canales_pr, 'TEMP.punto_wifi_gestion_canal', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('PTWFE', id_mes_pr, canales_pr, 'TEMP.punto_wifi_clawback', 'ACTUALIZAR');



END