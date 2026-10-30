BEGIN

DECLARE prefijo, mes_string STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

--SET id_mes_2 = FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET prefijo = 'RPCH';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

/*
CALL COMISIONES.pr_rap_coches (202509,['D2D','D2N','DEM']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_base` AS (


   SELECT 
  TRANSACCIONES.*

  FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

    LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA --- EXCLUIMOS PORTABILIDADES INTRAGRUPO
    ON TRANSACCIONES.phone_nm = CAST (INTRA.phone_nm AS STRING) 
        AND TRANSACCIONES.id_mes = INTRA.mes_activacion
        AND TRANSACCIONES.account_id = INTRA.account_id 
        AND TRANSACCIONES.marca = INTRA.brand_ds

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS
    ON TRANSACCIONES.service_id = VENTAS.service_id

  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_string
  AND TRANSACCIONES.CONCEPTO = 'A - Servicio Fijo' 
  AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  -- AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.cod_segmento = '12'

  UNION ALL 

  SELECT * 
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_string
  AND (TRANSACCIONES.CONCEPTO = 'B - Centralitas Base' AND TRANSACCIONES.tariff_id LIKE 'BASE%') -- SE CONTABILIZAN LOS SERVICIOS FIJOS Y LAS CENTRALITAS
  AND (DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR TRANSACCIONES.deactivation_date IS NULL)
  )
;


--- EQUIVALENCIAS PARA APLICAR RAPPEL MULTIMARCA ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` AS (
  
  SELECT DISTINCT 'CIF_GRUPO_1' AS grupo_cif, Numero_Documento AS cif FROM `mo-b2b-ssme-reporting.LOOKER.OPTICO`
  WHERE Numero_Documento IN ('B70666474', 'B05538095')

  UNION ALL
 
  SELECT DISTINCT 'CIF_GRUPO_2' AS grupo_cif, Numero_Documento AS cif FROM `mo-b2b-ssme-reporting.LOOKER.OPTICO`
  WHERE Numero_Documento IN('B66025776', 'B67602946')

  UNION ALL
  
  SELECT DISTINCT 'CIF_GRUPO_3' AS grupo_cif, Numero_Documento AS cif FROM `mo-b2b-ssme-reporting.LOOKER.OPTICO`
  WHERE Numero_Documento IN('B70446596', 'B70282652')

  UNION ALL

  SELECT DISTINCT 'CIF_GRUPO_4' AS grupo_cif, Numero_Documento AS cif FROM `mo-b2b-ssme-reporting.LOOKER.OPTICO`
  WHERE Numero_Documento IN('B16839458', 'B10759330')

  UNION ALL

  SELECT DISTINCT Numero_Documento AS grupo_cif, Numero_Documento AS cif FROM `mo-b2b-ssme-reporting.LOOKER.OPTICO`
  WHERE Numero_Documento NOT IN ('B70666474', 'B05538095','B66025776', 'B67602946','B70446596', 'B70282652','B16839458', 'B10759330')

)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_contador`AS (
  SELECT GRUPO_CIF, SUM(UNIDADES) AS SERVICIOS
  FROM(
        SELECT 
          CIF.grupo_cif,
          SUM(BASE.UNIDADES) AS UNIDADES

          FROM `mm-commissions-reporting.TEMP.rappel_fix_base` BASE

          LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
            ON BASE.cif = CIF.cif
          
          WHERE BASE.cod_segmento = '12' --- NO CUENTAN LAS ACTIVACIONES DE RESIDENCIAL DEL D2D981 Y D2N01117

          GROUP BY ALL

        --   UNION ALL
        -- --- AÑADIMOS LAS VENTAS DE ORANGE AL CONTEO ---
        --   SELECT CIF.grupo_cif, COUNT(*) AS UNIDADES

        --   FROM `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp` OSP

        --   INNER JOIN `mm-commissions-reporting.D2D.SFID_ORANGE`  SFID 
        --     ON OSP.sfid_id = SFID.SFID

        --   LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
        --     ON SFID.cif = CIF.cif

        --   WHERE OSP.service_type = 'BROADBAND'
        --     AND DATE_TRUNC(OSP.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
        --     AND (DATE_TRUNC(OSP.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR OSP.deactivation_date IS NULL)
        --     AND (OSP.PORT_IN_OPERADORES.grupo_empresa1 != 'MASORANGE' OR OSP.PORT_IN_OPERADORES.grupo_empresa1 IS NULL)

        --   GROUP BY ALL
        )
  GROUP BY ALL

  
  )
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_config` AS (
 
  SELECT 
  CODIGO,
  COUNT(CODIGO) AS COCHES

  FROM `mm-commissions-reporting.RappelD2D.RAP_COCHES` 

  WHERE cast(MES as string) = mes_string

  GROUP BY 1
  )

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches` AS (
  SELECT  
  'RPCH'||'_'||mes_string||'_'||S.CANAL||'_'||'COCHES'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
  S.mes_liquidado AS mes_liquidado,
  id_mes_pr AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Apoyo Coche' as concepto,
  'UPFR' AS tipo_concepto,
  S.unidades,
  
  CASE
    WHEN C.COCHES != 0 THEN
      CASE  -- Límite de 300 €/coche: el tope es absoluto aunque haya factor liga
        WHEN (10 * COALESCE(CASE WHEN S.activation_date >= '2026-07-01' THEN LIGA.porcentaje END, 1) * C2.SERVICIOS) / C.COCHES > 300
          THEN (300 * C.COCHES) / C2.SERVICIOS
        ELSE (10 * COALESCE(CASE WHEN S.activation_date >= '2026-07-01' THEN LIGA.porcentaje END, 1) * S.UNIDADES)
      END
    ELSE 0
  END AS comision,

  S.id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  S.nombre_comercio,
  S.razon_social,
  S.cif,
  S.zona_fiscal,
  S.marca,
  'INTERNET' AS service_type,
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
  'RAPPEL_'||S.CANAL||'_'||'COCHES'||'_'||mes_string AS process_code,
  S.comments,
  'C_MANUAL' AS facturador,
  S.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado



  FROM `mm-commissions-reporting.TEMP.rappel_coches_base` S

  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
    ON S.cif = CIF.cif

  INNER JOIN `mm-commissions-reporting.TEMP.rappel_coches_config` C
    ON S.cif = C.CODIGO 


  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_coches_contador` C2
    ON CIF.grupo_cif= C2.GRUPO_CIF

  LEFT JOIN `mm-commissions-reporting.GS.gs_segmento_liga` LIGA
    ON S.cif = LIGA.cif
   AND LIGA.id_mes = id_mes_pr
    
   QUALIFY ROW_NUMBER() OVER (PARTITION BY S.phone_nm,S.concepto ORDER BY S.sale_date DESC) = 1
)



UNION ALL

--- CLAWBACKS---
SELECT  
  'RPCH'||'_'||mes_string||'_'||T.CANAL||'_CLAW_COCHES_'||row_number () over () AS commission_id,
  'calculado' AS estado,
  V.mes_liquidado AS mes_liquidado,
  id_mes_pr AS id_mes,
  T.agrupacion_canal,
  T.canal,
  'E - Clawback Apoyo Coche'as concepto,
  T.tipo_concepto,
  T.unidades,
  T.comision * -1,
  --COMISIONES.f_comision_clawback(DATE_DIFF(DATE (V.deactivation_date), DATE (V.activation_date), DAY)+1,V.canal,V.tariff_ds) * T.comision AS comision,
  T.id_comisionista,
  T.distribuidor,
  T.sfid_id,
  T.seller,
  T.nombre_comercio,
  T.razon_social,
  T.cif,
  T.zona_fiscal,
  T.marca,
  T.service_type,
  T.phone_nm,
  T.tariff_id,
  T.tariff_ds,
  T.service_id,
  T.account_id,
  T.customer_id,
  T.line_type_ds,
  T.bundle_type,
  T.technology_ds,
  T.billing_type_ds,
  T.sale_date,
  T.activation_date,
  T.deactivation_date,
  T.order_id,
  T.order_type_agg,
  T.cod_segmento,
  T.cod_marca,
  T.cod_tipo_contrato,
  T.cod_producto,
  T.cod_canal,
  T.campaign_code,
  T.serial_number,
  T.tax_base,
  T.claim_code,
  'CLAWBACK_RAPPEL_COCHES_'||V.CANAL||'_'||mes_string AS process_code,
  T.comments,
  'C_MANUAL' AS facturador,
  T.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado

from `mm-commissions-reporting.COMISIONES.transacciones` T
left join `mm-commissions-reporting.COMISIONES.transacciones` V
on V.service_id = T.service_id
where T.concepto IN ('D - Apoyo Coche', 'Z - Apoyo Coche')
AND V.concepto = 'E - Clawback Servicio Fijo'
AND CAST(V.id_mes AS STRING) = mes_string
AND T.commission_id NOT LIKE '%ABONO%' --DESCARTAMOS PROCESOS POSTERIORES 
AND T.commission_id NOT LIKE '%FACTURA%' --DESCARTAMOS PROCESOS POSTERIORES
AND T.commission_id NOT like '%REC%'
AND V.CANAL IN UNNEST (canales_pr)

;

DELETE FROM `mm-commissions-reporting.TEMP.rappel_coches`
WHERE comision is null

;
-----INSERTAR D2D ID_MES_PR ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D','D2N','DEM'], 'mm-commissions-reporting.TEMP.rappel_coches', 'ACTUALIZAR');


-- -----INSERTAR D2N y DEM ID_MES_PR +1----
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_temp` AS(
-- SELECT *
-- FROM `mm-commissions-reporting.TEMP.rappel_coches`
-- WHERE CANAL IN ('D2N','DEM'))
-- ;
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, CAST (id_mes_2 AS INT64), ['D2N','DEM'], 'mm-commissions-reporting.TEMP.rappel_coches_temp', 'ACTUALIZAR');

END