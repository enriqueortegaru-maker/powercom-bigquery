BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre, tabla_nombre_agrupado, tabla_nombre_row STRING;
DECLARE mes DATE;

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); -- 202504;
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','comisiones_base_armb_', mes_liqui, '');
SET tabla_nombre_agrupado = CONCAT('mm-commissions-reporting.B2B.','agrupado_alta_real_armb_', mes_liqui, '');
SET tabla_nombre_row = CONCAT('mm-commissions-reporting.B2B.','row_comisiones_base_armb_', mes_liqui, '');

--Lanzamos la actualización de la tabla de DEALERS_ALTERNOS para tener la última foto
CALL `mm-commissions-reporting.B2B.pr_dealers_ALTERNOS_CM_MB`();

-- call `mm-commissions-reporting.B2B.pr_cartera_comisiones_base_armb`()

IF NOT EXISTS(
    SELECT *
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE canal = 'MB'
      AND id_mes = CAST(mes_string AS INT64)
      AND (commission_id LIKE 'ARMB%' AND commission_id LIKE CONCAT("ARMB_",CAST(mes_string AS INT64),"_%"))
      AND mes_liquidado = mes
    GROUP BY ALL
    ) THEN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.row_comisiones_base_armb` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 

    billing AS (
      SELECT * EXCEPT(service_type),
        CASE
          WHEN service_type = 'BROADBAND' THEN 'INTERNET'
          ELSE service_type
        END AS service_type, 
        CASE
          WHEN EXTRACT(DAY FROM invoice_date) != 01 THEN DATE_TRUNC(invoice_date,MONTH)
          WHEN LAST_DAY(INIT_DATE) = LAST_DAY(invoice_date) THEN DATE_TRUNC(DATE_ADD(invoice_date, INTERVAL 1 MONTH),MONTH)
          ELSE invoice_date
        END AS invoice_date_mod
      FROM `mm-datamart-kd.BILLING.billing_detail_net`
    ),

    base AS (
      SELECT --SIN DISTINCT
      CAST(mes_string AS INT64) AS id_mes,
      a.* EXCEPT (data_month_id,insert_dt,update_dt, service_type,imp_without_tax,imp_amount, segment_ds,invoice_date,init_date,end_date,invoice_date_mod),
      invoice_date,
      invoice_date_mod,
      init_date,
      end_date,
      CASE
        WHEN (a.billing_tier_1 LIKE '%COSTE DE ALTA' OR a.bill_id LIKE '%COSTE DE ALTA') AND c.current_sfid_id NOT IN ('C09-00009', 'C09-00061', 'C09-00099') THEN 0
        ELSE a.imp_without_tax
      END AS imp_without_tax,
      CASE
        WHEN (a.billing_tier_1 LIKE '%COSTE DE ALTA' OR a.bill_id LIKE '%COSTE DE ALTA') AND c.current_sfid_id NOT IN ('C09-00009', 'C09-00061', 'C09-00099') THEN 0 
        ELSE a.imp_amount
      END AS imp_amount,
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      b.first_territory_ds, 
      CASE 
        WHEN c.bundle_type IS NOT NULL AND a.service_type IN ('FIX','INTERNET') AND c.tariff_ds LIKE '%+%'     THEN 'FMC'
        WHEN c.bundle_type IS NOT NULL AND a.service_type IN ('FIX','INTERNET') AND c.tariff_ds NOT LIKE '%+%' THEN '2P'
        WHEN c.bundle_type IS NOT NULL AND a.service_type = 'MOBILE' THEN c.bundle_type
        WHEN c.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND COALESCE(c.tariff_ds, a.billing_tier_1) LIKE '%+%'           THEN  'FMC'
        WHEN c.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND COALESCE(c.tariff_ds, a.billing_tier_1) NOT LIKE '%+%'       THEN  '2P'
        WHEN c.bundle_type IS NULL AND a.service_type = 'MOBILE' AND COALESCE(c.tariff_ds, a.billing_tier_1) LIKE '%CONV%'                   THEN  'FMC'
        WHEN c.bundle_type IS NULL AND a.service_type = 'MOBILE' AND COALESCE(c.tariff_ds, a.billing_tier_1) NOT LIKE '%CONV%'               THEN  'MO'
      END AS TIPO_PAQUETE, 
      'MARBLANCA' AS CLIENTE,
      c.tariff_ds,
      c.tariff_id,
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
      c.activation_date,
      c.deactivation_date,
      c.order_day_id, 
      c.order_id,
      c.seller,
      CASE
        WHEN CONCAT(c.current_sfid_id,'-',c.current_user_store) IN ('C09-00062-0055','C09-00062-0004','C09-00062-0005','C09-00062-0006','C09-00062-0013') THEN CONCAT(c.current_sfid_id,'-',c.current_user_store)
        WHEN c.current_sfid_id = 'C09-00724-0001' THEN 'C09-00724' --Casos especiales que aparece la tienda en el current_sfid_id y comisionan bajo el mismo nombre.
        WHEN c.current_sfid_id LIKE 'C09-00716%'  THEN 'C09-00716' --Unificamos tiendas por correo de soporte comercial.
        ELSE c.current_sfid_id
      END AS current_sfid_id,
      CASE
        WHEN c.current_user_store = 'NULL' THEN NULL
        ELSE c.current_user_store
      END AS current_user_store,
      c.segment_ds as segmento,
      IF(c.segment_ds = 'BUSINESS','Negocios', c.segment_ds) AS segment_ds,
      DENSE_RANK() OVER(PARTITION BY current_sfid_id ORDER BY a.phone_nm ASC) AS orden_cartera,
      gescal
    FROM billing a 
    LEFT JOIN `mm-datamart-kd.SERVICES.service_base_net` b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm AND a.service_id = b.service_id
    JOIN (
      SELECT DISTINCT 
        a.service_id, 
        a.phone_nm, 
        account_id, 
        a.customer_id, 
        bundle_type, 
        tariff_ds,tariff_id, 
        activation_date, 
        deactivation_date, 
        segment_ds,order_type_agg, 
        technology_ds, 
        line_type_ds, 
        b.MAX_DATE AS order_day_id, 
        order_id, 
        seller, 
        sell_tariff_ds,
        sell_tariff_id, 
        current_user_store, 
        CASE
          WHEN a.current_sfid_id NOT LIKE 'C09%' THEN c.current_sfid_id
          ELSE a.current_sfid_id
        END AS current_sfid_id,
        gescal
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      JOIN (
        SELECT DISTINCT
          phone_nm,
          service_id,
          MAX(activation_date) AS MAX_DATE
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
        AND activation_date IS NOT NULL AND comm_brand_ds = 'MARBLANCA' 
        GROUP BY 1,2
      ) b ON a.phone_nm = b.phone_nm AND a.service_id = b.service_id AND a.activation_date = b.MAX_DATE
      LEFT JOIN ( --Para reemplazar los current_sfid_id que no tienen C09
        SELECT DISTINCT customer_id, current_sfid_id 
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE comm_brand_ds = 'MARBLANCA'
          AND current_sfid_id LIKE 'C09%'
        QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY activation_date DESC) = 1) c ON a.customer_id = c.customer_id AND a.current_sfid_id NOT LIKE 'C09%'
      WHERE comm_brand_ds = 'MARBLANCA' AND activation_date IS NOT NULL 
      AND activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
    ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND LAST_DAY(a.init_date) >= LAST_DAY(c.order_day_id) AND (LAST_DAY(a.end_date) <= LAST_DAY(c.deactivation_date) OR c.deactivation_date IS NULL)
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
    WHERE a.comm_brand_ds = 'MARBLANCA' 
      AND a.invoice_date_mod = DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH) --DATE_TRUNC(CURRENT_DATE, MONTH)
      --Los filtros de aplican abajo
    )
    
    SELECT *
    FROM base
  ; 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.armb_agrupado_alta_real` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS 
  
    SELECT
      current_sfid_id,
      a.phone_nm,
      a.activation_date 
    FROM `mm-commissions-reporting.TEMP.row_comisiones_base_armb` a
    LEFT JOIN (--Cruce para identificar las lineas que provengan de Alterna
      SELECT phone_nm, activation_date, deactivation_date, brand_id
      FROM `mm-datamart-kd.SERVICES.ventas_base_net`
      WHERE brand_id = 'ALTERNA_1'
        AND activation_date IS NOT NULL
    ) b ON a.phone_nm = b.phone_nm
    WHERE 1=1
      AND (b.brand_id IS NULL OR DATE_DIFF(a.activation_date,b.deactivation_date,day) >= 30) --Filtro importante para quedarnos con las altas reales
      AND  NOT a.tariff_ds LIKE '%TTB%' --Quitamos todas las TTB
      AND a.deactivation_date = '9999-12-31'
      AND a.activation_date IS NOT NULL
      AND (b.deactivation_date = '9999-12-31' OR b.deactivation_date IS NULL OR DATE_DIFF(b.deactivation_date,a.activation_date,YEAR) = 0)
      AND a.activation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH))
      AND a.current_sfid_id IN (--Cruce para quedarnos con los cableros-Alternos
        SELECT id_comisionista 
        FROM `mm-commissions-reporting.B2B.DEALERS_ALTERNOS_CM_MB` 
        WHERE agrupacion_canal = 'B2B - Marblanca'
      )
    GROUP BY ALL
    QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_armb` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

    SELECT *
    FROM `mm-commissions-reporting.TEMP.row_comisiones_base_armb` 
    WHERE 1=1
      AND (bill_id NOT LIKE 'PENALIZACION GASTOS INSTALACION%') 
      AND NOT (billing_tier_1 LIKE '%SET-UP%'
        OR billing_tier_1 LIKE      '%SEGUNDO CAMBIO%'
        OR billing_tier_1 LIKE      "%ALTA%" 
        OR billing_tier_1 =         "AJUSTE FACTURACION - PENALIZACION"
        OR billing_tier_1 LIKE      "%ABONO CUOTA DUPLICADA%"
        OR billing_tier_1 LIKE      "%VISITA%"
        OR billing_tier_1 LIKE      '%COMPENSACION POR CORTE DE SERVICIO%'
        OR billing_tier_1 LIKE      '%CUOTA NO DEVOLUCION DEL ROUTER%'
        OR billing_tier_1 =         "AJUSTE FACTURACION - OTROS"
      ) 
  ;
  -- Montamos la query de creación de la tabla diaria ROW/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre_row ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.row_comisiones_base_armb`';
  EXECUTE IMMEDIATE qry;
  -- Montamos la query de creación de la tabla diaria FILTRADA/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.comisiones_base_armb`';
  EXECUTE IMMEDIATE qry;
   --Montamos la query de creación de la tabla diaria AGRUPADA/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre_agrupado ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.armb_agrupado_alta_real`';
  EXECUTE IMMEDIATE qry;
  END IF;

  --Caso especial en el que la facturación se ha hecho PERO, quedó un cablero por subir su información a billing
  --Hay que agregar este left a la ultima consulta de base_inicial y modificar en vez de un CREATE OR REPLACE TABLE A UN INSERT TABLE
    -- LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` a ON tabla_nombre.CLIENTE = b.id_comisionista
    -- WHERE canal = 'MB'
    --   AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AS INT64)
    --   AND tabla_nombre.CLIENTE IS NULL;

END