BEGIN

DECLARE sql, mes_string, prefijo STRING;

SET mes_string = CAST(mes_pr AS STRING);

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo); 

IF canales_pr IS NULL THEN SET canales_pr = ['ENK'];
END IF;


/*
CALL COMISIONES.pr_financiaciones_exc_nva_categ(202603, ['ENK'], NULL);
*/

--- Creamos tabla con el PVP de tarifas (Para canal Exclusivo) ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pvp_bundles` AS (
  WITH mandatory AS (
    SELECT
      brand_ds,
      'MANDATORY' AS product_scope,
      bundle_id,
      name,

      CASE 
          WHEN product.product_type = 'POST-PAGO' THEN product.product_tariff_id
          WHEN product.product_type = 'INTERNET FTTH' AND category = 'Fixed+Broadband' THEN bundle_id
          ELSE CAST(null as STRING)
      END AS main_mobile_tariff_id,
      
      CASE 
          WHEN product.product_type = 'POST-PAGO' THEN product.product_name
          WHEN product.product_type = 'INTERNET FTTH' AND category = 'Fixed+Broadband' THEN name
          ELSE CAST(null as STRING)
      END AS main_mobile_tariff_name,


      bundle_pre_tax_amount,
    FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
      UNNEST(mandatory_products) AS product
    WHERE is_actual = 1 AND init_date >= "2024-08-01"
    GROUP BY ALL
    HAVING main_mobile_tariff_id IS NOT NULL
  ),
  nonmandatory AS (
    SELECT
      brand_ds,
      'NONMANDATORY' AS product_scope,
      bundle_id,
      name,

      CASE 
          WHEN product.product_type = 'POST-PAGO' THEN product.product_tariff_id
          WHEN product.product_type = 'INTERNET FTTH' AND category = 'Fixed+Broadband' THEN bundle_id
          ELSE CAST(null as STRING)
      END AS main_mobile_tariff_id,
      
      CASE 
          WHEN product.product_type = 'POST-PAGO' THEN product.product_name
          WHEN product.product_type = 'INTERNET FTTH' AND category = 'Fixed+Broadband' THEN name
          ELSE CAST(null as STRING)
      END AS main_mobile_tariff_name,


      bundle_pre_tax_amount,
    FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
      UNNEST(nonmandatory_products) AS product
    WHERE is_actual = 1 AND init_date >= "2024-08-01"
    GROUP BY ALL
    HAVING main_mobile_tariff_id IS NOT NULL
  )
  
  SELECT *
  FROM mandatory
  UNION ALL
  SELECT *
  FROM nonmandatory
)
;


---- Tabla de Finaciaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.financiaciones_exc_nva_categ`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  SELECT
     'calculado' AS estado
    --  ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,DATE_TRUNC(FINANCIACIONES.activation_date,MONTH) AS mes_liquidado
     ,mes_pr AS id_mes
     ,AGRUPACION.agrupacion_canal
     ,DEALER.canal
     ,concepto
     ,tipo_concepto
     ,1 AS unidades
    ,`mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
        DEALER.canal
        ,FINANCIACIONES.brand_ds
        ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
        ,FINANCIACIONES.bundle_type
        ,PVP_BUNDLES.bundle_pre_tax_amount) AS comision
      --- vendedor ---
     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,FINANCIACIONES.user_store AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,FINANCIACIONES.brand_ds AS marca
     ,'MOBILE' AS service_type
     ,CAST(FINANCIACIONES.phone_nm AS STRING) AS phone_nm    
     ,PVP_BUNDLES.bundle_id AS tariff_id
     ,PVP_BUNDLES.name AS tariff_ds      
     ,FINANCIACIONES.service_id
     ,FINANCIACIONES.account_id
     ,FINANCIACIONES.customer_id
     ,FINANCIACIONES.line_type_ds
     ,FINANCIACIONES.bundle_type
     ,FINANCIACIONES.technology_ds
     ,COALESCE(FINANCIACIONES.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,FINANCIACIONES.order_date AS sale_date
     ,FINANCIACIONES.activation_date
     ,FINANCIACIONES.deactivation_date
     ,CAST(FINANCIACIONES.order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(FINANCIACIONES.segment_ds, FINANCIACIONES.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(FINANCIACIONES.brand_ds) AS cod_marca

     ,CASE
          WHEN FINANCIACIONES.billing_type_ds = 'PREPAID'                                                                                                          THEN '10'
          WHEN FINANCIACIONES.bundle_type = 'FMC' AND FINANCIACIONES.line_type_ds = 'MAIN'                                                                         THEN (CASE WHEN FINANCIACIONES.sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN FINANCIACIONES.bundle_type = 'FMC'                                                                                                                  THEN (CASE WHEN FINANCIACIONES.sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN FINANCIACIONES.bundle_type = 'MO'  AND FINANCIACIONES.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND FINANCIACIONES.brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,'050' AS cod_producto
     ,AGRUPACION.codigo_canal_sap AS cod_canal
      --- informacion adicional ---
     ,CAST(NULL AS STRING)  AS campaign_code
     ,FINANCIACIONES.serial_number
     ,PVP_BUNDLES.bundle_pre_tax_amount AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(FINANCIACIONES.brand_ds) AS sociedad
     , 'PAGO FINANCIADO' AS financed_type
     ,FINANCIACIONES.device_type

  FROM `mm-commissions-reporting.COMISIONES.v_servicio_financiaciones` FINANCIACIONES

  LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
          ON COALESCE(FINANCIACIONES.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
              AND FINANCIACIONES.master_channel_ds = AGRUPACION.master_channel_ds
              AND FINANCIACIONES.channel_ds = AGRUPACION.channel_ds
              AND FINANCIACIONES.subchannel_ds = AGRUPACION.subchannel_ds
              AND FINANCIACIONES.brand_ds = AGRUPACION.comm_brand_ds

  INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
            ON AGRUPACION.agrupacion_canal IN ('Exclusivo')
              AND CONCEPTOS.id_prefijo = 'FINA'

  -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
          ON (
              FINANCIACIONES.sfid_id = DEALER.sfid_id 
              OR (FINANCIACIONES.brand_ds = 'YOIGO' AND SUBSTR(FINANCIACIONES.sfid_id, 1, 2) = DEALER.sfid_id)
              OR FINANCIACIONES.seller = DEALER.sfid_id
              OR FINANCIACIONES.user_store = DEALER.sfid_id
              )
              AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
              -- AND DEALER.id_mes = mes_pr

  INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
            ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
              AND DEALER.canal = CHANNEL.canal

  LEFT JOIN (
            SELECT DISTINCT phone_nm, sale_date
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE id_mes < mes_pr
                  AND (concepto LIKE '%Dispositivo Financiado%' OR concepto LIKE '%Financiacion terminales%' OR concepto LIKE '%Extracomision terminal%')
            ) TRANSACCIONES
          ON FINANCIACIONES.phone_nm = TRANSACCIONES.phone_nm
              AND FINANCIACIONES.order_date = TRANSACCIONES.sale_date

  LEFT JOIN (SELECT phone_nm, service_id, brand_ds, sell_bundle_id, sell_bundle_name, activation_date FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` GROUP BY ALL) VENTAS
          ON FINANCIACIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) AND FINANCIACIONES.brand_ds = VENTAS.brand_ds AND FINANCIACIONES.service_id = VENTAS.service_id 

  LEFT JOIN (SELECT data_month_id, phone_nm, service_id, brand_ds, bundle_id, bundle_name, init_date, end_date FROM `mm-datamart-kd.BILLING.billing_detail_emysim` GROUP BY ALL) BILLING
          ON FINANCIACIONES.phone_nm = CAST(BILLING.phone_nm AS STRING) AND FINANCIACIONES.brand_ds = BILLING.brand_ds AND FINANCIACIONES.service_id = BILLING.service_id AND BILLING.data_month_id = mes_pr AND FINANCIACIONES.activation_date BETWEEN BILLING.init_date AND BILLING.end_date

  LEFT JOIN  `mm-commissions-reporting.TEMP.pvp_bundles` PVP_BUNDLES
          ON PVP_BUNDLES.bundle_id = COALESCE(BILLING.bundle_id, CAST(VENTAS.sell_bundle_id AS STRING)) --AND PVP_BUNDLES.main_mobile_tariff_id = RENUEVOS.tariff_id

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON FINANCIACIONES.serial_number = MULTI.serial_number
             AND FINANCIACIONES.phone_nm = MULTI.phone_nm
             AND FINANCIACIONES.brand_ds = MULTI.brand_ds
             AND FINANCIACIONES.order_date = MULTI.order_date

  -- LEFT JOIN (
  --           SELECT RENUEVOS.serial_number
  --           -- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
  --           FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS
  --           WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
  --                 AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
  --                 AND financed_type = 'PAGO FINANCIADO'
  --                 AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
  --                 AND RENUEVOS.serial_number IS NOT NULL
  --                 AND RENUEVOS.sell_type = 'RENUEVO'
  --           QUALIFY ROW_NUMBER() OVER (
  --                                     PARTITION BY phone_nm, brand_ds
  --                                     ORDER BY RENUEVOS.activation_date ASC,
  --                                             RENUEVOS.deactivation_date ASC,
  --                                             RENUEVOS.original_cost_price DESC,
  --                                             RENUEVOS.serial_number ASC
  --                                     ) > 1
  --           ) MULTI
  --         ON FINANCIACIONES.serial_number = MULTI.serial_number

  CROSS JOIN UNNEST(canales_pr) AS canal_pr

  WHERE DATE_TRUNC(DATE(FINANCIACIONES.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND FINANCIACIONES.activation_date <= COALESCE(FINANCIACIONES.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND TRANSACCIONES.phone_nm IS NULL
      AND FINANCIACIONES.financed_type = 'PAGO FINANCIADO' 
      AND FINANCIACIONES.activation_date >= VENTAS.activation_date 
      AND AGRUPACION.agrupacion_canal = 'Exclusivo'
      AND FINANCIACIONES.flag_pay_penalty = 'SI'
      AND FINANCIACIONES.sell_terminal_origin_ds = 'RENUEVO'
      AND `mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
        DEALER.canal
        ,FINANCIACIONES.brand_ds
        ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
        ,FINANCIACIONES.bundle_type
        ,PVP_BUNDLES.bundle_pre_tax_amount) <> 0.0
  QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, order_id, phone_nm, FINANCIACIONES.brand_ds ORDER BY activation_date DESC) = 1


 UNION ALL


  SELECT 
     'calculado' AS estado
    --  ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,DATE_TRUNC(PAGOS_UNICOS.activation_date,MONTH) AS mes_liquidado
     ,mes_pr AS id_mes
     ,AGRUPACION.agrupacion_canal
     ,DEALER.canal
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,1 AS unidades
    ,`mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
        DEALER.canal
        ,PAGOS_UNICOS.brand_ds
        ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
        ,PAGOS_UNICOS.bundle_type
        ,PVP_BUNDLES.bundle_pre_tax_amount) AS comision
      --- vendedor ---
     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,PAGOS_UNICOS.user_store AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,PAGOS_UNICOS.brand_ds AS marca
     ,'MOBILE' AS service_type
     ,CAST(PAGOS_UNICOS.phone_nm AS STRING) AS phone_nm
     ,PVP_BUNDLES.bundle_id AS tariff_id
     ,PVP_BUNDLES.name AS tariff_ds 
     ,PAGOS_UNICOS.service_id
     ,PAGOS_UNICOS.account_id
     ,PAGOS_UNICOS.customer_id
     ,PAGOS_UNICOS.line_type_ds
     ,PAGOS_UNICOS.bundle_type
     ,PAGOS_UNICOS.technology_ds
     ,COALESCE(PAGOS_UNICOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,PAGOS_UNICOS.order_date AS sale_date
     ,PAGOS_UNICOS.activation_date
     ,PAGOS_UNICOS.deactivation_date
     ,PAGOS_UNICOS.order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(PAGOS_UNICOS.segment_ds, PAGOS_UNICOS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(PAGOS_UNICOS.brand_ds) AS cod_marca

     ,CASE
          WHEN PAGOS_UNICOS.billing_type_ds = 'PREPAID'                                                                                                      THEN '10'
          WHEN PAGOS_UNICOS.bundle_type = 'FMC' AND PAGOS_UNICOS.line_type_ds = 'MAIN'                                                                       THEN (CASE WHEN PAGOS_UNICOS.sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN PAGOS_UNICOS.bundle_type = 'FMC'                                                                                                              THEN (CASE WHEN PAGOS_UNICOS.sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN PAGOS_UNICOS.bundle_type = 'MO'  AND PAGOS_UNICOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND PAGOS_UNICOS.brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,'050' AS cod_producto
     ,AGRUPACION.codigo_canal_sap AS cod_canal
      --- informacion adicional ---
     ,CAST(NULL AS STRING)  AS campaign_code
     ,PAGOS_UNICOS.serial_number
     ,PVP_BUNDLES.bundle_pre_tax_amount AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,'Pago unico'  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(PAGOS_UNICOS.brand_ds) AS sociedad
     , 'PAGO UNICO' AS financed_type
     ,PAGOS_UNICOS.device_type


  FROM `mm-commissions-reporting.COMISIONES.v_servicio_financiaciones` PAGOS_UNICOS

  -- LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  LEFT JOIN `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES
        ON PAGOS_UNICOS.serial_number = TRANSACCIONES.serial_number AND PAGOS_UNICOS.seller = TRANSACCIONES.seller AND PAGOS_UNICOS.activation_date = TRANSACCIONES.activation_date

  LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
          ON COALESCE(PAGOS_UNICOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
              AND PAGOS_UNICOS.master_channel_ds = AGRUPACION.master_channel_ds
              AND PAGOS_UNICOS.channel_ds = AGRUPACION.channel_ds
              AND PAGOS_UNICOS.subchannel_ds = AGRUPACION.subchannel_ds
              AND PAGOS_UNICOS.brand_ds = AGRUPACION.comm_brand_ds

  INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
            ON AGRUPACION.agrupacion_canal IN ('Exclusivo')
              AND CONCEPTOS.id_prefijo = 'FINA'

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
          ON (
              PAGOS_UNICOS.sfid_id = DEALER.sfid_id 
              OR (PAGOS_UNICOS.brand_ds = 'YOIGO' AND SUBSTR(PAGOS_UNICOS.sfid_id, 1, 2) = DEALER.sfid_id)
              OR PAGOS_UNICOS.seller = DEALER.sfid_id
              OR PAGOS_UNICOS.user_store = DEALER.sfid_id
              )
              AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal

  INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
            ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
              AND DEALER.canal = CHANNEL.canal

  LEFT JOIN (
            SELECT DISTINCT phone_nm, sale_date
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE id_mes < mes_pr
                  AND (concepto LIKE '%Dispositivo Financiado%' OR concepto LIKE '%Financiacion terminales%' OR concepto LIKE '%Extracomision terminal%')
            ) CHECK_TRANSACCIONES
          ON PAGOS_UNICOS.phone_nm = CHECK_TRANSACCIONES.phone_nm
              AND PAGOS_UNICOS.order_date = CHECK_TRANSACCIONES.sale_date

  LEFT JOIN (SELECT phone_nm, service_id, brand_ds, sell_bundle_id, sell_bundle_name, activation_date FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` GROUP BY ALL) VENTAS
          ON PAGOS_UNICOS.phone_nm = CAST(VENTAS.phone_nm AS STRING) AND PAGOS_UNICOS.brand_ds = VENTAS.brand_ds AND PAGOS_UNICOS.service_id = VENTAS.service_id 

  LEFT JOIN (SELECT data_month_id, phone_nm, service_id, brand_ds, bundle_id, bundle_name, init_date, end_date FROM `mm-datamart-kd.BILLING.billing_detail_emysim` GROUP BY ALL) BILLING
          ON PAGOS_UNICOS.phone_nm = CAST(BILLING.phone_nm AS STRING) AND PAGOS_UNICOS.brand_ds = BILLING.brand_ds AND PAGOS_UNICOS.service_id = BILLING.service_id AND BILLING.data_month_id = mes_pr AND PAGOS_UNICOS.activation_date BETWEEN BILLING.init_date AND BILLING.end_date

  LEFT JOIN  `mm-commissions-reporting.TEMP.pvp_bundles` PVP_BUNDLES
          ON PVP_BUNDLES.bundle_id = COALESCE(BILLING.bundle_id, CAST(VENTAS.sell_bundle_id AS STRING)) --AND PVP_BUNDLES.main_mobile_tariff_id = RENUEVOS.tariff_id

  LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON PAGOS_UNICOS.serial_number = MULTI.serial_number
             AND PAGOS_UNICOS.phone_nm = MULTI.phone_nm
             AND PAGOS_UNICOS.brand_ds = MULTI.brand_ds
             AND PAGOS_UNICOS.order_date = MULTI.order_date

  CROSS JOIN UNNEST(canales_pr) AS canal_pr

  WHERE AGRUPACION.agrupacion_canal = 'Exclusivo'
      AND DATE_TRUNC(DATE(PAGOS_UNICOS.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND PAGOS_UNICOS.activation_date <= COALESCE(PAGOS_UNICOS.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND CHECK_TRANSACCIONES.phone_nm IS NULL
      AND PAGOS_UNICOS.activation_date >= VENTAS.activation_date 
      AND PAGOS_UNICOS.sell_terminal_origin_ds = 'RENUEVO'
      AND PAGOS_UNICOS.flag_pay_penalty = 'SI'
      AND PAGOS_UNICOS.financed_type IS NULL
      AND TRANSACCIONES.concepto = 'B - Renuevo'
      AND TRANSACCIONES.campaign_code = '1'
      AND `mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
        DEALER.canal
        ,PAGOS_UNICOS.brand_ds
        ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
        ,PAGOS_UNICOS.bundle_type
        ,PVP_BUNDLES.bundle_pre_tax_amount) <> 0.0

  QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, order_id, phone_nm, PAGOS_UNICOS.brand_ds ORDER BY activation_date DESC) = 1
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.financiaciones_final_exc_nva_categ`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT 
  'FINX'||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id
  ,*

FROM
    (SELECT *
    FROM `mm-commissions-reporting.TEMP.financiaciones_exc_nva_categ`
    WHERE financed_type = 'PAGO UNICO'
    QUALIFY ROW_NUMBER() OVER (
                                        PARTITION BY phone_nm, marca
                                        ORDER BY activation_date ASC,
                                                deactivation_date ASC,
                                                case when device_type = 'SMARTPHONE' THEN 1 ELSE 2 END ASC,
                                                serial_number ASC
                                        ) = 1

    UNION ALL

    SELECT *
    FROM `mm-commissions-reporting.TEMP.financiaciones_exc_nva_categ`
    WHERE financed_type = 'PAGO FINANCIADO'
    )
QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca ORDER BY CASE WHEN financed_type = 'PAGO UNICO' THEN 2 ELSE 1 END ASC) = 1

;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.financiaciones_exc` AS

-- SELECT 
--   'FINX'||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id
--   ,*

-- FROM `mm-commissions-reporting.TEMP.financiaciones_exc`
-- ;


ASSERT NOT EXISTS
(
SELECT service_id
FROM `mm-commissions-reporting.TEMP.financiaciones_final_exc_nva_categ`
GROUP BY marca, concepto, service_id, order_id
HAVING COUNT(1) > 1
);


--- Insertar tabla final ----

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('FINX', mes_pr, canales_pr, 'TEMP.financiaciones_final_exc_nva_categ', modo);


END