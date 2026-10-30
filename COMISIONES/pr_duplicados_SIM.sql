BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN 
  SET canales_pr = ['ENK','EML','EYG','ENX','AVO'];

END IF;

/*
CALL COMISIONES.pr_duplicados_SIM(202604, ['AVO']);
*/


CREATE OR REPLACE TABLE TEMP.duplicados_SIM AS (
     SELECT
      'DUPL'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     -- ,CONCEPTOS.concepto
     -- ,CONCEPTOS.tipo_concepto
     --- INCLUIR EN CONTROL
     ,'B - Duplicado SIM' AS concepto 
     ,'DUSI' AS tipo_concepto
     ,1 AS unidades
     ,4 AS comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id
     ,VENTAS.user_store AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,VENTAS.brand_ds AS marca
     ,'MOBILE' AS service_type
     ,CAST(VENTAS.msisdn AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,CAST(NULL AS STRING) AS tariff_ds
     ,VENTAS.service_id
     ,CAST (NULL AS STRING) AS account_id 
     ,VENTAS.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,VENTAS.min_fecha_alta AS sale_date
     ,VENTAS.min_fecha_alta AS activation_date
     ,VENTAS.min_fecha_baja AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,'06' AS cod_marca
     ,'20' AS cod_tipo_contrato
     ,'039' AS cod_producto
     ,CANAL.cod_canal AS cod_canal 
     ,CAST (NULL AS STRING) AS campaign_code
     ,CAST (NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(VENTAS.brand_ds) AS sociedad 

FROM `mm-datamart-kd.SERVICES.personal_icc_base` VENTAS



LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            REPLACE(VENTAS.sfid_id, 'LB', '') = DEALER.sfid_id
            OR UPPER(SPLIT(VENTAS.user_store, '@')[0]) = DEALER.sfid_id
            OR VENTAS.user_store = DEALER.sfid_id
            OR VENTAS.sfid_id || '-' || VENTAS.user_store = REPLACE(DEALER.sfid_id, ' ', '')
            )
          AND DEALER.id_mes = id_mes_pr -- JOHANNA 20251210


LEFT JOIN `mm-commissions-reporting.GS.CANALES` CANAL
  ON DEALER.canal = CANAL.canal

         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE VENTAS.brand_ds = 'PEPEPHONE'
AND DATE_TRUNC(VENTAS.min_fecha_alta, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND DEALER.comisiona = true 
AND DEALER.canal = canal_pr
AND DATE_TRUNC(VENTAS.min_fecha_baja, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))


QUALIFY ROW_NUMBER() OVER (PARTITION BY  VENTAS.service_id ORDER BY VENTAS.sfid_id DESC ) =  1 
)

;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('DUPL', id_mes_pr, canales_pr, 'TEMP.duplicados_SIM', 'ACTUALIZAR')

;

END