BEGIN


DECLARE sql, prefijo, mes_string STRING;
DECLARE mes_periodo_facturado DATE;
DECLARE id_mes_periodo_facturado INT64;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CALD';

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 month );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);

SET canales_pr = COALESCE(canales_pr, ['MP','MR','MI','CA','EML','PH']);


/*
CALL COMISIONES.pr_cald (202404,['MP','MR','MI','CA','EML','PH']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_status_heos`
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


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
group by 1,2,3,4
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_6_meses`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)) AS mes_facturado
     ,COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,'QVANTEL' AS data_source_ds
     ,'YOIGO' AS marca
     
     ,CASE
          WHEN BILLING.bill_id LIKE '%CONVDISC%'    THEN 'INTERNET'
          WHEN BILLING.bill_id LIKE 'FH%DISC%'      THEN 'INTERNET'
          WHEN BILLING.service_type = 'FIX'         THEN 'INTERNET'
          ELSE 'MOBILE'
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,VENTAS.technology_ds
     ,VENTAS.billing_type_ds
     ,VENTAS.sale_date
     ,VENTAS.activation_date AS activation_date
     ,VENTAS.deactivation_date AS deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
     ,VENTAS.cod_segmento
     ,VENTAS.cod_marca
     ,VENTAS.cod_tipo_contrato
     ,VENTAS.cod_producto
     ,VENTAS.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
           WHERE brand_ds = 'YOIGO'
                 AND activation_date IS NOT NULL
                 AND COALESCE(deactivation_date, '2100-01-01') >= DATE_SUB(mes_periodo_facturado, INTERVAL 4 MONTH)
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

WHERE BILLING.data_month_id BETWEEN CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -7 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                                AND CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY mes_facturado, phone_nm
                          ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                          CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                          CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                          CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                          CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC
                          ) = 1

UNION ALL

SELECT
      PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)) AS mes_facturado
     ,COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,'MYSIM' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,VENTAS.technology_ds
     ,VENTAS.billing_type_ds
     ,VENTAS.sale_date
     ,VENTAS.activation_date AS activation_date
     ,VENTAS.deactivation_date AS deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
     ,VENTAS.cod_segmento
     ,VENTAS.cod_marca
     ,VENTAS.cod_tipo_contrato
     ,VENTAS.cod_producto
     ,VENTAS.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
           WHERE activation_date IS NOT NULL
                 AND COALESCE(deactivation_date, '2100-01-01') >= DATE_SUB(mes_periodo_facturado, INTERVAL 4 MONTH)
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

WHERE BILLING.data_month_id BETWEEN CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -7 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                                AND CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY mes_facturado, phone_nm
                          ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                          CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                          CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                          CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                          CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC
                          ) = 1

UNION ALL

SELECT
      PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)) AS mes_facturado
     ,COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,'HEOS' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,VENTAS.technology_ds
     ,VENTAS.billing_type_ds
     ,VENTAS.sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
     ,VENTAS.cod_segmento
     ,VENTAS.cod_marca
     ,VENTAS.cod_tipo_contrato
     ,VENTAS.cod_producto
     ,VENTAS.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
           WHERE data_source_ds = 'HEOS'
                 AND activation_date IS NOT NULL
                 AND COALESCE(deactivation_date, '2100-01-01') >= DATE_SUB(mes_periodo_facturado, INTERVAL 4 MONTH)
           ) VENTAS
          ON BILLING.service_id = VENTAS.service_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.id_factura

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

WHERE BILLING.data_month_id BETWEEN CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -7 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                                AND CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY mes_facturado, service_id
                          ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                          CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                          CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                          CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                          CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_12_24_36_48_meses`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)) AS mes_facturado
     ,COALESCE(TRANSACCIONES.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.seller
     ,'QVANTEL' AS data_source_ds
     ,'YOIGO' AS marca
     
     ,CASE
          WHEN BILLING.bill_id LIKE '%CONVDISC%'    THEN 'INTERNET'
          WHEN BILLING.bill_id LIKE 'FH%DISC%'      THEN 'INTERNET'
          WHEN BILLING.service_type = 'FIX'         THEN 'INTERNET'
          ELSE 'MOBILE'
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT phone_nm, line_type_ds, bundle_type, technology_ds, billing_type_ds, sale_date, activation_date, deactivation_date, order_id, order_type_agg, cod_segmento, cod_marca, cod_tipo_contrato, cod_producto, cod_canal
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE marca = 'YOIGO'
                 AND concepto IN ('C - Calidad 12 meses', 'C - Calidad 24 meses', 'C - Calidad 36 meses', 'C - Calidad 48 meses')
           GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
           ) TRANSACCIONES
          ON CAST(BILLING.phone_nm AS STRING) = TRANSACCIONES.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON TRANSACCIONES.seller = AC.seller AND TRANSACCIONES.agrupacion_canal IS NULL

WHERE BILLING.data_month_id BETWEEN CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -8 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                                AND CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -49 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28

UNION ALL

SELECT
      PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)) AS mes_facturado
     ,COALESCE(TRANSACCIONES.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.seller
     ,'MYSIM' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date AS activation_date
     ,TRANSACCIONES.deactivation_date AS deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT phone_nm, line_type_ds, bundle_type, technology_ds, billing_type_ds, sale_date, activation_date, deactivation_date, order_id, order_type_agg, cod_segmento, cod_marca, cod_tipo_contrato, cod_producto, cod_canal
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE concepto IN ('C - Calidad 12 meses', 'C - Calidad 24 meses', 'C - Calidad 36 meses', 'C - Calidad 48 meses')
           GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
           ) TRANSACCIONES
          ON CAST(BILLING.phone_nm AS STRING) = TRANSACCIONES.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON TRANSACCIONES.seller = AC.seller AND TRANSACCIONES.agrupacion_canal IS NULL

WHERE BILLING.data_month_id BETWEEN CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -8 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                                AND CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -49 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28

UNION ALL

SELECT
      PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)) AS mes_facturado
     ,COALESCE(TRANSACCIONES.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.seller
     ,'HEOS' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

INNER JOIN (
           SELECT phone_nm, line_type_ds, bundle_type, technology_ds, billing_type_ds, sale_date, activation_date, deactivation_date, order_id, order_type_agg, cod_segmento, cod_marca, cod_tipo_contrato, cod_producto, cod_canal
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE marca = 'PEPEPHONE'
                 AND concepto IN ('C - Calidad 12 meses', 'C - Calidad 24 meses', 'C - Calidad 36 meses', 'C - Calidad 48 meses')
           GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
           ) TRANSACCIONES
          ON CAST(BILLING.phone_nm AS STRING) = TRANSACCIONES.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.id_factura

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON TRANSACCIONES.seller = AC.seller AND TRANSACCIONES.agrupacion_canal IS NULL

WHERE BILLING.data_month_id BETWEEN CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -8 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                                AND CAST(SUBSTR(REPLACE(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL -49 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28
)
;

/*
create or replace table `mm-commissions-reporting.TEMP.cald_facturacion` as
select marca, service_id, service_type, 'C - Calidad 6 meses' as concepto , sum(importe_facturado)/6 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -6 month)
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 12 meses' as concepto , sum(importe_facturado)/12 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -12 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 24 meses' as concepto , sum(importe_facturado)/24 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -24 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 36 meses' as concepto , sum(importe_facturado)/36 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -36 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
group by 1,2,3
union all
select marca, service_id, service_type, 'C - Calidad 48 meses' as concepto , sum(importe_facturado)/48 as importe_medio
from `mm-commissions-reporting.COMISIONES.facturacion_linea_mes` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status_heos` BILLING_STATUS_HEOS
         ON BILLING.invoice_id = BILLING_STATUS_HEOS.id_factura

WHERE COALESCE(BILLING_STATUS.status, BILLING_STATUS_HEOS.status, 'PAID') IN ('PAID', 'RECOLLECTED')
      AND mes_facturado between date_add (COMISIONES.f_mes_int (mes_int), interval -48 month) 
      and                       date_add (COMISIONES.f_mes_int (mes_int ),interval -1 month)
group by 1,2,3
;

create or replace table `mm-commissions-reporting.TEMP.cald_base` as
select
--- primary key ---
prefijo||'_'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
'calculado' as estado,
canal.agrupacion_canal,

--- comision ---
mes_int id_mes,
B.canal,
--- vendedor ---
id_comisionista,
distribuidor,
a.sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
zona_fiscal,
--- servicio ---
a.marca,
a.service_type,
phone_nm,
a.tariff_id,
a.tariff_ds,
a.service_id,
account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
deactivation_date,
order_id,
order_type_agg,
--- variables analiticas ---
cod_segmento,
cod_marca,
a.cod_tipo_contrato,
a.cod_producto,
canal.cod_canal,
--- informacion adicional ---
cast ( null as string ) campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast ( null as string ) claim_code,
cast ( null as string ) process_code,
cast ( null as string ) comments,
--- informacion contabilizacion ---
'C_MANUAL' as facturador,
date_diff (COMISIONES.f_mes_int (mes_int), date_trunc(activation_date, month), month) as delta_meses,
from `mm-commissions-reporting.COMISIONES.v_ventas_base_calidad` a
inner join `mm-commissions-reporting.COMISIONES.v_dealer` b on
     ( a.sfid_id = b.sfid_id 
  or (a.seller_formato_tms = b.sfid_id)
  or a.seller = b.sfid_id
  or a.sfid_id    || '-' || a.seller = replace ( b.sfid_id , ' ', '') )
  and b.id_mes = mes_int
  and b.comisiona
inner join `mm-commissions-reporting.GS.CANALES` canal on canal.canal = b.canal
cross join unnest(canales_pr) canpr 
where 1=1
and comisionamiento = 'Comisiona'
and coalesce ( deactivation_date , '2099-01-01') >= date_add ( COMISIONES.f_mes_int (mes_int) , interval 1 month)
and date_diff (COMISIONES.f_mes_int (mes_int), date_trunc(activation_date, month), month) in (6,12,24,36,48)
and b.canal = canpr
and not (a.marca in ('YOIGO') and b.canal = 'PH')
--and not (a.marca in ('PEPEPHONE') and b.agrupacion_canal = 'Exclusivo')
and a.order_type_agg in ('ALTA NUEVA', 'PORTABILIDAD', 'STC')
AND (a.seller NOT LIKE 'MLV%' OR a.seller NOT LIKE '%RPORT' OR a.seller NOT LIKE '%RBAJA')
qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by case when id_comisionista = seller then 1 else 0 end desc, length(b.id_comisionista) desc nulls last, comisiona desc ) = 1
;

create or replace table `mm-commissions-reporting.TEMP.cald` as
with
calculos as
(
  select a.*,
  c.concepto,
  c.tipo_concepto,
  1 as unidades,
  case
  when canal in ('MI','CA','NR','MR','MP','PH')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 6 meses','C - Calidad 12 meses')
      then case when t.importe_medio >= 18 then 10 when t.importe_medio >= 14 then 8 else 5 end
  when canal in ('MI','CA','NR','MR','MP')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 24 meses')
      then case when t.importe_medio >= 18 then 20 when t.importe_medio >= 14 then 16 else 10 end
  when canal in ('EML')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 6 meses','C - Calidad 12 meses')
      then case when t.importe_medio >= 25 then 8 when t.importe_medio >= 16 then 6 when t.importe_medio >= 8 then 3 else 0 end
  when canal in ('EML')
      and a.service_type = 'MOBILE' 
      and c.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 48 meses')
      then case when t.importe_medio >= 25 then 12 when t.importe_medio >= 16 then 10 when t.importe_medio >= 8 then 6 else 0 end   
  end as comision
from `mm-commissions-reporting.TEMP.cald_base` a
inner join `mm-commissions-reporting.TEMP.cald_facturacion` as t on a.marca=t.marca and a.service_type=t.service_type and a.service_id=t.service_id
inner join `mm-commissions-reporting.GS.CONCEPTOS` c on t.concepto = c.concepto
where case delta_meses
  when 6 then 'C - Calidad 6 meses'
  when 12 then 'C - Calidad 12 meses'
  when 24 then 'C - Calidad 24 meses'
  when 36 then 'C - Calidad 36 meses'
  when 48 then 'C - Calidad 48 meses'
end = c.concepto
and t.importe_medio > 1
) 
select *
from calculos
where comision > 0
-- quito la calidad para todos los mediamark que no le corresponde
and cif  not in('A62348107',
'A63907463',
'A63907356',
'A62581988',
'A63905772',
'A63524656',
'A82037292',
'A65281988'
)

;

--- Insertar tabla final ----

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CALD_', mes_int, canales_pr , 'TEMP.cald' , 'ACTUALIZAR');*/

end