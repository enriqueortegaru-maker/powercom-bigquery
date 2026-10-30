BEGIN
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.NIVEL_VENTAS_TIENDAS` AS
    SELECT a.*, nivel, a.importe * CASE nivel WHEN 1 THEN N1  WHEN 2 THEN N2  WHEN 3 THEN N3 WHEN 4 THEN N4 ELSE 1 END importe_nivel
    FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_NIVELCONSEGUIDO_TIPOMOVIMIENTO` c
    ON a.nombre_distribuidor = c.nombre_distribuidor
      AND a.canal = c.canal
      AND a.subcanal = c.subcanal
      AND CASE WHEN UPPER(c.tipomovimiento) = 'X' THEN 1 = 1 ELSE  a.tipomovimiento = c.tipomovimiento END
      AND a.marco_retributivo = c.marco_retributivo
      AND UPPER(a.marca_ds) = UPPER(c.marca_ds)
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_TRAMOS_RAPPEL_OBJETIVOS` b
    ON a.marco_retributivo = b.mr
      AND CASE WHEN UPPER(b.movimiento) = 'X' THEN 1 = 1 ELSE a.tipomovimiento = b.movimiento END
      AND UPPER(a.marca_ds) = UPPER(b.marca_ds);

  END