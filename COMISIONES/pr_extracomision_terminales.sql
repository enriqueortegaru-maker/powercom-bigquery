BEGIN

DECLARE mes_string STRING;
DECLARE pref_renvb, pref_renvf, pref_exex, pref_dcex, pref_exrp STRING;

SET mes_string = CAST(mes_pr AS STRING);

IF canales_pr IS NULL THEN SET canales_pr = ['EML','EYG','ENX','EDB','ENK'];
END IF;


/*
CALL COMISIONES.pr_extracomision_terminales(202609, ['EML','EYG','ENX','EDB','ENK']);
*/

-- CALL `mm-commissions-reporting.TERMINALES.pr_terminales_abonados_mes`(202609);


ASSERT EXISTS (SELECT 1 FROM `mm-commissions-reporting.TEMP.terminales_abonados_mes`)
  AS 'TEMP.terminales_abonados_mes esta vacia: ejecutar antes TERMINALES.pr_terminales_abonados_mes';


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_extracomisiones`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
SELECT TER.*
FROM `mm-commissions-reporting.TEMP.terminales_abonados_mes` TER
WHERE TER.agrupacion_canal = 'Exclusivo'
  AND EXISTS (
        SELECT 1 FROM `mm-commissions-reporting.TEMP.device_base` DEV
        WHERE DEV.serial_number = TER.IMEI AND DEV.sell_type = 'RENUEVO'
      )
  AND NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.COMISIONES.transacciones` TRA
        WHERE TRA.serial_number = TER.IMEI
          -- AND TRA.order_id = TER.oder_id
          AND TRA.concepto IN ('B - Renuevo',
                               'Z - Renuevo',
                               'F - Renuevo',
                               'Y - Renuevo'
                               )
      );


--PREFIJOS
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.prefijos_repesca`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
WITH usados AS (
  SELECT DISTINCT SPLIT(commission_id, '_')[OFFSET(0)] AS prefijo
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE id_mes = mes_pr
)
SELECT clave, CONCAT(CAST(MIN(d) AS STRING), clave) AS prefijo
FROM UNNEST(['RENVB','RENVF','EXEX','DCEX','EXRP']) clave
CROSS JOIN UNNEST(GENERATE_ARRAY(2, 9)) d
LEFT JOIN usados U
       ON U.prefijo = CONCAT(CAST(d AS STRING), clave)
WHERE U.prefijo IS NULL
GROUP BY clave;

SET pref_renvb = (SELECT prefijo FROM TEMP.prefijos_repesca WHERE clave = 'RENVB');
SET pref_renvf = (SELECT prefijo FROM TEMP.prefijos_repesca WHERE clave = 'RENVF');
SET pref_exex  = (SELECT prefijo FROM TEMP.prefijos_repesca WHERE clave = 'EXEX');
SET pref_dcex  = (SELECT prefijo FROM TEMP.prefijos_repesca WHERE clave = 'DCEX');
SET pref_exrp  = (SELECT prefijo FROM TEMP.prefijos_repesca WHERE clave = 'EXRP');

ASSERT pref_renvb IS NOT NULL AND pref_renvf IS NOT NULL AND pref_exex IS NOT NULL
   AND pref_dcex IS NOT NULL AND pref_exrp IS NOT NULL
  AS 'ERROR: no hay prefijo libre (2-9) para alguna clave de la repesca en este mes';


---- Tabla de Activaciones ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_term_activaciones`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      pref_renvb||'_'||CAST(mes_pr AS STRING)||'_'||'ENK'||'_'||ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     -- ,PARSE_DATE('%Y%m', CAST(id_mes_recla AS STRING)) AS mes_liquidado
     ,DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH) AS mes_liquidado
     ,mes_pr AS id_mes
     ,COALESCE(AGRUPACION.agrupacion_canal, DEALER.agrupacion_canal) AS agrupacion_canal
     ,DEALER.canal
     ,'B - Renuevo' AS concepto
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
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
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
          WHEN RENUEVOS.billing_type_ds = 'PREPAID'                                                 THEN '10'
          WHEN RENUEVOS.bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN'                      THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN RENUEVOS.bundle_type = 'FMC'                                                         THEN (CASE WHEN RENUEVOS.sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN RENUEVOS.bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') 
               AND RENUEVOS.brand_ds IN ('YOIGO', 'PEPEPHONE')                                      THEN '68'
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
     ,'' AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad

-- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

INNER JOIN `mm-commissions-reporting.TEMP.terminales_extracomisiones` TER
    ON TER.IMEI = RENUEVOS.serial_number
   AND TER.canal = RENUEVOS.canal
   AND TER.order_id = RENUEVOS.order_id

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
            AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

LEFT JOIN (
          SELECT DISTINCT serial_number, sale_date -- 20250616 JOHANNA: cambio phone_nm por serial_num y quito sale_date para hacer el filtro único
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE id_mes < mes_pr
                AND (concepto LIKE 'B%Renuevo%' OR concepto LIKE 'Z%Renuevo%')
          ) TRANSACCIONES
         ON RENUEVOS.serial_number = TRANSACCIONES.serial_number
            AND RENUEVOS.order_date = TRANSACCIONES.sale_date -- REVISAR SI SALEN DUPLICADOS POR INCLUIR SALE_DATE

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

WHERE TER.agrupacion_canal = 'Exclusivo'
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND RENUEVOS.sell_type = 'RENUEVO'
      AND DEALER.canal IN UNNEST(canales_pr)
      AND DEALER.comisiona
      AND TRANSACCIONES.serial_number IS NULL        

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
FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones`
QUALIFY COUNT(*) OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, marca) > 1
);


---- Tabla de Gestion de Canal (F - Renuevo) ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_term_gestion_canal`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      pref_renvf ||'_'||mes_string||'_'||DEALER.canal||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))  AS mes_liquidado
     ,mes_pr AS id_mes
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
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
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
     ,RENUEVOS.tariff_id
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

FROM `mm-commissions-reporting.TEMP.terminales_extracomisiones` TERM

INNER JOIN `mm-commissions-reporting.TEMP.device_base` RENUEVOS
          ON TERM.IMEI = RENUEVOS.serial_number
             AND TERM.canal = RENUEVOS.canal
             AND TERM.order_id = RENUEVOS.order_id


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
            AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
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

-- ELIMINADA la ventana de activacion (mes-1 / mes): ahora manda la tabla de abonados
WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND RENUEVOS.sell_type = 'RENUEVO'
      AND CASE WHEN RENUEVOS.channel_type_ds = 'INDIRECTO' THEN MULTI.sell_type = 'RENUEVO' ELSE TRUE END
      AND DEALER.canal IN UNNEST(canales_pr)
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
FROM `mm-commissions-reporting.TEMP.renuevos_term_gestion_canal`
QUALIFY COUNT(*) OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, marca) > 1
);


-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(pref_renvb, mes_pr, canales_pr, 'TEMP.renuevos_term_activaciones', 'ACTUALIZAR'); --PREFIJO!!
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(pref_renvf, mes_pr, canales_pr, 'TEMP.renuevos_term_gestion_canal', 'ACTUALIZAR'); -- PREFIJO!!


--////////EXTRACOMISIONES///////////////////////

ASSERT NOT EXISTS (
  SELECT 1
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRA
  INNER JOIN (
    SELECT serial_number, sale_date, order_id
    FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones`

    UNION DISTINCT

    SELECT serial_number, sale_date, order_id
    FROM `mm-commissions-reporting.TEMP.renuevos_term_gestion_canal`
  ) REN
    ON TRA.serial_number = REN.serial_number
   AND TRA.sale_date = REN.sale_date
   AND CAST(TRA.order_id AS STRING) = CAST(REN.order_id AS STRING)
  WHERE TRA.concepto LIKE '%Extracomision Renuevo Linea Principal%'
     or TRA.concepto LIKE '%Extracomision Tactica Renuevo%'
     or TRA.concepto LIKE '%Extracomision Terminal Renuevo%'
     or TRA.concepto LIKE '%Extracomision Renuevo TV%'

) AS 'ERROR: hay extracomisiones ya calculadas para renuevos del proceso actual';

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN
  ASSERT NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones` R
    LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` T
           ON R.commission_id = T.commission_id
          AND R.serial_number = T.serial_number
          AND T.estado IN ('calculado', 'validado')
    WHERE R.canal = 'ENK'
      AND T.commission_id IS NULL
  ) AS 'ERROR: renuevos de la repesca no insertados en transacciones o con prefijo distinto';
END IF;

DROP TABLE IF EXISTS `mm-commissions-reporting.TEMP.extracomisiones_exclusivo_repesca`;

CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.extracomisiones_exclusivo_repesca`
(
 mes_liquidado               DATE
,id_mes                      INT64
,agrupacion_canal            STRING
,canal                       STRING
,unidades                    INT64
,id_comisionista             STRING
,distribuidor                STRING
,sfid_id                     STRING
,seller                      STRING
,nombre_comercio             STRING
,razon_social                STRING
,cif                         STRING
,zona_fiscal                 STRING
,cond_pago                   STRING
,marca                       STRING
,service_type                STRING
,phone_nm                    STRING
,tariff_id                   STRING
,tariff_ds                   STRING
,service_id                  STRING
,account_id                  STRING
,customer_id                 STRING
,line_type_ds                STRING
,bundle_type                 STRING
,technology_ds               STRING
,billing_type_ds             STRING
,sale_date                   DATE
,activation_date             DATE
,deactivation_date           DATE
,order_id                    STRING
,order_type_agg              STRING
,cod_segmento                STRING
,cod_marca                   STRING
,cod_canal                   STRING
,campaign_code               STRING
,serial_number               STRING
,tax_base                    FLOAT64
,claim_code                  STRING
,process_code                STRING
,proceso_sap                 STRING
,id_registro                 STRING
,invoice_id                  STRING
,sociedad                    STRING
,bp                          STRING
,cuenta_contable             STRING
,centro_coste                STRING
,documento_sap               STRING
,documento_sap_posicion      STRING
,fecha_contabilizacion       STRING
,creado                      TIMESTAMP
,modificado                  TIMESTAMP
,id_factura_drive            STRING
,emails_acceso_trazabilidad  ARRAY<STRING>
,estado                      STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comments                    STRING
,comision                    FLOAT64
,cod_producto                STRING
,cod_tipo_contrato           STRING
)
;

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_repesca --- D - EXTRACOMISION RENUEVO LINEA PPAL. 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,15.0 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones` REPESCA

LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` RENUEVOS
     ON REPESCA.serial_number = RENUEVOS.serial_number 
          AND REPESCA.phone_nm = CAST(RENUEVOS.phone_nm AS STRING)
          AND REPESCA.order_id = CAST(RENUEVOS.id_subscription_terminal AS STRING)
          AND REPESCA.marca = RENUEVOS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON REPESCA.serial_number = MULTI.serial_number 
          AND REPESCA.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND REPESCA.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND REPESCA.marca = MULTI.brand_ds

INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     ON REPESCA.commission_id = TRANSACCIONES.commission_id
     AND TRANSACCIONES.estado IN ('calculado', 'validado')

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
     ON  TRANSACCIONES.phone_nm = VENTAS.phone_nm
     and TRANSACCIONES.service_id = VENTAS.service_id
     and TRANSACCIONES.marca = VENTAS.marca

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = mes_pr
      AND (
           TRANSACCIONES.canal IN ('ENK')
           AND TRANSACCIONES.concepto IN ('B - Renuevo')
           AND ((TRANSACCIONES.bundle_type = 'FMC')
           OR ( TRANSACCIONES.bundle_type = 'MO'
                AND TRANSACCIONES.tariff_ds LIKE '%CONV%'
                AND COALESCE(VENTAS.deactivation_date, '9999-12-31') = '9999-12-31'
                AND VENTAS.bundle_type = 'FMC'
              )
           )
           AND TRANSACCIONES.service_type = 'MOBILE'
           AND TRANSACCIONES.line_type_ds = 'MAIN'
           AND TRANSACCIONES.campaign_code = '1'
          )
     --  AND RENUEVOS.is_financed_desc = 'SI' -- 20251001 CAMBIO DE MR quitando la excepción a Pagos Únicos
     --  AND RENUEVOS.flag_pay_penalty = 'SI' -- 20251001 CAMBIO DE MR quitando la excepción a Pagos Únicos
      AND RENUEVOS.sell_terminal_origin_ds = 'RENUEVO'
      AND MULTI.multidispositivo = 'PRIMARIO'
      AND CONCEPTOS.concepto = 'D - Extracomision Renuevo Linea Principal'
     --  SI DA ERROR CRUZAR CON V_SERVICIO_RENUEVOS Y SACAR DE ESA VISTA LOS CAMPOS LINE_TYPE_DS Y BUNDLE_TYPE
     -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
     --        ON TRANSACCIONES.serial_number = RENUEVOS.serial_number 
     --             AND TRANSACCIONES.service_id = RENUEVOS.service_id
     --             AND TRANSACCIONES.order_id = CAST(RENUEVOS.order_id AS STRING)
     QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.commission_id) = 1
)
;

END IF;

--- D - EXTRACOMISION TÁCTICA RENUEVO --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_repesca --- D - EXTRACOMISION TÁCTICA RENUEVO 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,12.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones` REPESCA

LEFT JOIN `mm-commissions-reporting.TEMP.device_base` RENUEVOS
     ON REPESCA.serial_number = RENUEVOS.serial_number 
          AND REPESCA.phone_nm = RENUEVOS.phone_nm
          AND REPESCA.order_id = CAST(RENUEVOS.id_subscription_terminal AS STRING)
          AND REPESCA.marca = RENUEVOS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON REPESCA.serial_number = MULTI.serial_number 
          AND REPESCA.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND REPESCA.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND REPESCA.marca = MULTI.brand_ds

LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` SEGMENTACION
     ON (REPESCA.sfid_id = SEGMENTACION.id_comisionista OR REPESCA.seller = SEGMENTACION.id_comisionista)
          AND SEGMENTACION.id_mes = mes_pr

INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     ON REPESCA.commission_id = TRANSACCIONES.commission_id
     AND TRANSACCIONES.estado IN ('calculado', 'validado')

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = mes_pr
      AND (
           TRANSACCIONES.canal IN ('ENK')
           AND TRANSACCIONES.concepto IN ('B - Renuevo')
           AND TRANSACCIONES.campaign_code = '1'
          )
      AND SEGMENTACION.categorizacion = 'RODIO'
      AND RENUEVOS.sell_type = 'RENUEVO'
      AND MULTI.multidispositivo = 'PRIMARIO'
      AND CONCEPTOS.concepto = 'D - Extracomision Tactica Renuevo'

QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, marca ORDER BY RENUEVOS.order_date, deactivation_date, RENUEVOS.original_cost_price DESC, serial_number, RENUEVOS.id_subscription_terminal) = 1

)
;

END IF;

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN



--- D - EXTRACOMISION TERMINAL RENUEVO
INSERT INTO TEMP.extracomisiones_exclusivo_repesca
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CASE 
          WHEN DEVICES.total_pay_value_without_vat < 40    THEN 'GAMA A'
          WHEN DEVICES.total_pay_value_without_vat < 350   THEN 'GAMA B'
          WHEN DEVICES.total_pay_value_without_vat < 600   THEN 'GAMA C'
          WHEN DEVICES.total_pay_value_without_vat < 1000  THEN 'GAMA D'
          WHEN DEVICES.total_pay_value_without_vat >= 1000 THEN 'GAMA E'
      END AS comments

     ,CASE
          -- RENUEVOS PRIMARIOS FINANCIADOS
          WHEN MULTI.multidispositivo = 'PRIMARIO' AND DEVICES.is_financed_desc = 'SI' THEN
               CASE 
                    WHEN DEVICES.total_pay_value_without_vat < 40                   THEN IF(TRANSACCIONES.activation_date < '2026-07-20', 0.0, 10.0)
                    WHEN DEVICES.total_pay_value_without_vat < 350                  THEN IF(TRANSACCIONES.activation_date < '2026-07-20', 5.0, 20.0)
                    WHEN DEVICES.total_pay_value_without_vat < 600                  THEN IF(TRANSACCIONES.activation_date < '2026-07-20', 15.0, 35.0)
                    WHEN DEVICES.total_pay_value_without_vat BETWEEN 600 AND 999.99 THEN IF(TRANSACCIONES.activation_date < '2026-07-20', 25.0, 45.0)
                    WHEN DEVICES.total_pay_value_without_vat >= 1000                THEN IF(TRANSACCIONES.activation_date < '2026-07-20', 40.0, 60.0)
               END
          
          -- RENUEVOS MULTIDISPOSITIVO FINANCIADOS
          WHEN MULTI.multidispositivo = 'SECUNDARIO' AND DEVICES.is_financed_desc = 'SI' THEN
               CASE 
                    WHEN DEVICES.total_pay_value_without_vat < 40                   THEN 0.0
                    WHEN DEVICES.total_pay_value_without_vat < 350                  THEN 5.0
                    WHEN DEVICES.total_pay_value_without_vat < 600                  THEN 15.0
                    WHEN DEVICES.total_pay_value_without_vat BETWEEN 600 AND 999.99 THEN 25.0
                    WHEN DEVICES.total_pay_value_without_vat >= 1000                THEN 40.0
               END
          
          -- RENUEVOS PAGO ÚNICO
          WHEN DEVICES.is_financed_desc = 'NO' THEN
               CASE 
                    WHEN DEVICES.total_pay_value_without_vat < 40                   THEN 0.0
                    WHEN DEVICES.total_pay_value_without_vat < 350                  THEN 5.0
                    WHEN DEVICES.total_pay_value_without_vat < 600                  THEN 15.0
                    WHEN DEVICES.total_pay_value_without_vat BETWEEN 600 AND 999.99 THEN 25.0
                    WHEN DEVICES.total_pay_value_without_vat >= 1000                THEN 40.0
               END
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones` REPESCA

INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
          ON REPESCA.serial_number = DEVICES.serial_number 
          AND REPESCA.phone_nm = CAST(DEVICES.phone_nm AS STRING) 
          AND REPESCA.marca = DEVICES.brand_ds 
          AND REPESCA.order_id = CAST(DEVICES.id_subscription_terminal AS STRING)
          AND DEVICES.sell_terminal_origin_ds = 'RENUEVO'
          AND DEVICES.terminal_status_ds IN UNNEST(`mm-commissions-reporting.COMISIONES.f_terminal_status`())

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON REPESCA.serial_number = MULTI.serial_number 
          AND REPESCA.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND REPESCA.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND REPESCA.marca = MULTI.brand_ds

INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     ON REPESCA.commission_id = TRANSACCIONES.commission_id
     AND TRANSACCIONES.estado IN ('calculado', 'validado')


CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.concepto = 'B - Renuevo'
      AND TRANSACCIONES.billing_type_ds = 'POSTPAID'
      AND MULTI.sell_type = 'RENUEVO'
      AND CONCEPTOS.concepto = 'D - Extracomision Terminal Renuevo'
GROUP BY ALL
HAVING comision <> 0.00
)
;

END IF;

--- D - EXTRACOMISION RENUEVO TV (LEGO) --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_repesca --- D - EXTRACOMISION RENUEVO TV (LEGO)
(
SELECT 
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comision, cod_producto, cod_tipo_contrato, estado, comments)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,TRANSACCIONES.comments
     ,12.0 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones` REPESCA

INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
          ON REPESCA.serial_number = DEVICES.serial_number 
          AND REPESCA.phone_nm = CAST(DEVICES.phone_nm AS STRING) 
          AND REPESCA.marca = DEVICES.brand_ds 
          AND REPESCA.order_id = CAST(DEVICES.id_subscription_terminal AS STRING)
             AND DEVICES.sell_terminal_origin_ds = 'RENUEVO'
             AND DEVICES.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON REPESCA.serial_number = MULTI.serial_number 
          AND REPESCA.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND REPESCA.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND REPESCA.marca = MULTI.brand_ds

INNER JOIN `mm-commissions-reporting.COMISIONES.v_servicio_television` TELEVISION
     ON REPESCA.customer_id = TELEVISION.customer_id

INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     ON REPESCA.commission_id = TRANSACCIONES.commission_id
     AND TRANSACCIONES.estado IN ('calculado', 'validado')

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = mes_pr
      AND TRANSACCIONES.canal IN ('ENK')
      AND TRANSACCIONES.concepto = 'B - Renuevo'
      AND TRANSACCIONES.billing_type_ds = 'POSTPAID'
      AND TRANSACCIONES.activation_date >= '2026-07-20'
      AND MULTI.sell_type = 'RENUEVO'
      AND MULTI.multidispositivo = 'PRIMARIO'
      AND CONCEPTOS.concepto = 'D - Extracomision Renuevo TV'
      AND (
            TELEVISION.deactivation_date IS NULL
          OR
            TELEVISION.deactivation_date > DATE_ADD(MULTI.order_date, INTERVAL 6 MONTH)
          ) 
      AND TELEVISION.activation_date IS NOT NULL
      AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) < COALESCE(DATE_TRUNC(TELEVISION.deactivation_date, MONTH), '9999-12-31')
     
GROUP BY ALL
HAVING comision <> 0.00

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.serial_number) = 1
)
;

END IF;


CREATE OR REPLACE TABLE TEMP.extracomisiones_exclusivo_final_repesca 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      *
     ,pref_exex || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM TEMP.extracomisiones_exclusivo_repesca
WHERE comision IS NOT NULL
)
;


-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo` (pref_exex, mes_pr, ['ENK'] , 'TEMP.extracomisiones_exclusivo_final_repesca' , 'ACTUALIZAR');-- PREFIJO!!


--/////CAPTACION/////////////////////
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_capta_pendientes`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
SELECT TER.*
FROM `mm-commissions-reporting.TEMP.terminales_abonados_mes` TER
LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRA
       ON TER.IMEI = TRA.serial_number
      AND TER.order_id = TRA.order_id
      AND TER.canal = TRA.canal
      AND TRA.concepto IN ('D - Extracomision terminal', 'Z - Extracomision terminal')
WHERE TRA.serial_number IS NULL
  AND TER.canal IN UNNEST(canales_pr)
  AND EXISTS (
        SELECT 1 FROM `mm-commissions-reporting.TEMP.device_base` DEV
        WHERE DEV.serial_number = TER.IMEI AND DEV.sell_type = 'CAPTACION'
);

---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo_repesca` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
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
     DATE(DATE_TRUNC(DEVICE.picking_date_ts, MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
     OR
     DATE(DATE_TRUNC(DEVICE.picking_date_ts, MONTH)) = DATE_TRUNC(SALES.order_date,MONTH) 
    )
AND DATE(DATE_TRUNC(SALES.activation_date, MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
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


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_primarios_repesca`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
  'calculado' AS estado,
  PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado,
  mes_pr AS id_mes,
  DEALER.agrupacion_canal,
  DEALER.canal,
  'D - Extracomision terminal' as concepto,
  'UPFR' as tipo_concepto,
  1 AS unidades,

  `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
      (DEALER.canal
      ,RENUEVOS.financed_type
      ,((RENUEVOS.not_financed_price + RENUEVOS.q25_amount + RENUEVOS.financed_total_amount)/(1 + RENUEVOS.tax_value))
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
          WHEN (RENUEVOS.not_financed_price + RENUEVOS.q25_amount + RENUEVOS.financed_total_amount)/(1 + RENUEVOS.tax_value) < 40   THEN 'GAMA A'
          WHEN (RENUEVOS.not_financed_price + RENUEVOS.q25_amount + RENUEVOS.financed_total_amount)/(1 + RENUEVOS.tax_value) < 350  THEN 'GAMA B'
          WHEN (RENUEVOS.not_financed_price + RENUEVOS.q25_amount + RENUEVOS.financed_total_amount)/(1 + RENUEVOS.tax_value) >= 350 THEN 'GAMA C'
  END AS comments,

  'C_MANUAL' AS facturador,
  `mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad

FROM `mm-commissions-reporting.TEMP.dispositivos_capta_activaciones_exclusivo_repesca` RENUEVOS

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
        AND DEALER.id_mes = mes_pr

-- NUEVO: solo dispositivos pendientes de repesca (mismo IMEI+order_id+canal que abono terminales)
INNER JOIN `mm-commissions-reporting.TEMP.terminales_capta_pendientes` TERM
        ON RENUEVOS.serial_number = TERM.IMEI
       AND CAST(RENUEVOS.order_id AS STRING) = TERM.order_id
       AND DEALER.canal = TERM.canal

INNER JOIN  `mm-commissions-reporting.GS.CANALES` CHANNEL
      ON AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
      AND DEALER.canal = CHANNEL.canal

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final`  MULTI
          ON RENUEVOS.serial_number = MULTI.serial_number
             AND RENUEVOS.phone_nm = MULTI.phone_nm
             AND RENUEVOS.brand_ds = MULTI.brand_ds
             AND RENUEVOS.order_date = MULTI.order_date

INNER JOIN (
            SELECT service_id, phone_nm, marca
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE id_mes = mes_pr
            AND concepto = 'A - Servicio Movil Pospago'
            AND canal IN ('ENK')
            AND estado IN ('calculado', 'validado')

            UNION ALL

            (
              SELECT ACTIVACIONES.service_id, ACTIVACIONES.phone_nm, ACTIVACIONES.marca
              FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES

              LEFT JOIN (
                        SELECT service_id, phone_nm, marca
                        FROM `mm-commissions-reporting.COMISIONES.transacciones`
                        WHERE canal IN ('ENK') AND concepto IN ('A - Servicio Movil Pospago', 'D - Extracomision terminal') AND id_mes < mes_pr GROUP BY 1,2,3
                        ) TRANSACTIONS
                        ON ACTIVACIONES.service_id = TRANSACTIONS.service_id AND ACTIVACIONES.phone_nm = TRANSACTIONS.phone_nm AND ACTIVACIONES.marca = TRANSACTIONS.marca

              WHERE id_mes = mes_pr
                    AND TRANSACTIONS.service_id IS NULL
                    AND (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','2313','7126','7127','7108','7115'))
            )
          ) TRANSACCIONES
      ON TRANSACCIONES.service_id = RENUEVOS.service_id AND TRANSACCIONES.phone_nm = RENUEVOS.phone_nm AND TRANSACCIONES.marca = RENUEVOS.brand_ds

LEFT JOIN (
           SELECT DISTINCT serial_number
           FROM `mm-commissions-reporting.COMISIONES.transacciones`
           WHERE concepto IN ('D - Extracomision terminal','Z - Extracomision terminal')
           AND estado = 'facturado'
           AND canal = 'ENK'
           AND id_mes < mes_pr
          ) PAGADAS
          ON PAGADAS.serial_number = RENUEVOS.serial_number

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
  AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
  AND PAGADAS.serial_number IS NULL
  AND DEALER.canal IN UNNEST (canales_pr)
  AND DEALER.comisiona
  AND   `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
      (DEALER.canal
      ,RENUEVOS.financed_type
      ,((RENUEVOS.not_financed_price + RENUEVOS.q25_amount + RENUEVOS.financed_total_amount)/(1 + RENUEVOS.tax_value))
      ,CASE WHEN MULTI.multidispositivo = 'SECUNDARIO' THEN 2 ELSE 1 END
      ,RENUEVOS.brand_ds
      ,CAST(null AS STRING)
      ,RENUEVOS.flag_pay_penalty ) > 0
  AND MULTI.multidispositivo = 'PRIMARIO'

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'),service_id, marca
                           ORDER BY RENUEVOS.activation_date ASC,
                                    RENUEVOS.deactivation_date ASC,
                                    RENUEVOS.original_cost_price DESC,
                                    RENUEVOS.serial_number ASC
                          ) = 1
)
;



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_capta_final_exclusivo_repesca`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT
pref_dcex||'_'||CAST(mes_pr AS STRING)||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id,
*
FROM `mm-commissions-reporting.TEMP.dispositivos_capta_primarios_repesca`
;

--CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`(pref_dcex, mes_pr, ['ENK'], 'TEMP.dispositivos_capta_final_exclusivo_repesca', 'ACTUALIZAR');


--//////////////////////////////////////////////////////////////////////////////////////////
--/////OBJETIVO TERMINALES////////////////////////////////////////////////////////////////

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

ASSERT NOT EXISTS (
  SELECT 1
  FROM (
        SELECT commission_id, serial_number
        FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones`
        WHERE canal = 'ENK'
        UNION ALL
        SELECT commission_id, serial_number
        FROM `mm-commissions-reporting.TEMP.dispositivos_capta_final_exclusivo_repesca`
        WHERE canal = 'ENK'
       ) R
  LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` T
         ON R.commission_id = T.commission_id
        AND R.serial_number = T.serial_number
        AND T.estado IN ('calculado', 'validado')
  WHERE T.commission_id IS NULL
) AS 'ERROR: hay renuevos/captaciones que no estan insertados en transacciones o no coinciden';


CREATE OR REPLACE TABLE TEMP.calculo_objetivo_terminales_repesca
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
SELECT
      TRANSACCIONES.* EXCEPT (concepto, comision, commission_id, mes_liquidado, facturador, tipo_concepto, comments, id_mes, estado, tariff_id, tariff_ds, claim_code)
     ,ENK.multiplicador_terminales AS comision
     ,REPLACE(CONCEPTOS.concepto, 'D - ', 'Z - ') AS concepto
     ,CONCEPTOS.tipo_concepto
     ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
     ,mes_pr AS id_mes
     ,'C_MANUAL' AS facturador
     ,'calculado' AS estado
     ,CAST(NULL AS STRING) AS comments
     ,DEVICES.tariff_id
     ,DEVICES.tariff_ds
     ,CAST(NULL AS STRING) AS claim_code

FROM (
      SELECT commission_id FROM `mm-commissions-reporting.TEMP.renuevos_term_activaciones`
      UNION DISTINCT
      SELECT commission_id FROM `mm-commissions-reporting.TEMP.dispositivos_capta_final_exclusivo_repesca`
     ) REPESCA

INNER JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
        ON REPESCA.commission_id = TRANSACCIONES.commission_id
       AND TRANSACCIONES.estado IN ('calculado', 'validado')

LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` ENK
       ON (TRANSACCIONES.sfid_id = ENK.id_comisionista OR TRANSACCIONES.seller = ENK.id_comisionista)
      AND ENK.id_mes = mes_pr

LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
       ON TRANSACCIONES.serial_number = DEVICES.serial_number
      AND (TRANSACCIONES.activation_date = DATE(DEVICES.order_date) OR TRANSACCIONES.sale_date = DATE(DEVICES.order_date))
      AND (TRANSACCIONES.seller = DEVICES.user_store
           OR TRANSACCIONES.seller = UPPER(SPLIT(DEVICES.user_store,'@')[SAFE_OFFSET(0)])
           OR TRANSACCIONES.seller = UPPER(SPLIT(DEVICES.seller,'@')[SAFE_OFFSET(0)]))
      AND TRANSACCIONES.service_id = DEVICES.service_id
      AND TRANSACCIONES.account_id = DEVICES.account_id

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = mes_pr
  AND TRANSACCIONES.canal = 'ENK'
  AND TRANSACCIONES.concepto IN ('B - Renuevo', 'D - Extracomision terminal')
  AND CONCEPTOS.proceso LIKE '%EXRP%'
  AND CONCEPTOS.concepto = 'D - Extracomision Objetivo Terminales'
  AND ENK.id_comisionista IS NOT NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.serial_number
                           ORDER BY TRANSACCIONES.activation_date, TRANSACCIONES.commission_id) = 1
;

CREATE OR REPLACE TABLE TEMP.final_objetivo_terminales_repesca
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT
     mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
     ,unidades
     ,seller AS id_comisionista
     ,distribuidor
     ,seller AS sfid_id
     ,seller
     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
     ,'Z005' AS cond_pago
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
     ,CASE WHEN deactivation_date = '9999-12-31' THEN NULL ELSE deactivation_date END AS deactivation_date 
     ,order_id         
     ,order_type_agg   
     ,cod_segmento     
     ,cod_marca        
     ,cod_canal        
     ,campaign_code    
     ,serial_number    
     ,tax_base         
     ,claim_code
     ,process_code 
     ,proceso_sap               
     ,id_registro               
     ,invoice_id                
     ,sociedad                  
     ,bp                        
     ,cuenta_contable           
     ,centro_coste              
     ,documento_sap             
     ,documento_sap_posicion    
     ,fecha_contabilizacion     
     ,creado                    
     ,modificado                
     ,id_factura_drive          
     ,emails_acceso_trazabilidad
     ,estado  
     ,concepto      
     ,tipo_concepto
     ,facturador   
     ,comments     
     ,comision     
     ,cod_producto 
     ,cod_tipo_contrato       
     ,pref_exrp ||'_'||CAST(mes_pr AS STRING)||'_'||canal||'_'|| ROW_NUMBER () OVER () AS commission_id
     
FROM TEMP.calculo_objetivo_terminales_repesca 
WHERE comision > 0.0
;

END IF;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(pref_exrp, mes_pr, ['ENK'], 'TEMP.final_objetivo_terminales_repesca', 'ACTUALIZAR');


END