BEGIN

CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION` AS 
  
WITH
  servicioMovilPrepago AS (
  SELECT
    *
  FROM
    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
  WHERE
    categoria_servicio_ds = 'MOVILES PREPAGO')
SELECT
  DISTINCT serv.marca_ds,
  serv.Cliente_id,
  CAST(serv.servicio_id AS int64) servicio_id,
  serv.detalle_servicio_ds,
  cat.CONCEPTO_DS,
  serv.FECHA_RFB_ID,
  serv.FECHA_VENTA_NETA_ID,
  serv.fecha_rfb_dt,
  serv.fecha_venta_neta_dt,
  serv.canal_alta_ds,
  serv.subcanal_ds,
  serv.tipo_canal_alta_ds,
  serv.nombre_distribuidor_alta_ds,
  serv.agente_alta_id,
  serv.agente_creador_id,
  serv.categoria_servicio_ds,
  cl.cif_nif,
  serv.segmento_ds,
  cl.subsegmento_ds,
  CASE
    WHEN serv.marca_ds NOT IN ('R') THEN serv.marca_cartera_ds
  ELSE
  CASE
    WHEN ABS(DATE_DIFF(CAST(serv.fecha_rfb_dt AS DATE), CAST(rfb.fecha_alta_dt AS DATE), DAY))> 15 THEN 'CARTERA'
  ELSE
  'CAPTACION'
END
END
  marca_cartera_ds,
  rfb.fecha_alta_dt Antiguedad_Cliente,
  serv.equipo_ds,
  serv.territorio_ds,
  serv.tecnologia_detalle_ds,
  serv.portabilidad_in_lg,
  CASE
    WHEN serv.categoria_servicio_ds = 'BANDA ANCHA' THEN serv.velocidad_mb
  ELSE
  serv.gb
END
  gb,
  serv.expediente_id
FROM
  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` serv
INNER JOIN
  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` cat
ON
  serv.DETALLE_SERVICIO_DS = cat.DETALLE_SERVICIO_DS
  AND cat.MARCA_DS = serv.MARCA_DS
  AND cat.CATEGORIA_SERVICIO_DS = serv.CATEGORIA_SERVICIO_DS
  AND cat.tipo_identificacion_ds = 'DETALLE_SERVICIO'
  AND adicional_lg = 0
INNER JOIN
  `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cl 
-- PDTE PROBAR
--LEFT JOIN
--  `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cl
ON
  serv.marca_ds = cl.marca_ds
  AND serv.cliente_id = cl.cliente_id
LEFT JOIN
  `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` rfb
ON
  rfb.cliente_id = serv.cliente_id
  AND rfb.marca_ds = serv.marca_ds
  AND rfb.desde_id <= serv.fecha_rfb_id
  AND rfb.hasta_id > serv.fecha_rfb_id
LEFT JOIN
  servicioMovilPrepago AS smovprep
ON
  serv.servicio_id_origen = smovprep.servicio_id
WHERE
  serv.fecha_rfb_id BETWEEN DESDE
  AND HASTA
  AND (UPPER(serv.agente_creador_id) NOT IN ('MIGRAMASHFC_FTTH',
      'EKT_MIGRA_202206',
      'REPO_JUNIO_2022'))
  AND serv.marca_ds <> 'R'
  AND (serv.servicio_id_origen < 0
    OR (serv.agente_creador_id = 'MIGRACIONTMK'
      AND EXISTS (
      SELECT
        *
      FROM
        `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` smovprep
      WHERE
        smovprep.marca_ds = 'TELECABLE'
        AND smovprep.sistema_ds = 'SGI'
        AND smovprep.servicio_id = serv.servicio_id_origen
        AND smovprep.fecha_rfb_id BETWEEN DESDE
        AND HASTA ) )
    OR EXISTS (
    SELECT
      1
    FROM
      `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` smovprep
    WHERE
      smovprep.cliente_id = serv.cliente_id
      AND smovprep.marca_ds = serv.marca_ds
      AND smovprep.servicio_id = serv.servicio_id_original
      AND smovprep.fecha_rfb_id BETWEEN DESDE
      AND HASTA )
    OR (serv.categoria_servicio_ds = 'MOVILES POSTPAGO'
      AND smovprep.categoria_servicio_ds = 'MOVILES PREPAGO') )
  AND ((serv.segmento_ds IN ('RESIDENCIAL',
        'SOHO',
        'PYME')
      AND serv.marca_ds NOT IN ('TELECABLE','R'))
    OR (serv.segmento_ds IN ('RESIDENCIAL','SOHO')
      AND serv.marca_ds IN ('TELECABLE','R')) )
  AND serv.fecha_cancelacion_id > HASTA
  AND (serv.fecha_baja_id > HASTA
       OR serv.SERVICIO_ID_DESTINO > 0
  )
  AND ABS(DATE_DIFF(CAST(serv.fecha_rfs_dt AS DATE), CAST(serv.fecha_rfb_dt AS DATE), MONTH))<=2; 
  
  
  --- PASO 2: Vuelco registros en tabla de log `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION`
CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS
SELECT
  *
FROM
  `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION`
WHERE
  cif_nif IS NOT NULL; 
  
END