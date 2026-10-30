BEGIN

  DECLARE comm_entrega, comgc_entrega INT64;
  DECLARE prefijo STRING;
  SET comm_entrega = 5;
  SET comgc_entrega = 1;
  SET prefijo = 'UP_DEL_POS_';

  -- CALL `mm-commissions-reporting.COMISIONES.pr_entrega_tienda`('REAL',202601,'2026-01-01','2026-01-01','2026-01-31')

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.upfront_entrega_tienda` AS
  (

    SELECT --lbe.logistic_order_id, lbe.item_number, lbe.create_date_ts, lbe.expedition_date_ts, lbe.dealer_code, lbe.status_ds
      -- prefijo||PROCESO_PR||'_'||ID_MES_PR||'_'||row_number () over () AS commission_id,
      'calculado' AS estado
      , MES_LIQUIDADO_PR AS mes_liquidado
      , ID_MES_PR as id_mes
      , DEALER.agrupacion_canal AS agrupacion_canal
      , DEALER.canal AS canal
      , lbe.dealer_code AS id_comisionista
      , DEALER.canal AS distribuidor
      , SUBSTR(DEALER.id_comisionista,1,2) AS sfid_id
      , lbe.dealer_code AS seller
      , DEALER.nombre_comercio AS nombre_comercio
      , DEALER.razon_social AS razon_social
      , DEALER.cif AS cif
      , DEALER.zona_fiscal AS zona_fiscal      
      , UPPER(lbe.comm_brand_ds) AS marca
      , lbe.service_type AS service_type
      , CAST(lbe.phone_nm AS STRING) AS phone_nm
--      , SALES_CHANNEL.sell_tariff_id AS tariff_id
      , dbe.tariff_id AS tariff_id
--      , SALES_CHANNEL.sell_tariff_ds AS tariff_ds
      , dbe.tariff_ds AS tariff_ds
      , COALESCE(lee.subscriptionId, CAST(ape.SUBSCRIPTIONID AS STRING)) AS service_id
      , lbe.account_id AS account_id
      , lbe.customer_id as customer_id
      , SALES_CHANNEL.line_type_ds AS line_type_ds
      , CASE WHEN SALES_CHANNEL.technology_ds = 'MOBILE' THEN 'MO' ELSE 'FMC' END AS bundle_type
      , SALES_CHANNEL.technology_ds AS technology_ds
      , SALES_CHANNEL.billing_type_ds AS  billing_type_ds
      , CAST(COALESCE(lbe.create_date_ts,lee.createdDatetime) AS DATE) AS sale_date
      , COALESCE(CAST(ape.ACTDATE AS DATE),CAST(lbe.create_date_ts AS DATE),CAST(lee.createdDatetime AS DATE))  AS activation_date
      , CASE WHEN SALES_CHANNEL.deactivation_date IS NULL THEN CAST('9999-12-31' AS DATE) ELSE SALES_CHANNEL.deactivation_date END AS deactivation_date
      , COALESCE(CAST(lbe.item_number AS STRING),lee.orderCrmId) AS order_id
      , SALES_CHANNEL.order_type_agg AS order_type_agg
      , `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(SALES_CHANNEL.channel_segment_ds,lbe.comm_brand_ds) AS cod_segmento
      , `mm-commissions-reporting.COMISIONES.f_cod_marca`(lbe.comm_brand_ds,'MOBILE') AS cod_marca

      , CASE WHEN SALES_CHANNEL.sell_type = 'RENUEVO' THEN CASE
            WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
            WHEN SALES_CHANNEL.technology_ds NOT IN ('MOBILE') AND SALES_CHANNEL.line_type_ds = 'MAIN'             THEN (CASE WHEN SALES_CHANNEL.technology_ds = 'ADSL' THEN '60' ELSE '61' END)
            WHEN SALES_CHANNEL.technology_ds NOT IN ('MOBILE')                                                          THEN (CASE WHEN SALES_CHANNEL.technology_ds = 'ADSL' THEN '66' ELSE '67' END)
            WHEN SALES_CHANNEL.technology_ds IN ('MOBILE') AND UPPER(lbe.comm_brand_ds) IN ('YOIGO', 'PEPEPHONE') 
                AND SALES_CHANNEL.line_type_ds IN ('ADDITIONAL', 'EXTRA')                                         THEN '68'
            ELSE '20'
          END  
            ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(SALES_CHANNEL.billing_type_ds, 'MOBILE', CASE WHEN SALES_CHANNEL.technology_ds = 'MOBILE' THEN 'MO' ELSE 'FMC' END
                      , SALES_CHANNEL.technology_ds, UPPER(lbe.comm_brand_ds), SALES_CHANNEL.line_type_ds)
        END AS cod_tipo_contrato
      , CASE WHEN SALES_CHANNEL.sell_type = 'RENUEVO' THEN '050'  
            ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', UPPER(lbe.comm_brand_ds), SALES_CHANNEL.order_type_agg, SALES_CHANNEL.sell_type, CASE WHEN SALES_CHANNEL.sell_type = 'RENUEVO' THEN CASE
              WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
            WHEN SALES_CHANNEL.technology_ds NOT IN ('MOBILE') AND SALES_CHANNEL.line_type_ds = 'MAIN'                    THEN (CASE WHEN SALES_CHANNEL.technology_ds = 'ADSL' THEN '60' ELSE '61' END)
            WHEN SALES_CHANNEL.technology_ds NOT IN ('MOBILE')                                                            THEN (CASE WHEN SALES_CHANNEL.technology_ds = 'ADSL' THEN '66' ELSE '67' END)
            WHEN SALES_CHANNEL.technology_ds IN ('MOBILE')  AND SALES_CHANNEL.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND UPPER(lbe.comm_brand_ds) IN ('YOIGO', 'PEPEPHONE')  THEN '68'
              ELSE '20'
          END  
            ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(SALES_CHANNEL.billing_type_ds, 'MOBILE', CASE WHEN SALES_CHANNEL.technology_ds = 'MOBILE' THEN 'MO' ELSE 'FMC' END
                      , SALES_CHANNEL.technology_ds, UPPER(lbe.comm_brand_ds), SALES_CHANNEL.line_type_ds)
            END)      
        END as cod_producto
      , `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(lbe.channel_ds,lbe.subchannel_ds) as cod_canal
      , CAST (NULL AS STRING) as campaign_code
      , lee.devices_identifier AS serial_number
      , CASE WHEN DEALER.zona_fiscal = 'CAN' THEN ROUND((comm_entrega/1.07),2) ELSE ROUND((comm_entrega/1.21),2) END AS tax_base
      , CAST (NULL AS STRING) as claim_code
      , PROCESO_PR AS process_code
      , 'MYSIM' AS comments
      , 'C_MANUAL' AS facturador
      , CAST (NULL AS STRING) AS proceso_sap
      , CAST (NULL AS STRING) AS id_registro
      , CAST (NULL AS STRING) AS invoice_id
      , 'X0010' AS sociedad
      , CAST (NULL AS STRING) AS bp
      , CAST (NULL AS STRING) AS cuenta_contable
      , CAST (NULL AS STRING) AS centro_coste
      , CAST (NULL AS STRING) AS documento_sap
      , CAST (NULL AS STRING) AS documento_sap_posicion
      , CAST (NULL AS STRING) AS fecha_contabilizacion
      , CURRENT_TIMESTAMP AS creado
      , CAST (NULL AS STRING) AS modificado
      , CAST (NULL AS STRING) AS id_factura_drive
      , 'B - Entrega en tienda' AS concepto
      , 'UPFR' AS tipo_concepto
      , 1 AS unidades
      , comm_entrega AS comision

    FROM `mm-datamart-kd.LOGISTICS.logistic_base_emysim` lbe
      LEFT JOIN `mm-commissions-reporting.TEMP.APOLLO_PROP_EXPEDITIONITEM` ape
        ON  ape.ITEMNUMBER = lbe.item_number
        AND ape.LOGISTICORDERID = lbe.logistic_order_id
      INNER JOIN `mm-datamart-kd.LOGISTICS.logistic_expeditions_events` lee
        ON lee.orderId = lbe.logistic_order_id
      INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER 
        ON  lbe.dealer_code = DEALER.sfid_id 
        AND DEALER.id_mes = ID_MES_PR
        AND DEALER.comisiona
/*
      LEFT JOIN (
            SELECT channel_segment_ds, sfid_id, sell_tariff_id, sell_tariff_ds, line_type_ds, technology_ds, billing_type_ds, deactivation_date, order_type_agg, sell_type
            FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
            WHERE data_source_ds = 'MYSIM'
            QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
      ) AS SALES_CHANNEL
        ON lbe.dealer_code = SALES_CHANNEL.sfid_id
*/
      LEFT JOIN (
        SELECT channel_segment_ds, sfid_id, sell_tariff_id, sell_tariff_ds, line_type_ds, technology_ds, billing_type_ds, deactivation_date, order_type_agg, sell_type, phone_nm, customer_id, service_id
        FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` vbtn
        WHERE data_source_ds = 'MYSIM'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, customer_id, service_id ORDER BY activation_date DESC) = 1
      ) AS SALES_CHANNEL
        ON    SALES_CHANNEL.phone_nm    = lbe.phone_nm
          AND SALES_CHANNEL.customer_id = lbe.customer_id
          AND SALES_CHANNEL.service_id  = COALESCE(lee.subscriptionId, CAST(ape.SUBSCRIPTIONID AS STRING))

      LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` dbe
        ON  UPPER(lee.devices_identifier) = UPPER(dbe.serial_number)
        AND UPPER(COALESCE(lee.subscriptionId, CAST(ape.SUBSCRIPTIONID AS STRING))) = UPPER(dbe.service_id)
        AND UPPER(lbe.customer_id) = UPPER(dbe.customer_id)
        AND lbe.phone_nm = dbe.phone_nm

    WHERE lbe.dealer_code IS NOT NULL
      AND lbe.status_ds = 'ENTREGADO A CLIENTE'
      AND lbe.delivery_type = 'SHOP'
      AND lbe.dealer_code NOT IN ('LBTEST01')
      AND CAST(lee.deliveryPointDeliveredDatetime AS DATE) between ACTI_INI_PR and ACTI_FINAL_PR
  );

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.GC_entrega_tienda` AS

-- SELECT * EXCEPT(concepto,tipo_concepto,unidades,comision)
-- , 'F - Entrega en tienda' AS concepto
--       , 'UPFR' AS tipo_concepto
--       , 1 AS unidades
--       , comgc_entrega AS comision
-- FROM `mm-commissions-reporting.TEMP.upfront_entrega_tienda`
-- ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.transacciones_entrega_tienda` AS

SELECT *
      ,prefijo||PROCESO_PR||'_'||ID_MES_PR||'_'||row_number () over () AS commission_id, 
FROM (
      SELECT * FROM `mm-commissions-reporting.TEMP.upfront_entrega_tienda`
      -- UNION ALL
      -- SELECT * FROM `mm-commissions-reporting.TEMP.GC_entrega_tienda`
    );


  CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.transacciones_entrega_tienda), 'TEMP.transacciones_entrega_tienda', 'ACTUALIZAR');

END