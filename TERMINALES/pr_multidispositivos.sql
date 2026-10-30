BEGIN

-- CALL `mm-commissions-reporting.TERMINALES.pr_multidispositivos`(202603);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.multidispositivos` AS

WITH imeis_duplicados AS (
    SELECT serial_number
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

    INNER JOIN `mm-commissions-reporting.GS.exclusivo_dealers` b
                  ON a.user_store = b.id_comisionista AND b.comisiona

    WHERE terminal_status_ds IN ('FINANCIACION EN CURSO',
                              'AMORTIZACION PENDIENTE',
                              'USADO',
                              'EN FINANCIACION')
    AND DATE(order_date) >= '2025-09-01'
    AND serial_number IN (
        SELECT serial_number
        FROM (
              SELECT serial_number, --terminal_status_ds, COUNT(serial_number) cuenta, --DATE_TRUNC(DATE(order_date), MONTH) as mes
              -- serial_number,sell_terminal_origin_ds,terminal_status_ds,order_date,user_store,brand_ds, phone_nm,is_financed_desc,financed_end_date, * except(tech_description)
              FROM `mm-datamart-kd.SERVICES.devices_base_emysim` a

              INNER JOIN `mm-commissions-reporting.GS.exclusivo_dealers` b
                  ON a.user_store = b.id_comisionista AND b.comisiona

              WHERE 1 = 1
              and terminal_status_ds in ('FINANCIACION EN CURSO',
                              'AMORTIZACION PENDIENTE',
                              'USADO',
                              'EN FINANCIACION')
              and DATE(order_date) >= '2025-09-01'
              GROUP BY ALL
              HAVING COUNT(serial_number) > 1
              ORDER BY serial_number
              )
        )
    ORDER BY 1,4
)

SELECT 
      DISPOSITIVOS.* 
      ,CASE 
          WHEN MULTI.serial_number IS NOT NULL THEN 'SECUNDARIO'
          ELSE 'PRIMARIO'          
       END AS multidispositivo

FROM `mm-commissions-reporting.TEMP.device_base` DISPOSITIVOS

LEFT JOIN imeis_duplicados IMEIS
    ON IMEIS.serial_number = DISPOSITIVOS.serial_number

LEFT JOIN (
          SELECT serial_number
          FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

      --     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
      --     ON (
      --          UPPER(RENUEVOS.sfid_id) = DEALER.sfid_id 
      --          OR (RENUEVOS.brand_ds = 'YOIGO' AND SUBSTR(UPPER(RENUEVOS.sfid_id), 1, 2) = DEALER.sfid_id)
      --          OR UPPER(RENUEVOS.seller) = DEALER.sfid_id
      --          OR UPPER(RENUEVOS.user_store) = DEALER.sfid_id
      --          )
      --          AND DEALER.id_mes = mes_pr
               
          WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
                AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
                AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
                -- AND is_financed_desc = 'SI' -- 20260327 COMENTADO PARA INCLUIR PAGOS ÚNICOS EN EL ANÁLISIS DE PRIMARIO O MULTIDISPOSITIVO
            --     AND (
            --            (
            --            DEALER.canal = 'ENK' 
            --            AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
            --            )
            --         OR   
            --            (
            --            DEALER.canal != 'ENK' 
            --            AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
            --            )
                  --   )
                AND serial_number IS NOT NULL
          QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, brand_ds
                                    ORDER BY RENUEVOS.activation_date ASC,
                                             RENUEVOS.deactivation_date ASC,
                                             RENUEVOS.original_cost_price DESC,
                                             RENUEVOS.serial_number ASC
                                    ) > 1
          ) MULTI
         ON DISPOSITIVOS.serial_number = MULTI.serial_number
WHERE DISPOSITIVOS.terminal_status_ds IN ('AMORTIZACIÓN PENDIENTE','FINANCIACION EN CURSO','USADO')
      AND IMEIS.serial_number IS NULL

UNION ALL

SELECT 
      DISPOSITIVOS.* 
      ,CASE 
          WHEN MULTI.serial_number IS NOT NULL THEN 'SECUNDARIO'
          ELSE 'PRIMARIO'          
       END AS multidispositivo

FROM `mm-commissions-reporting.TEMP.device_base` DISPOSITIVOS

INNER JOIN imeis_duplicados IMEIS
    ON IMEIS.serial_number = DISPOSITIVOS.serial_number

LEFT JOIN (
          SELECT serial_number
          FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS             
          WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
                AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 2 MONTH)
                AND COALESCE(RENUEVOS.fecha_fin_financiacion, '9999-12-31',NULL) > DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)), INTERVAL 4 MONTH)
                AND serial_number IS NOT NULL
          QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, brand_ds
                                    ORDER BY RENUEVOS.activation_date ASC,
                                             RENUEVOS.deactivation_date ASC,
                                             RENUEVOS.original_cost_price DESC,
                                             RENUEVOS.serial_number ASC
                                    ) > 1
          ) MULTI
         ON DISPOSITIVOS.serial_number = MULTI.serial_number

WHERE DISPOSITIVOS.terminal_status_ds IN ('AMORTIZACIÓN PENDIENTE','FINANCIACION EN CURSO','USADO')

QUALIFY ROW_NUMBER() OVER(
                          PARTITION BY IMEIS.serial_number 
                          ORDER BY 
                                   IMEIS.order_date ASC, 
                                   CASE WHEN DISPOSITIVOS.status_servicio = 'ACTIVATED' THEN 1 ELSE 2 END ASC
                         ) = 1

;

END