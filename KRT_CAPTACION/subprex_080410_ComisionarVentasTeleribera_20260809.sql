BEGIN


    DECLARE VIMPORTE, VGRID INT64;    
    --DECLARE VDESDE INT64; SET VDESDE=20260701;
    SET VIMPORTE=125;   
    SET VGRID=71;

    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER INCENTIVADAS

        -- PASO 3: ACTUALIZAR IMPORTE DE INCENTIVOS
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    SET c.grid=VGRID,   
    c.nombre_distribuidor_alta_ds='TELERIBERA',
    c.categoria_servicio_ds="BANDA ANCHA",
    c.concepto_ds='Lead BA Teleribera',
    c.clase_mm='D - Extracomision',
    c.desc_mm='D - Extra',
    c.decomisionable='S',
    c.importe=VIMPORTE
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
    where c.marca_ds=v.marca_ds  
    and v.cliente_id=c.cliente_id
    and v.categoria_servicio_ds=c.categoria_servicio_ds
    and v.marca_ds="EUSKALTEL"
    and not contains_substr(v.detalle_servicio_ds,"TELERIBERA")
    and CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(EXTRACT(DATE FROM v.fecha_rfb_dt),MONTH)) AS INT64)=vdesde
    and c.marca_ds="EUSKALTEL"
    and c.grid=5
    and v.grid<5
    and contains_substr(c.detalle_servicio_ds,"TELERIBERA");


    
    -- PASO 5: GENERO LOG
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_FIN` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;


END