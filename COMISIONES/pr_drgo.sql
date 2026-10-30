BEGIN

DECLARE sql, mes_string, prefijo STRING;

SET mes_string = CONCAT(CAST(mes_int AS STRING), '01');

SET prefijo = 'DRGO';


--CALL `mm-commissions-reporting.COMISIONES.pr_drgo`(202402, ['EML', 'EYG']);


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.drgo` AS
SELECT
      prefijo||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m%d', mes_string) AS mes_liquidado
     ,mes_int AS id_mes
     ,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) AS agrupacion_canal
     ,DEALER.canal
     ,concepto
     ,tipo_concepto
     ,1 AS unidades
     
     ,CASE WHEN concepto = 'B - Doctor Go' THEN 8
           WHEN concepto = 'F - Doctor Go' THEN 1
      END AS comision
     
     ,CASE WHEN SUBSTR(concepto, 1, 1) IN ('F','H') AND DEALER.agrupacion_canal = 'No Exclusivo' THEN MASTER.id_comisionista ELSE DEALER.id_comisionista END AS id_comisionista
     ,distribuidor
     ,sfid AS sfid_id
     ,sfid AS seller

     ,CASE WHEN SUBSTR(concepto, 1, 1) IN ('F','H') AND DEALER.agrupacion_canal = 'No Exclusivo' THEN MASTER.nombre_comercio ELSE DEALER.nombre_comercio END AS nombre_comercio
     ,CASE WHEN SUBSTR(concepto, 1, 1) IN ('F','H') AND DEALER.agrupacion_canal = 'No Exclusivo' THEN MASTER.razon_social ELSE DEALER.razon_social END AS razon_social
     ,CASE WHEN SUBSTR(concepto, 1, 1) IN ('F','H') AND DEALER.agrupacion_canal = 'No Exclusivo' THEN MASTER.cif ELSE DEALER.cif END AS cif
     ,CASE WHEN SUBSTR(concepto, 1, 1) IN ('F','H') AND DEALER.agrupacion_canal = 'No Exclusivo' THEN MASTER.zona_fiscal ELSE DEALER.zona_fiscal END AS zona_fiscal
     
     ,'YOIGO' AS marca
     ,'INSURANCE' AS service_type
     ,CAST(msisdn AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,CAST(NULL AS STRING) AS tariff_ds
     ,CAST(NULL AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,DATE(fecha_venta) AS sale_date
     ,DATE(fecha_activacion) AS activation_date
     ,DATE(fecha_baja) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,'10' AS cod_segmento
     ,'01' AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'011' AS cod_producto
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(channel_ds, subchannel_ds) AS cod_canal
      --- informacion adicional ---
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`('YOIGO') AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_doctor_go` DOCTOR

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CONCEPTOS.proceso = 'DRGO'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON DOCTOR.sfid = DEALER.sfid_id 
            OR SUBSTR(DOCTOR.sfid, 1, 2) = DEALER.sfid_id
             
LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE CONCEPTOS.proceso = 'DRGO'
      AND DATE_TRUNC(DATE(fecha_activacion), MONTH) = PARSE_DATE('%Y%m%d', mes_string)
      AND DATE(fecha_activacion) <= COALESCE(DATE(fecha_baja), '9999-12-31')
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona

QUALIFY ROW_NUMBER() OVER (PARTITION BY msisdn, concepto ORDER BY DEALER.cif NULLS LAST) = 1
;


---- Tabla de Clawback ----

SET prefijo = 'DRCB';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.drgo_clawback` AS
SELECT
      TRANSACCIONES.* EXCEPT(concepto, comision, commission_id, estado, mes_liquidado, deactivation_date, bundle_type, cod_producto, facturador, campaign_code, comments, id_mes)
     ,prefijo||'_'||mes_string||'_'||TRANSACCIONES.canal||'_'||ROW_NUMBER () OVER () AS commission_id
     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF(DATE(DOCTOR.fecha_baja), TRANSACCIONES.activation_date, DAY), canal,TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision AS comision

     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'S', 'Y')      THEN 'H - Doctor Go'
           WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('F', 'S', 'Y')  THEN 'E - Doctor Go'
      END AS concepto

     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m%d', mes_string) AS mes_liquidado
     ,mes_int AS id_mes
     ,DOCTOR.fecha_baja AS deactivation_date
     ,CAST(NULL AS STRING) AS bundle_type
     ,'011' AS cod_producto
     ,'C_MANUAL' AS facturador
     ,campaign_code

     ,'Factura cargo retrotraído en un '|| REPLACE(CAST(-100 * `mm-commissions-reporting.COMISIONES.f_comision_clawback`
     (DATE_DIFF(DATE(DOCTOR.fecha_baja), TRANSACCIONES.activation_date, DAY), canal,TRANSACCIONES.tariff_ds) AS STRING), '.', '') || '%: ' || TRANSACCIONES.invoice_id AS comments

FROM (
     SELECT
           *
          ,1 AS rank

     FROM (
          SELECT
                * EXCEPT(comision)
               ,SUM(comision) OVER (PARTITION BY phone_nm, marca) AS comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE service_type = 'INSURANCE'
                AND (SUBSTR(commission_id, 1, 2) = 'DR' OR UPPER(concepto) LIKE '%DOCTOR%GO%')
                AND SUBSTR(concepto,1,1) NOT IN ('F', 'H', 'S', 'Y')
                AND estado = 'facturado'
          )
     WHERE comision > 0
     QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, marca ORDER BY concepto ASC) = 1

     UNION ALL

     SELECT
           *
          ,1 AS rank
     FROM (
          SELECT
                * EXCEPT(comision)
               ,SUM(comision) OVER (PARTITION BY phone_nm, marca) AS comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE service_type = 'INSURANCE'
                AND (SUBSTR(commission_id, 1, 2) = 'DR' OR UPPER(concepto) LIKE '%DOCTOR%GO%')
                AND (SUBSTR(concepto, 1, 1) IN ('F', 'H', 'S', 'Y') OR concepto LIKE ('%estion%'))
                AND estado = 'facturado'
          )
     WHERE comision > 0
     QUALIFY RANK() OVER (PARTITION BY phone_nm, marca ORDER BY concepto ASC) = 1

     UNION ALL

     SELECT
           * EXCEPT(comision, sociedad)
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
          ,CAST(NULL AS STRING) AS bp
          ,CAST(NULL AS STRING) AS cuenta_contable
          ,CAST(NULL AS STRING) AS centro_coste
          ,CAST(NULL AS STRING) AS documento_sap
          ,CAST(NULL AS STRING) AS documento_sap_posicion
          ,CAST(NULL AS STRING) AS fecha_contabilizacion
          ,CAST(NULL AS TIMESTAMP) AS creado
          ,CAST(NULL AS TIMESTAMP) AS modificado
          ,CAST(NULL AS STRING) AS id_factura_drive
          ,NULL AS emails_acceso_trazabilidad
          ,comision
          ,2 AS rank

     FROM `mm-commissions-reporting.TEMP.drgo`
     
     WHERE DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH) = PARSE_DATE('%Y%m%d', mes_string)
     ) TRANSACCIONES

INNER JOIN `mm-commissions-reporting.COMISIONES.v_doctor_go` DOCTOR
          ON TRANSACCIONES.phone_nm = CAST(DOCTOR.msisdn AS STRING)

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE DATE_TRUNC(COALESCE(DATE(DOCTOR.fecha_baja), '9999-12-31'), MONTH) = PARSE_DATE('%Y%m%d', mes_string)
      AND TRANSACCIONES.activation_date <= DATE(DOCTOR.fecha_baja)
      AND TRANSACCIONES.canal = canal_pr
      AND `mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF(DATE(DOCTOR.fecha_baja), TRANSACCIONES.activation_date, DAY), canal,TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision != 0
      
QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, concepto ORDER BY rank ASC) = 1
;


--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('DRGO_', mes_int, canales_pr, 'TEMP.drgo', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('DRCB_', mes_int, canales_pr, 'TEMP.drgo_clawback', 'ACTUALIZAR');


END