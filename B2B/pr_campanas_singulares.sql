BEGIN

  --CALL `mm-commissions-reporting.B2B.pr_campanas_singulares`();

  --Creamos las fechas
  DECLARE fecha_actual DATE;
  DECLARE inicio_mes_liquidacion DATE;
  DECLARE fin_mes_liquidacion DATE;
  DECLARE inicio_mes_clawback DATE;
  DECLARE fin_mes_clawback DATE;
  DECLARE id_mes_liquidacion INT64;

      --Damos valor a las fechas
  --SET fecha_actual = '2025-08-12'  --Para simular que estamos en agosto y calcular lo de julio
  SET fecha_actual = CURRENT_DATE();
  SET inicio_mes_liquidacion = DATE_TRUNC(DATE_SUB(fecha_actual,INTERVAL (SAFE_CAST(SUBSTRING(CAST(fecha_actual AS STRING),9,2) AS INT64)) DAY), MONTH);
  SET fin_mes_liquidacion = LAST_DAY(inicio_mes_liquidacion, MONTH);
  SET inicio_mes_clawback =  DATE_SUB(inicio_mes_liquidacion, INTERVAL 12 MONTH);
  SET fin_mes_clawback = LAST_DAY((DATE_SUB(inicio_mes_liquidacion, INTERVAL 1 MONTH)), MONTH);
  SET id_mes_liquidacion = SAFE_CAST(CONCAT(SUBSTRING(CAST(inicio_mes_liquidacion AS STRING),1,4),SUBSTRING(CAST(inicio_mes_liquidacion AS STRING),6,2)) AS INT64);

    --Llamamos a las campañas
  CALL `mm-commissions-reporting.B2B.pr_campana_2974`(inicio_mes_liquidacion, fin_mes_liquidacion, inicio_mes_clawback, fin_mes_clawback, id_mes_liquidacion);
  CALL `mm-commissions-reporting.B2B.pr_campana_3403`(inicio_mes_liquidacion, fin_mes_liquidacion, inicio_mes_clawback, fin_mes_clawback, id_mes_liquidacion);

END