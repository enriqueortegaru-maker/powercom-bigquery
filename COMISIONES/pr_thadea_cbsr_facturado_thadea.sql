BEGIN

DECLARE mes_string, prefijo STRING;

DECLARE mes_periodo_facturado_inicio, mes_periodo_facturado_fin, mes_periodo_facturado_inicio_7m, mes_periodo_facturado_fin_7m DATE;

DECLARE id_mes_periodo_facturado_inicio, id_mes_periodo_facturado_fin, id_mes_periodo_facturado_inicio_7m, id_mes_periodo_facturado_fin_7m INT64;


SET prefijo = 'THCBSR';

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES` WHERE plantilla_activaciones IS NOT NULL));

SET mes_string = CAST(mes_int AS STRING);

SET mes_periodo_facturado_inicio = DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL  - 3 MONTH );

SET mes_periodo_facturado_fin = DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL  - 1 MONTH );

SET mes_periodo_facturado_inicio_7m = DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL  - 6 MONTH );

SET mes_periodo_facturado_fin_7m = DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL  - 4 MONTH );

SET id_mes_periodo_facturado_inicio = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_inicio) AS INT64);

SET id_mes_periodo_facturado_fin = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_fin) AS INT64);

SET id_mes_periodo_facturado_inicio_7m = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_inicio_7m) AS INT64);

SET id_mes_periodo_facturado_fin_7m = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_fin_7m) AS INT64);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_thadea_cbsr_facturado_thadea`(202609, ['MKT_NR']);
*/


call `mm-commissions-reporting.COMISIONES.pr_dealer_ultima_version`(mes_int) ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_deactivation_date`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
WITH TRANSACCIONES_FILTRADAS AS (
    SELECT TRANSACCIONES.*
    FROM `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado` TRANSACCIONES

    LEFT JOIN  `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
     ON (
          ( DEALER.canal IN ('ENDE', 'FNAC_NR','MKT_NR') AND TRANSACCIONES.id_comisionista = DEALER.id_comisionista ) 
          OR 
          ( DEALER.canal NOT IN ('ENDE', 'FNAC_NR','MKT_NR') AND TRANSACCIONES.sfid_id = DEALER.id_comisionista )
     )

    CROSS JOIN UNNEST(canales_pr) canal_pr

    WHERE concepto IN (
        'C_PLAN_DE_PRECIOS',
        'C_RAPPEL',
        'C_EXTRACOMISION_PORTABILIDAD',
        'C_ALTA'
    )
      AND comision > 0
      AND TRANSACCIONES.id_mes > 202601
      AND DEALER.canal = canal_pr
)
     
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date, id_comisionista, comments)
     ,DEACTIVATIONS.deactivation_date
     ,DEACTIVATIONS.seller AS deactivation_seller

     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND TRANSACCIONES.id_comisionista IN ('BYMOVIL')    THEN CAST(TRANSACCIONES.seller AS STRING)
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND LENGTH(TRANSACCIONES.id_comisionista) IN (2, 3) THEN CAST(TRANSACCIONES.seller AS STRING)
          WHEN TRANSACCIONES.agrupacion_canal = 'Guuk' AND TRANSACCIONES.id_comisionista IN ('BYMOVIL')         THEN TRANSACCIONES.sfid_id
          ELSE TRANSACCIONES.id_comisionista
      END AS id_comisionista
     
     ,'CLAWBACKS THADEA' AS comments
      

-- FROM `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado` TRANSACCIONES

FROM TRANSACCIONES_FILTRADAS TRANSACCIONES

LEFT JOIN  `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
ON (
     ( DEALER.canal IN ('ENDE', 'FNAC_NR','MKT_NR') AND TRANSACCIONES.id_comisionista = DEALER.id_comisionista ) 
     OR 
     ( DEALER.canal NOT IN ('ENDE', 'FNAC_NR','MKT_NR') AND TRANSACCIONES.sfid_id = DEALER.id_comisionista )
   )

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` DEACTIVATIONS
         ON  CAST(TRANSACCIONES.phone_nm AS STRING) = DEACTIVATIONS.phone_nm 
            AND CAST(TRANSACCIONES.service_type AS STRING) = DEACTIVATIONS.service_type 
            AND CAST(TRANSACCIONES.marca AS STRING) = DEACTIVATIONS.brand_ds
            AND DEACTIVATIONS.service_id = TRANSACCIONES.service_id
            AND DEACTIVATIONS.activation_date IS NOT NULL
            AND TRANSACCIONES.activation_date <= DEACTIVATIONS.deactivation_date
          --   AND TRANSACCIONES.sale_date = DEACTIVATIONS.sale_date -- DESCOMENTAR CUANDO SE QUIERA HACER AJUSTE




CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE (
       (
       DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH) = COMISIONES.f_mes_int(mes_int)
       AND
       DEACTIVATIONS.deactivation_date <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,'1969-01-01'), INTERVAL 180 DAY)
       ) 

      )
      AND DEALER.canal = canal_pr
     --  AND CONCEPTOS.proceso_clawback = 'CBSR'
     AND TRANSACCIONES.concepto IN ('C_PLAN_DE_PRECIOS','C_RAPPEL','C_EXTRACOMISION_PORTABILIDAD','C_ALTA')
     AND TRANSACCIONES.comision > 0
     AND TRANSACCIONES.id_mes > 202601
    

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.sale_date = DEACTIVATIONS.sale_date THEN 1 ELSE 2 END ASC,
                                   CASE WHEN TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.deactivation_date ASC
                          ) = 1
)



;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE
          WHEN TRANSACCIONES.service_type = 'MOBILE' AND TRANSACCIONES.billing_type_ds = 'POSTPAGO' AND TRANSACCIONES.CONCEPTO = 'C_PLAN_DE_PRECIOS' THEN 'E - Clawback Servicio Movil Pospago' 
          WHEN TRANSACCIONES.service_type = 'MOBILE' AND TRANSACCIONES.billing_type_ds = 'PREPAGO'  AND TRANSACCIONES.CONCEPTO = 'C_PLAN_DE_PRECIOS' THEN 'E - Clawback Servicio Movil Prepago'
          WHEN TRANSACCIONES.service_type = 'INTERNET'                                              AND TRANSACCIONES.CONCEPTO = 'C_PLAN_DE_PRECIOS' THEN 'E - Clawback Servicio Fijo'

          WHEN TRANSACCIONES.service_type = 'MOBILE' AND TRANSACCIONES.billing_type_ds = 'POSTPAGO' AND TRANSACCIONES.CONCEPTO = 'C_EXTRACOMISION_PORTABILIDAD' THEN 'E - Clawback Portabilidad Movil Pospago' 
          WHEN TRANSACCIONES.service_type = 'MOBILE' AND TRANSACCIONES.billing_type_ds = 'PREPAGO'  AND TRANSACCIONES.CONCEPTO = 'C_EXTRACOMISION_PORTABILIDAD' THEN 'E - Clawback Portabilidad Movil Prepago'
          WHEN TRANSACCIONES.service_type = 'INTERNET'                                              AND TRANSACCIONES.CONCEPTO = 'C_EXTRACOMISION_PORTABILIDAD' THEN 'E - Clawback Portabilidad Fijo'

          WHEN TRANSACCIONES.CONCEPTO = 'C_RAPPEL' THEN 'E - Clawback Rappel'
          WHEN TRANSACCIONES.CONCEPTO = 'C_ALTA' AND CANAL='MKT_NR' THEN 'E - Clawback Alta SIM'
          ELSE NULL

          END AS concepto
     ,'UPFR' AS tipo_concepto
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.sfid_id
     ,CAST(TRANSACCIONES.marca AS STRING) as marca
     ,CAST(TRANSACCIONES.service_type AS STRING) as service_type
     ,CAST(TRANSACCIONES.phone_nm AS STRING) as phone_nm
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
     ,TRANSACCIONES.deactivation_seller
     ,MAX(TRANSACCIONES.bundle_type) AS bundle_type
     ,MAX(TRANSACCIONES.campaign_code) AS campaign_code
     ,MAX(TRANSACCIONES.line_type_ds) AS line_type_ds
     ,MAX(TRANSACCIONES.order_id) AS order_id
     ,MAX(TRANSACCIONES.order_type_agg) AS order_type_agg
     ,MAX(TRANSACCIONES.serial_number) AS serial_number
     ,MAX(TRANSACCIONES.tariff_ds) AS tariff_ds
     ,MAX(CAST(TRANSACCIONES.tariff_id AS STRING)) AS tariff_id
     ,MAX(TRANSACCIONES.tax_base) AS tax_base
     ,MAX(TRANSACCIONES.technology_ds) AS technology_ds
     ,MAX(TRANSACCIONES.comments) AS comments
     ,SUM(TRANSACCIONES.comision) AS comision
     ,ARRAY_AGG(TRANSACCIONES.commission_id) AS commission_id
     ,COUNT(DISTINCT TRANSACCIONES.commission_id) AS commission_id_count
     
FROM `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_dealer`
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
     
     ,prefijo || '_' || mes_int || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int (mes_int) AS mes_liquidado
     ,mes_int as id_mes
     ,CASE
          WHEN TRANSACCIONES.canal = 'PAR' THEN -1
          ELSE 1
     END AS unidades

     ,CASE
          WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
          ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
      END AS canal

     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback` (
        DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) + 1
       ,CASE
            WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
            ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
        END
       ,'1'
      )
      * TRANSACCIONES.comision AS comision
     
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

     ,CAST (NULL AS STRING) AS campaign_code

              
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON (
     ( DEALER.canal IN ('ENDE', 'FNAC_NR','MKT_NR') AND TRANSACCIONES.id_comisionista = DEALER.id_comisionista ) 
     OR 
     ( DEALER.canal NOT IN ('ENDE', 'FNAC_NR','MKT_NR') AND TRANSACCIONES.sfid_id = DEALER.id_comisionista )
   )

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
         ON DEALER.id_comisionista = TLV_CAMP.id_comisionista 
         AND DEALER.sfid_id = TLV_CAMP.SFID_ID 
         AND DEALER.canal = TLV_CAMP.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CBSR.* except (sfid_id)
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_dealer` CBSR

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, CAST(TRANSACCIONES.seller AS STRING) AS seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) ACTI

          LEFT JOIN `mm-commissions-reporting.PUBLICADO.comisiones_multimarca_facturado` TRANSACCIONES
                   ON REPLACE(ACTI, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CBSR.commission_id = DEALER_DETAIL.commission_id

WHERE comision < 0
      OR (
         CBSR.concepto IN ('E - Clawback Extracomision Objetivo fijo', 'E - Clawback Extracomision Objetivo Movil Pospago')
         AND CBSR.comision > 0
         AND commission_id_count = 1
         )
)
;
DELETE FROM `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea` CBSR
WHERE 
     -- NATIONAL RETAIL FNAC --
     (
     CANAL IN ('FNAC_NR') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date > '2026-09-01'
     )
    OR
     (
     CANAL IN ('ENDE') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date > '2026-09-01'
     )
     OR
     (
     CANAL IN ('MKT_NR') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date > '2026-09-01'
     )

     ---TLV - Outbound
     OR
     (
     CANAL IN ('OUOV','OUOC') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date > '2026-09-01'
     )
    
;

DELETE FROM `mm-commissions-reporting.TEMP.thadea_cbsr_facturado_thadea` 
WHERE CONCEPTO IS NULL OR COMISION IS NULL

;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('THCBSR', mes_int, canales_pr , 'TEMP.thadea_cbsr_facturado_thadea' , 'ACTUALIZAR');

END