BEGIN

  -- 1. Pre-calcular las fechas
  DECLARE v_desde_dt DATE;
  DECLARE v_fecha_calc_or_dt DATE;
  DECLARE v_fecha_calc_de_dt DATE;
  DECLARE v_mes_comision_id INT64;
  DECLARE v_mes_comision_dt DATE;

  -- Se asume que vdesde viene con formato YYYYMMDD. Si viene YYYYMM, esto fallará.
  SET v_desde_dt = PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING));
  SET v_fecha_calc_or_dt = PARSE_DATE("%Y%m%d", CAST(vfecha_calc_or AS STRING));
  SET v_fecha_calc_de_dt = PARSE_DATE("%Y%m%d", CAST(vfecha_calc_de AS STRING));
  SET v_mes_comision_id = CAST(vdesde / 100 AS INT64);
  SET v_mes_comision_dt = PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING));


  -- CONTROL 1: Validar que existe importe en la parametrización
  IF EXISTS (
    SELECT 1 
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` 
    WHERE COALESCE(importe, 0) > 0 AND desde = vdesde
  ) THEN 

    -- Crear tabla temporal de apuntes
    CREATE OR REPLACE TEMP TABLE tmp_apuntes AS       
    WITH top AS (
      SELECT 
        ag.marca_ds, 
        ag.desde, 
        ag.hasta,
        ag.version,
        ag.TipoProducto, 
        ag.ClaseProducto,
        ag.NombreProducto
      FROM `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` ag
      INNER JOIN `mm-commissions-reporting.KRT_CARTERA.V_FLUJO_MESxVERSION` vr 
        ON vr.mes = v_desde_dt    
      WHERE ag.desde = vdesde
        AND ag.fecha_calc_dt = v_fecha_calc_or_dt
        AND ag.version = vr.version
      GROUP BY 1, 2, 3, 4, 5, 6, 7
      QUALIFY ROW_NUMBER() OVER (PARTITION BY ag.marca_ds, ag.TipoProducto ORDER BY SUM(ag.importe) DESC) = 1
    ) 
    SELECT 
      v_fecha_calc_de_dt AS fecha_calc_dt, 
      -- Cuidado aquí: Si el LEFT JOIN falla, top.desde, hasta y version serán NULL.
      top.desde,
      top.hasta,
      top.version,            
      c.marca, 
      c.canal, 
      c.subcanal, 
      c.distribuidor AS nombre_distribuidor, 
      top.ClaseProducto, 
      c.categoria_servicio AS TipoProducto, 
      top.NombreProducto, 
      c.concepto AS concepto_ds,
      `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisionesv1`(c.desc_mm) AS clase_mm,
      c.desc_mm, 
      c.orden AS orden_sap, 
      v_mes_comision_id AS mes_comision_id,
      c.importe 
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
    LEFT JOIN top 
      ON c.marca = top.marca_ds AND c.categoria_servicio = top.TipoProducto  
    WHERE c.tipo = "CARTERA"
      AND c.desde = vdesde;

    -- CONTROL 2 (Integrado): Insertar en AGG_COMISIONES solo si no existen previamente
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` (
      fecha_calc_dt, desde, hasta, version, marca_ds, canal, subcanal, nombre_distribuidor, ClaseProducto, 
      TipoProducto, NombreProducto, concepto_ds, clase_mm, desc_mm, orden_sap, 
      mes_comision_id, importe, importe_nivel, total, decomisionable
    )
    SELECT 
      t.fecha_calc_dt, t.desde, t.hasta, t.version, t.marca, t.canal, t.subcanal, t.nombre_distribuidor, t.ClaseProducto, 
      t.TipoProducto, t.NombreProducto, t.concepto_ds, t.clase_mm, t.desc_mm, t.orden_sap, 
      t.mes_comision_id, 
      t.importe, t.importe, t.importe, 'N'
    FROM tmp_apuntes AS t
    WHERE NOT EXISTS (
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` dest
      WHERE dest.fecha_calc_dt = t.fecha_calc_dt
        AND dest.marca_ds = t.marca
        AND dest.canal = t.canal
        AND dest.subcanal = t.subcanal
        AND dest.nombre_distribuidor = t.nombre_distribuidor
        AND dest.concepto_ds = t.concepto_ds
        AND dest.mes_comision_id = t.mes_comision_id
    ); 

    -- CONTROL 2 (Integrado): Insertar en AGG_COMISIONES_LISTADO solo si no existen previamente
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` (
      fecha_calc_dt, desde, hasta, version, marca_ds, canal, subcanal, nombre_distribuidor, ClaseProducto, 
      TipoProducto, NombreProducto, concepto_lista, concepto_ds, clase_mm, desc_mm, 
      orden_sap, mes_comision_id, mes_comision_dt, importe, decomisionable
    )
    SELECT 
      t.fecha_calc_dt, t.desde, t.hasta, t.version, t.marca, t.canal, t.subcanal, t.nombre_distribuidor, t.ClaseProducto, 
      t.TipoProducto, t.NombreProducto, 'Unitario' AS concepto_lista, t.concepto_ds, 
      t.clase_mm, t.desc_mm, t.orden_sap, t.mes_comision_id, v_mes_comision_dt, t.importe, 'N'
    FROM tmp_apuntes AS t
    WHERE NOT EXISTS (
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` dest
      WHERE dest.fecha_calc_dt = t.fecha_calc_dt
        AND dest.marca_ds = t.marca
        AND dest.canal = t.canal
        AND dest.subcanal = t.subcanal
        AND dest.nombre_distribuidor = t.nombre_distribuidor
        AND dest.concepto_ds = t.concepto_ds
        AND dest.concepto_lista = 'Unitario'
        AND dest.mes_comision_id = t.mes_comision_id
    );

  END IF;

END