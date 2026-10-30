BEGIN

DECLARE fecha_inicio_real DATE;
DECLARE fecha_fin_real DATE;
DECLARE fecha_inicio_estima_1 DATE;
DECLARE fecha_fin_estima_1 DATE;
DECLARE fecha_inicio_estima_2 DATE;
DECLARE fecha_fin_estima_2 DATE;
DECLARE fecha_inicio_estima_3 DATE;
DECLARE fecha_fin_estima_3 DATE;
--DECLARE dias_estimacion INT64;

DECLARE fecha_inicio_estima_extra1 DATE;
DECLARE fecha_fin_estima_extra1 DATE;
DECLARE fecha_inicio_estima_extra2 DATE;
DECLARE fecha_fin_estima_extra2 DATE;
DECLARE fecha_inicio_estima_extra3 DATE;
DECLARE fecha_fin_estima_extra3 DATE;

SET fecha_inicio_real = '2025-04-01';        --Primer día de datos reales
SET fecha_fin_real = '2025-04-13';           --Último día de datos reales
SET fecha_inicio_estima_1 = '2025-04-08';  --Estima desde el 22
SET fecha_fin_estima_1 = '2025-04-13';     --Estima hasta el 27
SET fecha_inicio_estima_2 = '2025-04-08';  --Estima desde el 28
SET fecha_fin_estima_2 = '2025-04-10';     --Estima hasta el 30
SET fecha_inicio_estima_3 = '2025-04-08';  --Estima desde el 21
SET fecha_fin_estima_3 = '2025-04-08';     --Estima hasta el 21
--SET dias_estimacion = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion, DAY)+1);

SET fecha_inicio_estima_extra1 = '2025-04-08';  --Estima desde lunes santo
SET fecha_fin_estima_extra1 = '2025-04-10';     --Estima hasta miercoles santo
SET fecha_inicio_estima_extra2 = '2025-04-06';  --Estima jueves, viernes y domingo santo
SET fecha_fin_estima_extra2 = '2025-04-06';     --Estima jueves, viernes y domingo santo
SET fecha_inicio_estima_extra3 = '2025-04-05';  --Estima sabado santo
SET fecha_fin_estima_extra3 = '2025-04-05';     --Estima sabado santo

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_provi_sem_santa_25`();

select lo.marca, lo.fecha_estado_final, FORMAT_DATE('%A',lo.fecha_estado_final) as dia_semana
  , 'REAL' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final >= fecha_inicio_real
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 14) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 14)) as dia_semana
  , 'ESTIMADO_1' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_1 and fecha_fin_estima_1
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 20) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 20)) as dia_semana
  , 'ESTIMADO_2' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_2 and fecha_fin_estima_2
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 13) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 13)) as dia_semana
  , 'ESTIMADO_3' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_3 and fecha_fin_estima_3
  and lc.coste_sin_imp is not null
group by all
UNION ALL

select lo.marca, (lo.fecha_estado_final + 6) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 6)) as dia_semana
  , 'ESTIMADO_L_M' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_extra1 and fecha_fin_estima_extra1
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 11) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 11)) as dia_semana
  , 'ESTIMADO_J_SANTO' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_extra2 and fecha_fin_estima_extra2
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 12) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 12)) as dia_semana
  , 'ESTIMADO_V_SANTO' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_extra2 and fecha_fin_estima_extra2
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 13) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 13)) as dia_semana
  , 'ESTIMADO_D_SANTO' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_extra2 and fecha_fin_estima_extra2
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + 14) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + 14)) as dia_semana
  , 'ESTIMADO_S_SANTO' as tipo_calculo, lo.fecha_estado_final as fecha_calculo
  , lc.tipo_coste, lc.codigo_coste, round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
--    and lc.tipo_coste in ('FINANCE','PAYMENT','SUBSIDIO')  -- Tomamos solo costes de terminal
    and lc.codigo_coste in ('T - CUOTAS')  -- Tomamos solo cuotas mensuales. Dejamos fuera ('T - VALOR_RESIDUAL','T - PAGO_INICIAL','T - SUBSIDIO')
where lo.fecha_estado_final between fecha_inicio_estima_extra2 and fecha_fin_estima_extra2
  and lc.coste_sin_imp is not null
group by all

order by 1,2;

END