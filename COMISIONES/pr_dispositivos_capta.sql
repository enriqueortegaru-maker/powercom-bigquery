BEGIN

DECLARE sql, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['CIN','D2D', 'D2N','DEM','DO','DON','OU','OUN','WA','XI','XIN','XO','XOF','XS','XSN','WA'];

END IF;


/*
CALL COMISIONES.pr_dispositivos_capta (202602,['WA']);
*/


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones` AS (
  SELECT DISTINCT
       DEVICE.master_channel_ds 
      ,DEVICE.channel_ds
      ,DEVICE.subchannel_ds
      ,AGRUPACION.codigo_canal_sap AS cod_canal
      ,DEVICE.sfid_id
      ,DEVICE.user_store AS user_store
      ,UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)]) as seller
      ,SALES_CHANNEL.channel_segment_ds AS channel_segment_ds
      ,DEVICE.segment_ds
      ,DEVICE.brand_ds
      ,DEVICE.service_id
      ,DEVICE.tariff_id
      ,DEVICE.tariff_ds
      ,COALESCE(SALES.sell_bundle_type, 'MO') AS bundle_type
      ,COALESCE(REPLACE(SALES.line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds
      ,COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
      ,COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
      ,DEVICE.service_type AS technology_ds
      ,DEVICE.order_type_agg
      ,CAST(DEVICE.phone_nm AS STRING) phone_nm
      ,DATE(DEVICE.order_date) AS order_date
      ,COALESCE(SALES.activation_date,DATE(DEVICE.order_date))AS activation_date 
      ,DATE(DEVICE.cancellation_date_ts) AS deactivation_date
      ,DEVICE.account_id
      ,DEVICE.customer_id
      ,CAST(NULL AS STRING) AS order_id
      ,DEVICE.device_type_ds AS device_type
      ,DEVICE.product_code AS product_id
      ,DEVICE.tech_description AS product
      ,CASE WHEN DEVICE.is_financed_desc = 'SI' THEN 'PAGO FINANCIADO' ELSE 'NO FINANCIADO' END AS financed_type
      ,DEVICE.flag_pay_penalty
      ,DEVICE.cost_price
      ,DEVICE.serial_number
      ,DEVICE.data_source_ds AS data_source
      ,DEVICE.financed_end_date
      ,DEVICE.total_pay_value
      ,DEVICE.courier
      ,DEVICE.terminal_status_ds
      ,DEVICE.terminal_name
      ,DEVICE.sell_terminal_origin_ds
      ,DEVICE.EXPEDITION_STATUS_DS


FROM `mm-datamart-kd.DEVICES.device_base_mysim` DEVICE

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` SALES
         ON CAST(DEVICE.service_id AS STRING) = SALES.service_id AND DEVICE.brand_ds = SALES.brand_ds AND SALES.data_source_ds = 'MYSIM'
            AND DEVICE.data_source_ds = 'MYSIM'

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-datamart-kd.SERVICES.ventas_base_net`
          WHERE data_source_ds = 'MYSIM'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY activation_date DESC) = 1
          ) AS SALES_CHANNEL
         ON DEVICE.sfid_id = SALES_CHANNEL.sfid_id

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE( SALES_CHANNEL.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND DEVICE.master_channel_ds = AGRUPACION.master_channel_ds
            AND  DEVICE.channel_ds = AGRUPACION.channel_ds
            AND  DEVICE.subchannel_ds = AGRUPACION.subchannel_ds
            AND DEVICE.comm_brand_ds = AGRUPACION.comm_brand_ds

WHERE DEVICE.brand_ds IN ('MASMOVIL', 'YOIGO')
      AND (
          expedition_status_ds = 'CONFIRMADA'
          OR (DEVICE.terminal_status_ds = 'FINANCIACION EN CURSO')
          OR (DEVICE.terminal_status_ds = 'EN FINANCIACION')
          OR (DEVICE.terminal_status_ds = 'USADO')
          OR (expedition_status_ds = 'ENTREGADO A CLIENTE')
          )
          -- AND DEVICE.terminal_status_ds = 'USADO'
AND DATE(DATE_TRUNC(DEVICE.picking_date_ts, MONTH)) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND DEVICE.service_type = 'MOBILE'
AND DEVICE.device_type_ds NOT IN ('ROUTER')
AND DEVICE.sell_terminal_origin_ds = 'CAPTACION'

QUALIFY RANK () OVER (
                     PARTITION BY DEVICE.service_id, DEVICE.product_code
                     ORDER BY CASE WHEN SALES.order_day_id <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_day_id, '9999-12-31') END DESC,
                              CASE WHEN SALES.order_day_id > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_day_id, '9999-12-31') END ASC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END DESC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END ASC,
                              SALES.deactivation_date ASC
                     ) = 1
)
;

----- Tabla transacciones ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_final`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
  'DSPC'||'_'||id_mes_pr||'_'||DEALER.canal||'_'||ROW_NUMBER () OVER () AS commission_id,
  'calculado' AS estado,
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  DEALER.agrupacion_canal ,
  DEALER.canal,
  'D - Dispositivo Captacion' as concepto,
  'UPFR' as tipo_concepto,
  1 AS unidades,

  `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
  (DEALER.canal
  ,RENUEVOS.financed_type
  ,CASE WHEN DEALER.CANAL IN ('D2D','D2N','DEM') THEN RENUEVOS.total_pay_value ELSE RENUEVOS.cost_price END
  ,CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END
  ,RENUEVOS.brand_ds
  ,COALESCE(TLV_CROSS_SELL.campaign, CAST (NULL AS STRING))
  ,RENUEVOS.flag_pay_penalty ) 
  AS comision,

  DEALER.id_comisionista,
  COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor,
  DEALER.sfid_id,
  CASE
    WHEN RENUEVOS.seller IN ('ygoffline') THEN RENUEVOS.user_store
    ELSE RENUEVOS.seller
  END AS seller,
  DEALER.nombre_comercio,
  DEALER.razon_social,
  DEALER.cif,
  DEALER.zona_fiscal,
  RENUEVOS.brand_ds AS marca,
  RENUEVOS.technology_ds AS service_type,
  CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm,
  RENUEVOS.product_id AS tariff_id,
  COALESCE(RENUEVOS.terminal_name,RENUEVOS.product) AS tariff_ds,
  RENUEVOS.service_id,
  RENUEVOS.account_id,
  RENUEVOS.customer_id,
  CAST(NULL AS STRING) AS line_type_ds,
  CAST(NULL AS STRING) AS bundle_type,
  RENUEVOS.technology_ds,
  COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds,
  RENUEVOS.order_date AS sale_date,
  RENUEVOS.activation_date,
  RENUEVOS.deactivation_date,
  CAST(RENUEVOS.order_id AS STRING) AS order_id,
  CAST(NULL AS STRING) AS order_type_agg,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(RENUEVOS.segment_ds,RENUEVOS.brand_ds) AS cod_segmento,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RENUEVOS.brand_ds) AS cod_marca,
  CASE
    WHEN RENUEVOS.billing_type_ds = 'PREPAID' THEN '10'
    WHEN RENUEVOS.bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN' THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '60'ELSE '61' END )
    WHEN RENUEVOS.bundle_type = 'FMC' THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '66'ELSE '67'END )
    WHEN RENUEVOS.bundle_type = 'MO' AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND RENUEVOS.brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
    ELSE '20'
  END AS cod_tipo_contrato,
  CASE WHEN RENUEVOS.order_type_agg = 'PORTABILIDAD' THEN '040' ELSE '039' END AS cod_producto,
  CASE
    WHEN RENUEVOS.cod_canal IN ('14', '15') THEN '29'
    ELSE RENUEVOS.cod_canal
  END AS cod_canal,
  COALESCE(TLV_CROSS_SELL.campaign, CAST (NULL AS STRING)) AS campaign_code,
  RENUEVOS.serial_number,
  CAST(NULL AS FLOAT64) AS tax_base,
  CAST(NULL AS STRING) AS claim_code,
  CAST(NULL AS STRING) AS process_code,
  CAST(NULL AS STRING) AS comments,
  'C_MANUAL' AS facturador,
  `mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad
  -- ,RENUEVOS.sell_terminal_origin_ds
  -- ,RENUEVOS.expedition_status_ds
  -- ,RENUEVOS.terminal_status_ds
  -- ,ROUND(RENUEVOS.cost_price,2)
  -- ,ROUND(RENUEVOS.total_pay_value,2)
  -- ,RENUEVOS.financed_type
  -- ,CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END AS MULTI
  -- ,MULTI.multidispositivo

  
FROM
  `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones` RENUEVOS


LEFT JOIN (
  SELECT *
  FROM  `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`,
    UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION

      ON COALESCE(RENUEVOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
        AND RENUEVOS.master_channel_ds = AGRUPACION.master_channel_ds
        AND RENUEVOS.channel_ds = AGRUPACION.channel_ds
        AND RENUEVOS.subchannel_ds = AGRUPACION.subchannel_ds
        AND RENUEVOS.brand_ds = AGRUPACION.comm_brand_ds


LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
      ON (RENUEVOS.sfid_id = DEALER.sfid_id OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(RENUEVOS.sfid_id, 1, 2) = DEALER.sfid_id) OR RENUEVOS.seller = DEALER.sfid_id OR RENUEVOS.user_store = DEALER.sfid_id )
        AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
        AND DEALER.id_mes = id_mes_pr



INNER JOIN  `mm-commissions-reporting.GS.CANALES` CHANNEL
  ON CASE WHEN RENUEVOS.sfid_id IN ('TLVOU001','DONL026') THEN 'TLV - Outbound' ELSE AGRUPACION.agrupacion_canal END = CHANNEL.agrupacion_canal
   AND DEALER.canal = CHANNEL.canal

LEFT JOIN (SELECT serial_number
    
    FROM `mm-datamart-kd.DEVICES.device_base_mysim` RENUEVOS

    WHERE RENUEVOS.brand_ds IN ('MASMOVIL', 'YOIGO')
      AND (
          expedition_status_ds = 'CONFIRMADA'
          OR (RENUEVOS.terminal_status_ds = 'FINANCIACION EN CURSO')
          OR (RENUEVOS.terminal_status_ds = 'EN FINANCIACION')
          OR (RENUEVOS.terminal_status_ds = 'USADO')
          OR (expedition_status_ds = 'ENTREGADO A CLIENTE')
          )

AND RENUEVOS.service_type = 'MOBILE'
AND RENUEVOS.device_type_ds NOT IN ('ROUTER')
AND RENUEVOS.sell_terminal_origin_ds = 'CAPTACION'
    
      -- AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH)
      AND RENUEVOS.is_financed_desc = 'SI'
      AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 4 MONTH)
      AND serial_number IS NOT NULL
      
      QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, brand_ds
                                    ORDER BY RENUEVOS.order_date ASC,
                                            --  RENUEVOS.deactivation_date ASC,
                                             RENUEVOS.original_cost_price DESC,
                                             RENUEVOS.serial_number ASC
                                    ) > 1) MULTI
      ON RENUEVOS.serial_number = MULTI.serial_number

-- LEFT JOIN (
--     SELECT serial_number
    
--     FROM `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones` RENUEVOS
    
--     WHERE
--       RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
--       AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH)
--       AND financed_type = 'PAGO FINANCIADO'
--       AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH)
--       AND serial_number IS NOT NULL
--     QUALIFY
--       ROW_NUMBER() OVER (PARTITION BY phone_nm, brand_ds ORDER BY RENUEVOS.activation_date ASC, RENUEVOS.deactivation_date ASC, RENUEVOS.serial_number ASC ) > 1 ) MULTI
--   ON RENUEVOS.serial_number = MULTI.SERIAL_NUMBER

--  LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos` MULTI
--  ON RENUEVOS.serial_number = MULTI.serial_number



  LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
    ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
  AND DEALER.canal IN UNNEST (canales_pr)
  AND DEALER.comisiona
  AND   `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
  (DEALER.canal
  ,RENUEVOS.financed_type
  ,CASE WHEN DEALER.CANAL IN ('D2D','D2N','DEM') THEN RENUEVOS.total_pay_value ELSE RENUEVOS.cost_price END
  ,CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END
  ,RENUEVOS.brand_ds
  ,COALESCE(TLV_CROSS_SELL.campaign, CAST (NULL AS STRING))
  ,RENUEVOS.flag_pay_penalty ) > 0

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'),service_id, marca ORDER BY activation_date DESC) = 1
)
;


--- FACTOR SEGMENTACIÓN LIGA (SOLO D2D)

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN
UPDATE `mm-commissions-reporting.TEMP.dispositivos_capta_final` v
SET comision = v.comision * f.porcentaje
FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
WHERE v.cif = f.cif
  AND f.id_mes = id_mes_pr
  AND v.activation_date >= '2026-07-01'
  AND v.estado = 'calculado'
  AND v.canal IN ('D2D','D2N','DEM');
END IF;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('DSPC', id_mes_pr, canales_pr, 'TEMP.dispositivos_capta_final', 'ACTUALIZAR');


END