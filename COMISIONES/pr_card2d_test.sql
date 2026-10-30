BEGIN


/*
VERSIÓN DE TEST DE pr_card2d (fuente airtime: fotos mensuales FC_AIRTIME_LINEAS_YYYYMM)

- Misma lógica que producción. Solo cambia la fuente de airtime:
    PRODUCCIÓN: FC_AIRTIME_LINEAS            con MES = 'YYYYMM' (texto)
    TEST:       FC_AIRTIME_LINEAS_<YYYYMM>    foto del mes facturado, MES comparado como fecha
  (liquidación 202610 -> FC_AIRTIME_LINEAS_202609)
- Se mantiene el cruce por teléfono y los filtros SfidEstado = 'OK', AIRTIME = 1 y EnCartera = 1.
- Si la foto del mes no existe o está vacía, el procedimiento se para con un error.
- NO llama a pr_insert_comisiones -> no se sube nada a COMISIONES.transacciones.
- Todas las tablas de trabajo llevan _test para no pisar las de producción.

CALL COMISIONES.pr_card2d_test(202610, NULL, NULL, 0);

Resultados en:
  TEMP.card2d_test_airtime   -> foto de airtime (por línea) usada en el cálculo
  TEMP.card2d_test           -> cartera (C - Cartera)
  TEMP.card2d_test_bajas     -> penalizaciones (P - Cartera)
  TEMP.card2d_test_final     -> unión de ambas (lo que se habría insertado en transacciones)
*/ 


/* Declara las variables que se van a usar a lo largo del procedimiento */
DECLARE mes_string, prefijo,table_suffix STRING;
DECLARE meses ARRAY <DATE>;
DECLARE m INT64 DEFAULT 0;
DECLARE mes, id_mes_periodo_facturado, id_mes_periodo_antiguedad INT64;
DECLARE mes_periodo_facturado, mes_periodo_antiguedad DATE;


SET mes_string = CAST(id_mes_pr AS STRING);
SET table_suffix = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 MONTH)) AS STRING);

/* Si solo el valor de "id_mes_pr" está indicado, el procedimiento se ejecutara solo para ese mes. Pero si el valor de "mes_fin" es introducido, el procedimiento se ejecuta para el rango de meses entre y incluyendo los meses de "mes_inicio" y "mes_fin" */
IF mes_fin IS NULL THEN SET meses = ARRAY(SELECT PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)));
ELSE SET meses = GENERATE_DATE_ARRAY(PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)), PARSE_DATE('%Y%m', CAST(mes_fin AS STRING)), INTERVAL 1 MONTH);
END IF;


/* Borramos tablas temporales de ejecuciones previas */
IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = 'card2d_test_billing') > 0
THEN DROP TABLE `mm-commissions-reporting.TEMP.card2d_test_billing`;
END IF;

IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = 'card2d_test_deactivations') > 0
THEN DROP TABLE `mm-commissions-reporting.TEMP.card2d_test_deactivations`;
END IF;


/* Recupera el estado de las facturas de MYSIM */
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_billing_status_mysim`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1
)

;


/* Obtiene el detalle de los conceptos de Billing */ 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
GROUP BY 1,2,3,4
)
;


/* Obtiene los servicios con descuento por suspensión */ 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.suspension_servicio_cartera_test` AS
    SELECT
      customer_id, brand_ds, invoice_id, data_month_id, billing_tier_1
    FROM `mm-datamart-kd.BILLING.billing_detail_emysim` B
    WHERE billing_tier_1 like '%SUSPENSION%'
    AND data_month_id = id_mes_periodo_facturado
;

WHILE m < ARRAY_LENGTH(meses) DO -- Bucle mes

/* Contador bucle mes */
SET m = m + 1;

SET mes = CAST(SUBSTR(REPLACE(CAST(meses[ORDINAL(m)] AS STRING), '-', ''), 1, 6) AS INT64);
SET mes_periodo_facturado = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 1 MONTH);
SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);
SET mes_periodo_antiguedad = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 5 MONTH);
SET id_mes_periodo_antiguedad = CAST(FORMAT_DATE('%Y%m', mes_periodo_antiguedad) AS INT64);


/* TEST: foto de airtime por línea del mes facturado (sustituye a FC_AIRTIME_LINEAS).
   Liquidación 202610 -> FC_AIRTIME_LINEAS_202609. Teléfono y SFID se pasan a texto
   para cruzar igual que producción. */
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_airtime`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CAST(PHONE_NM AS STRING)    AS PHONE_NM
     ,CAST(CUSTOMER_ID AS STRING) AS CUSTOMER_ID
     ,CAST(SFID_ID AS STRING)     AS SFID_ID
     ,SfidEstado
     ,CAST(AIRTIME AS INT64)      AS AIRTIME
     ,CAST(EnCartera AS INT64)    AS EnCartera
     ,CARTERIZADO
FROM `mo-b2b-ssme-reporting.AIRTIME.FC_AIRTIME_LINEAS_*`
WHERE _TABLE_SUFFIX = CAST(id_mes_periodo_facturado AS STRING)
  AND CAST(MES AS DATE) = mes_periodo_facturado
)
;

/* TEST: si la foto del mes no existe o está vacía, se para aquí en lugar de calcular una cartera vacía */
IF (SELECT COUNT(*) FROM `mm-commissions-reporting.TEMP.card2d_test_airtime`) = 0 THEN
  RAISE USING MESSAGE = CONCAT('No hay datos en FC_AIRTIME_LINEAS_', CAST(id_mes_periodo_facturado AS STRING),
                               ' con MES = ', CAST(mes_periodo_facturado AS STRING));
END IF;




/* Extraemos las líneas de Billing para el periodo deseado */
CREATE OR REPLACE TEMPORARY TABLE billing AS
(
SELECT
      meses[ORDINAL(m)] AS mes_liquidado
     ,data_month_id
     ,'D2D' AS agrupacion_canal
     ,CLIENTES.SFID_ID AS sfid_id
     ,CLIENTES.SFID_ID AS seller
     ,'MYSIM' AS data_source_ds
     ,COALESCE(BILLING.brand_ds,CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET','BROADBAND')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,VENTAS.technology_ds
     ,VENTAS.billing_type_ds
     ,VENTAS.sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
     ,VENTAS.cod_segmento
     ,VENTAS.cod_marca
     ,VENTAS.cod_tipo_contrato
     ,VENTAS.cod_producto
     ,VENTAS.cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,MAX(VENTAS.comments) AS comments
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,BILLING.invoice_id

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
            SELECT *
            FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
            WHERE activation_date IS NOT NULL
            AND activation_date < COMISIONES.f_mes_int (id_mes_pr) -- PARA DEJAR DE CALCULAR CARTERA ID_MES_PR A PARTIR DE LIQUI 202608

           QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm
                                     ORDER BY CASE WHEN order_type_agg NOT IN ('MIGRACION CONTRATO', 'CAMBIO DOMICILIO') THEN 1 ELSE 2 END ASC,
                                              
                                              CASE WHEN COALESCE(deactivation_date, '9999-12-31') >= DATE_ADD(mes_periodo_facturado, INTERVAL 1 MONTH) THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN 1 ELSE 2 END ASC,

                                              CASE WHEN activation_date < mes_periodo_facturado THEN activation_date END DESC,
                                              CASE WHEN activation_date < mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END DESC,

                                              CASE WHEN activation_date >= mes_periodo_facturado THEN activation_date END ASC,
                                              CASE WHEN activation_date >= mes_periodo_facturado THEN COALESCE(deactivation_date, '9999-12-31') END ASC
                                     ) = 1
           ) VENTAS
          ON CAST(BILLING.phone_nm AS STRING) = VENTAS.phone_nm
             AND COALESCE(BILLING.brand_ds, CASE WHEN BILLING.serial = 'YC' THEN 'YOIGO' WHEN BILLING.serial = 'MC' THEN 'MASMOVIL' END) = VENTAS.brand_ds

--  INNER JOIN `mo-b2b-ssme-reporting.AIRTIME.CLIENTES_CARTERIZADOS_*` CLIENTES
-- ON CLIENTES.CUSTOMER_ID = BILLING.customer_id
-- PRODUCCIÓN:
-- inner join `mo-b2b-ssme-reporting.AIRTIME.FC_AIRTIME_LINEAS` CLIENTES
--          on CLIENTES.PHONE_NM = CAST(BILLING.phone_nm AS STRING)
--          and clientes.mes = CAST(id_mes_periodo_facturado AS STRING)
-- TEST: foto mensual del mes facturado
inner join `mm-commissions-reporting.TEMP.card2d_test_airtime` CLIENTES
         on CLIENTES.PHONE_NM = CAST(BILLING.phone_nm AS STRING)

LEFT JOIN `mm-commissions-reporting.TEMP.card2d_test_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.card2d_test_billing_status_mysim` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no


WHERE data_month_id = id_mes_periodo_facturado
AND clientes.SfidEstado='OK'
and CLIENTES.AIRTIME = 1
-- and clientes.carterizado = 'SI'
-- AND _table_suffix = CAST(id_mes_periodo_facturado AS STRING)
-- AND CONCEPTOS.bill_id !='MM_DESCUENTO_SUSPENSION_SERVICIO_100%'

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,32
)
;


IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = "card2d_test_billing") = 0
THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_billing` CLUSTER BY data_month_id OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS SELECT * FROM billing;

ELSE
INSERT INTO `mm-commissions-reporting.TEMP.card2d_test_billing` (SELECT * FROM billing);
END IF;



END WHILE;



/* Se ejecuta el proceso en modo estándar */
IF ajuste = 0

THEN

SET prefijo = 'CARD2D';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT *
FROM (
     SELECT
           prefijo || '_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,mes_liquidado
          ,id_mes_pr AS id_mes
          ,BILLING.agrupacion_canal
          ,DEALER.canal AS canal
          ,CONCEPTOS.concepto
          ,CONCEPTOS.tipo_concepto
          ,0 as unidades
     
          ,importe_facturado * 0.08 AS comision
     
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,SFIDS.SFID_ID AS sfid_id
          ,BILLING.seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,BILLING.marca
          ,BILLING.service_type
          ,BILLING.phone_nm
          ,BILLING.tariff_id
          ,BILLING.tariff_ds
          ,BILLING.service_id
          ,BILLING.account_id
          ,BILLING.customer_id
          ,BILLING.line_type_ds
          ,BILLING.bundle_type
          ,BILLING.technology_ds
          ,BILLING.billing_type_ds
          ,BILLING.sale_date

          ,CASE WHEN BILLING.activation_date = '9999-12-31' THEN BILLING.sale_date ELSE BILLING.activation_date END AS activation_date

          ,BILLING.deactivation_date
          ,BILLING.order_id
          ,BILLING.order_type_agg
          ,BILLING.cod_segmento
          ,BILLING.cod_marca
          ,BILLING.cod_tipo_contrato
          ,BILLING.cod_producto
          ,BILLING.cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,BILLING.invoice_id AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador

     FROM `mm-commissions-reporting.TEMP.card2d_test_billing` BILLING
     
     CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS, UNNEST(SPLIT(proceso, ',')) proc

     -- Añadimos relacion customer / sfid
      LEFT JOIN ( SELECT  SFID_ID, CUSTOMER_ID,EnCartera,PHONE_NM
                  FROM `mm-commissions-reporting.TEMP.card2d_test_airtime`   -- TEST (antes FC_AIRTIME_LINEAS + filtro MES)
                  WHERE EnCartera=1
                  AND SfidEstado='OK'
                  AND AIRTIME = 1
                  -- FROM `mo-b2b-ssme-reporting.AIRTIME.CLIENTES_CARTERIZADOS_*`
                  -- WHERE AIRTIME IS NOT NULL
                  -- AND _table_suffix = CAST(id_mes_periodo_facturado AS STRING)
                  ) SFIDS
            ON SFIDS.PHONE_NM = CAST(BILLING.phone_nm AS STRING)

      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
      ON SFIDS.SFID_ID = DEALER.sfid_id  

      LEFT JOIN `mm-commissions-reporting.TEMP.suspension_servicio_cartera_test` SUSPENSION 
         ON SUSPENSION.customer_id = BILLING.customer_id
         AND SUSPENSION.brand_ds = BILLING.marca
         AND SUSPENSION.invoice_id = BILLING.invoice_id    
     
     WHERE BILLING.agrupacion_canal = 'D2D'
           AND BILLING.status IN ('PAID', 'RECOLLECTED')
           AND BILLING.importe_facturado > 0
           AND proc = 'CARD2D'
           AND SUSPENSION.customer_id IS NULL
           AND DEALER.comisiona
           AND SFIDS.sfid_id IS NOT NULL
           AND BILLING.deactivation_date > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
           AND sfids.EnCartera=1

      --      AND sfids.airtime = 1
      


     
     QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING) ORDER BY LENGTH(id_comisionista) DESC) = 1
     )

WHERE COALESCE(comision, 0.0) > 0.0
)


;

/* Extraemos las líneas desactivadas en el mes con antigüedad de mas de 6 meses que van a descontar el precio de la cartera */



CREATE OR REPLACE TEMPORARY TABLE deactivations AS
(
SELECT
     BILLING.tariff_id,
     BILLING.tariff_ds,
     VENTAS.* EXCEPT(tariff_id, tariff_ds)
      


FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

INNER JOIN (SELECT *
            FROM `mm-commissions-reporting.TEMP.card2d_test` 

            UNION ALL

            (SELECT * EXCEPT (
                              proceso_sap, 
                              id_registro,
                              invoice_id,
                              sociedad,
                              bp,
                              cuenta_contable,
                              centro_coste,
                              documento_sap,
                              documento_sap_posicion,
                              fecha_contabilizacion,
                              creado,modificado,
                              id_factura_drive,
                              emails_acceso_trazabilidad,
                              cond_pago
                              )
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE CONCEPTO = 'C - Cartera'
            AND agrupacion_canal = 'D2D'
            AND service_type IN ('INTERNET','MOBILE','BROADBAND')
            AND id_mes < id_mes_pr
            QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id ORDER BY id_mes DESC) = 1)

            )BILLING
 ON CAST(VENTAS.phone_nm AS STRING) = BILLING.phone_nm
    AND VENTAS.customer_id = BILLING.customer_id


LEFT JOIN `mm-datamart-kd.SERVICES.semantic_kpi_services` INTRA
      ON CAST(INTRA.phone_nm AS STRING) = VENTAS.phone_nm
      AND INTRA.account_id = VENTAS.account_id
      AND INTRA.BRAND_DS IN ('MASMOVIL','YOIGO')
      AND INTRA.SEGMENT_DS IN ('BUSINESS','SOHO')
      AND INTRA.KPI= 'deactivation'

    

WHERE DATE_TRUNC(VENTAS.deactivation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND DATE_DIFF(VENTAS.deactivation_date, COALESCE(VENTAS.activation_date,'1969-01-01'), DAY) > 180
      AND deactivation_reason NOT IN ('CAMBIO DOMICILIO') 
      AND (INTRA.group_receiver IS NULL OR INTRA.group_receiver NOT IN ('GRUPO MASMOVIL', 'GRUPO ORANGE','GRUPO MASORANGE'))
      AND VENTAS.activation_date IS NOT NULL


QUALIFY ROW_NUMBER() OVER (PARTITION BY VENTAS.service_id, VENTAS.phone_nm, VENTAS.marca ORDER BY VENTAS.deactivation_date DESC, VENTAS.activation_date DESC) = 1
)
;

IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = "card2d_test_deactivations") = 0
THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_deactivations` OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS SELECT * FROM deactivations;

ELSE
INSERT INTO `mm-commissions-reporting.TEMP.card2d_test_deactivations` (SELECT * FROM deactivations);
END IF;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_bajas` AS
(
SELECT
      prefijo || '_P_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal AS canal
     ,'P - Cartera' AS concepto
     ,'UPFR' AS tipo_concepto
     ,0 as unidades

     ,CASE
          WHEN DEACTIVATIONS.service_type IN ('FIX', 'INTERNET','BROADBAND') THEN -120.00
          ELSE -30.00
      END AS comision

     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.id_comisionista AS sfid_id
     ,DEACTIVATIONS.seller AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,DEACTIVATIONS.marca
     ,DEACTIVATIONS.service_type
     ,DEACTIVATIONS.phone_nm
     ,DEACTIVATIONS.tariff_id
     ,DEACTIVATIONS.tariff_ds
     ,DEACTIVATIONS.service_id
     ,DEACTIVATIONS.account_id
     ,DEACTIVATIONS.customer_id
     ,DEACTIVATIONS.line_type_ds
     ,DEACTIVATIONS.bundle_type
     ,DEACTIVATIONS.technology_ds
     ,DEACTIVATIONS.billing_type_ds
     ,DEACTIVATIONS.sale_date

     ,CASE WHEN DEACTIVATIONS.activation_date = '9999-12-31' THEN DEACTIVATIONS.sale_date ELSE DEACTIVATIONS.activation_date END AS activation_date

     ,DEACTIVATIONS.deactivation_date
     ,DEACTIVATIONS.order_id
     ,DEACTIVATIONS.order_type_agg
     ,DEACTIVATIONS.cod_segmento
     ,DEACTIVATIONS.cod_marca
     ,DEACTIVATIONS.cod_tipo_contrato
     ,DEACTIVATIONS.cod_producto
     ,DEACTIVATIONS.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.card2d_test_deactivations` DEACTIVATIONS

     -- Añadimos relacion customer / sfid
      LEFT JOIN ( SELECT  SFID_ID, CUSTOMER_ID,CARTERIZADO,EnCartera,PHONE_NM
                  FROM `mm-commissions-reporting.TEMP.card2d_test_airtime`   -- TEST (antes FC_AIRTIME_LINEAS + filtro MES)
                  WHERE 1 = 1
                  -- AND EnCartera=1 --En cartera significa linea viva
                  AND SfidEstado='OK'
                  AND AIRTIME = 1
                  ) SFIDS
            ON cast(DEACTIVATIONS.phone_nm as string) = SFIDS.phone_nm

      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
      ON SFIDS.SFID_ID = DEALER.sfid_id  

WHERE DEACTIVATIONS.service_type IN ('INTERNET','MOBILE','BROADBAND')
      AND DEALER.comisiona
      AND SFIDS.sfid_id IS NOT NULL
      AND DEACTIVATIONS.billing_type_ds != 'PREPAID'
      AND DEACTIVATIONS.bundle_type != '2P' -- EXCLUIMOS 2P
      AND DEACTIVATIONS.tariff_id NOT IN ('7126','7127') AND DEACTIVATIONS.tariff_ds NOT LIKE '%GRATIS%' -- EXCLUIMOS LÍNEAS GRATUITAS
      AND (
    -- Cualquier CIF: entre 6 y menos de 24 meses
    (DATE_ADD(DEACTIVATIONS.activation_date, INTERVAL 6 MONTH)<= DEACTIVATIONS.deactivation_date AND DEACTIVATIONS.deactivation_date < DATE_ADD(DEACTIVATIONS.activation_date, INTERVAL 24 MONTH))

      OR
    -- CIF que no cumplen el obj de churn: a partir de 24 meses
    (CIF IN ('01179576K','B02918803','B06891469','B10786564','B13623624','B13862149','B13896410','B16441107','B16839458','B19461193','B40617136','B42530428','B55421127','B62681036','B64646995','B67311605','B70282652','B70366455','B70606926','B72401136','B74424714','B75376566','B80108186','B90381849','B90483793','B99454787') AND DEACTIVATIONS.deactivation_date >=DATE_ADD(DEACTIVATIONS.activation_date, INTERVAL 24 MONTH))
)

      -- AND EnCartera IS NULL



QUALIFY ROW_NUMBER() OVER (PARTITION BY DEACTIVATIONS.phone_nm, DEACTIVATIONS.marca ORDER BY LENGTH(DEALER.id_comisionista) DESC) = 1
)
;
--- Aplico la segmentación especial de la cartera

UPDATE `mm-commissions-reporting.TEMP.card2d_test` card2d
SET comision = card2d.comision * seg.porcentaje_cartera
FROM `mm-commissions-reporting.GS.gs_segmento_liga` seg
WHERE seg.cif = card2d.cif
AND card2d.id_mes = seg.id_mes
AND card2d.id_mes = id_mes_pr
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test_final` AS (
      SELECT * 
      FROM `mm-commissions-reporting.TEMP.card2d_test`

      UNION ALL

      SELECT * 
      FROM `mm-commissions-reporting.TEMP.card2d_test_bajas`


)
;

-- TEST: NO se inserta en transacciones
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.card2d_test_final), 'TEMP.card2d_test_final', 'ACTUALIZAR');

/* TEST: resumen del resultado */
SELECT concepto, COUNT(*) AS lineas, ROUND(SUM(comision), 2) AS comision
FROM `mm-commissions-reporting.TEMP.card2d_test_final`
GROUP BY concepto
ORDER BY concepto;

END IF;


/* Se ejecuta el proceso en modo ajuste. Se generan automáticamente el ajuste y la retrotracción */
IF ajuste = 1

THEN

SET prefijo = 'CARD2DAJ';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.card2d_test` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
(
SELECT *
FROM (
     SELECT
           prefijo || 'S_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,mes_liquidado
          ,id_mes_pr AS id_mes
          ,BILLING.agrupacion_canal
          ,DEALER.canal AS canal
          ,'Z - Cartera' AS concepto
          ,CONCEPTOS.tipo_concepto
          ,0 as unidades
     
          ,importe_facturado * 0.08 AS comision
     
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,BILLING.seller AS sfid_id
          ,BILLING.seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,BILLING.marca
          ,BILLING.service_type
          ,BILLING.phone_nm
          ,BILLING.tariff_id
          ,BILLING.tariff_ds
          ,BILLING.service_id
          ,BILLING.account_id
          ,BILLING.customer_id
          ,BILLING.line_type_ds
          ,BILLING.bundle_type
          ,BILLING.technology_ds
          ,BILLING.billing_type_ds
          ,BILLING.sale_date

          ,CASE WHEN BILLING.activation_date = '9999-12-31' THEN BILLING.sale_date ELSE BILLING.activation_date END AS activation_date

          ,BILLING.deactivation_date
          ,BILLING.order_id
          ,BILLING.order_type_agg
          ,BILLING.cod_segmento
          ,BILLING.cod_marca
          ,BILLING.cod_tipo_contrato
          ,BILLING.cod_producto
          ,BILLING.cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador

     FROM `mm-commissions-reporting.TEMP.card2d_test_billing` BILLING
     
     CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS, UNNEST(SPLIT(proceso, ',')) proc
     
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
              ON (
                 CASE WHEN BILLING.sfid_id != 'LB' THEN 
                                               (BILLING.sfid_id = DEALER.sfid_id 
                                               OR BILLING.seller = DEALER.sfid_id)
                 ELSE BILLING.seller = DEALER.sfid_id
                 END
                 )
                 AND BILLING.agrupacion_canal = DEALER.agrupacion_canal
     
     WHERE BILLING.agrupacion_canal = 'D2D'
           AND BILLING.status IN ('PAID', 'RECOLLECTED')
           AND BILLING.importe_facturado > 0
           AND proc = 'CARD2D'
           AND DEALER.comisiona
     
     QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING) ORDER BY LENGTH(id_comisionista) DESC) = 1
     )

WHERE COALESCE(comision, 0.0) > 0.0
)
UNION ALL
(
SELECT
      prefijo || 'P_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,DEACTIVATIONS.mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEACTIVATIONS.agrupacion_canal
     ,DEALER.canal AS canal
     ,'P - Cartera' AS concepto
     ,'UPFR' AS tipo_concepto
     ,0 as unidades

     ,CASE
          WHEN DEACTIVATIONS.service_type IN ('FIX', 'INTERNET','BROADBAND') THEN -120.00
          ELSE -30.00
      END AS comision

     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.id_comisionista AS sfid_id
     ,DEALER.id_comisionista AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,DEACTIVATIONS.marca
     ,DEACTIVATIONS.service_type
     ,DEACTIVATIONS.phone_nm
     ,DEACTIVATIONS.tariff_id
     ,DEACTIVATIONS.tariff_ds
     ,DEACTIVATIONS.service_id
     ,DEACTIVATIONS.account_id
     ,DEACTIVATIONS.customer_id
     ,DEACTIVATIONS.line_type_ds
     ,DEACTIVATIONS.bundle_type
     ,DEACTIVATIONS.technology_ds
     ,DEACTIVATIONS.billing_type_ds
     ,DEACTIVATIONS.sale_date

     ,CASE WHEN DEACTIVATIONS.activation_date = '9999-12-31' THEN DEACTIVATIONS.sale_date ELSE DEACTIVATIONS.activation_date END AS activation_date

     ,DEACTIVATIONS.deactivation_date
     ,DEACTIVATIONS.order_id
     ,DEACTIVATIONS.order_type_agg
     ,DEACTIVATIONS.cod_segmento
     ,DEACTIVATIONS.cod_marca
     ,DEACTIVATIONS.cod_tipo_contrato
     ,DEACTIVATIONS.cod_producto
     ,DEACTIVATIONS.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.card2d_test_deactivations` DEACTIVATIONS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON (DEACTIVATIONS.sfid_id = DEALER.sfid_id OR DEACTIVATIONS.seller = DEALER.sfid_id)
            AND DEACTIVATIONS.agrupacion_canal = DEALER.agrupacion_canal
     
WHERE DEALER.comisiona
     
QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca ORDER BY LENGTH(id_comisionista) DESC) = 1
)
UNION ALL
(
SELECT
      prefijo || 'R_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_liquidado
     ,id_mes_pr AS id_mes
     ,TRANSACCIONES.agrupacion_canal
     ,canal
     ,'Z - Cartera' AS concepto
     ,tipo_concepto
     ,0 as unidades
     ,importe_facturado * -1 AS comision
     ,DEALER.id_comisionista
     ,distribuidor
     ,sfid_id
     ,seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,billing_type_ds
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,order_id
     ,order_type_agg
     ,cod_segmento
     ,cod_marca
     ,cod_tipo_contrato
     ,cod_producto
     ,cod_canal
     ,campaign_code
     ,serial_number
     ,tax_base
     ,claim_code
     ,commission_id AS process_code
     ,comments
     ,facturador

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista
            AND BILLING.agrupacion_canal = DEALER.agrupacion_canal

WHERE TRANSACCIONES.agrupacion_canal = 'D2D'
      AND mes_liquidado BETWEEN PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)) AND PARSE_DATE('%Y%m', CAST(mes_fin AS STRING))
      AND estado = 'facturado'
      AND concepto IN ('C - Cartera', 'P - Cartera', 'Z - Cartera')
      AND DEALER.comisiona
)
)
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.card2d), 'TEMP.card2d', 'ACTUALIZAR');

END IF;


END