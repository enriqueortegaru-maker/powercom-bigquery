BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU','WA', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN'];
END IF;



-- CALL COMISIONES.pr_energia_2025_osp (202511,['DO']);


----- TABLA ACTIVACIONES -----

CREATE OR REPLACE TABLE TEMP.energia 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY))AS (
     SELECT
      'OSPENR'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     --- INCLUIR EN CONTROL
     ,'B - Energia' AS concepto
     ,'CSEN' AS tipo_concepto
     ,1 AS unidades
     ,CASE WHEN DEALER.CANAL IN ('DO','OU','WA','XI','XO','XOF','XS','XSO','XSN','OUN','DON','XIN','CIN') AND VENTAS.affiliate_code LIKE '%batman%' THEN TARIFAS.energia_batman
          ELSE TARIFAS.energia END AS comision

     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,CASE WHEN UPPER(VENTAS.tenant_code) = 'PEPE' THEN 'PEPEENERGY'
           ELSE UPPER(VENTAS.tenant_code)
           END AS marca
     ,'ENERGY' AS service_type
     ,CAST (VENTAS.phone AS STRING) AS phone_nm
     ,SVA.service_type AS tariff_id
     ,VENTAS.affiliate_code AS tariff_ds
     ,CAST (VENTAS.id AS STRING) AS service_id
     ,VENTAS.cups_code AS  account_id 
     ,SVA.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,VENTAS.signup_date AS sale_date
     ,VENTAS.activation_date
     ,VENTAS.churn_date AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(SVA.segment_ds, COALESCE(SVA.brand_ds,'PEPEPHONE')) AS cod_segmento
     ,CASE WHEN tenant_code ='yoigo' THEN '16'
      WHEN tenant_code ='masmovil' THEN '17' 
      WHEN tenant_code ='pepe' THEN '19'
      WHEN tenant_code ='orange' THEN '29'
      WHEN tenant_code ='jazztel' THEN '35'
      END AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'014' AS cod_producto
     ,COALESCE(AGRUPACION.codigo_canal_sap, CANALES.cod_canal) AS cod_canal
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,CAST (NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(CASE
                                                       WHEN UPPER(VENTAS.tenant_code) = 'PEPE' THEN 'PEPEENERGY'
                                                       WHEN UPPER(VENTAS.tenant_code) = 'MASMOVIL' THEN 'MASMOVIL'
                                                       WHEN UPPER(VENTAS.tenant_code) = 'YOIGO' THEN 'YOIGO'
                                                       END) AS sociedad 


FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  VENTAS


LEFT JOIN `mm-soho-reporting.TEMPORALES_SOHO.sva_unificado` SVA
        ON SVA.service_id = CAST(VENTAS.id AS STRING)

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(SVA.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND SVA.master_channel_ds = AGRUPACION.master_channel_ds
            AND SVA.channel_ds = AGRUPACION.channel_ds
            AND SVA.subchannel_ds = AGRUPACION.subchannel_ds
            AND SVA.brand_ds = AGRUPACION.comm_brand_ds


LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            REPLACE(VENTAS.sfid_id, 'LB', '') = DEALER.sfid_id
            OR UPPER(SPLIT(VENTAS.author_id, '@')[0]) = DEALER.sfid_id
            OR VENTAS.user_store = DEALER.sfid_id
            OR VENTAS.sfid_id || '-' || VENTAS.author_id = REPLACE(DEALER.sfid_id, ' ', '')
            )
            AND DEALER.id_mes = id_mes_pr


INNER JOIN `mm-commissions-reporting.GS.CANALES` CANALES 
          ON DEALER.canal =  CANALES.CANAL

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas_energia` TARIFAS
          ON TARIFAS.CANAL = DEALER.canal
          AND id_mes_pr BETWEEN TARIFAS.mes_inicio AND TARIFAS.mes_fin

          AND (TARIFAS.marca IS NULL OR TARIFAS.marca = UPPER(VENTAS.tenant_code))
          AND (TARIFAS.sfid IS NULL OR TARIFAS.sfid = DEALER.sfid_id)
          AND (TARIFAS.campaign_code IS NULL OR TARIFAS.campaign_code = TLV_CROSS_SELL.campaign)

          -- AND (CASE WHEN DEALER.CANAL = 'WA' THEN  DEALER.sfid_id = TARIFAS.sfid ELSE TRUE END)
          -- AND (CASE WHEN DEALER.CANAL = 'DO' AND TARIFAS.sfid IS NOT NULL THEN  DEALER.sfid_id = TARIFAS.sfid ELSE TRUE END)
          -- AND (CASE WHEN DEALER.CANAL = 'OU' AND TARIFAS.sfid IS NOT NULL THEN  DEALER.sfid_id = TARIFAS.sfid ELSE TRUE END)
          -- AND (CASE WHEN DEALER.CANAL = 'PH' THEN (TARIFAS.marca = UPPER(VENTAS.tenant_code)) ELSE TRUE END)
          -- AND (CASE WHEN DEALER.CANAL IN ('XS','XSO') THEN (TARIFAS.campaign_code = TLV_CROSS_SELL.campaign) ELSE TRUE END)

         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(VENTAS.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
-- AND AGRUPACION.agrupacion_canal = DEALER.agrupacion_canal
-- AND VENTAS.tenant_code in ('yoigo','masmovil','pepe','orange','jazztel') 
AND VENTAS.tenant_code in ('orange','jazztel') 
AND DEALER.canal = canal_pr
AND DEALER.comisiona IS TRUE
AND TARIFAS.energia IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY VENTAS.cups_code ORDER BY VENTAS.sfid_id DESC ) =  1 )


; 

----- GESTION DE CANAL -----

CREATE OR REPLACE TABLE TEMP.energia_gestion_canal 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY))AS (
     SELECT
     'ENRGF'||'_'|| mes_string ||'_'|| ACTIVACIONES.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,ACTIVACIONES.canal
     ,REPLACE(concepto, 'B -', 'F - Gestion de canal') AS concepto
     ,tipo_concepto
     ,unidades

     ,TARIFAS.gestion_canal_energia AS comision

     ,MASTER.id_comisionista
     ,distribuidor
     ,sfid_id
     ,seller
     ,MASTER.nombre_comercio
     ,MASTER.razon_social
     ,MASTER.documento AS cif
     ,MASTER.zona_fiscal
     ,ACTIVACIONES.marca
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
     ,ACTIVACIONES.campaign_code
     ,serial_number
     ,tax_base
     ,claim_code
     ,process_code
     ,comments
     ,facturador
     ,sociedad
FROM `mm-commissions-reporting.TEMP.energia` ACTIVACIONES

LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
  ON ACTIVACIONES.distribuidor = MASTER.id_comisionista


LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas_energia` TARIFAS
          ON TARIFAS.CANAL = ACTIVACIONES.canal
          AND id_mes_pr BETWEEN TARIFAS.mes_inicio AND TARIFAS.mes_fin


WHERE TARIFAS.gestion_canal_energia IS NOT NULL
AND (ACTIVACIONES.CANAL IN ('ALTN','ALTNC','ALTNH') AND MASTER.documento IS NOT NULL)
 
)

;

--- INCENTIVOS ENERGIA (D - Rappel energia , D - Multiplicador energia)

CREATE OR REPLACE TABLE TEMP.energia_incentivos 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY))AS ( 

SELECT 
      'ENRGD'||'_'|| mes_string ||'_'|| ACTIVACIONES.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
    , estado
    , mes_liquidado
    , ACTIVACIONES.id_mes
    , agrupacion_canal
    , ACTIVACIONES.canal
    , CASE 
          WHEN TARIFAS.rappel_energia IS NOT NULL      THEN 'D - Rappel energia' 
          WHEN MULTIPLICADOR.MULTIPLICADOR IS NOT NULL THEN 'D - Multiplicador energia'
      END AS concepto
    , tipo_concepto
    , unidades
    , CASE 
          WHEN TARIFAS.rappel_energia IS NOT NULL      THEN TARIFAS.rappel_energia 
          WHEN MULTIPLICADOR.MULTIPLICADOR IS NOT NULL THEN MULTIPLICADOR.MULTIPLICADOR * ACTIVACIONES.COMISION - ACTIVACIONES.COMISION
      END AS comision
    , id_comisionista
    , distribuidor
    , ACTIVACIONES.sfid_id
    , seller
    , nombre_comercio
    , ACTIVACIONES.razon_social
    , ACTIVACIONES.cif
    , zona_fiscal
    , ACTIVACIONES.marca
    , service_type
    , phone_nm
    , tariff_id
    , tariff_ds
    , service_id
    , account_id
    , customer_id
    , line_type_ds
    , bundle_type
    , technology_ds
    , billing_type_ds
    , sale_date
    , activation_date
    , deactivation_date
    , order_id
    , order_type_agg
    , cod_segmento
    , cod_marca
    , cod_tipo_contrato
    , cod_producto
    , cod_canal
    , ACTIVACIONES.campaign_code
    , serial_number
    , tax_base
    , claim_code
    , process_code
    , comments
    , facturador
    , sociedad

FROM `mm-commissions-reporting.TEMP.energia` ACTIVACIONES


LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas_energia` TARIFAS
          ON TARIFAS.CANAL = ACTIVACIONES.canal
          AND id_mes_pr BETWEEN TARIFAS.mes_inicio AND TARIFAS.mes_fin

          AND (CASE WHEN ACTIVACIONES.CANAL = 'DO' AND TARIFAS.rappel_energia IS NOT NULL THEN  ACTIVACIONES.sfid_id = TARIFAS.sfid ELSE TRUE END)

          AND (CASE WHEN ACTIVACIONES.CANAL IN ('XS','XSO') THEN (ACTIVACIONES.campaign_code = TARIFAS.campaign_code) ELSE TRUE END)

          AND (CASE WHEN ACTIVACIONES.CANAL IN ('XI','XO','XOF') THEN ACTIVACIONES.sfid_id = TARIFAS.sfid ELSE TRUE END)

LEFT JOIN `mm-commissions-reporting.COMISIONES.multiplicadores_luz` MULTIPLICADOR
     ON UPPER(ACTIVACIONES.seller) = MULTIPLICADOR.sfid_id and MULTIPLICADOR.id_mes = id_mes_pr


WHERE (TARIFAS.rappel_energia IS NOT NULL OR MULTIPLICADOR.MULTIPLICADOR IS NOT NULL)
AND (TARIFAS.rappel_energia >0 OR MULTIPLICADOR.MULTIPLICADOR >0)


)
;

---- CLAWBACK  ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.energia_clawback_deactivation_date` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY))AS
(
SELECT
      TRANSACCIONES.* EXCEPT(deactivation_date)
     ,DEACTIVATIONS.churn_date AS deactivation_date
      
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
           AND concepto in ('B - Energia','D - Rappel energia')
           AND estado = 'facturado'
           AND id_mes < id_mes_pr
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.energia`
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.energia_gestion_canal`
     ) TRANSACCIONES

LEFT JOIN `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  DEACTIVATIONS
         ON TRANSACCIONES.service_id =CAST (DEACTIVATIONS.id AS STRING)
            AND TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE DATE_TRUNC(DEACTIVATIONS.churn_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
      AND DEACTIVATIONS.churn_date <= DATE_ADD(COALESCE(TRANSACCIONES.activation_date,'1969-01-01'), INTERVAL 180 DAY)
      AND TRANSACCIONES.canal = canal_pr
      AND(
          -- Caso especial para campaign_code = 'Energia OUT'
          ( (TRANSACCIONES.campaign_code = 'Energia OUT' AND TRANSACCIONES.concepto = 'B - Energia' AND TRANSACCIONES.activation_date > '2025-07-01')
               OR
            (TRANSACCIONES.concepto = 'D - Rappel energia' AND TRANSACCIONES.activation_date < '2025-07-01')
          )

          OR

          (TRANSACCIONES.campaign_code != 'Energia OUT' OR TRANSACCIONES.campaign_code IS NULL)
         )

QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.commission_id
                          ORDER BY CASE WHEN TRANSACCIONES.account_id = DEACTIVATIONS.cups_code THEN 1 ELSE 2 END ASC,
                                   DEACTIVATIONS.churn_date ASC
                          ) = 1
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.energia_clawback_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
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
     
FROM `mm-commissions-reporting.TEMP.energia_clawback_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.energia_clawback_dealer`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(
                            canal,
                            comision,
                            commission_id,
                            id_comisionista,
                            campaign_code
                            )
     
     ,'OSPCENR' || '_' || mes_string || '_' || COALESCE(DEALER.canal, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int(id_mes_pr) AS mes_liquidado
     ,id_mes_pr as id_mes
     ,1 AS unidades

     ,COALESCE(DEALER.canal, TRANSACCIONES.canal) AS canal

     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback_energia` (
        DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) + 1
       ,COALESCE(DEALER.canal, TRANSACCIONES.canal)
       ,TRANSACCIONES.id_comisionista
      )
      * TRANSACCIONES.comision AS comision
     
     ,CASE
          WHEN TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'BYMOVIL'
          ELSE COALESCE(MASTER.id_comisionista, DEALER.id_comisionista)
      END AS id_comisionista

     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.cif, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.distribuidor
     ,TLV_CROSS_SELL.campaign AS campaign_code
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.energia_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.agrupacion_canal = DEALER.agrupacion_canal AND TRANSACCIONES.id_comisionista = DEALER.sfid_id AND DEALER.comisiona

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON TRANSACCIONES.id_comisionista = MASTER.id_comisionista AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'

WHERE DEALER.id_comisionista IS NOT NULL OR MASTER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.energia_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
(
SELECT
      CLWB.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.energia_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.energia_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) ENER
          LEFT JOIN `mm-commissions-reporting.TEMP.energia_clawback_deactivation_date` TRANSACCIONES
                   ON REPLACE(ENER, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0
)
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('OSPENR', id_mes_pr, canales_pr , 'TEMP.energia' , 'ACTUALIZAR');
    
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('ENRGF', id_mes_pr, canales_pr, 'TEMP.energia_gestion_canal', 'ACTUALIZAR');

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('ENRGD', id_mes_pr, canales_pr, 'TEMP.energia_incentivos', 'ACTUALIZAR');

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('OSPCENR', id_mes_pr, canales_pr, 'TEMP.energia_clawback', 'ACTUALIZAR');

END