BEGIN

  --CALL `mm-commissions-reporting.KRT_MASIVO.pr_fl_actualiza_tabla_transacciones_opt`(202610);

  DECLARE VCRM, VSEGMENTO_DS STRING;
  DECLARE VMES_FACTURA_DT DATE;
  DECLARE VHOY_ID INT64;

  SET VMES_FACTURA_DT = PARSE_DATE('%Y%m', CAST(VMES_ID AS STRING));
  SET VCRM            = "MYSIM";
  SET VSEGMENTO_DS    = "RESIDENCIAL";
  SET VHOY_ID         = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE()) AS INT64);


  --- PASO 1: CREO TABLA INTERMEDIA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO` AS
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` WHERE 1=0;


  --- PASO 2: INSERTO REGISTROS EN TABLA INTERMEDIA
  INSERT `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO`
  (
    commission_id,
    estado,
    mes_factura_dt,
    agrupacion_canal,
    concepto,
    tipo_concepto,       -- [1] will be resolved in PASO 3
    comision,
    distribuidor,
    sfid_id,
    seller,
    marca,
    service_type,
    phone_nm,
    tariff_id,
    tariff_ds,
    service_id,
    customer_id,
    sale_date,
    activation_date,
    deactivation_date,
    order_type_agg,
    cod_segmento,
    cod_marca,
    id_registro,
    invoice_id,
    sociedad,
    bp,
    segmento,
    orden,
    clase_concepto,      -- [2] generator output for Translator lookup
    concepto_ds_gekt,
    operation,
    canal_gekt,
    subcanal_gekt,
    marco,
    distribuidor_gekt,
    clase,
    tipo,
    data_source_ds
  )

  SELECT DISTINCT
    commission_id,
    'calculado',
    mes_factura_dt,
    "PENDIENTE",
    concepto,
    CAST(NULL AS STRING),   -- [1] tipo_concepto = NULL; resolved to CODIGO in PASO 3
    importe,
    distribuidor,
    sfid_id,
    seller,
    brand_ds,
    service_type,
    phone_nm,
    tariff_id,
    tariff_ds,
    service_id,
    customer_id,
    EXTRACT(DATE FROM sale_date),
    EXTRACT(DATE FROM activation_date),
    deactivation_date,
    order_type_agg,
    CAST(NULL AS STRING),
    CAST(NULL AS STRING),
    id_registro,
    invoice_id,
    `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(UPPER(TRIM(brand_ds))),
    LPAD(CAST(ac.bp AS STRING), 5, '0'),
    COALESCE(IFNULL(segment_ds, ''), 'RESIDENCIAL'),
    h.orden,
    -- [2] clase_concepto ← generator output (SAP description; Translator CONCEPTO match key)
    `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
      h.tipo,
      LEFT(h.concepto, 1),
      `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(h.orden),
      VSEGMENTO_DS,
      concepto,
      service_type,
      g.DETALLE
    ),
    concepto_marco,
    operacion,
    channel_ds,
    subchannel_ds,
    marco,
    distribuidor,
    clase,
    h.tipo,
    data_source_ds

  FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` h
  LEFT JOIN `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac
    ON  ac.marca          = h.brand_ds
    AND ac.nombre_acreedor = h.distribuidor
  LEFT JOIN (
    -- [3] g-join: ESTADO priority (ACTIVO > PUBLICADA > INACTIVO), then CANAL, DETALLE
    SELECT tipo, marca, orden, CANAL, DETALLE,
      ROW_NUMBER() OVER (
        PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
        ORDER BY
          CASE ESTADO WHEN 'ACTIVO' THEN 1 WHEN 'PUBLICADA' THEN 2 ELSE 3 END,
          CANAL,
          DETALLE
      ) AS rn
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
    WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
  ) g
    ON  UPPER(TRIM(g.tipo))  = h.tipo
    AND UPPER(TRIM(g.MARCA)) = UPPER(TRIM(h.brand_ds))
    AND g.ORDEN              = h.orden
    AND g.rn                 = 1

  WHERE mes_factura_dt = VMES_FACTURA_DT
    AND comisiona      = 1;


  --- PASO 3: RESUELVO CODIGO SAP  [NEW — fix_07_01]
  -- Lookup del CODIGO de 4 caracteres en PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP.
  -- Segment expansion: MASIVO→{RESIDENCIAL,SOHO,PYME}; PYME M / PYME P→BUSINESS.
  -- SEGMENTO field may be a comma-separated list: each token is exploded independently.
  -- Explicit token wins over an expanded one (ORDER BY priority).
  -- Unmatched rows (Class A2/C) stay NULL — never force-assigned. [INVARIANT-VOCAB]
  UPDATE `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO` e
  SET tipo_concepto = k.CODIGO
  FROM (
    SELECT CODIGO, k_concepto, k_sociedad, k_marca, k_orden, k_segmento
    FROM (
      SELECT
        p.CODIGO,
        UPPER(TRIM(p.CONCEPTO)) AS k_concepto,
        UPPER(TRIM(p.SOCIEDAD)) AS k_sociedad,
        UPPER(TRIM(p.MARCA))    AS k_marca,
        p.ORDEN                 AS k_orden,
        seg                     AS k_segmento,
        ROW_NUMBER() OVER (
          PARTITION BY UPPER(TRIM(p.CONCEPTO)), UPPER(TRIM(p.SOCIEDAD)),
                       UPPER(TRIM(p.MARCA)), p.ORDEN, seg
          ORDER BY
            -- Explicit token wins over expanded MASIVO / PYME M / PYME P
            IF(REGEXP_REPLACE(UPPER(TRIM(s_raw)), r'[\s\-]+', ' ')
                 IN ('MASIVO', 'PYME M', 'PYME P'), 1, 0),
            p.CODIGO
        ) AS rn
      FROM `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` p
      CROSS JOIN UNNEST(SPLIT(p.SEGMENTO, ',')) AS s_raw
      CROSS JOIN UNNEST(
        CASE REGEXP_REPLACE(UPPER(TRIM(s_raw)), r'[\s\-]+', ' ')
          WHEN 'MASIVO'  THEN ['RESIDENCIAL', 'SOHO', 'PYME']
          WHEN 'PYME M'  THEN ['BUSINESS']
          WHEN 'PYME P'  THEN ['BUSINESS']
          ELSE [REGEXP_REPLACE(UPPER(TRIM(s_raw)), r'[\s\-]+', ' ')]
        END
      ) AS seg
      WHERE NULLIF(TRIM(s_raw), '') IS NOT NULL
        AND LENGTH(TRIM(p.CODIGO)) = 4
    )
    WHERE rn = 1
  ) k
  WHERE k.k_concepto = UPPER(TRIM(e.clase_concepto))
    AND k.k_sociedad = UPPER(TRIM(e.sociedad))
    AND k.k_marca    = UPPER(TRIM(e.marca))
    AND k.k_orden    = e.orden
    AND k.k_segmento = COALESCE(NULLIF(UPPER(TRIM(e.segmento)), ''), 'RESIDENCIAL');


  --- PASO 4: ACTUALIZO TABLA TRANSACCIONES
  DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
  WHERE t.mes_factura_dt = VMES_FACTURA_DT
    AND t.data_source_ds = VCRM
    AND NOT EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_PUBLICACION` p
      WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
        AND UPPER(TRIM(p.tipo))     = UPPER(TRIM(t.tipo))
        AND p.mes_comision_id       = VMES_ID
        AND p.fecha_id IS NOT NULL
        AND p.fecha_id              < VHOY_ID
    );

  INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
  SELECT e.*
  FROM `mm-commissions-reporting.KRT_MASIVO.TRANSACCIONES_EN_PROCESO` e
  WHERE NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_PUBLICACION` p
    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
      AND UPPER(TRIM(p.tipo))     = UPPER(TRIM(e.tipo))
      AND p.mes_comision_id       = VMES_ID
      AND p.fecha_id IS NOT NULL
      AND p.fecha_id              < VHOY_ID
  );

END