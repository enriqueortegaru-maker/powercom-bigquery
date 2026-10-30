BEGIN

--DECLARE initial_date DATE;
--DECLARE brands STRING;

--SET initial_date = '2025-09-01';
--SET brands = "'PEPEPHONE','LEBARA','MASMOVIL','MARBLANCA','SWENO','JOI','LLAMAYA','GUUK','LYCAMOBILE','PARLEM','ALTERNA','YOIGO'";

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_main`();

    --Crea las tablas temporales necesarias para comenzar el proceso
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_preparation`(initial_date); --,brands); 
    --Crea las tablas locales en mm-commissions-reporting.COSTES_LOGISTICOS
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_creation`(initial_date); --,brands);
    --Crea las tablas en mm-logistics-reporting.LOG_FACTURACION
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order`();
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order_line`();
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order_status`();
    --Cambiamos vistas por tablas temporales, para hacer la gestión de incidencias/postprocesos y mejorar en rendimiento 
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_vistas_temp`(initial_date);
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_postprocessing`();
    --Calcula los costes en las tablas locales en mm-commissions-reporting.COSTES_LOGISTICOS
    --Ejecuta pr_logistic_temp
    -- Y crea las tablas de costes en mm-logistics-reporting.LOG_FACTURACION
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order_costs`();
  --Generamos las tablas temporales para las facturas
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_temp`();
    --Crea las tablas de facturacion en mm-logistics-reporting.LOG_FACTURACION
  CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_invoice`();

END