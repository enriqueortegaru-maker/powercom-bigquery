BEGIN

  declare param_hasta_dt date;    
  set param_hasta_dt = parse_date ('%Y%m%d', cast ( HASTA as string) );

  -- PASO 1: ACTUALIZO REGISTROS DE SERVICIOS_CAPTACION
  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` a

  SET
    a.concepto_ds = CONCAT( CASE
        WHEN a.categoria_servicio_ds = 'MOVILES POSTPAGO' THEN CASE
        WHEN orden = 1 THEN 'Primera linea '
      ELSE
      'Linea adicional '
    END
      ELSE
      ''
    END
      ,
      CASE
        WHEN a.categoria_servicio_ds = 'MOVILES POSTPAGO' AND c.clasificacion_ds = 'SOMO' THEN 'SOMO '
      ELSE
      ''
    END
      , a.concepto_ds,CASE
        WHEN a.portabilidad_in_lg = 1 THEN ' con portabilidad'
      ELSE
      ' sin portabilidad'
    END
      )
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY cliente_id, marca_ds ORDER BY gb DESC, servicio_id) orden
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
    WHERE
      categoria_servicio_ds IN ('FIJA',
        'MOVILES POSTPAGO')) b,
    `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` c
  WHERE
    a.categoria_servicio_ds IN ('FIJA',
      'MOVILES POSTPAGO')
    AND a.servicio_id = b.servicio_id
    AND a.marca_ds = b.marca_ds
    AND a.cliente_id = c.cliente_id
    AND a.marca_ds = c.marca_ds
    AND CAST(c.desde_dt AS date) <= param_hasta_dt
    AND CAST(c.hasta_dt AS date) > param_hasta_dt;  



-- PASO 2: INSERTO REGISTROS EN FICHERO DE LOG

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0107_SERVICIOS_CAPTACION` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`; 

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0107_SERVICIOS_CAPTACION_UPD` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM  
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0106_SERVICIOS_CAPTACION`;



END