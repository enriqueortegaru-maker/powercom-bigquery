BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado DATE;
DECLARE id_mes_periodo_facturado INT64;


SET prefijo = 'CARNEX';

SET canales_pr = COALESCE(canales_pr, ['ALTN','ALTNC','ALTNH']);

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);

/*
CALL COMISIONES.pr_carnex(202608,['ALTN']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tramos_fijo_alternativo` AS (
  

  SELECT SEGMENTACION.ID_PDV AS sfid_digo, ID_PDV.sfid as sfid_id, SEGMENTACION.*,GS.*

--   FROM `mm-commissions-reporting.GS.ALTERNATIVO_SEGMENTACION_FIJO` SEGMENTACION

  FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.SEGMENTACION_MENSUAL_ALTERNATIVO_FIJO` SEGMENTACION

  LEFT JOIN  `mm-commissions-reporting.GS.RAPPEL_FIJO` GS

   ON SEGMENTACION.SEGMENTACION_FIJO = GS.CLASIFICACION
    AND ID_MES_PR BETWEEN GS.MES_INICIO AND GS.MES_FIN

  
  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` ID_PDV
  ON SEGMENTACION.ID_EMPRESA = ID_PDV.sfid_unico



  WHERE SEGMENTACION.MES = ID_MES_PR
  
)


;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex_billing_status_heos`
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


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex_billing_conceptos`
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


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex_billing`
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
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT *
      --      FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
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

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_status` BILLING_STATUS
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
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,30

UNION ALL

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal

     ,CASE WHEN VENTAS.sfid_id = 'GENMIGRA' THEN COALESCE(SFID.sfid_id, VENTAS.seller) ELSE VENTAS.sfid_id END AS sfid_id

     ,CASE WHEN VENTAS.seller = 'GENMIGRA' THEN COALESCE(SFID.seller, VENTAS.seller) ELSE VENTAS.seller END AS seller

     ,'MYSIM' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX','INTERNET','BROADBAND')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')            THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.bundle_id
     ,BILLING.bundle_name
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
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
      --      FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
            FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
           WHERE comisionamiento = 'Comisiona'
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
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm AND BILLING.brand_ds = VENTAS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_status` BILLING_STATUS
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
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|GAS|ENERG')
         AND NOT (REGEXP_CONTAINS(BILLING.movtype_ds, r'DEVOLUCI') AND BILLING.concept_type_ds != 'Promociones')
         AND BILLING.service_type = 'MOBILE'
        --  AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%')
        AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%') 
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
         AND BILLING.service_type IN ('FIX','INTERNET','BROADBAND')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX','INTERNET','BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|GAS|ENERG')
         AND NOT (REGEXP_CONTAINS(BILLING.movtype_ds, r'DEVOLUCI') AND BILLING.concept_type_ds != 'Promociones') 
         AND BILLING.service_type IN ('FIX','INTERNET','BROADBAND')
        --  AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%' OR CONCEPTOS.bill_id LIKE '%T&B%')  
        AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%' OR CONCEPTOS.bill_id LIKE '%T&B%')
         )
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        OR
         (
         data_month_id >= 202304
         AND BILLING.service_type IN ('TV', 'ORANGE TV')
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
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|GAS|ENERG')
         AND NOT (REGEXP_CONTAINS(BILLING.movtype_ds, r'DEVOLUCI') AND BILLING.concept_type_ds != 'Promociones') -- 202609 Para incluir descuentos TV con movtype_ds DEVOLUCION
         AND BILLING.service_type IN ('TV', 'ORANGE TV')
        --  AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%')) 
        AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%' OR CONCEPTOS.bill_id LIKE '%DTO%')) -- DESCUENTO TV
        )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,30

UNION ALL

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,'HEOS' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX','INTERNET','BROADBAND')     THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')           THEN 'MOBILE'
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
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

INNER JOIN (
           SELECT *
      --      FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
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

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_status_heos` BILLING_STATUS
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
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%')
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
         AND BILLING.service_type IN ('FIX','INTERNET','BROADBAND')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX','INTERNET','BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
      --    AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('FIX','INTERNET','BROADBAND')
        --  AND CONCEPTOS.bill_id LIKE '%DESCUENTO%' )
        AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%'))
          -- DESCUENTO FIJO
          
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,30

-- UNION ALL
-- SELECT
--       COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal

--      ,CASE WHEN VENTAS.sfid_id = 'GENMIGRA' THEN COALESCE(SFID.sfid_id, VENTAS.seller) ELSE VENTAS.sfid_id END AS sfid_id

--      ,CASE WHEN VENTAS.seller = 'GENMIGRA' THEN COALESCE(SFID.seller, VENTAS.seller) ELSE VENTAS.seller END AS seller

--      ,'OSP' AS data_source_ds
--      ,BILLING.brand_ds AS marca

--      ,VENTAS.service_type

--      ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
--     --  ,BILLING.bundle_id
--     ,VENTAS.TARIFF_ID
--     --  ,BILLING.bundle_name
--     ,VENTAS.tariff_ds
--      ,CAST(BILLING.service_id AS STRING) AS service_id
--      ,CAST(BILLING.account_id AS STRING) AS account_id
--      ,CAST(BILLING.customer_id AS STRING) AS customer_id
--      ,VENTAS.line_type_ds
--      ,VENTAS.bundle_type
--      ,VENTAS.technology_ds
--      ,VENTAS.billing_type_ds
--      ,VENTAS.sale_date
--      ,VENTAS.activation_date
--      ,VENTAS.deactivation_date
--      ,VENTAS.order_id
--      ,VENTAS.order_type_agg
--      ,VENTAS.cod_segmento
--      ,VENTAS.cod_marca
--      ,VENTAS.cod_tipo_contrato
--      ,VENTAS.cod_producto
--      ,VENTAS.cod_canal
--      ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
--      ,MAX(VENTAS.comments) AS comments
--      ,SUM(BILLING.imp_amount) AS importe_facturado

-- FROM `mm-datamart-kd.BILLING.billing_detail_jazztel` BILLING
-- -- FROM `mm-datamart-kd.JV_ORANGE.billing_detail_osp` BILLING

-- INNER JOIN (
--            SELECT *
--       --      FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
--             FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
--            WHERE comisionamiento = 'Comisiona'
--            AND marca ='JAZZTEL'
--                  AND activation_date IS NOT NULL

--            QUALIFY ROW_NUMBER() OVER (
--                                      PARTITION BY phone_nm
--                                      ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') THEN 1 ELSE 2 END ASC,
                                              
--                                               CASE WHEN COALESCE(deactivation_date, '9999-12-31') >= DATE_ADD(id_mes_periodo_facturado , INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

--                                               CASE WHEN activation_date < id_mes_periodo_facturado  THEN 1 ELSE 2 END ASC,

--                                               CASE WHEN activation_date < id_mes_periodo_facturado  THEN activation_date END DESC,
--                                               CASE WHEN activation_date < id_mes_periodo_facturado  THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

--                                               CASE WHEN activation_date >= id_mes_periodo_facturado  THEN activation_date END ASC,
--                                               CASE WHEN activation_date >= id_mes_periodo_facturado  THEN COALESCE(deactivation_date, '9999-12-31') END ASC
--                                      ) = 1
--            ) VENTAS
--           ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm AND BILLING.brand_ds = VENTAS.brand_ds 
--           AND BILLING.document_hash = VENTAS.HASH_DOCUMENT_NUMBER


-- LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_status` BILLING_STATUS
--          ON BILLING.invoice_id = BILLING_STATUS.invoice_no

-- LEFT JOIN (
--           SELECT seller, agrupacion_canal
--           FROM `mm-commissions-reporting.COMISIONES.transacciones`
--           QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
--           ) AC
--          ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

-- LEFT JOIN (
--           SELECT phone_nm, marca, sale_date, sfid_id, seller
--           FROM `mm-commissions-reporting.COMISIONES.transacciones`
--           WHERE concepto LIKE 'A%'
--           QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca, sale_date ORDER BY id_mes DESC) = 1
--           ) SFID
--          ON VENTAS.phone_nm = SFID.phone_nm AND VENTAS.marca = SFID.marca AND VENTAS.sale_date = SFID.sale_date

-- WHERE data_month_id = id_mes_periodo_facturado 
--  AND BILLING.brand_ds = 'JAZZTEL'
     
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27 

UNION ALL

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,CASE 
          WHEN VENTAS.sfid_id = 'GENMIGRA' 
          THEN COALESCE(SFID.sfid_id, VENTAS.seller) 
          ELSE VENTAS.sfid_id 
      END AS sfid_id

     ,CASE 
          WHEN VENTAS.seller = 'GENMIGRA' 
          THEN COALESCE(SFID.seller, VENTAS.seller) 
          ELSE VENTAS.seller 
      END AS seller

     ,'OSP' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,VENTAS.service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,VENTAS.TARIFF_ID
     ,VENTAS.tariff_ds
     ,CAST(BILLING.service_id AS STRING) AS service_id
     ,CAST(BILLING.account_id AS STRING) AS account_id
     ,CAST(BILLING.customer_id AS STRING) AS customer_id
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
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_amount) AS importe_facturado
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_jazztel` BILLING
-- FROM `mm-datamart-kd.JV_ORANGE.billing_detail_osp` BILLING

INNER JOIN (
    SELECT *
    -- FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones`
    FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`

    WHERE comisionamiento = 'Comisiona'
      AND marca = 'JAZZTEL'
      AND activation_date IS NOT NULL

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY phone_nm

        ORDER BY 

            CASE 
                WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') 
                THEN 1 
                ELSE 2 
            END ASC,

            CASE 
                WHEN COALESCE(deactivation_date, '9999-12-31') >= 
                     DATE_ADD(
                         PARSE_DATE(
                             '%Y%m', 
                             CAST(id_mes_periodo_facturado AS STRING)
                         ),
                         INTERVAL 1 MONTH
                     )
                THEN 1 
                ELSE 2 
            END ASC,

            CASE 
                WHEN activation_date < 
                     PARSE_DATE(
                         '%Y%m', 
                         CAST(id_mes_periodo_facturado AS STRING)
                     )
                THEN 1 
                ELSE 2 
            END ASC,

            CASE 
                WHEN activation_date < 
                     PARSE_DATE(
                         '%Y%m', 
                         CAST(id_mes_periodo_facturado AS STRING)
                     )
                THEN activation_date 
            END DESC,

            CASE 
                WHEN activation_date < 
                     PARSE_DATE(
                         '%Y%m', 
                         CAST(id_mes_periodo_facturado AS STRING)
                     )
                THEN COALESCE(deactivation_date, '9999-12-31') 
            END DESC,

            CASE 
                WHEN activation_date >= 
                     PARSE_DATE(
                         '%Y%m', 
                         CAST(id_mes_periodo_facturado AS STRING)
                     )
                THEN activation_date 
            END ASC,

            CASE 
                WHEN activation_date >= 
                     PARSE_DATE(
                         '%Y%m', 
                         CAST(id_mes_periodo_facturado AS STRING)
                     )
                THEN COALESCE(deactivation_date, '9999-12-31') 
            END ASC

    ) = 1
) VENTAS

    ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm 
   AND BILLING.brand_ds = VENTAS.brand_ds 
   AND BILLING.document_hash = VENTAS.HASH_DOCUMENT_NUMBER

LEFT JOIN `mm-commissions-reporting.TEMP.carnex_billing_status` BILLING_STATUS
    ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
    SELECT 
        seller, 
        agrupacion_canal
    FROM `mm-commissions-reporting.COMISIONES.transacciones`

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY seller 
        ORDER BY id_mes DESC
    ) = 1
) AC

    ON VENTAS.seller = AC.seller 
   AND VENTAS.agrupacion_canal IS NULL

LEFT JOIN (
    SELECT 
        phone_nm, 
        marca, 
        sale_date, 
        sfid_id, 
        seller
    FROM `mm-commissions-reporting.COMISIONES.transacciones`

    WHERE concepto LIKE 'A%'

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY phone_nm, marca, sale_date 
        ORDER BY id_mes DESC
    ) = 1
) SFID

    ON VENTAS.phone_nm = SFID.phone_nm 
   AND VENTAS.marca = SFID.marca 
   AND VENTAS.sale_date = SFID.sale_date

WHERE data_month_id = id_mes_periodo_facturado 
  AND BILLING.brand_ds = 'JAZZTEL'

GROUP BY 
    1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,30


)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT *
FROM (
     SELECT 
           prefijo || '_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
          ,CAST(mes_string AS INT64) AS id_mes
          ,DEALER.agrupacion_canal 
          ,DEALER.canal
          ,CASE WHEN BILLING.SFID_ID IN ('LB106900','LB110100','LB139740') THEN 'C - Cartera 4%' ELSE 'C - Cartera' END AS concepto
          ,'AIRT'AS tipo_concepto
          ,1 as unidades
          ,CASE WHEN BILLING.SFID_ID IN ('LB106900','LB110100','LB139740') THEN importe_facturado * 0.04
           ELSE importe_facturado * TRAMOS.PORCENTAJE END AS comision
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

          ,CASE WHEN BILLING.activation_date = '9999-12-31' THEN BILLING.sale_date ELSE BILLING.activation_date END AS activation_date

          ,BILLING.deactivation_date
          ,BILLING.order_id
          ,BILLING.order_type_agg
          ,BILLING.cod_segmento
          ,BILLING.cod_marca
          ,BILLING.cod_tipo_contrato
          ,BILLING.cod_producto
          ,BILLING.cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,BILLING.invoice_id  AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador
     
     FROM (
          (
          SELECT *
          FROM `mm-commissions-reporting.TEMP.carnex_billing`
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
          SELECT * FROM `mm-commissions-reporting.TEMP.carnex_billing` WHERE data_source_ds IN ('HEOS')
          ) BILLING

     LEFT JOIN `mm-sales-reporting.optico.ORIGEN_DESTINO_PDV_MM` MIGRACIONES 
      ON MIGRACIONES.sfid_anterior = BILLING.SELLER 

     LEFT JOIN `mm-commissions-reporting.GS.ALTERNATIVO_SFID_MIGRADOS_CARTERA` SFID_EXCL
     ON (BILLING.SFID_ID = SFID_EXCL.EXCLUSIVO OR BILLING.seller = SFID_EXCL.EXCLUSIVO)

     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
              ON (((
                 BILLING.sfid_id = DEALER.sfid_id 
                 OR BILLING.seller = DEALER.sfid_id
                 )
                 AND BILLING.agrupacion_canal = DEALER.agrupacion_canal)
                 OR SFID_EXCL.ALTERNATIVO = DEALER.sfid_id
                 OR MIGRACIONES.sfid_actual = DEALER.sfid_id)
     
     LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
               ON CONCEPTOS.id_prefijo = 'CARNEX'

     
     LEFT JOIN `mm-commissions-reporting.TEMP.tramos_fijo_alternativo` TRAMOS_FIJO
     ON TRAMOS_FIJO.sfid_id = DEALER.sfid_id AND (id_mes_pr BETWEEN TRAMOS_FIJO.MES_INICIO AND TRAMOS_FIJO.MES_FIN)

     LEFT JOIN `mm-commissions-reporting.TEMP.CARTERA_TRAMOS`  TRAMOS
      ON (TRAMOS_FIJO.ALTAS_FIJO BETWEEN TRAMOS.RANGO_INI AND TRAMOS.RANGO_FIN)
            AND (id_mes_pr BETWEEN TRAMOS.MES_INICIO AND TRAMOS.MES_FIN)

     LEFT JOIN `mm-commissions-reporting.TEMP.suspension_servicio_cartera` SUSPENSION
        ON BILLING.customer_id = SUSPENSION.customer_id
               AND BILLING.marca = SUSPENSION.brand_ds
               AND BILLING.invoice_id = SUSPENSION.invoice_id 

     WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
           AND BILLING.importe_facturado > 0
           AND SUSPENSION.customer_id IS NULL
           AND (DEALER.CANAL IN ('ALTN','ALTNH','ALTNC')           
            AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)),
            DATE_TRUNC(BILLING.activation_date, MONTH),
            MONTH) < 12)
           AND BILLING.activation_date >= '2025-01-01' 
           AND (TRAMOS.PORCENTAJE > 0 OR SFID_EXCL.EXCLUSIVO IN ('LB106900','LB110100','LB139740')) -- AÑADIMOS CARTERA DE SFIDS MIRGRADOS
           AND DATE_TRUNC(BILLING.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))



     
     QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING) ORDER BY LENGTH(id_comisionista) DESC) = 1
     )
     
WHERE COALESCE(comision, 0.0) > 0.0
)
;

--- CARTERA OSP JAZZTEL
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex_osp_jazztel` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 12 DAY)) AS 
SELECT 
           'CARNEXJ' || '_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
          ,CAST(mes_string AS INT64) AS id_mes
          ,DEALER.agrupacion_canal 
          ,DEALER.canal
          ,CASE WHEN BILLING.SFID_ID IN ('LB106900','LB110100','LB139740') THEN 'C - Cartera 4%' ELSE 'C - Cartera' END AS concepto
          ,'AIRT'AS tipo_concepto
          ,1 as unidades
          ,CASE WHEN BILLING.SFID_ID IN ('LB106900','LB110100','LB139740') THEN importe_facturado * 0.04
           ELSE importe_facturado * TRAMOS.PORCENTAJE END AS comision
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

          ,CASE WHEN BILLING.activation_date = '9999-12-31' THEN BILLING.sale_date ELSE BILLING.activation_date END AS activation_date

          ,BILLING.deactivation_date
          ,BILLING.order_id
          ,BILLING.order_type_agg
          ,BILLING.cod_segmento
          ,BILLING.cod_marca
          ,BILLING.cod_tipo_contrato
          ,BILLING.cod_producto
          ,BILLING.cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,BILLING.invoice_id  AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador
     
     FROM (
          (
          SELECT *
          FROM `mm-commissions-reporting.TEMP.carnex_billing`
          WHERE data_source_ds IN ('OSP')
          QUALIFY RANK() OVER (
                              PARTITION BY phone_nm, marca, service_type
                              ORDER BY CASE
                                           WHEN data_source_ds = 'MYSIM' THEN 1
                                           WHEN data_source_ds = 'QVANTEL' THEN 2
                                       END ASC
                              ) = 1
          )
          UNION ALL
          SELECT * FROM `mm-commissions-reporting.TEMP.carnex_billing` WHERE data_source_ds IN ('HEOS')
          UNION ALL
          SELECT * FROM `mm-commissions-reporting.TEMP.carnex_billing` WHERE data_source_ds IN ('OSP')
          ) BILLING

     LEFT JOIN `mm-sales-reporting.optico.ORIGEN_DESTINO_PDV_MM` MIGRACIONES 
      ON MIGRACIONES.sfid_anterior = BILLING.SELLER 

     LEFT JOIN `mm-commissions-reporting.GS.ALTERNATIVO_SFID_MIGRADOS_CARTERA` SFID_EXCL
     ON (BILLING.SFID_ID = SFID_EXCL.EXCLUSIVO OR BILLING.seller = SFID_EXCL.EXCLUSIVO)

     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
              ON BILLING.SFID_ID = DEALER.SFID_ID

     
     LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
               ON CONCEPTOS.id_prefijo = 'CARNEX'

     
     LEFT JOIN `mm-commissions-reporting.TEMP.tramos_fijo_alternativo` TRAMOS_FIJO
     ON TRAMOS_FIJO.sfid_id = DEALER.sfid_id AND (id_mes_pr BETWEEN TRAMOS_FIJO.MES_INICIO AND TRAMOS_FIJO.MES_FIN)

     LEFT JOIN `mm-commissions-reporting.TEMP.CARTERA_TRAMOS`  TRAMOS
      ON (TRAMOS_FIJO.ALTAS_FIJO BETWEEN TRAMOS.RANGO_INI AND TRAMOS.RANGO_FIN)
            AND (id_mes_pr BETWEEN TRAMOS.MES_INICIO AND TRAMOS.MES_FIN)

     WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
     AND BILLING.MARCA IN ('JAZZTEL')
           AND BILLING.importe_facturado > 0
           AND (DEALER.CANAL IN ('ALTN','ALTNH','ALTNC')           
            AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)),
            DATE_TRUNC(BILLING.activation_date, MONTH),
            MONTH) < 12)
           AND BILLING.activation_date >= '2025-01-01' 
           AND (TRAMOS.PORCENTAJE > 0 OR SFID_EXCL.EXCLUSIVO IN ('LB106900','LB110100','LB139740')) -- AÑADIMOS CARTERA DE SFIDS MIRGRADOS
           AND DATE_TRUNC(COALESCE(BILLING.deactivation_date,'9999-12-31'), MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING) ORDER BY LENGTH(id_comisionista) DESC) = 1
;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnex` 
-- AS (
--   SELECT *
--   FROM `mm-commissions-reporting.TEMP.carnex` 
--   UNION ALL
--   SELECT * 
--   FROM `mm-commissions-reporting.TEMP.carnex_osp_jazztel` 
-- )
-- ;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CARNEX', 202609, ['ALTN'], 'TEMP.carnex', 'ACTUALIZAR');


END