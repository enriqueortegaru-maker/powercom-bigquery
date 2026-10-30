BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.VENTAS_CARTERA` AS
  Select distinct *
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e;
  

END