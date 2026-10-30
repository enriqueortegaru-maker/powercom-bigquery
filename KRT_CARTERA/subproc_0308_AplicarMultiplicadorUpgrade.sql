BEGIN

    --- PASO 1: Creo tabla BONOS_TELEVENTAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS` AS
    SELECT a.*, importe * coalesce(multiplicador_upg, 1) importe_nivel
    FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
    ON UPPER(a.marca_ds) = c.marca_ds AND a.campana_id = c.campana_id AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1 = 1 ELSE a.nombre_distribuidor = c.nombre_distribuidor END;


    --- PASO 2: Creo tabla LOG
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0308_BONOS_TELEVENTAS` AS 
    SELECT *
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`;
  

  END