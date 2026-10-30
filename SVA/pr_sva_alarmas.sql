BEGIN

-- CALL `mm-commissions-reporting.SVA.pr_sva_alarmas`('2022-11-01')

DECLARE table_name, qry, month_name STRING;


CREATE OR REPLACE TEMPORARY TABLE alarmas AS

/*SELECT *
FROM `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working`
WHERE tipo_concepto = 'ALRM'

UNION ALL*/

SELECT DISTINCT
        record_id AS id_registro
  
       ,CASE WHEN UPPER(brand_ds) = 'PEPEPHONE' THEN '7100' ELSE 'X001' END AS sociedad
  
       ,CASE WHEN UPPER(brand_ds) = 'YOIGO' THEN SUBSTR(sale_dealer, 1, 2) ELSE sale_dealer END AS id_comisionista
  
       ,'DEA' as tipo_comisionista
       ,COALESCE(DEALERS_TELEVENTA.documento, DEALERS_EXCLUSIVO.documento, DEALERS_NO_EXCLUSIVO.CIF_PDV, '') AS CIF
       ,COALESCE(DEALERS_TELEVENTA.zona_fiscal, DEALERS_EXCLUSIVO.zona_fiscal) AS zona_fiscal    
       ,concept_type AS tipo_concepto
       ,concept AS descripcion_concepto
       ,qty AS uds
       ,base_amount AS importe_base
       ,'EUR' AS moneda
       ,'C' as via_pago
       ,COALESCE(DEALERS_TELEVENTA.condiciones_pago_sap, DEALERS_EXCLUSIVO.condiciones_pago_sap ) as cond_pago
  
       ,CASE alarmas.channel
                     WHEN 'DO' THEN '14'
                     WHEN 'WA' then '14'
                     WHEN 'CI' THEN '14'
                     WHEN 'OU' THEN '15'
                     WHEN 'XO' THEN '15'
                     WHEN 'XI' THEN '15'
                     WHEN 'XS' THEN '15'
                     WHEN 'XE' THEN '15'
                     WHEN 'XT' THEN '15'
                     WHEN 'XA' THEN '15'
                     WHEN 'DX' THEN '27'
                     WHEN 'BY' THEN '27'
                     WHEN 'KH' THEN '27'
                     WHEN 'LB' THEN '27'
                     WHEN 'LM' THEN '27'
                     WHEN 'LY' then '27'
                     WHEN 'MD' THEN '27'
                     WHEN 'TA' THEN '27'
        END AS cod_canal
  
       ,'014' AS cod_producto
       ,'99' AS cod_tipo_contrato
  
       ,CASE
            WHEN upper(brand_ds) = 'PEPEPHONE' THEN '19'
            WHEN upper(brand_ds) = 'MASMOVIL'  THEN '17'
            ELSE '99'
        END AS cod_marca
      
       ,'999' as cod_operador
  
       ,CASE
            WHEN UPPER(brand_ds) = 'GUUK'     THEN '10'
            WHEN UPPER(brand_ds) = 'LLAMAYA'  THEN '10'
            WHEN segment_ds = 'B2C'           THEN '10'
            WHEN segment_ds = 'SOHO'          THEN '12'
            WHEN segment_ds = 'B2B'           THEN '12'
            ELSE '10'
        END AS cod_segmento
        
       ,'C_MANUAL' as facturador
       
       ,CASE SUBSTR(concept, 1, 1)
             WHEN 'A' THEN 'A - Servicio base'
             WHEN 'B' THEN 'B - SVA'
             WHEN 'C' THEN 'C - Calidad'
             WHEN 'D' THEN 'D - Extracomisión'
             WHEN 'E' THEN 'E - Clawback'
             WHEN 'F' THEN 'F - Gestión de canal'
             WHEN 'G' THEN 'G - Gestión de canal GPV'
             WHEN 'H' THEN 'H - Clawback gestión de canal'
             WHEN 'R' THEN 'R - Recalculo periodo anterior'
             WHEN 'S' THEN 'S - Recalculo periodo anterior master'
             WHEN 'P' THEN 'P - Penalización'
             WHEN 'Y' THEN 'Y - Ajustes Master'
             WHEN 'Z' THEN 'Z - Ajustes'
        END as clasificacion_concepto
       
       ,alarmas.channel AS canal
       ,service_id AS subscription_id
       ,product_type_ds AS product_type
       ,bundle_type
       ,CAST(msisdn AS STRING) AS msisdn
       ,activation_date AS fecha_activacion
       ,deactivation_date AS fecha_baja
       ,account_id
       ,customer_id
       ,sale_dealer AS sfid_unico
       ,sale_dealer AS tienda
       ,COALESCE(DEALERS_TELEVENTA.distribuidor, DEALERS_EXCLUSIVO.distribuidor) AS distribuidor
       ,mes_pr AS fecha
       ,'Otros servicios' AS agrupacion_cod_tipo_contrato
       ,'Residencial' AS segmento
       ,COALESCE(DEALERS_TELEVENTA.razon_social, DEALERS_EXCLUSIVO.razon_social) AS razon_social
       ,COALESCE(DEALERS_TELEVENTA.nombre, DEALERS_EXCLUSIVO.nombre) AS nombre_comercio
       ,UPPER(brand_ds) AS marca
       ,service_id AS order_id
       ,CAST(NULL AS STRING) AS product_id
       ,CAST(NULL AS STRING) AS product
       ,CAST(NULL AS STRING) AS user_id
       -- revisar,CASE WHEN UPPER(brand_ds) = 'YOIGO' THEN user_id ELSE web_user END AS user_id

FROM `mm-commissions-reporting.SVA.gs_sva_alarmas` AS ALARMAS

LEFT JOIN `mm-commissions-reporting.TELEVENTA.DEALERS` AS DEALERS_TELEVENTA
        ON CASE WHEN UPPER(ALARMAS.brand_ds) = 'YOIGO' THEN SUBSTR(ALARMAS.sale_dealer, 1, 2) ELSE ALARMAS.sale_dealer END = DEALERS_TELEVENTA.billing_dealer

LEFT JOIN `mm-commissions-reporting.EXCLUSIVO.DEALERS` AS DEALERS_EXCLUSIVO
        ON CASE WHEN UPPER(ALARMAS.brand_ds) = 'YOIGO' THEN SUBSTR(alarmas.sale_dealer, 1, 2) ELSE ALARMAS.sale_dealer END = DEALERS_EXCLUSIVO.billing_dealer

        LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` AS DEALERS_NO_EXCLUSIVO
        ON CASE WHEN UPPER(ALARMAS.brand_ds) = 'YOIGO' THEN SUBSTR(alarmas.sale_dealer, 1, 2) ELSE ALARMAS.sale_dealer END = DEALERS_NO_EXCLUSIVO.sfid

LEFT JOIN `mm-commissions-reporting.TELEVENTA.CONCEPTOS_FACTURA` CONCEPTS_TELEVENTA
         ON alarmas.concept = CONCEPTS_TELEVENTA.concepto

LEFT JOIN `mm-commissions-reporting.EXCLUSIVO.CONCEPTOS_FACTURA` CONCEPTS_EXCLUSVIO
         ON alarmas.concept = CONCEPTS_EXCLUSVIO.concepto

LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` CONCEPTS_NO_EXCLUSVIO
         ON alarmas.concept = CONCEPTS_NO_EXCLUSVIO.concepto
;



SET month_name = REPLACE(CAST(mes_pr AS STRING), '-', '');
SET table_name = CONCAT('`mm-commissions-reporting.SVA.sva_alarmas_', month_name, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || table_name || ' AS SELECT * FROM ' || 'alarmas';
EXECUTE IMMEDIATE qry;


--CALL `mm-commissions-reporting.SVA.pr_sva_alarmas_sap`(mes_pr);


END