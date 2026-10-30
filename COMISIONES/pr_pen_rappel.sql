BEGIN

DECLARE prefijo, mes_string STRING;
 

SET mes_string = CAST(id_mes_pr AS STRING);

--SET id_mes_2 = FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET prefijo = 'PCIF';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

/*
CALL COMISIONES.pr_pen_rappel (202511,['D2D','D2N','DEM']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ventas_por_distribuidor` AS (


WITH total_ventas AS (
SELECT 
    CIF_EQUIV.grupo_cif, 
    COUNT(*) AS total

  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base_net` VENTAS
    ON TRANSACCIONES.account_id = VENTAS.account_id 
    AND TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) 
    AND TRANSACCIONES.customer_id = VENTAS.customer_id
    AND TRANSACCIONES.service_id = VENTAS.service_id

  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF_EQUIV
    ON TRANSACCIONES.cif = CIF_EQUIV.cif 

  WHERE TRANSACCIONES.id_mes = id_mes_pr
    AND TRANSACCIONES.CANAL IN UNNEST(canales_pr)
    AND TRANSACCIONES.concepto LIKE 'A - Servicio Fijo'
    -- AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    -- AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), MONTH)
    AND TRANSACCIONES.cod_segmento = '12'
  GROUP BY CIF_EQUIV.grupo_cif
)

SELECT 
  CIF_EQUIV.grupo_cif, 
  total_ventas.total,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'NIF' THEN VENTAS.service_id END) AS NIF,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'CIF' THEN VENTAS.service_id  END) AS CIF,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'DNI' THEN VENTAS.service_id  END) AS DNI,
  COUNT(CASE WHEN VENTAS.customer_document_type = 'TR' THEN VENTAS.service_id  END) AS TR,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'NIF' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_nif,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'CIF' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_cif,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'DNI' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_dni,
  ROUND((COUNT(CASE WHEN VENTAS.customer_document_type = 'TR' THEN VENTAS.service_id  END) * 100.0 / total_ventas.total),2) AS porcentaje_tr

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base_net` VENTAS
  ON TRANSACCIONES.account_id = VENTAS.account_id 
  AND TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING) 
  AND TRANSACCIONES.customer_id = VENTAS.customer_id
  AND TRANSACCIONES.service_id = VENTAS.service_id

LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF_EQUIV
  ON TRANSACCIONES.cif = CIF_EQUIV.cif  
  
LEFT JOIN total_ventas 
  ON CIF_EQUIV.grupo_cif = total_ventas.grupo_cif

WHERE TRANSACCIONES.id_mes = id_mes_pr
  AND TRANSACCIONES.CANAL IN UNNEST(canales_pr)
  AND TRANSACCIONES.concepto LIKE 'A - Servicio Fijo'
  -- AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  -- AND DATE_TRUNC(TRANSACCIONES.activation_date, MONTH) = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), MONTH)
  AND TRANSACCIONES.cod_segmento = '12'

GROUP BY CIF_EQUIV.grupo_cif, total_ventas.total
ORDER BY CIF_EQUIV.grupo_cif, porcentaje_cif DESC
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PCIF` AS (
  SELECT  
  prefijo ||'_'||mes_string||'_'||S.CANAL||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
  S.mes_liquidado AS mes_liquidado,
  id_mes_pr AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'P - Penalizacion CIF' concepto,
  S.tipo_concepto,
  S.unidades,
  S.comision * -1 AS comision,
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
  'Penalizacion - CIF' AS comments,
 'C_MANUAL' AS facturador,
  S.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado
  FROM `mm-commissions-reporting.COMISIONES.transacciones` S
  

  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF_EQUIV
    ON S.cif = CIF_EQUIV.cif

  LEFT JOIN  `mm-commissions-reporting.TEMP.ventas_por_distribuidor` VENTAS
    ON CIF_EQUIV.grupo_cif = VENTAS.grupo_cif
    
  WHERE S.CONCEPTO LIKE 'D - Rappel Fijo%'
  AND S.CANAL IN UNNEST (canales_pr)
  AND VENTAS.porcentaje_cif < 5
  AND S.id_mes = CASE 
                  WHEN S.CANAL IN ('D2D','D2N', 'DEM') THEN CAST(FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))) AS INT64) 
                  ELSE id_mes_pr 
                END

)

;

DELETE FROM `mm-commissions-reporting.TEMP.PCIF`
WHERE comision = 0

;


-----INSERTAR D2D ID_MES_PR ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D','D2N','DEM'], 'mm-commissions-reporting.TEMP.PCIF', 'ACTUALIZAR');


-- -----INSERTAR D2N y DEM ID_MES_PR +1----
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PCIF_temp` AS(
-- SELECT *
-- FROM `mm-commissions-reporting.TEMP.PCIF`
-- WHERE CANAL IN ('D2N','DEM'))
-- ;
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, CAST(id_mes_2 AS INT64), ['D2N','DEM'], 'mm-commissions-reporting.TEMP.PCIF_temp', 'ACTUALIZAR');

END