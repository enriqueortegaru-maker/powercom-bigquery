BEGIN

DECLARE prefijo, mes_string, id_mes_2 STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

-- SET id_mes_2 = FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET prefijo = 'PTLF';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

/*
CALL COMISIONES.pr_rap_llamadas (202510,['D2D','D2N','DEM']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cont_venta_telefonica` AS(

  SELECT 
  CIF.grupo_cif
  ,SUM(ventas_auditadas) AS VENTAS 
  ,SUM(ventas_telefonicas) AS VENTA_TELEFONICA
  ,SUM(ventas_telefonicas)/SUM(ventas_auditadas) AS POR_VENTA_TELEFONICA
  FROM `mm-soho-reporting.Query_cache.kpi_calidad_presencial` VT

    LEFT JOIN `mo-b2b-ssme-reporting.LOOKER.OPTICO` OPTICO
    ON VT.sfid_id = OPTICO.ID_UNICO

    LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
    ON OPTICO.Numero_Documento = CIF.cif
    
  WHERE VT.MAIL = 'ainhoa.fernandezs@asesormasmovil.es'
  AND DATE_TRUNC(VT.period, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))

  GROUP BY ALL
  
)

;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rap_llamadas` AS (
  SELECT  
  prefijo ||'_'||mes_string||'_'||S.CANAL||'_'||'LLAMADAS'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
  S.mes_liquidado, 
  S.id_mes,
  S.agrupacion_canal,
  S.canal,
  'P - Penalizacion Venta Telefonica'as concepto,
  S.tipo_concepto,
  S.unidades,
  CASE 
    WHEN  CA.POR_VENTA_TELEFONICA * 100 between 15 AND 25 THEN (0.5 * S.COMISION) * -1
    WHEN  CA.POR_VENTA_TELEFONICA * 100 >= 25 THEN (1 * S.COMISION) * -1
    ELSE 0
  END AS comision,
  s.id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  S.nombre_comercio,
  S.razon_social,
  S.cif,
  S.zona_fiscal,
  S.marca,
  S.service_type,
  S.phone_nm,
  S.tariff_id,
  S.tariff_ds,
  S.service_id,
  S.account_id,
  S.customer_id,
  S.line_type_ds,
  S.bundle_type,
  S.technology_ds,
  S.billing_type_ds,
  S.sale_date,
  S.activation_date,
  S.deactivation_date,
  S.order_id,
  S.order_type_agg,
  S.cod_segmento,
  S.cod_marca,
  S.cod_tipo_contrato,
  S.cod_producto,
  S.cod_canal,
  S.claim_code,
  S.serial_number,
  S.tax_base,
  S.campaign_code,
  S.commission_id AS process_code,
  CASE 
    WHEN  CA.POR_VENTA_TELEFONICA * 100 BETWEEN 15 AND 25 THEN 'Penalizacion - Venta Telefonica 50%'
    WHEN  CA.POR_VENTA_TELEFONICA * 100 >= 25             THEN 'Penalizacion - Venta Telefonica 100%'
    ELSE NULL
  END AS comments,
 'C_MANUAL' AS facturador,
  S.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado


  FROM `mm-commissions-reporting.COMISIONES.transacciones` S
  
  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
    ON CIF.cif = S.cif

  LEFT JOIN `mm-commissions-reporting.TEMP.cont_venta_telefonica` CA
    ON CA.grupo_cif = CIF.grupo_cif 

  WHERE (S.concepto LIKE 'D - Rappel Fijo%' 
         AND NOT EXISTS (
           SELECT 1 
           FROM `mm-commissions-reporting.COMISIONES.transacciones` S2
           WHERE S2.service_id = S.service_id
           AND S2.concepto = 'P - Penalizacion CIF' 
           )
        )
  AND S.CANAL IN UNNEST (canales_pr) 
  AND CAST(S.id_mes AS STRING) = CASE 
        WHEN S.CANAL IN ('D2D','D2N', 'DEM') THEN FORMAT_DATE('%Y%m', DATE(PARSE_DATE('%Y%m', mes_string)))
        ELSE mes_string
      END
      
)

;

DELETE FROM `mm-commissions-reporting.TEMP.rap_llamadas`
WHERE comision = 0

;


-- -----INSERTAR D2D ID_MES_PR ----
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rap_llamadas_temp` AS(
-- SELECT *
-- FROM `mm-commissions-reporting.TEMP.rap_llamadas`
-- WHERE CANAL IN ('D2D'))
-- ;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D','D2N','DEM'], 'mm-commissions-reporting.TEMP.rap_llamadas', 'ACTUALIZAR');


-- -----INSERTAR D2N y DEM ID_MES_PR +1----
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rap_llamadas_temp` AS(
-- SELECT *
-- FROM `mm-commissions-reporting.TEMP.rap_llamadas`
-- WHERE CANAL IN ('D2N','DEM'))
-- ;
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, CAST(id_mes_2 AS INT64), ['D2N','DEM'], 'mm-commissions-reporting.TEMP.rap_llamadas_temp', 'ACTUALIZAR');

END