BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_provision`();

DECLARE fecha_inicio_real DATE;
DECLARE fecha_fin_real DATE;
DECLARE fecha_inicio_estimacion DATE;
DECLARE fecha_fin_estimacion DATE;
DECLARE dias_estimacion INT64;
DECLARE fecha_inicio_estimacion_2 DATE;
DECLARE fecha_fin_estimacion_2 DATE;
DECLARE dias_estimacion_2 INT64;
DECLARE fecha_inicio_estimacion_3 DATE;
DECLARE fecha_fin_estimacion_3 DATE;
DECLARE dias_estimacion_3 INT64;
DECLARE fecha_inicio_estimacion_4 DATE;
DECLARE fecha_fin_estimacion_4 DATE;
DECLARE dias_estimacion_4 INT64;
DECLARE fecha_inicio_estimacion_5 DATE;
DECLARE fecha_fin_estimacion_5 DATE;
DECLARE dias_estimacion_5 INT64;

SET fecha_inicio_real = '2025-12-01';        --Primer día de datos reales
SET fecha_fin_real = '2025-12-14';           --Último día de datos reales
SET fecha_inicio_estimacion = '2025-12-01';  --Primer día que tomamos de datos estimados
SET fecha_fin_estimacion = '2025-12-05';     --Último día que tomamos de datos estimados
SET dias_estimacion = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion, DAY)+1);
SET fecha_inicio_estimacion_2 = '2025-12-13';  --Primer día que tomamos de datos estimados
SET fecha_fin_estimacion_2 = '2025-12-14';     --Último día que tomamos de datos estimados
SET dias_estimacion_2 = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion_2, DAY)+6);
SET fecha_inicio_estimacion_3 = '2025-12-01';  --Primer día que tomamos de datos estimados
SET fecha_fin_estimacion_3 = '2025-12-02';     --Último día que tomamos de datos estimados
SET dias_estimacion_3 = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion_2, DAY)+20);
SET fecha_inicio_estimacion_4 = '2025-12-12';  --Primer día que tomamos de datos estimados
SET fecha_fin_estimacion_4 = '2025-12-14';     --Último día que tomamos de datos estimados
SET dias_estimacion_4 = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion_2, DAY)+13);
SET fecha_inicio_estimacion_5 = '2025-12-01';  --Primer día que tomamos de datos estimados
SET fecha_fin_estimacion_5 = '2025-12-02';     --Último día que tomamos de datos estimados
SET dias_estimacion_5 = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion_2, DAY)+27);

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_provision`();

SELECT lo.marca, lo.fecha_estado_final, FORMAT_DATE('%A',lo.fecha_estado_final) AS dia_semana
  , 'REAL' AS tipo_calculo, lo.fecha_estado_final AS fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp, ROUND(SUM(coste_con_imp),2) AS coste_con_imp
FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  LEFT JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    ON  lc.id_orden = lo.id_orden
    AND lc.tipo_pedido = lo.tipo_pedido
    AND lc.marca = lo.marca 
--    AND lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    AND lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
--    AND lc.codigo_coste like '%CUOTAS%'
WHERE lo.fecha_estado_final BETWEEN fecha_inicio_real AND fecha_fin_real
  AND lc.coste_sin_imp is not null
GROUP BY ALL

UNION ALL

SELECT lo.marca, (lo.fecha_estado_final + dias_estimacion) AS fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + dias_estimacion)) AS dia_semana
  , 'ESTIMADO' AS tipo_calculo, lo.fecha_estado_final AS fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp, ROUND(SUM(coste_con_imp),2) AS coste_con_imp 
FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  LEFT JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    ON  lc.id_orden = lo.id_orden
    AND lc.tipo_pedido = lo.tipo_pedido
    AND lc.marca = lo.marca 
--    AND lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    AND lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
--    AND lc.codigo_coste like '%CUOTAS%'
WHERE lo.fecha_estado_final BETWEEN fecha_inicio_estimacion AND fecha_fin_estimacion
  AND lc.coste_sin_imp is not null
GROUP BY ALL

UNION ALL

SELECT lo.marca, (lo.fecha_estado_final + dias_estimacion_2) AS fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + dias_estimacion_2)) AS dia_semana
  , 'ESTIMADO' AS tipo_calculo, lo.fecha_estado_final AS fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp, ROUND(SUM(coste_con_imp),2) AS coste_con_imp 
FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  LEFT JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    ON  lc.id_orden = lo.id_orden
    AND lc.tipo_pedido = lo.tipo_pedido
    AND lc.marca = lo.marca 
--    AND lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    AND lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
--    AND lc.codigo_coste like '%CUOTAS%'
WHERE lo.fecha_estado_final BETWEEN fecha_inicio_estimacion_2 AND fecha_fin_estimacion_2
  AND lc.coste_sin_imp is not null
GROUP BY ALL

UNION ALL

SELECT lo.marca, (lo.fecha_estado_final + dias_estimacion_3) AS fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + dias_estimacion_3)) AS dia_semana
  , 'ESTIMADO' AS tipo_calculo, lo.fecha_estado_final AS fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp, ROUND(SUM(coste_con_imp),2) AS coste_con_imp 
FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  LEFT JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    ON  lc.id_orden = lo.id_orden
    AND lc.tipo_pedido = lo.tipo_pedido
    AND lc.marca = lo.marca 
--    AND lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    AND lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
--    AND lc.codigo_coste like '%CUOTAS%'
WHERE lo.fecha_estado_final BETWEEN fecha_inicio_estimacion_3 AND fecha_fin_estimacion_3
  AND lc.coste_sin_imp is not null
GROUP BY ALL

UNION ALL

SELECT lo.marca, (lo.fecha_estado_final + dias_estimacion_4) AS fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + dias_estimacion_4)) AS dia_semana
  , 'ESTIMADO' AS tipo_calculo, lo.fecha_estado_final AS fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp, ROUND(SUM(coste_con_imp),2) AS coste_con_imp 
FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  LEFT JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    ON  lc.id_orden = lo.id_orden
    AND lc.tipo_pedido = lo.tipo_pedido
    AND lc.marca = lo.marca 
--    AND lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    AND lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
--    AND lc.codigo_coste like '%CUOTAS%'
WHERE lo.fecha_estado_final BETWEEN fecha_inicio_estimacion_4 AND fecha_fin_estimacion_4
  AND lc.coste_sin_imp is not null
GROUP BY ALL

UNION ALL

SELECT lo.marca, (lo.fecha_estado_final + dias_estimacion_5) AS fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + dias_estimacion_5)) AS dia_semana
  , 'ESTIMADO' AS tipo_calculo, lo.fecha_estado_final AS fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp, ROUND(SUM(coste_con_imp),2) AS coste_con_imp 
FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  LEFT JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    ON  lc.id_orden = lo.id_orden
    AND lc.tipo_pedido = lo.tipo_pedido
    AND lc.marca = lo.marca 
--    AND lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    AND lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
--    AND lc.codigo_coste like '%CUOTAS%'
WHERE lo.fecha_estado_final BETWEEN fecha_inicio_estimacion_5 AND fecha_fin_estimacion_5
  AND lc.coste_sin_imp is not null
GROUP BY ALL

ORDER BY 1,2;

END