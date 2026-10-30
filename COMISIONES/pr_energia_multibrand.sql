BEGIN

-------------------------------------------------------------
-- Procedimiento que calcula todos los actos comerciales de energía, independientemente del canal
-------------------------------------------------------------

-- CALL `mm-commissions-reporting.COMISIONES.pr_energia_multibrand`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.energia_multibrand` AS

  SELECT cups_code,* EXCEPT(cups_code)
  FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity`
  WHERE activation_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))
    AND tenant_code in ('jazztel','orange','symio')
    AND cups_code NOT IN (
      SELECT DISTINCT Servicio
      FROM `mm-commissions-reporting.TEMP.thadea_informe_detalle`
      WHERE CONCEPTO like '%ALTA_LUZ%'
    )
  ;

END