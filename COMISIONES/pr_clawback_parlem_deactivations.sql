BEGIN

--CALL `mm-commissions-reporting.COMISIONES.pr_clawback_parlem_deactivations`();

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.clawback_parlem_deactivations` AS 
  WITH BASE AS (

      SELECT
          phone_nm,
          activation_date,
          deactivation_date,
          sale_date,
          brand_ds

      FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`

      WHERE NOT (
          activation_date IS NULL
          AND deactivation_date IS NULL
      )

  ),

  ORDERED AS (

      SELECT
          *,

          LAG(deactivation_date) OVER (
              PARTITION BY phone_nm
              ORDER BY activation_date
          ) AS prev_deactivation_date

      FROM BASE
  ),

  GROUPED AS (

      SELECT
          *,

          CASE
              WHEN prev_deactivation_date IS NULL THEN 1

              WHEN DATE_DIFF(
                      activation_date,
                      prev_deactivation_date,
                      DAY
                   ) > 15
                   THEN 1

              ELSE 0
          END AS new_cycle_flag

      FROM ORDERED
  ),

  CYCLES AS (

      SELECT
          *,

          SUM(new_cycle_flag) OVER (
              PARTITION BY phone_nm
              ORDER BY activation_date
          ) AS cycle_id

      FROM GROUPED
  ),

  LAST_CYCLE AS (

      SELECT *
      FROM CYCLES

      QUALIFY cycle_id = MAX(cycle_id) OVER (
          PARTITION BY phone_nm
      )
  ),

  DEACTIVATIONS AS (

      SELECT
          phone_nm,
          brand_ds,

          MIN(activation_date) AS activation_date,

          CASE
              WHEN COUNTIF(deactivation_date IS NULL) > 0
                  THEN NULL
              ELSE MAX(deactivation_date)
          END AS deactivation_date,

          MAX(sale_date) AS sale_date

      FROM LAST_CYCLE

      GROUP BY
          phone_nm,
          brand_ds
  )

  SELECT * FROM DEACTIVATIONS;

END