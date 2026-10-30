BEGIN
  DECLARE VCRM STRING DEFAULT 'MYSIM';
  DECLARE VMES_FACTURA_DT DATE;
  DECLARE VHOY_ID INT64;

  SET VMES_FACTURA_DT = PARSE_DATE('%Y%m', CAST(vmes_id AS STRING));
  SET VHOY_ID = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE('Europe/Madrid')) AS INT64);

  --- PASO 1: ELIMINO Y RECREO TABLA INTERMEDIA
  DROP TABLE IF EXISTS `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_MASIVO_V5`;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_MASIVO_V5` AS
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5` WHERE 1 = 0;

  --- PASO 2: INSERTO REGISTROS EN TABLA INTERMEDIA
  INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_MASIVO_V5` (
    commission_id, estado, mes_factura_dt,id_mes,mes_liquidado, agrupacion_canal, concepto, tipo_concepto,
    comision, distribuidor, sfid_id, seller, marca, service_type, phone_nm, tariff_id,
    tariff_ds, service_id, customer_id, sale_date, activation_date, deactivation_date,
    order_type_agg, cod_segmento, cod_marca, id_registro, invoice_id, sociedad, bp,id_comisionista,
    segmento, orden, clase_concepto, concepto_ds_gekt, operation, canal_gekt,
    subcanal_gekt, marco, distribuidor_gekt, clase, tipo, data_source_ds
  )
  WITH g_dedup AS (
    SELECT UPPER(TRIM(tipo)) AS tipo_norm, UPPER(TRIM(marca)) AS marca_norm, orden, DETALLE
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
    WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden ORDER BY CANAL, DETALLE) = 1
  )
  SELECT DISTINCT
    h.commission_id,
    'calculado',
    h.mes_factura_dt,
    CAST(FORMAT_DATE('%Y%m',h.mes_factura_dt) as INT64),
    CASE WHEN UPPER(TRIM(h.tipo))="COMISION" then `mm-commissions-reporting.KRT_MIG_PWC.f_trans_crea_mes_liquidado`(h.mes_factura_dt, EXTRACT(DATE FROM h.activation_date))
         WHEN UPPER(TRIM(h.tipo))="DECOMISION" then `mm-commissions-reporting.KRT_MIG_PWC.f_trans_crea_mes_liquidado`(h.mes_factura_dt, h.deactivation_date)
    END,
    'PENDIENTE',
    h.concepto,
    CAST(NULL AS STRING),
    h.importe,
    h.distribuidor,
    h.sfid_id,
    h.seller,
    h.brand_ds,
    h.service_type,
    h.phone_nm,
    h.tariff_id,
    h.tariff_ds,
    h.service_id,
    h.customer_id,
    EXTRACT(DATE FROM h.sale_date),
    EXTRACT(DATE FROM h.activation_date),
    h.deactivation_date,
    h.order_type_agg,
    CAST(NULL AS STRING),
    CAST(NULL AS STRING),
    h.id_registro,
    h.invoice_id,
    `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(UPPER(TRIM(h.brand_ds))),
    LPAD(CAST(ac.bp AS STRING), 5, '0'),
    LPAD(CAST(ac.bp AS STRING), 5, '0'),    
    COALESCE(NULLIF(UPPER(TRIM(h.segment_ds)), ''), 'RESIDENCIAL'),
    h.orden,
    `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
      h.tipo,
      `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(h.tariff_ds, CAST(NULL AS STRING), h.concepto, h.concepto_marco),
      `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(h.orden),
      COALESCE(NULLIF(UPPER(TRIM(h.segment_ds)), ''), 'RESIDENCIAL'),
      h.concepto,
      IF(h.tipo = 'CARTERA', CAST(NULL AS STRING), ''),
      g.DETALLE
    ),
    h.concepto_marco,
    h.operacion,
    h.channel_ds,
    h.subchannel_ds,
    h.marco,
    h.distribuidor,
    h.clase,
    h.tipo,
    h.data_source_ds
  FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` h
  LEFT JOIN `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES` ac
    ON ac.marca = h.brand_ds
   AND ac.nombre_acreedor = h.distribuidor
  LEFT JOIN g_dedup g
    ON g.tipo_norm  = UPPER(TRIM(h.tipo))
   AND g.marca_norm = UPPER(TRIM(h.brand_ds))
   AND g.orden      = h.orden
  WHERE h.mes_factura_dt = VMES_FACTURA_DT
    AND h.comisiona = 1;

  --- PASO 3: RESUELVO CODIGO SAP [V5]
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0113_ResolverCodigoSapv5_opt`('TRANSACCIONES_EN_PROCESO_MASIVO_V5', vmes_id * 100 + 1, 'TOTAL');

  --- PASO 4: ACTUALIZO TABLA TRANSACCIONES_V5
  DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5` t
  WHERE t.mes_factura_dt = VMES_FACTURA_DT
    AND t.data_source_ds = VCRM
    AND NOT EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_PUBLICACION` p
      WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
        AND UPPER(TRIM(p.tipo))     = UPPER(TRIM(t.tipo))
        AND p.mes_comision_id       = vmes_id
        AND p.fecha_id IS NOT NULL
        AND p.fecha_id < VHOY_ID
    );

  INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5`
  SELECT e.*
  FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_MASIVO_V5` e
  WHERE NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_PUBLICACION` p
    WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
      AND UPPER(TRIM(p.tipo))     = UPPER(TRIM(e.tipo))
      AND p.mes_comision_id       = vmes_id
      AND p.fecha_id IS NOT NULL
      AND p.fecha_id < VHOY_ID
  );
END