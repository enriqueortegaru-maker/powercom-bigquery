BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_preparation`('2025-09-01')

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_kafka_direccion`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_direccion`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT * 
  FROM (
    SELECT UPPER(tenantByTopic) AS marca
        , subscriptions.orderCrmId AS id_orden
        , reexpedition AS reexpedition
        , businessProcess AS tipo_pedido
        , customer.user.identityDocument.number AS documento
        , addressLines.addressLineValue AS direccion
        , expeditionId AS expeditionId  --2024/11/27
        , CAST(createdDatetime AS DATETIME) AS createdDatetime  --2024/11/27
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(shipping.address.addressLines) AS addressLines
    -- Elimino filtro por marcas 2026/02/17
    -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') 
    --   AND logisticsOperator = 'INTERBOX'
    WHERE logisticsOperator = 'INTERBOX'
      AND addressLines.addressLineName = 'Street'
--      AND businessProcess IN ('PEDIDO','DESISTIMIENTO')
    QUALIFY RANK () OVER (PARTITION BY tenantByTopic, subscriptions.orderCrmId, reexpedition ORDER BY createdDatetime DESC) = 1
  )
  QUALIFY ROW_NUMBER() OVER (PARTITION BY marca, id_orden, reexpedition ORDER BY createdDatetime DESC) = 1;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_kafka_provincia`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_provincia`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT marca, id_orden, MAX(provincia) AS provincia
  FROM(
      SELECT UPPER(tenantByTopic) AS marca
            , subscriptions.orderCrmId AS id_orden
            , CASE WHEN UPPER(addressLines.addressLineValue) = 'CORUÑA, A' THEN 'A CORUÑA'
                   WHEN UPPER(addressLines.addressLineValue) = 'CORU&NTILDE;A' THEN 'A CORUÑA'
                   WHEN UPPER(addressLines.addressLineValue) = 'CORUNA' THEN 'A CORUÑA'
                   WHEN UPPER(addressLines.addressLineValue) = 'CORUA‘A, A' THEN 'A CORUÑA'
                   WHEN UPPER(addressLines.addressLineValue) = 'LA CORU&NTILDE;A' THEN 'A CORUÑA'
                   WHEN UPPER(addressLines.addressLineValue) = 'ALAVA' THEN 'ARABA/ÁLAVA'
                   WHEN UPPER(addressLines.addressLineValue) = 'ARABA/ALAVA' THEN 'ARABA/ÁLAVA'
                   WHEN UPPER(addressLines.addressLineValue) = 'AAAAVILA' THEN 'ÁVILA'
                   WHEN UPPER(addressLines.addressLineValue) = 'AVILA' THEN 'ÁVILA'
                   WHEN UPPER(addressLines.addressLineValue) = 'ALICANTE' THEN 'ALICANTE/ALACANT'
                   WHEN UPPER(addressLines.addressLineValue) = 'ALACANT' THEN 'ALICANTE/ALACANT'
                   WHEN UPPER(addressLines.addressLineValue) = 'ALMER&IACUTE;A' THEN 'ALMERÍA'
                   WHEN UPPER(addressLines.addressLineValue) = 'ALMERAA' THEN 'ALMERÍA'
                   WHEN UPPER(addressLines.addressLineValue) = 'ALMERIA' THEN 'ALMERÍA'
                   WHEN UPPER(addressLines.addressLineValue) = 'BALEARES' THEN 'ILLES BALEARS'
                   WHEN UPPER(addressLines.addressLineValue) = 'ISLAS BALEARES' THEN 'ILLES BALEARS'
                   WHEN UPPER(addressLines.addressLineValue) = 'C&AACUTE;CERES' THEN 'CÁCERES'
                   WHEN UPPER(addressLines.addressLineValue) = 'CACERES' THEN 'CÁCERES'
                   WHEN UPPER(addressLines.addressLineValue) = 'C&AACUTE;DIZ' THEN 'CÁDIZ'
                   WHEN UPPER(addressLines.addressLineValue) = 'CADIZ' THEN 'CÁDIZ'
                   WHEN UPPER(addressLines.addressLineValue) = 'CADIZ' THEN 'CÁDIZ'
                   WHEN UPPER(addressLines.addressLineValue) = 'C&OACUTE;RDOBA' THEN 'CÓRDOBA'
                   WHEN UPPER(addressLines.addressLineValue) = 'CORDOBA' THEN 'CÓRDOBA'
                   WHEN UPPER(addressLines.addressLineValue) = 'CASTELL&AMP;AMP;OACUTE;N' THEN 'CASTELLÓN/CASTELLÓ'
                   WHEN UPPER(addressLines.addressLineValue) = 'CASTELL&AMP;OACUTE;N' THEN 'CASTELLÓN/CASTELLÓ'
                   WHEN UPPER(addressLines.addressLineValue) = 'CASTELL&OACUTE;N' THEN 'CASTELLÓN/CASTELLÓ'
                   WHEN UPPER(addressLines.addressLineValue) = 'CASTELLON' THEN 'CASTELLÓN/CASTELLÓ'
                   WHEN UPPER(addressLines.addressLineValue) = 'CASTELLÓN' THEN 'CASTELLÓN/CASTELLÓ'
                   WHEN UPPER(addressLines.addressLineValue) = 'GERONA' THEN 'GIRONA'
                   WHEN UPPER(addressLines.addressLineValue) = 'GUIPUZCOA' THEN 'GIPUZKOA'
                   WHEN UPPER(addressLines.addressLineValue) = 'JAEN' THEN 'JAÉN'
                   WHEN UPPER(addressLines.addressLineValue) = 'LA‰RIDA' THEN 'LLEIDA'
                   WHEN UPPER(addressLines.addressLineValue) = 'LÉRIDA' THEN 'LLEIDA'
                   WHEN UPPER(addressLines.addressLineValue) = 'LERIDA' THEN 'LLEIDA'
                   WHEN UPPER(addressLines.addressLineValue) = 'LE&AMP;OACUTE;N' THEN 'LEÓN'
                   WHEN UPPER(addressLines.addressLineValue) = 'LE&OACUTE;N' THEN 'LEÓN'
                   WHEN UPPER(addressLines.addressLineValue) = 'LEA“N' THEN 'LEÓN'
                   WHEN UPPER(addressLines.addressLineValue) = 'LEON' THEN 'LEÓN'
                   WHEN UPPER(addressLines.addressLineValue) = 'M&AACUTE;LAGA' THEN 'MÁLAGA'
                   WHEN UPPER(addressLines.addressLineValue) = 'M&AMP;AACUTE;LAGA' THEN 'MÁLAGA'
                   WHEN UPPER(addressLines.addressLineValue) = 'MÃÂÃÂLAGA' THEN 'MÁLAGA'
                   WHEN UPPER(addressLines.addressLineValue) = 'MALAGA' THEN 'MÁLAGA'
                   WHEN UPPER(addressLines.addressLineValue) = 'MALAGA' THEN 'MÁLAGA'
                   WHEN UPPER(addressLines.addressLineValue) = 'S. C. DE TENERIFE' THEN 'S.C. TENERIFE'
                   WHEN UPPER(addressLines.addressLineValue) = 'TENERIFE' THEN 'S.C. TENERIFE'
                   WHEN UPPER(addressLines.addressLineValue) = 'VIZCAYA' THEN 'BIZKAIA'
                   WHEN UPPER(addressLines.addressLineValue) = 'VALENCIA' THEN 'VALENCIA/VALÈNCIA'
            ELSE UPPER(addressLines.addressLineValue) END AS provincia
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(shipping.address.addressLines) AS addressLines
      -- Elimino filtro por marcas 2026/02/17
      -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO')  -- ('YOIGO','MASMOVIL')
      -- AND UPPER(logisticsOperator) = 'INTERBOX'
    WHERE UPPER(logisticsOperator) = 'INTERBOX'
--      AND UPPER(businessProcess) = 'PEDIDO'
      AND UPPER(logisticOperation) = 'DELIVERY'
      AND addressLines.addressLineName = 'Province'
  )
  GROUP BY ALL;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_kafka_shipped`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_shipped`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT marca, orderCrmId, reexpedition, weight, courier, service, expeditionId, identifier AS serial_number, businessProcess, rank, expeditionIdExternal
  FROM (
    SELECT CASE WHEN (transport.courier = 'CORREOS' AND subscriptionId IS NULL) THEN 'DOCUMENTACION' ELSE 'PEDIDO' END AS documentacion  --Intentamos identificar la documentación de las Smart-TV. Si faltan pedidos, esta podría ser la causa.
--      , CAST(subscriptions.orderCrmId AS INTEGER) AS orderCrmId
      , subscriptions.orderCrmId AS orderCrmId
      , reexpedition, transport.deliveryDetails.package.weight, transport.courier, transport.service
      , kf.expeditionId  --2024/11/27
      , kf.expeditionIdExternal  --valor pedido eurologistica (2025/09)
      , kf.businessProcess       --añado si es pedido o desistimiento (2025/09)
      , devices.identifier
      , UPPER(tenantByTopic) AS marca
--Ordeno para quedarme con el peso mayor, eliminANDo el duplicado por la SIM, pero incluyo reexpediciones y fechas para asegurar que incluya todas las expediciones  -- 2026/01/31
--      , RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition, expeditionId ORDER BY transport.deliveryDetails.package.weight DESC) AS rank  
      , RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition ORDER BY transport.deliveryDetails.package.weight DESC, shippedDatetime DESC) AS rank
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_SHIPPED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
      -- Elimino filtro por marcas 2026/02/17
    -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
    --   AND UPPER(businessProcess) = 'PEDIDO'
--    WHERE UPPER(businessProcess) = 'PEDIDO'
--      AND UPPER(subscriptions.orderCrmId) NOT LIKE '%M%'
    QUALIFY rank = 1   --Me quedo con el peso mayor, eliminANDo la SIM cuANDo tiene dispositivo
    )
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_shipped_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT CASE WHEN (transport.courier = 'CORREOS' AND subscriptionId IS NULL) THEN 'DOCUMENTACION' ELSE 'PEDIDO' END AS documentacion  --Intentamos identificar la documentación de las Smart-TV. Si faltan pedidos, esta podría ser la causa.
    , subscriptions.orderCrmId AS orderCrmId
    , reexpedition, transport.deliveryDetails.package.weight, transport.courier, transport.service
    , kf.expeditionId  
    , kf.expeditionIdExternal
    , kf.businessProcess  
    , devices.identifier
    , UPPER(tenantByTopic) AS marca
    , devices.subscriptionDeviceId
    , kf.shippedDatetime
  FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_SHIPPED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
  WHERE TIMESTAMP_TRUNC(shippedDatetime, DAY) >= CAST (initial_date AS TIMESTAMP)   --'2024-05-01'
    AND UPPER(kf.logisticsOperator) = 'INTERBOX'
    AND UPPER(kf.deliveryType) = 'HOME'
    AND UPPER(kf.businessProcess) = 'PEDIDO'
    AND UPPER(transport.courier) = 'CORREOS'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition, expeditionIdExternal ORDER BY shippedDatetime DESC, devices.subscriptionDeviceId DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_shipped_desestimiento`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT marca, orderCrmId, reexpedition, weight, courier, service, expeditionId, identifier AS serial_number, businessProcess, rank, expeditionIdExternal
  FROM (
    SELECT CASE WHEN (transport.courier = 'CORREOS' AND subscriptionId IS NULL) THEN 'DOCUMENTACION' ELSE 'PEDIDO' END AS documentacion  
      , subscriptions.orderCrmId AS orderCrmId
      , reexpedition, transport.deliveryDetails.package.weight, transport.courier, transport.service
      , kf.expeditionId  
      , kf.expeditionIdExternal  --valor pedido eurologistica (2025/09)
      , kf.businessProcess       --añado si es pedido o desistimiento (2025/09)
      , devices.identifier
      , UPPER(tenantByTopic) AS marca
      , RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition, expeditionId ORDER BY transport.deliveryDetails.package.weight DESC) AS rank  
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_SHIPPED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
      -- Elimino filtro por marcas 2026/02/17
    -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO')
    --   AND UPPER(businessProcess) = 'DESISTIMIENTO'
    WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
    QUALIFY rank = 1   --Me quedo con el peso mayor, eliminANDo la SIM cuANDo tiene dispositivo
    )
  GROUP BY ALL;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_kafka_codigo_postal`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_codigo_postal`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT UPPER(tenantByTopic) AS marca
      , subscriptions.orderCrmId AS id_orden
      , MAX(addressLines.addressLineValue) AS codigo_postal  --ALGUNOS PEDIDOS TIENEN 2 DIFERENTES, TENEMOS QUE QUEDARNOS CON UNO (EJEMPLO 16905951)
  FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(shipping.address.addressLines) AS addressLines
  WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO')  -- ('YOIGO','MASMOVIL')
    AND UPPER(logisticsOperator) = 'INTERBOX'
--    AND UPPER(businessProcess) = 'PEDIDO'
    AND UPPER(logisticOperation) = 'DELIVERY'
    AND addressLines.addressLineName = 'ZipCode'
  GROUP BY ALL;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_kafka_preparation`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_preparation`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT UPPER(marca) AS marca, orderCrmId, reexpedition
    , CASE WHEN printed_pages IS NULL THEN 0 ELSE printed_pages END AS impresos
    , CASE WHEN preprinted_pages IS NULL THEN 0 ELSE preprinted_pages END AS preimpresos
    , tipo, referencia
  FROM (
    SELECT *
      , (SELECT MAX(documentation.totalPages) AS totalPages
          FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST(subscriptions) subscriptions, UNNEST(documentation) documentation
          -- Elimino filtro por marcas 2026/02/17
          -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
          --   AND TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
          WHERE TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
            AND preprinted = 'false'
            AND subscriptions.orderCrmId = ORDENES.orderCrmId AND reexpedition = ORDENES.reexpedition
        ) AS printed_pages
      , (SELECT MAX(documentation.totalPages) AS totalPages
          FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST(subscriptions) subscriptions, UNNEST(documentation) documentation
          -- Elimino filtro por marcas 2026/02/17
          -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
          --   AND TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
          WHERE TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
            AND preprinted = 'true'
            AND subscriptions.orderCrmId = ORDENES.orderCrmId AND reexpedition = ORDENES.reexpedition
        ) AS preprinted_pages
    FROM 
    (
    SELECT DISTINCT tenantByTopic AS marca, subscriptions.orderCrmId AS orderCrmId, reexpedition, devices.type AS tipo, devices.reference AS referencia
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST(subscriptions) subscriptions, UNNEST(subscriptions.devices) devices
      -- Elimino filtro por marcas 2026/02/17
    -- WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
    --   AND devices.reference NOT IN ('ZYODOCTVB') --EXCLUYO LA DOCUMENTACION DE LAS SMART-TVs
    WHERE devices.reference NOT IN ('ZYODOCTVB') --EXCLUYO LA DOCUMENTACION DE LAS SMART-TVs
      AND TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
    ) ORDENES
  );


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_preparation_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT UPPER(marca) AS marca, orderCrmId, reexpedition
    , CASE WHEN printed_pages IS NULL THEN 0 ELSE printed_pages END AS impresos
    , CASE WHEN preprinted_pages IS NULL THEN 0 ELSE preprinted_pages END AS preimpresos
    , tipo, referencia, id_orden
  FROM (
    SELECT *
      , (SELECT MAX(documentation.totalPages) AS totalPages
          FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST(subscriptions) subscriptions, UNNEST(documentation) documentation
          WHERE TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
            AND preprinted = 'false'
            AND subscriptions.orderCrmId = ORDENES.orderCrmId AND reexpedition = ORDENES.reexpedition
        ) AS printed_pages
      , (SELECT MAX(documentation.totalPages) AS totalPages
          FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST(subscriptions) subscriptions, UNNEST(documentation) documentation
          WHERE TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
            AND preprinted = 'true'
            AND subscriptions.orderCrmId = ORDENES.orderCrmId AND reexpedition = ORDENES.reexpedition
        ) AS preprinted_pages
    FROM 
    (
    SELECT DISTINCT tenantByTopic AS marca, subscriptions.orderCrmId AS orderCrmId, reexpedition, 'DOCUMENTACION SMART TV' AS tipo, devices.reference AS referencia
      , CASE WHEN CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING) IS NOT NULL AND CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING) <> '' THEN CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING)
             WHEN devices.subscriptionDeviceId IS NOT NULL AND devices.subscriptionDeviceId <> '' THEN devices.subscriptionDeviceId
             WHEN subscriptions.orderCrmId IS NOT NULL THEN subscriptions.orderCrmId 
             ELSE CAST(NULL AS STRING) END AS id_orden
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST(subscriptions) subscriptions, UNNEST(subscriptions.devices) devices
    WHERE devices.reference IN ('ZYODOCTVB') --EXCLUYO LA DOCUMENTACION DE LAS SMART-TVs
      AND TIMESTAMP_TRUNC(loadDate, DAY) >=  TIMESTAMP(initial_date) -- TIMESTAMP("2024-03-01")
    ) ORDENES
  );

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_kafka_tipo_dispositivo`
  --Lo eliminamos en feb/25 porque ya no lo usamos
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_tipo_dispositivo`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  --SACAMOS LOS TIPOS DE CADA REFERENCIA, LOS QUE NO SE MUESTREN SERÁN GENERIC
  SELECT UPPER(tenantByTopic) AS marca, devices.reference, devices.type
  FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST (subscriptions) subscriptions, UNNEST (devices) devices
    , (
        SELECT DISTINCT devices.reference AS referencia
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED_*`, UNNEST (subscriptions) subscriptions, UNNEST (devices) devices
    ) modelos
  WHERE modelos.referencia = devices.reference
    AND devices.type NOT IN ('GENERIC')
  GROUP BY ALL
  ORDER BY 1;
/*
  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_dispositivo_calculado`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dispositivo_calculado`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT UPPER(marca) AS marca, id_orden,
    CASE WHEN CUENTA_LINEAS >= 1 AND CUENTA_SIMs >= 1 AND CUENTA_TERMINAL = 0 AND CUENTA_PATINETE = 0 AND CUENTA_TV = 0 AND CUENTA_ROUTER = 0 AND CUENTA_SMARTHOME = 0 AND CUENTA_STB = 0 THEN 'SIM'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_TERMINAL >= 1   THEN 'Terminal'
        WHEN CUENTA_LINEAS  >= 2 AND CUENTA_SIMs >= 1 AND CUENTA_TERMINAL >= 1 THEN 'SIM + Terminal'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_PATINETE >= 1   THEN 'PATINETE'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_TV       >= 1   THEN 'TV'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_ROUTER >= 1     THEN 'Router'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_SMARTHOME >= 1  THEN 'SmartHome'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_STB >= 1        THEN 'STB'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_ACCESORIO >= 1  THEN 'ACCESORIO'
        WHEN CUENTA_LINEAS  = 1 AND CUENTA_SIMs = 0 AND CUENTA_GENERIC >= 1    THEN 'Terminal'
        WHEN CUENTA_LINEAS  > 1 AND (CUENTA_SIMs-1) >= 1                       THEN 'SIM_adicional' --Hay que ver como incluir el cálculo de SIMs adicionales
        ELSE 'REVISAR - CASO NO CONTEMPLADO'
    END AS dispositivo_calculado
  FROM (
    SELECT ORDENES.marca AS marca, ORDENES.id_orden
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden) AS CUENTA_LINEAS
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'SIM') AS CUENTA_SIMs
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'TERMINAL') AS CUENTA_TERMINAL
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'PATINETE') AS CUENTA_PATINETE
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) IN ('TV','SMART_TV')) AS CUENTA_TV
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'ROUTER') AS CUENTA_ROUTER
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'SMARTHOME') AS CUENTA_SMARTHOME
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'STB') AS CUENTA_STB
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'ACCESORIO') AS CUENTA_ACCESORIO
      , (SELECT COUNT (1) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS WHERE LINEAS.id_orden = ORDENES.id_orden AND UPPER(LINEAS.dispositivo) = 'GENERIC') AS CUENTA_GENERIC
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` ORDENES
    WHERE id_orden IS NOT NULL
  ) SIM_DISPO
  ;
*/
  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_canal_directo`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_canal_directo`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ot AS OT, pedidomm AS PEDIDOMM, itemnumber AS ITEMNUMBER, linea AS LINEA
    , tecnologia AS TECNOLOGIA, estado AS ESTADO, obscourier AS OBSCOURIER
    , fechacreacion AS FECHACREACION, fechaestado AS FECHAESTADO, salidaalmacen AS SALIDAALMACEN
    , fechadeentrega AS  FECHADEENTREGA, solicituddecancelacion AS SOLICITUDDECANCELACION
    , referenciapadreenvio AS REFERENCIAPADRE, referenciatipoenvio AS REFERENCIATIPO
    , referenciaenvio AS REFERENCIA, descripcionenvio AS DESCRIPCION, nserieenvio AS NSERIE
    , cantidadenvio AS CANTIDAD, canalventa AS CANALVENTA, master AS MASTER, tfncontacto AS TFNCONTACTO--, CLIENTE, DNI
    , subtipocliente AS SUBTIPOCLIENTE
    --, DIRECCION
    , poblacion AS POBLACION, provincia AS PROVINCIA, codigopostal AS CODIGOPOSTAL, operadorlogistico AS OPERADORLOGISTICO
    , CASE WHEN rx IS NULL THEN 'R0' ELSE rx END AS RX
    , sims AS SIMS,ultimaincidencia AS ULTIMAINCIDENCIA, portabilidad AS PORTABILIDAD, parvacante AS PARVACANTE
    , msisdn AS MSISDN, tipopedidomysim AS TIPOPEDIDOMYSIM, tipocliente AS TIPOCLIENTE
    , subscriptiondeviceid AS SUBSCRIPTIONDEVICEID, entregasegura AS ENTREGASEGURA, retornodac AS RETORNODAC, fotodni AS FOTODNI
    , entregaexclusiva AS ENTREGAEXCLUSIVA, courier AS COURIER, servicio AS SERVICIO
  FROM (
    SELECT * 
    FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml
    WHERE ml.operadorlogistico = 'Interbox'
      AND ml.tipocliente = 'Canal Directo'
      AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
      AND ml.referenciatipoenvio NOT IN ('Papelería')
      AND ml.estado NOT IN ('Cancelación solicitada')
    QUALIFY RANK() OVER (PARTITION BY ml.itemnumber, ml.rx ORDER BY ml.fechaestado DESC, ml.salidaalmacen DESC) = 1 
  )tabla
  QUALIFY ROW_NUMBER() OVER(PARTITION BY tabla.itemnumber, tabla.nserieenvio ORDER BY tabla.rx) = 1;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_canal_directo`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_canal_directo_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT OT, PEDIDOMM, ITEMNUMBER, LINEA, TECNOLOGIA, ESTADO, OBSCOURIER, FECHACREACION, FECHAESTADO, SALIDAALMACEN, FECHADEENTREGA, SOLICITUDDECANCELACION, referenciapadreenvio AS REFERENCIAPADRE, referenciatipoenvio AS REFERENCIATIPO, referenciaenvio AS REFERENCIA, descripcionenvio AS DESCRIPCION, nserieenvio AS NSERIE, cantidadenvio AS CANTIDAD, CANALVENTA, MASTER, TFNCONTACTO--, CLIENTE, DNI
    , SUBTIPOCLIENTE
    --, DIRECCION
    , POBLACION, PROVINCIA, CODIGOPOSTAL, OPERADORLOGISTICO
    , CASE WHEN RX IS NULL THEN 'R0' ELSE RX END AS RX
    , SIMS, ULTIMAINCIDENCIA, PORTABILIDAD, PARVACANTE, MSISDN, TIPOPEDIDOMYSIM, TIPOCLIENTE, SUBSCRIPTIONDEVICEID, ENTREGASEGURA, RETORNODAC, FOTODNI, ENTREGAEXCLUSIVA, COURIER, SERVICIO
  FROM (
    SELECT * 
    FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml
    WHERE ml.operadorlogistico = 'Interbox'
      AND ml.tipocliente = 'Canal Directo'
      AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
      AND ml.referenciatipoenvio IN ('Papelería')
      AND ml.referenciaenvio IN ('ZYODOCTVB')
      --AND ml.estado NOT IN ('Cancelación solicitada')
      AND ml.estado IN ('Cancelado-Anulado','Entregado a custodiador','Entregado en punto de entrega','Entregado en WH')  --ELIMINO LOS QUE NO SEAN ENTREGADO O anulado pre picking
    QUALIFY RANK() OVER (PARTITION BY ml.itemnumber, ml.rx ORDER BY ml.fechaestado DESC, ml.salidaalmacen DESC) = 1 
  )tabla
  QUALIFY ROW_NUMBER() OVER(PARTITION BY tabla.itemnumber, tabla.nserieenvio ORDER BY tabla.rx) = 1;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_dispositivo`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_dispositivo`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT oml.itemnumber
--    , oml.RX
    , CASE WHEN oml.rx IS NULL THEN 'R0' ELSE oml.rx END AS RX
    
    , oml.referenciatipoenvio, oml.tecnologia

    , CASE 
          WHEN oml.courier = 'HL' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%SMART TV%'  AND UPPER(oml.descripcionenvio) NOT LIKE '%STICK%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%GOOGLE TV%' AND UPPER(oml.descripcionenvio) NOT LIKE '%STICK%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%XIAOMI TV%' AND UPPER(oml.descripcionenvio) NOT LIKE '%STICK%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%QLED%TV%'   AND UPPER(oml.descripcionenvio) NOT LIKE '%STICK%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%TV%QLED%'   AND UPPER(oml.descripcionenvio) NOT LIKE '%STICK%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%SCOOTER%' THEN 'PATINETE'
          WHEN (UPPER(oml.descripcionenvio) LIKE '%CAJA DE VOZ%' OR UPPER(oml.descripcionenvio) LIKE '%MIFI%') THEN 'ACCESORIO'
          WHEN oml.referenciatipoenvio = 'SIM Card' THEN 'SIM'
          WHEN oml.referenciatipoenvio = 'Terminal' THEN 'TERMINAL'
          WHEN oml.referenciatipoenvio ='Tablet' THEN 'TABLET'
          WHEN oml.referenciatipoenvio IN ('Accesories','Accesories with Imei','Accesories with Serial Number') THEN 'ACCESORIO'
          WHEN oml.referenciatipoenvio IN ('Router ADSL','Router Fibra') THEN 'ROUTER'
          WHEN oml.referenciatipoenvio IN ('Modem') THEN 'ACCESORIO'
          WHEN oml.referenciatipoenvio IN ('TV Yoigo') THEN 'STB'
          WHEN oml.referenciatipoenvio = 'Papelería' THEN 'DOCUMENTACION'
          WHEN oml.referenciatipoenvio NOT IN ('Accesories','Accesories with Imei','Accesories with Serial Number','Modem','Papelería','Router ADSL','Router Fibra','SIM Card','TV Yoigo','Tablet','Terminal') THEN oml.referenciatipoenvio
          WHEN kt.type IS NOT NULL AND oml.referenciatipoenvio IS NULL THEN kt.type
          WHEN grc.referencia IS NOT NULL THEN 'ACCESORIO'  
          ELSE 'GENERIC' END AS dispositivo
    , oml.nserieenvio AS numero_serie 
    , otros.tipo AS otros_equipos

  --FROM `mm-commissions-reporting.TEMP.ORDERS_MASLOLA` oml
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` oml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
    lEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation` kp
      ON  kp .orderCrmId = CAST(oml.itemnumber AS STRING)
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_tipo_dispositivo` kt
      ON  kt.reference = kp.referencia 
    LEFT JOIN  `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_router_cliente_final` grc
      ON  grc.referencia = oml.referenciaenvio
      AND grc.fecha_desde <= CAST(oml.fechacreacion AS DATE)
      AND grc.fecha_hasta >= CAST(oml.fechacreacion AS DATE)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_otros_equipos` otros
      ON  otros.codigo = oml.referenciaenvio

--  WHERE oml.NSERIE IS NOT NULL 

  GROUP BY ALL;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_lineas`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_lineas`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  --Sacamos el nº de línea de cada pedido
  SELECT COALESCE(ml.pedidomm,ml.itemnumber) AS PEDIDOMM, MAX(ml.linea) AS LINEA
  --FROM `mm-commissions-reporting.TEMP.ORDERS_MASLOLA` ml
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
  GROUP BY ALL;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_orderbox_canal_directo`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.orderbox_canal_directo`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT
      CAST(NULL AS STRING) AS OT
    , num_pedido_asociado AS PEDIDOMM
    , num_pedido_asociado AS ITEMNUMBER
    , CAST (1 AS INTEGER) AS LINEA
    , NULL TECNOLOGIA                          --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , estado AS ESTADO
    , COALESCE((SELECT MAX (subestado) FROM `mm-datamart-kd.TICKETING.orderbox_base_tickets` obt WHERE day >= initial_date AND  obt.num_pedido_asociado = num_pedido_asociado AND estado = 'Cerrado'),CAST (NULL AS STRING)) AS OBSCOURIER
    , fecha_creacion AS FECHACREACION
    , fecha_estado_gestion AS FECHAESTADO
    , CAST (NULL AS TIMESTAMP) AS SALIDAALMACEN
    , CAST (NULL AS TIMESTAMP) AS FECHADEENTREGA
    , CAST(NULL AS STRING) AS SOLICITUDDECANCELACION
    , CAST(NULL AS STRING) AS REFERENCIAPADRE  --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS REFERENCIATIPO   --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS REFERENCIA       --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS DESCRIPCION      --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , COALESCE (imei_recoger, imei_enviar, NULL) AS NSERIE
    , CAST (1 AS INTEGER) AS CANTIDAD
    , CAST(NULL AS STRING) AS CANALVENTA       --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS MASTER           --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , telefono_contacto_cliente AS TFNCONTACTO
    , CAST(NULL AS STRING) AS CLIENTE          --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS DNI              --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS SUBTIPOCLIENTE   --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CAST(NULL AS STRING) AS DIRECCION
    , direccion_cliente_ciudad AS POBLACION
    , CAST(NULL AS STRING) AS PROVINCIA        --Tomar del pedido original al consutruir la tabla 40_logistic_order
    , CASE WHEN digitos_cp = 5 THEN direccion_cliente_cp
          WHEN digitos_cp = 4 THEN CONCAT('0',direccion_cliente_cp)
          WHEN digitos_cp = 3 THEN CONCAT(CONCAT('0',direccion_cliente_cp),'0')
          END AS CODIGOPOSTAL
    , CASE WHEN UPPER(usuario_gestion) = 'INTERBOX' THEN 'Interbox' ELSE usuario_gestion END AS OPERADORLOGISTICO
    , CAST(NULL AS STRING) AS RX
    , 'NO' AS SIMS
    , fecha_creacion AS ULTIMAINCIDENCIA
    , CAST(NULL AS STRING) AS PORTABILIDAD
    , CAST(NULL AS STRING) AS PARVACANTE
    , msisdn_cliente AS MSISDN  
    , tipo AS TIPOPEDIDOMYSIM
    , 'Canal Directo' AS TIPOCLIENTE
    , CAST(NULL AS STRING) AS SUBSCRIPTIONDEVICEID
    , CAST(NULL AS STRING) AS ENTREGASEGURA
    , CAST(NULL AS STRING) AS RETORNODAC
    , CAST(NULL AS STRING) AS FOTODNI
    , CAST(NULL AS STRING) AS ENTREGAEXCLUSIVA
    , CAST(NULL AS STRING) AS COURIER
    , CAST(NULL AS STRING) AS SERVICIO
    , rma AS RMA
    , UPPER(marca) AS MARCA
    , ticket AS TICKET
    , subestado AS SUBESTADO
--    , rank

  FROM (
    SELECT UPPER(obt.brand) AS marca, obt.num_pedido_asociado, obt.estado, obt.fecha_creacion, obt.imei_recoger, obt.imei_enviar, obt.telefono_contacto_cliente, obt.direccion_cliente_ciudad
        , CAST(obt.direccion_cliente_cp AS STRING) AS direccion_cliente_cp, LENGTH(CAST(obt.direccion_cliente_cp AS STRING)) AS digitos_cp
        , CAST(obt.fecha_estado_gestion AS DATE) AS fecha_estado_gestion
        , obt.usuario_gestion, obt.msisdn_cliente, obt.tipo, obt.rma, obt.ticket
        , obt.subestado, obt.fecha_estado_gestion AS FECHA_GESTION
--        , RANK () OVER(PARTITION BY obt.num_pedido_asociado, obt.tipo ORDER BY fecha_estado_gestion DESC) AS rank  --2024/11/28
    FROM `mm-datamart-kd.TICKETING.orderbox_base_tickets` obt
    WHERE UPPER(usuario_gestion) = 'INTERBOX' 
      AND UPPER (perfil_usuario_gestion) = 'INTERBOX' 
      AND (
          obt.estado = 'Cerrado'  --Quitamos Cancelado, En proceso y Sin procesar
                                  --O añadimos subestados finales, que no se ha actualizado el campo estado en orderbox
          OR (obt.estado = 'En proceso' AND obt.subestado IN ('Abonado OL','Abono a Yoigo','Abono a cliente','Cancelado','Desastre','Devuelto al almacen','Devuelto almacen','Entregado','Siniestro','Desistimiento aceptado'))
      )
      AND tipo NOT IN ('Recogida STB baja','Recogida Router baja','Recogida HotSpot Baja')
      AND imei_recoger IS NOT NULL AND imei_recoger NOT IN ('NULL')
      AND obt.subestado IS NOT NULL  --2024/11/28
      AND day >= initial_date -- "2024-04-01" 
--    GROUP BY ALL
    QUALIFY RANK () OVER(PARTITION BY obt.ticket, obt.tipo ORDER BY fecha_estado_gestion, subestado DESC) = 1
  )
  QUALIFY ROW_NUMBER () OVER(PARTITION BY ticket, tipo ORDER BY fecha_estado_gestion, subestado DESC) = 1;


  --Tabla temporal de los subestados en los desistimientos en Orderbox
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.desistimiento_subestado_orderbox`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT 
    UPPER(brAND) AS MARCA,
    CAST (day AS DATE) AS day,
    num_pedido_asociado AS PEDIDOMM,
    ticket,
    imei_recoger,
    subestado,
    msisdn_cliente,
    telefono_contacto_cliente,
    CAST (fecha_estado_gestion AS DATETIME) AS FECHAESTADO,
    terminal_recoger STRING
  FROM `mm-datamart-kd.TICKETING.orderbox_base_tickets` obt
  WHERE UPPER(usuario_gestion) = 'INTERBOX' 
    AND UPPER (perfil_usuario_gestion) = 'INTERBOX' 
    -- Elimino filtro por marcas 2026/02/17
    -- AND UPPER(obt.brAND) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO')  -- ('YOIGO','MASMOVIL')
    AND tipo IN ('Desisimitiento','Desistimientos Fija')
    AND subestado IS NOT NULL
    AND (
        obt.estado = 'Cerrado'  --Quitamos Cancelado, En proceso y Sin procesar
                                --O añadimos subestados finales, que no se ha actualizado el campo estado en orderbox
        OR (obt.estado = 'En proceso' AND obt.subestado IN ('Abonado OL','Abono a Yoigo','Abono a cliente','Cancelado','Desastre','Devuelto al almacen','Devuelto almacen','Entregado','Siniestro'))
    )
    AND tipo NOT IN ('Recogida STB baja','Recogida Router baja','Recogida HotSpot Baja')
    AND imei_recoger IS NOT NULL AND imei_recoger NOT IN ('NULL')
    AND day >= initial_date -- "2024-04-01"
  ;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_inicio_picking`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_inicio_picking`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ml.itemnumber, ml.fechaestado, ml.estado
  --FROM `mm-commissions-reporting.TEMP.ORDERS_MASLOLA` ml
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    AND ml.estado = 'Inicio extracción'
    AND ml.referenciatipoenvio NOT IN ('Papelería')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_inicio_picking_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ml.itemnumber, ml.fechaestado, ml.estado
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    AND ml.estado = 'Inicio extracción'  
    AND ml.referenciatipo IN ('Papelería')
    AND ml.referencia IN ('ZYODOCTVB')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY itemnumber, estado ORDER BY fechaestado) = 1;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_salida_almacen`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_salida_almacen`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ml.itemnumber, ml.fechaestado, ml.estado
  --FROM `mm-commissions-reporting.TEMP.ORDERS_MASLOLA` ml
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    AND ml.estado = 'Salida de Almacen'
    AND ml.referenciatipoenvio NOT IN ('Papelería')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_salida_almacen_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ml.itemnumber, ml.fechaestado, ml.estado
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` ml
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.referenciatipo IN ('Papelería')
    AND ml.referencia IN ('ZYODOCTVB')
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    AND ml.estado = 'Salida de Almacen'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY itemnumber, estado ORDER BY fechaestado) = 1;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_maslola_estado_reexp`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_estado_reexp`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ITEMNUMBER
       , FECHAESTADO
       , estado
       , CASE WHEN rx IS NULL THEN 'R0' ELSE rx END AS reexpedition
  FROM (
    SELECT ml.itemnumber, ml.fechaestado, ml.estado, ml.rx
       , RANK() OVER (PARTITION BY ITEMNUMBER, RX ORDER BY FECHAESTADO DESC) AS rank
    --FROM `mm-commissions-reporting.TEMP.ORDERS_MASLOLA` ml
    FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
        ON gef.estado = ml.estado
    WHERE ml.operadorlogistico = 'Interbox'
      AND ml.tipocliente = 'Canal Directo'
      AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
      AND ml.referenciatipoenvio NOT IN ('Papelería')
      AND gef.final = 'SI'
    GROUP BY ALL
    ORDER BY 2 ASC
    )
  WHERE rank = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_estado_reexp_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT ml.itemnumber, ml.fechaestado, ml.estado, CASE WHEN rx IS NULL THEN 'R0' ELSE rx END AS reexpedition, ml.pedidomm, ml.ot--, ml.idol
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` ml
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    AND ml.referenciatipo IN ('Papelería')
    AND ml.referencia IN ('ZYODOCTVB')
    --AND ml.idol <> '0'
  QUALIFY RANK() OVER (PARTITION BY itemnumber, rx ORDER BY fechaestado DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.desistimiento_estado_final`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT *
      , RANK() OVER (PARTITION BY orderCrmId, reexpedition ORDER BY fecha DESC, id_modelo DESC, accion) AS rank
    FROM (

        --Desistimiento ACEPTADO
        SELECT 'EXPEDITION_ACCEPTED' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(acceptedDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
              , devices.identifier AS serial_number, devices.type AS tipo_dispositivo, devices.reference AS id_modelo
              , devices.price.markup.amount AS precio_con_markup, devices.price.noMarkup.amount AS precio_sin_markup
              , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
              , transport.pickupDetails.package.weight AS peso
              , CAST(acceptedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(acceptedDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_ACCEPTED*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
        AND UPPER(logisticOperation) = 'PICKUP'
        AND acceptedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        --Desistimiento NO ACEPTADO
        SELECT 'EXPEDITION_NOT_ACCEPTED' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(notAcceptedDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm   
              , devices.identifier AS serial_number
              , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
              , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
              , transport.pickupDetails.package.weight AS peso
              , CAST(notAcceptedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(notAcceptedDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_NOT_ACCEPTED_V2*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
        AND UPPER(logisticOperation) = 'PICKUP'
        AND notAcceptedDatetime >CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        ----Desistimiento ENTREGADO ALMACEN
        SELECT 'EXPEDITION_WAREHOUSE_DELIVERED' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(warehouseDeliveredDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
              , devices.identifier AS serial_number
              , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS seguro_transporte   --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS courier             --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS servicio            --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_expedicion       --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS peso               --dato no disponible en el kafka
              , CAST(warehouseDeliveredDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(warehouseDeliveredDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_WAREHOUSE_DELIVERED_V2*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
        AND UPPER(logisticOperation) = 'PICKUP'
        AND warehouseDeliveredDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        --Desistimiento ENTREGADO A CLIENTE
        SELECT 'EXPEDITION_DELIVERED' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(deliveredDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, ed.reexpedition, subscriptions.externalId.number AS phone_nm
              , devices.identifier AS serial_number
              , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS seguro_transporte   --dato no disponible en el kafka
--              , CAST(NULL AS STRING) AS courier             --dato no disponible en el kafka
              , CASE WHEN shipping.pickupType = 'AGENCY' THEN 'CORREOS' ELSE CAST(NULL AS STRING) END AS courier   --2025/04/10
              , CAST(NULL AS STRING) AS servicio            --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_expedicion       --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS peso               --dato no disponible en el kafka
              , CAST(deliveredDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(deliveredDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_DELIVERED_V*` ed, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
        AND UPPER(logisticOperation) = 'DELIVERY'  --Entrega al cliente de vuelta
        AND deliveredDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        --Desistimiento NO RECOGIDO
        SELECT 'EXPEDITION_NOT_COLLECTED' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(notCollectedDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
              , devices.identifier AS serial_number
              , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
              , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
              , transport.pickupDetails.package.weight AS peso
              , CAST(notCollectedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(notCollectedDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_NOT_COLLECTED_V2*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
        AND UPPER(logisticOperation) = 'PICKUP'
        AND notCollectedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        --Desistimiento DESASTRE
        SELECT 'EXPEDITION_DISASTER' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(disasterDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
              , devices.identifier AS serial_number
              , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS seguro_transporte   --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS courier             --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS servicio            --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_expedicion       --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS peso               --dato no disponible en el kafka
              , CAST(disasterDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(disasterDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_DISASTER_V*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
        AND UPPER(logisticOperation) = 'PICKUP'  --Entrega al cliente de vuelta
        AND disasterDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        --Desistimiento RECOGIDO
        SELECT 'EXPEDITION_COLLECTED' AS accion
              , UPPER(tenantByTopic) AS marca
              , CAST(SUBSTR(CAST(collectedDatetime AS STRING),1,19) AS DATETIME) AS fecha
              , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
              , devices.identifier AS serial_number
              , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
              , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
              , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
              , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
              , transport.pickupDetails.package.weight AS peso
              , CAST(collectedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(collectedDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_COLLECTED_V*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE businessProcess IN ('DESISTIMIENTO')
          -- Elimino filtro por marcas 2026/02/17
          -- AND UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
          AND collectedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL

        UNION ALL

        --Desistimiento CREADO
        SELECT 'EXPEDITION_CREATED' AS accion
        , UPPER(tenantByTopic) AS marca
        , CAST(SUBSTR(CAST(createdDatetime AS STRING),1,19) AS DATETIME) AS fecha
        , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
        , devices.identifier AS serial_number
        , CAST(NULL AS STRING) AS tipo_dispositivo     --dato no disponible en el kafka
        , CAST(NULL AS STRING) AS id_modelo            --dato no disponible en el kafka
        , CAST(NULL AS FLOAT64)  AS precio_con_markup  --dato no disponible en el kafka
        , CAST(NULL AS FLOAT64)  AS precio_sin_markup  --dato no disponible en el kafka
        , CAST(NULL AS STRING) AS seguro_transporte    --dato no disponible en el kafka
--        , CAST(NULL AS STRING) AS courier              --dato no disponible en el kafka
        , CASE WHEN shipping.pickupType = 'AGENCY' THEN 'CORREOS' ELSE CAST(NULL AS STRING) END AS courier   --2025/04/10
        , CAST(NULL AS STRING) AS servicio             --dato no disponible en el kafka
        , CAST(NULL AS STRING) AS id_expedicion        --dato no disponible en el kafka
        , CAST(NULL AS FLOAT64) AS peso                 --dato no disponible en el kafka
        , CAST(createdDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(createdDatetime AS STRING),1,19) AS fecha_txt
        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
        WHERE businessProcess = 'DESISTIMIENTO'
        AND createdDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
        GROUP BY ALL
    )
    QUALIFY rank = 1;

  --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.desistimiento_estado`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS


  /************************************
  * KAFKA_EVENTS.LOGISTICS_EXPEDITION *
  ************************************/

  /****************************************************************************
        ACCION                       IFS ESTADOS	               ESTADO FINAL
        ------                       -----------                 ------------
  EXPEDITION_WAREHOUSE_DELIVERED     ¿RETURNED?	                  SI
  EXPEDITION_NOT_ACCEPTED	           COLLECTED_NOT_OK_TIME_OUT    SI
  EXPEDITION_NOT_COLLECTED           NOT_COLLECTED	              NO
  EXPEDITION_DISASTER	               DISASTER	                    SI
  EXPEDITION_ACCEPTED	               COLLECTED_OK	                SI
  EXPEDITION_DELIVERED	             DELIVERED	                  SI
  ¿?	                               DELIVERED_TO_ANOVO	          SI
  ¿?	                               ATTEMP_TIME_OUT	            SI
  ****************************************************************************/

  SELECT *
    , RANK() OVER (PARTITION BY orderCrmId, reexpedition ORDER BY fecha DESC) AS rank
  FROM (

      --Desistimiento ACEPTADO
      SELECT 'EXPEDITION_ACCEPTED' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(acceptedDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
            , devices.identifier AS serial_number, devices.type AS tipo_dispositivo, devices.reference AS id_modelo
            , devices.price.markup.amount AS precio_con_markup, devices.price.noMarkup.amount AS precio_sin_markup
            , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
            , transport.pickupDetails.package.weight AS peso
            , CAST(acceptedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(acceptedDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_ACCEPTED*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
      AND UPPER(logisticOperation) = 'PICKUP'
      AND acceptedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      --Desistimiento NO ACEPTADO
      SELECT 'EXPEDITION_NOT_ACCEPTED' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(notAcceptedDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm   
            , devices.identifier AS serial_number
            , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
            , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
            , transport.pickupDetails.package.weight AS peso
            , CAST(notAcceptedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(notAcceptedDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_NOT_ACCEPTED_V2*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
      AND UPPER(logisticOperation) = 'PICKUP'
      AND notAcceptedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      ----Desistimiento ENTREGADO ALMACEN
      SELECT 'EXPEDITION_WAREHOUSE_DELIVERED' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(warehouseDeliveredDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
            , devices.identifier AS serial_number
            , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS seguro_transporte   --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS courier             --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS servicio            --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_expedicion       --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS peso               --dato no disponible en el kafka
            , CAST(warehouseDeliveredDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(warehouseDeliveredDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_WAREHOUSE_DELIVERED_V2*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
      AND UPPER(logisticOperation) = 'PICKUP'
      AND warehouseDeliveredDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      --Desistimiento ENTREGADO A CLIENTE
      SELECT 'EXPEDITION_DELIVERED' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(deliveredDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
            , devices.identifier AS serial_number
            , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS seguro_transporte   --dato no disponible en el kafka
--            , CAST(NULL AS STRING) AS courier             --dato no disponible en el kafka
            , CASE WHEN shipping.pickupType = 'AGENCY' THEN 'CORREOS' ELSE CAST(NULL AS STRING) END AS courier   --2025/04/10
            , CAST(NULL AS STRING) AS servicio            --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_expedicion       --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS peso               --dato no disponible en el kafka
            , CAST(deliveredDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(deliveredDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_DELIVERED_V*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
      AND UPPER(logisticOperation) = 'DELIVERY'  --Entrega al cliente de vuelta
      AND deliveredDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      --Desistimiento NO RECOGIDO
      SELECT 'EXPEDITION_NOT_COLLECTED' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(notCollectedDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
            , devices.identifier AS serial_number
            , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
            , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
            , transport.pickupDetails.package.weight AS peso
            , CAST(notCollectedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(notCollectedDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_NOT_COLLECTED_V2*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
      AND UPPER(logisticOperation) = 'PICKUP'
      AND notCollectedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      --Desistimiento DESASTRE
      SELECT 'EXPEDITION_DISASTER' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(disasterDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
            , devices.identifier AS serial_number
            , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS seguro_transporte   --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS courier             --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS servicio            --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_expedicion       --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS peso               --dato no disponible en el kafka
            , CAST(disasterDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(disasterDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_DISASTER_V*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE UPPER(businessProcess) = 'DESISTIMIENTO'
      AND UPPER(logisticOperation) = 'PICKUP'  --Entrega al cliente de vuelta
      AND disasterDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      --Desistimiento RECOGIDO
      SELECT 'EXPEDITION_COLLECTED' AS accion
            , UPPER(tenantByTopic) AS marca
            , CAST(SUBSTR(CAST(collectedDatetime AS STRING),1,19) AS DATETIME) AS fecha
            , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
            , devices.identifier AS serial_number
            , CAST(NULL AS STRING) AS tipo_dispositivo    --dato no disponible en el kafka
            , CAST(NULL AS STRING) AS id_modelo           --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_con_markup  --dato no disponible en el kafka
            , CAST(NULL AS FLOAT64) AS precio_sin_markup  --dato no disponible en el kafka
            , transport.coverage AS seguro_transporte, transport.courier AS courier, transport.service AS servicio, transport.expeditionNumber AS id_expedicion
            , transport.pickupDetails.package.weight AS peso
            , CAST(collectedDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(collectedDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_COLLECTED_V*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE businessProcess IN ('DESISTIMIENTO')
        -- Elimino filtro por marcas 2026/02/17
        -- AND UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO')
        AND collectedDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

      UNION ALL

      --Desistimiento CREADO
      SELECT 'EXPEDITION_CREATED' AS accion
      , UPPER(tenantByTopic) AS marca
      , CAST(SUBSTR(CAST(createdDatetime AS STRING),1,19) AS DATETIME) AS fecha
      , subscriptions.orderCrmId AS orderCrmId, reexpedition, subscriptions.externalId.number AS phone_nm
      , devices.identifier AS serial_number
      , CAST(NULL AS STRING) AS tipo_dispositivo     --dato no disponible en el kafka
      , CAST(NULL AS STRING) AS id_modelo            --dato no disponible en el kafka
      , CAST(NULL AS FLOAT64)  AS precio_con_markup  --dato no disponible en el kafka
      , CAST(NULL AS FLOAT64)  AS precio_sin_markup  --dato no disponible en el kafka
      , CAST(NULL AS STRING) AS seguro_transporte    --dato no disponible en el kafka
--      , CAST(NULL AS STRING) AS courier              --dato no disponible en el kafka
      , CASE WHEN shipping.pickupType = 'AGENCY' THEN 'CORREOS' ELSE CAST(NULL AS STRING) END AS courier   --2025/04/10
      , CAST(NULL AS STRING) AS servicio             --dato no disponible en el kafka
      , CAST(NULL AS STRING) AS id_expedicion        --dato no disponible en el kafka
      , CAST(NULL AS FLOAT64) AS peso                 --dato no disponible en el kafka
      , CAST(createdDatetime AS DATE) AS fecha_dia, SUBSTR(CAST(createdDatetime AS STRING),1,19) AS fecha_txt
      FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*`, UNNEST (subscriptions) AS subscriptions, UNNEST(subscriptions.devices) AS devices
      WHERE businessProcess = 'DESISTIMIENTO'
      AND createdDatetime > CAST(initial_date AS TIMESTAMP) -- '2024-06-01'
      GROUP BY ALL

  );

    --Tabla temporal sustituye a la vista `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_courier`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.desistimiento_courier`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT marca, orderCrmId, reexpedition, phone_nm, serial_number, courier, servicio, prioridad
    , RANK() OVER (PARTITION BY marca, orderCrmId ORDER BY prioridad ASC) AS rank_priority
  FROM (
    SELECT UPPER(de.marca) AS marca, de.orderCrmId, de.reexpedition, de.phone_nm, de.serial_number, de.courier, de.servicio
      , RANK() OVER (PARTITION BY marca, orderCrmId ORDER BY fecha DESC) AS rank
      , 1 AS prioridad
--    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` vde
    FROM `mm-commissions-reporting.TEMP.desistimiento_estado` de 
    WHERE courier IS NOT NULL
    QUALIFY rank = 1

    UNION ALL

    SELECT UPPER(dn.brAND_ds) AS marca
      , CAST(dn.item_number AS STRING) AS orderCrmId 
      , 'R0' AS reexpedition
      , CAST(dn.phone_nm AS STRING) AS phone_nm
      , dn.serial_number AS serial_number
      , dn.courier AS courier
      , 'NULL' AS servicio
      , RANK() OVER(PARTITION BY dn.brAND_ds, dn.item_number ORDER BY dn.order_date DESC) AS rank
      , 2 AS prioridad
    --FROM `mm-datamart-kd.SERVICES.devices_base_emysim` dn   --Habría que ver que pasa con los que no cruzan
    FROM `mm-datamart-kd.DEVICES.device_base_mysim` dn
    WHERE dn.courier IS NOT NULL
  )
  QUALIFY rank_priority = 1;

    --Tabla temporal con los estados de los desistimientos
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.desistimiento_tabla_estados`
   OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT SAFE_CAST(KAF.orderCrmId AS INT64) AS pedido, KAF.reexpedition AS reexpedicion, UPPER(KAF.marca) AS marca, KAF.fecha AS fecha, KAF.accion AS estado, CAST (NULL AS INT64) AS ticket
      , 'KAFKA' AS ORIGEN_ESTADO
      , CASE WHEN EXISTS (
          SELECT 1 FROM `mm-commissions-reporting.TEMP.desistimiento_subestado_orderbox` ORX1 WHERE CAST(ORX1.PEDIDOMM AS STRING) = KAF.orderCrmId AND UPPER(ORX1.MARCA) = UPPER(KAF.marca)
        ) THEN 'EXISTE_ORDERBOX' ELSE 'NO_EXISTE_ORDERBOX' END AS MAS_INFO
    FROM `mm-commissions-reporting.TEMP.desistimiento_estado` KAF
    WHERE SAFE_CAST(orderCrmId AS INT64) IS NOT NULL

    UNION ALL

    SELECT SAFE_CAST(ORX.PEDIDOMM AS INT64) AS pedido, CAST(NULL AS STRING) AS reexpedicion, UPPER(ORX.MARCA) AS marca, ORX.FECHAESTADO AS fecha, ORX.SUBESTADO AS estado, CAST(ORX.TICKET AS INT64) AS ticket
      , 'ORDERBOX' AS ORIGEN_ESTADO
      , CASE WHEN EXISTS (
          SELECT 1 FROM `mm-commissions-reporting.TEMP.desistimiento_estado` KAF1 WHERE CAST(ORX.PEDIDOMM AS STRING) = KAF1.orderCrmId AND UPPER(ORX.MARCA) = UPPER(KAF1.marca)
        ) THEN 'EXISTE_KAFKA' ELSE 'NO_EXISTE_KAFKA' END AS MAS_INFO
    FROM `mm-commissions-reporting.TEMP.desistimiento_subestado_orderbox` ORX
  ;


  --TABLA temporal de envíos de contratos para que el cliente firme y se le envíe la SMART TV
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.documentacion_contrato_firma`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT oml.itemnumber, oml.RX, oml.referenciatipoenvio, oml.tecnologia
    , CASE 
          WHEN oml.COURIER = 'HL' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%SMART TV%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%GOOGLE TV%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%XIAOMI TV%' THEN 'SMART_TV'
          WHEN UPPER(oml.descripcionenvio) LIKE '%SCOOTER%' THEN 'PATINETE'
          WHEN oml.referenciatipoenvio = 'SIM Card' THEN 'SIM'
          WHEN oml.referenciatipoenvio = 'Terminal' THEN 'TERMINAL'
          WHEN oml.referenciatipoenvio ='Tablet' THEN 'TABLET'
          WHEN oml.referenciatipoenvio IN ('Accesories','Accesories with Imei','Accesories with Serial Number') THEN 'ACCESORIO'
          WHEN oml.referenciatipoenvio IN ('Router ADSL','Router Fibra') THEN 'ROUTER'
          WHEN oml.referenciatipoenvio IN ('Modem') THEN 'ACCESORIO'
          WHEN oml.referenciatipoenvio IN ('TV Yoigo') THEN 'STB'
          WHEN oml.referenciatipoenvio = 'Papelería' THEN 'DOCUMENTACION'
          WHEN oml.referenciatipoenvio NOT IN ('Accesories','Accesories with Imei','Accesories with Serial Number','Modem','Papelería','Router ADSL','Router Fibra','SIM Card','TV Yoigo','Tablet','Terminal') THEN oml.referenciatipoenvio
          ELSE 'GENERIC' END AS dispositivo
    , oml.nserieenvio AS numero_serie
    , oml.OT, oml.referenciaenvio, oml.descripcionenvio
  --FROM `mm-commissions-reporting.TEMP.ORDERS_MASLOLA` oml
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` oml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE oml.referenciatipoenvio IN ('Papelería','Papeleria')
  GROUP BY ALL;


  --Tabla temporal de pedidos de MASLOLA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
 SELECT oml.ITEMNUMBER
    , COUNT(DISTINCT TECNOLOGIA) AS cuenta_tecnologia
    , COUNT(DISTINCT OT) AS cuenta_OT
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('SIM Card')) AS CUENTA_SIM
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('TV Yoigo')) AS CUENTA_STB
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND md.dispositivo IN ('PATINETE')) AS CUENTA_PATIN
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND md.dispositivo IN ('SMART_TV')) AS CUENTA_SMART_TV
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber 
         AND (TECNOLOGIA IN ('Accesories') or (UPPER(oml.descripcionenvio) LIKE '%CAJA DE VOZ%' OR UPPER(oml.descripcionenvio) LIKE '%MIFI%')))AS CUENTA_Accesories
    , (SELECT COUNT(1) 
       FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md 
       WHERE md.itemnumber = oml.itemnumber 
         AND (
          TECNOLOGIA IN ('Accesories with Imei') AND md.dispositivo NOT IN ('SMART_TV','PATINETE')
          OR TECNOLOGIA IN ('Accesories with Serial Number') AND md.dispositivo IN ('ACCESORIO')
        )
      ) AS CUENTA_ACC_IMEI
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber 
         AND TECNOLOGIA IN ('Accesories with Serial Number') AND md.dispositivo NOT IN ('SMART_TV','PATINETE','ACCESORIO')) AS CUENTA_ACC_SN
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Modem') 
         AND UPPER(oml.descripcionenvio) NOT LIKE '%CAJA DE VOZ%' AND UPPER(oml.descripcionenvio) NOT LIKE '%MIFI%') AS CUENTA_MODEM
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('ONT')) AS CUENTA_ONT
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.documentacion_contrato_firma` dcf WHERE dcf.itemnumber = oml.itemnumber AND dcf.TECNOLOGIA IN ('Papelería','Papeleria')) AS CUENTA_Papeleria
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Router ADSL','Router Fibra')) AS CUENTA_Router
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Tablet')) AS CUENTA_Tablet
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Terminal')) AS CUENTA_Terminal
    , (SELECT MAX(md.otros_equipos) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber) AS CUENTA_otros_equipos
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` oml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE oml.fechacreacion >= CAST(initial_date AS TIMESTAMP)  --'2024-04-01'
    AND oml.tipocliente = 'Canal Directo'
    AND UPPER(oml.operadorlogistico) = 'INTERBOX'
    AND oml.referenciatipoenvio NOT IN ('Papelería')
  GROUP BY ALL
  ORDER BY 1;

  --Tabla temporal de pedidos de MASLOLA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA_papeleria`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT oml.itemnumber
    , COUNT(DISTINCT TECNOLOGIA) AS cuenta_tecnologia
    , COUNT(DISTINCT OT) AS cuenta_OT
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('SIM Card')) AS CUENTA_SIM
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('TV Yoigo')) AS CUENTA_STB
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND md.dispositivo IN ('PATINETE')) AS CUENTA_PATIN
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND md.dispositivo IN ('SMART_TV')) AS CUENTA_SMART_TV
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber 
         AND (TECNOLOGIA IN ('Accesories') or (UPPER(oml.descripcionenvio) LIKE '%CAJA DE VOZ%' OR UPPER(oml.descripcionenvio) LIKE '%MIFI%')))AS CUENTA_Accesories
    , (SELECT COUNT(1) 
       FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md 
       WHERE md.itemnumber = oml.itemnumber 
         AND (
          TECNOLOGIA IN ('Accesories with Imei') AND md.dispositivo NOT IN ('SMART_TV','PATINETE')
          OR TECNOLOGIA IN ('Accesories with Serial Number') AND md.dispositivo IN ('ACCESORIO')
        )     
      ) AS CUENTA_ACC_IMEI
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber 
         AND TECNOLOGIA IN ('Accesories with Serial Number') AND md.dispositivo NOT IN ('SMART_TV','PATINETE','ACCESORIO')) AS CUENTA_ACC_SN
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Modem') 
         AND UPPER(oml.descripcionenvio) NOT LIKE '%CAJA DE VOZ%' AND UPPER(oml.descripcionenvio) NOT LIKE '%MIFI%') AS CUENTA_MODEM
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('ONT')) AS CUENTA_ONT
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.documentacion_contrato_firma` dcf WHERE dcf.itemnumber = oml.itemnumber AND dcf.TECNOLOGIA IN ('Papelería','Papeleria')) AS CUENTA_Papeleria
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Router ADSL','Router Fibra')) AS CUENTA_Router
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Tablet')) AS CUENTA_Tablet
    , (SELECT COUNT(1) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber AND TECNOLOGIA IN ('Terminal')) AS CUENTA_Terminal
    , (SELECT MAX(md.otros_equipos) FROM `mm-commissions-reporting.TEMP.maslola_dispositivo` md WHERE md.itemnumber = oml.itemnumber) AS CUENTA_otros_equipos
 
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` oml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE oml.fechacreacion >= CAST(initial_date AS TIMESTAMP)  --'2024-04-01'
    AND oml.tipocliente = 'Canal Directo'
    AND UPPER(oml.operadorlogistico) = 'INTERBOX'
    AND oml.referenciatipoenvio IN ('Papelería')
    AND oml.referenciaenvio IN ('ZYODOCTVB')
  GROUP BY ALL
  ORDER BY 1;

    --TABLA temporal de precios en INTERBOX
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.stock_Interbox`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS 
  SELECT Codigo, Descripcion, Precio_Compra, Precio_Almacen, Precio_mk_up, Organizacion, Familia, Subfamilia, Status, Fecha_alta, Fecha_update, Product_id
  FROM `mm-logistics-reporting.STOCK.log_maestro`
  QUALIFY ROW_NUMBER() OVER (PARTITION BY Codigo ORDER BY Fecha_update DESC, Fecha_alta DESC, Product_id DESC ) =  1 ;

    --TABLA temporal de SWAPS
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.swap_maslola`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS 
/*  SELECT operadorlogistico, tipopedidomysim, deliverytype, tipocliente, day, ot, pedidomm, itemnumber, estado, fechacreacion, fechadeentrega, fechaestado
    , referenciaenvio, referenciapadreenvio, referenciatipoenvio, descripcionenvio, nserieenvio, cantidadenvio
    , master, tfncontacto, provincia, codigopostal, rx
    , entregasegura, retornodac, fotodni, entregaexclusiva, courier, servicio
    , referenciarecogida, referenciapadrerecogida, referenciatiporecogida, descripcionrecogida, nserierecogida, cantidadrecogida, obscourier, hasclient, linea*/
  SELECT operadorlogistico, tipopedidomysim, tipocliente, day, ot, pedidomm, itemnumber, estado, fechacreacion, fechadeentrega, fechaestado
    , referencia, referenciapadre, referenciatipo, descripcion, nserie, cantidad
    , master, tfncontacto, provincia, codigopostal, rx
    , entregasegura, retornodac, fotodni, entregaexclusiva, courier, servicio
    --, referenciarecogida, referenciapadrerecogida, referenciatiporecogida, descripcionrecogida, nserierecogida, cantidadrecogida
    , obscourier, hasclient, linea
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` nom
  WHERE tipopedidomysim = 'SWAP'
    AND day >= initial_date
  QUALIFY RANK () OVER (
    PARTITION BY operadorlogistico, tipopedidomysim, tipocliente, ot, pedidomm, itemnumber
    ORDER BY fechaestado DESC, estado DESC
    ) = 1;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_shipped_desistimiento`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT marca, orderCrmId, reexpedition, weight, courier, service, expeditionId, identifier AS serial_number, businessProcess, rank, expeditionIdExternal
  FROM (
    SELECT CASE WHEN (transport.courier = 'CORREOS' AND subscriptionId IS NULL) THEN 'DOCUMENTACION' ELSE 'PEDIDO' END AS documentacion  --Intentamos identificar la documentación de las Smart-TV. Si faltan pedidos, esta podría ser la causa.
--      , CAST(subscriptions.orderCrmId AS INTEGER) AS orderCrmId
      , subscriptions.orderCrmId AS orderCrmId
      , reexpedition, transport.deliveryDetails.package.weight, transport.courier, transport.service
      , kf.expeditionId  --2024/11/27
      , kf.expeditionIdExternal  --valor pedido eurologistica (2025/09)
      , kf.businessProcess       --añado si es pedido o desistimiento (2025/09)
      , devices.identifier
      , UPPER(tenantByTopic) AS marca
      , RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition, expeditionId ORDER BY transport.deliveryDetails.package.weight DESC) AS rank  --Ordeno para quedarme con el peso mayor, eliminANDo el duplicado por la SIM, pero incluyo reexpediciones y fechas para asegurar que incluya todas las expediciones
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_SHIPPED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
    WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
      AND UPPER(businessProcess) = 'DESISTIMIENTO'
--      AND UPPER(subscriptions.orderCrmId) NOT LIKE '%M%'
    QUALIFY rank = 1   --Me quedo con el peso mayor, eliminANDo la SIM cuANDo tiene dispositivo
    )
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_status_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT UPPER(tenantByTopic) AS marca
      , subscriptions.orderCrmId AS orderCrmId
      , reexpedition
      , logisticsOperator
      , businessProcess
      , logisticOperation
      , deliveryType
      , expeditionIdExternal
      , expeditionId
      , stateDatetime
      , status.value AS status
      , status.description AS description
      , subscriptions.orderId as serial
      , devices.identifier as serial_number
      , subscriptions.orderIdExternal
      , devices.reference
      , devices.type
      , subscriptions.subscriptionId
--      , RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition, expeditionId ORDER BY stateDatetime DESC) AS rank 
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_STATUS_UPDATED_V*`, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
    WHERE logisticOperation = 'SWAP'
      AND UPPER(businessProcess) = 'SWAP'
      AND TIMESTAMP_TRUNC(loadDate, DAY) >= CAST(initial_date AS TIMESTAMP)  -- TIMESTAMP("2025-12-01")   
      AND expeditionIdExternal IS NOT NULL
    QUALIFY RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition, expeditionId ORDER BY stateDatetime DESC, status) = 1;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.vbtn_clientes`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT comm_brand_ds, customer_id, account_id, service_id, phone_nm, order_date, customer_document_type, customer_document, contract_id
  FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
  QUALIFY RANK () OVER (PARTITION BY comm_brand_ds, customer_id, account_id, service_id, phone_nm ORDER BY order_date DESC) = 1  ;

--Nombre del cliente
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_nombre`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT documento, nombre_completo
  FROM (
   SELECT UPPER(tenantByTopic) AS marca
        , subscriptions.orderCrmId AS id_orden
        , reexpedition AS reexpedition
        , businessProcess AS tipo_pedido
        , customer.user.identityDocument.number AS documento
        , expeditionId AS expeditionId  --2024/11/27
        , customer.user.name AS nombre_cliente
        , REPLACE(ARRAY_TO_STRING(customer.user.surnames,' '),'/',' ') AS apellido_cliente
        , CONCAT(CONCAT(customer.user.name,' '),REPLACE(ARRAY_TO_STRING(customer.user.surnames,' '),'/',' ')) AS nombre_completo
        , businessProcess
        , CAST(createdDatetime AS DATETIME) AS createdDatetime  --2024/11/27
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions--, UNNEST(shipping.address.addressLines) AS addressLines
    WHERE logisticsOperator = 'INTERBOX'
--      AND businessProcess IN ('PEDIDO','DESISTIMIENTO')
    QUALIFY RANK () OVER (PARTITION BY tenantByTopic, subscriptions.orderCrmId, reexpedition ORDER BY createdDatetime DESC) = 1
  )
  QUALIFY ROW_NUMBER() OVER (PARTITION BY documento ORDER BY createdDatetime DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.valor_unitario_logistico`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT *
  FROM(
    SELECT codigo_contrato, posicion_cm, texto_sap, importe AS valor, tipo_pedido
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES_CONFIG
    WHERE fecha_hasta = '9999-12-31'
      AND importe IS NOT NULL
      AND codigo_contrato IS NOT NULL
    GROUP BY ALL

    UNION ALL

    SELECT codigo_contrato, posicion_cm, texto_sap, porcentaje AS valor, tipo_pedido
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES_CONFIG
    WHERE fecha_hasta = '9999-12-31'
      AND importe IS NULL
      AND porcentaje IS NOT NULL
      AND codigo_contrato IS NOT NULL
    GROUP BY ALL
  )
  QUALIFY RANK() OVER (PARTITION BY codigo_contrato ORDER BY valor DESC) = 1
  ORDER BY 1,2,3,4;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_lineas_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT nnom.itemnumber, CAST(SPLIT(CAST(nnom.itemnumber AS STRING), '_')[OFFSET(0)] AS STRING) AS id_orden, MAX(nnom.linea) AS LINEA
    FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` nnom
    WHERE nnom.operadorlogistico = 'INTERBOX'
      AND nnom.tipopedidomysim = 'SWAP'
      AND nnom.tipocliente = 'CANAL DIRECTO'
      AND nnom.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_shipped_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT UPPER(tenantByTopic) AS marca
      , subscriptions.orderCrmId AS orderCrmId
      , reexpedition
      , transport.deliveryDetails.package.weight
      , transport.courier
      , transport.service
      , kf.expeditionId  --2024/11/27
      , devices.identifier
      , kf.businessProcess       --añado si es pedido o desistimiento (2025/09)
      , kf.expeditionIdExternal  --valor pedido eurologistica (2025/09) 
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_SHIPPED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
    WHERE businessProcess IN ('SWAP','DOA')
      AND TIMESTAMP_TRUNC(loadDate, DAY) >= TIMESTAMP(initial_date) -- '2024-05-01'  
    QUALIFY RANK() OVER (PARTITION BY subscriptions.orderCrmId, reexpedition ORDER BY shippedDatetime DESC, transport.deliveryDetails.package.weight DESC) = 1; 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_canal_directo_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT nnom.ITEMNUMBER, CAST(SPLIT(CAST(nnom.ITEMNUMBER AS STRING), '_')[OFFSET(0)] AS STRING) AS id_orden
         , CASE WHEN nnom.rx IS NULL THEN 'R0' ELSE nnom.rx END AS rx
         , nnom.entregaexclusiva, nnom.entregasegura, nnom.fotodni, nnom.estado, nnom.fechaestado, nnom.solicituddecancelacion, nnom.retornodac, nnom.obscourier, nnom.canalventa
         --, nnom.nserie, nnom.referencia, nnom.descripcion, nnom.referenciapadre
         , nnom.nserieenvio, nnom.nserierecogida, nnom.referenciaenvio, nnom.referenciarecogida, descripcionenvio, descripcionrecogida, referenciapadreenvio, referenciapadrerecogida

    FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` nnom
    WHERE UPPER(nnom.operadorlogistico) = 'INTERBOX'
      AND UPPER(nnom.tipocliente) = 'CANAL DIRECTO'
      AND UPPER(nnom.tipopedidomysim) = 'SWAP'
      AND nnom.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
    QUALIFY RANK() OVER (PARTITION BY nnom.ITEMNUMBER, nnom.RX ORDER BY FECHAESTADO DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_direccion_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT * 
  FROM (
    SELECT UPPER(tenantByTopic) AS marca

        , subscriptions.orderIdExternal AS id_orden
        , CASE WHEN reexpedition IS NULL THEN 'R0' ELSE reexpedition END AS reexpedition
        , UPPER(kf.logisticOperation) AS tipo_pedido
        , customer.user.identityDocument.number AS documento
        , addressLines.addressLineValue AS direccion
        , expeditionId AS expeditionId
        , CAST(createdDatetime AS DATETIME) AS createdDatetime
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(shipping.address.addressLines) AS addressLines
    WHERE UPPER(kf.logisticsOperator) = 'INTERBOX'
      AND UPPER(kf.logisticOperation) = 'SWAP'
      AND addressLines.addressLineName = 'Street'
    QUALIFY RANK () OVER (PARTITION BY tenantByTopic, subscriptions.orderIdExternal, subscriptions.orderCrmId, reexpedition ORDER BY createdDatetime DESC) = 1
  )
  QUALIFY ROW_NUMBER() OVER (PARTITION BY marca, id_orden, reexpedition ORDER BY createdDatetime DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_codigo_postal_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    
  SELECT *
  FROM(
    SELECT UPPER(tenantByTopic) AS marca
      , subscriptions.orderIdExternal AS id_orden
      , CASE WHEN reexpedition IS NULL THEN 'R0' ELSE reexpedition END AS reexpedition  
      , UPPER(kf.logisticOperation) AS tipo_pedido
      , addressLines.addressLineValue AS codigo_postal  --ALGUNOS PEDIDOS TIENEN 2 DIFERENTES, TENEMOS QUE QUEDARNOS CON UNO (EJEMPLO 16905951)
      , customer.user.identityDocument.number AS documento
      , expeditionId AS expeditionId
      , CAST(createdDatetime AS DATETIME) AS createdDatetime
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(shipping.address.addressLines) AS addressLines
    WHERE UPPER(logisticsOperator) = 'INTERBOX'
      AND UPPER(kf.logisticOperation) = 'SWAP'
      AND addressLines.addressLineName = 'ZipCode'
      AND addressLines.addressLineValue IS NOT NULL
      AND subscriptions.orderCrmId  IS NOT NULL
    QUALIFY RANK() OVER (PARTITION BY tenantByTopic, subscriptions.orderIdExternal, subscriptions.orderCrmId, reexpedition ORDER BY createdDatetime DESC) = 1
  ) QUALIFY ROW_NUMBER() OVER (PARTITION BY marca, id_orden, reexpedition, expeditionId ORDER BY createdDatetime DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_provincia_swap`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  SELECT *
  FROM(
    SELECT UPPER(tenantByTopic) AS marca
      , subscriptions.orderIdExternal AS id_orden
      , CASE WHEN reexpedition IS NULL THEN 'R0' ELSE reexpedition END AS reexpedition  
      , UPPER(kf.logisticOperation) AS tipo_pedido
      , CASE WHEN UPPER(addressLines.addressLineValue) = 'CORUÑA, A' THEN 'A CORUÑA'
             WHEN UPPER(addressLines.addressLineValue) = 'CORU&NTILDE;A' THEN 'A CORUÑA'
             WHEN UPPER(addressLines.addressLineValue) = 'CORUNA' THEN 'A CORUÑA'
             WHEN UPPER(addressLines.addressLineValue) = 'CORUA‘A, A' THEN 'A CORUÑA'
             WHEN UPPER(addressLines.addressLineValue) = 'LA CORU&NTILDE;A' THEN 'A CORUÑA'
             WHEN UPPER(addressLines.addressLineValue) = 'ALAVA' THEN 'ARABA/ÁLAVA'
             WHEN UPPER(addressLines.addressLineValue) = 'ARABA/ALAVA' THEN 'ARABA/ÁLAVA'
             WHEN UPPER(addressLines.addressLineValue) = 'AAAAVILA' THEN 'ÁVILA'
             WHEN UPPER(addressLines.addressLineValue) = 'AVILA' THEN 'ÁVILA'
             WHEN UPPER(addressLines.addressLineValue) = 'ALICANTE' THEN 'ALICANTE/ALACANT'
             WHEN UPPER(addressLines.addressLineValue) = 'ALACANT' THEN 'ALICANTE/ALACANT'
             WHEN UPPER(addressLines.addressLineValue) = 'ALMER&IACUTE;A' THEN 'ALMERÍA'
             WHEN UPPER(addressLines.addressLineValue) = 'ALMERAA' THEN 'ALMERÍA'
             WHEN UPPER(addressLines.addressLineValue) = 'ALMERIA' THEN 'ALMERÍA'
             WHEN UPPER(addressLines.addressLineValue) = 'BALEARES' THEN 'ILLES BALEARS'
             WHEN UPPER(addressLines.addressLineValue) = 'ISLAS BALEARES' THEN 'ILLES BALEARS'
             WHEN UPPER(addressLines.addressLineValue) = 'C&AACUTE;CERES' THEN 'CÁCERES'
             WHEN UPPER(addressLines.addressLineValue) = 'CACERES' THEN 'CÁCERES'
             WHEN UPPER(addressLines.addressLineValue) = 'C&AACUTE;DIZ' THEN 'CÁDIZ'
             WHEN UPPER(addressLines.addressLineValue) = 'CADIZ' THEN 'CÁDIZ'
             WHEN UPPER(addressLines.addressLineValue) = 'CADIZ' THEN 'CÁDIZ'
             WHEN UPPER(addressLines.addressLineValue) = 'C&OACUTE;RDOBA' THEN 'CÓRDOBA'
             WHEN UPPER(addressLines.addressLineValue) = 'CORDOBA' THEN 'CÓRDOBA'
             WHEN UPPER(addressLines.addressLineValue) = 'CASTELL&AMP;AMP;OACUTE;N' THEN 'CASTELLÓN/CASTELLÓ'
             WHEN UPPER(addressLines.addressLineValue) = 'CASTELL&AMP;OACUTE;N' THEN 'CASTELLÓN/CASTELLÓ'
             WHEN UPPER(addressLines.addressLineValue) = 'CASTELL&OACUTE;N' THEN 'CASTELLÓN/CASTELLÓ'
             WHEN UPPER(addressLines.addressLineValue) = 'CASTELLON' THEN 'CASTELLÓN/CASTELLÓ'
             WHEN UPPER(addressLines.addressLineValue) = 'CASTELLÓN' THEN 'CASTELLÓN/CASTELLÓ'
             WHEN UPPER(addressLines.addressLineValue) = 'GERONA' THEN 'GIRONA'
             WHEN UPPER(addressLines.addressLineValue) = 'GUIPUZCOA' THEN 'GIPUZKOA'
             WHEN UPPER(addressLines.addressLineValue) = 'JAEN' THEN 'JAÉN'
             WHEN UPPER(addressLines.addressLineValue) = 'LA‰RIDA' THEN 'LLEIDA'
             WHEN UPPER(addressLines.addressLineValue) = 'LÉRIDA' THEN 'LLEIDA'
             WHEN UPPER(addressLines.addressLineValue) = 'LERIDA' THEN 'LLEIDA'
             WHEN UPPER(addressLines.addressLineValue) = 'LE&AMP;OACUTE;N' THEN 'LEÓN'
             WHEN UPPER(addressLines.addressLineValue) = 'LE&OACUTE;N' THEN 'LEÓN'
             WHEN UPPER(addressLines.addressLineValue) = 'LEA“N' THEN 'LEÓN'
             WHEN UPPER(addressLines.addressLineValue) = 'LEON' THEN 'LEÓN'
             WHEN UPPER(addressLines.addressLineValue) = 'M&AACUTE;LAGA' THEN 'MÁLAGA'
             WHEN UPPER(addressLines.addressLineValue) = 'M&AMP;AACUTE;LAGA' THEN 'MÁLAGA'
             WHEN UPPER(addressLines.addressLineValue) = 'MÃÂÃÂLAGA' THEN 'MÁLAGA'
             WHEN UPPER(addressLines.addressLineValue) = 'MALAGA' THEN 'MÁLAGA'
             WHEN UPPER(addressLines.addressLineValue) = 'MALAGA' THEN 'MÁLAGA'
             WHEN UPPER(addressLines.addressLineValue) = 'S. C. DE TENERIFE' THEN 'S.C. TENERIFE'
             WHEN UPPER(addressLines.addressLineValue) = 'TENERIFE' THEN 'S.C. TENERIFE'
             WHEN UPPER(addressLines.addressLineValue) = 'VIZCAYA' THEN 'BIZKAIA'
             WHEN UPPER(addressLines.addressLineValue) = 'VALENCIA' THEN 'VALENCIA/VALÈNCIA'
        ELSE UPPER(addressLines.addressLineValue) END AS provincia
      , customer.user.identityDocument.number AS documento
      , expeditionId AS expeditionId
      , CAST(createdDatetime AS DATETIME) AS createdDatetime
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` kf, UNNEST(subscriptions) subscriptions, UNNEST(shipping.address.addressLines) AS addressLines
    WHERE UPPER(kf.logisticsOperator) = 'INTERBOX'
      AND UPPER(kf.logisticOperation) = 'SWAP'
      AND addressLines.addressLineName = 'Province'
    QUALIFY RANK() OVER (PARTITION BY tenantByTopic, subscriptions.orderIdExternal, subscriptions.orderCrmId, reexpedition ORDER BY createdDatetime DESC) = 1
  ) QUALIFY ROW_NUMBER() OVER (PARTITION BY marca, id_orden, reexpedition, expeditionId ORDER BY createdDatetime DESC) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contenido_Swap_MASLOLA`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT nnom.itemnumber
    , CASE WHEN referenciatipo IN ('TV Yoigo')       THEN 'STB'
           WHEN referenciatipo IN ('Terminal')       THEN 'TERMINAL'
           WHEN referenciatipo IN ('Tablet')         THEN 'TABLET'
           WHEN referenciatipo IN ('Modem')          THEN 'MODEM'
           WHEN referenciatipo IN ('Router Fibra')   THEN 'ROUTER'
           WHEN referenciatipo IN ('Accesories with Imei') AND UPPER(descripcion) LIKE '%TV%'             THEN 'SMART TV'
           WHEN referenciatipo IN ('Accesories with Imei') AND UPPER(descripcion) LIKE '%WATCH%'          THEN 'ACCESORIO'
           WHEN referenciatipo IN ('Accesories with Imei') AND UPPER(descripcion) LIKE '%BAND%'           THEN 'ACCESORIO'
           WHEN referenciatipo IN ('Accesories with Imei')                                                THEN 'ACCESORIO'
           WHEN referenciatipo IN ('Accesories with Serial Number') AND UPPER(descripcion) LIKE '%TV%'    THEN 'SMART TV'
           WHEN referenciatipo IN ('Accesories with Serial Number') AND UPPER(descripcion) LIKE '%WATCH%' THEN 'ACCESORIO'
           WHEN referenciatipo IN ('Accesories with Serial Number') AND UPPER(descripcion) LIKE '%BAND%'  THEN 'ACCESORIO'
           WHEN referenciatipo IN ('Accesories with Serial Number')                                       THEN 'ACCESORIO'
           ELSE referenciatipo END AS tipo_dispositivo
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` nnom
  WHERE tipopedidomysim = 'SWAP'
      AND nnom.fechacreacion >= CAST(initial_date AS TIMESTAMP)  --'2024-04-01'
  QUALIFY RANK() OVER (PARTITION BY itemnumber, referenciatipo, descripcion ORDER BY fechaestado DESC) = 1;


    --Buscamos los segundos intentos de entrega de Smart TV en maslola
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_segundos_intentos_STV`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT itemnumber
      , CASE WHEN rx IS NULL THEN 'R0' ELSE rx END AS rx
      , estado, nserie, COUNT(1) AS intentos
    FROM `mm-datamart-kd.LOGISTICS.netkia_orders_lola` mm
    WHERE CAST(itemnumber AS STRING) IN ( SELECT DISTINCT ORDENES.id_orden AS id_orden
                          FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
                          WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
                            AND (UPPER(ORDENES.courier) IN ('HL','INSIDE') OR ORDENES.courier IS NULL)
                            AND UPPER(ORDENES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') 
                        )

      AND estado = 'En reparto'
    GROUP BY ALL
    HAVING intentos > 1;



  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maslola_lineas_item`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

  --Sacamos el nº de línea de cada pedido
  SELECT COALESCE(ml.itemnumber,ml.pedidomm) AS ITEMNUMBER, MAX(ml.linea) AS LINEA
  FROM `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
  WHERE ml.operadorlogistico = 'Interbox'
    AND ml.tipocliente = 'Canal Directo'
    AND ml.fechacreacion >= CAST(initial_date AS TIMESTAMP) -- '2024-03-01'
  GROUP BY ALL;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.kafka_shipped_pedidos`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT businessProcess, orderCrmId, reexpedition, expeditionIdExternal, expeditionId, shippedDatetime, transport.courier, transport.deliveryDetails.package.weight
    , CASE WHEN transport.courier = 'CORREOS' AND transport.deliveryDetails.package.weight = 0.08 THEN 'DOCUMENTACION SMART TV'
            WHEN transport.courier IN ('HL','INSIDE') THEN 'SMART TV'
            ELSE 'PEDIDO' END AS Tipoproducto
    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_SHIPPED*` kf, UNNEST(subscriptions) subscriptions--, UNNEST(devices) devices
    WHERE expeditionIdExternal IS NOT NULL
    AND shippedDatetime >= CAST (initial_date AS TIMESTAMP)  --'2026-01-01'
    QUALIFY ROW_NUMBER () OVER (PARTITION BY businessProcess, orderCrmId, reexpedition, expeditionIdExternal ORDER BY shippedDatetime DESC) = 1;


END