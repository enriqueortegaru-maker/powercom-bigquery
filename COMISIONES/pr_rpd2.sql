BEGIN


DECLARE prefijo, mes_string, id_mes_2 STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

SET id_mes_2 = FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET prefijo = 'RPD2';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);


-- CALL `mm-commissions-reporting.COMISIONES.pr_rpd2`(202507,['D2D','D2N','DEM']);


ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.seller
FROM `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` REPARTOS
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON REPARTOS.seller = DEALER.sfid_id
            AND DEALER.id_mes = id_mes_pr AND DEALER.agrupacion_canal = 'D2D' AND comisiona
WHERE DEALER.sfid_id IS NULL AND REPARTOS.importe <> 0
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_repartos` AS

WITH reparto_X001_10 AS
(
SELECT
      concepto
     ,'10' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_10) AS arr
FROM `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` v
WHERE id_mes = id_mes_pr
)
,

reparto_X001_12 AS
(
SELECT
      concepto
     ,'12' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_12) AS arr
FROM `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` v
WHERE id_mes = id_mes_pr
)
,

reparto_7000_10 AS
(
SELECT
      concepto
     ,'10' AS cod_segmento
     ,'7000' AS sociedad
     ,SPLIT(reparto_7000_10) AS arr
FROM `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` v
WHERE id_mes = id_mes_pr
)

SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_10, UNNEST(arr) cod_tipo_contrato
UNION DISTINCT
SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_X001_12, UNNEST(arr) cod_tipo_contrato
UNION DISTINCT
SELECT DISTINCT
        concepto
       ,cod_segmento
       ,sociedad
       ,cod_tipo_contrato
FROM reparto_7000_10, UNNEST(arr) cod_tipo_contrato
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_base_comisiones` AS

SELECT

     CASE WHEN TRANSACCIONES.concepto IN ( 'P - Penalizacion Venta Telefonica') THEN 'P - Penalizacion Venta Telefonica'
          WHEN TRANSACCIONES.concepto IN ( 'P - Penalizacion CIF')              THEN 'P - Penalizacion CIF'
     ELSE REPARTOS.concepto END AS concepto
     ,id_mes_pr AS id_mes
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,TRANSACCIONES.* EXCEPT(concepto, id_mes, mes_liquidado)
     
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.rpd2_repartos` REPARTOS
          ON TRANSACCIONES.cod_segmento = REPARTOS.cod_segmento AND TRANSACCIONES.sociedad = REPARTOS.sociedad AND TRANSACCIONES.cod_tipo_contrato = REPARTOS.cod_tipo_contrato

INNER JOIN `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` RAPPEL
          ON TRANSACCIONES.sfid_id = RAPPEL.seller 
             AND REPARTOS.concepto = RAPPEL.concepto 
             AND RAPPEL.id_mes =  id_mes_pr
             AND RAPPEL.importe <> 0


WHERE 
  (
    -- Penalizaciones para canal D2D en mes en curso
    TRANSACCIONES.CANAL = 'D2D'
    AND TRANSACCIONES.id_mes = id_mes_pr
    AND (
      (REPARTOS.concepto = 'P - Penalizacion CIF' AND TRANSACCIONES.concepto = 'P - Penalizacion CIF') OR
      (REPARTOS.concepto = 'P - Penalizacion Venta Telefonica' AND TRANSACCIONES.concepto = 'P - Penalizacion Venta Telefonica')
    )
  )
  OR (
    -- Penalizaciones para canales D2N y DEM en mes siguiente
    TRANSACCIONES.CANAL IN ('D2N', 'DEM')
    AND TRANSACCIONES.id_mes = CAST (id_mes_pr AS INT64)
     -- AND (
     -- TRANSACCIONES.commission_id LIKE 'PCIF_202506%'
     -- OR TRANSACCIONES.commission_id LIKE 'PTLF_202506%'
     -- )

    AND (
      (REPARTOS.concepto = 'P - Penalizacion CIF' AND TRANSACCIONES.concepto = 'P - Penalizacion CIF') OR
      (REPARTOS.concepto = 'P - Penalizacion Venta Telefonica' AND TRANSACCIONES.concepto = 'P - Penalizacion Venta Telefonica')
    )
  )
  OR (
    -- OTROS CONCEPTOS
    REPARTOS.concepto NOT IN ('P - Penalizacion CIF', 'P - Penalizacion Venta Telefonica')
    AND TRANSACCIONES.concepto = 'A - Servicio Fijo'
    AND TRANSACCIONES.id_mes = id_mes_pr
  )


QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_unitario` AS

SELECT
      BASE.sfid_id
     ,BASE.concepto
     ,RAPPEL.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.rpd2_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` RAPPEL
          ON BASE.concepto = RAPPEL.concepto 
            AND BASE.sfid_id = RAPPEL.seller 
            AND RAPPEL.id_mes = id_mes_pr

WHERE RAPPEL.importe <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_calculo` AS

SELECT
      prefijo||'_'||id_mes_pr||'_'||BASE.canal||'_REP_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,CASE 
          WHEN DEALER.canal in ('D2D','D2N', 'DEM') THEN PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
          
          ELSE DATE_ADD((PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))),INTERVAL 1 MONTH)
          END
           AS mes_liquidado

     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,BASE.concepto
     ,CONCEPTOS.tipo_concepto
     ,BASE.unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.id_comisionista ELSE DEALER.id_comisionista END AS id_comisionista

     ,BASE.distribuidor
     ,BASE.sfid_id
     ,BASE.seller

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.nombre_comercio ELSE DEALER.nombre_comercio END AS nombre_comercio

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.razon_social ELSE DEALER.razon_social END AS razon_social

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.cif ELSE DEALER.cif END AS cif

     ,CASE WHEN SUBSTR(BASE.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.zona_fiscal ELSE DEALER.zona_fiscal END AS zona_fiscal

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
     ,'22' AS cod_canal
     ,BASE.campaign_code
     ,BASE.serial_number
     ,BASE.tax_base
     ,BASE.claim_code
     ,BASE.process_code
     ,BASE.comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.TEMP.rpd2_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON BASE.sfid_id = DEALER.sfid_id AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.rpd2_unitario` UNITARIO
         ON BASE.sfid_id = UNITARIO.sfid_id AND BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_correccion` AS

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
            ,SUM(comision) OVER (PARTITION BY sfid_id, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.rpd2_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.rpd2_unitario` UNITARIO
         ON CALCULO.sfid_id = UNITARIO.sfid_id AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_cruzado` AS

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
     SELECT * FROM `mm-commissions-reporting.TEMP.rpd2_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.rpd2_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2_no_cruzado` AS
SELECT
      prefijo||'_'||id_mes_pr||'_R'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,CASE 
          WHEN DEALER.canal IN ('D2N', 'DEM','D2D') THEN PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
          
          ELSE DATE_ADD((PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))),INTERVAL 1 MONTH)
          END
           AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,RAPPEL.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,RAPPEL.importe AS comision

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.id_comisionista ELSE DEALER.id_comisionista END AS id_comisionista

     ,DEALER.distribuidor
     ,DEALER.sfid_id
     ,DEALER.sfid_id AS seller

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.nombre_comercio ELSE DEALER.nombre_comercio END AS nombre_comercio

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.razon_social ELSE DEALER.razon_social END AS razon_social

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.cif ELSE DEALER.cif END AS cif

     ,CASE WHEN SUBSTR(RAPPEL.concepto, 1, 1) IN ('F', 'H', 'Y') THEN MASTER.zona_fiscal ELSE DEALER.zona_fiscal END AS zona_fiscal

     ,CASE WHEN DEALER.canal = 'D2N' THEN 'YOIGO' ELSE 'MASMOVIL' END AS marca

     ,CASE WHEN COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') = '61' THEN 'INTERNET' ELSE 'MOBILE' END AS service_type

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
     ,'12' AS cod_segmento
     ,'05' AS cod_marca
     ,COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') AS cod_tipo_contrato
     ,'040' AS cod_producto
     ,'22' AS cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON RAPPEL.seller = DEALER.sfid_id AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

LEFT JOIN `mm-commissions-reporting.TEMP.rpd2_unitario` UNITARIO
         ON RAPPEL.seller = UNITARIO.sfid_id AND RAPPEL.concepto = UNITARIO.concepto

WHERE IF(SUBSTR(RAPPEL.SELLER,1,3) = 'D2D', RAPPEL.id_mes,RAPPEL.id_mes - 1) = id_mes_pr AND UNITARIO.sfid_id IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rpd2` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||id_mes_pr||'_'||canal||'_REP_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.rpd2_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.rpd2_no_cruzado`
     )
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.sfid_id
FROM (SELECT sfid_id, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.rpd2` GROUP BY 1) REPARTO
LEFT JOIN (SELECT seller, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_repartos_d2d_rappel_mensual` WHERE id_mes = id_mes_pr GROUP BY 1) GS
         ON REPARTO.sfid_id = GS.seller
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);




---INSERTAR D2D ID_MES_PR ----


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D','D2N','DEM'], 'mm-commissions-reporting.TEMP.rpd2', 'ACTUALIZAR');

END