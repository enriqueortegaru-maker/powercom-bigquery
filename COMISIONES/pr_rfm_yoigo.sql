BEGIN


--CALL `mm-commissions-reporting.COMISIONES.pr_rfm_yoigo`();


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rfm_yoigo_ventas_base_net_qvantel`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT * 
FROM `mm-dwh-prod.80_RFM_QVANTEL.ventas_base_net_qvantel_*`
QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY customer_id, service_id, service_type, order_id
                          ORDER BY CAST(_table_suffix AS INT64) ASC
                          ) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rfm_yoigo_migration_completed`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT
      origin_customer_id
     ,origin_service_id
     ,customer_id
     ,service_id
     ,service_type
     
     ,CASE
          WHEN service_type = 'INTERNET' AND phone_nm IS NULL
          THEN LAG(phone_nm) OVER (PARTITION BY origin_customer_id, origin_service_id, customer_id ORDER BY service_type, service_id)

          ELSE phone_nm
      END AS phone_nm

FROM (
     SELECT
           origin_customer_id
          ,origin_service_id
          ,customer_id
          ,MAX(service_id) AS service_id
          ,REPLACE(REPLACE(REPLACE(service_type, 'Landline', 'FIX'), 'Broadband', 'INTERNET'), 'Mobile', 'MOBILE') AS service_type
          ,phone_nm
     FROM `mm-datamart-kd.RFM_YOIGO.migration_completed`
     WHERE service_type NOT IN ('DataSharing', 'TV', 'SECURITY')
     GROUP BY 1,2,3,5,6
     )
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.rfm_yoigo` AS

SELECT
      VENTAS.*
     ,MIGRATION.customer_id AS mysim_customer_id
     ,MIGRATION.service_id AS mysim_service_id
     ,MIGRATION.service_type AS mysim_service_type

FROM `mm-commissions-reporting.TEMP.rfm_yoigo_ventas_base_net_qvantel` VENTAS

INNER JOIN `mm-commissions-reporting.TEMP.rfm_yoigo_migration_completed` MIGRATION
         ON CAST(VENTAS.customer_id AS STRING) = MIGRATION.origin_customer_id
            AND CAST(VENTAS.service_id AS STRING) = MIGRATION.origin_service_id
            AND VENTAS.phone_nm = MIGRATION.phone_nm
;


END