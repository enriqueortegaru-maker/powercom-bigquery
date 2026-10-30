BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_temp`();

--CREA LAS TABLAS TEMPORALES UTILIZADAS EN EL PROCESO

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contador_impresos`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT tipo_pedido, id_orden, SUM(total_impresos) AS total_impresos, SUM(total_preimpresos) AS total_preimpresos, SUM(total_color) AS total_color
  FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_prep`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_prep
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - PREPA_PEDIDO','L - PREPA_EXTRA','L - PREPA_PEDIDO_DISP_AD')   --,'L - PREPA_PEDIDO_SIM_AD'  Tiene su propio apartado ("Sim_adic")
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_prep_sim_adic`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido,ROUND(SUM(COST.coste_sin_imp),2) AS Coste_prep
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - PREPA_PEDIDO_SIM_AD')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Costes_Impresos`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  --SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Costes_Impresos
  SELECT COST.id_orden, CAST(NULL AS STRING) AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Costes_Impresos
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - PRINT_DOC_BW') 
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Costes_Preimpresos`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  --SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Costes_Preimpresos
  SELECT COST.id_orden, CAST(NULL AS STRING) AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Costes_Preimpresos
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - PRINT_DOC_PRE') 
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Cancelacion_post`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Cancelacion_post
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - CANCEL_PICK') 
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Total_Coste_Manipul`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Total_Coste_Manipul
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - PREPA_PEDIDO','L - PREPA_PEDIDO_SIM_AD','L - PREPA_EXTRA','L - PRINT_DOC_BW','L - PRINT_DOC_PRE','L - CANCEL_PICK')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Devo_Contrato`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Devo_Contrato
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - RETORNO_DOC')  -- ('L - DEVO_CONTRATO')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Seguro_de_tte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Seguro_de_tte
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - SEGURO')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Foto_DNI`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Foto_DNI
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - FOTODNI')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Entrega_Exclusiva`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Entrega_Exclusiva
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - ENTREGA_EXCL')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Transp`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Transp
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
      ON  ORDENES.id_orden = COST.id_orden
      --AND ORDENES.reexpedicion = COST.reexpedition  --2026/03/26
      AND CASE WHEN COST.reexpedition IS NULL THEN ORDENES.reexpedicion = 'R0' ELSE COST.reexpedition = ORDENES.reexpedicion END
      AND ORDENES.tipo_pedido = COST.tipo_pedido
  WHERE UPPER(COST.codigo_coste) IN ('L - TRANSP','L - TRANSP_KG_AD','L - TRANSP_ANOVO','L - TRANSP_ANOVO_KG_AD','L - DEVOLUCION','L - TRANSP (2º INTENTO)','L - TRANSP_DEVOLUCION') AND (UPPER(ORDENES.courier) NOT IN ('CORREOS') OR ORDENES.courier IS NULL)
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Swap_Transp`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Swap
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
      ON  ORDENES.id_orden = COST.id_orden
      --AND ORDENES.reexpedicion = COST.reexpedition  --2026/03/26
      AND CASE WHEN COST.reexpedition IS NULL THEN ORDENES.reexpedicion = 'R0' ELSE COST.reexpedition = ORDENES.reexpedicion END
      AND ORDENES.tipo_pedido = COST.tipo_pedido
  WHERE UPPER(COST.codigo_coste) IN ('L - TRANSP SWAP','L - TRANSP_SWAP','L - TRANSP_SWAP_KG_AD')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Correos`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Correos
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
      ON  ORDENES.id_orden = COST.id_orden
      --AND ORDENES.reexpedicion = COST.reexpedition  --2026/03/26
      AND CASE WHEN COST.reexpedition IS NULL THEN ORDENES.reexpedicion = 'R0' ELSE COST.reexpedition = ORDENES.reexpedicion END
      AND ORDENES.tipo_pedido = COST.tipo_pedido
  WHERE UPPER(COST.codigo_coste) IN ('L - TRANSP','L - TRANSP_KG_AD','L - DEVOLUCION') --,'L - RETORNO_DOC') 
    AND UPPER(ORDENES.courier) IN ('CORREOS')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Devolucion_Recog`   
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Devolucion_Recog
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
      ON  ORDENES.id_orden = COST.id_orden
      --AND ORDENES.reexpedicion = COST.reexpedition  --2026/03/26
      AND CASE WHEN COST.reexpedition IS NULL THEN ORDENES.reexpedicion = 'R0' ELSE COST.reexpedition = ORDENES.reexpedicion END
      AND ORDENES.tipo_pedido = COST.tipo_pedido
  WHERE UPPER(COST.codigo_coste) IN ('L - VERIFICACION','L - RECOGIDA') --Revisión de los recogido en el desistimiento
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Dua`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Dua
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - DUA')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_DESTRUCCION`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_DESTRUCCION
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - TRANSP_DEST_SIM')
  GROUP BY ALL;
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Coste_Cancelacion`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Coste_Cancelacion
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - CANCELACION')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Total_Coste_Transporte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT COST.id_orden, CASE WHEN COST.reexpedition IS NULL THEN 'R0' ELSE COST.reexpedition END AS reexpedition, COST.tipo_pedido, ROUND(SUM(COST.coste_sin_imp),2) AS Total_Coste_Transporte
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST 
  WHERE UPPER(COST.codigo_coste) IN ('L - DEVO_CONTRATO','L - SEGURO','L - FOTODNI','L - ENTREGA_EXCL','L - TRANSP','L - TRANSP_KG_AD','L - TRANSP_ANOVO','L - TRANSP_ANOVO_KG_AD','L - TRANSP_DEST_SIM','L - CANCELACION','L - DUA','L - VERIFICACION','L - DEVOLUCION','L - TRANSP SWAP','L - RECOGIDA','L - RETORNO_DOC','L - TRANSP_SWAP','L - TRANSP_SWAP_KG_AD','L - TRANSP (2º INTENTO)','L - TRANSP_DEVOLUCION')
  GROUP BY ALL;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Num_Lineas`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  SELECT LINEAS.tipo_pedido, LINEAS.id_orden, LINEAS.reexpedicion, LINEAS.marca, MIN(LINEAS.numero_linea) AS MIN_NUMERO_LINEAS
  FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
  GROUP BY ALL
  ORDER BY 1,2,3,4;
/*
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
 SELECT ORDENES.id_orden
    , CASE WHEN ORDENES.reexpedicion IS NULL THEN 'R0' ELSE ORDENES.reexpedicion END AS reexpedicion
    , ORDENES.tipo_pedido
    , COALESCE(TERM.Term,0) AS Term
    , COALESCE(Sim.Sim,0) AS Sim
    , COALESCE(Pae.Pae,0) AS Pae
    , COALESCE(Patin.patin,0) AS Patin
    , COALESCE(TV.TV,0) AS TV
    , 0 AS Plv
    , COALESCE(Coste_prep.Coste_prep,0) AS Coste_prep
    , COALESCE(CAST((Coste_prep_sim_adic.Coste_prep/0.16) AS INT64),0) AS Unidades_adic
    , COALESCE(Coste_prep_sim_adic.Coste_prep,0) AS Sim_adic
    , COALESCE(Costes_Impresos.Costes_Impresos,0) AS Costes_Impresos
    , COALESCE(Costes_Preimpresos.Costes_Preimpresos,0) AS Costes_Preimpresos
    , COALESCE(Coste_Cancelacion_post.Coste_Cancelacion_post,0) AS Coste_Cancelacion_post
    , COALESCE(Total_Coste_Manipul.Total_Coste_Manipul,0) AS Total_Coste_Manipul
    , COALESCE(Coste_Devo_Contrato.Coste_Devo_Contrato,0) AS Coste_Devo_Contrato
    , COALESCE(Coste_Seguro_de_tte.Coste_Seguro_de_tte,0) AS Coste_Seguro_de_tte
    , COALESCE(Coste_Foto_DNI.Coste_Foto_DNI,0) AS Coste_Foto_DNI
    , COALESCE(Coste_Entrega_Exclusiva.Coste_Entrega_Exclusiva,0) AS Coste_Entrega_Exclusiva
    , 0 AS Coste_Appointment
    , COALESCE(Coste_Transp.Coste_Transp,0) AS Coste_Transp
    , COALESCE(Coste_Correos.Coste_Correos,0) AS Coste_Correos
    , 0 AS Coste_Swaps
    , COALESCE(Coste_Dua.Coste_Dua,0) AS Coste_Dua
    , 0 AS Coste_Contrareembolso
    , COALESCE(Coste_DESTRUCCION.Coste_DESTRUCCION,0) AS Coste_DESTRUCCION
    --, 0 AS Coste_DEVOLUCION_RECOG
    , COALESCE(Coste_Devolucion_Recog.Coste_Devolucion_Recog,0) AS Coste_DEVOLUCION_RECOG  
    , COALESCE(Coste_Cancelacion.Coste_Cancelacion,0) AS Coste_Cancelacion
    , 0 AS Coste_Recanalizacion
    , 0 AS Coste_extras
    , COALESCE(Total_Coste_Transporte.Total_Coste_Transporte,0) AS Total_Coste_Transporte
    , 0 AS EXCESO_CORREOS_HL
    , (COALESCE(Total_Coste_Manipul.Total_Coste_Manipul,0) + COALESCE(Total_Coste_Transporte.Total_Coste_Transporte,0)) AS Total_Coste_Man_y_Trans
    , CAST(NULL AS STRING) AS Palets_Manip
    , CAST(NULL AS STRING) AS Palets_sin_Manip

    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES

      LEFT JOIN `mm-commissions-reporting.TEMP.Term_counter` TERM
        ON  TERM.id_orden = ORDENES.id_orden 
        --AND TERM.reexpedicion = ORDENES.reexpedicion
        AND ((TERM.reexpedicion = ORDENES.reexpedicion) OR (TERM.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.SIM_counter` Sim
        ON  Sim.id_orden = ORDENES.id_orden 
        --AND Sim.reexpedicion = ORDENES.reexpedicion
        AND ((Sim.reexpedicion = ORDENES.reexpedicion) OR (Sim.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.Pae_counter` Pae
        ON  Pae.id_orden = ORDENES.id_orden 
        --AND Pae.reexpedicion = ORDENES.reexpedicion
        AND ((Pae.reexpedicion = ORDENES.reexpedicion) OR (Pae.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.Patin_counter` Patin
        ON  Patin.id_orden = ORDENES.id_orden 
        --AND Patin.reexpedicion = ORDENES.reexpedicion
        AND ((Patin.reexpedicion = ORDENES.reexpedicion) OR (Patin.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.TV_counter` TV
        ON  TV.id_orden = ORDENES.id_orden 
        --AND TV.reexpedicion = ORDENES.reexpedicion
        AND ((TV.reexpedicion = ORDENES.reexpedicion) OR (TV.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_prep` Coste_prep
        ON  Coste_prep.id_orden = ORDENES.id_orden 
        --AND Coste_prep.reexpedition = ORDENES.reexpedicion
        AND ((Coste_prep.reexpedition = ORDENES.reexpedicion) OR (Coste_prep.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_prep.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_prep_sim_adic` Coste_prep_sim_adic
        ON  Coste_prep_sim_adic.id_orden = ORDENES.id_orden 
        --AND Coste_prep_sim_adic.reexpedition = ORDENES.reexpedicion
        AND ((Coste_prep_sim_adic.reexpedition = ORDENES.reexpedicion) OR (Coste_prep_sim_adic.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_prep_sim_adic.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Costes_Impresos` Costes_Impresos
        ON  Costes_Impresos.id_orden = ORDENES.id_orden 
        --AND Costes_Impresos.reexpedition = ORDENES.reexpedicion
        AND ((Costes_Impresos.reexpedition = ORDENES.reexpedicion) OR (Costes_Impresos.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Costes_Impresos.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Costes_Preimpresos` Costes_Preimpresos
        ON  Costes_Preimpresos.id_orden = ORDENES.id_orden 
        --AND Costes_Preimpresos.reexpedition = ORDENES.reexpedicion   
        AND ((Costes_Preimpresos.reexpedition = ORDENES.reexpedicion) OR (Costes_Preimpresos.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Costes_Preimpresos.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Cancelacion_post` Coste_Cancelacion_post
        ON  Coste_Cancelacion_post.id_orden = ORDENES.id_orden 
        --AND Coste_Cancelacion_post.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Cancelacion_post.reexpedition = ORDENES.reexpedicion) OR (Coste_Cancelacion_post.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Cancelacion_post.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Total_Coste_Manipul` Total_Coste_Manipul
        ON  Total_Coste_Manipul.id_orden = ORDENES.id_orden 
        --AND Total_Coste_Manipul.reexpedition = ORDENES.reexpedicion
        AND ((Total_Coste_Manipul.reexpedition = ORDENES.reexpedicion) OR (Total_Coste_Manipul.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Total_Coste_Manipul.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Devo_Contrato` Coste_Devo_Contrato
        ON  Coste_Devo_Contrato.id_orden = ORDENES.id_orden 
        --AND Coste_Devo_Contrato.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Devo_Contrato.reexpedition = ORDENES.reexpedicion) OR (Coste_Devo_Contrato.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Devo_Contrato.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Seguro_de_tte` Coste_Seguro_de_tte
        ON  Coste_Seguro_de_tte.id_orden = ORDENES.id_orden 
        --AND Coste_Seguro_de_tte.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Seguro_de_tte.reexpedition = ORDENES.reexpedicion) OR (Coste_Seguro_de_tte.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Seguro_de_tte.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Foto_DNI` Coste_Foto_DNI
        ON  Coste_Foto_DNI.id_orden = ORDENES.id_orden 
        --AND Coste_Foto_DNI.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Foto_DNI.reexpedition = ORDENES.reexpedicion) OR (Coste_Foto_DNI.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Foto_DNI.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Entrega_Exclusiva` Coste_Entrega_Exclusiva
        ON  Coste_Entrega_Exclusiva.id_orden = ORDENES.id_orden 
        --AND Coste_Entrega_Exclusiva.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Entrega_Exclusiva.reexpedition = ORDENES.reexpedicion) OR (Coste_Entrega_Exclusiva.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Entrega_Exclusiva.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Transp` Coste_Transp
        ON  Coste_Transp.id_orden = ORDENES.id_orden 
        --AND Coste_Transp.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Transp.reexpedition = ORDENES.reexpedicion) OR (Coste_Transp.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Transp.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Correos` Coste_Correos
        ON  Coste_Correos.id_orden = ORDENES.id_orden 
        --AND Coste_Correos.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Correos.reexpedition = ORDENES.reexpedicion) OR (Coste_Correos.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Correos.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Dua` Coste_Dua
        ON  Coste_Dua.id_orden = ORDENES.id_orden 
        --AND Coste_Dua.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Dua.reexpedition = ORDENES.reexpedicion) OR (Coste_Dua.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Dua.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_DESTRUCCION` Coste_DESTRUCCION
        ON  Coste_DESTRUCCION.id_orden = ORDENES.id_orden 
        --AND Coste_DESTRUCCION.reexpedition = ORDENES.reexpedicion
        AND ((Coste_DESTRUCCION.reexpedition = ORDENES.reexpedicion) OR (Coste_DESTRUCCION.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_DESTRUCCION.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Cancelacion` Coste_Cancelacion
        ON  Coste_Cancelacion.id_orden = ORDENES.id_orden 
        --AND Coste_Cancelacion.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Cancelacion.reexpedition = ORDENES.reexpedicion) OR (Coste_Cancelacion.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Cancelacion.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Total_Coste_Transporte` Total_Coste_Transporte
        ON  Total_Coste_Transporte.id_orden = ORDENES.id_orden 
        --AND Total_Coste_Transporte.reexpedition = ORDENES.reexpedicion
        AND ((Total_Coste_Transporte.reexpedition = ORDENES.reexpedicion) OR (Total_Coste_Transporte.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Total_Coste_Transporte.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Devolucion_Recog` Coste_Devolucion_Recog
        ON  Coste_Devolucion_Recog.id_orden = ORDENES.id_orden 
        --AND Coste_Devolucion_Recog.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Devolucion_Recog.reexpedition = ORDENES.reexpedicion) OR (Coste_Devolucion_Recog.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Devolucion_Recog.tipo_pedido = ORDENES.tipo_pedido

    WHERE ORDENES.estado_final NOT IN ('MULTISIM')
    QUALIFY ROW_NUMBER () OVER (PARTITION BY id_orden, reexpedicion, tipo_pedido ORDER BY id_orden, reexpedicion) = 1;
*/

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica_Tmp`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT ORDENES.id_orden
      , CASE WHEN ORDENES.reexpedicion IS NULL THEN 'R0' ELSE ORDENES.reexpedicion END AS reexpedicion
      , ORDENES.tipo_pedido
      , COALESCE(TERM.Term,0) AS Term
      , COALESCE(Sim.Sim,0) AS Sim
      , COALESCE(Pae.Pae,0) AS Pae
      , COALESCE(Patin.patin,0) AS Patin
      , COALESCE(TV.TV,0) AS TV
      , 0 AS Plv
      , COALESCE(Coste_prep.Coste_prep,0) AS Coste_prep
      , COALESCE(CAST((Coste_prep_sim_adic.Coste_prep/0.16) AS INT64),0) AS Unidades_adic
      , COALESCE(Coste_prep_sim_adic.Coste_prep,0) AS Sim_adic
      , COALESCE(Costes_Impresos.Costes_Impresos,0) AS Costes_Impresos
      , COALESCE(Costes_Preimpresos.Costes_Preimpresos,0) AS Costes_Preimpresos
      , COALESCE(Coste_Cancelacion_post.Coste_Cancelacion_post,0) AS Coste_Cancelacion_post
      , COALESCE(Total_Coste_Manipul.Total_Coste_Manipul,0) AS Total_Coste_Manipul
      , COALESCE(Coste_Devo_Contrato.Coste_Devo_Contrato,0) AS Coste_Devo_Contrato
      , COALESCE(Coste_Seguro_de_tte.Coste_Seguro_de_tte,0) AS Coste_Seguro_de_tte
      , COALESCE(Coste_Foto_DNI.Coste_Foto_DNI,0) AS Coste_Foto_DNI
      , COALESCE(Coste_Entrega_Exclusiva.Coste_Entrega_Exclusiva,0) AS Coste_Entrega_Exclusiva
      , 0 AS Coste_Appointment
      , COALESCE(Coste_Transp.Coste_Transp,0) AS Coste_Transp
      , COALESCE(Coste_Correos.Coste_Correos,0) AS Coste_Correos
      , COALESCE(Coste_Swap.Coste_Swap,0) AS Coste_Swaps
      , COALESCE(Coste_Dua.Coste_Dua,0) AS Coste_Dua
      , 0 AS Coste_Contrareembolso
      , COALESCE(Coste_DESTRUCCION.Coste_DESTRUCCION,0) AS Coste_DESTRUCCION
      --, 0 AS Coste_DEVOLUCION_RECOG
      , COALESCE(Coste_Devolucion_Recog.Coste_Devolucion_Recog,0) AS Coste_DEVOLUCION_RECOG  
      , COALESCE(Coste_Cancelacion.Coste_Cancelacion,0) AS Coste_Cancelacion
      , 0 AS Coste_Recanalizacion
      , 0 AS Coste_extras
      , COALESCE(Total_Coste_Transporte.Total_Coste_Transporte,0) AS Total_Coste_Transporte
      , 0 AS EXCESO_CORREOS_HL
      , (COALESCE(Total_Coste_Manipul.Total_Coste_Manipul,0) + COALESCE(Total_Coste_Transporte.Total_Coste_Transporte,0)) AS Total_Coste_Man_y_Trans
      , CAST(NULL AS STRING) AS Palets_Manip
      , CAST(NULL AS STRING) AS Palets_sin_Manip
      , Contador_Impresos.total_impresos
      , Contador_Impresos.total_preimpresos
      , Contador_Impresos.total_color

    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES

      LEFT JOIN `mm-commissions-reporting.TEMP.Term_counter` TERM
        ON  TERM.id_orden = ORDENES.id_orden 
        --AND TERM.reexpedicion = ORDENES.reexpedicion
        AND ((TERM.reexpedicion = ORDENES.reexpedicion) OR (TERM.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.SIM_counter` Sim
        ON  Sim.id_orden = ORDENES.id_orden 
        --AND Sim.reexpedicion = ORDENES.reexpedicion
        AND ((Sim.reexpedicion = ORDENES.reexpedicion) OR (Sim.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.Pae_counter` Pae
        ON  Pae.id_orden = ORDENES.id_orden 
        --AND Pae.reexpedicion = ORDENES.reexpedicion
        AND ((Pae.reexpedicion = ORDENES.reexpedicion) OR (Pae.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.Patin_counter` Patin
        ON  Patin.id_orden = ORDENES.id_orden 
        --AND Pae.reexpedicion = ORDENES.reexpedicion
        AND ((Patin.reexpedicion = ORDENES.reexpedicion) OR (Patin.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.TV_counter` TV
        ON  TV.id_orden = ORDENES.id_orden 
        --AND TV.reexpedicion = ORDENES.reexpedicion
        AND ((TV.reexpedicion = ORDENES.reexpedicion) OR (TV.reexpedicion IS NULL AND ORDENES.reexpedicion = 'R0'))
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_prep` Coste_prep
        ON  Coste_prep.id_orden = ORDENES.id_orden 
        --AND Coste_prep.reexpedition = ORDENES.reexpedicion
        AND ((Coste_prep.reexpedition = ORDENES.reexpedicion) OR (Coste_prep.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_prep.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_prep_sim_adic` Coste_prep_sim_adic
        ON  Coste_prep_sim_adic.id_orden = ORDENES.id_orden 
        --AND Coste_prep_sim_adic.reexpedition = ORDENES.reexpedicion
        AND ((Coste_prep_sim_adic.reexpedition = ORDENES.reexpedicion) OR (Coste_prep_sim_adic.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_prep_sim_adic.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Costes_Impresos` Costes_Impresos
        ON  Costes_Impresos.id_orden = ORDENES.id_orden 
        --AND Costes_Impresos.reexpedition = ORDENES.reexpedicion
        AND ((Costes_Impresos.reexpedition = ORDENES.reexpedicion) OR (Costes_Impresos.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Costes_Impresos.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Costes_Preimpresos` Costes_Preimpresos
        ON  Costes_Preimpresos.id_orden = ORDENES.id_orden 
        --AND Costes_Preimpresos.reexpedition = ORDENES.reexpedicion   
        AND ((Costes_Preimpresos.reexpedition = ORDENES.reexpedicion) OR (Costes_Preimpresos.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Costes_Preimpresos.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Cancelacion_post` Coste_Cancelacion_post
        ON  Coste_Cancelacion_post.id_orden = ORDENES.id_orden 
        --AND Coste_Cancelacion_post.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Cancelacion_post.reexpedition = ORDENES.reexpedicion) OR (Coste_Cancelacion_post.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Cancelacion_post.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Total_Coste_Manipul` Total_Coste_Manipul
        ON  Total_Coste_Manipul.id_orden = ORDENES.id_orden 
        --AND Total_Coste_Manipul.reexpedition = ORDENES.reexpedicion
        AND ((Total_Coste_Manipul.reexpedition = ORDENES.reexpedicion) OR (Total_Coste_Manipul.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Total_Coste_Manipul.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Devo_Contrato` Coste_Devo_Contrato
        ON  Coste_Devo_Contrato.id_orden = ORDENES.id_orden 
        --AND Coste_Devo_Contrato.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Devo_Contrato.reexpedition = ORDENES.reexpedicion) OR (Coste_Devo_Contrato.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Devo_Contrato.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Seguro_de_tte` Coste_Seguro_de_tte
        ON  Coste_Seguro_de_tte.id_orden = ORDENES.id_orden 
        --AND Coste_Seguro_de_tte.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Seguro_de_tte.reexpedition = ORDENES.reexpedicion) OR (Coste_Seguro_de_tte.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Seguro_de_tte.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Foto_DNI` Coste_Foto_DNI
        ON  Coste_Foto_DNI.id_orden = ORDENES.id_orden 
        --AND Coste_Foto_DNI.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Foto_DNI.reexpedition = ORDENES.reexpedicion) OR (Coste_Foto_DNI.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Foto_DNI.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Entrega_Exclusiva` Coste_Entrega_Exclusiva
        ON  Coste_Entrega_Exclusiva.id_orden = ORDENES.id_orden 
        --AND Coste_Entrega_Exclusiva.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Entrega_Exclusiva.reexpedition = ORDENES.reexpedicion) OR (Coste_Entrega_Exclusiva.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Entrega_Exclusiva.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Transp` Coste_Transp
        ON  Coste_Transp.id_orden = ORDENES.id_orden 
        --AND Coste_Transp.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Transp.reexpedition = ORDENES.reexpedicion) OR (Coste_Transp.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Transp.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Swap_Transp` Coste_Swap
        ON  Coste_Swap.id_orden = ORDENES.id_orden 
        --AND Coste_Swap.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Swap.reexpedition = ORDENES.reexpedicion) OR (Coste_Swap.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Swap.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Correos` Coste_Correos
        ON  Coste_Correos.id_orden = ORDENES.id_orden 
        --AND Coste_Correos.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Correos.reexpedition = ORDENES.reexpedicion) OR (Coste_Correos.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Correos.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Dua` Coste_Dua
        ON  Coste_Dua.id_orden = ORDENES.id_orden 
        --AND Coste_Dua.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Dua.reexpedition = ORDENES.reexpedicion) OR (Coste_Dua.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Dua.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_DESTRUCCION` Coste_DESTRUCCION
        ON  Coste_DESTRUCCION.id_orden = ORDENES.id_orden 
        --AND Coste_DESTRUCCION.reexpedition = ORDENES.reexpedicion
        AND ((Coste_DESTRUCCION.reexpedition = ORDENES.reexpedicion) OR (Coste_DESTRUCCION.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_DESTRUCCION.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Cancelacion` Coste_Cancelacion
        ON  Coste_Cancelacion.id_orden = ORDENES.id_orden 
        --AND Coste_Cancelacion.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Cancelacion.reexpedition = ORDENES.reexpedicion) OR (Coste_Cancelacion.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Cancelacion.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Total_Coste_Transporte` Total_Coste_Transporte
        ON  Total_Coste_Transporte.id_orden = ORDENES.id_orden 
        --AND Total_Coste_Transporte.reexpedition = ORDENES.reexpedicion
        AND ((Total_Coste_Transporte.reexpedition = ORDENES.reexpedicion) OR (Total_Coste_Transporte.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Total_Coste_Transporte.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Devolucion_Recog` Coste_Devolucion_Recog
        ON  Coste_Devolucion_Recog.id_orden = ORDENES.id_orden 
        --AND Coste_Devolucion_Recog.reexpedition = ORDENES.reexpedicion
        AND ((Coste_Devolucion_Recog.reexpedition = ORDENES.reexpedicion) OR (Coste_Devolucion_Recog.reexpedition IS NULL AND ORDENES.reexpedicion = 'R0'))
        AND Coste_Devolucion_Recog.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.Contador_impresos` Contador_Impresos
        ON  Contador_Impresos.id_orden = ORDENES.id_orden
        AND Contador_Impresos.tipo_pedido = ORDENES.tipo_pedido

    WHERE ORDENES.estado_final NOT IN ('MULTISIM')
    QUALIFY ROW_NUMBER () OVER (PARTITION BY id_orden, reexpedicion, tipo_pedido ORDER BY id_orden, reexpedicion) = 1;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT id_orden, reexpedicion, tipo_pedido, Term, Sim, Pae, Patin, TV, Plv
      , SUM(Coste_prep) AS Coste_prep
      , Unidades_adic
      , Sim_adic
      , SUM(Costes_Impresos) AS Costes_Impresos
      , SUM(Costes_Preimpresos) AS Costes_Preimpresos
      , SUM(Coste_Cancelacion_post) AS Coste_Cancelacion_post
      , ROUND(SUM(Total_Coste_Manipul),2) AS Total_Coste_Manipul
      , SUM(Coste_Devo_Contrato) AS Coste_Devo_Contrato
      , SUM(Coste_Seguro_de_tte) AS Coste_Seguro_de_tte
      , SUM(Coste_Foto_DNI) AS Coste_Foto_DNI
      , SUM(Coste_Entrega_Exclusiva) AS Coste_Entrega_Exclusiva
      , SUM(Coste_Appointment) AS Coste_Appointment
      , SUM(Coste_Transp) AS Coste_Transp
      , SUM(Coste_Correos) AS Coste_Correos
      , SUM(Coste_Swaps) AS Coste_Swaps
      , SUM(Coste_Dua) AS Coste_Dua
      , SUM(Coste_Contrareembolso) AS Coste_Contrareembolso
      , SUM(Coste_DESTRUCCION) AS Coste_DESTRUCCION
      , SUM(Coste_DEVOLUCION_RECOG) AS Coste_DEVOLUCION_RECOG
      , SUM(Coste_Cancelacion) AS Coste_Cancelacion
      , SUM(Coste_Recanalizacion) AS Coste_Recanalizacion
      , SUM(Coste_extras) AS Coste_extras
      , ROUND(SUM(Total_Coste_Transporte),2) AS Total_Coste_Transporte
      , SUM(EXCESO_CORREOS_HL) AS EXCESO_CORREOS_HL
      , ROUND(SUM(Total_Coste_Man_y_Trans),2) AS Total_Coste_Man_y_Trans
      , Palets_Manip, Palets_sin_Manip
      , total_impresos, total_preimpresos, total_color

    FROM `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica_Tmp` 

    GROUP BY ALL;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tipo_equipo`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
    SELECT tipo_pedido, marca, id_orden, order_dispo as dispositivo, canal, Tipo_equipo
    FROM (
      SELECT ORDENES.tipo_pedido, ORDENES.marca, ORDENES.id_orden, ORDENES.dispositivo as order_dispo, ORDENES.canal, LINEAS.id_modelo, LINEAS.codigo_modelo, LINEAS.descripcion_modelo, LINEAS.dispositivo as lineas_dispo, MAESTRO.familia, MAESTRO.Subfamilia
        , CASE WHEN UPPER(familia) IN ('ROUTER') AND UPPER(Subfamilia) NOT IN ('ROUTER MOVIL 5G') THEN 'Fijo' 
              WHEN UPPER(familia) IN ('HOME') AND UPPER(Subfamilia) IN ('FIJO') THEN 'Fijo' 
              ELSE 'Movil' END AS Tipo_equipo
      FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
        LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
          ON  LINEAS.id_orden = ORDENES.id_orden
          AND LINEAS.reexpedicion = ORDENES.reexpedicion
          AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
        LEFT JOIN `mm-logistics-reporting.STOCK.log_maestro` MAESTRO
          ON  MAESTRO.Codigo = LINEAS.id_modelo
    )
    QUALIFY ROW_NUMBER() OVER (PARTITION BY tipo_pedido, marca, id_orden ORDER BY Tipo_equipo ASC) =  1;

END