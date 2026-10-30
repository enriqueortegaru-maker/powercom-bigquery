BEGIN
  DECLARE prefijo, mes_string, max_comisiones STRING;


  SET mes_string = CAST(id_mes_pr AS STRING);

  SET prefijo = 'RAPD';

  SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);

  --SET max_comisiones = (SELECT MAX(_table_suffix) FROM `mm-commissions-reporting.60_EDW_COMMISSIONS.ventas_base_telco_comisiones_*`);

  /*
  CALL COMISIONES.pr_rapd2d (202510,['D2D','D2N','DEM']);
  */

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base` AS (


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
    --AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
    AND TRANSACCIONES.cod_segmento = '12'

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
    -- AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
    AND TRANSACCIONES.id_comisionista IN ('D2D981' , 'D2N01117')
    AND TRANSACCIONES.cod_segmento = '10'


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

    UNION ALL
    SELECT 'B09961558' AS grupo_cif, 'B09961558' AS cif
  ); 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base_final` AS(
    
   WITH PORCENTAJE_2P AS (
      /*Conteo de servicios 2P para calcular el tope del 25% */
      SELECT 
        grupo_cif, 
        SUM(UNIDADES_2P) / SUM(UNIDADES) AS PORCENTAJE_2P,
        SUM(UNIDADES) * 0.25 AS PERMITIDO, 
        SUM(UNIDADES_2P) AS UNIDADES_2P,
        SUM(UNIDADES_3P) AS UNIDADES_3P,
        SUM(UNIDADES_multi_sede) AS UNIDADES_multi_sede,
        SUM(UNIDADES) AS UNIDADES

      FROM (
            SELECT
            CIF.grupo_cif,
            COUNT(CASE WHEN BASE.bundle_type = '2P' AND tariff_ds not like '%MULTISEDE%' THEN BASE.unidades END) AS UNIDADES_2P,
            COUNT(CASE WHEN BASE.bundle_type = '2P' AND tariff_ds like '%MULTISEDE%' THEN BASE.unidades END) AS UNIDADES_multi_sede,
            COUNT(CASE WHEN BASE.bundle_type = 'FMC' THEN BASE.unidades END) AS UNIDADES_3P,
            COUNT(BASE.UNIDADES) AS UNIDADES
            FROM `mm-commissions-reporting.TEMP.rappel_fix_base` BASE
            LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
              ON BASE.cif = CIF.cif
            WHERE BASE.cod_segmento = '12'
            -- WHERE BASE.CIF NOT IN ('B80108186') ---- NO APLICAMOS TECHO 2P PARA TIGRE// Ya no se hace excepcion a tigre en la llave del 25%
            GROUP BY CIF.grupo_cif)

      GROUP BY ALL
      ),

      /*Ordenamos por fecha las activaciones 2P*/
      SERVICIOS_2P_NUMERADOS AS (
      SELECT 
        BASE.*, 
        CIF.grupo_cif,
        ROW_NUMBER() OVER (PARTITION BY CIF.grupo_cif ORDER BY BASE.activation_date) AS orden_activacion
      FROM `mm-commissions-reporting.TEMP.rappel_fix_base` BASE
      LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
        ON BASE.cif = CIF.cif
      WHERE BASE.bundle_type = '2P'
      AND BASE.tariff_ds not like '%MULTISEDE%'  -- Desde oct 25 las multisedes no entran para el techo pero si para las unidades totales
      AND BASE.cod_segmento = '12'
      )

      /* Creamos tabla base sólo con aquellos servicios 2P que están dentro del 25% + FMC + Centralitas*/
      SELECT 
        S2P.* EXCEPT (grupo_cif, orden_activacion)
      FROM SERVICIOS_2P_NUMERADOS S2P
      LEFT JOIN PORCENTAJE_2P P 
        ON S2P.grupo_cif = P.grupo_cif
      WHERE S2P.orden_activacion <= P.PERMITIDO

      UNION ALL 
      /* Agregamos FMC, Centralitas y 2P Multisede */
 
      SELECT *
      FROM `mm-commissions-reporting.TEMP.rappel_fix_base` 
      WHERE (bundle_type !='2P' OR bundle_type IS NULL OR (bundle_type = '2P' AND tariff_ds like '%MULTISEDE%'))
      -- AND CIF NOT IN ('B80108186')
      
      -- UNIMOS VENTAS DE TIGRE SIN APLICAR EL TOPE DEL 2P --
      /*
      UNION ALL 
      SELECT * 
      FROM `mm-commissions-reporting.TEMP.rappel_fix_base` 
      WHERE (bundle_type ='2P' OR bundle_type IS NULL)
      AND CIF  IN ('B80108186')*/

  );

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_contador`AS (
  SELECT GRUPO_CIF, SUM(UNIDADES) AS SERVICIOS
  FROM(
        SELECT 
          CIF.grupo_cif,
          SUM(BASE.UNIDADES) AS UNIDADES

          FROM `mm-commissions-reporting.TEMP.rappel_fix_base_final` BASE

          LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
            ON BASE.cif = CIF.cif
          
          WHERE BASE.cod_segmento = '12' --- NO CUENTAN LAS ACTIVACIONES DE RESIDENCIAL DEL D2D981 Y D2N01117

          GROUP BY ALL
 
            
      ---- AÑADIMOS MANUALMENTE ALTAS DE ORANGE 
UNION ALL SELECT 'B01501287' AS grupo_cif,10 AS UNIDADES --ADEGAR
UNION ALL SELECT 'B16767642' AS grupo_cif,4 AS UNIDADES --GRUPO C22
UNION ALL SELECT 'B52554821' AS grupo_cif,21 AS UNIDADES --AVE FENIX
UNION ALL SELECT 'B67311605' AS grupo_cif,14 AS UNIDADES --BLUE CONNECTION DREAM
UNION ALL SELECT 'B95602967' AS grupo_cif,3 AS UNIDADES --SUCCESS
UNION ALL SELECT 'B22651046' AS grupo_cif,28 AS UNIDADES --BLACKMANGO
UNION ALL SELECT 'A81564445' AS grupo_cif,3 AS UNIDADES --KONECTA
UNION ALL SELECT 'B70282652' AS grupo_cif,7 AS UNIDADES --XMI FORZA
UNION ALL SELECT 'B82439712' AS grupo_cif,2 AS UNIDADES --100 POR 100
UNION ALL SELECT 'CIF_GRUPO_4' AS grupo_cif,35 AS UNIDADES --AML
UNION ALL SELECT 'B06324248' AS grupo_cif,34 AS UNIDADES --ANEVINIP
UNION ALL SELECT 'B54918693' AS grupo_cif,92 AS UNIDADES --ARACEL
UNION ALL SELECT 'B02860211' AS grupo_cif,22 AS UNIDADES --BELIEVE IT
UNION ALL SELECT 'B67315671' AS grupo_cif,5 AS UNIDADES --BMV
UNION ALL SELECT 'B90355942' AS grupo_cif,11 AS UNIDADES --CALABASSA
UNION ALL SELECT 'B01728492' AS grupo_cif,6 AS UNIDADES --CALL SOLUTIONS
UNION ALL SELECT 'B66613506' AS grupo_cif,8 AS UNIDADES --CIBTEL
UNION ALL SELECT 'B95379541' AS grupo_cif,71 AS UNIDADES --CONEXIÓN
UNION ALL SELECT 'B44535946' AS grupo_cif,12 AS UNIDADES --DIGITAL WAP
UNION ALL SELECT 'B95931382' AS grupo_cif,12 AS UNIDADES --DISTELNOR
UNION ALL SELECT 'B56035272' AS grupo_cif,15 AS UNIDADES --G Y C
UNION ALL SELECT 'B23786122' AS grupo_cif,4 AS UNIDADES --JOVALCON
UNION ALL SELECT 'B22658710' AS grupo_cif,17 AS UNIDADES --MAS TREE
UNION ALL SELECT 'B75318311' AS grupo_cif,9 AS UNIDADES --MAVASOL
UNION ALL SELECT 'B36471639' AS grupo_cif,3 AS UNIDADES --MULTISERVICIOS
UNION ALL SELECT 'B54695465' AS grupo_cif,9 AS UNIDADES --NASERTEL
UNION ALL SELECT 'B67802959' AS grupo_cif,43 AS UNIDADES --NEWLAND TELECOM
UNION ALL SELECT 'B19350206' AS grupo_cif,32 AS UNIDADES --NORTIA TELECOM
UNION ALL SELECT 'B56132806' AS grupo_cif,29 AS UNIDADES --OFERTEL PROPYMES
UNION ALL SELECT 'B01637974' AS grupo_cif,6 AS UNIDADES --OMEGA
UNION ALL SELECT 'B67459669' AS grupo_cif,5 AS UNIDADES --ONEXT
UNION ALL SELECT 'B88077011' AS grupo_cif,10 AS UNIDADES --OSHOP
UNION ALL SELECT 'B49196538' AS grupo_cif,16 AS UNIDADES --PROMOVIL
UNION ALL SELECT 'B01623248' AS grupo_cif,2 AS UNIDADES --SOLUCIONES FP
UNION ALL SELECT 'B55697148' AS grupo_cif,8 AS UNIDADES --TELECOMCAT
UNION ALL SELECT 'B53353355' AS grupo_cif,12 AS UNIDADES --TELECONCEPT
UNION ALL SELECT 'B87732020' AS grupo_cif,166 AS UNIDADES --TELMASUR
UNION ALL SELECT 'B56096167' AS grupo_cif,31 AS UNIDADES --VEMA
UNION ALL SELECT 'B26563676' AS grupo_cif,25 AS UNIDADES --WANDATEL
UNION ALL SELECT 'B76779636' AS grupo_cif,3 AS UNIDADES --BIG TENERIFE
UNION ALL SELECT 'B21768874' AS grupo_cif,3 AS UNIDADES --CODE CLOUD
UNION ALL SELECT 'B42223503' AS grupo_cif,8 AS UNIDADES --GEC ASESORAMIENTO
UNION ALL SELECT 'B87377784' AS grupo_cif,2 AS UNIDADES --STUNT
UNION ALL SELECT 'B95172656' AS grupo_cif,4 AS UNIDADES --BIOSS COMUNICACIONES
UNION ALL SELECT 'B83327460' AS grupo_cif,7 AS UNIDADES --INNERIA 
UNION ALL SELECT 'B10918456' AS grupo_cif,4 AS UNIDADES --SFERA 
UNION ALL SELECT 'B70606926' AS grupo_cif,4 AS UNIDADES --HADSMART
UNION ALL SELECT 'B22891154' AS grupo_cif,2 AS UNIDADES --SERGATELCO

        
    )GROUP BY ALL);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_config` AS (
  
    SELECT *

    FROM `mm-commissions-reporting.TEMP.rappel_fix_contador` C

    LEFT JOIN `mm-commissions-reporting.RappelD2D.RAP_MARCO` d

    ON C.SERVICIOS BETWEEN d.RANGO_INI AND d.RANGO_FIN 
    AND d.MES = id_mes_pr 
    AND D.TIPO = 'MENSUAL'
    
    WHERE cast(d.MES as string) = mes_string
    )

  ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix` AS (
  SELECT  
    prefijo ||'_'||mes_string||'_'||S.CANAL||'_'||'SIN_TRAMO'||'_'||row_number () over () AS commission_id,
    'calculado' AS estado,
    S.mes_liquidado AS mes_liquidado,
    id_mes_pr AS id_mes,
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



  FROM `mm-commissions-reporting.TEMP.rappel_fix_base_final` S


    LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
      ON S.cif = CIF.cif

    LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_config` C
      ON CIF.grupo_cif = C.grupo_cif
    QUALIFY ROW_NUMBER() OVER (PARTITION BY S.phone_nm, S.concepto ORDER BY S.sale_date DESC) = 1

  UNION ALL

  --- CLAWBACKS---
  SELECT  
    prefijo||'_'||mes_string||'_'||T.CANAL||'_CLAW_FIJO_'||row_number () over () AS commission_id,
    'calculado' AS estado,
    V.mes_liquidado AS mes_liquidado,
    id_mes_pr AS id_mes,
    T.agrupacion_canal,
    T.canal,
    REPLACE(T.concepto, 'D - Rappel Fijo_', 'E - Clawback Rappel Fijo_') as concepto,
    T.tipo_concepto,
    T.unidades,
    --COMISIONES.f_comision_clawback(DATE_DIFF(DATE (V.deactivation_date), DATE (V.activation_date), DAY)+1,V.canal,V.tariff_ds) * T.comision AS comision,
    T.comision * -1,
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
    'CLAWBACK_RAPPEL_FIJO_'||T.CANAL||'_'||mes_string AS process_code,
    T.comments,
    'C_MANUAL' AS facturador,
    T.sociedad,
    CURRENT_TIMESTAMP AS creado,
    CURRENT_TIMESTAMP AS modificado

  from `mm-commissions-reporting.COMISIONES.transacciones` T
  left join `mm-commissions-reporting.COMISIONES.transacciones` V
  on V.service_id = T.service_id
  where T.concepto like 'D - Rappel Fijo_%'
  AND V.concepto = 'E - Clawback Servicio Fijo'
  AND T.commission_id NOT LIKE '%ABONO%' --DESCARTAMOS PROCESOS POSTERIORES 
  AND T.commission_id NOT LIKE '%FACTURA%' --DESCARTAMOS PROCESOS POSTERIORES'
  AND T.commission_id NOT LIKE '%REC%' --DESCARTAMOS PROCESOS POSTERIORES'
  AND V.CANAL IN UNNEST (canales_pr)
  AND cast (V.id_mes AS STRING) = mes_string
  --  QUALIFY ROW_NUMBER() OVER (PARTITION BY T.phone_nm ORDER BY T.sale_date DESC) = 1


    )
  ;


--- FACTOR SEGMENTACIÓN LIGA (SOLO D2D) ---
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN
UPDATE `mm-commissions-reporting.TEMP.rappel_fix` v
SET comision = v.comision * f.porcentaje
FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
WHERE v.cif = f.cif
  AND f.id_mes = id_mes_pr
  AND v.activation_date >= '2026-07-01'
  AND v.estado = 'calculado'
  AND v.canal IN ('D2D','D2N','DEM')
  AND v.concepto LIKE 'D - Rappel Fijo%';
END IF;


DELETE FROM `mm-commissions-reporting.TEMP.rappel_fix`
WHERE comision is null

  ;

---- Para los incentivos, no podemos contemplar las intragrupo. //ENERO Y FEBRERO 2026 NO HAY INCENTIVOS

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base_no_interco` AS (
--  SELECT TRANSACCIONES.*
--  FROM `mm-commissions-reporting.TEMP.rappel_fix_base` TRANSACCIONES
 
--  LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA --- EXCLUIMOS PORTABILIDADES INTRAGRUPO
--       ON TRANSACCIONES.phone_nm = CAST (INTRA.phone_nm AS STRING) 
--           AND TRANSACCIONES.id_mes = INTRA.mes_activacion
--           AND TRANSACCIONES.account_id = INTRA.account_id 
--           AND TRANSACCIONES.marca = INTRA.brand_ds
  
--   WHERE (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)

-- );
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_base_final_no_interco` AS(
    
--     WITH PORCENTAJE_2P AS (
--       /*Conteo de servicios 2P para calcular el tope del 25% */
--       SELECT 
--         grupo_cif, 
--         SUM(UNIDADES_2P) / SUM(UNIDADES) AS PORCENTAJE_2P,
--         SUM(UNIDADES) * 0.25 AS PERMITIDO

--       FROM (
--             SELECT
--             CIF.grupo_cif,
--             COUNT(CASE WHEN BASE.bundle_type = '2P' THEN BASE.unidades END) AS UNIDADES_2P,
--             COUNT(BASE.UNIDADES) AS UNIDADES
--             FROM `mm-commissions-reporting.TEMP.rappel_fix_base_no_interco` BASE
--             LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
--               ON BASE.cif = CIF.cif
--             -- WHERE BASE.CIF NOT IN ('B80108186') ---- NO APLICAMOS TECHO 2P PARA TIGRE// Ya no se hace excepcion a tigre en la llave del 25%
--             GROUP BY CIF.grupo_cif)

--       GROUP BY ALL 
--     ),

--       /*Ordenamos por fecha las activaciones 2P*/
--       SERVICIOS_2P_NUMERADOS AS (
--       SELECT 
--         BASE.*, 
--         CIF.grupo_cif,
--         ROW_NUMBER() OVER (PARTITION BY CIF.grupo_cif ORDER BY BASE.activation_date) AS orden_activacion
--       FROM `mm-commissions-reporting.TEMP.rappel_fix_base_no_interco` BASE
--       LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
--         ON BASE.cif = CIF.cif
--       WHERE BASE.bundle_type = '2P'
--       )

--       /* Creamos tabla base sólo con aquellos servicios 2P que están dentro del 25% + FMC + Centralitas*/
--       SELECT 
--         S2P.* EXCEPT (grupo_cif, orden_activacion)
--       FROM SERVICIOS_2P_NUMERADOS S2P
--       LEFT JOIN PORCENTAJE_2P P 
--         ON S2P.grupo_cif = P.grupo_cif
--       WHERE S2P.orden_activacion <= P.PERMITIDO

--       UNION ALL 

--       SELECT *
--       FROM `mm-commissions-reporting.TEMP.rappel_fix_base_no_interco` 
--       WHERE (bundle_type !='2P' OR bundle_type IS NULL)
--       -- AND CIF NOT IN ('B80108186')
      
--       -- UNIMOS VENTAS DE TIGRE SIN APLICAR EL TOPE DEL 2P --
--       /*
--       UNION ALL 
--       SELECT * 
--       FROM `mm-commissions-reporting.TEMP.rappel_fix_base` 
--       WHERE (bundle_type ='2P' OR bundle_type IS NULL)
--       AND CIF  IN ('B80108186')*/

--   )

--   ;
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_contador_no_interco`AS (
--   SELECT GRUPO_CIF, SUM(UNIDADES) AS SERVICIOS
--   FROM(
--         SELECT 
--           CIF.grupo_cif,
--           SUM(BASE.UNIDADES) AS UNIDADES

--           FROM `mm-commissions-reporting.TEMP.rappel_fix_base_final_no_interco` BASE

--           LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
--             ON BASE.cif = CIF.cif
          
--           WHERE BASE.cod_segmento = '12' --- NO CUENTAN LAS ACTIVACIONES DE RESIDENCIAL DEL D2D981 Y D2N01117

--           GROUP BY ALL
          
--       ---- AÑADIMOS MANUALMENTE CENTRALITAS DE ORANGE
--         UNION ALL
--         SELECT 'B01501287' AS grupo_cif, 3 AS UNIDADES  --ADEGAR
--         UNION ALL
--         SELECT 'B44808244' AS grupo_cif, 5 AS UNIDADES -- FUERZA LA PLANA
--         UNION ALL
--         SELECT 'B52554821' AS grupo_cif, 18 AS UNIDADES -- AVE FENIX
--         UNION ALL
--         SELECT 'B67914408' AS grupo_cif, 2 AS UNIDADES -- MASNOOMADAS
--         UNION ALL
--         SELECT 'B95602967' AS grupo_cif, 13 AS UNIDADES -- SUCCESS
--         UNION ALL
--         SELECT 'B33984329' AS grupo_cif, 4 AS UNIDADES -- BENCEX
--         UNION ALL
--         SELECT 'B01524784' AS grupo_cif, 2 AS UNIDADES -- XENTIA 
--         UNION ALL
--         SELECT 'B67311605' AS grupo_cif, 36 AS UNIDADES --  BLUE C 
--         UNION ALL
--         SELECT 'B16767642' AS grupo_cif, 3 AS UNIDADES -- C22 CONSULTING 
--         UNION ALL
--         SELECT 'B02860211' AS grupo_cif, 37 AS UNIDADES -- BELIEVE IT
--         UNION ALL
--         SELECT 'B70606926' AS grupo_cif, 4 AS UNIDADES -- HANDSMART
--         UNION ALL
--         SELECT 'A41050980' AS grupo_cif, 2 AS UNIDADES -- SERVINFORM
--         UNION ALL
--         SELECT 'B22651046' AS grupo_cif, 1 AS UNIDADES -- BLACKMANGO
--         UNION ALL
--         SELECT 'B16839458' AS grupo_cif, 43 AS UNIDADES -- AML
--         UNION ALL
--         SELECT 'B75318311' AS grupo_cif, 8 AS UNIDADES -- ASESORES MAVASOL S.L.U
        
--     )
--     GROUP BY ALL
--   );


-- ---- EXTRAINCENTIVO SEPTIEMBRE 2025

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_config_incentivo_septiembre` AS (
  
--     SELECT cont.*,obj.tramo_20,obj.tramo_30

--     FROM `mm-commissions-reporting.TEMP.rappel_fix_contador_no_interco` cont

--     LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` equiv 
--     ON cont.grupo_cif = equiv.grupo_cif
--     INNER JOIN `mm-commissions-reporting.RappelD2D.EXTRAINCENTIVO_SEPTIEMBRE` obj
--     ON equiv.cif = obj.cif
--     QUALIFY ROW_NUMBER() OVER (PARTITION BY cont.grupo_cif, obj.tramo_20,obj.tramo_30 ) = 1
--       );


-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_incentivo_septiembre` AS (
--   SELECT  
--     'RAPD' ||'_'||mes_string||'_'||S.CANAL||'_'||'EXTRA'||'_'||row_number () over () AS commission_id,
--     'calculado' AS estado,
--     S.mes_liquidado AS mes_liquidado,
--     id_mes_pr AS id_mes,
--     S.agrupacion_canal,
--     S.canal,

--     CASE 
--     WHEN C.SERVICIOS >=C.tramo_20 and C.SERVICIOS < C.tramo_30 THEN 'D - Incentivo Diciembre Tramo 20'
--     WHEN C.SERVICIOS >= C.tramo_30 THEN 'D - Incentivo Diciembre Tramo 30'
--     ELSE CAST(NULL AS STRING)
--     END AS concepto,
    
--     'UPFR'AS tipo_concepto,
--     S.unidades,

--     CASE
--     WHEN C.SERVICIOS >=C.tramo_20 and C.SERVICIOS < C.tramo_30 THEN 20.0
--     WHEN C.SERVICIOS >= C.tramo_30 THEN 30.0
--     ELSE 0
--     END AS comision,

--     s.id_comisionista,
--     S.distribuidor,
--     S.sfid_id,
--     S.seller,
--     S.nombre_comercio,
--     S.razon_social,
--     S.cif,
--     S.zona_fiscal,
--     S.marca,
--     'INTERNET' AS service_type,
--     S.phone_nm,
--     S.tariff_id,
--     S.tariff_ds,
--     S.service_id,
--     S.account_id,
--     S.customer_id,
--     S.line_type_ds,
--     S.bundle_type,
--     S.technology_ds,
--     S.billing_type_ds,
--     S.sale_date,
--     S.activation_date,
--     S.deactivation_date,
--     S.order_id,
--     S.order_type_agg,
--     S.cod_segmento,
--     S.cod_marca,
--     S.cod_tipo_contrato,
--     S.cod_producto,
--     S.cod_canal,
--     S.claim_code,
--     S.serial_number,
--     S.tax_base,
--     S.campaign_code,
--     'RAPPEL_'||S.CANAL||'_FIJO_'||mes_string AS process_code,
--     S.comments,
--   'C_MANUAL' AS facturador,
--     S.sociedad,
--     CURRENT_TIMESTAMP AS creado,
--     CURRENT_TIMESTAMP AS modificado



--   FROM `mm-commissions-reporting.TEMP.rappel_fix_base_final_no_interco` S


--     LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
--       ON S.cif = CIF.cif

--     LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_config_incentivo_septiembre` C
--       ON CIF.grupo_cif = C.grupo_cif
      

--   QUALIFY 
--   ROW_NUMBER() OVER (PARTITION BY S.phone_nm, S.concepto ORDER BY S.sale_date DESC) = 1
--   AND CASE
--           WHEN C.SERVICIOS >= C.tramo_20 AND C.SERVICIOS < C.tramo_30 THEN 1
--           WHEN C.SERVICIOS >= C.tramo_30 THEN 1
--           ELSE 0
--         END = 1
--   );

--   DELETE FROM `mm-commissions-reporting.TEMP.rappel_fix_incentivo_septiembre`
--   WHERE comision = 0;

-- ------- AÑADIMOS EL INCENTIVO
--   INSERT INTO `mm-commissions-reporting.TEMP.rappel_fix`
--   SELECT * FROM `mm-commissions-reporting.TEMP.rappel_fix_incentivo_septiembre`;



  /*
  --- EXTRA RAPPEL ---

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_extra_base` AS (


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
    AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_anterior
    AND TRANSACCIONES.CONCEPTO = 'A - Servicio Fijo' 
    AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(mes_anterior AS STRING))
    AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup IS NULL)
    AND TRANSACCIONES.cod_segmento = '12'

    UNION ALL 

    SELECT * 
    FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
    WHERE TRANSACCIONES.CANAL IN UNNEST (canales_pr)
    AND cast(TRANSACCIONES.ID_MES AS STRING) = mes_anterior
    AND (TRANSACCIONES.CONCEPTO = 'B - Centralitas Base' AND TRANSACCIONES.tariff_id LIKE 'BASE%') -- SE CONTABILIZAN LOS SERVICIOS FIJOS Y LAS CENTRALITAS
    AND (DATE_TRUNC(TRANSACCIONES.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(mes_anterior AS STRING)) OR TRANSACCIONES.deactivation_date IS NULL)
  )

  ;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_extra_contador`AS (
    SELECT 
    CIF.grupo_cif,
    SUM(BASE.UNIDADES) AS SERVICIOS

    FROM `mm-commissions-reporting.TEMP.rappel_extra_base` BASE

    LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
      ON BASE.cif = CIF.cif
    
    WHERE BASE.cod_segmento = '12' 

    GROUP BY 1
    ORDER BY  2 DESC
    )
  ;
  ---- EXTRA DE RAPPEL ---- SÓLO SI APRUEBAN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_extra_D2D` AS (
    SELECT  
    'RAPD' ||'_'||mes_string||'_'||S.CANAL||'_'||'EXTRA'||'_'||row_number () over () AS commission_id,
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
    'D - Extracomision Rappel'as concepto,
    'UPFR'AS tipo_concepto,
    S.unidades,
  20 AS comision,
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
    'RAPPEL_'||S.CANAL||'_EXTRA_'||mes_string AS process_code,
    S.comments,
  'C_MANUAL' AS facturador,
    S.sociedad,
    CURRENT_TIMESTAMP AS creado,
    CURRENT_TIMESTAMP AS modificado



    FROM `mm-commissions-reporting.TEMP.rappel_fix_base` S
    
    LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF 
      ON S.cif = CIF.cif
    
    LEFT JOIN (SELECT CONTEO.grupo_cif
                FROM `mm-commissions-reporting.TEMP.rappel_fix_contador` CONTEO

                LEFT JOIN `mm-commissions-reporting.TEMP.rappel_extra_contador` MES_ANT
                ON CONTEO.grupo_cif = MES_ANT.grupo_cif

                WHERE CONTEO.SERVICIOS >= MES_ANT.SERVICIOS) CONTEO
                ON CIF.grupo_cif = CONTEO.grupo_cif
    WHERE CONTEO.grupo_cif IS NOT NULL

    QUALIFY ROW_NUMBER() OVER (PARTITION BY S.phone_nm, S.concepto ORDER BY S.sale_date DESC) = 1

  )
  ;
  */

  

-----INSERTAR D2D ID_MES_PR ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['D2D','D2N','DEM'], 'mm-commissions-reporting.TEMP.rappel_fix', 'ACTUALIZAR');


  -- -----INSERTAR D2N y DEM ID_MES_PR +1----
  -- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_fix_temp` AS(
  -- SELECT *
  -- FROM `mm-commissions-reporting.TEMP.rappel_fix`
  -- WHERE CANAL IN ('D2N','DEM')
  -- )
  -- ;
  -- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, CAST (id_mes_2 AS INT64), ['D2N','DEM'], 'mm-commissions-reporting.TEMP.rappel_fix_temp', 'ACTUALIZAR');



END