BEGIN

DECLARE mes_string, qry, tabla_nombre STRING;

SET mes_string = CONCAT(CAST(id_mes_pr AS STRING),'01');



-- CALL `mm-commissions-reporting.TERMINALES.pr_multidispositivos_final_2026`(202610);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.financiaciones_nueva_categ_disp` AS
SELECT 
  phone_nm
  ,serial_number
  ,brand_ds
  ,sell_type
  ,terminal_status_ds
  ,order_date
  ,CASE 
       WHEN is_financed_desc IN ('SI','PAGO FINANCIADO') THEN DATE(fecha_fin_financiacion) 
       WHEN is_financed_desc IN ('NO','PAGO UNICO') THEN DATE_ADD(order_date, INTERVAL 24 MONTH) -- Por indicación de Enrique, se está asociando un compromiso de permanencia de 12 meses a todos los pagos únicos. Cambiado a 24 20260717
   END AS fecha_fin_financiacion
  ,is_financed_desc
  ,user_store
  ,status_servicio
  ,terminal_name
  ,total_pay_value
  ,compromiso_permanencia

FROM `mm-commissions-reporting.TEMP.device_base`
WHERE terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
AND brand_ds IN ('MASMOVIL','YOIGO')
AND DATE(order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
GROUP BY ALL

QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, order_date ORDER BY DATE(fecha_fin_financiacion) DESC) = 1

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.multidispositivos_final_nc` AS

-- Ubicamos los imeis duplicados con mayúculas y minúsculas
WITH duplicados_mayus AS (
SELECT serial_number, UPPER(serial_number) AS imei_mayus
FROM `mm-datamart-kd.DEVICES.device_base_mysim` a
INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
    ON a.user_store = b.id_comisionista AND b.comisiona
WHERE 1 = 1
and terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
and DATE(order_date) >= '2025-09-01'
GROUP BY ALL
),

-- Unimos los imeis encontrados arriba con el resto de duplicados
imeis_duplicados AS (
    SELECT 
        c.serial_number
        ,e.sell_type
        ,a.terminal_status_ds
        ,a.order_date
        ,CAST(a.phone_nm AS STRING) AS phone_nm
        ,a.is_financed_desc
        ,a.financed_end_date
        -- ,e.status_servicio
        ,e.* except(serial_number,sell_type,terminal_status_ds,order_date,phone_nm,is_financed_desc,fecha_fin_financiacion)
    FROM `mm-datamart-kd.DEVICES.device_base_mysim` a

    INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
                  ON a.user_store = b.id_comisionista AND b.comisiona

    INNER JOIN (
               -- IMEIs duplicados
               SELECT * 
               FROM (            
                    SELECT serial_number
                    FROM `mm-datamart-kd.DEVICES.device_base_mysim` a

                    INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
                        ON a.user_store = b.id_comisionista AND b.comisiona

                    WHERE 1 = 1
                    and terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
                    and DATE(order_date) >= '2025-09-01'
                    GROUP BY ALL
                    HAVING COUNT(serial_number) > 1
                    ORDER BY serial_number
                    )
               UNION ALL
                -- IMEIs duplicados mayúsculas y minúsculas
               SELECT *
               FROM (
                    SELECT imei_mayus
                    FROM duplicados_mayus
                    GROUP BY ALL
                    HAVING COUNT(imei_mayus) > 1
                    )
              ) c
              ON UPPER(a.serial_number) = c.serial_number

    LEFT JOIN `mm-commissions-reporting.TEMP.device_base` e
        ON a.serial_number = e.serial_number
          AND DATE(a.order_date) = e.order_date

    WHERE a.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
    AND DATE(a.order_date) >= '2025-09-01'
    AND UPPER(a.serial_number) = c.serial_number
    
    QUALIFY ROW_NUMBER() OVER(
                          PARTITION BY c.serial_number
                          ORDER BY 
                                   CASE WHEN status_servicio = 'ACTIVATED' THEN 1 ELSE 2 END ASC,
                                   order_date ASC
                         ) = 1
    ORDER BY 1,4
),

-- Unimos imeis duplicados y no duplicados
total_dispositivos AS (
    -- Dispositivos sin IMEIs duplicados
    SELECT 
      DISPOSITIVOS.phone_nm
      ,DISPOSITIVOS.serial_number
      ,DISPOSITIVOS.terminal_status_ds
      ,DISPOSITIVOS.is_financed_desc
      ,DISPOSITIVOS.order_date
      ,DISPOSITIVOS.fecha_fin_financiacion
      ,DISPOSITIVOS.* EXCEPT(phone_nm, serial_number, terminal_status_ds, is_financed_desc, order_date, fecha_fin_financiacion) 

    FROM `mm-commissions-reporting.TEMP.device_base` DISPOSITIVOS

    LEFT JOIN imeis_duplicados IMEIS
        ON IMEIS.serial_number = DISPOSITIVOS.serial_number

    WHERE DISPOSITIVOS.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
          AND IMEIS.serial_number IS NULL
          AND DATE(DISPOSITIVOS.order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query

    UNION ALL

    -- IMEIs duplicados
    SELECT 
      phone_nm
      ,serial_number
      ,terminal_status_ds
      ,is_financed_desc
      ,DATE(order_date) AS order_date
      ,financed_end_date AS fecha_fin_financiacion
      ,* EXCEPT(phone_nm, serial_number, terminal_status_ds, is_financed_desc, order_date, financed_end_date)

    FROM imeis_duplicados
    WHERE terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
    AND DATE(order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
),

-- Ubicamos los actos comerciales en que se vende más de un dispositivo
ventas_multidispositivos AS (
    SELECT
      phone_nm
      ,serial_number
      ,sell_type
      ,terminal_status_ds
      ,order_date
      ,fecha_fin_financiacion
      ,is_financed_desc
      ,user_store
      ,status_servicio
      ,terminal_name
      ,total_pay_value
      ,compromiso_permanencia
      ,* EXCEPT(product, order_date,phone_nm)
    FROM `mm-commissions-reporting.TEMP.device_base`
    WHERE terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
    AND DATE(order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
    AND brand_ds IN ('MASMOVIL', 'YOIGO')
    QUALIFY COUNT(*) OVER(PARTITION BY phone_nm, order_date ORDER BY order_date) > 1
),

-- Financiaciones y Pagos únicos cuya fecha fin de financiación o compromiso de permanencia no ha caducado
financiaciones_vivas AS (
    -- VENTAS A PLAZOS Y PAGOS ÚNICOS
    -- SELECT
    --     *
    --     ,CASE
    --          WHEN LAG(amortizacion, 1) OVER (PARTITION BY phone_nm ORDER BY order_date) = 'SI' THEN order_date -- Ajustamos fecha fin financiación a las amortizaciones. En tabla devices se queda con la fecha original
    --          ELSE LAG(fecha_fin_financiacion, 1) OVER (PARTITION BY phone_nm ORDER BY order_date) 
    --      END AS fecha_fin_financiacion_previa

    --     ,CASE
    --          WHEN amortizacion = 'SI' THEN fecha_venta_siguiente -- Ajustamos fecha fin financiación a las amortizaciones. En tabla devices se queda con la fecha original
    --          ELSE MAX(fecha_fin_financiacion) OVER (PARTITION BY phone_nm ORDER BY order_date) 
    --      END AS max_fecha_fin_financiacion 
    -- FROM (
          SELECT 
            *
            ,LAG(fecha_fin_financiacion, 1) OVER (PARTITION BY phone_nm ORDER BY order_date) AS fecha_fin_financiacion_previa
            ,MAX(fecha_fin_financiacion) OVER (PARTITION BY phone_nm ORDER BY order_date) AS max_fecha_fin_financiacion
            ,IF(is_financed_desc = 'SI' AND terminal_status_ds = 'USADO', 'SI','NO') AS amortizacion
            ,LEAD(order_date, 1) OVER (PARTITION BY phone_nm ORDER BY order_date) AS fecha_venta_siguiente
          FROM `mm-commissions-reporting.TEMP.financiaciones_nueva_categ_disp`
          WHERE DATE(order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
        --  )
),

rank_ventas_dispositivos AS (
    SELECT
      DVC.phone_nm,
      DVC.serial_number,
      DVC.terminal_status_ds,
      DVC.order_date,
      CASE
        --   WHEN DVC.is_financed_desc = 'SI' AND DVC.terminal_status_ds = 'USADO' THEN FNC.fecha_venta_siguiente -- Ajustamos fecha fin financiación a las amortizaciones. En tabla devices se queda con la fecha original
          WHEN DVC.fecha_fin_financiacion IS NOT NULL THEN DATE(DVC.fecha_fin_financiacion) 
          ELSE DATE_ADD(DVC.order_date, INTERVAL 24 MONTH)
      END AS fecha_fin_financiacion,
                 
      CASE
          WHEN DVC.phone_nm = FNC.phone_nm AND DVC.order_date = FNC.order_date THEN FNC.fecha_fin_financiacion_previa
          ELSE CAST(null AS DATE)
      END AS fecha_fin_financiacion_previa, -- Obtenemos la fecha fin de financiación de la venta previa 
      
      FNC.max_fecha_fin_financiacion,
      DVC.is_financed_desc,
      
      RANK() OVER (PARTITION BY DVC.phone_nm ORDER BY DVC.order_date) AS sale_rank, -- Rank a cada venta
      ROW_NUMBER() OVER (
                         PARTITION BY DVC.phone_nm, DVC.order_date, DVC.brand_ds 
                         ORDER BY DVC.activation_date ASC,
                                  DVC.deactivation_date ASC,
                                  DVC.original_cost_price DESC,
                                  DVC.serial_number ASC,
                                  DVC.id_subscription_terminal ASC
                        ) AS device_rank, -- Rank a cada dispositivo dentro de una venta
      
      DVC.original_cost_price,
      CASE WHEN MLT.phone_nm IS NOT NULL THEN 1 ELSE 0 END AS venta_multi,
      DVC.* EXCEPT(phone_nm, serial_number, terminal_status_ds, order_date, fecha_fin_financiacion, is_financed_desc, original_cost_price)
    
    FROM total_dispositivos DVC
          
    LEFT JOIN ventas_multidispositivos MLT
            ON DVC.phone_nm = MLT.phone_nm
               AND DVC.order_date = MLT.order_date
               AND DVC.brand_ds = MLT.brand_ds
    
    LEFT JOIN financiaciones_vivas FNC 
            ON DVC.phone_nm = FNC.phone_nm
               AND DVC.order_date = FNC.order_date

    LEFT JOIN imeis_duplicados IME
            ON UPPER(DVC.serial_number) = IME.serial_number

    WHERE DVC.brand_ds IN ('MASMOVIL', 'YOIGO')
    AND DATE(DVC.order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
    AND DVC.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
    
    -- GROUP BY DVC.phone_nm, DVC.serial_number, DVC.terminal_status_ds, DVC.order_date, DVC.fecha_fin_financiacion, DVC.is_financed_desc, DVC.brand_ds, DVC.activation_date, DVC.deactivation_date, DVC.original_cost_price, DVC.id_subscription_terminal, MLT.phone_nm, FNC.phone_nm, FNC.order_date, FNC.fecha_fin_financiacion_previa, FNC.max_fecha_fin_financiacion,IME.serial_number, IME.status_servicio, IME.order_date
    GROUP BY 1,2,3,4,5,6,7,8,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69, DVC.fecha_fin_financiacion, DVC.fecha_inicio_financiacion, DVC.cod_canal, DVC.total_pay_value, DVC.courier, DVC.compromiso_permanencia, IME.status_servicio, IME.order_date, DVC.pago_inicial


    QUALIFY ROW_NUMBER() OVER(
                          PARTITION BY UPPER(DVC.serial_number) 
                          ORDER BY 
                                   CASE WHEN IME.status_servicio = 'ACTIVATED' THEN 1 ELSE 2 END ASC,
                                   IME.order_date ASC
                         ) = 1            
)

/*
---------------------------------------------------------
CATEGORIZACION DISPOSITIVOS
---------------------------------------------------------
*/
SELECT 
    phone_nm
    ,serial_number
    ,terminal_status_ds
    ,is_financed_desc
    ,order_date
    ,fecha_fin_financiacion
    ,fecha_fin_financiacion_previa
    ,max_fecha_fin_financiacion
    ,CASE
        -- ANTES DEL 2026-10-01
        WHEN order_date < '2026-10-01' THEN
            CASE
                  -- La primera venta siempre es primaria
                WHEN sale_rank = 1 THEN
                    IF(device_rank = 1,'PRIMARIO','SECUNDARIO')
                  -- Las captaciones siempre son primarias
                WHEN sell_type = 'CAPTACION' THEN 'PRIMARIO' -- 20260522 por caso IMEI 350811294279688 (financiación amortizada - no se cambia aún la fecha fin de financiación - y portabilidad intragrupo)

                  -- Una nueva venta es primaria si faltan 4 meses o menos para finalizar la financiación que esté en curso
                WHEN fecha_fin_financiacion = max_fecha_fin_financiacion THEN
                    IF(venta_multi = 1,
                       IF(device_rank = 1,
                          IF(order_date >= DATE_SUB(fecha_fin_financiacion_previa, INTERVAL 4 MONTH),'PRIMARIO','SECUNDARIO')
                         ,'SECUNDARIO')
                      ,IF(order_date >= DATE_SUB(fecha_fin_financiacion_previa, INTERVAL 4 MONTH),'PRIMARIO','SECUNDARIO'))
                WHEN fecha_fin_financiacion != max_fecha_fin_financiacion THEN
                    IF(order_date >= DATE_SUB(max_fecha_fin_financiacion, INTERVAL 4 MONTH),'PRIMARIO','SECUNDARIO')
                ELSE 'SECUNDARIO'
            END

        --  DESDE EL 2026-10-01 (nueva categorizacion)
        WHEN sell_type = 'CAPTACION'    THEN 'PRIMARIO'   -- en captacion no hay multidispositivos
        WHEN offer_segmentation = 'OMM' THEN 'PRIMARIO'   -- Mi Fijo siempre primario

        -- Candidato a primario: segmentación A-E y (financiado, o pago único con penalty), solo un primario por mes
        WHEN UPPER(RIGHT(offer_segmentation,1)) IN ('A','B','C','D','E')
             AND (terminal_status_ds IN ('AMORTIZACION PENDIENTE', 'AMORTIZACIÓN PENDIENTE', 'EN FINANCIACION', 'FINANCIACION EN CURSO')
                  OR ((is_financed_desc IN ('NO','PAGO UNICO') or terminal_status_ds in ('USADO')) AND compromiso_permanencia = 'SI'))
             AND ROW_NUMBER() OVER (
                    PARTITION BY phone_nm, DATE_TRUNC(order_date, MONTH)
                    ORDER BY
                        CASE WHEN COALESCE(sell_type,'') <> 'CAPTACION'
                                  AND UPPER(RIGHT(offer_segmentation,1)) IN ('A','B','C','D','E')
                                  AND (terminal_status_ds IN ('AMORTIZACION PENDIENTE', 'AMORTIZACIÓN PENDIENTE', 'EN FINANCIACION', 'FINANCIACION EN CURSO')
                                       OR ((is_financed_desc IN ('NO','PAGO UNICO') or terminal_status_ds in ('USADO')) AND compromiso_permanencia = 'SI'))
                             THEN 0 ELSE 1 END,
                        sale_rank ASC,
                        device_rank ASC
                 ) = 1
             THEN 'PRIMARIO'

        ELSE 'SECUNDARIO'  
     END AS multidispositivo
    ,sale_rank
    ,device_rank
    ,venta_multi
    ,* EXCEPT(phone_nm, serial_number, terminal_status_ds, is_financed_desc, order_date, fecha_fin_financiacion, fecha_fin_financiacion_previa, max_fecha_fin_financiacion,sale_rank, device_rank, venta_multi,product) 

FROM rank_ventas_dispositivos 

WHERE terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
      AND DATE(order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query

-- AND phone_nm = '653487897' -- multiventa con VaP previa
-- AND phone_nm = '655148352' -- venta con VaP en curso y amortización de la primera venta
-- AND phone_nm = '680130652' -- venta con VaP finalizando
-- AND phone_nm = '652112477' -- multiventa con PU previo
-- AND phone_nm = '744602341' -- multiventa con PU previo
-- AND phone_nm = '670062679' -- multiventa con PU previo (antes del IF anidado en campo multidispositivo, los 2 disp de marzo 26 aparecían como primarios)
-- AND phone_nm IN ('686770891','602663544') -- imei duplicado mayúsculas y minúsculas 301FC3034K00000 --> phone_nm correcto 602663544
-- AND phone_nm IN ('644860819','648056876') -- imei duplicado 1S82XB00EJSPPF5V3VXW --> phone_nm correcto 644860819
-- AND phone_nm = '603305150' -- multiventa con sale_rank 1. Ambos dispositivos aparecían como primarios
-- AND phone_nm = '648669388' -- amortización

ORDER BY order_date, device_rank
;

ASSERT NOT EXISTS (
  SELECT 1
  FROM `mm-commissions-reporting.TEMP.multidispositivos_final_nc`
  WHERE multidispositivo = 'PRIMARIO'
    AND order_date >= '2026-10-01'
    AND COALESCE(sell_type, '') <> 'CAPTACION'
    AND COALESCE(offer_segmentation, '') <> 'OMM'
  GROUP BY phone_nm, DATE_TRUNC(order_date, MONTH)
  HAVING COUNT(*) > 1
) AS 'ERROR: hay lineas con mas de un dispositivo PRIMARIO en el mismo mes (desde 2026-10-01)';


SET tabla_nombre = CONCAT('`mm-commissions-reporting.COMISIONES.categorizacion_dispositivos_', mes_string, '_nc`');
SET qry = 'CREATE OR REPLACE TABLE ' || tabla_nombre || ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.multidispositivos_final_nc`';
EXECUTE IMMEDIATE qry;

END