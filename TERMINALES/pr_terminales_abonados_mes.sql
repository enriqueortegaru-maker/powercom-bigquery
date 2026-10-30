BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_terminales_abonados_mes`(202608);

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_abonados_mes`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 10 DAY)) AS

    SELECT  IMEI, order_id, zona_fiscal, agrupacion_canal, canal, ROUND(SUM(comision),2) as importe
    FROM `mm-commissions-reporting.TERMINALES.TERMINALES`
    WHERE IMEI IN(
      select distinct IMEI
      from `mm-commissions-reporting.TERMINALES.TERMINALES`
      where id_mes = MES_PR
        and process_code in ('REAL','AJUS_MANUAL')
        and tipo_concepto IN ('FINT','SUBS','SRCI')
    )
      AND tipo_concepto IN ('FINT','SUBS','SRCI')
      AND process_code IN ('REAL','AJUS_MANUAL')
    GROUP BY ALL
    HAVING importe <> 0;

END