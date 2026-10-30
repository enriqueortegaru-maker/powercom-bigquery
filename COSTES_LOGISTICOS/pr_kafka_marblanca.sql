BEGIN

    CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_marblanca`
      OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT ke.createdDatetime
        , ke.expeditionId
        , ke.reexpedition
        , subscriptions.orderCrmId
        , devices.subscriptionDeviceId
        , customer.user.contactData.phoneNumber.number AS phone_nm
        , customer.user.identityDocument.type AS document_type
        , customer.user.identityDocument.number AS document_nm
        , UPPER(ks.marca) AS brand_ds
        , UPPER(ke.logisticsOperator) AS logisticsOperator
        , UPPER(ke.businessProcess) AS businessProcess
        , UPPER(ke.logisticOperation) AS logisticOperation
        , ks.serial_number
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` ke, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped` ks
        ON  ks.orderCrmId = subscriptions.orderCrmId
        AND ks.expeditionId = ke.expeditionId  --2024/11/27
        AND ks.reexpedition = ke.reexpedition
    WHERE TIMESTAMP_TRUNC(ke.loadDate, DAY) >= TIMESTAMP("2025-01-01") 
      AND UPPER(ke.logisticsOperator) = 'INTERBOX'
      AND UPPER(ke.tenantByTopic) IN ('MARBLANCA')
      AND UPPER(ke.businessProcess) IN ('PEDIDO')
      AND UPPER(ke.logisticOperation) IN ('DELIVERY')
  ;

END