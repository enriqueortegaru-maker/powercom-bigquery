BEGIN

  -- 1. PRECALCULO FECHA Y VERSIONES ACTIVAS
  -- Evita parsear fechas (PARSE_DATE) millones de veces dentro del WHERE/EXISTS.
  CREATE OR REPLACE TEMP TABLE tmp_versiones_activas AS
  SELECT DISTINCT 
    version,
    DATE_TRUNC(PARSE_DATE("%Y-%m-%d", CAST(mes AS STRING)), MONTH) as mes_calculo
  FROM `mm-commissions-reporting.KRT_CAPTACION.V_FLUJO_MESxVERSION`;


  -- 2. PASO 1 : CORRECTIVO ENERGIA
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
  SET categoria_servicio_ds = "ENERGIA"
  WHERE (categoria_servicio_ds IS NULL OR LENGTH(categoria_servicio_ds) < 2)
    AND (
         -- Usamos UPPER para asegurar coincidencia sin importar mayúsculas/minúsculas
         UPPER(detalle_Servicio_ds) IN ('ELECTRICIDAD','GAS','SVE','SVG') 
         OR CONTAINS_SUBSTR(concepto_ds, "energia") 
    );


  -- 3. PASO 2 : RESTO (COMISIONES)
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
  SET c.categoria_servicio_ds = s.categoria_servicio_ds
  FROM ( 
      -- Seleccionamos solo las columnas necesarias para el JOIN
      SELECT DISTINCT marca_ds, cliente_id, servicio_id, categoria_servicio_ds 
      FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`  
  ) s
  WHERE s.marca_ds = c.marca_ds
    AND s.cliente_id = c.cliente_id
    AND s.servicio_id = c.servicio_id
    AND (c.categoria_servicio_ds IS NULL OR LENGTH(c.categoria_servicio_ds) < 2)
    -- Cruce optimizado contra la tabla temporal
    AND EXISTS (
        SELECT 1 
        FROM tmp_versiones_activas v
        WHERE v.mes_calculo = DATE_TRUNC(c.fecha_Calc_dt, MONTH) 
          AND v.version = c.version
    );


  -- 4. PASO 3 : RESTO (AGG_COMISIONES)
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c
  SET c.categoria_servicio_ds = s.categoria_servicio_ds
  FROM ( 
      SELECT DISTINCT marca_ds, cliente_id, servicio_id, categoria_servicio_ds 
      FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`  
  ) s
  WHERE s.marca_ds = c.marca_ds
    AND s.cliente_id = c.cliente_id
    AND s.servicio_id = c.servicio_id
    AND (c.categoria_servicio_ds IS NULL OR LENGTH(c.categoria_servicio_ds) < 2)
    AND EXISTS (
        SELECT 1 
        FROM tmp_versiones_activas v
        WHERE v.mes_calculo = DATE_TRUNC(c.fecha_Calc_dt, MONTH) 
          AND v.version = c.version
    );

END