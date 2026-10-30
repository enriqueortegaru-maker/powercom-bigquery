BEGIN

  DECLARE sql, prefijo, mes_string STRING;
  DECLARE fecha_inicio DATE;
  DECLARE fecha_fin DATE;
  DECLARE fecha_inicio_mes_siguiente DATE;

  SET mes_string = CAST(mes_int AS STRING);
  SET prefijo = 'CPAD4';
  SET canales_pr = ['NASH', 'OCE', 'NTCLI'];


  -- Fechas dinámicas
  SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
  SET fecha_fin = DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 DAY);
  SET fecha_inicio_mes_siguiente = DATE_ADD(fecha_inicio, INTERVAL 1 MONTH);

-- call `mm-commissions-reporting.COMISIONES.pr_nss_cartera`(202609,['NASH', 'OCE', 'NTCLI']);



-- AGOSTO


---PASO 1
 
CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_idcomisionista`
 AS (
  SELECT a.empresa, b.ID_COMISIONISTA,a.no AS cliente
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_customer_*` a
  LEFT JOIN `mm-commissions-reporting.GS.DELEGACION_NNS` b
  ON a.empresa = b.empresa AND COALESCE(a.delegacion,a.empresa) = COALESCE(b.ID_DELEGACION,b.EMPRESA)
  WHERE 1=1
  AND ID_COMISIONISTA IS NOT NULL
  AND a.empresa <> '900- HITSMOBILE'
  AND NOT (a.empresa = '74- NetllarGlobal' AND a.no NOT LIKE 'CL034-M%') -- LAVALL
  QUALIFY ROW_NUMBER () OVER (PARTITION BY  a.no ORDER BY last_date_mod DESC) = 1

)
;
 

 
--paso 2 comisionar cartera fijo, alarmas y TV
 CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_base_fijo_cartera` as (
  
   SELECT a.empresa, a.num_contrato as contrato1, a.num_linea_contrato, a.sell_to_customer_no as cliente,
   CASE 
      WHEN a.sell_to_customer_no in ('CL001-012853','CL001-000011') THEN a.sell_to_customer_no
      WHEN b.empresa = '74- NetllarGlobal' THEN 'CL001-000027'
      ELSE b.ID_COMISIONISTA 
   END AS ID_COMISIONISTA,   
   a.no as producto, 
   item.Level_0, item.level_3,
    CASE
      WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 LIKE '%IND%' THEN SUM(a.amount)
      WHEN item.level_0 = 'INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN SUM(a.amount)
      ELSE SUM(a.amount) 
    END AS TAX_BASE ,
      CASE
      WHEN id_comisionista = 'CL908-000001' AND item.Level_0 = 'INTERNET MINORISTA' AND item.level_3 LIKE '%IND%'  THEN 8
      WHEN id_comisionista = 'CL908-000001' AND item.Level_0 = 'INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN 10
      WHEN id_comisionista = 'CL908-000007' AND item.Level_0 = 'INTERNET MINORISTA' AND item.level_3 LIKE '%IND%'  THEN 5
      WHEN id_comisionista = 'CL908-000007' AND item.Level_0 = 'INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN 5
      WHEN  item.Level_0='INTERNET MINORISTA' AND item.level_3 LIKE '%IND%' THEN importe.cartera_indirecta
      WHEN  item.Level_0='INTERNET MINORISTA' AND item.level_3 NOT LIKE '%IND%' THEN importe.cartera_directa
      WHEN  item.Level_0='TELEVISIÓN'  THEN 15
      WHEN  item.Level_0='NET ALARM'  THEN 20
      ELSE NULL 
    END AS por_COMISION,
    item.* except (Level_0, level_3),
    importe.agrupacion_canal

    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.nnss_idcomisionista` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    ON a.empresa = importe.empresa_cartera
    WHERE 1 = 1
      --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND (
        (item.level_0 = 'INTERNET MINORISTA' 
          AND item.level_1='CUOTA MENSUAL RESIDENCIAL' 
          AND item.level_2='INTERNET FIBRA CM')
      OR item.level_0 = 'NET ALARM'
      OR item.level_0 = 'TELEVISIÓN')
      --AND a.bill_to_customer_no in ('CL001-012853')  --, 'CL001-012853') -- BLAUFIBRA Y LIFE

    GROUP BY ALL
 );




 --paso 3 comisionr movil
 CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_base_movil_cartera` as (
  
    SELECT 
      a.empresa, 
      a.num_contrato as contrato1, 
      a.num_linea_contrato, 
      a.sell_to_customer_no as cliente,
      CASE 
        WHEN a.sell_to_customer_no in ('CL001-012853','CL001-000011') THEN a.sell_to_customer_no
        WHEN b.empresa = '74- NetllarGlobal' THEN 'CL001-000027'
        ELSE b.ID_COMISIONISTA 
      END AS ID_COMISIONISTA,   
      a.no as producto, 
      item.Level_0 , 
      item.level_3,
      CASE
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price >10 THEN SUM(a.amount)
        WHEN item.Level_0='TELEFONIA MÓVIL' AND item.unit_price <10 THEN SUM(a.amount)
        ELSE SUM(a.amount) END AS TAX_BASE ,
      CASE
        WHEN id_comisionista = 'CL908-000001' AND item.Level_0 = 'TELEFONIA MÓVIL' THEN 10
        WHEN id_comisionista = 'CL908-000007' AND item.Level_0 = 'TELEFONIA MÓVIL' THEN 5
        WHEN id_comisionista = 'CL900-010938' AND item.Level_0 = 'TELEFONIA MÓVIL' THEN 10
        WHEN  item.Level_0='TELEFONIA MÓVIL' AND item.unit_price >10 THEN importe.cartera_movil_menos_10
        WHEN  item.Level_0='TELEFONIA MÓVIL' AND item.unit_price <10 THEN importe.cartera_movil_mayor_10
        ELSE NULL 
      END AS por_COMISION,
      -- CASE WHEN  item.Level_0='TELEFONIA MÓVIL' THEN 30
      --   ELSE NULL
      -- END AS por_COMISION,
      item.* EXCEPT(level_0, level_3),
      importe.agrupacion_canal

    
    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.nnss_idcomisionista` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    ON a.empresa = importe.empresa_cartera
    WHERE 1 = 1
      --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
      AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
      AND item.Level_0 ='TELEFONIA MÓVIL'
      AND item.level_1 IN ('PLANES Y TARIFAS','SOBRETARIFICACIÓN VOZ Y DATOS MÓVIL')
      AND item.level_3 not like '%Sobretarificaciones de SMS%'
      --AND a.empresa = '01- central' and a.bill_to_customer_no in ('CL001-012853') --, 'CL001-012853') -- BLAUFIBRA Y LIFE

      
    GROUP BY ALL
    );

    
  -- paso 4 bundle

  CREATE or replace TABLE  `mm-commissions-reporting.TEMP.nnss_base_bundle_cartera` as (

  SELECT 
    a.empresa, 
    a.num_contrato as contrato1, 
    a.num_linea_contrato, 
    a.sell_to_customer_no as cliente,
    CASE 
      WHEN a.sell_to_customer_no in ('CL001-012853','CL001-000011') THEN a.sell_to_customer_no
      WHEN b.empresa = '74- NetllarGlobal' THEN 'CL001-000027'
      ELSE b.ID_COMISIONISTA 
    END AS ID_COMISIONISTA,   
    a.no as producto, 
    item.Level_0 , 
    item.level_3, 
    CASE
      WHEN  item.Level_0='BUNDLE PAQUETE' AND item.unit_price >10 THEN SUM(a.amount)
      WHEN  item.Level_0='BUNDLE PAQUETE' AND item.unit_price <10 THEN SUM(a.amount)
      ELSE SUM(a.amount)
    END AS tax_base, 
    CASE
      WHEN id_comisionista = 'CL908-000001' AND item.Level_0 = 'BUNDLE PAQUETE' AND item.level_3 LIKE '%IND%'  THEN 8
      WHEN id_comisionista = 'CL908-000001' AND item.Level_0 = 'BUNDLE PAQUETE' AND item.level_3 NOT LIKE '%IND%' THEN 10
      WHEN id_comisionista = 'CL908-000007' AND item.Level_0 = 'BUNDLE PAQUETE' AND item.level_3 LIKE '%IND%'  THEN 5
      WHEN id_comisionista = 'CL908-000007' AND item.Level_0 = 'BUNDLE PAQUETE' AND item.level_3 NOT LIKE '%IND%' THEN 5
      WHEN  item.Level_0='BUNDLE PAQUETE' AND item.level_3 LIKE '%IND%' THEN importe.cartera_indirecta
      WHEN  item.Level_0='BUNDLE PAQUETE' AND item.level_3 NOT LIKE '%IND%' THEN importe.cartera_directa
      ELSE NULL 
    END AS por_COMISION,
    -- CASE WHEN  item.Level_0='BUNDLE PAQUETE' THEN 20
    -- ELSE NULL
    -- END AS por_COMISION,
   
    item.* EXCEPT(level_0, level_3),
    importe.agrupacion_canal

    FROM  `mm-dwh-prod.00_SANDBOX_NNS.bi_sales_invoice_line_20261005` a
    LEFT JOIN `mm-commissions-reporting.TEMP.nnss_idcomisionista` b
    ON a.sell_to_customer_no = b.cliente and a.Empresa =b.empresa  
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20261005` item
    ON a.no = item.no
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    ON a.empresa = importe.empresa_cartera
    WHERE 1 = 1
    --AND CAST(a.posting_date AS STRING) LIKE '2026-08%'
    AND DATETIME_TRUNC(a.posting_date, MONTH) = DATETIME(fecha_inicio)
    AND item.Level_0='BUNDLE PAQUETE'
    AND item.level_1 IN ('BUNDLE 2P')
    AND item.level_3  LIKE '%Promo FIBRA 500 12m CM0425%'
    --AND a.empresa = '01- central' and a.bill_to_customer_no in ('CL001-012853')--, 'CL001-012853') -- BLAUFIBRA Y LIFE

  GROUP BY ALL

  );


    
    ---unir y sacar el phone para insert

    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_base_comisiones_cartera` AS (
    
    SELECT 
      a.*, 
      COALESCE(b.cli_asociado,b.referencia_externa) AS phone_nm,
      (tax_base * (por_comision/100)) AS comision,
      CAST(b.fecha_inicio AS DATE) AS fecha_ini,
      CASE
        WHEN CAST(b.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
        ELSE CAST(b.fecha_fin AS DATE)
      END AS fecha_final,
      b.Cliente as cliente2
    FROM  `mm-commissions-reporting.TEMP.nnss_base_movil_cartera` a
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
      b.Cliente as cliente2
    FROM  `mm-commissions-reporting.TEMP.nnss_base_fijo_cartera` a
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
      b.Cliente as cliente2
        
    FROM  `mm-commissions-reporting.TEMP.nnss_base_bundle_cartera` a
    LEFT JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20261005` b
    ON a.contrato1 = b.num_contrato AND a.num_linea_contrato = b.num_linea AND a.no = b.producto
    WHERE 1 = 1
      AND (tax_base * (por_comision/100)) <>0 
      AND id_comisionista IS NOT NULL


    );

    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.comisiones_cartera_nss` AS (

    SELECT
      prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
      'calculado' as estado, 
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, 
      CAST(mes_string AS INT64) AS id_mes,
      base.agrupacion_canal,
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NTCLI'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'HICLI'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'OCE'
        ELSE NULL
      END AS canal, 
      CASE 
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN 'C - Gestion Cartera Movil' 
        WHEN level_0 IN ('INTERNET MINORISTA','BUNDLE PAQUETE') THEN 'C - Gestion Cartera Fibra' 
        WHEN level_0 = 'NET ALARM' THEN 'C - Gestión Cartera Alarmas'
        WHEN level_0 = 'TELEVISIÓN' THEN 'C - Gestión Cartera TV'
        ELSE NULL
      END AS concepto, 
      CASE
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'AIR1'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'AIRN'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'AIRH'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'AIRN'
        ELSE NULL
      END AS tipo_concepto,
      1 AS unidades,
      base.comision,
      base.id_comisionista,  
      base.id_comisionista as distribuidor,
      base.id_comisionista as sfid_id,  
      CASE 
        WHEN base.id_comisionista = 'CL001-012853' THEN '910- LIFE'
        WHEN base.id_comisionista = 'CL001-000011' THEN '12- barcelona10'
        WHEN base.empresa = '74- NetllarGlobal' THEN '34- lavall' 
        ELSE base.empresa 
        END as seller, 
      CASE 
        WHEN base.empresa = '74- NetllarGlobal' THEN 'CONECTA LA VALL, S.L.'
        ELSE dealers.nombre_comercio
      END AS nombre_comercio,  
      dealers.razon_social, 
      dealers.documento as cif,  
      dealers.zona_fiscal,  
      dealers.cond_pago,
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NETLLAR'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'HITS'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'OCEANS'
        ELSE NULL
      END AS marca,  
      CASE 
        WHEN level_0 = 'INTERNET MINORISTA' THEN 'INTERNET'
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN 'MOBILE'
        WHEN level_0 = 'NET ALARM' THEN 'SECURITY'
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
        WHEN level_0 = 'NET ALARM' THEN '20'
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
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN '8300'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'X001'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'X001'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'X001'
        ELSE NULL 
      END AS sociedad,
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

    FROM `mm-commissions-reporting.TEMP.nnss_base_comisiones_cartera` base
    LEFT JOIN `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    ON base.id_comisionista = dealers.id_comisionista
    WHERE 1 = 1
      AND base.id_comisionista NOT IN  ('CL908-000012','CL908-000505','CL908-000784','CL908-001141','CL908-001155','CL908-001183')
      AND dealers.comisiona = TRUE
      AND base.agrupacion_canal is not null
    );



    -- Actualización tabla transacciones --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_cartera_nss',
  'ACTUALIZAR'
);

END