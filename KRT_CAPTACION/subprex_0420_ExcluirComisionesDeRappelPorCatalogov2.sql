BEGIN

    /*
        SE ELIMINA EL RAPPEL DE AQUELLOS SERVICIOS QUE ESTEN ASOCIADOS A CATALOGOS DE SERVICIOS O PROMOCIONES ESPECIFICADOS EN LA TABLA DE EXCLUSION
          PASO 1: SE IDENTIFICAN SERVICIOS ASOCIADOS A CATALOGOS DE SERVICIOS O PROMOCIONES CONCRETAS 
          PASO 2: SE ELIMINAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS IDENTIFICADOS EN LA TABLA PREVIA
    */

  
    -- PASO 1: SE IDENTIFICAN SERVICIOS ASOCIADOS A CATALOGOS DE SERVICIOS O PROMOCIONES CONCRETAS 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0420_SERVICIOS_CANDIDATOS_EXCLUSION` AS 
    SELECT c.marca_ds, c.cliente_id, c.servicio_id FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    inner join  `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXCLUSION_RAPPELxCATALOGO` r
    on r.marca_ds=c.marca_ds  and TRIM(r.catalogo_id)=TRIM(c.catalogo_id);


    -- PASO 2: SE ELIMINAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS IDENTIFICADOS EN LA TABLA PREVIA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0420_COMISIONES_RAPPEL_EXCLUIDAS` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
      WHERE EXISTS (
      select 1 from   `mm-commissions-reporting.KRT_CAPTACION.LOG_0420_SERVICIOS_CANDIDATOS_EXCLUSION` r
      where r.marca_ds=c.marca_ds  and r.cliente_id=c.cliente_id and r.servicio_id=c.servicio_id 
      and (contains_substr(c.concepto_ds,'rappel teorico') or contains_substr(c.concepto_ds,'rappel diferencia')) 
    );


    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    where EXISTS (
      select 1 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0420_COMISIONES_RAPPEL_EXCLUIDAS` r
      where r.marca_ds=c.marca_ds  and r.cliente_id=c.cliente_id and r.servicio_id=c.servicio_id 
      and (contains_substr(c.concepto_ds,'rappel teorico') or contains_substr(c.concepto_ds,'rappel diferencia')) 
    );

END