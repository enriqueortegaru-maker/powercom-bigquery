BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado DATE;
DECLARE id_mes_periodo_facturado INT64;


SET prefijo = 'CAROU';

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);


/*
CALL COMISIONES.pr_carou(202407)
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carou_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carou_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
group by 1,2,3,4
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carou_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      VENTAS.agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,'YOIGO' AS marca
     
     ,CASE
          WHEN BILLING.bill_id LIKE '%CONVDISC%'    THEN 'INTERNET'
          WHEN BILLING.bill_id LIKE 'FH%DISC%'      THEN 'INTERNET'
          WHEN BILLING.service_type = 'FIX' THEN 'INTERNET'
          ELSE 'MOBILE'
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id
     ,VENTAS.customer_id
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
     ,COALESCE(status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE comisionamiento = 'Comisiona'
                 AND brand_ds = 'YOIGO'
                 AND activation_date IS NOT NULL
                 AND COALESCE(deactivation_date, '2100-01-01') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH)
           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.carou_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carou_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE data_month_id = id_mes_periodo_facturado
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
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26

UNION ALL

SELECT
      VENTAS.agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type
     
     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id
     ,VENTAS.customer_id
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
     ,COALESCE(status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE comisionamiento = 'Comisiona'
                 AND brand_ds = 'YOIGO'
                 AND activation_date IS NOT NULL
                 AND COALESCE(deactivation_date, '2100-01-01') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH)
           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.carou_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carou_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE data_month_id = id_mes_periodo_facturado
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
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carou` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT 
      prefijo || '_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
     ,CAST(mes_string AS INT64) AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,'C - Cartera' AS concepto
     ,'AIRT' AS tipo_concepto
     ,1 as unidades
     ,importe_facturado * 0.05 AS comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,BILLING.seller AS sfid_id
     ,BILLING.seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
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
     ,BILLING.activation_date
     ,BILLING.deactivation_date
     ,BILLING.order_id
     ,BILLING.order_type_agg
     ,BILLING.cod_segmento
     ,BILLING.cod_marca
     ,BILLING.cod_tipo_contrato
     ,BILLING.cod_producto
     ,BILLING.cod_canal

     ,CASE
          WHEN BILLING.activation_date < '2024-07-22' --<-- INCLUSION DE NUEVOS SFIDS Y CAMPAÑAS EN TLV CROSS-SELL - JULIO 2024
          THEN COALESCE(
                        `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, BILLING.marca, BILLING.seller, BILLING.service_type)
                       ,TLV_CROSS_SELL.campaign
                       )
          
          ELSE COALESCE(
                        TLV_CROSS_SELL.campaign
                       ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, BILLING.marca, BILLING.seller, BILLING.service_type)
                       )
      END AS campaign_code

     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.carou_billing` BILLING

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON (
            BILLING.sfid_id = DEALER.sfid_id 
            OR (SUBSTR(BILLING.seller,1,2) = DEALER.sfid_id)
            OR BILLING.seller = DEALER.sfid_id
            OR BILLING.sfid_id || '-' || BILLING.seller = REPLACE(DEALER.sfid_id , ' ', '')
            )
            AND DEALER.agrupacion_canal = 'TLV - Outbound'

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
      AND DEALER.id_comisionista IN ('CL', 'CT', 'TO', 'RC', 'CP')
      AND BILLING.importe_facturado >= 6.00
      AND BILLING.bundle_type IN ('MO')
      AND BILLING.service_type IN ('MOBILE')
      AND BILLING.marca IN ('YOIGO')
      /* Excluir números que antes no se calculaban desde IFS */
      AND BILLING.phone_nm IN (
                              SELECT DISTINCT phone_nm
                              FROM `mm-commissions-reporting.COMISIONES.transacciones`
                              WHERE id_mes = 202307 AND agrupacion_canal = 'TLV - Outbound' AND concepto = 'C - Cartera'
                              )

UNION ALL /* Incluir números que salían antiguamente de IFS pero que con la nueva extracción no salen */

SELECT 
      'CAROU_IFS' || '_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
     ,CAST(mes_string AS INT64) AS id_mes
     ,TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,'C - Cartera' AS concepto
     ,'AIRT' AS tipo_concepto
     ,1 as unidades
     ,TRANSACCIONES.comision
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.distribuidor
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.seller
     ,TRANSACCIONES.nombre_comercio
     ,TRANSACCIONES.razon_social
     ,TRANSACCIONES.cif
     ,TRANSACCIONES.zona_fiscal
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
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
     ,TRANSACCIONES.campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

WHERE TRANSACCIONES.id_mes = 202307 AND TRANSACCIONES.agrupacion_canal = 'TLV - Outbound' AND TRANSACCIONES.concepto = 'C - Cartera'
      AND TRANSACCIONES.phone_nm NOT IN (
                                        SELECT DISTINCT phone_nm
                                        FROM `mm-commissions-reporting.TEMP.carou_billing` BILLING
                                        LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
                                                 ON (
                                                    BILLING.sfid_id = DEALER.sfid_id 
                                                    OR (SUBSTR(BILLING.seller,1,2) = DEALER.sfid_id)
                                                    OR BILLING.seller = DEALER.sfid_id
                                                    OR BILLING.sfid_id || '-' || BILLING.seller = REPLACE(DEALER.sfid_id , ' ', '')
                                                    )
                                                    AND DEALER.agrupacion_canal = 'TLV - Outbound'
                                        WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
                                              AND DEALER.id_comisionista IN ('CL', 'CT', 'TO', 'RC', 'CP')
                                              AND BILLING.importe_facturado >= 6.00
                                              AND BILLING.bundle_type IN ('MO')
                                              AND BILLING.service_type IN ('MOBILE')
                                              AND BILLING.marca IN ('YOIGO')
                                        )
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, ['OU'], 'TEMP.carou', 'ACTUALIZAR');


END