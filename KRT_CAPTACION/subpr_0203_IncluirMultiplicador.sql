BEGIN

--- PASO 1: Calculo importe con multiplicador y registro en tabla de log


	insert into `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` 
	select distinct a.*
	replace ('Rappel Llamada' as concepto_ds,
	a.importe * (CAST(b.multiplicador AS FLOAT64) - 1) as importe) 
	from `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` a 
	inner join `mm-commissions-reporting.KRT_CAPTACION.MULTIPLICADOR` b
	on a.marca_ds = b.marca_ds and a.canal_alta_ds = b.canal_ds and a.subcanal_ds = b.subcanal_ds and a.nombre_distribuidor_alta_ds = b.nombre_distribuidor_ds;



--- PASO 2: Inserto registros en tabla de marco retributivo

    -- Log de fichero completo      

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0203_MARCO_RETRIBUTIVOxCANAL` AS
    SELECT 
      * 
    FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0203_MARCO_RETRIBUTIVOxCANAL_UPD` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
    EXCEPT DISTINCT
    SELECT
      * 
    FROM  
      `mm-commissions-reporting.KRT_CAPTACION..LOG_0202_MARCO_RETRIBUTIVOxCANAL`;
END