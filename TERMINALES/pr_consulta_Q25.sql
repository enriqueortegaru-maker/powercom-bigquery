BEGIN

/*
DECLARE initial_date DATE;
DECLARE end_date DATE;
SET initial_date = '2025-10-01';
SET end_date = '2025-10-31';
*/

--CALL `mm-commissions-reporting.TERMINALES.pr_consulta_Q25`('2026-07-01','2026-07-31');

SELECT *
FROM (
  SELECT dbe.financed_end_date AS EVENT_DATE, dbe.user_store AS EXT_CUSTOMER_NO, dbe.phone_nm AS MSISDN, dbe.serial_number AS IMEI, vbt.contract_id AS CONTRACT_ID, 'EXTENSION' AS ADDON1, 'DONE WITH RENEWAL' AS ADDON2
    , CAST(NULL AS INT64) AS ADDON3, CAST(NULL AS STRING) AS ADDON5, 'EXT_10' AS ADDON6
  FROM `mm-datamart-kd.DEVICES.device_base_mysim` dbe
    LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` vbt
      ON  vbt.brand_ds = dbe.brand_ds
      AND vbt.phone_nm = dbe.phone_nm
      AND vbt.service_id = dbe.service_id
      AND vbt.customer_id = dbe.customer_id
  WHERE dbe.q25_months = 12
    AND dbe.refinanced_status = 'TERMINADO'
    AND dbe.financed_end_date BETWEEN initial_date AND end_date
    AND SUBSTR(COALESCE(dbe.user_store,NULL), 1, 2) IN ('AX','BY','DB','DX','KH','LB','LM','LX','LY','MD','PH','TA','TP','ML','MY','MB')
    AND dbe.user_store NOT IN ('LB152006') 

    UNION ALL

    SELECT 
    CAST(dp.REQUESTDATE AS DATE) AS EVENT_DATE,  --dp.REQUESTDATE también valdría
    dp.CODEAGENT AS EXT_CUSTOMER_NO,
    dbe.phone_nm AS MSISDN,
    dbe.serial_number AS IMEI,
    CASE WHEN SUBSTR(dp.ORDERIDEXTERNAL,1,2) =  'OK' THEN substr(dp.ORDERIDEXTERNAL,6,(LENGTH(dp.ORDERIDEXTERNAL)-5)) 
        WHEN SUBSTR(dp.ORDERIDEXTERNAL,1,2) <> 'OK' THEN dp.ORDERIDEXTERNAL
        WHEN dp.ORDERIDEXTERNAL IS NULL             THEN CAST(NULL AS STRING)
      ELSE CAST(NULL AS STRING) END AS CONTRACT_ID,
    'RETURN' AS ADDON1,
    CASE WHEN lee.acceptedDatetime IS NOT NULL THEN 'DONE'  --OK
        WHEN lee.notAcceptedDatetime IS NOT NULL THEN 'KO'  --Not accepted
        ELSE 'REVISAR' END AS ADDON2,
    CAST(dbe.q25_amount AS INT64) AS ADDON3,
    'DETAILED' AS ADDON5,
    'RET_4' AS ADDON6  --RETURN-OK
  FROM `mm-commissions-reporting.TEMP.APOLLO_PROP_DEVICEPICKUP` dp
    LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` dbe
      ON  dbe.id_subscription_terminal = dp.SUBSCRIPTIONTERMINALID
    LEFT JOIN `mm-datamart-kd.LOGISTICS.logistic_expeditions_events` lee
      ON  lee.id_subscription_terminal = CAST(dp.SUBSCRIPTIONTERMINALID AS STRING)
      AND lee.businessProcess = 'FINALPAYMENT'
      AND lee.logisticsOperator = 'ANOVO'
      AND lee.logisticOperation = 'PICKUP'
      AND lee.deliverytype = dp.RETURNTYPE
  WHERE dp.RETURNTYPE = 'SHOP'
    AND CAST(dp.REQUESTDATE AS DATE) BETWEEN initial_date AND end_date
    AND dp.CODEAGENT NOT IN ('LB152006') 
);

END