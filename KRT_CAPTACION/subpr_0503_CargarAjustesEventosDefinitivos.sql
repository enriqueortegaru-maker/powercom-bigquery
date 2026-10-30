BEGIN

--- PASO 1: Cargo eventos decomisionables de marco retributivo x canal en tabla de ajustes de eventos

    --- Tabla de salida
    --  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` AS
  SELECT DISTINCT *,'S' decomisionable
  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
  WHERE marco_retributivo_ds IS NOT NULL
  AND (flag_marca_cartera = 0 OR (flag_marca_cartera = 1 AND marca_cartera_ds = 'CAPTACION' ));



--- PASO 2: Vuelco a tabla de log

    --- Tabla de salida
    --  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0503_AJUSTES_EVENTOS_DEFINITIVOS` AS
  SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0503_EVENTOS_RECHAZADOS_MR_NULO` AS
  SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` ei
  WHERE ei.marco_retributivo_ds is null
  and NOT EXISTS (
      SELECT 1 
      from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` ef
      where ef.marca_ds=ei.marca_ds and  ef.cliente_id=ei.cliente_id and ef.servicio_id=ei.servicio_id and ef.concepto_ds=ei.concepto_ds
  );


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0503_EVENTOS_RECHAZADOS_MR_NO_NULO` AS
  SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` ei
  WHERE ei.marco_retributivo_ds is not null
  and NOT EXISTS (
      SELECT 1 
      from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` ef
      where ef.marca_ds=ei.marca_ds and  ef.cliente_id=ei.cliente_id and ef.servicio_id=ei.servicio_id and ef.concepto_ds=ei.concepto_ds
  );






END