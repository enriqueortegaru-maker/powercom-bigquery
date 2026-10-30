BEGIN

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION_MM.EVENTOS_CAPTACION`
  SELECT
    DISTINCT S.marca_ds,
    s.Cliente_id,
    CAST(servicio_id AS int64) servicio_id,
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
      WHEN s.marca_ds NOT IN ('TELECABLE', 'R') THEN S.marca_cartera_ds
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
    CASE
      WHEN servicio_id_origen < 0 THEN 'NO'
    ELSE
    'SI'
  END
    CAMBIO,
    c.multiplicador
  FROM
    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CATALOGO` C
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
  WHERE
    s.marca_ds <> 'R'
    AND fecha_rfb_id BETWEEN DESDE
    AND HASTA
    AND UPPER(agente_creador_id) <> 'MIGRAMASHFC_FTTH'
    AND ((s.segmento_ds IN ('RESIDENCIAL',
          'SOHO',
          'PYME')
        AND s.marca_ds NOT IN ('TELECABLE',
          'R'))
      OR (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO')
        AND s.marca_ds IN ('TELECABLE',
          'R')))
    AND fecha_cancelacion_id > HASTA
    AND (fecha_baja_id > HASTA
      OR SERVICIO_ID_DESTINO > 0)
    AND NOT EXISTS (
    SELECT
      1
    FROM
      `mm-commissions-reporting.KRT_CAPTACION_MM.EVENTOS_CAPTACION` T
    WHERE
      T.SERVICIO_ID = S.SERVICIO_ID
      AND T.MARCA_DS = S.MARCA_DS)
    AND ABS(DATE_DIFF(CAST(fecha_rfs_dt AS DATE), CAST(fecha_rfb_dt AS DATE), MONTH))<=2;
  
END