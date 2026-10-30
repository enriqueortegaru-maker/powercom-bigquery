BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado, mes_periodo_facturado_3m DATE;
DECLARE id_mes_periodo_facturado, id_mes_periodo_facturado_3m INT64;



SET prefijo = 'CARNV';

SET mes_string = CAST(id_mes_pr AS STRING);

IF canales_pr IS NULL THEN SET canales_pr = ['PH','ENK'];
END IF;

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET mes_periodo_facturado_3m = DATE_ADD(mes_periodo_facturado, INTERVAL  - 4 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);

SET id_mes_periodo_facturado_3m = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_3m) AS INT64);



-- CALL COMISIONES.pr_carnv(202606,['ENK']);



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnv_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnv_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
group by 1,2,3,4
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnv_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      '' AS agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,VENTAS.user_store
     ,'QVANTEL' AS data_source_ds
     ,'YOIGO' AS marca
     
     ,CASE
          WHEN BILLING.bill_id LIKE '%CONVDISC%'    THEN 'INTERNET'
          WHEN BILLING.bill_id LIKE 'FH%DISC%'      THEN 'INTERNET'
          WHEN BILLING.service_type = 'FIX'         THEN 'INTERNET'
          WHEN BILLING.service_type = 'BROADBAND'   THEN 'INTERNET'
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
     ,VENTAS.order_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,VENTAS.order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca

     ,CASE
          WHEN VENTAS.billing_type_ds = 'PREPAID'
          THEN '10'

          WHEN VENTAS.bundle_type = 'FMC' AND VENTAS.line_type_ds = 'MAIN'
          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)

          WHEN VENTAS.bundle_type = 'FMC'
          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)

          WHEN VENTAS.bundle_type = 'MO'  AND VENTAS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND VENTAS.brand_ds IN ('YOIGO')
          THEN '68'

          ELSE '20'
      END AS cod_tipo_contrato

     ,'050' AS cod_producto
     ,VENTAS.codigo_canal_sap AS cod_canal
     ,VENTAS.serial_number

     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,VENTAS.compromiso_permanencia
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,BILLING.invoice_id
     ,CAST(null AS DATE) last_service_activation
     ,CAST(FORMAT_DATE('%Y%m',VENTAS.order_date) AS INT64) AS id_mes_renuevo
     ,DEALER.id_mes AS id_mes_dealer

FROM `mm-datamart-kd.BILLING.billing_detail_qvantel` BILLING

INNER JOIN (
           SELECT RENUEVOS.*, AGRUPACION.codigo_canal_sap
      --      FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
      FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(RENUEVOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND RENUEVOS.master_channel_ds = AGRUPACION.master_channel_ds
            AND RENUEVOS.channel_ds = AGRUPACION.channel_ds
            AND RENUEVOS.subchannel_ds = AGRUPACION.subchannel_ds
            AND RENUEVOS.brand_ds = AGRUPACION.comm_brand_ds

           WHERE brand_ds = 'YOIGO'
                 AND activation_date IS NOT NULL
                 AND DATE_TRUNC(activation_date, MONTH) BETWEEN DATE_SUB(mes_periodo_facturado, INTERVAL 18 MONTH) AND mes_periodo_facturado
                 AND COALESCE(deactivation_date, '2100-01-01') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH)
                 AND AGRUPACION.agrupacion_canal IN ('Exclusivo','No Exclusivo')
                 AND RENUEVOS.sell_type = 'RENUEVO'
           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC,

                                              RENUEVOS.deactivation_date ASC,
                                              RENUEVOS.original_cost_price DESC,
                                              RENUEVOS.serial_number ASC                                              
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm 

LEFT JOIN `mm-commissions-reporting.TEMP.carnv_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carnv_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
             VENTAS.sfid_id = DEALER.sfid_id 
            OR VENTAS.seller = DEALER.sfid_id
            )

WHERE data_month_id = id_mes_periodo_facturado
      AND DEALER.canal = 'ENK'
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
         AND BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,32,33,34,35
HAVING id_mes_renuevo = id_mes_dealer

UNION ALL

SELECT
      '' AS agrupacion_canal
     ,VENTAS.sfid_id
     ,VENTAS.seller
     ,VENTAS.user_store
     ,'MYSIM' AS data_source_ds
     ,VENTAS.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH')         THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING_DETAIL.tariff_id
     ,BILLING_DETAIL.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,VENTAS.technology_ds
     ,VENTAS.billing_type_ds
     ,VENTAS.order_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,VENTAS.order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca

     ,CASE
          WHEN VENTAS.billing_type_ds = 'PREPAID'
          THEN '10'

          WHEN VENTAS.bundle_type = 'FMC' AND VENTAS.line_type_ds = 'MAIN'
          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)

          WHEN VENTAS.bundle_type = 'FMC'
          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)

          WHEN VENTAS.bundle_type = 'MO'  AND VENTAS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND VENTAS.brand_ds IN ('YOIGO')
          THEN '68'

          ELSE '20'
      END AS cod_tipo_contrato

     ,'050' AS cod_producto
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(VENTAS.channel_ds, VENTAS.subchannel_ds) AS cod_canal
     ,VENTAS.serial_number

     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,VENTAS.compromiso_permanencia
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,BILLING.invoice_id
     ,VENTAS.last_service_activation
     ,CAST(FORMAT_DATE('%Y%m',VENTAS.order_date) AS INT64) AS id_mes_renuevo
     ,DEALER.id_mes AS id_mes_dealer

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT SALES.activation_date AS last_service_activation, RENUEVOS.*
           FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

           INNER JOIN (
                  SELECT *
                  FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` 
                  WHERE TRUE
                  -- AND comisionamiento = 'Comisiona'
                  AND marca IN ('YOIGO', 'MASMOVIL')
                        AND activation_date IS NOT NULL
                        AND activation_date < COMISIONES.f_mes_int (id_mes_pr) -- PARA DEJAR DE CALCULAR CARTERA ID_MES_PR A PARTIR DE LIQUI 202606

                  QUALIFY ROW_NUMBER() OVER (
                                          PARTITION BY phone_nm, brand_ds -- 20260708 JD: Agrego marca para incluir ambas marcas en el mismo mes en portas. Ej: phone_nm 600027808
                                          ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO','HLR') THEN 1 ELSE 2 END ASC,
                                               
                                                   CASE WHEN COALESCE(deactivation_date, '9999-12-31') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

                                                   CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                                   CASE WHEN activation_date < mes_periodo_facturado THEN activation_date END DESC,
                                                   CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

                                                   CASE WHEN activation_date >= mes_periodo_facturado THEN activation_date END ASC,
                                                   CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END ASC
                                          ) = 1
                  ) SALES
                  ON SALES.phone_nm = RENUEVOS.phone_nm
                  AND SALES.marca = RENUEVOS.brand_ds

      --      LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
      --               ON COALESCE(SALES.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
      --                  AND SALES.master_channel_ds = AGRUPACION.master_channel_ds
      --                  AND SALES.channel_ds = AGRUPACION.channel_ds
      --                  AND SALES.subchannel_ds = AGRUPACION.subchannel_ds
      --                  AND SALES.brand_ds = AGRUPACION.comm_brand_ds

           WHERE RENUEVOS.activation_date IS NOT NULL
                 AND DATE_TRUNC(RENUEVOS.activation_date, MONTH) BETWEEN DATE_SUB(mes_periodo_facturado, INTERVAL 18 MONTH) AND mes_periodo_facturado
                 AND COALESCE(RENUEVOS.deactivation_date, '2100-01-01') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH)
                 AND DATE_TRUNC(SALES.deactivation_date, MONTH) >= mes_periodo_facturado
                 AND SALES.activation_date <= RENUEVOS.order_date
            --      AND AGRUPACION.agrupacion_canal IN ('Exclusivo','No Exclusivo')
                 AND RENUEVOS.agrupacion_canal IN ('Exclusivo','No Exclusivo')
            --      AND RENUEVOS.sell_type = 'RENUEVO' -- 20260713 JD: Comento y meto sell_type en QUALIFY para que traiga el dispositivo más reciente. Filtramos renuevos en la TEMP.carnv
           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END DESC,

                                              CASE WHEN sell_type = 'RENUEVO' THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(activation_date, '2100-01-01') END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '2100-01-01') END ASC,

                                              RENUEVOS.deactivation_date ASC,
                                              RENUEVOS.original_cost_price DESC,
                                              RENUEVOS.serial_number ASC
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm
            AND BILLING.brand_ds = VENTAS.brand_ds

LEFT JOIN (  SELECT *
             FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
             WHERE data_month_id = id_mes_periodo_facturado
             QUALIFY ROW_NUMBER() OVER (
                                       PARTITION BY phone_nm
                                       ORDER BY movement_date DESC
                                       ) = 1
          ) BILLING_DETAIL
          ON BILLING_DETAIL.phone_nm = BILLING.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.carnv_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carnv_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
             VENTAS.sfid_id = DEALER.sfid_id 
            OR VENTAS.seller = DEALER.sfid_id
            )

WHERE BILLING.data_month_id = id_mes_periodo_facturado
      AND BILLING.init_date >= VENTAS.last_service_activation
      AND DEALER.canal = 'ENK'
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
         AND BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         ((
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET', 'BROADBAND') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         )
         AND BILLING.data_month_id < 202500)
         OR
         (          
         BILLING.data_month_id > 202500
         AND NOT REGEXP_CONTAINS(BILLING.movtype_ds, r'FINANCIACION|PENALIZACI|XCF|SEGURO|DEFERENCIA|AJUSTE|DEVOLUCION')
         AND BILLING.service_type IN ('FIX','INTERNET','BROADBAND')
         AND (CONCEPTOS.bill_id LIKE '%DESCUENTO%' OR CONCEPTOS.bill_id LIKE '%DTO%' OR CONCEPTOS.bill_id LIKE '%X 12 MESES S/P%' OR CONCEPTOS.bill_id LIKE '%T&B%')  )
          -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,32,33,34,35
HAVING id_mes_renuevo = id_mes_dealer
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.robos_otras_agrupaciones` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT *
FROM `mm-commissions-reporting.TEMP.multidispositivos_final_nc`
WHERE canal IN ('ALTN','PH')
AND brand_ds IN ('YOIGO','MASMOVIL')
AND multidispositivo = 'PRIMARIO'
AND compromiso_permanencia = 'SI'
AND order_date >= '2025-07-01'
GROUP BY ALL
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnv` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT CARTERA.*
FROM
( ----- CARTERA RENUEVO PH ----------     
      SELECT 
      prefijo || '_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id 
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,CAST(mes_string AS INT64) AS id_mes
      ,DEALER.agrupacion_canal
      ,DEALER.canal

      ,'C - Cartera Renuevo' AS concepto

      ,'AIRT' AS tipo_concepto
      ,1 as unidades
      ,BILLING.importe_facturado * 0.01 AS comision
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
      ,CAST(BILLING.order_id AS STRING) as order_id
      ,BILLING.order_type_agg
      ,BILLING.cod_segmento
      ,BILLING.cod_marca
      ,BILLING.cod_tipo_contrato
      ,BILLING.cod_producto
      ,BILLING.cod_canal
      ,CAST(NULL AS STRING)  AS campaign_code
      ,BILLING.serial_number AS serial_number
      ,BILLING.importe_facturado AS tax_base
      ,CAST(NULL AS STRING)  AS claim_code
      ,CAST(NULL AS STRING)  AS process_code
      ,CAST(NULL AS STRING)  AS comments
      ,'C_MANUAL' AS facturador

      FROM (
      SELECT *
      FROM `mm-commissions-reporting.TEMP.carnv_billing`
      WHERE data_source_ds IN ('MYSIM', 'QVANTEL')
      QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, marca, service_type
                                    ORDER BY CASE
                                                WHEN data_source_ds = 'MYSIM' THEN 1
                                                WHEN data_source_ds = 'QVANTEL' THEN 2
                                          END ASC
                                    ) = 1
      ) BILLING

      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
            ON (
                  BILLING.sfid_id = DEALER.sfid_id 
                  OR BILLING.seller = DEALER.sfid_id
                  )
                  -- AND BILLING.agrupacion_canal = DEALER.agrupacion_canal
                  
      -- CROSS JOIN UNNEST(canales_pr) AS canal_pr

      WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
            AND BILLING.importe_facturado > 0
            -- AND DEALER.CANAL = canal_pr
            AND DEALER.CANAL = 'PH'

      QUALIFY ROW_NUMBER () OVER (PARTITION BY service_id, phone_nm, marca) = 1


UNION ALL


----- CARTERA RENUEVO ENK ----------        
      SELECT 
       prefijo || '_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id 
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,CAST(mes_string AS INT64) AS id_mes
      ,DEALER.agrupacion_canal
      ,DEALER.canal

      ,'C - Cartera Renuevo' AS concepto

      ,'AIRT' AS tipo_concepto
      ,1 as unidades

      ,CASE  
           WHEN DEALER.CANAL = 'ENK' AND DEALER.comisiona = true  AND MULTIDISPOSITIVOS.multidispositivo = 'PRIMARIO'   THEN importe_facturado * 0.04
           WHEN DEALER.CANAL = 'ENK' AND DEALER.comisiona = true  AND MULTIDISPOSITIVOS.multidispositivo = 'SECUNDARIO' THEN importe_facturado * 0.00
           WHEN DEALER.CANAL = 'ENK' AND DEALER.comisiona = false                                                       THEN importe_facturado * 0.00 
      END AS comision

      ,DEALER.id_comisionista
      ,DEALER.distribuidor
      ,MULTIDISPOSITIVOS.seller AS sfid_id -- REEMPLAZAMOS EL DE BILLING POR EL ÚLTIMO QUE ROBA
      ,MULTIDISPOSITIVOS.seller -- REEMPLAZAMOS EL DE BILLING POR EL ÚLTIMO QUE ROBA
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
      ,CAST(BILLING.order_id AS STRING) as order_id
      ,BILLING.order_type_agg
      ,BILLING.cod_segmento
      ,BILLING.cod_marca
      ,BILLING.cod_tipo_contrato
      ,BILLING.cod_producto
      ,BILLING.cod_canal
      ,CAST(NULL AS STRING)  AS campaign_code
      ,BILLING.serial_number AS serial_number
      ,BILLING.importe_facturado AS tax_base
      ,CAST(NULL AS STRING)  AS claim_code
      ,BILLING.invoice_id AS process_code
      ,CAST(NULL AS STRING)  AS comments
      ,'C_MANUAL' AS facturador

      FROM (
      SELECT * 
      FROM `mm-commissions-reporting.TEMP.carnv_billing`
      WHERE data_source_ds IN ('MYSIM', 'QVANTEL')
      GROUP BY ALL
      QUALIFY RANK() OVER (
                                    PARTITION BY phone_nm, marca, service_type
                                    ORDER BY CASE
                                                WHEN data_source_ds = 'MYSIM' THEN 1
                                                WHEN data_source_ds = 'QVANTEL' THEN 2
                                          END ASC
                                    ) = 1
      ) BILLING

      -- LEFT JOIN (
      --     SELECT RENUEVOS.serial_number
      -- --     FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
      --     FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS
      --     WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      --           AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 2 MONTH)
      --       --     AND financed_type = 'PAGO FINANCIADO'
      --           AND is_financed_desc = 'SI'
      --           AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 4 MONTH)
      --           AND RENUEVOS.serial_number IS NOT NULL
      --           AND RENUEVOS.sell_type = 'RENUEVO'
      --     QUALIFY ROW_NUMBER() OVER (
      --                               PARTITION BY phone_nm, brand_ds
      --                               ORDER BY RENUEVOS.activation_date ASC,
      --                                        RENUEVOS.deactivation_date ASC,
      --                                        RENUEVOS.original_cost_price DESC,
      --                                        RENUEVOS.serial_number ASC
      --                               ) = 1
      --     ) PRIMARIOS
      --    ON BILLING.serial_number = PRIMARIOS.serial_number

      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
            ON (
                  BILLING.sfid_id = DEALER.sfid_id 
                  OR BILLING.seller = DEALER.sfid_id
                  )
                  -- AND BILLING.agrupacion_canal = DEALER.agrupacion_canal

      LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final_nc` MULTIDISPOSITIVOS
        ON BILLING.phone_nm = MULTIDISPOSITIVOS.phone_nm 
            AND BILLING.marca = MULTIDISPOSITIVOS.brand_ds
            AND BILLING.sale_date = MULTIDISPOSITIVOS.order_date
            AND DEALER.sfid_id = MULTIDISPOSITIVOS.seller
                  
      LEFT JOIN `mm-commissions-reporting.TEMP.robos_otras_agrupaciones` ROBOS 
            ON BILLING.phone_nm = ROBOS.phone_nm
               AND BILLING.marca = ROBOS.brand_ds
               AND BILLING.sale_date < ROBOS.order_date
               AND DEALER.sfid_id = ROBOS.seller
      CROSS JOIN UNNEST(canales_pr) AS canal_pr

      WHERE 1 = 1
            -- AND BILLING.status IN ('PAID', 'RECOLLECTED') -- SE REVISA EN N+4
            AND BILLING.importe_facturado > 0
            -- AND DEALER.CANAL = canal_pr
            AND DEALER.CANAL = 'ENK' 
            AND MULTIDISPOSITIVOS.order_date >= '2025-07-01' 
            AND BILLING.compromiso_permanencia = 'SI'
            AND MULTIDISPOSITIVOS.multidispositivo = 'PRIMARIO'
            AND MULTIDISPOSITIVOS.sell_type = 'RENUEVO'
            AND (ROBOS.phone_nm IS NULL OR BILLING.sale_date > ROBOS.order_date)
        
      QUALIFY ROW_NUMBER () OVER (PARTITION BY MULTIDISPOSITIVOS.phone_nm, MULTIDISPOSITIVOS.brand_ds ORDER BY MULTIDISPOSITIVOS.activation_date DESC) = 1
      -- QUALIFY ROW_NUMBER () OVER (PARTITION BY service_id, phone_nm, marca) = 1
) CARTERA 

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
            ON (
                  CARTERA.sfid_id = DEALER.sfid_id 
                  OR CARTERA.seller = DEALER.sfid_id
                  )

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE comision <> 0.00
AND DEALER.canal = canal_pr
AND DEALER.comisiona
)
;

------------------------------------------------------------
-- BILLING N+4 PARA IMPAGO CARTERA NUEVO MR EXCLUSIVO - ENK
------------------------------------------------------------

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnv_facturacion_3m` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

(
SELECT
      BILLING.invoice_id
     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     -- ,CAST(NULL AS STRING) AS service_id
     ,BILLING.service_id
     ,BILLING.brand_ds
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status

     -- ,CASE WHEN COALESCE(BILLING_STATUS.status, 'PAID') NOT IN ('PAID', 'RECOLLECTED') THEN 1 ELSE 0 END AS unpaid

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

LEFT JOIN `mm-commissions-reporting.TEMP.carnv_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE BILLING.data_month_id = id_mes_periodo_facturado_3m
      AND BILLING.phone_nm IS NOT NULL
      AND BILLING.brand_ds IS NOT NULL

GROUP BY 1,2,3,4,5
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carnv_unpaid`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
     prefijo|| 'E' || '_' || mes_string || '_' || 'ENK' || '_' || ROW_NUMBER() OVER () AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,TRANSACCIONES_DETALLE.agrupacion_canal AS agrupacion_canal
      ,TRANSACCIONES_DETALLE.canal
      ,'E - Clawback Cartera Renuevo' AS concepto
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
     FROM `mm-commissions-reporting.TEMP.carnv_facturacion_3m`
     WHERE status NOT IN ('PAID', 'RECOLLECTED')
     GROUP BY 1,2,3
     ) UNPAID

INNER JOIN (
           SELECT service_id, phone_nm, serial_number, marca, service_type, activation_date, sum(comision) as sum_comision, sum(tax_base) as sum_tax_base, process_code
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE id_mes = CAST(FORMAT_DATE('%Y%m',DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_periodo_facturado_3m AS STRING)), INTERVAL 1 MONTH)) AS INT64)
                 AND agrupacion_canal IN ('Exclusivo')
                 AND canal = 'ENK'
                 AND commission_id LIKE '%CARNV%'
               --   AND comments NOT LIKE 'Reg. Cartera impagada%' -- DESCOMENTAR PARA REGULARIZAR ANTES DE 202601
           GROUP BY 1,2,3,4,5,6,9
           ) TRANSACCIONES
          ON UNPAID.phone_nm = TRANSACCIONES.phone_nm
             AND UNPAID.service_id = TRANSACCIONES.service_id
             AND UNPAID.brand_ds = TRANSACCIONES.marca

LEFT JOIN ( -- BUSCAR UN SÓLO REGISTRO PARA ASIGNARLE LA SUM(COMISION)
            SELECT * EXCEPT(commission_id,comision)
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE agrupacion_canal = 'Exclusivo'
            AND concepto LIKE '% - Cartera Renuevo%'
            AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_periodo_facturado_3m AS STRING)), INTERVAL 1 MONTH)) AS INT64)
          --   AND comments NOT LIKE 'Reg. Cartera impagada%' -- DESCOMENTAR PARA REGULARIZAR ANTES DE 202601
            GROUP BY ALL
            QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca, activation_date, service_type) = 1
          ) TRANSACCIONES_DETALLE
           ON TRANSACCIONES_DETALLE.serial_number = TRANSACCIONES.serial_number
           AND TRANSACCIONES_DETALLE.phone_nm = TRANSACCIONES.phone_nm
           AND TRANSACCIONES_DETALLE.marca = TRANSACCIONES.marca
           AND TRANSACCIONES_DETALLE.activation_date = TRANSACCIONES.activation_date
           AND TRANSACCIONES_DETALLE.service_type = TRANSACCIONES.service_type

WHERE seller IS NOT NULL
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr, 'TEMP.carnv', 'ACTUALIZAR');

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CARNVE', id_mes_pr, canales_pr, 'TEMP.carnv_unpaid', 'ACTUALIZAR');



END