BEGIN

-- CALL `mm-commissions-reporting.B2B.pr_tipo_activacion_service`()

-- PASO 1: Precalcular ventanas y join maestro

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tipo_activacion_service_p1` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

    SELECT
        a.comm_brand_ds,
        a.customer_id,
        -- a.account_id,
        a.phone_nm,
        a.activation_date,
        a.deactivation_date,
        `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(b.grupo) AS grupo,

        -- Ventanas por phone_nm
        IFNULL(LAG(a.comm_brand_ds) OVER (PARTITION BY a.phone_nm ORDER BY a.activation_date ASC),a.comm_brand_ds) AS prev_brand,
        LAG(a.deactivation_date) OVER (PARTITION BY a.phone_nm ORDER BY a.activation_date ASC) AS prev_deactivation,
        LAG(a.deactivation_date) OVER (PARTITION BY a.customer_id,a.phone_nm ORDER BY activation_date ASC) AS prev_deactivation_cust,
        -- LAG(b.grupo)             OVER (PARTITION BY a.phone_nm ORDER BY a.activation_date ASC) AS prev_grupo,
        IFNULL(UPPER(LAG(b.grupo) OVER (PARTITION BY a.phone_nm ORDER BY a.activation_date ASC)),UPPER(b.grupo))AS prev_grupo,

        -- Ventana por cliente + phone_nm
        ROW_NUMBER() OVER (PARTITION BY a.customer_id, a.phone_nm ORDER BY a.activation_date ASC) AS rn_customer
        

    FROM `mm-datamart-kd.SERVICES.service_base_net` a
    LEFT JOIN `mm-b2b-reporting.MAESTROS.Maestro_B2B` b
        ON a.customer_id = b.customer_id_xena
  
;


-- PASO 2: Clasificar el tipo de activación

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tipo_activacion_service_p2` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

    SELECT
        *,
        CASE
            -- Migración entre marcas distintas
            WHEN DATE_DIFF(activation_date, prev_deactivation, DAY) BETWEEN 0 AND 5
                 AND prev_brand != comm_brand_ds
                THEN CONCAT('MIGRACION ', UPPER(prev_brand))

            -- Migración dentro del mismo grupo
            WHEN rn_customer = 1
                 AND DATE_DIFF(activation_date, prev_deactivation, DAY) BETWEEN 0 AND 5
                 AND prev_grupo = grupo
                 AND grupo != 'NA'
                THEN 'MIGRACION MISMO GRUPO'

            -- Intercomunidad (misma marca, cliente nuevo)
            WHEN rn_customer = 1
                 AND DATE_DIFF(activation_date, prev_deactivation, DAY) BETWEEN 0 AND 5
                 AND prev_brand = comm_brand_ds
                THEN 'INTERCO'

            -- Primera activación del cliente
            WHEN rn_customer = 1
                THEN 'PRIMERA ACTIVACION'

            -- Cambio de tarifa
            WHEN DATE_DIFF(activation_date, prev_deactivation_cust, DAY) BETWEEN 0 AND 5
                THEN 'CAMBIO TARIFA'

            ELSE 'X ACTIVACION'
        END AS first_activation_flag

    FROM `mm-commissions-reporting.TEMP.tipo_activacion_service_p1`
;


-- PASO 3: Calcular fecha de primera activación

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tipo_activacion_service_p3` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

    SELECT
        *,
        -- Marca las filas que inician un nuevo ciclo
        CASE
            WHEN first_activation_flag NOT IN ('CAMBIO TARIFA') 
                THEN activation_date
        END AS inicio_ciclo,

        -- Número de ciclo acumulado para agrupar filas del mismo ciclo
        COUNTIF(first_activation_flag NOT IN ('CAMBIO TARIFA'))
            OVER (PARTITION BY comm_brand_ds, customer_id, phone_nm ORDER BY activation_date ASC) AS num_ciclo,
        
        LEAD(first_activation_flag) OVER (
            PARTITION BY comm_brand_ds, customer_id, phone_nm 
            ORDER BY activation_date ASC
        ) AS next_flag,

        LEAD(activation_date) OVER (
            PARTITION BY comm_brand_ds, customer_id, phone_nm 
            ORDER BY activation_date ASC
        ) AS next_activation_date

    FROM `mm-commissions-reporting.TEMP.tipo_activacion_service_p2`
;


-- PASO 4: Propagar la fecha de inicio de ciclo
CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.tipo_activacion_service` AS

    SELECT
        * EXCEPT(prev_brand,prev_deactivation,prev_deactivation_cust,prev_grupo,rn_customer,inicio_ciclo,num_ciclo,next_flag,next_activation_date),
        CASE
            WHEN first_activation_flag = 'CAMBIO TARIFA' THEN MIN(inicio_ciclo) OVER (
            PARTITION BY comm_brand_ds, customer_id, phone_nm, num_ciclo)
            ELSE NULL 
        END AS primera_activacion,

        CASE
          -- Tiene baja pero el siguiente registro es CAMBIO TARIFA = sigue activa, NO es clawback
          WHEN deactivation_date IS NOT NULL 
              AND next_flag = 'CAMBIO TARIFA'
              THEN FALSE

          -- Tiene baja y no hay continuidad = SÍ es clawback
          WHEN deactivation_date IS NOT NULL 
              AND (next_flag IS NULL OR next_flag NOT IN ('CAMBIO TARIFA'))
              THEN TRUE

            -- Sin baja = no es clawback
            ELSE FALSE
        END AS es_clawback

    FROM `mm-commissions-reporting.TEMP.tipo_activacion_service_p3`
;



END