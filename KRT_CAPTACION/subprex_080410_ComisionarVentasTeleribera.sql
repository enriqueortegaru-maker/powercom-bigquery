BEGIN


    DECLARE VIMPORTE, VGRID INT64; 
    DECLARE VDESDE_1M_DT, VHASTA_DT DATE;   
    --DECLARE VDESDE INT64; SET VDESDE=20260701;
    SET VDESDE_1M_DT=DATE_SUB(DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(VDESDE AS STRING)), MONTH), INTERVAL 1 MONTH);
    SET VHASTA_DT=LAST_DAY(PARSE_DATE("%Y%m%d",CAST(VDESDE AS STRING)), MONTH);
    SET VIMPORTE=125;   
    SET VGRID=71;


    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER INCENTIVADAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_INI` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    --DECLARE VDESDE INT64;DECLARE VDESDE_1M_DT DATE; SET VDESDE=20260701; SET VDESDE_1M_DT='2026-07-01';
    with marcador as (
    --- Marcadores Teleribera 
        --DECLARE VDESDE INT64;DECLARE VDESDE_1M_DT, VHASTA_DT DATE; SET VDESDE=20260701; SET VDESDE_1M_DT=DATE_SUB(DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(VDESDE AS STRING)), MONTH), INTERVAL 1 MONTH); SET VHASTA_DT=LAST_DAY(PARSE_DATE("%Y%m%d",CAST(VDESDE AS STRING)), MONTH);
        --SELECT VDESDE, VDESDE_1M_DT, VHASTA_DT;
        select marca_ds, cliente_id, servicio_id,detalle_servicio_ds, fecha_venta_neta_dt,FECHA_VENTA_NETA_ID,fecha_rfb_dt, fecha_rfb_id
        FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
        where DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(fecha_rfb_id AS STRING)), MONTH) BETWEEN VDESDE_1M_DT AND VHASTA_DT
        and contains_substr(detalle_servicio_ds,"Teleribera")
        and (fecha_rfb_dt is not null or fecha_rfb_id is not null)
    )
    select distinct c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    INNER JOIN marcador m 
    on c.marca_ds=m.marca_ds and m.cliente_id=c.cliente_id
    where c.categoria_servicio_ds="BANDA ANCHA"
    and contains_substr(desc_mm,"A - ");



    -- PASO 1: IDENTIFICAR POBLACION DE COMISIONES DE RAPPEL QUE DEBEN SER INCENTIVADAS

        -- PASO 3: ACTUALIZAR IMPORTE DE INCENTIVOS
    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_INI`
    SET grid=VGRID, 
    nombre_distribuidor_alta_ds='RAUL CHUECA LITAGO',
    clase_mm='D - Extracomision',
    desc_mm='D - Extra',
    decomisionable='S',
    importe=VIMPORTE
    WHERE TRUE;

    
    -- PASO 5: GENERO LOG
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    (
        marca_ds,
        Cliente_id,
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
        portabilidad_in_lg,
        gb,
        expediente_id,
        expediente_padre_id,
        contrato_id,
        tipo_pedido_ds,
        pedido_id,
        tipo_producto_pedido_re_ds,
        visibilidad_pedido_lg,
        catalogo_id,
        grid,
        desc_mm,
        clase_mm,
        pedido,
        nplays,
        nplays_rfb,
        cat_plays,
        cat_plays_rfb,
        nplays_p,
        nplays_rfb_p,
        cat_plays_p,
        cat_plays_rfb_p,
        clave,
        marco_retributivo_ds,
        flag_marca_cartera,
        grupo_rappel_ds,
        orden_sap,
        importe,
        decomisionable,
        mes_comision_id
    ) select 
        marca_ds,
        Cliente_id,
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
        portabilidad_in_lg,
        gb,
        expediente_id,
        expediente_padre_id,
        contrato_id,
        tipo_pedido_ds,
        pedido_id,
        tipo_producto_pedido_re_ds,
        visibilidad_pedido_lg,
        catalogo_id,
        grid,
        desc_mm,
        clase_mm,
        pedido,
        nplays,
        nplays_rfb,
        cat_plays,
        cat_plays_rfb,
        nplays_p,
        nplays_rfb_p,
        cat_plays_p,
        cat_plays_rfb_p,
        clave,
        marco_retributivo_ds,
        flag_marca_cartera,
        grupo_rappel_ds,
        orden_sap,
        importe,
        decomisionable,
        mes_comision_id   
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_INI`;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_080410_COMISIONES_FIN` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
    select distinct c.*
    FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c;
 



END