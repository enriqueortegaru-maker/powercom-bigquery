BEGIN

    /*
        SE PONDERA EL RAPPEL DE AQUELLOS SERVICIOS QUE ESTEN ASOCIADOS A CATALOGOS DE SERVICIOS O PROMOCIONES ESPECIFICADOS EN LA TABLA DE EXCLUSION
          PASO 1: SE IDENTIFICAN SERVICIOS ASOCIADOS A CATALOGOS DE SERVICIOS QUE SE PONDERAN,  Y SE VINCULA CON PONDERACION A APLICAR
          PASO 2: SE IDENTIFICAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS IDENTIFICADOS EN LA TABLA PREVIA
          PASO 3: SE ACTUALIZAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS IDENTIFICADOS EN LA TABLA PREVIA
    */

  
    -- PASO 1: SE IDENTIFICAN LOS SERVICIOS ASOCIADOS A CATALOGOS DE SERVICIOS CONCRETAS Y SE VINCULAN CON PONDERACION A APLICAR
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0425_SERVICIOS_CANDIDATOS_PONDERACION` AS 
    SELECT distinct c.marca_ds, c.cliente_id, c.servicio_id, r.ponderacion 
    FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    inner join  `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_PONDERA_RAPPELxCANALxCATALOGO` r
    on r.marca_ds=c.marca_ds and CASE WHEN UPPER(TRIM(r.canal))='X' THEN TRUE ELSE UPPER(TRIM(r.canal))=c.canal_alta_ds END
    and CASE WHEN UPPER(TRIM(r.subcanal))='X' THEN TRUE ELSE UPPER(TRIM(r.subcanal))=c.subcanal_ds END
    and UPPER(TRIM(r.catalogo_id))=UPPER(TRIM(c.catalogo_id))
    order by 1,2,3,4;



    -- PASO 2: SE IDENTIFICAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS QUE SE DEBEN PONDERAR
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0425_COMISIONES_RAPPEL_PONDERADAS` AS 
    SELECT distinct c.* , r.ponderacion
    FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.LOG_0425_SERVICIOS_CANDIDATOS_PONDERACION` r
    on r.marca_ds=c.marca_ds  and r.cliente_id=c.cliente_id and r.servicio_id=c.servicio_id  
    and (contains_substr(c.concepto_ds,'rappel teorico') or contains_substr(c.concepto_ds,'rappel diferencia')); 
    

    
    -- PASO 3: SE ACTUALIZAN LAS COMISIONES DE RAPPEL DE LOS SERVICIOS IDENTIFICADOS EN LA TABLA PREVIA
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` c
    SET c.importe=c.importe*p.ponderacion   
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0425_COMISIONES_RAPPEL_PONDERADAS` p
    WHERE p.marca_ds=c.marca_ds  and p.cliente_id=c.cliente_id and p.servicio_id=c.servicio_id and p.concepto_ds=c.concepto_ds;


END