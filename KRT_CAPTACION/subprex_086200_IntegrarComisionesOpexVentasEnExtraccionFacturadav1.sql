BEGIN

  -- 1. Pre-calcular las fechas y variables de forma eficiente
  DECLARE v_desde_dt DATE;
  DECLARE v_fecha_calc_or_dt DATE;
  DECLARE v_fecha_calc_de_dt DATE;
  DECLARE v_mes_comision_id INT64;

  SET v_desde_dt = PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING));
  SET v_fecha_calc_or_dt = PARSE_DATE("%Y%m%d", CAST(vfecha_calc_or AS STRING));
  SET v_fecha_calc_de_dt = PARSE_DATE("%Y%m%d", CAST(vfecha_calc_de AS STRING));
  SET v_mes_comision_id = CAST(vdesde / 100 AS INT64);

  -- CONTROL 1: Validar que existe importe a procesar en la parametrización usando EXISTS
  IF EXISTS (
    SELECT 1 
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` 
    WHERE COALESCE(importe, 0) > 0 AND desde = vdesde
  ) THEN 

    -- 2. Crear tabla temporal de apuntes a integrar (Limpia y optimizada)
    CREATE OR REPLACE TEMP TABLE tmp_apuntes AS       
    WITH top AS (
      -- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo 
      -- y posteriormente poder generar el concepto SAP  
      SELECT 
        ag.marca_ds,
        ag.desde, 
        ag.hasta,
        ag.version,
        ag.categoria_servicio_ds, 
        ag.detalle_servicio_ds
      FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` ag
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.V_FLUJO_MESxVERSION` vr 
        ON vr.mes = v_desde_dt    
      WHERE ag.desde = vdesde
        AND ag.fecha_calc_dt = v_fecha_calc_or_dt
        AND ag.version = vr.version
      GROUP BY 1, 2, 3, 4, 5, 6
      QUALIFY ROW_NUMBER() OVER (PARTITION BY ag.marca_ds, ag.categoria_servicio_ds ORDER BY SUM(ag.importe) DESC) = 1
    ) 
    SELECT 
      v_fecha_calc_de_dt AS fecha_calc_dt, 
      top.desde,
      top.hasta,
      top.version,            
      c.marca, 
      c.canal, 
      c.subcanal, 
      c.distribuidor,
      c.categoria_servicio,
      top.detalle_servicio_ds, 
      c.concepto,
      `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(c.desc_mm) AS clase_mm,
      c.desc_mm, 
      c.orden, 
      v_mes_comision_id AS mes_comision_id, 
      c.importe, 
      'N' AS decomisionable, 
      666 AS grid
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
    LEFT JOIN top 
      ON c.marca = top.marca_ds AND c.categoria_servicio = top.categoria_servicio_ds    
    WHERE CONTAINS_SUBSTR(c.tipo, "CAPTACION")
      AND c.desde = vdesde;

    -- CONTROL 2: Insertar en AGG_COMISIONES solo los registros que NO existan previamente
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` (
      fecha_calc_dt, desde, hasta, version,marca_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,
      categoria_servicio_ds, detalle_servicio_ds, concepto_ds, clase_mm, desc_mm, 
      orden_sap, mes_comision_id, importe, decomisionable, grid
    )
    SELECT 
      t.fecha_calc_dt, t.desde, t.hasta, t.version, t.marca, t.canal, t.subcanal, t.distribuidor, 
      t.categoria_servicio, t.detalle_servicio_ds, t.concepto, t.clase_mm, t.desc_mm, 
      t.orden, t.mes_comision_id, t.importe, t.decomisionable, t.grid
    FROM tmp_apuntes AS t
    WHERE NOT EXISTS (
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` dest
      WHERE dest.fecha_calc_dt = t.fecha_calc_dt
        AND dest.marca_ds = t.marca
        AND dest.canal_alta_ds = t.canal
        AND dest.subcanal_ds = t.subcanal
        AND dest.nombre_distribuidor_alta_ds = t.distribuidor -- Control por distribuidor
        AND dest.concepto_ds = t.concepto
        AND dest.mes_comision_id = t.mes_comision_id
    );

  END IF;

END