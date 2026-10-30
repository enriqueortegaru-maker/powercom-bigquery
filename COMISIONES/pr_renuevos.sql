BEGIN
--
DECLARE sql, mes_string STRING;

SET mes_string = CAST(mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','D2D','D2N','DEM','EDB', 'EML', 'EYG', 'ENX', 'ENK', 'OU', 'OUN','PH', 'XI', 'XIN', 'XS','XSN','XSO','WA'];
END IF;


/*
CALL COMISIONES.pr_renuevos(202605, ['ENK','EML']);
*/


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_activaciones`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      'RENVB'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,COALESCE(AGRUPACION.agrupacion_canal, DEALER.agrupacion_canal) AS agrupacion_canal
     ,DEALER.canal
     ,concepto
     ,tipo_concepto
     ,1 AS unidades
     
     ,`mm-commissions-reporting.COMISIONES.f_comision_renuevos`
      (
      DEALER.canal,
      CASE WHEN RENUEVOS.order_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign END,
      RENUEVOS.brand_ds,
      DEALER.sfid_id,
      TRUE,
      FALSE,
      CASE WHEN DEALER.CANAL IN ('D2D','D2N','DEM') THEN RENUEVOS.original_cost_price ELSE RENUEVOS.total_pay_value END,
      RENUEVOS.courier,
      CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END,
      RENUEVOS.is_financed_desc
      ) AS comision

      --- vendedor ---
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id

     ,CASE WHEN RENUEVOS.seller IN ('ygoffline') THEN UPPER(RENUEVOS.user_store) ELSE UPPER(RENUEVOS.seller) END AS seller

     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,RENUEVOS.brand_ds AS marca
     ,'MOBILE' AS service_type --<----------- REVISAR
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     -- ,product_id AS tariff_id
     ,RENUEVOS.tariff_id
     -- ,product AS tariff_ds
     ,RENUEVOS.tariff_ds
     ,RENUEVOS.service_id
     ,RENUEVOS.account_id
     ,RENUEVOS.customer_id
     ,RENUEVOS.line_type_ds
     ,RENUEVOS.bundle_type
     ,RENUEVOS.technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,RENUEVOS.order_date AS sale_date
     ,RENUEVOS.activation_date
     ,RENUEVOS.deactivation_date
     ,CAST(RENUEVOS.order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(RENUEVOS.segment_ds, RENUEVOS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RENUEVOS.brand_ds) AS cod_marca

     ,CASE
          WHEN RENUEVOS.billing_type_ds = 'PREPAID'                                               THEN '10'
          WHEN RENUEVOS.bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN'                    THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN RENUEVOS.bundle_type = 'FMC'                                                       THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN RENUEVOS.bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') 
               AND RENUEVOS.brand_ds IN ('YOIGO', 'PEPEPHONE')                                             THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,'050' AS cod_producto

     ,CASE
          WHEN RENUEVOS.cod_canal IN ('14', '15') THEN '29'
          ELSE RENUEVOS.cod_canal
      END AS cod_canal

     ,CASE
          WHEN AGRUPACION.agrupacion_canal = 'Exclusivo' THEN CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN '2' ELSE '1' END
           WHEN RENUEVOS.order_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign 
     END AS campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad

-- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.id_prefijo = 'RENV'

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(RENUEVOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND RENUEVOS.master_channel_ds = AGRUPACION.master_channel_ds
            AND RENUEVOS.channel_ds = AGRUPACION.channel_ds
            AND RENUEVOS.subchannel_ds = AGRUPACION.subchannel_ds
            AND RENUEVOS.brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
            OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
            OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
            OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
            )
            --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
            AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

LEFT JOIN (
          SELECT DISTINCT serial_number, sale_date -- 20250616 JOHANNA: cambio phone_nm por serial_num y quito sale_date para hacer el filtro único
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE id_mes < mes_pr
                AND (concepto LIKE 'B%Renuevo%' OR concepto LIKE 'Z%Renuevo%')
          ) TRANSACCIONES
         ON RENUEVOS.serial_number = TRANSACCIONES.serial_number
            AND RENUEVOS.order_date = TRANSACCIONES.sale_date -- REVISAR SI SALEN DUPLICADOS POR INCLUIR SALE_DATE

-- LEFT JOIN (
--           SELECT serial_number
--           -- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
--           FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

--           LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
--           ON (
--                UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
--                OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
--                OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
--                OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
--                )
--                -- AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
--                AND DEALER.id_mes = mes_pr
               
--           WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
--           -- AÑADO FILTRO POR LOS ÚLTIMOS 6 MESES PARA LIBERAR PESO AL PROCESO --
--           -- AND RENUEVOS.activation_date >= DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)),INTERVAL 6 MONTH)

--                 AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
--                --  AND is_financed_desc = 'SI' -- 20260327 PARA INCLUIR PAGOS ÚNICOS EN EL ANÁLISIS DE PRIMARIO O MULTIDISPOSITIVO
--                 AND (
--                        (
--                        DEALER.canal = 'ENK' 
--                        AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
--                        )
--                     OR   
--                        (
--                        DEALER.canal != 'ENK' 
--                        AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
--                        )

--                     )
--                 AND serial_number IS NOT NULL
--           QUALIFY ROW_NUMBER() OVER (
--                                     PARTITION BY phone_nm, brand_ds
--                                     ORDER BY RENUEVOS.activation_date ASC,
--                                              RENUEVOS.deactivation_date ASC,
--                                              RENUEVOS.original_cost_price DESC,
--                                              RENUEVOS.serial_number ASC
--                                     ) > 1
--           ) MULTI
--          ON RENUEVOS.serial_number = MULTI.serial_number

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON RENUEVOS.serial_number = MULTI.serial_number
             AND RENUEVOS.phone_nm = MULTI.phone_nm
             AND RENUEVOS.brand_ds = MULTI.brand_ds
             AND RENUEVOS.order_date = MULTI.order_date
             AND (
                  UPPER(MULTI.sfid_id) = DEALER.sfid_id 
                  OR UPPER(MULTI.seller) = DEALER.sfid_id
                  OR UPPER(MULTI.user_store) = DEALER.sfid_id
                 )

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH)
        BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND RENUEVOS.sell_type = 'RENUEVO'
      AND CASE WHEN RENUEVOS.channel_type_ds = 'INDIRECTO' THEN MULTI.sell_type = 'RENUEVO' ELSE TRUE END
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND TRANSACCIONES.serial_number IS NULL

      AND NOT (
              DEALER.canal IN ('XS','XSO')
              AND RENUEVOS.brand_ds = 'MASMOVIL'
              AND DEALER.id_comisionista IN ('CAROUT006',  'CAROUT013')
              )

          AND NOT (
              DEALER.canal = 'XS'
              AND DEALER.id_comisionista IN ('CAROUT032')
              
              )
        

      AND COALESCE(`mm-commissions-reporting.COMISIONES.f_comision_renuevos`
           (
            DEALER.canal
           ,CASE WHEN RENUEVOS.order_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign END
           ,RENUEVOS.brand_ds
           ,DEALER.sfid_id
           ,TRUE
           ,FALSE
           ,CASE WHEN DEALER.CANAL IN ('D2D','D2N','DEM') THEN RENUEVOS.original_cost_price ELSE RENUEVOS.total_pay_value END
           ,RENUEVOS.courier
           ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
           ,RENUEVOS.is_financed_desc
           ),0.0) <> 0.0 -- JOHANNA 20250623: AGREGAMOS COALESCE CON EL 0.00 PARA QUE NO CALCULE GC POR UPFRONTS DE OTROS CANALES

     AND NOT (DEALER.agrupacion_canal = 'D2D' AND `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(RENUEVOS.segment_ds, RENUEVOS.brand_ds) != '12')

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, marca ORDER BY activation_date DESC, order_id ASC) = 1
)
;


ASSERT NOT EXISTS
(
SELECT COALESCE(serial_number, 'Z'), service_id, marca
FROM `mm-commissions-reporting.TEMP.renuevos_activaciones`
QUALIFY COUNT(*) OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, marca) > 1
);


---- Tabla de Gestion de Canal ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_gestion_canal`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      'RENVF'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))  AS mes_liquidado
     ,mes_pr AS id_mes
     --,COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds), DEALER.agrupacion_canal) AS agrupacion_canal
     ,COALESCE(AGRUPACION.agrupacion_canal, DEALER.agrupacion_canal) AS agrupacion_canal
     ,DEALER.canal
     ,REPLACE(concepto, 'B -', 'F -') AS concepto
     ,tipo_concepto
     ,1 AS unidades
     ,`mm-commissions-reporting.COMISIONES.f_comision_renuevos`
      (
      DEALER.canal,
      CASE WHEN RENUEVOS.order_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign END,
      RENUEVOS.brand_ds,
      DEALER.sfid_id,
      FALSE,
      TRUE,
      RENUEVOS.total_pay_value,
      RENUEVOS.courier,
      CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END,
      RENUEVOS.is_financed_desc
      ) AS comision
      --- vendedor ---
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,CASE WHEN CANAL = 'ALTN' THEN DEALER.distribuidor ELSE COALESCE(DEALER.distribuidor, DEALER.id_comisionista) END AS distribuidor
     ,DEALER.sfid_id

     ,CASE WHEN RENUEVOS.seller IN ('ygoffline') THEN RENUEVOS.user_store ELSE UPPER(RENUEVOS.seller) END AS seller

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
      --- servicio ---
     ,RENUEVOS.brand_ds AS marca
     ,'MOBILE' AS service_type --<----------- REVISAR
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     -- ,product_id AS tariff_id
     ,RENUEVOS.tariff_id
     -- ,product AS tariff_ds
     ,RENUEVOS.tariff_ds
     ,RENUEVOS.service_id
     ,RENUEVOS.account_id
     ,RENUEVOS.customer_id
     ,RENUEVOS.line_type_ds
     ,RENUEVOS.bundle_type
     ,RENUEVOS.technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,RENUEVOS.order_date AS sale_date
     ,RENUEVOS.activation_date
     ,RENUEVOS.deactivation_date
     ,CAST(RENUEVOS.order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(RENUEVOS.segment_ds, RENUEVOS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RENUEVOS.brand_ds) AS cod_marca

     ,CASE
          WHEN RENUEVOS.billing_type_ds = 'PREPAID'                                               THEN '10'
          WHEN RENUEVOS.bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN'                    THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN RENUEVOS.bundle_type = 'FMC'                                                       THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN RENUEVOS.bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') 
               AND RENUEVOS.brand_ds IN ('YOIGO', 'PEPEPHONE')                                             THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato

     ,'050' AS cod_producto

     ,CASE
          WHEN RENUEVOS.cod_canal IN ('14', '15') THEN '29'
          ELSE RENUEVOS.cod_canal
      END AS cod_canal

      --- informacion adicional ---

     ,CASE
          WHEN AGRUPACION.agrupacion_canal = 'Exclusivo' THEN CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN '2' ELSE '1' END
          WHEN RENUEVOS.order_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign 
      END AS campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad

-- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.id_prefijo = 'RENV'

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(RENUEVOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND RENUEVOS.master_channel_ds = AGRUPACION.master_channel_ds
            AND RENUEVOS.channel_ds = AGRUPACION.channel_ds
            AND RENUEVOS.subchannel_ds = AGRUPACION.subchannel_ds
            AND RENUEVOS.brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
            OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
            OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
            OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
            )
            --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
            AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

LEFT JOIN (
          SELECT DISTINCT serial_number, agrupacion_canal, sale_date -- 20250616 JOHANNA: cambio phone_nm por serial_num y quito sale_date para hacer el filtro único
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE id_mes < mes_pr
                AND (concepto LIKE 'F%Renuevo%' OR concepto LIKE 'Y%Renuevo%')
          ) TRANSACCIONES
         ON RENUEVOS.serial_number = TRANSACCIONES.serial_number
         AND DEALER.agrupacion_canal = TRANSACCIONES.agrupacion_canal
            AND RENUEVOS.order_date = TRANSACCIONES.sale_date

-- LEFT JOIN (
--           SELECT serial_number
--           -- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
--           FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS
--           WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
--           -- AÑADO FILTRO POR LOS ÚLTIMOS 6 MESES PARA LIBERAR PESO AL PROCESO --
--           -- AND RENUEVOS.activation_date >= DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)),INTERVAL 6 MONTH)
          
--                 AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
--                 AND is_financed_desc = 'SI'
--                 AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
--                 AND serial_number IS NOT NULL
--           QUALIFY ROW_NUMBER() OVER (
--                                     PARTITION BY phone_nm, brand_ds
--                                     ORDER BY RENUEVOS.activation_date ASC,
--                                              RENUEVOS.deactivation_date ASC,
--                                              RENUEVOS.original_cost_price DESC,
--                                              RENUEVOS.serial_number ASC
--                                     ) > 1
--           ) MULTI
--          ON RENUEVOS.serial_number = MULTI.serial_number

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON RENUEVOS.serial_number = MULTI.serial_number
             AND RENUEVOS.phone_nm = MULTI.phone_nm
             AND RENUEVOS.brand_ds = MULTI.brand_ds
             AND RENUEVOS.order_date = MULTI.order_date
             AND (
                  UPPER(MULTI.sfid_id) = DEALER.sfid_id 
                  OR UPPER(MULTI.seller) = DEALER.sfid_id
                  OR UPPER(MULTI.user_store) = DEALER.sfid_id
                 )

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH)
        BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND RENUEVOS.sell_type = 'RENUEVO'
      AND CASE WHEN RENUEVOS.channel_type_ds = 'INDIRECTO' THEN MULTI.sell_type = 'RENUEVO' ELSE TRUE END
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND TRANSACCIONES.serial_number IS NULL
      AND `mm-commissions-reporting.COMISIONES.f_comision_renuevos`
           (
            DEALER.canal
           ,CASE WHEN RENUEVOS.order_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign END
           ,RENUEVOS.brand_ds
           ,DEALER.sfid_id
           ,FALSE
           ,TRUE
           ,RENUEVOS.total_pay_value
           ,RENUEVOS.courier
           ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
           ,RENUEVOS.is_financed_desc
           ) <> 0.0

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, order_id, marca ORDER BY activation_date DESC) = 1
)
;


ASSERT NOT EXISTS
(
SELECT COALESCE(serial_number, 'Z'), service_id, marca
FROM `mm-commissions-reporting.TEMP.renuevos_gestion_canal`
QUALIFY COUNT(*) OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, marca) > 1
);


---- Tabla de Clawback ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_clawback_date`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date, cod_canal)
     ,COALESCE(DATE(DEVICES.cancellation_date_ts), PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))) AS deactivation_date

     ,CASE
          WHEN cod_canal IN ('14', '15') THEN '29'
          ELSE cod_canal
      END AS cod_canal

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
          ON TRANSACCIONES.serial_number = DEVICES.serial_number
             AND TRANSACCIONES.service_id = DEVICES.service_id
             AND TRANSACCIONES.order_id = CAST(DEVICES.id_subscription_terminal AS STRING)

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE (
      (COALESCE(DATE_TRUNC(DATE(cancellation_date_ts), MONTH), '9999-12-31') = DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      AND
      DEVICES.terminal_status_ds IN ('CANCELADO', 'EXPEDICIÓN PENDIENTE DE CANCELACIÓN', 'PENDIENTE A DESACTIVAR','DESISTIDO'))
      OR
      COALESCE(DATE_TRUNC(DATE(cancellation_date_ts), MONTH), '9999-12-31') = DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      OR
      COALESCE(DATE_TRUNC(DATE(cancellation_date_ts), MONTH), '9999-12-31') = PARSE_DATE('%Y%m', mes_string)
      )
      AND DATE_TRUNC(DATE(TRANSACCIONES.activation_date), MONTH) = DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH)
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.comision > 0
      AND (TRANSACCIONES.commission_id LIKE '%RENV%' OR TRANSACCIONES.commission_id LIKE '%RPD%')

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, concepto, marca ORDER BY activation_date DESC) = 1
)
;



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_clawback_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - ' ELSE 'E - ' END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     ,TRANSACCIONES.tipo_concepto

     ,CASE
          WHEN id_comisionista IN ('BYMOVIL','BY') AND LENGTH(seller) > 2  THEN seller
          WHEN id_comisionista = 'BY' AND LENGTH(sfid_id) > 2 THEN sfid_id
          ELSE id_comisionista
      END AS id_comisionista

     ,TRANSACCIONES.marca
     ,MIN(TRANSACCIONES.service_type) AS service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,MAX(TRANSACCIONES.deactivation_date) AS deactivation_date
     ,MAX(TRANSACCIONES.cod_segmento) AS cod_segmento
     ,TRANSACCIONES.cod_marca
     ,MAX(TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,TRANSACCIONES.sociedad
     ,MAX(TRANSACCIONES.bundle_type) AS bundle_type
     ,MAX(TRANSACCIONES.campaign_code) AS campaign_code
     ,MAX(TRANSACCIONES.line_type_ds) AS line_type_ds
     ,MAX(TRANSACCIONES.order_id) AS order_id
     ,MAX(TRANSACCIONES.order_type_agg) AS order_type_agg
     ,serial_number
     ,MAX(TRANSACCIONES.tariff_ds) AS tariff_ds
     ,MAX(TRANSACCIONES.tariff_id) AS tariff_id
     ,MAX(TRANSACCIONES.tax_base) AS tax_base
     ,MAX(TRANSACCIONES.technology_ds) AS technology_ds
     ,MAX(TRANSACCIONES.comments) AS comments
     ,SUM(TRANSACCIONES.comision) AS comision
     ,ARRAY_AGG(TRANSACCIONES.commission_id) AS commission_id

FROM `mm-commissions-reporting.TEMP.renuevos_clawback_date` TRANSACCIONES

WHERE SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto)) IN
        (
         'Clawback Rappel Renuevo'
        ,'Renuevo'
        ,'Rappel Renuevo'
        )

GROUP BY 1,2,3,4,5,6,8,9,10,11,12,13,14,17,19,20,21,27
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_clawback_dealer`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(
                            canal,
                            comision,
                            commission_id,
                            id_comisionista,
                            campaign_code
                            )
     
     ,'RENVE' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int(mes_pr) AS mes_liquidado
     ,mes_pr as id_mes
     ,1 AS unidades
     ,COALESCE(DEALER.canal, TRANSACCIONES.canal) AS canal
     ,TRANSACCIONES.comision * -1 AS comision
     
     ,CASE
          -- WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'BYMOVIL'
          WHEN TRANSACCIONES.agrupacion_canal = 'Guuk' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y')      THEN 'BYMOVIL'
          ELSE COALESCE(MASTER.id_comisionista, DEALER.id_comisionista)
      END AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.distribuidor

     ,CASE WHEN TRANSACCIONES.sale_date < '2026-01-01' THEN TLV_CROSS_SELL.comentarios ELSE TLV_CROSS_SELL.campaign
      END AS campaign_code
              
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.renuevos_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.renuevos_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.renuevos_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) COMM
          LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
                   ON REPLACE(COMM, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0
)
;

ASSERT NOT EXISTS
(
SELECT COALESCE(serial_number, 'Z'), service_id, concepto, marca
FROM `mm-commissions-reporting.TEMP.renuevos_clawback`
QUALIFY COUNT(*) OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, concepto, marca) > 1
);

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN
  UPDATE `mm-commissions-reporting.TEMP.renuevos_activaciones` v
  SET comision = v.comision * f.porcentaje
  FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
  WHERE v.cif = f.cif
    AND f.id_mes = mes_pr
    AND v.activation_date >= '2026-07-01'
    AND v.estado = 'calculado'
    AND v.canal IN ('D2D','D2N','DEM');
END IF;

--- Insertar tabla final ----

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RENVB', mes_pr, canales_pr, 'TEMP.renuevos_activaciones', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RENVF', mes_pr, canales_pr, 'TEMP.renuevos_gestion_canal', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RENVE', mes_pr, canales_pr, 'TEMP.renuevos_clawback', 'ACTUALIZAR');


END