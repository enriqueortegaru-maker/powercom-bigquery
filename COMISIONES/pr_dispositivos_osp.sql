BEGIN

DECLARE sql, mes_string STRING;

SET mes_string = CAST(mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','BO','DO','DOT','WA','XSO','XO','XIBO','OUO','OSPNBO','OSPNOUN','MKT_NR'];
END IF;


/*
CALL COMISIONES.pr_dispositivos_osp(202603, ['OUOCC','XSO']);
*/


---- CREAMOS TABLA TEMPORAL PARA DISPOSITIVOS DE JAZZTEL HASTA QUE LA INFO ESTÉ OK EN DEVICES ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.DISPOSITIVOS_JAZZTEL`  AS (
  SELECT
    CASE WHEN VENTA IN ("POSTVENTA","RENOVE") THEN "RENUEVO" ELSE "CAPTACION" END AS tipo_venta,
    "OSP" AS data_source_ds,
    CAST(NULL AS STRING) AS account_id,
    CAST(cusjzz.DWH_CUSTOMER_KEY AS STRING) AS customer_id,
    CAST(ID_EXPEDIENTE AS STRING) AS service_id,
    CAST(ID_RELACION_DISP AS INT64) AS id_subscription_terminal, --ID_DISPOSITIVO
    CASE
      WHEN TIPO_SERVICIO_1 = "POSTPAGO" THEN "MOBILE"
      WHEN TIPO_SERVICIO_1 = "FIJO" THEN "BROADBAND"
      ELSE REPLACE(TIPO_SERVICIO_1,"MOVIL","MOBILE")
    END AS service_type,
    SEGMENTO AS segment_ds,
    "JAZZTEL" AS brand_ds,
    COALESCE(FC_ALTA_DISP) AS order_day_id,
    CAST(TIME(fecha_alta_exp) AS STRING) AS order_hour_id,
    CASE
      WHEN DESESTIMIENTO='NO' AND ESTADO_PEDIDO_DISP IN ('FINALIZADO') THEN FC_RFB_DISP
      ELSE NULL
    END AS activation_date,
    CASE
      WHEN DESESTIMIENTO='NO' AND ESTADO_PEDIDO_DISP IN ('FINALIZADO') THEN FC_RFB_DISP
      ELSE NULL
    END AS fecha_entrega, -- Fecha de activación con criterio de Comisiones
    DATE(NULL) AS deactivation_date,
    CAST(NULL AS INT64) AS canal_alta_id,
    CANAL_TIDEMARCK AS channel_ds,
    SUBGRUPO_CANAL_DISP AS subchannel_ds,
    CAST(CCC_DISP AS STRING) AS sfid_id,
    AGENTE AS user_store,
    AGENTE AS seller,
    CAST(NULL AS STRING) AS tariff_id,
    CAST(NULL AS STRING) AS tafiff_ds,
    TARIFA AS tariff_ds,
    CAST(NUM_TLF AS STRING) AS phone_nm,
    MARCA AS manufacturer_name,
    CONCAT(REPLACE(REPLACE(MARCA," TERMINAL","")," TERMINAL MOVIL",""), CONCAT(" ", MODELO)) AS terminal_model,
    CUOTA_FINANCIACION AS Cuota,
    CAST(MESES_FINANCIACION AS STRING) AS Periodo,
    CAST(CUOTA_INICIAL AS STRING) AS initial_payment,
    CAST(PRECIO_REFERENCIA_DISP AS STRING) AS total_pay_value,
    VENTA AS order_type_ds,
    TIPO_DISP AS payment_type,
    DATE(NULL) AS financed_init_date,
    DATE(NULL) AS financed_end_date,
    CAST(NULL AS STRING) AS mac,    
    CASE
      WHEN GAMA LIKE ("SMARTPHONE%") OR GAMA IN ("TERMINAL") THEN CASE WHEN IMEI = -66  THEN NULL ELSE CAST(IMEI AS STRING) END
      ELSE CASE WHEN NUMERO_SERIE IN ("SIN DATOS") THEN NULL ELSE NUMERO_SERIE END
    END AS serial,
    GAMA AS device_type_ds,
    CAST(NULL AS STRING) AS frontal,
    CAST(id_relacion_disp AS STRING) AS order_id,
    CASE
      WHEN DESESTIMIENTO='NO' AND ESTADO_PEDIDO_DISP IN ('FINALIZADO') THEN "ENTREGADO"
      WHEN DESESTIMIENTO='NO' AND ESTADO_PEDIDO_DISP IN ('EN CURSO', 'EN ELABORACION') THEN "EN VUELO"
      ELSE "CANCELADO" 
    END AS order_status_ds,
    ESTADO_PEDIDO_DISP AS expedition_status_ds,
    MOTIVO_CANCELACION AS end_reason,
    campanias.PLATAFORMA AS plataforma,
    CAST(NULL AS STRING) AS bundle_type,
    COALESCE(NULL,"RESIDENCIAL") AS channel_segment_ds,
    TIPO_CANAL_DISP AS superchannel_ds,
    campanias.DE_CAMPANIA AS campaign,
    
    CAST(ESTADO_DISP AS STRING) terminal_status_ds,
    CAST(FORMAT_DATETIME("%Y-%m-%d", COALESCE(FECHA_VN,FC_ALTA_DISP)) AS STRING) AS fecha_venta_formato,
    REF_TERMINAL AS codigo_terminal,

    TIPO_DISP AS financed_type,
    CAST(NULL AS STRING) AS canal_cvm,

    CAST(NULL AS STRING) AS catalog,
    CAST(NULL AS STRING) AS channel_id_catalogo_enum,

    CAST(NULL AS STRING) AS CROSSELL, 
    CAST(NULL AS INT64) AS CROSSELL_phone_nm,
    DATE(NULL) AS CROSSELL_order_day_id,
    DATE(NULL) AS CROSSELL_activation_date,
    CAST(NULL AS STRING) AS CROSSELL_sfid_id,

    PROVINCIA AS provincia,
    MUNICIPIO_INE AS poblacion,
    CP AS zip_code,

    CAST(NULL AS STRING) AS line_Type_ds,

    CAST(NULL AS STRING) AS payterm,

    "POSTPAID" AS billing_type_ds,

    REPLACE(CAST(jzz.ref_terminal AS STRING),"-V","") AS SAP_CODE_ID,
    CAST(NULL AS STRING) AS sales_contract_id,

    DE_DISPOSITIVO AS second_device_flg,

    id_permanencia AS device_subvention_id,
    CAST(NULL AS STRING) AS distribution_type_ds,

    cusjzz.document_hash AS document_hash,

    tipo_entrega AS delivery_method,

    DATE(NULL) AS test_date,

    CAST(NULL AS STRING) AS dig_signature_status_agg 
  
  FROM
    `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.jzz_2102_dispositivos` AS jzz
  LEFT JOIN
    `mm-datamart-kd.PERSONAL_INFO.osp_maestro_customer_jazztel` AS cusjzz
  ON
    CAST(jzz.ID_CLIENTE AS STRING) = cusjzz.CUSTOMER_ID

  LEFT JOIN (
    SELECT
      DISTINCT
      ID_CCC,
      DE_CAMPANIA,
      RAZON_SOCIAL AS PLATAFORMA,
      ROW_NUMBER() OVER (PARTITION BY ID_CCC ORDER BY DE_CAMPANIA DESC) AS RN
    FROM
      `mm-sales-reporting.SAS_TELEVENTA.DM_JAZZ_CAMPANIAS`
  ) AS campanias
  ON
    jzz.CCC_DISP = campanias.ID_CCC
    AND campanias.RN = 1

  WHERE
    GAMA NOT IN ('MODEM/USB','ROUTER','REPETIDOR_WIFI','MODEM','STB')
    AND	TIPO_CANAL_DISP NOT IN ('TRASLADOS')

)
;
---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivos_OSP` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS (

SELECT DISTINCT
  CASE WHEN DEVICE.brand_ds = 'JAZZTEL' THEN JAZZ.tipo_venta
       WHEN DEVICE.brand_ds = 'ORANGE' AND DEVICE.sell_type = 'RENOVE' THEN 'RENUEVO' ELSE 'CAPTACION' END AS sell_type,
  SALES.CANAL_N0 AS master_channel_ds,
  SALES.CANAL_N1 AS channel_ds,
  SALES.CANAL_N2 AS subchannel_ds,
  AGRUPACION.codigo_canal_sap AS cod_canal,
  DEVICE.sfid_id,
  CAST (NULL AS STRING) AS SFIDPADRE,
  DEVICE.user_store AS user_store,
  UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)]) AS seller,
  SALES.channel_segment_ds AS channel_segment_ds,
  DEVICE.segment_ds,
  DEVICE.brand_ds,
  CAST(DEVICE.service_id AS STRING )  AS service_id,
  DEVICE.tariff_id,
  DEVICE.tariff_ds,
  COALESCE(SALES.sell_bundle_type, 'MO') AS bundle_type,
  COALESCE(REPLACE(SALES.sell_line_type_ds, 'DESC', 'MAIN'), 'MAIN') AS line_type_ds,
  COALESCE(SALES.billing_type_ds, 'POSTPAID') AS billing_type_ds,
  COALESCE(SALES.technology_ds, 'MOBILE') AS sales_technology_ds,
  DEVICE.service_type AS technology_ds,
  COALESCE(DEVICE.service_type, JAZZ.service_type) AS service_type,
  DEVICE.order_type_agg,
  CAST(DEVICE.phone_nm AS STRING) phone_nm,
  DATE(DEVICE.order_date) AS order_date,
  COALESCE(DATE(JAZZ.ACTIVATION_DATE),DATE(DEVICE.provider_delivery_date)) AS activation_date,
  DATE(DEVICE.cancellation_date_ts) AS deactivation_date,
  CAST(DEVICE.account_id AS STRING) AS account_id,
  CAST(DEVICE.customer_id AS STRING) AS customer_id,
  CAST(NULL AS STRING) AS order_id,
  DEVICE.device_type_ds AS device_type,
  DEVICE.product_code AS product_id,
  DEVICE.tech_description AS product,
  CASE
    WHEN DEVICE.is_financed_desc = 'SI' THEN 'PAGO FINANCIADO'
    ELSE 'NO FINANCIADO'
    END
    AS financed_type,
  DEVICE.flag_pay_penalty,
  DEVICE.serial_number,
  DEVICE.data_source_ds AS data_source,
  DEVICE.financed_end_date,
  DEVICE.total_pay_value,
  DEVICE.courier,
  DEVICE.terminal_status_ds,
  DEVICE.terminal_name,
  DEVICE.terminal_id ,
  DEVICE.terminal_model,
  CASE WHEN DEVICE.BRAND_DS = 'JAZZTEL' THEN CAST(JAZZ.total_pay_value AS FLOAT64)
       WHEN DEVICE.BRAND_DS = 'ORANGE'  THEN CAST(DEVICE.TOTAL_PAY_VALUE AS FLOAT64)/1.21 ----REVISAR
   END AS PVP,
    CASE WHEN DEVICE.brand_ds = 'JAZZTEL' AND UPPER(JAZZ.second_device_flg) LIKE '%SECUNDARIO%' THEN 1 
       WHEN DEVICE.brand_ds = 'JAZZTEL' AND UPPER(JAZZ.second_device_flg) NOT LIKE '%SECUNDARIO%' THEN 0 
  ELSE DEVICE.second_device_flg END AS second_device_flg,
  COALESCE(CAST(JAZZ.order_id AS STRING),CAST(DEVICE.id_subscription_terminal AS STRING)) AS id_subscription_terminal
FROM `mm-datamart-kd.SERVICES.devices_base_osp` DEVICE

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
  ON (DEVICE.sfid_id = DEALER.id_comisionista OR DEVICE.sfid_id = DEALER.SFID_ID)
  AND DEALER.id_mes = mes_pr


LEFT JOIN `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` SALES
  ON CAST(DEVICE.service_id AS STRING) = SALES.service_id
    AND DEVICE.brand_ds = SALES.brand_ds


LEFT JOIN `mm-commissions-reporting.TEMP.DISPOSITIVOS_JAZZTEL` JAZZ
ON DEVICE.phone_nm = JAZZ.phone_nm 
  AND DEVICE.brand_ds = JAZZ.brand_ds
  AND CAST(DEVICE.customer_id AS STRING) = JAZZ.customer_id 
  AND DEVICE.item_number = JAZZ.order_id

LEFT JOIN
  (
    SELECT *
    FROM
      `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`,
      UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal
  ) AGRUPACION
  ON COALESCE(SALES.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
    AND SALES.CANAL_N0 = AGRUPACION.master_channel_ds
    AND SALES.CANAL_N1 = AGRUPACION.channel_ds
    AND SALES.CANAL_N2 = AGRUPACION.subchannel_ds
    AND DEVICE.brand_ds = AGRUPACION.comm_brand_ds

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DEVICE.brand_ds IN ('ORANGE','SIMYO','JAZZTEL')
AND DEALER.CANAL = canal_pr
  AND DATE(DATE_TRUNC(DEVICE.provider_delivery_date, MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
  AND DATE(DATE_TRUNC(COALESCE(DATE(JAZZ.ACTIVATION_DATE),DATE(DEVICE.provider_delivery_date)),MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
AND (
              /*CAPTACION*/
           (
              (DEVICE.brand_ds = 'ORANGE'
               AND DEVICE.sell_type IN ('ALTA NUEVA', 'PORTABILIDAD','MIGRACION','ALTA POR PORTABILIDAD') 
               AND DEVICE.terminal_status_ds IN ('EN FINANCIACION','LIQUIDACION')
              )
              OR
              (DEVICE.brand_ds = 'ORANGE'
               AND DEVICE.sell_type IN ('TERMINAL SIN SERVICIO') 
               AND DEVICE.terminal_status_ds IS NULL
              )
              OR
                (DEVICE.brand_ds = 'JAZZTEL'
               AND JAZZ.tipo_venta = 'CAPTACION'
               AND DEVICE.terminal_status_ds IN ('EN FINANCIACION','LIQUIDACION')
              )
              OR
              (DEVICE.brand_ds = 'JAZZTEL'
               AND JAZZ.tipo_venta = 'CAPTACION' 
               AND DEVICE.terminal_status_ds IS NULL
              )
           ) 
          OR
           (      
              /*RENUEVO*/ 
           DEVICE.brand_ds = 'ORANGE'              
           AND DEVICE.sell_type IN ('RENOVE')
           AND (
               DEVICE.expedition_status_ds IN ('CONFIRMACION ENTREGA','CONFIRMACIÓN ENTREGA','ENTREGADO')
               OR DEVICE.terminal_status_ds = 'EN FINANCIACION'
               OR DEVICE.terminal_status_ds = 'LIQUIDACION'
               )
           )
          OR
           (      
              /*RENUEVO*/  
           DEVICE.brand_ds = 'ORANGE'              
           AND DEVICE.sell_type IN ('RENOVE')
           AND (
               DEVICE.terminal_status_ds NOT IN ('CANCELADO', 'EXPEDICIÓN PENDIENTE DE CANCELACIÓN', 'PENDIENTE A DESACTIVAR','DESISTIDO','DESISTIMIENTO')
               )
           )
          OR
          (      
              /*RENUEVO*/ 
           DEVICE.brand_ds = 'JAZZTEL'              
           AND JAZZ.tipo_venta = 'RENUEVO' 
           AND (
               DEVICE.expedition_status_ds IN ('CONFIRMACION ENTREGA','CONFIRMACIÓN ENTREGA','ENTREGADO')
               OR DEVICE.terminal_status_ds = 'EN FINANCIACION'
               OR DEVICE.terminal_status_ds = 'LIQUIDACION'
               )
           )
          OR
           (      
              /*RENUEVO*/  
           DEVICE.brand_ds = 'JAZZTEL'              
           AND JAZZ.tipo_venta = 'RENUEVO' 
           AND (
               DEVICE.terminal_status_ds NOT IN ('CANCELADO', 'EXPEDICIÓN PENDIENTE DE CANCELACIÓN', 'PENDIENTE A DESACTIVAR','DESISTIDO','DESISTIMIENTO')
               )
           )
          )


QUALIFY RANK () OVER (
                     PARTITION BY DEVICE.service_id, DEVICE.terminal_id 
                     ORDER BY CASE WHEN SALES.order_day_id <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_day_id, '9999-12-31') END DESC,
                              CASE WHEN SALES.order_day_id > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.order_day_id, '9999-12-31') END ASC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') <= DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END DESC,
                              CASE WHEN COALESCE(SALES.activation_date, '9999-12-31') > DATE(DEVICE.order_date)
                                   THEN COALESCE(SALES.activation_date, '9999-12-31') END ASC,
                              SALES.deactivation_date ASC,
                              CASE WHEN DEVICE.sfid_id = DEALER.sfid_id THEN 1 ELSE 2 END ASC,
                              DEALER.creado DESC  --Tomamos la última actualización
                     ) = 1
                     )
;

-- CAPTACION  -- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.captacion_activaciones_OSP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS
(SELECT  'DSOSP'||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id,* 
FROM 
(SELECT
     
     'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,COALESCE(AGRUPACION.agrupacion_canal, DEALER.agrupacion_canal) AS agrupacion_canal
     ,DEALER.canal
     ,CASE WHEN DEALER.CANAL = 'ALTN' THEN concepto ELSE 'D - Dispositivo Captacion' END AS concepto
     ,'UPFR' AS tipo_concepto
     ,1 AS unidades
     
     ,CASE WHEN DEALER.CANAL ='ALTN' THEN 15 
      WHEN DEALER.CANAL IN ('BO','XIBO','OSPNBO') THEN 3.00 
      ---- ENDESA ---
      WHEN DEALER.CANAL = 'ENDE' AND RENUEVOS.second_device_flg = 1 THEN 5   --- Secundario
      WHEN DEALER.CANAL = 'ENDE' AND RENUEVOS.second_device_flg != 1 THEN 15 --- Primario

      --- TLV - OUTBOUND COLD CALLING JAZZTEL
      WHEN DEALER.CANAL = 'OUOC' 
            AND RENUEVOS.BRAND_DS = 'JAZZTEL'
            AND RENUEVOS.service_type = 'FTTH'
            AND RENUEVOS.financed_type = 'PAGO FINANCIADO' 
            AND CAMP.campaign IN ('COLD CALLING',
                                  'COLD CALLING OFFSHORE',
                                  'COLD CALLING TEMPL',
                                  'COLD CALLING TRADICIONAL CRECIMIENTOS',
                                  'COLD CALLING V3'
                                  ) 
            AND RENUEVOS.PVP < 2 THEN 4

      WHEN DEALER.CANAL = 'OUOC' 
            AND RENUEVOS.BRAND_DS = 'JAZZTEL'
            AND RENUEVOS.service_type = 'FTTH'
            AND RENUEVOS.financed_type = 'PAGO FINANCIADO' 
            AND CAMP.campaign IN ('COLD CALLING',
                                  'COLD CALLING OFFSHORE',
                                  'COLD CALLING TEMPL',
                                  'COLD CALLING TRADICIONAL CRECIMIENTOS',
                                  'COLD CALLING V3'
                                  ) 
            AND RENUEVOS.PVP >= 2 THEN 24

    WHEN DEALER.CANAL = 'OUOC' 
            AND RENUEVOS.BRAND_DS = 'JAZZTEL'
            AND RENUEVOS.service_type = 'MOVIL'
            AND RENUEVOS.financed_type = 'PAGO FINANCIADO' 
            AND CAMP.campaign IN ('COLD CALLING',
                                  'COLD CALLING OFFSHORE',
                                  'COLD CALLING TEMPL',
                                  'COLD CALLING TRADICIONAL CRECIMIENTOS',
                                  'COLD CALLING V3'
                                  ) 
            THEN 24

      WHEN DEALER.CANAL IN ('DO','DOT','WA','XI','XSO','OSPNIN','XSO','OSPNXSN','OSPNOUN','OUOC','OUOV','MKT_NR') THEN `mm-commissions-reporting.COMISIONES.f_comision_dispositivos_capta`
                                             (DEALER.canal
                                             ,RENUEVOS.financed_type
                                             ,RENUEVOS.PVP
                                            --  ,CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END
                                             ,CASE  WHEN RENUEVOS.second_device_flg = 1 THEN 2 
                                              ELSE 1 END
                                             ,RENUEVOS.brand_ds
                                             ,CAMP.campaign
                                             ,RENUEVOS.flag_pay_penalty ) 
          END AS comision

      --- vendedor ---
     ,CASE WHEN BRAND_DS = 'SIMYO' AND DEALER.CANAL = 'ALTN' THEN SFIDPADRE ELSE DEALER.id_comisionista END AS id_comisionista
     ,DEALER.distribuidor
     ,CASE WHEN BRAND_DS = 'SIMYO' AND DEALER.CANAL = 'ALTN' THEN RENUEVOS.SFID_ID ELSE RENUEVOS.sfid_id END AS sfid_id

     ,CASE WHEN seller IN ('ygoffline') THEN UPPER(user_store) ELSE UPPER(seller) END AS seller

     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,brand_ds AS marca
     ,CASE WHEN RENUEVOS.service_type = 'MOVIL' THEN 'MOBILE'
          WHEN RENUEVOS.service_type = 'FTTH' THEN 'INTERNET'
          ELSE RENUEVOS.service_type END AS service_type
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     ,CAST(terminal_id  AS STRING)  AS tariff_id
     ,terminal_model AS tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,RENUEVOS.line_type_ds
     ,bundle_type
     ,technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,order_date AS sale_date
     ,activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca

     ,CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
      RENUEVOS.service_type , brand_ds 
      ,order_type_agg 
      ,sell_type
     ,CASE
          WHEN billing_type_ds = 'PREPAID'                   THEN '10'
          WHEN bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN' THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                           THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END) AS cod_producto

     ,CASE
          WHEN RENUEVOS.cod_canal IN ('14', '15') THEN '29'
          ELSE RENUEVOS.cod_canal
      END AS cod_canal

     ,CAMP.campaign AS campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code

    ,CASE  WHEN RENUEVOS.second_device_flg = 1 THEN 'Secundario' 
               ELSE 'Primario' END AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.TEMP.dispositivos_OSP` RENUEVOS


INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.id_prefijo = 'FINA'

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(RENUEVOS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND RENUEVOS.master_channel_ds = AGRUPACION.master_channel_ds
            AND RENUEVOS.channel_ds = AGRUPACION.channel_ds
            AND RENUEVOS.subchannel_ds = AGRUPACION.subchannel_ds
            AND RENUEVOS.brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (UPPER(RENUEVOS.sfid_id) = DEALER.id_comisionista 
            OR
            UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
            OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
            OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
            OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
            )
            -- AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            AND DEALER.id_mes = mes_pr

 LEFT JOIN (SELECT DISTINCT service_id as service_t, phone_nm as phone_t, marca as marca_t, comision
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE CANAL = 'OSPNIN'
            AND id_mes = mes_pr) TRANSACCIONES
  ON RENUEVOS.phone_nm = TRANSACCIONES.phone_t
  AND RENUEVOS.brand_ds = TRANSACCIONES.marca_t
  AND RENUEVOS.service_id = TRANSACCIONES.service_t

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista
 AND DEALER.canal = CAMP.canal

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas` TARIFAS --- Añadimos cruce con TARIFAS PARA XSO CAMPAÑAS PONDERACION
ON CAMP.campaign = TARIFAS.campaign_code
  AND RENUEVOS.brand_ds = TARIFAS.marca
  AND DEALER.canal = TARIFAS.canal
  AND RENUEVOS.tariff_id = TARIFAS.tariff_id
  AND TARIFAS.id_mes = mes_pr


CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH)
        BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND sell_type = 'CAPTACION'
     --  AND financed_type = 'PAGO FINANCIADO'
     AND (CAMP.campaign IS NULL
          OR
          CAMP.campaign NOT IN (
                              --- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                         'COLD CALLING CAPTA SOHO',
                         'COLD CALLING CARTERA SOHO',
                         'COLD CALLING CAPTA RES',
                         'COLD CALLING CAPTA RES T EXTERNOS',
                         'COLD CALLING CAPTA RES NEW',
                         'COLD CALLING CAPTACION IA',


                         --- MR COLD CALLING CONTROLADO SOLO MARCA JAZZTEL ---

                         'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
                         'COLD CALLING CONTROLADO OFFSHORE',
                         'COLD CALLING CONTROLADO',
                         'COLD CALLING CONTROLADO TEMPL',
                         'COLD CALLING CONTROLADO CRECIMIENTOS',
                         'COLD CALLING CONTROLADO JE ',
                         'COLD CALLING CONTROLADO PL_EX',

                         --- MR LINEAS ADICIONALES SOLO MARCA JAZZTEL ---
                         'LINEAS ADICIONALES',


                         --- MR XSELLING SOLO MARCA JAZZTEL ---

                         'CROSS SELLING_MV',
                         'CROSS SELLING',
                         'CROSELLING_SEGUNDA RESIDENCIA'
      ))
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, order_id, marca ORDER BY activation_date DESC) = 1

--- UNIMOS OUTBOUND PONDERACIONES

UNION ALL

SELECT
      -- 'DSOSP'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,DEALER.agrupacion_canal AS agrupacion_canal
     ,DEALER.canal
     ,CASE WHEN DEALER.CANAL = 'ALTN' THEN concepto ELSE 'D - Dispositivo Captacion' END AS concepto
     ,'UPFR' AS tipo_concepto
     ,1 AS unidades
     
     ,CASE
           --- PONDERACIONES CANAL XSO
      
      WHEN DEALER.CANAL = 'XSO' 
            AND RENUEVOS.service_type = 'FTTH'
            AND RENUEVOS.financed_type = 'PAGO FINANCIADO' 
            AND CAMP.campaign IN ('CROSS SELLING','CROSS SELLING_MV','LINEAS ADICIONALES') 
            AND RENUEVOS.PVP >= 2 THEN 0.15 
      
      WHEN DEALER.CANAL = 'XSO' 
            AND RENUEVOS.service_type = 'FTTH'
            AND RENUEVOS.financed_type = 'PAGO FINANCIADO' 
            AND CAMP.campaign IN ('CROSS SELLING','CROSS SELLING_MV','LINEAS ADICIONALES') 
            AND RENUEVOS.PVP < 2 THEN 0.05 
            
     WHEN BRAND_DS = 'ORANGE' THEN CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64)/1.5 * 0.5 * UNITARIO.UNITARIO 
     
     WHEN BRAND_DS = 'JAZZTEL' AND PONDERACIONES.order_type_agg = 'PORTABILIDAD' THEN CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64)/2 * UNITARIO.UNITARIO 
    
     WHEN BRAND_DS = 'JAZZTEL' THEN CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO 
      
     END AS comision

      --- vendedor ---
     ,CASE WHEN BRAND_DS = 'SIMYO' AND DEALER.CANAL = 'ALTN' THEN SFIDPADRE ELSE DEALER.id_comisionista END AS id_comisionista
     ,DEALER.distribuidor
     ,CASE WHEN BRAND_DS = 'SIMYO' AND DEALER.CANAL = 'ALTN' THEN RENUEVOS.SFID_ID ELSE RENUEVOS.sfid_id END AS sfid_id

     ,CASE WHEN seller IN ('ygoffline') THEN UPPER(user_store) ELSE UPPER(seller) END AS seller

     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,brand_ds AS marca
     ,CASE WHEN RENUEVOS.service_type = 'MOVIL' THEN 'MOBILE'
          WHEN RENUEVOS.service_type = 'FTTH' THEN 'INTERNET'
          ELSE RENUEVOS.service_type END AS service_type
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     ,CAST(terminal_id  AS STRING)  AS tariff_id
     ,terminal_model AS tariff_ds
     ,RENUEVOS.service_id
     ,account_id
     ,RENUEVOS.customer_id
     ,RENUEVOS.line_type_ds
     ,bundle_type
     ,technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,order_date AS sale_date
     ,RENUEVOS.activation_date
     ,RENUEVOS.deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca

     ,CASE
          WHEN billing_type_ds = 'PREPAID'                                                                            THEN '10'
          WHEN bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
      RENUEVOS.service_type , brand_ds 
      ,RENUEVOS.order_type_agg 
      ,sell_type
     ,CASE
          WHEN billing_type_ds = 'PREPAID'                   THEN '10'
          WHEN bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN' THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                           THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END) AS cod_producto

     ,CASE
          WHEN RENUEVOS.cod_canal IN ('14', '15') THEN '29'
          ELSE RENUEVOS.cod_canal
      END AS cod_canal

     ,CAMP.campaign AS campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code

    ,CASE  WHEN RENUEVOS.second_device_flg = 1 THEN 'Secundario' 
               ELSE 'Primario' END AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.TEMP.dispositivos_OSP` RENUEVOS


INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.id_prefijo = 'FINA'


LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (UPPER(RENUEVOS.sfid_id) = DEALER.id_comisionista 
            OR
            UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
            OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
            OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
            OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
            )
            -- AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
            AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista
 AND DEALER.canal = CAMP.canal

LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
ON RENUEVOS.phone_nm = CAST(PONDERACIONES.PHONE_NM AS STRING)
 AND RENUEVOS.id_subscription_terminal = CAST(PONDERACIONES.id_subscription_terminal AS STRING)
 AND PONDERACIONES.ORDER_STATUS_DS = 'ENTREGADO'
 AND PONDERACIONES.MES = '2026-09-01'

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON PONDERACIONES.MARCA_CANAL = UNITARIO.MARCA
 AND DEALER.ID_COMISIONISTA = UNITARIO.SFID
 AND UNITARIO.MES = mes_pr


CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH)
        BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND sell_type = 'CAPTACION'
      AND CAMP.campaign IN (
                              --- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                         'COLD CALLING CAPTA SOHO',
                         'COLD CALLING CARTERA SOHO',
                         'COLD CALLING CAPTA RES',
                         'COLD CALLING CAPTA RES T EXTERNOS',
                         'COLD CALLING CAPTA RES NEW',
                         'COLD CALLING CAPTACION IA',


                         --- MR COLD CALLING CONTROLADO SOLO MARCA JAZZTEL ---

                         'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
                         'COLD CALLING CONTROLADO OFFSHORE',
                         'COLD CALLING CONTROLADO',
                         'COLD CALLING CONTROLADO TEMPL',
                         'COLD CALLING CONTROLADO CRECIMIENTOS',
                         'COLD CALLING CONTROLADO JE ',
                         'COLD CALLING CONTROLADO PL_EX',

                         --- MR LINEAS ADICIONALES SOLO MARCA JAZZTEL ---
                         'LINEAS ADICIONALES',


                         --- MR XSELLING SOLO MARCA JAZZTEL ---

                         'CROSS SELLING_MV',
                         'CROSS SELLING',
                         'CROSELLING_SEGUNDA RESIDENCIA'
      )
      AND PONDERACIONES.service_type = 'TERMINAL CAPTACION'
     --  AND financed_type = 'PAGO FINANCIADO'
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, order_id, marca ORDER BY activation_date DESC) = 1

)

)
;

DELETE
      FROM `mm-commissions-reporting.TEMP.captacion_activaciones_OSP`
      WHERE COMISION < 0.0  OR COMISION IS NULL
;

--- AÑADIMOS VENTAS SIMYO PARA ALTERNATIVO ---
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ALTN')) THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.captacion_activaciones_OSP_simyo` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS (

SELECT
      'DSOSP'||'_'||mes_string||'_'||DEALER.canal||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,'D - Dispositivo Financiado' AS concepto
     ,'UPFR' AS tipo_concepto
     ,1 AS unidades
     
     ,CASE WHEN DEALER.CANAL ='ALTN' THEN 15 
     
          END AS comision

      --- vendedor ---
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id

     ,RENUEVOS.seller

     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,RENUEVOS.brand_ds AS marca
     ,CASE WHEN RENUEVOS.service_type = 'MOVIL' THEN 'MOBILE'
          WHEN RENUEVOS.service_type = 'FTTH' THEN 'INTERNET'
          ELSE RENUEVOS.service_type END AS service_type
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     ,RENUEVOS.tariff_id
     ,RENUEVOS.terminal_model AS tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id
     ,VENTAS.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,RENUEVOS.service_type AS technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,RENUEVOS.order_day_id AS sale_date
     ,RENUEVOS.fecha_entrega AS activation_date
     ,RENUEVOS.deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, RENUEVOS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RENUEVOS.brand_ds) AS cod_marca

     ,VENTAS.cod_tipo_contrato
      
     ,VENTAS. cod_producto

     ,'29' AS cod_canal

     ,CAST(NULL AS STRING)  AS campaign_code

     ,RENUEVOS.serial AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code

    ,CAST(NULL AS STRING)  AS  comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(RENUEVOS.brand_ds) AS sociedad


FROM `mm-sales-reporting.SPEEDUP.query_devices_multimarca` RENUEVOS


LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
     ON RENUEVOS.seller = UPPER(DEALER.sfid_id)

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
     ON VENTAS.phone_nm = RENUEVOS.phone_nm
     AND VENTAS.customer_id = RENUEVOS.customer_id
     AND VENTAS.brand_ds = RENUEVOS.brand_ds
     AND VENTAS.sale_date = RENUEVOS.order_day_id
     AND VENTAS.activation_date IS NOT NULL

WHERE RENUEVOS.brand_ds = 'SIMYO'
AND DATE(DATE_TRUNC(RENUEVOS.order_day_id, MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
AND DEALER.CANAL = 'ALTN'
AND RENUEVOS.order_status_ds = 'ENTREGADO'
AND RENUEVOS.payterm = 'VAP'
AND RENUEVOS.tipo_venta = 'CAPTACION'

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), VENTAS.service_id, VENTAS.order_id, VENTAS.marca ORDER BY RENUEVOS.activation_date DESC) = 1 )
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.captacion_activaciones_OSP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS
(
  SELECT 
  'DSOSP'||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id
  ,*
  FROM 
      (SELECT * EXCEPT (commission_id)
      FROM `mm-commissions-reporting.TEMP.captacion_activaciones_OSP`

      UNION ALL

      SELECT * EXCEPT (commission_id)
      FROM  `mm-commissions-reporting.TEMP.captacion_activaciones_OSP_simyo` )


)
;
END IF
;
---- GESTION DE CANAL DISPOSITIVOS CAPTA ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.captacion_DHO_activaciones_OSP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS
(
SELECT
      'DSOSPF'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))  AS mes_liquidado
     ,mes_pr AS id_mes
     ,RENUEVOS.agrupacion_canal
     ,DEALER.canal
     ,REPLACE(RENUEVOS.concepto, 'D -', 'F -') AS concepto
     ,RENUEVOS.tipo_concepto
     ,1 AS unidades
     ,1.5 AS comision
      --- vendedor ---
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,DEALER.distribuidor
     ,RENUEVOS.sfid_id

     ,RENUEVOS.seller

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
      --- servicio ---
     ,marca
     ,'MOBILE' AS service_type --<----------- REVISAR
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     -- ,product_id AS tariff_id
     ,tariff_id
     -- ,product AS tariff_ds
     ,tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,COALESCE(RENUEVOS.billing_type_ds, 'POSTPAID') AS billing_type_ds
     ,RENUEVOS.sale_date
     ,activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,RENUEVOS.cod_segmento
     , RENUEVOS.cod_marca

     ,RENUEVOS.cod_tipo_contrato

     ,RENUEVOS.cod_producto

     ,RENUEVOS.cod_canal

      --- informacion adicional ---

     ,campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,RENUEVOS.sociedad


FROM `mm-commissions-reporting.TEMP.captacion_activaciones_OSP` RENUEVOS

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.id_prefijo = 'RENV'



LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (UPPER(RENUEVOS.sfid_id) = DEALER.id_comisionista 
            OR
            UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
            OR (RENUEVOS.marca = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
            OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
            )
            AND DEALER.id_mes = mes_pr


LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

-- INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
--           ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
--              AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
--              AND DEALER.canal = CHANNEL.canal

LEFT JOIN (
          SELECT DISTINCT serial_number, agrupacion_canal, sale_date -- 20250616 JOHANNA: cambio phone_nm por serial_num y quito sale_date para hacer el filtro único
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE id_mes < mes_pr
                AND (concepto LIKE 'F%Renuevo%' OR concepto LIKE 'Y%Renuevo%')
          ) TRANSACCIONES
         ON RENUEVOS.serial_number = TRANSACCIONES.serial_number
         AND DEALER.agrupacion_canal = TRANSACCIONES.agrupacion_canal
            AND RENUEVOS.sale_date = TRANSACCIONES.sale_date



CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH)
        BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND MASTER.id_comisionista IS NOT NULL
      AND TRANSACCIONES.serial_number IS NULL


QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, order_id, marca ORDER BY activation_date DESC) = 1)
;







CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('DSOSP', mes_pr, canales_pr, 'TEMP.captacion_activaciones_OSP', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('DSOSPF', mes_pr, canales_pr, 'TEMP.captacion_DHO_activaciones_OSP', 'ACTUALIZAR');


END