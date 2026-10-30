BEGIN

  declare param_hasta_dt date;    
  set param_hasta_dt = parse_date ('%Y%m%d', cast ( HASTA as string) );

-- PASO 1: ACTUALIZO REGISTROS DE SERVICIOS_CAPTACION

UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv

  SET
    serv.concepto_ds = CONCAT(CASE WHEN serv.categoria_servicio_ds = 'MOVILES POSTPAGO' THEN CASE WHEN sfmxtr.orden = 1 THEN 'Primera linea ' ELSE 'Linea adicional ' END ELSE '' END
      , CASE WHEN serv.categoria_servicio_ds = 'MOVILES POSTPAGO' AND sfmxtr.clasificacion_ds = 'SOMO' THEN 'SOMO ' ELSE  ''  END
      , serv.concepto_ds,
      CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad'  END
    )
  FROM (
      With sfm as (
          --- Servicios de captacion, de categorias fijo y movil postpago, enriquecidos con identificativo segmentado por marca_ds y cliente_id  
          SELECT marca_ds,Cliente_id,servicio_id, categoria_servicio_ds, detalle_servicio_ds, CONCEPTO_DS,gb,portabilidad_in_lg, ROW_NUMBER() OVER (PARTITION BY cliente_id, marca_ds ORDER BY gb DESC, servicio_id) orden
          FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
          WHERE categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
      )
      --- Servicios de captacion de categorias fijo y movil postpago, enriquecidos con identificativo segmentado por marca_ds y cliente_id  
      --- Y cruzado con tramos de servicio 
      select DISTINCT sfm.*, tr.clasificacion_ds, tr.desde_dt, tr.hasta_dt  
      from sfm 
      inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` as tr
      on sfm.marca_ds=tr.marca_ds and sfm.cliente_id=tr.cliente_id
      WHERE CAST(tr.desde_dt AS date) <= param_hasta_dt
        AND CAST(tr.hasta_dt AS date) > param_hasta_dt 
      order by gb desc, servicio_id 
  ) sfmxtr
  WHERE serv.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
  AND serv.servicio_id =sfmxtr.servicio_id
  AND serv.marca_ds=sfmxtr.marca_ds
  AND serv.cliente_id=sfmxtr.cliente_id;

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