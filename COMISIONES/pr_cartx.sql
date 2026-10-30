BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado,mes_periodo_facturado_3m DATE;
DECLARE id_mes_periodo_facturado,id_mes_periodo_facturado_3m INT64;


SET prefijo = 'CARTX';

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET mes_periodo_facturado_3m = DATE_ADD(mes_periodo_facturado, INTERVAL  - 4 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);

SET id_mes_periodo_facturado_3m = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_3m) AS INT64);


/*
CALL COMISIONES.pr_cartx(202606);
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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.suspension_servicio_cartera` AS
    SELECT
      customer_id, brand_ds, invoice_id, data_month_id, billing_tier_1
    FROM `mm-datamart-kd.BILLING.billing_detail_emysim` B
    WHERE billing_tier_1 like '%SUSPENSION%'
    AND data_month_id = id_mes_periodo_facturado 
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
------------------------------------------
-- QVANTEL
------------------------------------------
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
          WHEN BILLING.service_type = 'BROADBAND'   THEN 'INTERNET' -- 20260309 JOHANNA
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
               --   AND activation_date < COMISIONES.f_mes_int (id_mes_pr)
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
          -- AND BILLING.service_id = VENTAS.service_id

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
     --  AND VENTAS.activation_date < COMISIONES.f_mes_int (id_mes_pr)
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
         AND BILLING.service_type IN ('FIX', 'INTERNET','BROADBAND') -- 20260309 JOHANNA: AGREGO BROADBAND
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX') -- 20260309 JOHANNA: AGREGO BROADBAND
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

------------------------------------------
-- MYSIM
------------------------------------------

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
          WHEN BILLING.service_type IN ('FIX', 'INTERNET','BROADBAND')  THEN 'INTERNET' -- 20260309 JOHANNA: AGREGO BROADBAND 
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')         THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,CASE WHEN BILLING.service_type = 'FIX' THEN BROADBAND.tariff_id  ELSE BILLING.tariff_id  END AS tariff_id
     ,CASE WHEN BILLING.service_type = 'FIX' THEN BROADBAND.tariff_ds  ELSE BILLING.tariff_ds  END AS tariff_ds
     ,CASE WHEN BILLING.service_type = 'FIX' THEN BROADBAND.service_id ELSE BILLING.service_id END AS service_id
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
     ,BILLING.invoice_id
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` sales
           WHERE comisionamiento = 'Comisiona'
           AND marca IN ('YOIGO', 'MASMOVIL')
                 AND activation_date IS NOT NULL
                 AND activation_date < COMISIONES.f_mes_int (id_mes_pr) -- PARA DEJAR DE CALCULAR CARTERA ID_MES_PR A PARTIR DE LIQUI 202606

           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY sales.phone_nm, sales.brand_ds -- 20260708 JD: Agrego marca para incluir ambas marcas en el mismo mes en portas. Ej: phone_nm 600027808
                                     ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') THEN 1 ELSE 2 END ASC,
                                              
                                              CASE WHEN COALESCE(sales.deactivation_date, '9999-12-31') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN activation_date END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN activation_date END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END ASC
                                     ) = 1

           UNION ALL

           SELECT 
             '' AS comisionamiento
             ,TVS.brand_ds AS marca
             ,TVS.brand_ds
             ,TVS.service_id
             ,TVS.account_id
             ,TVS.customer_id
             ,'TV' AS service_type
             ,TVS.sell_line_type_ds
             ,CASE 
                  WHEN TVS.sell_bundle_type LIKE '%B%' THEN 'FMC' 
                  WHEN TVS.sell_bundle_type LIKE 'M%' THEN 'MO' 
              END AS bundle_type
             ,TVS.technology_ds
             ,TVS.billing_type_ds
             ,CAST(TVS.phone_nm AS STRING) AS phone_nm
             ,TVS.order_date AS sale_date
             ,TVS.activation_date
             ,TVS.real_deactivation_date AS deactivation_date
             ,TVS.order_id
             ,TVS.order_type_agg
             ,TVS.port_in_operator_ds
             ,TVS.sell_tariff_id
             ,TVS.sell_tariff_ds
             ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(TVS.segment_ds, TVS.brand_ds) AS cod_segmento
             ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(TVS.brand_ds) AS cod_marca
             ,'99' AS cod_tipo_contrato
             ,'006' AS cod_producto
             ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(TVS.channel_ds, TVS.subchannel_ds) AS cod_canal
             ,AC.agrupacion_canal
             ,TVS.user_store AS sfid_id
             ,TVS.user_store AS seller
             ,TVS.channel_ds
             ,TVS.order_fix_id
             ,CAST(null AS STRING) AS claim_code
             ,CAST(null AS STRING) AS comments
             ,TVS.contract_id
             ,TVS.data_source_ds
             ,TVS.port_in_operator_ds AS portability_group_donor
             ,TVS.port_in_operator_ds AS portability_operator_donor
             ,TVS.flag_order
             ,TVS.segment_ds
             ,TVS.user_store
             ,TVS.subchannel_ds
             ,TVS.cancellation_date AS cancellation_day_id
             ,TVS.sell_type
             ,TVS.province
             ,TVS.zip_code
             ,TVS.terminal_model
             ,CAST(null AS STRING) AS sva_tv
             ,TVS.channel_segment_ds
             ,TVS.master_channel_ds
             ,TVS.channel_type_ds
             ,TVS.customer_document AS hash_document_number
             ,cancellation_reason_agg
             ,cancellation_subreason_agg
             ,CAST(null AS DATE) AS max_appointment_date
             ,CAST(null AS STRING) AS billing_tier
             ,CAST(null AS STRING) AS qvantel_service_id
             ,CAST(null AS INT64) AS post_pre_flag
             ,CAST(null AS STRING) AS sociedad
             ,CAST(null AS INT64) AS id_mes_activacion
             ,CAST(null AS STRING) AS seller_formato_tms

           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` TVS
           
           LEFT JOIN (
                     SELECT seller, agrupacion_canal
                     FROM `mm-commissions-reporting.COMISIONES.transacciones`
                     QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
                     ) AC
                    ON TVS.seller = AC.seller
           
           WHERE service_type IN ('ORANGE TV')
           AND activation_date IS NOT NULL
           AND order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO')
         
           ) VENTAS
          ON CASE WHEN BILLING.service_type = 'ORANGE TV' THEN BILLING.service_id ELSE CAST(BILLING.phone_nm AS STRING) END
             = 
             CASE WHEN VENTAS.service_type = 'ORANGE TV' THEN VENTAS.service_id ELSE VENTAS.phone_nm END -- LIQUI 202604 AGREGAMOS CASE CON SERVICE_ID PARA INCLUIR ORANGE TV
             AND COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) = VENTAS.brand_ds

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

LEFT JOIN (
          SELECT phone_nm, brand_ds, tariff_id, tariff_ds, service_id
          FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
          WHERE service_type = 'BROADBAND'
          AND data_month_id = id_mes_periodo_facturado
          QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, brand_ds) = 1
          ) BROADBAND
          ON BILLING.phone_nm = BROADBAND.phone_nm AND BILLING.brand_ds = BROADBAND.brand_ds


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
         AND BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') -- 20260309 JOHANNA: AGREGO BROADBAND
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET','BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX') -- 20260309 JOHANNA: AGREGO BROADBAND
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|GAS|ENERG')
         AND NOT (REGEXP_CONTAINS(BILLING.movtype_ds, r'DEVOLUCI') AND BILLING.concept_type_ds != 'Promociones')
         AND BILLING.service_type IN ('FIX','INTERNET','BROADBAND') -- 20260309 JOHANNA: AGREGO BROADBAND
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%' OR CONCEPTOS.bill_id LIKE '%T&B%')  )
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        OR
         (
         data_month_id >= 202304
         AND BILLING.service_type IN ('TV','ORANGE TV')
         AND CONCEPTOS.billing_concept_type_ds IN ('QUOTA TV')
         AND CONCEPTOS.billing_detail_ds IN ('AGILE_TV','YOIGO_TV','MASMOVIL_TV','RAKUTEN')
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
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%' OR CONCEPTOS.bill_id LIKE '%DTO%')) -- DESCUENTO TV
        )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27

UNION ALL

------------------------------------------
-- HEOS
------------------------------------------

SELECT
      COALESCE(VENTAS.agrupacion_canal, AC.agrupacion_canal) AS agrupacion_canal
     ,TRIM(VENTAS.sfid_id) AS sfid_id
     ,TRIM(VENTAS.seller) AS seller
     ,'HEOS' AS data_source_ds
     ,BILLING.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') THEN 'INTERNET' -- 20260309 JOHANNA: AGREGO BROADBAND
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')         THEN 'MOBILE'
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
         AND BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') -- 20260309 JOHANNA: AGREGO BROADBAND
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX') -- 20260309 JOHANNA: AGREGO BROADBAND
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
      --    AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('FIX','INTERNET', 'BROADBAND') -- 20260309 JOHANNA: AGREGO BROADBAND
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%' OR CONCEPTOS.bill_id LIKE '%DISCO%'))
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27

UNION ALL

------------------------------------------
-- STREAMING MYSIM
------------------------------------------

SELECT
      DEALER.agrupacion_canal

     ,CASE WHEN VENTAS.sfid_id = 'GENMIGRA' THEN COALESCE(SFID.sfid_id, TRIM(VENTAS.user_store)) ELSE TRIM(VENTAS.user_store) END AS sfid_id

     ,CASE 
          WHEN TRIM(VENTAS.sfid_id) = 'GENMIGRA' THEN COALESCE(TRIM(VENTAS.user_store),SFID.seller) 
          WHEN TRIM(VENTAS.sfid_id) = 'LB'       THEN COALESCE(TRIM(VENTAS.user_store),SFID.seller)
          ELSE TRIM(VENTAS.user_store) 
      END AS seller

     ,'MYSIM' AS data_source_ds
     ,COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET','BROADBAND')  THEN 'INTERNET' 
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')         THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
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
     ,VENTAS.billing_type_ds
     ,VENTAS.order_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.real_deactivation_date AS deactivation_date
     ,CAST(VENTAS.order_id AS STRING) AS order_id
     ,VENTAS.order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca

     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
         VENTAS.billing_type_ds, 
         VENTAS.service_type, 
         COALESCE(CASE WHEN VENTAS.sell_bundle_type = 'DESC' THEN VENTAS.bundle_type ELSE VENTAS.sell_bundle_type END, VENTAS.bundle_type), 
         VENTAS.technology_ds, 
         VENTAS.brand_ds, 
         COALESCE(CASE WHEN VENTAS.sell_line_type_ds = 'DESC' THEN VENTAS.line_type_ds ELSE VENTAS.sell_line_type_ds END, VENTAS.line_type_ds)
      )  AS cod_tipo_contrato

     ,'006' AS cod_producto
     ,'27' cod_canal
     ,BILLING.invoice_id
     ,CAST(null AS STRING) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`

           WHERE true
           AND brand_ds IN ('YOIGO', 'MASMOVIL')
           AND activation_date IS NOT NULL
           AND activation_date >= '2026-07-20' -- INICIO PORTFOLIO LEGO

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
          ON CAST(BILLING.service_id AS STRING) = VENTAS.service_id 
             AND COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) = VENTAS.brand_ds

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

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

-- LEFT JOIN (
--           SELECT seller, agrupacion_canal
--           FROM `mm-commissions-reporting.COMISIONES.transacciones`
--           QUALIFY ROW_NUMBER() OVER (PARTITION BY seller ORDER BY id_mes DESC) = 1
--           ) AC
--          ON VENTAS.seller = AC.seller AND VENTAS.agrupacion_canal IS NULL

LEFT JOIN (
          SELECT phone_nm, marca, sale_date, sfid_id, seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE (concepto LIKE 'A%' AND seller != 'LB') OR (concepto LIKE 'C%' AND seller != 'LB')
          QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca, sale_date ORDER BY id_mes DESC) = 1
          ) SFID
         ON CAST(VENTAS.phone_nm AS STRING) = SFID.phone_nm AND VENTAS.brand_ds = SFID.marca AND VENTAS.order_date = SFID.sale_date

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON DEALER.sfid_id = VENTAS.user_store

WHERE data_month_id = id_mes_periodo_facturado
      AND
        (
         (data_month_id >= 202607
         AND BILLING.service_type IN ('AMAZON PRIME','DISNEY','MAX','NETFLIX')
         AND CONCEPTOS.billing_concept_type_ds IN ('QUOTA','QUOTA TV')
         AND CONCEPTOS.billing_detail_ds IN ('AMAZON','DISNEY','MAX','QUOTA') -- QUOTA = NETFLIX
         ) -- CUOTA STREAMING
          OR
         (data_month_id >=202607
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('AMAZON PRIME','DISNEY','MAX','NETFLIX')
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%'OR CONCEPTOS.bill_id LIKE '%DISCO%')
         ) -- DESCUENTO STREAMING
       )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27

UNION ALL

------------------------------------------
-- STREAMING HEOS
------------------------------------------

SELECT
      DEALER.agrupacion_canal

     ,CASE WHEN VENTAS.sfid_id = 'GENMIGRA' THEN COALESCE(SFID.sfid_id, TRIM(VENTAS.user_store)) ELSE TRIM(VENTAS.user_store) END AS sfid_id

     ,CASE 
          WHEN TRIM(VENTAS.sfid_id) = 'GENMIGRA' THEN COALESCE(TRIM(VENTAS.user_store),SFID.seller) 
          WHEN TRIM(VENTAS.sfid_id) = 'LB'       THEN COALESCE(TRIM(VENTAS.user_store),SFID.seller)
          ELSE TRIM(VENTAS.user_store) 
      END AS seller

     ,'HEOS' AS data_source_ds
     ,COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET','BROADBAND')  THEN 'INTERNET' 
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')         THEN 'MOBILE'
          WHEN BILLING.billing_tier_2 LIKE 'PRIME%'                     THEN 'AMAZON PRIME'
          WHEN BILLING.billing_tier_2 LIKE 'HBO%'                       THEN 'MAX'
          WHEN BILLING.billing_tier_2 LIKE 'NETFLIX%'                   THEN 'NETFLIX'
          WHEN BILLING.billing_tier_2 LIKE 'DISNEY%'                    THEN 'DISNEY'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,VENTAS.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
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
     ,VENTAS.billing_type_ds
     ,VENTAS.order_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.real_deactivation_date AS deactivation_date
     ,CAST(VENTAS.order_id AS STRING) AS order_id
     ,VENTAS.order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca

     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
         VENTAS.billing_type_ds, 
         VENTAS.service_type, 
         COALESCE(CASE WHEN VENTAS.sell_bundle_type = 'DESC' THEN VENTAS.bundle_type ELSE VENTAS.sell_bundle_type END, VENTAS.bundle_type), 
         VENTAS.technology_ds, 
         VENTAS.brand_ds, 
         COALESCE(CASE WHEN VENTAS.sell_line_type_ds = 'DESC' THEN VENTAS.line_type_ds ELSE VENTAS.sell_line_type_ds END, VENTAS.line_type_ds)
      )  AS cod_tipo_contrato

     ,'006' AS cod_producto
     ,'27' cod_canal
     ,BILLING.invoice_id
     ,CAST(null AS STRING) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

INNER JOIN (
           SELECT *
           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
           WHERE true
           AND brand_ds IN ('PEPEPHONE')
           AND activation_date IS NOT NULL
           AND activation_date >= '2026-07-20' -- INICIO PORTFOLIO LEGO

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
          ON BILLING.customer_id = VENTAS.customer_id 
             AND BILLING.brand_ds = VENTAS.brand_ds
             AND CASE 
                     WHEN BILLING.billing_tier_2 LIKE 'PRIME%'   THEN 'AMAZON PRIME'
                     WHEN BILLING.billing_tier_2 LIKE 'HBO%'     THEN 'MAX'
                     WHEN BILLING.billing_tier_2 LIKE 'NETFLIX%' THEN 'NETFLIX'
                     WHEN BILLING.billing_tier_2 LIKE 'DISNEY%'  THEN 'DISNEY' 
                  END
                  =
                  VENTAS.service_type

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
               WHERE data_source_ds = 'HEOS'
                     AND service_type IN ('BROADBAND', 'FIX', 'MOBILE')
                    --  AND service_status_ds = 'ACTIVO' -- JOHANNA 20250506 PARA EVITAR DUPLICADO EN ESTADO TERMINADO
               ) SERVICE_DETAILS
          
          INNER JOIN (
                     SELECT
                           account_id
                          ,brand_ds
                     FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                     WHERE service_type IN ('AMAZON PRIME', 'MAX', 'NETFLIX','DISNEY')
                           AND brand_ds IN ('PEPEPHONE')
                     GROUP BY 1,2
                     ) STREAMING_ACCOUNTS
                    ON SERVICE_DETAILS.account_id = STREAMING_ACCOUNTS.account_id AND SERVICE_DETAILS.brand_ds = STREAMING_ACCOUNTS.brand_ds
          
          QUALIFY RANK() OVER (
                              PARTITION BY account_id, brand_ds
                              ORDER BY CASE WHEN service_type = 'BROADBAND' THEN 1 ELSE 2 END ASC
                              ) = 1
          ) SERVICE_DETAILS
         ON VENTAS.account_id = SERVICE_DETAILS.account_id AND VENTAS.brand_ds = SERVICE_DETAILS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN (
          SELECT phone_nm, marca, sale_date, sfid_id, seller, agrupacion_canal
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE (concepto LIKE 'A%' AND seller != 'LB') OR (concepto LIKE 'C%' AND seller != 'LB')
          QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca, sale_date ORDER BY id_mes DESC) = 1
          ) SFID
         ON CAST(VENTAS.phone_nm AS STRING) = SFID.phone_nm AND VENTAS.brand_ds = SFID.marca AND VENTAS.order_date = SFID.sale_date

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON DEALER.sfid_id = VENTAS.user_store

WHERE data_month_id = id_mes_periodo_facturado
      AND
        (
         (data_month_id >= 202607
         AND BILLING.service_type IN ('STREAMING')
         AND (BILLING.billing_tier_2 LIKE 'PRIME%' OR BILLING.billing_tier_2 LIKE 'HBO%' OR BILLING.billing_tier_2 LIKE 'NETFLIX%' OR BILLING.billing_tier_2 LIKE 'DISNEY%')
         AND CONCEPTOS.billing_concept_type_ds IN ('QUOTA','USAGE') -- FALTA CONFIRMAR SI SE DEBE INCLUIR USAGE
         ) -- CUOTA STREAMING )
          OR
         (data_month_id >=202607
         AND BILLING.service_type IN ('STREAMING')
         AND (BILLING.billing_tier_2 LIKE 'PRIME%' OR BILLING.billing_tier_2 LIKE 'HBO%' OR BILLING.billing_tier_2 LIKE 'NETFLIX%' OR BILLING.billing_tier_2 LIKE 'DISNEY%')
         AND CONCEPTOS.billing_concept_type_ds IN ('QUOTA DISCOUNT')
         AND (CONCEPTOS.bill_id LIKE '%DESC%' OR CONCEPTOS.bill_id LIKE '%DESKO%'OR CONCEPTOS.bill_id LIKE '%DISCO%')
         ) -- DESCUENTO STREAMING
       )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
  prefijo || '_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
 ,estado
 ,mes_liquidado
 ,id_mes
 ,agrupacion_canal
 ,canal
 ,concepto
 ,tipo_concepto
 ,unidades
 ,SUM(comision) AS comision
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
 ,SUM(tax_base) AS tax_base
 ,claim_code
 ,process_code
 ,comments
 ,facturador
FROM (
     SELECT 
          'calculado' AS estado
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
          ,COALESCE(IFS_RET.cif, DEALER.documento) AS cif
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
                        CASE WHEN BILLING.sfid_id != 'LB' THEN COALESCE(BILLING.sfid_id, BILLING.seller) = DEALER.id_comisionista
                                                            --   (
                                                            --     BILLING.sfid_id = DEALER.id_comisionista 
                                                            --   OR 
                                                            --     BILLING.seller = DEALER.id_comisionista 
                                                            --   ) -- 20260703 JD: ESTABA DUPLICANDO REGISTROS
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

     LEFT JOIN (
                SELECT DISTINCT phone_nm, marca
                FROM `mm-commissions-reporting.COMISIONES.transacciones`
                WHERE agrupacion_canal = 'Exclusivo'
                AND concepto LIKE '%Cartera Renuevo'
                AND id_mes = id_mes_pr
                GROUP BY ALL
                ) CARTERA_RENUEVO
              ON BILLING.phone_nm = CARTERA_RENUEVO.phone_nm
               --   AND BILLING.marca = CARTERA_RENUEVO.marca
               --   AND BILLING.service_id = CARTERA_RENUEVO.service_id  

     LEFT JOIN `mm-commissions-reporting.TEMP.suspension_servicio_cartera` SUSPENSION
               ON BILLING.customer_id = SUSPENSION.customer_id
               AND BILLING.marca = SUSPENSION.brand_ds
               AND BILLING.invoice_id = SUSPENSION.invoice_id
     
     WHERE 1=1 
      --      AND BILLING.status IN ('PAID', 'RECOLLECTED')
           AND (
               (DEALER.canal = 'ENK' AND CARTERA_RENUEVO.phone_nm IS NULL)
               OR
               DEALER.canal != 'ENK'
               )
          --  AND BILLING.importe_facturado > 0
           AND BLACKLIST.sfid IS NULL
           AND SUSPENSION.customer_id IS NULL
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
     
-- WHERE COALESCE(comision, 0.0) > 0.0
WHERE comision IS NOT NULL
AND comision <> 0.0
GROUP BY 2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_facturacion_3m` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

(
SELECT
      BILLING.invoice_id
     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.service_id
     ,BILLING.brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE BILLING.data_month_id = id_mes_periodo_facturado_3m
      AND BILLING.phone_nm IS NOT NULL
      AND BILLING.brand_ds IS NOT NULL

GROUP BY 1,2,3,4,5

UNION ALL

SELECT
      BILLING.invoice_id
     ,CAST(NULL AS STRING) AS phone_nm
     ,BILLING.service_id
     ,'PEPEPHONE' AS brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

FROM `mm-datamart-kd.BILLING.billing_detail_heos` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.cartx_billing_status_heos` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.id_factura

WHERE BILLING.data_month_id = id_mes_periodo_facturado_3m
      AND BILLING.service_id IS NOT NULL

GROUP BY 1,2,3,4,5
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartx_unpaid`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
     prefijo|| 'E' || '_' || mes_string || '_' || 'ENK' || '_' || ROW_NUMBER() OVER () AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,TRANSACCIONES_DETALLE.agrupacion_canal AS agrupacion_canal
      ,TRANSACCIONES_DETALLE.canal
      ,'E - Clawback '|| SUBSTR(TRANSACCIONES_DETALLE.concepto,5) AS concepto
      ,TRANSACCIONES_DETALLE.tipo_concepto
      ,1 as unidades
      ,TRANSACCIONES.sum_comision * -1 as comision
      ,TRANSACCIONES_DETALLE.seller AS id_comisionista
      ,'BYMOVIL' AS distribuidor 
      ,TRANSACCIONES_DETALLE.seller AS sfid_id
      ,TRANSACCIONES_DETALLE.seller
      ,TRANSACCIONES_DETALLE.nombre_comercio
      ,TRANSACCIONES_DETALLE.razon_social
      ,TRANSACCIONES_DETALLE.cif
      ,TRANSACCIONES_DETALLE.zona_fiscal
      ,TRANSACCIONES_DETALLE.marca
      ,TRANSACCIONES.service_type
      ,TRANSACCIONES_DETALLE.phone_nm
      ,TRANSACCIONES_DETALLE.tariff_id
      ,TRANSACCIONES_DETALLE.tariff_ds
      ,TRANSACCIONES_DETALLE.service_id
      ,TRANSACCIONES_DETALLE.account_id
      ,TRANSACCIONES_DETALLE.customer_id
      ,TRANSACCIONES_DETALLE.line_type_ds
      ,TRANSACCIONES_DETALLE.bundle_type
      ,TRANSACCIONES_DETALLE.technology_ds
      ,TRANSACCIONES_DETALLE.billing_type_ds
      ,TRANSACCIONES_DETALLE.sale_date
      ,TRANSACCIONES_DETALLE.activation_date
      ,TRANSACCIONES_DETALLE.deactivation_date
      ,TRANSACCIONES_DETALLE.order_id
      ,TRANSACCIONES_DETALLE.order_type_agg
      ,TRANSACCIONES_DETALLE.cod_segmento
      ,TRANSACCIONES_DETALLE.cod_marca
      ,TRANSACCIONES_DETALLE.cod_tipo_contrato
      ,TRANSACCIONES_DETALLE.cod_producto
      ,TRANSACCIONES_DETALLE.cod_canal
      ,TRANSACCIONES_DETALLE.campaign_code
      ,TRANSACCIONES_DETALLE.serial_number
      ,TRANSACCIONES.sum_tax_base AS tax_base
      ,CAST(null AS STRING) AS claim_code
      ,TRANSACCIONES.process_code
      ,'Impago Cartera '|| CAST(id_mes_periodo_facturado_3m AS STRING) AS comments
      ,'C_MANUAL' AS facturador

FROM (
     SELECT phone_nm, service_id, brand_ds
     FROM `mm-commissions-reporting.TEMP.cartx_facturacion_3m`
     WHERE status NOT IN ('PAID', 'RECOLLECTED')
     GROUP BY 1,2,3
     ) UNPAID

INNER JOIN (
           SELECT service_id, phone_nm, marca, service_type, activation_date, sum(comision) as sum_comision, sum(tax_base) as sum_tax_base, process_code
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE id_mes = CAST(FORMAT_DATE('%Y%m',DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_periodo_facturado_3m AS STRING)), INTERVAL 1 MONTH)) AS INT64)
                 AND agrupacion_canal IN ('Exclusivo')
                 AND canal = 'ENK'
                 AND commission_id LIKE '%CARTX%'
               --   AND comments NOT LIKE 'Reg. Cartera impagada%' -- DESCOMENTAR PARA REGULARIZAR ANTES DE 202601
           GROUP BY 1,2,3,4,5,8
           ) TRANSACCIONES
          ON CASE WHEN UNPAID.brand_ds = 'PEPEPHONE' THEN UNPAID.service_id ELSE UNPAID.phone_nm END
             =
             CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
             AND UNPAID.service_id = TRANSACCIONES.service_id
             AND UNPAID.brand_ds = TRANSACCIONES.marca

LEFT JOIN ( -- BUSCAR UN SÓLO REGISTRO PARA ASIGNARLE LA SUM(COMISION)
            SELECT * EXCEPT(commission_id,comision)
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE agrupacion_canal = 'Exclusivo'
            AND concepto LIKE '% - Cartera 4%'
            AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_periodo_facturado_3m AS STRING)), INTERVAL 1 MONTH)) AS INT64)
          --   AND comments NOT LIKE 'Reg. Cartera impagada%' -- DESCOMENTAR PARA REGULARIZAR ANTES DE 202601
            GROUP BY ALL
            QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca, activation_date, service_type) = 1
          ) TRANSACCIONES_DETALLE
           ON TRANSACCIONES_DETALLE.phone_nm = TRANSACCIONES.phone_nm
           AND TRANSACCIONES_DETALLE.marca = TRANSACCIONES.marca
           AND TRANSACCIONES_DETALLE.activation_date = TRANSACCIONES.activation_date
           AND TRANSACCIONES_DETALLE.service_type = TRANSACCIONES.service_type

WHERE seller IS NOT NULL
)
;

--  *********************************************************************************
--   COMENTAR DESPUÉS DE REVISAR DUPLICADOS CON QUERY CARTERA RENUEVO VS CAPATACIÓN
--  *********************************************************************************
ASSERT NOT EXISTS (
     SELECT *
     FROM `mm-commissions-reporting.TEMP.cartx` a
     INNER JOIN (SELECT phone_nm FROM `mm-commissions-reporting.COMISIONES.transacciones` WHERE commission_id LIKE 'CARNV_20%' AND id_mes = id_mes_pr) b --Añado CARNV_20 para evitar que tome Clawback
          ON a.phone_nm = b.phone_nm
     WHERE a.id_mes = id_mes_pr
     AND a.concepto = 'C - Cartera 4%'
) AS 'Hay cálculo de Cartera 4% para phone_nm con Cartera Renuevo'
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, ['EYG','EML','ENX','ENK'], 'TEMP.cartx', 'ACTUALIZAR');

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CARTXE', id_mes_pr, ['ENK'], 'TEMP.cartx_unpaid', 'ACTUALIZAR');


END