BEGIN

  -- Tabla salida
  --  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  


--- Paso 1: Identifico los registros a introducir en tabla AJUSTES_EVENTOS_DEFINITIVOS

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
  -- Tabla entrada
  --  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
  --  `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS`

  SELECT
    DISTINCT t.marca_ds,
    t.Cliente_id,
    t.servicio_id,
    t.detalle_servicio_ds,
    CONCAT('Extra por concepto: ', e.CONCEPTO_DS) concepto_ds,
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
    t.desc_mm,
    t.clase_mm,
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
    CASE
      WHEN e.POR_BA = 'S' THEN e.importe
    ELSE
    CASE
      WHEN e.subcanal_ds = 'X' THEN e.importe/clientes
    ELSE
    e.importe/clientes_subcanal
  END
  END
    importe,
    e.decomisionable
  FROM (
    SELECT
      *,
      COUNT(*) OVER (PARTITION BY marca_ds, nombre_distribuidor_alta_ds, canal_alta_ds, subcanal_ds) clientes_subcanal,
      COUNT(*) OVER (PARTITION BY marca_ds, nombre_distribuidor_alta_ds, canal_alta_ds) clientes
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
    WHERE
      --grupo_rappel_ds IS NOT NULL
      --AND 
      categoria_servicio_ds = 'BANDA ANCHA'
      AND concepto_ds <> 'Descuento plataforma cancelación'
      AND concepto_ds NOT IN ('Rappel',
        'Rappel Teorico',
        'Rappel Diferencia',
        'Rappel Llamada')
      AND concepto_ds NOT LIKE 'Extra por concepto: %'
      AND UPPER(detalle_servicio_ds) NOT LIKE 'DESCUENTO%'
      AND UPPER(detalle_servicio_ds) NOT LIKE '%ESTUDIANTE%' )t
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS`  e
  ON
    t.marca_ds = e.marca_ds
    AND t.nombre_distribuidor_alta_ds = e.nombre_distribuidor_ds
    AND
    CASE
      WHEN e.subcanal_ds <> 'X' THEN t.subcanal_ds = e.subcanal_ds
    ELSE
    TRUE
  END
    AND t.canal_alta_ds = e.canal_ds;



  -- PASO 2: INSERTO REGISTROS DE LOG

    -- Log de fichero completo
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`; 


    -- Log de incremento
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_INCR` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` 
    EXCEPT DISTINCT
    SELECT
      * 
    FROM  
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0503_AJUSTES_EVENTOS_DEFINITIVOS`;


----
--
--  CONTROL DE VERSIONES
--
--    v1: 20220628 :Se incluye exclusión de Rappel Llamada, tras modificar flujo, e incluir el concepto_ds 'Rappel Llamada' como nuevo concepto_ds
--                  Se incluye tabla LOG_0505_AJUSTES_EVENTOS_DEFINITIVOS
--        

END