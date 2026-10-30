BEGIN
  --- TABLA SALIDA
  --  `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 


  --- TABLAS ENTRADA
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
  --  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS`
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info`
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb`


--- Paso 1: Inserto en tabla SERVICIOS CAPTACION

  INSERT INTO 
    `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 

  SELECT
    DISTINCT S.marca_ds,
    s.Cliente_id,
    CAST(S.servicio_id AS int64) servicio_id,
    S.detalle_servicio_ds,
    C.CONCEPTO_DS,
    S.FECHA_RFB_ID,
    S.FECHA_VENTA_NETA_ID,
    s.fecha_rfb_dt,
    s.fecha_venta_neta_dt,
    S.canal_alta_ds,
    S.subcanal_ds,
    S.tipo_canal_alta_ds,
    S.nombre_distribuidor_alta_ds,
    s.agente_alta_id,
    s.agente_creador_id,
    s.categoria_servicio_ds,
    cl.cif_nif,
    s.segmento_ds,
    cl.subsegmento_ds,
    CASE
      WHEN s.marca_ds NOT IN ('R') THEN S.marca_cartera_ds
    ELSE
    CASE
      WHEN ABS(DATE_DIFF(CAST(s.fecha_rfb_dt AS DATE), CAST(rfb.fecha_alta_dt AS DATE), DAY))> 15 THEN 'CARTERA'
    ELSE
    'CAPTACION'
  END
  END
    marca_cartera_ds,
    rfb.fecha_alta_dt,
    s.equipo_ds,
    s.territorio_ds,
    s.tecnologia_detalle_ds,
    s.portabilidad_in_lg,
    CASE
      WHEN s.categoria_servicio_ds = 'BANDA ANCHA' THEN s.velocidad_mb
    ELSE
    s.gb
  END
    gb,
    s.expediente_id,s.expediente_padre_id, s.contrato_id, s.tipo_pedido_ds, s.pedido_id, s.tipo_producto_pedido_re_ds, s.visibilidad_pedido_lg, s.catalogo_id , 3 as grid 
  FROM
    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` C
  ON
    C.MARCA_DS = S.MARCA_DS
    AND C.CATEGORIA_SERVICIO_DS = S.CATEGORIA_SERVICIO_DS
    AND C.tipo_identificacion_ds = 'BLOQUE'
    AND
    CASE
      WHEN campo_filtrado = 'VELOCIDAD_MB' THEN S.VELOCIDAD_MB BETWEEN C.VALOR_MINIMO AND C.VALOR_MAXIMO
      WHEN campo_filtrado = 'GB' THEN S.GB BETWEEN C.VALOR_MINIMO
    AND C.VALOR_MAXIMO
  END
    AND adicional_lg = 0
    AND c.tecnologia_detalle_ds = s.tecnologia_detalle_ds
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cl
  ON
    s.marca_ds = cl.marca_ds
    AND s.cliente_id = cl.cliente_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` rfb
  ON
    rfb.cliente_id = s.cliente_id
    AND rfb.marca_ds = s.marca_ds
    AND rfb.desde_id <= s.fecha_rfb_id
    AND rfb.hasta_id > s.fecha_rfb_id
  LEFT JOIN (
    SELECT
      *
    FROM
      `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
    WHERE
      categoria_servicio_ds = 'MOVILES PREPAGO') smovprep
  ON
    s.servicio_id_origen = smovprep.servicio_id
  WHERE
    s.marca_ds <> 'R'
    AND (((s.fecha_rfb_id BETWEEN DESDE AND HASTA) AND ABS(DATE_DIFF(CAST(S.fecha_rfs_dt AS DATE), CAST(S.fecha_rfb_dt AS DATE), MONTH))<=2) or (s.FECHA_VENTA_NETA_ID BETWEEN DESDE AND HASTA))    
    --AND s.fecha_rfb_id BETWEEN DESDE AND HASTA
    AND UPPER(s.agente_creador_id) <> 'MIGRAMASHFC_FTTH'
    AND (s.servicio_id_origen < 0
      OR (UPPER(s.agente_creador_id) IN ('TC_MIGRA_MOV_202101')
        AND EXISTS (
        SELECT
          *
        FROM
          `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` stcmig
        INNER JOIN
          `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` stc
        ON
          stcmig.servicio_id_origen = stc.servicio_id
          AND stc.marca_ds = stcmig.marca_ds
        WHERE
          stc.marca_ds = 'TELECABLE'
          AND stc.sistema_ds = 'SGI'
          AND stcmig.servicio_id = s.servicio_id_original
          AND stc.fecha_rfb_id BETWEEN DESDE
          AND HASTA ) )
      OR (s.categoria_servicio_ds = 'MOVILES POSTPAGO'
        AND smovprep.CATEGORIA_SERVICIO_DS = 'MOVILES PREPAGO')
      OR (UPPER(S.agente_creador_id) IN ('MIGRACIONTMK')
        AND EXISTS (
        SELECT
          *
        FROM
          `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` stc
        WHERE
          stc.marca_ds = 'TELECABLE'
          AND stc.sistema_ds = 'SGI'
          AND stc.servicio_id = s.servicio_id_origen
          AND stc.fecha_rfb_id BETWEEN DESDE
          AND HASTA ) )
      OR EXISTS (
      SELECT
        1
      FROM
        `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` smig
      WHERE
        smig.cliente_id = s.cliente_id
        AND smig.marca_ds = s.marca_ds
        AND smig.servicio_id = s.servicio_id_original
        AND smig.fecha_rfb_id BETWEEN DESDE
        AND HASTA ) )
    AND ( (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO',
          'PYME')
        AND s.marca_ds NOT IN ('TELECABLE',
          'R'))
      OR (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO')
        AND s.marca_ds IN ('TELECABLE',
          'R')) )
    AND S.fecha_cancelacion_id > HASTA
    AND (S.fecha_baja_id > HASTA
      --OR S.SERVICIO_ID_DESTINO > 0
      )
    AND NOT EXISTS (
    SELECT
      1
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` T
    WHERE
      T.SERVICIO_ID = S.SERVICIO_ID
      AND T.MARCA_DS = S.MARCA_DS );


-- PASO 2: CREO TABLAS DE LOG

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`; 

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_INCR` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM  
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0102_VENTAS_CAPTACION`;

END