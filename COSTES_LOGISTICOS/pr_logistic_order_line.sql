BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order_line`()

  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` AS
  (
    SELECT *
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line`

    UNION ALL

    SELECT *
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line`
/*
    UNION ALL

    SELECT *
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_line`
*/
  );

END