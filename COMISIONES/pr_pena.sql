BEGIN

DECLARE mes_string, prefijo STRING;


SET prefijo = 'JJPENA';

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES` WHERE plantilla_activaciones IS NOT NULL));

SET mes_string = CAST(mes_int AS STRING);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_pena`(202502, ['D2D']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pena_transacciones`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(id_comisionista, claim_code, comments)
     ,FRAUD.sfid AS fraud_seller

     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND TRANSACCIONES.id_comisionista IN ('BYMOVIL')    THEN TRANSACCIONES.seller
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND LENGTH(TRANSACCIONES.id_comisionista) IN (2, 3) THEN TRANSACCIONES.seller
          WHEN TRANSACCIONES.agrupacion_canal = 'Guuk' AND TRANSACCIONES.id_comisionista IN ('BYMOVIL')         THEN TRANSACCIONES.sfid_id
          ELSE TRANSACCIONES.id_comisionista
      END AS id_comisionista
     
     ,CONCAT('Auditoria ', mes_string) AS claim_code
     ,'Penalizacion por fraude' AS comments
      
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT *
          FROM `mm-commissions-reporting.TERMINALES.MAN_WRONG_ADD`
          WHERE DATE_TRUNC(event_date, MONTH) = COMISIONES.f_mes_int(mes_int) AND tipo = 'FRAUDE'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY msisdn ORDER BY done_stamp DESC) = 1
          ) FRAUD
         ON (
            TRANSACCIONES.id_comisionista = FRAUD.sfid
            OR TRANSACCIONES.sfid_id = FRAUD.sfid
            OR TRANSACCIONES.seller = FRAUD.sfid
            )
            AND TRANSACCIONES.phone_nm = CAST(FRAUD.msisdn AS STRING)
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE FRAUD.msisdn IS NOT NULL
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado != 'rechazado'
      AND TRANSACCIONES.mes_liquidado >= DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 5 MONTH)
      AND TRANSACCIONES.mes_liquidado < DATE_ADD(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      AND TRANSACCIONES.tipo_concepto NOT IN ('AIRT')
      AND (
           (
           FRAUD.tipo_fraude = 'COMISIONES'
           AND NOT (TRANSACCIONES.concepto LIKE 'T%' OR TRANSACCIONES.concepto LIKE 'X%')
           )
          OR
           (
           FRAUD.tipo_fraude = 'TOT'
           AND TRANSACCIONES.tipo_concepto NOT IN ('AIRT')
           AND NOT (TRANSACCIONES.concepto LIKE 'T%' OR TRANSACCIONES.concepto LIKE 'X%')
           AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto)) NOT IN
                 (
                  'Cambio de Titularidad'
                 ,'Clawback Cambio de Titularidad'
                 ,'Clawback seguro movil'
                 ,'Clawback seguro pagos'
                 ,'Clawback Television'
                 ,'Clawback Television Premium'
                 ,'Devolucion SIM'
                 ,'Devolucion SIM Yoigo'
                 ,'Duplicado SIM'
                 ,'Extracomision Comercial FMC Distribuidor'
                 ,'Extracomision Comercial Piloto Omnicanalidad'
                 ,'Extracomision Comercial postpago Distribuidor'
                 ,'Extracomision Comercial renuevo'
                 ,'Mistery Shopping'
                 ,'Seguro movil'
                 ,'Seguro pagos'
                 ,'Servicio Movil Prepago'
                 ,'Television'
                 ,'Television Premium'
                 )
           )
          )



QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.seller = FRAUD.sfid THEN 1 ELSE 2 END ASC,
                                   CASE WHEN TRANSACCIONES.sfid_id = FRAUD.sfid THEN 1 ELSE 2 END ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pena_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,'P - ' || SUBSTR(REPLACE(TRANSACCIONES.concepto, 'Clawback ', ''), 5) AS concepto
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,TRANSACCIONES.sociedad
     ,TRANSACCIONES.fraud_seller
     ,MAX(TRANSACCIONES.activation_date) AS activation_date
     ,MAX(TRANSACCIONES.bundle_type) AS bundle_type
     ,MAX(TRANSACCIONES.campaign_code) AS campaign_code
     ,MIN(TRANSACCIONES.deactivation_date) AS deactivation_date
     ,MAX(TRANSACCIONES.line_type_ds) AS line_type_ds
     ,MAX(TRANSACCIONES.order_id) AS order_id
     ,MAX(TRANSACCIONES.order_type_agg) AS order_type_agg
     ,MIN(TRANSACCIONES.sale_date) AS sale_date
     ,MAX(TRANSACCIONES.serial_number) AS serial_number
     ,MAX(TRANSACCIONES.tariff_ds) AS tariff_ds
     ,MAX(TRANSACCIONES.tariff_id) AS tariff_id
     ,MAX(TRANSACCIONES.tax_base) AS tax_base
     ,MAX(TRANSACCIONES.technology_ds) AS technology_ds
     ,MAX(TRANSACCIONES.claim_code) AS claim_code
     ,MAX(TRANSACCIONES.comments) AS comments
     ,SUM(TRANSACCIONES.comision) AS comision
     ,ARRAY_AGG(TRANSACCIONES.commission_id) AS commission_id
     ,COUNT(DISTINCT TRANSACCIONES.commission_id) AS commission_id_count
     
FROM `mm-commissions-reporting.TEMP.pena_transacciones` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
)
;


ASSERT NOT EXISTS
(
SELECT *
FROM `mm-commissions-reporting.TEMP.pena_summation`
QUALIFY COUNT(*) OVER (PARTITION BY phone_nm, marca,concepto,activation_date ,id_comisionista) > 1
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pena_dealer`
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
     
     ,prefijo || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int (mes_int) AS mes_liquidado
     ,mes_int as id_mes
     ,1 AS unidades

     ,CASE
          WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
          ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
      END AS canal

     ,TRANSACCIONES.comision * -1.00 AS comision
     
     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'BYMOVIL'
          WHEN TRANSACCIONES.agrupacion_canal = 'Guuk' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y')      THEN 'BYMOVIL'
          ELSE COALESCE(MASTER.id_comisionista, DEALER.id_comisionista)
      END AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,COALESCE(MASTER.id_comisionista, DEALER.distribuidor) AS distribuidor

     ,CASE
          WHEN TRANSACCIONES.activation_date < '2024-07-22' --<-- INCLUSION DE NUEVOS SFIDS Y CAMPAÑAS EN TLV CROSS-SELL - JULIO 2024
          THEN COALESCE(
                        TRANSACCIONES.campaign_code
                       ,COMISIONES.f_clasificacion_camp_cross_sell(
                          CASE
                              WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
                              ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
                          END
                         ,TRANSACCIONES.marca
                         ,TRANSACCIONES.fraud_seller
                         ,TRANSACCIONES.service_type
                         )
                       ,TLV_CROSS_SELL.campaign
                        )
          
          ELSE COALESCE(
                        TRANSACCIONES.campaign_code
                       ,TLV_CROSS_SELL.campaign
                       ,COMISIONES.f_clasificacion_camp_cross_sell(
                          CASE
                              WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
                              ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
                          END
                         ,TRANSACCIONES.marca
                         ,TRANSACCIONES.fraud_seller
                         ,TRANSACCIONES.service_type
                         )
                        )
      END AS campaign_code
              
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.pena_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pena`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      PENA.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.pena_dealer` PENA

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.pena_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) ACTI
          LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
                   ON REPLACE(ACTI, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON PENA.commission_id = DEALER_DETAIL.commission_id

WHERE comision < 0
      OR (
         PENA.concepto IN ('E - Clawback Extracomision Objetivo fijo', 'E - Clawback Extracomision Objetivo Movil Pospago')
         AND PENA.comision > 0
         AND commission_id_count = 1
         )
)
;


-- REVISAR DUPLICIDAD por esta combinación de campos por compartir la misma fecha de desactivacion (CAMBIOS DE DOMICILIO y CAMBIOS DE TECNOLOGIA)


ASSERT NOT EXISTS
(
SELECT phone_nm
FROM `mm-commissions-reporting.TEMP.pena`
GROUP BY marca, service_id, phone_nm, service_type, concepto, id_comisionista
HAVING COUNT(1) > 1
);



 CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('PENAF', mes_int, canales_pr , 'TEMP.pena' , 'ACTUALIZAR');



END