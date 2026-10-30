BEGIN

  DECLARE prefijo STRING;
  DECLARE mes_string STRING;

  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo = 'ACTI_';

  SET canales_pr = COALESCE(
    canales_pr,
    (
      SELECT ARRAY_AGG(canal)
      FROM `mm-commissions-reporting.GS.CANALES`
      WHERE plantilla_activaciones IN ('Sin tramos', 'Con tramos')
    )
  );

  /*
  call  COMISIONES.pr_acti_cross_sell_OUT (202601, ['XS']);
  */


  /* ================================
     ACTIVACIONES KPI
     ================================ */

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activationes_kpi_tlv_cross_sell_OUT`
  OPTIONS (
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
  )
  AS
  SELECT *
  FROM `mm-commissions-reporting.COMISIONES.activaciones` a
  CROSS JOIN UNNEST(canales_pr) AS canal_pr
  WHERE a.canal = canal_pr;

  /* ================================
     ACTUALIZAR TARIFAS EN MAESTRO
     ================================ */

  INSERT INTO COMISIONES.tarifas_cross_sell_OUT
  SELECT DISTINCT
    a.canal,
    a.id_mes,
    a.campaign_code,
    a.marca,
    a.service_type,
    a.tariff_id,
    a.tariff_ds,
    CASE
      WHEN a.service_type = 'MOBILE' THEN a.line_type_ds
      ELSE CAST(NULL AS STRING)
    END AS line_type_ds,
    CASE
      WHEN a.service_type = 'MOBILE' THEN a.bundle_type
      ELSE CAST(NULL AS STRING)
    END AS bundle_type,
    COALESCE(b.comision, CAST(NULL AS FLOAT64)) AS comision,
    b.portabilidad,
    'ACTI',
    CURRENT_TIMESTAMP()
  FROM `mm-commissions-reporting.COMISIONES.activaciones` a
  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas_cross_sell_OUT` b
    ON a.marca = b.marca
   AND a.service_type = b.service_type
   AND a.tariff_id = b.tariff_id
   AND a.tariff_ds = b.tariff_ds
   AND a.id_mes = b.id_mes
   AND a.canal = b.canal
   AND a.campaign_code = b.campaign_code
   AND (a.service_type = 'INTERNET' OR a.bundle_type = b.bundle_type)
   AND (a.service_type = 'INTERNET' OR a.line_type_ds = b.line_type_ds)
  CROSS JOIN UNNEST(canales_pr) AS canal_pr
  WHERE a.canal = canal_pr
    AND b.canal IS NULL
    AND a.service_type IN ('MOBILE', 'INTERNET')
    AND a.id_mes = id_mes_pr;

  /* ================================
     CONCEPTOS
     ================================ */

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_conceptos_cross_sell_OUT`
  OPTIONS (
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
  )
  AS
  WITH tarifas_tramos AS (
    SELECT
      canal,
      marca,
      campaign_code,
      service_type,
      tariff_id,
      tariff_ds,
      line_type_ds,
      bundle_type,
      comision,
      portabilidad
    FROM `mm-commissions-reporting.COMISIONES.v_tarifas_cross_sell_OUT`
    WHERE id_mes = id_mes_pr
  ),
  marco AS (

    -- SERVICIO FIJO
    SELECT
      canal,
      marca,
      campaign_code,
      service_type,
      tariff_id,
      tariff_ds,
      line_type_ds,
      CAST(NULL AS STRING) AS bundle_type,
      'A - Servicio Fijo' AS concepto,
      'UPFR' AS tipo_concepto,
      comision
    FROM tarifas_tramos a
    CROSS JOIN UNNEST(canales_pr) canal_pr
    WHERE canal = canal_pr
      AND service_type = 'INTERNET'
      AND a.comision IS NOT NULL

    UNION ALL

    -- SERVICIO MOVIL
    SELECT
      canal,
      marca,
      campaign_code,
      service_type,
      tariff_id,
      tariff_ds,
      line_type_ds,
      bundle_type,
      'A - Servicio Movil Pospago' AS concepto,
      'UPFR' AS tipo_concepto,
      comision
    FROM tarifas_tramos a
    CROSS JOIN UNNEST(canales_pr) canal_pr
    WHERE canal = canal_pr
      AND service_type = 'MOBILE'
      AND COALESCE(line_type_ds, 'a') != 'MULTISIM'
      AND a.comision IS NOT NULL

    UNION ALL

    -- PORTABILIDAD
    SELECT
      canal,
      marca,
      campaign_code,
      service_type,
      tariff_id,
      tariff_ds,
      line_type_ds,
      bundle_type,
      CASE
        WHEN service_type = 'MOBILE'
          THEN 'A - Portabilidad Movil Pospago'
        ELSE 'A - Portabilidad Fijo'
      END AS concepto,
      'UPFR' AS tipo_concepto,
      portabilidad AS comision
    FROM tarifas_tramos a
    CROSS JOIN UNNEST(canales_pr) canal_pr
    WHERE canal = canal_pr
      AND a.portabilidad IS NOT NULL
  )

  SELECT *
  FROM marco
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
      canal,
      marca,
      campaign_code,
      service_type,
      tariff_id,
      tariff_ds,
      line_type_ds,
      concepto,
      bundle_type
  ) = 1;

  /* ================================
     COMISIONES
     ================================ */

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_tlv_cross_sell_OUT`
  OPTIONS (
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
  )
  AS
  SELECT
    prefijo || '_' || mes_string || '_' || b.canal || '_' || ROW_NUMBER() OVER () AS commission_id,
    'calculado' AS estado,
    id_mes_pr AS id_mes,
    b.agrupacion_canal,
    b.canal,
    CASE
      WHEN b.billing_type_ds = 'PREPAID'
        THEN REPLACE(concepto, 'Pospago', 'Prepago')
      ELSE concepto
    END AS concepto,
    tipo_concepto,
    1 AS unidades,
    comision,
    b.id_comisionista,
    COALESCE(distribuidor, b.id_comisionista) AS distribuidor,
    sfid_id,
    seller,
    b.nombre_comercio,
    b.razon_social,
    b.cif,
    b.zona_fiscal,
    b.marca,
    b.service_type,
    phone_nm,
    b.tariff_id,
    b.tariff_ds,
    b.service_id,
    account_id,
    customer_id,
    a.line_type_ds,
    b.bundle_type,
    technology_ds,
    billing_type_ds,
    sale_date,
    activation_date,
    deactivation_date,
    b.order_id,
    order_type_agg,
    cod_segmento,
    cod_marca,
    cod_tipo_contrato,
    cod_producto,
    COALESCE(d.cod_canal, b.cod_canal) AS cod_canal,
    b.campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    comments,
    'C_MANUAL' AS facturador
  FROM `mm-commissions-reporting.TEMP.acti_conceptos_cross_sell_OUT` a
  INNER JOIN `mm-commissions-reporting.TEMP.activationes_kpi_tlv_cross_sell_OUT` b
    ON b.canal = a.canal
   AND a.marca = b.marca
   AND a.service_type = b.service_type
   AND a.tariff_id = b.tariff_id
   AND a.tariff_ds = b.tariff_ds
   AND a.campaign_code = b.campaign_code
  INNER JOIN `mm-commissions-reporting.GS.CANALES` d
    ON a.canal = d.canal
  LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
    ON b.id_comisionista = tlv_cross_sell.id_comisionista
   AND b.canal = tlv_cross_sell.canal
  CROSS JOIN UNNEST(canales_pr) AS canal_pr
  WHERE b.canal = canal_pr
    AND b.id_mes = id_mes_pr
    AND b.comisionamiento = 'Comisiona'
    AND (
      CASE
        WHEN a.service_type = 'MOBILE' THEN a.line_type_ds
        ELSE 'FIX'
      END
    ) = (
      CASE
        WHEN b.service_type = 'MOBILE' THEN b.line_type_ds
        ELSE 'FIX'
      END
    )
    AND b.order_type_agg IN ('ALTA NUEVA', 'PORTABILIDAD')
    AND b.cif IS NOT NULL;

  ASSERT NOT EXISTS (
    SELECT *
    FROM `mm-commissions-reporting.TEMP.acti_comisiones_tlv_cross_sell_OUT`
    QUALIFY COUNT(*) OVER (
      PARTITION BY phone_nm, service_id, marca, service_type, concepto
    ) > 1
  );

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_tlv_cross_sell_OUT_final`
  OPTIONS (
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
  )
  AS
  SELECT *
  FROM `mm-commissions-reporting.TEMP.acti_comisiones_tlv_cross_sell_OUT`
  WHERE comision IS NOT NULL
    AND (comision != 0
    );


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.acti_comisiones_tlv_cross_sell_OUT_final'  , 'ACTUALIZAR');

END