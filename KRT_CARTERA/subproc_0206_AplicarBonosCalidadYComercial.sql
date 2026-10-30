BEGIN
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS` AS
    SELECT a.*,
      CASE WHEN bonus_comercial = 'S' AND (tvt_ups_virgin = 'N' OR tvt_ups_virgin IS NULL) 
              THEN importe_nivel * 0.05 
           ELSE 0 
      END  bono_comercial,
      CASE
        WHEN (tvt_ups_virgin = 'N' OR tvt_ups_virgin IS NULL) 
            THEN CASE WHEN bonus_comercial = 'S' 
                  THEN importe_nivel * 1.05 
                  ELSE importe_nivel END * bonus_calidad 
        ELSE 0 
      END bono_calidad
    FROM `mm-commissions-reporting.KRT_CARTERA.NIVEL_VENTAS_TIENDAS` a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_BONUS_CALIDAD_COMERCIAL` b
    ON
      a.nombre_distribuidor = b.nombre_distribuidor
      AND a.canal = b.canal
      AND a.subcanal = b.subcanal
      AND a.marco_retributivo = b.marco_retributivo
      AND UPPER(a.marca_ds) = UPPER(b.marca_ds);

  END