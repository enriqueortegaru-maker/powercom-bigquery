BEGIN

DECLARE prefijo STRING;
DECLARE mes_string STRING;
DECLARE mes_facturado DATE;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CALD';

SET canales_pr = COALESCE(canales_pr, ['AVO']);

SET mes_facturado = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 1 MONTH);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_cald_avoris`(202604, ['AVO']);
*/



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cald_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS    --Esta tabla siempre hay que actualizarla para ejecutar
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1
)
;
---VALIDAR QUE LA ÚLTIMA FACTURA ESTÁ PAGADA----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calidad_factura` AS (
  SELECT *
  FROM `COMISIONES.facturacion_linea_mes_phone_nm` BILLING
  LEFT JOIN `mm-commissions-reporting.TEMP.cald_billing_status` STATUS
    ON BILLING.invoice_id = STATUS.invoice_no
  WHERE BILLING.mes_facturado = mes_facturado
  AND STATUS.status IN ('PAID', 'RECOLLECTED')
); 



---CONSUMO MEDIO DE LOS CLIENTES ÚLTIMOS 6 MESES---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calidad_consumo_avoris` AS (
  SELECT marca, service_id, service_type, phone_nm, SUM(importe_facturado) AS importe_facturado
  FROM `COMISIONES.facturacion_linea_mes_phone_nm` BILLING
  WHERE BILLING.mes_facturado BETWEEN DATE_SUB(mes_facturado, INTERVAL 6 MONTH) AND mes_facturado
  AND MARCA = 'PEPEPHONE'
  GROUP BY 1, 2, 3, 4
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calidad_avoris_base` AS (
  SELECT
      -- VENTAS.agrupacion_canal,
      'No Exclusivo' as agrupacion_canal,
      D.canal,
      CASE
       WHEN DATE_DIFF(PARSE_DATE('%Y%m', mes_string), DATE(VENTAS.activation_date), MONTH) = 6  THEN 'C - Calidad 6 meses'
       WHEN DATE_DIFF(PARSE_DATE('%Y%m', mes_string), DATE(VENTAS.activation_date), MONTH) = 12 THEN 'C - Calidad 12 meses'
       WHEN DATE_DIFF(PARSE_DATE('%Y%m', mes_string), DATE(VENTAS.activation_date), MONTH) = 24 THEN 'C - Calidad 24 meses'
      ELSE NULL
      END AS concepto,
      VENTAS_BASE_NET.sfid_id AS id_comisionista,
      VENTAS_BASE_NET.sfid_id AS distribuidor,
      VENTAS.seller,
      VENTAS.marca,
      VENTAS.service_type,
      VENTAS.phone_nm,
      VENTAS.tariff_id,
      VENTAS.tariff_ds,
      VENTAS.service_id,
      VENTAS.account_id,
      VENTAS.customer_id,
      VENTAS.line_type_ds,
      VENTAS.bundle_type,
      VENTAS.technology_ds,
      VENTAS.billing_type_ds,
      VENTAS.sale_date,
      VENTAS.activation_date,
      VENTAS.deactivation_date,
      VENTAS.order_id,
      VENTAS.order_type_agg,
      VENTAS.cod_segmento,
      VENTAS.cod_marca,
      VENTAS.cod_tipo_contrato,
      VENTAS.cod_producto,
      VENTAS.cod_canal,
      'C_MANUAL' AS facturador,
      VENTAS.sociedad

  FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS 

  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` VENTAS_BASE_NET
  ON VENTAS.service_id = VENTAS_BASE_NET.service_id

  LEFT JOIN ( SELECT codigo_pdv as sfid_id, 'AVO' as canal
              FROM `mm-commissions-reporting.GS.SFID_AVORIS` 

              UNION ALL

              SELECT sfid_id, canal
              FROM `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`
              WHERE CANAL = 'AVO'
            ) D
    ON VENTAS_BASE_NET.sfid_id = D.sfid_id OR VENTAS.sfid_id = D.sfid_id 

  WHERE D.canal = 'AVO'
    AND DATE_TRUNC(DATE(VENTAS.deactivation_date), MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND VENTAS.marca = 'PEPEPHONE'
    AND DATE_DIFF(PARSE_DATE('%Y%m', mes_string), DATE(VENTAS.activation_date), MONTH) IN (6, 12, 24)
  GROUP BY ALL
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calidad_avoris_final` AS (
SELECT 
   prefijo || '_AVO' || mes_string || '_' || A.canal || '_' || ROW_NUMBER() OVER() AS commission_id,
    'calculado' AS estado,
   PARSE_DATE('%Y%m', mes_string) AS mes_liquidado,
    id_mes_pr AS id_mes,
    A.agrupacion_canal,
    A.canal,
    A.concepto,
    'AIRT' AS tipo_concepto,
    1 AS unidades,
    CASE 
      WHEN concepto = 'C - Calidad 24 meses' THEN
        CASE 
          WHEN T.importe_facturado >= 18.00                 THEN 20
          WHEN T.importe_facturado BETWEEN 14.00 AND 17.99  THEN 16
          WHEN T.importe_facturado < 14.00                  THEN 10
          ELSE 0
        END
      WHEN concepto IN ('C - Calidad 6 meses', 'C - Calidad 12 meses') THEN
        CASE 
          WHEN T.importe_facturado >= 18.00                 THEN 10
          WHEN T.importe_facturado BETWEEN 14.00 AND 17.99  THEN 8
          WHEN T.importe_facturado < 14.00                  THEN 5
          ELSE 0
        END
      ELSE 0
    END AS comision,

    A.id_comisionista,
    A.distribuidor,
    D.sfid_id,
    A.seller,
    D.nombre_comercio,
    D.razon_social,
    D.cif,
    D.zona_fiscal,
    A.marca,
    A.service_type,
    A.phone_nm,
    A.tariff_id,
    A.tariff_ds,
    A.service_id,
    A.account_id,
    A.customer_id,
    A.line_type_ds,
    A.bundle_type,
    A.technology_ds,
    A.billing_type_ds,
    A.sale_date,
    A.activation_date,
    A.deactivation_date,
    A.order_id,
    A.order_type_agg,
    A.cod_segmento,
    A.cod_marca,
    A.cod_tipo_contrato,
    A.cod_producto,
    A.cod_canal,
    CAST(NULL AS STRING) AS campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    'Calidad No Exclusivo ' || id_mes_pr AS comments,
    'C_MANUAL' AS facturador,
    A.sociedad,
    CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.TEMP.calidad_avoris_base` A


  LEFT JOIN `mm-commissions-reporting.TEMP.calidad_consumo_avoris`  T 
  ON A.service_id = T.service_id 

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` D
  ON (
    A.seller = D.sfid_id
    OR A.id_comisionista = D.sfid_id
    OR A.id_comisionista || '-' || A.seller = REPLACE(D.sfid_id, ' ', '')
    ) 
    AND D.id_mes = id_mes_pr
   WHERE A.service_type = 'MOBILE'
   
  QUALIFY ROW_NUMBER () OVER (PARTITION BY service_id, phone_nm, marca) = 1

);


DELETE FROM `mm-commissions-reporting.TEMP.calidad_avoris_final`
WHERE comision = 0

;
--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CALD_AVO', id_mes_pr, canales_pr, 'TEMP.calidad_avoris_final', 'ACTUALIZAR');
END