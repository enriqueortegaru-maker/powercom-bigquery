BEGIN


DECLARE mes_string, prefijo STRING;

SET prefijo = 'CHRN';

SET canales_pr = ['ENK'];

SET mes_string = CAST(id_mes_pr AS STRING);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_autochurn`(202607, ['ENK']);
*/


-- Hacemos conteo de las bajas y altas que tenemos para cada customer_id

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cuenta_servicios_autochurn` AS


SELECT 
  customer_id, 
  brand_ds, 
  -- MIN(activation_date) OVER(PARTITION BY customer_id, phone_nm) AS activation,
  activation_date,
  deactivation_date, 
  'bajas' as tipo, 
  DATE_DIFF(deactivation_date,activation_date, DAY) dias_activo, 
  COUNT(service_id)*-1 cant_servicios

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
WHERE service_type = 'MOBILE'
AND billing_type_ds = 'POSTPAID'
AND deactivation_date != '9999-12-31'
-- AND order_type_agg != 'MIGRACION CONTRATO'
AND activation_date IS NOT NULL
AND deactivation_date BETWEEN DATE_SUB(LAST_DAY(COMISIONES.f_mes_int(id_mes_pr), MONTH), INTERVAL 180 DAY) AND LAST_DAY(COMISIONES.f_mes_int(id_mes_pr), MONTH)
-- AND brand_ds IN ('YOIGO','MASMOVIL','PEPEPHONE','ORANGE','JAZZTEL','SIMYO','EUSKALTEL','R','GUUK','TELECABLE','EMBOU')
AND brand_ds IN ('YOIGO','MASMOVIL','PEPEPHONE')
-- GROUP BY 1,2,activation_date,phone_nm,4,5,6
GROUP BY ALL

UNION ALL

SELECT customer_id, brand_ds, activation_date, deactivation_date, 'altas' as tipo, CAST(null AS INT64) dias_activo, COUNT(service_id) cant_servicios
FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
WHERE service_type = 'MOBILE'
AND billing_type_ds = 'POSTPAID'
AND deactivation_date = '9999-12-31'
AND order_type_agg != 'MIGRACION CONTRATO'
AND activation_date IS NOT NULL
AND DATE_TRUNC(activation_date,MONTH) = COMISIONES.f_mes_int(id_mes_pr)
-- AND brand_ds IN ('YOIGO','MASMOVIL','PEPEPHONE','ORANGE','JAZZTEL','SIMYO','EUSKALTEL','R','GUUK','TELECABLE','EMBOU')
AND brand_ds IN ('YOIGO','MASMOVIL','PEPEPHONE')
GROUP BY ALL

;

-- Si debemos recalcular, limpiamos lo que habíamos agregado como emparejado en el histórico

-- UPDATE `mm-commissions-reporting.TEMP.servicios_x_customer`
-- SET autochurn = false, mes_decomision = CAST(null AS INT64)
-- WHERE mes_decomision = id_mes_pr 

-- ;

DELETE `mm-commissions-reporting.TEMP.historico_emparejados`
WHERE mes_decomision = id_mes_pr 

;

-- Extraemos servicios (phone_nm) por customer_id

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.servicios_x_customer` AS

INSERT INTO `mm-commissions-reporting.TEMP.servicios_x_customer` -- SE DEBE INSERTAR POR ID_MES_PR PARA NO MACHACAR EL BOOLEANO (FALTAN LOS 2 PRIMEROS MESES PORQUE NO HABÍA CAMBIADO AL INSERT Y SE RECREABA LA TABLA)

SELECT 
  brand_ds, 
  customer_id, 
  phone_nm, 
  -- MIN(activation_date) OVER(PARTITION BY customer_id, phone_nm) AS activation_date_min, 
  activation_date,
  deactivation_date, 
  CAST(null AS BOOL) AS autochurn, 
  CAST(null AS INT64) mes_decomision

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
WHERE service_type = 'MOBILE'
AND billing_type_ds = 'POSTPAID'
AND activation_date IS NOT NULL
AND brand_ds IN ('YOIGO','MASMOVIL','PEPEPHONE')
-- AND order_type_agg != 'MIGRACION CONTRATO'
-- AND activation_date < COMISIONES.f_mes_int(mes_int) -- CAMBIAR POR MES_INT
AND (deactivation_date >= DATE_SUB(COMISIONES.f_mes_int(id_mes_pr), INTERVAL 30 DAY) OR deactivation_date = '9999-12-31')
-- GROUP BY 1,2,3,activation_date,5,6,7
GROUP BY ALL
-- QUALIFY ROW_NUMBER() OVER(PARTITION BY brand_ds, customer_id, phone_nm, deactivation_date ORDER BY deactivation_date DESC, activation_date ASC) = 1 

;

-- Marcamos los servicios que serán útiles para hacer autochurn según las reglas de 180 y 90 días

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.autochurn_90_dias` AS

SELECT 
    TRANSACCIONES.customer_id,
    SERVICIOS.brand_ds,
    SERVICIOS.dias_activo,
    SERVICIOS.activation_date,
    SERVICIOS.deactivation_date,
    SERVICIOS.cant_servicios,
    SERVICIOS.tipo,
    
    CASE 
        WHEN dias_activo > 180 THEN
                      CASE   
                          WHEN DATE_DIFF(TRANSACCIONES.activation_date, SERVICIOS.deactivation_date, DAY) BETWEEN 0 AND 30 THEN 30 -- CAMBIÓ A 30 DÍAS A PARTIR DE MARZO 2026
                          WHEN DATE_DIFF(TRANSACCIONES.activation_date, SERVICIOS.deactivation_date, DAY) BETWEEN -30 AND -1 THEN -30
                          ELSE CAST(null AS INT64)
                      END

        -- WHEN dias_activo <= 180 THEN 
        --               CASE 
        --                   WHEN DATE_DIFF(TRANSACCIONES.activation_date, SERVICIOS.deactivation_date, DAY) BETWEEN 0 AND 30 THEN 30 
        --                   ELSE CAST(null AS INT64)
        --               END -- CAMBIÓ A PARTIR DE MARZO 2026

    END AS dias_alta_baja_customer,

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.cuenta_servicios_autochurn` SERVICIOS
        ON TRANSACCIONES.customer_id = SERVICIOS.customer_id

WHERE TRANSACCIONES.id_mes = id_mes_pr
AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
AND TRANSACCIONES.service_type = 'MOBILE'
AND TRANSACCIONES.billing_type_ds = 'POSTPAID'
AND DATE_TRUNC(TRANSACCIONES.activation_date,MONTH) = COMISIONES.f_mes_int(id_mes_pr)
AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago','E - Clawback Servicio Movil Pospago','Z - Clawback Servicio Movil Pospago')
GROUP BY TRANSACCIONES.customer_id,TRANSACCIONES.activation_date,SERVICIOS.deactivation_date,SERVICIOS.tipo,SERVICIOS.activation_date,TRANSACCIONES.deactivation_date,TRANSACCIONES.marca,SERVICIOS.dias_activo, SERVICIOS.cant_servicios, SERVICIOS.brand_ds
QUALIFY ROW_NUMBER() OVER(PARTITION BY TRANSACCIONES.customer_id,SERVICIOS.activation_date,SERVICIOS.deactivation_date,SERVICIOS.tipo) = 1

;

-- Incluimos phone_nm a la tabla anterior

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.autochurn_90_dias_servicios` AS

SELECT 
  SERVICIOS.*
  ,CASE
       WHEN SERVICIOS.activation_date = AUTOCHURN.activation_date AND SERVICIOS.deactivation_date = AUTOCHURN.deactivation_date THEN AUTOCHURN.dias_alta_baja_customer 
       ELSE CAST(null AS INT64)
   END AS dias_alta_baja_customer

FROM `mm-commissions-reporting.TEMP.autochurn_90_dias` AUTOCHURN

LEFT JOIN `mm-commissions-reporting.TEMP.servicios_x_customer` SERVICIOS
        ON AUTOCHURN.customer_id = SERVICIOS.customer_id
           AND AUTOCHURN.brand_ds = SERVICIOS.brand_ds
           AND AUTOCHURN.activation_date = SERVICIOS.activation_date
           AND AUTOCHURN.deactivation_date = SERVICIOS.deactivation_date

;


-- ============================================

-- EMPAREJAMIENTO ALEATORIO ACTIVACIONES ↔ BAJAS

-- Devuelve phone_nm DE ACTIVACIÓN y DE BAJA

-- ============================================

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.emparejados` AS

WITH

-- 1) Activaciones filtradas

trans_base AS (
  SELECT
    t.customer_id,
    t.activation_date,
    t.seller,
    t.marca,
    t.phone_nm
  FROM `mm-commissions-reporting.COMISIONES.transacciones` t
  WHERE t.agrupacion_canal = 'Exclusivo'
    AND t.service_type = 'MOBILE'
    AND DATE_TRUNC(t.activation_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
    AND t.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago')
),

-- 2) Agrupa activaciones si hay varias unidades por fila

a_group AS (
  SELECT
    customer_id,
    activation_date,
    seller,
    marca,
    phone_nm,
    COUNT(1) AS cuenta_servicios
  FROM trans_base
  GROUP BY customer_id, activation_date, seller, marca, phone_nm
),

-- 3) Explota activaciones a nivel unidad

a_units AS (
  SELECT
    customer_id,
    activation_date,
    seller,
    marca,
    phone_nm AS phone_nm_activacion,
    -- unit_idx
  FROM a_group--, UNNEST(GENERATE_ARRAY(1, cuenta_servicios)) AS unit_idx
),

-- 4) Bajas agregadas con phone_nm

b_raw AS (
  SELECT DISTINCT
    au.customer_id,
    aus.deactivation_date,
    aus.phone_nm AS phone_nm_baja,
    COUNT(aus.phone_nm) AS unidades_baja
  FROM `mm-commissions-reporting.TEMP.autochurn_90_dias` au

  INNER JOIN `mm-commissions-reporting.TEMP.autochurn_90_dias_servicios` aus USING (customer_id)
  WHERE au.tipo = 'bajas'
  AND aus.dias_alta_baja_customer IS NOT NULL
  GROUP BY ALL
),

-- 5) Explota bajas por unidad

b_units AS (
  SELECT
    customer_id,
    deactivation_date,
    phone_nm_baja,
    -- unit_idx
  FROM b_raw--, UNNEST(GENERATE_ARRAY(1, unidades_baja)) AS unit_idx
),

-- 6) Aleatoriza activaciones por cliente

a_rand AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
                        PARTITION BY customer_id
                        ORDER BY activation_date DESC,phone_nm_activacion ASC,RAND()
                      ) AS rn
  FROM a_units
),

-- 7) Aleatoriza bajas por cliente

b_rand AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
                        PARTITION BY customer_id
                        ORDER BY deactivation_date DESC, phone_nm_baja DESC,RAND()
                      ) AS rn
  FROM b_units
)

-- 8) EMPAREJAMIENTO 1:1

SELECT
  COALESCE(a.customer_id, b.customer_id) AS customer_id,

  -- Activación
  a.activation_date,
  a.seller,
  a.marca,
  a.phone_nm_activacion,
  -- a.unit_idx AS unidad_activacion,

  -- Baja
  b.phone_nm_baja,
  -- b.unit_idx AS unidad_baja,

  -- Estado (match / sobrante)
  CASE
    WHEN a.customer_id IS NOT NULL AND b.customer_id IS NOT NULL THEN 'emparejado'
    WHEN a.customer_id IS NOT NULL AND b.customer_id IS NULL THEN 'sobrante_activacion'
    WHEN a.customer_id IS NULL     AND b.customer_id IS NOT NULL THEN 'sobrante_baja'

  END AS estado

FROM a_rand a

LEFT JOIN b_rand b
  ON a.customer_id = b.customer_id
  AND a.rn = b.rn
  -- AND a.phone_nm_activacion <> b.phone_nm_baja

LEFT JOIN `mm-commissions-reporting.TEMP.historico_emparejados` em
  ON b.phone_nm_baja  = em.phone_nm_baja

WHERE em.phone_nm_baja IS NULL

ORDER BY customer_id, estado;
 


-- Insertamos en el histórico con el que cruzamos en la tabla anterior para saber los que ya se han emparejado

INSERT INTO `mm-commissions-reporting.TEMP.historico_emparejados`

SELECT *, id_mes_pr AS mes_decomision
FROM `mm-commissions-reporting.TEMP.emparejados`
WHERE estado = 'emparejado'

;


-- Sacamos cálculo de comisiones que se deben retroceder

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calculo_autochurn` AS

SELECT
      TRANSACCIONES.* EXCEPT(comments,comision,commission_id, concepto)
     ,'Autochurn Emparejado con '||EMPAREJAMIENTOS.phone_nm_baja AS comments
     ,TRANSACCIONES.comision * -1 AS comision
     ,prefijo || '_'|| mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER() AS commission_id
     ,REPLACE(TRANSACCIONES.concepto,SUBSTR(TRANSACCIONES.concepto,1,4),'P - ') AS concepto
      
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.emparejados` EMPAREJAMIENTOS
        ON TRANSACCIONES.customer_id = EMPAREJAMIENTOS.customer_id
        AND TRANSACCIONES.phone_nm = EMPAREJAMIENTOS.phone_nm_activacion

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE
                 WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('P', 'Q', 'R', 'S', 'Y', 'Z')
                 THEN SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
                 ELSE TRANSACCIONES.concepto
             END
             =
             CASE
                 WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('P', 'Q', 'R', 'S', 'Y', 'Z')
                 THEN SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto))
                 ELSE CONCEPTOS.concepto
             END
          AND CASE 
                   WHEN SUBSTR(TRANSACCIONES.concepto,5) = 'Extracomision terminal' THEN 'DCEX'
                   ELSE CONCEPTOS.proceso 
              END
              = CONCEPTOS.proceso 
          AND TRANSACCIONES.tipo_concepto = CONCEPTOS.tipo_concepto 

LEFT JOIN `mm-commissions-reporting.GS.exclusivo_dealers` DEALER
        ON TRANSACCIONES.seller = DEALER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final_nc` DISPOSITIVOS
        ON TRANSACCIONES.serial_number = DISPOSITIVOS.serial_number
        AND DISPOSITIVOS.sell_type = 'CAPTACION'

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE TRANSACCIONES.agrupacion_canal = 'Exclusivo'
    AND TRANSACCIONES.service_type = 'MOBILE'
    AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
    AND CONCEPTOS.tipo_concepto = 'UPFR'
    AND (TRANSACCIONES.concepto IN (
                                    'A - Servicio Movil Pospago',
                                    'Z - Servicio Movil Pospago',
                                    'A - Portabilidad Movil Pospago',
                                    'D - Extracomision Objetivo Movil Pospago',
                                    'D - Extracomision Segmentacion'
                                   )
        OR
          (DISPOSITIVOS.sell_type = 'CAPTACION'
           AND TRANSACCIONES.concepto IN (
                                          'D - Extracomision terminal', -- se quita extra renuevo ppal y se agrega extra terminal por confirmación correo Laura González Rey del 11/06/2026
                                          'D - Extracomision Objetivo Terminales' -- correo Laura González Rey del 11/06/2026
                                         )
          )
        )                         
    AND TRANSACCIONES.canal = canal_pr
    AND TRANSACCIONES.estado != 'rechazado'
    AND TRANSACCIONES.comision <> 0.0
    AND EMPAREJAMIENTOS.estado = 'emparejado'
    AND DEALER.comisiona
    AND DEALER.canal = canal_pr
;

UPDATE `mm-commissions-reporting.TEMP.servicios_x_customer`
SET autochurn = true, mes_decomision = id_mes_pr
WHERE phone_nm IN (SELECT phone_nm_baja FROM `mm-commissions-reporting.TEMP.emparejados` WHERE estado = 'emparejado' GROUP BY ALL)
AND deactivation_date != '9999-12-31'
;

-- VALIDACIÓN PHONE_NM NO HAYA SIDO EMPAREJADO ANTERIORMENTE
ASSERT NOT EXISTS
(
SELECT DISTINCT CALCULO.phone_nm
FROM `mm-commissions-reporting.TEMP.calculo_autochurn` CALCULO 

LEFT JOIN `mm-commissions-reporting.TEMP.historico_emparejados` HISTORICO
    ON SUBSTR(CALCULO.comments,16,9) = HISTORICO.phone_nm_baja

WHERE HISTORICO.phone_nm_baja IS NOT NULL
AND CALCULO.id_mes != HISTORICO.mes_decomision
QUALIFY ROW_NUMBER() OVER (PARTITION BY CALCULO.phone_nm, CALCULO.marca, CALCULO.customer_id) = 1
) AS 'Hay phone_nm que ya han sido emparejados'
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.calculo_autochurn'  , 'ACTUALIZAR');

END