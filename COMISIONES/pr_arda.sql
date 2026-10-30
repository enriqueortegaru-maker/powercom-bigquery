BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ADA';

SET canales_pr = ['ADA'];

-- call `mm-commissions-reporting.COMISIONES.pr_arda`(202308,['ADA']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arda` AS 


--CARTERA

  WITH base AS (
      SELECT DISTINCT 
        data_month_id,
        Cliente,
        SubCliente AS account_id,
        Msisdn AS phone_nm,
        CASE
          WHEN Fecha_Activacion IN ('W45486','216517','216042') THEN NULL
          ELSE PARSE_DATE('%Y%m%d',Fecha_Activacion)
        END AS activation_date,
        COALESCE(Tarifa_ID,SUBSTRING(Bono_Compartido_Descripcion,1,5)) AS bono_id,
        COALESCE(Producto_Descripcion,SUBSTRING(Bono_Compartido_Descripcion,7)) AS bono_name,
        Producto_ID,
        Total_Facturacion AS imp_without_tax
      FROM  `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_20230901`a
      WHERE a.cliente = '216517'
        --AND SubCliente = '216517708113'
        --AND d.invoice_date = DATE_TRUNC(CURRENT_DATE(), MONTH) --Si quieres lanzar junio va 2023-07-01 
        --AND (a.deactivation_date IS NULL OR a.deactivation_date >= '2023-06-01') --AND a.phone_nm = 613130514
  ),

  max_precio_base AS (
    SELECT 
      a.* EXCEPT(imp_without_tax),
      b.max_precio AS pvp_sin_iva
    FROM base a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        MAX(imp_without_tax) AS max_precio
      FROM base
      WHERE phone_nm IS NOT NULL
      GROUP BY 1
    ) b ON a.account_id = b.account_id AND a.imp_without_tax = b.max_precio
    WHERE b.account_id IS NOT NULL 
  ), --SELECT * FROM max_precio_base 

  min_base AS (
    SELECT 
      a.* EXCEPT(activation_date),
      b.min_act_date AS activation_date
    FROM max_precio_base a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        MIN(activation_date) AS min_act_date
      FROM max_precio_base
      GROUP BY 1
    ) b ON a.account_id = b.account_id AND a.activation_date = b.min_act_date
    WHERE b.account_id IS NOT NULL 
  ),--SELECT * FROM min_base 

  bono_base AS (
    SELECT 
      a.* EXCEPT(phone_nm),
      'SI' AS linea_principal,
      b.min_phone_nm AS phone_nm
    FROM min_base a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        bono_id,
        MIN(phone_nm) AS min_phone_nm
      FROM min_base
      GROUP BY 1,2
    ) b ON a.account_id = b.account_id AND a.phone_nm = b.min_phone_nm AND a.bono_id = b.bono_id
    WHERE b.account_id IS NOT NULL 
  ) --SELECT * FROM bono_base WHERE account_id ='216517720779'
  ,

  def_base AS(
    SELECT a.*,
        IF(b.linea_principal IS NULL,'NO','SI') AS linea_principal,
        CASE
          WHEN b.phone_nm IS NOT NULL THEN 'MAIN'
          ELSE 'ADDITIONAL'
        END AS line_type_ds,
        c.service_type,
        c.service_id,
        c.technology_ds,
        c.billing_type_ds,
        c.deactivation_date
    FROM base a
    LEFT JOIN bono_base b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm
    LEFT JOIN (
      SELECT a.* EXCEPT(activation_date),
        b.max_activation_date
      FROM `mm-datamart-kd.SERVICES.service_base_net` a
      JOIN (
        SELECT DISTINCT phone_nm, account_id, MAX(activation_date) AS max_activation_date
        FROM `mm-datamart-kd.SERVICES.service_base_net`
        WHERE comm_brand_ds = 'CABLEMOVIL'
        GROUP BY 1,2
      ) b ON a.phone_nm = b.phone_nm AND a.account_id = b.account_id AND a.activation_date = b.max_activation_date
    ) c ON a.phone_nm = CAST(c.phone_nm AS STRING) AND a.account_id = c.account_id
  )
  ,
  -- SELECT *
  -- FROM def_base
  -- WHERE phone_nm = '655653263'


--UPFRONT

  base_act AS (
      
    SELECT DISTINCT 
      a.* EXCEPT (service_type, segment_ds),
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      '216517' AS CLIENTE,
      d.bono_name,
      d.bono_id,
      d.pvp_sin_iva,
      IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds,
      IF(b.account_id IS NOT NULL, 'NO','SI') AS linea_principal,
      c.kpi_gross_add AS kpi_gross_add_last
    FROM  `mm-datamart-kd.SERVICES.service_base_net` a
    LEFT JOIN (
      SELECT
        phone_nm,
        account_id,
        service_id,
      FROM `mm-datamart-kd.SERVICES.service_base_net`
      WHERE customer_id = '216517'
        AND LAST_DAY(activation_date) = last_day(date_sub(current_date(),INTERVAL 1 MONTH))  
        AND activation_date IS NOT NULL 
        AND line_type_ds = 'MAIN' 
        AND service_type = 'MOBILE' 
    ) b ON a.account_id = b.account_id
    LEFT JOIN (
      --Buscamos en el mes anterior si tiene un kpi = 1
      SELECT
        phone_nm,
        account_id,
        kpi_gross_add,
        MIN(activation_date)
      FROM `mm-datamart-kd.SERVICES.service_base_net`
      WHERE customer_id = '216517' 
        AND activation_date IS NOT NULL 
        AND line_type_ds = 'MAIN' 
        AND service_type = 'MOBILE' 
        AND LAST_DAY(activation_date) = last_day(date_sub(current_date(),INTERVAL 1 MONTH))
        AND kpi_gross_add = 1
      GROUP BY 1,2,3
    ) c ON a.account_id = c.account_id
    LEFT JOIN (
      SELECT DISTINCT
        a.phone_nm, 
        a.bono_id,
        a.bono_name,
        a.bono_producto,
        a.bono_service,
        b.fecha,
        s.pvp_sin_iva
      FROM `mm-datamart-kd.SERVICES.bonos_base_xena` a
      JOIN (
        SELECT 
          phone_nm,
          bono_service,
          MAX(PARSE_DATE('%Y%m%d', init_date)) AS fecha
        FROM `mm-datamart-kd.SERVICES.bonos_base_xena` a
        WHERE bono_service NOT IN ('VOZ') 
          AND PARSE_DATE('%Y%m%d', init_date) <= LAST_DAY(CURRENT_DATE()) 
          AND fuente = 'MSISDN' --AND phone_nm = '601980569'
        GROUP BY 1,2
      ) b ON PARSE_DATE('%Y%m%d', a.init_date) = b.fecha AND a.phone_nm = b.phone_nm AND a.bono_service = b.bono_service
      LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.Maestro_BI_XENA` s ON a.bono_id = s.id_bono 
    ) d ON a.tariff_id = d.bono_producto AND CAST(a.phone_nm AS STRING) = d.phone_nm
    WHERE customer_id = '216517'
      AND (a.kpi_gross_add = 1 OR c.kpi_gross_add = 1) 
      --Ejemplos: activation '2023-05-01' AND '2023-05-31'// deactivation '2023-06-01'
      AND (a.activation_date BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))) 
      AND (a.deactivation_date IS NULL OR a.deactivation_date >= DATE_TRUNC(CURRENT_DATE(),MONTH))
      --OJO QUE HAY QUE CAMBIAR DESPUES DEL OR POR CURRENT_DATE SIN EL DATE_SUB
  ),

  max_precio_act AS (
    SELECT 
      a.* EXCEPT(pvp_sin_iva),
      b.max_precio AS pvp_sin_iva
    FROM base_act a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        MAX(pvp_sin_iva) AS max_precio
      FROM base_act
      GROUP BY 1
    ) b ON a.account_id = b.account_id AND a.pvp_sin_iva = b.max_precio
    WHERE b.account_id IS NOT NULL 
  ), -- SELECT * FROM max_precio_act WHERE phone_nm = 685847569

  min_act_date AS (
    SELECT 
      a.* EXCEPT(activation_date),
      b.min_act_date AS activation_date
    FROM max_precio_act a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        MIN(activation_date) AS min_act_date
      FROM max_precio_act
      GROUP BY 1
    ) b ON a.account_id = b.account_id AND a.activation_date = b.min_act_date
    WHERE b.account_id IS NOT NULL 
  ), --SELECT * FROM min_act_date WHERE phone_nm = 685847569

  def_base_act AS (
    SELECT 
      a.* EXCEPT(phone_nm, pvp_sin_iva),
      a.pvp_sin_iva AS imp_without_tax,
      b.max_phone_nm AS phone_nm
    FROM min_act_date a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        bono_id,
        MAX(phone_nm) AS max_phone_nm
      FROM min_act_date
      GROUP BY 1,2
    ) b ON a.account_id = b.account_id AND a.phone_nm = b.max_phone_nm AND a.bono_id = b.bono_id
    WHERE b.account_id IS NOT NULL 
  ), -- SELECT * FROM bono_act WHERE phone_nm = 685847569

--CLAWBACK

  bono_deact AS (
      
    SELECT DISTINCT 
      a.* EXCEPT (service_type, segment_ds,activation_date),
      CAST(activation_date AS STRING) AS activation_date,
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      '216517' AS CLIENTE,
      d.bono_name,
      d.bono_id,
      d.pvp_sin_iva,
      IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds,
      IF(b.account_id IS NOT NULL, 'NO','SI') AS linea_principal
    FROM  `mm-datamart-kd.SERVICES.service_base_net` a
    LEFT JOIN (
      SELECT
        phone_nm,
        account_id,
        service_id,
      FROM `mm-datamart-kd.SERVICES.service_base_net`
      WHERE customer_id = '216517'
        AND LAST_DAY(activation_date) = last_day(date_sub(current_date(),INTERVAL 3 month)) 
        AND activation_date IS NOT NULL 
        AND line_type_ds = 'MAIN' 
        AND service_type = 'MOBILE' 
    ) b ON a.account_id = b.account_id
    LEFT JOIN (
      SELECT DISTINCT
        a.phone_nm, 
        a.bono_id,
        a.bono_name,
        a.bono_producto,
        a.bono_service,
        b.fecha,
        s.pvp_sin_iva
      FROM `mm-datamart-kd.SERVICES.bonos_base_xena` a
      JOIN (
        SELECT 
          phone_nm,
          bono_service,
          MAX(PARSE_DATE('%Y%m%d', init_date)) AS fecha
        FROM `mm-datamart-kd.SERVICES.bonos_base_xena` a
        WHERE bono_service NOT IN ('VOZ') 
          AND PARSE_DATE('%Y%m%d', init_date) <= LAST_DAY(CURRENT_DATE()) 
          AND fuente = 'MSISDN' --AND phone_nm = '601980569'
        GROUP BY 1,2
      ) b ON PARSE_DATE('%Y%m%d', a.init_date) = b.fecha AND a.phone_nm = b.phone_nm AND a.bono_service = b.bono_service
      LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.Maestro_BI_XENA` s ON a.bono_id = s.id_bono 
    ) d ON a.tariff_id = d.bono_producto AND CAST(a.phone_nm AS STRING) = d.phone_nm
    WHERE --(a.activation_date BETWEEN '2023-04-01' AND '2023-04-30' AND a.kpi_gross_add = 1 AND (a.deactivation_date IS NULL OR a.deactivation_date >= '2023-05-01')) 
      customer_id = '216517'
      AND (a.deactivation_date BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 2 MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH)) 
      AND a.kpi_deactivation = 1)--No hay duplicados por telefono, duplicados por acc id, solo uno
      AND (DATE_DIFF(a.activation_date, a.deactivation_date, DAY)< 365)
      --AND b.account_id IS NULL
      --AND a.phone_nm = 601980569
  ),


-- CALCULO

  b AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(NULL AS INT64) as id_mes, 
      'B2B' AS agrupacion_canal,
      'ADA' AS canal,
      CASE
        WHEN linea_principal = 'SI' AND line_type_ds = 'MAIN' THEN 'C - Gestion Cartera Movil (40%)'
        WHEN linea_principal = 'NO' AND line_type_ds = 'ADDITIONAL' THEN 'C - Gestion Cartera Movil (50%)'
        ELSE 'C - Gestion Cartera Resto (0%)'
      END AS concepto,
      'AIRT' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
        CASE
        WHEN linea_principal = 'SI' AND line_type_ds = 'MAIN' THEN imp_without_tax*0.40
        WHEN linea_principal = 'NO' AND line_type_ds = 'ADDITIONAL' THEN imp_without_tax*0.50
        ELSE 0
      END AS comision,
      imp_without_tax,
      def_base.CLIENTE             AS id_comisionista,
      def_base.CLIENTE             AS distribuidor,
      def_base.CLIENTE             AS sfid_id,
      def_base.CLIENTE             AS seller, --es null def_base.sfid_id
      'ADAMO TELECOM IBERIA S.A.'  AS nombre_comercio,
      'ADAMO TELECOM IBERIA S.A.'  AS razon_social, 
      'A65232357'                  AS cif,
      'PEN'                        AS zona_fiscal,
      'ADAMO'                      AS marca,
      def_base.service_type        AS service_type,
      CAST(def_base.phone_nm       AS STRING)           AS phone_nm,
      def_base.bono_id             AS tariff_id,
      def_base.bono_name           AS tariff_ds,
      def_base.service_id          AS service_id,
      def_base.account_id          AS account_id,
      def_base.cliente             AS customer_id,
      def_base.line_type_ds        AS line_type_ds,
      CAST(NULL AS STRING)         AS bundle_type,
      def_base.technology_ds       AS technology_ds,
      def_base.billing_type_ds     AS billing_type_ds,
      CAST(NULL AS DATE)           AS sale_date,
      def_base.activation_date     AS activation_date,
      def_base.deactivation_date   AS deactivation_date,
      CAST(NULL AS STRING)         AS order_id,
      --CAST(def_base.order_id AS STRING)           AS order_id,
      CAST(NULL AS STRING)         AS order_type_agg,
      --def_base.order_type_agg     AS order_type_agg,
      '42'                         AS cod_segmento,
      '09'                         AS cod_marca,
      -- CASE
      --   WHEN billing_type_ds = 'PREPAID' THEN '10'
      --   WHEN def_base.service_type in ('INTERNET', 'FIX') AND def_base.TIPO_PAQUETE = 'FMC' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '60' 
      --       ELSE '61' END
      --     )
      --   WHEN def_base.service_type in ('INTERNET', 'FIX') THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '62'
      --       ELSE '63' END
      --     )
      --   WHEN def_base.service_type = 'MOBILE' AND def_base.TIPO_PAQUETE = 'FMC' AND line_type_ds = 'MAIN' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '60' 
      --       ELSE '61' END
      --     )
      --   WHEN def_base.service_type = 'MOBILE' AND def_base.TIPO_PAQUETE = 'FMC' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '66' 
      --       ELSE '67' END
      --     )
      --   WHEN def_base.service_type = 'MOBILE' AND def_base.TIPO_PAQUETE = 'MO' AND line_type_ds in ('ADDITIONAL', 'EXTRA') AND brand_ds = 'YOIGO' THEN '68'
      --   WHEN def_base.service_type = 'MOBILE' THEN '20'
      --   ELSE '99' 
      -- END                     AS cod_tipo_contrato,
      CAST(NULL AS STRING)    AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      -- CASE 
      --   WHEN def_base.service_type IN ('INTERNET', 'FIX') THEN '039'   
      --   WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
      --   ELSE '039'   
      -- END                     AS cod_producto,
      CAST(NULL AS STRING)     AS cod_producto,
      CAST(def_base.imp_without_tax AS STRING) AS claim_code,
      CAST(NULL AS STRING)     AS campaign_code,
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
    FROM def_base
  ),

  b_act AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(NULL AS INT64) as id_mes, 
      'B2B' AS agrupacion_canal,
      'ADA' AS canal,
      'D - Incentivo adicional Ádamo 2022 – 2024' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
      CASE
        WHEN imp_without_tax < 14  THEN 10
        WHEN imp_without_tax >= 14 THEN 15
        ELSE 0
      END AS comision,
      def_base_act.CLIENTE         AS id_comisionista,
      def_base_act.CLIENTE         AS distribuidor,
      def_base_act.CLIENTE         AS sfid_id,
      def_base_act.CLIENTE         AS seller, --es null def_base_act.sfid_id
      'ADAMO TELECOM IBERIA S.A.'  AS nombre_comercio,
      'ADAMO TELECOM IBERIA S.A.'  AS razon_social, 
      'A65232357'                  AS cif,
      'PEN'                        AS zona_fiscal,
      'ADAMO'                      AS marca,
      def_base_act.service_type        AS service_type,
      CAST(def_base_act.phone_nm AS STRING)           AS phone_nm,
      def_base_act.bono_id            AS tariff_id,
      def_base_act.bono_name          AS tariff_ds,
      def_base_act.service_id         AS service_id,
      def_base_act.account_id         AS account_id,
      def_base_act.cliente            AS customer_id,
      def_base_act.line_type_ds       AS line_type_ds,
      CAST(NULL AS STRING)            AS bundle_type,
      def_base_act.technology_ds      AS technology_ds,
      def_base_act.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)              AS sale_date,
      def_base_act.activation_date    AS activation_date,
      def_base_act.deactivation_date  AS deactivation_date,
      CAST(NULL AS STRING)            AS order_id,
      --CAST(def_base_act.order_id AS STRING)           AS order_id,
      CAST(NULL AS STRING)            AS order_type_agg,
      --def_base_act.order_type_agg     AS order_type_agg,
      '42'                            AS cod_segmento,
      '09'                            AS cod_marca,
      -- CASE
      --   WHEN billing_type_ds = 'PREPAID' THEN '10'
      --   WHEN def_base_act.service_type in ('INTERNET', 'FIX') AND def_base_act.TIPO_PAQUETE = 'FMC' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '60' 
      --       ELSE '61' END
      --     )
      --   WHEN def_base_act.service_type in ('INTERNET', 'FIX') THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '62'
      --       ELSE '63' END
      --     )
      --   WHEN def_base_act.service_type = 'MOBILE' AND def_base_act.TIPO_PAQUETE = 'FMC' AND line_type_ds = 'MAIN' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '60' 
      --       ELSE '61' END
      --     )
      --   WHEN def_base_act.service_type = 'MOBILE' AND def_base_act.TIPO_PAQUETE = 'FMC' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '66' 
      --       ELSE '67' END
      --     )
      --   WHEN def_base_act.service_type = 'MOBILE' AND def_base_act.TIPO_PAQUETE = 'MO' AND line_type_ds in ('ADDITIONAL', 'EXTRA') AND brand_ds = 'YOIGO' THEN '68'
      --   WHEN def_base_act.service_type = 'MOBILE' THEN '20'
      --   ELSE '99' 
      -- END                     AS cod_tipo_contrato,
      CAST(NULL AS STRING)    AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      -- CASE 
      --   WHEN def_base_act.service_type IN ('INTERNET', 'FIX') THEN '039'   
      --   WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
      --   ELSE '039'   
      -- END                     AS cod_producto,
      CAST(NULL AS STRING)     AS cod_producto,
      CAST(def_base_act.imp_without_tax AS STRING)    AS claim_code,
      CAST(NULL AS STRING)     AS campaign_code,
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
    FROM def_base_act
  ),
  
  b_clawback AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(NULL AS INT64) as id_mes, 
      'B2B' AS agrupacion_canal,
      'ADA' AS canal,
      'D - Incentivo adicional Ádamo 2022 – 2024 abril 2023’' AS concepto,
      'AIRT' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
      CASE
        WHEN pvp_sin_iva >= 14 THEN -15
        WHEN pvp_sin_iva < 14  THEN -10
        ELSE 0
      END AS comision,
      bono_deact.CLIENTE           AS id_comisionista,
      bono_deact.CLIENTE           AS distribuidor,
      bono_deact.CLIENTE           AS sfid_id,
      bono_deact.CLIENTE           AS seller, --es null bono_deact.sfid_id
      'ADAMO TELECOM IBERIA S.A.'  AS nombre_comercio,
      'ADAMO TELECOM IBERIA S.A.'  AS razon_social, 
      'A65232357'                  AS cif,
      'PEN'                        AS zona_fiscal,
      'ADAMO'                      AS marca,
      bono_deact.service_type      AS service_type,
      CAST(bono_deact.phone_nm AS STRING)           AS phone_nm,
      bono_deact.tariff_id          AS tariff_id,
      bono_deact.tariff_ds          AS tariff_ds,
      bono_deact.service_id         AS service_id,
      bono_deact.account_id         AS account_id,
      bono_deact.customer_id        AS customer_id,
      bono_deact.line_type_ds       AS line_type_ds,
      CAST(NULL AS STRING)          AS bundle_type,
      bono_deact.technology_ds      AS technology_ds,
      bono_deact.billing_type_ds    AS billing_type_ds,
      CAST(NULL AS DATE)            AS sale_date,
      bono_deact.activation_date    AS activation_date,
      bono_deact.deactivation_date  AS deactivation_date,
      CAST(NULL AS STRING) AS order_id,
      --CAST(bono_deact.order_id AS STRING)           AS order_id,
      CAST(NULL AS STRING) AS order_type_agg,
      --bono_deact.order_type_agg     AS order_type_agg,
      '42'                          AS cod_segmento,
      '09'                          AS cod_marca,
      -- CASE
      --   WHEN billing_type_ds = 'PREPAID' THEN '10'
      --   WHEN bono_deact.service_type in ('INTERNET', 'FIX') AND bono_deact.TIPO_PAQUETE = 'FMC' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '60' 
      --       ELSE '61' END
      --     )
      --   WHEN bono_deact.service_type in ('INTERNET', 'FIX') THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '62'
      --       ELSE '63' END
      
      --     )
      --   WHEN bono_deact.service_type = 'MOBILE' AND bono_deact.TIPO_PAQUETE = 'FMC' AND line_type_ds = 'MAIN' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '60' 
      --       ELSE '61' END
      --     )
      --   WHEN bono_deact.service_type = 'MOBILE' AND bono_deact.TIPO_PAQUETE = 'FMC' THEN (
      --     CASE 
      --       WHEN technology_ds = 'ADSL' THEN '66' 
      --       ELSE '67' END
      --     )
      --   WHEN bono_deact.service_type = 'MOBILE' AND bono_deact.TIPO_PAQUETE = 'MO' AND line_type_ds in ('ADDITIONAL', 'EXTRA') AND brand_ds = 'YOIGO' THEN '68'
      --   WHEN bono_deact.service_type = 'MOBILE' THEN '20'
      --   ELSE '99' 
      -- END                     AS cod_tipo_contrato,
      CAST(NULL AS STRING) AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      -- CASE 
      --   WHEN bono_deact.service_type IN ('INTERNET', 'FIX') THEN '039'   
      --   WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
      --   ELSE '039'   
      -- END                     AS cod_producto,
      CAST(NULL AS STRING)     AS cod_producto,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS campaign_code,
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
    FROM bono_deact
  ),

  acum_final AS (
    SELECT
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CASE
        WHEN SUM(COMISION) < SUM(imp_without_tax)*0.45 THEN 1
        ELSE 0
      END AS tipo_fact,
      CASE
        WHEN SUM(COMISION) < SUM(imp_without_tax)*0.45 THEN SUM(imp_without_tax)*0.45 - SUM(COMISION)
        ELSE 0  
        END AS acumulado_fin_ano,
      SUM(imp_without_tax)*0.02 AS acumulado_JUN_JUN
    FROM b
  ),

  acumulado_fin_ano AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(NULL AS INT64) as id_mes, 
      'B2B' AS agrupacion_canal,
      'ADA' AS canal,
      'D - Acumulado hasta Fin de Año' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
      acumulado_fin_ano   AS  comision,
      '216517'           AS id_comisionista,
      '216517'           AS distribuidor,
      '216517'           AS sfid_id,
      '216517'           AS seller, --es null bono_deact.sfid_id
      'ADAMO TELECOM IBERIA S.A. Incentivos Anual'   AS nombre_comercio,
      'ADAMO TELECOM IBERIA S.A. Incentivos Anual'   AS razon_social, 
      'A65232357'                    AS cif,
      'PEN'                          AS zona_fiscal,
      'ADAMO'                        AS marca,
      CAST(NULL AS STRING)           AS service_type,
      CAST(NULL AS STRING)           AS phone_nm,
      CAST(NULL AS STRING)           AS tariff_id,
      CAST(NULL AS STRING)           AS tariff_ds,
      CAST(NULL AS STRING)           AS service_id,
      CAST(NULL AS STRING)           AS account_id,
      CAST(NULL AS STRING)           AS customer_id,
      CAST(NULL AS STRING)           AS line_type_ds,
      CAST(NULL AS STRING)           AS bundle_type,
      CAST(NULL AS STRING)           AS technology_ds,
      CAST(NULL AS STRING)           AS billing_type_ds,
      CAST(NULL AS DATE)             AS sale_date,
      CAST(NULL AS DATE)             AS activation_date,
      CAST(NULL AS DATE)             AS deactivation_date,
      CAST(NULL AS STRING)           AS order_id,
      CAST(NULL AS STRING)           AS order_type_agg,
      '42'                           AS cod_segmento,
      '09'                           AS cod_marca,
      CAST(NULL AS STRING)           AS cod_tipo_contrato,
      '30'                           AS cod_canal,
      CAST(NULL AS STRING)           AS cod_producto,
      CAST(NULL AS STRING)           AS claim_code,
      CAST(NULL AS STRING)           AS campaign_code,
      CAST(NULL AS STRING)           AS process_code,
      CAST(NULL AS STRING)           AS comments,
      'C_MANUAL'                     AS facturador,
      CAST(NULL AS STRING)           AS proceso_sap,
      CAST(NULL AS STRING)           AS id_registro,
      CAST(NULL AS STRING)           AS invoice_id,
      'X001'                         AS sociedad,
      CAST(NULL AS STRING)           AS bp,
      CAST(NULL AS STRING)           AS cuenta_contable,
      CAST(NULL AS STRING)           AS centro_coste,
      CAST(NULL AS STRING)           AS documento_sap,
      CAST(NULL AS STRING)           AS documento_sap_posicion,
      CAST(NULL AS STRING)           AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)        AS creado,
      CAST(NULL AS TIMESTAMP)        AS modificado,
      CAST(NULL AS STRING)           AS id_factura_drive,
      CAST(NULL AS STRING)           AS emails_acceso_trazabilidad
    FROM acum_final
  ),

  acumulado_jun_jun AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(NULL AS INT64) as id_mes, 
      'B2B' AS agrupacion_canal,
      'ADA' AS canal,
      'D - Acumulado (2%)' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
      acumulado_JUN_JUN AS  comision,
      '216517'           AS id_comisionista,
      '216517'           AS distribuidor,
      '216517'           AS sfid_id,
      '216517'           AS seller, --es null bono_deact.sfid_id
      'ADAMO TELECOM IBERIA S.A. Incentivos Anual'   AS nombre_comercio,
      'ADAMO TELECOM IBERIA S.A. Incentivos Anual'   AS razon_social, 
      'A65232357'                    AS cif,
      'PEN'                          AS zona_fiscal,
      'ADAMO'                        AS marca,
      CAST(NULL AS STRING)           AS service_type,
      CAST(NULL AS STRING)           AS phone_nm,
      CAST(NULL AS STRING)           AS tariff_id,
      CAST(NULL AS STRING)           AS tariff_ds,
      CAST(NULL AS STRING)           AS service_id,
      CAST(NULL AS STRING)           AS account_id,
      CAST(NULL AS STRING)           AS customer_id,
      CAST(NULL AS STRING)           AS line_type_ds,
      CAST(NULL AS STRING)           AS bundle_type,
      CAST(NULL AS STRING)           AS technology_ds,
      CAST(NULL AS STRING)           AS billing_type_ds,
      CAST(NULL AS DATE)             AS sale_date,
      CAST(NULL AS DATE)             AS activation_date,
      CAST(NULL AS DATE)             AS deactivation_date,
      CAST(NULL AS STRING)           AS order_id,
      CAST(NULL AS STRING)           AS order_type_agg,
      '42'                           AS cod_segmento,
      '09'                           AS cod_marca,
      CAST(NULL AS STRING)           AS cod_tipo_contrato,
      '30'                           AS cod_canal,
      CAST(NULL AS STRING)           AS cod_producto,
      CAST(NULL AS STRING)           AS claim_code,
      CAST(NULL AS STRING)           AS campaign_code,
      CAST(NULL AS STRING)           AS process_code,
      CAST(NULL AS STRING)           AS comments,
      'C_MANUAL'                     AS facturador,
      CAST(NULL AS STRING)           AS proceso_sap,
      CAST(NULL AS STRING)           AS id_registro,
      CAST(NULL AS STRING)           AS invoice_id,
      'X001'                         AS sociedad,
      CAST(NULL AS STRING)           AS bp,
      CAST(NULL AS STRING)           AS cuenta_contable,
      CAST(NULL AS STRING)           AS centro_coste,
      CAST(NULL AS STRING)           AS documento_sap,
      CAST(NULL AS STRING)           AS documento_sap_posicion,
      CAST(NULL AS STRING)           AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)        AS creado,
      CAST(NULL AS TIMESTAMP)        AS modificado,
      CAST(NULL AS STRING)           AS id_factura_drive,
      CAST(NULL AS STRING)           AS emails_acceso_trazabilidad
    FROM acum_final
  ),

  cuota_mantenimiento_linea AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(NULL AS INT64) as id_mes, 
      'B2B' AS agrupacion_canal,
      'ADA' AS canal,
      'D - Cuota Mantenimiento Linea' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
      COUNT(*)*0.5 AS  comision,
      '216517'           AS id_comisionista,
      '216517'           AS distribuidor,
      '216517'           AS sfid_id,
      '216517'           AS seller, --es null bono_deact.sfid_id
      'ADAMO TELECOM IBERIA S.A. Incentivos Anual'   AS nombre_comercio,
      'ADAMO TELECOM IBERIA S.A. Incentivos Anual'   AS razon_social, 
      'A65232357'                    AS cif,
      'PEN'                          AS zona_fiscal,
      'ADAMO'                        AS marca,
      CAST(NULL AS STRING)           AS service_type,
      CAST(NULL AS STRING)           AS phone_nm,
      CAST(NULL AS STRING)           AS tariff_id,
      CAST(NULL AS STRING)           AS tariff_ds,
      CAST(NULL AS STRING)           AS service_id,
      CAST(NULL AS STRING)           AS account_id,
      CAST(NULL AS STRING)           AS customer_id,
      CAST(NULL AS STRING)           AS line_type_ds,
      CAST(NULL AS STRING)           AS bundle_type,
      CAST(NULL AS STRING)           AS technology_ds,
      CAST(NULL AS STRING)           AS billing_type_ds,
      CAST(NULL AS DATE)             AS sale_date,
      CAST(NULL AS DATE)             AS activation_date,
      CAST(NULL AS DATE)             AS deactivation_date,
      CAST(NULL AS STRING)           AS order_id,
      CAST(NULL AS STRING)           AS order_type_agg,
      '42'                           AS cod_segmento,
      '09'                           AS cod_marca,
      CAST(NULL AS STRING)           AS cod_tipo_contrato,
      '30'                           AS cod_canal,
      CAST(NULL AS STRING)           AS cod_producto,
      CAST(NULL AS STRING)           AS claim_code,
      CAST(NULL AS STRING)           AS campaign_code,
      CAST(NULL AS STRING)           AS process_code,
      CAST(NULL AS STRING)           AS comments,
      'C_MANUAL'                     AS facturador,
      CAST(NULL AS STRING)           AS proceso_sap,
      CAST(NULL AS STRING)           AS id_registro,
      CAST(NULL AS STRING)           AS invoice_id,
      'X001'                         AS sociedad,
      CAST(NULL AS STRING)           AS bp,
      CAST(NULL AS STRING)           AS cuenta_contable,
      CAST(NULL AS STRING)           AS centro_coste,
      CAST(NULL AS STRING)           AS documento_sap,
      CAST(NULL AS STRING)           AS documento_sap_posicion,
      CAST(NULL AS STRING)           AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)        AS creado,
      CAST(NULL AS TIMESTAMP)        AS modificado,
      CAST(NULL AS STRING)           AS id_factura_drive,
      CAST(NULL AS STRING)           AS emails_acceso_trazabilidad
    FROM  `mm-datamart-kd.BILLING.billing_detail_net`
    WHERE customer_id = '216517' AND UPPER(billing_tier_2) LIKE '%MANTENIMIENTO%' AND data_month_id = 202309

  ),

  final AS (
    SELECT DISTINCT
      estado,
      b.mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      CASE
        WHEN acum_final.tipo_fact = 0 THEN 'C - Gestion Cartera Movil (45%)'
        ELSE concepto
      END AS concepto,
      tipo_concepto,
      COUNT(service_id)      AS unidades,
      CASE
        WHEN acum_final.tipo_fact = 0 THEN SUM(ROUND(imp_without_tax*0.45,3))
        ELSE SUM(ROUND(comision,3))
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
      claim_code,
      campaign_code,
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
    LEFT JOIN acum_final ON b.mes_liquidado = acum_final.mes_liquidado
    GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,acum_final.tipo_fact

    UNION ALL
    

    SELECT DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      COUNT(service_id)      AS unidades,
      SUM(ROUND(comision,3)) AS comision,
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
      claim_code,
      campaign_code,
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
    FROM b_act
    WHERE comision IS NOT NULL AND comision != 0
    GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58

  --   UNION ALL

  --   SELECT DISTINCT
  --     estado,
  --     mes_liquidado,
  --     id_mes,
  --     agrupacion_canal,
  --     canal,
  --     concepto,
  --     tipo_concepto,
  --     COUNT(service_id)      AS unidades,
  --     SUM(ROUND(comision,3)) AS comision,
  --     id_comisionista,
  --     distribuidor,
  --     sfid_id,
  --     seller,
  --     nombre_comercio,
  --     razon_social,
  --     cif,
  --     zona_fiscal,
  --     marca,
  --     service_type,
  --     phone_nm,
  --     tariff_id,
  --     tariff_ds,
  --     service_id,
  --     account_id,
  --     customer_id,
  --     line_type_ds,
  --     bundle_type,
  --     technology_ds,
  --     billing_type_ds,
  --     sale_date,
  --     activation_date,
  --     deactivation_date,
  --     order_id,
  --     order_type_agg,
  --     cod_segmento,
  --     cod_marca,
  --     cod_tipo_contrato,
  --     cod_producto,
  --     cod_canal,
  --     claim_code,
  --     campaign_code,
  --     process_code,
  --     comments,
  --     facturador,
  --     proceso_sap,
  --     id_registro,
  --     invoice_id,
  --     sociedad,
  --     bp,
  --     cuenta_contable,
  --     centro_coste,
  --     documento_sap,
  --     documento_sap_posicion,
  --     fecha_contabilizacion,
  --     creado,
  --     modificado,
  --     id_factura_drive,
  --     emails_acceso_trazabilidad
  --   FROM b_clawback
  --   WHERE comision IS NOT NULL AND comision != 0
  --   GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58

    UNION ALL

    SELECT DISTINCT
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        COUNT(service_id)      AS unidades,
        SUM(ROUND(comision,3)) AS comision,
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
        claim_code,
        campaign_code,
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
      FROM acumulado_fin_ano
      GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58

      UNION ALL

    SELECT DISTINCT
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        COUNT(service_id)      AS unidades,
        SUM(ROUND(comision,3)) AS comision,
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
        claim_code,
        campaign_code,
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
      FROM acumulado_jun_jun
      GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58

      UNION ALL

    SELECT DISTINCT
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        COUNT(service_id)      AS unidades,
        SUM(ROUND(comision,3)) AS comision,
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
        claim_code,
        campaign_code,
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
      FROM cuota_mantenimiento_linea
      GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58
  )

  SELECT 
  prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
  *
  FROM final
  WHERE comision != 0;

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arda',
  'ACTUALIZAR'
);

END