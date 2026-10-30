BEGIN

DECLARE prefijo STRING;
DECLARE mes_string STRING;
DECLARE mes_facturado DATE;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CALDNX';

SET canales_pr = COALESCE(canales_pr, ['ALTN','ALTNC','ALTNH','CA','MP','PH']);

SET mes_facturado = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 1 MONTH);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_cald_nex`(202602, ['ALTN','ALTNC','ALTNH','PH']);
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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tramos_fijo_alternativo` AS (
  

  SELECT ID_PDV.sfid_unico AS sfid_digo, ID_PDV.sfid as sfid_id, SEGMENTACION.*,GS.*

  FROM `mm-commissions-reporting.GS.ALTERNATIVO_SEGMENTACION_FIJO` SEGMENTACION

  LEFT JOIN  `mm-commissions-reporting.GS.RAPPEL_FIJO` GS

   ON SEGMENTACION.SEGMENTACION_FIJO = GS.CLASIFICACION
    AND ID_MES_PR BETWEEN GS.MES_INICIO AND GS.MES_FIN

  
  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` ID_PDV
  ON SEGMENTACION.ID_EMPRESA = ID_PDV.id_empresa



  WHERE SEGMENTACION.MES = ID_MES_PR
  
)
;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_calidad_base` AS (
  SELECT
      TRANSACCIONES.agrupacion_canal,
      D.canal,
      TRANSACCIONES.concepto,
      TRANSACCIONES.tipo_concepto,
      TRANSACCIONES.unidades,
      TRANSACCIONES.comision,
      D.id_comisionista,
      D.distribuidor,
      TRANSACCIONES.seller,
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
  LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS 
    ON TRANSACCIONES.phone_nm = VENTAS.phone_nm AND TRANSACCIONES.account_id = VENTAS.account_id

  LEFT JOIN  `mm-commissions-reporting.GS.ALTERNATIVO_SFID_MIGRADOS_CARTERA` SFID_MP
   ON TRANSACCIONES.seller = SFID_MP.MP

  -- LEFT JOIN `mm-sales-reporting.optico.ORIGEN_DESTINO_PDV_MM` MIGRACIONES 
  -- ON MIGRACIONES.sfid_anterior = TRANSACCIONES.sfid_id 

   LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` D
    ON (TRANSACCIONES.seller = D.sfid_id OR SFID_MP.ALTERNATIVO = D.sfid_id )
    AND D.id_mes = id_mes_pr -- COMENTAR SI SE QUIEREN CALCULAR PERIODOS ANTERIORES

  WHERE D.canal IN UNNEST(canales_pr)
    AND TRANSACCIONES.agrupacion_canal ='No Exclusivo'
    AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'C - Calidad 6 meses', 'C - Calidad 12 meses')
    -- AND (VENTAS.deactivation_date = '9999-12-31' OR VENTAS.deactivation_date IS NULL)
    AND DATE_TRUNC(DATE(VENTAS.deactivation_date), MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    AND (       
      (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH)) AS INT64))
      OR (TRANSACCIONES.concepto = 'C - Calidad 6 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH)) AS INT64))
      OR (TRANSACCIONES.concepto = 'C - Calidad 12 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH)) AS INT64))
    )
    AND TRANSACCIONES.estado = 'facturado'
    AND TRANSACCIONES.comision > 0
 
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_FINAL_NEX` AS (
SELECT 
   prefijo||'_' || mes_string || '_' || A.canal || '_' || ROW_NUMBER() OVER() AS commission_id,
    'calculado' AS estado,
   PARSE_DATE('%Y%m', mes_string) AS mes_liquidado,
    id_mes_pr AS id_mes,
    A.agrupacion_canal,
    A.canal,
    CASE 
      WHEN A.concepto = 'A - Servicio Movil Pospago' THEN 'C - Calidad 6 meses' 
      WHEN A.concepto = 'C - Calidad 6 meses'  THEN 'C - Calidad 12 meses' 
      WHEN A.concepto = 'C - Calidad 12 meses' THEN 'C - Calidad 24 meses' 
    END AS concepto,
    'AIRT' AS tipo_concepto,
    A.unidades,
    CASE
      WHEN D.canal = 'PH' AND A.marca = 'YOIGO' THEN 0
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'A - Servicio Movil Pospago' AND t.importe_medio >= 18 THEN 10 
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'A - Servicio Movil Pospago' AND t.importe_medio >= 14 THEN 8
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'A - Servicio Movil Pospago' AND t.importe_medio < 14 THEN 5
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'A - Servicio Movil Pospago' AND t.importe_medio = 0 THEN 0 
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'C - Calidad 6 meses' THEN A.comision 
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'C - Calidad 12 meses' AND A.comision = 10 THEN 20
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'C - Calidad 12 meses' AND A.comision = 8 THEN 16
      WHEN D.canal IN ('ALTN','ALTNC','MP','PH') AND A.concepto = 'C - Calidad 12 meses' AND A.comision = 5 THEN 10     
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
  FROM `mm-commissions-reporting.TEMP.CALIDAD_calidad_base` A



  LEFT JOIN `mm-commissions-reporting.TEMP.calidad_consumo` T 
  ON A.phone_nm = CAST(T.phone_nm AS STRING) AND A.service_id = T.service_id

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` D
  ON (
    A.seller = D.sfid_id
    OR A.id_comisionista = D.sfid_id
    OR A.id_comisionista || '-' || A.seller = REPLACE(D.sfid_id, ' ', '')
    ) 
    AND D.id_mes = id_mes_pr -- COMENTAR SI SE QUIEREN CALCULAR PERIODOS ANTERIORES

  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
    ON D.sfid_id = OPTICO.sfid

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fijo_config` RAPPEL_FIJO
  ON RAPPEL_FIJO.sfid_unico = OPTICO.sfid_unico

  -- LEFT JOIN `mm-commissions-reporting.TEMP.tramos_fijo_alternativo` TRAMOS_FIJO
  --   ON TRAMOS_FIJO.sfid_id = D.sfid_id AND (id_mes_pr BETWEEN TRAMOS_FIJO.MES_INICIO AND TRAMOS_FIJO.MES_FIN)

  WHERE D.cif NOT IN ('A82037292','A65281988')
  AND T.importe_medio > 4
  AND D.comisiona = true
  AND NOT (D.canal IN ('ALTN','ALTNC','ALTNH') AND activation_date >= '2025-01-01')
  -- AND TRAMOS_FIJO.TRAMO_FIJO IN ('Tramo 4','Tramo 5')
  AND (
   D.canal NOT IN ('ALTN','ALTNC','ALTNH')
   OR RAPPEL_FIJO.CLASIFICACION IN ('PLATINO','DIAMANTE')
   OR A.seller IN ('MP060745','MP101211','MP390792'))
  QUALIFY ROW_NUMBER () OVER (PARTITION BY service_id, phone_nm, marca) = 1

);


DELETE FROM `mm-commissions-reporting.TEMP.CALIDAD_FINAL_NEX`
WHERE comision = 0

;

--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr, 'TEMP.CALIDAD_FINAL_NEX', 'ACTUALIZAR');


END