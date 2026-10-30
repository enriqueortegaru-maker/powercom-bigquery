BEGIN

DECLARE clave STRING;

SET clave = 'ARAL';

-- DECLARE mes_pr DATE DEFAULT '2022-11-01';

CREATE OR REPLACE TABLE `mm-commissions-reporting.CABLEOPERADORES.comisiones_working_aral` AS 

-- DECLARE mes_pr DATE DEFAULT '2022-11-01';

  WITH svc AS( --esto para upfront

    SELECT DISTINCT
      tariff_ds,
      IF(service_type = 'FIX', IF(activation_tariff_ds LIKE '%+%', '3P', '2P'),service_type) AS bundle_type,
      COUNT(DISTINCT phone_nm) AS cant_clientes,
      20*COUNT(DISTINCT phone_nm) AS comision_upfront
    FROM `mm-datamart-kd.SERVICES.service_base_net` s
    WHERE true
      AND activation_date >= '2023-01-01'  
      AND activation_date <= '2023-01-31'  
      AND comm_brand_ds = 'ALTERNA' 
      AND kpi_gross_add = 1
    GROUP BY 1,2
    ORDER BY 1

  ),
  
  base AS ( --esto para cartera

    SELECT DISTINCT 
      a.*, 
      b.first_territory_ds, 
      IF(c.sell_bundle_type IS NULL, 'DESC', c.sell_bundle_type) AS TIPO_PAQUETE, 
      'Alterna' AS CLIENTE,
      c.sell_tariff_ds, 
      c.sell_tariff_id, 
      c.order_type_agg,
      c.technology_ds,
      c.line_type_ds,
      IF(c.segment_ds = 'BUSINESS','Negocios', c.segment_ds) AS segment_ds
    FROM `mm-datamart-kd.BILLING.billing_detail_net` a 
    LEFT JOIN `mm-datamart-kd.SERVICES.service_base_net` b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm
    LEFT JOIN (
      SELECT DISTINCT service_id, phone_nm, account_id, customer_id, sell_bundle_type, sell_tariff_ds,sell_tariff_id, activation_date, deactivation_date, segment_ds,order_type_agg, technology_ds, line_type_ds
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` WHERE comm_brand_ds = 'ALTERNA'
     ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND a.init_date >= c.activation_date AND a.end_date <= c.deactivation_date --AND a.service_id = c.service_id
    WHERE a.comm_brand_ds = 'ALTERNA' AND a.invoice_date = '2023-02-01' AND (CONCAT(a.service_type,sell_bundle_type) != 'MOBILEFMC' OR CONCAT(a.service_type,sell_bundle_type) IS NULL)
    
  ),

  col AS (
    SELECT DISTINCT Tipo_Paquete, Cuota, Cuota_BST, b.sell_tariff_id
    FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_alterna` a
    LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` b ON a.Tipo_Paquete = b.sell_tariff_ds
  ),

  b AS(
    SELECT DISTINCT
      -- base.service_id,
      -- base.phone_nm,
      'X001' AS sociedad,
      base.CLIENTE AS id_comisionista,
      'DEA' AS tipo_comisionista,
      b2b_xena.document_number AS CIF,
      CASE 
        WHEN UPPER(b2b_xena.provincia) LIKE '%TENERIFE%' THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%PALMAS%'   THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CANARIA%'  THEN 'CAN'
        WHEN UPPER(b2b_xena.provincia) LIKE '%CEUTA%'    THEN 'CEU'
        WHEN UPPER(b2b_xena.provincia) LIKE '%MELILLA%'  THEN 'MEL'
        ELSE 'PEN'
      END AS zona_fiscal,
      'AIRT' AS tipo_concepto,
      CASE 
        WHEN base.TIPO_PAQUETE = 'MO'  THEN CONCAT('C - Gestion Cartera Movil ','(',IF(sell_tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota)),'%)')
        WHEN base.TIPO_PAQUETE = 'FMC' THEN CONCAT('C - Gestion Cartera 3P ','(',IF(sell_tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota)),'%)')
        WHEN base.TIPO_PAQUETE = '2P'  THEN CONCAT('C - Gestion Cartera 2P ','(',IF(sell_tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota)),'%)')
        ELSE 'OTROS'
      END   AS descripcion_concepto,
      NULL  AS uds,
      -- base.TIPO_PAQUETE,
      -- IF(billing_tier_1 LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota)) AS porcentaje,
      /*base.imp_without_tax AS base_imponible,
      IF(sell_tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota))  AS porcentaje_comision,*/
      base.imp_without_tax*(IF(sell_tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota))/100)  AS importe_base,
      'EUR'   AS moneda,
      'C'     AS via_pago,
      'Z001'  AS cond_pago,
      '30'    AS cod_canal,
      CASE 
        WHEN service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END AS cod_producto,
      -- CASE
      --   WHEN base.tariff_id = '' OR base.tariff_id IS NULL THEN base.bono_id 
      --   WHEN base.tariff_id != '' OR base.tariff_id IS NOT NULL THEN base.tariff_id 
      --   ELSE NULL
      -- END AS Product_id,
      -- CASE
      --   WHEN (base.bono_id = '' AND base.tariff_id != '') OR (base.bono_id IS NULL AND base.tariff_id IS NOT NULL) THEN UPPER(base.tariff_ds) 
      --   WHEN (base.bono_id != '' AND base.tariff_id = '') OR (base.bono_id IS NOT NULL AND base.tariff_id IS NULL) THEN UPPER(base.bono_name) 
      --   ELSE upper(base.tariff_ds)
      -- END AS Product,
      -- base.imp_without_tax AS Importe_bruto,
      -- CASE 
      --   WHEN base.service_type = 'FIX' THEN '61' 
      --   WHEN base.service_type LIKE 'MOBILE%' THEN '20' 
      -- END AS cod_tipo_contrato,
      -- CAST(NULL AS STRING)  AS cod_tipo_contrato,
      CASE
        WHEN billing_type_ds = 'PREPAID' THEN '10'
        WHEN service_type in ('INTERNET', 'FIX') AND base.TIPO_PAQUETE = 'FMC' THEN (
          CASE 
            WHEN technology_ds = 'ADSL' THEN '60' 
            ELSE '61' END
          )
        WHEN service_type in ('INTERNET', 'FIX') THEN (
          CASE 
            WHEN technology_ds = 'ADSL' THEN '62'
            ELSE '63' END
          )
        WHEN service_type = 'MOBILE' AND base.TIPO_PAQUETE = 'FMC' AND line_type_ds = 'MAIN' THEN (
          CASE 
            WHEN technology_ds = 'ADSL' THEN '60' 
            ELSE '61' END
          )
        WHEN service_type = 'MOBILE' AND base.TIPO_PAQUETE = 'FMC' THEN (
          CASE 
            WHEN technology_ds = 'ADSL' THEN '66' 
            ELSE '67' END
          )
        WHEN service_type = 'MOBILE' AND base.TIPO_PAQUETE = 'MO' AND line_type_ds in ('ADDITIONAL', 'EXTRA') AND brand_ds = 'YOIGO' THEN '68'
        WHEN service_type = 'MOBILE' THEN '20'
        ELSE '99' 
      END                   AS cod_tipo_contrato,
      '09'                  AS cod_marca,
      '999'                  AS cod_operador,
      '42'                  AS cod_segmento,
      'C_MANUAL'            AS facturador,
      'C - Calidad'         AS clasificacion_concepto,
      'CABLEOPERADORES'     AS canal,
      CAST(NULL AS STRING)  AS subscription_id,
      base.service_type     AS product_type,
      base.TIPO_PAQUETE     AS bundle_type,
      CAST(NULL AS STRING)  AS msisdn,
      CAST(NULL AS DATE)    AS fecha_activacion,
      CAST(NULL AS DATE)    AS fecha_baja,
      CAST(NULL AS STRING)  AS account_id,
      base.CLIENTE          AS customer_id,
      base.CLIENTE          AS sfid_unico,
      base.CLIENTE          AS tienda,
      base.CLIENTE          AS distribuidor,
      mes_pr                AS fecha,
      base.TIPO_PAQUETE     AS agrupacion_cod_tipo_contrato,
      base.segment_ds       AS segmento,
      CAST(NULL AS STRING)  AS razon_social, 
      b2b_xena.cuenta_cliente AS nombre_comercio,
      'ALTERNA' AS MARCA,
      CAST(NULL AS STRING)  AS order_id,
      base.sell_tariff_id   AS Product_id,
      base.sell_tariff_ds   AS Product,
      CAST(NULL AS STRING)  AS user_id,
      base.phone_nm,
      -- IF(sell_tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO', 25, IF(first_territory_ds LIKE 'BST%', Cuota_BST, Cuota)) AS porcentaje,
    FROM base
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-b2b-reporting.MAESTROS.Maestro_B2B`
      ) b2b_xena ON base.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN col ON col.sell_tariff_id = base.sell_tariff_id --OR col.Tipo_Paquete = base.sell_tariff_ds OR col.Tipo_Paquete = base.billing_tier_1
    -- GROUP BY 1,2,3,4,5,6,7,8,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45
    ORDER BY product_id ASC

  ), 

  final AS (

    SELECT DISTINCT
      sociedad,
      id_comisionista,
      tipo_comisionista,
      b.CIF,
      zona_fiscal,
      tipo_concepto,
      descripcion_concepto,
      COUNT(DISTINCT phone_nm) AS uds,
      /*SUM(ROUND(base_imponible,2))      AS base_imponible,
      porcentaje_comision,*/
      SUM(ROUND(importe_base,2))        AS importe_base,
      moneda,
      via_pago,
      cond_pago,
      cod_canal,
      cod_producto,
      cod_tipo_contrato,
      cod_marca,
      cod_operador,
      cod_segmento,
      facturador,
      clasificacion_concepto,
      canal,
      subscription_id,
      product_type,
      bundle_type,
      msisdn,
      fecha_activacion,
      fecha_baja,
      account_id,
      customer_id,
      sfid_unico,
      tienda,
      distribuidor,
      fecha,
      agrupacion_cod_tipo_contrato,
      segmento,
      razon_social,
      nombre_comercio,
      marca,
      order_id,
      Product_id,
      Product,
      -- user_id
      -- IF(autofactura.CIF IS NOT NULL, 'SI', 'NO') AS autofactura
    FROM b WHERE importe_base IS NOT NULL
    -- LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.maestro_autofactura` autofactura
    --   ON autofactura.CIF = b.CIF
  GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41
  

  )

  SELECT 
    'ARAL_CABL_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
    -- CONCAT('JOICOM','202211-',ROUND(0001 + RAND() * (9999 - 0001))) AS id_registro,
    *,
    CAST(NULL AS STRING) AS user_id,
    CAST(NULL AS STRING) AS campaign_code,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments
  FROM final 
;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'CABLEOPERADORES.comisiones_working_aral',
  'CABLEOPERADORES.comisiones_working'
);

END