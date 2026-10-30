BEGIN

-- DECLARACIÓN DE VARIABLES
DECLARE sql, prefijo, mes_string STRING;
DECLARE fecha_inicio DATE;
DECLARE fecha_fin DATE;
DECLARE mes_anterior STRING;

SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'ARJSM';
SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
SET fecha_fin = LAST_DAY(fecha_inicio);
SET mes_anterior = FORMAT_DATE('%Y%m', DATE_SUB(fecha_inicio, INTERVAL 1 MONTH));


  -- call `mm-commissions-reporting.COMISIONES.pr_upfront_dorus_jsm`(202609, ['JSM'])

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activaciones_JSM` AS

SELECT
  
 
  FIRST_VALUE(codigo_pas) OVER (
    PARTITION BY codigo_cli, tipo_servicio
    ORDER BY fecha_activacion
  ) AS codigo_pas_inicial,
 
  MIN(fecha_activacion) OVER (
    PARTITION BY codigo_cli, tipo_servicio
  ) AS fecha_activacion_inicial,
 
  MAX(fecha_baja) OVER (
    PARTITION BY codigo_cli, tipo_servicio
  ) AS fecha_baja_final,

  t.*
 
FROM `mm-dwh-prod.00_SANDBOX_DORUS.seguimientoventas` t
WHERE 1=1
;

CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.base_fibra_JSM` AS

  WITH base_fibra AS (
    SELECT 
      a.id,
      a.codigo_pas,
      a.codigo_pas_anterior_ct, 
      a.tipo_cambio_pas,
      a.codigo_cli,
      a.nombre_cliente, 
      a.dni_cliente,
      a.contrato, 
      a.tipo_servicio,
      a.tipo_reporte,
      a.producto,
      
      -- Categorización Velocidad Fibra Blanca
      CASE 
        WHEN a.tipo_reporte = 'FIBRA BLANCA' THEN
          CASE 
            WHEN a.producto LIKE '%100Mb%' THEN 'FIBRA 100MB'
            WHEN a.producto LIKE '%50Mb%'  THEN 'FIBRA 50MB'
            WHEN a.producto LIKE '%1 Gb%'  THEN 'FIBRA 1GB'
            WHEN REGEXP_CONTAINS(a.producto, r'(?i)600\s*Mb|500\s*Mb') THEN 'FIBRA 600MB'
            ELSE 'OTRAS VELOCIDADES'
          END
      END AS producto_velocidad,
      
      -- Categorización Velocidad Fibra Propia (<200MB / >=300MB)
      CASE 
        WHEN a.tipo_reporte = 'FIBRA PROPIA' THEN
          CASE 
            WHEN REGEXP_CONTAINS(a.producto, r'(?i)\b(10|20|30|50|100|200)\s*MB\b') THEN '200MB E INFERIORES'
            ELSE '300MB Y SUPERIORES'
          END
      END AS producto_velocidad_2,

      -- Categorización Velocidad Fibra Propia (1GB)
      CASE 
        WHEN a.tipo_reporte = 'FIBRA PROPIA' THEN
          CASE 
            WHEN REGEXP_CONTAINS(a.producto, r'(?i)\b(1|10)\s*GB\b') THEN 'FIBRA PROPIA >= 1GB'
            ELSE 'FIBRA PROPIA < 1GB'
          END
      END AS producto_velocidad_3,

      CASE 
        WHEN a.precio_producto < 10 THEN 'Menor de 10'
        WHEN a.precio_producto <= 10 THEN 'Mayor de 10'
      END AS producto_precio,

      a.promocion,
      a.empresa_distribuidora,
      a.tienda,
      TRIM(REGEXP_REPLACE(a.tienda, r'\s*\(.*?\)', '')) AS sfid,
      a.operadora,
      a.fecha_contrato,
      a.fecha_activacion,
      a.fecha_baja,
      a.estado,
      a.telefono1_cli,
      a.telefono2_cli,
      a.telefono_servicio,
      a.precio_producto,
      a.estado_servicio,
      a.ultimo_estado,
      a.motivo_baja,
      a.estado_anterior,
      a.tipo_numero,
      a.operador_entrante,
      a.operador_saliente,
      (UPPER(a.producto) LIKE '%NEBA%') AS es_neba

    FROM `mm-commissions-reporting.TEMP.activaciones_JSM` a
    WHERE a.fecha_activacion BETWEEN fecha_inicio AND fecha_fin
      --AND a.fecha_baja IS NULL
      AND a.estado IN ('ALTA', 'ALTAS CAMBIO DE TECNOLOGIA')
      AND a.tipo_servicio = 'FIBRA'
      --AND a.fecha_activacion_inicial < DATE_SUB(a.fecha_activacion, INTERVAL 2 MONTH)
  )

    

  SELECT 
    f.*,
    b.id_comisionista,
    b.documento AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision

  FROM base_fibra f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
    ON f.sfid = b.id_comisionista

  -- TABLA 1: MARCO_COMISIONES_JSM (Requiere coincidencia de velocidad en ciertos marcos)
  LEFT JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.canal = c.marco_retributivo
   AND (
     (f.tipo_reporte = 'FIBRA BLANCA' AND NOT f.es_neba AND b.canal IN ('MRESP', 'MRIN', 'FRAN_PANDERA') AND f.producto_velocidad = c.producto AND c.servicio = 'FIBRA BLANCA')

     OR (f.tipo_reporte = 'FIBRA BLANCA' AND NOT f.es_neba AND b.canal NOT IN ('MRESP', 'MRIN', 'FRAN_PANDERA') AND c.servicio = 'FIBRA BLANCA')
     
     OR
     (f.tipo_reporte = 'FIBRA PROPIA' AND NOT f.es_neba AND b.canal IN ('MRESP', 'MRIN', 'FRAN_PANDERA') AND f.producto_velocidad_2 = c.producto AND c.servicio = 'FIBRA PROPIA')
     OR
     (f.tipo_reporte = 'FIBRA PROPIA' AND NOT f.es_neba AND (b.canal LIKE 'AMR%' OR b.canal = 'NMR') AND f.producto_velocidad_3 = c.producto AND c.servicio = 'FIBRA PROPIA')
     OR
     (f.tipo_reporte = 'FIBRA PROPIA' AND NOT f.es_neba AND b.canal NOT IN ('MRESP', 'MRIN', 'FRAN_PANDERA', 'NMR') AND b.canal NOT LIKE 'AMR%' AND c.servicio = 'FIBRA PROPIA')
   
     OR

     (f.es_neba AND c.servicio = 'FIBRA NEBA')
   )
     
  --Solo mantenemos las filas que hayan cruzado correctamente con alguna de las dos tablas de comisiones
  WHERE c.marco_retributivo IS NOT NULL 


  -- Sacamos la Cooperativa Valenciana que va por otro listado de Dealers donde tenemos las cadenas con padres e hijos

  UNION ALL

SELECT 
    f.*,
    b.sfid_hijo,
    b.cif_padre AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision

  FROM base_fibra f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b
    ON f.sfid = b.sfid_hijo

  -- TABLA 1: MARCO_COMISIONES_JSM (Requiere coincidencia de velocidad en ciertos marcos)
  LEFT JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.marco_retributivo_padre = c.marco_retributivo
   AND (
     (f.tipo_reporte = 'FIBRA BLANCA' AND NOT f.es_neba AND c.servicio = 'FIBRA BLANCA')

     OR (f.tipo_reporte = 'FIBRA PROPIA' AND NOT f.es_neba AND c.servicio = 'FIBRA PROPIA')

     OR (f.es_neba AND c.servicio = 'FIBRA NEBA')

     OR (f.es_neba AND c.servicio = 'FIBRA NEBA')
   )
     
  --Solo mantenemos las filas que hayan cruzado correctamente con alguna de las dos tablas de comisiones
  WHERE c.marco_retributivo IS NOT NULL ;






--------------------------------------------------------------------------------
-- 2. COMISIONES FIJO
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_fijo_wimax_JSM` AS
  WITH base_fijo_wimax AS (
    SELECT 
      a.id,
      a.codigo_pas,
      a.codigo_pas_anterior_ct, 
      a.tipo_cambio_pas,
      a.codigo_cli,
      a.nombre_cliente, 
      a.dni_cliente,
      a.contrato, 
      a.tipo_servicio,
      a.tipo_reporte,
      a.producto,
      --TRIM(REGEXP_REPLACE(a.tienda, r'\s*\(.*?\)', '')) AS sfid,
      CASE 
        WHEN a.tipo_servicio = 'FIJO' THEN
          CASE
            WHEN UPPER(a.producto) = 'FIJO A FIJO 1000 MINUTOS' THEN 'FIJO A FIJO 1000 MINUTOS'
            WHEN REGEXP_CONTAINS(UPPER(a.producto), r'250\s*MIN|500\s*MIN|1000\s*MIN|2000\s*MIN|ILIMITADO') THEN 'FIJO >=250 MIN'
            ELSE 'FIJO < 50 MIN'
          END
      END AS producto_fijo_parametrizado,
       CASE
        WHEN REGEXP_CONTAINS(UPPER(a.producto), r'FD24|FDP|\bFD\b|DIRECTO')
          OR SAFE_CAST(REGEXP_EXTRACT(UPPER(a.producto), r'(\d+)\s*MB') AS INT64) > 30
          OR REGEXP_CONTAINS(UPPER(a.producto), r'100\s*MB|150\s*MB|300\s*MB|450\s*MB|500\s*MB|40\s*MB|50\s*MB|32\s*MB|50X50|100/100')
          THEN 'WIMAX > 30 MB (O FD)'
        WHEN SAFE_CAST(REGEXP_EXTRACT(UPPER(a.producto), r'(\d+)\s*MB') AS INT64) <= 30
          OR REGEXP_CONTAINS(UPPER(a.producto), r'\b(1|2|3|4|5|6|8|10|12|13|15|16|20|25|30)\s*MB\b')
          OR REGEXP_CONTAINS(UPPER(a.producto), r'30X10|30X15|20X10|20X20|15X5|10X10|30/2|30/3|20/2|20/1|12/2|12/1|10/1')
          OR REGEXP_CONTAINS(UPPER(a.producto), r'MEGAS')
          THEN 'WIMAX 30 MB'
        ELSE 'WIMAX'
      END AS producto_wimax_velocidad,

       a.promocion,
      a.empresa_distribuidora,
      a.tienda,
      TRIM(REGEXP_REPLACE(a.tienda, r'\s*\(.*?\)', '')) AS sfid,
      a.operadora,
      a.fecha_contrato,
      a.fecha_activacion,
      a.fecha_baja,
      a.estado,
      a.telefono1_cli,
      a.telefono2_cli,
      a.telefono_servicio,
      a.precio_producto,
      a.estado_servicio,
      a.ultimo_estado,
      a.motivo_baja,
      a.estado_anterior,
      a.tipo_numero,
      a.operador_entrante,
      a.operador_saliente,
      (UPPER(a.producto) LIKE '%NEBA%') AS es_neba


    FROM `mm-commissions-reporting.TEMP.activaciones_JSM` a
    WHERE a.fecha_activacion BETWEEN fecha_inicio AND fecha_fin
      AND a.estado IN ('ALTA', 'ALTAS CAMBIO DE TECNOLOGIA')
      AND a.tipo_servicio IN ('FIJO', 'WIMAX')
      --AND a.fecha_activacion_inicial < DATE_SUB(a.fecha_activacion, INTERVAL 2 MONTH)
  )
  SELECT 
    f.*,
    b.id_comisionista,
    b.documento AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront 
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision
  FROM base_fijo_wimax f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
    ON f.sfid = b.id_comisionista
  INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.canal = c.marco_retributivo
   AND  
    (
     (f.tipo_reporte = 'FIJO' AND (b.canal) IN ('FRAN_PANDERA', 'MRED') AND c.servicio = 'FIJO')
     OR
     (
       f.tipo_reporte = 'FIJO' AND REGEXP_CONTAINS(UPPER(b.canal), r'^(AMR|NMR)') AND b.canal NOT IN ('FRAN_PANDERA', 'MRED')
       AND c.producto = f.producto_fijo_parametrizado AND c.servicio = 'FIJO'
     )

     OR 
      (f.tipo_reporte = 'WIMAX' AND (b.canal LIKE 'AMR%' OR b.canal = 'NMR') AND c.producto = f.producto_wimax_velocidad AND c.servicio = 'WIMAX')

    OR 
      (f.tipo_reporte = 'WIMAX' AND (b.canal NOT LIKE 'AMR%' AND b.canal <> 'NMR') AND c.servicio = 'WIMAX')

    )



    UNION ALL



   SELECT 
    f.*,
    b.sfid_hijo,
    b.cif_padre AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision
  FROM base_fijo_wimax f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b
    ON f.sfid = b.sfid_hijo
  INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.marco_retributivo_padre = c.marco_retributivo
   AND  (f.tipo_reporte = 'WIMAX' AND c.servicio = 'WIMAX')

   --Solo mantenemos las filas que hayan cruzado correctamente con alguna de las dos tablas de comisiones
  WHERE c.marco_retributivo IS NOT NULL ;

    



--------------------------------------------------------------------------------
-- 3. COMISIONES MÓVIL
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_movil_JSM` AS
  WITH base_movil AS (
    SELECT 
      a.id,
      a.codigo_pas,
      a.codigo_pas_anterior_ct, 
      a.tipo_cambio_pas,
      a.codigo_cli,
      a.nombre_cliente, 
      a.dni_cliente,
      a.contrato, 
      a.tipo_servicio,
      a.tipo_reporte,
      a.producto,
      
      -- 1. Categorización PVP (Versión 1)
      CASE 
        WHEN a.precio_producto > 0 AND a.precio_producto <= 6 THEN 'MOVIL <= 6€'
        WHEN a.precio_producto > 6 AND a.precio_producto <= 10 THEN 'MOVIL <= 10€'
        WHEN a.precio_producto > 10 AND a.precio_producto <= 20 THEN 'MOVIL <= 20€'
        WHEN a.precio_producto > 20 AND a.precio_producto <= 30 THEN 'MOVIL <= 30€'
        WHEN a.precio_producto > 30 THEN 'MOVIL > 30€'
      END AS movil_pvp_v1,

      -- 2. Categorización PVP (Versión 2)
      CASE 
        WHEN a.precio_producto > 0 AND a.precio_producto < 10 THEN 'MOVIL <10€ PVP'
        WHEN a.precio_producto >= 10 THEN 'MOVIL >10€ PVP'
      END AS movil_pvp_v2,

      -- 3. Categorización PVP (Versión 3)
      CASE 
        WHEN a.precio_producto > 0 AND a.precio_producto < 9.90 THEN 'SERVICIOS MOVILES TARIFA < 9,90€'
        WHEN a.precio_producto >= 9.90 AND a.precio_producto < 19.90 THEN 'SERVICIOS MOVILES TARIFA >= 9,90€'
        WHEN a.precio_producto >= 19.90 AND a.precio_producto < 29.90 THEN 'SERVICIOS MOVILES TARIFA >= 19,90€'
        WHEN a.precio_producto >= 29.90 THEN 'SERVICIOS MOVILES TARIFA >= 29,90€'
      END AS movil_pvp_v3,

      -- 4. Categorización Ilimitada
      CASE 
        WHEN REGEXP_CONTAINS(UPPER(a.producto), r'ILIM') THEN 'MOVIL ILIMITADO + GB'
        ELSE 'MOVIL MINUTOS + MB'
      END AS movil_ilimitada,

      a.promocion,
      a.empresa_distribuidora,
      a.tienda,
      TRIM(REGEXP_REPLACE(a.tienda, r'\s*\(.*?\)', '')) AS sfid,
      a.operadora,
      a.fecha_contrato,
      a.fecha_activacion,
      a.fecha_baja,
      a.estado,
      a.telefono1_cli,
      a.telefono2_cli,
      a.telefono_servicio,
      a.precio_producto,
      a.estado_servicio,
      a.ultimo_estado,
      a.motivo_baja,
      a.estado_anterior,
      a.tipo_numero,
      a.operador_entrante,
      a.operador_saliente,
      (UPPER(a.producto) LIKE '%NEBA%') AS es_neba

    FROM `mm-commissions-reporting.TEMP.activaciones_JSM` a
    WHERE a.fecha_activacion BETWEEN fecha_inicio AND fecha_fin 
      AND a.estado IN ('ALTA', 'ALTAS CAMBIO DE TECNOLOGIA')
      AND a.tipo_servicio = 'MOVIL'
      --AND a.fecha_activacion_inicial < DATE_SUB(a.fecha_activacion, INTERVAL 2 MONTH)

      -- Añade aquí si aplica alguna validación adicional de fecha_activacion_inicial
  )

  SELECT 
    f.*,
    b.id_comisionista,
    b.documento AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront 
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision
  FROM base_movil f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
    ON f.sfid = b.id_comisionista
  INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.canal = c.marco_retributivo
   
  AND (
      -- Ajusta los nombres de los marcos específicos y los campos de c.producto según tus tablas de Google Sheets
      
      -- Ejemplo para marcos que miran PVP v1
      (b.canal IN ('AMR_INNOVACIONES','AMR_PADILLA','AMR_FORTIC','AMR_WIMAX','AMR_WIMAX_PEGALAJAR', 'NMR') AND c.producto = f.movil_pvp_v1 AND c.servicio = 'MOVIL')
      
      -- Ejemplo para marcos que miran PVP v2
      OR (b.canal IN ('COOP_COAHIJO', 'COOP_COARVAL', 'COOP_COARVAL_PADRE', 'COOP_UPA', 'COOP_UPNA', 'MREXTv2v2', 'MRPOP', 'MRPOPV2', 'MRA') AND c.producto = f.movil_pvp_v2 AND c.servicio = 'MOVIL')

      -- Ejemplo para marcos que miran PVP v3
      OR (b.canal IN ('FRAN_PANDERA', 'MRESP', 'MRIN') AND c.producto = f.movil_pvp_v3 AND c.servicio = 'MOVIL')

      -- Ejemplo para marcos que miran si es ilimitada
      OR (b.canal IN ('MRED') AND c.producto = f.movil_ilimitada AND c.servicio = 'MOVIL')

      -- 5. El resto de marcos que pagan todos sus móviles de una misma manera (sin distinguir producto/precio)
      OR (b.canal IN ('GESTELCOM', 'NMDR') AND c.servicio = 'MOVIL')
   )
      



   UNION ALL


   SELECT 
    f.*,
    b.sfid_hijo,
    b.cif_padre AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision
  FROM base_movil f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CADENAS_JSM` b
    ON f.sfid = b.sfid_hijo
  INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.marco_retributivo_padre = c.marco_retributivo
    AND (c.producto = f.movil_pvp_v3 AND c.servicio = 'MOVIL')
    
    
    
    --Solo mantenemos las filas que hayan cruzado correctamente con alguna de las dos tablas de comisiones
  WHERE c.marco_retributivo IS NOT NULL ;
   


    -- 4. OTROS


    CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_otros_JSM` AS
  WITH base_movil AS (
    SELECT 
      a.id,
      a.codigo_pas,
      a.codigo_pas_anterior_ct, 
      a.tipo_cambio_pas,
      a.codigo_cli,
      a.nombre_cliente, 
      a.dni_cliente,
      a.contrato, 
      a.tipo_servicio,
      a.tipo_reporte,
      a.producto,
      
      CASE 
        WHEN a.producto IN ('IP FIJA', 'IP Fija', 'PRO IP FIJA') THEN 'IP FIJA'
        WHEN a.producto IN ('Centralita', 'Centralita - cuota', 'Centralita Virtual') THEN 'CENTRALITA'
        WHEN a.producto LIKE 'Bono%' AND producto LIKE '%fijo%' THEN 'SERVICIOS ADICIONALES (BONOS DE MINUTOS EN FIJO)'
        WHEN a.producto LIKE 'Bono%' AND producto NOT LIKE '%fijo%' THEN 'SERVICIOS ADICIONALES (BONOS DE MINUTOS, DATOS, ETC.)'
        ELSE null
      END AS producto_categorizado,

      a.promocion,
      a.empresa_distribuidora,
      a.tienda,
      TRIM(REGEXP_REPLACE(a.tienda, r'\s*\(.*?\)', '')) AS sfid,
      a.operadora,
      a.fecha_contrato,
      a.fecha_activacion,
      a.fecha_baja,
      a.estado,
      a.telefono1_cli,
      a.telefono2_cli,
      a.telefono_servicio,
      a.precio_producto,
      a.estado_servicio,
      a.ultimo_estado,
      a.motivo_baja,
      a.estado_anterior,
      a.tipo_numero,
      a.operador_entrante,
      a.operador_saliente,
      (UPPER(a.producto) LIKE '%NEBA%') AS es_neba

    FROM `mm-commissions-reporting.TEMP.activaciones_JSM` a
    WHERE a.fecha_activacion BETWEEN fecha_inicio AND fecha_fin 
      AND a.estado IN ('ALTA', 'ALTAS CAMBIO DE TECNOLOGIA')
      AND a.tipo_servicio = 'OTROS'
      AND a.fecha_activacion_inicial < DATE_SUB(a.fecha_activacion, INTERVAL 2 MONTH)

  )

  SELECT 
    f.*,
    b.id_comisionista,
    b.documento AS cif,
    c.marco_retributivo,
    CASE 
      WHEN f.producto LIKE 'Bono%' THEN 0
      WHEN f.estado = 'ALTA' THEN c.upfront 
      WHEN f.estado = 'ALTAS CAMBIO DE TECNOLOGIA' THEN c.cambio_te
    END AS comision
  FROM base_movil f
  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
    ON f.sfid = b.id_comisionista
  INNER JOIN `mm-commissions-reporting.GS.MARCO_COMISIONES_JSM` c
    ON b.canal = c.marco_retributivo
   AND (
      
      (b.canal IN ('AMR_INNOVACIONES','AMR_PADILLA','AMR_FORTIC','AMR_WIMAX','AMR_WIMAX_PEGALAJAR', 'MRESP', 'MRIN', 'NMR') AND c.producto = f.producto_categorizado AND c.servicio = 'OTROS')
      
     
   );


  -- UNIMOS TODO EL UPFRONT

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.captacion_total_JSM` AS

  SELECT 
    id, codigo_pas, codigo_cli, codigo_pas_anterior_ct, contrato, tipo_servicio, tipo_reporte, producto, operadora, telefono_servicio,
    empresa_distribuidora, cif, fecha_activacion, fecha_baja, precio_producto, estado, sfid, id_comisionista, 
    marco_retributivo, comision

  FROM `mm-commissions-reporting.TEMP.base_fibra_JSM`

  UNION ALL

  SELECT 
    id, codigo_pas, codigo_cli, codigo_pas_anterior_ct, contrato, tipo_servicio, tipo_reporte, producto, operadora, telefono_servicio,
    empresa_distribuidora, cif, fecha_activacion, fecha_baja, precio_producto, estado, sfid, id_comisionista, 
    marco_retributivo, comision
  
  FROM `mm-commissions-reporting.TEMP.base_fijo_wimax_JSM`

  UNION ALL

  SELECT 
    id, codigo_pas, codigo_cli, codigo_pas_anterior_ct, contrato, tipo_servicio, tipo_reporte, producto, operadora, telefono_servicio,
    empresa_distribuidora, cif, fecha_activacion, fecha_baja, precio_producto, estado, sfid, id_comisionista, 
    marco_retributivo, comision
  
  FROM `mm-commissions-reporting.TEMP.base_movil_JSM`

  UNION ALL

  SELECT 
    id, codigo_pas, codigo_cli, codigo_pas_anterior_ct, contrato, tipo_servicio, tipo_reporte, producto, operadora, telefono_servicio,
    empresa_distribuidora, cif, fecha_activacion, fecha_baja, precio_producto, estado, sfid, id_comisionista, 
    marco_retributivo, comision 
  
  FROM `mm-commissions-reporting.TEMP.base_otros_JSM`;



   -- CLAWBACK


    -- Mi base de clawback va a ser lo que he pagado desde el pasado mes hacia atrás, + lo que voy a pagar este mes para quitar el clawback de dichas altas (es algo que se hace en JSM para mantener la trazabilidad)

  CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.base_clawback_JSM` AS 

  WITH base_clawback AS (

  -- Nos traemos del bucket todo lo pagado en los ultimos 18 meses en concepto de Upfront
    
  SELECT 

    CAST (data_month_id AS INT64) AS id_mes,
    id_contrato AS contrato,
    CAST (id_cliente AS INT64) AS codigo_cli,
    entidad AS empresa_distribuidora,
    cif_entidad AS cif,
    sfid AS id_comisionista,
    DATE(SAFE_CAST(fecha_instalacion AS TIMESTAMP)) AS fecha_activacion,
    DATE(SAFE_CAST(fecha_baja AS TIMESTAMP)) AS fecha_baja,
    CAST (codigo_pas AS INT64) AS codigo_pas,
    CAST (codigo_pas_anterior AS INT64) AS codigo_pas_anterior_ct,
    nombre_producto as producto,
    tipo_cambio,
    tipo_comision,
    servicio AS tipo_servicio,
    null AS tipo_reporte,
    CAST(REPLACE(IMPORTE_COMISION,',','.') as FLOAT64) AS comision
 
    
  FROM `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`
  WHERE 1 = 1
    AND tipo_cambio IN ('NUEVA ALTA', 'CAMBIO TECNOLOGIA')
    AND tipo_comision IN ('CAPTACION', 'REGULARIZACION CAPTACION')
    AND CAST(data_month_id AS INT64) < mes_int -- Hay cosas en el bucket en 202609 que son de 202608 (APP y FORTIC)
    AND DATE(SAFE_CAST(fecha_instalacion AS TIMESTAMP)) > DATE_SUB(fecha_inicio, INTERVAL 20 MONTH)
    AND CAST(REPLACE(IMPORTE_COMISION,',','.') as FLOAT64) > 0
 

  
  -- Lo unimos al Upfront que vamos a pagar este mes
  
  
  UNION ALL

  SELECT 
    202607 AS id_mes,
    contrato,
    codigo_cli,
    empresa_distribuidora,
    cif,
    id_comisionista,
    fecha_activacion,
    fecha_baja,
    codigo_pas,
    codigo_pas_anterior_ct,
    producto,
    estado AS tipo_cambio,
    'CAPTACION' AS tipo_comision,
    tipo_servicio,
    tipo_reporte,
    comision


  FROM `mm-commissions-reporting.TEMP.captacion_total_JSM` 

  )
     
  -- Ahora extraemos de nuestras tablas de base todas las líneas de captación que han causado baja este mes
  -- Cruzaremos con nuestra base de clawback mediante contrato, sfid y PAS para quitarle la comisión a quién corresponda

    SELECT 
      a.id,
      a.fecha_activacion_inicial,
      a.fecha_baja_final,
      b.codigo_pas,
      b.codigo_pas_anterior_ct, 
      a.tipo_cambio_pas,
      a.codigo_cli,
      b.empresa_distribuidora, 
      b.cif,
      a.contrato, 
      a.tipo_servicio,
      a.tipo_reporte,
      a.producto,
      CASE 
        WHEN a.precio_producto < 9.90 THEN 'SERVICIOS MOVILES TARIFA < 9,90€'
        ELSE 'SERVICIOS MOVILES TARIFA >= 9,90€'
      END AS producto_movil_pvp,
      b.comision,
      a.promocion,
      a.tienda,
      TRIM(REGEXP_REPLACE(a.tienda, r'\s*\(.*?\)', '')) AS sfid,
      a.operadora,
      a.fecha_contrato,
      b.fecha_activacion,
      a.fecha_baja,
      DATE_DIFF(a.fecha_baja, b.fecha_activacion, MONTH) AS fecha_dif,
      a.estado,
      a.telefono1_cli,
      a.telefono2_cli,
      a.telefono_servicio,
      a.precio_producto,
      a.estado_servicio,
      a.ultimo_estado,
      a.motivo_baja,
      a.estado_anterior,
      a.tipo_numero,
      a.operador_entrante,
      a.operador_saliente,
      (UPPER(a.producto) LIKE '%NEBA%') AS es_neba

    FROM `mm-commissions-reporting.TEMP.activaciones_JSM` a
    INNER JOIN base_clawback b
    ON a.sfid = b.id_comisionista AND a.contrato = b.contrato AND a.codigo_pas = b.codigo_pas
    WHERE 1 = 1
      AND b.fecha_activacion > DATE_SUB(fecha_inicio, INTERVAL 20 MONTH)
      AND a.fecha_baja BETWEEN fecha_inicio AND fecha_fin
      AND a.estado IN ('BAJA', 'BAJAS CAMBIO DE TECNOLOGIA');



      CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.clawback_fibra_fijo_wimax_JSM` AS 

      
      
      SELECT 
        a.* ,
        1 as unidades,
        b.id_comisionista,
        b.canal,
        b.documento AS cif_GS,
        CASE 
          WHEN a.fecha_dif = 0 THEN a.comision * -1
          WHEN b.canal LIKE 'AMR%' THEN
            CASE 
              WHEN a.fecha_dif < 18 THEN a.comision * -1
              ELSE 0
            END

          WHEN (b.canal LIKE 'COOP%' OR b.canal IN ('MREXTv2v2', 'MRA', 'MRPOPV2')) THEN
            CASE
              WHEN a.fecha_dif < 6 THEN a.comision * -1
              WHEN a.fecha_dif >= 6 AND a.fecha_dif < 12 THEN a.comision * -0.5
              ELSE 0
            END
          
          WHEN b.canal IN ('FRAN_PANDERA', 'MRESP') THEN
            CASE
              WHEN a.fecha_dif < 6 THEN a.comision * -1
              WHEN a.fecha_dif >= 6 AND a.fecha_dif < 9 THEN a.comision * -0.75
              WHEN a.fecha_dif >= 9 AND a.fecha_dif < 12 THEN a.comision * -0.5
              ELSE 0
            END
          
          WHEN b.canal = 'GESTELCOM' THEN
            CASE
              WHEN a.fecha_dif < 6 THEN a.comision * -1
              WHEN a.fecha_dif >= 6 AND a.fecha_dif < 9 THEN a.comision * -0.75
              ELSE 0
            END

          WHEN b.canal IN ('MRED', 'MRIN', 'NMR') THEN
            CASE 
          -- Si la diferencia entre baja y alta es menor a 18 meses, quitamos la comisión 
              WHEN a.fecha_dif < 12 THEN a.comision * -1
              ELSE 0
            END

          WHEN b.canal = 'MRPOP' THEN
            CASE
              WHEN a.fecha_dif < 6 THEN a.comision * -1
              WHEN a.fecha_dif >= 6 AND a.fecha_dif < 12 THEN a.comision * -0.75
              ELSE 0
            END

          WHEN b.canal = 'NMDR' THEN
            CASE
              WHEN a.fecha_dif < 12 THEN a.comision * -1
              WHEN a.fecha_dif >= 12 AND a.fecha_dif < 18 THEN a.comision * -0.5
              ELSE 0
            END

          ELSE 0
        END AS comision_clawback,
        comision as comision_upfront

      

      FROM `mm-commissions-reporting.TEMP.base_clawback_JSM` a

      LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
      ON a.sfid = b.id_comisionista

      -- No hace falta cruzar con el marco porque me baso en la comisión pagada

      WHERE a.tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX');




CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.clawback_movil_JSM` AS 

      
      
      SELECT 
        a.* ,
        1 as unidades,
        b.id_comisionista,
        b.canal,
        b.documento AS cif_GS,
        CASE 
          WHEN a.fecha_dif = 0 THEN a.comision * -1
          WHEN (b.canal LIKE 'AMR%' OR b.canal IN ('NMDR', 'NMR')) THEN
            CASE 
              WHEN a.fecha_dif < 12 THEN a.comision * -1
              ELSE 0
            END

          WHEN (b.canal LIKE 'COOP%' OR b.canal IN ('GESTELCOM', 'MREXTv2v2', 'MRA', 'MRED', 'MRESP', 'MRIN', 'MRPOP', 'MRPOPV2')) THEN
            CASE
              WHEN a.fecha_dif <= 6 THEN a.comision * -1
              ELSE 0
            END
          
          WHEN b.canal = 'FRAN_PANDERA' AND producto_movil_pvp = 'SERVICIOS MOVILES TARIFA < 9,90€' THEN
            CASE
              WHEN a.fecha_dif < 6 THEN a.comision * -1
              WHEN a.fecha_dif >= 6 AND a.fecha_dif < 9 THEN a.comision * -0.75
              WHEN a.fecha_dif >= 9 AND a.fecha_dif < 12 THEN a.comision * -0.5
              ELSE 0
            END

          WHEN b.canal = 'FRAN_PANDERA' AND producto_movil_pvp = 'SERVICIOS MOVILES TARIFA >= 9,90€' THEN
            CASE
              WHEN a.fecha_dif <= 6 THEN a.comision * -1
              ELSE 0
            END

          ELSE 0
        END AS comision_clawback,
        comision as comision_upfront

      

      FROM `mm-commissions-reporting.TEMP.base_clawback_JSM` a

      LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
      ON a.sfid = b.id_comisionista

      -- No hace falta cruzar con el marco porque me baso en la comisión pagada

      WHERE a.tipo_servicio = 'MOVIL';



-- UNIMOS CLAWBACK

CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.clawback_JSM` AS

SELECT * FROM  `mm-commissions-reporting.TEMP.clawback_fibra_fijo_wimax_JSM`
WHERE comision_clawback <> 0

UNION ALL


SELECT * FROM  `mm-commissions-reporting.TEMP.clawback_movil_JSM`
WHERE comision_clawback <> 0
;



-- UNIMOS ACTIVACIONES Y CLAWBACK


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_upfront_JSM` AS


SELECT 
  prefijo||'_'||mes_string||'_'||'JSM'||'_'||row_number () over() AS commission_id,
  'calculado' AS estado, 
  DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, 
  CAST(mes_string AS INT64) AS id_mes,
  'B2B2C - Populoos' AS agrupacion_canal,
  'JSM' AS canal,
  'A - Servicio base' AS concepto,
  'UPF1' AS tipo_concepto,
  1 AS unidades,
  comision,
  sfid AS id_comisionista,  
  operadora AS distribuidor,
  sfid AS sfid_id,  
  sfid AS seller,
  b.nombre_comercio AS nombre_comercio,
  b.nombre_comercio AS razon_social,
  b.documento AS cif,
  'PEN' AS zona_fiscal,
  'Z020' AS cond_pago,
  'JSM' AS marca,
  CASE WHEN tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX', 'OTROS') THEN 'INTERNET'
    ELSE 'MOBILE' END AS service_type,
  telefono_servicio AS phone_nm,
  null AS tariff_id,
  producto AS tariff_ds,
  null AS service_id,
  contrato AS account_id,
  codigo_cli AS customer_id,
  CAST(NULL AS STRING) AS line_type_ds,
  tipo_reporte AS bundle_type,
  CAST(NULL AS STRING) AS technology_ds,  
  CAST(NULL AS STRING) AS billing_type_ds, 
  fecha_activacion AS sale_date,
  fecha_activacion AS activation_date,
  fecha_baja AS deactivation_date,
  CAST(NULL AS STRING) AS order_id, 
  estado AS order_type_agg, 
  '42' AS cod_segmento,
  '09' AS cod_marca,
  CASE 
    WHEN tipo_servicio = 'MOVIL' THEN '20'
    WHEN tipo_servicio = 'FIBRA' THEN '61'
    WHEN tipo_servicio = 'FIJO' THEN '63'
    WHEN tipo_servicio = 'WIMAX' THEN '64'
    ELSE '98'
  END AS cod_tipo_contrato,
  '039' AS cod_producto,
  '27' AS cod_canal,
  'CAPTACION' AS campaign_code, 
  CAST(NULL AS STRING) AS serial_number, 
  CAST(NULL AS FLOAT64) AS tax_base, 
  CAST(codigo_pas AS STRING) AS claim_code, 
  CAST(NULL AS STRING) AS process_code, 
  CAST(NULL AS STRING) AS comments, 
  'C_MANUAL' AS facturador, 
  CAST(NULL AS STRING) AS proceso_sap, 
  CAST(NULL AS STRING) AS id_registro, 
  CAST(NULL AS STRING) AS invoice_id, 
  '8300' AS sociedad,
  CAST(NULL AS STRING) AS bp, 
  '0060722112' AS cuenta_contable, 
  CAST(NULL AS STRING) AS centro_coste, 
  CAST(NULL AS STRING) AS documento_sap,
  CAST(NULL AS STRING) AS documento_sap_posicion,
  CAST(NULL AS STRING) AS fecha_contabilizacion,
  CAST(NULL AS TIMESTAMP) AS creado,
  CAST(NULL AS TIMESTAMP) AS modificado,
  CAST(NULL AS STRING) AS id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad

FROM `mm-commissions-reporting.TEMP.captacion_total_JSM` a
LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
ON a.sfid = b.id_comisionista

UNION ALL

SELECT 
  prefijo||'_'||mes_string||'_'||'JSM'||'_'||row_number () over() AS commission_id,
  'calculado' AS estado, 
  DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, 
  CAST(mes_string AS INT64) AS id_mes,
  'B2B2C - Populoos' AS agrupacion_canal,
  'JSM' AS canal,
  'E - Clawback' AS concepto,
  'UPF1' AS tipo_concepto,
  -1 AS unidades,
  comision_clawback AS comision,
  sfid AS id_comisionista,  
  operadora AS distribuidor,
  sfid AS sfid_id,  
  sfid AS seller,
  b.nombre_comercio AS nombre_comercio,
  b.nombre_comercio AS razon_social,
  b.documento AS cif,
  'PEN' AS zona_fiscal,
  'Z020' AS cond_pago,
  'JSM' AS marca,
  CASE WHEN tipo_servicio IN ('FIBRA', 'FIJO', 'WIMAX', 'OTROS') THEN 'INTERNET'
    ELSE 'MOBILE' END AS service_type,
  telefono_servicio AS phone_nm,
  null AS tariff_id,
  producto AS tariff_ds,
  null AS service_id,
  contrato AS account_id,
  codigo_cli AS customer_id,
  CAST(NULL AS STRING) AS line_type_ds,
  tipo_reporte AS bundle_type,
  CAST(NULL AS STRING) AS technology_ds,  
  CAST(NULL AS STRING) AS billing_type_ds, 
  fecha_activacion AS sale_date,
  fecha_activacion AS activation_date,
  fecha_baja AS deactivation_date,
  CAST(NULL AS STRING) AS order_id, 
  estado AS order_type_agg, 
  '42' AS cod_segmento,
  '09' AS cod_marca,
  CASE 
    WHEN tipo_servicio = 'MOVIL' THEN '20'
    WHEN tipo_servicio = 'FIBRA' THEN '61'
    WHEN tipo_servicio = 'FIJO' THEN '63'
    WHEN tipo_servicio = 'WIMAX' THEN '64'
    ELSE '98'
  END AS cod_tipo_contrato,
  '039' AS cod_producto,
  '27' AS cod_canal,
  'CAPTACION' AS campaign_code, 
  CAST(NULL AS STRING) AS serial_number, 
  CAST(NULL AS FLOAT64) AS tax_base, 
  CAST(codigo_pas AS STRING) AS claim_code, 
  CAST(NULL AS STRING) AS process_code, 
  CAST(NULL AS STRING) AS comments, 
  'C_MANUAL' AS facturador, 
  CAST(NULL AS STRING) AS proceso_sap, 
  CAST(NULL AS STRING) AS id_registro, 
  CAST(NULL AS STRING) AS invoice_id, 
  '8300' AS sociedad,
  CAST(NULL AS STRING) AS bp, 
  '0060722112' AS cuenta_contable, 
  CAST(NULL AS STRING) AS centro_coste, 
  CAST(NULL AS STRING) AS documento_sap,
  CAST(NULL AS STRING) AS documento_sap_posicion,
  CAST(NULL AS STRING) AS fecha_contabilizacion,
  CAST(NULL AS TIMESTAMP) AS creado,
  CAST(NULL AS TIMESTAMP) AS modificado,
  CAST(NULL AS STRING) AS id_factura_drive,
  CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.clawback_JSM` a
LEFT JOIN `mm-commissions-reporting.GS.DEALERS_JSM` b
ON a.sfid = b.id_comisionista
;


DELETE `mm-commissions-reporting.TEMP.comisiones_upfront_JSM` 
WHERE comision = 0 OR cif is null;



END