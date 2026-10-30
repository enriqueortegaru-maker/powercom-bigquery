BEGIN

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` AS

  --- Consulta con tablas de entrada
  --    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
  --    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS` C
  --    `mm-commissions-reporting.KRT_CAPTACION.CANALES` CA


  SELECT
    S.marca_ds,
    S.nombre_distribuidor_alta_ds,
    S.canal_alta_ds,
    S.subcanal_ds,
    S.tipo_canal_alta_ds,
    ca.grupo_rappel_ds,
    COUNT(servicio_id) BAS
  FROM
    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS` C
  ON
    C.MARCA_DS = S.MARCA_DS
    AND C.CATEGORIA_SERVICIO_DS = S.CATEGORIA_SERVICIO_DS
    AND C.tipo_identificacion_ds = 'BLOQUE'
    AND s.categoria_servicio_ds = 'BANDA ANCHA'
    AND
    CASE
      WHEN campo_filtrado = 'VELOCIDAD_MB' THEN S.VELOCIDAD_MB BETWEEN C.VALOR_MINIMO AND C.VALOR_MAXIMO
      WHEN campo_filtrado = 'GB' THEN S.GB BETWEEN C.VALOR_MINIMO
    AND C.VALOR_MAXIMO
  END
    AND adicional_lg = 0
    AND c.tecnologia_detalle_ds = s.tecnologia_detalle_ds
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.CANALES` CA
  ON
    S.MARCA_DS = CA.MARCA_DS
    AND S.NOMBRE_DISTRIBUIDOR_ALTA_DS = CA.NOMBRE_DISTRIBUIDOR_DS
    AND S.CANAL_ALTA_DS = CA.CANAL_DS
    AND S.TIPO_CANAL_ALTA_DS = CA.TIPO_CANAL_DS
    AND S.SUBCANAL_DS = CA.SUBCANAL_DS
    AND
    CASE
      WHEN CA.SEGMENTO_DS <> 'X' THEN CA.SEGMENTO_DS = S.SEGMENTO_DS
    ELSE
    TRUE
  END
    AND
    CASE
      WHEN CA.territorio_ds <> 'X' THEN S.TERRITORIO_DS = CA.TERRITORIO_DS
    ELSE
    TRUE
  END
  WHERE
    fecha_venta_bruta_id BETWEEN DESDE_ID
    AND HASTA_ID
    AND servicio_id_origen < 0
    AND UPPER(agente_creador_id) <> 'MIGRAMASHFC_FTTH'
    AND ((s.segmento_ds IN ('RESIDENCIAL',
          'SOHO',
          'PYME')
        AND s.marca_ds IN ('EUSKALTEL',
          'RACC',
          'VIRGIN'))
      OR (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO')
        AND s.marca_ds NOT IN ('EUSKALTEL',
          'RACC',
          'VIRGIN')))
    AND s.fecha_venta_bruta_id < CAST(FORMAT_DATE("%Y%m%d", CURRENT_DATE()) AS int64)
  GROUP BY
    S.marca_ds,
    S.nombre_distribuidor_alta_ds,
    S.canal_alta_ds,
    S.subcanal_ds,
    S.tipo_canal_alta_ds,
    ca.grupo_rappel_ds;

END