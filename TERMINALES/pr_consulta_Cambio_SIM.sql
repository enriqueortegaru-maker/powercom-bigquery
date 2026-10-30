BEGIN

DECLARE initial_date DATE;
DECLARE end_date DATE;

SET initial_date = '2026-05-01';
SET end_date = '2026-05-31';

--CALL `mm-commissions-reporting.TERMINALES.pr_consulta_Cambio_SIM`();

SELECT *
FROM (
SELECT a.msisdn AS MSISDN, a.user_store AS SFID, a.min_fecha_alta AS EVENT_DATE, a.iccid AS ICC
FROM `mm-datamart-kd.SERVICES.personal_icc_base`  a
  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base_net` b
  ON a.service_id =b.service_id AND b.activation_date<> a.min_fecha_alta
WHERE min_fecha_alta >= initial_date
  AND min_fecha_alta <= end_date
  AND a.brand_ds='YOIGO'
  AND a.change_reason='REEMPLAZO'
  AND (a.user_store LIKE 'LB%'
    OR a.user_store LIKE 'LM%'
    OR a.user_store LIKE 'LY%'
    OR a.user_store LIKE 'MP%'
    OR a.user_store LIKE 'AX%'
    OR a.user_store LIKE 'BY%'
    OR a.user_store LIKE 'DX%'
    OR a.user_store LIKE 'KH%'
    OR a.user_store LIKE 'MD%'
    OR a.user_store LIKE 'TA%'
    OR a.user_store LIKE 'ME%'  --incluido para 202601
    OR a.user_store LIKE 'ML%'  --incluido para 202601
    OR a.user_store LIKE 'MY%'  --incluido para 202601
    OR a.user_store LIKE 'MB%'  --incluido para 202601
  )
  AND a.user_store != 'LB'
  AND a.user_store != 'LM'
  AND a.user_store != 'LY'
  AND a.user_store != 'MP'
  AND a.user_store != 'AX'
  AND a.user_store != 'BY'
  AND a.user_store != 'DX'
  AND a.user_store != 'KH'
  AND a.user_store != 'MD'
  AND a.user_store != 'TA'
  AND a.user_store != 'ME'
  AND a.user_store != 'ML'
  AND a.user_store != 'MY'
  AND a.user_store != 'MB'
)
GROUP BY 1,2,3,4
ORDER BY 4,3;

END