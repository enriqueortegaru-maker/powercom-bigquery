BEGIN
DECLARE prefijo, mes_string, max_comisiones STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'RPFJ';

SET canales_pr = COALESCE(canales_pr, ['ALTN','ALTNC','ALTNH']);


/*
CALL COMISIONES.pr_rappel_fijo_alt (202609,['ALTN']);
*/


--- BORRAMOS REGISTROS SI TIENEN EL MISMO ID MES DE LA TABLA BASE HISTÓRICA --
DELETE FROM
`mm-commissions-reporting.NO_EXCLUSIVO.base_rappel_fijo`
WHERE id_mes = PARSE_DATE('%Y%m', mes_string);


--- CREAMOS TABLA BASE PARA RAPPEL FIJO (histórica) ---
INSERT INTO `mm-commissions-reporting.NO_EXCLUSIVO.base_rappel_fijo` (

WITH SEGMENTACION AS(

-- VENTAS GMM NO ACTIVADAS EN MES EN CURSO --
SELECT
T.marca	,
T.service_id	,
T.account_id	,
T.customer_id	,
T.service_type	,
T.line_type_ds	,
T.bundle_type	,
T.technology_ds	,
T.billing_type_ds	,
T.phone_nm	,
T.sale_date	,
T.activation_date	,
T.deactivation_date	,
T.order_type_agg	,
T.tariff_id	,
T.tariff_ds	,
T.cod_segmento	,
T.cod_marca	,
T.cod_tipo_contrato	,
T.cod_producto	,
T.cod_canal	,
T.agrupacion_canal	,
T.sfid_id	,
T.seller	,
T.user_store ,
T.cancellation_day_id	,
OPTICO.sfid_unico



FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` T

left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`  b on
     ( T.sfid_id = b.sfid_id 
  or (T.seller_formato_tms = b.sfid_id AND T.agrupacion_canal NOT IN ('No Exclusivo'))
  or T.seller = b.sfid_id
  or T.sfid_id    || '-' || T.seller = replace ( b.sfid_id , ' ', '') )


LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
    ON b.sfid_id = OPTICO.sfid

WHERE B.canal IN ('ALTN', 'ALTNH', 'ALTNC')
    AND DATE_TRUNC(T.sale_date, MONTH) = PARSE_DATE('%Y%m', mes_string)
    AND (T.activation_date IS NULL OR FORMAT_DATE('%Y%m', T.activation_date) > mes_string)
    AND (
        (marca != 'PEPEPHONE' AND T.service_type = 'FIX') OR
        (marca = 'PEPEPHONE' AND T.service_type = 'INTERNET')
        )
    AND T.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
    AND T.comisionamiento LIKE 'Comisiona%'
    -- AND OPTICO.estado !='BAJA'
    AND T.MARCA NOT IN ('SIMYO','JAZZTEL')


GROUP BY ALL

UNION ALL
-- VENTAS ACTIVADAS GMM (INCLUYE ALGUNA RETRAMITADA)--
SELECT  
T.marca	,
T.service_id	,
T.account_id	,
T.customer_id	,
T.service_type	,
T.line_type_ds	,
T.bundle_type	,
T.technology_ds	,
T.billing_type_ds	,
T.phone_nm	,
T.sale_date	,
T.activation_date	,
T.deactivation_date	,
T.order_type_agg	,
T.tariff_id	,
T.tariff_ds	,
T.cod_segmento	,
T.cod_marca	,
T.cod_tipo_contrato	,
T.cod_producto	,
T.cod_canal	,
T.agrupacion_canal	,
T.sfid_id	,
T.seller	,
T.seller AS user_store ,
T.deactivation_date AS cancellation_day_id ,
OPTICO.sfid_unico


FROM `mm-commissions-reporting.COMISIONES.transacciones` T

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
    ON T.sfid_id = OPTICO.sfid

WHERE T.canal IN ('ALTN')
    AND T.id_mes = id_mes_pr
    AND DATE_TRUNC(T.sale_date, MONTH) = PARSE_DATE('%Y%m', mes_string)
    AND T.concepto IN ( 'A - Servicio Fijo')
    AND T.MARCA NOT IN ('SIMYO','JAZZTEL')
    -- AND OPTICO.estado !='BAJA'

GROUP BY ALL

UNION ALL

-- SIMYO Y JAZZTEL --
SELECT
   T.marca	,
T.service_id	,
T.account_id	,
T.customer_id	,
T.service_type	,
T.line_type_ds	,
T.bundle_type	,
T.technology_ds	,
T.billing_type_ds	,
T.phone_nm	,
T.sale_date	,
T.activation_date	,
T.deactivation_date	,
T.order_type_agg	,
T.tariff_id	,
T.tariff_ds	,
T.cod_segmento	,
T.cod_marca	,
T.cod_tipo_contrato	,
T.cod_producto	,
T.cod_canal	,
T.agrupacion_canal	,
T.sfid_id	,
T.seller	,
T.user_store ,
T.cancellation_day_id	,
OPTICO.sfid_unico


FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` T

left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`  b on
     ( T.sfid_id = b.sfid_id 

  or (T.seller_formato_tms = b.sfid_id AND T.agrupacion_canal NOT IN ('No Exclusivo'))
  or T.seller = b.sfid_id
  or T.sfid_id    || '-' || T.seller = replace ( b.sfid_id , ' ', '')
  OR T.user_store = b.sfid_id )


LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
    ON b.sfid_id = OPTICO.sfid

WHERE B.canal IN ('ALTN')
    AND DATE_TRUNC(T.sale_date, MONTH) = PARSE_DATE('%Y%m', mes_string)
    AND T.MARCA IN ('JAZZTEL','SIMYO')
    AND T.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
    AND T.service_type = 'INTERNET'
    AND T.comisionamiento LIKE 'Comisiona%'
    -- AND OPTICO.ESTADO !='BAJA'
GROUP BY ALL)

SELECT 
PARSE_DATE('%Y%m', CAST(mes_string AS STRING)) AS id_mes
,* 
FROM SEGMENTACION
GROUP BY ALL
)


;
------- SEGMENTACION (Para Rappel Fijo PDV y Lotes Fijo) ---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo_conteo` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS(

SELECT 
--  OPTICO.id_empresa,
--  OPTICO.sfid_unico,
  BASE.sfid_unico,
    COUNT(DISTINCT service_id) AS altas,
    COUNT(DISTINCT 
    CASE
      WHEN
        DATE_TRUNC(BASE.deactivation_date, MONTH) = PARSE_DATE('%Y%m', mes_string)
        OR
        DATE_TRUNC(BASE.cancellation_day_id, MONTH) = PARSE_DATE('%Y%m', mes_string)
      THEN BASE.service_id
    END) AS bajas


FROM `mm-commissions-reporting.NO_EXCLUSIVO.base_rappel_fijo` BASE


 

WHERE BASE.id_mes = PARSE_DATE('%Y%m', mes_string)

GROUP BY ALL

)

;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo_config`
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (
WITH AGG AS (
  SELECT
    -- id_empresa,
    sfid_unico,
    SUM(altas) AS altas,
    SUM(bajas) AS bajas,
    SUM(altas - bajas) AS netas
  FROM `mm-commissions-reporting.TEMP.rappel_fijo_conteo`
  GROUP BY
    -- id_empresa
    sfid_unico
)

SELECT
  -- A.id_empresa,
  A.sfid_unico,
  A.altas,
  A.bajas,
  A.netas,
  --- Rappel Fijo ---
  R.CONCEPTO,
  R.CLASIFICACION,
  R.PRECIO,
  --- Rappel Lotes ---
  R.CONCEPTO_LOTES_FIJO,
  R.PRECIO_LOTES_FIJO

FROM AGG A

LEFT JOIN `mm-commissions-reporting.GS.RAPPEL_FIJO` R
  ON A.netas BETWEEN R.RANGO_INI AND R.RANGO_FIN
 AND id_mes_pr BETWEEN R.MES_INICIO AND R.MES_FIN)
;


--- BORRAMOS REGISTROS SI TIENEN EL MISMO ID MES DE LA TABLA BASE HISTÓRICA --
DELETE FROM
`mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.SEGMENTACION_MENSUAL_ALTERNATIVO_FIJO`
WHERE MES = id_mes_pr;

INSERT INTO `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.SEGMENTACION_MENSUAL_ALTERNATIVO_FIJO`  (

SELECT 
id_mes_pr AS MES 
,CAST (NULL AS STRING) AS ID_EMPRESA
,sfid_unico AS ID_PDV
,netas AS ALTAS_FIJO
,CLASIFICACION AS TRAMO_OBTENIDO
,CLASIFICACION AS SEGMENTACION_FIJO

FROM `mm-commissions-reporting.TEMP.rappel_fijo_config`

)
;

----- PDV -------
----- TABLA BASE RAPPEL MENSUAL FIJO PDV ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo_base` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (


  SELECT 
  TRANSACCIONES.*

  FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND TRANSACCIONES.ID_MES = id_mes_pr
  AND TRANSACCIONES.CONCEPTO = 'A - Servicio Fijo' 
  -- AND COALESCE(DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH),'9999-12-31') > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))

  )  

;
---- D - Rappel Mensual (RAPPEL MENSUAL FIJO PDV UNITARIO) -----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (
  SELECT  
  'RPFJD' ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id
  ,'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,BASE.agrupacion_canal
  ,BASE.canal
  ,CONFIG.CONCEPTO as concepto
  ,BASE.tipo_concepto
  ,BASE.unidades
  ,CONFIG.PRECIO * BASE.UNIDADES AS comision
  ,BASE.id_comisionista
  ,BASE.distribuidor
  ,BASE.sfid_id
  ,BASE.seller
  ,BASE.nombre_comercio
  ,BASE.razon_social
  ,BASE.cif
  ,BASE.zona_fiscal
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
  ,BASE.claim_code
  ,BASE.serial_number
  ,BASE.tax_base
  ,BASE.campaign_code
  ,'RAPPEL_FIJO_'||mes_string AS process_code
  ,BASE.comments
  ,'C_MANUAL' AS facturador
  ,BASE.sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado


  FROM `mm-commissions-reporting.TEMP.rappel_fijo_base` BASE

  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
  ON BASE.SFID_ID = OPTICO.SFID
    OR BASE.seller = OPTICO.sfid
    -- OR BASE.user_store = OPTICO.sfid

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fijo_config` CONFIG
  -- ON OPTICO.id_empresa = CONFIG.ID_EMPRESA
  ON OPTICO.sfid_unico = CONFIG.sfid_unico

  WHERE CONFIG.PRECIO > 0
  
  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id ORDER BY BASE.sale_date DESC) = 1)


;


-- RAPPEL LOTES --
--- TABLA PARA EL RANKING DE PDV QUE OPTA A PREMIO CON MAS VENTAS POR ID_EMPRESA --


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.lotes_fijo_ranking_pdv` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (

SELECT
  -- PDV.id_empresa,
  PDV.sfid_unico,
  PDV.netas,
  CONFIG.CLASIFICACION,
  CONFIG.CONCEPTO,
  CONFIG.PRECIO,
  CONFIG.CONCEPTO_LOTES_FIJO,
  CONFIG.PRECIO_LOTES_FIJO
FROM (
  SELECT
    -- id_empresa,
    sfid_unico,
    SUM(altas) - SUM(bajas) AS netas,
    ROW_NUMBER() OVER (
      PARTITION BY sfid_unico
      ORDER BY SUM(altas) - SUM(bajas) DESC, sfid_unico
    ) AS rn
  FROM `mm-commissions-reporting.TEMP.rappel_fijo_conteo`
  GROUP BY
    -- id_empresa,
    sfid_unico
) PDV

LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fijo_config` CONFIG
-- ON PDV.ID_EMPRESA = CONFIG.ID_EMPRESA
ON PDV.sfid_unico = CONFIG.sfid_unico
WHERE rn = 1
)
;


---- D - Rappel Lotes (REPARTO) -----
-- Tabla comisiones --
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.lotes_fijo` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (
SELECT  
  'RPFJL' ||'_'||mes_string||'_'||DEALER.CANAL||'_'||row_number () over () AS commission_id
  ,'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,DEALER.agrupacion_canal
  ,DEALER.canal
  ,PDV.CONCEPTO_LOTES_FIJO as concepto
  ,'UPFR' AS tipo_concepto
  ,1 AS unidades
  ,PDV.PRECIO_LOTES_FIJO / PDV.netas AS comision
  ,DEALER.id_comisionista
  ,DEALER.distribuidor
  ,BASE.sfid_id
  -- ,BASE.seller
  ,BASE.user_store AS seller
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
  ,CAST (NULL AS STRING) AS order_id --- INCLUIR EN TABLA BASE
  ,BASE.order_type_agg
  ,BASE.cod_segmento
  ,BASE.cod_marca
  ,BASE.cod_tipo_contrato
  ,BASE.cod_producto
  ,BASE.cod_canal
  ,CAST (NULL AS STRING) AS claim_code
  ,CAST (NULL AS STRING) AS serial_number
  ,CAST (NULL AS FLOAT64) AS tax_base
  ,CAST (NULL AS STRING) AS campaign_code
  ,'LOTES_FIJO_'||mes_string AS process_code
  ,CAST (NULL AS STRING) AS comments
  ,'C_MANUAL' AS facturador
  ,`mm-commissions-reporting.COMISIONES.f_sociedad`(BASE.marca) AS sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado
  -- ,OPTICO.id_empresa
  -- ,OPTICO.sfid_unico

  FROM `mm-commissions-reporting.NO_EXCLUSIVO.base_rappel_fijo` BASE

  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
  ON BASE.sfid_id = OPTICO.sfid
    OR BASE.seller = OPTICO.sfid
    OR BASE.user_store = OPTICO.sfid

  LEFT JOIN `mm-commissions-reporting.TEMP.lotes_fijo_ranking_pdv` PDV
  ON OPTICO.sfid_unico = PDV.sfid_unico

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
  ON DEALER.sfid_id = BASE.sfid_id 
   OR DEALER.SFID_ID = BASE.seller
   OR DEALER.sfid_id = BASE.user_store

  WHERE PDV.PRECIO_LOTES_FIJO > 0 
  AND BASE.id_mes = PARSE_DATE('%Y%m',mes_string)
  AND (
    BASE.deactivation_date IS NULL
    OR DATE_TRUNC(BASE.deactivation_date, MONTH) != PARSE_DATE('%Y%m', mes_string)
  )
  AND (
    BASE.cancellation_day_id IS NULL
    OR DATE_TRUNC(BASE.cancellation_day_id, MONTH) != PARSE_DATE('%Y%m', mes_string)
  )
  
  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id, BASE.phone_nm ORDER BY BASE.sale_date DESC) = 1

)

;

------- DHO ---------
---- TABLA BASE RAPPEL FIJO DHO ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo_base_DHO` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (


  SELECT 
  TRANSACCIONES.*

  FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND TRANSACCIONES.ID_MES = id_mes_pr
  AND TRANSACCIONES.CONCEPTO = 'F - Servicio Fijo' 
  -- AND COALESCE(DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH),'9999-12-31') > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  ) 

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo_DHO_config` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (
  SELECT 
  OBJETIVOS_DHO.DHO,
  OBJETIVOS_DHO.OBJETIVO,
  OBJETIVOS_DHO.PDV_ACTIVOS,
  RAPPEL_FIJO_DHO.PRECIO,
  RAPPEL_FIJO_DHO.CONCEPTO
FROM 
  `mm-commissions-reporting.GS.OBJETIVOS_DHO` OBJETIVOS_DHO

LEFT JOIN 
  `mm-commissions-reporting.GS.RAPPEL_FIJO_DHO` RAPPEL_FIJO_DHO
  ON OBJETIVOS_DHO.OBJETIVO = RAPPEL_FIJO_DHO.OBJETIVO
  AND OBJETIVOS_DHO.PDV_ACTIVOS = RAPPEL_FIJO_DHO.PDV_ACTIVOS

WHERE OBJETIVOS_DHO.ID_MES = id_mes_pr
AND id_mes_pr BETWEEN RAPPEL_FIJO_DHO.MES_INICIO AND RAPPEL_FIJO_DHO.MES_FIN

)

;


-------- F - Objetivo Mensual (Rappel Mensual Fijo DHO)  ---------

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fijo_DHO` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS (
  SELECT  
    'RPFJF' ||'_'|| mes_string ||'_'|| BASE.CANAL ||'_'|| row_number () over () AS commission_id,
    'calculado' AS estado,
    PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado,
    id_mes_pr AS id_mes,
    BASE.agrupacion_canal,
    BASE.canal,
    CONFIG.CONCEPTO AS concepto,
    BASE.tipo_concepto,
    BASE.unidades,
    CONFIG.PRECIO AS comision,
    BASE.id_comisionista,
    BASE.distribuidor,
    BASE.sfid_id,
    BASE.seller,
    BASE.nombre_comercio,
    BASE.razon_social,
    BASE.cif,
    BASE.zona_fiscal,
    BASE.marca,
    BASE.service_type,
    BASE.phone_nm,
    BASE.tariff_id,
    BASE.tariff_ds,
    BASE.service_id,
    BASE.account_id,
    BASE.customer_id,
    BASE.line_type_ds,
    BASE.bundle_type,
    BASE.technology_ds,
    BASE.billing_type_ds,
    BASE.sale_date,
    BASE.activation_date,
    BASE.deactivation_date,
    BASE.order_id,
    BASE.order_type_agg,
    BASE.cod_segmento,
    BASE.cod_marca,
    BASE.cod_tipo_contrato,
    BASE.cod_producto,
    BASE.cod_canal,
    BASE.claim_code,
    BASE.serial_number,
    BASE.tax_base,
    BASE.campaign_code,
    'RAPPEL_FIJO_DHO'|| mes_string AS process_code,
    BASE.comments,
    'C_MANUAL' AS facturador,
    BASE.sociedad,
    CURRENT_TIMESTAMP AS creado,
    CURRENT_TIMESTAMP AS modificado

  FROM `mm-commissions-reporting.TEMP.rappel_fijo_base_DHO` BASE
  
  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fijo_DHO_config` CONFIG
    ON BASE.id_comisionista = CONFIG.DHO

  WHERE CONFIG.PRECIO > 0

  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id ORDER BY BASE.sale_date DESC) = 1
);

-- D - Incentivo Lotes Fijo

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.incentivolotes_fijo` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS (
SELECT  
  'RPFJI' ||'_'||mes_string||'_'||DEALER.CANAL||'_'||row_number () over () AS commission_id
  ,'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,DEALER.agrupacion_canal
  ,DEALER.canal
  ,'D - Incentivo Lotes Fijo' as concepto
  ,'UPFR' AS tipo_concepto
  ,1 AS unidades
  ,PDV.INCENTIVO/CONTEO.UNIDADES AS comision
  ,DEALER.id_comisionista
  ,DEALER.distribuidor
  ,BASE.sfid_id
  -- ,BASE.seller
  ,BASE.user_store AS seller
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
  ,CAST (NULL AS STRING) AS order_id --- INCLUIR EN TABLA BASE
  ,BASE.order_type_agg
  ,BASE.cod_segmento
  ,BASE.cod_marca
  ,BASE.cod_tipo_contrato
  ,BASE.cod_producto
  ,BASE.cod_canal
  ,CAST (NULL AS STRING) AS claim_code
  ,CAST (NULL AS STRING) AS serial_number
  ,CAST (NULL AS FLOAT64) AS tax_base
  ,CAST (NULL AS STRING) AS campaign_code
  ,'INCENTIVO_LOTES_FIJO_'||'202608' AS process_code
  ,CAST (NULL AS STRING) AS comments
  ,'C_MANUAL' AS facturador
  ,`mm-commissions-reporting.COMISIONES.f_sociedad`(BASE.marca) AS sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado
  -- ,OPTICO.id_empresa
  -- ,OPTICO.sfid_unico

  FROM `mm-commissions-reporting.NO_EXCLUSIVO.base_rappel_fijo` BASE

  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
  ON BASE.sfid_id = OPTICO.sfid
    OR BASE.seller = OPTICO.sfid
    OR BASE.user_store = OPTICO.sfid

  LEFT JOIN `mm-commissions-reporting.GS.INCENTIVO_LOTES_ALTERNATIVO` PDV
  ON OPTICO.sfid_unico = PDV.ID_PDV
  AND PDV.MES = id_mes_pr

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
  ON DEALER.sfid_id = BASE.sfid_id 
   OR DEALER.SFID_ID = BASE.seller
   OR DEALER.sfid_id = BASE.user_store

  LEFT JOIN (
             SELECT sfid_unico, COUNT (*) AS UNIDADES
             FROM (
                    SELECT *
                    FROM `mm-commissions-reporting.NO_EXCLUSIVO.base_rappel_fijo`
                    WHERE id_mes = PARSE_DATE('%Y%m', '202609')
                    QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id, phone_nm ORDER BY service_type DESC) = 1
                  )
              GROUP BY sfid_unico
            ) CONTEO
    ON CONTEO.sfid_unico = PDV.ID_PDV
  
  WHERE PDV.ID_PDV IS NOT NULL
  AND BASE.id_mes = PARSE_DATE('%Y%m',mes_string)

  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.sfid_id, BASE.phone_nm ORDER BY BASE.service_type DESC) = 1
)
;



-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RPFJD', id_mes_pr, canales_pr, 'TEMP.rappel_fijo', 'ACTUALIZAR');
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RPFJL', id_mes_pr, canales_pr, 'TEMP.lotes_fijo', 'ACTUALIZAR');
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RPFJF', id_mes_pr, canales_pr, 'TEMP.rappel_fijo_DHO', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RPFJI', id_mes_pr, canales_pr, 'TEMP.incentivolotes_fijo', 'ACTUALIZAR');


END