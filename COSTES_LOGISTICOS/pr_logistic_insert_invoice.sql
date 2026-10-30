BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_insert_invoice`(202602)

--  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_interbox_202601_v5` as
--  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_interbox` as
--  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_interbox_202602_v2` as

  INSERT INTO `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_interbox` 
  (
    SELECT *
    FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_complete`
    WHERE id_mes = CAST(pr_mes AS STRING)
    QUALIFY ROW_NUMBER () OVER (PARTITION BY id_mes, MARCA, Order_No, Estado, Tipo_evento_logistico ORDER BY Total_Coste_Man_y_Trans DESC) = 1
  );

--  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_quiero_IB_202602_v2` as
--  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_quiero_IB` as
   INSERT INTO `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_autofactura_quiero_IB`
   (
    SELECT * 
    FROM `mm-logistics-reporting.LOG_FACTURACION.43_logistic_costs_quiero`
    WHERE id_mes = pr_mes
   );

END