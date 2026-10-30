BEGIN

DECLARE sql, mes_string, prefijo STRING;

SET mes_string = CAST(mes_pr AS STRING);

SET prefijo = 'TLVNRP';


-- CALL `mm-commissions-reporting.COMISIONES.pr_tlvnrp`(202507);



ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.sfid_id
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp`
     GROUP BY ALL
     ) REPARTOS
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON REPARTOS.sfid_id = DEALER.sfid_id
            AND DEALER.id_mes = mes_pr AND DEALER.agrupacion_canal = 'TLV - Negocios' AND comisiona
WHERE DEALER.sfid_id IS NULL AND REPARTOS.importe <> 0
);





CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvn_repartos` AS (
  

WITH reparto_X001_12 AS
(
SELECT
      concepto
     ,tipo_concepto
     ,'12' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_12) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp`
     GROUP BY ALL
     )
WHERE id_mes = mes_pr 
)


SELECT DISTINCT
        concepto
       ,tipo_concepto
       ,cod_segmento
       ,sociedad
       ,SPLIT(arr, '+')[OFFSET(0)] AS bundle_type
       ,SPLIT(arr, '+')[OFFSET(1)] AS line_type_ds
       ,SPLIT(arr, '+')[OFFSET(2)] AS service_type
FROM reparto_X001_12, UNNEST(arr) arr
)

;



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp_base_comisiones` AS (


SELECT
      REPARTOS.concepto
     ,mes_pr AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,ACTIVACIONES.id_comisionista 
     ,RAPPEL.sfid_id AS sfid_id_cruce
     ,ACTIVACIONES.* EXCEPT(id_mes, id_comisionista, sfid_digo, campaign_code)

     ,CAST(NULL AS STRING)  AS campaign_code

     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     
FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES

INNER JOIN `mm-commissions-reporting.TEMP.tlvn_repartos` REPARTOS
          ON ACTIVACIONES.cod_segmento = REPARTOS.cod_segmento
             AND ACTIVACIONES.sociedad = REPARTOS.sociedad AND ACTIVACIONES.bundle_type = REPARTOS.bundle_type
             AND ACTIVACIONES.line_type_ds = REPARTOS.line_type_ds AND ACTIVACIONES.service_type = REPARTOS.service_type

LEFT JOIN `mm-commissions-reporting.GS.tlv_negocios_dealers` TLVN
         ON ACTIVACIONES.id_comisionista = TLVN.id_comisionista AND ACTIVACIONES.canal = TLVN.canal

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp`
           GROUP BY ALL
           ) RAPPEL
          ON (ACTIVACIONES.id_comisionista = RAPPEL.sfid_id OR ACTIVACIONES.sfid_id = RAPPEL.sfid_id OR ACTIVACIONES.distribuidor = RAPPEL.sfid_id)
             AND RAPPEL.id_mes = mes_pr
             AND REPARTOS.concepto = RAPPEL.concepto
             AND RAPPEL.importe <> 0

WHERE ACTIVACIONES.id_mes = mes_pr
      AND comisionamiento IN ('Comisiona', 'No comisiona - campana')

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, phone_nm, marca, service_type, REPARTOS.concepto) = 1

UNION ALL


  SELECT
      REPARTOS.concepto
     ,mes_pr AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,RENUEVOS.sfid_id
     ,RAPPEL.sfid_id AS sfid_id_cruce
     ,CAST(NULL AS STRING) AS comisionamiento
     ,RENUEVOS.brand_ds AS marca
     ,RENUEVOS.brand_ds
     ,RENUEVOS.service_id
     ,RENUEVOS.account_id
     ,RENUEVOS.customer_id
     ,'MOBILE' AS service_type
     ,RENUEVOS.line_type_ds
     ,RENUEVOS.bundle_type
     ,RENUEVOS.technology_ds
     ,RENUEVOS.billing_type_ds
     ,RENUEVOS.phone_nm
     ,RENUEVOS.order_date AS sale_date
     ,RENUEVOS.activation_date
     ,RENUEVOS.deactivation_date
     ,CAST(RENUEVOS.order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,RENUEVOS.tariff_id AS tariff_id
     ,RENUEVOS.product AS tariff_ds
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(RENUEVOS.segment_ds, RENUEVOS.brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(RENUEVOS.brand_ds) AS cod_marca
     
     ,CASE
          WHEN RENUEVOS.bundle_type = 'FMC' AND RENUEVOS.line_type_ds = 'MAIN'  THEN '61'
          WHEN RENUEVOS.bundle_type = 'FMC'                                     THEN '67'
          WHEN RENUEVOS.bundle_type = 'MO' AND RENUEVOS.line_type_ds IN ('ADDITIONAL', 'EXTRA') 
               AND RENUEVOS.brand_ds = 'YOIGO'                                  THEN '68'
          ELSE '20'
     END AS cod_tipo_contrato


     ,'050' AS cod_producto
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(RENUEVOS.channel_ds, RENUEVOS.subchannel_ds) AS cod_canal
     ,RENUEVOS.seller
     ,CAST(NULL AS STRING) AS order_fix_id
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS comments
     ,RENUEVOS.data_source AS data_source_ds
     ,'X001' AS sociedad
     ,CAST(NULL AS STRING) AS seller_formato_tms
     ,'TLV-Negocios' AS agrupacion_canal_ventas_base
     ,'TLV-Negocios' AS agrupacion_canal
     ,CAST(NULL AS STRING) AS distribuidor
     ,DEALER.canal
     ,CAST('true' AS BOOL) AS comisiona
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,CAST(NULL AS STRING) AS comentarios
     ,CAST(NULL AS STRING) AS cif_gpv
     ,'johanna.dominguez@asesormasmovil.es' AS creado_por
     ,CURRENT_TIMESTAMP() AS creado
     ,RENUEVOS.sfid_id AS sfid_original
     ,RENUEVOS.sfid_id AS sfid_id
     ,CAST(NULL AS STRING) AS portability_group_donor
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,CAST(NULL AS STRING) AS billing_tier

     ,CAST (NULL AS STRING) AS campaign_code

     ,RENUEVOS.serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base

-- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
FROM `mm-commissions-reporting.TEMP.device_base` RENUEVOS

INNER JOIN `mm-commissions-reporting.TEMP.tlvn_repartos` REPARTOS
          ON REPARTOS.tipo_concepto = 'CURE' AND RENUEVOS.technology_ds = REPARTOS.service_type

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON RENUEVOS.sfid_id = DEALER.sfid_id AND DEALER.agrupacion_canal = 'TLV - Negocios' AND DEALER.id_mes = mes_pr

LEFT JOIN  `mm-commissions-reporting.GS.tlv_negocios_dealers`  TLVN
         ON DEALER.id_comisionista = TLVN.id_comisionista AND DEALER.canal = TLVN.canal

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp`
           GROUP BY ALL
           ) RAPPEL
          ON RENUEVOS.sfid_id = RAPPEL.sfid_id
             AND RAPPEL.id_mes = mes_pr
             AND REPARTOS.concepto = RAPPEL.concepto

             AND RAPPEL.importe <> 0

WHERE DATE_TRUNC(RENUEVOS.activation_date, MONTH) = COMISIONES.f_mes_int (mes_pr)
      AND REPARTOS.concepto IN ('D - Camp. Cliente Riesgo Fuga','D - Camp. Cliente Renuevos')
      AND RENUEVOS.sell_type = 'RENUEVO'

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, phone_nm, marca, service_type, REPARTOS.concepto) = 1

)

;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp_unitario` AS (

SELECT
      BASE.sfid_id_cruce AS sfid_id
     ,BASE.concepto
     ,RAPPEL.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.tlvnrp_base_comisiones` BASE

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp`
           GROUP BY ALL
           ) RAPPEL
          ON BASE.id_mes = RAPPEL.id_mes
             AND BASE.sfid_id_cruce = RAPPEL.sfid_id
             AND BASE.concepto = RAPPEL.concepto

WHERE RAPPEL.importe <> 0
          
GROUP BY ALL
)
;





CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,BASE.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision

     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,BASE.sfid_id
     ,BASE.sfid_id_cruce
     ,BASE.seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,BASE.marca
     ,BASE.service_type
     ,BASE.phone_nm
     ,BASE.tariff_id
     ,BASE.tariff_ds
     ,BASE.service_id
     ,BASE.account_id
     ,BASE.customer_id
     ,BASE.line_type_ds
     ,BASE.bundle_type
     ,BASE.technology_ds
     ,BASE.billing_type_ds
     ,BASE.sale_date
     ,BASE.activation_date
     ,BASE.deactivation_date
     ,BASE.order_id
     ,BASE.order_type_agg
     ,BASE.cod_segmento
     ,BASE.cod_marca
     ,BASE.cod_tipo_contrato
     ,BASE.cod_producto
     ,BASE.cod_canal
     ,CAST (NULL AS STRING) AS campaign_code
     ,BASE.serial_number
     ,BASE.tax_base
     ,BASE.claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.TEMP.tlvnrp_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (BASE.sfid_id = DEALER.sfid_id OR BASE.id_comisionista = DEALER.id_comisionista) AND DEALER.agrupacion_canal = 'TLV - Negocios' AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.TEMP.tlvnrp_unitario` UNITARIO
         ON BASE.sfid_id_cruce = UNITARIO.sfid_id AND BASE.concepto = UNITARIO.concepto

LEFT JOIN  `mm-commissions-reporting.GS.tlv_negocios_dealers`  TLVN
         ON DEALER.id_comisionista = TLVN.id_comisionista AND DEALER.canal = TLVN.canal
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp_correccion` AS

SELECT
      CALCULO.commission_id
     ,CALCULO.estado
     ,CALCULO.mes_liquidado
     ,CALCULO.id_mes
     ,CALCULO.agrupacion_canal
     ,CALCULO.canal
     ,CALCULO.concepto
     ,CALCULO.tipo_concepto
     ,CALCULO.unidades
     ,(UNITARIO.importe - CALCULO.comision) AS comision
     ,CALCULO.* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * EXCEPT(comision)
            ,SUM(comision) OVER (PARTITION BY sfid_id_cruce, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.tlvnrp_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id_cruce, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.tlvnrp_unitario` UNITARIO
         ON CALCULO.sfid_id_cruce = UNITARIO.sfid_id AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp_cruzado` AS

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
     ,ROUND(SUM(comision) OVER (PARTITION BY concepto, service_id, marca, service_type),2) AS comision
     ,* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.tlvnrp_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.tlvnrp_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp_no_cruzado` AS
SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_pr AS STRING)) AS mes_liquidado
     ,mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,RAPPEL.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,RAPPEL.importe AS comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id AS sfid_id
     ,RAPPEL.sfid_id AS sfid_id_cruce
     ,COALESCE(RAPPEL.sfid_id, DEALER.sfid_id) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,'MASMOVIL' AS marca

     ,CASE
          WHEN COALESCE(
                       `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`
                        (
                         'POSTPAID',
                         REPLACE(SPLIT(RAPPEL.reparto_X001_12, '+')[OFFSET(2)],',',''),
                         SPLIT(RAPPEL.reparto_X001_12, '+')[OFFSET(0)],
                         'FTTH',
                         'MASMOVIL' ,
                         SPLIT(RAPPEL.reparto_X001_12, '+')[OFFSET(1)]
                        )
                        , '61') = '61'
               AND RAPPEL.tipo_concepto <> 'CURE'
          THEN 'INTERNET'
          ELSE 'MOBILE'
      END AS service_type

     ,CAST(NULL AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,CAST(NULL AS STRING) AS tariff_ds
     ,CAST(NULL AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,CAST(NULL AS DATE) AS sale_date
     ,CAST(NULL AS DATE) AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`('MASMOVIL') AS cod_marca

     ,COALESCE(
              `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`
               (
                'POSTPAID',
                REPLACE(SPLIT(RAPPEL.reparto_X001_12, '+')[OFFSET(2)],',',''),
                SPLIT(RAPPEL.reparto_X001_12, '+')[OFFSET(0)],
                'FTTH',
                'MASMOVIL' ,
                SPLIT(RAPPEL.reparto_X001_12, '+')[OFFSET(1)]
               )
               , '61') AS cod_tipo_contrato

     ,'040' AS cod_producto 
     ,'15' AS cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp`
     GROUP BY ALL
     ) RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON  RAPPEL.sfid_id = DEALER.sfid_id AND DEALER.id_mes = mes_pr

LEFT JOIN `mm-commissions-reporting.TEMP.tlvnrp_unitario` UNITARIO
         ON RAPPEL.sfid_id = UNITARIO.sfid_id AND RAPPEL.concepto = UNITARIO.concepto

WHERE RAPPEL.id_mes = mes_pr AND UNITARIO.sfid_id IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tlvnrp` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.tlvnrp_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.tlvnrp_no_cruzado`
     )
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.sfid_id_cruce
FROM (SELECT sfid_id_cruce, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.tlvnrp` GROUP BY ALL) REPARTO
LEFT JOIN (SELECT sfid_id, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_tlvnrp` WHERE id_mes = mes_pr GROUP BY ALL) GS
         ON REPARTO.sfid_id_cruce = GS.sfid_id 
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (
                                                                prefijo,
                                                                mes_pr,
                                                                (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.tlvnrp WHERE canal IS NOT NULL),
                                                                'TEMP.tlvnrp',
                                                                'ACTUALIZAR'
                                                                )
;

END