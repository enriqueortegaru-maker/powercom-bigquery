BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo);

IF canales_pr IS NULL THEN 
  SET canales_pr = ['CIN', 'D2N', 'DO', 'DON', 'EML', 'ENK', 'EYG', 'OU', 'OUN', 'WA', 'XI', 'XIN', 'XO', 'XOF', 'XS', 'XSO'];

END IF;


/*
CALL COMISIONES.pr_stream_preliqui(202510, ['XS','XSO'],'DAILY');
*/


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stream_activations`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      'STREB'||'_'|| mes_string ||'_'|| canal_pr ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     , CASE WHEN VENTAS.sfid_id IN ('DONL026','TLVOU001') THEN 'TLV - DO' ELSE AGRUPACION.agrupacion_canal END AS agrupacion_canal
     ,DEALER.canal
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,1 AS unidades

     ,`mm-commissions-reporting.COMISIONES.f_comision_streaming`
      (
      DEALER.canal,
      DEALER.id_comisionista,
      VENTAS.service_type, 
      TRUE,
      FALSE,
      TLV_CROSS_SELL.campaign
      ) AS comision

     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id

     ,CASE
          WHEN DEALER.agrupacion_canal = 'Exclusivo'                THEN UPPER(VENTAS.user_store)
          WHEN (VENTAS.seller LIKE '%@%' OR seller in ('ygonline')) THEN UPPER(DEALER.sfid_id)
          ELSE UPPER(SPLIT(VENTAS.seller, '@')[0])
      END AS seller

     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,VENTAS.brand_ds AS marca
     ,VENTAS.service_type
     ,CAST(SERVICE_DETAILS.phone_nm AS STRING) AS phone_nm
     ,VENTAS.tariff_id
     ,VENTAS.tariff_ds
     
     ,CASE
          WHEN VENTAS.service_type = 'NETFLIX' THEN VENTAS.service_id
          ELSE SERVICE_DETAILS.service_id
      END AS service_id

     ,VENTAS.account_id
     ,VENTAS.customer_id
     ,VENTAS.line_type_ds

     ,CASE
          WHEN COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) IN ('2P', 'FMC', 'MO')
          THEN COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type)

          WHEN COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) LIKE ('%M%') AND COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) LIKE ('%B%')
          THEN 'FMC'

          WHEN COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) LIKE ('%M%')
               AND COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) NOT LIKE ('%B%')
          THEN 'MO'
          
          WHEN COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) NOT LIKE ('%M%')
               AND COALESCE(VENTAS.sell_bundle_type, SERVICE_DETAILS.bundle_type) LIKE ('%B%')
          THEN '2P'
      END AS bundle_type

     ,VENTAS.technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,VENTAS.order_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,CAST(VENTAS.order_id AS STRING) AS order_id
     ,VENTAS.order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca

     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
         billing_type_ds, 
         VENTAS.service_type, 
         COALESCE(CASE WHEN VENTAS.sell_bundle_type = 'DESC' THEN VENTAS.bundle_type ELSE VENTAS.sell_bundle_type END, VENTAS.bundle_type), 
         technology_ds, 
         VENTAS.brand_ds, 
         COALESCE(CASE WHEN sell_line_type_ds = 'DESC' THEN line_type_ds ELSE sell_line_type_ds END, line_type_ds)
      )  AS cod_tipo_contrato

     ,'006' AS cod_producto

     ,AGRUPACION.codigo_canal_sap AS cod_canal
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,VENTAS.service_id AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(VENTAS.brand_ds) AS sociedad --<---- Revisar

FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON VENTAS.service_type = CONCEPTOS.service_type AND CONCEPTOS.proceso = 'STRE' AND SUBSTR(CONCEPTOS.concepto,1,1) = 'B'

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(VENTAS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND VENTAS.master_channel_ds = AGRUPACION.master_channel_ds
            AND VENTAS.channel_ds = AGRUPACION.channel_ds
            AND VENTAS.subchannel_ds = AGRUPACION.subchannel_ds
            AND VENTAS.comm_brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            REPLACE(VENTAS.sfid_id, 'LB', '') = DEALER.sfid_id
            OR UPPER(SPLIT(VENTAS.seller, '@')[0]) = DEALER.sfid_id
            OR VENTAS.user_store = DEALER.sfid_id
            OR VENTAS.sfid_id || '-' || VENTAS.seller = REPLACE(DEALER.sfid_id, ' ', '')
            )
            AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN (
          SELECT SERVICE_DETAILS.*
          
          FROM (
               SELECT
                     account_id
                    ,service_id
                    ,phone_nm
                    ,brand_ds
                    ,service_type
                    ,bundle_type
                    ,order_date
                    ,cancellation_date
                    ,activation_date
                    ,deactivation_date
                    ,order_fix_id
               FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
               WHERE data_source_ds = 'MYSIM'
                     AND service_type IN ('BROADBAND', 'FIX', 'MOBILE')
                    --  AND service_status_ds = 'ACTIVO' -- JOHANNA 20250506 PARA EVITAR DUPLICADO EN ESTADO TERMINADO
               ) SERVICE_DETAILS
          
          INNER JOIN (
                     SELECT
                           account_id
                          ,brand_ds
                     FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                     WHERE service_type IN ('AMAZON PRIME', 'MAX', 'NETFLIX','DISNEY')
                           AND brand_ds IN ('YOIGO','MASMOVIL')
                     GROUP BY 1,2
                     ) STREAMING_ACCOUNTS
                    ON SERVICE_DETAILS.account_id = STREAMING_ACCOUNTS.account_id AND SERVICE_DETAILS.brand_ds = STREAMING_ACCOUNTS.brand_ds
          
          QUALIFY RANK() OVER (
                              PARTITION BY account_id, brand_ds
                              ORDER BY CASE WHEN service_type = 'BROADBAND' THEN 1 ELSE 2 END ASC
                              ) = 1
          ) SERVICE_DETAILS
         ON VENTAS.account_id = SERVICE_DETAILS.account_id AND VENTAS.brand_ds = SERVICE_DETAILS.brand_ds

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE VENTAS.service_type IN ('AMAZON PRIME', 'MAX', 'NETFLIX', 'DISNEY')
      AND DATE_TRUNC(VENTAS.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND VENTAS.activation_date <= COALESCE(VENTAS.deactivation_date, '9999-12-31')
      AND VENTAS.brand_ds IN ('YOIGO','MASMOVIL')
      AND CASE WHEN VENTAS.sfid_id IN ('DONL026','TLVOU001') THEN 'TLV - DO' ELSE AGRUPACION.agrupacion_canal END = DEALER.agrupacion_canal
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND `mm-commissions-reporting.COMISIONES.f_comision_streaming`
          (
          DEALER.canal,
          DEALER.id_comisionista,
          VENTAS.service_type, 
          TRUE,
          FALSE,
          TLV_CROSS_SELL.campaign
          ) > 0.0
        
QUALIFY RANK() OVER (
                    PARTITION BY VENTAS.service_id, VENTAS.brand_ds, VENTAS.service_type
                    ORDER BY
                            CASE
                                WHEN VENTAS.activation_date BETWEEN SERVICE_DETAILS.order_date
                                     AND COALESCE(SERVICE_DETAILS.deactivation_date, SERVICE_DETAILS.cancellation_date, '9999-12-31') THEN 1
                                ELSE 2
                            END ASC

                           ,CASE
                                WHEN COALESCE(VENTAS.deactivation_date, '9999-12-31') = '9999-12-31'
                                     AND COALESCE(SERVICE_DETAILS.deactivation_date, SERVICE_DETAILS.cancellation_date, '9999-12-31') = '9999-12-31'
                                THEN 1
                                ELSE 2
                            END ASC

                           ,CASE WHEN SERVICE_DETAILS.order_fix_id IS NOT NULL THEN 1 ELSE 2 END ASC

                           ,ABS(DATE_DIFF(SERVICE_DETAILS.activation_date, VENTAS.activation_date, DAY)) ASC
                    ) = 1
)
;


ASSERT NOT EXISTS
(
SELECT phone_nm, account_id, marca, service_type, serial_number
FROM `mm-commissions-reporting.TEMP.stream_activations`
GROUP BY 1,2,3,4,5
HAVING COUNT(1) > 1
) AS 'There are duplicates in stream_activations'
;


---- Tabla Gestión Canal ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stream_gestion_canal`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      'STREF'||'_'|| mes_string ||'_'|| canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
     ,REPLACE(concepto, 'B -', 'F -') AS concepto
     ,tipo_concepto
     ,unidades

     ,`mm-commissions-reporting.COMISIONES.f_comision_streaming`
      (
      canal,
      id_comisionista,
      service_type, 
      FALSE,
      TRUE,
      'campaign_code'
      ) AS comision

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
FROM `mm-commissions-reporting.TEMP.stream_activations`
WHERE `mm-commissions-reporting.COMISIONES.f_comision_streaming`
       (
       canal,
       id_comisionista,
       service_type, 
       FALSE,
       TRUE,
      'campaign_code'
       ) > 0.0
)
;


---- Clawback ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stream_clawback_deactivation_date`
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
           AND service_type IN ('AMAZON PRIME', 'MAX', 'NETFLIX','DISNEY')
           AND estado = 'facturado'
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.stream_activations`
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.stream_gestion_canal`
     ) TRANSACCIONES

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` DEACTIVATIONS
         ON TRANSACCIONES.serial_number = DEACTIVATIONS.service_id
            AND TRANSACCIONES.marca = DEACTIVATIONS.brand_ds
            AND TRANSACCIONES.service_type = DEACTIVATIONS.service_type
            AND TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
      AND DEACTIVATIONS.deactivation_date <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,'1969-01-01'), INTERVAL 180 DAY)
      AND TRANSACCIONES.canal = canal_pr

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.sale_date = DEACTIVATIONS.order_date THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.deactivation_date ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stream_clawback_summation`
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
     
FROM `mm-commissions-reporting.TEMP.stream_clawback_deactivation_date` TRANSACCIONES
WHERE TRANSACCIONES.canal != 'ENK'
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stream_clawback_dealer`
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
     
     ,'STREE' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
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
     
     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'BYMOVIL'
          ELSE COALESCE(MASTER.id_comisionista, DEALER.id_comisionista)
      END AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.distribuidor
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.stream_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stream_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.stream_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.stream_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) STRE
          LEFT JOIN `mm-commissions-reporting.TEMP.stream_clawback_deactivation_date` TRANSACCIONES
                   ON REPLACE(STRE, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

WHERE NOT ( campaign_code IN ('Camp. piloto','Blindaje'))
AND NOT (
  CLWB.activation_date >= '2025-07-01' ---> Desde julio hay cambios en las OTTs y no se aplica Clawback a algunos canales.
)

AND NOT (CLWB.activation_date >= '2025-08-01' ---> Desde agosto hay no se aplica Clawback en HBO MAX a algunos canales.
          AND CANAL IN ('OU','DO','XI','XO','XOF','WA','XS','XSO')
          AND CLWB.concepto IN ('B - Max')
          )

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0
)
;


--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('STREB', id_mes_pr, canales_pr, 'TEMP.stream_activations', modo);
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('STREF', id_mes_pr, canales_pr, 'TEMP.stream_gestion_canal', modo);
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('STREE', id_mes_pr, canales_pr, 'TEMP.stream_clawback', modo);



END