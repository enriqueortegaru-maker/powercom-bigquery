BEGIN

  -- PASO 1: Creamos tabla con población de nuevos eventos con rappel teórico

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0402_MARCO_RETRIBUTIVOxCANAL_INCR` AS

  --- Tabla entrada 
  ---  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`        -> Marco retributivo -> MARCO_RETRIBUTIVOxCANAL
  ---  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL` -> 
  ---  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL ALCANZADO` -> RAPPEL ALCANZADO

    SELECT
      DISTINCT t.marca_ds,
      t.Cliente_id,
      t.servicio_id,
      t.detalle_servicio_ds,
      'Rappel Teorico' CONCEPTO_DS,
      t.FECHA_RFB_ID,
      t.FECHA_VENTA_NETA_ID,
      t.fecha_rfb_dt,
      t.fecha_venta_neta_dt,
      t.canal_alta_ds,
      t.subcanal_ds,
      t.tipo_canal_alta_ds,
      t.nombre_distribuidor_alta_ds,
      t.agente_alta_id,
      t.agente_creador_id,
      t.categoria_servicio_ds,
      t.cif_nif,
      t.segmento_ds,
      t.subsegmento_ds,
      t.marca_cartera_ds,
      t.Antiguedad_Cliente,
      t.equipo_ds,
      t.territorio_ds,
      t.tecnologia_detalle_ds,
      t.portabilidad_in_lg,
      t.gb,
      t.expediente_id,
      t.expediente_padre_id,
      t.contrato_id,
      t.tipo_pedido_ds,
      t.pedido_id,
      t.tipo_producto_pedido_re_ds,
      t.visibilidad_pedido_lg,
      t.catalogo_id,
      t.grid,
      'D - Rappel Teorico' as desc_mm,
      'D - Extracomision' as clase_mm,
--      t.desc_mm,
--      t.clase_mm,
      t.pedido,
      t.nplays,
      t.nplays_rfb,
      t.cat_plays,
      t.cat_plays_rfb,
      t.nplays_p,
      t.nplays_rfb_p,
      t.cat_plays_p,
      t.cat_plays_rfb_p,
      t.clave,
      t.marco_retributivo_ds,
      t.flag_marca_cartera,
      t.grupo_rappel_ds,
      t.orden_sap,
      CAST(CASE
          WHEN CAST(nivel AS int64) = 1 THEN n1
          WHEN CAST(nivel AS int64) = 2 THEN n2
          WHEN CAST(nivel AS int64) = 3 THEN n3
          WHEN CAST(nivel AS int64) = 4 THEN n4
          WHEN CAST(nivel AS int64) = 5 THEN n5
          WHEN CAST(nivel AS int64) = 6 THEN n6
          WHEN CAST(nivel AS int64) = 7 THEN n7
          WHEN CAST(nivel AS int64) = 8 THEN n8
          WHEN CAST(nivel AS int64) = 9 THEN n9
          WHEN CAST(nivel AS int64) = 10 THEN n10
          WHEN CAST(nivel AS int64) = 11 THEN n11
          WHEN CAST(nivel AS int64) = 12 THEN n12
          WHEN CAST(nivel AS int64) = 13 THEN n13
          WHEN CAST(nivel AS int64) = 14 THEN n14
          WHEN CAST(nivel AS int64) = 15 THEN n15
          WHEN CAST(nivel AS int64) = 16 THEN n16
          WHEN CAST(nivel AS int64) = 17 THEN n17
          WHEN CAST(nivel AS int64) = 18 THEN n18
          WHEN CAST(nivel AS int64) = 19 THEN n19
          WHEN CAST(nivel AS int64) = 20 THEN n20
        ELSE
        0
      END
        AS float64) importe
    FROM (
      SELECT
        *
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
      WHERE
        grupo_rappel_ds IS NOT NULL
        AND categoria_servicio_ds = 'BANDA ANCHA'
        AND concepto_ds <> 'Descuento plataforma cancelación'
        AND UPPER(TRIM(tecnologia_detalle_ds)) <> 'FTTR'
        AND UPPER(detalle_servicio_ds) NOT LIKE 'DESCUENTO%'
        AND UPPER(detalle_servicio_ds) NOT LIKE '%ESTUDIANTE%' ) t
    LEFT JOIN
      `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` r
    ON
      t.marca_ds = r.marca_ds
      AND t.grupo_rappel_ds = r.agrupacion_rappel_ds
    LEFT JOIN
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ALCANZADO` ra
    ON
      t.marca_ds = ra.marca_ds
      AND t.nombre_distribuidor_alta_ds = ra.nombre_distribuidor_alta_ds
      AND t.canal_alta_ds = ra.canal_alta_ds
      AND t.subcanal_ds = ra.subcanal_ds
      AND t.grupo_rappel_ds = ra.grupo_rappel_ds;


  -- PASO 2: Insertamos eventos

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0402_MARCO_RETRIBUTIVOxCANAL_INCR` ;



  -- PASO 3: CREO TABLA LOG DE SALIDA

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
        `mm-commissions-reporting.KRT_CAPTACION.LOG_0402_MARCO_RETRIBUTIVOxCANAL` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`; 



END