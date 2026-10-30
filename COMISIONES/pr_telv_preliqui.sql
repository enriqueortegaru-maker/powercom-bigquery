BEGIN

DECLARE mes_string, prefijo STRING;

SET mes_string = FORMAT_DATE('%Y%m', mes_pr);

SET prefijo = 'TELV';

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo);

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH','CA', 'GB','MP', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU', 'CI' ,'WA', 'ECI', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN', 'GUUK', 'GUD2D'];
END IF;


/*
CALL COMISIONES.pr_telv_preliqui(DATE('2026-08-01'),['ENK','EML','EYG'],'DAILY');
*/


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_activaciones_preliqui` AS
SELECT
      prefijo||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_pr AS mes_liquidado
     ,CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64) AS id_mes
     --,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) AS agrupacion_canal
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,concepto
     ,tipo_concepto
     ,1 AS unidades
     ,`mm-commissions-reporting.COMISIONES.f_comision_television`
      (
      DEALER.canal,
      TELEVISION.brand_ds, 
      TELEVISION.product_id,
      TELEVISION.product,
      premium = 1,
           ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
      CASE
            WHEN TELEVISION.order_date < '2026-01-01'
             THEN COALESCE(COALESCE(tlv_cross_sell.comentarios, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')),tlv_cross_sell.campaign)

            ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV'))
      END,
      TRUE,
      FALSE
      )
      AS comision
      --- vendedor ---
     ,DEALER.id_comisionista
     ,COALESCE(distribuidor, DEALER.id_comisionista) AS distribuidor
     
     ,CASE WHEN DEALER.agrupacion_canal = 'Exclusivo' AND LENGTH(DEALER.sfid_id) = 2 THEN seller ELSE DEALER.sfid_id END AS sfid_id

     ,seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,cif
     ,DEALER.zona_fiscal
     ,DEALER.cond_pago
      --- servicio ---
     ,brand_ds AS marca
     ,'TV' AS service_type
     ,CAST(phone_nm AS STRING) AS phone_nm
     ,product_id AS tariff_id
     ,product AS tariff_ds
--      ,service_id
     ,COALESCE(service_id,service_tv_id) AS service_id
     ,account_id
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,order_date AS sale_date
     ,activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'006' AS cod_producto
     ,TELEVISION.cod_canal

     ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
     ,CASE
            WHEN TELEVISION.order_date < '2026-01-01'
             THEN COALESCE(COALESCE(tlv_cross_sell.comentarios, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')),tlv_cross_sell.campaign)

            ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV'))
      END as campaign_code


--      ,CAST(NULL AS STRING)  AS serial_number
     ,TELEVISION.service_tv_id AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_servicio_television` TELEVISION

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TELEVISION.premium = 1 THEN 'PREMIUM' ELSE 'BASE' END = CONCEPTOS.subproceso AND CONCEPTOS.proceso = 'TELV'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (TELEVISION.sfid_id = DEALER.sfid_id 
            OR (TELEVISION.brand_ds = 'YOIGO' AND SUBSTR(TELEVISION.sfid_id, 1, 2) = DEALER.sfid_id)
            OR TELEVISION.seller = DEALER.sfid_id
            OR TELEVISION.sfid_id || '-' || TELEVISION.seller = REPLACE(DEALER.sfid_id, ' ', ''))
            AND CAST (DEALER.id_mes AS STRING) = mes_string

-- LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             TELEVISION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(TELEVISION.activation_date, MONTH) = mes_pr
      AND activation_date <= COALESCE(TELEVISION.deactivation_date, '9999-12-31')
      --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
      AND TELEVISION.agrupacion_canal = DEALER.agrupacion_canal
      AND TELEVISION.order_type_agg != 'MIGRACION CONTRATO'
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND NOT (
              DEALER.canal IN ('XS')
              AND TELEVISION.brand_ds = 'MASMOVIL'
              AND DEALER.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013','CAROUT033')
              AND CASE
                      WHEN TELEVISION.activation_date < '2024-07-22' --<-- INCLUSION DE NUEVOS SFIDS Y CAMPAÑAS EN TLV CROSS-SELL - JULIO 2024
                      THEN COALESCE(
                                    `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, seller, 'TV')
                                   ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, COALESCE(distribuidor, DEALER.id_comisionista), 'TV')
                                   ,TLV_CROSS_SELL.campaign
                                   )
                      
                      ELSE COALESCE(
                                    TLV_CROSS_SELL.campaign
                                   ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, seller, 'TV')
                                   ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, COALESCE(distribuidor, DEALER.id_comisionista), 'TV')
                                   )
                  END = 'Lineas adicionales OUT'
              )

          AND NOT (
              DEALER.canal = 'XS'
              AND DEALER.id_comisionista IN ('CAROUT032')
              
              )
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, brand_ds ORDER BY activation_date DESC) = 1
;


ASSERT NOT EXISTS
(
SELECT service_id
FROM `mm-commissions-reporting.TEMP.tv_activaciones_preliqui`
GROUP BY marca, concepto, service_id
HAVING COUNT(1) > 1
);


---- Tabla de Gestion de Canal ----

SET prefijo = 'TVGC';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_gestion_canal_preliqui` AS
SELECT
      prefijo||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_pr AS mes_liquidado
     ,CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64) AS id_mes
     --,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) AS agrupacion_canal
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,REPLACE(concepto, 'B -', 'F -') AS concepto
     ,tipo_concepto
     ,1 AS unidades
     ,`mm-commissions-reporting.COMISIONES.f_comision_television`
      (
      DEALER.canal,
      TELEVISION.brand_ds, 
      TELEVISION.product_id,
      TELEVISION.product,
      premium = 1,
           ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
      CASE
            WHEN TELEVISION.order_date < '2026-01-01'
             THEN COALESCE(COALESCE(tlv_cross_sell.comentarios, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')),tlv_cross_sell.campaign)

            ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV'))
      END,
      FALSE,
      TRUE
      ) AS comision
      --- vendedor ---
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,COALESCE(distribuidor, DEALER.id_comisionista) AS distribuidor
     
     ,CASE WHEN DEALER.agrupacion_canal = 'Exclusivo' AND LENGTH(DEALER.sfid_id) = 2 THEN seller ELSE DEALER.sfid_id END AS sfid_id
     
     ,seller
     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.cond_pago
      --- servicio ---
     ,brand_ds AS marca
     ,'TV' AS service_type
     ,CAST(phone_nm AS STRING) AS phone_nm
     ,product_id AS tariff_id
     ,product AS tariff_ds
--      ,service_id
     ,COALESCE(service_id,service_tv_id) AS service_id
     ,account_id
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,order_date AS sale_date
     ,activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'006' AS cod_producto
     ,TELEVISION.cod_canal

          ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
     ,CASE
            WHEN TELEVISION.order_date < '2026-01-01'
             THEN COALESCE(COALESCE(tlv_cross_sell.comentarios, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')),tlv_cross_sell.campaign)

            ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV'))
      END as campaign_code
              
--      ,CAST(NULL AS STRING)  AS serial_number
     ,TELEVISION.service_tv_id AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_servicio_television` TELEVISION

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TELEVISION.premium = 1 THEN 'PREMIUM' ELSE 'BASE' END = CONCEPTOS.subproceso AND CONCEPTOS.proceso = 'TELV'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (TELEVISION.sfid_id = DEALER.sfid_id 
            OR (TELEVISION.brand_ds = 'YOIGO' AND SUBSTR(TELEVISION.sfid_id, 1, 2) = DEALER.sfid_id)
            OR TELEVISION.seller = DEALER.sfid_id
            OR TELEVISION.sfid_id || '-' || TELEVISION.seller = REPLACE(DEALER.sfid_id, ' ', ''))
            AND CAST(DEALER.id_mes AS STRING) = mes_string

LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             TELEVISION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

INNER JOIN (SELECT DISTINCT gc from `mm-commissions-reporting.GS.CONCEPTOS`, UNNEST(SPLIT(gestion_canal, ',')) gc) GESTION_CANAL
           ON DEALER.canal = GESTION_CANAL.gc

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(TELEVISION.activation_date, MONTH) = mes_pr
      AND activation_date <= COALESCE(TELEVISION.deactivation_date, '9999-12-31')
      --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
      AND TELEVISION.agrupacion_canal = DEALER.agrupacion_canal
      AND TELEVISION.order_type_agg != 'MIGRACION CONTRATO'
      AND TELEVISION.agrupacion_canal != 'Exclusivo'
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND ((DEALER.agrupacion_canal = 'No Exclusivo' AND MASTER.id_comisionista IS NOT NULL) OR DEALER.agrupacion_canal <> 'No Exclusivo')
      AND NOT (
            DEALER.canal = 'WA'
            AND DEALER.id_comisionista IN ('RONL004', 'RONL025', 'RONL050', 'MW','3W')
            )
      AND NOT (
            DEALER.canal = 'OU'
            AND DEALER.id_comisionista IN ('TLVOU009', 'TLVOU022')
            )
      AND NOT (
            DEALER.canal = 'DO'
            AND DEALER.id_comisionista IN ('DONL003', 'NE')
            )
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, brand_ds ORDER BY activation_date DESC) = 1
;


ASSERT NOT EXISTS
(
SELECT service_id
FROM `mm-commissions-reporting.TEMP.tv_gestion_canal_preliqui`
GROUP BY marca, concepto, service_id
HAVING COUNT(1) > 1
);


---- Tabla de Clawback ----

SET prefijo = 'TVCB';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_clawback_preliqui` AS
SELECT
      TRANSACCIONES.* EXCEPT(concepto, comision, commission_id, estado, mes_liquidado, deactivation_date, bundle_type, cod_producto, facturador, campaign_code, comments, id_mes, id_comisionista, distribuidor, sfid_id, seller, nombre_comercio, razon_social, cif, zona_fiscal)
     ,prefijo||'_'||mes_string||'_'||TRANSACCIONES.canal||'_'||ROW_NUMBER () OVER () AS commission_id
     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF(VENTAS.deactivation_date, TRANSACCIONES.activation_date, DAY), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision AS comision

     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto NOT LIKE '%Premium%'     THEN 'H - Clawback Television'
           WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto LIKE '%Premium%'         THEN 'H - Clawback Television Premium'
           WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto NOT LIKE '%Premium%' THEN 'E - Clawback Television'
           WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto LIKE '%Premium%'     THEN 'E - Clawback Television Premium'
      END AS concepto

     ,'calculado' AS estado
     ,mes_pr AS mes_liquidado
     ,CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64) AS id_mes
     ,VENTAS.deactivation_date

     ,CASE WHEN VENTAS.bundle_type = 'DESC' THEN 'FMC' ELSE VENTAS.bundle_type END AS bundle_type
     ,'006' AS cod_producto

     ,'C_MANUAL' AS facturador

      ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
     ,CASE
            WHEN TRANSACCIONES.sale_date < '2026-01-01'
             THEN COALESCE(COALESCE(tlv_cross_sell.comentarios, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(TRANSACCIONES.canal, TRANSACCIONES.marca, TRANSACCIONES.sfid_id, 'TV')),tlv_cross_sell.campaign)

            ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(TRANSACCIONES.canal, TRANSACCIONES.marca, TRANSACCIONES.sfid_id, 'TV'))
      END as campaign_code

     ,'Factura cargo retrotraído en un '|| REPLACE(CAST(-100 * `mm-commissions-reporting.COMISIONES.f_comision_clawback`
     (DATE_DIFF(VENTAS.deactivation_date, TRANSACCIONES.activation_date, DAY), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) AS STRING), '.', '') || '%: ' || TRANSACCIONES.invoice_id AS comments

     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,DEALER.id_comisionista AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal

FROM (
     SELECT
           * 
          ,1 AS rank

     FROM (
          SELECT
                * EXCEPT(comision)
               ,SUM(comision) OVER (PARTITION BY service_id, marca) AS comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE service_type = 'TV'
                AND SUBSTR(concepto,1,1) NOT IN ('F', 'H', 'S', 'Y','C')
                AND concepto NOT LIKE ('%Acelerador%')
                AND concepto NOT LIKE ('%Multiplicador%')
                AND concepto NOT LIKE ('%Camp%')
                AND concepto NOT LIKE ('%estion%')
                AND estado = 'facturado'
          )
     WHERE comision > 0
     QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca ORDER BY concepto ASC) = 1

     UNION ALL

     SELECT
           *
          ,1 AS rank
     FROM (
          SELECT
                * EXCEPT(comision)
               ,SUM(comision) OVER (PARTITION BY service_id, marca) AS comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE service_type = 'TV'
                AND (SUBSTR(concepto,1,1) IN ('F', 'H', 'S', 'Y') OR concepto LIKE ('%estion%'))
                AND concepto NOT LIKE ('%Acelerador%')
                AND concepto NOT LIKE ('%Multiplicador%')
                AND concepto NOT LIKE ('%GPV%')
                AND estado = 'facturado'
                AND agrupacion_canal != ' Exclusivo'
          )
     WHERE comision > 0
     QUALIFY RANK() OVER (PARTITION BY service_id, marca ORDER BY concepto ASC) = 1

     UNION ALL

     SELECT
           * EXCEPT(comision, sociedad)
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
          ,CAST(NULL AS STRING) AS bp
          ,CAST(NULL AS STRING) AS cuenta_contable
          ,CAST(NULL AS STRING) AS centro_coste
          ,CAST(NULL AS STRING) AS documento_sap
          ,CAST(NULL AS STRING) AS documento_sap_posicion
          ,CAST(NULL AS STRING) AS fecha_contabilizacion
          ,CAST(NULL AS TIMESTAMP) AS creado
          ,CAST(NULL AS TIMESTAMP) AS modificado
          ,CAST(NULL AS STRING) AS id_factura_drive
          ,NULL AS emails_acceso_trazabilidad
          ,comision
          ,2 AS rank

     FROM `mm-commissions-reporting.TEMP.tv_activaciones_preliqui`
     
     WHERE DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH) = mes_pr

     UNION ALL

     SELECT
           * EXCEPT(comision, sociedad)
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
          ,CAST(NULL AS STRING) AS bp
          ,CAST(NULL AS STRING) AS cuenta_contable
          ,CAST(NULL AS STRING) AS centro_coste
          ,CAST(NULL AS STRING) AS documento_sap
          ,CAST(NULL AS STRING) AS documento_sap_posicion
          ,CAST(NULL AS STRING) AS fecha_contabilizacion
          ,CAST(NULL AS TIMESTAMP) AS creado
          ,CAST(NULL AS TIMESTAMP) AS modificado
          ,CAST(NULL AS STRING) AS id_factura_drive
          ,NULL AS emails_acceso_trazabilidad
          ,comision
          ,2 AS rank

     FROM `mm-commissions-reporting.TEMP.tv_gestion_canal_preliqui`
     
     WHERE DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH) = mes_pr

     ) TRANSACCIONES

INNER JOIN `mm-commissions-reporting.COMISIONES.v_servicio_television` VENTAS
          ON TRANSACCIONES.service_id = VENTAS.service_id AND TRANSACCIONES.marca = VENTAS.brand_ds

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON TRANSACCIONES.id_comisionista = TLV_CROSS_SELL.id_comisionista AND TRANSACCIONES.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE DATE_TRUNC(COALESCE(VENTAS.deactivation_date, '9999-12-31'), MONTH) = mes_pr
      AND TRANSACCIONES.activation_date <= VENTAS.deactivation_date
      AND TRANSACCIONES.canal = canal_pr
      AND DEALER.comisiona
      AND `mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF(VENTAS.deactivation_date, TRANSACCIONES.activation_date, day), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision != 0
      AND NOT (
            TRANSACCIONES.canal IN ('XS')
            AND TRANSACCIONES.marca = 'MASMOVIL'
            AND TRANSACCIONES.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
            AND TRANSACCIONES.campaign_code = 'Lineas adicionales OUT'
            )
      AND NOT (
            TRANSACCIONES.canal = 'WA'
            AND TRANSACCIONES.id_comisionista IN ('RONL004', 'RONL025', 'RONL050', 'MW','3W')
            )
      AND NOT (
            TRANSACCIONES.canal = 'OU'
            AND TRANSACCIONES.id_comisionista IN ('TLVOU009', 'TLVOU022')
            )
      AND NOT (
            TRANSACCIONES.canal = 'DO'
            AND TRANSACCIONES.id_comisionista IN ('DONL003', 'NE')
            )
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, concepto ORDER BY rank ASC) = 1
;


ASSERT NOT EXISTS
(
SELECT service_id
FROM `mm-commissions-reporting.TEMP.tv_clawback_preliqui`
GROUP BY marca, concepto, service_id, canal
HAVING COUNT(1) > 1
);


--- Insertar tabla final ----
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('TELV_', CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64), canales_pr, 'TEMP.tv_activaciones_preliqui', modo);
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('TVGC_', CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64), canales_pr, 'TEMP.tv_gestion_canal_preliqui', modo);
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('TVCB_', CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64), canales_pr, 'TEMP.tv_clawback_preliqui', modo);


END