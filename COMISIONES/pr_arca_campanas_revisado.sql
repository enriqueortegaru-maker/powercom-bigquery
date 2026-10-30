BEGIN

DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'CABCAMP3'; 
SET canales_pr = ['CM','CALT'];

-- call `mm-commissions-reporting.COMISIONES.pr_arca_campanas_revisado`(202608,['CM','CALT'])

-- Extraemos la info/ tipologia de las campañas de la Gs de Cablemovil

CALL `mm-commissions-reporting.B2B.pr_campanas_base_general`(mes_int, ['CM','CALT']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CABCAMP3_B_CARTERA` AS (

  SELECT services.*

  FROM `mm-commissions-reporting.B2B.upfronts_base_arca_*` upfr_base --no esta muy fino como base

  LEFT JOIN `mm-commissions-reporting.TEMP.services_base_net_agrupado_CM` services
    ON CONCAT(CAST(upfr_base.phone_nm AS STRING),'-',upfr_base.activation_date) = CONCAT(CAST(services.phone_nm AS STRING),'-',services.activation_date)

  WHERE _TABLE_SUFFIX = CONCAT(mes_string,'01')
    AND (services.deactivation_date IS NULL OR services.deactivation_date = '9999-12-31'
            OR services.deactivation_date > DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH))
            -- AND upfr_base.phone_nm = 698950336

);



END