BEGIN

  -- 1. Pre-calcular variables
  DECLARE v_mes_comision_id  INT64;
  --DECLARE VVERSION_FL INT64;
  --DECLARE VMES_DT DATE;
  --SET VMES_DT=(SELECT DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST (VDESDE AS string)),month));
  --SET vversion_fl=(SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerVersionDeFlujoVigenteEnMes`(VMES_DT));

  SET v_mes_comision_id = CAST(vdesde / 100 AS INT64);

  -- CONTROL 1: Validar que existe importe a procesar usando EXISTS 
  IF EXISTS (
    SELECT 1 
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` 
    WHERE COALESCE(importe, 0) > 0 AND desde = vdesde
  ) THEN 

    -- 2. Crear tabla temporal 
    CREATE OR REPLACE TEMP TABLE tmp_apuntes AS       
    WITH top AS (
      -- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo 
      SELECT 
        marca_ds, 
        categoria_servicio_ds, 
        detalle_servicio_ds
      FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
      GROUP BY 1, 2, 3
      QUALIFY ROW_NUMBER() OVER (PARTITION BY marca_ds, categoria_servicio_ds ORDER BY SUM(importe) DESC) = 1
    ) 
    SELECT 
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

    -- CONTROL 2: Insertar en COMISIONES solo los registros que NO existan previamente
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` (
      marca_ds, segmento_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,
      categoria_servicio_ds, detalle_servicio_ds, concepto_ds, clase_mm, 
      desc_mm, orden_sap, mes_comision_id, importe, decomisionable, grid
    )
    SELECT 
      t.marca, "RESIDENCIAL",t.canal, t.subcanal, t.distribuidor, t.categoria_servicio, 
      t.detalle_servicio_ds, t.concepto, t.clase_mm, t.desc_mm, t.orden, 
      t.mes_comision_id, t.importe, t.decomisionable, t.grid
    FROM tmp_apuntes AS t
    WHERE NOT EXISTS (
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` dest
      WHERE dest.marca_ds = t.marca
        AND dest.canal_alta_ds = t.canal
        AND dest.subcanal_ds = t.subcanal
        AND dest.nombre_distribuidor_alta_ds = t.distribuidor
        AND dest.concepto_ds = t.concepto
        AND dest.mes_comision_id = t.mes_comision_id
    );

  END IF;

END