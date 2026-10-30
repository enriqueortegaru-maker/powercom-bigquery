BEGIN

DECLARE sql, mes_string, prefijo STRING;

SET mes_string = CAST(mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','ENK','PH'];
END IF;


/*
CALL COMISIONES.pr_financiaciones(202604, ['ALTN']);
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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.financiaciones` AS
SELECT
      'FINA'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     --,COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds), DEALER.agrupacion_canal) AS agrupacion_canal
     ,AGRUPACION.agrupacion_canal
     ,DEALER.canal
     ,concepto
     ,tipo_concepto
     ,1 AS unidades
    --  ,`mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(DEALER.canal, RENUEVOS.financed_type) AS comision
    ,`mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
        DEALER.canal
        ,RENUEVOS.brand_ds
        ,CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END
        ,RENUEVOS.bundle_type
        ,PVP_BUNDLES.bundle_pre_tax_amount) AS comision
      --- vendedor ---
     ,id_comisionista
     ,COALESCE(distribuidor, id_comisionista) AS distribuidor
     ,DEALER.sfid_id

     ,CASE 
          WHEN AGRUPACION.agrupacion_canal = 'Exclusivo'  THEN user_store
          WHEN seller IN ('ygoffline')                    THEN user_store 
          ELSE seller 
      END AS seller

     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
      --- servicio ---
     ,RENUEVOS.brand_ds AS marca
     ,'MOBILE' AS service_type
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     
     ,CASE 
          WHEN AGRUPACION.agrupacion_canal = 'Exclusivo' THEN PVP_BUNDLES.bundle_id
          ELSE product_id 
      END AS tariff_id

     ,CASE 
          WHEN AGRUPACION.agrupacion_canal = 'Exclusivo' THEN PVP_BUNDLES.name
          ELSE product 
      END AS tariff_ds
      
     ,RENUEVOS.service_id
     ,account_id
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,RENUEVOS.bundle_type
     ,technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,order_date AS sale_date
     ,RENUEVOS.activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, RENUEVOS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RENUEVOS.brand_ds) AS cod_marca

     ,CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND RENUEVOS.brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
      service_type 
      ,RENUEVOS.brand_ds 
      ,order_type_agg 
      ,'sell_type'
     ,CASE
          WHEN billing_type_ds = 'PREPAID'                   THEN '10'
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN' THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                           THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND RENUEVOS.brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END) AS cod_producto

     ,AGRUPACION.codigo_canal_sap AS cod_canal
      --- informacion adicional ---
     ,CAST(NULL AS STRING)  AS campaign_code
     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_servicio_financiaciones` RENUEVOS

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(RENUEVOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND RENUEVOS.master_channel_ds = AGRUPACION.master_channel_ds
            AND RENUEVOS.channel_ds = AGRUPACION.channel_ds
            AND RENUEVOS.subchannel_ds = AGRUPACION.subchannel_ds
            AND RENUEVOS.brand_ds = AGRUPACION.comm_brand_ds

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CONCEPTOS.agrupacion_canal
             AGRUPACION.agrupacion_canal IN ('Exclusivo','No Exclusivo')
             AND CONCEPTOS.id_prefijo = 'FINA'

-- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON (
            RENUEVOS.sfid_id = DEALER.sfid_id 
            OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(RENUEVOS.sfid_id, 1, 2) = DEALER.sfid_id)
            OR RENUEVOS.seller = DEALER.sfid_id
            OR RENUEVOS.user_store = DEALER.sfid_id
            )
            --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
            AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            -- AND DEALER.id_mes = mes_pr

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

LEFT JOIN (
          SELECT DISTINCT phone_nm, sale_date
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE id_mes < mes_pr
                AND (concepto LIKE '%Dispositivo Financiado%' OR concepto LIKE '%Financiacion terminales%' OR concepto LIKE '%Extracomision terminal%')
          ) TRANSACCIONES
         ON RENUEVOS.phone_nm = TRANSACCIONES.phone_nm
            AND RENUEVOS.order_date = TRANSACCIONES.sale_date

LEFT JOIN (SELECT phone_nm, service_id, brand_ds, sell_bundle_id, sell_bundle_name, activation_date FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` GROUP BY ALL) VENTAS
        ON RENUEVOS.phone_nm = CAST(VENTAS.phone_nm AS STRING) AND RENUEVOS.brand_ds = VENTAS.brand_ds AND RENUEVOS.service_id = VENTAS.service_id 

LEFT JOIN (SELECT data_month_id, phone_nm, service_id, brand_ds, bundle_id, bundle_name, init_date, end_date FROM `mm-datamart-kd.BILLING.billing_detail_emysim` GROUP BY ALL) BILLING
        ON RENUEVOS.phone_nm = CAST(BILLING.phone_nm AS STRING) AND RENUEVOS.brand_ds = BILLING.brand_ds AND RENUEVOS.service_id = BILLING.service_id AND BILLING.data_month_id = mes_pr AND RENUEVOS.activation_date BETWEEN BILLING.init_date AND BILLING.end_date

LEFT JOIN  `mm-commissions-reporting.TEMP.pvp_bundles` PVP_BUNDLES
        ON PVP_BUNDLES.bundle_id = COALESCE(BILLING.bundle_id, CAST(VENTAS.sell_bundle_id AS STRING)) --AND PVP_BUNDLES.main_mobile_tariff_id = RENUEVOS.tariff_id

LEFT JOIN (
          SELECT RENUEVOS.serial_number
          -- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
          FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS
          WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
                AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
                AND financed_type = 'PAGO FINANCIADO'
                AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
                AND RENUEVOS.serial_number IS NOT NULL
                AND RENUEVOS.sell_type = 'RENUEVO'
          QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, brand_ds
                                    ORDER BY RENUEVOS.activation_date ASC,
                                             RENUEVOS.deactivation_date ASC,
                                             RENUEVOS.original_cost_price DESC,
                                             RENUEVOS.serial_number ASC
                                    ) > 1
          ) MULTI
         ON RENUEVOS.serial_number = MULTI.serial_number

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND TRANSACCIONES.phone_nm IS NULL
      AND RENUEVOS.financed_type = 'PAGO FINANCIADO' 
      AND (AGRUPACION.agrupacion_canal= 'Exclusivo'AND RENUEVOS.activation_date >= VENTAS.activation_date 
          OR
          AGRUPACION.agrupacion_canal= 'No Exclusivo')

      AND (
            (
             AGRUPACION.agrupacion_canal = 'Exclusivo'
             AND RENUEVOS.flag_pay_penalty = 'SI'
             AND RENUEVOS.sell_terminal_origin_ds = 'RENUEVO'
            )
          OR
            (
            --  AGRUPACION.agrupacion_canal = 'No Exclusivo'
             DEALER.CANAL= 'ALTN'
             AND RENUEVOS.sell_terminal_origin_ds = 'CAPTACION'
            )
          OR
            (
            --  AGRUPACION.agrupacion_canal = 'No Exclusivo'
             DEALER.CANAL= 'PH'
            --  AND RENUEVOS.sell_terminal_origin_ds = 'CAPTACION'
            )

          )
      AND `mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
        DEALER.canal
        ,RENUEVOS.brand_ds
        ,CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END
        ,RENUEVOS.bundle_type
        ,PVP_BUNDLES.bundle_pre_tax_amount) <> 0.0

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, order_id, phone_nm, RENUEVOS.brand_ds ORDER BY activation_date DESC) = 1
;


ASSERT NOT EXISTS
(
SELECT service_id
FROM `mm-commissions-reporting.TEMP.financiaciones`
GROUP BY marca, concepto, service_id, order_id
HAVING COUNT(1) > 1
);


--- Insertar tabla final ----

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('FINA', mes_pr, canales_pr, 'TEMP.financiaciones', 'ACTUALIZAR');


END