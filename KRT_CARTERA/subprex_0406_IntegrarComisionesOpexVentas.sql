BEGIN

  -- 1. Pre-calcular variables
  DECLARE v_mes_comision_id INT64;
  SET v_mes_comision_id = CAST(vdesde / 100 AS INT64);

  -- CONTROL 1: Validar que existe importe a procesar usando EXISTS
  IF EXISTS (
    SELECT 1 
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` 
    WHERE COALESCE(importe, 0) > 0 AND desde = vdesde
  ) THEN 

    -- 2. Crear tabla temporal aislando y clarificando la lógica
    CREATE OR REPLACE TEMP TABLE tmp_apuntes AS       
    --DECLARE VDESDE, V_MES_COMISION_ID INT64;SET VDESDE=20260201;SET v_mes_comision_id = CAST(vdesde / 100 AS INT64);
    WITH top AS (
      -- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo 
      --DECLARE VDESDE, V_MES_COMISION_ID INT64;SET VDESDE=20260201;SET v_mes_comision_id = CAST(vdesde / 100 AS INT64);
      SELECT 
        marca_ds,
        ClaseProducto,
        TipoProducto, 
        NombreProducto
      FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
      where canal not in ("PAD","B2B")
      GROUP BY 1, 2, 3, 4
      QUALIFY ROW_NUMBER() OVER (PARTITION BY marca_ds, TipoProducto ORDER BY SUM(importe) DESC) = 1
    ) 
    SELECT 
      c.marca, 
      c.canal, 
      c.subcanal, 
      c.distribuidor, 
      top.ClaseProducto, 
      c.categoria_servicio AS TipoProducto, 
      top.NombreProducto, 
      c.concepto,
      `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisionesv1`(c.desc_mm) AS clase_mm,
      c.desc_mm, 
      c.orden, 
      v_mes_comision_id AS mes_comision_id,
      c.importe, 
      c.importe AS importe_nivel, 
      c.importe AS total
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
    LEFT JOIN top 
      ON UPPER(TRIM(c.marca)) = TRIM(UPPER(top.marca_ds)) AND TRIM(UPPER(c.categoria_servicio)) = TRIM(UPPER(top.TipoProducto))   
    WHERE CONTAINS_SUBSTR(c.tipo, "CARTERA")
      AND c.desde = vdesde;

    -- CONTROL 2 (Idempotencia): Insertar solo los registros que NO existan previamente
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES` (
      marca_ds, segmento, canal, subcanal, nombre_distribuidor, ClaseProducto, 
      TipoProducto, NombreProducto, concepto_ds, clase_mm, desc_mm, 
      orden_sap, mes_comision_id, importe, importe_nivel, total
    )
    SELECT 
      t.marca, "RESIDENCIAL", t.canal, t.subcanal, t.distribuidor, t.ClaseProducto, 
      t.TipoProducto, t.NombreProducto, t.concepto, t.clase_mm, t.desc_mm, 
      t.orden, t.mes_comision_id, t.importe, t.importe_nivel, t.total
    FROM tmp_apuntes AS t
    WHERE NOT EXISTS (
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` dest
      WHERE dest.marca_ds = t.marca
        AND dest.canal = t.canal
        AND dest.subcanal = t.subcanal
        AND dest.nombre_distribuidor = t.distribuidor
        AND dest.concepto_ds = t.concepto
        AND dest.mes_comision_id = t.mes_comision_id
    );

  END IF;

END