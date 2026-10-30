begin

declare sql, prefijo, mes_string string;

declare nuevo_MR ARRAY<STRING>;

set mes_string = CAST(id_mes_pr as string);

set prefijo = 'ACTIX';

set modo = IF(modo IS NULL, 'ACTUALIZAR', modo);

set nuevo_MR = ['ENK','ENKO'];

set canales_pr = coalesce (canales_pr, 
(select array_agg (canal) from `mm-commissions-reporting.GS.CANALES` where agrupacion_canal = 'Exclusivo')
);

/*
call  COMISIONES.pr_acti_exclusivo (202609, ['ENKO','ENXO'],NULL);
*/


-- Migraciones PREPAGO A POSTPAGO

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.migraciones_pre_post_exc` AS

WITH POS_PRE_90_DIAS AS (
  SELECT ACTIVACIONES.phone_nm, ACTIVACIONES.customer_id, ACTIVACIONES.account_id, ACTIVACIONES.activation_date, POS_PRE.activation_date, POS_PRE.deactivation_date, ACTIVACIONES.customer_id, POS_PRE.customer_id
  FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
  
  INNER JOIN (SELECT * 
          --     FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
              FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` 
              WHERE order_type_agg = 'MIGRACION POSTPAGO A PREPAGO'
              AND activation_date >= '2026-06-01'
             ) POS_PRE
     ON ACTIVACIONES.phone_nm = CAST(POS_PRE.phone_nm AS STRING) -- Cruzamos sólo por phone_nm porque account y customer cambian en algunos casos
  
  WHERE TRUE
  AND ACTIVACIONES.canal IN UNNEST (nuevo_MR)
  AND ACTIVACIONES.id_mes = id_mes_pr
  AND ACTIVACIONES.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO'
  AND DATE_DIFF(ACTIVACIONES.activation_date, POS_PRE.deactivation_date, DAY) <= 90
)

SELECT 
     ACTIVACIONES.phone_nm
     ,ACTIVACIONES.service_id
     ,ACTIVACIONES.service_type
     ,CASE
          WHEN ACTIVACIONES.marca IN ('YOIGO', 'MASMOVIL')          THEN FACTURACION.tariff_id
          WHEN ACTIVACIONES.marca IN ('ORANGE', 'JAZZTEL', 'SIMYO') THEN ACTIVACIONES.tariff_id
      END AS tariff_id

     ,CASE
          WHEN ACTIVACIONES.marca IN ('YOIGO', 'MASMOVIL')          THEN REGEXP_REPLACE(NORMALIZE(FACTURACION.tariff_ds, NFD), r'\pM', '')
          WHEN ACTIVACIONES.marca IN ('ORANGE', 'JAZZTEL', 'SIMYO') THEN ACTIVACIONES.tariff_ds
      END AS tariff_ds

     ,ACTIVACIONES.brand_ds AS marca
     -- ,FACTURACION.data_month_id
     ,MIGRACIONES_CONTRATO.service_id AS service_id_migracion_contrato
     ,MIGRACIONES_CONTRATO.line_type_ds AS line_type_migracion_contrato

FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES

LEFT JOIN (SELECT  *
           FROM `mm-commissions-reporting.COMISIONES.activaciones`
           WHERE order_type_agg = 'MIGRACION CONTRATO'
           AND id_mes = id_mes_pr 
           AND canal IN UNNEST (nuevo_MR)
           ) MIGRACIONES_CONTRATO 
           ON MIGRACIONES_CONTRATO.phone_nm = ACTIVACIONES.phone_nm
              AND DATE_TRUNC(MIGRACIONES_CONTRATO.activation_date, MONTH) = DATE_TRUNC(ACTIVACIONES.activation_date, MONTH)

LEFT JOIN (
             SELECT 
               -- data_month_id,
               service_id,
               phone_nm,
               brand_ds,
               tariff_id,
               tariff_ds,
               bundle_id,
               init_date,
               end_date,
               concept_type_ds,
               movement_date
             FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
             WHERE data_month_id = id_mes_pr

             UNION ALL

             SELECT 
               -- CASE
               --      WHEN brand_ds = 'YOIGO'    THEN CAST(FORMAT_DATE('%Y%m', DATE_SUB(invoice_cycle_date, INTERVAL 1 MONTH)) AS INT64) 
               --      WHEN brand_ds = 'MASMOVIL' THEN CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(invoice_cycle_date, MONTH)) AS INT64)
               -- END AS data_month_id,
               service_id,
               phone_nm,
               brand_ds,
               tariff_id,
               tariff_ds,
               bundle_id,
               init_date,
               end_date,
               concept_type_ds,
               movement_date
             FROM `mm-datamart-kd.BILLING.prebilling_detail_emysim` 
             WHERE CAST(FORMAT_DATE('%Y%m', init_date) AS INT64) = id_mes_pr  
            )FACTURACION
     ON ACTIVACIONES.phone_nm = CAST(FACTURACION.phone_nm AS STRING)
     -- AND ACTIVACIONES.id_mes = FACTURACION.data_month_id 
     AND (ACTIVACIONES.service_id = FACTURACION.service_id
          OR
          MIGRACIONES_CONTRATO.service_id = FACTURACION.service_id
          )
     AND ACTIVACIONES.marca = FACTURACION.brand_ds

LEFT JOIN POS_PRE_90_DIAS POS_PRE
     ON ACTIVACIONES.phone_nm = CAST(POS_PRE.phone_nm AS STRING)

WHERE ACTIVACIONES.canal IN UNNEST (nuevo_MR)
     AND ACTIVACIONES.id_mes = id_mes_pr
     AND ACTIVACIONES.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO'
     AND CAST(FORMAT_DATE('%Y%m', ACTIVACIONES.deactivation_date) AS INT64) > id_mes_pr
     AND POS_PRE.phone_nm IS NULL

QUALIFY ROW_NUMBER() OVER(PARTITION BY ACTIVACIONES.phone_nm, ACTIVACIONES.brand_ds ORDER BY FACTURACION.movement_date ASC) = 1

;

/* Generates KPIs to facilitate commission calculations */
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activationes_kpi_exc` AS
(
SELECT 
     a.* EXCEPT(tariff_id,tariff_ds)
     ,CASE WHEN a.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' THEN b.tariff_id ELSE a.tariff_id END AS tariff_id
     ,CASE WHEN a.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' THEN b.tariff_ds ELSE a.tariff_ds END AS tariff_ds
FROM `mm-commissions-reporting.COMISIONES.activaciones` a

LEFT JOIN `mm-commissions-reporting.TEMP.migraciones_pre_post_exc` b
     ON a.service_id = b.service_id AND a.canal IN UNNEST (nuevo_MR) AND a.marca = b.marca AND a.service_type = b.service_type --AND DATE_TRUNC(a.activation_date, MONTH) = PARSE_DATE('%Y%m%d',CONCAT(CAST(b.data_month_id AS STRING),'01'))
CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE a.canal = canal_pr
AND CAST(FORMAT_DATE('%Y%m', a.activation_date) AS INT64) = id_mes_pr
)
;

-- Disgregar los bundles para comisionar las tarifas que comparten datos

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.disgregacion_bundles_exc` AS
(
SELECT
      brand_ds,
      'MANDATORY' AS product_scope,
      bundle_id,
      name,

      CASE 
          WHEN product.product_type = 'POST-PAGO' THEN product.product_tariff_id
          WHEN product.product_type = 'INTERNET FTTH' AND category = 'Fixed+Broadband' THEN bundle_id
          ELSE CAST(null as STRING)
      END AS main_mobile_tariff_id,
      
      CASE 
          WHEN product.product_type = 'POST-PAGO' THEN product.product_name
          WHEN product.product_type = 'INTERNET FTTH' AND category = 'Fixed+Broadband' THEN name
          ELSE CAST(null as STRING)
      END AS main_mobile_tariff_name,

    FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
      UNNEST(mandatory_products) AS product
    WHERE is_actual = 1 AND init_date >= "2024-08-01"
    GROUP BY ALL
    HAVING main_mobile_tariff_id IS NOT NULL
)
;

-- Dúos y compartidas gratuitas

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` AS 

SELECT data_month_id,A.phone_nm,A.service_id,A.brand_ds,A.tariff_id,concept_type_ds,concept_ds 
          FROM `mm-commissions-reporting.COMISIONES.activaciones` A
          LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_emysim` F
                ON A.service_id = F.service_id AND A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id
          WHERE A.id_mes = id_mes_pr
          AND A.agrupacion_canal = 'Exclusivo' 
          AND concept_type_ds = 'Promociones'
          AND (
               A.tariff_id IN ('8205','8212','8145','8187')
               AND F.brand_ds = 'YOIGO'
               AND UPPER(concept_ds) LIKE '%DESCUENTO 100%DÚO PRINCIPAL%'
               OR
               A.tariff_id IN ('7108')
               AND F.brand_ds = 'MASMOVIL'
               AND UPPER(concept_ds) LIKE 'MM_DTO TARIFA MAS COMPARTIDA_3 EUROS'
               OR
               A.tariff_id IN ('7115')
               AND F.brand_ds = 'MASMOVIL'
               AND UPPER(concept_ds) LIKE 'MM_DTO LINEA ADICIONAL COMPARTIDA PRO'
               OR
               A.tariff_id IN ('7169')
               AND F.brand_ds = 'MASMOVIL'
               AND UPPER(concept_ds) LIKE 'MM_DTO LINEA ADICIONAL COMPARTIDA PRO%'
               )
          AND data_month_id = id_mes_pr
          QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm,service_id,brand_ds) = 1

;

-- Actualizar tarifas en el maestro --

insert into COMISIONES.tarifas 
select 
distinct
a.canal,
a.id_mes,
a.marca,
a.service_type,
a.tariff_id, 
a.tariff_ds,
case when a.service_type = 'MOBILE' then a.line_type_ds end as line_type_ds,
c.pvp,
c.tramo_1,
c.tramo_2,
c.tramo_3,
c.tramo_4,
c.tramo_5,
c.migraciones,
c.traslados,
c.gestion_canal,
c.cuota,
c.consumo,
a.campaign_code,
'ACTIX',
current_timestamp(),
a.bundle_type
from `mm-commissions-reporting.COMISIONES.activaciones` a
left join `mm-commissions-reporting.COMISIONES.tarifas_ultima_version` b 
     on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id and a.id_mes=b.id_mes and a.canal=b.canal
     and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
left join (select * 
           from `mm-commissions-reporting.COMISIONES.tarifas_ultima_version` 
           qualify row_number () over (partition by canal, marca, service_type, tariff_id, tariff_ds, line_type_ds, campaign_code 
                                       order by id_mes desc,creado desc) = 1 
          )c -- sin id_mes para que traiga los datos del último mes que tenga info
     on a.marca = c.marca and a.service_type = c.service_type and a.tariff_id = c.tariff_id  
     and a.canal = c.canal and a.tariff_ds = c.tariff_ds 
     and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (c.line_type_ds,'NA')
cross join unnest (canales_pr) as canal_pr
where a.canal = canal_pr
and b.canal is null
and a.service_type in ('MOBILE', 'INTERNET')
and a.id_mes = id_mes_pr
;

-- Duos y compartidas con coste y comisión 

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.compartidas_coste_exc` AS

SELECT A.service_id, B.main_mobile_tariff_id, B.main_mobile_tariff_name, T.tramo_1 AS comision

            FROM `mm-commissions-reporting.COMISIONES.activaciones` A
            
            LEFT JOIN (
                         SELECT 
                              data_month_id,
                              service_id,
                              phone_nm,
                              brand_ds,
                              tariff_id,
                              tariff_ds,
                              bundle_id,
                              init_date,
                              end_date,
                              concept_type_ds 
                         FROM `mm-datamart-kd.BILLING.billing_detail_emysim` 
                         WHERE data_month_id = id_mes_pr
                         AND concept_type_ds = 'Cuotas'
                         
                         UNION ALL
                         
                         -- PARA INCLUIR LAS TARIFAS COMPARTIDAS MM QUE SE ACTIVAN DESPUÉS DEL 22 DE CADA MES Y CAEN EN LA FACTURACIÓN DEL SIGUIENTE DATA_MONTH_ID
                         SELECT 
                              CASE
                                   WHEN brand_ds = 'YOIGO'    THEN CAST(FORMAT_DATE('%Y%m', DATE_SUB(invoice_cycle_date, INTERVAL 1 MONTH)) AS INT64) 
                                   WHEN brand_ds = 'MASMOVIL' AND DATE_TRUNC(invoice_cycle_date, MONTH) = DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m%d',CONCAT(CAST(id_mes_pr AS STRING),'01')), INTERVAL 1 MONTH), MONTH)
                                        THEN CAST(FORMAT_DATE('%Y%m', DATE_SUB(invoice_cycle_date, INTERVAL 1 MONTH)) AS INT64)
                                   WHEN brand_ds = 'MASMOVIL' THEN CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(invoice_cycle_date, MONTH)) AS INT64) 
                              END AS data_month_id,
                              service_id,
                              phone_nm,
                              brand_ds,
                              tariff_id,
                              tariff_ds,
                              bundle_id,
                              init_date,
                              end_date,
                              concept_type_ds
                         FROM `mm-datamart-kd.BILLING.prebilling_detail_emysim` 
                      )F
               ON A.service_id = F.service_id AND A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id

            LEFT JOIN `mm-commissions-reporting.TEMP.disgregacion_bundles_exc` B
               ON B.bundle_id = F.bundle_id 
            
            LEFT JOIN (SELECT * EXCEPT(creado_por) 
                       FROM `mm-commissions-reporting.COMISIONES.tarifas` 
                       WHERE id_mes <= id_mes_pr
                         AND canal IN UNNEST (nuevo_MR)
                         AND tramo_1 IS NOT NULL
                         AND tramo_1 != 0
                       GROUP BY ALL

                       QUALIFY ROW_NUMBER() OVER(PARTITION BY tariff_id, tariff_ds, service_type, marca, canal ORDER BY id_mes DESC, creado DESC) = 1) T
               ON T.tariff_id = B.main_mobile_tariff_id

            LEFT JOIN (
                         SELECT *
                         FROM `mm-commissions-reporting.COMISIONES.transacciones`
                         WHERE agrupacion_canal = 'Exclusivo'
                         AND concepto IN ('A - Servicio Movil Pospago', 'Z - Servicio Movil Pospago')
                         AND estado = 'facturado'
                      ) COMISIONADAS
               ON COMISIONADAS.phone_nm = A.phone_nm AND COMISIONADAS.service_id = A.service_id AND COMISIONADAS.marca = A.marca    
            
            WHERE (
                    A.tariff_id IN ('8205','8212','7108','7115','8145','8187',/*'7169',*/'7174')
                    OR
                    A.tariff_id = '7126' AND A.activation_date >= '2026-01-22'
                  )
            AND A.agrupacion_canal = 'Exclusivo'
            AND A.canal IN UNNEST (nuevo_MR)
            AND F.data_month_id = id_mes_pr
            AND F.concept_type_ds = 'Cuotas'
            AND A.service_id NOT IN (SELECT service_id FROM `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` )
            AND T.canal IN UNNEST (nuevo_MR)
            AND T.id_mes = id_mes_pr
            AND COMISIONADAS.phone_nm IS NULL
-- QUALIFY ROW_NUMBER() OVER(PARTITION BY F.service_id, F.tariff_id ORDER BY DATE_DIFF(end_date,init_date,DAY) DESC) = 1
QUALIFY ROW_NUMBER() OVER(PARTITION BY F.service_id, F.tariff_id ORDER BY init_date ASC) = 1


;

-- Segunda Vivienda

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.segunda_vivienda_exc` AS

SELECT A.service_id, A.tariff_id, A.tariff_ds, A.marca, T.traslados AS comision

            FROM `mm-commissions-reporting.COMISIONES.activaciones` A

            INNER JOIN (
                         SELECT DISTINCT 
                           service_id 
                         FROM `mm-datamart-kd.SERVICES.campaign_base_emysim`
                         WHERE campaign_id IN (824,1464,1465,1466,1702,1931,1987,1115,2089,2123,2124,2131,2132,2140,2165)
                         AND (UPPER(campaign_description) LIKE '%SEGUNDA%' OR UPPER(campaignname) LIKE '%SEGUNDA%' OR UPPER(campaign_description) LIKE '%MULTISEDE%' OR UPPER(campaignname) LIKE '%MULTISEDE%' OR UPPER(campaign_description) LIKE '%ADICIONAL%' OR UPPER(campaignname) LIKE '%ADICIONAL%')
                      ) segunda_vivienda 
                ON A.service_id = segunda_vivienda.service_id
            
            LEFT JOIN (SELECT * EXCEPT(creado, creado_por) FROM `mm-commissions-reporting.COMISIONES.tarifas_ultima_version`  WHERE traslados != 0.0 GROUP BY ALL) T
               ON T.tariff_id = A.tariff_id  
            
            WHERE A.agrupacion_canal = 'Exclusivo'
            AND A.canal = 'ENK'
            AND A.service_type = 'INTERNET'
            AND A.marca IN ('YOIGO','MASMOVIL')
            AND A.id_mes = id_mes_pr
            AND T.canal = 'ENK'
            AND T.id_mes = id_mes_pr
QUALIFY ROW_NUMBER() OVER(PARTITION BY A.service_id, A.tariff_id, A.marca ORDER BY A.activation_date DESC) = 1

UNION ALL

SELECT A.service_id, A.tariff_id, A.tariff_ds, A.marca, T.traslados AS comision

            FROM `mm-commissions-reporting.COMISIONES.activaciones` A

            INNER JOIN `mm-commissions-reporting.GS.tarifas_thadea_multibrand` segunda_vivienda 
                ON A.tariff_id = segunda_vivienda.tariff_id
                AND segunda_vivienda.Effective_End IS NULL
            
            LEFT JOIN (SELECT * EXCEPT(creado, creado_por) FROM `mm-commissions-reporting.COMISIONES.tarifas_ultima_version`  WHERE traslados != 0.0 GROUP BY ALL) T
               ON T.tariff_id = A.tariff_id  
            
            WHERE A.agrupacion_canal = 'Exclusivo'
            AND A.canal = 'ENKO'
            AND A.service_type = 'INTERNET'
            AND A.marca IN ('ORANGE','JAZZTEL')
            AND A.id_mes = id_mes_pr
            AND segunda_vivienda.SegundaVivienda
            AND T.canal = 'ENKO'
            AND T.id_mes = id_mes_pr
QUALIFY ROW_NUMBER() OVER(PARTITION BY A.service_id, A.tariff_id, A.marca ORDER BY A.activation_date DESC) = 1
;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tarifas_nuevo_marco` AS

-- SELECT 
--   *
--   ,CASE 
--       WHEN capacidad = 0   THEN
--           CASE
--               WHEN tariff_ds LIKE '%FIJO%' THEN 40
--               WHEN tariff_ds LIKE '%MULTISIM%' THEN 25
--               ELSE 0
--           END
--       WHEN capacidad = 1   THEN 50
--       WHEN capacidad <= 25 THEN 15
--       WHEN capacidad <= 40 THEN 20
--       WHEN capacidad <= 50 THEN 25
--       WHEN capacidad <= 90 THEN 30
--       WHEN capacidad >  90 THEN 40
--    END AS comision     

-- FROM (
-- SELECT DISTINCT
--     tariff_id,
--     tariff_ds,
--     IF(SAFE_CAST(REGEXP_EXTRACT(tariff_ds, r'(\d+)\s?GB') AS INT64) IS NULL, IF(tariff_ds LIKE '%INF%',1 ,0),SAFE_CAST(REGEXP_EXTRACT(tariff_ds, r'(\d+)\s?GB') AS INT64)) AS capacidad,
--     service_type,
--     marca,
--     order_type_agg,
--     canal
--       FROM `mm-commissions-reporting.COMISIONES.activaciones` 
--   WHERE canal IN ('ENK')
--   AND id_mes = id_mes_pr
--   AND service_type = 'MOBILE'
--   AND billing_type_ds = 'POSTPAID'
-- )

-- UNION ALL

-- SELECT 
--   * EXCEPT(cod_segmento,tariff_extract)
--   ,CASE 
--       WHEN capacidad IS NULL THEN
--           CASE
--               WHEN tariff_ds = 'INTERNET MOVIL EN CASA'                         THEN 55
--               WHEN tariff_ds = 'INTERNET MOVIL EN CASA: SEGUNDA RESIDENCIA'     THEN 30
--               ELSE 0
--           END
--       WHEN capacidad = 10 AND tariff_extract LIKE '%GB%' AND marca = 'YOIGO'    THEN 160
--       WHEN capacidad = 2 AND tariff_extract LIKE '%GB%' AND marca = 'YOIGO'     THEN 15
--       WHEN capacidad = 1 AND tariff_extract LIKE '%GB%' THEN
--           CASE 
--               WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 70
--               WHEN marca = 'YOIGO'                                              THEN 125
--               WHEN marca IN ('MASMOVIL','PEPEPHONE')                            THEN 95
--           END
--       WHEN capacidad = 2 AND tariff_extract LIKE '%GB%' AND cod_segmento = '12' THEN
--           CASE 
--               WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 70
--               WHEN marca = 'YOIGO'                                              THEN 125
--               WHEN marca IN ('MASMOVIL','PEPEPHONE')                            THEN 95
--           END
--       WHEN capacidad IN (600,500) AND tariff_extract LIKE '%MB%' THEN
--           CASE 
--               WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 50
--               WHEN marca = 'YOIGO'                                              THEN 105
--               WHEN marca IN ('MASMOVIL','PEPEPHONE')                            THEN 75
--           END
--       WHEN capacidad = 300 AND tariff_extract LIKE '%MB%' THEN
--           CASE 
--               WHEN (tariff_ds LIKE '%SEGUNDA%' OR tariff_ds LIKE '%MULTISEDE%') THEN 30
--               WHEN marca = 'YOIGO'                                              THEN 85
--               WHEN marca IN ('MASMOVIL','PEPEPHONE')                            THEN 55
--           END
--    END AS comision     

-- FROM (
-- SELECT DISTINCT
--     tariff_id,
--     tariff_ds,
--     TRIM(SPLIT(tariff_ds, '+')[SAFE_OFFSET(0)]) AS tariff_extract,
--     SAFE_CAST(REGEXP_EXTRACT(TRIM(SPLIT(tariff_ds, '+')[SAFE_OFFSET(0)]), r'(\d+)') AS INT64) AS capacidad,
--     cod_segmento,
--     service_type,
--     marca,
--     order_type_agg,
--     canal

--       FROM `mm-commissions-reporting.COMISIONES.activaciones` 
--   WHERE canal IN ('ENK')
--   AND id_mes = id_mes_pr
--   AND service_type = 'INTERNET'
--   AND order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
--   AND billing_type_ds = 'POSTPAID'
-- )

-- UNION ALL

-- SELECT 
--   * EXCEPT(cod_segmento,tariff_extract)
--   ,CASE      
--       WHEN capacidad = 10 AND tariff_extract LIKE '%GB%'         THEN 96
--       WHEN capacidad = 2 AND tariff_extract LIKE '%GB%'          THEN 84
--       WHEN capacidad = 1 AND tariff_extract LIKE '%GB%'          THEN 70
--       WHEN capacidad IN (600,500) AND tariff_extract LIKE '%MB%' THEN 50
--       WHEN capacidad = 300 AND tariff_extract LIKE '%MB%'        THEN 30

--    END AS comision     

-- FROM (
-- SELECT DISTINCT
--     tariff_id,
--     tariff_ds,
--     TRIM(SPLIT(tariff_ds, '+')[SAFE_OFFSET(0)]) AS tariff_extract,
--     SAFE_CAST(REGEXP_EXTRACT(TRIM(SPLIT(tariff_ds, '+')[SAFE_OFFSET(0)]), r'(\d+)') AS INT64) AS capacidad,
--     cod_segmento,
--     service_type,
--     marca,
--     order_type_agg,
--     canal

--       FROM `mm-commissions-reporting.COMISIONES.activaciones` 
--   WHERE canal IN ('ENK')
--   AND id_mes = id_mes_pr
--   AND service_type = 'INTERNET'
--   AND order_type_agg IN ('CAMBIO DOMICILIO','CAMBIO TECNOLOGIA')
--   AND billing_type_ds = 'POSTPAID'
-- )
-- ;

---------------------------------------

create or replace table `mm-commissions-reporting.TEMP.acti_conceptos_exc` as

with

tarifas_tramos as
(
select
canal,
marca,
service_type,
tariff_id,
tariff_ds,
line_type_ds,
tramo,
comision,
traslados,
migraciones,
gestion_canal,
campaign_code

from `mm-commissions-reporting.COMISIONES.tarifas_ultima_version` 
unpivot ( comision for tramo in (tramo_1,tramo_2,tramo_3,tramo_4,tramo_5))
where id_mes = id_mes_pr
),


marco as
(

-- Servicio fijo y movil --
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
tariff_ds,
a.line_type_ds,
id_comisionista

     ,CASE
          WHEN service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          ELSE 'A - Servicio Fijo'
      END AS concepto,

'UPFR' AS tipo_concepto,
comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1') 
and (a.service_type in ('MOBILE','INTERNET') AND  COALESCE(a.line_type_ds,'a') != 'MULTISIM')

-- Servicio Multisim --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
tariff_ds,
a.line_type_ds,
id_comisionista,
'B - Multisim' as concepto,
'UPFR' AS tipo_concepto,
comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
AND a.line_type_ds = 'MULTISIM' 

-- Portabilidad --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
tariff_ds,
a.line_type_ds,
id_comisionista,
case when service_type = 'MOBILE' then 'A - Portabilidad Movil Pospago' else 'A - Portabilidad Fijo' END as concepto, 
'UPFR' AS tipo_concepto,
`mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(a.marca, a.service_type, a.tariff_id, a.tariff_ds, a.line_type_ds, a.canal , false,a.campaign_code) comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.canal NOT IN UNNEST (nuevo_MR)

--  traslados --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
tariff_ds,
a.line_type_ds,
id_comisionista,
'A - Servicio Fijo Cambio de Domicilio' as concepto, 
'UPFR' AS tipo_concepto,
CASE WHEN traslados > 1 THEN traslados ELSE comision*traslados END as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.service_type = 'INTERNET'

--  migraciones --
union all
select
a.canal as canal,
a.marca,
a.service_type,
tariff_id,
tariff_ds,
a.line_type_ds,
id_comisionista,
'A - Servicio Fijo Cambio de Tecnologia' as concepto, 
'UPFR' AS tipo_concepto,
CASE WHEN migraciones > 1 THEN migraciones ELSE comision*migraciones END as comision
from tarifas_tramos a
left join `mm-commissions-reporting.COMISIONES.v_actr_tramos` b on a.marca=b.marca and a.canal=b.canal and b.mes = mes_string
cross join unnest (canales_pr) canal_pr
where a.canal = canal_pr
and a.tramo =  coalesce ('tramo_'||cast (b.tramo as string),'tramo_1')
and a.service_type = 'INTERNET'
)


select *
from marco
qualify row_number ()  over (partition by canal, marca, service_type, tariff_id,tariff_ds, line_type_ds, concepto,id_comisionista ) = 1
;

--- Calcular tabla de comisiones ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_exc` AS

SELECT
--- primary key ---
prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id,
*

FROM (
     SELECT
     --- comision ---
     'calculado' AS estado,
     id_mes_pr id_mes,
     b.agrupacion_canal,
     b.canal,

     CASE 
          WHEN b.billing_type_ds = 'PREPAID' THEN REPLACE(a.concepto, 'Pospago', 'Prepago') 
          ELSE a.concepto 
     END AS concepto,
     a.tipo_concepto,
     1 as unidades,

     ----Comision----
     CASE

         --------------- EML, ENX, EYG, EDB ----------------
         WHEN b.canal IN ('EML','ENX','EYG','EDB') THEN 
     
             CASE
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'AJUSTNETFLIX' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'A - Servicio Movil Pospago'
                 THEN 25.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'AJUSTNETFLIX' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'F - Servicio Movil Pospago'
                 THEN 3.75
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'FIJOALOPEPE1' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' AND b. order_type_agg = 'ALTA NUEVA'
                      AND concepto = 'A - Servicio Movil Pospago'
                 THEN 15.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'FIJOALOPEPE1' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'MAIN' AND b. order_type_agg = 'ALTA NUEVA'
                      AND concepto = 'F - Servicio Movil Pospago'
                 THEN 0.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'INIMINETFLIX' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'A - Servicio Movil Pospago'
                 THEN 40.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'INIMINETFLIX' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'F - Servicio Movil Pospago'
                 THEN 6.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
                      AND concepto = 'A - Servicio Movil Pospago'
                 THEN 40.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'MAIN'
                      AND concepto = 'F - Servicio Movil Pospago'
                 THEN 6.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'A - Servicio Movil Pospago'
                 THEN 25.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH23GBILIMI' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'F - Servicio Movil Pospago'
                 THEN 3.75
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH25GBILIM1' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'A - Servicio Movil Pospago'
                 THEN 40.00
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_id = 'TNH25GBILIM1' AND b.bundle_type = 'FMC' AND a.line_type_ds = 'ADDITIONAL'
                      AND concepto = 'F - Servicio Movil Pospago'
                 THEN 6.00
     
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.billing_tier IN ('DESCUENTO 100% DUO PRINCIPAL', 'DESCUENTO 100% INDEFINIDO DUO PRINCIPAL PRO') AND concepto NOT LIKE '%Portabilidad%'
                 THEN 0.00
     
                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.tariff_ds = 'DUO PRINCIPAL' AND b.order_type_agg = 'ALTA NUEVA' AND concepto NOT LIKE '%Portabilidad%'
                 THEN 0.00
             ELSE a.comision END

         --------------- ENK ----------------
         WHEN b.canal IN UNNEST (nuevo_MR) THEN
             CASE
                 WHEN b.agrupacion_canal = 'Exclusivo' AND c.concept_ds IN ('Descuento 100% Dúo principal','C Descuento 100% Dúo principal','Descuento 100% indefinido Dúo principal PRO','MM_DTO TARIFA MAS COMPARTIDA_3 EUROS','MM_DTO LINEA ADICIONAL COMPARTIDA PRO') --AND concepto NOT LIKE '%Portabilidad%'
                 THEN 0.00

                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.service_id = c.service_id THEN 0.00 -- COMPARTIDAS GRATUITAS

                 WHEN b.agrupacion_canal = 'Exclusivo' AND b.service_id = e.service_id THEN e.comision -- COMPARTIDAS CON COSTE 

               --   WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = 'PEPEPHONE' AND b.tariff_ds = f.tariff_ds AND b.service_type = f.service_type THEN f.comision
                 
               --   WHEN b.agrupacion_canal = 'Exclusivo' AND b.marca = f.marca AND b.tariff_id = f.tariff_id AND b.service_type = f.service_type THEN f.comision 

             ELSE a.comision END
         ELSE a.comision

     END AS comision,

     --- vendedor ---
     b.id_comisionista,
     b.distribuidor,
     b.sfid_id,
     b.id_comisionista AS seller,
     b.nombre_comercio,
     b.razon_social,
     b.cif,
     b.zona_fiscal,

     --- servicio ---
     b.marca,
     b.service_type,
     b.phone_nm,
     CASE WHEN b.service_id = h.service_id THEN h.tariff_id ELSE b.tariff_id END AS tariff_id,
     CASE WHEN b.service_id = h.service_id THEN h.tariff_ds ELSE b.tariff_ds END AS tariff_ds,
     b.service_id,
     b.account_id,
     b.customer_id,
     a.line_type_ds,
     b.bundle_type,
     b.technology_ds,
     b.billing_type_ds,
     b.sale_date,
     b.activation_date,
     b.deactivation_date,
     COALESCE(b.sfid_digo,b.order_id) AS order_id,
     b.order_type_agg,

     --- variables analiticas ---
     cod_segmento,
     cod_marca,
     cod_tipo_contrato,
     cod_producto,
     coalesce (d.cod_canal, b.cod_canal) as cod_canal,

     --- informacion adicional ---
     cast ( null as string ) as campaign_code,
     cast ( null as string ) serial_number,
     cast ( null as float64 ) tax_base,
     cast ( null as string ) claim_code,
     cast ( null as string ) process_code,
     comments,

     --- informacion contabilizacion ---
     'C_MANUAL' as facturador,

     FROM (
          SELECT * FROM `mm-commissions-reporting.TEMP.acti_conceptos_exc` WHERE canal NOT IN ('ALTN', 'ALTNC','ALTNH')
          ) a

     INNER JOIN `mm-commissions-reporting.TEMP.activationes_kpi_exc` b
           ON a.canal = b.canal AND a.marca = b.marca AND a.service_type = b.service_type AND a.tariff_id = b.tariff_id AND a.tariff_ds = b.tariff_ds AND b.bundle_type = b.bundle_type

     LEFT JOIN `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` c -- DUO Y MAS AD COMPARTIDA GRATUITAS
           ON c.phone_nm = b.phone_nm AND c.service_id = b.service_id AND c.brand_ds = b.marca AND c.data_month_id = b.id_mes

     LEFT JOIN `mm-commissions-reporting.TEMP.compartidas_coste_exc` e -- DUO Y MAS AD COMPARTIDA DE COSTE
           ON b.service_id = e.service_id  

     INNER JOIN `mm-commissions-reporting.GS.CANALES` d 
           ON a.canal = d.canal 

     -- LEFT JOIN `mm-commissions-reporting.TEMP.tarifas_nuevo_marco` f
     --       ON f.canal = b.canal AND f.marca = b.marca AND f.service_type = b.service_type AND f.tariff_id = b.tariff_id AND f.tariff_ds = b.tariff_ds AND f.order_type_agg = b.order_type_agg AND b.canal = 'ENK'

     -- INNER JOIN `mm-commissions-reporting.GS.exclusivo_dealers` g 
     INNER JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` g 
          ON b.id_comisionista = g.sfid_id
          AND g.id_mes = id_mes_pr
          AND g.comisiona

     LEFT JOIN `mm-commissions-reporting.TEMP.migraciones_pre_post_exc` h
          ON h.phone_nm = b.phone_nm AND h.service_id = b.service_id AND h.marca = b.marca --AND h.data_month_id = b.id_mes

     cross join unnest(canales_pr) as canal_pr

     where 1=1
     and b.canal = canal_pr
     and b.id_mes = id_mes_pr
     and b.comisionamiento = 'Comisiona'
     and b.service_id NOT IN (SELECT DISTINCT service_id FROM `mm-commissions-reporting.TEMP.segunda_vivienda_exc`)
     and DATE_TRUNC(b.deactivation_date,MONTH) > DATE_TRUNC(b.activation_date,MONTH) -- 20250926
     and case when a.service_type = 'MOBILE' then a.line_type_ds else 'FIX' end = case when b.service_type = 'MOBILE' then b.line_type_ds else 'FIX' end
     and case
       when concepto in ('A - Portabilidad Movil Pospago', 'A - Portabilidad Fijo') then 'PORTABILIDAD'
       when concepto = 'A - Servicio Fijo Cambio de Domicilio'  then 'CAMBIO DOMICILIO'
       when concepto = 'A - Servicio Fijo Cambio de Tecnologia' then 'CAMBIO TECNOLOGIA'
       when concepto in ('A - Servicio Fijo', 'A - Servicio Movil Pospago','B - Multisim') and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC', 'MULTISIM','MIGRACION PREPAGO A POSTPAGO') then b.order_type_agg
       end = b.order_type_agg
     and (not (coalesce (b.distribuidor,'NA') not in (select id_comisionista from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` ) and substr(a.concepto,1,1) =     'F') or b.distribuidor = 'BYMOVIL')
     and (
           b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC','CAMBIO DOMICILIO','MULTISIM','HLR')
         or
           (b.canal IN UNNEST (nuevo_MR) and b.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO')
         or
           (b.canal IN UNNEST (nuevo_MR) and b.activation_date < '2026-07-01' and b.order_type_agg = 'CAMBIO TECNOLOGIA')
         or
           (b.canal NOT IN UNNEST (nuevo_MR) and b.order_type_agg = 'CAMBIO TECNOLOGIA')
         )
     and (b.cif is not null 
          OR
          b.comentarios = 'NUEVO PRELIQUI'
         ) 


     UNION ALL 

     --********************* SEGUNDA VIVIENDA ********************

     select
     --- comision ---
     'calculado' AS estado,
     id_mes_pr id_mes,
     b.agrupacion_canal,
     b.canal,
     'A - Servicio Fijo 2da Vivienda' AS concepto,
     'UPFR' AS tipo_concepto,
     1 as unidades,

     ----Comision----
     SEGUNDA_VIVIENDA.comision,

     --- vendedor ---
     b.id_comisionista,
     b.distribuidor,
     b.sfid_id,
     b.id_comisionista AS seller,
     b.nombre_comercio,
     b.razon_social,
     b.cif,
     b.zona_fiscal,

     --- servicio ---
     b.marca,
     b.service_type,
     b.phone_nm,
     b.tariff_id,
     b.tariff_ds,
     b.service_id,
     b.account_id,
     b.customer_id,
     b.line_type_ds,
     b.bundle_type,
     b.technology_ds,
     b.billing_type_ds,
     b.sale_date,
     b.activation_date,
     b.deactivation_date,
     COALESCE(b.sfid_digo,b.order_id) AS order_id,
     b.order_type_agg,

     --- variables analiticas ---
     cod_segmento,
     cod_marca,
     cod_tipo_contrato,
     cod_producto,
     coalesce (d.cod_canal, b.cod_canal) as cod_canal,

     --- informacion adicional ---
     cast ( null as string ) as campaign_code,
     cast ( null as string ) serial_number,
     cast ( null as float64 ) tax_base,
     cast ( null as string ) claim_code,
     cast ( null as string ) process_code,
     comments,

     --- informacion contabilizacion ---
     'C_MANUAL' as facturador,

     FROM `mm-commissions-reporting.TEMP.activationes_kpi_exc` b

     INNER JOIN `mm-commissions-reporting.GS.CANALES` d 
           ON b.canal = d.canal

     LEFT JOIN `mm-commissions-reporting.TEMP.segunda_vivienda_exc` SEGUNDA_VIVIENDA
           ON b.service_id = SEGUNDA_VIVIENDA.service_id

     cross join unnest(canales_pr) as canal_pr

     where 1=1
     and b.canal = canal_pr
     and b.id_mes = id_mes_pr
     and b.comisionamiento = 'Comisiona'
     and b.service_id = SEGUNDA_VIVIENDA.service_id
     and DATE_TRUNC(b.deactivation_date,MONTH) > DATE_TRUNC(b.activation_date,MONTH) -- 20250926
     and b.order_type_agg in ('ALTA NUEVA','PORTABILIDAD')
     and (b.cif is not null 
          OR
          b.comentarios = 'NUEVO PRELIQUI'
         ) 
     )

;


assert not exists (
  select *
  from `mm-commissions-reporting.TEMP.acti_comisiones_exc`
  QUALIFY COUNT(*) OVER (PARTITION BY phone_nm, service_id, marca, service_type, concepto) > 1

) AS 'Hay duplicados en ACTIX'
;


create or replace table `mm-commissions-reporting.TEMP.acti_comisiones_final_exc` as 
select *
from `mm-commissions-reporting.TEMP.acti_comisiones_exc`
where comision is not null
      and (
          comision != 0
          OR
          (comision = 0 AND tariff_id in ('8205','8212','7108','7115','7126','7127','7169','7176','8145','8187'))
          );

--- Insertar tabla final ----

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo` (prefijo, id_mes_pr, canales_pr, 'TEMP.acti_comisiones_final_exc', modo);

IF modo = 'ACTUALIZAR' THEN
-- Borrar Cambios de Domicilio para los que no hayan transcurrido más de 90 días desde la fecha de activación de la línea 'ENK'
DELETE
FROM `mm-commissions-reporting.COMISIONES.transacciones` 
-- SET estado = 'rechazado', comments = 'Cambio de domicilio < 90 dias desde alta'

WHERE commission_id IN (
                        WITH CAMBIO_DOM AS (
                           SELECT account_id, phone_nm, activation_date, brand_ds
                           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                           WHERE 1 = 1 
                           AND service_type = 'BROADBAND'
                           AND order_type_agg IN ('CAMBIO DOMICILIO')
                           AND activation_date IS NOT NULL
                           AND phone_nm IN (SELECT CAST(phone_nm AS INT64)
                                              FROM `mm-commissions-reporting.COMISIONES.transacciones` 
                                              WHERE id_mes = id_mes_pr
                                              AND agrupacion_canal = 'Exclusivo'
                                              AND canal IN UNNEST (nuevo_MR)
                                              AND estado NOT IN ('rechazado','facturado')
                                              AND concepto = 'A - Servicio Fijo Cambio de Domicilio')
                           GROUP BY account_id, phone_nm, order_type_agg, activation_date, brand_ds
                           QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, order_type_agg, brand_ds ORDER BY activation_date DESC) = 1
                         )

                         ,

                          ALTAS AS (
                           SELECT account_id, phone_nm, activation_date, brand_ds
                           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                           WHERE 1 = 1 
                           AND service_type = 'BROADBAND'
                           AND order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
                           AND activation_date IS NOT NULL
                           AND phone_nm IN (SELECT CAST(phone_nm AS INT64)
                                              FROM `mm-commissions-reporting.COMISIONES.transacciones` 
                                              WHERE id_mes = id_mes_pr
                                              AND agrupacion_canal = 'Exclusivo'
                                              AND canal IN UNNEST (nuevo_MR)
                                              AND estado NOT IN ('rechazado','facturado')
                                              AND concepto = 'A - Servicio Fijo Cambio de Domicilio')
                           GROUP BY account_id, phone_nm, order_type_agg, activation_date, brand_ds
                           QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, brand_ds ORDER BY activation_date DESC) = 1
                         )



                         SELECT DISTINCT CALC.commission_id
                         -- , CD.account_id, CD.phone_nm,CD.activation_date as CD_activation_date, A.activation_date AS alta_activation_date, DATE_DIFF(CD.                         activation_date, A.activation_date, DAY) AS dias_cambio_domicilio

                         FROM CAMBIO_DOM CD

                         LEFT JOIN ALTAS A
                           ON CD.phone_nm = A.phone_nm AND CD.brand_ds = A.brand_ds

                         LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` CALC
                           ON CD.phone_nm = CAST(CALC.phone_nm AS INT64) AND CD.brand_ds = CALC.marca

                         WHERE CALC.id_mes = id_mes_pr
                         AND CALC.agrupacion_canal = 'Exclusivo'
                         AND CALC.canal IN UNNEST (nuevo_MR)
                         AND CALC.concepto = 'A - Servicio Fijo Cambio de Domicilio'
                         AND CALC.estado NOT IN ('validado','confirmado','facturado')
                         AND DATE_DIFF(CD.activation_date, A.activation_date, DAY) < 90
                       ) 
;

END IF;

IF modo = 'DAILY' THEN
-- Borrar Cambios de Domicilio para los que no hayan transcurrido más de 90 días desde la fecha de activación de la línea 'ENK'
DELETE
FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` 
-- SET estado = 'rechazado', comments = 'Cambio de domicilio < 90 dias desde alta'

WHERE commission_id IN (
                        WITH CAMBIO_DOM AS (
                           SELECT account_id, phone_nm, activation_date, brand_ds
                           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                           WHERE 1 = 1 
                           AND service_type = 'BROADBAND'
                           AND order_type_agg IN ('CAMBIO DOMICILIO')
                           AND activation_date IS NOT NULL
                           AND phone_nm IN (SELECT CAST(phone_nm AS INT64)
                                              FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` 
                                              WHERE id_mes = id_mes_pr
                                              AND agrupacion_canal = 'Exclusivo'
                                              AND canal IN UNNEST (nuevo_MR)
                                              AND estado NOT IN ('rechazado','facturado')
                                              AND concepto = 'A - Servicio Fijo Cambio de Domicilio')
                           GROUP BY account_id, phone_nm, order_type_agg, activation_date, brand_ds
                           QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, order_type_agg, brand_ds ORDER BY activation_date DESC) = 1
                         )

                         ,

                          ALTAS AS (
                           SELECT account_id, phone_nm, activation_date, brand_ds
                           FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                           WHERE 1 = 1 
                           AND service_type = 'BROADBAND'
                           AND order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
                           AND activation_date IS NOT NULL
                           AND phone_nm IN (SELECT CAST(phone_nm AS INT64)
                                              FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` 
                                              WHERE id_mes = id_mes_pr
                                              AND agrupacion_canal = 'Exclusivo'
                                              AND canal IN UNNEST (nuevo_MR)
                                              AND estado NOT IN ('rechazado','facturado')
                                              AND concepto = 'A - Servicio Fijo Cambio de Domicilio')
                           GROUP BY account_id, phone_nm, order_type_agg, activation_date, brand_ds
                           QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm, brand_ds ORDER BY activation_date DESC) = 1
                         )



                         SELECT DISTINCT CALC.commission_id
                         -- , CD.account_id, CD.phone_nm,CD.activation_date as CD_activation_date, A.activation_date AS alta_activation_date, DATE_DIFF(CD.                         activation_date, A.activation_date, DAY) AS dias_cambio_domicilio

                         FROM CAMBIO_DOM CD

                         LEFT JOIN ALTAS A
                           ON CD.phone_nm = A.phone_nm AND CD.brand_ds = A.brand_ds

                         LEFT JOIN `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` CALC
                           ON CD.phone_nm = CAST(CALC.phone_nm AS INT64) AND CD.brand_ds = CALC.marca

                         WHERE CALC.id_mes = id_mes_pr
                         AND CALC.agrupacion_canal = 'Exclusivo'
                         AND CALC.canal IN UNNEST (nuevo_MR)
                         AND CALC.concepto = 'A - Servicio Fijo Cambio de Domicilio'
                         AND CALC.estado NOT IN ('validado','confirmado','facturado')
                         AND DATE_DIFF(CD.activation_date, A.activation_date, DAY) < 90
                       ) 
;

END IF;


call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`( false );


end