BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'RALT';


-- CALL `mm-commissions-reporting.COMISIONES.pr_ralt`(202406);

ASSERT EXISTS (
  SELECT id_mes
  FROM `mm-commissions-reporting.COMISIONES.v_repartos_alterna`
  WHERE id_mes = CAST(mes_string AS INT64)
) AS 'Falta por agregar id_mes para realizar el reparto'

;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_repartos` AS

WITH reparto_X001_42 AS
(
SELECT
      concepto
     ,'42' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_42) AS arr
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_alterna`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6
     )
)


SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_42, UNNEST(COALESCE(arr, ['20'])) cod_tipo_contrato
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_base_comisiones` AS

SELECT
      REPARTOS.concepto
     ,mes_int AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,TRANSACCIONES.* EXCEPT(concepto, id_mes, mes_liquidado)
     
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.ralt_repartos` REPARTOS
          ON TRANSACCIONES.cod_segmento = REPARTOS.cod_segmento AND TRANSACCIONES.sociedad = REPARTOS.sociedad
           AND TRANSACCIONES.cod_tipo_contrato = REPARTOS.cod_tipo_contrato

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_repartos_alterna`
           WHERE id_mes = mes_int
           GROUP BY 1,2,3,4,5,6
           ) RAPPEL
          ON TRANSACCIONES.id_comisionista = RAPPEL.seller AND REPARTOS.concepto = RAPPEL.concepto AND RAPPEL.importe <> 0

WHERE TRANSACCIONES.id_mes = mes_int
      AND TRANSACCIONES.commission_id LIKE 'ARAL%'
      AND TRANSACCIONES.concepto IN (
                                    'D - Upfront Acuerdo Alterna 2022'
                                    )
      AND TRANSACCIONES.line_type_ds <> 'ADDITIONAL'

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_unitario` AS

SELECT
      BASE.id_comisionista
     ,BASE.concepto
     ,RAPPEL.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.ralt_base_comisiones` BASE

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_repartos_alterna`
           WHERE id_mes = mes_int
           GROUP BY 1,2,3,4,5,6
           ) RAPPEL
          ON BASE.concepto = RAPPEL.concepto AND BASE.id_comisionista = RAPPEL.seller

WHERE RAPPEL.importe <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||BASE.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,BASE.agrupacion_canal /*DEALER.agrupacion_canal*/ 
     ,BASE.canal /*DEALER.canal*/ 
     ,BASE.concepto
     ,BASE.tipo_concepto
     ,BASE.unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision
     ,BASE.id_comisionista /*DEALER.nombre_comercio*/ AS id_comisionista
     ,BASE.distribuidor
     ,BASE.sfid_id
     ,BASE.seller
     ,BASE.nombre_comercio /*DEALER.nombre_comercio*/ AS nombre_comercio
     ,BASE.razon_social /*DEALER.razon_social*/ AS razon_social
     ,BASE.cif /*DEALER.cif*/ AS cif
     ,BASE.zona_fiscal /*DEALER.zona_fiscal*/ AS zona_fiscal
     ,BASE.marca

     ,CASE WHEN BASE.service_type = 'FIX' THEN 'INTERNET' ELSE BASE.service_type END AS service_type

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
     ,'30' AS cod_canal
     ,BASE.claim_code
     ,BASE.campaign_code
     ,CAST(NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64)  AS tax_base
     ,BASE.process_code
     ,BASE.comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.TEMP.ralt_base_comisiones` BASE

-- INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
--           ON BASE.concepto = CONCEPTOS.concepto
/*
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON BASE.distribuidor = DEALER.sfid_id AND DEALER.id_mes = mes_int
*/
LEFT JOIN `mm-commissions-reporting.TEMP.ralt_unitario` UNITARIO
         ON BASE.id_comisionista = UNITARIO.id_comisionista AND BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_correccion` AS

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
            ,SUM(comision) OVER (PARTITION BY id_comisionista, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.ralt_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY id_comisionista, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.ralt_unitario` UNITARIO
         ON CALCULO.id_comisionista = UNITARIO.id_comisionista AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_cruzado` AS

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
     SELECT * FROM `mm-commissions-reporting.TEMP.ralt_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.ralt_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt_no_cruzado` AS
SELECT
      prefijo||'_'||mes_string||'_'||'ALT'||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,'B2B - Alterna' /*DEALER.agrupacion_canal*/ AS agrupacion_canal
     ,'ALT' /*DEALER.canal*/ AS canal
     ,RAPPEL.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,RAPPEL.importe AS comision
     ,'F40411' /*DEALER.id_comisionista*/ AS id_comisionista
     ,'F40411' /*DEALER.distribuidor*/ AS distribuidor
     ,CAST(NULL AS STRING) AS sfid_id
     ,CAST(NULL AS STRING) AS seller
     ,'THE TELECOM BOUTIQUE, S.L.' /*DEALER.nombre_comercio*/ AS nombre_comercio
     ,'THE TELECOM BOUTIQUE, S.L.' /*DEALER.razon_social*/ AS razon_social
     ,'B87522652' /*DEALER.cif*/ AS cif
     ,'PEN' /*DEALER.zona_fiscal*/ AS zona_fiscal
     ,'ALTERNA' AS marca

     ,CASE WHEN COALESCE(SPLIT(RAPPEL.reparto_X001_42)[OFFSET(0)], '61') = '61' THEN 'INTERNET' ELSE 'MOBILE' END AS service_type

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
     ,'42' AS cod_segmento
     ,'09' AS cod_marca
     ,COALESCE(SPLIT(RAPPEL.reparto_X001_42)[OFFSET(0)], '61') AS cod_tipo_contrato
     ,'040' AS cod_producto
     ,'30' AS cod_canal
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS campaign_code
     ,CAST(NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64)  AS tax_base
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_repartos_alterna`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6
     ) RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto
/*
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON RAPPEL.seller = DEALER.sfid_id AND DEALER.id_mes = mes_int
*/
LEFT JOIN `mm-commissions-reporting.TEMP.ralt_unitario` UNITARIO
         ON RAPPEL.seller = UNITARIO.id_comisionista AND RAPPEL.concepto = UNITARIO.concepto

WHERE UNITARIO.id_comisionista IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ralt` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.ralt_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.ralt_no_cruzado`
     )
WHERE comision IS NOT NULL
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.id_comisionista
FROM (SELECT id_comisionista, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.ralt` GROUP BY 1) REPARTO
LEFT JOIN (SELECT seller, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_repartos_alterna` WHERE id_mes = mes_int GROUP BY 1) GS
         ON REPARTO.id_comisionista = GS.seller
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('RALT_', mes_int, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.ralt), 'TEMP.ralt', 'ACTUALIZAR');


END