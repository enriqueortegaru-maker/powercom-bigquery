BEGIN
DECLARE prefijo, mes_string, id_mes_2, mes_anterior, max_comisiones STRING;


SET mes_string = CAST(id_mes_pr AS STRING);

SET id_mes_2 = FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET mes_anterior = FORMAT_DATE('%Y%m', DATE_SUB(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes_pr AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH));

SET prefijo = 'RAPD';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

SET max_comisiones = (SELECT MAX(_table_suffix) FROM `mm-commissions-reporting.60_EDW_COMMISSIONS.ventas_base_telco_comisiones_*`);

/*
CALL COMISIONES.pr_rapd2d_ajuste (202508,['D2D','D2N','DEM']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste` AS (


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
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.cod_segmento = '12'

  AND TRANSACCIONES.id_comisionista IN ('D2D981' , 'D2N01117') --Solo voy a ajustar la de tigre

  UNION ALL 

  SELECT * 
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
  WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_string
  AND (TRANSACCIONES.CONCEPTO = 'B - Centralitas Base' AND TRANSACCIONES.tariff_id LIKE 'BASE%') -- SE CONTABILIZAN LOS SERVICIOS FIJOS Y LAS CENTRALITAS
  -- AND (DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR TRANSACCIONES.deactivation_date IS NULL)

  UNION ALL
  ----- AÑADIMOS VENTAS RESI PARA D2D981 Y D2N01117 -----
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
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
  AND TRANSACCIONES.id_comisionista IN ('D2D981' , 'D2N01117')
  AND TRANSACCIONES.cod_segmento = '10'


  )  
;

--- EQUIVALENCIAS PARA APLICAR RAPPEL MULTIMARCA ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` AS (
  
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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste_final_ajuste` AS(
  
  WITH PORCENTAJE_2P AS (
    /*Conteo de servicios 2P para calcular el tope del 25% */
    SELECT 
      grupo_cif, 
      SUM(UNIDADES_2P) / SUM(UNIDADES) AS PORCENTAJE_2P,
      SUM(UNIDADES) * 0.25 AS PERMITIDO

    FROM (
          SELECT
          CIF.grupo_cif,
          COUNT(CASE WHEN BASE.bundle_type = '2P' THEN BASE.unidades END) AS UNIDADES_2P,
          COUNT(BASE.UNIDADES) AS UNIDADES
          FROM `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste` BASE
          LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF 
            ON BASE.cif = CIF.cif
           WHERE BASE.CIF NOT IN ('B80108186') ---- NO APLICAMOS TECHO 2P PARA TIGRE// Ya no se hace excepcion a tigre en la llave del 25%
          GROUP BY CIF.grupo_cif

          UNION ALL

          SELECT --CIF.grupo_cif,VBTO_CLEAN. sell_bundle_type, COUNT(*) AS UNIDADES
          CIF.grupo_cif,
          COUNT(CASE WHEN OSP.VBTO_CLEAN.sell_bundle_type= '2P' THEN OSP.phone_nm END) AS UNIDADES_2P,
          COUNT(*) AS UNIDADES

          -- FROM `mm-commissions-reporting.10_CLEANING_COMMISSIONS.ventas_base_telco_osp_*` OSP
          FROM `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp` OSP

          INNER JOIN `mm-commissions-reporting.D2D.SFID_ORANGE`  SFID 
            ON OSP.sfid_id = SFID.SFID

          LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF
            ON SFID.cif = CIF.cif

          WHERE OSP.service_type = 'BROADBAND'
            AND DATE_TRUNC(OSP.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
            AND (DATE_TRUNC(OSP.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR OSP.deactivation_date IS NULL)
            -- AND (OSP.PORT_IN_OPERADORES.grupo_empresa1 != 'MASORANGE' OR OSP.PORT_IN_OPERADORES.grupo_empresa1 IS NULL)

          GROUP BY ALL ) 

    GROUP BY ALL
    ),

    /*Ordenamos por fecha las activaciones 2P*/
    SERVICIOS_2P_NUMERADOS AS (
    SELECT 
      BASE.*, 
      CIF.grupo_cif,
      ROW_NUMBER() OVER (PARTITION BY CIF.grupo_cif ORDER BY BASE.activation_date) AS orden_activacion
    FROM `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste` BASE
    LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF 
      ON BASE.cif = CIF.cif
    WHERE BASE.bundle_type = '2P'
    )

    /* Creamos tabla base sólo con aquellos servicios 2P que están dentro del 25% + FMC + Centralitas*/
    SELECT 
      S2P.* EXCEPT (grupo_cif, orden_activacion)
    FROM SERVICIOS_2P_NUMERADOS S2P
    LEFT JOIN PORCENTAJE_2P P 
      ON S2P.grupo_cif = P.grupo_cif
    WHERE S2P.orden_activacion <= P.PERMITIDO

    UNION ALL 

    SELECT *
    FROM `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste` 
    WHERE (bundle_type !='2P' OR bundle_type IS NULL)
    AND CIF NOT IN ('B80108186')
    
    -- UNIMOS VENTAS DE TIGRE SIN APLICAR EL TOPE DEL 2P --
    
    UNION ALL 
    SELECT * 
    FROM `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste` 
    WHERE (bundle_type !='2P' OR bundle_type IS NULL OR bundle_type = '2P')
    AND CIF  IN ('B80108186')

)

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_contador_ajuste`AS (
 SELECT GRUPO_CIF, SUM(UNIDADES) AS SERVICIOS
 FROM(
      SELECT 
        CIF.grupo_cif,
        SUM(BASE.UNIDADES) AS UNIDADES

        FROM `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste_final_ajuste` BASE

        LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF
          ON BASE.cif = CIF.cif
        
        WHERE BASE.cod_segmento = '12' --- NO CUENTAN LAS ACTIVACIONES DE RESIDENCIAL DEL D2D981 Y D2N01117

        GROUP BY ALL
        
        UNION ALL
      --- AÑADIMOS LAS VENTAS DE ORANGE AL CONTEO ---
        SELECT CIF.grupo_cif, COUNT(*) AS UNIDADES

        -- FROM `mm-commissions-reporting.10_CLEANING_COMMISSIONS.ventas_base_telco_osp_*` OSP

        FROM  `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.ventas_base_telco_osp` OSP

        INNER JOIN `mm-commissions-reporting.D2D.SFID_ORANGE`  SFID 
          ON OSP.sfid_id = SFID.SFID

        LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF
          ON SFID.cif = CIF.cif

        WHERE  OSP.service_type = 'BROADBAND'
          AND DATE_TRUNC(OSP.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
          AND (DATE_TRUNC(OSP.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR OSP.deactivation_date IS NULL)
          AND (OSP.PORT_IN_OPERADORES.grupo_empresa1 != 'MASORANGE' OR OSP.PORT_IN_OPERADORES.grupo_empresa1 IS NULL)

        GROUP BY ALL 

        ---AÑADIMOS CENTRALITAS ORANGE// NO SALEN REGISTROS PORQUE NO ENCONTRAMOS EL CAMPO QUE CRUZA
        UNION ALL

        SELECT CIF.grupo_cif, COUNT(*) AS UNIDADES

        FROM  `mm-datamart-kd.SERVICES.osp_fc_centrex` OSP

        INNER JOIN `mm-commissions-reporting.D2D.SFID_ORANGE`  SFID 
          ON CAST(OSP.SFID_KEY AS STRING) = SFID.SFID

        LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF
          ON SFID.cif = CIF.cif

        WHERE  
           DATE_TRUNC(OSP.ACTIVATION_DATE, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
          AND (DATE_TRUNC(OSP.DEACTIVATION_DATE, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) OR OSP.deactivation_date IS NULL)
          GROUP BY ALL
          
  )
  GROUP BY ALL
);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_config_ajuste` AS (
 
  SELECT *

  FROM `mm-commissions-reporting.TEMP.rappel_fix_contador_ajuste` C

  LEFT JOIN `mm-commissions-reporting.RappelD2D.RAP_MARCO` d

   ON C.SERVICIOS BETWEEN d.RANGO_INI AND d.RANGO_FIN 
   AND d.MES = id_mes_pr 
   AND D.TIPO = 'MENSUAL'
  
  WHERE cast(d.MES as string) = mes_string
  )

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_ajuste` AS (
SELECT  
  prefijo ||'_'||mes_string||'_'||S.CANAL||'_'||'SIN_TRAMO'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE S.mes_liquidado 
    END AS mes_liquidado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Rappel Fijo_'||C.CLASIFICACION as concepto,
  'UPFR'AS tipo_concepto,
  S.unidades,

  CASE WHEN S.cod_segmento = '10' THEN C.PRECIO/2 
       WHEN S.cod_segmento = '12' THEN C.PRECIO
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
  'RAPPEL_'||S.CANAL||'_FIJO_'||mes_string AS process_code,
  S.comments,
 'C_MANUAL' AS facturador,
  S.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado



FROM `mm-commissions-reporting.TEMP.rappel_fix_base_ajuste_final_ajuste` S


  LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D_ajuste` CIF 
    ON S.cif = CIF.cif

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_config_ajuste` C
    ON CIF.grupo_cif = C.grupo_cif
   QUALIFY ROW_NUMBER() OVER (PARTITION BY S.phone_nm, S.concepto ORDER BY S.sale_date DESC) = 1

);


DELETE FROM `mm-commissions-reporting.TEMP.rappel_fix_ajuste`
WHERE comision is null


/*

-----INSERTAR D2D ID_MES_PR ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_temp` AS(
SELECT *
FROM `mm-commissions-reporting.TEMP.rappel_fix_ajuste`
WHERE CANAL IN ('D2D')

)
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D'], 'mm-commissions-reporting.TEMP.rappel_fix_temp', 'ACTUALIZAR');


-----INSERTAR D2N y DEM ID_MES_PR +1----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_temp` AS(
SELECT *
FROM `mm-commissions-reporting.TEMP.rappel_fix_ajuste`
WHERE CANAL IN ('D2N','DEM')
)
;
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, CAST (id_mes_2 AS INT64), ['D2N','DEM'], 'mm-commissions-reporting.TEMP.rappel_fix_temp', 'ACTUALIZAR');
*/
;

END