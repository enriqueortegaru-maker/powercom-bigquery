BEGIN


    --- PASO 1: INSERTO REGISTROS EN BONOS_TELEVENTAS

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`
    SELECT
      DISTINCT a.* replace (CASE coalesce(nivel_ups,
          nivel_tvt_ups_virgin)
          WHEN 1 THEN b.N1
          WHEN 2 THEN b.N2
          WHEN 3 THEN b.N3
          WHEN 4 THEN b.N4
          WHEN 5 THEN b.N5
          WHEN 6 THEN b.N6
        ELSE
        NULL
      END AS importe, 'Rappel' AS NombreProducto, 'Rappel' AS TipoMovimiento),
--
--      PARCHE: REVISAR ESTA CASO        
--              
      CASE coalesce(nivel_ups, nivel_tvt_ups_virgin)
        WHEN 1 THEN b.N1
        WHEN 2 THEN b.N2
        WHEN 3 THEN b.N3
        WHEN 4 THEN b.N4
        WHEN 5 THEN b.N5
        WHEN 6 THEN b.N6
      ELSE
      NULL
    END
--      AS importe
      AS importe_nivel
    FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
    ON  UPPER(a.marca_ds) = c.marca_ds AND a.campana_id = c.campana_id AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1 = 1  ELSE a.nombre_distribuidor = c.nombre_distribuidor END
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_MR_TVT_UPS` b
    ON UPPER(a.marca_ds) = b.marca_Ds AND a.marco_retributivo = b.marco_retributivo AND a.tipomovimiento = b.tipo_movimiento
    WHERE (nivel_ups IS NOT NULL OR nivel_tvt_ups_virgin IS NOT NULL  OR nivel_tvt_ups_virgin > 0 )AND b.tipo_movimiento IS NOT NULL;



    --- PASO 2: CREO LOG

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0309_BONOS_TELEVENTAS` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`;
  
      
  END