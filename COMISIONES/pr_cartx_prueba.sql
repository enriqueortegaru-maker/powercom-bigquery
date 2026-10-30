BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado, mes_periodo_facturado_inicio_7m, mes_periodo_facturado_fin_7m DATE;
DECLARE id_mes_periodo_facturado, id_mes_periodo_facturado_inicio_7m, id_mes_periodo_facturado_fin_7m INT64;


SET prefijo = 'CARTX';

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET mes_periodo_facturado_inicio_7m = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 6 MONTH );

SET mes_periodo_facturado_fin_7m = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 4 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);

SET id_mes_periodo_facturado_inicio_7m = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_inicio_7m) AS INT64);

SET id_mes_periodo_facturado_fin_7m = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_fin_7m) AS INT64);

/*
CALL COMISIONES.pr_cartx_prueba(202507);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_billing_status_heos`
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


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
GROUP BY 1,2,3,4
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,TRIM(VENTAS.sfid_id) AS sfid_id
     ,TRIM(VENTAS.seller) AS seller
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
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
     ,VENTAS.cod_segmento
     ,VENTAS.cod_marca
     ,VENTAS.cod_tipo_contrato
     ,VENTAS.cod_producto
     ,VENTAS.cod_canal
--      ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,BILLING.invoice_id
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE comisionamiento = 'Comisiona'
                 AND brand_ds = 'YOIGO'
                 AND activation_date IS NOT NULL
           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') THEN 1 ELSE 2 END ASC,
                                              
                                              CASE WHEN COALESCE(deactivation_date, '9999-12-31') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN activation_date END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN activation_date END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END ASC
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

WHERE data_month_id = id_mes_periodo_facturado
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         OR
          (
          CONCEPTOS.bill_id IN ('DESCUENTO 100%X12MESES CON PERMANENCIA 24MESES') -- DESCUENTOS MOVIL ESPECIALES
          )
         )
         AND BILLING.data_month_id < 202500)
      --    OR
      --    (          
      --    BILLING.data_month_id > 202500
      --    AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
      --    AND BILLING.service_type = 'MOBILE'
      --    AND CONCEPTOS.bill_id = 'DESCUENTO') 
          -- DESCUENTO MOVIL
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
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         )
         AND BILLING.data_month_id < 202500)
      --    OR
      --    (          
      --    BILLING.data_month_id > 202500
      --    AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
      --    AND BILLING.service_type IN ('FIX','INTERNET')
      --    AND CONCEPTOS.bill_id = 'DESCUENTO' )
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27

UNION ALL

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal

     ,CASE WHEN VENTAS.sfid_id = 'GENMIGRA' THEN COALESCE(SFID.sfid_id, TRIM(VENTAS.seller)) ELSE TRIM(VENTAS.sfid_id) END AS sfid_id

     ,CASE 
          WHEN TRIM(VENTAS.seller) = 'GENMIGRA' THEN COALESCE(SFID.seller, TRIM(VENTAS.seller)) 
          WHEN TRIM(VENTAS.seller) = 'LB'       THEN COALESCE(SFID.seller, TRIM(VENTAS.user_store))
          ELSE TRIM(VENTAS.seller) 
      END AS seller

     ,'MYSIM' AS data_source_ds
     ,COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) AS marca

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
--      ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,BILLING.invoice_id
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE comisionamiento = 'Comisiona'
                 AND activation_date IS NOT NULL

           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') THEN 1 ELSE 2 END ASC,
                                              
                                              CASE WHEN COALESCE(deactivation_date, '9999-12-31') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN activation_date END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN activation_date END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END ASC
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm AND COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) = VENTAS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

LEFT JOIN (
          SELECT phone_nm, marca, sale_date, sfid_id, seller
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE (concepto LIKE 'A%' AND seller != 'LB') OR (concepto LIKE 'C%' AND seller != 'LB')
          QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca, sale_date ORDER BY id_mes DESC) = 1
          ) SFID
         ON VENTAS.phone_nm = SFID.phone_nm AND VENTAS.marca = SFID.marca AND VENTAS.sale_date = SFID.sale_date

WHERE data_month_id = id_mes_periodo_facturado
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         OR
          (
          CONCEPTOS.bill_id IN ('DESCUENTO 100%X12MESES CON PERMANENCIA 24MESES') -- DESCUENTOS MOVIL ESPECIALES
          )
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type = 'MOBILE'
         AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%') 
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
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('FIX','INTERNET')
         AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%' OR CONCEPTOS.bill_id LIKE '%T&B%')  )
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        OR
         (
         data_month_id >= 202304
         AND BILLING.service_type IN ('TV')
         AND CONCEPTOS.billing_concept_type_ds IN ('QUOTA TV')
         AND CONCEPTOS.billing_detail_ds IN ('AGILE_TV')
         ) -- CUOTA TV
        OR
         (
         data_month_id >= 202304
         AND data_month_id < 202500
         AND BILLING.service_type IN ('TV')
         AND CONCEPTOS.billing_concept_type_ds IN ('DISCOUNT TV')
         AND CONCEPTOS.billing_detail_ds IN ('DESCUENTO_AGILE_TV')
         )
         OR
         (          
         data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('TV')
         AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%')) -- DESCUENTO TV
        )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27

UNION ALL

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,TRIM(VENTAS.sfid_id) AS sfid_id
     ,TRIM(VENTAS.seller) AS seller
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
--      ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,BILLING.invoice_id
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE comisionamiento = 'Comisiona'
                 AND data_source_ds = 'HEOS'
                 AND activation_date IS NOT NULL
           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY service_id
                                     ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') THEN 1 ELSE 2 END ASC,
                                              
                                              CASE WHEN COALESCE(deactivation_date, '9999-12-31') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN activation_date END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN activation_date END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END ASC
                                     ) = 1
           ) VENTAS
          ON BILLING.service_id = VENTAS.service_id

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status_heos` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.id_factura

LEFT JOIN (
          SELECT seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
          ) AC
         ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

WHERE data_month_id = id_mes_periodo_facturado
      AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         OR
          (
          CONCEPTOS.bill_id IN ('DESCUENTO 100%X12MESES CON PERMANENCIA 24MESES') -- DESCUENTOS MOVIL ESPECIALES
          )
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
      --    AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type = 'MOBILE'
         AND CONCEPTOS.bill_id LIKE '%DESCUENTO%' 
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
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
      --    AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('FIX','INTERNET')
         AND CONCEPTOS.bill_id LIKE '%DESCUENTO%' )
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT *
FROM (
     SELECT 
           prefijo || '_' || mes_string || '_' || COALESCE(IFS_RET.canal, DEALER.canal) || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
          ,CAST(mes_string AS INT64) AS id_mes
          ,COALESCE(IFS_RET.agrupacion_canal, BILLING.agrupacion_canal) AS agrupacion_canal
          ,COALESCE(IFS_RET.canal, DEALER.canal) AS canal
          ,CONCEPTOS.concepto
          ,CONCEPTOS.tipo_concepto
          ,1 as unidades
     
          ,CASE
               WHEN CONCEPTOS.concepto = 'C - Cartera 4%'                                       THEN importe_facturado * 0.04
               WHEN CONCEPTOS.concepto = 'C - Cartera 3%'                                       THEN importe_facturado * 0.03
               WHEN CONCEPTOS.concepto = 'C - Cartera' AND BILLING.billing_type_ds = 'POSTPAID' THEN importe_facturado * 0.040002
               WHEN CONCEPTOS.concepto = 'C - Cartera' AND BILLING.billing_type_ds = 'PREPAID'  THEN importe_facturado * 0.00
           END AS comision
     
          ,COALESCE(IFS_RET.seller, DEALER.id_comisionista) AS id_comisionista
          ,COALESCE(IFS_RET.distribuidor, 'BYMOVIL') AS distribuidor -- 20250811 Johanna: Agrego BYMOVIL como distribuidor hardcodeado porque no viene en la GS SELLERS
          ,COALESCE(IFS_RET.seller, DEALER.id_comisionista) AS sfid_id -- 20250811 Johanna: Cambio BILLING.seller por DEALER.id_comisionista
          ,COALESCE(IFS_RET.seller, DEALER.id_comisionista) AS seller -- 20250811 Johanna: Cambio BILLING.seller por DEALER.id_comisionista
          ,COALESCE(IFS_RET.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
          ,COALESCE(IFS_RET.razon_social, DEALER.razon_social) AS razon_social
          ,COALESCE(IFS_RET.cif, DEALER.cif) AS cif
          ,COALESCE(IFS_RET.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
          ,BILLING.marca
          ,BILLING.service_type
          ,BILLING.phone_nm
          ,BILLING.tariff_id
          ,BILLING.tariff_ds
          ,BILLING.service_id
          ,BILLING.account_id
          ,BILLING.customer_id
          ,BILLING.line_type_ds
          ,BILLING.bundle_type
          ,BILLING.technology_ds
          ,BILLING.billing_type_ds
          ,BILLING.sale_date

          ,CASE WHEN BILLING.activation_date = '9999-12-31' THEN BILLING.sale_date ELSE BILLING.activation_date END AS activation_date

          ,BILLING.deactivation_date
          ,BILLING.order_id
          ,BILLING.order_type_agg
          ,BILLING.cod_segmento
          ,BILLING.cod_marca
          ,BILLING.cod_tipo_contrato
          ,BILLING.cod_producto
          ,COALESCE(IFS_RET.cod_canal, BILLING.cod_canal) AS cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number

          ,CASE
               WHEN CONCEPTOS.concepto = 'C - Cartera 4%'                                       THEN importe_facturado 
               WHEN CONCEPTOS.concepto = 'C - Cartera 3%'                                       THEN importe_facturado 
               WHEN CONCEPTOS.concepto = 'C - Cartera' AND BILLING.billing_type_ds = 'POSTPAID' THEN importe_facturado 
               WHEN CONCEPTOS.concepto = 'C - Cartera' AND BILLING.billing_type_ds = 'PREPAID'  THEN importe_facturado 
           END AS tax_base

          ,CAST(NULL AS STRING)  AS claim_code
          ,BILLING.invoice_id AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador
     
     FROM (
          (
          SELECT *
          FROM `mm-commissions-reporting.TEMP.cartx_billing`
          WHERE data_source_ds IN ('MYSIM', 'QVANTEL')
          QUALIFY RANK() OVER (
                              PARTITION BY phone_nm, marca, service_type
                              ORDER BY CASE
                                           WHEN data_source_ds = 'MYSIM' THEN 1
                                           WHEN data_source_ds = 'QVANTEL' THEN 2
                                       END ASC
                              ) = 1
          )
          UNION ALL
          SELECT * FROM `mm-commissions-reporting.TEMP.cartx_billing` WHERE data_source_ds IN ('HEOS')
          ) BILLING
     
        LEFT JOIN `mm-commissions-reporting.GS.exclusivo_dealers` DEALER
                  ON (
                        CASE WHEN BILLING.sfid_id != 'LB' THEN 
                                                              (
                                                                BILLING.sfid_id = DEALER.id_comisionista 
                                                              OR 
                                                                BILLING.seller = DEALER.id_comisionista 
                                                              )
                             ELSE BILLING.seller = DEALER.id_comisionista 
                        END
                     )
                  AND BILLING.agrupacion_canal = 'Exclusivo'

--      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
--                   ON (
--                         CASE WHEN BILLING.sfid_id != 'LB' THEN 
--                                                       (BILLING.sfid_id = DEALER.sfid_id 
--                                                       OR BILLING.seller = DEALER.sfid_id)
--                         ELSE BILLING.seller = DEALER.sfid_id
--                         END
--                      ) -- 20250411 JOHANNA: CASE PARA CORREGIR ZONAS FISCALES ERRÓNEAS POR BILLING.SFID_ID = LB
            --   ON (
            --      BILLING.sfid_id = DEALER.sfid_id 
            --      OR BILLING.seller = DEALER.sfid_id
            --      )
            --      AND BILLING.agrupacion_canal = DEALER.agrupacion_canal
     
     LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
               ON CONCEPTOS.id_prefijo = 'CAREX'
                  AND CASE
                          WHEN DEALER.canal IN ('EYG')                                          THEN 'Cartera'
                          WHEN DEALER.canal IN ('ENK') AND DEALER.canal_procedencia IN ('EYG')  THEN 'Cartera' 
                          WHEN DEALER.canal IN ('ENK')                                          THEN 'Cartera 4%' -- A PARTIR DE LIQUI AGOSTO 2025
                          WHEN DEALER.canal IN ('EML','ENX')                                    THEN 'Cartera 3%'                           
                      END = SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) -- 20250424 JOHANNA: CAMBIO EL ELSE POR WHEN 'EYG' PARA QUE NO CALCULE CARTERA POSTPAGO A ENX -- 20250507 AGREGO ENX PARA CÁLCULO CARTERA 3%
     
     LEFT JOIN (
               SELECT phone_nm
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE id_mes <= 202309 AND agrupacion_canal = 'Exclusivo' AND canal = 'EYG' AND concepto = 'C - Cartera' AND activation_date < '2022-01-01'
               GROUP BY 1
               ) IFS
              ON BILLING.phone_nm = IFS.phone_nm AND BILLING.activation_date < '2023-10-01'
     
     LEFT JOIN (
               SELECT *
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE id_mes = 202309 AND agrupacion_canal = 'Exclusivo' AND canal = 'EYG' AND concepto = 'C - Cartera'
               ) IFS_RET
              ON BILLING.phone_nm = IFS_RET.phone_nm AND BILLING.marca = IFS_RET.marca AND BILLING.agrupacion_canal = 'No aplica'
     
     LEFT JOIN `mm-commissions-reporting.GS.BAJACARTERA` BLACKLIST
              ON COALESCE(IFS_RET.seller, DEALER.id_comisionista) = BLACKLIST.sfid AND BLACKLIST.pagar = 'NO'
     
     WHERE 1=1 --BILLING.status IN ('PAID', 'RECOLLECTED')
           AND BILLING.importe_facturado > 0
           AND BLACKLIST.sfid IS NULL
           AND DEALER.id_comisionista NOT LIKE 'DBL%'
           AND (
                (
                BILLING.service_type IN ('MOBILE')
                AND  (
                       COALESCE(IFS_RET.canal, DEALER.canal) IN ('EYG') 
                       OR
                       (DEALER.canal = 'ENK' AND DEALER.canal_procedencia = 'EYG' AND DEALER.fecha_firma >= 202508)
                     ) 
                AND BILLING.marca = 'YOIGO'
                AND (BILLING.billing_type_ds = 'POSTPAID' AND BILLING.importe_facturado >= 6.00)
                AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera'
                ) -- C - Cartera -- 1
               OR
                (
                BILLING.service_type IN ('MOBILE')
                AND COALESCE(IFS_RET.canal, DEALER.canal_procedencia) IN ('EYG')
            --     AND DEALER.canal = 'ENK'
                AND DEALER.fecha_firma = 202507
                AND BILLING.marca = 'YOIGO'
                AND DATE_TRUNC(BILLING.activation_date, MONTH) < DATE('2025-07-01')
                AND (BILLING.billing_type_ds = 'POSTPAID' AND BILLING.importe_facturado >= 6.00)
                AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera'
                ) -- C - Cartera -- 4 residual
               OR
                (
                BILLING.billing_type_ds = 'POSTPAID'
                AND COALESCE(IFS_RET.canal, DEALER.canal) IN ('EML','ENX') 
                AND DATE_TRUNC(BILLING.activation_date, MONTH) >= DATE('2023-01-01')
                AND BILLING.marca IN ('GUUK', 'LLAMAYA', 'MASMOVIL', 'PEPEPHONE', 'YOIGO')
                AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera 3%'
                ) -- C - Cartera 3% -- 2, 3
               OR
                (
                BILLING.billing_type_ds = 'POSTPAID'
                AND COALESCE(IFS_RET.canal, DEALER.canal_procedencia) IN ('EML','ENX') 
                AND DEALER.canal = 'ENK'
                AND DATE_TRUNC(BILLING.activation_date, MONTH) BETWEEN DATE('2023-01-01') AND DATE('2025-06-01')
                AND BILLING.marca IN ('GUUK', 'LLAMAYA', 'MASMOVIL', 'PEPEPHONE', 'YOIGO')
                AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera 4%'
                ) -- C - Cartera 3% QUE PASA A 4% A PARTIR DEL 01/07 -- 5, 6
               OR
                (
                BILLING.billing_type_ds = 'POSTPAID'
                AND COALESCE(IFS_RET.canal, DEALER.canal) IN ('ENK') 
                AND DATE_TRUNC(BILLING.activation_date, MONTH) >= DATE('2025-07-01')
                AND BILLING.marca IN ('GUUK', 'LLAMAYA', 'MASMOVIL', 'PEPEPHONE', 'YOIGO')
                AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera 4%'
                ) -- C - Cartera 4% -- 4, 5, 6
               )
           --AND NOT (BILLING.activation_date < '2023-10-01' AND COALESCE(IFS_RET.canal, DEALER.canal) = 'EYG' AND IFS.phone_nm IS NULL)
     
     QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING) ORDER BY LENGTH(id_comisionista) DESC) = 1
     )
     
WHERE COALESCE(comision, 0.0) > 0.0
)
;


-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, ['EYG','EML','ENX','ENK'], 'TEMP.cartx', 'ACTUALIZAR');


END