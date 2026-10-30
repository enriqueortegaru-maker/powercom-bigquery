BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_costs_provision`();

DECLARE fecha_inicio_real DATE;
DECLARE fecha_fin_real DATE;
DECLARE fecha_inicio_estimacion DATE;
DECLARE fecha_fin_estimacion DATE;
DECLARE dias_estimacion INT64;
SET fecha_inicio_real = '2025-09-01';        --Primer día de datos reales
SET fecha_fin_real = '2025-09-16';           --Último día de datos reales
SET fecha_inicio_estimacion = '2025-09-03';  --Primer día que tomamos de datos estimados
SET fecha_fin_estimacion = '2025-09-16';     --Último día que tomamos de datos estimados
SET dias_estimacion = (DATE_DIFF(fecha_fin_real,fecha_inicio_estimacion, DAY)+1);

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_main`();  --ACTIVAR ANTES DE EJECUTAR PROVISIÓN COMPLETA

select lo.marca, lo.fecha_estado_final, FORMAT_DATE('%A',lo.fecha_estado_final) as dia_semana
  , 'REAL' as tipo_calculo, lo.fecha_estado_final as fecha_calculo, lc.tipo_coste
--  , lc.codigo_coste
  , round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
    and lc.tipo_coste in ('LOGISTICO')  
where lo.fecha_estado_final between fecha_inicio_real and fecha_fin_real
  and lc.coste_sin_imp is not null
group by all

UNION ALL

select lo.marca, (lo.fecha_estado_final + dias_estimacion) as fecha_estado_final, FORMAT_DATE('%A',(lo.fecha_estado_final + dias_estimacion)) as dia_semana
  , 'ESTIMADO' as tipo_calculo, lo.fecha_estado_final as fecha_calculo, lc.tipo_coste
--  , lc.codigo_coste
  , round(sum(coste_sin_imp),2) as coste_sin_imp, round(sum(coste_con_imp),2) as coste_con_imp 
from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  left join `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` lc
    on  lc.id_orden = lo.id_orden
    and lc.tipo_pedido = lo.tipo_pedido
    and lc.marca = lo.marca 
    and lc.tipo_coste in ('LOGISTICO')  
where lo.fecha_estado_final between fecha_inicio_estimacion and fecha_fin_estimacion
  and lc.coste_sin_imp is not null
group by all

order by 1,2;

END