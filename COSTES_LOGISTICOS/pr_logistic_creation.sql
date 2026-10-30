BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_creation`('2025-09-01')

    --TABLA de órdenes de Entrega
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` AS
  (
--    SELECT * 
--    FROM(
        SELECT UPPER(tenantByTopic) AS marca
    --        , ml.MASTER AS id_master, btn.channel_ds AS Master
            , SAFE_CAST(subscriptions.orderCrmId AS STRING) AS id_orden
            , ke.reexpedition AS reexpedition
            , li.LINEA AS numero_lineas
            , CASE WHEN logisticOperation = 'DELIVERY' THEN 'Entrega'
                    WHEN logisticOperation = 'PICKUP' THEN 'Desistimiento'
                    WHEN logisticOperation = 'SWAP' THEN 'Swap'
              ELSE logisticOperation END AS tipo_pedido
            , CASE WHEN ks.courier = 'HL' THEN 'domicilio'
                  WHEN shipping.deliveryType = 'HOME' THEN 'domicilio'
                  WHEN shipping.deliveryType = 'SHOP' THEN 'tienda'
                  WHEN shipping.deliveryType = 'AGENCY' AND ks.courier = 'CORREOS' THEN 'correos'
              ELSE 'domicilio' END AS tipo_orden
            , 'entrega' AS motivo 
            --, ks.expeditionIdExternal AS numero_expedicion --id de Eurologistica  
            , COALESCE(ks.expeditionIdExternal,ks.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'_Entrega')) AS numero_expedicion --id de Eurologistica  
            , CASE WHEN shipping.address.type = 'SHIPMENT' THEN 'B2C' ELSE shipping.address.type END AS tipo_destinatario
            , logisticsOperator AS operador_logistico
            , ks.courier AS courier
            , ks.service AS servicio
            , CASE WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ entrega segura + FOTODNI)'
                    WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'Exclusiva (+ entrega segura)'
                    WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ FOTODNI)'
                    WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN 'Exclusiva'
                    WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'DNI (entrega segura + FOTODNI)'
                    WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'DNI (entrega segura)'
                    WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'FOTODNI'
                    WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN CAST(NULL AS STRING)
                ELSE 'DESCONOCIDO - REVISAR' END AS identificacion
            , CASE  WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Cancelado-Devuelto al Almacén')  AND cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1 THEN 'Destruido (SIM)' 
                    WHEN ml.ESTADO IN ('Destruído por transportista') THEN 'Destruido (SIM)'         --Modificamos el valor original, sin mas cambio
                    WHEN ml.ESTADO IN ('Documentación enviada') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
                    WHEN ml.ESTADO IN ('Desastre en la entrega en el WH') THEN 'Entregado (Documentacion KO)'  --Modificamos el valor original, sin mas cambio
                    WHEN ml.ESTADO IN ('Entregado a custodiador','Entregado en WH') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
                    WHEN ml.ESTADO IN ('Entregado en punto de entrega','En delegacion destino') THEN 'Entregado'  --Modificamos el valor original, sin mas cambio
                    WHEN ml.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking' 	  
                    WHEN ml.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking'
                    --WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
                    WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Devuelto al almacen'
                    WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
                    WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
                    ELSE ml.ESTADO END AS estado_final
            , ml.FECHAESTADO AS fecha_estado_final
            , CASE WHEN ml.SOLICITUDDECANCELACION IS NULL THEN 'NO' ELSE 'SI' END AS cancelacion_solicitada
            , btn.customer_id AS id_cliente
            , subscriptions.subscriptionId AS id_suscripcion
            , ml.RETORNODAC AS retorno_contrato
            , prov.provincia AS provincia
            , cp.codigo_postal AS codigo_postal
            , ml.OBSCOURIER AS textos
            --, subscriptions.externalId.number AS telefono_contacto
            , COALESCE(subscriptions.externalId.number,customer.user.contactData.phoneNumber.number) AS telefono_contacto
            , MAX(TIMESTAMP_TRUNC(ke.createdDatetime, SECOND)) AS fecha_comunicacion
            , ml.FECHAESTADO AS fecha_ultima_actualizacion
            , customer.user.identityDocument.type AS tipo_documento
            , customer.user.identityDocument.number AS documento
            , btn.segment_ds tipo_cliente
            , CASE WHEN cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1                                                    THEN 'SIM'
                  WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) = 'MANIPULADO'               THEN 'Equipo manipulado + SIM'
                  WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PATINES')               THEN 'PATINETE'
                  WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1 AND CUENTA_Papeleria = 1   THEN 'SMART TV+DOCUMENTACION'
                  WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 1   THEN 'SMART TV+DOCUMENTACION'
                  WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 0   THEN 'SMART TV'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_PATIN >= 1                               THEN 'PATINETE'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1                            THEN 'SMART TV'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1                           THEN 'SIM+SMART TV'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria > 0  THEN 'SIM+SMART TV+DOCUMENTACION'
                  --WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PAE')                  THEN 'PAE'
                  WHEN ks.weight > 2 AND ks.weight <= 7                                                                   THEN 'PAE'
                  WHEN ks.weight > 7 AND ks.weight <= 18                                                                  THEN 'MAE'
                  WHEN ks.weight > 18                                                                                     THEN 'GAE'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Terminal >= 1                            THEN 'TERMINAL'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Tablet >= 1                              THEN 'TABLET'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Router >= 1                              THEN 'ROUTER'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_MODEM >= 1                               THEN 'MODEM'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_STB >= 1                                 THEN 'STB'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Accesories >= 1                          THEN 'ACCESORIO'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1                            THEN 'ACCESORIO'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_SN >= 1                              THEN 'PAE'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Papeleria >= 1                           THEN 'PAPELERIA'
                  WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ONT >= 1                                 THEN 'ONT'     
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Terminal > 0                            THEN 'SIM+TERMINAL'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Tablet > 0                              THEN 'SIM+TABLET'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Router > 0                              THEN 'SIM+ROUTER'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_MODEM > 0                               THEN 'SIM+MODEM'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_STB > 0                                 THEN 'SIM+STB'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Accesories > 0                          THEN 'SIM+ACCESORIO'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_IMEI > 0                            THEN 'SIM+ACCESORIO'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_SN > 0                              THEN 'SIM+ACCESORIO'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Papeleria > 0                           THEN 'SIM+PAPELERIA'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ONT > 0                                 THEN 'SIM+ONT'
                  WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  = 0                                                     THEN 'DISPOSITIVOS'
                  WHEN cpm.cuenta_tecnologia IS NULL                                                                      THEN 'SIN DATOS EN ORDERBOX'
              ELSE 'REVISAR' END AS dispositivo
            , CASE WHEN billing_type_ds = 'PREPAID' THEN 'PREPAGO'
                    WHEN billing_type_ds = 'POSTPAID' THEN 'POSTPAGO'
              ELSE billing_type_ds END AS categoria_contrato
            , kp.impresos AS total_impresos
            , kp.preimpresos AS total_preimpresos
            , CAST(NULL AS INTEGER) AS total_color
            , cpm.cuenta_tecnologia AS total_bultos
            , CAST(0 AS FLOAT64) AS importe_pedido
            , 'NO' AS contrarrembolso
            , CAST (NULL AS INTEGER) AS importe_contrarrembolso
            , ROUND(ks.weight,3) AS total_peso  --HACER
            , COALESCE(btn.master_channel_ds,UPPER(ml.CANALVENTA)) AS canal
            , btn.user_store AS SFID_ID
            , btn.sub_segment_ds AS segmento
            , btn.contract_id AS contrato
            , CASE  WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Cancelado-Devuelto al Almacén')  AND cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1 THEN 'Destruido (SIM)' 
                    WHEN er.ESTADO IN ('Destruído por transportista') THEN 'Destruido (SIM)'         --Modificamos el valor original, sin mas cambio
                    WHEN er.ESTADO IN ('Documentación enviada') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
                    WHEN er.ESTADO IN ('Desastre en la entrega en el WH') THEN 'Entregado (Documentacion KO)'  --Falla la entrega de la documentacion    --Modificamos el valor original, sin mas cambio
                    WHEN er.ESTADO IN ('Entregado a custodiador','Entregado en WH') THEN 'Entregado (Documentacion OK)'  --Entrega de la documentacion   --Modificamos el valor original, sin mas cambio
                    WHEN er.ESTADO IN ('Entregado en punto de entrega','En delegacion destino') THEN 'Entregado'  --Modificamos el valor original, sin mas cambio
                    WHEN ml.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking' 	  
                    WHEN ml.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking'
                    --WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
                    WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Devuelto al almacen'
                    WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
                    WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
                    ELSE ml.ESTADO END AS estado_reexpedicion
/*
                    WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking' 
                    WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking' 
                    WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
                    ELSE er.ESTADO END AS estado_reexpedicion
*/
              --, SAFE_CAST(ml.PEDIDOMM AS INT64) AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
              --, ml.PEDIDOMM AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
              , COALESCE(ml.PEDIDOMM,ml.OT,ml.ITEMNUMBER) AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
              , dir.direccion AS direccion 

        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` ke, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_direccion` dir
            ON  UPPER(dir.marca) = UPPER(ke.tenantByTopic)
            AND dir.id_orden = subscriptions.orderCrmId
            AND dir.reexpedition = ke.reexpedition
--            AND dir.tipo_pedido = 'PEDIDO'
            AND dir.expeditionId = ke.expeditionId  --2024/11/24
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_codigo_postal` cp
            ON  UPPER(cp.marca) = UPPER(ke.tenantByTopic)
            AND cp.id_orden = subscriptions.orderCrmId
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_provincia` prov
            ON  UPPER(prov.marca) = UPPER(ke.tenantByTopic)
            AND prov.id_orden = subscriptions.orderCrmId
          LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
            ON  btn.phone_nm = CAST(subscriptions.externalId.number AS INTEGER)
            AND UPPER(btn.data_source_ds) = 'MYSIM'
            AND UPPER(btn.brand_ds) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
            --AND btn.order_date = CAST(TIMESTAMP_TRUNC(createdDatetime, DAY) AS DATE)  --ALGUNOS NO TIENEN ORDEN Y NO TIENEN FECHA, SI QUITO EL FILTRO, ME PUEDE TRAEAR INFORMACION ANTIGUA --REVISAR
            AND btn.service_id = subscriptions.subscriptionId  --Otra opción de filtro
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped` ks
            ON  ks.orderCrmId = subscriptions.orderCrmId
            AND CAST(ks.expeditionId AS STRING) = CAST(ke.expeditionId AS STRING)
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation` kp
            ON  kp.orderCrmId = subscriptions.orderCrmId
            AND kp.reexpedition = ke.reexpedition
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo` ml
            ON  ml.ITEMNUMBER = subscriptions.orderCrmId
            AND ml.RX = ke.reexpedition
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_lineas` li
            ON  CAST(li.PEDIDOMM AS STRING) = subscriptions.orderCrmId --= ml.PEDIDOMM
            --Tomamos como picking el evento 'Inicio extracción'
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_inicio_picking` ip
            ON  ip.ITEMNUMBER = subscriptions.orderCrmId
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_salida_almacen` sa
            ON  sa.ITEMNUMBER = subscriptions.orderCrmId
            --BUSCAMOS EL TIPO DE DISPOSITIVO
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_dispositivo` md
            ON  md.ITEMNUMBER = subscriptions.orderCrmId

          -- LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
          --   ON  gef.estado = ml.ESTADO
          --   AND gef.tipo_pedido = 'Entrega'

          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_estado_reexp` er
            ON  er.ITEMNUMBER = subscriptions.orderCrmId
            AND er.reexpedition = ke.reexpedition
          LEFT JOIN `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA` cpm
            ON cpm.ITEMNUMBER = subscriptions.orderCrmId

        WHERE UPPER(tenantByTopic) IN ('YOIGO','MASMOVIL','PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA')-- ('YOIGO','MASMOVIL')
          AND UPPER(ke.logisticsOperator) = 'INTERBOX'
--          AND UPPER(ke.businessProcess) = 'PEDIDO'
          AND UPPER(logisticOperation) = 'DELIVERY'
            --Si no tienen estado, no podemos facturarlo
          AND ml.ESTADO IS NOT NULL
            --Eliminamos los envíos de la documentación de las SMART-TVs
          AND md.referenciatipoenvio NOT IN ('Papelería')
--          AND devices.subscriptionDeviceId NOT LIKE '%-%'  --2025-11-12 Eliminamos esta restricción porque perdemos pedidos según https://jiranext.masorange.es/browse/DDEV-30867
            --Elimina duplicados pero podemos perder algunos pedidos, por ejemplo 16438416
          AND subscriptions.subscriptionId IS NOT NULL  --lo eliminamos porque perdemos pedidos 2024/11/19

            --Solo nos quedamos con estados finales --DEJAMOS TODOS LOS ESTADOS, NO SOLO LOS FINALES
          --AND gef.final = 'SI'
            --FILTRO DE FECHA--

          AND TIMESTAMP_TRUNC(loadDate, DAY) >= CAST (initial_date AS TIMESTAMP) --TIMESTAMP(initial_date)  --('2024-05-01')

        GROUP BY ALL
  /*CUIDADO CON ESTE CAMBIO 31/03/2026 */
--    )
--    WHERE (estado_final NOT IN ('Cancelación solicitada','Cancelación solicitada por el cliente - recogida solicitada','Cancelado prepicking','Cancelado postpicking') AND numero_expedicion IS NOT NULL AND direccion IS NOT NULL)
--      OR (estado_final IN ('Cancelación solicitada','Cancelación solicitada por el cliente - recogida solicitada','Cancelado prepicking','Cancelado postpicking') AND numero_expedicion IS NOT NULL AND direccion IS NOT NULL AND tipo_orden IS NOT NULL)
  );
   
   -- UNION ALL --GJV 2024-11-19 

     --2026/05/06 Cambio UNION ALL por un INSERT posterior
     --Incluimos pedidos que se hayan preparado completamente en el almacén pero se haya perdido la notificación kafka de Expedition_Created (es un error conocido recurrente pero poco habitual)
  INSERT INTO `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` (
    SELECT UPPER(tenantByTopic) AS marca
--    , ml.MASTER AS id_master, btn.channel_ds AS Master
    , SAFE_CAST(subscriptions.orderCrmId AS STRING) AS id_orden
    , ke.reexpedition AS reexpedition
    , li.LINEA AS numero_lineas
    , CASE WHEN logisticOperation = 'DELIVERY' THEN 'Entrega'
            WHEN logisticOperation = 'PICKUP' THEN 'Desistimiento'
            WHEN logisticOperation = 'SWAP' THEN 'Swap'
      ELSE logisticOperation END AS tipo_pedido
    , CAST (NULL AS STRING) AS tipo_orden
    , 'entrega' AS motivo 
    --, ks.expeditionIdExternal AS numero_expedicion --id de Eurologistica  
    , COALESCE(ks.expeditionIdExternal,ks.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'_Entrega')) AS numero_expedicion --id de Eurologistica  
    , 'B2C' AS tipo_destinatario
    , logisticsOperator AS operador_logistico
    , ks.courier AS courier
    , ks.service AS servicio
    , CASE WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ entrega segura + FOTODNI)'
            WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'Exclusiva (+ entrega segura)'
            WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ FOTODNI)'
            WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN 'Exclusiva'
            WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'DNI (entrega segura + FOTODNI)'
            WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'DNI (entrega segura)'
            WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'FOTODNI'
            WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN CAST(NULL AS STRING)
        ELSE 'DESCONOCIDO - REVISAR' END AS identificacion
    , CASE  WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Cancelado-Devuelto al Almacén')  AND cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1 THEN 'Destruido (SIM)' 
            WHEN ml.ESTADO IN ('Destruído por transportista') THEN 'Destruido (SIM)'         --Modificamos el valor original, sin mas cambio
            WHEN ml.ESTADO IN ('Documentación enviada') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
            WHEN ml.ESTADO IN ('Desastre en la entrega en el WH') THEN 'Entregado (Documentacion KO)'  --Falla la entrega de la documentacion    --Modificamos el valor original, sin mas cambio
            WHEN ml.ESTADO IN ('Entregado a custodiador','Entregado en WH') THEN 'Entregado (Documentacion OK)'  --Entrega de la documentacion   --Modificamos el valor original, sin mas cambio
            WHEN ml.ESTADO IN ('Entregado en punto de entrega','En delegacion destino') THEN 'Entregado'  --Modificamos el valor original, sin mas cambio
            WHEN ml.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking' 	  
            WHEN ml.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking'
            --WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
            WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Devuelto al almacen'
            WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
            WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
            ELSE ml.ESTADO END AS estado_final
/*
            WHEN ml.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking' 
            WHEN ml.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking' 
            WHEN ml.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
            ELSE ml.ESTADO END AS estado_final
*/
    , ml.FECHAESTADO AS fecha_estado_final
    , CASE WHEN ml.SOLICITUDDECANCELACION IS NULL THEN 'NO' ELSE 'SI' END AS cancelacion_solicitada
    , btn.customer_id AS id_cliente
    , subscriptions.subscriptionId AS id_suscripcion
    , ml.RETORNODAC AS retorno_contrato
    , prov.provincia AS provincia
    , cp.codigo_postal AS codigo_postal
    , ml.OBSCOURIER AS textos
    , subscriptions.externalId.number AS telefono_contacto
    --, COALESCE(subscriptions.externalId.number,customer.user.contactData.phoneNumber.number) AS telefono_contacto
    , MAX(TIMESTAMP_TRUNC(preparationCompletedDatetime, SECOND)) AS fecha_comunicacion
    , ml.FECHAESTADO AS fecha_ultima_actualizacion
    , CAST (NULL AS STRING) AS tipo_documento
    , CAST (NULL AS STRING) AS documento
    , btn.segment_ds tipo_cliente
/*
        , CASE WHEN cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1                            THEN 'SIM'
               WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) = 'MANIPULADO'             THEN 'Equipo manipulado + SIM'
               WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PAE')                  THEN 'PAE'
               WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PATINES')              THEN 'PATINETE'
               WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1 AND CUENTA_Papeleria = 1 THEN 'SMART TV+DOCUMENTACION'
               WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 1 THEN 'SMART TV+DOCUMENTACION'
               WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 0 THEN 'SMART TV'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Terminal >= 1    THEN 'TERMINAL'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Tablet >= 1      THEN 'TABLET'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Router >= 1      THEN 'ROUTER'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_MODEM >= 1       THEN 'MODEM'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_STB >= 1         THEN 'STB'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_PATIN >= 1       THEN 'PATINETE'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1    THEN 'SMART TV'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Accesories >= 1  THEN 'ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1    THEN 'ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_SN >= 1      THEN 'PAE'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Papeleria >= 1   THEN 'PAPELERIA'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ONT >= 1         THEN 'ONT'     
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Terminal > 0    THEN 'SIM+TERMINAL'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Tablet > 0      THEN 'SIM+TABLET'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Router > 0      THEN 'SIM+ROUTER'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_MODEM > 0       THEN 'SIM+MODEM'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_STB > 0         THEN 'SIM+STB'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Accesories > 0  THEN 'SIM+ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_IMEI > 0    THEN 'SIM+ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_SN > 0      THEN 'SIM+ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1   THEN 'SIM+SMART TV'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria > 0   THEN 'SIM+SMART TV+DOCUMENTACION'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Papeleria > 0   THEN 'SIM+PAPELERIA'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ONT > 0         THEN 'SIM+ONT'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  = 0                             THEN 'DISPOSITIVOS'
               WHEN cpm.cuenta_tecnologia IS NULL                                              THEN 'SIN DATOS EN ORDERBOX'
          ELSE 'REVISAR' END AS dispositivo
*/
    , CASE WHEN cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1                                                    THEN 'SIM'
          WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) = 'MANIPULADO'               THEN 'Equipo manipulado + SIM'
          WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PATINES')               THEN 'PATINETE'
          WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1 AND CUENTA_Papeleria = 1   THEN 'SMART TV+DOCUMENTACION'
          WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 1   THEN 'SMART TV+DOCUMENTACION'
          WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 0   THEN 'SMART TV'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_PATIN >= 1                               THEN 'PATINETE'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1                            THEN 'SMART TV'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1                           THEN 'SIM+SMART TV'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria > 0  THEN 'SIM+SMART TV+DOCUMENTACION'
          --WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PAE')                  THEN 'PAE'
          WHEN ks.weight > 2 AND ks.weight <= 7                                                                   THEN 'PAE'
          WHEN ks.weight > 7 AND ks.weight <= 18                                                                  THEN 'MAE'
          WHEN ks.weight > 18                                                                                     THEN 'GAE'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Terminal >= 1                            THEN 'TERMINAL'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Tablet >= 1                              THEN 'TABLET'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Router >= 1                              THEN 'ROUTER'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_MODEM >= 1                               THEN 'MODEM'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_STB >= 1                                 THEN 'STB'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Accesories >= 1                          THEN 'ACCESORIO'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1                            THEN 'ACCESORIO'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_SN >= 1                              THEN 'PAE'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Papeleria >= 1                           THEN 'PAPELERIA'
          WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ONT >= 1                                 THEN 'ONT'     
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Terminal > 0                            THEN 'SIM+TERMINAL'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Tablet > 0                              THEN 'SIM+TABLET'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Router > 0                              THEN 'SIM+ROUTER'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_MODEM > 0                               THEN 'SIM+MODEM'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_STB > 0                                 THEN 'SIM+STB'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Accesories > 0                          THEN 'SIM+ACCESORIO'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_IMEI > 0                            THEN 'SIM+ACCESORIO'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_SN > 0                              THEN 'SIM+ACCESORIO'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Papeleria > 0                           THEN 'SIM+PAPELERIA'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ONT > 0                                 THEN 'SIM+ONT'
          WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  = 0                                                     THEN 'DISPOSITIVOS'
          WHEN cpm.cuenta_tecnologia IS NULL                                                                      THEN 'SIN DATOS EN ORDERBOX'
      ELSE 'REVISAR' END AS dispositivo
    , CASE WHEN billing_type_ds = 'PREPAID' THEN 'PREPAGO'
            WHEN billing_type_ds = 'POSTPAID' THEN 'POSTPAGO'
      ELSE billing_type_ds END AS categoria_contrato
    , kp.impresos AS total_impresos
    , kp.preimpresos AS total_preimpresos
    , CAST(NULL AS INTEGER) AS total_color
    , cpm.cuenta_tecnologia AS total_bultos
    , CAST(0 AS FLOAT64) AS importe_pedido
    , 'NO' AS contrarrembolso
    , CAST (NULL AS INTEGER) AS importe_contrarrembolso
    , ROUND(ks.weight,3) AS total_peso  --HACER
    , COALESCE(btn.master_channel_ds,UPPER(ml.CANALVENTA)) AS canal
    , btn.user_store AS SFID_ID
    , btn.sub_segment_ds AS segmento
    , btn.contract_id AS contrato
    , CASE  WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Cancelado-Devuelto al Almacén')  AND cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1 THEN 'Destruido (SIM)' 
            WHEN er.ESTADO IN ('Destruído por transportista') THEN 'Destruido (SIM)'         --Modificamos el valor original, sin mas cambio
            WHEN er.ESTADO IN ('Documentación enviada') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
            WHEN er.ESTADO IN ('Desastre en la entrega en el WH') THEN 'Entregado (Documentacion KO)'  --Falla la entrega de la documentacion    --Modificamos el valor original, sin mas cambio
            WHEN er.ESTADO IN ('Entregado a custodiador','Entregado en WH') THEN 'Entregado (Documentacion OK)'  --Entrega de la documentacion   --Modificamos el valor original, sin mas cambio
            WHEN er.ESTADO IN ('Entregado en punto de entrega','En delegacion destino') THEN 'Entregado'  --Modificamos el valor original, sin mas cambio
            WHEN ml.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking' 	  
            WHEN ml.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking'
            --WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
            WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Devuelto al almacen'
            WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
            WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
            ELSE ml.ESTADO END AS estado_final
/*
            WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking' 
            WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking' 
            WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'           
            ELSE er.ESTADO END AS estado_reexpedicion
*/
      --, SAFE_CAST(ml.PEDIDOMM AS INT64) AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
      , COALESCE(ml.PEDIDOMM,ml.OT,ml.ITEMNUMBER) AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
      , dir.direccion AS direccion

FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_PREPARATION_COMPLETED*` ke, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
  LEFT JOIN `mm-commissions-reporting.TEMP.kafka_direccion` dir
    ON  UPPER(dir.marca) = UPPER(ke.tenantByTopic)
    AND dir.id_orden = subscriptions.orderCrmId
    AND dir.reexpedition = ke.reexpedition
    AND dir.tipo_pedido = 'PEDIDO'
  LEFT JOIN `mm-commissions-reporting.TEMP.kafka_codigo_postal` cp
    ON  UPPER(cp.marca) = UPPER(ke.tenantByTopic)
    AND cp.id_orden = subscriptions.orderCrmId
  LEFT JOIN `mm-commissions-reporting.TEMP.kafka_provincia` prov
    ON  UPPER(prov.marca) = UPPER(ke.tenantByTopic)
    AND prov.id_orden = subscriptions.orderCrmId
  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
    ON  CAST(btn.phone_nm AS STRING) = subscriptions.externalId.number
    AND UPPER(btn.data_source_ds) = 'MYSIM'
    AND UPPER(btn.brand_ds) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
    --AND btn.order_date = CAST(TIMESTAMP_TRUNC(createdDatetime, DAY) AS DATE)  --ALGUNOS NO TIENEN ORDEN Y NO TIENEN FECHA, SI QUITO EL FILTRO, ME PUEDE TRAEAR INFORMACION ANTIGUA --REVISAR
    AND btn.service_id = subscriptions.subscriptionId  --Otra opción de filtro
  LEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation` kp
    ON  kp.orderCrmId = subscriptions.orderCrmId
    AND kp.reexpedition = ke.reexpedition
  LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped` ks
    ON ks.orderCrmId = subscriptions.orderCrmId
    AND ks.expeditionId = ke.expeditionId  --2024/11/27

--  LEFT JOIN `mm-commissions-reporting.TEMP.kafka_tipo_dispositivo` kt   --feb/25 lo eliminamos
--    ON  kt.reference = kp.referencia

  LEFT JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo` ml
    ON  ml.ITEMNUMBER = subscriptions.orderCrmId
    AND ml.RX = ke.reexpedition 
  LEFT JOIN `mm-commissions-reporting.TEMP.maslola_lineas` li
    ON  li.PEDIDOMM = ml.PEDIDOMM
    --Tomamos como picking el evento 'Inicio extracción'
  LEFT JOIN `mm-commissions-reporting.TEMP.maslola_inicio_picking` ip
    ON  ip.ITEMNUMBER = subscriptions.orderCrmId
  LEFT JOIN `mm-commissions-reporting.TEMP.maslola_salida_almacen` sa
    ON  sa.ITEMNUMBER = subscriptions.orderCrmId
    --BUSCAMOS EL TIPO DE DISPOSITIVO
  LEFT JOIN `mm-commissions-reporting.TEMP.maslola_dispositivo` md
    ON  md.ITEMNUMBER = subscriptions.orderCrmId

  -- LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
  --   ON  gef.estado = ml.ESTADO
  --   AND gef.tipo_pedido = 'Entrega'

  LEFT JOIN `mm-commissions-reporting.TEMP.maslola_estado_reexp` er
    ON  er.ITEMNUMBER  = subscriptions.orderCrmId
    AND er.reexpedition = ke.reexpedition
  LEFT JOIN `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA` cpm
    ON cpm.ITEMNUMBER = subscriptions.orderCrmId

WHERE NOT EXISTS (SELECT 1 FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo WHERE subscriptions.orderCrmId = CAST(lo.id_orden AS STRING))
  AND preparationCompletedDatetime >= CAST(initial_date AS TIMESTAMP) -- '2024-04-01'  
  AND UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
  AND UPPER(ke.logisticsOperator) = 'INTERBOX'
--  AND UPPER(ke.businessProcess) = 'PEDIDO'
  AND UPPER(logisticOperation) = 'DELIVERY'
  AND subscriptions.subscriptionId IS NOT NULL
    --Si no tienen estado, no podemos facturarlo
  AND ml.ESTADO IS NOT NULL
    --Eliminamos los envíos de la documentación de las SMART-TVs
  AND md.referenciatipoenvio NOT IN ('Papelería')
--  AND devices.subscriptionDeviceId NOT LIKE '%-%'  --2025-11-12 Eliminamos esta restricción porque perdemos pedidos según https://jiranext.masorange.es/browse/DDEV-30867
    --Solo nos quedamos con estados finales --DEJAMOS TODOS LOS ESTADOS, NO SOLO LOS FINALES
  --AND gef.final = 'SI'

GROUP BY ALL
);

    --Añadimos a la tabla de órdenes de Entrega, los contratos de la SMART TV
  INSERT INTO `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` (
        SELECT UPPER(tenantByTopic) AS marca
            , CASE WHEN CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING) IS NOT NULL AND CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING) <> '' THEN CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING)
                   WHEN devices.subscriptionDeviceId IS NOT NULL AND devices.subscriptionDeviceId <> '' THEN devices.subscriptionDeviceId
                   WHEN subscriptions.orderCrmId IS NOT NULL THEN subscriptions.orderCrmId 
                   ELSE CAST(NULL AS STRING) END AS id_orden
            , ke.reexpedition AS reexpedition
            , 1 AS numero_lineas
            , CASE WHEN logisticOperation = 'DELIVERY' THEN 'Entrega'
                    WHEN logisticOperation = 'PICKUP' THEN 'Desistimiento'
                    WHEN logisticOperation = 'SWAP' THEN 'Swap'
              ELSE logisticOperation END AS tipo_pedido
            , CASE WHEN ks.courier = 'HL' THEN 'domicilio'
                  WHEN shipping.deliveryType = 'HOME' THEN 'domicilio'
                  WHEN shipping.deliveryType = 'SHOP' THEN 'tienda'
                  WHEN shipping.deliveryType = 'AGENCY' AND ks.courier = 'CORREOS' THEN 'correos'
              ELSE 'domicilio' END AS tipo_orden
            , 'entrega' AS motivo 
            --, ks.expeditionIdExternal AS numero_expedicion
            , COALESCE(ks.expeditionIdExternal,ks.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'_Entrega')) AS numero_expedicion --id de Eurologistica  
            , CASE WHEN shipping.address.type = 'SHIPMENT' THEN 'B2C' ELSE shipping.address.type END AS tipo_destinatario
            , logisticsOperator AS operador_logistico
            , 'CORREOS' AS courier
            , ks.service AS servicio
            , CASE WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ entrega segura + FOTODNI)'
                   WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'Exclusiva (+ entrega segura)'
                   WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ FOTODNI)'
                   WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN 'Exclusiva'
                   WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'DNI (entrega segura + FOTODNI)'
                   WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'DNI (entrega segura)'
                   WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'FOTODNI'
                   WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN CAST(NULL AS STRING)
                ELSE 'DESCONOCIDO - REVISAR' END AS identificacion
            , CASE WHEN ml.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking'
                   WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén','No Entregado-Devuelto al Almacén') THEN 'Cancelado postpicking'
                   WHEN ml.ESTADO IN ('Entregado a custodiador','Entregado en punto de entrega','Entregado en WH') THEN 'Entregado'
                   WHEN ml.ESTADO IN ('Siniestro','Desastre en la entrega en el WH','Destruído por transportista') THEN 'Desastre'
                   WHEN ml.ESTADO IN ('Tránsito devolución','En tránsito','Salida de Almacen') THEN 'En tránsito'
                   ELSE ml.ESTADO END AS estado_final
            , ml.FECHAESTADO AS fecha_estado_final
            , CASE WHEN ml.SOLICITUDDECANCELACION IS NULL THEN 'NO' ELSE 'SI' END AS cancelacion_solicitada
            , btn.customer_id AS id_cliente
            , subscriptions.subscriptionId AS id_suscripcion
            , ml.RETORNODAC AS retorno_contrato
            , prov.provincia AS provincia
            , cp.codigo_postal AS codigo_postal
            , ml.OBSCOURIER AS textos
            , COALESCE(subscriptions.externalId.number,customer.user.contactData.phoneNumber.number) AS telefono_contacto
            , MAX(TIMESTAMP_TRUNC(ke.createdDatetime, SECOND)) AS fecha_comunicacion
            , ml.FECHAESTADO AS fecha_ultima_actualizacion
            , customer.user.identityDocument.type AS tipo_documento
            , customer.user.identityDocument.number AS documento
            , btn.segment_ds tipo_cliente
            , 'DOCUMENTACION SMART TV' AS dispositivo
            , 'POSTPAGO' AS categoria_contrato
            , COALESCE(kp.impresos,8) AS total_impresos
            , COALESCE(kp.preimpresos,0) AS total_preimpresos
            , CAST(NULL AS INTEGER) AS total_color
            , cpm.cuenta_tecnologia AS total_bultos
            , 0.01 AS importe_pedido
            , 'NO' AS contrarrembolso
            , CAST (NULL AS INTEGER) AS importe_contrarrembolso
            , ROUND(ks.weight,3) AS total_peso
            , COALESCE(btn.master_channel_ds,UPPER(ml.CANALVENTA)) AS canal
            , btn.user_store AS SFID_ID
            , btn.sub_segment_ds AS segmento
            , btn.contract_id AS contrato
            , CASE WHEN ml.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking'
                   WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén','No Entregado-Devuelto al Almacén') THEN 'Cancelado postpicking'
                   WHEN ml.ESTADO IN ('Entregado a custodiador','Entregado en punto de entrega','Entregado en WH') THEN 'Entregado'
                   WHEN ml.ESTADO IN ('Siniestro','Desastre en la entrega en el WH','Destruído por transportista') THEN 'Desastre'
                   WHEN ml.ESTADO IN ('Tránsito devolución','En tránsito','Salida de Almacen') THEN 'En tránsito'
                   ELSE er.ESTADO END AS estado_reexpedicion
              , COALESCE(ml.PEDIDOMM,ml.OT,ml.ITEMNUMBER) AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
              , dir.direccion AS direccion 

        FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` ke, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_direccion` dir
            ON  UPPER(dir.marca) = UPPER(ke.tenantByTopic)
            AND dir.id_orden = subscriptions.orderCrmId
            AND dir.reexpedition = ke.reexpedition
            AND dir.expeditionId = ke.expeditionId  --2024/11/24
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_codigo_postal` cp
            ON  UPPER(cp.marca) = UPPER(ke.tenantByTopic)
            AND cp.id_orden = subscriptions.orderCrmId
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_provincia` prov
            ON  UPPER(prov.marca) = UPPER(ke.tenantByTopic)
            AND prov.id_orden = subscriptions.orderCrmId
          LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
            ON  btn.phone_nm = CAST(subscriptions.externalId.number AS INTEGER)
            AND UPPER(btn.data_source_ds) = 'MYSIM'
            AND btn.service_id = subscriptions.subscriptionId 
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped_papeleria` ks
            ON  ks.orderCrmId = subscriptions.orderCrmId
            AND CAST(ks.expeditionId AS STRING) = CAST(ke.expeditionId AS STRING)
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation_papeleria` kp
            -- ON  kp.orderCrmId = subscriptions.orderCrmId
            ON  kp.id_orden = substr(devices.subscriptionDeviceId,10,7)
            AND kp.reexpedition = ke.reexpedition
          INNER JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo_papeleria` ml  --HAGO INNER PARA SACAR SOLO LOS QUE FILTRO (DAC ENTREGADO O CANCELADO PREPICKING)
            ON  ml.ITEMNUMBER = subscriptions.orderCrmId
            AND ml.RX = ke.reexpedition

          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_inicio_picking_papeleria` ip
            ON  CAST(ip.itemnumber AS STRING) = subscriptions.orderCrmId
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_salida_almacen_papeleria` sa
            ON  CAST(sa.ITEMNUMBER AS STRING) = subscriptions.orderCrmId
          LEFT JOIN `mm-commissions-reporting.TEMP.maslola_estado_reexp_papeleria` er
            ON  CAST(er.ITEMNUMBER AS STRING) = subscriptions.orderCrmId
            AND er.reexpedition = ke.reexpedition
          LEFT JOIN `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA_papeleria` cpm
            ON cpm.ITEMNUMBER = subscriptions.orderCrmId

        WHERE UPPER(ke.logisticsOperator) = 'INTERBOX'
          --AND UPPER(tenantByTopic) IN ('YOIGO','MASMOVIL','PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA')
          AND UPPER(logisticOperation) = 'DELIVERY'
          AND ml.ESTADO IS NOT NULL
            --Cogemos los envíos de la documentación de las SMART-TVs
          AND devices.reference IN ('ZYODOCTVB')
          AND TIMESTAMP_TRUNC(loadDate, DAY) >= CAST (initial_date AS TIMESTAMP) --TIMESTAMP(initial_date)  --('2024-05-01')

        GROUP BY ALL
  );

/*
      SELECT UPPER(tenantByTopic) AS marca
--        , ml.MASTER AS id_master, btn.channel_ds AS Master
--        , COALESCE(CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING),devices.subscriptionDeviceId,subscriptions.orderCrmId,) AS id_orden
        , CASE WHEN CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING) IS NOT NULL AND CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING) <> '' THEN CAST(substr(devices.subscriptionDeviceId,10,7) AS STRING)
              WHEN devices.subscriptionDeviceId IS NOT NULL AND devices.subscriptionDeviceId <> '' THEN devices.subscriptionDeviceId
              WHEN subscriptions.orderCrmId IS NOT NULL THEN subscriptions.orderCrmId 
              ELSE CAST(NULL AS STRING) END AS id_orden
        , ke.reexpedition AS reexpedition
        , CAST(NULL AS INT64) AS numero_lineas
        , CASE WHEN logisticOperation = 'DELIVERY' THEN 'Entrega'
                WHEN logisticOperation = 'PICKUP' THEN 'Desistimiento'
                WHEN logisticOperation = 'SWAP' THEN 'Swap'
          ELSE logisticOperation END AS tipo_pedido
        , CASE WHEN shipping.deliveryType = 'HOME' THEN 'domicilio'
                WHEN shipping.deliveryType = 'SHOP' THEN 'tienda'
                WHEN shipping.deliveryType = 'AGENCY' AND ks.courier = 'CORREOS' THEN 'correos'
          ELSE 'domicilio' END AS tipo_orden
        , 'entrega' AS motivo 
        , ks.expeditionIdExternal AS numero_expedicion --id de Eurologistica  
        , CASE WHEN shipping.address.type = 'SHIPMENT' THEN 'B2C' ELSE shipping.address.type END AS tipo_destinatario
        , logisticsOperator AS operador_logistico
        , 'CORREOS' AS courier  --, ks.courier AS courier
        , ks.service AS servicio
        , CASE WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ entrega segura + FOTODNI)'
                WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'Exclusiva (+ entrega segura)'
                WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'Exclusiva (+ FOTODNI)'
                WHEN ml.ENTREGAEXCLUSIVA = 'SI' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN 'Exclusiva'
                WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'SI' THEN 'DNI (entrega segura + FOTODNI)'
                WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'SI' AND ml.FOTODNI = 'NO' THEN 'DNI (entrega segura)'
                WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'SI' THEN 'FOTODNI'
                WHEN ml.ENTREGAEXCLUSIVA = 'NO' AND ml.ENTREGASEGURA = 'NO' AND ml.FOTODNI = 'NO' THEN CAST(NULL AS STRING)
            ELSE 'DESCONOCIDO - REVISAR' END AS identificacion
--        , 'Entregado (Documentacion OK)' AS estado_final
        , CASE  WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Cancelado-Devuelto al Almacén')  AND cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1 THEN 'Destruido (SIM)' 
                WHEN er.ESTADO IN ('Destruído por transportista') THEN 'Destruido (SIM)'         --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Documentación enviada') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Desastre en la entrega en el WH') THEN 'Entregado (Documentacion KO)'  --Falla la entrega de la documentacion    --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Entregado a custodiador','Entregado en WH') THEN 'Entregado (Documentacion OK)'  --Entrega de la documentacion   --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Entregado en punto de entrega','En delegacion destino') THEN 'Entregado'  --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking' 	  
                WHEN er.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking'
                WHEN er.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
                WHEN er.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
                WHEN er.ESTADO IN ('Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'

                -- WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking' 
                -- WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking' 
                -- WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'           

                WHEN er.ESTADO IS NULL THEN 'Entregado (Documentacion OK)'
                WHEN er.ESTADO = ''    THEN 'Entregado (Documentacion OK)'
                ELSE er.ESTADO END AS estado_fina
        , ml.FECHAESTADO AS fecha_estado_final
        , CASE WHEN ml.SOLICITUDDECANCELACION IS NULL THEN 'NO' ELSE 'SI' END AS cancelacion_solicitada
        , btn.customer_id AS id_cliente
        , subscriptions.subscriptionId AS id_suscripcion
        , ml.RETORNODAC AS retorno_contrato
        , prov.provincia AS provincia
        , cp.codigo_postal AS codigo_postal
        , ml.OBSCOURIER AS textos
        --, subscriptions.externalId.number AS telefono_contacto
        , COALESCE(subscriptions.externalId.number,customer.user.contactData.phoneNumber.number) AS telefono_contacto
        , MAX(TIMESTAMP_TRUNC(ke.createdDatetime, SECOND)) AS fecha_comunicacion
        , ml.FECHAESTADO AS fecha_ultima_actualizacion
        , customer.user.identityDocument.type AS tipo_documento
        , customer.user.identityDocument.number AS documento
        , btn.segment_ds tipo_cliente
        , 'DOCUMENTACION SMART TV' AS dispositivo
        , CASE WHEN billing_type_ds = 'PREPAID' THEN 'PREPAGO'
                WHEN billing_type_ds = 'POSTPAID' THEN 'POSTPAGO'
          ELSE billing_type_ds END AS categoria_contrato
        , kp.impresos AS total_impresos
        , kp.preimpresos AS total_preimpresos
        , CAST(NULL AS INTEGER) AS total_color
        , 1 AS total_bultos
        , CAST(0 AS FLOAT64) AS importe_pedido
        , 'NO' AS contrarrembolso
        , CAST (NULL AS INTEGER) AS importe_contrarrembolso
        , ks.weight AS total_peso  --HACER
        , COALESCE(btn.master_channel_ds,UPPER(ml.CANALVENTA)) AS canal
        , btn.user_store AS SFID_ID
        , btn.sub_segment_ds AS segmento
        , btn.contract_id AS contrato
        , CASE  WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Cancelado-Devuelto al Almacén')  AND cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1 THEN 'Destruido (SIM)' 
                WHEN er.ESTADO IN ('Destruído por transportista') THEN 'Destruido (SIM)'         --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Documentación enviada') THEN 'Entregado (Documentacion OK)'  --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Desastre en la entrega en el WH') THEN 'Entregado (Documentacion KO)'  --Falla la entrega de la documentacion    --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Entregado a custodiador','Entregado en WH') THEN 'Entregado (Documentacion OK)'  --Entrega de la documentacion   --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Entregado en punto de entrega','En delegacion destino') THEN 'Entregado'  --Modificamos el valor original, sin mas cambio
                WHEN er.ESTADO IN ('Cancelado-Anulado') THEN 'Cancelado prepicking' 	  
                WHEN er.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking'
                WHEN er.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
                WHEN er.ESTADO IN ('Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
                WHEN er.ESTADO IN ('Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'

                -- WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NULL THEN 'Cancelado prepicking' 
                -- WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking' 
                -- WHEN er.ESTADO IN ('Cancelado-Anulado','Cancelado-Devuelto al Almacén','Cancelado Devolucion Almacén','No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
                -- WHEN er.ESTADO IS NULL THEN 'Entregado (Documentacion OK)'
                -- WHEN er.ESTADO = ''    THEN 'Entregado (Documentacion OK)'

                ELSE er.ESTADO END AS estado_reexpedicion
          --, SAFE_CAST(subscriptions.orderCrmId AS INT64) AS pedido_padre  
          , COALESCE(ml.PEDIDOMM,ml.OT,ml.ITEMNUMBER) AS pedido_padre  --Modificamos PEDIDOMM por pedido_padre
          , dir.direccion AS direccion

    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` ke, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_direccion` dir
        ON  UPPER(dir.marca) = UPPER(ke.tenantByTopic)
        AND dir.id_orden = subscriptions.orderCrmId
        AND dir.reexpedition = ke.reexpedition
        AND dir.tipo_pedido = 'PEDIDO'
        AND dir.expeditionId = ke.expeditionId  --2024/11/24
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_codigo_postal` cp
        ON  UPPER(cp.marca) = UPPER(ke.tenantByTopic)
        AND cp.id_orden = SAFE_CAST(subscriptions.orderCrmId AS STRING)
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_provincia` prov
        ON  UPPER(prov.marca) = UPPER(ke.tenantByTopic)
        AND prov.id_orden = subscriptions.orderCrmId
      LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
        ON  btn.phone_nm = CAST(subscriptions.externalId.number AS INTEGER)
        AND UPPER(btn.data_source_ds) = 'MYSIM'
        AND UPPER(btn.brand_ds) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
        --AND btn.order_date = CAST(TIMESTAMP_TRUNC(createdDatetime, DAY) AS DATE)  --ALGUNOS NO TIENEN ORDEN Y NO TIENEN FECHA, SI QUITO EL FILTRO, ME PUEDE TRAEAR INFORMACION ANTIGUA --REVISAR
        AND btn.service_id = subscriptions.subscriptionId  --Otra opción de filtro
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation` kp
        ON  kp.orderCrmId = subscriptions.orderCrmId
        AND kp.reexpedition = ke.reexpedition
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped` ks
        ON ks.orderCrmId = subscriptions.orderCrmId
        AND ks.expeditionId = ke.expeditionId  --2024/11/27
--      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_tipo_dispositivo` kt    --feb/25eliminamos kt
--        ON  kt.reference = kp.referencia
      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo` ml
        ON  ml.ITEMNUMBER = subscriptions.orderCrmId
        AND ml.RX = ke.reexpedition
        --Tomamos como picking el evento 'Inicio extracción'
      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_inicio_picking` ip
        ON  ip.ITEMNUMBER = subscriptions.orderCrmId
      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_salida_almacen` sa
        ON  sa.ITEMNUMBER = subscriptions.orderCrmId
        --BUSCAMOS EL TIPO DE DISPOSITIVO

--      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_dispositivo` md
--        ON  md.ITEMNUMBER = subscriptions.orderCrmId


      -- LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
      --   ON  gef.estado = ml.ESTADO
      --   AND gef.tipo_pedido = 'Entrega'

      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_estado_reexp` er
        ON  er.ITEMNUMBER = subscriptions.orderCrmId
        AND er.reexpedition = ke.reexpedition
      LEFT JOIN `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA` cpm
        ON cpm.ITEMNUMBER = subscriptions.orderCrmId

    WHERE UPPER(tenantByTopic) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO')  -- ('YOIGO','MASMOVIL')
      AND UPPER(ke.logisticsOperator) = 'INTERBOX'
--      AND UPPER(ke.businessProcess) = 'PEDIDO'
      AND UPPER(ke.logisticOperation) = 'DELIVERY'
        --Si no tienen estado, no podemos facturarlo
      AND ml.ESTADO IS NOT NULL
        --Eliminamos los envíos de la documentación de las SMART-TVs
--      AND devices.subscriptionDeviceId LIKE '%-%'
      AND subscriptions.orderCrmId IN (SELECT CAST(id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` aaa WHERE aaa.dispositivo = 'SMART TV+DOCUMENTACION')
        --Solo nos quedamos con estados finales --DEJAMOS TODOS LOS ESTADOS, NO SOLO LOS FINALES
      --AND gef.final = 'SI'
      AND ks.expeditionIdExternal IS NOT NULL
        --FILTRO DE FECHA--
      AND TIMESTAMP_TRUNC(loadDate, DAY) >= TIMESTAMP(initial_date) --('2024-05-01')

    GROUP BY ALL
  );
*/
    --TABLA de órdenes de Desistimiento
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` AS(
    SELECT 
        dn.brand_ds AS marca
--      , ml.MASTER AS id_master, vbn.channel_ds AS Master -- Pendiente de confirmar
      , CAST(ob.ticket AS STRING) AS id_orden  --Cambiamos el id_orden por el nº de ticket de orderbox en los desistimientos. El pedido de Entrega está en pedido_padre
      , CASE WHEN ob.RX IS NULL THEN 'R0' ELSE ob.RX END AS rexpedicion
      , ob.LINEA AS numero_lineas
      , ob.TIPOPEDIDOMYSIM AS tipo_pedido
      , CASE WHEN UPPER(TRANSPORT.courier) = 'CORREOS' THEN 'Correos'
            WHEN UPPER(TRANSPORT.courier) <> 'CORREOS' THEN 'Domicilio'
            WHEN TRANSPORT.courier IS NULL AND UPPER(dn.courier) = 'CORREOS' THEN 'Correos'
            ELSE 'Domicio' END AS tipo_orden
      , dn.order_type_agg AS motivo_orden
      --, kf.expeditionIdExternal AS numero_expedicion --id de Eurologistica  
      , COALESCE(kf.expeditionIdExternal,kf.expeditionId,('DUMMY_'||ob.ticket||'Desistimiento')) AS numero_expedicion --id de Eurologistica  
      , CASE WHEN ob.TIPOCLIENTE = 'Canal Directo' THEN 'B2C' ELSE ob.TIPOCLIENTE END AS tipo_destinatario
      , ob.OPERADORLOGISTICO AS operador_logistico
      , CASE WHEN ESTADO.courier IS NOT NULL THEN UPPER(ESTADO.courier) WHEN nm.courier IS NOT NULL THEN nm.courier ELSE dn.courier END AS courier
      , CASE WHEN ESTADO.servicio IS NOT NULL THEN UPPER(ESTADO.servicio) ELSE nm.servicio END AS servicio
      , CASE WHEN ob.ENTREGAEXCLUSIVA = 'SI' AND ob.ENTREGASEGURA = 'SI' AND ob.FOTODNI = 'SI' THEN 'Exclusiva (+ entrega segura + FOTODNI)'
            WHEN ob.ENTREGAEXCLUSIVA = 'SI' AND ob.ENTREGASEGURA = 'SI' AND ob.FOTODNI = 'NO' THEN 'Exclusiva (+ entrega segura)'
            WHEN ob.ENTREGAEXCLUSIVA = 'SI' AND ob.ENTREGASEGURA = 'NO' AND ob.FOTODNI = 'SI' THEN 'Exclusiva (+ FOTODNI)'
            WHEN ob.ENTREGAEXCLUSIVA = 'SI' AND ob.ENTREGASEGURA = 'NO' AND ob.FOTODNI = 'NO' THEN 'Exclusiva'
            WHEN ob.ENTREGAEXCLUSIVA = 'NO' AND ob.ENTREGASEGURA = 'SI' AND ob.FOTODNI = 'SI' THEN 'DNI (entrega segura + FOTODNI)'
            WHEN ob.ENTREGAEXCLUSIVA = 'NO' AND ob.ENTREGASEGURA = 'SI' AND ob.FOTODNI = 'NO' THEN 'DNI (entrega segura)'
            WHEN ob.ENTREGAEXCLUSIVA = 'NO' AND ob.ENTREGASEGURA = 'NO' AND ob.FOTODNI = 'SI' THEN 'FOTODNI'
            WHEN ob.ENTREGAEXCLUSIVA = 'NO' AND ob.ENTREGASEGURA = 'NO' AND ob.FOTODNI = 'NO' THEN CAST(NULL AS STRING)
        ELSE 'N/A' END AS identificacion
      , CASE WHEN EKD.estado_kafka IS NOT NULL THEN EKD.estado_kafka
            WHEN EKD.estado_kafka IS NULL AND ob.subestado IS NULL THEN ob.subestado
            ELSE 'Sin estado en Kafka ni Orderbox' END AS estado_final
      , MAX(ob.FECHAESTADO) AS fecha_estado_final
      , CASE WHEN ob.SOLICITUDDECANCELACION IS NULL THEN 'NO' ELSE 'SI' END AS cancelacion_solicitada
      , dn.customer_id AS id_cliente
      , dn.service_id AS id_suscripcion
      , CASE WHEN ob.RETORNODAC IS NOT NULL THEN ob.RETORNODAC ELSE 'N/A' END AS retorno_contrato
      , CASE WHEN ob.PROVINCIA IS NOT NULL THEN ob.PROVINCIA
            WHEN ob.PROVINCIA IS NULL AND vbn.province IS NOT NULL THEN vbn.province
            WHEN ob.CODIGOPOSTAL IS NOT NULL THEN ZONA.provincia
            ELSE CAST(NULL AS STRING) END AS provincia
      , CASE WHEN ob.CODIGOPOSTAL IS NOT NULL THEN ob.CODIGOPOSTAL
            WHEN ob.CODIGOPOSTAL IS NULL AND ob.provincia IS NOT NULL THEN ZONA.codigo_postal
            WHEN ob.CODIGOPOSTAL IS NULL AND vbn.province IS NOT NULL THEN CONCAT(ZONA_PROVINCIA.codigo_postal,'XXX')
            ELSE  CAST(NULL AS STRING) END AS codigo_postal
      , ob.OBSCOURIER AS Textos  --Revisar si escribe varios textos o solo uno
      , ob.TFNCONTACTO AS telefono_contacto
      , ob.FECHACREACION AS fecha_comunicacion
      , MAX(ob.FECHAESTADO) AS fecha_ultima_actualizacion
      , cc.document_type AS tipo_documento
      , dir.documento AS documento
      , coalesce(ob.SUBTIPOCLIENTE, vbn.segment_ds,NULL) AS tipo_cliente
      , UPPER(coalesce(ml.TECNOLOGIA,dn.device_type_ds,NULL)) AS dispositivo
      , CASE WHEN vbn.billing_type_ds = 'POSTPAID' THEN 'POSTPAGO'
            WHEN vbn.billing_type_ds = 'PREPAID' THEN 'PREPAGO'
            ELSE CAST(NULL AS STRING) END AS categoria_contrato
      , CAST(NULL AS INTEGER) AS total_impresos
      , CAST(NULL AS INTEGER) AS total_preimpresos
      , CAST(NULL AS INTEGER) AS total_color
      , ob.CANTIDAD AS total_bultos
      , CAST(NULL AS FLOAT64) AS importe_pedido
      , 'NO' AS contrarrembolso
      , CAST(NULL AS FLOAT64) AS importe_contrarrembolso
      , ROUND(kf.weight,3) AS total_peso
      , COALESCE(vbn.master_channel_ds,UPPER(ml.CANALVENTA)) AS canal
      , vbn.sfid_id AS SFID_ID_VBN
      , dn.segment_ds AS segmento
      , vbn.contract_id AS contrato
      , 'N/A' AS estado_reexpedicion
      --, CAST(ob.ITEMNUMBER AS INT64) AS pedido_padre --cambiamos PEDIDOMM por pedido_padre para linkarlo con irder_id en el pedido
      , ob.ITEMNUMBER AS pedido_padre --cambiamos PEDIDOMM por pedido_padre para linkarlo con irder_id en el pedido
      , dir.direccion AS direccion

    FROM `mm-commissions-reporting.TEMP.orderbox_canal_directo` ob
      --INNER JOIN `mm-datamart-kd.SERVICES.devices_base_net` dn   --Habría que ver que pasa con los que no cruzan
      INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` dn
        ON  dn.item_number =  SAFE_CAST(ob.PEDIDOMM AS INT64)
      INNER JOIN `mm-datamart-kd.SERVICES.ventas_base_emysim` vbn --FALLA INNER
        ON  vbn.brand_ds = dn.brand_ds
        AND vbn.customer_id = dn.customer_id
        AND vbn.service_id = dn.service_id
        AND CAST (vbn.fecha_baja AS TIMESTAMP) >= ob.FECHACREACION
      LEFT JOIN `mm-datamart-kd.SERVICES.customer_carterizacion` cc
        ON  cc.customer_id = dn.customer_id
        AND cc.brand_ds = vbn.brand_ds
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped_desestimiento` kf
        ON  kf.orderCrmId = CAST(ob.PEDIDOMM AS STRING)
        AND kf.serial_number = ob.NSERIE
      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo` ml
        ON  ml.PEDIDOMM = ob.PEDIDOMM -- = SAFE_CAST(ob.PEDIDOMM AS INT64)  --ml.ITEMNUMBER = SAFE_CAST(ob.ITEMNUMBER AS INT64)
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_direccion` dir
        ON  UPPER(dir.marca) = UPPER(dn.brand_ds)
        AND dir.id_orden = CAST (ob.ITEMNUMBER AS STRING)
        AND dir.reexpedition = CASE WHEN ob.RX IS NULL THEN 'R0' ELSE ob.RX END
--        AND dir.rankkk = 1 --Para que tome Desistimiento en lugar de Pedido cuando exista
      LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADO
        ON  ESTADO.orderCrmId = CAST (ob.ITEMNUMBER AS STRING)
        AND UPPER(ESTADO.marca) = UPPER(ob.MARCA)
        AND ESTADO.courier IS NOT NULL AND ESTADO.servicio IS NOT NULL
        AND ESTADO.rank =1  --Evita duplicados
      LEFT JOIN `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` nm
--      LEFT JOIN `mm-datamart-kd.LOGISTICS.new_netkia_orders_maslola` nm
        --ON  nm.itemnumber = ob.PEDIDOMM
        ON  SAFE_CAST(nm.itemnumber AS INT64) = SAFE_CAST(ob.PEDIDOMM AS INT64)
        AND nm.estado = 'Recibido Interbox'
        AND nm.referenciatipoenvio NOT IN ('Papelería')  --ELIMINAMOS LA 'Documentación a entregar previa a instalar una Smart-TC, firmar por el cliente y retornar', ya que la tendremos que tratar aparte, si fuera necesario
        AND nm.ultimaincidencia IS NULL --Nos quedamos con los datos sin incidencia. CUIDADO NO ELIMINE TODAS LAS REEXPEDICIONES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = ob.CODIGOPOSTAL
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA_PROVINCIA
        ON  ZONA_PROVINCIA.provincia = vbn.province
      LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_courier` TRANSPORT
        ON  TRANSPORT.orderCrmId = CAST(ob.PEDIDOMM AS STRING)
        AND TRANSPORT.marca = dn.brand_ds
      LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado_final` DE
        ON  DE.orderCrmId = CAST(ob.ITEMNUMBER AS STRING)
        AND UPPER(DE.marca) = UPPER(dn.brand_ds)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_kafka_desist` EKD
        ON  EKD.accion = DE.accion

    WHERE UPPER(ob.TIPOPEDIDOMYSIM) = 'DESISTIMIENTO'
      AND ob.ticket IS NOT NULL
      AND UPPER(ob.OPERADORLOGISTICO) = 'INTERBOX'
      AND UPPER(ob.TIPOCLIENTE) = 'CANAL DIRECTO'
      AND UPPER(ob.MARCA) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
      AND ob.FECHAESTADO >= initial_date -- '2024-06-01'
      --AND ob.rank = 1
    GROUP BY ALL

  );

   --TABLA de líneas de cada orden de Entrega
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` AS(
    SELECT 
        CAST(lo.id_orden AS STRING) AS id_orden
      , 'Entrega' AS tipo_pedido
      , lo.numero_expedicion AS numero_expedicion --Todavía no lo tenemos sin ser HASH
      , lo.reexpedition AS reexpedicion
      , ml.LINEA AS numero_linea
      , ml.NSERIE AS numero_serie
      , CAST(NULL AS STRING) AS numero_serie_ficticio
      , lo.telefono_contacto AS MSISDN
/*
      , CASE WHEN cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1                            THEN 'SIM'
               WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) = 'MANIPULADO'             THEN 'Equipo manipulado + SIM'
               WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PAE')                  THEN 'PAE'
               WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PATINES')              THEN 'PATINETE'
               WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1 AND CUENTA_Papeleria = 1 THEN 'SMART TV+DOCUMENTACION'
               WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 1 THEN 'SMART TV+DOCUMENTACION'
               WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 0 THEN 'SMART TV'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Terminal >= 1    THEN 'TERMINAL'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Tablet >= 1      THEN 'TABLET'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Router >= 1      THEN 'ROUTER'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_MODEM >= 1       THEN 'MODEM'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_STB >= 1         THEN 'STB'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_PATIN >= 1       THEN 'PATINETE'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1    THEN 'SMART TV'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Accesories >= 1  THEN 'ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1    THEN 'ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_SN >= 1      THEN 'PAE'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Papeleria >= 1   THEN 'PAPELERIA'
               WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ONT >= 1         THEN 'ONT'     
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Terminal > 0    THEN 'SIM+TERMINAL'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Tablet > 0      THEN 'SIM+TABLET'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Router > 0      THEN 'SIM+ROUTER'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_MODEM > 0       THEN 'SIM+MODEM'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_STB > 0         THEN 'SIM+STB'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Accesories > 0  THEN 'SIM+ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_IMEI > 0    THEN 'SIM+ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_SN > 0      THEN 'SIM+ACCESORIO'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1   THEN 'SIM+SMART TV'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria > 0   THEN 'SIM+SMART TV+DOCUMENTACION'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Papeleria > 0   THEN 'SIM+PAPELERIA'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ONT > 0         THEN 'SIM+ONT'
               WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  = 0                             THEN 'DISPOSITIVOS'
               WHEN cpm.cuenta_tecnologia IS NULL                                              THEN 'SIN DATOS EN ORDERBOX'
          ELSE 'REVISAR' END AS dispositivo
*/
      , CASE WHEN cpm.cuenta_tecnologia = 1  AND cuenta_SIM >= 1                                                    THEN 'SIM'
            WHEN ml.NSERIE IS NULL AND cuenta_SIM >= 1                                                              THEN 'SIM'
            WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) = 'MANIPULADO'               THEN 'Equipo manipulado + SIM'
            WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PATINES')               THEN 'PATINETE'
            WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1 AND CUENTA_Papeleria = 1   THEN 'SMART TV+DOCUMENTACION'
            WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 1   THEN 'SMART TV+DOCUMENTACION'
            WHEN cpm.cuenta_tecnologia = 2  AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria = 0   THEN 'SMART TV'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_PATIN >= 1                               THEN 'PATINETE'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_SMART_TV >= 1                            THEN 'SMART TV'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1                           THEN 'SIM+SMART TV'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_SMART_TV >= 1 AND CUENTA_Papeleria > 0  THEN 'SIM+SMART TV+DOCUMENTACION'
            --WHEN cpm.cuenta_tecnologia IS NOT NULL AND UPPER(cpm.CUENTA_otros_equipos) IN ('PAE')                  THEN 'PAE'
            WHEN ks.weight > 2 AND ks.weight <= 7                                                                   THEN 'PAE'
            WHEN ks.weight > 7 AND ks.weight <= 18                                                                  THEN 'MAE'
            WHEN ks.weight > 18                                                                                     THEN 'GAE'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Terminal >= 1                            THEN 'TERMINAL'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Tablet >= 1                              THEN 'TABLET'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Router >= 1                              THEN 'ROUTER'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_MODEM >= 1                               THEN 'MODEM'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_STB >= 1                                 THEN 'STB'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Accesories >= 1                          THEN 'ACCESORIO'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_IMEI >= 1                            THEN 'ACCESORIO'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ACC_SN >= 1                              THEN 'PAE'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_Papeleria >= 1                           THEN 'PAPELERIA'
            WHEN cpm.cuenta_tecnologia >= 1 AND cuenta_SIM  = 0 AND CUENTA_ONT >= 1                                 THEN 'ONT'     
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Terminal > 0                            THEN 'SIM+TERMINAL'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Tablet > 0                              THEN 'SIM+TABLET'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Router > 0                              THEN 'SIM+ROUTER'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_MODEM > 0                               THEN 'SIM+MODEM'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_STB > 0                                 THEN 'SIM+STB'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Accesories > 0                          THEN 'SIM+ACCESORIO'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_IMEI > 0                            THEN 'SIM+ACCESORIO'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ACC_SN > 0                              THEN 'SIM+ACCESORIO'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_Papeleria > 0                           THEN 'SIM+PAPELERIA'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  >= 1 AND CUENTA_ONT > 0                                 THEN 'SIM+ONT'
            WHEN cpm.cuenta_tecnologia >= 2 AND cuenta_SIM  = 0                                                     THEN 'DISPOSITIVOS'
            WHEN cpm.cuenta_tecnologia IS NULL                                                                      THEN 'SIN DATOS EN ORDERBOX'
        ELSE 'REVISAR' END AS dispositivo
      , ml.REFERENCIA AS id_modelo
      , ml.DESCRIPCION AS descripcion_modelo
      , ml.REFERENCIAPADRE AS codigo_modelo
      , dn.gross_subsidy_1 AS subsidio 
      , CAST(NULL AS FLOAT64) AS pago_por_contrarrembolso
      , ROUND(dn.cost_with_canon_without_markup,6) AS precio_almacen_sin_imp --es el valor sin impuestos confirmado por Logística
      , ROUND((dn.cost_with_canon_without_markup * IMPUESTOS.valor),6) AS precio_almacen_con_imp --aplicamos impuesto al precio sin impuesto
      , CAST(NULL AS FLOAT64) AS precio_factura
      , CASE WHEN initial_payment > 0 THEN initial_payment
             WHEN initial_payment = 0 AND not_financed_price > 0 THEN not_financed_price
             ELSE 0 END AS pago_inicial  --2025-02-24
      , dn.financed_total_amount AS pago_aplazado
      , dn.q25_amount AS valor_residual
      , kp.impresos AS total_impresos
      , kp.preimpresos AS total_preimpresos
      , CAST (0 AS INTEGER) AS total_color
      , CAST(NULL AS STRING) AS rango_inicial
      , CAST(NULL AS STRING) AS rango_final
      , CAST(NULL AS INT64) AS cantidad
      , ks.weight AS peso
      , CAST(NULL AS INT64) AS unidades_caja
      , CAST(NULL AS INT64) AS unidades_paquete
      , CAST(NULL AS INT64) AS cajas_pallet
      , lo.marca AS marca
      
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo` ml
        ON  ml.ITEMNUMBER = lo.id_orden
        AND ml.RX = lo.reexpedition
      LEFT JOIN  `mm-datamart-kd.DEVICES.device_base_mysim` dn
        ON  dn.item_number = SAFE_CAST(ml.ITEMNUMBER AS INT64)
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation` kp
        ON kp.orderCrmId = lo.id_orden
        AND kp.reexpedition = lo.reexpedition
        AND kp.referencia = ml.REFERENCIA
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped` ks
        ON  ks.orderCrmId = lo.id_orden
        AND ks.reexpedition = lo.reexpedition
        AND ks.expeditionId = lo.numero_expedicion  --ELIMINAMOS DUPLICADOS EN LAS SMART-TV, PORQUE LA DOCUMENTACION LLEVA EXPEDICION DISTINTA --2024/12/12
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  IMPUESTOS.codigo_postal = SUBSTR(lo.codigo_postal,1,2)
      AND IMPUESTOS.fecha_desde BETWEEN CAST(lo.fecha_estado_final AS DATE) AND CAST(lo.fecha_estado_final AS DATE)
    LEFT JOIN `mm-commissions-reporting.TEMP.Contenido_pedido_MASLOLA` cpm
      ON cpm.ITEMNUMBER = lo.id_orden

    WHERE ml.ESTADO IS NOT NULL  --Si no tienen estado, no podemos facturarlo

    QUALIFY ROW_NUMBER() OVER (PARTITION BY lo.id_orden, lo.reexpedition, lo.numero_expedicion, ml.NSERIE ORDER BY dn.cost_with_canon_without_markup DESC, dn.financed_total_amount DESC, dn.gross_subsidy_1 DESC) = 1

    ORDER BY 1,2,3
  );

    --TABLA de líneas de cada orden de Desistimiento
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` AS(
--    SELECT CAST(ob.ITEMNUMBER AS INT64) AS id_orden
--    SELECT CAST(ob.TICKET AS INT64) AS id_orden
    SELECT CAST(ob.TICKET AS STRING) AS id_orden
      , 'Desistimiento' AS tipo_orden
--      , CAST(ob.PEDIDOMM AS STRING) AS numero_expedicion --Todavía no lo tenemos sin ser HASH
      --, ks.expeditionIdExternal AS numero_expedicion --id de Eurologistica  
      , COALESCE(ks.expeditionIdExternal,ks.expeditionId,('DUMMY_'||ob.ticket||'Desistimiento')) AS numero_expedicion --id de Eurologistica  
      , CAST(NULL AS STRING) AS reexpedicion
      , ob.LINEA AS numero_linea
      , ob.NSERIE AS numero_serie
      , CAST(NULL AS STRING) AS numero_serie_ficticio
      , CAST(ob.MSISDN AS STRING) AS MSISDN
      , CASE WHEN gd.dispositivo IS NOT NULL THEN gd.dispositivo
            WHEN SUBSTR(gd.dispositivo,1,4) = '8934' THEN 'SIM'
            WHEN (SELECT MAX (ml.REFERENCIATIPO) FROM `mm-commissions-reporting.TEMP.maslola_canal_directo` ml WHERE ml.NSERIE = ob.NSERIE) IS NOT NULL THEN (SELECT MAX (ml.REFERENCIATIPO) FROM `mm-commissions-reporting.TEMP.maslola_canal_directo` ml WHERE ml.NSERIE = ob.NSERIE)
            ELSE 'Dispositivo' END AS dispositivo
      , dn.product_code AS id_modelo
      , dn.terminal_name AS descripcion_modelo
      , dn.product_code AS codigo_modelo
      , dn.gross_subsidy_1 AS subsidio 
      , CAST(NULL AS FLOAT64) AS pago_por_contrarrembolso
      , ROUND(dn.cost_with_canon_without_markup,6) AS precio_almacen_sin_imp --es el valor sin impuestos (el que figura en OaC)
      , ROUND((dn.cost_with_canon_without_markup * IMPUESTOS.valor),6) AS precio_almacen_con_imp --aplicamos impuesto al precio sin impuesto
      , CAST(NULL AS FLOAT64) AS precio_factura
      , dn.initial_payment AS pago_inicial
      , dn.financed_total_amount AS pago_aplazado
      , dn.q25_amount AS valor_residual
      , kp.impresos AS total_impresos
      , kp.preimpresos AS total_preimpresos
      , CAST (0 AS INTEGER) AS total_color
      , CAST(NULL AS STRING) AS rango_inicial
      , CAST(NULL AS STRING) AS rango_final
      , CAST(NULL AS INT64) AS cantidad
      , ks.weight AS peso
      , CAST(NULL AS INT64) AS unidades_caja
      , CAST(NULL AS INT64) AS unidades_paquete
      , CAST(NULL AS INT64) AS cajas_pallet
      , UPPER(ob.MARCA) AS marca

    FROM `mm-commissions-reporting.TEMP.orderbox_canal_directo` ob
    --INNER JOIN `mm-datamart-kd.SERVICES.devices_base_net` dn   --Habría que ver que pasa con los que no cruzan
    INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` dn 
      ON  dn.item_number = SAFE_CAST(ob.PEDIDOMM AS INT64)
    INNER JOIN `mm-datamart-kd.SERVICES.ventas_base_emysim` be  --Habría que ver que pasa con los que no cruzan
      ON  be.brand_ds = dn.brand_ds
      AND be.customer_id = dn.customer_id
      AND be.service_id = dn.service_id
      AND CAST (be.fecha_baja AS TIMESTAMP) >= ob.FECHACREACION
    LEFT JOIN `mm-datamart-kd.SERVICES.customer_carterizacion` cc
      ON  cc.customer_id = dn.customer_id
      AND cc.brand_ds = be.brand_ds
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped` ks
      ON ks.orderCrmId = CAST(ob.PEDIDOMM AS STRING)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_dispositivo` gd
      ON gd.referencia = ob.REFERENCIATIPO
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_preparation` kp
      ON kp.orderCrmId = CAST(ob.PEDIDOMM AS STRING)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  IMPUESTOS.codigo_postal = SUBSTR(ob.CODIGOPOSTAL,1,2)
      AND IMPUESTOS.fecha_desde BETWEEN CAST(ob.FECHACREACION AS DATE) AND CAST(ob.FECHAESTADO AS DATE)

    WHERE UPPER(ob.TIPOPEDIDOMYSIM) = 'DESISTIMIENTO'
      AND ob.ticket IS NOT NULL
      AND UPPER(ob.OPERADORLOGISTICO) = 'INTERBOX'
      AND UPPER(ob.TIPOCLIENTE) = 'CANAL DIRECTO'
      AND UPPER(ob.MARCA) IN ('PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO') -- ('YOIGO','MASMOVIL')
      AND ob.FECHAESTADO >= initial_date -- '2024-06-01'
      --AND ob.rank = 1

    GROUP BY ALL 
  );

    --TABLA de estados de cada orden de Entrega
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_status_order` AS(
--    SELECT lo.id_orden AS id_orden
    SELECT CAST(lo.id_orden AS STRING) AS id_orden
        , 'Entrega' AS tipo_pedido
        , lo.reexpedition AS reexpedition
        , lo.numero_expedicion AS numero_expedicion --id de Eurologistica  
        --, COALESCE(kf.expeditionIdExternal,kf.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'Entrega')) AS numero_expedicion --id de Eurologistica  
        , ml.ESTADO AS estado
        , ml.FECHAESTADO AS fecha_estado
        , ef.final AS estado_final
        , lo.marca AS marca
    
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
      -- mm-commissions-reporting.TEMP.ORDERS_MASLOLA --
      LEFT JOIN `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` ml   --30/10/2025 Cambiamos `mm-dwh-prod.00_SANDBOX_NETKIA.ORDERS_MASLOLA por netkia_orders_maslola (DDEV-38976)
      --ON SAFE_CAST(ml.ITEMNUMBER AS INT64) = lo.id_orden
      ON ml.ITEMNUMBER = lo.id_orden
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ef
        ON  ef.ESTADO = ml.ESTADO
        AND ef.tipo_pedido = 'Entrega'

    ORDER BY 1,2,5 DESC
  );

    --TABLA de estados de cada orden de Desistimiento
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_status` AS(
    SELECT *
    FROM (
      --PRIMERA PARTE --> SÍ TIENE ESTADO EN KAFKA
--        SELECT li.id_orden AS id_orden
        SELECT CAST(li.id_orden AS STRING) AS id_orden
          , 'Desistimiento' AS tipo_pedido, CAST(NULL AS STRING) AS reexpedicion
          --, 'PENDIENTE' AS numero_expedicion
          , li.numero_expedicion AS numero_expedicion --id de Eurologistica  
          --, kf.expeditionIdExternal AS numero_expedicion --id de Eurologistica
          --, COALESCE(kf.expeditionIdExternal,kf.expeditionId,('DUMMY_'||ob.ticket||'Desistimiento')) AS numero_expedicion --id de Eurologistica  
          , dte.estado AS estado
          , dte.fecha AS fecha_estado
          , ekd.estado_final AS estado_final
          , li.marca AS marca
        FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` li
          INNER JOIN `mm-commissions-reporting.TEMP.desistimiento_tabla_estados` dte
            ON  CAST(dte.pedido AS STRING) = li.pedido_padre
            AND UPPER(dte.marca) = UPPER(li.marca)
            AND dte.ORIGEN_ESTADO = 'KAFKA'
          LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_kafka_desist` ekd
            ON ekd.accion = dte.estado
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped_desestimiento` kf
            ON  kf.orderCrmId = li.id_orden
            --AND kf.serial_number = li.NSERIE

      UNION ALL

      --BUSCAR 2ª PARTE - SI NO TIENE KAFKA, BUSCAR EN ORDERBOX
--        SELECT li.id_orden AS id_orden
        SELECT CAST(li.id_orden AS STRING) AS id_orden
          , 'Desistimiento' AS tipo_pedido, CAST(NULL AS STRING) AS reexpedicion
          --, 'PENDIENTE' AS numero_expedicion
          , li.numero_expedicion AS numero_expedicion --id de Eurologistica  
          --, kf.expeditionIdExternal AS numero_expedicion --id de Eurologistica
          --, COALESCE(kf.expeditionIdExternal,kf.expeditionId,('DUMMY_'||ob.ticket||'Desistimiento')) AS numero_expedicion --id de Eurologistica  
          , dte.estado AS estado
          , dte.fecha AS fecha_estado
          , ef.final AS estado_final
          , li.marca AS marca
        FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` li
          INNER JOIN `mm-commissions-reporting.TEMP.desistimiento_tabla_estados` dte
            ON  CAST(dte.pedido AS STRING) = li.pedido_padre
            AND UPPER(dte.marca) = UPPER(li.marca)
            AND dte.ORIGEN_ESTADO = 'ORDERBOX'
            AND dte.MAS_INFO = 'NO_EXISTE_KAFKA'  --Si ya hemos anotado el estado de KAFKA, no ponemos el de ORDERBOX
          LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ef
            ON ef.estado = dte.estado
          LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped_desestimiento` kf
            ON  kf.orderCrmId = li.id_orden
            --AND kf.serial_number = ob.NSERIE
    )
    WHERE estado IS NOT NULL
    ORDER BY id_orden, fecha_estado ASC, estado_final ASC, estado DESC
  );
/*
      --TABLA de órdenes de SWAP
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` AS(
    SELECT UPPER(ke.tenantByTopic) AS marca
        , SAFE_CAST(subscriptions.orderIdExternal AS STRING) AS id_orden
        , ke.reexpedition AS reexpedition
        , li.LINEA AS numero_lineas
        , CASE WHEN logisticOperation = 'DELIVERY' THEN 'Entrega'
                WHEN logisticOperation = 'PICKUP' THEN 'Desistimiento'
                WHEN logisticOperation = 'SWAP' THEN 'Swap'
          ELSE logisticOperation END AS tipo_pedido
        , CASE WHEN shipping.deliveryType = 'HOME' THEN 'domicilio'
                WHEN shipping.deliveryType = 'SHOP' THEN 'tienda'
                WHEN shipping.deliveryType = 'AGENCY' AND ks.courier = 'CORREOS' THEN 'correos'
                ELSE 'domicilio' END AS tipo_orden
        , 'entrega' AS motivo 
        --, COALESCE(ks.expeditionIdExternal, ks.expeditionId) AS numero_expedicion --id de Eurologistica  
        , COALESCE(ks.expeditionIdExternal,ks.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'Entrega')) AS numero_expedicion --id de Eurologistica  
        , CASE WHEN shipping.address.type = 'SHIPMENT' THEN 'B2C' ELSE shipping.address.type END AS tipo_destinatario
        , logisticsOperator AS operador_logistico
        , ks.courier AS courier
        , ks.service AS servicio
        , CASE  WHEN ml.entregaexclusiva = 'SI' AND ml.entregasegura = 'SI' AND ml.fotodni = 'SI' THEN 'Exclusiva (+ entrega segura + fotodni)'
                WHEN ml.entregaexclusiva = 'SI' AND ml.entregasegura = 'SI' AND ml.fotodni = 'NO' THEN 'Exclusiva (+ entrega segura)'
                WHEN ml.entregaexclusiva = 'SI' AND ml.entregasegura = 'NO' AND ml.fotodni = 'SI' THEN 'Exclusiva (+ fotodni)'
                WHEN ml.entregaexclusiva = 'SI' AND ml.entregasegura = 'NO' AND ml.fotodni = 'NO' THEN 'Exclusiva'
                WHEN ml.entregaexclusiva = 'NO' AND ml.entregasegura = 'SI' AND ml.fotodni = 'SI' THEN 'DNI (entrega segura + fotodni)'
                WHEN ml.entregaexclusiva = 'NO' AND ml.entregasegura = 'SI' AND ml.fotodni = 'NO' THEN 'DNI (entrega segura)'
                WHEN ml.entregaexclusiva = 'NO' AND ml.entregasegura = 'NO' AND ml.fotodni = 'SI' THEN 'fotodni'
                WHEN ml.entregaexclusiva = 'NO' AND ml.entregasegura = 'NO' AND ml.fotodni = 'NO' THEN CAST(NULL AS STRING)
            ELSE 'DESCONOCIDO - REVISAR' END AS identificacion
        , CASE WHEN ml.estado IN ('Entregado','Entregado ANOVO','DOA rechazada. Screening KO') THEN 'Entregado'
               WHEN ml.estado IN ('Cancelado','Cancelado-Anulado') THEN 'Anulado pre-picking'

              WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Devuelto al almacen'
              WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
              WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
              ELSE ml.ESTADO END AS estado_final
        , ml.fechaestado AS fecha_estado_final
        , CASE WHEN ml.SOLICITUDDECANCELACION IS NULL THEN 'NO' ELSE 'SI' END AS cancelacion_solicitada
        , btn.customer_id AS id_cliente
        , subscriptions.subscriptionId AS id_suscripcion
        , ml.retornodac AS retorno_contrato
        , prov.provincia AS provincia
        , cp.codigo_postal AS codigo_postal
        , ml.obscourier AS textos
        , COALESCE(subscriptions.externalId.number,customer.user.contactData.phoneNumber.number) AS telefono_contacto
        , TIMESTAMP_TRUNC(ke.createdDatetime, SECOND) AS fecha_comunicacion
        , ml.fechaestado AS fecha_ultima_actualizacion
        , customer.user.identityDocument.type AS tipo_documento
        , customer.user.identityDocument.number AS documento
        , btn.segment_ds AS tipo_cliente
        , cpm.tipo_dispositivo AS dispositivo
        , CASE WHEN billing_type_ds = 'PREPAID' THEN 'PREPAGO'
                WHEN billing_type_ds = 'POSTPAID' THEN 'POSTPAGO'
          ELSE billing_type_ds END AS categoria_contrato
        , CAST(0 AS INT64) AS total_impresos
        , CAST(0 AS INT64) AS total_preimpresos
        , CAST(NULL AS INTEGER) AS total_color
        , CAST(1 AS INT64) AS total_bultos
        , CAST(0 AS FLOAT64) AS importe_pedido
        , 'NO' AS contrarrembolso
        , CAST (NULL AS INTEGER) AS importe_contrarrembolso
        , ROUND(ks.weight,3) AS total_peso  --HACER
        , COALESCE(btn.master_channel_ds,UPPER(ml.canalventa)) AS canal
        , btn.user_store AS SFID_ID
        , btn.sub_segment_ds AS segmento
        , btn.contract_id AS contrato
        , CASE WHEN ml.estado IN ('Entregado','Entregado ANOVO','DOA rechazada. Screening KO') THEN 'Entregado'
               WHEN ml.estado IN ('Cancelado','Cancelado-Anulado') THEN 'Anulado pre-picking'
                --WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Cancelado postpicking'
               WHEN ml.ESTADO IN ('Cancelado-Devuelto al Almacén') THEN 'Devuelto al almacen'
               WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NULL THEN 'Cancelado postpicking'
               WHEN ml.ESTADO IN ('No Entregado-Devuelto al Almacén','Rechazado Cliente-Devuelto al Almacén','Recibido Interbox','Devuelto almacen') AND ip.FECHAESTADO IS NOT NULL AND sa.FECHAESTADO IS NOT NULL THEN 'Devuelto al almacen'
               ELSE ml.ESTADO END AS estado_final

        --, SAFE_CAST(subscriptions.orderCrmId AS INT64) AS pedido_padre
        , subscriptions.orderCrmId AS pedido_padre
        , dir.direccion AS direccion 

    FROM `mm-dwh-prod.KAFKA_MASLOGISTICS.LOGISTICS_EXPEDITION_CREATED*` ke, UNNEST(subscriptions) subscriptions, UNNEST(devices) devices
      INNER JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo_swap` ml
        ON  ml.id_orden = subscriptions.orderIdExternal --subscriptions.orderCrmId
        AND ml.rx = ke.reexpedition
      LEFT JOIN `mm-commissions-reporting.TEMP.maslola_lineas_swap` li
        ON  li.id_orden = subscriptions.orderIdExternal
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_shipped_swap` ks
        ON  ks.orderCrmId = subscriptions.orderCrmId
        AND ks.reexpedition = ke.reexpedition
        --AND CAST(ks.expeditionId AS STRING) = CAST(ke.expeditionId AS STRING)
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_direccion_swap` dir
        ON  UPPER(dir.marca) = UPPER(ke.tenantByTopic)
        AND dir.id_orden = subscriptions.orderIdExternal
        AND dir.reexpedition = ke.reexpedition
        AND dir.expeditionId = ke.expeditionId
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_codigo_postal_swap` cp
        ON  UPPER(cp.marca) = UPPER(ke.tenantByTopic)
        AND cp.id_orden = subscriptions.orderIdExternal
        AND cp.reexpedition = ke.reexpedition
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_provincia_swap` prov
        ON  UPPER(prov.marca) = UPPER(ke.tenantByTopic)
        AND prov.id_orden = subscriptions.orderIdExternal
        AND cp.reexpedition = ke.reexpedition
      LEFT JOIN `mm-commissions-reporting.TEMP.Contenido_Swap_MASLOLA` cpm
        ON SPLIT(CAST(cpm.ITEMNUMBER AS STRING), '_')[OFFSET(0)] = subscriptions.orderIdExternal
      LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
        ON  btn.phone_nm = CAST(customer.user.contactData.phoneNumber.number AS INTEGER)
        AND UPPER(btn.brand_ds) = UPPER(ke.tenantByTopic)

    WHERE UPPER(ke.logisticsOperator) = 'INTERBOX'
      AND UPPER(ke.logisticOperation) = 'SWAP'
      AND CAST(ke.createdDatetime AS DATE) >= initial_date  -- '2024-05-01'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY subscriptions.orderIdExternal, ke.tenantByTopic, ke.reexpedition ORDER BY ml.fechaestado DESC) = 1
  );


   --TABLA de líneas de cada orden de Swap
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_line` AS(
    SELECT 
        CAST(ls.id_orden AS STRING) AS id_orden
      , 'Swap' AS tipo_pedido
      , ls.numero_expedicion AS numero_expedicion --Todavía no lo tenemos sin ser HASH
      --, COALESCE(ls.expeditionIdExternal,ls.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'Swap')) AS numero_expedicion --id de Eurologistica  
      , ls.reexpedition AS reexpedicion
      , ls.numero_lineas AS numero_linea
      , ml.nserieenvio AS numero_serie
      , CAST(NULL AS STRING) AS numero_serie_ficticio
      , ls.telefono_contacto AS MSISDN
      , ls.dispositivo AS dispositivo
      , ml.referenciaenvio AS id_modelo
      --, CAST(NULL AS STRING) AS id_modelo
      , ml.descripcionenvio AS descripcion_modelo
      --, CAST(NULL AS STRING) AS descripcion_modelo
      , ml.referenciapadreenvio AS codigo_modelo
      --, CAST(NULL AS STRING) AS codigo_modelo
      , dn.gross_subsidy_1 AS subsidio 
      , CAST(NULL AS FLOAT64) AS pago_por_contrarrembolso
      , ROUND(dn.cost_with_canon_without_markup,6) AS precio_almacen_sin_imp --es el valor sin impuestos confirmado por Logística
      , ROUND((dn.cost_with_canon_without_markup * IMPUESTOS.valor),6) AS precio_almacen_con_imp --aplicamos impuesto al precio sin impuesto
      , CAST(NULL AS FLOAT64) AS precio_factura
      , CASE WHEN initial_payment > 0 THEN initial_payment
             WHEN initial_payment = 0 AND not_financed_price > 0 THEN not_financed_price
             ELSE 0 END AS pago_inicial
      , dn.financed_total_amount AS pago_aplazado
      , dn.q25_amount AS valor_residual
      , ls.total_impresos AS total_impresos
      , ls.total_preimpresos AS total_preimpresos
      , CAST (0 AS INTEGER) AS total_color
      , CAST(NULL AS STRING) AS rango_inicial
      , CAST(NULL AS STRING) AS rango_final
      , CAST(NULL AS INT64) AS cantidad
      , ROUND(ls.total_peso,3) AS peso
      , CAST(NULL AS INT64) AS unidades_caja
      , CAST(NULL AS INT64) AS unidades_paquete
      , CAST(NULL AS INT64) AS cajas_pallet
      , ls.marca AS marca     
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ls
      INNER JOIN `mm-commissions-reporting.TEMP.maslola_canal_directo_swap` ml
        ON  ml.id_orden = ls.id_orden
        AND ml.rx = ls.reexpedition
      --LEFT JOIN `mm-datamart-kd.SERVICES.devices_base_net` dn
      LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` dn
        ON  dn.item_number = SAFE_CAST(ml.ITEMNUMBER AS INT64)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  IMPUESTOS.codigo_postal = SUBSTR(ls.codigo_postal,1,2)
      AND IMPUESTOS.fecha_desde BETWEEN CAST(ls.fecha_estado_final AS DATE) AND CAST(ls.fecha_estado_final AS DATE)
    WHERE ml.ESTADO IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ls.id_orden, ls.marca, ls.numero_expedicion ORDER BY ls.numero_expedicion DESC, ml.nserieenvio ASC) = 1
  );

  CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_status_swap` AS(
    SELECT CAST(ls.id_orden AS STRING) AS id_orden
        , 'Swap' AS tipo_pedido
        , ls.reexpedition AS reexpedition
        , ls.numero_expedicion AS numero_expedicion --id de Eurologistica  
        --, COALESCE(ls.expeditionIdExternal,ls.expeditionId,('DUMMY_'||subscriptions.orderCrmId||'Swap')) AS numero_expedicion --id de Eurologistica  
        , nnom.ESTADO AS estado
        , nnom.FECHAESTADO AS fecha_estado
        , ef.final AS estado_final
        , ls.marca AS marca   
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ls
      --LEFT JOIN `mm-datamart-kd.LOGISTICS.new_netkia_orders_maslola` nnom
      LEFT JOIN `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` nnom
        ON  nnom.tipopedidomysim = 'SWAP'
        AND (nnom.itemnumber = ls.id_orden
          OR nnom.itemnumber = CONCAT(ls.id_orden,'_TIY'))
        AND CASE WHEN nnom.rx IS NULL THEN ls.reexpedition = 'R0' ELSE nnom.rx = ls.reexpedition END
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ef
        ON  ef.ESTADO = nnom.ESTADO
        AND ef.tipo_pedido = 'Swap'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ls.id_orden, ls.marca, ls.numero_expedicion, nnom.ESTADO ORDER BY nnom.FECHAESTADO DESC, ls.numero_expedicion DESC) = 1
    ORDER BY 1,2,5 DESC
  );
*/
END