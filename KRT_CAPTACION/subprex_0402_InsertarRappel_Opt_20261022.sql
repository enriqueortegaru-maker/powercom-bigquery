BEGIN

  /* PASO 1: Inserción directa del Rappel Teórico.
    Evitamos crear tablas LOG intermedias para el volcado. La inserción se hace en vuelo.
  */

  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
  
  SELECT
      t.marca_ds, t.Cliente_id, t.servicio_id, t.detalle_servicio_ds,
      'Rappel Teorico' AS CONCEPTO_DS,
      t.FECHA_RFB_ID, t.FECHA_VENTA_NETA_ID, t.fecha_rfb_dt, t.fecha_venta_neta_dt,
      t.canal_alta_ds, t.subcanal_ds, t.tipo_canal_alta_ds, t.nombre_distribuidor_alta_ds,
      t.agente_alta_id, t.agente_creador_id, t.categoria_servicio_ds, t.cif_nif,
      t.segmento_ds, t.subsegmento_ds, t.marca_cartera_ds, t.Antiguedad_Cliente,
      t.equipo_ds, t.territorio_ds, t.tecnologia_detalle_ds, t.portabilidad_in_lg,
      t.gb, t.expediente_id, t.expediente_padre_id, t.contrato_id, t.tipo_pedido_ds,
      t.pedido_id, t.tipo_producto_pedido_re_ds, t.visibilidad_pedido_lg, t.catalogo_id,
      t.grid, 
      'D - Rappel Teorico' AS desc_mm, 
      'D - Extracomision' AS clase_mm,
      t.pedido, t.nplays, t.nplays_rfb, t.cat_plays, t.cat_plays_rfb,
      t.nplays_p, t.nplays_rfb_p, t.cat_plays_p, t.cat_plays_rfb_p,
      t.clave, t.marco_retributivo_ds, t.flag_marca_cartera, t.grupo_rappel_ds, t.orden_sap,
      
      -- OPTIMIZACIÓN CORE: Arrays dinámicos en lugar de CASE masivos. 
      -- BigQuery mapeará el nivel alcanzado directamente a la posición del array.
      CAST(
        [r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.n8, r.n9, r.n10, 
         r.n11, r.n12, r.n13, r.n14, r.n15, r.n16, r.n17, r.n18, r.n19, r.n20]
        [SAFE_OFFSET(CAST(ra.nivel AS INT64) - 1)] 
      AS FLOAT64) AS importe

  FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` t
  
  /* LEFT JOIN se mantiene para parámetros, pero INNER JOIN para el alcanzado 
     asegura que no iteremos sobre ventas que no clasificaron para rappel */
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` r
      ON t.marca_ds = r.marca_ds AND t.grupo_rappel_ds = r.agrupacion_rappel_ds
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO` ra
      ON t.marca_ds = ra.marca_ds
      AND t.nombre_distribuidor_alta_ds = ra.nombre_distribuidor_alta_ds
      AND t.canal_alta_ds = ra.canal_alta_ds
      AND t.subcanal_ds = ra.subcanal_ds
      AND t.grupo_rappel_ds = ra.grupo_rappel_ds
      
  WHERE t.grupo_rappel_ds IS NOT NULL
    AND t.categoria_servicio_ds = 'BANDA ANCHA'
    -- IDEMPOTENCIA: Previene re-inserción cíclica de rappels en recálculos
    AND t.concepto_ds NOT IN ('Descuento plataforma cancelación', 'Rappel Teorico', 'Rappel Diferencia')
    AND UPPER(TRIM(t.tecnologia_detalle_ds)) <> 'FTTR'
    AND UPPER(t.detalle_servicio_ds) NOT LIKE 'DESCUENTO%'
    AND UPPER(t.detalle_servicio_ds) NOT LIKE '%ESTUDIANTE%';


  /* PASO 2: LOGGING OPTIMIZADO
    Si Finanzas requiere una vista del resultado, extraemos SOLO lo recién calculado, 
    no toda la tabla de nuevo.
  */
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0402_MARCO_RETRIBUTIVO_RAPPEL` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` 
  WHERE CONCEPTO_DS IN ('Rappel Teorico', 'Rappel Diferencia');

END