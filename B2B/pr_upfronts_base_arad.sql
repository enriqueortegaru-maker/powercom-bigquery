BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre STRING;
DECLARE mes DATE;

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); -- 202504;
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','upfronts_base_arad_', mes_liqui, '');

-- CALL `mm-commissions-reporting.B2B.pr_upfronts_base_arad`()

IF NOT EXISTS(
  SELECT *
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE canal = 'ADA'
    AND id_mes = CAST(mes_string AS INT64)
    AND (commission_id LIKE 'ARAD%' AND commission_id LIKE CONCAT("ARAD_",CAST(mes_string AS INT64),"_%"))
    AND mes_liquidado = mes
  GROUP BY ALL
  ) THEN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.upfronts_base_arad`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 
    base_act AS (   
      SELECT  
        a.brand_id,
        a.customer_id,
        a.account_id,
        a.service_id,
        a.phone_nm,
        a.tariff_id,
        a.tariff_ds,
        a.line_type_ds,
        a.technology_ds,
        a.billing_type_ds,
        IF(a.service_type IN ('FIX','BROADBAND'), 'INTERNET',a.service_type) AS service_type, 
        '216517' AS CLIENTE,
        b.bono_id,
        b.bono_name,
        IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds,
        a.activation_date,
        IF(a.deactivation_date > LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH),NULL,a.deactivation_date) AS deactivation_date,
        IFNULL(m.arpu,0) AS arpu
      FROM  `mm-datamart-kd.SERVICES.service_base_net` a
      LEFT JOIN (
        SELECT service_id,
          customer_id,
          phone_nm,
          bono_id,
          bono_name,
          SAFE.PARSE_DATE('%Y%m%d',init_date) AS init_date,
          SAFE.PARSE_DATE("%Y%m%d", end_date) AS end_date,
        FROM `mm-datamart-kd.SERVICES.bonos_base_xena`
        WHERE 1=1
          AND fuente = 'MSISDN'
          AND customer_id = '216517'
          AND SAFE.PARSE_DATE('%Y%m%d',init_date) BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) AND LAST_DAY((PARSE_DATE('%Y%m',mes_string))) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
          AND SAFE.PARSE_DATE("%Y%m%d", end_date)  >= DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      ) b ON a.service_id = b.service_id AND a.customer_id = b.customer_id AND CAST(a.phone_nm AS STRING) = b.phone_nm 
      JOIN (
        --Buscamos en el HISTORIAL del account_id si una linea anterior ha tenido un kpi_gross_add = 1
        SELECT
          account_id,
          MIN(activation_date) AS min_act_date
        FROM `mm-datamart-kd.SERVICES.service_base_net`
        WHERE customer_id = '216517' 
          AND activation_date IS NOT NULL 
          AND line_type_ds = 'MAIN' 
          AND service_type = 'MOBILE' 
          AND (deactivation_date IS NULL OR LAST_DAY(deactivation_date) = LAST_DAY((PARSE_DATE('%Y%m',mes_string)))) --LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH))
          AND kpi_gross_add = 1
        GROUP BY 1
      ) c ON a.account_id = c.account_id AND a.activation_date = c.min_act_date
      LEFT JOIN (
        SELECT DISTINCT
          id_producto_2,
          id_bono,
          tipo_paquete,
          pvp_sin_iva,
          concatenado,
          arpu
          FROM `mm-b2b-reporting.MAESTROS.Maestro_BI_XENA_bonos_cartera`
      ) m ON m.id_bono = b.bono_id
      WHERE 1=1
        AND a.customer_id = '216517'
        AND activation_date IS NOT NULL 
        AND line_type_ds = 'MAIN' 
        AND service_type = 'MOBILE'
        AND a.kpi_gross_add = 1 
        AND tariff_ds NOT LIKE ('%TRV%')
        --Ejemplos: activation '2023-05-01' AND '2023-05-31'// deactivation '2023-06-01'
        AND ((a.activation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH)AND LAST_DAY((PARSE_DATE('%Y%m',mes_string)))) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)))     
        AND (a.deactivation_date IS NULL OR a.deactivation_date >= DATE_TRUNC(DATE_ADD((PARSE_DATE('%Y%m',mes_string)), INTERVAL 1 MONTH),MONTH))) --DATE_TRUNC(CURRENT_DATE(), MONTH))
    ),
    
    base_act_f AS (
      SELECT *
      FROM base_act
      WHERE 1=1
        AND arpu > 0
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm) = 1 --No se incluye activation_date como en el clawback.
    ),

    def_altas AS (
      SELECT *,
        row_number() over (partition by account_id order by arpu DESC, activation_date ASC, phone_nm DESC) AS ordenar_account_ids,
        CASE
          WHEN deactivation_date IS NOT NULL THEN '3. DX'
          ELSE '2. GROSS ADD'
        END AS kpi
      FROM base_act_f
      )

  SELECT *
  FROM def_altas
  ;

  --Montamos la query de creación de la tabla diaria /
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.upfronts_base_arad`';
  EXECUTE IMMEDIATE qry;
  END IF;
END