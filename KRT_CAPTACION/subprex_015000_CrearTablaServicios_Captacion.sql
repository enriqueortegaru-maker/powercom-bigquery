BEGIN

  DECLARE DESDE_1M INT64;
  SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);
  
  ----------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------
  ---
  --- PASO 1: CREA TABLAS DE EVENTOS CAPTACION, VENTAS CAPTACION Y SERVICIOS CAPTACION
  ----

    --- PASO 1.1: CREA TABLA EVENTOS CAPTACION -------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.EVENTOS_CAPTACION` AS
    select distinct *
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`; 


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_EVENTOS_CAPTACION` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.EVENTOS_CAPTACION`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_VENTAS_CAPTACION` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;


    --- PASO 1.2: CREA TABLA SERVICIOS CAPTACION -------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS
    select distinct * --except(expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg,catalogo_id, grid, desc_mm, clase_mm)
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
    where fecha_rfb_id is not null
    and fecha_rfb_id>=desde and fecha_rfb_id<=hasta;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`;


    --- PASO 1.3: CREA TABLA SERVICIOS CAPTACION EXCLUIDOS -------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION_EXCLUIDOS` AS
    select distinct * --except(expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg,catalogo_id, grid, desc_mm, clase_mm)
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
    where fecha_rfb_id is null
    or fecha_rfb_id>hasta;

    
    --- PASO 1.3: CREA TABLA SERVICIOS CAPTACION 1M -------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION_1MP` AS
    select distinct * --except(expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg,catalogo_id, grid, desc_mm, clase_mm)
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
    where fecha_rfb_id is not null
    and fecha_rfb_id>=desde_1m and fecha_rfb_id<desde;


/*
    MODIFICACION 20230828 

    --- PASO 1.4: CREA TABLA VENTAS CAPTACION CON DATOS DE VENTAS NETAS EN MES DE COMISIONADO-------
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS
    select distinct *
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
    --where fecha_venta_neta_id>=desde_1m and fecha_venta_neta_id<=hasta;
    where fecha_venta_neta_id>=desde and fecha_venta_neta_id<=hasta;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_VENTAS_CAPTACION` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;
*/
  
END