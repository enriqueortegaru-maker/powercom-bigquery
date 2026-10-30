BEGIN

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0420_COMISIONES_RAPPEL_EXCLUIDAS` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
      WHERE EXISTS (
      select 1 from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXCLUSION_RAPPELxCATALOGO` r
      where contains_substr(c.concepto_ds,'rappel') and  not contains_substr(c.concepto_ds,'llamada') and r.marca_ds=c.marca_ds  and r.catalogo_id=c.catalogo_id
      --and r.cliente_id=c.cliente_id and r.servicio_id=c.servicio_id and r.concepto_ds=c.concepto_ds
    );


    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    where EXISTS (
      select 1 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0420_COMISIONES_RAPPEL_EXCLUIDAS` r
      where contains_substr(c.concepto_ds,'rappel') and  not contains_substr(c.concepto_ds,'llamada') and r.marca_ds=c.marca_ds  and r.catalogo_id=c.catalogo_id

    );

END