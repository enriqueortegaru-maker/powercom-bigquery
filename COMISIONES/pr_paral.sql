BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'PARAL';

SET canales_pr = ['ALT'];

-- CALL `mm-commissions-reporting.COMISIONES.pr_paral`(202408,['ALT']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_9_puntos_aral` AS

WITH 

  base_tr AS (
    --Los duplicados que hay son por cambios de tarifa que es correcto
    SELECT DISTINCT * EXCEPT (commission_id, emails_acceso_trazabilidad)
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE marca = 'ALTERNA'
      AND id_mes BETWEEN 202409 AND 202503
      AND (concepto = 'C - Gestion Cartera MO (46%)' OR concepto = 'C - Gestion Cartera MBB (46%)')
  ),

  final AS (

    SELECT 
      'calculado' AS estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AS mes_liquidado,
      CAST(mes_string AS INT64) AS id_mes,
      agrupacion_canal,
      canal,
      'D - Cierre 9 puntos Comision Cartera Sep 24 - Mar 25' AS concepto,
      tipo_concepto,
      unidades,
      ROUND((comision*100/46)*0.09,3) AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
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
      cod_producto,
      cod_canal,
      CAST(NULL AS STRING) AS campaign_code,
      serial_number,
      COALESCE(tax_base, CAST(campaign_code AS FLOAT64)) AS tax_base,
      claim_code,
      process_code,
      COALESCE(CONCAT("Fecha_registro ",id_mes,' / ',comments),CONCAT("Fecha_registro ",id_mes)) AS comments,
      facturador,
      CAST(NULL AS STRING) AS proceso_sap,
      CAST(NULL AS STRING) AS id_registro,
      CAST(NULL AS STRING) AS invoice_id,
      sociedad,
      CAST(NULL AS STRING) AS bp,
      CAST(NULL AS STRING) AS cuenta_contable,
      CAST(NULL AS STRING) AS centro_coste,
      CAST(NULL AS STRING) AS documento_sap,
      CAST(NULL AS STRING) AS documento_sap_posicion,
      CAST(NULL AS STRING) AS fecha_contabilizacion,
      CAST(NULL AS STRING) AS creado,
      CAST(NULL AS STRING) AS modificado,
      CAST(NULL AS STRING) AS id_factura_drive,
      CAST (NULL AS STRING) AS emails_acceso_trazabilidad,
    FROM base_tr a
  )

  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
  FROM final
  WHERE comision IS NOT NULL AND comision != 0; 

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_base_9_puntos_aral',
  'ACTUALIZAR'
);

END