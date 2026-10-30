BEGIN

DECLARE mes_string, prefijo STRING;

DECLARE mes_periodo_facturado_inicio, mes_periodo_facturado_fin, mes_periodo_facturado_inicio_7m, mes_periodo_facturado_fin_7m DATE;

DECLARE id_mes_periodo_facturado_inicio, id_mes_periodo_facturado_fin, id_mes_periodo_facturado_inicio_7m, id_mes_periodo_facturado_fin_7m INT64;


SET prefijo = 'CBSR';

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
CALL `mm-commissions-reporting.COMISIONES.pr_cbsr`(202608, ['XSO','OSPNXSN']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_billing_status_heos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      id_factura

     ,CASE WHEN tipo_evento = "Impago" THEN 'REJECTED' ELSE 'PAID' END AS status

FROM `mm-commissions-reporting.COBROS.HEOS_IMPAGOS`
WHERE fecha IS NOT NULL
QUALIFY ROW_NUMBER () OVER (PARTITION BY id_factura ORDER BY fecha DESC) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      BILLING.invoice_id
     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS service_id
     ,BILLING.brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

     ,CASE WHEN COALESCE(BILLING_STATUS.status, 'PAID') NOT IN ('PAID', 'RECOLLECTED') THEN 1 ELSE 0 END AS unpaid

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cbsr_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE BILLING.data_month_id BETWEEN id_mes_periodo_facturado_inicio AND id_mes_periodo_facturado_fin
      AND BILLING.phone_nm IS NOT NULL
      AND BILLING.brand_ds IS NOT NULL

GROUP BY 1,2,3,4,5,6

UNION ALL

SELECT
      BILLING.invoice_id
     ,CAST(NULL AS STRING) AS phone_nm
     ,BILLING.service_id
     ,'PEPEPHONE' AS brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

     ,CASE WHEN COALESCE(BILLING_STATUS.status, 'PAID') NOT IN ('PAID', 'RECOLLECTED') THEN 1 ELSE 0 END AS unpaid

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cbsr_billing_status_heos` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.id_factura

WHERE BILLING.data_month_id BETWEEN id_mes_periodo_facturado_inicio AND id_mes_periodo_facturado_fin
      AND BILLING.service_id IS NOT NULL

GROUP BY 1,2,3,4,5,6
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_billing_7m`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      BILLING.invoice_id
     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS service_id
     ,BILLING.brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

     ,CASE WHEN COALESCE(BILLING_STATUS.status, 'PAID') NOT IN ('PAID', 'RECOLLECTED') THEN 1 ELSE 0 END AS unpaid

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cbsr_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE BILLING.data_month_id BETWEEN id_mes_periodo_facturado_inicio_7m AND id_mes_periodo_facturado_fin_7m
      AND BILLING.phone_nm IS NOT NULL
      AND BILLING.brand_ds IS NOT NULL

GROUP BY 1,2,3,4,5,6

UNION ALL

SELECT
      BILLING.invoice_id
     ,CAST(NULL AS STRING) AS phone_nm
     ,BILLING.service_id
     ,'PEPEPHONE' AS brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

     ,CASE WHEN COALESCE(BILLING_STATUS.status, 'PAID') NOT IN ('PAID', 'RECOLLECTED') THEN 1 ELSE 0 END AS unpaid

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cbsr_billing_status_heos` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.id_factura

WHERE BILLING.data_month_id BETWEEN id_mes_periodo_facturado_inicio_7m AND id_mes_periodo_facturado_fin_7m
      AND BILLING.service_id IS NOT NULL

GROUP BY 1,2,3,4,5,6
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_unpaid`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      UNPAID.*
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.activation_date

FROM (
     SELECT *
     FROM (
          SELECT phone_nm, service_id, brand_ds
          FROM `mm-commissions-reporting.TEMP.cbsr_billing`
          QUALIFY SUM(unpaid) OVER (PARTITION BY CASE WHEN brand_ds <> 'PEPEPHONE' THEN CAST(phone_nm AS STRING) ELSE service_id END, brand_ds) = 3
          )
     GROUP BY 1,2,3
     ) UNPAID

INNER JOIN (
           SELECT service_id, phone_nm, marca, service_type, activation_date
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE id_mes = id_mes_periodo_facturado_inicio
                 AND agrupacion_canal IN ('D2D', 'No Exclusivo') --- 202601 quitamos Exclusivo
                 AND concepto LIKE 'A%'
           GROUP BY 1,2,3,4,5
           ) TRANSACCIONES
          ON CASE WHEN UNPAID.brand_ds = 'PEPEPHONE' THEN UNPAID.service_id ELSE UNPAID.phone_nm END
             =
             CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
             AND UNPAID.brand_ds = TRANSACCIONES.marca


--- IMPAGOS CANAL EXCLUSIVO MR ANTIGUO -- 

UNION ALL 




SELECT
      UNPAID.*
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.activation_date

FROM (
     SELECT *
     FROM (
          SELECT phone_nm, service_id, brand_ds
          FROM `mm-commissions-reporting.TEMP.cbsr_billing`
          QUALIFY SUM(unpaid) OVER (PARTITION BY CASE WHEN brand_ds <> 'PEPEPHONE' THEN CAST(phone_nm AS STRING) ELSE service_id END, brand_ds) = 3
          )
     GROUP BY 1,2,3
     ) UNPAID

INNER JOIN (
           SELECT service_id, phone_nm, marca, service_type, activation_date
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE id_mes = id_mes_periodo_facturado_inicio
                 AND agrupacion_canal IN ('Exclusivo')
                 AND canal != 'ENK'
                 AND concepto LIKE 'A%'
           GROUP BY 1,2,3,4,5
           ) TRANSACCIONES
          ON CASE WHEN UNPAID.brand_ds = 'PEPEPHONE' THEN UNPAID.service_id ELSE UNPAID.phone_nm END
             =
             CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
             AND UNPAID.brand_ds = TRANSACCIONES.marca






--- IMPAGOS CANAL EXCLUSIVO CON MÍNIMO 1 MES IMPAGADO (NUEVO MR 202507) --           

UNION ALL 




SELECT
      UNPAID.*
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.activation_date

FROM (
     SELECT *
     FROM (
          SELECT phone_nm, service_id, brand_ds
          FROM `mm-commissions-reporting.TEMP.cbsr_billing_7m`
          QUALIFY SUM(unpaid) OVER (PARTITION BY CASE WHEN brand_ds <> 'PEPEPHONE' THEN CAST(phone_nm AS STRING) ELSE service_id END, brand_ds) >= 1
          )
     GROUP BY 1,2,3
     ) UNPAID

INNER JOIN (
           SELECT service_id, phone_nm, marca, service_type, activation_date
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE id_mes = id_mes_periodo_facturado_inicio_7m
                 AND agrupacion_canal IN ('Exclusivo')
                 AND canal = 'ENK'
                 AND activation_date >= '2025-07-01'
                 AND concepto LIKE 'A%'
               --   AND (concepto LIKE 'A%' OR SUBSTR(commission_id,1,5) IN ('AJSEM','TBEXC'))
           GROUP BY 1,2,3,4,5
          --  QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, marca ORDER BY CASE WHEN SUBSTR(commission_id,1,5) IN ('AJSEM','TBEXC') THEN 1 ELSE 2 END) = 1
           ) TRANSACCIONES
          ON CASE WHEN UNPAID.brand_ds = 'PEPEPHONE' THEN UNPAID.service_id ELSE UNPAID.phone_nm END
             =
             CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
             AND UNPAID.brand_ds = TRANSACCIONES.marca

)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_deactivation_date`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date, id_comisionista, comments)
     ,DEACTIVATIONS.deactivation_date
     ,DEACTIVATIONS.seller AS deactivation_seller

     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND TRANSACCIONES.id_comisionista IN ('BYMOVIL')    THEN TRANSACCIONES.seller
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND LENGTH(TRANSACCIONES.id_comisionista) IN (2, 3) THEN TRANSACCIONES.seller
          WHEN TRANSACCIONES.agrupacion_canal = 'Guuk' AND TRANSACCIONES.id_comisionista IN ('BYMOVIL')         THEN TRANSACCIONES.sfid_id
          ELSE TRANSACCIONES.id_comisionista
      END AS id_comisionista
     
     ,CASE WHEN UNPAID.brand_ds IS NOT NULL THEN 'Baja por impago' END AS comments
      
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

-- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` DEACTIVATIONS
LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` DEACTIVATIONS
         ON CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
            =
            CASE WHEN DEACTIVATIONS.brand_ds = 'PEPEPHONE' THEN DEACTIVATIONS.service_id ELSE DEACTIVATIONS.phone_nm END
            
            AND TRANSACCIONES.service_type = DEACTIVATIONS.service_type 
            AND TRANSACCIONES.marca = DEACTIVATIONS.brand_ds
            AND DEACTIVATIONS.activation_date IS NOT NULL
            AND TRANSACCIONES.activation_date <= DEACTIVATIONS.deactivation_date
          --   AND TRANSACCIONES.sale_date = DEACTIVATIONS.sale_date -- DESCOMENTAR CUANDO SE QUIERA HACER AJUSTE

LEFT JOIN `mm-commissions-reporting.TEMP.cbsr_unpaid` UNPAID
         ON CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
            =
            CASE WHEN UNPAID.brand_ds = 'PEPEPHONE' THEN UNPAID.service_id ELSE UNPAID.phone_nm END
            
            AND TRANSACCIONES.service_type = UNPAID.service_type 
            AND TRANSACCIONES.marca = UNPAID.brand_ds
            AND TRANSACCIONES.activation_date = UNPAID.activation_date

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE
                 WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('P', 'Q', 'R', 'S', 'Y', 'Z')
                 THEN SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
                 ELSE TRANSACCIONES.concepto
             END
             =
             CASE
                 WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('P', 'Q', 'R', 'S', 'Y', 'Z')
                 THEN SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto))
                 ELSE CONCEPTOS.concepto
             END
          AND TRANSACCIONES.tipo_concepto = CONCEPTOS.tipo_concepto
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE (
       (
       DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH) = COMISIONES.f_mes_int(mes_int)
       AND
       DEACTIVATIONS.deactivation_date <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,'1969-01-01'), INTERVAL 180 DAY)
       ) 
      OR
       UNPAID.brand_ds IS NOT NULL
      )
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.canal != 'PAR'
      AND TRANSACCIONES.estado != 'rechazado'
      AND CONCEPTOS.proceso_clawback = 'CBSR'
      AND NOT (
              TRANSACCIONES.canal = 'XS'
              AND TRANSACCIONES.marca = 'MASMOVIL'
              AND TRANSACCIONES.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
              AND TRANSACCIONES.campaign_code = 'Lineas adicionales OUT'
              AND TRANSACCIONES.deactivation_date >= '2023-10-01'
              )
          AND NOT (
                  TRANSACCIONES.canal = 'XS'
                  AND TRANSACCIONES.marca = 'YOIGO'
                  AND TRANSACCIONES.id_comisionista IN ('CAROUT007','KO')
                  AND TRANSACCIONES.campaign_code = 'Lineas adicionales OUT'
                  AND TRANSACCIONES.deactivation_date BETWEEN '2023-12-01' AND '2024-01-31'
                  )
          AND NOT (
                  TRANSACCIONES.canal = 'WA'
                  AND TRANSACCIONES.id_comisionista IN ('RONL004','RONL025', 'RONL050', 'MW','3W')
                  )
          AND NOT (
                  TRANSACCIONES.canal = 'OU'
                  AND TRANSACCIONES.id_comisionista IN ('TLVOU009', 'TLVOU022')
                  )
          AND NOT (
                  TRANSACCIONES.canal = 'DO'
                  AND TRANSACCIONES.id_comisionista IN ('DONL003', 'NE')
                  )
          AND NOT (
                  TRANSACCIONES.agrupacion_canal LIKE 'TLV - %'
                  AND TRANSACCIONES.marca = 'GUUK'
                  )
          ---- Cabeceras MM TLVN que se están descontando con un acuerdo de cobro ----
          AND NOT (
                  TRANSACCIONES.agrupacion_canal = 'TLV - Negocios'
                  AND TRANSACCIONES.activation_date BETWEEN '2023-02-01' AND '2023-10-31'
                  AND TRANSACCIONES.marca = 'MASMOVIL'
                  AND TRANSACCIONES.tariff_ds LIKE '%CONV'
                  AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago','D - Rappel')
                  AND TRANSACCIONES.bundle_type = 'FMC'
                  AND TRANSACCIONES.line_type_ds = 'MAIN'
                  AND TRANSACCIONES.service_type = 'MOBILE'
                  AND TRANSACCIONES.estado = 'facturado'
                  AND TRANSACCIONES.nombre_comercio NOT IN ('ABAI','ABAI BUSINESS SOLUTIONS, S.TRANSACCIONES.U', 'B12', 'PHONE GROUP', 'BEE CALLING SOLUTIONS')
                  )
      AND NOT (
              TRANSACCIONES.agrupacion_canal = 'Exclusivo'
              AND SUBSTR(TRANSACCIONES.concepto,1,4) IN ('F - ','Y - ')
              )

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.sale_date = DEACTIVATIONS.sale_date THEN 1 ELSE 2 END ASC,
                                   CASE WHEN TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.deactivation_date ASC
                          ) = 1
)


UNION ALL

--CLAWBACK PARLEM


SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date,id_comisionista, comments)
     ,DEACTIVATIONS.deactivation_date
     ,TRANSACCIONES.seller AS deactivation_seller
     ,TRANSACCIONES.id_comisionista AS id_comisionista
     ,CAST(NULL AS STRING) AS comments
      
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.clawback_parlem_deactivations` DEACTIVATIONS
         ON 
            CASE
              WHEN TRANSACCIONES.canal = 'PAR'
                   THEN CONCAT(TRANSACCIONES.activation_date,'-',TRANSACCIONES.phone_nm)
              ELSE NULL
            END
            =
            CASE
              WHEN DEACTIVATIONS.brand_ds = 'PARLEM'
                   THEN CONCAT(DEACTIVATIONS.activation_date,'-',DEACTIVATIONS.phone_nm)
              ELSE NULL
            END

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE
                 WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('P', 'Q', 'R', 'S', 'Y', 'Z')
                 THEN SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
                 ELSE TRANSACCIONES.concepto
             END
             =
             CASE
                 WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('P', 'Q', 'R', 'S', 'Y', 'Z')
                 THEN SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto))
                 ELSE CONCEPTOS.concepto
             END

CROSS JOIN UNNEST(canales_pr) canal_pr


WHERE 1=1

      AND (
        (
            DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH)
            = PARSE_DATE('%Y%m', mes_string)
          

      AND DEACTIVATIONS.deactivation_date <= DATE_ADD(
            COALESCE(TRANSACCIONES.activation_date,'1969-01-01'),
            INTERVAL 365 DAY)
          )
        )

      AND TRANSACCIONES.canal = canal_pr

      AND TRANSACCIONES.canal = 'PAR'

      AND TRANSACCIONES.estado != 'rechazado'

      AND CONCEPTOS.proceso_clawback = 'CBSR'

QUALIFY ROW_NUMBER() OVER (
            PARTITION BY TRANSACCIONES.commission_id
            ORDER BY
                CASE
                    WHEN TRANSACCIONES.sale_date = DEACTIVATIONS.sale_date
                    THEN 1
                    ELSE 2
                END ASC,

                CASE
                    WHEN TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date
                    THEN 1
                    ELSE 2
                END ASC,

                DEACTIVATIONS.deactivation_date ASC
        ) = 1

;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE 
          WHEN TRANSACCIONES.canal = 'PAR' THEN 'E - '
          WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - Clawback ' 
          ELSE 'E - Clawback ' 
     END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     --,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - Clawback ' ELSE 'E - Clawback ' END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     ,CASE
          WHEN SUBSTR(TRANSACCIONES.concepto,5,LENGTH(TRANSACCIONES.concepto)) IN ('Dispositivo Captacion','Extracomision terminal') AND TRANSACCIONES.tipo_concepto = 'CURE' THEN 'UPFR'
          ELSE TRANSACCIONES.tipo_concepto
      END AS tipo_concepto
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
     ,TRANSACCIONES.deactivation_seller
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
     ,COUNT(DISTINCT TRANSACCIONES.commission_id) AS commission_id_count
     
FROM `mm-commissions-reporting.TEMP.cbsr_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr_dealer`
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
     ,CASE
          WHEN TRANSACCIONES.canal = 'PAR' THEN -1
          ELSE 1
     END AS unidades

     ,CASE
          WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
          ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
      END AS canal

     ,CASE 
          WHEN DEALER.canal IN ('D2D','D2N','DEM') 
            AND TRANSACCIONES.activation_date >= '2026-07-01' AND DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) <= 90 
                then -1.00 * TRANSACCIONES.comision
          WHEN DEALER.canal IN ('D2D','D2N','DEM') 
            AND TRANSACCIONES.activation_date >= '2026-07-01' AND DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) <= 120 
                then -0.90 * TRANSACCIONES.comision
          WHEN DEALER.canal IN ('D2D','D2N','DEM') 
            AND TRANSACCIONES.activation_date >= '2026-07-01' AND DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) <= 150 
                then -0.80 * TRANSACCIONES.comision
          WHEN DEALER.canal IN ('D2D','D2N','DEM') 
            AND TRANSACCIONES.activation_date >= '2026-07-01' AND DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) <= 180 
                then -0.70 * TRANSACCIONES.comision
          WHEN DEALER.canal IN ('D2D','D2N','DEM') 
            AND TRANSACCIONES.activation_date >= '2026-07-01' AND DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) <= 270 
                then -0.60 * TRANSACCIONES.comision
          WHEN DEALER.canal IN ('D2D','D2N','DEM') 
            AND TRANSACCIONES.activation_date >= '2026-07-01' AND DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) <= 365 
                then -0.50 * TRANSACCIONES.comision
      ELSE
     `mm-commissions-reporting.COMISIONES.f_comision_clawback` (
        CASE
            WHEN comments IS NOT NULL THEN 60
            ELSE DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) + 1
        END
       ,CASE
            WHEN TRANSACCIONES.canal IN ('GU0008', 'GU0009', 'GU0011','GUD2D', 'GUUK', 'GUUKG', 'GUUK14') THEN TRANSACCIONES.canal
            ELSE COALESCE(DEALER.canal, TRANSACCIONES.canal)
        END
       ,TRANSACCIONES.tariff_ds
      )
      * TRANSACCIONES.comision 
      END AS comision
     
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
                         ,TRANSACCIONES.deactivation_seller
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
                         ,TRANSACCIONES.deactivation_seller
                         ,TRANSACCIONES.service_type
                         )
                        )
      END AS campaign_code
              
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.cbsr_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsr`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CBSR.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.cbsr_dealer` CBSR

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.cbsr_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) ACTI
          LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
                   ON REPLACE(ACTI, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CBSR.commission_id = DEALER_DETAIL.commission_id

WHERE comision < 0
      OR (
         CBSR.concepto IN ('E - Clawback Extracomision Objetivo fijo', 
                           'E - Clawback Extracomision Objetivo Movil Pospago', 
                           'E - Clawback Portabilidad Fijo',
                           'E - Clawback Portabilidad Movil Pospago'
                          )
         AND CBSR.comision > 0
         AND commission_id_count = 1
         )
)
;

---- CORRECTIVO PARA EVITAR DUPLICIDADES DE CLAWBACK ----
DELETE FROM `mm-commissions-reporting.TEMP.cbsr` CBSR
WHERE CBSR.id_mes = mes_int
  AND EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.COMISIONES.transacciones` A
        WHERE A.service_id = CBSR.service_id
          AND A.concepto = CBSR.concepto
          AND A.id_mes < mes_int
    )
;
--- ELIMINAR CLAWBACKS ANTERIORES A MIGRACIONES DE THADEA A POWERCOM
DELETE FROM `mm-commissions-reporting.TEMP.cbsr` CBSR
WHERE 
     -- TLV - DO Migrado en Marzo26 --
     (
     CANAL IN ('DO','DOT') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-03-01'
     )
     OR
     -- TLV - Cross-sell + TLV - Web Capta Migrado en Mayo --
     (
     CANAL IN ('WA','BO','XI','XIBO') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-05-01'
     )
     OR
     -- TLV - Negocios INB Migrado en Junio26 --
     (
     CANAL IN ('OSPNIN') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-06-01'
     )
     OR
     -- TLV - Cross-sell OUT + TLV - NEGOCIOS XSELL OUT Migrado en Agosto26 --
     (
     CANAL IN ('OSPNXSN','XSO') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-08-01'
     )
     OR
     -- Alternativo Migrado en Febrero26 --
     (
     CANAL IN ('ALTN') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-02-01'
     )
     OR
     -- NATIONAL RETAIL FNAC --
     (
     CANAL IN ('FNAC_NR') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-09-01'
     )
    
;
-- REVISAR DUPLICIDAD por esta combinación de campos por compartir la misma fecha de desactivacion (CAMBIOS DE DOMICILIO y CAMBIOS DE TECNOLOGIA)

---D2D: EVITAR CLACKBACKS POR ENCIMA DE LA PENALIZACIÓN DE DOCUMENTACIÓN-----

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.phone_nm_clawback_docu_d2d` AS(

  WITH phone_nm_clawback AS(
    SELECT phone_nm
    FROM `mm-commissions-reporting.TEMP.cbsr`
    WHERE concepto = 'E - Clawback Documentacion Entregada' and agrupacion_canal = 'D2D'
  )

  SELECT trans.phone_nm, SUM(trans.comision) AS suma_conceptos_docu
  
  FROM phone_nm_clawback 
  LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` trans
    ON phone_nm_clawback.phone_nm = trans.phone_nm
  WHERE trans.agrupacion_canal = 'D2D' AND trans.concepto IN ('D - Documentacion Entregada', 'P - Documentacion Auditada')
  GROUP BY phone_nm
  HAVING SUM(comision)=0
  ORDER BY 2 DESC
);

DELETE FROM `mm-commissions-reporting.TEMP.cbsr`
WHERE phone_nm IN (
  SELECT DISTINCT(phone_nm)
  FROM `mm-commissions-reporting.TEMP.phone_nm_clawback_docu_d2d`)
;




END IF;



/*
ASSERT NOT EXISTS
(
SELECT service_id
FROM `mm-commissions-reporting.TEMP.cbsr`
GROUP BY marca, service_id, phone_nm, service_type, concepto
HAVING COUNT(1) > 1
);
*/ 

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CBSR', mes_int, canales_pr , 'TEMP.cbsr' , 'ACTUALIZAR');



END