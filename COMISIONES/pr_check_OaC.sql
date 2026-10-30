BEGIN

--CALL `mm-commissions-reporting.COMISIONES.pr_check_OaC`();

  CALL `mm-commissions-reporting.TERMINALES.pr_device_base`();  

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.check_OaC`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT *
    FROM (
      SELECT DEVICE.master_channel_ds, DEVICE.agrupacion_canal, DEVICE.product_code, DEVICE.terminal_name, DEVICE.purch_price, DEVICE.order_date
        , OAC.precio_oac
        , CASE WHEN OAC.precio_oac IS NULL THEN 'Revisar - Falta precio_oac' ELSE CAST(ROUND((precio_oac - DEVICE.purch_price),2) AS STRING) END AS diferencia
    --    , DEVICE.seller
        , COUNT(DISTINCT(DEVICE.serial_number)) AS cuenta_IMEIs
/*
      FROM `mm-commissions-reporting.TEMP.device_base` DEVICE
        LEFT JOIN `mm-commissions-reporting.TEMP.dispositivos_OaC` OAC
          ON  OAC.codigo = DEVICE.product_code
          AND OAC.fecha_inicio <= DEVICE.order_date
          AND OAC.fecha_fin >= DEVICE.order_date
          AND DEVICE.agrupacion_canal = OAC.agrupacion_canal
*/
      FROM `mm-commissions-reporting.TEMP.device_base` DEVICE
        LEFT JOIN `mm-commissions-reporting.TEMP.codigos_OaC` CODE
          ON  CODE.product_code = DEVICE.product_code
        LEFT JOIN `mm-commissions-reporting.TEMP.dispositivos_OaC` OAC
          ON  OAC.modelo = CODE.terminal_name
          AND OAC.fecha_inicio <= DEVICE.order_date
          AND OAC.fecha_fin >= DEVICE.order_date
          --AND DEVICE.agrupacion_canal = OAC.agrupacion_canal
          AND UPPER(DEVICE.master_channel_ds) = UPPER(OAC.agrupacion_canal)
      --WHERE order_date >= '2025-06-20'
      WHERE order_date >= (DATE_TRUNC(CURRENT_DATE(), MONTH) - 30)
        AND master_channel_ds IN ('EXCLUSIVO','NO EXCLUSIVO')
      GROUP BY ALL
    )
    WHERE purch_price IS NOT NULL
      AND ( 
          (purch_price - precio_oac) >  0.01
      OR (purch_price - precio_oac) < -0.01
      OR precio_oac IS NULL
      )
    ORDER BY 1,7 DESC,2,3,4,5,6;

END