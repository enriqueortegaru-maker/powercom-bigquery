BEGIN

DECLARE prefijo STRING;
DECLARE mes_string STRING;
DECLARE mes_facturado DATE;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CAEX';

SET canales_pr = COALESCE(canales_pr, ['EML','ENX','ENK']);

SET mes_facturado = DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 1 MONTH);

--ojo antes de lanzar modificar la fecha linea 49 un mes menos del mes en curso.
/*
CALL `mm-commissions-reporting.COMISIONES.pr_cald_exnew`(202608, ['EML','ENX','ENK']);
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
  -- WHERE BILLING.mes_facturado = '2024-05-01'
  WHERE BILLING.mes_facturado = mes_facturado
  AND STATUS.status IN ('PAID', 'RECOLLECTED')
); 



---CONSUMO MEDIO DE LOS CLIENTES ÚLTIMOS 6 MESES---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calidad_consumo` AS (
  SELECT marca, phone_nm,count(distinct(mes_facturado)) as conteo, SUM(importe_facturado)/5 AS importe_medio
  FROM `COMISIONES.facturacion_linea_mes_phone_nm` BILLING
  -- WHERE BILLING.mes_facturado BETWEEN mes_facturado and DATE_SUB(mes_facturado, INTERVAL 4 MONTH) 
  -- WHERE (BILLING.mes_facturado < '2026-04-01' AND BILLING.mes_facturado >= DATE_SUB('2026-03-01', INTERVAL 4 MONTH)) -- PRIMERA FECHA ID_MES_PR, SEGUNDA FECHA ID_MES_PR - 1
  WHERE (BILLING.mes_facturado < DATE(PARSE_DATE('%Y%m', mes_string)) AND BILLING.mes_facturado >= DATE_SUB(mes_facturado, INTERVAL 4 MONTH)) -- PRIMERA FECHA ID_MES_PR, SEGUNDA FECHA ID_MES_PR - 1
  -- WHERE (BILLING.mes_facturado = mes_facturado or BILLING.mes_facturado > DATE_SUB(mes_facturado, INTERVAL 4 MONTH))
  -- GROUP BY 1, 2, 3, 4,5
  GROUP BY ALL
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_calidad_base` AS (
  SELECT
      TRANSACCIONES.agrupacion_canal,
      TRANSACCIONES.canal,
      TRANSACCIONES.concepto,
      TRANSACCIONES.tipo_concepto,
      TRANSACCIONES.unidades,
      TRANSACCIONES.comision,
      TRANSACCIONES.id_comisionista,
      TRANSACCIONES.distribuidor,
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
  -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS 
  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS
    ON TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) AND TRANSACCIONES.marca = VENTAS.brand_ds and TRANSACCIONES.service_id = VENTAS.service_id
  WHERE TRANSACCIONES.canal IN UNNEST(canales_pr)
    AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'C - Calidad 6 meses','C - Calidad 12 meses')
    AND VENTAS.service_status_ds IN ('ACTIVO','CARTERA')    
    -- AND (VENTAS.deactivation_date = '9999-12-31' OR VENTAS.deactivation_date IS NULL)
    AND VENTAS.activation_date < '2025-07-01' -- FECHA INICIO NUEVO MR
    and TRANSACCIONES.mes_liquidado = PARSE_DATE('%Y%m', CAST(TRANSACCIONES.id_mes AS STRING))
    AND (       
      (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH)) AS INT64))
      -- OR (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH)) AS INT64)) -- Para calcular Calidad 12 meses en casos en que no se haya pagado la Calidad 6 meses
      -- OR (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 24 MONTH)) AS INT64))
      OR (TRANSACCIONES.concepto = 'C - Calidad 6 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 6 MONTH)) AS INT64))
      OR (TRANSACCIONES.concepto = 'C - Calidad 12 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH)) AS INT64))
    )
    AND TRANSACCIONES.estado = 'facturado'
    AND TRANSACCIONES.comision > 0
    and TRANSACCIONES.mes_liquidado = PARSE_DATE('%Y%m', CAST(TRANSACCIONES.id_mes AS STRING))
    -- and VENTAS.activation_date is not null
  -- GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33
  GROUP BY ALL

  union all

    SELECT
      TRANSACCIONES.agrupacion_canal,
      TRANSACCIONES.canal,
      TRANSACCIONES.concepto,
      TRANSACCIONES.tipo_concepto,
      TRANSACCIONES.unidades,
      TRANSACCIONES.comision,
      TRANSACCIONES.id_comisionista,
      TRANSACCIONES.distribuidor,
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
  -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS 
  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS
    ON TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) AND TRANSACCIONES.marca = VENTAS.brand_ds AND TRANSACCIONES.service_id = VENTAS.service_id
  WHERE TRANSACCIONES.canal IN UNNEST(canales_pr)
    AND TRANSACCIONES.concepto IN ('C - Calidad 24 meses', 'C - Calidad 36 meses')
    -- AND (VENTAS.deactivation_date = '9999-12-31' OR VENTAS.deactivation_date IS NULL)
    AND VENTAS.service_status_ds IN ('ACTIVO','CARTERA')    
    and TRANSACCIONES.mes_liquidado = PARSE_DATE('%Y%m', CAST(TRANSACCIONES.id_mes AS STRING))
    AND (       
 
        (TRANSACCIONES.concepto = 'C - Calidad 24 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH)) AS INT64))
       OR (TRANSACCIONES.concepto = 'C - Calidad 36 meses' AND TRANSACCIONES.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE(PARSE_DATE('%Y%m', mes_string)), INTERVAL 12 MONTH)) AS INT64))
    )
    AND TRANSACCIONES.estado = 'facturado'
    AND TRANSACCIONES.comision > 0
    and TRANSACCIONES.mes_liquidado = PARSE_DATE('%Y%m', CAST(TRANSACCIONES.id_mes AS STRING))
    -- and VENTAS.activation_date is not null
  -- GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33
  GROUP BY ALL
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_FINAL_EXCLU` AS (
SELECT 
   prefijo || '_EX' || mes_string || '_' || A.canal || '_' || ROW_NUMBER() OVER() AS commission_id,
    'calculado' AS estado,
   PARSE_DATE('%Y%m', mes_string) AS mes_liquidado,
    id_mes_pr AS id_mes,
    A.agrupacion_canal,
    D.canal,
    CASE 
      WHEN A.concepto = 'A - Servicio Movil Pospago' THEN 'C - Calidad 6 meses' 
      WHEN A.concepto = 'C - Calidad 6 meses'  THEN 'C - Calidad 12 meses' 
      WHEN A.concepto = 'C - Calidad 12 meses' THEN 'C - Calidad 24 meses' 
      WHEN A.concepto = 'C - Calidad 24 meses' THEN 'C - Calidad 36 meses' 
      WHEN A.concepto = 'C - Calidad 36 meses' THEN 'C - Calidad 48 meses' 
    END AS concepto,
    'AIRT' AS tipo_concepto,
    A.unidades,
    CASE
      WHEN A.canal IN ('EML','ENX') AND A.concepto IN ('A - Servicio Movil Pospago','C - Calidad 6 meses') 
      and T.conteo >=5 AND t.importe_medio >= 25 THEN 8 
      WHEN A.canal IN ('EML','ENX') AND A.concepto IN ('A - Servicio Movil Pospago','C - Calidad 6 meses') 
      and T.conteo >=5 AND t.importe_medio >= 16 THEN 6
      WHEN A.canal IN ('EML','ENX') AND A.concepto IN ('A - Servicio Movil Pospago','C - Calidad 6 meses') 
      and T.conteo >=5 AND t.importe_medio >=  8  THEN 3
      WHEN A.canal IN ('EML','ENX') AND A.concepto IN ('C - Calidad 12 meses','C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 48 meses') 
       and T.conteo >=5 AND t.importe_medio >= 25 THEN 12 
      WHEN A.canal IN ('EML','ENX') AND A.concepto IN ('C - Calidad 12 meses','C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 48 meses') 
       and T.conteo >=5 AND t.importe_medio >= 16 THEN 10
      WHEN A.canal IN ('EML','ENX') AND A.concepto IN ('C - Calidad 12 meses','C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 48 meses') 
       and T.conteo >=5 AND t.importe_medio >= 8  THEN 6
           ELSE 0 
    END AS comision,
    D.id_comisionista,
    A.distribuidor,
    D.id_comisionista AS sfid_id,
    D.id_comisionista AS seller,
    D.nombre_comercio,
    D.razon_social,
    D.documento AS cif,
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
  ON A.phone_nm = CAST(T.phone_nm AS STRING) AND A.marca = T.marca
  
  LEFT JOIN `mm-commissions-reporting.GS.BAJACARTERA` f
  ON a.seller = f.seller

  -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` D
  -- ON (
  --   A.seller = D.sfid_id
  --   OR A.id_comisionista = D.sfid_id
  --   OR A.id_comisionista || '-' || A.seller = REPLACE(D.sfid_id, ' ', '')
  --   ) 

  LEFT JOIN `mm-commissions-reporting.GS.exclusivo_dealers` D
  ON (
         A.seller = D.id_comisionista
      OR A.id_comisionista = D.id_comisionista
      OR A.id_comisionista || '-' || A.seller = REPLACE(D.id_comisionista, ' ', '')
     )
  AND A.canal = D.canal_procedencia

  --  AND D.id_mes = id_mes_pr
  --  AND D.id_mes = 202502

 LEFT JOIN (
          SELECT
                phone_nm
               ,marca
               ,COUNT(DISTINCT concepto) num_conceptos
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE agrupacion_canal = 'Exclusivo'
                AND concepto IN ('C - Calidad 6 meses','C - Calidad 12 meses','C - Calidad 24 meses', 'C - Calidad 36 meses')
                AND estado = 'facturado'
          GROUP BY 1,2
          ) CALIDAD
         ON a.phone_nm = CALIDAD.phone_nm
            AND a.marca = CALIDAD.marca  and a.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses')
            AND CASE
                    WHEN a.concepto = 'C - Calidad 24 meses' THEN 1
                    WHEN a.concepto = 'C - Calidad 36 meses' THEN 1
                END
                <= CALIDAD.num_conceptos

  WHERE D.documento NOT IN ('A82037292','A65281988')
   and f.PAGAR ='TRUE'
  AND T.importe_medio >= 0 
  AND D.comisiona = true
  and (a.concepto in ('A - Servicio Movil Pospago','C - Calidad 6 meses','C - Calidad 12 meses') or calidad.phone_nm is not null)

  QUALIFY ROW_NUMBER () OVER (PARTITION BY phone_nm, marca) = 1

);


DELETE FROM `mm-commissions-reporting.TEMP.CALIDAD_FINAL_EXCLU`
WHERE comision = 0;

DELETE FROM `mm-commissions-reporting.TEMP.CALIDAD_FINAL_EXCLU`
where seller like '%_RPORT' ;

delete `mm-commissions-reporting.TEMP.CALIDAD_FINAL_EXCLU` 
where commission_id in (select distinct commission_id from `mm-commissions-reporting.TEMP.CALIDAD_FINAL_EXCLU` a
  LEFT JOIN `mm-commissions-reporting.GS.BAJACARTERA` b
  ON a.seller = b.seller
  WHERE 1=1
  AND b.PAGAR ='FALSE')
;

--- Insertar tabla final ----

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CAEX_', id_mes_pr, canales_pr, 'TEMP.CALIDAD_FINAL_EXCLU', 'ACTUALIZAR');


END