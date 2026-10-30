BEGIN

DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'TTRAM';

IF canales_pr IS NULL THEN 
  SET canales_pr = ['XI', 'XO', 'XOF','WA'];
END IF;

/*
CALL COMISIONES.pr_traslados_tramos (202602,['XI']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activaciones_traslados_tramos` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS
(
  SELECT * 
  FROM `mm-commissions-reporting.COMISIONES.activaciones` a
  CROSS JOIN UNNEST(canales_pr) AS canal_pr
  WHERE a.canal = canal_pr
  AND a.order_type_agg = 'CAMBIO DOMICILIO'
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.traslados_tramos`
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS (
  WITH
  tramos_migraciones AS (
    SELECT
      canal,
      marca,
      service_type,
      tariff_id,
      tariff_ds,
      tramo,
      comision
    FROM `mm-commissions-reporting.COMISIONES.v_tarifas_tramos_migraciones`
    UNPIVOT (comision FOR tramo IN (tramo_1, tramo_2, tramo_3, tramo_4, tramo_5))
  ),
  marco_migraciones AS (
    SELECT
      b.canal,
      a.marca,
      a.service_type,
      CAST(NULL AS STRING) AS campaign_code,
      tariff_id,
      tariff_ds,
      CAST(NULL AS STRING) AS line_type_ds,
      id_comisionista,
      'A - Servicio Fijo Cambio de Domicilio' AS concepto,
      'UPFR' AS tipo_concepto,
      comision
    FROM tramos_migraciones a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b 
      ON a.marca = b.marca 
     AND b.canal =a.canal
     AND b.mes = mes_string
    WHERE a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.service_type IN ('INTERNET')
  )

  SELECT *
  FROM marco_migraciones
  QUALIFY ROW_NUMBER() OVER (PARTITION BY canal, marca, service_type, tariff_id, tariff_ds, line_type_ds, concepto, id_comisionista, campaign_code) = 1
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.traslados_tramos_comisiones` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS (
  SELECT
    --- primary key ---
    prefijo || '_' || mes_string || '_' || b.canal || '_' || ROW_NUMBER() OVER () AS commission_id,
    --- comision ---
    'calculado' AS estado,
    id_mes_pr AS id_mes,
    b.agrupacion_canal,
    b.canal,
    CASE 
      WHEN b.billing_type_ds = 'PREPAID' THEN REPLACE(concepto, 'Pospago', 'Prepago') 
      ELSE concepto 
    END AS concepto,
    tipo_concepto,
    1 AS unidades,

    ---- Comision ----
    comision,

    --- vendedor ---
    b.id_comisionista,
    distribuidor,
    sfid_id,
    seller,
    nombre_comercio,
    razon_social,
    cif,
    zona_fiscal,

    --- servicio ---
    b.marca,
    b.service_type,
    phone_nm,
    b.tariff_id,
    b.tariff_ds,
    b.service_id,
    account_id,
    customer_id,
    a.line_type_ds,
    bundle_type,
    technology_ds,
    billing_type_ds,
    sale_date,
    activation_date,
    deactivation_date,
    COALESCE(b.sfid_digo, order_id) AS order_id,
    order_type_agg,

    --- variables analiticas ---
    cod_segmento,
    cod_marca,
    cod_tipo_contrato,
    cod_producto,
    COALESCE(d.cod_canal, b.cod_canal) AS cod_canal,

    --- informacion adicional ---
    b.campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    comments,

    --- informacion contabilizacion ---
    'C_MANUAL' AS facturador

  FROM (
    SELECT * FROM `mm-commissions-reporting.TEMP.traslados_tramos`
  ) a
  INNER JOIN `mm-commissions-reporting.TEMP.activaciones_traslados_tramos` b
    ON a.canal = b.canal 
   AND a.marca = b.marca 
   AND a.service_type = b.service_type 
   AND a.tariff_id = b.tariff_id
   AND a.tariff_ds = b.tariff_ds
   AND a.id_comisionista = b.id_comisionista

  INNER JOIN `mm-commissions-reporting.GS.CANALES` d 
    ON a.canal = d.canal

  CROSS JOIN UNNEST(canales_pr) AS canal_pr

  WHERE 1 = 1
    AND b.canal = canal_pr
    AND b.id_mes = id_mes_pr
    AND b.comisionamiento = 'Comisiona'
    AND CASE WHEN a.service_type = 'MOBILE' THEN a.line_type_ds ELSE 'FIX' END 
        = CASE WHEN b.service_type = 'MOBILE' THEN b.line_type_ds ELSE 'FIX' END

    AND CASE
          WHEN concepto = 'A - Servicio Fijo Cambio de Domicilio' THEN 'CAMBIO DOMICILIO'
          WHEN concepto = 'A - Servicio Fijo Cambio de Tecnologia' THEN 'CAMBIO TECNOLOGIA'
          WHEN concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago', 'B - Multisim', 'F - Servicio Fijo', 
                            'F - Servicio Movil Pospago', 'F - Multisim', 'G - Servicio Fijo', 'G - Servicio Movil Pospago') 
               AND b.order_type_agg IN ('ALTA NUEVA', 'PORTABILIDAD', 'STC', 'MULTISIM') 
               THEN b.order_type_agg
        END = b.order_type_agg

    AND b.order_type_agg IN ('CAMBIO DOMICILIO', 'CAMBIO TECNOLOGIA')
    AND b.cif IS NOT NULL
);

ASSERT NOT EXISTS (
  SELECT *
  FROM `mm-commissions-reporting.TEMP.traslados_tramos_comisiones`
  QUALIFY COUNT(*) OVER (PARTITION BY phone_nm, service_id, marca, service_type, concepto) > 1
); -- Hay duplicados!

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.traslados_tramos_comisiones_final` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS 
SELECT *
FROM `mm-commissions-reporting.TEMP.traslados_tramos_comisiones`
WHERE comision IS NOT NULL
  AND comision != 0;

--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.traslados_tramos_comisiones_final', 'ACTUALIZAR');
call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base_prueba`(false);
END