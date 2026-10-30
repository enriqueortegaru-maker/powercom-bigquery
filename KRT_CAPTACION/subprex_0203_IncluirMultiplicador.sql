BEGIN
  --- PASO 1: Calculo importe con multiplicador y registro en tabla de log
INSERT INTO
  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
SELECT
  DISTINCT a.* replace ('Rappel Llamada' AS concepto_ds,
    a.importe * (CAST(b.multiplicador AS FLOAT64) - 1) AS importe)
FROM
  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` a
INNER JOIN
  `mm-commissions-reporting.KRT_CAPTACION.PARAM_MULTIPLICADOR` b
ON
  a.marca_ds = b.marca_ds
  AND a.canal_alta_ds = b.canal_ds
  AND a.subcanal_ds = b.subcanal_ds
  AND a.nombre_distribuidor_alta_ds = b.nombre_distribuidor_ds; --- PASO 2: Inserto registros en tabla de marco retributivo -- Log de fichero completo
CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CAPTACION.LOG_0203_MARCO_RETRIBUTIVOxCANAL` AS
SELECT
  *
FROM
  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;
CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CAPTACION.LOG_0203_MARCO_RETRIBUTIVOxCANAL_UPD` AS
SELECT
  *
FROM
  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` EXCEPT DISTINCT
SELECT
  *
FROM
  `mm-commissions-reporting.KRT_CAPTACION..LOG_0202_MARCO_RETRIBUTIVOxCANAL`;
END