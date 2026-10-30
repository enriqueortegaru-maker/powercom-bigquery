BEGIN

  DECLARE
    DESDE_DT,
    HASTA_DT date;
  SET
    DESDE_DT = parse_date ('%Y%m%d',
      CAST ( DESDE AS string) );
  SET
    HASTA_DT = parse_date ('%Y%m%d',
      CAST ( HASTA AS string) );
    

  --- PASO 1: Creo tabla con registros a ingresar

--  CREATE OR REPLACE TABLE
--    `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_SERVICIOS_CAPTACION` AS

--  Select * 
--    From `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`  
--  Where 1 = 2;

  --- PASO 1: Inserto registros en tabla de registros a ingresar
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`

  SELECT
    DISTINCT catalogo.marca_ds,
    CAST(p.swCustomerId AS INT64) cliente_id,
    tmp.servicio_id,
    cat.swReleaseName NombreProducto,
    'Descuento plataforma cancelación' concepto_ds,
    (EXTRACT(YEAR
      FROM
        p.swDateInstalled)*10000 + EXTRACT(MONTH
      FROM
        p.swDateInstalled) * 100 + EXTRACT(DAY
      FROM
        p.swDateInstalled)) FECHA_RFB_ID,
    (EXTRACT(YEAR
      FROM
        p.swDateCreated)*10000 + EXTRACT(MONTH
      FROM
        p.swDateCreated) * 100 + EXTRACT(DAY
      FROM
        p.swDateCreated)) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT,
    p.swDateCreated FECHA_VENTA_NETA_DT,
    tmp.canal_alta_ds,
    tmp.subcanal_ds,
    tmp.tipo_canal_alta_ds,
    tmp.nombre_distribuidor_alta_ds,
    tmp.agente_alta_id,
    tmp.agente_creador_id,
    tmp.categoria_servicio_ds,
    c.swNIE cif_nif,
    tmp.segmento_ds,
    tmp.subsegmento_ds,
    p.swMarcaCartera,
    tmp.Antiguedad_cliente,
    tmp.equipo_ds,
    tmp.territorio_ds,
    tmp.tecnologia_detalle_ds,
    0,
    0,
    CAST(NULL AS STRING),
    CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), NULL, CAST(NULL AS STRING), CAST(NULL AS STRING)    
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_DESCUENTOS` catalogo
  ON
    p.swProdReleaseId = CAST(CAST(catalogo.catalogo_id AS FLOAT64) AS INT64)
    AND MARCA_DS IN ('VIRGIN',
      'EUSKALTEL' )
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
  ON
    tmp.cliente_id = p.swCustomerId
    AND tmp.categoria_servicio_ds = 'BANDA ANCHA'
    AND tmp.tipo_canal_alta_ds = 'NO PRESENCIAL'
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_USUARIOS` u
  ON
    p.swCreatedBy = u.usuario_ds
    AND u.marca_ds IN ('VIRGIN',
      'EUSKALTEL' )
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
  ON
    p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c
  ON
    p.swCustomerId = c.swCustomerId
  WHERE
    (  (DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT) 
     or (DATE_TRUNC(CAST (p.swDateCreated AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT)
    )    
    ---DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT
    AND p.swStatus <> 'Inactivo'
    AND p.swProdOrigId IS NULL
    --##### PARCHE DE VERSION 1
    --  Eliminado
    --AND p.swFechaDesinstalacion IS NULL 
    --
    --  Incluido
    AND (p.swFechaDesinstalacion IS NULL
      OR DATE_TRUNC(CAST(p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT);


  -- PASO 2: INSERTO REGISTROS DE LOG

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0162_SERVICIOS_CAPTACION` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`; 

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0162_SERVICIOS_CAPTACION_INCR` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM  
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0161_SERVICIOS_CAPTACION`;

END