BEGIN

    --DECLARE VDESDE INT64 DEFAULT 20261001;DECLARE VTIPO STRING DEFAULT 'CAPTACION';
    UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` e
    SET tipo_concepto = k.CODIGO
    FROM (
      SELECT CODIGO, k_concepto, k_sociedad, k_marca, k_tipo, k_orden, k_segmento
      FROM (
        SELECT
          p.CODIGO,
          UPPER(TRIM(p.TIPO)) AS k_tipo,          
          UPPER(TRIM(p.CONCEPTO)) AS k_concepto,
          UPPER(TRIM(p.SOCIEDAD)) AS k_sociedad,
          UPPER(TRIM(p.MARCA))    AS k_marca,
          p.ORDEN                 AS k_orden,
          seg                     AS k_segmento,
          ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(p.CONCEPTO)), UPPER(TRIM(p.SOCIEDAD)),
                         UPPER(TRIM(p.MARCA)), p.ORDEN, seg
            ORDER BY
              -- Explicit token wins over MASIVO / PYME M / PYME P expansion
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
      AND k.k_segmento = COALESCE(NULLIF(UPPER(TRIM(e.segmento)), ''), 'RESIDENCIAL')
      AND k.CODIGO != COALESCE(e.tipo_concepto, 'NODEFINIDO')
      AND e.mes_factura_dt=PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING))
      AND CASE WHEN VTIPO="TOTAL" THEN TRUE ELSE UPPER(e.tipo)=UPPER(k.k_tipo) END;

END