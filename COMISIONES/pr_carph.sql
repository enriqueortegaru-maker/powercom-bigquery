BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado DATE;
DECLARE id_mes_periodo_facturado INT64;


SET prefijo = 'CARPH';

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);


/*
CALL COMISIONES.pr_carph(202511);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carph_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carph_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
GROUP BY 1,2,3,4
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.suspension_servicio_cartera` AS
    SELECT
      customer_id, brand_ds, invoice_id, data_month_id, billing_tier_1
    FROM `mm-datamart-kd.BILLING.billing_detail_emysim` B
    WHERE billing_tier_1 like '%SUSPENSION%'
    AND data_month_id = id_mes_periodo_facturado 
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carph_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
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
     ,VENTAS.tariff_id
     ,VENTAS.tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id
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
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT *
          --  FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
          FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE (comisionamiento = 'Comisiona' OR comisionamiento LIKE '%Phone House%')
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
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm and BILLING.customer_id = VENTAS.customer_id

LEFT JOIN `mm-commissions-reporting.TEMP.carph_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carph_billing_status` BILLING_STATUS
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

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,29

UNION ALL

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal

     ,CASE WHEN VENTAS.sfid_id = 'GENMIGRA' THEN COALESCE(SFID.sfid_id, VENTAS.seller) ELSE VENTAS.sfid_id END AS sfid_id

     ,CASE WHEN VENTAS.seller = 'GENMIGRA' THEN COALESCE(SFID.seller, VENTAS.seller) ELSE VENTAS.seller END AS seller

     ,'MYSIM' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type
     
     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,VENTAS.tariff_id
     ,VENTAS.tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id
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
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
          --  FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
          FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE (comisionamiento = 'Comisiona' OR comisionamiento LIKE '%Phone House%')
                 AND activation_date IS NOT NULL
                 AND activation_date < COMISIONES.f_mes_int (id_mes_pr) -- PARA DEJAR DE CALCULAR CARTERA ID_MES_PR A PARTIR DE LIQUI 202608

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
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm AND BILLING.brand_ds = VENTAS.brand_ds and BILLING.customer_id = VENTAS.customer_id


LEFT JOIN `mm-commissions-reporting.TEMP.carph_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carph_billing_status` BILLING_STATUS
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
          WHERE concepto LIKE 'A%'
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
         OR
          (
          CONCEPTOS.bill_id IN ('DESCUENTO 100%X12MESES CON PERMANENCIA 24MESES') -- DESCUENTOS MOVIL ESPECIALES
          )
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|GAS|ENERG')
         AND NOT (REGEXP_CONTAINS(BILLING.movtype_ds, r'DEVOLUCI') AND BILLING.concept_type_ds != 'Promociones') 
         AND BILLING.service_type = 'MOBILE'
     --     AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%') 
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%')
         ) -- DESCUENTO MOVIL
         
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,29
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carph` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT *
FROM (
     SELECT 
           prefijo || '_' || mes_string || '_' || COALESCE(IFS_RET.canal, DEALER.canal) || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
          ,CAST(mes_string AS INT64) AS id_mes
          ,COALESCE(IFS_RET.agrupacion_canal,DEALER.agrupacion_canal, BILLING.agrupacion_canal) AS agrupacion_canal
          -- ,COALESCE(IFS_RET.canal, DEALER.canal) AS canal
          ,'PH' AS canal
          ,'C - Cartera' AS concepto
          ,'AIRT' AS tipo_concepto
          ,1 as unidades
     
          ,CASE
               WHEN BILLING.billing_type_ds = 'POSTPAID' THEN importe_facturado * 0.10
               WHEN BILLING.billing_type_ds = 'PREPAID'  THEN importe_facturado * 0.04
           END AS comision
     
          ,COALESCE(IFS_RET.seller, DEALER.id_comisionista) AS id_comisionista
          ,COALESCE(IFS_RET.distribuidor, DEALER.distribuidor) AS distribuidor
          ,COALESCE(IFS_RET.seller, BILLING.seller) AS sfid_id
          ,COALESCE(IFS_RET.seller, BILLING.seller) AS seller
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
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,BILLING.invoice_id  AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador
     
     FROM (
          SELECT *
          FROM `mm-commissions-reporting.TEMP.carph_billing`
          QUALIFY RANK() OVER (
                              PARTITION BY phone_nm, marca, service_type
                              ORDER BY CASE
                                           WHEN data_source_ds = 'MYSIM' THEN 1
                                           WHEN data_source_ds = 'QVANTEL' THEN 2
                                       END ASC
                              ) = 1
          ) BILLING
     
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
              ON (
                 BILLING.sfid_id = DEALER.sfid_id
                 OR BILLING.seller = DEALER.sfid_id
                 OR BILLING.sfid_id || '-' || BILLING.seller = REPLACE(DEALER.sfid_id , ' ', '')
                 )
                 AND BILLING.agrupacion_canal = DEALER.agrupacion_canal
               --   AND DEALER.canal = 'PH'
     
     LEFT JOIN (
               SELECT *
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE id_mes = 202309 AND agrupacion_canal = 'No Exclusivo' AND canal = 'PH' AND concepto = 'C - Cartera'
               ) IFS_RET
              ON BILLING.phone_nm = IFS_RET.phone_nm AND BILLING.marca = IFS_RET.marca AND BILLING.agrupacion_canal = 'No aplica'

     LEFT JOIN `mm-commissions-reporting.TEMP.suspension_servicio_cartera` SUSPENSION
               ON BILLING.customer_id = SUSPENSION.customer_id
               AND BILLING.marca = SUSPENSION.brand_ds
               AND BILLING.invoice_id = SUSPENSION.invoice_id
     
     WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
           AND BILLING.importe_facturado > 0
           AND BILLING.service_type IN ('MOBILE')
           AND BILLING.marca = 'YOIGO'
           AND SUSPENSION.customer_id IS NULL
      --      AND DEALER.canal IN ('PH')
           AND (
               COALESCE(IFS_RET.seller, DEALER.id_comisionista) LIKE 'PH%'
               OR COALESCE(IFS_RET.seller, DEALER.sfid_id) LIKE 'PH%'
               OR COALESCE(IFS_RET.seller, BILLING.seller) LIKE 'PH%'
               )
           -- MAX 48 MESES
           AND DATE_DIFF(mes_periodo_facturado, BILLING.activation_date, MONTH) <= 48
           -- EXCLUIMOS BAJAS
           AND (BILLING.deactivation_date IS NULL OR BILLING.deactivation_date > mes_periodo_facturado)

          --  AND BILLING.activation_date < '2024-10-01'
     
     QUALIFY RANK() OVER (
                         PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING)
                         ORDER BY DEALER.id_mes DESC,
                                  CASE WHEN DEALER.sfid_id = BILLING.seller THEN 1 ELSE 2 END ASC,
                                  CASE WHEN DEALER.sfid_id = BILLING.sfid_id THEN 1 ELSE 2 END ASC
                         ) = 1
     )

WHERE COALESCE(comision, 0.0) > 0.0
AND agrupacion_canal  = 'No Exclusivo'
AND billing_type_ds = 'POSTPAID'
AND cif is not null
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CARPH', id_mes_pr, ['PH'], 'TEMP.carph', 'ACTUALIZAR');


END