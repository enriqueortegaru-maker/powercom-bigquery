BEGIN
DECLARE prefijo, mes_string STRING;
DECLARE fecha_mes DATE;

SET mes_string = CAST(id_mes_pr AS STRING);

SET fecha_mes = DATE(PARSE_DATE('%Y%m', mes_string));

SET prefijo = 'RPMV';

SET canales_pr = COALESCE(canales_pr, ['ALTN']);


/*
CALL COMISIONES.pr_volumen_movil_alt (202604,['ALTN']);
*/

-- Tabla base para determinar qué ventas computan al incentivo ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.volumen_movil_base` AS (
SELECT 
CASE 
  WHEN DATE_TRUNC(deactivation_date, MONTH) = DATE_TRUNC(fecha_mes, MONTH) THEN 'NO'
  WHEN TARIFAS.PVP IS NOT NULL THEN 'NO'
  ELSE 'SI' END AS computa,
CASE 
  WHEN DATE_TRUNC(deactivation_date, MONTH) = DATE_TRUNC(fecha_mes, MONTH) THEN 'Baja en el mes'
  WHEN TARIFAS.PVP IS NOT NULL THEN 'Tarifa con PVP igual o inferior a 3€'
  ELSE NULL END AS motivo,
fecha_mes AS fecha_datos,
OPTICO.id_empresa,
OPTICO.sfid_unico AS codigo_pdv,
ACTIVACIONES.*

FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
ON ACTIVACIONES.sfid_id = OPTICO.sfid

LEFT JOIN `mm-commissions-reporting.GS.alternativo_tarifas_volumen_movil` TARIFAS
ON ACTIVACIONES.marca = TARIFAS.marca
 AND ACTIVACIONES.tariff_id = TARIFAS.tariff_id
 AND ACTIVACIONES.tariff_ds = TARIFAS.tariff_ds
 AND ACTIVACIONES.bundle_type = TARIFAS.bundle_type
 AND ACTIVACIONES.line_type_ds = TARIFAS.line_type_ds


WHERE ACTIVACIONES.ID_MES = id_mes_pr
AND ACTIVACIONES.CANAL = 'ALTN'
AND ACTIVACIONES.service_type = 'MOBILE'
AND ACTIVACIONES.billing_type_ds = 'POSTPAID'
AND ACTIVACIONES.order_type_agg !='MIGRACION CONTRATO'

)
;

-- Insertamos las ventas que tenemos en cuenta en la tabla histórica para futuras reclamaciones --
BEGIN TRANSACTION;
DELETE
FROM `mm-commissions-reporting.NO_EXCLUSIVO.base_volumen_movil`
WHERE fecha_datos = fecha_mes;

INSERT INTO `mm-commissions-reporting.NO_EXCLUSIVO.base_volumen_movil`
SELECT *
FROM `mm-commissions-reporting.TEMP.volumen_movil_base`;

COMMIT TRANSACTION;

-- Determinamos cantidad de incentivo por id_empresa --
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.volumen_movil_config` AS (
WITH CONTEO AS (
SELECT
 BASE.id_mes,
 OPTICO.sfid_unico AS id_pdv,
 COUNT (*) AS TOTAL 

FROM `mm-commissions-reporting.TEMP.volumen_movil_base` BASE

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
ON BASE.sfid_id = OPTICO.sfid

WHERE BASE.computa ='SI'

GROUP BY
  BASE.id_mes,
  OPTICO.sfid_unico)

SELECT
 CONT.id_mes
 ,CONT.id_pdv
 ,CONT.TOTAL AS ALTAS_NETAS
 ,TRAMOS.CONCEPTO
 ,TRAMOS.CLASIFICACION
 ,TRAMOS.PRECIO
FROM CONTEO CONT

LEFT JOIN `mm-commissions-reporting.GS.VOLUMEN_MOVIL` TRAMOS
ON CONT.TOTAL BETWEEN RANGO_INI AND RANGO_FIN
AND id_mes_pr BETWEEN TRAMOS.MES_INICIO AND TRAMOS.MES_FIN

INNER JOIN `mm-commissions-reporting.GS.ALTERNATIVO_PDV_VOLUMEN_MOVIL` PDV
ON PDV.codigo_pdv = CONT.id_pdv

WHERE PDV.mes = id_mes_pr

)

;
--- Tabla de comisiones final ---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.volumen_movil` AS (
  SELECT  
  -- prefijo ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id
  'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,BASE.agrupacion_canal
  ,BASE.canal
  ,'D - Extracomision Volumen Movil' as concepto
  ,'UPFR'AS tipo_concepto
  ,1 AS unidades
  ,CONFIG.PRECIO / NULLIF(CONFIG.altas_netas, 0) AS comision
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
  ,CAST (NULL AS STRING) AS serial_number
  ,CAST (NULL AS FLOAT64) AS tax_base
  ,CAST (NULL AS STRING) AS campaign_code
  ,CAST (NULL AS STRING) AS process_code
  ,CAST (NULL AS STRING) AS comments
  ,'C_MANUAL' AS facturador
  ,BASE.sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado


  FROM `mm-commissions-reporting.TEMP.volumen_movil_base` BASE

  LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
  ON BASE.sfid_id = OPTICO.sfid
 

  LEFT JOIN `mm-commissions-reporting.TEMP.volumen_movil_config` CONFIG
    ON OPTICO.sfid_unico = CONFIG.id_pdv
    
 
  WHERE CONFIG.PRECIO > 0
  AND BASE.computa = 'SI'

  
  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id ORDER BY BASE.sale_date DESC) = 1)
  ;

ASSERT (
  (
    SELECT
      ROUND(
        (SELECT SUM(comision)
         FROM `mm-commissions-reporting.TEMP.volumen_movil`)
        -
        (SELECT SUM(PRECIO)
         FROM `mm-commissions-reporting.TEMP.volumen_movil_config`),
        2
      )
  ) = 0
)
AS 'ERROR RPMV: La suma de las comisiones calculadas no coincide con la suma de los precios de configuracion por id PDV'

;

-- REPARTO DHO --- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.volumen_movil_config_DHO` AS (
  SELECT 
  DISTRIBUIDOR, 
  COUNT (unidades) as UNIDADES, 
  OBJETIVOS.TRAMO_POSPAGO

  FROM `mm-commissions-reporting.TEMP.volumen_movil` BASE

  LEFT JOIN `mm-commissions-reporting.GS.OBJETIVOS_DHO` OBJETIVOS
  ON BASE.DISTRIBUIDOR = OBJETIVOS.DHO
  AND OBJETIVOS.ID_MES = id_mes_pr

    WHERE distribuidor IS NOT NULL
  GROUP BY ALL
)
;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.volumen_movil_DHO` AS (
  SELECT  
  -- prefijo ||'_'||mes_string||'_'||BASE.CANAL||'_'||row_number () over () AS commission_id
  'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,BASE.agrupacion_canal
  ,BASE.canal
  ,'F - Extracomision Volumen Movil' as concepto
  ,'UPFR'AS tipo_concepto
  ,1 AS unidades
  ,CASE 
   WHEN DHO.TRAMO_POSPAGO = '<90' THEN 0
   WHEN DHO.TRAMO_POSPAGO = '90-100' THEN 1500/ DHO.UNIDADES
   WHEN DHO.TRAMO_POSPAGO = '100-115' THEN 3500/ DHO.UNIDADES
   WHEN DHO.TRAMO_POSPAGO = '>115' THEN 5500/ DHO.UNIDADES
   END AS comision
  ,MASTER.id_comisionista
  ,BASE.distribuidor
  ,BASE.sfid_id
  ,BASE.seller
  ,MASTER.nombre_comercio
  ,MASTER.razon_social
  ,MASTER.cif
  ,MASTER.zona_fiscal
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
  ,CAST (NULL AS STRING) AS serial_number
  ,CAST (NULL AS FLOAT64) AS tax_base
  ,CAST (NULL AS STRING) AS campaign_code
  ,CAST (NULL AS STRING) AS process_code
  ,CAST (NULL AS STRING) AS comments
  ,'C_MANUAL' AS facturador
  ,BASE.sociedad
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado


  FROM `mm-commissions-reporting.TEMP.volumen_movil` BASE

  INNER JOIN `mm-commissions-reporting.TEMP.volumen_movil_config_DHO` DHO
  ON BASE.DISTRIBUIDOR = DHO.DISTRIBUIDOR

  LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
  ON BASE.distribuidor = MASTER.id_comisionista

  WHERE MASTER.id_comisionista IS NOT NULL


  
  QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.service_id ORDER BY BASE.sale_date DESC) = 1)
  ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.volumen_movil_final` AS (
  SELECT *
  ,prefijo || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id 
  FROM (SELECT *
        FROM `mm-commissions-reporting.TEMP.volumen_movil`
  
        UNION ALL

        SELECT *
        
        FROM `mm-commissions-reporting.TEMP.volumen_movil_DHO`
        WHERE COMISION >0)
)  

;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr, 'TEMP.volumen_movil_final', 'ACTUALIZAR');

END