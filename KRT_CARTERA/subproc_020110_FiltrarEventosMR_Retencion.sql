BEGIN

  --- PASO 1: IDENTIFICO POBLACION DE EVENTOS NO ALTA A FILTRAR

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020110_EVENTOS_NO_ALTA_FILTRADOS` AS 
  select distinct *
  from `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL`
  where (contains_substr(marco_retributivo, "fideliza") or contains_substr(marco_retributivo, "atc") ) and UPPER(TRIM(tipomovimiento)) not like"ALTA %" and UPPER(TRIM(tipomovimiento)) not like"TRASLAD%";

  --- PASO 2: CREO LISTADO DE EVENTOS EXCLUYENDO LOS EVENTOS N O ALTA A FILTRAR

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0202_MARCO_RETRIBUTIVO_TIENDASxCANAL` AS 
  SELECT distinct e.* from `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL` e
  WHERE NOT EXISTS(
     select 1
     from `mm-commissions-reporting.KRT_CARTERA.LOG_020110_EVENTOS_NO_ALTA_FILTRADOS` f
     where f.marca_ds=e.marca_ds and f.IdFijo=e.IdFijo and f.IdProducto=e.IdProducto  and f.canal=e.canal and f.subcanal=e.subcanal and f.agente=e.agente and f.TipoMovimiento=e.TipoMovimiento
      and f.concepto_ds=e.Concepto_ds
   );

  --- PASO 3: CREO TABLA DE SALIDA CONTENIENDO POBLACION DE EVENTOS A COMISIONAR EXCLUYENDO EVENTOS A FILTRAR
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`
  AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0202_MARCO_RETRIBUTIVO_TIENDASxCANAL`; 

END