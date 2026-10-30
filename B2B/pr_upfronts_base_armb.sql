BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre STRING;
DECLARE mes DATE;

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); -- 202504;
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','upfronts_base_armb_', mes_liqui, '');

-- CALL `mm-commissions-reporting.B2B.pr_upfronts_base_armb`()

-- IF NOT EXISTS(
--     SELECT *
--     FROM `mm-commissions-reporting.COMISIONES.transacciones`
--     WHERE canal = 'MB'
--       AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AS INT64)
--       AND (commission_id LIKE 'ARMB%' AND commission_id LIKE CONCAT("ARMB_",CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AS INT64),"_%"))
--       AND mes_liquidado = mes
--     GROUP BY ALL
--     ) THEN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.upfronts_base_armb` AS

  WITH 

    base AS (
      SELECT DISTINCT
        CAST(mes_string AS INT64) AS id_mes,
        data_source_ds,
        a.brand_id,
        a.customer_id,
        a.account_id,
        a.service_id,
        a.phone_nm,
        a.activation_date,
        CASE
          WHEN a.deactivation_date >= DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH) THEN NULL
          ELSE a.deactivation_date
        END AS deactivation_date,
        a.activation_reason_ds,
        a.deactivation_reason_ds,
        a.segment_ds,
        a.sub_segment_ds,
        a.billing_type_ds,
        a.technology_speed_ds,
        a.sfid_id,
        a.order_fix_id,
        a.first_territory_ds,
        a.current_territory_ds,
        a.access_ds,
        a.deactivation_tariff_ds,
        a.activation_tariff_ds,
        a.deactivation_tariff_id,
        a.activation_tariff_id,
        a.deactivation_date_main_line,
        a.activation_date_main_line,
        a.kpi_fin_tramo_eop,
        a.kpi_gross_add,
        a.kpi_deactivation,
        a.kpi_gross_add_before_net,
        a.kpi_deactivation_before_net,
        a.net_id,
        a.net_order,
        a.brand_ds,
        a.sub_brand_ds,
        a.comm_brand_ds,
        a.brand_aggr,
        a.channel_segment_ds,
        a.subchannel_ds,
        a.channel_ds,
        a.superchannel_ds,
        a.master_channel_ds,
        a.channel_type_ds,
        a.last_update,
        a.last_update_acc_prov,
        a.last_update_net,
        IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
        CASE 
          WHEN c.bundle_type IS NOT NULL AND a.service_type IN ('FIX','INTERNET') AND c.tariff_ds LIKE '%+%'     THEN 'FMC'
          WHEN c.bundle_type IS NOT NULL AND a.service_type IN ('FIX','INTERNET') AND c.tariff_ds NOT LIKE '%+%' THEN '2P'
          WHEN c.bundle_type IS NOT NULL AND a.service_type = 'MOBILE' THEN c.bundle_type
          WHEN c.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND c.tariff_ds LIKE '%+%'           THEN  'FMC'
          WHEN c.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND c.tariff_ds NOT LIKE '%+%'       THEN  '2P'
          WHEN c.bundle_type IS NULL AND a.service_type = 'MOBILE' AND c.tariff_ds LIKE '%CONV%'                   THEN  'FMC'
          WHEN c.bundle_type IS NULL AND a.service_type = 'MOBILE' AND c.tariff_ds NOT LIKE '%CONV%'               THEN  'MO'
        END AS TIPO_PAQUETE, 
        'MARBLANCA' AS CLIENTE,
        c.tariff_ds,
        c.tariff_id,
        c.bundle_type,
        IF(a.service_type = 'MOBILE' AND c.bundle_type != d.bundle_type, d.sell_tariff_ds, d.tariff_ds) AS TARIFA_PAQUETE,
        IF(a.service_type = 'MOBILE' AND c.bundle_type != d.bundle_type, d.sell_tariff_id, d.tariff_id) AS ID_TARIFA_PAQUETE,
        c.order_type_agg,
        c.technology_ds,
        CASE
          WHEN c.bundle_type = 'MO' THEN 'NA'
          WHEN a.service_type = 'MOBILE' AND c.bundle_type != 'MO' AND d.tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
          WHEN a.service_type IN('FIX','INTERNET') AND c.tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
          ELSE 'PROPIA'
        END AS TIPO_FIBRA,
        IF(c.line_type_ds = 'EXTRA', 'ADDITIONAL', c.line_type_ds) AS line_type_ds,
        c.order_day_id,
        c.order_id,
        c.seller,
        CASE 
          WHEN current_sfid_id = 'C09-00724-0001' THEN 'C09-00724' 
          WHEN current_sfid_id LIKE 'C09-00716%'  THEN 'C09-00716' --Unificamos tiendas por correo de soporte comercial.
          ELSE current_sfid_id
        END AS current_sfid_id, 
        CASE
          WHEN c.current_user_store = 'NULL' THEN NULL
          ELSE c.current_user_store
        END AS current_user_store,
        e.document_type,
        c.gescal,
        IF(f.grupo_operador_donante_unificado IS NULL, 'NO DEFINIDA',grupo_operador_donante_unificado) AS grupo_operador_donante_unificado
      FROM `mm-datamart-kd.SERVICES.service_base_net` a 
      LEFT JOIN (
        SELECT DISTINCT a.service_id, a.phone_nm, account_id, customer_id, bundle_type, tariff_ds,tariff_id, activation_date, deactivation_date, segment_ds,order_type_agg, technology_ds, line_type_ds, b.MAX_DATE AS order_day_id, order_id, seller, current_sfid_id, sell_tariff_ds, sell_tariff_id,current_user_store,customer_document_type,gescal
        FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
        JOIN (
          SELECT DISTINCT
            phone_nm,
            service_id,
            MAX(activation_date) AS MAX_DATE
          FROM `mm-datamart-kd.SERVICES.ventas_base_net`
          WHERE activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
          AND activation_date IS NOT NULL AND comm_brand_ds = 'MARBLANCA'
          AND order_type_agg <> 'CAMBIO DOMICILIO'
          
           GROUP BY 1,2
        ) b ON a.phone_nm = b.phone_nm AND a.service_id = b.service_id AND a.activation_date = b.MAX_DATE
        WHERE comm_brand_ds = 'MARBLANCA' AND activation_date IS NOT NULL 
        AND activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
      ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND a.activation_date = c.activation_date AND a.service_id = c.service_id
      LEFT JOIN (
        SELECT DISTINCT 
          account_id,
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
          a.service_type = 'FIX'  
          AND a.activation_date IS NOT NULL  
          AND a.activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
          AND a.comm_brand_ds = 'MARBLANCA' 
          AND (LAST_DAY(a.deactivation_date) >= last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
          OR a.deactivation_date IS NULL) 
          --a.order_type_agg != 'CAMBIO DOMICILIO'
      ) d ON c.account_id = d.account_id AND c.order_day_id >= d.order_day_id AND (c.deactivation_date <= d.deactivation_date OR d.deactivation_date IS NULL) AND a.service_type = 'MOBILE'
      LEFT JOIN (
        SELECT DISTINCT document_type, original_document_type, phone_nm, account_id
        FROM `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` 
        ) e ON a.phone_nm = e.phone_nm AND a.account_id = e.account_id
      LEFT JOIN (
        SELECT grupo_operador_donante_unificado, phone_nm, activation_date
        FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
        WHERE brand_ds = 'MARBLANCA'
          AND grupo_operador_donante_unificado IS NOT NULL
        GROUP BY ALL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm ORDER BY activation_date DESC, grupo_operador_donante_unificado DESC) = 1
      ) f ON a.phone_nm = f.phone_nm AND a.activation_date = f.activation_date
    -- INNER JOIN ( 
    --     SELECT DISTINCT phone_nm, customer_id, billing_tier_1
    --     FROM `mm-datamart-kd.BILLING.billing_detail_net` 
    --     WHERE billing_tier_1 = 'COSTE DE ALTA' AND comm_brand_ds = 'MARBLANCA' AND service_type in ('FIX', 'BROADBAND')
    --     GROUP BY ALL
    --   ) g ON a.customer_id = g.customer_id AND a.phone_nm = g.phone_nm
    -- LO QUITAMOS POR EL ERROR DE LA 1354

      WHERE a.comm_brand_ds = 'MARBLANCA' 
        -- AND (a.kpi_gross_add = 1 ) --OR a.kpi_gross_add_before_net = 1 --filtrado en comisiones working

        --No filtramos por fecha de activación porque puede existir una campaña que esté en vuelo que se cierre 2 años después de su creación.

        --AND a.activation_date BETWEEN DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 11 MONTH), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
        AND (a.deactivation_date IS NULL OR a.deactivation_date = '9999-12-31' 
        OR a.deactivation_date >= DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH)) -- DATE_TRUNC(CURRENT_DATE, MONTH)
        AND (a.service_type = 'FIX')
    )
    
    SELECT *
    FROM base

  ;

    --Montamos la query de creación de la tabla diaria /
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.upfronts_base_armb`';
  EXECUTE IMMEDIATE qry;
  --END IF;

  --Caso especial en el que la facturación se ha hecho PERO, quedó un cablero por subir su información a billing
  --Hay que agregar este left a la ultima consulta de base_inicial y modificar en vez de un CREATE OR REPLACE TABLE A UN INSERT TABLE
    -- LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` a ON tabla_nombre.CLIENTE = b.id_comisionista
    -- WHERE canal = 'MB'
    --   AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AS INT64)
    --   AND tabla_nombre.CLIENTE IS NULL;

END