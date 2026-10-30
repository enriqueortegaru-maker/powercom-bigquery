BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order`()

  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` AS
  (
    SELECT 
        marca
      , id_orden
      , reexpedition AS reexpedicion
      , numero_lineas
      , tipo_pedido
      , tipo_orden
      , motivo
      , numero_expedicion
      , tipo_destinatario
      , operador_logistico
      , courier
      , servicio
      , identificacion
      , estado_final
      , CAST(fecha_estado_final AS DATE) AS fecha_estado_final
      , cancelacion_solicitada
      , id_cliente
      , id_suscripcion
      , retorno_contrato
      , provincia
      , codigo_postal
      , Textos
      , telefono_contacto
      , fecha_comunicacion
      , CAST(fecha_ultima_actualizacion AS DATE) AS fecha_ultima_actualizacion
      , * EXCEPT (marca
                  , id_orden, reexpedition, numero_lineas, tipo_pedido, tipo_orden, motivo, numero_expedicion
                  , tipo_destinatario, operador_logistico, courier, servicio, identificacion, estado_final, fecha_estado_final, cancelacion_solicitada
                  , id_cliente, id_suscripcion, retorno_contrato, provincia, codigo_postal, Textos, telefono_contacto, fecha_comunicacion, fecha_ultima_actualizacion, SFID_ID)
      , SFID_ID AS SFID_ID
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order`

    UNION ALL

    SELECT 
        marca
      , id_orden
      , rexpedicion AS reexpedicion
      , numero_lineas
      , tipo_pedido
      , tipo_orden
      , motivo_orden AS motivo
      , numero_expedicion
      , tipo_destinatario
      , operador_logistico
      , courier
      , servicio
      , identificacion
      , estado_final
      , fecha_estado_final AS fecha_estado_final
      , cancelacion_solicitada
      , id_cliente
      , id_suscripcion
      , retorno_contrato
      , provincia
      , codigo_postal
      , Textos
      , CAST(telefono_contacto AS STRING) AS telefono_contacto
        , fecha_comunicacion
      , CAST(fecha_ultima_actualizacion AS DATE) AS fecha_ultima_actualizacion
      , * EXCEPT (marca
                  , id_orden, rexpedicion, numero_lineas, tipo_pedido, tipo_orden, motivo_orden, numero_expedicion
                  , tipo_destinatario, operador_logistico, courier, servicio, identificacion, estado_final, fecha_estado_final, cancelacion_solicitada
                  , id_cliente, id_suscripcion, retorno_contrato, provincia, codigo_postal, Textos, telefono_contacto, fecha_comunicacion, fecha_ultima_actualizacion, SFID_ID_VBN)
      , SFID_ID_VBN AS SFID_ID
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` 
/*
    UNION ALL

    SELECT
        marca
      , id_orden
      , reexpedition AS reexpedicion
      , numero_lineas
      , tipo_pedido
      , tipo_orden
      , motivo AS motivo_orden
      , numero_expedicion
      , tipo_destinatario
      , operador_logistico
      , courier
      , servicio
      , identificacion
      , estado_final
      , CAST(fecha_estado_final AS DATE) AS fecha_estado_final
      , cancelacion_solicitada
      , id_cliente
      , id_suscripcion
      , retorno_contrato
      , provincia
      , codigo_postal
      , Textos
      , CAST(telefono_contacto AS STRING) AS telefono_contacto
      , fecha_comunicacion
      , CAST(fecha_ultima_actualizacion AS DATE) AS fecha_ultima_actualizacion
      , * EXCEPT (marca
                  , id_orden, reexpedition, numero_lineas, tipo_pedido, tipo_orden, motivo, numero_expedicion
                  , tipo_destinatario, operador_logistico, courier, servicio, identificacion, estado_final, fecha_estado_final, cancelacion_solicitada
                  , id_cliente, id_suscripcion, retorno_contrato, provincia, codigo_postal, Textos, telefono_contacto, fecha_comunicacion, fecha_ultima_actualizacion, SFID_ID)
      , SFID_ID AS SFID_ID
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap`
*/ 
/*
    UNION ALL

    SELECT
        marca
      , SAFE_CAST(id_orden AS INT64) AS id_orden
      , rexpedicion AS reexpedicion
      , numero_lineas
      , tipo_pedido
      , tipo_orden
      , motivo_orden
      , numero_expedicion
      , tipo_destinatario
      , operador_logistico
      , courier
      , servicio
      , identificacion
      , estado_final
      , fecha_estado_final AS fecha_estado_final
      , cancelacion_solicitada
      , id_cliente
      , id_suscripcion
      , retorno_contrato
      , provincia
      , codigo_postal
      , Textos
      , CAST(telefono_contacto AS STRING) AS telefono_contacto
      , * EXCEPT (marca
                  --, id_master, Master, RMA
                  , id_orden, rexpedicion, numero_lineas, tipo_pedido, tipo_orden, motivo_orden, numero_expedicion
                  , tipo_destinatario, operador_logistico, courier, servicio, identificacion, estado_final, fecha_estado_final, cancelacion_solicitada
                  , id_cliente, id_suscripcion, retorno_contrato, provincia, codigo_postal, Textos, telefono_contacto)
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_cancelacion`
*/
  );

END