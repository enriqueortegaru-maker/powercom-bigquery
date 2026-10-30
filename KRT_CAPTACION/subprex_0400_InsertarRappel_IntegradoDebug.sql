BEGIN

  /* PASO 1: LECTURA ÚNICA, CÁLCULO VECTORIZADO E INSERCIÓN DUAL
    Insertamos Teórico y Diferencia en una sola transacción leyendo la base 1 sola vez.
  */

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0400_MARCO_RETRIBUTIVO_RAPPEL`  
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  WITH base_filtrada AS (
      -- 1.1 Extraemos la base comisionable aplicando los filtros compartidos de 0402 y 0403
      SELECT 
          t.*,
          r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.n8, r.n9, r.n10, 
          r.n11, r.n12, r.n13, r.n14, r.n15, r.n16, r.n17, r.n18, r.n19, r.n20,
          CAST(a.nivel AS INT64) AS nivel_teorico,
          CAST(ra.nivel_alcanzado_id AS INT64) AS nivel_asignado
      FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` t
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` r
          ON t.marca_ds = r.marca_ds AND t.grupo_rappel_ds = r.agrupacion_rappel_ds
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO` a
          ON t.marca_ds = a.marca_ds AND t.nombre_distribuidor_alta_ds = a.nombre_distribuidor_alta_ds
          AND t.canal_alta_ds = a.canal_alta_ds AND t.subcanal_ds = a.subcanal_ds AND t.grupo_rappel_ds = a.grupo_rappel_ds
      LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO` ra
          ON t.marca_ds = ra.marca_ds AND t.nombre_distribuidor_alta_ds = ra.nombre_distribuidor_ds
          AND t.canal_alta_ds = ra.canal_ds AND t.subcanal_ds = ra.subcanal_ds AND t.grupo_rappel_ds = ra.grupo_rappel_ds
      WHERE t.grupo_rappel_ds IS NOT NULL
        AND t.categoria_servicio_ds = 'BANDA ANCHA'
        -- Excluimos rappels ya calculados para asegurar IDEMPOTENCIA
        AND t.concepto_ds NOT IN ('Descuento plataforma cancelación', 'Rappel Teorico', 'Rappel Diferencia')
        AND UPPER(TRIM(t.tecnologia_detalle_ds)) <> 'FTTR'
        AND UPPER(t.detalle_servicio_ds) NOT LIKE 'DESCUENTO%'
        AND UPPER(t.detalle_servicio_ds) NOT LIKE '%ESTUDIANTE%'
  ),
  
  importes_calculados AS (
      -- 1.2 Vectorizamos el CASE masivo convirtiéndolo en un ARRAY de acceso directo
      SELECT 
          *,
          COALESCE(
            [n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18,n19,n20]
            [SAFE_OFFSET(nivel_teorico - 1)], 0.0
          ) AS importe_teorico,
          
          COALESCE(
            [n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18,n19,n20]
            [SAFE_OFFSET(nivel_asignado - 1)], 0.0
          ) AS importe_asignado
      FROM base_filtrada
  ),
  
  rappel_teorico AS (
      -- 1.3 Preparamos los registros de Rappel Teórico
      SELECT 
          marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, 
          'Rappel Teorico' AS CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, fecha_rfb_dt, fecha_venta_neta_dt,
          canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, 
          categoria_servicio_ds, cif_nif, segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, 
          territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb, expediente_id, expediente_padre_id, contrato_id, 
          tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg, catalogo_id, grid,
          'D - Rappel Teorico' as desc_mm, 'D - Extracomision' as clase_mm,
          pedido, nplays, nplays_rfb, cat_plays, cat_plays_rfb, nplays_p, nplays_rfb_p, cat_plays_p, cat_plays_rfb_p,
          clave, marco_retributivo_ds, flag_marca_cartera, grupo_rappel_ds, orden_sap,
          importe_teorico AS importe
      FROM importes_calculados
  ),
  
  rappel_diferencia AS (
      -- 1.4 Preparamos los registros de Rappel Diferencia (Aplicando la lógica original del 0403)
      SELECT 
          marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, 
          'Rappel Diferencia' AS CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, fecha_rfb_dt, fecha_venta_neta_dt,
          canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, 
          categoria_servicio_ds, cif_nif, segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, 
          territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb, expediente_id, expediente_padre_id, contrato_id, 
          tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg, catalogo_id, grid,
          'D - Rappel Diferencia' as desc_mm, 'D - Extracomision' as clase_mm,
          pedido, nplays, nplays_rfb, cat_plays, cat_plays_rfb, nplays_p, nplays_rfb_p, cat_plays_p, cat_plays_rfb_p,
          clave, marco_retributivo_ds, flag_marca_cartera, grupo_rappel_ds, orden_sap,
          (importe_teorico - importe_asignado) AS importe
      FROM importes_calculados
      WHERE (nivel_teorico <> nivel_asignado) OR (nivel_teorico IS NULL)
  )

  -- 1.5 Ensamblamos todo y mandamos a insertar
  SELECT * FROM rappel_teorico
  UNION ALL
  SELECT * FROM rappel_diferencia;

END