BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['OSPNIN','OSPNXSN','XSO','DO','WA','XI','OUO','OSPNOUN','OUOC','OUOV'];
END IF;




-- CALL COMISIONES.pr_sva_osp (202606,['XSO']);


-- ACTIVACIONES --
CREATE OR REPLACE TABLE TEMP.sva_osp AS (
     SELECT
      'SVAOSB'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal

     ,'B - SVA' AS concepto 

     ,'UPFR' AS tipo_concepto
     ,1 AS unidades
     ,CASE 
          WHEN DEALER.CANAL IN ('XSO','OSPNXSN') AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') AND VENTAS.PRODUCT_ID = '13884' THEN  2.00 -- Google One Basic
          WHEN DEALER.CANAL IN ('XSO','OSPNXSN') AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') AND VENTAS.PRODUCT_ID = '13885' THEN 10.00 -- Google AI Plus Resi
          WHEN DEALER.CANAL IN ('XSO','OSPNXSN') AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') AND VENTAS.PRODUCT_ID = '13886' THEN 20.00 -- Google AI Pro
          WHEN DEALER.CANAL IN ('XSO','OSPNXSN') AND TLV_CAMP.campaign IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') AND VENTAS.PRODUCT_ID = '13887' THEN 10.00 -- Google AI Plus Soho

          WHEN DEALER.CANAL IN ('DO','WA','XI') AND VENTAS.PRODUCT_ID = '13884' THEN  4.00 -- Google One Basic
          WHEN DEALER.CANAL IN ('DO','WA','XI') AND VENTAS.PRODUCT_ID = '13885' THEN 20.00 -- Google AI Plus Resi
          WHEN DEALER.CANAL IN ('DO','WA','XI') AND VENTAS.PRODUCT_ID = '13886' THEN 44.00 -- Google AI Pro
          WHEN DEALER.CANAL IN ('DO','WA','XI') AND VENTAS.PRODUCT_ID = '13887' THEN 20.00 -- Google AI Plus Soho

          -- TLV - OUTBOUND --
          WHEN DEALER.CANAL IN ('OUO','OSPNOUN') AND TLV_CAMP.campaign IN ('COLD CALLING CAPTA RES TRADICIONAL') AND VENTAS.PRODUCT_ID = '13884' THEN  4.00 -- Google One Basic
          WHEN DEALER.CANAL IN ('OUO','OSPNOUN') AND TLV_CAMP.campaign IN ('COLD CALLING CAPTA RES TRADICIONAL') AND VENTAS.PRODUCT_ID = '13885' THEN 20.00 -- Google AI Plus Resi
          WHEN DEALER.CANAL IN ('OUO','OSPNOUN') AND TLV_CAMP.campaign IN ('COLD CALLING CAPTA RES TRADICIONAL') AND VENTAS.PRODUCT_ID = '13886' THEN 44.00 -- Google AI Pro
          WHEN DEALER.CANAL IN ('OUO','OSPNOUN') AND TLV_CAMP.campaign IN ('COLD CALLING CAPTA RES TRADICIONAL') AND VENTAS.PRODUCT_ID = '13887' THEN 20.00 -- Google AI Plus Soho
     ELSE TARIFAS.COMISION END AS comision
     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,COALESCE(VENTAS.seller, DEALER.id_comisionista) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,VENTAS.brand_ds AS marca
     ,VENTAS.service_type
     ,VENTAS.phone_nm
     ,VENTAS.product_id AS tariff_id
     ,VENTAS.product AS tariff_ds
     ,VENTAS.service_id
     ,VENTAS.account_id 
     ,VENTAS.customer_id
     ,VENTAS.line_type_ds
     ,VENTAS.bundle_type
     ,VENTAS.technology_ds
     ,VENTAS.billing_type_ds
     ,VENTAS.order_date AS  sale_date
     ,VENTAS.activation_date
     ,VENTAS.deactivation_date
     ,VENTAS.order_id
     ,VENTAS.order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'999' AS cod_producto
     ,VENTAS.cod_canal  
     ,TLV_CAMP.campaign AS campaign_code
     ,CAST (NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(VENTAS.brand_ds) AS sociedad 

FROM `mm-commissions-reporting.COMISIONES.v_servicio_svas_osp` VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
ON VENTAS.sfid_id = DEALER.sfid_id
AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign`  TLV_CAMP
         ON DEALER.id_comisionista = TLV_CAMP.id_comisionista AND DEALER.canal = TLV_CAMP.canal



LEFT JOIN  `mm-commissions-reporting.GS.SVA_TARIFAS_TLV_NEGOCIOS` TARIFAS
ON VENTAS.PRODUCT_ID = TARIFAS.PRODUCT_ID
AND VENTAS.PRODUCT = TARIFAS.PRODUCT
AND DEALER.canal = TARIFAS.CANAL
AND VENTAS.brand_ds = TARIFAS.MARCA
         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(VENTAS.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND DEALER.comisiona = true
AND DEALER.canal = canal_pr
AND (TARIFAS.COMISION IS NOT NULL OR TARIFAS.COMISION > 0)
 
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY  VENTAS.service_id ORDER BY VENTAS.sfid_id DESC ) =  1 

)
;

-- DESACTIVACIONES -- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_osp_clawback_deactivation_date`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date)
     ,DEACTIVATIONS.deactivation_date
      
FROM (
     SELECT
           commission_id
          ,estado
          ,mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,concepto
          ,tipo_concepto
          ,unidades
          ,comision
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
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
          ,process_code
          ,comments
          ,facturador
          ,sociedad
     
     FROM `mm-commissions-reporting.COMISIONES.transacciones`
     WHERE DATE_TRUNC(activation_date, MONTH) BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 7 MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND estado = 'facturado'
      AND commission_id LIKE 'SVAOS%'
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.sva_digital` 
     
     
     ) TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_servicio_svas_osp` DEACTIVATIONS
         ON TRANSACCIONES.service_id = DEACTIVATIONS.service_id
            AND TRANSACCIONES.marca = DEACTIVATIONS.brand_ds
            AND TRANSACCIONES.account_id = DEACTIVATIONS.account_id
            AND TRANSACCIONES.customer_id = DEACTIVATIONS.customer_id
            AND TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
      AND DEACTIVATIONS.deactivation_date <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,'1969-01-01'), INTERVAL 180 DAY)
      AND TRANSACCIONES.canal = canal_pr
      

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.deactivation_date ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_osp_clawback_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - Clawback ' ELSE 'E - Clawback ' END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,TRANSACCIONES.sociedad
     ,MAX(TRANSACCIONES.bundle_type) AS bundle_type
     ,MAX(TRANSACCIONES.campaign_code) AS campaign_code
     ,MAX(TRANSACCIONES.line_type_ds) AS line_type_ds
     ,MAX(TRANSACCIONES.order_id) AS order_id
     ,MAX(TRANSACCIONES.order_type_agg) AS order_type_agg
     ,MAX(TRANSACCIONES.serial_number) AS serial_number
     ,MAX(TRANSACCIONES.tariff_ds) AS tariff_ds
     ,MAX(TRANSACCIONES.tariff_id) AS tariff_id
     ,MAX(TRANSACCIONES.tax_base) AS tax_base
     ,MAX(TRANSACCIONES.technology_ds) AS technology_ds
     ,MAX(TRANSACCIONES.comments) AS comments
     ,SUM(TRANSACCIONES.comision) AS comision
     ,ARRAY_AGG(TRANSACCIONES.commission_id) AS commission_id
     
FROM `mm-commissions-reporting.TEMP.sva_osp_clawback_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_osp_clawback_dealer`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(
                            canal,
                            comision,
                            commission_id,
                            id_comisionista,
                            campaign_code
                            )
     
     ,'SVAOSE' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int(id_mes_pr) AS mes_liquidado
     ,id_mes_pr as id_mes
     ,1 AS unidades

     ,COALESCE(DEALER.canal, TRANSACCIONES.canal) AS canal

     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback` (
        DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) + 1
       ,COALESCE(DEALER.canal, TRANSACCIONES.canal)
       ,TRANSACCIONES.tariff_ds
      )
      * TRANSACCIONES.comision AS comision
     
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.distribuidor
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.sva_osp_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_osp_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.* 
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.sva_osp_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.sva_osp_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) STRE
          LEFT JOIN `mm-commissions-reporting.TEMP.sva_osp_clawback_deactivation_date` TRANSACCIONES
                   ON REPLACE(STRE, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0)
;



--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SVAOSB', id_mes_pr, canales_pr, 'TEMP.sva_osp', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SVAOSE', id_mes_pr, canales_pr, 'TEMP.sva_osp_clawback', 'ACTUALIZAR');

END