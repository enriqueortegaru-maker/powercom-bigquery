BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_TERMINALES` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_ter_eventos_terminales`();

END