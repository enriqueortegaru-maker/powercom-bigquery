BEGIN

-- VARIABLES PARA RELANZAR HACIA ATRAS
DECLARE mes_siguiente DATE;
set mes_siguiente = DATE_ADD(MES, INTERVAL 1 MONTH);
--CALL `mm-commissions-reporting.B2B.services_base_net_agrupado_CM_`('2026-08-01')


--Proceso adaptado a services.services

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tipo_activacion_service_AGRUPADO_final` AS
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.services_base_net_agrupado_CM` AS
WITH 

  datos AS (

    SELECT
      comm_brand_ds,
      customer_id,
      service_id,
      service_type,
      phone_nm,
      activation_date,
      CASE
        WHEN deactivation_date >= mes_siguiente THEN NULL -- Para que la tabla tenga la info hasta este dia
        ELSE deactivation_date
      END AS deactivation_date,

      tariff_id,
      tariff_ds,
      account_id

    FROM `mm-datamart-kd.SERVICES.service_base_net`

    WHERE activation_date IS NOT NULL
      AND comm_brand_ds = 'CABLEMOVIL'
      AND activation_date < mes_siguiente -- Para que la tabla tenga la info hasta este dia
   ),
  fechas AS (
    SELECT
     *,
     LAG(deactivation_date) OVER (PARTITION BY phone_nm, customer_id ORDER BY activation_date ASC) AS desactivacion_anterior

    FROM datos

    WHERE activation_date IS NOT NULL
      AND comm_brand_ds = 'CABLEMOVIL'
      -- AND activation_date >= '2024-12-01' 
  ),

  diferencias AS (
     SELECT
       *,
       DATE_DIFF(activation_date,desactivacion_anterior,DAY) AS dias_desde_desactivacion_anterior,
       CASE
         WHEN desactivacion_anterior IS NULL THEN 1
         WHEN DATE_DIFF(activation_date,desactivacion_anterior,DAY) > 5 THEN 1
         ELSE 0
       END AS nueva_venta

      FROM fechas
  ),

  grupos AS (
    SELECT
      *,
      SUM(nueva_venta) OVER (PARTITION BY phone_nm, customer_id ORDER BY activation_date ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS grupo_venta

    FROM diferencias
  )

SELECT
  comm_brand_ds,
  customer_id,
  ARRAY_AGG(STRUCT(activation_date,deactivation_date,tariff_id,tariff_ds,account_id)ORDER BY activation_date DESC LIMIT 1)[SAFE_OFFSET(0)].account_id AS account_id,
  service_id,
  service_type,
  phone_nm,
  grupo_venta,
  MIN(activation_date) AS activation_date,
  ARRAY_AGG(STRUCT(activation_date,deactivation_date,tariff_id,tariff_ds,account_id)ORDER BY activation_date DESC LIMIT 1)[SAFE_OFFSET(0)].deactivation_date AS deactivation_date ,
  ARRAY_AGG(STRUCT(activation_date,deactivation_date,tariff_id,tariff_ds,account_id)ORDER BY activation_date DESC LIMIT 1)[SAFE_OFFSET(0)].tariff_id AS tariff_id,
  ARRAY_AGG(STRUCT(activation_date,deactivation_date,tariff_id,tariff_ds,account_id)ORDER BY activation_date DESC LIMIT 1)[SAFE_OFFSET(0)].tariff_ds AS tariff_ds,
  --COUNT(*) AS numero_registros

FROM grupos

GROUP BY
    comm_brand_ds,
    customer_id,
    service_id,
    service_type,
    phone_nm,
    grupo_venta

-- order by phone_nm,grupo_venta
  ;

END