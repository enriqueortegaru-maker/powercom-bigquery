BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_vistas_temp`('2025-09-01');

--CREA TABLAS TEMPORALES UTILIZADAS EN EL PROCESO

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.SIM_counter`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT LINE.id_orden, LINE.reexpedicion,  COUNT(1) AS Sim 
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE 
    WHERE UPPER(LINE.dispositivo) IN ('SIM')
    GROUP BY 1,2;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Pae_counter`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT LINE.id_orden, LINE.reexpedicion,  COUNT(1) AS Pae
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE 
    WHERE UPPER(LINE.dispositivo) IN ('PAE')
    GROUP BY 1,2;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Patin_counter`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT LINE.id_orden, LINE.reexpedicion,  COUNT(1) AS Patin
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE 
    WHERE UPPER(LINE.dispositivo) IN ('PATINETE')
    GROUP BY 1,2;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TV_counter`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT LINE.id_orden, LINE.reexpedicion,  COUNT(1) AS TV
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE 
    WHERE UPPER(LINE.dispositivo) IN ('SMART_TV','SMART TV','SMART TV+DOCUMENTACION')
    GROUP BY 1,2;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Term_counter`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT LINE.id_orden, LINE.reexpedicion,  COUNT(1) AS Term 
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE 
    WHERE UPPER(LINE.dispositivo) NOT IN ('SIM','PAE','PATINETE','SMART_TV','SMART TV','SMART TV+DOCUMENTACION','DOCUMENTACION SMART TV') OR LINE.dispositivo IS NULL
    GROUP BY 1,2;

  --LISTADO DE SIMs CON PEDIDO PADRE
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pedidos_SIM`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT pedido_padre, numero_expedicion, marca, count(1) as n_SIMs_ped_padre
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` 
    WHERE dispositivo = 'SIM'
      AND pedido_padre IS NOT NULL
    GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.LISTA_IMEIS_MODELOS`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT *
    FROM (
      SELECT numero_serie, LINEAS.id_modelo
      FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
      WHERE numero_serie IS NOT NULL
      GROUP BY ALL 

      UNION ALL

      SELECT numero_serie, LINEAS.id_modelo
      FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      WHERE numero_serie IS NOT NULL
      GROUP BY ALL 

      UNION ALL

      SELECT numero_serie, LINEAS.id_modelo
      FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_line` LINEAS
      WHERE numero_serie IS NOT NULL
      GROUP BY ALL 
    )
    QUALIFY ROW_NUMBER() OVER (PARTITION BY numero_serie ORDER BY id_modelo DESC) = 1
    ORDER BY 1;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pedidos_varios_dispositivos`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT pedido_padre, id_orden, reexpedicion, dispositivo, numero_lineas, estado_final, fecha_estado_final, nom.idol, nom.ot
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
      --LEFT JOIN `mm-datamart-kd.LOGISTICS.new_netkia_orders_maslola` nom
      LEFT JOIN `mm-datamart-kd.LOGISTICS.netkia_orders_maslola` nom
        ON  nom.itemnumber = lo.id_orden
        AND CASE WHEN nom.rx IS NULL THEN lo.reexpedicion = 'R0' ELSE UPPER (nom.rx) = UPPER (lo.reexpedicion) END
        AND nom.idol NOT IN ('0')
        AND nom.idol IS NOT NULL
    WHERE lo.tipo_pedido = 'Entrega'
      AND dispositivo IN ('STB','ACCESORIO','ROUTER')   
      AND numero_lineas >= 2
      AND fecha_estado_final >= initial_date  -- '2024-09-01'
      --AND pedido_padre IN ('PV13015999','PV12958764')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY pedido_padre, id_orden, reexpedicion, dispositivo, nom.idol ORDER BY estado_final DESC) = 1
    ORDER BY 1,2,3;


END