BEGIN
--Procedimiento que sube las reclamaciones a transacciones que tengan muchas lineas

-- call `mm-commissions-reporting.COMISIONES.pr_sub_transacciones_B2B`(['MB']);

DECLARE sql, prefijo, mes_string STRING;


SET mes_string = CAST(202504 AS STRING);

SET prefijo = 'ARM6'; 

SET canales_pr = ['MB'];

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tabla_sub_tr_BQ` AS

WITH 
  consulta_1 AS (
    SELECT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
      CAST(mes_string AS INT64) as id_mes, 
      agrupacion_canal,
      canal,
      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(concepto,'C - ','Z - '),'D - ','Z - '),'E - ','Z - '),'A - ','Z - '),'R - ','Z - ') AS concepto,
      tipo_concepto,
      1 AS unidades,
      comision*-1 AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social, 
      cif,
      zona_fiscal,
      cond_pago,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_canal,
      cod_producto,
      '202503'                 AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM  `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE 1=1
      AND canal = 'MB'
      AND estado = 'facturado'
      AND id_mes = 202503
      AND id_comisionista = 'C09-00205' 
      AND (concepto LIKE 'C -%' OR concepto LIKE 'D -%' OR concepto LIKE 'A -%')
      --AND (concepto = 'C - Gestion Cartera Movil (40%)' OR concepto = 'D - Camp. Cable ID: 2860')
  ),
  
  -- consulta_2 AS (

  --   SELECT
  --     'calculado' as estado,
  --     DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  --     CAST(mes_string AS INT64) as id_mes, 
  --     agrupacion_canal,
  --     canal,
  --     REPLACE(REPLACE(REPLACE(REPLACE(REPLACE('C - Gestion Cartera Movil (45%)','C - ','Z - '),'D - ','Z - '),'E - ','Z - '),'A - ','Z - '),'R - ','Z - ') AS concepto,
  --     tipo_concepto,
  --     1 AS unidades,
  --     CASE
  --       WHEN CAST(REGEXP_EXTRACT(concepto, r'\(([\d.]+)%\)') AS FLOAT64) IS NULL THEN comision
  --       WHEN CAST(REGEXP_EXTRACT(concepto, r'\(([\d.]+)%\)') AS FLOAT64) > 0 THEN comision/(CAST(REGEXP_EXTRACT(concepto, r'\(([\d.]+)%\)') AS FLOAT64)/100) * 0.45
  --       END AS comision,
  --     id_comisionista,
  --     distribuidor,
  --     sfid_id,
  --     seller,
  --     nombre_comercio,
  --     razon_social, 
  --     cif,
  --     zona_fiscal,
  --     cond_pago,
  --     marca,
  --     service_type,
  --     phone_nm,
  --     tariff_id,
  --     tariff_ds,
  --     service_id,
  --     account_id,
  --     customer_id,
  --     line_type_ds,
  --     bundle_type,
  --     technology_ds,
  --     billing_type_ds,
  --     sale_date,
  --     activation_date,
  --     deactivation_date,
  --     order_id,
  --     order_type_agg,
  --     cod_segmento,
  --     cod_marca,
  --     cod_tipo_contrato,
  --     cod_canal,
  --     cod_producto,
  --     '202503'                 AS campaign_code,
  --     CAST(NULL AS STRING)     AS serial_number,
  --     tax_base,
  --     CAST(NULL AS STRING)     AS claim_code,
  --     CAST(NULL AS STRING)     AS process_code,
  --     comments,
  --     'C_MANUAL'               AS facturador,
  --     CAST(NULL AS STRING)     AS proceso_sap,
  --     CAST(NULL AS STRING)     AS id_registro,
  --     CAST(NULL AS STRING)     AS invoice_id,
  --     'X001'                   AS sociedad,
  --     CAST(NULL AS STRING)     AS bp,
  --     CAST(NULL AS STRING)     AS cuenta_contable,
  --     CAST(NULL AS STRING)     AS centro_coste,
  --     CAST(NULL AS STRING)     AS documento_sap,
  --     CAST(NULL AS STRING)     AS documento_sap_posicion,
  --     CAST(NULL AS STRING)     AS fecha_contabilizacion,
  --     CAST(NULL AS TIMESTAMP)  AS creado,
  --     CAST(NULL AS TIMESTAMP)  AS modificado,
  --     CAST(NULL AS STRING)     AS id_factura_drive,
  --     CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
  --   FROM  `mm-commissions-reporting.COMISIONES.transacciones`
  --   WHERE 1=1 
  --     AND canal = 'CM'
  --     AND estado = 'facturado'
  --     AND id_mes = 202503
  --     AND id_comisionista = 'F88520'
  --     AND concepto = 'C - Gestion Cartera Movil (40%)'
  -- ),

  final AS (
    SELECT *
    FROM consulta_1

    --UNION ALL

    -- SELECT *
    -- FROM consulta_2
  )


  SELECT prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
  FROM final
;

  -- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  CAST(mes_string AS INT64),
  canales_pr,
  'TEMP.tabla_sub_tr_BQ',
  'ACTUALIZAR'
);
END