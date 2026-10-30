BEGIN

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` AS
  SELECT
    *
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`;
    
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS`
  SELECT
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
    NULL AS portabilidad_in_lg,
    NULL AS gb,
    NULL AS expediente_id,
    clave,
    marco_retributivo_ds,
    flag_marca_cartera,
    grupo_rappel_ds,
    orden_sap,
    importe,
    decomisionable
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.RETRASOS`
  where not (marca_ds is null and Cliente_id is null and servicio_id is null and detalle_servicio_ds is null and FECHA_RFB_ID is null);


  -- PASO 2: CREO TABLA UNITARIOS MAS RAPPEL MAS AJUSTES

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS`; 


END