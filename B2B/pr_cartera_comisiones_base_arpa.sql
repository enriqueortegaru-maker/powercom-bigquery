BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre STRING;
DECLARE mes DATE;

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); -- 202504;
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','comisiones_base_arpa_', mes_liqui, '');

-- CALL `mm-commissions-reporting.B2B.pr_cartera_comisiones_base_arpa`()  
--pr_cartera_comisiones_base_arpa

IF NOT EXISTS(
    SELECT *
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE canal = 'PAR'
      AND id_mes = CAST(mes_string AS INT64)
      AND (commission_id LIKE 'ARPA%'AND commission_id LIKE CONCAT("ARPA_",CAST(mes_string AS INT64),"_%"))
      AND mes_liquidado = mes
    GROUP BY ALL
    ) THEN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_arpa` AS

  WITH 

  --Filtramos ventas_base_telco_net para la marca Parlem
  ventas_base_telco AS (

    SELECT * EXCEPT(sfid_id,bundle_id),
      IFNULL(bundle_id,1) AS bundle_id, --A los bundle_id NULOS le ponemos un número X para que en la clasificación del paquete puedan cruzar y no sean NULOS en el crurce
      CASE
          WHEN comm_brand_ds = 'PARLEM' AND (sfid_id LIKE 'TLV%' OR sfid_id LIKE 'CARIN%' OR sfid_id LIKE 'DONL%' OR sfid_id LIKE 'RONL%') THEN current_sfid_id
          WHEN sfid_id IS NULL THEN current_sfid_id
          ELSE sfid_id 
      END AS sfid_id
    FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
    WHERE 1=1
      AND comm_brand_ds = 'PARLEM'
      AND activation_date < DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH) --DATE_TRUNC(CURRENT_DATE(), MONTH)
      AND activation_date IS NOT NULL
      AND service_type IN ('FIX', 'MOBILE', 'BROADBAND')
      AND (deactivation_date >= PARSE_DATE('%Y%m',mes_string) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH), MONTH)
        OR deactivation_date IS NULL)
  ), --select * from ventas_base_telco where account_id = '11169448'

  transacciones_bundle_type AS (

    SELECT a.account_id, a.bundle_type, b.bundle_id
    FROM `mm-commissions-reporting.COMISIONES.transacciones` a
    LEFT JOIN ventas_base_telco b ON a.service_id = b.service_id AND CAST(b.phone_nm AS STRING) = a.phone_nm 
    WHERE 1=1
      AND canal = 'PAR'
    QUALIFY ROW_NUMBER() OVER(PARTITION BY a.account_id ORDER BY a.activation_date DESC) = 1
  ),

  --Realizamos una agregación por número de servicios FIX/MOBILE para definir MO,2P,FMC. Hay casos en que una 2P es una FMC y la tarifa es incorrecta. 
  ext_bundle_type AS (

    SELECT 
      account_id,
      bundle_id,
      COUNT(*) AS total_services,
      COUNT(CASE WHEN service_type = 'FIX' THEN 1 END) AS fix_count,
      COUNT(CASE WHEN service_type = 'MOBILE' THEN 1 END) AS mobile_count,
    FROM ventas_base_telco
    WHERE 1=1
      AND (deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(PARSE_DATE('%Y%m',mes_string)) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)) 
      OR deactivation_date IS NULL OR deactivation_date >= DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH))-- DATE_TRUNC(CURRENT_DATE(), MONTH)) -- quitamos aquellas fechas de desactivación que estén en el mes en curso
      AND service_type IN ('FIX', 'MOBILE')
    GROUP BY ALL
  ), 

  --Definimos el bundle_type según el número de servicios 
  count_bundle_type AS (

    SELECT 
      a.account_id,
      a.bundle_id,
      CASE 
        WHEN serv.total_services >= 3 AND serv.fix_count > 0 AND mobile_count > 0 THEN 'FMC'
        WHEN serv.total_services >= 3 AND serv.fix_count = serv.total_services THEN '2P'
        WHEN serv.total_services >= 3 AND serv.mobile_count = serv.total_services THEN 'MO'
        WHEN serv.total_services >= 2 AND serv.fix_count > 0 AND mobile_count = 0 THEN '2P'  
        WHEN serv.total_services = 2 AND serv.mobile_count = 1 AND serv.fix_count = 1 THEN 'FMC'
        WHEN serv.total_services = 2 AND serv.mobile_count = serv.total_services THEN 'MO' 
        WHEN serv.total_services = 1 AND serv.fix_count = 1 THEN '2P'
        WHEN serv.total_services = 1 AND serv.mobile_count = 1 THEN 'MO'
        ELSE  tr.bundle_type
      END AS bundle_type_n
    FROM ventas_base_telco a
    LEFT JOIN ext_bundle_type serv ON serv.account_id = a.account_id AND serv.bundle_id = a.bundle_id
    LEFT JOIN transacciones_bundle_type tr ON tr.account_id = a.account_id AND tr.bundle_id = a.bundle_id
    WHERE 1=1
    GROUP BY ALL
  ),

  base_ventas AS (

    SELECT a.* EXCEPT(order_fix_id,bundle_type, service_type),
      CASE
        WHEN bundle_type_n IS NULL THEN
        --Bajas menores al mes de la liquidación
          CASE
            WHEN a.bundle_type IN ('D','MD','M') THEN 'MO'
            WHEN a.bundle_type LIKE ('FM%') THEN 'FMC'
            WHEN a.bundle_type = 'FB' THEN '2P'
            ELSE NULL
          END
        ELSE bundle_type_n
      END AS bundle_type,
      a.bundle_type AS bundle_type_old,
      COALESCE(IF(a.order_fix_id = '', NULL, a.order_fix_id), b.order_fix_id) AS order_fix_id,
      IF(service_type IN ('FIX','BROADBAND'), 'INTERNET', service_type) AS service_type,
    FROM ventas_base_telco a
    LEFT JOIN (
      SELECT 
          account_id,
          order_fix_id
      FROM ventas_base_telco
      WHERE service_type = 'FIX'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY account_id ORDER BY activation_date DESC) = 1
    ) b ON a.account_id = b.account_id 
    LEFT JOIN count_bundle_type ON a.account_id = count_bundle_type.account_id AND a.bundle_id = count_bundle_type.bundle_id
  ),

  base_in AS (
    SELECT
      'F46463' AS CLIENTE,
      a.comm_brand_ds,
      a.service_id,
      a.brand_ds,
      a.phone_nm, 
      a.account_id, 
      a.customer_id, 
      a.service_type,
      a.bundle_type AS  TIPO_PAQUETE,
      CASE
        WHEN tariff_ds = 'TARIFA FIJO' THEN CAST(a.bundle_id AS STRING)
        WHEN bundle_type IN ('FMC', '2P') and a.bundle_id IS NOT NULL AND service_type != 'MOBILE'  THEN CAST(a.bundle_id AS STRING)
        ELSE a.tariff_id 
      END AS tariff_id, 
      CASE
        WHEN tariff_ds = 'TARIFA FIJO' THEN a.bundle_name
        WHEN bundle_type IN ('FMC', '2P') and a.bundle_name IS NOT NULL AND service_type != 'MOBILE' THEN a.bundle_name
        ELSE UPPER(a.tariff_ds) 
      END AS tariff_ds,
      CAST(
      CASE
        WHEN a.bundle_id = 1 THEN NULL
        ELSE COALESCE(a.bundle_id, b.bundle_id)
      END AS STRING) AS ID_TARIFA_PAQUETE ,
      CASE
        WHEN CAST(a.bundle_id AS STRING) = '1' THEN NULL
        ELSE COALESCE(a.bundle_name, b.bundle_name)
      END AS TARIFA_PAQUETE,
      CASE
        WHEN a.bundle_id = 1 THEN NULL 
        ELSE a.bundle_id
      END bundle_id,
      a.bundle_name,
      -- c.init_date,
      -- c.end_date, 
      a.activation_date, 
      IF(deactivation_date IS NULL, '9999-12-31', deactivation_date) AS deactivation_date,
      a.segment_ds,
      a.billing_type_ds,
      a.order_type_agg, 
      a.technology_ds, 
      line_type_ds,
      a.order_date AS order_day_id,
      a.order_id, 
      a.zip_code,
      --IF(order_fix_id = '', NULL,order_fix_id) AS order_fix_id,
      first_territory_ds,
      a.seller, 
      a.sfid_id,
      a.current_sfid_id, 
      a.order_fix_id
    FROM base_ventas a
    LEFT JOIN (
        SELECT account_id, bundle_id, bundle_name
        FROM base_ventas
        WHERE service_type = 'INTERNET'
        QUALIFY ROW_NUMBER() OVER(PARTITION BY account_id) = 1
    ) b ON a.account_id = b.account_id
  ),

   base_line_type AS (

    SELECT * EXCEPT(line_type_ds),
      CASE
        WHEN line_type_ds = 'MAIN' AND (tariff_ds LIKE '% AD%') AND tipo_paquete != 'MO' THEN 'ADDITIONAL'
        WHEN tipo_paquete = 'MO' THEN 'MAIN'
        ELSE line_type_ds
      END AS  line_type_ds,
      CASE
        WHEN TIPO_PAQUETE = 'MO' THEN 'NA'
        WHEN service_type = 'MOBILE' AND TIPO_PAQUETE != 'MO' AND TARIFA_PAQUETE LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        WHEN service_type = 'INTERNET' AND tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        ELSE 'PROPIA'
      END AS TIPO_FIBRA,
    FROM base_in
  ) ,

  base_fix AS (

    SELECT * EXCEPT(order_fix_id),
      CASE
        WHEN (line_type_ds = 'MAIN' AND tariff_ds LIKE '% AD%') OR line_type_ds = 'ADDITIONAL' THEN NULL
        ELSE IF(order_fix_id = '',NULL,order_fix_id)
      END AS order_fix_id,
    FROM base_line_type
  ),

    /* Cruze para recuperar huella del acceso */

  base_huella AS (

    SELECT a.* EXCEPT(first_territory_ds),
      COALESCE(f.footprint_detail, g.footprint_detail) AS footprint_detail,
      COALESCE(f.footprint_contract, g.footprint_contract) AS footprint_contract,
      COALESCE(a.first_territory_ds,e.ftth_territoryowner) AS first_territory_ds
    FROM base_fix a
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
    ),
  
  --Clasificamos el first_territoy_ds según indicaciones del excel

  base AS (

    SELECT a.* EXCEPT(first_territory_ds),
      CASE
        WHEN TIPO_PAQUETE IN ('FMC','2P') AND (b.FOOTPRINT IS NULL OR c.first_territory_ds IS NULL) THEN 'PROPIA'
        ELSE COALESCE(b.FOOTPRINT,c.FOOTPRINT)
      END AS  first_territory_ds,
    FROM base_huella a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.clasificacion_huellas_canales` b ON a.footprint_contract = b.FOOTPRINT_CONTRACT AND a.footprint_detail = b.FOOTPRINT_DETAIL
    LEFT JOIN `mm-commissions-reporting.COMISIONES.clasificacion_first_territory_canales` c ON a.first_territory_ds = c.first_territory_ds AND a.TIPO_PAQUETE IN ('FMC','2P')
  )
   ,

  base_cartera AS (

    SELECT a.*, 
      c.billing_tier_1, 
      c.imp_without_tax 
    FROM base a
    JOIN (
    SELECT invoice_id, account_id, service_id, phone_nm,billing_tier_1, SUM(imp_without_tax)AS imp_without_tax
    FROM `mm-datamart-kd.BILLING.billing_detail_emysim` 
    WHERE --Modificar por el canal 
      comm_brand_ds = 'PARLEM'
      AND invoice_date = DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH) --DATE_TRUNC(CURRENT_DATE(),MONTH)
      AND imp_without_tax != 0
      --Marblanca
      -- AND NOT (billing_tier_1 LIKE '%SET-UP%'
      --       OR billing_tier_1 LIKE "%ALTA%"
      --       OR billing_tier_1 LIKE '%SEGUNDO CAMBIO%'
      --       OR billing_tier_1 = "AJUSTE FACTURACION - PENALIZACION"
      --       OR billing_tier_1 LIKE "%VISITA TECNICO%"
      --       OR billing_tier_1 LIKE "%ABONO CUOTA DUPLICADA%"
      --       )
      -- Otros canales
      AND NOT(billing_tier_1 LIKE '%RESTABLECIMIENTO DEL SERVICIO%'
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
      ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND a.service_id = c.service_id   

        QUALIFY ROW_NUMBER() OVER(PARTITION BY c.invoice_id, a.account_id, a.customer_id, a.service_id, c.billing_tier_1, CAST(c.imp_without_tax AS STRING) ORDER BY a.activation_date DESC) = 1

  )

  SELECT 
    CAST(mes_string AS INT64) AS id_mes,
    *
  FROM base_cartera
;

    --Montamos la query de creación de la tabla diaria /
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.comisiones_base_arpa`';
  EXECUTE IMMEDIATE qry;
  END IF;

END