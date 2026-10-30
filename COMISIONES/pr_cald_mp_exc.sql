BEGIN

DECLARE prefijo STRING;
DECLARE mes_string STRING;
DECLARE mes_facturado DATE;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CALD';

SET canales_pr = COALESCE(canales_pr, ['MP']);

SET mes_facturado = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 1 MONTH);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_cald_mp_exc`(202512, ['MP']);
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
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calidad_consumo` AS (
  SELECT marca, service_id, service_type, phone_nm, SUM(importe_facturado)/6 AS importe_medio
  FROM `COMISIONES.facturacion_linea_mes_phone_nm` BILLING
  WHERE BILLING.mes_facturado BETWEEN DATE_SUB(mes_facturado, INTERVAL 6 MONTH) AND mes_facturado
  GROUP BY 1, 2, 3, 4
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_calidad_base_MP` AS (
  SELECT
      TRANSACCIONES.agrupacion_canal,
      D.canal,
      TRANSACCIONES.concepto,
      TRANSACCIONES.tipo_concepto,
      TRANSACCIONES.unidades,
      TRANSACCIONES.comision,
      TRANSACCIONES.sfid_id AS id_comisionista,
      TRANSACCIONES.distribuidor,
      TRANSACCIONES.sfid_id,
      TRANSACCIONES.marca,
      TRANSACCIONES.service_type,
      TRANSACCIONES.phone_nm,
      TRANSACCIONES.tariff_id,
      TRANSACCIONES.tariff_ds,
      TRANSACCIONES.service_id,
      TRANSACCIONES.account_id,
      TRANSACCIONES.customer_id,
      TRANSACCIONES.line_type_ds,
      TRANSACCIONES.bundle_type,
      TRANSACCIONES.technology_ds,
      TRANSACCIONES.billing_type_ds,
      TRANSACCIONES.sale_date,
      TRANSACCIONES.activation_date,
      TRANSACCIONES.deactivation_date,
      TRANSACCIONES.order_id,
      TRANSACCIONES.order_type_agg,
      TRANSACCIONES.cod_segmento,
      TRANSACCIONES.cod_marca,
      TRANSACCIONES.cod_tipo_contrato,
      TRANSACCIONES.cod_producto,
      TRANSACCIONES.cod_canal,
      TRANSACCIONES.facturador,
      TRANSACCIONES.sociedad

  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  -- FROM `mm-commissions-reporting.TEMP.CALIDAD_LB206230` TRANSACCIONES
  LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS 
    ON TRANSACCIONES.phone_nm = VENTAS.phone_nm AND TRANSACCIONES.account_id = VENTAS.account_id

   LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` D
    ON TRANSACCIONES.sfid_id = D.sfid_id --AND D.id_mes = id_mes_pr

  WHERE 1 = 1
    AND D.canal IN UNNEST(canales_pr)
    -- AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'C - Calidad 6 meses', 'C - Calidad 12 meses')
    AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'C - Calidad 6 meses', 'C - Calidad 12 meses','Z - Servicio Movil Pospago', 'Z - Calidad 6 meses', 'Z - Calidad 12 meses')
    -- AND (VENTAS.deactivation_date = '9999-12-31' OR VENTAS.deactivation_date IS NULL)
    AND DATE_TRUNC(DATE(VENTAS.deactivation_date), MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND (       
      -- (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH)) AS INT64))
      (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH))
      -- OR (TRANSACCIONES.concepto = 'C - Calidad 6 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH)) AS INT64))
      OR (TRANSACCIONES.concepto IN ('C - Calidad 6 meses','Z - Calidad 6 meses') AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH))
      -- OR (TRANSACCIONES.concepto = 'C - Calidad 12 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH)) AS INT64))
      OR (TRANSACCIONES.concepto IN ('C - Calidad 12 meses','Z - Calidad 12 meses') AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 24 MONTH))
    )
    AND TRANSACCIONES.estado = 'facturado'
    AND TRANSACCIONES.comision > 0
 
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_FINAL_MP_EXC` AS (
SELECT 
   prefijo || '_EXC' || mes_string || '_' || A.canal || '_' || ROW_NUMBER() OVER() AS commission_id,
    'calculado' AS estado,
   PARSE_DATE('%Y%m', mes_string) AS mes_liquidado,
    id_mes_pr AS id_mes,
    A.agrupacion_canal,
    A.canal,
    CASE 
      WHEN A.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago') THEN 'C - Calidad 6 meses' 
      WHEN A.concepto IN ('C - Calidad 6 meses','Z - Calidad 6 meses')               THEN 'C - Calidad 12 meses' 
      WHEN A.concepto IN ('C - Calidad 12 meses','Z - Calidad 12 meses')             THEN 'C - Calidad 24 meses' 
    END AS concepto,
    'AIRT' AS tipo_concepto,
    A.unidades,
    CASE
      WHEN A.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago') AND t.importe_medio >= 18 THEN 10 
      WHEN A.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago') AND t.importe_medio >= 14 THEN 8
      WHEN A.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago') AND t.importe_medio < 14  THEN 5
      WHEN A.concepto IN ('A - Servicio Movil Pospago','Z - Servicio Movil Pospago') AND t.importe_medio = 0   THEN 0 
      WHEN A.concepto IN ('C - Calidad 6 meses','Z - Calidad 6 meses')                       THEN A.comision 
      WHEN A.concepto IN ('C - Calidad 12 meses','Z - Calidad 12 meses') AND A.comision = 10 THEN 20
      WHEN A.concepto IN ('C - Calidad 12 meses','Z - Calidad 12 meses') AND A.comision = 8  THEN 16
      WHEN A.concepto IN ('C - Calidad 12 meses','Z - Calidad 12 meses') AND A.comision = 5  THEN 10     
      ELSE 0 
    END AS comision,
    A.id_comisionista,
    A.distribuidor,
    D.sfid_id,
    A.sfid_id AS seller,
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
    'Calidad MP ' || id_mes_pr AS comments,
    'C_MANUAL' AS facturador,
    A.sociedad,
    CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.TEMP.CALIDAD_calidad_base_MP` A

  LEFT JOIN `mm-commissions-reporting.TEMP.calidad_consumo` T 
  ON A.phone_nm = CAST(T.phone_nm AS STRING) AND A.service_id = T.service_id

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` D
  ON (
    A.sfid_id = D.sfid_id
    OR A.id_comisionista = D.sfid_id
    OR A.id_comisionista || '-' || A.sfid_id = REPLACE(D.sfid_id, ' ', '')
    ) 
    -- AND D.id_mes = id_mes_pr

  WHERE D.cif NOT IN ('A82037292','A65281988')
  AND T.importe_medio > 4
  AND D.comisiona = true
  QUALIFY ROW_NUMBER () OVER (PARTITION BY service_id, phone_nm, marca) = 1

);


DELETE FROM `mm-commissions-reporting.TEMP.CALIDAD_FINAL_MP_EXC`
WHERE comision = 0

;

--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CALD_', id_mes_pr, canales_pr, 'TEMP.CALIDAD_FINAL_MP_EXC', 'ACTUALIZAR');


END