BEGIN
    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_INI` AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;


    -- PASO 0: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER PENALIZABLES
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_PENALIZABLES` AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p on c.marca_ds=p.marca_ds
    AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
    --AND c.nplays=p.plays
    AND c.nplays_p=p.plays 
    AND TRIM(UPPER(c.cat_plays_p))!=TRIM(UPPER(Coalesce(p.exclusion,'NA')))  -- AÑADIDO EXCLUSIONES DE VIRGIN       
    AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL');


    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER PENALIZADAS (TODAS LAS PENALIZABLES MENOS LAS QUE TIENEN GRID -3).
  
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_PENALIZADAS` AS 
    SELECT * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_PENALIZABLES` 
    WHERE grid!=-3;
      
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_PENALIZACIONES` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_PENALIZADAS`;


    -- PASO 2: IDENTIFICAR POR SERVICIO LA POBLACION DE COMISIONES DE RAPPEL Y LAS PENALIZACIONES QUE ARRASTRA 

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_PENALIZACIONES` c
    SET c.importe=p.importe,
    c.clase_mm="P - Penalizacion",
    c.desc_mm="P - Penalización por ponderación de rappel"
    FROM (
        /*
        with p as (
            SELECT c.*, p.ponderacion
            from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
            inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p on c.marca_ds=p.marca_ds
            AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
            --AND c.nplays=p.plays
            AND c.nplays_p=p.plays 
            AND (( TRIM(UPPER(c.cat_plays_p))!=TRIM(UPPER(Coalesce(p.exclusion,'NA')))  -- AÑADIDO EXCLUSIONES DE VIRGIN       
            AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL'))
            OR (starts_with(TRIM(clase_mm),"P -")   AND contains_substr(TRIM(UPPER(c.concepto_ds)),'RAPPEL')))
        ) select marca_ds,categoria_servicio_ds, detalle_servicio_ds,cliente_id,servicio_id,ponderacion, SAFE_MULTIPLY(1-ponderacion,SAFE_NEGATE(sum(importe))) as importe
        from p
        group by 1,2,3,4,5,6
        order by 1,2,3
        */

        with p as (
            SELECT c.*, p.ponderacion
            from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
            inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p on c.marca_ds=p.marca_ds
            AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
            --AND c.nplays=p.plays
            AND c.nplays_p=p.plays 
            AND (( TRIM(UPPER(c.cat_plays_p))!=TRIM(UPPER(Coalesce(p.exclusion,'NA')))  -- AÑADIDO EXCLUSIONES DE VIRGIN       
            AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL'))
            OR (starts_with(TRIM(clase_mm),"P -")   AND contains_substr(TRIM(UPPER(c.concepto_ds)),'RAPPEL')))
            --AND servicio_id=147636160
        ) select marca_ds,categoria_servicio_ds, detalle_servicio_ds,cliente_id,servicio_id,concepto_ds,ponderacion, SAFE_MULTIPLY(1-ponderacion,SAFE_NEGATE(sum(importe))) as importe
        from p
        group by 1,2,3,4,5,6,7
        order by 1,2,3

    ) p
    where c.marca_Ds=p.marca_ds 
    and c.cliente_id=p.cliente_id 
    and c.categoria_servicio_ds=p.categoria_servicio_ds 
    and c.detalle_Servicio_ds=p.detalle_Servicio_ds 
    and c.concepto_ds=p.concepto_ds
    and c.servicio_id=p.servicio_id;




    -- PASO 4: INSERTO PENALIZACIONES EN COMISIONADO
    
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_PENALIZACIONES`;

    -- PASO 4: INSERTO PENALIZACIONES EN COMISIONADO

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0803_COMISIONES_FIN` AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;


END