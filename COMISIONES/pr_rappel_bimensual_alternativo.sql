BEGIN
DECLARE prefijo, mes_string STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'RPBI';

SET canales_pr = COALESCE(canales_pr, ['ALTN']);

/*
CALL COMISIONES.pr_rappel_bimensual_alternativo (202606,['ALTN']);
*/



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_bimensual_agrupado` AS (
  SELECT 
  --  SEGMENTACION.CODIGO_PDV
  SEGMENTACION.ID_PDV
  ,SUM(SEGMENTACION.ALTAS_FIJO) AS ALTAS_FIJO

  -- FROM `mm-commissions-reporting.GS.ALTERNATIVO_SEGMENTACION_FIJO` SEGMENTACION
  -- FROM  `mm-commissions-reporting.GS.SEGMENTACION_ALTERNATIVO_FIJO` SEGMENTACION
  FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.SEGMENTACION_MENSUAL_ALTERNATIVO_FIJO` SEGMENTACION

  LEFT JOIN ( SELECT  
              --CODIGO_PDV,
              ID_PDV, 
              count(*) AS TOTAL
              -- FROM `mm-commissions-reporting.GS.ALTERNATIVO_SEGMENTACION_FIJO` 
              -- FROM `mm-commissions-reporting.GS.SEGMENTACION_ALTERNATIVO_FIJO`
              FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.SEGMENTACION_MENSUAL_ALTERNATIVO_FIJO`
              WHERE MES IN (ID_MES_PR,CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS INT64))
              -- AND TRAMO_FIJO != 'Sin altas'
              GROUP BY ALL)CONTEO
              -- ON CONTEO.CODIGO_PDV = SEGMENTACION.CODIGO_PDV
              ON CONTEO.ID_PDV = SEGMENTACION.ID_PDV

  WHERE SEGMENTACION.MES IN (ID_MES_PR,CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS INT64))
  AND CONTEO.TOTAL = 2

  GROUP BY ALL
)
;

------- SEGMENTACION BIMENSUAL ---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_bimensual_config` AS (
  
  SELECT 
  --ID_PDV.sfid_digo, ID_PDV.sfid_id, SEGMENTACION.*,GS.*
  ID_PDV.sfid_unico AS sfid_digo, ID_PDV.sfid as sfid_id,
  SEGMENTACION.*, GS.*

  FROM `mm-commissions-reporting.TEMP.rappel_bimensual_agrupado` SEGMENTACION

  LEFT JOIN  `mm-commissions-reporting.GS.ALTERNATIVO_RAPPEL_BIMENSUAL` GS

   ON SEGMENTACION.ALTAS_FIJO BETWEEN GS.RANGO_INI AND GS.RANGO_FIN 
    AND ID_MES_PR BETWEEN GS.MES_INICIO AND GS.MES_FIN

  -- LEFT JOIN `mm-commissions-reporting.GS.DIS_digo_unico` ID_PDV
  -- ON SEGMENTACION.CODIGO_PDV  = ID_PDV.sfid_digo
  
  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` ID_PDV
  ON SEGMENTACION.ID_PDV = ID_PDV.sfid_unico



)
;


----- TABLA BASE RAPPEL BIMENSUAL FIJO PDV ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_bimensual_base` AS (


  SELECT 
  TRANSACCIONES.*

  FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS
    ON VENTAS.service_id = TRANSACCIONES.service_id

  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND TRANSACCIONES.CONCEPTO IN ('A - Servicio Fijo','Z - Servicio Fijo' )
  AND DATE_TRUNC(COALESCE(VENTAS.deactivation_date,'9999-12-31'), MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND CAST(TRANSACCIONES.id_mes AS STRING) IN (
    mes_string, 
    CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS STRING))

  )  

;
---- D - Rappel Bimensual (RAPPEL BIMENSUAL PDV UNITARIO) -----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_bimensual` AS (
  SELECT  
  'RPBI' ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id
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
  ,BASE.claim_code
  ,BASE.serial_number
  ,BASE.tax_base
  ,CAST (NULL AS STRING) AS campaign_code
  ,'RAPPEL_BIMENSUAL_'||mes_string AS process_code
  ,BASE.comments
  ,'C_MANUAL' AS facturador
  ,BASE.sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado


  FROM `mm-commissions-reporting.TEMP.rappel_bimensual_base` BASE

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
  ON BASE.sfid_id = DEALER.sfid_id AND DEALER.id_mes = ID_MES_PR

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_bimensual_config` CONFIG
  ON BASE.sfid_id = CONFIG.sfid_id 

  WHERE CONFIG.PRECIO > 0
  
  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id ORDER BY BASE.sale_date DESC) = 1)

;



CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RPBI', id_mes_pr, ['ALTN'], 'TEMP.rappel_bimensual', 'ACTUALIZAR');



END