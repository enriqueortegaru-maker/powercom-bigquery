BEGIN

-- CALL `mm-commissions-reporting.TERMINALES.pr_multidispositivos_v2`(202603);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.financiaciones_categ_disp` AS
SELECT 
  phone_nm
  ,serial_number
  ,brand_ds
  ,sell_type
  ,terminal_status_ds
  ,order_date
  ,CASE 
       WHEN is_financed_desc IN ('SI','PAGO FINANCIADO') THEN DATE(fecha_fin_financiacion) 
       WHEN is_financed_desc IN ('NO','PAGO UNICO') THEN DATE_ADD(order_date, INTERVAL 12 MONTH) -- Por indicación de Enrique, se está asociando un compromiso de permanencia de 12 meses a todos los pagos únicos
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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.multidispositivos_v2` AS

-- Ubicamos los imeis duplicados con mayúculas y minúsculas
WITH duplicados_mayus AS (
SELECT serial_number, UPPER(serial_number) AS imei_mayus
FROM `mm-datamart-kd.SERVICES.devices_base_emysim` a
INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
    ON a.user_store = b.id_comisionista AND b.comisiona
WHERE 1 = 1
and terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
and DATE(order_date) >= '2025-09-01'
GROUP BY ALL
),

-- Unimos los imeis encontrados arriba con el resto de duplicados
imeis_duplicados AS (
    SELECT a.serial_number
           ,sell_terminal_origin_ds
           ,terminal_status_ds
           ,order_date
           ,user_store
           ,brand_ds
           ,phone_nm
           ,is_financed_desc
           ,financed_end_date
           ,device_type_ds
           ,terminal_name
    FROM `mm-datamart-kd.SERVICES.devices_base_emysim` a

    INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
                  ON a.user_store = b.id_comisionista AND b.comisiona

    LEFT JOIN (SELECT serial_number
               FROM `mm-datamart-kd.SERVICES.devices_base_emysim` a
 
               INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
                   ON a.user_store = b.id_comisionista AND b.comisiona
 
               WHERE 1 = 1
               and terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
               and DATE(order_date) >= '2025-09-01'
               GROUP BY ALL
               HAVING COUNT(serial_number) > 1
               ORDER BY serial_number
              ) c
              ON a.serial_number = c.serial_number

    LEFT JOIN (SELECT imei_mayus
               FROM duplicados_mayus
               GROUP BY ALL
               HAVING COUNT(imei_mayus) > 1
              ) d
              ON UPPER(a.serial_number) = d.imei_mayus


    WHERE terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
    AND DATE(order_date) >= '2025-09-01'
    AND (a.serial_number = c.serial_number OR UPPER(a.serial_number) = d.imei_mayus)
    ORDER BY 1,4
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
    SELECT 
      *
      ,LAG(fecha_fin_financiacion, 1) OVER (PARTITION BY phone_nm ORDER BY order_date) AS fecha_fin_financiacion_previa
      ,MAX(fecha_fin_financiacion) OVER (PARTITION BY phone_nm ORDER BY order_date) AS max_fecha_fin_financiacion
    FROM `mm-commissions-reporting.TEMP.financiaciones_categ_disp`
    WHERE DATE(order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
),

rank_ventas_dispositivos AS (
    SELECT
      DVC.phone_nm,
      DVC.serial_number,
      DVC.terminal_status_ds,
      DVC.order_date,
      CASE
          WHEN DVC.fecha_fin_financiacion IS NOT NULL THEN DATE(DVC.fecha_fin_financiacion) 
          ELSE DATE_ADD(DVC.order_date, INTERVAL 12 MONTH) -- Por indicación de Enrique, se está asociando un compromiso de permanencia de 12 meses a todos los pagos únicos
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
      CASE WHEN MLT.phone_nm IS NOT NULL THEN 1 ELSE 0 END AS venta_multi
    
    FROM `mm-commissions-reporting.TEMP.device_base` DVC
          
    LEFT JOIN ventas_multidispositivos MLT
            ON DVC.phone_nm = MLT.phone_nm
               AND DVC.order_date = MLT.order_date
               AND DVC.brand_ds = MLT.brand_ds
    
    LEFT JOIN financiaciones_vivas FNC 
            ON DVC.phone_nm = FNC.phone_nm
               AND DVC.order_date = FNC.order_date

    WHERE DVC.brand_ds IN ('MASMOVIL', 'YOIGO')
    AND DATE(DVC.order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query
    AND DVC.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
    
    GROUP BY DVC.phone_nm, DVC.serial_number, DVC.terminal_status_ds, DVC.order_date, DVC.fecha_fin_financiacion, DVC.is_financed_desc, DVC.brand_ds, DVC.activation_date, DVC.deactivation_date, DVC.original_cost_price, DVC.id_subscription_terminal, MLT.phone_nm, FNC.phone_nm, FNC.order_date, FNC.fecha_fin_financiacion_previa, FNC.max_fecha_fin_financiacion
            
)

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
        -- La primera venta siempre es primaria
      WHEN sale_rank = 1 THEN 'PRIMARIO'
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
     END AS multidispositivo
    ,sale_rank
    ,device_rank
    ,venta_multi
    ,* EXCEPT(phone_nm, serial_number, terminal_status_ds, is_financed_desc, order_date, fecha_fin_financiacion, fecha_fin_financiacion_previa, max_fecha_fin_financiacion,sale_rank, device_rank, venta_multi,product) 
FROM (
-- Dispositivos sin IMEIs duplicados
SELECT 
      RANK_DVC.phone_nm
      ,RANK_DVC.serial_number
      ,RANK_DVC.terminal_status_ds
      ,RANK_DVC.is_financed_desc
      ,RANK_DVC.order_date
      ,RANK_DVC.fecha_fin_financiacion
      ,RANK_DVC.fecha_fin_financiacion_previa
      ,RANK_DVC.max_fecha_fin_financiacion
      ,RANK_DVC.sale_rank
      ,RANK_DVC.device_rank
      ,RANK_DVC.venta_multi
      ,DISPOSITIVOS.* EXCEPT(phone_nm, serial_number, terminal_status_ds, is_financed_desc, order_date, fecha_fin_financiacion) 

FROM `mm-commissions-reporting.TEMP.device_base` DISPOSITIVOS

LEFT JOIN imeis_duplicados IMEIS
    ON IMEIS.serial_number = DISPOSITIVOS.serial_number

LEFT JOIN rank_ventas_dispositivos RANK_DVC 
    ON RANK_DVC.serial_number = DISPOSITIVOS.serial_number


WHERE DISPOSITIVOS.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
      AND IMEIS.serial_number IS NULL
      AND DATE(DISPOSITIVOS.order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query

UNION ALL

-- IMEIs duplicados
SELECT 
      RANK_DVC.phone_nm
      ,RANK_DVC.serial_number
      ,RANK_DVC.terminal_status_ds
      ,RANK_DVC.is_financed_desc
      ,RANK_DVC.order_date
      ,RANK_DVC.fecha_fin_financiacion
      ,RANK_DVC.fecha_fin_financiacion_previa
      ,RANK_DVC.max_fecha_fin_financiacion
      ,RANK_DVC.sale_rank
      ,RANK_DVC.device_rank
      ,RANK_DVC.venta_multi
      ,DISPOSITIVOS.* EXCEPT(phone_nm, serial_number, terminal_status_ds, is_financed_desc, order_date, fecha_fin_financiacion) 

FROM `mm-commissions-reporting.TEMP.device_base` DISPOSITIVOS

INNER JOIN imeis_duplicados IMEIS
    ON IMEIS.serial_number = DISPOSITIVOS.serial_number

LEFT JOIN rank_ventas_dispositivos RANK_DVC 
    ON RANK_DVC.serial_number = DISPOSITIVOS.serial_number


WHERE DISPOSITIVOS.terminal_status_ds IN UNNEST (`mm-commissions-reporting.COMISIONES.f_terminal_status`())
AND DATE(DISPOSITIVOS.order_date) >= '2022-01-01' -- Filtramos desde hace 4 años (máx. tiempo financiación) por aligerar la query

QUALIFY ROW_NUMBER() OVER(
                          PARTITION BY IMEIS.serial_number 
                          ORDER BY 
                                   IMEIS.order_date ASC, 
                                   CASE WHEN DISPOSITIVOS.status_servicio = 'ACTIVATED' THEN 1 ELSE 2 END ASC
                         ) = 1
)
-- WHERE phone_nm = '653487897' -- multiventa con VaP previa
-- WHERE phone_nm = '655148352' -- venta con VaP en curso
-- WHERE phone_nm = '680130652' -- venta con VaP finalizando
-- WHERE phone_nm = '652112477' -- multiventa con PU previo
-- WHERE phone_nm = '744602341' -- multiventa con PU previo
-- WHERE phone_nm = '670062679' -- multiventa con PU previo (antes del IF anidado en campo multidispositivo, los 2 disp de marzo 26 aparecían como primarios)
-- WHERE phone_nm IN ('686770891','602663544')
ORDER BY order_date, device_rank
;

END