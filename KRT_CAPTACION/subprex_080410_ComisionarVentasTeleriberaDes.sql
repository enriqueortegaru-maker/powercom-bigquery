BEGIN


    DECLARE VIMPORTE, VGRID INT64;    
    SET VIMPORTE=50;   
    SET VGRID=71;

    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER INCENTIVADAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_INCENTIVABLES_TELERIBERA` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT
    servicio_id,
    detalle_servicio_ds,
    "Lead BA Teleribera" CONCEPTO_DS,
    FECHA_RFB_ID,
    FECHA_VENTA_NETA_ID,
    fecha_rfb_dt,
    fecha_venta_neta_dt,
    canal_alta_ds,
    subcanal_ds,
    tipo_canal_alta_ds,
    "TELERIBERA" as nombre_distribuidor_alta_ds,
    agente_alta_id,
    agente_creador_id,
    "BANDA ANCHA" as categoria_servicio_ds,
    cif_nif,
    segmento_ds,
    subsegmento_ds,
    marca_cartera_ds,
    Antiguedad_Cliente,
    equipo_ds,
    territorio_ds,
    tecnologia_detalle_ds,
    contrato_id,
    catalogo_id,
    VGRID as grid,
    'D - Extra' desc_mm,
    'D - Extracomision' as clase_mm,
    'S' AS decomisionable,    
    VIMPORTE AS importe
    FROM  `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
    where contains_substr(detalle_servicio_ds,"TELERIBERA");


    -- PASO 4: INSERTO PENALIZACIONES EN COMISIONADO
    INSERT  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    (
        servicio_id,
        detalle_servicio_ds,
        CONCEPTO_DS,
        FECHA_RFB_ID,
        FECHA_VENTA_NETA_ID,
        fecha_rfb_dt,
        fecha_venta_neta_dt,
        canal_alta_ds,
        subcanal_ds,
        tipo_canal_alta_ds,
        nombre_distribuidor_alta_ds,
        agente_alta_id,
        agente_creador_id,
        categoria_servicio_ds,
        cif_nif,
        segmento_ds,
        subsegmento_ds,
        marca_cartera_ds,
        Antiguedad_Cliente,
        equipo_ds,
        territorio_ds,
        tecnologia_detalle_ds,
        contrato_id,
        catalogo_id,
        grid,
        desc_mm,
        clase_mm,
        decomisionable,
        importe
    ) select *
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_INCENTIVABLES_TELERIBERA`;


    -- PASO 5: GENERO LOG
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_FIN` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    SELECT c.* --,p.ponderacion, --c.importe*p.ponderacion as importe_ponderado  
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;


END