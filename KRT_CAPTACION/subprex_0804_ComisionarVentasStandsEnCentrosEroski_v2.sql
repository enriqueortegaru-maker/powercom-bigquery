BEGIN

    ---- MODIFICACION VERSION
    ----    COMISIONADO 202505: SE ELIMINA AGENTE DE ALTA ERA055 y SE INTRODUCE NNS179
    ----    COMISIONADO 202506: SE ELIMINA AGENTE DE ALTA XEN480 y SE INTRODUCEN KLK007 y BIO602
    ----    COMISIONADO 202507: SE ELIMINAN AGENTES DE ALTA NNS183, XEN480, NNS179, BIO602 y SE INTRODUCE KLK012



    DECLARE VIMPORTE, VGRID INT64;    
    SET VIMPORTE=75;   
    SET VGRID=70;

    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER INCENTIVADAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0804_COMISIONES_INCENTIVABLES_STANDS_EROSKI` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_EROSKI_AGENTES_VENTAS_STANDS` p
    on p.marca_ds=c.marca_ds 
    and p.canal_alta_ds=c.canal_alta_ds 
    and case when TRIM(UPPER(p.subcanal_ds))="X" THEN TRUE ELSE p.subcanal_ds=c.subcanal_ds END 
    and p.desc_mm=c.desc_mm 
    and UPPER(TRIM(p.agente_alta_id))=UPPER(TRIM(c.agente_alta_id)) 
    and  c.fecha_rfb_id between p.fecha_ini_id  and p.fecha_fin_id;  



    /*
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    -- Desde 1 de Febrero
    --where TRIM(UPPER(c.agente_alta_id)) in ('KLK010','NNS183','XEN480','XEN488','NAV350','ERA055','KLK007')    
    -- Desde 1 de Mayo 
    --where TRIM(UPPER(c.agente_alta_id)) in ('KLK010','NNS183','XEN480','XEN488','NAV350',         'KLK007','NNS179')
    -- Desde 1 de Junio
    where TRIM(UPPER(c.agente_alta_id)) in ('KLK010','NNS183',           'XEN488','NAV350','KLK007', 'NNS179','KLK009','BIO602')        
    AND TRIM(UPPER(c.categoria_servicio_ds))='BANDA ANCHA'
    AND TRIM(UPPER(c.subcanal_ds))='STANDS'    
    AND contains_substr(c.desc_mm,'servicio acceso BA');
    */


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