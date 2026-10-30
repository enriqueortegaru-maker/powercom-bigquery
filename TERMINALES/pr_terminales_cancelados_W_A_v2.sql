BEGIN

--Llamamos al procedimiento para preparar el listado
--CALL `mm-commissions-reporting.TERMINALES.pr_terminales_cancelados_W_A_v2`(202607,'2026-08-01','2026-07-01');

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_cancelados_W_A`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 10 DAY)) AS

SELECT afectados.IMEI, mes_a_revisar AS mes_liquidado, afectados.marca, afectados.id_comisionista, afectados.phone_nm
  , afectados.CONTRACT_ID as contract_id, DEVICE.TERMINAL_NAME AS ID_MODELO, afectados.order_id AS order_id
FROM `mm-datamart-kd.DEVICES.device_base_mysim` DEVICE,

  ( SELECT TER.IMEI, TER.id_comisionista, TER.marca, TER.phone_nm, TER.CONTRACT_ID, TER.order_id, ROUND(SUM(TER.comision),2) as importe
    FROM `mm-commissions-reporting.TERMINALES.TERMINALES` TER
      , (SELECT
          IMEI, id_comisionista, phone_nm, CONTRACT_ID, order_id
        FROM `mm-commissions-reporting.TERMINALES.TERMINALES` TER
        WHERE id_mes = id_mes_facturado
          AND tipo_concepto IN ('SRCI','SUBS','FINT')
          AND process_code IN ('REAL','AJUS_MANUAL')
        GROUP BY ALL) lista
    WHERE TER.IMEI = lista.IMEI
      AND TER.id_comisionista = lista.id_comisionista
      AND TER.phone_nm = lista.phone_nm
      AND TER.CONTRACT_ID = lista.CONTRACT_ID
      AND TER.order_id = lista.order_id
    GROUP BY ALL
    HAVING importe <> 0
  ) afectados

WHERE DEVICE.serial_number IN (afectados.IMEI)
  AND UPPER(DEVICE.brand_ds) = UPPER(afectados.marca)
  AND CAST(DEVICE.order_date AS DATE) >= mes_a_revisar
  AND CAST(DEVICE.order_date AS DATE) <= (SELECT LAST_DAY(mes_a_revisar, MONTH))
  AND DEVICE.terminal_status_ds IN ('CANCELADO','CANCELADA','FINANCIACION DESACTIVADA')
  --AND DEVICE.user_store = afectados.id_comisionista
  AND DEVICE.brand_ds = afectados.marca
  AND DEVICE.phone_nm = CAST (afectados.phone_nm AS INT64)
  AND afectados.order_id = CAST (DEVICE.id_subscription_terminal AS STRING)
;


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
          ON  A.IMEI = B.serial_number 
          AND A.marca = B.brand_ds 
          AND A.id_comisionista = B.user_store 
          AND A.phone_nm = CAST(B.phone_nm AS STRING) 
          AND A.order_id = CAST (b.id_subscription_terminal AS STRING)
      WHERE B.terminal_status_ds IN ('FINANCIACION EN CURSO','USADO')
      AND DATE(B.order_date) BETWEEN mes_a_facturar AND mes_a_revisar
  ) 
;

END