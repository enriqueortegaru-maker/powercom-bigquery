BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order_status`()

  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_status` AS
  (
    SELECT id_orden, tipo_pedido, reexpedition, numero_expedicion, estado, CAST(fecha_estado AS DATETIME) AS fecha_estado, estado_final
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_status_order`

    UNION ALL

    SELECT id_orden, tipo_pedido, reexpedicion AS reexpedition, numero_expedicion, estado, CAST(fecha_estado AS DATETIME) AS fecha_estado, estado_final
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_status`

    UNION ALL

    SELECT id_orden, tipo_pedido, reexpedition AS reexpedition, numero_expedicion, estado, CAST(fecha_estado AS DATETIME) AS fecha_estado, estado_final
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_status_swap`

  );

END