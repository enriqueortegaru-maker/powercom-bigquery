BEGIN
  -- Arquitectura V5:
  -- 1. Cero lógica de commission_id.
  -- 2. Cruce por las 5 claves: sociedad, marca, orden, segmento, clase_concepto (CONCEPTO).
  -- 3. Reglas de segmento:
  --    - Regla 1 (CSV): SPLIT por ','
  --    - Regla 2 (MASIVO): 'MASIVO' -> ['RESIDENCIAL', 'SOHO', 'PYME']
  --    - Regla 3 (BUSINESS): 'PYME P', 'PYME M', 'PYME - P', 'PYME - M', 'BUSINESS' <-> 'BUSINESS'
  --    - Coherencia GRUPOSxCONCEPTOS / ORDENES: cuando en CODIGO_SAP un concepto terminado en 'Negocios'
  --      tiene grabado SEGMENTO='RESIDENCIAL' por error de carga (órdenes 110000001290, 110000001882,
  --      210000001416, 230000001623, 180000010297, 180000010299), habilita 'SOHO' y 'PYME' según GRUPOSxCONCEPTOS.
  DECLARE VFQ_TABLA, VMES, VTIPOS_SQL, VSQL STRING;
  DECLARE VTIPOS ARRAY<STRING>;
  DECLARE VMES_FACTURA_DT DATE;

  IF vtabla IS NULL OR vtabla NOT IN ('TRANSACCIONES_EN_PROCESO_V5', 'TRANSACCIONES_EN_PROCESO_MASIVO_V5', 'TRANSACCIONES_EN_PROCESO_PYME_V5') THEN
    RAISE USING MESSAGE = FORMAT('subproc_0113_v5: tabla no permitida [%s]', IFNULL(vtabla, 'NULL'));
  END IF;
  IF vdesde IS NULL THEN
    RAISE USING MESSAGE = 'subproc_0113_v5: vdesde NULL';
  END IF;

  SET VFQ_TABLA = CONCAT('`mm-commissions-reporting.KRT_SAP.', vtabla, '`');
  SET VMES_FACTURA_DT = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING)), MONTH);
  SET VMES = FORMAT("DATE '%t'", VMES_FACTURA_DT);

  SET VTIPOS = CASE
    WHEN vtipo IS NULL OR UPPER(TRIM(vtipo)) IN ('TODOS', 'TODAS', 'TOTAL') THEN ['CAPTACION', 'CARTERA']
    WHEN UPPER(TRIM(vtipo)) IN ('CAPTACION', 'CARTERA')                    THEN [UPPER(TRIM(vtipo))]
    WHEN CONTAINS_SUBSTR(vtipo, 'Total')                                   THEN ['CAPTACION', 'CARTERA']
    WHEN CONTAINS_SUBSTR(vtipo, 'Captacion')                               THEN ['CAPTACION']
    WHEN CONTAINS_SUBSTR(vtipo, 'Cartera')                                 THEN ['CARTERA']
    ELSE CAST([] AS ARRAY<STRING>)
  END;

  IF ARRAY_LENGTH(VTIPOS) = 0 THEN
    RAISE USING MESSAGE = FORMAT(
      'W0_VTIPO_NO_SOPORTADO: subproc_0113_v5 recibió vtipo [%s]; admitidos NULL, TODOS, TODAS, TOTAL, CAPTACION, CARTERA',
      IFNULL(vtipo, 'NULL'));
  END IF;

  SET VTIPOS_SQL = (SELECT STRING_AGG(FORMAT("'%s'", t), ', ') FROM UNNEST(VTIPOS) t);

  SET VSQL = """
  CREATE OR REPLACE TABLE @@TABLA@@ AS
  WITH src_numbered AS (
    SELECT
      e.*,
      ROW_NUMBER() OVER () AS __rid,
      IFNULL(e.mes_factura_dt = @@MES@@ AND e.tipo IN (@@TIPOS@@), FALSE) AS __en_ambito,
      CASE WHEN TRIM(IFNULL(e.segmento, '')) = '' THEN 'RESIDENCIAL' ELSE e.segmento END AS __seg_raw,
      UPPER(TRIM(CASE WHEN TRIM(IFNULL(e.segmento, '')) = '' THEN 'RESIDENCIAL' ELSE e.segmento END)) AS __seg_norm
    FROM @@TABLA@@ e
  ),
  p_ord AS (
    SELECT
      p.tipo                   AS p_tipo,
      UPPER(TRIM(p.marca))     AS p_marca,
      UPPER(TRIM(canal_split)) AS p_canal,
      UPPER(TRIM(srv_split))   AS p_service_type,
      UPPER(TRIM(seg_equiv))   AS p_segmento,
      UPPER(TRIM(marc_split))  AS p_marco,
      UPPER(TRIM(op_split))    AS p_operacion,
      orden_match              AS p_orden_match,
      p.orden                  AS p_orden_nueva
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ORDENxCANAL` p
    CROSS JOIN UNNEST(SPLIT(p.canal)) canal_split
    CROSS JOIN UNNEST(SPLIT(p.service_type)) srv_split
    CROSS JOIN UNNEST(SPLIT(p.segmento)) seg_split
    CROSS JOIN UNNEST(
      CASE UPPER(TRIM(seg_split))
        WHEN 'MASIVO'   THEN ['RESIDENCIAL', 'SOHO', 'PYME']
        WHEN 'BUSINESS' THEN ['BUSINESS', 'PYME P', 'PYME M', 'PYME - P', 'PYME - M']
        WHEN 'PYME P'   THEN ['BUSINESS', 'PYME P', 'PYME - P']
        WHEN 'PYME M'   THEN ['BUSINESS', 'PYME M', 'PYME - M']
        WHEN 'PYME - P' THEN ['BUSINESS', 'PYME P', 'PYME - P']
        WHEN 'PYME - M' THEN ['BUSINESS', 'PYME M', 'PYME - M']
        ELSE [UPPER(TRIM(seg_split))]
      END
    ) seg_equiv
    CROSS JOIN UNNEST(SPLIT(p.marco)) marc_split
    CROSS JOIN UNNEST(SPLIT(p.operacion)) op_split
    CROSS JOIN UNNEST([p.orden_previa, p.orden]) orden_match
    WHERE '@@NOMBRE_TABLA@@' = 'TRANSACCIONES_EN_PROCESO_V5'
      AND p.tipo IN (@@TIPOS@@)
      AND p.ESTADO = 'PUBLICAR'
      AND UPPER(TRIM(op_split)) IN UNNEST(CASE p.tipo WHEN 'CAPTACION' THEN ['ALTA','BAJA']
                                                      WHEN 'CARTERA'   THEN ['ALTA','BAJA','CAMBIO']
                                                      ELSE CAST([] AS ARRAY<STRING>) END)
  ),
  paso0 AS (
    SELECT
      s.* EXCEPT(__seg_raw, __seg_norm),
      s.__seg_norm,
      IF(s.__en_ambito AND NOT CONTAINS_SUBSTR(IFNULL(s.concepto_ds_gekt, ''), 'POSTVENTA'),
         COALESCE(p.p_orden_nueva, s.orden),
         s.orden) AS __orden_final,
      IF(s.__en_ambito AND NOT CONTAINS_SUBSTR(IFNULL(s.concepto_ds_gekt, ''), 'POSTVENTA') AND p.p_orden_nueva IS NOT NULL,
         s.__seg_raw,
         s.segmento) AS __segmento_final
    FROM src_numbered s
    LEFT JOIN p_ord p
      ON  s.__en_ambito
      AND NOT CONTAINS_SUBSTR(IFNULL(s.concepto_ds_gekt, ''), 'POSTVENTA')
      AND s.tipo = p.p_tipo
      AND UPPER(TRIM(s.marca)) = p.p_marca
      AND UPPER(TRIM(s.canal_gekt)) = p.p_canal
      AND UPPER(TRIM(s.service_type)) = p.p_service_type
      AND s.__seg_norm = p.p_segmento
      AND UPPER(TRIM(s.operation)) = p.p_operacion
      AND (p.p_marco = 'X' OR UPPER(TRIM(s.marco)) = p.p_marco)
      AND s.orden = p.p_orden_match
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY s.__rid
      ORDER BY CASE WHEN p.p_marco IS NOT NULL AND p.p_marco != 'X' THEN 1 ELSE 0 END DESC,
               p.p_orden_nueva ASC
    ) = 1
  ),
  g_dedup AS (
    SELECT UPPER(TRIM(tipo)) AS k_tipo, UPPER(TRIM(marca)) AS k_marca, orden AS k_orden, DETALLE
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
    WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
      ORDER BY CANAL, DETALLE
    ) = 1
  ),
  o_dedup AS (
    SELECT
      REPLACE(UPPER(TRIM(p.SOCIEDAD)), 'ET000', 'ET00') AS k_sociedad,
      UPPER(TRIM(p.MARCA))                              AS k_marca,
      p.ORDEN                                           AS k_orden,
      UPPER(TRIM(p.CONCEPTO))                           AS k_concepto,
      UPPER(TRIM(seg_equiv))                            AS k_segmento,
      UPPER(TRIM(p.TIPO))                               AS k_tipo_trad,
      TRIM(p.CODIGO)                                    AS CODIGO,
      CASE WHEN TRIM(seg_csv) = UPPER(TRIM(seg_equiv)) THEN 0 ELSE 1 END AS prioridad_seg
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` p
    CROSS JOIN UNNEST(SPLIT(UPPER(TRIM(p.SEGMENTO)), ',')) AS seg_csv
    CROSS JOIN UNNEST(
      CASE
        -- Regla 2: MASIVO -> RESIDENCIAL, SOHO, PYME
        WHEN TRIM(seg_csv) = 'MASIVO' THEN ['RESIDENCIAL', 'SOHO', 'PYME']
        -- Regla 3: PYME P / PYME M / BUSINESS <-> BUSINESS
        WHEN TRIM(seg_csv) IN ('PYME P', 'PYME - P') THEN ['BUSINESS', 'PYME P', 'PYME - P']
        WHEN TRIM(seg_csv) IN ('PYME M', 'PYME - M') THEN ['BUSINESS', 'PYME M', 'PYME - M']
        WHEN TRIM(seg_csv) = 'BUSINESS'              THEN ['BUSINESS', 'PYME P', 'PYME M', 'PYME - P', 'PYME - M']
        -- Corrección de consistencia con GRUPOSxCONCEPTOS y ORDENES:
        -- Si el concepto en CODIGO_SAP termina en 'NEGOCIOS' pero su columna SEGMENTO dice 'RESIDENCIAL',
        -- su ámbito real en GRUPOSxCONCEPTOS es 'SOHO,PYME'
        WHEN TRIM(seg_csv) = 'RESIDENCIAL' AND ENDS_WITH(UPPER(TRIM(p.CONCEPTO)), 'NEGOCIOS') THEN ['SOHO', 'PYME', 'RESIDENCIAL']
        ELSE [TRIM(seg_csv)]
      END
    ) AS seg_equiv
    WHERE p.CODIGO IS NOT NULL
      AND LENGTH(TRIM(p.CODIGO)) BETWEEN 1 AND 4
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY REPLACE(UPPER(TRIM(p.SOCIEDAD)), 'ET000', 'ET00'), UPPER(TRIM(p.MARCA)), p.ORDEN, UPPER(TRIM(p.CONCEPTO)), UPPER(TRIM(seg_equiv))
      ORDER BY prioridad_seg ASC, TRIM(p.CODIGO) ASC
    ) = 1
  ),
  od AS (
    SELECT
      o.k_sociedad, o.k_marca, o.k_orden, o.k_concepto, o.k_segmento, o.CODIGO, o.prioridad_seg,
      STARTS_WITH(CAST(o.k_orden AS STRING), '2') AS digito2,
      CASE
        WHEN LOWER(IFNULL(g.DETALLE, '')) LIKE '%plataforma cancelacion%' THEN 'Extracomision Plataforma Cancelacion '
        WHEN LOWER(IFNULL(g.DETALLE, '')) LIKE '%postventa%'              THEN 'Extracomision Postventa '
        WHEN LOWER(IFNULL(g.DETALLE, '')) LIKE '%gestion%'                THEN 'Extracomision Gestion '
      END AS mid_capt
    FROM o_dedup o
    LEFT JOIN g_dedup g
      ON g.k_tipo  = o.k_tipo_trad
     AND g.k_marca = o.k_marca
     AND g.k_orden = o.k_orden
  )
  SELECT
    s.* EXCEPT(__rid, __en_ambito, __seg_norm, __orden_final, __segmento_final)
    REPLACE (
      s.__orden_final AS orden,
      s.__segmento_final AS segmento,
      IF(s.__en_ambito, IFNULL(od.CODIGO, s.tipo_concepto), s.tipo_concepto) AS tipo_concepto
    )
  FROM paso0 s
  LEFT JOIN od
    ON  s.__en_ambito
    AND od.k_sociedad = REPLACE(UPPER(TRIM(s.sociedad)), 'ET000', 'ET00')
    AND od.k_marca    = UPPER(TRIM(s.marca))
    AND od.k_orden    = s.__orden_final
    AND od.k_segmento = s.__seg_norm
    AND od.k_concepto = UPPER(TRIM(CASE
          WHEN s.tipo = 'CAPTACION' AND od.mid_capt IS NOT NULL AND STARTS_WITH(s.clase_concepto, 'D - ')
            THEN REGEXP_REPLACE(s.clase_concepto, '^D - .*?Capt[.] ', CONCAT('D - ', od.mid_capt, 'Capt. '))
          WHEN s.tipo = 'CARTERA' AND od.digito2 AND STARTS_WITH(s.clase_concepto, 'D - Extracomision ')
               AND NOT CONTAINS_SUBSTR(s.concepto, 'Plataforma Pad')
            THEN REGEXP_REPLACE(s.clase_concepto, '^D - Extracomision (?:Altas|Terminales) ',
                   IF(COALESCE(s.categoria_servicio_ds, 'NODEF') IN ('DISPOSITIVOS', 'TERMINALES', 'CPE'),
                      'D - Extracomision Terminales ', 'D - Extracomision Altas '))
          ELSE s.clase_concepto
        END))
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY s.__rid
    ORDER BY od.prioridad_seg ASC, od.CODIGO ASC
  ) = 1
  """;

  EXECUTE IMMEDIATE REPLACE(REPLACE(REPLACE(REPLACE(VSQL, '@@TABLA@@', VFQ_TABLA), '@@NOMBRE_TABLA@@', vtabla), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL);

  --- AVISOS (no bloqueantes)
  EXECUTE IMMEDIATE REPLACE(REPLACE(REPLACE("""
  SELECT 'W1_SIN_CODIGO' AS aviso, tipo, clase, sociedad, marca, segmento, orden, clase_concepto,
         COUNT(*) AS filas, ROUND(SUM(IFNULL(comision, 0)), 2) AS importe
  FROM @@TABLA@@
  WHERE tipo_concepto IS NULL AND mes_factura_dt = @@MES@@ AND tipo IN (@@TIPOS@@)
  GROUP BY ALL
  ORDER BY importe DESC
  LIMIT 50
  """, '@@TABLA@@', VFQ_TABLA), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL);

  EXECUTE IMMEDIATE REPLACE(REPLACE(REPLACE("""
  SELECT 'W2_SIN_ACREEDOR' AS aviso, tipo, marca, distribuidor_gekt,
         COUNT(*) AS filas, ROUND(SUM(IFNULL(comision, 0)), 2) AS importe
  FROM @@TABLA@@ e
  WHERE e.tipo_concepto IS NOT NULL AND e.mes_factura_dt = @@MES@@ AND e.tipo IN (@@TIPOS@@)
    AND NOT EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_SAP.PARAM_CRM_DISTRIBUIDORES` d
      JOIN `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` a
        ON a.SOCIEDAD = d.SOCIEDAD AND UPPER(TRIM(a.CIF)) = UPPER(TRIM(d.CIF)) AND a.BP = d.BP AND a.marca = d.marca
      WHERE d.marca = e.marca AND UPPER(TRIM(d.nombre_distribuidor)) = UPPER(TRIM(e.distribuidor_gekt))
    )
  GROUP BY ALL
  ORDER BY importe DESC
  LIMIT 50
  """, '@@TABLA@@', VFQ_TABLA), '@@MES@@', VMES), '@@TIPOS@@', VTIPOS_SQL);
END