BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado DATE;
DECLARE id_mes_periodo_facturado INT64;


SET prefijo = 'CARCE';

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 month );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);

IF canales_pr IS NULL THEN SET canales_pr = ['EML', 'EYG', 'ENX', 'XS'];
END IF;

/*
CALL COMISIONES.pr_carce(202506,['XS']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carce_billing_status`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT invoice_no, status
FROM `mm-commissions-reporting.COBROS.payment_status_invoices`
QUALIFY ROW_NUMBER () OVER (PARTITION BY invoice_no ORDER BY order_by DESC) = 1 
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carce_billing_conceptos`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT billing_concept_type_ds, bill_id, billing_detail_ds, bill_item_updated
FROM `mm-datamart-kd.BILLING.dm_billing_concept_type`
group by 1,2,3,4
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carce_billing`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      'Exclusivo' AS agrupacion_canal
     ,CERES.sfid_id
     ,CERES.sfid_id AS seller
     ,'MYSIM' AS data_source_ds
     ,CERES.brand_ds AS marca

     ,CASE
          WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
          WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
          ELSE BILLING.service_type
      END AS service_type

     ,CAST(BILLING.phone_nm AS STRING) AS phone_nm
     ,BILLING.tariff_id
     ,BILLING.tariff_ds
     ,BILLING.service_id
     ,BILLING.account_id
     ,BILLING.customer_id
     ,BILLING.line_type_ds
     ,REPLACE(BILLING.bundle_type, 'ERROR', 'MO') AS bundle_type
     ,BILLING.technology_ds
     ,BILLING.billing_type_ds
     ,CAST(NULL AS DATE) AS sale_date
     ,CAST(NULL AS DATE) AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(BILLING.segment_ds, BILLING.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(BILLING.brand_ds) AS cod_marca

     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`
       (
       BILLING.billing_type_ds,

       CASE
           WHEN BILLING.service_type IN ('FIX', 'INTERNET')      THEN 'INTERNET'
           WHEN BILLING.service_type IN ('MOBILE', 'APPLEWATCH') THEN 'MOBILE'
           ELSE BILLING.service_type
       END,

       REPLACE(BILLING.bundle_type, 'ERROR', 'MO'),
       BILLING.technology_ds,
       BILLING.brand_ds,
       BILLING.line_type_ds
       ) AS cod_tipo_contrato

     ,'041' AS cod_producto

     ,'27' AS cod_canal
     ,COALESCE(BILLING_STATUS.status, 'PAID') AS status
     ,SUM(BILLING.imp_without_tax) AS importe_facturado
     ,CERES.CERES_I
     ,CERES.CERES_II

FROM `mm-datamart-kd.BILLING.billing_detail_emysim` BILLING

INNER JOIN (
           SELECT

                 CASE WHEN RFM.origin_customer_id IS NOT NULL THEN RFM.customer_id ELSE CERES_I_II.customer_id END AS customer_id
           
                ,CERES_I_II.brand_Ds
                ,ANY_VALUE(CERES_I_II.Tienda_carterizado) AS sfid_id
                ,MAX(CERES_I) CERES_I
                ,MAX(CERES_II) CERES_II
      --      FROM `mm-prepaid-reporting.Analisis_DG.CERES_pilot_db` CERES
      --      FROM `mm-prepaid-reporting.Analisis_DG.ZZCERES1_pilot_db_backup_20240601` CERES -- solo para comisiones de tiendas liqui ago
            FROM (
                  -- (SELECT CERES.customer_id, 1 as CERES_I, 0 as CERES_II, CERES.brand_Ds, CERES.Tienda_carterizado
                  -- FROM `mm-sales-reporting.EXPANSION.CERES_total_ID_base` CERES                  
                  -- WHERE CERES.gc_1 = 0
                  -- AND CERES.gc_1 IS NOT NULL
                  -- GROUP BY 1,2,3,4,5) -- CERES 1
          

                  -- UNION ALL 

                  
                  (SELECT CERES.customer_id, 0 as CERES_I, 1 as CERES_II, CERES.brand_Ds, CERES.Tienda_carterizado
                  FROM `mm-sales-reporting.EXPANSION.CERES_total_ID_base` CERES                             
                  WHERE CERES.gc_2 = 0
                  AND CERES.gc_2 IS NOT NULL                              
                  GROUP BY 1,2,3,4,5) -- CERES 2
                  ) CERES_I_II                                     
                  
            LEFT JOIN `mm-datamart-kd.RFM_YOIGO.migration_completed` RFM
                  ON CERES_I_II.customer_id = RFM.origin_customer_id AND CERES_I_II.brand_ds = 'YOIGO'
            GROUP BY 1,2  
                  ) CERES
                  ON BILLING.customer_id = CERES.customer_id AND BILLING.brand_ds = CERES.brand_Ds         

LEFT JOIN `mm-commissions-reporting.TEMP.carce_billing_conceptos` CONCEPTOS
         ON BILLING.bill_id = CONCEPTOS.bill_id

LEFT JOIN `mm-commissions-reporting.TEMP.carce_billing_status` BILLING_STATUS
         ON BILLING.invoice_id = BILLING_STATUS.invoice_no

WHERE data_month_id = id_mes_periodo_facturado 
      /*AND
        (
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA MOVIL
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type = 'MOBILE'
          AND (CONCEPTOS.bill_item_updated <> 'QUOTA_FIX' OR CONCEPTOS.bill_item_updated IS NULL)
          )
         OR
          (
          CONCEPTOS.billing_concept_type_ds = 'QUOTA'
          AND CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          AND BILLING.service_type IN ('MOBILE', 'APPLEWATCH')
          )
         ) -- DESCUENTO MOVIL
        OR
         (CONCEPTOS.billing_concept_type_ds IN ('BONO', 'BONO VOZ')) -- BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'BONO DISCOUNT') -- DESCUENTO BONO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'MOBILE') -- CONSUMO MOVIL
        OR 
         (
         CONCEPTOS.billing_concept_type_ds = 'QUOTA'
         AND BILLING.service_type IN ('FIX', 'INTERNET')
         AND CONCEPTOS.billing_detail_ds NOT IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
         ) -- CUOTA FIJO
        OR
         (
          (
          CONCEPTOS.billing_concept_type_ds IN ('CAPTA DISCOUNT', 'XSELL DISCOUNT', 'LOYALTY DISCOUNT', 'DISCOUNT TV', 'ENERGY DISCOUNT', 'QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          OR CONCEPTOS.billing_detail_ds IN ('QUOTA_DISCOUNT', 'QUOTA DISCOUNT')
          )
          AND (BILLING.service_type IN ('FIX', 'INTERNET') OR CONCEPTOS.bill_item_updated = 'QUOTA_FIX')
         ) -- DESCUENTO FIJO
        OR
         (CONCEPTOS.billing_concept_type_ds = 'USAGE' AND BILLING.service_type = 'FIX') -- CONSUMO FIJO
        )*/
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,29,30
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.carce` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT *
      ,prefijo || '_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
      FROM ( 
      
      SELECT
     'calculado' AS estado
     ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
     ,CAST(mes_string AS INT64) AS id_mes
     ,BILLING.agrupacion_canal
     ,DEALER.canal

     ,'D - Gestion Campana Multicanal' AS concepto

     ,'AIRT' AS tipo_concepto
     ,CASE WHEN BILLING.agrupacion_canal = 'TLV - Cross-sell' THEN CAST(NULL AS INT64) ELSE 1 END AS unidades

     ,SUM(CASE WHEN BILLING.agrupacion_canal = 'Exclusivo' THEN 
           CASE WHEN CERES_I = 1   THEN importe_facturado * 0.005 * 0.5
                WHEN CERES_II = 1  THEN importe_facturado * 0.005 * 0.5 END
                
           WHEN BILLING.agrupacion_canal = 'TLV - Cross-sell' THEN
           CASE --WHEN DEALER.id_comisionista IN ('CAROUT008', 'AV') AND CERES_I = 1  THEN importe_facturado * 0.005 * 0.5
            --     WHEN DEALER.id_comisionista IN ('CARIN008', 'MV') AND CERES_I = 1   THEN importe_facturado * 0.005 * 0.5
                WHEN DEALER.id_comisionista IN ('CAROUT008', 'AV') AND CERES_II = 1 THEN importe_facturado * 0.005 * 0.73
                WHEN DEALER.id_comisionista IN ('CARIN008', 'MV') AND CERES_II = 1  THEN importe_facturado * 0.005 * 0.27 END
     END) AS comision
     
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
     ,BILLING.activation_date
     ,BILLING.deactivation_date
     ,BILLING.order_id
     ,BILLING.order_type_agg
     ,BILLING.cod_segmento
     ,BILLING.cod_marca
     ,BILLING.cod_tipo_contrato
     ,BILLING.cod_producto
     ,BILLING.cod_canal
     ,CASE WHEN DEALER.id_comisionista IN ('CAROUT008','AV','CARIN008','MV') THEN 'Camp. piloto' END AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador
     

FROM (
     (
     SELECT
           * EXCEPT(agrupacion_canal, sfid_id, seller, cod_canal)
          ,agrupacion_canal
          ,sfid_id
          ,seller
          ,cod_canal
     FROM `mm-commissions-reporting.TEMP.carce_billing`
     )
     UNION ALL
     (
     SELECT
           * EXCEPT(agrupacion_canal,sfid_id, seller, cod_canal)
          ,'TLV - Cross-sell' AS agrupacion_canal
          ,'CAROUT008' AS sfid_id
          ,'CAROUT008' AS seller
          ,'15' AS cod_canal
     FROM `mm-commissions-reporting.TEMP.carce_billing`
     )
     UNION ALL
     (
     SELECT
           * EXCEPT(agrupacion_canal,sfid_id, seller, cod_canal)
          ,'TLV - Cross-sell' AS agrupacion_canal
          ,'CARIN008' AS sfid_id
          ,'CARIN008' AS seller
          ,'15' AS cod_canal
     FROM `mm-commissions-reporting.TEMP.carce_billing`
     )
     ) BILLING

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON (
            BILLING.sfid_id = DEALER.sfid_id 
            OR SUBSTR(BILLING.seller,1,2) = DEALER.sfid_id
            )
            AND BILLING.agrupacion_canal = DEALER.agrupacion_canal

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
      AND BILLING.importe_facturado > 0
      AND BILLING.service_type IN ('MOBILE', 'INTERNET')
      AND DEALER.canal = canal_pr
      AND DEALER.sfid_id NOT IN ('CAROUT026',
      'CAROUT031',
      'CAROUT035',
      'CAROUT036',
      'CAROUT037',
      'CAROUT038',
      'CAROUT039',
      'CAROUT040') --- Eliminamos Sfids de Camp.Piloto y Blindaje

GROUP BY 1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46
)
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr,(SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.carce), 'TEMP.carce', 'ACTUALIZAR');


END