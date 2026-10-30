BEGIN

  DECLARE sql, prefijo, mes_string STRING;
  DECLARE fecha_inicio DATE;
  DECLARE fecha_fin DATE;
  DECLARE fecha_inicio_mes_siguiente DATE;

  SET mes_string = CAST(mes_int AS STRING);
  SET prefijo = 'CPAD4';
  SET canales_pr = ['HICLI'];


  -- Fechas dinámicas
  SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
  SET fecha_fin = DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 DAY);
  SET fecha_inicio_mes_siguiente = DATE_ADD(fecha_inicio, INTERVAL 1 MONTH);

-- call `mm-commissions-reporting.COMISIONES.pr_hits_cartera`(202609,['HICLI']);



-- AGOSTO


-- ---PASO 1

-- CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.bi_customer_hits` AS
-- SELECT * FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_customer_*` a
-- WHERE 1=1
--   AND a.no IS NOT NULL
--   AND a.empresa = '900- HITSMOBILE'
--   ;


-- -- MULTIHOUSE (Delegacion nula)

-- UPDATE `mm-commissions-reporting.TEMP.bi_customer_hits` a
-- SET delegacion = '562428'
-- WHERE a.no = 'CL900-031589'
-- ;
 
CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.hits_idcomisionista_202609`
 AS (
  SELECT a.empresa, b.ID_COMISIONISTA,a.no AS cliente
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_customer_*` a
  LEFT JOIN `mm-commissions-reporting.GS.DELEGACION_NNS` b
  ON a.empresa = b.empresa AND COALESCE(a.delegacion,a.no) = COALESCE(b.ID_DELEGACION,b.ID_COMISIONISTA) 
  WHERE 1=1
  AND ID_COMISIONISTA IS NOT NULL
  AND a.empresa = '900- HITSMOBILE'
  QUALIFY ROW_NUMBER () OVER (PARTITION BY  a.no ORDER BY last_date_mod DESC) = 1

)
;
 

 
--paso 2 comisionar cartera fijo, alarmas y TV
 CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.hits_base_fijo_cartera_202609` as (
  
   SELECT 
    a.empresa, 
    a.num_contrato as contrato1, 
    a.num_linea_contrato, 
    b.ID_COMISIONISTA AS ID_COMISIONISTA,   
    a.no as producto, 
    item.Level_0, item.level_3,
      CASE
        WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 LIKE '%IND%' THEN SUM(a.amount)
        WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN SUM(a.amount)
        ELSE SUM(a.amount) 
      END AS TAX_BASE ,
        CASE
        -- GTI
        WHEN  item.Level_0 = 'INTERNET MINORISTA' AND b.id_comisionista = 'CL900-010938' AND item.level_3 LIKE '%IND%' THEN 8 
        WHEN  item.Level_0 = 'INTERNET MINORISTA' AND b.id_comisionista = 'CL900-010938' AND item.level_3 NOT LIKE '%IND%' THEN 10 
        -- SIN CUOTAS
        WHEN  item.Level_0 = 'INTERNET MINORISTA' AND b.id_comisionista = 'CL900-000170' THEN 15
        -- TV 
        WHEN item.Level_0 = 'TELEVISIÓN' AND b.id_comisionista = 'CL900-004836' THEN 15
        -- RESTO
        ELSE importe.cartera
      END AS por_COMISION,
      item.* except (Level_0, level_3)

    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    LEFT JOIN `mm-commissions-reporting.GS.B2B_HITS_COMISIONES` importe
    ON b.ID_COMISIONISTA = importe.id_comisonista
    WHERE 1 = 1
       --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND (
        (item.level_0 = 'INTERNET MINORISTA' 
          AND item.level_1='CUOTA MENSUAL RESIDENCIAL' 
          AND item.level_2='INTERNET FIBRA CM')
      OR (item.level_0 = 'TELEVISIÓN' AND b.id_comisionista = 'CL900-004836'))
      --AND a.bill_to_customer_no in ('CL001-012853')  --, 'CL001-012853') -- BLAUFIBRA Y LIFE

    GROUP BY ALL
 );




 --paso 3 comisionr movil
 CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.hits_base_movil_cartera_202609` as (
  
    SELECT 
      a.empresa, 
      a.num_contrato as contrato1, 
      a.num_linea_contrato, 
      CASE WHEN a.sell_to_customer_no in ('CL001-012853','CL001-000011') THEN a.sell_to_customer_no 
      ELSE b.ID_COMISIONISTA END AS ID_COMISIONISTA,
      a.no as producto, 
      item.Level_0 , 
      item.level_3,
      CASE
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price >10 THEN SUM(a.amount)
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price <10 THEN SUM(a.amount)
        ELSE SUM(a.amount) END AS TAX_BASE ,
      CASE WHEN  item.Level_0 = 'TELEFONIA MÓVIL' AND b.id_comisionista = 'CL900-000170' THEN 15
      ELSE importe.cartera END AS por_COMISION,
      item.* EXCEPT(level_0, level_3)

    
    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    LEFT JOIN `mm-commissions-reporting.GS.B2B_HITS_COMISIONES` importe
    ON b.ID_COMISIONISTA = importe.id_comisonista

    WHERE 1 = 1
       --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND item.Level_0 ='TELEFONIA MÓVIL'
      AND item.level_1 IN ('PLANES Y TARIFAS','SOBRETARIFICACIÓN VOZ Y DATOS MÓVIL')
      AND item.level_3 not like '%Sobretarificaciones de SMS%'

      
    GROUP BY ALL
    );

    
  -- paso 4 bundle

  CREATE or replace TABLE  `mm-commissions-reporting.TEMP.hits_base_bundle_cartera_202609` as (

  SELECT 
    a.empresa, 
    a.num_contrato as contrato1, 
    a.num_linea_contrato, 
    CASE WHEN a.sell_to_customer_no in ('CL001-012853','CL001-000011') THEN a.sell_to_customer_no 
    ELSE b.ID_COMISIONISTA END AS ID_COMISIONISTA,
    a.no as producto, 
    item.Level_0 , 
    item.level_3, 
    CASE
      WHEN  item.Level_0='BUNDLE PAQUETE' AND item.unit_price >10 THEN SUM(a.amount)
      WHEN  item.Level_0='BUNDLE PAQUETE' AND item.unit_price <10 THEN SUM(a.amount)
      ELSE SUM(a.amount)
    END AS tax_base, 
    CASE
        -- GTI
        WHEN  item.Level_0 = 'BUNDLE PAQUETE' AND b.id_comisionista = 'CL900-010938' AND item.level_3 LIKE '%IND%' THEN 8 
        WHEN  item.Level_0 = 'BUNDLE PAQUETE' AND b.id_comisionista = 'CL900-010938' AND item.level_3 NOT LIKE '%IND%' THEN 10 
        -- SIN CUOTAS
        WHEN  item.Level_0 = 'BUNDLE PAQUETE' AND b.id_comisionista = 'CL900-000170' THEN 15
                -- RESTO
        ELSE importe.cartera
      END AS por_COMISION,
    -- CASE WHEN  item.Level_0='BUNDLE PAQUETE' THEN 20
    -- ELSE NULL
    -- END AS por_COMISION,
   
    item.* EXCEPT(level_0, level_3)

    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    LEFT JOIN `mm-commissions-reporting.GS.B2B_HITS_COMISIONES` importe
    ON b.ID_COMISIONISTA = importe.id_comisonista

    WHERE 1 = 1
      --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
    AND item.Level_0='BUNDLE PAQUETE'
    AND item.level_1 IN ('BUNDLE 2P')
    AND item.level_3  LIKE '%Promo FIBRA 500 12m CM0425%'
    --AND a.empresa = '01- central' and a.bill_to_customer_no in ('CL001-012853')--, 'CL001-012853') -- BLAUFIBRA Y LIFE

  GROUP BY ALL

  );



 -- paso 5 CM MASTER FIBRA

  CREATE or replace TABLE  `mm-commissions-reporting.TEMP.hits_base_master_fibra_cartera_202609` as (

    -- PIPOL CL900-000137
SELECT
  a.empresa,
  a.num_contrato AS contrato1,
  a.num_linea_contrato,
  'CL900-000137' AS ID_COMISIONISTA,
  a.no AS producto,
  item.level_0,
  item.level_3,
  CASE
      WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 LIKE '%IND%' THEN SUM(a.amount)
      WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN SUM(a.amount)
      ELSE SUM(a.amount) 
    END AS tax_base,
  10 AS por_COMISION,
  item.* EXCEPT(level_0, level_3)

 FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    WHERE 1 = 1
       --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND item.level_0 = 'INTERNET MINORISTA' 
      AND item.level_1='CUOTA MENSUAL RESIDENCIAL' 
      AND item.level_2='INTERNET FIBRA CM'
     
  AND b.ID_COMISIONISTA IN (
      'CL900-000137',
      'CL900-001169',
      'CL900-001225',
      'CL900-001226',
      'CL900-001038',
      'CL900-000262',
      'CL900-001039',
      'CL900-000645',
      'CL900-000549',
      'CL900-001037',
      'CL900-000263'
  )

GROUP BY ALL

UNION ALL

  -- SIPINPHONE SL - CL900-000288
SELECT
  a.empresa,
  a.num_contrato AS contrato1,
  a.num_linea_contrato,
  'CL900-000288' AS ID_COMISIONISTA,
  a.no AS producto,
  item.level_0,
  item.level_3,
  CASE
      WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 LIKE '%IND%' THEN SUM(a.amount)
      WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN SUM(a.amount)
      ELSE SUM(a.amount) 
    END AS tax_base,
  10 AS por_COMISION,
  item.* EXCEPT(level_0, level_3)

FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    WHERE 1 = 1
      --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND item.level_0 = 'INTERNET MINORISTA' 
      AND item.level_1='CUOTA MENSUAL RESIDENCIAL' 
      AND item.level_2='INTERNET FIBRA CM'
  AND b.ID_COMISIONISTA IN (
    'CL900-000288',
        'CL900-000277',
        'CL900-001093',
        'CL900-000294',
        'CL900-000120'

  )

GROUP BY ALL


  );


  -- paso 6 CM MASTER MOVIL

  CREATE or replace TABLE  `mm-commissions-reporting.TEMP.hits_base_master_movil_cartera_202609` as (

        -- PIPOL CL900-000137
    SELECT
      a.empresa,
      a.num_contrato AS contrato1,
      a.num_linea_contrato,
      'CL900-000137' AS ID_COMISIONISTA,
      a.no AS producto,
      item.level_0,
      item.level_3,
      CASE
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price >10 THEN SUM(a.amount)
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price <10 THEN SUM(a.amount)
        ELSE SUM(a.amount) 
      END AS TAX_BASE,
      10 AS por_COMISION,
      item.* EXCEPT(level_0, level_3)

   FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    WHERE 1 = 1
       --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND item.Level_0 ='TELEFONIA MÓVIL'
      AND item.level_1 IN ('PLANES Y TARIFAS','SOBRETARIFICACIÓN VOZ Y DATOS MÓVIL')
      AND item.level_3 not like '%Sobretarificaciones de SMS%'
      AND b.ID_COMISIONISTA IN (
      'CL900-000137',
      'CL900-001169',
      'CL900-001225',
      'CL900-001226',
      'CL900-001038',
      'CL900-000262',
      'CL900-001039',
      'CL900-000645',
      'CL900-000549',
      'CL900-001037',
      'CL900-000263'
      )

    GROUP BY ALL

    UNION ALL

      -- SIPINPHONE SL - CL900-000288
    SELECT
      a.empresa,
      a.num_contrato AS contrato1,
      a.num_linea_contrato,
      'CL900-000288' AS ID_COMISIONISTA,
      a.no AS producto,
      item.level_0,
      item.level_3,
     CASE
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price >10 THEN SUM(a.amount)
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price <10 THEN SUM(a.amount)
        ELSE SUM(a.amount) 
      END AS TAX_BASE,
      10 AS por_COMISION,
      item.* EXCEPT(level_0, level_3)

    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.hits_idcomisionista_202609` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    WHERE 1 = 1
       --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND item.Level_0 ='TELEFONIA MÓVIL'
      AND item.level_1 IN ('PLANES Y TARIFAS','SOBRETARIFICACIÓN VOZ Y DATOS MÓVIL')
      AND item.level_3 not like '%Sobretarificaciones de SMS%'
      AND b.ID_COMISIONISTA IN (
        'CL900-000288',
        'CL900-000277',
        'CL900-001093',
        'CL900-000294',
        'CL900-000120'

      )

    GROUP BY ALL

    
  );


    
    ---unir y sacar el phone para insert

    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.hits_base_comisiones_cartera_202609` AS (
    
    SELECT 
      a.*, 
      COALESCE(b.cli_asociado,b.referencia_externa) AS phone_nm,
      (tax_base * (por_comision/100)) AS comision,
      CAST(b.fecha_inicio AS DATE) AS fecha_ini,
      CASE
        WHEN CAST(b.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
        ELSE CAST(b.fecha_fin AS DATE)
      END AS fecha_final,
      b.Cliente
    FROM  `mm-commissions-reporting.TEMP.hits_base_movil_cartera_202609` a
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20261005` b
    ON a.contrato1 = b.num_contrato AND a.num_linea_contrato = b.num_linea AND a.no = b.producto
     WHERE 1 = 1
      AND (tax_base * (por_comision/100)) <>0 
      AND id_comisionista IS NOT NULL

    UNION ALL

    SELECT 
      a.*, 
      COALESCE(b.cli_asociado,b.referencia_externa) AS phone_nm,
      (tax_base * (por_comision/100)) AS comision,
      CAST(b.fecha_inicio AS DATE) AS fecha_ini,
      CASE
        WHEN CAST(b.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
        ELSE CAST(b.fecha_fin AS DATE)
      END AS fecha_final,
      b.Cliente
    FROM  `mm-commissions-reporting.TEMP.hits_base_fijo_cartera_202609` a
    left JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20261005` b
    ON a.contrato1 = b.num_contrato AND a.num_linea_contrato = b.num_linea AND a.no = b.producto 
     WHERE 1 = 1
      AND (tax_base * (por_comision/100)) <>0 
      AND id_comisionista IS NOT NULL

    UNION ALL

    SELECT 
      a.*, 
      COALESCE(b.cli_asociado,b.referencia_externa) AS phone_nm,
      (tax_base * (por_comision/100)) AS comision,
      CAST(b.fecha_inicio AS DATE) AS fecha_ini,
      CASE
        WHEN CAST(b.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
        ELSE CAST(b.fecha_fin AS DATE)
      END AS fecha_final,
      b.Cliente
        
    FROM  `mm-commissions-reporting.TEMP.hits_base_bundle_cartera_202609` a
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20261005` b
    ON a.contrato1 = b.num_contrato AND a.num_linea_contrato = b.num_linea AND a.no = b.producto
    WHERE 1 = 1
      AND (tax_base * (por_comision/100)) <>0 
      AND id_comisionista IS NOT NULL

       UNION ALL

    SELECT 
      a.*, 
      COALESCE(b.cli_asociado,b.referencia_externa) AS phone_nm,
      (tax_base * (por_comision/100)) AS comision,
      CAST(b.fecha_inicio AS DATE) AS fecha_ini,
      CASE
        WHEN CAST(b.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
        ELSE CAST(b.fecha_fin AS DATE)
      END AS fecha_final,
      b.Cliente
        
    FROM  `mm-commissions-reporting.TEMP.hits_base_master_fibra_cartera_202609` a
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20261005` b
    ON a.contrato1 = b.num_contrato AND a.num_linea_contrato = b.num_linea AND a.no = b.producto
    WHERE 1 = 1
      AND (tax_base * (por_comision/100)) <>0 
      AND id_comisionista IS NOT NULL


    UNION ALL

    SELECT 
      a.*, 
      COALESCE(b.cli_asociado,b.referencia_externa) AS phone_nm,
      (tax_base * (por_comision/100)) AS comision,
      CAST(b.fecha_inicio AS DATE) AS fecha_ini,
      CASE
        WHEN CAST(b.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
        ELSE CAST(b.fecha_fin AS DATE)
      END AS fecha_final,
      b.Cliente
        
    FROM  `mm-commissions-reporting.TEMP.hits_base_master_movil_cartera_202609` a
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20261005` b
    ON a.contrato1 = b.num_contrato AND a.num_linea_contrato = b.num_linea AND a.no = b.producto
    WHERE 1 = 1
      AND (tax_base * (por_comision/100)) <>0 
      AND id_comisionista IS NOT NULL

    );

    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.comisiones_cartera_hits_202609` AS (

    SELECT
      prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
      'calculado' as estado, 
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, 
      CAST(mes_string AS INT64) AS id_mes,
      'B2B - Hits' AS agrupacion_canal,
      'HICLI' AS canal, 
      CASE 
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN 'C - Gestion Cartera Movil' 
        WHEN level_0 IN ('INTERNET MINORISTA','BUNDLE PAQUETE') THEN 'C - Gestion Cartera Fibra' 
        WHEN level_0 = 'TELEVISIÓN' THEN 'C - Gestión Cartera TV'
        ELSE NULL
      END AS concepto, 
      'AIRH' AS tipo_concepto,
      1 AS unidades,
      base.comision,
      base.id_comisionista,  
      base.id_comisionista as distribuidor,
      base.id_comisionista as sfid_id,  
      base.empresa as seller, 
      dealers.nombre_comercio, 
      dealers.razon_social, 
      dealers.documento as cif,  
      dealers.zona_fiscal,  
      dealers.cond_pago,
      'HITS' AS marca,  
      CASE 
        WHEN level_0 = 'INTERNET MINORISTA' THEN 'INTERNET'
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN 'MOBILE'
        WHEN level_0 = 'TELEVISIÓN' THEN 'TV'
        ELSE 'INTERNET'
      END AS service_type, 
      base.phone_nm, 
      base.no as tariff_id,  
      base.description as tariff_ds, 
      concat(base.contrato1, base.num_linea_contrato) as service_id, 
      base.contrato1 as account_id, 
      base.cliente as customer_id,  
      CAST(NULL AS STRING) AS line_type_ds,
      CASE 
        WHEN Level_2 = 'INTERNET FIBRA CM' and base.Level_3 like '%CONV%' THEN 'FMC'
        WHEN Level_2 = 'INTERNET FIBRA CM' and base.Level_3 not like '%CONV%' THEN '2P'
        WHEN level_2 = 'MOVIL TARIFA CM' THEN 'MO'
        ELSE NULL
      END AS bundle_type, 
      CAST(NULL AS STRING) AS technology_ds,  
      CAST(NULL AS STRING) AS billing_type_ds, 
      base.fecha_ini AS sale_date, 
      base.fecha_ini as activation_date,  
      base.fecha_final as deactivation_date,  
      CAST(NULL AS STRING) AS order_id, 
      CAST(NULL AS STRING) AS order_type_agg, 
      '42' AS cod_segmento, 
      '05' AS cod_marca,  
      CASE 
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN '20' 
        WHEN level_0 = 'INTERNET MINORISTA' THEN '61'
        WHEN level_0 = 'TELEVISIÓN' THEN '20'
        ELSE '61'
      END AS cod_tipo_contrato,  
      '999' AS cod_producto, 
      '30' AS cod_canal,
      CAST(NULL AS STRING) AS campaign_code, 
      CAST(NULL AS STRING) AS serial_number, 
      base.tax_base AS tax_base, 
      CAST(NULL AS STRING) AS claim_code, 
      CAST(NULL AS STRING) AS process_code, 
      base.producto AS comments, 
      'C_MANUAL' AS facturador, 
      CAST(NULL AS STRING) AS proceso_sap, 
      CAST(NULL AS STRING) AS id_registro, 
      CAST(NULL AS STRING) AS invoice_id, 
       'X001' AS sociedad,
      CAST(NULL AS STRING) AS bp, 
      CAST(NULL AS STRING) AS cuenta_contable, 
      CAST(NULL AS STRING) AS centro_coste, 
      CAST(NULL AS STRING) AS documento_sap,
      CAST(NULL AS STRING) AS documento_sap_posicion,
      CAST(NULL AS STRING) AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP) AS creado,
      CAST(NULL AS TIMESTAMP) AS modificado,
      CAST(NULL AS STRING) AS id_factura_drive,
      CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad

    FROM `mm-commissions-reporting.TEMP.hits_base_comisiones_cartera_202609` base
    LEFT JOIN `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    ON base.id_comisionista = dealers.id_comisionista
    WHERE 1 = 1
      AND base.id_comisionista NOT IN  ('CL908-000012','CL908-000505','CL908-000784','CL908-001141','CL908-001155','CL908-001183')
      AND dealers.comisiona = TRUE
      --AND base.agrupacion_canal is not null
    );

  -- ES EL MASTER DE NEXUS 
  INSERT INTO `mm-commissions-reporting.TEMP.comisiones_cartera_hits_202609` (
    commission_id,
    estado,
    mes_liquidado,
    id_mes,
    agrupacion_canal,
    canal,
    concepto,
    tipo_concepto,
    unidades,
    comision,
    id_comisionista,
    distribuidor,
    sfid_id,
    seller,
    nombre_comercio,
    razon_social,
    cif,
    zona_fiscal,
    cond_pago,
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
  )
  SELECT
    prefijo||'_'||mes_string||'_'||canal||'_H_'||row_number () over() AS commission_id,
    estado, 
    mes_liquidado, 
    id_mes, 
    agrupacion_canal, 
    canal, 
    CASE 
      WHEN concepto ='C - Gestion Cartera Movil' THEN 'H - Gestion Cartera Movil'
      WHEN concepto ='C - Gestion Cartera Fibra' THEN 'H - Gestion Cartera Fibra'
    END AS concepto,
    tipo_concepto, 
    unidades,
    0.05 * tax_base AS comision,
    'CL900-019431' as id_comisionista,
    'CL900-019431' as distribuidor,
    'CL900-019431' as sfid_id,
    seller,
    'NEXUS MARKETING SERVICES, S.L.',
    'NEXUS MARKETING SERVICES, S.L.' as razon_social,
    'B75399881' as cif,
    zona_fiscal,
    cond_pago,
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
  FROM `mm-commissions-reporting.TEMP.comisiones_cartera_hits_202609`
  WHERE id_comisionista IN ('CL900-000327','CL900-014509', 'CL900-000058', 'CL900-000242')
    ;

    


    -- Actualización tabla transacciones --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_cartera_hits_202609',
  'ACTUALIZAR'
);

END