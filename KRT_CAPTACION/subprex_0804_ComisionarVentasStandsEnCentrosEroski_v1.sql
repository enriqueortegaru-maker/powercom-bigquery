BEGIN

    ---- MODIFICACION VERSION
    ----    COMISIONADO 202505: SE ELIMINA AGENTE DE ALTA ERA055 y SE INTRODUCE NNS179

    DECLARE VIMPORTE, VGRID INT64;    
    SET VIMPORTE=75;   
    SET VGRID=70;

    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER INCENTIVADAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_INCENTIVABLES_STANDS_EROSKI` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    --where TRIM(UPPER(c.agente_alta_id)) in ('KLK010','NNS183','XEN480','XEN488','NAV350','ERA055','KLK007')    
    where TRIM(UPPER(c.agente_alta_id)) in ('KLK010','NNS183','XEN480','XEN488','NAV350','NNS179','KLK007')        
    AND TRIM(UPPER(c.categoria_servicio_ds))='BANDA ANCHA'
    AND TRIM(UPPER(c.subcanal_ds))='STANDS'    
    AND contains_substr(c.desc_mm,'servicio acceso BA');


    -- PASO 2: CREAR TABLA CON POBLACION DE COMISIONES DE INCENTIVOS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_INCENTIVADOS_STANDS_EROSKI` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_INCENTIVABLES_STANDS_EROSKI` c;


    -- PASO 3: ACTUALIZAR IMPORTE DE INCENTIVOS
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_INCENTIVADOS_STANDS_EROSKI`
    SET grid=VGRID,
    nombre_distribuidor_alta_ds='EROSKI CENTRAL',
    clase_mm='D - Extracomision',
    desc_mm='D - Extra',
    decomisionable='S',    
    importe=VIMPORTE
    WHERE TRUE;


    -- PASO 4: INSERTO PENALIZACIONES EN COMISIONADO
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_INCENTIVADOS_STANDS_EROSKI`;


    -- PASO 5: GENERO LOG
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_FIN` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;


END