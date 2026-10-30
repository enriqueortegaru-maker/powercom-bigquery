BEGIN

  --LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20240601;SET HASTA=20240630;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`;



  ---- PROCEDIMIENTO PARA INSERTAR REGISTROS SOLO SI  EL NUMERO DE ELEMENTOS A INSERTAR ES SUPERIOR A 1
  IF EXISTS (SELECT marca_ds FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RETRASOS`) THEN

    --DECLARE DESDE, HASTA INT64; SET DESDE=20230401;SET HASTA=20230430;
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` as 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` where 1=0;
   
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` 
    SELECT
      TRIM(marca_ds),
      Cliente_id,
      servicio_id,
      TRIM(detalle_servicio_ds),
      CONCEPTO_DS,
      --FECHA_RFB_ID,
      `mm-commissions-reporting.KRT_CAPTACION.f_correctivoFechaId_calculaFechaIdInconsistenteConTimestamp`(FECHA_RFB_DT, FECHA_RFB_ID),
      --FECHA_VENTA_NETA_ID,
      `mm-commissions-reporting.KRT_CAPTACION.f_correctivoFechaId_calculaFechaIdInconsistenteConTimestamp`(FECHA_VENTA_NETA_DT, FECHA_VENTA_NETA_ID),
      --fecha_rfb_dt,
      `mm-commissions-reporting.KRT_CAPTACION.f_correctivoFechaDt_calculaTimestampInconsistenteConFechaId`(FECHA_RFB_DT, FECHA_RFB_ID),
      --fecha_venta_neta_dt,
      `mm-commissions-reporting.KRT_CAPTACION.f_correctivoFechaDt_calculaTimestampInconsistenteConFechaId`(FECHA_VENTA_NETA_DT, FECHA_VENTA_NETA_ID),
      TRIM(canal_alta_ds),
      TRIM(subcanal_ds),
      TRIM(tipo_canal_alta_ds),
      TRIM(nombre_distribuidor_alta_ds),
      agente_alta_id,
      agente_creador_id,
      TRIM(categoria_servicio_ds),
      cif_nif,
      segmento_ds,
      subsegmento_ds,
      marca_cartera_ds,
      Antiguedad_Cliente,
      equipo_ds,
      territorio_ds,
      TRIM(tecnologia_detalle_ds),
      NULL AS portabilidad_in_lg,
      NULL AS gb,
      NULL AS expediente_id,
      CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), 
      52,
      NULL,
      NULL, 
      CAST(NULL AS STRING), NULL, NULL, CAST(NULL AS STRING), CAST(NULL AS STRING), NULL, NULL, CAST(NULL AS STRING), CAST(NULL AS STRING),
      clave,
      TRIM(marco_retributivo_ds),
      flag_marca_cartera,
      grupo_rappel_ds,
      orden_sap,
      importe,
      UPPER(decomisionable)
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RETRASOS`
    where not (marca_ds is null and Cliente_id is null and servicio_id is null and detalle_servicio_ds is null and FECHA_RFB_ID is null);

    


    -- PARCHE PARA ENRIQUECER LOS AJUSTES CON DATOS IMPORTADOS DE LOS SERVICIOS DE CAPTACION
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` r
    SET r.portabilidad_in_lg=s.portabilidad_in_lg,
        r.gb=s.gb,
        r.expediente_id=s.expediente_id,
        r.expediente_padre_id=s.expediente_padre_id,
        r.contrato_id=s.contrato_id,
        r.tipo_pedido_ds=s.tipo_pedido_ds,
        r.pedido_id=s.pedido_id,
        r.tipo_producto_pedido_re_ds=s.tipo_producto_pedido_re_ds,
        r.visibilidad_pedido_lg=s.visibilidad_pedido_lg,
        r.catalogo_id=s.catalogo_id,
        r.pedido=s.pedido,
        r.nplays=s.nplays,
        r.nplays_rfb=s.nplays_rfb,
        r.cat_plays=s.cat_plays,
        r.cat_plays_rfb=s.cat_plays_rfb,
        r.nplays_p=s.nplays_p,
        r.nplays_rfb_p=s.nplays_rfb_p,
        r.cat_plays_p=s.cat_plays_p,
        r.cat_plays_rfb_p=s.cat_plays_rfb_p
    from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`s 
    --from (SELECT distinct * from `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION`s where version=6 and hasta=20230228 and fecha_calc_dt="2023-03-07") s
    where r.marca_ds=s.marca_ds
    and r.cliente_id=s.cliente_id
    and r.servicio_id=s.servicio_id
    and r.concepto_ds=s.concepto_ds
    and r.canal_alta_ds=s.canal_alta_ds
    and r.subcanal_ds=s.subcanal_ds
    and r.nombre_distribuidor_alta_ds=s.nombre_distribuidor_alta_ds   
    and r.agente_alta_id=s.agente_alta_id
--  and r.fecha_venta_neta_dt=s.fecha_venta_neta_dt
--  and r.fecha_rfb_dt=s.fecha_rfb_dt
    and r.clase_mm='Z - Ajustes' 
    and r.desc_mm='Z - Ajustes';

    -- FIN PARCHE
    --LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20240601;SET HASTA=20240630;
    --- ACTUALIZO LOS CAMPOS DE TIPIFICACION
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` 
    SET desc_mm=`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_comisionesv1`(categoria_servicio_ds, concepto_ds, 0, 52) where 1=1;

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` 
    SET clase_mm=`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(desc_mm) WHERE 1=1;
    

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` 
    SET clase_mm=case when not(fecha_rfb_id>=desde and fecha_rfb_id<=hasta) then 'Y - Retrasos'else clase_mm  END WHERE 1=1;
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS` 
    SET desc_mm=case when not(fecha_rfb_id>=desde and fecha_rfb_id<=hasta) then replace(desc_mm, LEFT(desc_mm,4),'Y - ') ELSE desc_mm END  WHERE 1=1;




    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_COMISIONADOS` as 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_LEIDOS`;

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_COMISIONADOS`
    SET fecha_rfb_dt=PARSE_TIMESTAMP('%Y%m%d', CAST(fecha_rfb_id as string))
    where CAST(FORMAT_TIMESTAMP("%Y%m%d",fecha_rfb_dt ) AS INT64) <>fecha_rfb_id;

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_COMISIONADOS`
    SET fecha_venta_neta_dt=PARSE_TIMESTAMP('%Y%m%d', CAST(fecha_venta_neta_id as string))
    where CAST(FORMAT_TIMESTAMP("%Y%m%d",fecha_venta_neta_dt ) AS INT64) <>fecha_venta_neta_id;



    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS`
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0601_RETRASOS_COMISIONADOS`;



  END IF; 

  -- PASO 2: CREO TABLA UNITARIOS MAS RAPPEL MAS AJUSTES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS`; 

END