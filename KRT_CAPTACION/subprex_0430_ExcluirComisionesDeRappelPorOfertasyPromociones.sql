BEGIN

    /*
        SE ELIMINA EL RAPPEL DE AQUELLOS SERVICIOS QUE ESTEN ASOCIADOS A OFERTAS Y PROMOCIONES
          PASO 1: SE IDENTIFICAN SERVICIOS ASOCIADOS A CATALOGOS DE SERVICIOS O PROMOCIONES CONCRETAS 
          PASO 2: SE ELIMINAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS IDENTIFICADOS EN LA TABLA PREVIA
    */

  
    -- PASO 1: SE IDENTIFICAN LAS COMISIONES DE RAPPEL DE OFERTA Y PROMOCIONES
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0430_COMISIONES_RAPPEL_EXCLUIDAS` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    WHERE grid in (8,9)
    and (contains_substr(concepto_ds,'rappel teorico') or contains_substr(concepto_ds,'rappel diferencia'));


    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    where EXISTS (
      select 1 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0430_COMISIONES_RAPPEL_EXCLUIDAS` r
      where r.marca_ds=c.marca_ds  and r.cliente_id=c.cliente_id and r.servicio_id=c.servicio_id 
      and (contains_substr(c.concepto_ds,'rappel teorico') or contains_substr(c.concepto_ds,'rappel diferencia')) 
    );

END