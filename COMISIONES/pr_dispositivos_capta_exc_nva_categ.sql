BEGIN

DECLARE sql, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo); 

IF canales_pr IS NULL THEN SET canales_pr = ['ENK'];

END IF;


/*
CALL COMISIONES.pr_dispositivos_capta_exc_nva_categ(202603,['ENK'],NULL);
*/


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo_nva_categ` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS (
  SELECT DISTINCT
       DEVICE.master_channel_ds 
      ,DEVICE.channel_ds
      ,DEVICE.subchannel_ds
      ,AGRUPACION.codigo_canal_sap AS cod_canal
      ,DEVICE.sfid_id
      ,DEVICE.user_store AS user_store
      ,COALESCE(DEVICE.user_store,UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)])) as seller
      ,SALES_CHANNEL.channel_segment_ds AS channel_segment_ds
      ,DEVICE.segment_ds
      ,DEVICE.brand_ds
      ,DEVICE.service_id
      ,DEVICE.tariff_id
      ,DEVICE.tariff_ds
      
      ,CASE 
           WHEN COALESCE(SALES.sell_bundle_type, 'MO') LIKE 'FM%' THEN 'FMC' 
           ELSE 'MO'
       END AS bundle_type
      
      ,COALESCE(REPLACE(SALES.line_type_ds, 'DESC', 'MAIN'), SALES.line_type_ds) AS line_type_ds     
      ,COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds
      ,COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds
      ,DEVICE.service_type AS technology_ds
      ,CAST(DEVICE.phone_nm AS STRING) phone_nm
      ,DATE(DEVICE.order_date) AS order_date
      
      ,CASE 
           WHEN SALES.activation_date < DATE(DEVICE.order_date) THEN DATE(DEVICE.order_date) 
           ELSE COALESCE(SALES.activation_date,DATE(DEVICE.order_date)) 
       END AS activation_date

      ,DATE(DEVICE.cancellation_date_ts) AS deactivation_date
      ,DEVICE.account_id
      ,DEVICE.customer_id
      ,DEVICE.id_subscription_terminal AS order_id
      ,DEVICE.device_type_ds AS device_type
      ,DEVICE.product_code AS product_id
      ,DEVICE.terminal_name AS product
      ,CASE WHEN DEVICE.is_financed_desc = 'SI' THEN 'PAGO FINANCIADO' ELSE 'NO FINANCIADO' END AS financed_type
      ,DEVICE.flag_pay_penalty
      ,DEVICE.cost_price
      ,DEVICE.serial_number
      ,DEVICE.data_source_ds AS data_source
      ,DEVICE.financed_end_date
      ,DEVICE.total_pay_value_without_vat
      ,DEVICE.courier
      ,DEVICE.terminal_status_ds
      ,DEVICE.terminal_name
      ,DEVICE.not_financed_price
      ,DEVICE.q25_amount
      ,DEVICE.financed_total_amount
      ,DEVICE.order_type_agg
      ,DEVICE.original_cost_price
      ,DEVICE.tax_value

FROM `mm-datamart-kd.DEVICES.device_base_mysim` DEVICE

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` SALES
         ON CAST(DEVICE.service_id AS STRING) = SALES.service_id AND DEVICE.brand_ds = SALES.brand_ds AND SALES.data_source_ds = 'MYSIM'
            AND DEVICE.data_source_ds = 'MYSIM'

LEFT JOIN (
          SELECT channel_segment_ds, sfid_id
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
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

WHERE 1 = 1
AND DEVICE.master_channel_ds = 'EXCLUSIVO' -- 09/09/25
AND DEVICE.brand_ds IN ('MASMOVIL', 'YOIGO')
      AND (
          expedition_status_ds = 'CONFIRMADA'
          OR (expedition_status_ds IS NULL)
          OR (DEVICE.terminal_status_ds = 'FINANCIACION EN CURSO')
          OR (DEVICE.terminal_status_ds = 'EN FINANCIACION')
          OR (DEVICE.terminal_status_ds = 'USADO')
          )
      AND DEVICE.terminal_status_ds NOT IN ('CANCELADO','DESISTIDO')
      AND DEVICE.sell_terminal_origin_ds IN ('CAPTACION','AÃ±ADIR LINEA','MIGRACIÓN DE PAQUETE') --08/09/25
      AND SALES.billing_type_ds = 'POSTPAID'
AND (
     DATE(DATE_TRUNC(DEVICE.picking_date_ts, MONTH)) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     OR
     DATE(DATE_TRUNC(DEVICE.picking_date_ts, MONTH)) = DATE_TRUNC(SALES.order_date,MONTH) 
    )
AND DATE(DATE_TRUNC(SALES.activation_date, MONTH)) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND SALES.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD','MIGRACION PREPAGO A POSTPAGO')
-- AND DEVICE.device_type_ds NOT IN ('ROUTER', 'Hotspotwifi','STB')

QUALIFY RANK () OVER (
                     PARTITION BY /*DEVICE.service_id,*/ DEVICE.serial_number, DEVICE.product_code
                     ORDER BY CASE WHEN (DEVICE.terminal_status_ds = 'USADO' OR DEVICE.terminal_status_ds = 'FINANCIACION EN CURSO')
                                   THEN DEVICE.order_date END ASC,
                              CASE WHEN SALES.order_date <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_date, '9999-12-31') END DESC,
                              CASE WHEN SALES.order_date > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_date, '9999-12-31') END ASC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END DESC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END ASC,
                              SALES.deactivation_date ASC
                     ) = 1
)
;

----- Tabla transacciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_primarios_nva_categ`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
  -- 'DCEX'||'_'||id_mes_pr||'_'||DEALER.canal||'_'||ROW_NUMBER () OVER () AS commission_id,
  'calculado' AS estado,
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  DEALER.agrupacion_canal ,
  DEALER.canal,
  'D - Extracomision terminal' as concepto,
  'UPFR' as tipo_concepto,
  1 AS unidades,

  `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
  (DEALER.canal
  ,RENUEVOS.financed_type
  ,RENUEVOS.total_pay_value_without_vat 
  ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
  ,RENUEVOS.brand_ds
  ,CAST(null AS STRING)
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
  RENUEVOS.line_type_ds,
  RENUEVOS.bundle_type,
  RENUEVOS.technology_ds,
  COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds,
  RENUEVOS.order_date AS sale_date,
  RENUEVOS.activation_date,
  RENUEVOS.deactivation_date,
  CAST(RENUEVOS.order_id AS STRING) AS order_id,
  RENUEVOS.order_type_agg,
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

  CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN '2' ELSE '1' END AS campaign_code,
  RENUEVOS.serial_number,
  RENUEVOS.total_pay_value_without_vat AS tax_base,
  CAST(NULL AS STRING) AS claim_code,
  CAST(NULL AS STRING) AS process_code,
  
  CASE 
          WHEN RENUEVOS.total_pay_value_without_vat < 40   THEN 'GAMA A'
          WHEN RENUEVOS.total_pay_value_without_vat < 350  THEN 'GAMA B'
          WHEN RENUEVOS.total_pay_value_without_vat >= 350 THEN 'GAMA C'
  END AS comments,

  'C_MANUAL' AS facturador,
  `mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad
  -- ,RENUEVOS.terminal_status_ds
  -- ,RENUEVOS.cost_price
  
FROM
  `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo_nva_categ` RENUEVOS


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
      ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
      AND DEALER.canal = CHANNEL.canal

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON RENUEVOS.serial_number = MULTI.serial_number
             AND RENUEVOS.phone_nm = MULTI.phone_nm
             AND RENUEVOS.brand_ds = MULTI.brand_ds
             AND RENUEVOS.order_date = MULTI.order_date

-- LEFT JOIN (
--             SELECT serial_number
            
--             FROM `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo` RENUEVOS
            
--             WHERE
--               RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
--               AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 2 MONTH)
--               AND financed_type = 'PAGO FINANCIADO'
--               AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 4 MONTH)
--               AND serial_number IS NOT NULL
--             QUALIFY
--               ROW_NUMBER() OVER (PARTITION BY phone_nm, brand_ds ORDER BY RENUEVOS.activation_date ASC, RENUEVOS.deactivation_date ASC, RENUEVOS.serial_number ASC ) > 1 
--           ) MULTI
--       ON RENUEVOS.serial_number = MULTI.serial_number



-- Asegurar que se calcula por cada servicio móvil que tenga un dispositivo, incluyendo las tarifas que no comisionan
INNER JOIN (
            SELECT service_id, phone_nm, marca
            -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
            FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
            WHERE id_mes = id_mes_pr
            AND concepto = 'A - Servicio Movil Pospago'
            AND canal IN ('ENK')
            AND estado IN ('calculado', 'validado')

            UNION ALL

            ( 
              SELECT ACTIVACIONES.service_id, ACTIVACIONES.phone_nm, ACTIVACIONES.marca
              FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
    
              LEFT JOIN (
                        SELECT service_id, phone_nm, marca, /*cond_pago*/
                        -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
                        FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
                        WHERE canal IN ('ENK') AND concepto IN ('A - Servicio Movil Pospago', 'D - Extracomision terminal') AND id_mes < id_mes_pr GROUP BY 1,2,3
                        ) TRANSACTIONS
                        ON ACTIVACIONES.service_id = TRANSACTIONS.service_id AND ACTIVACIONES.phone_nm = TRANSACTIONS.phone_nm AND ACTIVACIONES.marca = TRANSACTIONS.marca

              WHERE id_mes = id_mes_pr
                    AND TRANSACTIONS.service_id IS NULL
                    AND (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','2313','7126','7127','7108','7115'))
            )
          ) TRANSACCIONES
      ON TRANSACCIONES.service_id = RENUEVOS.service_id AND TRANSACCIONES.phone_nm = RENUEVOS.phone_nm AND TRANSACCIONES.marca = RENUEVOS.brand_ds

-- Comprobar que no se haya pagado anteriormente la comisión para el mismo serial_number
LEFT JOIN (
           SELECT DISTINCT serial_number
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE concepto IN ('D - Extracomision terminal','Z - Extracomision terminal')
           AND estado = 'facturado'
           AND canal = 'ENK'
           AND id_mes < id_mes_pr
          ) PAGADAS
          ON PAGADAS.serial_number = RENUEVOS.serial_number

CROSS JOIN UNNEST(canales_pr) AS canal_pr


WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
  AND PAGADAS.serial_number IS NULL
  AND DEALER.canal IN UNNEST (canales_pr)
  AND DEALER.comisiona
  AND   `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
  (DEALER.canal
  ,RENUEVOS.financed_type
  ,RENUEVOS.total_pay_value_without_vat
  ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
  ,RENUEVOS.brand_ds
  ,CAST(null AS STRING)
  ,RENUEVOS.flag_pay_penalty ) > 0


QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'),service_id, marca 
                           ORDER BY RENUEVOS.activation_date ASC, 
                                    RENUEVOS.deactivation_date ASC, 
                                    RENUEVOS.original_cost_price DESC,
                                    RENUEVOS.serial_number ASC
                          ) = 1
) 
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_multidispositivos_nva_categ`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

(
SELECT
  -- 'DCEX'||'_'||id_mes_pr||'_'||DEALER.canal||'_'||ROW_NUMBER () OVER () AS commission_id,
  'calculado' AS estado,
  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
  id_mes_pr AS id_mes,
  DEALER.agrupacion_canal ,
  DEALER.canal,
  'D - Extracomision terminal' as concepto,
  'UPFR' as tipo_concepto,
  1 AS unidades,

  `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
  (DEALER.canal
  ,RENUEVOS.financed_type
  ,RENUEVOS.total_pay_value_without_vat 
  ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
  ,RENUEVOS.brand_ds
  ,CAST(null AS STRING)
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
  RENUEVOS.line_type_ds,
  RENUEVOS.bundle_type,
  RENUEVOS.technology_ds,
  COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds,
  RENUEVOS.order_date AS sale_date,
  RENUEVOS.activation_date,
  RENUEVOS.deactivation_date,
  CAST(RENUEVOS.order_id AS STRING) AS order_id,
  RENUEVOS.order_type_agg,
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
  CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN '2' ELSE '1' END AS campaign_code,
  RENUEVOS.serial_number,
  RENUEVOS.total_pay_value_without_vat AS tax_base,
  CAST(NULL AS STRING) AS claim_code,
  CAST(NULL AS STRING) AS process_code,
  
  CASE 
          WHEN RENUEVOS.total_pay_value_without_vat < 40   THEN 'GAMA A'
          WHEN RENUEVOS.total_pay_value_without_vat < 350  THEN 'GAMA B'
          WHEN RENUEVOS.total_pay_value_without_vat >= 350 THEN 'GAMA C'
  END AS comments,
  
  'C_MANUAL' AS facturador,
  `mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad
  -- ,RENUEVOS.terminal_status_ds
  -- ,RENUEVOS.cost_price
  
FROM
  `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo_nva_categ` RENUEVOS


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
  ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
   AND DEALER.canal = CHANNEL.canal

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON RENUEVOS.serial_number = MULTI.serial_number
             AND RENUEVOS.phone_nm = MULTI.phone_nm
             AND RENUEVOS.brand_ds = MULTI.brand_ds
             AND RENUEVOS.order_date = MULTI.order_date

-- LEFT JOIN (
--     SELECT serial_number
    
--     FROM `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo` RENUEVOS
    
--     WHERE
--       RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
--       AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH)
--       AND financed_type = 'PAGO FINANCIADO'
--       AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 4 MONTH)
--       AND serial_number IS NOT NULL
--     QUALIFY
--       ROW_NUMBER() OVER (PARTITION BY phone_nm, brand_ds ORDER BY RENUEVOS.activation_date ASC, RENUEVOS.deactivation_date ASC, RENUEVOS.serial_number ASC ) > 1 ) MULTI
--   ON RENUEVOS.serial_number = MULTI.serial_number


-- Asegurar que se calcula por cada servicio móvil que tenga un dispositivo, incluyendo las tarifas que no comisionan
INNER JOIN (
            SELECT service_id, phone_nm, marca
            -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
            FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
            WHERE id_mes = id_mes_pr
            AND concepto = 'A - Servicio Movil Pospago'
            AND canal IN ('ENK')
            AND estado IN ('calculado', 'validado')

            UNION ALL

            ( 
              SELECT ACTIVACIONES.service_id, ACTIVACIONES.phone_nm, ACTIVACIONES.marca
              FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
    
              LEFT JOIN (
                        SELECT service_id, phone_nm, marca, /*cond_pago*/
                        -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
                        FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
                        WHERE canal IN ('ENK') AND concepto IN ('A - Servicio Movil Pospago', 'D - Extracomision terminal') AND id_mes < id_mes_pr GROUP BY 1,2,3
                        ) TRANSACTIONS
                        ON ACTIVACIONES.service_id = TRANSACTIONS.service_id AND ACTIVACIONES.phone_nm = TRANSACTIONS.phone_nm AND ACTIVACIONES.marca = TRANSACTIONS.marca

              WHERE id_mes = id_mes_pr
                    AND TRANSACTIONS.service_id IS NULL
                    AND (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','2313','7126','7127','7169'))
            )
          ) TRANSACCIONES
      ON TRANSACCIONES.service_id = RENUEVOS.service_id AND TRANSACCIONES.phone_nm = RENUEVOS.phone_nm AND TRANSACCIONES.marca = RENUEVOS.brand_ds

-- Comprobar que no se haya pagado anteriormente la comisión para el mismo serial_number
LEFT JOIN (
           SELECT DISTINCT serial_number
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE concepto IN ('D - Extracomision terminal','Z - Extracomision terminal')
           AND estado = 'facturado'
           AND canal = 'ENK'
           AND id_mes < id_mes_pr
          ) PAGADAS
          ON PAGADAS.serial_number = RENUEVOS.serial_number

CROSS JOIN UNNEST(canales_pr) AS canal_pr


WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
  AND PAGADAS.serial_number IS NULL
  AND DEALER.canal IN UNNEST (canales_pr)
  AND DEALER.comisiona
  AND   `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
  (DEALER.canal
  ,RENUEVOS.financed_type
  ,RENUEVOS.total_pay_value_without_vat
  ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
  ,RENUEVOS.brand_ds
  ,CAST(null AS STRING)
  ,RENUEVOS.flag_pay_penalty ) > 0


QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'),service_id, marca 
                           ORDER BY RENUEVOS.activation_date ASC, 
                                    RENUEVOS.deactivation_date ASC, 
                                    RENUEVOS.original_cost_price DESC,
                                    RENUEVOS.serial_number ASC
                          ) > 1
) 

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_multidispositivos_nva_categ`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT MULTIS.*
FROM `mm-commissions-reporting.TEMP.dispositivos_capta_primarios_nva_categ` PRIMARIOS
INNER JOIN `mm-commissions-reporting.TEMP.dispositivos_capta_multidispositivos_nva_categ` MULTIS
        ON PRIMARIOS.phone_nm = MULTIS.phone_nm AND PRIMARIOS.sale_date = MULTIS.sale_date
WHERE PRIMARIOS.serial_number != MULTIS.serial_number

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_final_exclusivo_nva_categ`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT 
'DCEX'||'_'||id_mes_pr||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id,
*
FROM (
      SELECT * FROM `mm-commissions-reporting.TEMP.dispositivos_capta_primarios_nva_categ`
      UNION ALL
      SELECT * FROM `mm-commissions-reporting.TEMP.dispositivos_capta_multidispositivos_nva_categ`
     )

;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('DCEX', id_mes_pr, canales_pr, 'TEMP.dispositivos_capta_final_exclusivo_nva_categ', modo);


END