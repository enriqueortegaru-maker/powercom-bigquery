BEGIN

DECLARE sql, mes_string STRING;

SET mes_string = CAST(mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','BO','WA','XO','XIBO','DO'];
END IF;


/*
CALL COMISIONES.pr_renuevos_osp(202609, ['OSPNOUN','OSPNXSN']);
*/


---- CREAMOS TABLA TEMPORAL PARA DISPOSITIVOS DE JAZZTEL HASTA QUE LA INFO ESTÉ OK EN DEVICES ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.DISPOSITIVOS_JAZZTEL`  AS (
  SELECT
    CASE WHEN VENTA IN ("POSTVENTA","RENOVE") THEN "RENUEVO" ELSE "CAPTACION" END AS tipo_venta,
    "OSP" AS data_source_ds, -- JAZZTEL
    CAST(NULL AS STRING) AS account_id,
    --CAST(ID_CLIENTE AS STRING) AS customer_id,
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
    CAST(CCC_DISP AS STRING) AS sfid_id, -- swChnlPartnerId=canal_alta_id // swCreatedBy=agente_alta_id
    AGENTE AS user_store,
    AGENTE AS seller,
    CAST(NULL AS STRING) AS tariff_id,
    CAST(NULL AS STRING) AS tafiff_ds, -- DEPRECATED, DONT USE
    TARIFA AS tariff_ds,
    CAST(NUM_TLF AS STRING) AS phone_nm,
    MARCA AS manufacturer_name,
    CONCAT(REPLACE(REPLACE(MARCA," TERMINAL","")," TERMINAL MOVIL",""), CONCAT(" ", MODELO)) AS terminal_model,
    CUOTA_FINANCIACION AS Cuota,
    CAST(MESES_FINANCIACION AS STRING) AS Periodo, -- meses
    CAST(CUOTA_INICIAL AS STRING) AS initial_payment,
    CAST(PRECIO_REFERENCIA_DISP AS STRING) AS total_pay_value,
    VENTA AS order_type_ds,
    TIPO_DISP AS payment_type, -- % financiacion
    DATE(NULL) AS financed_init_date,
    DATE(NULL) AS financed_end_date,
    CAST(NULL AS STRING) AS mac,    
    CASE
      WHEN GAMA LIKE ("SMARTPHONE%") OR GAMA IN ("TERMINAL") THEN CASE WHEN IMEI = -66  THEN NULL ELSE CAST(IMEI AS STRING) END
      ELSE CASE WHEN NUMERO_SERIE IN ("SIN DATOS") THEN NULL ELSE NUMERO_SERIE END
    END AS serial,
    -- CASE WHEN IMEI = -66  THEN NULL ELSE CAST(NUMERO_SERIE AS STRING) END AS serial,
    --CASE WHEN NUMERO_SERIE IN ("SIN DATOS") THEN NULL ELSE NUMERO_SERIE END AS serial,
    GAMA AS device_type_ds,
    CAST(NULL AS STRING) AS frontal,
    CAST(id_relacion_disp AS STRING) AS order_id,
    CASE
      WHEN DESESTIMIENTO='NO' AND ESTADO_PEDIDO_DISP IN ('FINALIZADO') THEN "ENTREGADO"
      WHEN DESESTIMIENTO='NO' AND ESTADO_PEDIDO_DISP IN ('EN CURSO', 'EN ELABORACION') THEN "EN VUELO"
      --WHEN DESESTIMIENTO='SI' OR ESTADO_PEDIDO_DISP NOT IN ('EN CURSO', 'EN ELABORACION') THEN "CANCELADO"
      ELSE "CANCELADO" -- NULL
    END AS order_status_ds,
    ESTADO_PEDIDO_DISP AS expedition_status_ds,
    MOTIVO_CANCELACION AS end_reason, --SUBMOTIVO_CANCELACION
    campanias.PLATAFORMA AS plataforma,
    CAST(NULL AS STRING) AS bundle_type,
    COALESCE(NULL,"RESIDENCIAL") AS channel_segment_ds,
    TIPO_CANAL_DISP AS superchannel_ds,
    campanias.DE_CAMPANIA AS campaign, -- CAMPANIA
    
    CAST(ESTADO_DISP AS STRING) terminal_status_ds,
    CAST(FORMAT_DATETIME("%Y-%m-%d", COALESCE(FECHA_VN,FC_ALTA_DISP)) AS STRING) AS fecha_venta_formato,
    REF_TERMINAL AS codigo_terminal,

    TIPO_DISP AS financed_type,
    CAST(NULL AS STRING) AS canal_cvm,

    CAST(NULL AS STRING) AS catalog,
    CAST(NULL AS STRING) AS channel_id_catalogo_enum,

    CAST(NULL AS STRING) AS CROSSELL, --TIPO_ACTO_CONVERGENTE
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

    CAST(NULL AS STRING) AS dig_signature_status_agg --BIVEN-681
  
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
    --AND ESTADO_PEDIDO_DISP IN ('EN CURSO', 'EN ELABORACION', 'FINALIZADO')
    AND	TIPO_CANAL_DISP NOT IN ('TRASLADOS')
    -- AND FC_ALTA_DISP >= (SELECT limitehistorico FROM variablespersonalizadas)
    --AND DESESTIMIENTO='NO'
)
;

--- CREAMOS TABLA DE TRAMOS PARA RENUEVOS EN TLVN CANAL OSPNIN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tramos_renuevos_OSPNIN` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS (
  SELECT b.id_comisionista,a.*
    FROM (
        SELECT *
        FROM `mm-commissions-reporting.GS.RENUEVOS_TRAMOS_TLVN`
        UNPIVOT (
            comision FOR tramo IN (
                tramo_1,
                tramo_2,
                tramo_3,
                tramo_4
            )
        )
    ) a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
      AND a.canal = b.canal
      AND b.mes = mes_string

    CROSS JOIN UNNEST(canales_pr) AS canal_pr
      
    WHERE   a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
    AND a.canal = canal_pr)
;
---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_OSP` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS (

WITH 
multidevices AS (

  SELECT
    DISTINCT
    data_source_ds,
    brand_ds,
    phone_nm,
    order_day_id,
    id_subscription_terminal
  FROM (
    SELECT
      DISTINCT
      fins.data_source_ds,
      fins.brand_ds,
      fins.phone_nm,
      ords.order_day_id,
      ords.id_subscription_terminal,
    FROM
      `mm-sales-reporting.SPEEDUP.query_devices_multimarca` AS fins
    LEFT JOIN (
      SELECT
        DISTINCT
        data_source_ds,
        brand_ds,
        phone_nm,
        order_day_id,
        id_subscription_terminal,
      FROM
        `mm-sales-reporting.SPEEDUP.query_devices_multimarca`
      WHERE
        data_source_ds IN ("MYSIM","EKTNET","TCNET","R")
        AND phone_nm != "-2"
        AND device_type_group IN ("SMARTPHONE","OTROS")
        AND order_day_id >= '2024-01-01'
        --AND fins.order_status_ds = "ENTREGADO"
    ) AS ords
    ON
      ords.data_source_ds = fins.data_source_ds
      AND ords.brand_ds = fins.brand_ds
      AND ords.phone_nm = fins.phone_nm
      AND fins.financed_init_date < ords.order_day_id
      AND fins.financed_end_date > ords.order_day_id
    WHERE
      fins.financed_end_date IS NOT NULL
      AND ords.data_source_ds IS NOT NULL
      AND fins.phone_nm != "-2"
      AND fins.device_type_group IN ("SMARTPHONE","OTROS")
      AND fins.order_status_ds = "ENTREGADO"
    UNION ALL
    SELECT
      DISTINCT
      fins.data_source_ds,
      fins.brand_ds,
      fins.phone_nm,
      ords.order_day_id,
      ords.id_subscription_terminal,
    FROM
      `mm-sales-reporting.SPEEDUP.query_devices_multimarca` AS fins
    LEFT JOIN (
      SELECT
        DISTINCT
        data_source_ds,
        brand_ds,
        phone_nm,
        order_day_id,
        id_subscription_terminal,
        financed_end_date,
      FROM
        `mm-sales-reporting.SPEEDUP.query_devices_multimarca`
      WHERE
        data_source_ds IN ("MYSIM","EKTNET","TCNET","R")
        AND phone_nm != "-2"
        AND device_type_group IN ("SMARTPHONE","OTROS")    
        AND order_day_id >= '2024-01-01'
        --AND fins.order_status_ds = "ENTREGADO"
    ) AS ords
    ON
      ords.data_source_ds = fins.data_source_ds
      AND ords.brand_ds = fins.brand_ds
      AND ords.phone_nm = fins.phone_nm
      AND fins.financed_init_date = ords.order_day_id
      AND fins.financed_end_date > ords.order_day_id
      AND CASE
        WHEN fins.id_subscription_terminal < ords.id_subscription_terminal THEN 1
        WHEN fins.id_subscription_terminal != ords.id_subscription_terminal AND ords.financed_end_date IS NULL THEN 1
        ELSE 0
      END = 1
    WHERE
      fins.financed_end_date IS NOT NULL
      AND ords.data_source_ds IS NOT NULL
      AND fins.phone_nm != "-2"
      AND fins.device_type_group IN ("SMARTPHONE","OTROS")
      AND fins.order_status_ds = "ENTREGADO"
  )-- GROUP BY ALL
)

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
  CAST(DEVICE.phone_nm AS STRING) phone_nm,
  DATE(DEVICE.order_date) AS order_date,
  DATE(DEVICE.provider_delivery_date) AS activation_date,
  DATE(DEVICE.cancellation_date_ts) AS deactivation_date,
  CAST(DEVICE.account_id AS STRING) AS account_id,
  CAST(DEVICE.customer_id AS STRING) AS customer_id,
  CAST(DEVICE.id_subscription_terminal AS STRING) AS order_id,
  DEVICE.device_type_ds AS device_type,
  DEVICE.product_code AS product_id,
  DEVICE.tech_description AS product,
  DEVICE.is_financed_desc,
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
--   CASE WHEN DEVICE.BRAND_DS = 'JAZZTEL' THEN CAST(JAZZ.total_pay_value AS FLOAT64)
--        WHEN DEVICE.BRAND_DS = 'ORANGE'  THEN CAST(DEVICE.TOTAL_PAY_VALUE AS FLOAT64)/1.21 
--    END AS PVP,
  CASE WHEN DEVICE.BRAND_DS = 'JAZZTEL' THEN CAST(DEVICE.TOTAL_PAY_VALUE AS FLOAT64) --- EN Jazztel el PVP viene sin IVA
       ELSE CAST(DEVICE.TOTAL_PAY_VALUE AS FLOAT64)/1.21 END AS PVP, --- En Orange el PVP viene con IVA
  CASE WHEN DEVICE.brand_ds = 'JAZZTEL' AND UPPER(JAZZ.second_device_flg) LIKE '%SECUNDARIO%' THEN 1 
       WHEN DEVICE.brand_ds = 'JAZZTEL' AND UPPER(JAZZ.second_device_flg) NOT LIKE '%SECUNDARIO%' THEN 0 
       WHEN multidevices.data_source_ds IS NOT NULL OR COALESCE(CAST(DEVICE.second_device_flg AS STRING), '0') = '1' THEN 1
  -- CASE WHEN DEVICE.brand_ds = 'JAZZTEL'  THEN 0 
  --      WHEN multidevices.data_source_ds IS NOT NULL OR COALESCE(CAST(DEVICE.second_device_flg AS STRING), '0') = '1' THEN 1
    ELSE 0 END AS second_device_flg
  -- ELSE DEVICE.second_device_flg END AS second_device_flg
  ,cast(DEVICE.tariff_key as string) as tariff_key
  ,CASE WHEN DEVICE.brand_ds = 'ORANGE' THEN DEVICE.service_type ELSE JAZZ.service_type END AS service_type


FROM `mm-datamart-kd.SERVICES.devices_base_osp` DEVICE

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
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

LEFT JOIN
  multidevices
ON
  multidevices.data_source_ds = DEVICE.data_source_ds
  AND multidevices.brand_ds = DEVICE.brand_ds
  AND multidevices.phone_nm = DEVICE.phone_nm
  AND multidevices.order_day_id = DEVICE.sale_date
  AND multidevices.id_subscription_terminal = DEVICE.id_subscription_terminal

WHERE DEVICE.brand_ds IN ('ORANGE','SIMYO','JAZZTEL')
  AND DATE(DATE_TRUNC(DEVICE.provider_delivery_date, MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
  -- AND DATE(DATE_TRUNC(DEVICE.order_date, MONTH)) = PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
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


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_activaciones_OSP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS
(
SELECT
      'RNOSP'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,concepto
     ,tipo_concepto
     ,1 AS unidades
     
     ,CASE WHEN DEALER.CANAL ='ALTN' THEN 25 
           WHEN DEALER.CANAL = 'OSPNIN' AND RENUEVOS.second_device_flg = 1 THEN
            CASE WHEN TRAMOS_OSPNIN.campaign = 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_1' THEN 13
                 WHEN TRAMOS_OSPNIN.campaign = 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_2' THEN 12
                 WHEN TRAMOS_OSPNIN.campaign = 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_3' THEN 11
                 WHEN TRAMOS_OSPNIN.campaign = 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_4' THEN 11
                 WHEN TRAMOS_OSPNIN.campaign != 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_1' THEN 7
                 WHEN TRAMOS_OSPNIN.campaign != 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_2' THEN 6
                 WHEN TRAMOS_OSPNIN.campaign != 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_3' THEN 6
                 WHEN TRAMOS_OSPNIN.campaign != 'I-ADVIZE DRS EMPRESA' AND TRAMOS_OSPNIN.tramo = 'tramo_4' THEN 6
              END
           WHEN DEALER.CANAL = 'OSPNIN' AND RENUEVOS.second_device_flg = 1 AND CAMP.campaign IN ('I-ADVIZE DRS EMPRESA','I-ADVIZE EMPRESA') THEN 6 
           WHEN DEALER.CANAL = 'OSPNIN' AND RENUEVOS.second_device_flg = 1 AND CAMP.campaign NOT IN ('I-ADVIZE DRS EMPRESA','I-ADVIZE EMPRESA') THEN 3
           WHEN DEALER.CANAL IN ('OUO','OUOCC','OUOP','OSPNOUN','OSPNXSN','XSO') AND CAMP.campaign IN (
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
                THEN CASE 
                      WHEN RENUEVOS.service_type IN ('MOVIL','MOBILE')               THEN 0.10 * UNITARIO.UNITARIO
                      WHEN RENUEVOS.service_type = 'BROADBAND' AND RENUEVOS.PVP >= 2 THEN 0.15 * UNITARIO.UNITARIO
                      WHEN RENUEVOS.service_type = 'BROADBAND' AND RENUEVOS.PVP < 2  THEN 0.05 * UNITARIO.UNITARIO
                    END
           WHEN DEALER.CANAL IN ('BO','DO','DOT','WA','XI','XIBO','OSPNBO','XSO','OSPNXSN','MKT_NR') THEN
               `mm-commissions-reporting.COMISIONES.f_comision_renuevos`
               (
               DEALER.canal,
               CAMP.campaign,
               RENUEVOS.brand_ds,
               DEALER.sfid_id,
               TRUE,
               FALSE,
               RENUEVOS.PVP,
               NULL,
               -- CASE WHEN MULTI.serial_number IS NOT NULL THEN 2 ELSE 1 END,
               CASE  WHEN RENUEVOS.second_device_flg = 1 THEN 2 
               ELSE 1 END,
               RENUEVOS.is_financed_desc
               ) 
           END AS comision


      --- vendedor ---
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,RENUEVOS.sfid_id

     ,CASE WHEN seller IN ('ygoffline') THEN UPPER(user_store) ELSE UPPER(seller) END AS seller

     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
      --- servicio ---
     ,brand_ds AS marca
     ,CASE WHEN RENUEVOS.service_type = 'MOVIL' THEN 'MOBILE'
           WHEN RENUEVOS.service_type = 'BROADBAND' THEN 'INTERNET'
           ELSE RENUEVOS.service_type END AS service_type
 
     ,CAST(RENUEVOS.phone_nm AS STRING) AS phone_nm
     ,CAST(terminal_id  AS STRING)  AS tariff_id
     ,terminal_model AS tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
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
          WHEN bundle_type = 'FMC' AND line_type_ds = 'MAIN'                                                          THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '60' ELSE '61' END)
          WHEN bundle_type = 'FMC'                                                                                    THEN (CASE WHEN sales_technology_ds = 'ADSL' THEN '66' ELSE '67' END)
          WHEN bundle_type = 'MO'  AND line_type_ds IN ('ADDITIONAL', 'EXTRA') AND brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
          ELSE '20'
      END AS cod_tipo_contrato
      
     ,'050' AS cod_producto

     ,CASE
          WHEN RENUEVOS.cod_canal IN ('14', '15') THEN '29'
          ELSE RENUEVOS.cod_canal
      END AS cod_canal

     ,CAMP.campaign AS campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CASE WHEN  RENUEVOS.second_device_flg = 1 THEN 'Secundario' 
          ELSE 'Primario' END AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.TEMP.renuevos_OSP` RENUEVOS


INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.id_prefijo = 'RENV'

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


LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista
 AND DEALER.canal = CAMP.canal

LEFT JOIN  `mm-commissions-reporting.TEMP.tramos_renuevos_OSPNIN`  TRAMOS_OSPNIN
ON DEALER.id_comisionista = TRAMOS_OSPNIN.id_comisionista
AND RENUEVOS.brand_ds = TRAMOS_OSPNIN.marca
AND RENUEVOS.tariff_key = TRAMOS_OSPNIN.tariff_id
AND CAMP.campaign = TRAMOS_OSPNIN.campaign

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON DEALER.id_comisionista = UNITARIO.SFID
  AND RENUEVOS.brand_ds = UNITARIO.marca
  AND UNITARIO.MES = mes_pr

-- INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
--           ON
--              AGRUPACION.agrupacion_canal = CHANNEL.agrupacion_canal
--              AND DEALER.canal = CHANNEL.canal

/*
LEFT JOIN (
          SELECT serial_number
          FROM `mm-datamart-kd.SERVICES.devices_base_osp` RENUEVOS

          LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
          ON (
               UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
               OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
               OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
               OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
               )
               -- AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
               AND DEALER.id_mes = mes_pr
               
          WHERE CAST(RENUEVOS.provider_delivery_date AS DATE) <= COALESCE(CAST(RENUEVOS.cancellation_date_ts AS DATE), '9999-12-31')
          -- AÑADO FILTRO POR LOS ÚLTIMOS 6 MESES PARA LIBERAR PESO AL PROCESO --
          AND CAST(RENUEVOS.provider_delivery_date AS DATE) >= DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)),INTERVAL 6 MONTH)

                AND COALESCE(CAST(RENUEVOS.cancellation_date_ts AS DATE), '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
                -- AND is_financed_desc = 'SI'
                AND (
                       (
                       DEALER.canal = 'ENK' 
                       AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
                       )
                    OR   
                       (
                       DEALER.canal != 'ENK' 
                       AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
                       )

                    )
                AND serial_number IS NOT NULL
          QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, brand_ds
                                    ORDER BY CAST(RENUEVOS.provider_delivery_date AS DATE) ASC,
                                             CAST(RENUEVOS.cancellation_date_ts AS DATE) ASC,
                                             RENUEVOS.total_pay_value DESC,
                                             RENUEVOS.serial_number ASC
                                    ) > 1
          ) MULTI
         ON RENUEVOS.serial_number = MULTI.serial_number
*/
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(DATE(RENUEVOS.activation_date), MONTH)
        BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))
      AND RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND sell_type = 'RENUEVO'
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, order_id, marca ORDER BY activation_date DESC) = 1
)
;

--- GESTION CANAL RENUEVOS ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_DHO_activaciones_OSP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS
(
SELECT
      'RNOSPF'||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING))  AS mes_liquidado
     ,mes_pr AS id_mes
     --,COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds), DEALER.agrupacion_canal) AS agrupacion_canal
     ,RENUEVOS.agrupacion_canal
     ,DEALER.canal
     ,REPLACE(RENUEVOS.concepto, 'B -', 'F -') AS concepto
     ,RENUEVOS.tipo_concepto
     ,1 AS unidades
     ,2.5 AS comision
      --- vendedor ---
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
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

     ,'050' AS cod_producto

     ,RENUEVOS.cod_canal

      --- informacion adicional ---

     ,RENUEVOS.campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,RENUEVOS.sociedad


FROM `mm-commissions-reporting.TEMP.renuevos_activaciones_OSP` RENUEVOS

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
      AND TRANSACCIONES.serial_number IS NULL
      AND DEALER.CANAL = 'ALTN'


QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, order_id, marca ORDER BY activation_date DESC) = 1)
;


---- CLAWBACK RENUEVOS ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_osp_clawback_date`
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

INNER JOIN `mm-datamart-kd.SERVICES.devices_base_osp` DEVICES
          ON TRANSACCIONES.serial_number = CAST(DEVICES.serial_number AS STRING)
             AND TRANSACCIONES.service_id = CAST(DEVICES.service_id AS STRING)
             AND TRANSACCIONES.order_id = CAST(DEVICES.id_subscription_terminal AS STRING)

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE (
      (
        cancellation_date_ts IS NULL
        AND DEVICES.terminal_status_ds IN ('CANCELADO', 'EXPEDICIÓN PENDIENTE DE CANCELACIÓN', 'PENDIENTE A DESACTIVAR','DESISTIDO','DESISTIMIENTO')
       )
      OR
      (COALESCE(DATE_TRUNC(DATE(cancellation_date_ts), MONTH), '9999-12-31') = DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      AND
      DEVICES.terminal_status_ds IN ('CANCELADO', 'EXPEDICIÓN PENDIENTE DE CANCELACIÓN', 'PENDIENTE A DESACTIVAR','DESISTIDO','DESISTIMIENTO'))
      OR
      COALESCE(DATE_TRUNC(DATE(cancellation_date_ts), MONTH), '9999-12-31') = DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)
      OR
      COALESCE(DATE_TRUNC(DATE(cancellation_date_ts), MONTH), '9999-12-31') = PARSE_DATE('%Y%m', mes_string)
      )
      -- AND DATE_TRUNC(DATE(TRANSACCIONES.activation_date), MONTH) = DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH)
      AND DATE_TRUNC(DATE(TRANSACCIONES.activation_date), MONTH)  
              BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 1 MONTH)
              AND LAST_DAY(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)))
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.comision > 0
      AND (TRANSACCIONES.commission_id LIKE '%RNOSP%' OR TRANSACCIONES.commission_id LIKE '%RPD%')

QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, concepto, marca ORDER BY activation_date DESC) = 1
)
;



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_osp_clawback_summation`
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

FROM `mm-commissions-reporting.TEMP.renuevos_osp_clawback_date` TRANSACCIONES

WHERE SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto)) IN
        (
         'Clawback Rappel Renuevo'
        ,'Renuevo'
        ,'Rappel Renuevo'
        )

GROUP BY 1,2,3,4,5,6,8,9,10,11,12,13,14,17,19,20,21,27
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_osp_clawback_dealer`
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
     
     ,'RNOSPE' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
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

FROM `mm-commissions-reporting.TEMP.renuevos_osp_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.renuevos_osp_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.renuevos_osp_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.renuevos_osp_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) COMM
          LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
                   ON REPLACE(COMM, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY ROW_NUMBER() OVER (PARTITION BY CLWB.process_code ORDER BY CLWB.concepto ASC) = 1 
)
;

ASSERT NOT EXISTS
(
SELECT COALESCE(serial_number, 'Z'), service_id, concepto, marca
FROM `mm-commissions-reporting.TEMP.renuevos_osp_clawback`
QUALIFY COUNT(*) OVER (PARTITION BY COALESCE(serial_number, 'Z'), service_id, concepto, marca) > 1
);




CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RNOSP', mes_pr, canales_pr, 'TEMP.renuevos_activaciones_OSP', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RNOSPF', mes_pr, canales_pr, 'TEMP.renuevos_DHO_activaciones_OSP', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RNOSPE', mes_pr, canales_pr, 'TEMP.renuevos_osp_clawback', 'ACTUALIZAR');

END