BEGIN
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION_MM.UNITARIOS`;

    INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES`
    SELECT
      DISTINCT a.* REPLACE( importe_dealer * (CASE
            WHEN multiplicador = 'POST' THEN POST
            WHEN multiplicador = 'FMC' THEN FMC
          ELSE
          1
        END
          -1) AS importe_dealer, 'Rappel' AS CONCEPTO_DS,
        CASE
          WHEN subcanal_ds LIKE 'NO EXCLUS%'THEN importe_porta_dealer * (CASE
            WHEN multiplicador = 'POST' THEN POST
            WHEN multiplicador = 'FMC' THEN FMC
          ELSE
          1
        END
          -1)
        ELSE
        0
      END
        AS importe_porta_dealer, 0 AS importe_gestor, 0 AS importe_porta_gestor, 0 AS importe_segmento )
    FROM
      `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES` a
    INNER JOIN
      `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_MULTIPLICADOR` b
    ON
      a.agente_alta_id = b.agente
      AND a.multiplicador IN ('POST',
        'FMC');

END