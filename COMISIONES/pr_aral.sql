BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARAL';

SET canales_pr = ['ALT'];

-- CALL `mm-commissions-reporting.COMISIONES.pr_aral`(202509,['ALT']);

--LUEGO, EJECUTAR EL PROCEDIMEINTO "RALT" CAMPAÑA DISTRIBUCIÓN LINEAS SIEMPRE

-- CALL `mm-commissions-reporting.COMISIONES.pr_ralt`(202410)

--LUEGO, EJECUTAR EL PROCEDIMIENTO "RALTC3" CAMPAÑA TRIMESTRAL HASTA 202509 UPFRONT Y CLAWBACK 202601

-- CALL `mm-commissions-reporting.COMISIONES.pr_raltc3`(202410,['ALT']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_aral` AS 

WITH base_inicial AS (  --esto para cartera
    SELECT DISTINCT 
      a.comm_brand_ds,
      'F40411' AS CLIENTE,
      a.service_id, 
      a.brand_ds,
      a.phone_nm, 
      a.account_id, 
      a.customer_id, 
      a.bundle_type,
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type,
      CASE 
        WHEN a.service_type IN ('FIX','INTERNET') AND a.bundle_type = 'FMC' AND a.tariff_ds NOT LIKE '%+%' THEN '2P'
        WHEN a.service_type IN ('FIX','INTERNET') AND a.bundle_type = '2P' AND a.tariff_ds LIKE '%+%'      THEN 'FMC'
        WHEN a.service_type NOT IN ('FIX','INTERNET')AND a.bundle_type IS NOT NULL THEN a.bundle_type
        WHEN a.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND a.tariff_ds LIKE '%+%'           THEN  'FMC'
        WHEN a.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND a.tariff_ds NOT LIKE '%+%'       THEN  '2P'
        WHEN a.bundle_type IS NULL AND a.service_type = 'MOBILE' AND a.tariff_ds LIKE '%CONV%'                   THEN  'FMC'
        WHEN a.bundle_type IS NULL AND a.service_type = 'MOBILE' AND a.tariff_ds NOT LIKE '%CONV%'               THEN  'MO'
        ELSE a.bundle_type
      END AS TIPO_PAQUETE,
      billing_tier_1,
      IF(a.service_type = 'MOBILE' AND a.line_type_ds = 'MAIN' AND a.bundle_type != d.bundle_type, UPPER(d.sell_tariff_ds), UPPER(d.tariff_ds)) AS TARIFA_PAQUETE,
          IF(a.service_type = 'MOBILE' AND a.line_type_ds = 'MAIN' AND a.bundle_type != d.bundle_type, d.sell_tariff_id, d.tariff_id) AS ID_TARIFA_PAQUETE,
      a.tariff_id AS tariff_id, 
      UPPER(a.tariff_ds) AS tariff_ds,
      CASE
        WHEN a.bundle_type = 'MO' THEN 'NA'
        WHEN a.service_type = 'MOBILE' AND a.line_type_ds = 'MAIN' AND a.bundle_type != 'MO' AND 
        --TARIFA PAQUETE
        IF(a.service_type = 'MOBILE' AND a.line_type_ds = 'MAIN' AND a.bundle_type != d.bundle_type, UPPER(d.sell_tariff_ds), UPPER(d.tariff_ds)) LIKE '%INDIRECTA%' THEN 'INDIRECTA' 
        WHEN a.service_type IN('FIX','INTERNET') AND a.tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        ELSE 'PROPIA'
      END AS TIPO_FIBRA,
      c.imp_without_tax, 
      a.activation_date, 
      a.deactivation_date, 
      a.segment_ds,
      a.billing_type_ds,
      a.order_type_agg, 
      a.technology_ds, 
      CASE
        WHEN a.line_type_ds = 'MAIN' AND (a.tariff_ds LIKE '% AD%') THEN 'ADDITIONAL'
        ELSE a.line_type_ds
      END AS  line_type_ds,
      a.order_day_id, 
      a.order_id, 
      a.seller, 
      CASE
        WHEN a.sfid_id IS NULL THEN a.current_sfid_id
        ELSE a.sfid_id
      END AS sfid_id,
      d.first_territory_ds AS first_territory_ds, 
      CASE
        WHEN (a.line_type_ds = 'MAIN' AND a.tariff_ds LIKE '% AD%') OR a.line_type_ds = 'ADDITIONAL' THEN NULL
        ELSE COALESCE(d.order_fix_id,IF(a.order_fix_id = '',NULL,a.order_fix_id)) 
      END AS order_fix_id
    FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
    JOIN (
      SELECT DISTINCT phone_nm, billing_tier_1,SUM(imp_without_tax) AS imp_without_tax
      FROM `mm-datamart-kd.BILLING.billing_detail_net`
      WHERE comm_brand_ds = 'ALTERNA' 
        AND invoice_date = DATE_TRUNC(CURRENT_DATE, MONTH)
        --AND (billing_tier_1 NOT LIKE "PENALIZACION %" OR bill_id NOT LIKE "PENALIZACION %")
        AND NOT (billing_tier_1 LIKE '%RESTABLECIMIENTO DEL SERVICIO%'
        OR billing_tier_1 LIKE '%VISITA TECNICO%'
        OR billing_tier_1 LIKE '%SIM%'
        --OR billing_tier_1 LIKE '%IMPAGO%'
        OR billing_tier_1 LIKE '%CREDITO FACTURA SIGUIENTE%'
        OR billing_tier_1 LIKE '%ATC%'
        OR billing_tier_1 LIKE '%DUPLICADO%'
        OR billing_tier_1 LIKE '%AVERIA%'
        OR billing_tier_1 LIKE '%IMPAGO DE FACTURA%'
        OR billing_tier_1 LIKE "PENALIZACION %"
        OR bill_id        LIKE "PENALIZACION %"
        --SWENO
        OR billing_tier_1 LIKE '%TV%'
        OR billing_tier_1 LIKE '%CORTE DE SERVICIO%'
        OR billing_tier_1 LIKE '%VISITA TECNICO%'
        OR billing_tier_1 LIKE '%SIM%'
        OR billing_tier_1 LIKE '%7%'
        OR billing_tier_1 LIKE '%OPIT%'
        )
      GROUP BY ALL
    ) c ON a.phone_nm = c.phone_nm 
    LEFT JOIN (
      SELECT DISTINCT 
        a.account_id,
        sell_bundle_type,
        bundle_type,
        sell_tariff_ds, 
        sell_tariff_id, 
        tariff_ds,
        order_day_id,
        tariff_id,
        activation_date,
        first_territory_ds,
        IF(order_fix_id = '', NULL,order_fix_id) AS order_fix_id,
        IF(deactivation_date = '9999-12-31', NULL, deactivation_date) AS deactivation_date
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      LEFT JOIN (
        SELECT DISTINCT 
          first_territory_ds,
          a.account_id,
          a.phone_nm
        FROM `mm-datamart-kd.SERVICES.service_base_net` a
        JOIN(
          SELECT DISTINCT 
            MAX(activation_date) AS MAX_DATE,
            account_id,
            phone_nm
          FROM `mm-datamart-kd.SERVICES.service_base_net`
          WHERE service_type = 'FIX'
          GROUP BY 2,3
        ) b ON a.activation_date = b.MAX_DATE AND a.account_id = b.account_id AND a.phone_nm = b.phone_nm
        WHERE service_type = 'FIX'
      )b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm
      WHERE 
        a.service_type = 'FIX'  
        AND a.activation_date IS NOT NULL 
        AND a.activation_date <= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH))  
        AND a.comm_brand_ds = 'ALTERNA' 
        AND (LAST_DAY(a.deactivation_date) >= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) OR a.deactivation_date IS NULL)
    ) d ON a.account_id = d.account_id AND a.service_type = 'MOBILE'
    WHERE comm_brand_ds = 'ALTERNA' 
      AND a.activation_date IS NOT NULL 
      AND (LAST_DAY(a.deactivation_date) >= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) OR a.deactivation_date IS NULL)
      --AND a.phone_nm = 984096622
      --AND a.account_id = '19354200'
      --AND c.imp_without_tax != 0
    QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm,billing_tier_1 ORDER BY activation_date DESC) = 1 --Agregado billing_tier_1 para que pueda aparecer el mismo importe
  ),

-- Extraemos la información de las huellas 

  base AS (
    SELECT a.* EXCEPT(first_territory_ds),
      COALESCE(f.footprint_detail, g.footprint_detail) AS footprint_detail,
      COALESCE(f.footprint_contract, g.footprint_contract) AS footprint_contract,
      COALESCE(a.first_territory_ds,e.ftth_territoryowner) AS first_territory_ds
    FROM base_inicial a
    /* Cruze para recuperar huella del acceso */
    LEFT JOIN (
      SELECT workorder_id, ftth_iua, adsl_administrative,ftth_territoryowner
      FROM `mm-datamart-kd.ACCESS_PROVISION.provision_base`
      GROUP BY 1,2,3,4
      ) e ON COALESCE(a.order_fix_id, 'a') = e.workorder_id AND a.TIPO_PAQUETE IN ('FMC', '2P') --OR (COALESCE(d.order_fix_id, 'a') = e.workorder_id) 
    LEFT JOIN (
      SELECT iua_last, adminnumber_last, start_id, movement_date, footprint_owner, footprint_detail,footprint_contract
      FROM `mm-datamart-kd.ACCESS_PROVISION.fix_base_net` WHERE DATE(movement_date) < DATE_TRUNC(CURRENT_DATE(), MONTH) AND footprint_owner <> 'TELEFONICA'
      QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(iua_last, 'a'), COALESCE(adminnumber_last, 'a') ORDER BY start_id DESC, movement_date DESC) = 1
      ) f ON COALESCE(e.ftth_iua, 'a') = COALESCE(f.iua_last, 'z') AND e.adsl_administrative IS NULL 
    LEFT JOIN (
      SELECT iua_last, adminnumber_last, start_id, movement_date, footprint_owner, footprint_detail,footprint_contract
      FROM `mm-datamart-kd.ACCESS_PROVISION.fix_base_net` WHERE DATE(movement_date) < DATE_TRUNC(CURRENT_DATE(), MONTH) AND footprint_owner = 'TELEFONICA'
      QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(iua_last, 'a'), COALESCE(adminnumber_last, 'a') ORDER BY start_id DESC, movement_date DESC) = 1
      ) g ON COALESCE(e.adsl_administrative,'a') = COALESCE(g.adminnumber_last, 'z')
    )
  
    --Clasificamos el first_territoy_ds según indicaciones del excel

    SELECT a.* EXCEPT(first_territory_ds),
      CASE
        WHEN TIPO_PAQUETE IN ('FMC','2P') AND (b.FOOTPRINT IS NULL OR c.first_territory_ds IS NULL) THEN 'PROPIA'
        ELSE COALESCE(b.FOOTPRINT,c.FOOTPRINT)
      END AS  first_territory_ds,
    FROM base a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.clasificacion_huellas_canales` b ON a.footprint_contract = b.FOOTPRINT_CONTRACT AND a.footprint_detail = b.FOOTPRINT_DETAIL
    LEFT JOIN `mm-commissions-reporting.COMISIONES.clasificacion_first_territory_canales` c ON a.first_territory_ds = c.first_territory_ds AND a.TIPO_PAQUETE IN ('FMC','2P')
  ;

-- --Validacion dealers.

--   ASSERT NOT EXISTS(--Si se modifica hay que actualizarlo también en App Script

--     SELECT DISTINCT a.sfid_id
--     FROM `mm-commissions-reporting.TEMP.comisiones_base_aral` a
--     LEFT JOIN `mm-commissions-reporting.GS.DEALERS_ALTERNA` b ON a.sfid_id = b.id_comisionista
--     WHERE a.comm_brand_ds = 'ALTERNA' AND b.id_comisionista IS NULL AND a.activation_date > DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
--       AND a.sfid_id != 'NULL'

--   ) AS 'Faltan dealers por definir'
--   ;

  
-- --Validación de las huellas. Si falta alguna ejecutar la query del ASSERT

--   ASSERT NOT EXISTS((--Si se modifica hay que actualizarlo también en App Script

--     SELECT DISTINCT a.footprint_detail,a.footprint_contract
--     FROM `mm-commissions-reporting.TEMP.comisiones_base_aral` a
--     LEFT JOIN `mm-commissions-reporting.COMISIONES.clasificacion_huellas_canales` b ON CONCAT(a.footprint_detail,'-',IF(a.footprint_contract IS NULL, '.',a.footprint_contract)) = CONCAT(b.footprint_detail,'-',IF(b.footprint_contract IS NULL, '.',b.footprint_contract))
--     LEFT JOIN `mm-commissions-reporting.COMISIONES.clasificacion_first_territory_canales` c ON a.first_territory_ds = c.first_territory_ds
--     WHERE CONCAT(b.footprint_detail,'-',IF (b.footprint_contract IS NULL, '.',b.footprint_contract)) IS NULL
--       AND service_type <> 'MOBILE'
--       AND NOT (a.footprint_detail IS NULL AND a.footprint_contract IS NULL)
--       AND c.first_territory_ds IS NOT NULL

--   )) AS 'Faltan huellas por definir'
--   ;

  -- ASSERT NOT EXISTS((--Si se modifica hay que actualizarlo también en App Script

  --   SELECT DISTINCT a.tariff_id, a.tariff_ds,
  --   FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
  --   LEFT JOIN `mm-commissions-reporting.TEMP.comisiones_base_aral`b ON a.tariff_id = b.tariff_id
  --   LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_ALT` c ON a.tariff_id = c.tariff_id
  --   WHERE a.comm_brand_ds = 'ALTERNA' 
  --     AND (b.tariff_id IS NULL OR c.tariff_id IS NULL) 
  --     AND (a.deactivation_date IS NULL OR a.deactivation_date = '9999-12-31')
  --     AND a.activation_date IS NOT NULL
  --     AND a.activation_date < LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH), MONTH)
  --     AND a.tariff_id IS NOT NULL
  --   ORDER BY a.tariff_id

  --   -- SELECT DISTINCT a.tariff_id, a.tariff_ds 
  --   -- FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
  --   -- LEFT JOIN `mm-commissions-reporting.TEMP.comisiones_base_aral`b ON a.tariff_id = b.tariff_id
  --   -- LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_ALT` c ON a.tariff_id = c.tariff_id
  --   -- WHERE a.comm_brand_ds = 'ALTERNA' AND (b.tariff_id IS NULL OR c.tariff_id IS NULL) AND a.activation_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))

  -- )) AS 'Faltan tarifas por definir'
  -- ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ARAL_BASE_UPFRONT` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS 

  WITH base_upfront AS (

    SELECT DISTINCT 
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as periodo,
      a.* EXCEPT (service_type, segment_ds, deactivation_date, sell_tariff_id,sell_tariff_ds,sell_line_type_ds,order_type_agg,order_id,order_day_id,port_in_operator_ds,seller,line_type_ds),
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      'F40411' AS CLIENTE,
      CASE 
        WHEN a.service_type IN ('FIX','INTERNET') AND a.sell_bundle_type = 'FMC' AND a.sell_tariff_ds NOT LIKE '%+%' THEN '2P'
        WHEN a.service_type IN ('FIX','INTERNET') AND a.sell_bundle_type = '2P' AND a.sell_tariff_ds LIKE '%+%'      THEN 'FMC'
        WHEN a.service_type NOT IN ('FIX','INTERNET')AND a.sell_bundle_type IS NOT NULL THEN a.sell_bundle_type
      ELSE a.sell_bundle_type
      END AS TIPO_PAQUETE,
      CASE
        WHEN a.sell_bundle_type = 'MO' THEN 'NA'
        WHEN a.service_type = 'MOBILE' AND a.sell_line_type_ds = 'MAIN' AND a.sell_bundle_type != 'MO' AND d.sell_tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        WHEN a.service_type IN('FIX','INTERNET') AND a.sell_tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        ELSE 'PROPIA'
      END AS TIPO_FIBRA,
      a.order_day_id,
      a.sell_tariff_id,
      UPPER(a.sell_tariff_ds) AS sell_tariff_ds,
      CAST(NULL AS STRING) AS line_type_ds, --Se anula para la función
      a.sell_line_type_ds,
      a.order_type_agg,
      a.order_id,
      a.seller,
      IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds,
      IF(a.deactivation_date = '9999-12-31', NULL, a.deactivation_date) AS deactivation_date,
      b.imp_without_tax,
      b.init_date,
      b.end_date,
      a.port_in_operator_ds
    FROM  `mm-datamart-kd.SERVICES.ventas_base_net` a
    LEFT JOIN (
      SELECT phone_nm,
        account_id,
        service_id,
        SUM(imp_without_tax) AS imp_without_tax,
        MAX(init_date) AS init_date,
        MAX(end_date) AS end_date
      FROM `mm-datamart-kd.BILLING.billing_detail_net`
      WHERE (bill_id LIKE 'TARIFA %' OR bill_id LIKE 'DTO %') 
        AND service_type IN ('MOBILE','FIX','INTERNET') --Antes solo MOBILE
        AND data_month_id = CAST(FORMAT_DATE('%Y%m', DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH)) AS INT64) AND end_date = LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))
      GROUP BY 1,2,3
     ) b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm AND a.service_id = b.service_id
    LEFT JOIN (
      SELECT DISTINCT 
        a.account_id,
        sell_bundle_type,
        bundle_type,
        sell_tariff_ds, 
        sell_tariff_id, 
        tariff_ds,
        order_day_id,
        tariff_id,
        activation_date,
        IF(deactivation_date = '9999-12-31', NULL, deactivation_date) AS deactivation_date
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      WHERE 
        a.service_type = 'FIX' AND 
        a.activation_date IS NOT NULL AND 
        a.activation_date <= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AND 
        a.comm_brand_ds = 'ALTERNA' AND
        (LAST_DAY(a.deactivation_date) >= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) OR a.deactivation_date IS NULL)
    ) d ON a.account_id = d.account_id AND a.service_type = 'MOBILE' 
    WHERE a.comm_brand_ds = 'ALTERNA'  
        --AND a.kpi_gross_add = 1 
        --Ejemplos: activation '2023-05-01' AND '2023-05-31'// deactivation '2023-06-01'
        AND(a.activation_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)) 
        AND a.tariff_ds NOT LIKE '%TRV%'
  )

  SELECT *
  FROM base_upfront
  ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ARAL_BASE_CLAWBACK` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  ----CLAWBACK----
  WITH

    base_clawback  AS(
    
      SELECT *
      FROM (
        SELECT DISTINCT 
          a.data_source_ds,
          a.brand_id,
          a.brand_ds,
          a.comm_brand_ds,
          a.customer_id,
          a.sfid_id,
          a.account_id,
          a.service_id,
          a.phone_nm,
          a.sell_tariff_id,
          UPPER(a.sell_tariff_ds) AS sell_tariff_ds,
          a.activation_date,
          a.deactivation_date,
          CAST(NULL AS STRING) AS line_type_ds, --Se anula para la función
          a.sell_line_type_ds,
          a.technology_ds,
          CASE 
            WHEN a.service_type = 'FIX' THEN 'INTERNET'
            ELSE a.service_type
          END AS service_type,
          'F40411' AS CLIENTE,
          CASE 
            WHEN a.service_type IN ('FIX','INTERNET') AND a.sell_bundle_type = 'FMC' AND a.sell_tariff_ds NOT LIKE '%+%' THEN '2P'
            WHEN a.service_type IN ('FIX','INTERNET') AND a.sell_bundle_type = '2P' AND a.sell_tariff_ds LIKE '%+%'      THEN 'FMC'
            WHEN a.service_type NOT IN ('FIX','INTERNET')AND a.sell_bundle_type IS NOT NULL THEN a.sell_bundle_type
          ELSE a.sell_bundle_type
          END AS TIPO_PAQUETE,
          CASE
            WHEN a.service_type = 'MOBILE' THEN 'NA'
            WHEN a.service_type IN('FIX','INTERNET') AND a.sell_tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
            ELSE 'PROPIA'
          END AS TIPO_FIBRA,
          a.billing_type_ds,
          a.order_day_id,
          a.order_type_agg,
          a.order_id,
          a.seller,
          h.concepto,
          h.comision,
        FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
        LEFT JOIN (
            SELECT 
              REPLACE(REPLACE(REPLACE(REPLACE(concepto, 'D - ', 'E - '),'A - ', 'E - '),'R - ','E - '),'Z - ','E - ') AS concepto,
              activation_date,
              tariff_id,
              tariff_ds,
              bundle_type,
              service_id,
              phone_nm,
              SUM(comision) AS comision
            FROM `mm-commissions-reporting.COMISIONES.transacciones` 
            WHERE marca = 'ALTERNA' 
              AND comision != 0 
              AND tipo_concepto = 'UPFR' 
              AND id_mes <= CAST(202503 AS INT64)
              --AND phone_nm = '948001727'
              -- AND id_mes != CAST(FORMAT_DATE('%Y%m', DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH))AS INT64)
              AND commission_id NOT LIKE 'RALTC%'
            --AND concepto IN ('D - Upfront Acuerdo Alterna 2022','D - Rappel Acuerdo Alterna 2022')  
            GROUP BY ALL
        ) h ON SAFE_CAST(h.phone_nm AS FLOAT64) = a.phone_nm AND h.service_id = a.service_id AND (h.tariff_id = a.sell_tariff_id OR h.tariff_ds = a.sell_tariff_ds) AND a.activation_date = h.activation_date
        WHERE a.comm_brand_ds = 'ALTERNA'
            AND a.activation_date IS NOT NULL
              AND LAST_DAY(a.deactivation_date) = LAST_DAY(PARSE_DATE('%Y%m', mes_string))
              --AND LAST_DAY(a.deactivation_date) = LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))

              AND DATE_DIFF(a.deactivation_date,a.activation_date, DAY) < 365
              --AND a.phone_nm = 600486045             
        )
        QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, sell_tariff_id,concepto,activation_date) = 1
  ),

  migracion AS (--BAJAS Y ALTAS EL MISMO DIA EN ALTERNA CHAO
        SELECT COALESCE(sfid_id,customer_id) AS sfid_id,CAST(NULL AS STRING) AS user_store,comm_brand_ds,phone_nm, CAST(NULL AS STRING) AS sell_tariff_ds, tariff_ds,activation_reason_ds,activation_date,IF(deactivation_date = '9999-12-31',NULL,deactivation_date) AS deactivation_date
        FROM `mm-datamart-kd.SERVICES.service_base_net`
        WHERE 1=1
          AND comm_brand_ds IN ('CABLEMOVIL')
          AND activation_date >= '2025-04-01'-- DATE_TRUNC(PARSE_DATE('%Y%m', mes_string),MONTH) --'2025-06-01'
        GROUP BY ALL

        UNION ALL

        SELECT current_sfid_id AS sfid_id,user_store,comm_brand_ds,phone_nm,sell_tariff_ds,tariff_ds,CAST(NULL AS STRING) AS activation_reason_ds, activation_date,IF(deactivation_date = '9999-12-31',NULL,deactivation_date) AS deactivation_date
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE 1=1
          AND comm_brand_ds IN ('MARBLANCA','MASMOVIL','ALTERNA','PEPEPHONE','GUUK','BETIS','YOIGO','HAPPYMOVIL','MASMOVIL','LLAMAYA','MM ROUND ROBIN','SENIORTELECOM')
          AND activation_date >= '2025-04-01'-- DATE_TRUNC(PARSE_DATE('%Y%m', mes_string),MONTH) --'2025-06-01'
        GROUP BY ALL
      ),

      cruce AS (
        SELECT a.*, b.id_comisionista
        FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` b ON a.cif = b.documento

        UNION ALL

        SELECT a.*, c.id_comisionista
        FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA`  c ON a.cif = c.documento
      ),

      alternos AS (
        SELECT *
        FROM cruce
        WHERE id_comisionista IS NOT NULL
        GROUP BY ALL
      ),

      migra_alternos AS (
        SELECT *
        FROM migracion a
        LEFT JOIN alternos b ON a.sfid_id = b.id_comisionista --OR a.user_store = b.id_comisionista
      ),

      bajas AS (
        SELECT 
          CAST(mes_string AS INT64) AS id_mes,
          a.* EXCEPT(activation_date,deactivation_date),
          b.sfid_id AS sfid_id_migra,
          b.id_comisionista,
          a.activation_date,
          a.deactivation_date,
          b.activation_date AS nueva_activation_date,
          b.deactivation_date AS nueva_deactivation_date,
          CASE
            WHEN b.tariff_ds LIKE '%TTB%' OR b.sell_tariff_ds LIKE '%TTB%' AND b.deactivation_date IS NULL THEN 'MIGRACION TTB ALT'
            WHEN b.sfid_id = b.id_comisionista AND b.comm_brand_ds IN ('CABLEMOVIL','MARBLANCA') AND b.deactivation_date IS NULL THEN 'MIGRACION CM_MB ALT'--AND ABS(DATE_DIFF(b.activation_date,a.deactivation_date, DAY)) BETWEEN 0 AND 5
            WHEN b.comm_brand_ds IN ('MASMOVIL','PEPEPHONE','GUUK','BETIS','YOIGO','HAPPYMOVIL','MASMOVIL','LLAMAYA','MM ROUND ROBIN','SENIORTELECOM')  AND b.deactivation_date IS NULL THEN 'MIGRACION MM ALT' --AND ABS(DATE_DIFF(b.activation_date,a.deactivation_date, DAY)) BETWEEN 0 AND 5
            WHEN b.comm_brand_ds = 'ALTERNA' THEN 'ACTIVA EN ALTERNA'
            WHEN b.comm_brand_ds NOT IN ('CABLEMOVIL','MARBLANCA','MASMOVIL','ALTERNA','PEPEPHONE','GUUK','BETIS','YOIGO','HAPPYMOVIL','MASMOVIL','LLAMAYA','MM ROUND ROBIN','SENIORTELECOM') AND b.deactivation_date IS NOT NULL THEN 'BAJA REAL FUERA DE MM'
            WHEN COALESCE(b.sfid_id,'1') != COALESCE(b.id_comisionista,'0') AND b.comm_brand_ds IN ('CABLEMOVIL','MARBLANCA') AND b.deactivation_date IS NOT NULL THEN 'BAJA REAL NO ALT - CM_MB'
            WHEN COALESCE(b.sfid_id,'1') != COALESCE(b.id_comisionista,'0') AND b.comm_brand_ds IN ('MASMOVIL','PEPEPHONE','GUUK','BETIS','YOIGO','HAPPYMOVIL','MASMOVIL','LLAMAYA','MM ROUND ROBIN','SENIORTELECOM') AND b.deactivation_date IS NOT NULL THEN 'BAJA REAL NO ALT - MM'
            -- WHEN COALESCE(b.sfid_id,'1') != COALESCE(b.id_comisionista,'0') AND b.comm_brand_ds IN ('CABLEMOVIL','MARBLANCA') AND DATE_DIFF(b.activation_date,a.deactivation_date, DAY) >= 6 THEN 'BAJA REAL NO ALT'
            WHEN b.sfid_id = b.id_comisionista AND b.comm_brand_ds IN ('CABLEMOVIL','MARBLANCA') AND b.deactivation_date IS NOT NULL THEN 'BAJA REAL CM_MB ALT'
            WHEN b.sfid_id = b.id_comisionista AND b.comm_brand_ds IN ('MASMOVIL','PEPEPHONE','GUUK','BETIS','YOIGO','HAPPYMOVIL','MASMOVIL','LLAMAYA','MM ROUND ROBIN','SENIORTELECOM')  AND b.deactivation_date IS NOT NULL THEN 'BAJA REAL MM'
            WHEN COALESCE(b.sfid_id,'1') != COALESCE(b.id_comisionista,'0') AND b.comm_brand_ds IN ('CABLEMOVIL','MARBLANCA') AND b.deactivation_date IS NULL THEN 'MIGRACION NO ALT - CM_MB'
            WHEN COALESCE(b.sfid_id,'1') != COALESCE(b.id_comisionista,'0') AND b.comm_brand_ds IN ('CABLEMOVIL','MARBLANCA','MASMOVIL','ALTERNA','PEPEPHONE','GUUK','BETIS','YOIGO','HAPPYMOVIL','MASMOVIL','LLAMAYA','MM ROUND ROBIN','SENIORTELECOM') AND b.deactivation_date IS NULL THEN 'MIGRACION NO ALT - MM'
            WHEN b.deactivation_date IS NOT NULL THEN 'BAJA REAL'
            WHEN b.activation_date IS NULL THEN 'BAJA REAL'
            ELSE NULL --'MIGRACION NO ALT'
          END comentarios,
          b.comm_brand_ds AS comm_brand_ds_migra,
          b.activation_reason_ds
        FROM base_clawback a -- `mm-commissions-reporting.TEMP.clawback_alterna` a 
        LEFT JOIN migra_alternos b ON a.phone_nm = b.phone_nm 
        WHERE 1=1
          AND concepto IS NOT NULL
        QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm,concepto ORDER BY b.deactivation_date ASC) = 1
      )

    SELECT *
    FROM bajas 
    WHERE 1=1

  ----FIN CLAWBACK----
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_aral` AS 

  WITH 
  cam_alterna_l AS (
      SELECT DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado
  ),
  
  dt AS (
    SELECT DISTINCT tariff_id, tariff_ds, cuota,a.cuota_bst, porcentaje_extra_consumo, porcentaje_cartera_voz_y_datos AS Por_comision, service_type, upfront, campana_objetivo, upfront_bst, line_type, tipo_fibra,
    FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_ALT` a
  ),

  hist_up AS (
    SELECT *
    FROM `mm-commissions-reporting.GS.HIST_UPFRONT_ALTERNA`
  ),

  b AS(

    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      `mm-commissions-reporting.CABLEOPERADORES.f_concepto_alterna`(base.service_type, base.TIPO_FIBRA, base.tariff_ds, base.TIPO_PAQUETE, base.first_territory_ds, base.activation_date, base.line_type_ds, base.TARIFA_PAQUETE) AS concepto,
      'AIRT' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      base.imp_without_tax AS imp_base, 
      `mm-commissions-reporting.CABLEOPERADORES.f_comision_alterna`(base.service_type, base.TIPO_FIBRA, base.tariff_ds, base.TIPO_PAQUETE, base.first_territory_ds, base.activation_date, dt.por_comision, base.imp_without_tax, dt.Cuota, dt.Cuota_BST, base.line_type_ds, base.TARIFA_PAQUETE) AS comision,
      base.CLIENTE        AS id_comisionista,
      base.sfid_id        AS distribuidor,
      base.sfid_id        AS sfid_id,
      base.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base.service_type       AS service_type,
      CAST(base.phone_nm AS STRING)           AS phone_nm,
      base.tariff_id          AS tariff_id,
      base.tariff_ds          AS tariff_ds,
      base.service_id         AS service_id,
      base.account_id         AS account_id,
      base.customer_id        AS customer_id,
      base.line_type_ds       AS line_type_ds,
      base.TIPO_PAQUETE       AS bundle_type,
      base.technology_ds      AS technology_ds,
      'POSTPAID'              AS billing_type_ds,
      --base.init_date          AS init_date,
      --base.end_date           AS end_date,
      base.order_day_id       AS sale_date,
      base.activation_date    AS activation_date,
      IF(base.deactivation_date IS NULL, '9999-12-31',base.deactivation_date)  AS deactivation_date,
      CAST(base.order_id AS STRING)           AS order_id,
      base.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base.billing_type_ds, base.service_type, base.TIPO_PAQUETE, base.technology_ds ,base.line_type_ds , base.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      base.billing_tier_1      AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      base.imp_without_tax     AS tax_base,
      base.first_territory_ds  AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      --CONCAT(base.init_date,"//", base.end_date)  AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.comisiones_base_aral` base
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON 
        -- base.tariff_id = dt.tariff_id
        CASE
          WHEN base.service_type = 'MOBILE' AND base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' THEN base.ID_TARIFA_PAQUETE 
          ELSE base.tariff_id
        END = dt.tariff_id
        AND dt.service_type = base.service_type
        AND dt.line_type = base.line_type_ds
        AND dt.tipo_fibra = base.TIPO_FIBRA
    LEFT JOIN `mm-commissions-reporting.SAP.vendor_list` zona_fiscal 
      ON zona_fiscal.tax_code = b2b_xena.document_number
    -- QUALIFY ROW_NUMBER () OVER (PARTITION BY service_id, brand_ds ORDER BY activation_date DESC) = 1
    
  ),

  b_upfront AS (
  
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      'D - Upfront Acuerdo Alterna 2022' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      SUM(base_upfront.imp_without_tax) AS imp_without_tax,
      dt.upfront,
      CASE
        WHEN base_upfront.TIPO_PAQUETE = 'FMC' AND base_upfront.service_type = 'MOBILE' AND (base_upfront.imp_without_tax/IF(DATE_DIFF(base_upfront.end_date, base_upfront.init_date, DAY)=0,1,DATE_DIFF(base_upfront.end_date, base_upfront.init_date, DAY))*EXTRACT(DAY FROM base_upfront.end_date)) >= 5 THEN 10
        ELSE upfront
      END AS comision,
      base_upfront.tipo_fibra,
      base_upfront.CLIENTE        AS id_comisionista,
      base_upfront.sfid_id        AS distribuidor,
      base_upfront.sfid_id        AS sfid_id,
      base_upfront.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_upfront.service_type       AS service_type,
      CAST(base_upfront.phone_nm AS STRING)           AS phone_nm,
      base_upfront.sell_tariff_id     AS tariff_id,
      base_upfront.sell_tariff_ds     AS tariff_ds,
      base_upfront.service_id         AS service_id,
      base_upfront.account_id         AS account_id,
      base_upfront.customer_id        AS customer_id,
      base_upfront.sell_line_type_ds  AS line_type_ds,
      base_upfront.TIPO_PAQUETE       AS bundle_type,
      base_upfront.technology_ds      AS technology_ds,
      base_upfront.billing_type_ds    AS billing_type_ds,
      base_upfront.init_date          AS init_date,
      base_upfront.end_date           AS end_date,
      base_upfront.order_day_id       AS sale_date,
      base_upfront.activation_date    AS activation_date,
      IF(base_upfront.deactivation_date IS NULL, '9999-12-31',base_upfront.deactivation_date)  AS deactivation_date,
      CAST(base_upfront.order_id AS STRING)           AS order_id,
      base_upfront.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront.billing_type_ds, base_upfront.service_type, base_upfront.TIPO_PAQUETE, base_upfront.technology_ds ,COALESCE(base_upfront.line_type_ds,base_upfront.sell_line_type_ds) , base_upfront.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_upfront.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_UPFRONT` base_upfront
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_upfront.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_upfront.service_type
        AND dt.line_type = base_upfront.sell_line_type_ds
        AND dt.tipo_fibra = base_upfront.TIPO_FIBRA
    GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58
  ),

  --INCENTIVO ALTAS 2P y 3P 2024-01-01 al 2024-03-01
  
  b_upfront_2P_3P AS (
  
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      'D - Camp. BA Ene-Mar 24 ID:1854' AS concepto, 
      'UPFR' AS tipo_concepto,
      '1' AS unidades,
      10 AS comision,
      base_upfront.tipo_fibra,
      base_upfront.CLIENTE        AS id_comisionista,
      base_upfront.sfid_id        AS distribuidor,
      base_upfront.sfid_id        AS sfid_id,
      base_upfront.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_upfront.service_type       AS service_type,
      CAST(base_upfront.phone_nm AS STRING)           AS phone_nm,
      base_upfront.sell_tariff_id     AS tariff_id,
      base_upfront.sell_tariff_ds     AS tariff_ds,
      base_upfront.service_id         AS service_id,
      base_upfront.account_id         AS account_id,
      base_upfront.customer_id        AS customer_id,
      base_upfront.sell_line_type_ds  AS line_type_ds,
      base_upfront.TIPO_PAQUETE       AS bundle_type,
      base_upfront.technology_ds      AS technology_ds,
      base_upfront.billing_type_ds    AS billing_type_ds,
      base_upfront.init_date          AS init_date,
      base_upfront.end_date           AS end_date,
      base_upfront.order_day_id       AS sale_date,
      base_upfront.activation_date    AS activation_date,
      IF(base_upfront.deactivation_date IS NULL, '9999-12-31',base_upfront.deactivation_date)  AS deactivation_date,
      CAST(base_upfront.order_id AS STRING)           AS order_id,
      base_upfront.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront.billing_type_ds, base_upfront.service_type, base_upfront.TIPO_PAQUETE, base_upfront.technology_ds ,COALESCE(base_upfront.line_type_ds,base_upfront.sell_line_type_ds) , base_upfront.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_upfront.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad,
      base_upfront.port_in_operator_ds AS operador_origen
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_UPFRONT` base_upfront
    LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` a ON base_upfront.port_in_operator_ds =a.OPERADOR
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_upfront.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_upfront.service_type
        AND dt.line_type = base_upfront.sell_line_type_ds
        AND dt.tipo_fibra = base_upfront.TIPO_FIBRA
    --ACTIVACIONES 2P,3P EXCLUYENDO FIBRAS Y MOVILES QUE PROVENGAN DEL GRUPO MM
    WHERE a.GRUPO_EMPRESA1 != 'GRUPO MASMOVIL'
      AND TIPO_PAQUETE IN ('FMC','2P')
      AND base_upfront.service_type IN ('MOBILE','INTERNET')
    GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,base_upfront.port_in_operator_ds
  ),--SELECT * FROM b_upfront_2P_3P  WHERE phone_nm = '604296869'

  b_rappel AS (
  
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      'D - Rappel Acuerdo Alterna 2022' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      CASE
        WHEN base_upfront.TIPO_PAQUETE = 'FMC' AND base_upfront.service_type = 'MOBILE' THEN 5 -- AND a.ARPU_3P_ADICIONALES >= 37 
        --WHEN base_upfront.TIPO_PAQUETE = 'MO'  AND base_upfront.service_type = 'MOBILE' AND a.ARPU_MO >= 10 THEN 5
        ELSE 0
      END AS comision,
      base_upfront.CLIENTE        AS id_comisionista,
      base_upfront.sfid_id        AS distribuidor,
      base_upfront.sfid_id        AS sfid_id,
      base_upfront.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_upfront.service_type       AS service_type,
      CAST(base_upfront.phone_nm AS STRING)           AS phone_nm,
      base_upfront.sell_tariff_id     AS tariff_id,
      base_upfront.sell_tariff_ds     AS tariff_ds,
      base_upfront.service_id         AS service_id,
      base_upfront.account_id         AS account_id,
      base_upfront.customer_id        AS customer_id,
      base_upfront.sell_line_type_ds  AS line_type_ds,
      base_upfront.TIPO_PAQUETE       AS bundle_type,
      base_upfront.technology_ds      AS technology_ds,
      base_upfront.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS init_date,
      CAST(NULL AS DATE)              AS end_date,
      base_upfront.order_day_id       AS sale_date,
      base_upfront.activation_date    AS activation_date,
      IF(base_upfront.deactivation_date IS NULL, '9999-12-31',base_upfront.deactivation_date)  AS deactivation_date,
      CAST(base_upfront.order_id AS STRING)           AS order_id,
      base_upfront.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront.billing_type_ds, base_upfront.service_type, base_upfront.TIPO_PAQUETE, base_upfront.technology_ds ,COALESCE(base_upfront.line_type_ds,base_upfront.sell_line_type_ds) , base_upfront.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_upfront.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_UPFRONT` base_upfront
    LEFT JOIN `mm-commissions-reporting.GS.ARPU_Alterna` a ON a.periodo = base_upfront.periodo
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_upfront.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_upfront.service_type
        AND dt.line_type = base_upfront.sell_line_type_ds
        AND dt.tipo_fibra = base_upfront.TIPO_FIBRA
  ),
  --DADA DE BAJA liquidacion 02/2025

  -- campana_descuento_2P AS (

  --   SELECT DISTINCT
  --     'calculado' as estado,
  --     DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
  --     CAST(mes_string AS INT64) as id_mes, 
  --     'B2B - Alterna' AS agrupacion_canal,
  --     'ALT' AS canal,
  --     'D - Camp. Desc 2P ID:1678' AS concepto, -- D - Campana descuento 2P
  --     'UPFR' AS tipo_concepto,
  --     1 AS unidades,
  --     49.58 AS comision,
  --     base_upfront.CLIENTE        AS id_comisionista,
  --     base_upfront.sfid_id        AS distribuidor,
  --     base_upfront.sfid_id        AS sfid_id,
  --     base_upfront.seller         AS seller,
  --     'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
  --     'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
  --     'B87522652'                        AS cif,
  --     CASE 
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
  --       ELSE 'PEN'
  --     END AS zona_fiscal,
  --     'ALTERNA'               AS marca,
  --     base_upfront.service_type       AS service_type,
  --     CAST(base_upfront.phone_nm AS STRING)           AS phone_nm,
  --     base_upfront.sell_tariff_id     AS tariff_id,
  --     base_upfront.sell_tariff_ds     AS tariff_ds,
  --     base_upfront.service_id         AS service_id,
  --     base_upfront.account_id         AS account_id,
  --     base_upfront.customer_id        AS customer_id,
  --     base_upfront.sell_line_type_ds  AS line_type_ds,
  --     base_upfront.TIPO_PAQUETE       AS bundle_type,
  --     base_upfront.technology_ds      AS technology_ds,
  --     base_upfront.billing_type_ds    AS billing_type_ds,
  --     CAST(NULL AS DATE)              AS init_date,
  --     CAST(NULL AS DATE)              AS end_date,
  --     base_upfront.order_day_id       AS sale_date,
  --     base_upfront.activation_date    AS activation_date,
  --     IF(base_upfront.deactivation_date IS NULL, '9999-12-31',base_upfront.deactivation_date)  AS deactivation_date,
  --     CAST(base_upfront.order_id AS STRING)           AS order_id,
  --     base_upfront.order_type_agg     AS order_type_agg,
  --     '42'                    AS cod_segmento,
  --     '09'                    AS cod_marca,
  --     `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront.billing_type_ds, base_upfront.service_type, base_upfront.TIPO_PAQUETE, base_upfront.technology_ds ,COALESCE(base_upfront.line_type_ds,base_upfront.sell_line_type_ds) , base_upfront.brand_ds)                     AS cod_tipo_contrato,
  --     '30'                    AS cod_canal,
  --     CASE 
  --       WHEN base_upfront.service_type IN ('INTERNET', 'FIX') THEN '041'   
  --       WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
  --       ELSE '039'   
  --     END                     AS cod_producto,
  --     CAST(NULL AS STRING)     AS campaign_code,
  --     CAST(NULL AS STRING)     AS serial_number,
  --     CAST(NULL AS FLOAT64)    AS tax_base,
  --     CAST(NULL AS STRING)     AS claim_code,
  --     CAST(NULL AS STRING)     AS process_code,
  --     CAST(NULL AS STRING)     AS comments,
  --     'C_MANUAL'               AS facturador,
  --     CAST(NULL AS STRING)     AS proceso_sap,
  --     CAST(NULL AS STRING)     AS id_registro,
  --     CAST(NULL AS STRING)     AS invoice_id,
  --     'X001'                   AS sociedad,
  --     CAST(NULL AS STRING)     AS bp,
  --     CAST(NULL AS STRING)     AS cuenta_contable,
  --     CAST(NULL AS STRING)     AS centro_coste,
  --     CAST(NULL AS STRING)     AS documento_sap,
  --     CAST(NULL AS STRING)     AS documento_sap_posicion,
  --     CAST(NULL AS STRING)     AS fecha_contabilizacion,
  --     CAST(NULL AS TIMESTAMP)  AS creado,
  --     CAST(NULL AS TIMESTAMP)  AS modificado,
  --     CAST(NULL AS STRING)     AS id_factura_drive,
  --     CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
  --   FROM base_upfront
  --   LEFT JOIN (
  --     SELECT 
  --       cuenta_cliente,
  --       document_number,
  --       customer_id_xena,
  --       provincia,
  --       segmento
  --     FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
  --     ) b2b_xena ON base_upfront.CLIENTE = b2b_xena.customer_id_xena
  --   LEFT JOIN dt ON base_upfront.sell_tariff_id = dt.tariff_id
  --       AND dt.service_type = base_upfront.service_type
  --       AND dt.line_type = base_upfront.sell_line_type_ds
  --       AND dt.tipo_fibra = base_upfront.TIPO_FIBRA
  --   WHERE base_upfront.TIPO_PAQUETE = '2P'
  -- ),

  --DADA DE BAJA liquidacion 02/2025
  -- b_camp_obj AS (

  --   SELECT DISTINCT
  --     'calculado' as estado,
  --     DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
  --     CAST(mes_string AS INT64) as id_mes, 
  --     'B2B - Alterna' AS agrupacion_canal,
  --     'ALT' AS canal,
  --     'D - Adenda Alterna 3P ID:1750' AS concepto, -- D - Campana Objetivo
  --     'UPFR' AS tipo_concepto,
  --     CAST(NULL AS INT64) AS unidades,
  --     CASE
  --       WHEN dt.campana_objetivo IS NULL THEN 0
  --       ELSE dt.campana_objetivo
  --     END AS comision,
  --     base_upfront.CLIENTE        AS id_comisionista,
  --     base_upfront.sfid_id        AS distribuidor,
  --     base_upfront.sfid_id        AS sfid_id,
  --     base_upfront.seller         AS seller,
  --     'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
  --     'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
  --     'B87522652'                        AS cif,
  --     CASE 
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
  --       WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
  --       ELSE 'PEN'
  --     END AS zona_fiscal,
  --     'ALTERNA'               AS marca,
  --     base_upfront.service_type       AS service_type,
  --     CAST(base_upfront.phone_nm AS STRING)           AS phone_nm,
  --     base_upfront.sell_tariff_id     AS tariff_id,
  --     base_upfront.sell_tariff_ds     AS tariff_ds,
  --     base_upfront.service_id         AS service_id,
  --     base_upfront.account_id         AS account_id,
  --     base_upfront.customer_id        AS customer_id,
  --     base_upfront.sell_line_type_ds  AS line_type_ds,
  --     base_upfront.TIPO_PAQUETE       AS bundle_type,
  --     base_upfront.technology_ds      AS technology_ds,
  --     base_upfront.billing_type_ds    AS billing_type_ds,
  --     CAST(NULL AS DATE)              AS init_date,
  --     CAST(NULL AS DATE)              AS end_date,
  --     base_upfront.order_day_id       AS sale_date,
  --     base_upfront.activation_date    AS activation_date,
  --     IF(base_upfront.deactivation_date IS NULL, '9999-12-31',base_upfront.deactivation_date)  AS deactivation_date,
  --     CAST(base_upfront.order_id AS STRING)           AS order_id,
  --     base_upfront.order_type_agg     AS order_type_agg,
  --     '42'                    AS cod_segmento,
  --     '09'                    AS cod_marca,
  --     `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront.billing_type_ds, base_upfront.service_type, base_upfront.TIPO_PAQUETE, base_upfront.technology_ds ,COALESCE(base_upfront.line_type_ds,base_upfront.sell_line_type_ds) , base_upfront.brand_ds)                     AS cod_tipo_contrato,
  --     '30'                    AS cod_canal,
  --     CASE 
  --       WHEN base_upfront.service_type IN ('INTERNET', 'FIX') THEN '041'   
  --       WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
  --       ELSE '039'   
  --     END                     AS cod_producto,
  --     CAST(NULL AS STRING)     AS campaign_code,
  --     CAST(NULL AS STRING)     AS serial_number,
  --     CAST(NULL AS FLOAT64)    AS tax_base,
  --     CAST(NULL AS STRING)     AS claim_code,
  --     CAST(NULL AS STRING)     AS process_code,
  --     CAST(NULL AS STRING)     AS comments,
  --     'C_MANUAL'               AS facturador,
  --     CAST(NULL AS STRING)     AS proceso_sap,
  --     CAST(NULL AS STRING)     AS id_registro,
  --     CAST(NULL AS STRING)     AS invoice_id,
  --     'X001'                   AS sociedad,
  --     CAST(NULL AS STRING)     AS bp,
  --     CAST(NULL AS STRING)     AS cuenta_contable,
  --     CAST(NULL AS STRING)     AS centro_coste,
  --     CAST(NULL AS STRING)     AS documento_sap,
  --     CAST(NULL AS STRING)     AS documento_sap_posicion,
  --     CAST(NULL AS STRING)     AS fecha_contabilizacion,
  --     CAST(NULL AS TIMESTAMP)  AS creado,
  --     CAST(NULL AS TIMESTAMP)  AS modificado,
  --     CAST(NULL AS STRING)     AS id_factura_drive,
  --     CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
  --   FROM base_upfront
  --   LEFT JOIN (
  --     SELECT 
  --       cuenta_cliente,
  --       document_number,
  --       customer_id_xena,
  --       provincia,
  --       segmento
  --     FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
  --     ) b2b_xena ON base_upfront.CLIENTE = b2b_xena.customer_id_xena
  --   LEFT JOIN dt ON base_upfront.sell_tariff_id = dt.tariff_id
  --       AND dt.service_type = base_upfront.service_type
  --       AND dt.line_type = base_upfront.sell_line_type_ds
  --       AND dt.tipo_fibra = base_upfront.TIPO_FIBRA
  -- ),

   b_clawback_upfront AS (
  
    SELECT --DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      REPLACE(REPLACE(REPLACE(REPLACE(IFNULL(IFNULL(g.concepto,base_clawback.concepto),'E - Upfront Acuerdo Alterna 2022'),'D - ','E - '),'A - ','E - '),'R - ','E - '),'Z - ','E - ') AS concepto,
        --'E - Upfront' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      IFNULL(IFNULL(g.comision*-1,base_clawback.comision*-1),0) AS  comision,
      -- CASE
      --   WHEN g.phone_nm IS NOT NULL THEN g.comision*-1
      --   ELSE base_clawback.comision*-1 
      -- END AS comision,
      base_clawback.CLIENTE        AS id_comisionista,
      base_clawback.sfid_id        AS distribuidor,
      base_clawback.sfid_id        AS sfid_id,
      base_clawback.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_clawback.service_type       AS service_type,
      CAST(base_clawback.phone_nm AS STRING)           AS phone_nm,
      base_clawback.sell_tariff_id     AS tariff_id,
      base_clawback.sell_tariff_ds     AS tariff_ds,
      base_clawback.service_id         AS service_id,
      base_clawback.account_id         AS account_id,
      base_clawback.customer_id        AS customer_id,
      base_clawback.sell_line_type_ds  AS line_type_ds,
      base_clawback.TIPO_PAQUETE       AS bundle_type,
      base_clawback.technology_ds      AS technology_ds,
      base_clawback.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS init_date,
      CAST(NULL AS DATE)              AS end_date,
      base_clawback.order_day_id       AS sale_date,
      base_clawback.activation_date    AS activation_date,
      base_clawback.deactivation_date  AS deactivation_date,
      CAST(base_clawback.order_id AS STRING)           AS order_id,
      base_clawback.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_clawback.billing_type_ds, base_clawback.service_type, base_clawback.TIPO_PAQUETE, base_clawback.technology_ds ,COALESCE(base_clawback.line_type_ds,base_clawback.sell_line_type_ds) , base_clawback.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_clawback.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      comentarios              AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      comm_brand_ds_migra      AS claim_code,
      activation_reason_ds     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_CLAWBACK` base_clawback
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_clawback.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_clawback.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_clawback.service_type
        AND dt.line_type = base_clawback.sell_line_type_ds
        AND dt.tipo_fibra = base_clawback.TIPO_FIBRA
    LEFT JOIN (
            SELECT 
              concepto,
              tariff_id,
              tariff_ds,
              bundle_type,
              service_id,
              phone_nm,
              comision
            FROM b_upfront 
            WHERE marca = 'ALTERNA' AND comision > 0 AND tipo_concepto = 'UPFR'
            --AND concepto IN ('D - Upfront Acuerdo Alterna 2022','D - Rappel Acuerdo Alterna 2022')  
        ) g ON g.phone_nm = CAST(base_clawback.phone_nm AS STRING) AND g.service_id = base_clawback.service_id AND (g.tariff_id = base_clawback.sell_tariff_id OR g.tariff_ds = base_clawback.sell_tariff_ds)
      WHERE --base_clawback.comision IS NOT NULL AND 
        (base_clawback.concepto LIKE '%Upfront Acuerdo Alterna 2022' OR base_clawback.concepto IS NULL)
        
  ), --SELECT * FROM b_clawback_upfront WHERE phone_nm = '600053378'

  b_clawback_2P_3P AS (
  
    SELECT --DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      REPLACE(REPLACE(REPLACE(REPLACE(IFNULL(IFNULL(h.concepto,base_clawback.concepto),'E - Camp. BA Ene-Mar 24 ID:1854'),'D - ','E - '),'A - ','E - '),'R - ','E - '),'Z - ','E - ') AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      IFNULL(IFNULL(h.comision*-1,base_clawback.comision*-1),0) AS  comision,
      -- CASE
      --   WHEN h.phone_nm IS NOT NULL THEN h.comision*-1
      --   ELSE base_clawback.comision*-1 
      -- END AS comision,
      base_clawback.CLIENTE        AS id_comisionista,
      base_clawback.sfid_id        AS distribuidor,
      base_clawback.sfid_id        AS sfid_id,
      base_clawback.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_clawback.service_type       AS service_type,
      CAST(base_clawback.phone_nm AS STRING)           AS phone_nm,
      base_clawback.sell_tariff_id     AS tariff_id,
      base_clawback.sell_tariff_ds     AS tariff_ds,
      base_clawback.service_id         AS service_id,
      base_clawback.account_id         AS account_id,
      base_clawback.customer_id        AS customer_id,
      base_clawback.sell_line_type_ds  AS line_type_ds,
      base_clawback.TIPO_PAQUETE       AS bundle_type,
      base_clawback.technology_ds      AS technology_ds,
      base_clawback.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS init_date,
      CAST(NULL AS DATE)              AS end_date,
      base_clawback.order_day_id       AS sale_date,
      base_clawback.activation_date    AS activation_date,
      base_clawback.deactivation_date  AS deactivation_date,
      CAST(base_clawback.order_id AS STRING)           AS order_id,
      base_clawback.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_clawback.billing_type_ds, base_clawback.service_type, base_clawback.TIPO_PAQUETE, base_clawback.technology_ds ,COALESCE(base_clawback.line_type_ds,base_clawback.sell_line_type_ds) , base_clawback.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_clawback.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      comentarios              AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      comm_brand_ds_migra      AS claim_code,
      activation_reason_ds     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_CLAWBACK` base_clawback
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_clawback.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_clawback.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_clawback.service_type
        AND dt.line_type = base_clawback.sell_line_type_ds
        AND dt.tipo_fibra = base_clawback.TIPO_FIBRA
    LEFT JOIN (
            SELECT 
              concepto,
              tariff_id,
              tariff_ds,
              bundle_type,
              service_id,
              phone_nm,
              comision
            FROM b_upfront_2P_3P  
            WHERE marca = 'ALTERNA' AND comision > 0 AND tipo_concepto = 'UPFR'
            --AND concepto IN ('D - Upfront Acuerdo Alterna 2022','D - Rappel Acuerdo Alterna 2022')  
        ) h ON h.phone_nm = CAST(base_clawback.phone_nm AS STRING) AND h.service_id = base_clawback.service_id AND (h.tariff_id = base_clawback.sell_tariff_id OR h.tariff_ds = base_clawback.sell_tariff_ds)
      WHERE --base_clawback.comision IS NOT NULL AND 
        (base_clawback.concepto LIKE '%Camp. BA Ene-Mar 24 ID:1854' OR base_clawback.concepto IS NULL) 
        
  ),

  b_clawback_descuento_2P AS (
  
    SELECT --DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      --SE COMENTA PORQUE EL UPFRONT HA TERMINADO, SE CONTINÚA CALCULADO EL CLAWBACK 
      -- REPLACE(REPLACE(REPLACE(REPLACE(IFNULL(IFNULL(i.concepto,base_clawback.concepto),'E - Camp. Desc 2P ID:1678'),'D - ','E - '),'A - ','E - '),'R - ','E - '),'Z - ','E - ') AS concepto,

      REPLACE(REPLACE(REPLACE(REPLACE(IFNULL(base_clawback.concepto,'E - Camp. Desc 2P ID:1678'),'D - ','E - '),'A - ','E - '),'R - ','E - '),'Z - ','E - ') AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      --MISMO COMENTARIO DE ARRIBA
      -- IFNULL(IFNULL(i.comision*-1,base_clawback.comision*-1),0) AS  comision,

      --EL PRORRATEO DEL CLAWBACK SE HACE EN FINAL--
      IFNULL(base_clawback.comision*-1,0) AS  comision,
      base_clawback.CLIENTE        AS id_comisionista,
      base_clawback.sfid_id        AS distribuidor,
      base_clawback.sfid_id        AS sfid_id,
      base_clawback.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_clawback.service_type       AS service_type,
      CAST(base_clawback.phone_nm AS STRING)           AS phone_nm,
      base_clawback.sell_tariff_id     AS tariff_id,
      base_clawback.sell_tariff_ds     AS tariff_ds,
      base_clawback.service_id         AS service_id,
      base_clawback.account_id         AS account_id,
      base_clawback.customer_id        AS customer_id,
      base_clawback.sell_line_type_ds  AS line_type_ds,
      base_clawback.TIPO_PAQUETE       AS bundle_type,
      base_clawback.technology_ds      AS technology_ds,
      base_clawback.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS init_date,
      CAST(NULL AS DATE)              AS end_date,
      base_clawback.order_day_id       AS sale_date,
      base_clawback.activation_date    AS activation_date,
      base_clawback.deactivation_date  AS deactivation_date,
      CAST(base_clawback.order_id AS STRING)           AS order_id,
      base_clawback.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_clawback.billing_type_ds, base_clawback.service_type, base_clawback.TIPO_PAQUETE, base_clawback.technology_ds ,COALESCE(base_clawback.line_type_ds,base_clawback.sell_line_type_ds) , base_clawback.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_clawback.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      comentarios              AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      comm_brand_ds_migra      AS claim_code,
      activation_reason_ds     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_CLAWBACK` base_clawback
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_clawback.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_clawback.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_clawback.service_type
        AND dt.line_type = base_clawback.sell_line_type_ds
        AND dt.tipo_fibra = base_clawback.TIPO_FIBRA
      --SE COMENTA PORQUE EL UPFRONT HA TERMINADO, SE CONTINÚA CALCULADO EL CLAWBACK 
      -- LEFT JOIN (
      --       SELECT 
      --         concepto,
      --         tariff_id,
      --         tariff_ds,
      --         bundle_type,
      --         service_id,
      --         phone_nm,
      --         comision
      --       FROM campana_descuento_2P  
      --       WHERE marca = 'ALTERNA' AND comision > 0 AND tipo_concepto = 'UPFR'
      --   ) i ON i.phone_nm = CAST(base_clawback.phone_nm AS STRING) AND i.service_id = base_clawback.service_id AND (i.tariff_id = base_clawback.sell_tariff_id OR i.tariff_ds = base_clawback.sell_tariff_ds)
      WHERE 
        (base_clawback.concepto LIKE '%Camp. Desc 2P ID:1678' OR base_clawback.concepto IS NULL)
        
  ),

  b_clawback_camp_obj AS (

    SELECT --DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      CASE
        WHEN base_clawback.concepto LIKE '%Adenda Alterna 3P ID:1459' THEN 'E - Adenda Alterna 3P ID:1459' 
        ELSE 'E - Adenda Alterna 3P ID:1750' 
      END AS concepto, --'E - Campaña Objetivo'
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      --SE COMENTA PORQUE EL UPFRONT HA TERMINADO, SE CONTINÚA CALCULADO EL CLAWBACK
      --COALESCE(IF(-base_clawback.comision = 0,NULL,-base_clawback.comision) ,IF(-m.comision = 0,NULL,-m.comision), -dt.campana_objetivo) AS comision,
      
      COALESCE(IF(-base_clawback.comision = 0,NULL,-base_clawback.comision), -dt.campana_objetivo) AS comision,
      -- CASE
      --   WHEN dt.campana_objetivo IS NULL THEN 0
      --   ELSE -dt.campana_objetivo
      -- END AS comision,
      base_clawback.CLIENTE        AS id_comisionista,
      base_clawback.sfid_id        AS distribuidor,
      base_clawback.sfid_id        AS sfid_id,
      base_clawback.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_clawback.service_type       AS service_type,
      CAST(base_clawback.phone_nm AS STRING)           AS phone_nm,
      base_clawback.sell_tariff_id     AS tariff_id,
      base_clawback.sell_tariff_ds     AS tariff_ds,
      base_clawback.service_id         AS service_id,
      base_clawback.account_id         AS account_id,
      base_clawback.customer_id        AS customer_id,
      base_clawback.sell_line_type_ds  AS line_type_ds,
      base_clawback.TIPO_PAQUETE       AS bundle_type,
      base_clawback.technology_ds      AS technology_ds,
      base_clawback.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS init_date,
      CAST(NULL AS DATE)              AS end_date,
      base_clawback.order_day_id       AS sale_date,
      base_clawback.activation_date    AS activation_date,
      base_clawback.deactivation_date  AS deactivation_date,
      CAST(base_clawback.order_id AS STRING)           AS order_id,
      base_clawback.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_clawback.billing_type_ds, base_clawback.service_type, base_clawback.TIPO_PAQUETE, base_clawback.technology_ds ,COALESCE(base_clawback.line_type_ds,base_clawback.sell_line_type_ds) , base_clawback.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_clawback.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      comentarios              AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      comm_brand_ds_migra      AS claim_code,
      activation_reason_ds     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_CLAWBACK` base_clawback
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_clawback.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_clawback.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_clawback.service_type
        AND dt.line_type = base_clawback.sell_line_type_ds
        AND dt.tipo_fibra = base_clawback.TIPO_FIBRA
    --SE COMENTA PORQUE EL UPFRONT HA TERMINADO, SE CONTINÚA CALCULADO EL CLAWBACK    
    -- LEFT JOIN (
    --         SELECT 
    --           concepto,
    --           tariff_id,
    --           tariff_ds,
    --           bundle_type,
    --           service_id,
    --           phone_nm,
    --           comision
    --         FROM b_camp_obj  
    --         WHERE marca = 'ALTERNA' AND comision > 0 AND tipo_concepto = 'UPFR'
    --     ) m ON m.phone_nm = CAST(base_clawback.phone_nm AS STRING) AND m.service_id = base_clawback.service_id AND (m.tariff_id = base_clawback.sell_tariff_id OR m.tariff_ds = base_clawback.sell_tariff_ds)
      WHERE 
      (
        base_clawback.concepto LIKE '%Adenda Alterna 3P ID:1459' --Nombre antiguo de la campaña
         OR base_clawback.concepto IS NULL 
         OR base_clawback.concepto LIKE '%Adenda Alterna 3P ID:1750'
        )
  ),

  b_clawback_rappel AS (
  
    SELECT --DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - Alterna' AS agrupacion_canal,
      'ALT' AS canal,
      REPLACE(REPLACE(REPLACE(REPLACE(IFNULL(IFNULL(t.concepto,base_clawback.concepto),'E - Rappel Acuerdo Alterna 2022'),'D - ','E - '),'A - ','E - '),'R - ','E - '),'Z - ','E - ') AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      IFNULL(IFNULL(t.comision*-1,base_clawback.comision*-1),0) AS  comision,
      --  CASE
      --   WHEN t.phone_nm IS NOT NULL THEN t.comision*-1
      --   ELSE base_clawback.rappel*-1 
      -- END AS comision,
      --base_clawback.rappel*-1 AS comision,
      base_clawback.CLIENTE        AS id_comisionista,
      base_clawback.sfid_id        AS distribuidor,
      base_clawback.sfid_id        AS sfid_id,
      base_clawback.seller         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'  AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'  AS razon_social, 
      'B87522652'                        AS cif,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'ALTERNA'               AS marca,
      base_clawback.service_type       AS service_type,
      CAST(base_clawback.phone_nm AS STRING)           AS phone_nm,
      base_clawback.sell_tariff_id     AS tariff_id,
      base_clawback.sell_tariff_ds     AS tariff_ds,
      base_clawback.service_id         AS service_id,
      base_clawback.account_id         AS account_id,
      base_clawback.customer_id        AS customer_id,
      base_clawback.sell_line_type_ds  AS line_type_ds,
      base_clawback.TIPO_PAQUETE       AS bundle_type,
      base_clawback.technology_ds      AS technology_ds,
      base_clawback.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS init_date,
      CAST(NULL AS DATE)              AS end_date,
      base_clawback.order_day_id       AS sale_date,
      base_clawback.activation_date    AS activation_date,
      base_clawback.deactivation_date  AS deactivation_date,
      CAST(base_clawback.order_id AS STRING)           AS order_id,
      base_clawback.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_clawback.billing_type_ds, base_clawback.service_type, base_clawback.TIPO_PAQUETE, base_clawback.technology_ds ,COALESCE(base_clawback.line_type_ds,base_clawback.sell_line_type_ds) , base_clawback.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_clawback.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      comentarios              AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      comm_brand_ds_migra      AS claim_code,
      activation_reason_ds     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.ARAL_BASE_CLAWBACK` base_clawback
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_clawback.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN dt ON base_clawback.sell_tariff_id = dt.tariff_id
        AND dt.service_type = base_clawback.service_type
        AND dt.line_type = base_clawback.sell_line_type_ds
        AND dt.tipo_fibra = base_clawback.TIPO_FIBRA
    LEFT JOIN (
            SELECT 
              concepto,
              tariff_id,
              tariff_ds,
              bundle_type,
              service_id,
              phone_nm,
              comision
            FROM b_rappel 
            WHERE marca = 'ALTERNA' AND comision > 0 AND tipo_concepto = 'UPFR'
            --AND concepto IN ('D - Upfront Acuerdo Alterna 2022','D - Rappel Acuerdo Alterna 2022')  
        ) t ON t.phone_nm = CAST(base_clawback.phone_nm AS STRING) AND t.service_id = base_clawback.service_id AND (t.tariff_id = base_clawback.sell_tariff_id OR t.tariff_ds = base_clawback.sell_tariff_ds)
    WHERE --base_clawback.comision IS NOT NULL AND 
      (base_clawback.concepto LIKE '%Rappel Acuerdo Alterna 2022' OR base_clawback.concepto IS NULL)
  ),

  final AS (

    SELECT 
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
      comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b

    UNION ALL

    SELECT DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
      SUM(comision) AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_upfront
    GROUP BY ALL

    UNION ALL

    SELECT DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
      SUM(comision) AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_rappel
    GROUP BY ALL
  
    UNION ALL

    --INCENTIVO ALTAS 2P y 3P 2024-01-01 al 2024-03-01

    SELECT DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1  AS unidades,
      SUM(comision) AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_upfront_2P_3P
    WHERE comision IS NOT NULL AND comision != 0
      AND id_mes BETWEEN 202401 AND 202403
    GROUP BY ALL


    -- UNION ALL

    -- SELECT DISTINCT
    --   estado,
    --   mes_liquidado,
    --   id_mes,
    --   agrupacion_canal,
    --   canal,
    --   concepto,
    --   tipo_concepto,
    --   1 AS unidades,
    --   SUM(comision) AS comision,
    --   id_comisionista,
    --   distribuidor,
    --   sfid_id,
    --   seller,
    --   nombre_comercio,
    --   razon_social,
    --   cif,
    --   zona_fiscal,
    --   marca,
    --   service_type,
    --   phone_nm,
    --   tariff_id,
    --   tariff_ds,
    --   service_id,
    --   account_id,
    --   customer_id,
    --   line_type_ds,
    --   bundle_type,
    --   technology_ds,
    --   billing_type_ds,
    --   sale_date,
    --   activation_date,
    --   deactivation_date,
    --   order_id,
    --   order_type_agg,
    --   cod_segmento,
    --   cod_marca,
    --   cod_tipo_contrato,
    --   cod_producto,
    --   cod_canal,
    --   campaign_code,
    --   serial_number,
    --   tax_base,
    --   claim_code,
    --   process_code,
    --   comments,
    --   facturador,
    --   proceso_sap,
    --   id_registro,
    --   invoice_id,
    --   sociedad,
    --   bp,
    --   cuenta_contable,
    --   centro_coste,
    --   documento_sap,
    --   documento_sap_posicion,
    --   fecha_contabilizacion,
    --   creado,
    --   modificado,
    --   id_factura_drive,
    --   emails_acceso_trazabilidad
    -- FROM campana_descuento_2P
    -- WHERE comision IS NOT NULL AND comision != 0
    -- GROUP BY ALL
  
    -- UNION ALL

    -- SELECT DISTINCT
    --   estado,
    --   mes_liquidado,
    --   id_mes,
    --   agrupacion_canal,
    --   canal,
    --   concepto,
    --   tipo_concepto,
    --   unidades,
    --   SUM(comision) AS comision,
    --   id_comisionista,
    --   distribuidor,
    --   sfid_id,
    --   seller,
    --   nombre_comercio,
    --   razon_social,
    --   cif,
    --   zona_fiscal,
    --   marca,
    --   service_type,
    --   phone_nm,
    --   tariff_id,
    --   tariff_ds,
    --   service_id,
    --   account_id,
    --   customer_id,
    --   line_type_ds,
    --   bundle_type,
    --   technology_ds,
    --   billing_type_ds,
    --   sale_date,
    --   activation_date,
    --   deactivation_date,
    --   order_id,
    --   order_type_agg,
    --   cod_segmento,
    --   cod_marca,
    --   cod_tipo_contrato,
    --   cod_producto,
    --   cod_canal,
    --   campaign_code,
    --   serial_number,
    --   tax_base,
    --   claim_code,
    --   process_code,
    --   comments,
    --   facturador,
    --   proceso_sap,
    --   id_registro,
    --   invoice_id,
    --   sociedad,
    --   bp,
    --   cuenta_contable,
    --   centro_coste,
    --   documento_sap,
    --   documento_sap_posicion,
    --   fecha_contabilizacion,
    --   creado,
    --   modificado,
    --   id_factura_drive,
    --   emails_acceso_trazabilidad
    -- FROM b_camp_obj
    -- WHERE comision IS NOT NULL AND comision != 0
    -- GROUP BY 1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60
    
    UNION ALL

    SELECT --DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      -1 AS unidades,
      comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_clawback_upfront
    --WHERE comision IS NOT NULL AND comision != 0

    UNION ALL

    SELECT --DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      -1 AS unidades,
      comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_clawback_2P_3P
    WHERE comision IS NOT NULL AND comision != 0

    UNION ALL

    SELECT --DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      -1 AS unidades,
      CASE
        WHEN activation_date < DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH) THEN ROUND(((DATE_DIFF(deactivation_date,activation_date,MONTH)-12)*comision/12)*-1,2)
        ELSE comision
      END AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_clawback_descuento_2P
    WHERE comision IS NOT NULL AND comision != 0

    UNION ALL

    SELECT --DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      -1 AS unidades,
      comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_clawback_camp_obj
    WHERE comision IS NOT NULL AND comision != 0
    
    UNION ALL

    SELECT --DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      -1 AS unidades,
      comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive,
      emails_acceso_trazabilidad
    FROM b_clawback_rappel
    WHERE comision IS NOT NULL AND comision != 0
  ) 


  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    * EXCEPT(campaign_code),
    CASE
      WHEN campaign_code LIKE 'BAJA REAL%' THEN 'BAJA REAL'
      ELSE 'PORTABILIDAD'
    END AS campaign_code
  FROM final
  WHERE 1=1 
    AND comision IS NOT NULL --AND comision != 0
    AND concepto LIKE 'E -%'
    --ultimo mes que se lanzó el upfront 202503
      AND activation_date < '2025-04-01'
    --Partidas de clawback que computan para el cálculo.
    AND campaign_code IN (
      'BAJA REAL',
      'BAJA REAL NO ALT - MM',
      'MIGRACION NO ALT - CM_MB',
      'BAJA REAL CM_MB ALT',
      'BAJA REAL NO ALT - CM_MB'
    );

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_aral',
  'ACTUALIZAR'
);

-- CREATE OR REPLACE TABLE TABLA_upfront_ALTERNA_2P_3P AS

--   SELECT *
--   FROM b_upfront_2P_3P
-- ;

END