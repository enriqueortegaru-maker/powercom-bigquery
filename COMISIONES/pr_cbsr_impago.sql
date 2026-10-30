BEGIN

DECLARE mes_string, prefijo STRING;

DECLARE mes_periodo_facturado_inicio, mes_periodo_facturado_fin  DATE;

DECLARE id_mes_liquidado INT64;


SET prefijo = 'CBSRIM';

SET mes_string = CAST(mes_int AS STRING);

SET mes_periodo_facturado_inicio = DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL  - 6 MONTH ); -- MES EN EL QUE SE DA DE ALTA EL SERVICIO

SET mes_periodo_facturado_fin = LAST_DAY(DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL -4 MONTH)); -- MES PARA VER LAS 3 PRIMERAS FACTURAS

SET id_mes_liquidado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_inicio) AS INT64); -- MES LIQUIDADO SOBRE EL QUE APLICA



-- CALL COMISIONES.pr_cbsr_impago (202609, ['DO','WA','XI']);



--- CREAMOS TABLA IMPAGOS AÑADIENDO EL DOCUMENT HASH ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.impagos` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS (

  SELECT 
  STATUS.*
  ,BILLING.account_id
  ,BILLING.phone_nm
  ,BILLING.document_hash 

  FROM `mm-commissions-reporting.COBROS.payment_status_invoices` STATUS
  LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_mo` BILLING
  ON STATUS.invoice_no = BILLING.invoice_id
  AND STATUS.company_name = BILLING.brand_ds

  WHERE BILLING.billing_date BETWEEN mes_periodo_facturado_inicio AND mes_periodo_facturado_fin -- Periodo a revisar
  QUALIFY ROW_NUMBER() OVER (PARTITION BY company_name,customer_id,phone_nm, invoice_no ORDER BY order_by DESC) = 1

  UNION ALL

    SELECT 
  'ORANGE' AS company
  ,STATUS.customer_id
  ,STATUS.company_name
  ,STATUS.invoice_id AS invoice_no
  ,'' as blart
  ,'REJECTED' AS status
  ,CAST (NULL AS DATE) AS fecha_registro
  ,1 as order_by
  ,CAST (NULL AS STRING) AS rechazo_descripcion
  ,CAST (NULL AS STRING) AS via_recobro_descripcion
  ,CAST (NULL AS STRING) AS block_type
  ,BILLING.account_id
  ,BILLING.phone_nm
  ,BILLING.document_hash 

  FROM `mm-commissions-reporting.TEMP.impago_orange`  STATUS
  LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_mo` BILLING
  ON STATUS.invoice_id = BILLING.invoice_id
  AND STATUS.company_name = BILLING.brand_ds

  WHERE BILLING.billing_date BETWEEN mes_periodo_facturado_inicio AND mes_periodo_facturado_fin -- Periodo a revisar
  QUALIFY ROW_NUMBER() OVER (PARTITION BY company_name,customer_id,phone_nm, BILLING.invoice_id ORDER BY external_id DESC) = 1
  
  )

;


--- TLV - DO ---
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DO','DOT')) THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.impagos_tlv_do`  
OPTIONS (
  expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 12 DAY)
)
AS (

SELECT 
 'CBSRIM' || '_' || mes_int || '_' || COALESCE(DEALER.canal, T.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
,'calculado' AS ESTADO
,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
,mes_int as id_mes
,T.agrupacion_canal
,T.canal
,CONCAT('E - Clawback', SUBSTR(T.concepto, 4)) AS concepto
,tipo_concepto
,unidades
,COMISION*-1 AS comision 
,T.id_comisionista
,T.distribuidor
,T.sfid_id
,T.seller
,DEALER.nombre_comercio
,DEALER.razon_social
,DEALER.cif
,DEALER.zona_fiscal
,COLLATE(T.marca, '') AS marca
,COLLATE(T.service_type, '') AS service_type
,T.phone_nm
,T.tariff_id
,T.tariff_ds
,T.service_id
,T.account_id
,T.customer_id
,T.line_type_ds
,T.bundle_type
,T.technology_ds
,T.billing_type_ds
,T.sale_date
,T.activation_date
,T.deactivation_date
,T.order_id
,T.order_type_agg
,T.cod_segmento
,T.cod_marca
,T.cod_tipo_contrato
,T.cod_producto
,T.cod_canal
,'Baja por impago' AS claim_code
,campaign_code
,T.serial_number
,T.tax_base
, REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
,'Baja por impago' AS comments
,'C_MANUAL' as facturador
,T.sociedad
,CURRENT_TIMESTAMP () as creado


-- FROM `mm-commissions-reporting.COMISIONES.transacciones`  T

FROM  (
       SELECT * FROM `mm-commissions-reporting.COMISIONES.transacciones_thadea` 

       UNION ALL

       SELECT * FROM `mm-commissions-reporting.COMISIONES.transacciones`
       WHERE (
              id_mes > 202601 --- MARCAS ORANGE, JAZZTEL Y SIMYO SE MIGRARON EN MAYO
              AND MARCA IN ('ORANGE', 'JAZZTEL','SIMYO')
            )

            OR MARCA IN ('MASMOVIL', 'YOIGO')
      ) T

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON T.ID_COMISIONISTA = DEALER.ID_COMISIONISTA
OR T.sfid_id = DEALER.sfid_id



LEFT JOIN  (
            --- CLAWBACKS ORIGEN POWER
            SELECT DISTINCT service_id , phone_nm, concepto FROM `mm-commissions-reporting.COMISIONES.transacciones` CBSR
            WHERE id_mes <= mes_int
            AND CONCEPTO LIKE 'E -%'
            AND (
                 canal IN ('DO')
               OR (
                canal = 'DOT' AND id_mes >= 202607 --- CANAL DOT APLICA DESDE JULIO 2026 QUE ES CUANDO MIGRA AL NUEVO MARCO
                )
                ) 
            AND (COMMENTS IS NULL OR COMMENTS !='Baja por impago')

            UNION ALL
            --- CLAWBACKS ORIGEN THADEA
            SELECT DISTINCT service_id , phone_nm, concepto FROM `mm-commissions-reporting.COMISIONES.transacciones_thadea` CBSR
            WHERE id_mes <= mes_int
            AND CONCEPTO LIKE 'E -%'
            AND canal = 'DO'
            
            ) CBSR_ANTERIOR
              ON CBSR_ANTERIOR.SERVICE_ID = T.SERVICE_ID
              AND CBSR_ANTERIOR.PHONE_NM = T.PHONE_NM
              AND CBSR_ANTERIOR.CONCEPTO = CONCAT('E - Clawback', SUBSTR(T.concepto, 4))



LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON T.account_id = VENTAS.account_id
AND T.customer_id = VENTAS.customer_id
AND T.MARCA = VENTAS.brand_ds
AND T.phone_nm = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.impagos`  I  
  ON (
      (
        I.company_name IN ('ORANGE','JAZZTEL','SIMYO') --- PARA MARCAS ORANGE CRUZAMOS POR HASH DOCUMENT
        AND I.document_hash = VENTAS.hash_document_number
      )
      OR
      (
        I.company_name IN ('MASMOVIL','YOIGO') --- PARA MARCAS GMM CRUZAMOS POR CUSTOMER_ID
        AND I.customer_id = VENTAS.customer_id
      )
  )
  AND CAST(I.phone_nm AS STRING) = T.phone_nm
  AND I.company_name = T.MARCA

CROSS JOIN UNNEST(canales_pr) canal_pr

  WHERE I.fecha_registro > T.activation_date
  AND I.status = 'REJECTED'
  AND T.id_mes = id_mes_liquidado
  AND DEALER.canal = canal_pr
  AND (
    DEALER.canal IN ('DO')
    OR (DEALER.canal = 'DOT' AND T.id_mes >= 202607 --- CANAL DOT APLICA DESDE JULIO 2026 QUE ES CUANDO MIGRA AL NUEVO MARCO
    )
    )
  AND T.concepto IN (
                    'A - Portabilidad Fijo',
                    'A - Portabilidad Movil Pospago',
                    'A - Servicio Fijo',
                    'A - Servicio Movil Pospago',
                    'B - Television',
                    'B - Television Premium',
                    'D - Dispositivo Captacion',
                    'D - Extracomision Segmentacion',
                    'D - OTT',
                    'D - Rappel'
                    )
    AND CBSR_ANTERIOR.service_id is null

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY T.CONCEPTO, T.SERVICE_ID
    ORDER BY I.fecha_registro DESC
) = 1
);
END IF;


--- TLV - INBOUND ('WA','CI','XI')

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('WA','XI','CI')) THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.impagos_tlv_inbound`  
OPTIONS (
  expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 12 DAY)
)
AS (

SELECT 
 'CBSRIM' || '_' || mes_int || '_' || COALESCE(DEALER.canal, T.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
,'calculado' AS ESTADO
,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
,mes_int as id_mes
,T.agrupacion_canal
,T.canal
,CONCAT('E - Clawback', SUBSTR(T.concepto, 4)) AS concepto
,tipo_concepto
,unidades
,COMISION*-1 AS comision 
,T.id_comisionista
,T.distribuidor
,T.sfid_id
,T.seller
,DEALER.nombre_comercio
,DEALER.razon_social
,DEALER.cif
,DEALER.zona_fiscal
,COLLATE(T.marca, '') AS marca
,COLLATE(T.service_type, '') AS service_type
,T.phone_nm
,T.tariff_id
,T.tariff_ds
,T.service_id
,T.account_id
,T.customer_id
,T.line_type_ds
,T.bundle_type
,T.technology_ds
,T.billing_type_ds
,T.sale_date
,T.activation_date
,T.deactivation_date
,T.order_id
,T.order_type_agg
,T.cod_segmento
,T.cod_marca
,T.cod_tipo_contrato
,T.cod_producto
,T.cod_canal
,'Baja por impago' AS claim_code
,campaign_code
,T.serial_number
,T.tax_base
, REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
,'Baja por impago' AS comments
,'C_MANUAL' as facturador
,T.sociedad
,CURRENT_TIMESTAMP () as creado


FROM  (
       SELECT * FROM `mm-commissions-reporting.COMISIONES.transacciones_thadea` 

       UNION ALL

       SELECT * FROM `mm-commissions-reporting.COMISIONES.transacciones`
       WHERE (
              id_mes > 202604 --- MARCAS ORANGE, JAZZTEL Y SIMYO SE MIGRARON EN MAYO
              AND MARCA IN ('ORANGE', 'JAZZTEL','SIMYO')
            )

            OR MARCA IN ('MASMOVIL', 'YOIGO')
      ) T



LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON T.ID_COMISIONISTA = DEALER.ID_COMISIONISTA
OR T.sfid_id = DEALER.sfid_id



LEFT JOIN  (
            --- CLAWBACKS ORIGEN POWER
            SELECT DISTINCT service_id , phone_nm, concepto FROM `mm-commissions-reporting.COMISIONES.transacciones` CBSR
            WHERE id_mes <= mes_int
            AND CONCEPTO LIKE 'E -%'
            AND (
                 canal IN ('WA','XI')
               OR (
                canal = 'CI' AND id_mes >= 202605 --- CANAL CI APLICA DESDE MAYO 202605 QUE ES CUANDO MIGRA AL NUEVO MARCO
                )
                )
            AND (COMMENTS IS NULL OR COMMENTS !='Baja por impago')

            UNION ALL
            --- CLAWBACKS ORIGEN THADEA
            SELECT DISTINCT service_id , phone_nm, concepto FROM `mm-commissions-reporting.COMISIONES.transacciones_thadea` CBSR
            WHERE id_mes <= mes_int
            AND CONCEPTO LIKE 'E -%'
            AND canal IN ('WA','XI')
            ) CBSR_ANTERIOR
              ON CBSR_ANTERIOR.SERVICE_ID = T.SERVICE_ID
              AND CBSR_ANTERIOR.PHONE_NM = T.PHONE_NM
              AND CBSR_ANTERIOR.CONCEPTO = CONCAT('E - Clawback', SUBSTR(T.concepto, 4))



LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON T.account_id = VENTAS.account_id
AND T.customer_id = VENTAS.customer_id
AND T.MARCA = VENTAS.brand_ds
AND T.phone_nm = VENTAS.phone_nm

LEFT JOIN `mm-commissions-reporting.TEMP.impagos`  I  
  ON (
      (
        I.company_name IN ('ORANGE','JAZZTEL','SIMYO')     --- PARA MARCAS ORANGE CRUZAMOS POR HASH DOCUMENT
        AND I.document_hash = VENTAS.hash_document_number
      )
      OR
      (
        I.company_name IN ('MASMOVIL','YOIGO')     --- PARA MARCAS GMM CRUZAMOS POR CUSTOMER ID
        AND I.customer_id = VENTAS.customer_id
      )
)
  AND CAST(I.phone_nm AS STRING) = T.phone_nm
  AND I.company_name = T.MARCA

CROSS JOIN UNNEST(canales_pr) canal_pr

  WHERE I.fecha_registro > T.activation_date
  AND I.status = 'REJECTED'
  AND T.id_mes = id_mes_liquidado
  AND DEALER.canal = canal_pr
  AND (
    DEALER.canal IN ('WA','XI')
    OR (DEALER.canal = 'CI' AND T.id_mes >= 202605
    )
    )
  AND T.concepto IN (
                    'A - Portabilidad Fijo',
                    'A - Portabilidad Movil Pospago',
                    'A - Servicio Fijo',
                    'A - Servicio Movil Pospago',
                    'B - Television',
                    'B - Television Premium',
                    'D - Dispositivo Captacion',
                    'D - Extracomision Segmentacion',
                    'D - OTT',
                    'D - Rappel'
                    )
  AND CBSR_ANTERIOR.service_id is null

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY T.CONCEPTO, T.SERVICE_ID
    ORDER BY I.fecha_registro DESC
) = 1
)
;
END IF;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cbsrim_final`  
OPTIONS (
  expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 12 DAY)
)
AS (
SELECT * 
FROM `mm-commissions-reporting.TEMP.impagos_tlv_do`  

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE CANAL = canal_pr

UNION ALL

SELECT * 
FROM `mm-commissions-reporting.TEMP.impagos_tlv_inbound` 

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE CANAL = canal_pr
)
;



CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CBSRIM', mes_int,  canales_pr , 'TEMP.cbsrim_final' , 'ACTUALIZAR');

END