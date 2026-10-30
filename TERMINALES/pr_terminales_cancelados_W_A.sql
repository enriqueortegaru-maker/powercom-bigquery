BEGIN

--Llamamos al procedimiento para preparar el listado
--CALL `mm-commissions-reporting.TERMINALES.pr_terminales_cancelados_W_A`(id_mes_facturado_desde INT64, id_mes_facturado_hasta INT64, mes_a_facturar DATE)
--CALL `mm-commissions-reporting.TERMINALES.pr_terminales_cancelados_W_A`(202608,202608,'2026-09-01','2026-09-30');

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_cancelados_W_A`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 10 DAY)) AS

--Se pagó y se canceló después
SELECT IMEI, mes_liquidado, marca, id_comisionista, lista.phone_nm, CONTRACT_ID as contract_id, lista.TERMINAL_NAME AS ID_MODELO, lista.order_id AS order_id
FROM `mm-datamart-kd.DEVICES.device_base_mysim` DEVICE,
  ( SELECT
      IMEI, mes_liquidado, marca, id_comisionista, phone_nm, CONTRACT_ID, TER.TERMINAL_NAME, order_id
    FROM `mm-commissions-reporting.TERMINALES.TERMINALES` TER
    WHERE id_mes >= id_mes_facturado_desde AND id_mes <= id_mes_facturado_hasta
      AND tipo_concepto IN ('SRCI','SUBS','FINT')
      AND process_code IN ('REAL','AJUS_MANUAL')
    GROUP BY ALL
  ) lista
WHERE DEVICE.serial_number IN (lista.IMEI)
--  AND UPPER(DEVICE.brand_ds) = UPPER(lista.marca)
  AND CAST(DEVICE.order_date AS DATE) >= lista.mes_liquidado
  AND CAST(DEVICE.order_date AS DATE) <= (SELECT LAST_DAY(lista.mes_liquidado, MONTH))
  AND DEVICE.terminal_status_ds IN ('CANCELADO','CANCELADA','FINANCIACION DESACTIVADA')
  AND DEVICE.user_store = lista.id_comisionista
  AND DEVICE.brand_ds = lista.marca
  AND DEVICE.phone_nm = CAST (lista.phone_nm AS INT64)
  AND lista.order_id = CAST (DEVICE.id_subscription_terminal AS STRING)
;

/*
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_usado_W_A`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 10 DAY)) AS

--Comprobar que tiene una nueva para pagar
SELECT TCW.IMEI, DEVICE.terminal_status_ds, DEVICE.order_date, DEVICE.brand_ds, DEVICE.phone_nm, DEVICE.user_store, TCW.contract_id
FROM `mm-commissions-reporting.TEMP.terminales_cancelados_W_A` TCW
  LEFT JOIN `mm-datamart-kd.SERVICES.devices_base_emysim` DEVICE
  ON  TCW.IMEI = DEVICE.serial_number
  AND CAST(TCW.phone_nm AS INT64) = DEVICE.phone_nm
  AND TCW.id_comisionista = DEVICE.user_store
  AND TCW.marca = DEVICE.brand_ds
  AND CAST(DEVICE.order_date AS DATE) < '2025-05-31'
  AND CAST(DEVICE.order_date AS DATE) >= '2025-05-01'
  AND DEVICE.terminal_status_ds in ('USADO','FINANCIACION EN CURSO','EN FINANCIACION')
;
*/

/*
--RESULTADO
-- Eliminamos aquellos que tienen una venta en estatus que está OK
SELECT
    CAST (mes_a_facturar AS DATE) AS EVENT_DATE
  , id_comisionista AS SFID
  , phone_nm AS MSISDN
  , contract_id AS contract_id
  , CAST (mes_a_facturar AS DATE) AS done_stamp
  , 'WRONG_ADD' AS TIPO
  ,'COMISIONES' AS tipo_fraude
  , IMEI AS IMEI
  , ID_MODELO
  , order_id
FROM `mm-commissions-reporting.TEMP.terminales_cancelados_W_A`
WHERE IMEI NOT IN (
              SELECT DISTINCT B.serial_number
              FROM `mm-commissions-reporting.TEMP.terminales_cancelados_W_A` A
              INNER JOIN `mm-datamart-kd.SERVICES.devices_base_emysim` B
                    ON A.IMEI = B.serial_number AND A.marca = B.brand_ds AND A.id_comisionista = B.user_store AND A.phone_nm = CAST(B.phone_nm AS STRING) AND A.order_id = CAST (b.id_subscription_terminal AS STRING)
              WHERE B.terminal_status_ds IN ('FINANCIACION EN CURSO','USADO')
              AND DATE(B.order_date) BETWEEN mes_a_revisar AND mes_a_facturar
              ) 
;
*/

--RESULTADO A CARGAR EN OTHER_COMMISSION
SELECT
    CAST (mes_a_facturar AS DATE) AS EVENT_DATE
  , id_comisionista AS SFID
  , phone_nm AS MSISDN
  , contract_id AS contract_id
  , CAST (mes_a_facturar AS DATE) AS done_stamp
  , 'WRONG_ADD' AS TIPO
  , 'COMISIONES' AS tipo_fraude
  , CAST(NULL AS STRING) AS contador_duplicados
  , IMEI AS IMEI
  , ID_MODELO
  , order_id
FROM `mm-commissions-reporting.TEMP.terminales_cancelados_W_A`
WHERE IMEI NOT IN (
              SELECT DISTINCT B.serial_number
              FROM `mm-commissions-reporting.TEMP.terminales_cancelados_W_A` A
              INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` B
                    ON A.IMEI = B.serial_number AND A.marca = B.brand_ds AND A.id_comisionista = B.user_store AND A.phone_nm = CAST(B.phone_nm AS STRING) AND A.order_id = CAST (b.id_subscription_terminal AS STRING)
              WHERE B.terminal_status_ds IN ('FINANCIACION EN CURSO','USADO')
              AND DATE(B.order_date) BETWEEN mes_a_facturar AND mes_a_revisar
              ) 
;

END