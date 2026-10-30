BEGIN

  /* PASO 1: Inserción directa del Multiplicador (Rappel Llamada)
     Se elimina la creación de la tabla física intermedia (LOG_..._UPD) y el costoso DISTINCT.
     Se inserta directamente en la tabla destino.
  */
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
  
  SELECT 
      a.* REPLACE (
          'Rappel Llamada' AS concepto_ds,	
          a.importe * (CAST(b.multiplicador AS FLOAT64) - 1) AS importe, 
          'D - Extracomision' AS clase_mm, 
          'D - Multiplicador' AS desc_mm
      ) 
  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` a 
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_MULTIPLICADOR` b
      ON a.marca_ds = b.marca_ds 
      AND a.canal_alta_ds = b.canal_ds 
      AND a.subcanal_ds = b.subcanal_ds 
      AND a.nombre_distribuidor_alta_ds = b.nombre_distribuidor_ds
  WHERE 
      -- IDEMPOTENCIA: Evita aplicar el multiplicador a comisiones de tipo Rappel o a sí mismo
      a.concepto_ds NOT IN ('Rappel Llamada', 'Rappel Teorico', 'Rappel Diferencia');


  /* PASO 2: Creación de la tabla de LOG de forma focalizada
     En lugar de clonar TODA la tabla maestra de nuevo, generamos un log
     que contenga exclusivamente los registros calculados en este módulo.
     Se añade caducidad de 7 días para no saturar el almacenamiento.
  */
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0203_MARCO_RETRIBUTIVO_MULTIPLICADOR` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT *
  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
  WHERE concepto_ds = 'Rappel Llamada';

END