BEGIN

  DECLARE sql, prefijo, mes_string STRING;
  DECLARE fecha_inicio DATE;
  DECLARE fecha_fin DATE;
  DECLARE fecha_inicio_mes_siguiente DATE;

  SET mes_string = CAST(mes_int AS STRING);
  SET prefijo = 'RPAD';
  SET canales_pr = ['NASH', 'NTCLI', 'HICLI', 'OCE'];

  -- Fechas dinámicas
  SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
  SET fecha_fin = DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 DAY);
  SET fecha_inicio_mes_siguiente = DATE_ADD(fecha_inicio, INTERVAL 1 MONTH);

-- call `mm-commissions-reporting.COMISIONES.pr_nss_copia`(202601,['NASH', 'NTCLI', 'HICLI' 'OCE']);


-- AGOSTO


---PASO 1
 
CREATE or replace TABLE  `mm-commissions-reporting.TEMP.nnss_idcomisionista_202601_copia`
 AS (
  SELECT a.empresa, b.ID_COMISIONISTA,a.no as cliente
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_customer_*` a
  LEFT JOIN `mm-commissions-reporting.GS.DELEGACION_NNS` b
  ON a.empresa = b.empresa AND coalesce(a.delegacion,a.empresa) = coalesce(b.ID_DELEGACION,b.EMPRESA)
  where 1=1
  and ID_COMISIONISTA is not null
  qualify row_number () over (partition by a.no order by last_date_mod desc) = 1
)
;
 
--PASO 2 crear tabla ventas
 
 CREATE or replace  TABLE  `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_copia`
 as (
  SELECT a.* except(fecha_inicio, fecha_fin, cliente,referencia_externa ,glob_dim_1_code, glob_dim_2_code),
  CAST(a.fecha_inicio AS DATE) AS fecha_ini,
  CASE
    WHEN CAST(a.fecha_fin AS DATE) = '1753-01-01' THEN '9999-12-31'
    ELSE CAST(a.fecha_fin AS DATE)
  END AS fecha_final,
  c.id_comisionista AS id_comisionista,
  b.cliente,
  -- case
    -- WHEN item.item_category_code = 'CM INTERNET'
    --   THEN (CASE WHEN item.item_category_code = 'CM FIJO' THEN a.cli_asociado END)
    --       --  OVER (PARTITION BY a.num_contrato)
    --        ELSE a.cli_asociado end as phone_nm,
COALESCE(a.cli_asociado,a.referencia_externa) as phone_nm,
  item.*
  -- CASE
  -- WHEN item.no ='SV-0892' then 'CM INTERNET'
  -- ELSE ITEM.item_category_code END AS item_category_code
 
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20260202` a
  inner join `mm-dwh-prod.00_SANDBOX_NNS.bi_cabecera_contrato_20260202` b
    ON a.num_contrato = b.num_contrato
   LEFT JOIN `mm-commissions-reporting.TEMP.nnss_idcomisionista_202601_copia` c
   ON a.empresa = c.empresa and b.cliente =c.cliente  
   left join `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20260202` item
  ON a.producto = item.no
 
 )
;
 
 
--paso 3 comisionr fijo
 CREATE or replace TABLE  `mm-commissions-reporting.TEMP.nnss_base_202601_copia` as (
  
  WITH num_contrato AS (

    select distinct num_contrato FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_copia`
    WHERE 1=1
    -- AND b.empresa LIKE '07- alicante5'
    AND fecha_ini BETWEEN fecha_inicio AND fecha_fin
    -- AND (base.fecha_fin = '9999-12-31' OR base.fecha_fin > '2025-07-31')
    AND description LIKE '%CM%'
    and Level_0='INTERNET MINORISTA'
    and level_1='CUOTA MENSUAL RESIDENCIAL'
    and level_2='INTERNET FIBRA CM'
    AND (baja = 1 or baja_cambio_tarifa = 1)


  ),

 num_linea AS (

    select distinct phone_nm from `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_copia` 
    where 1=1  
    AND fecha_ini BETWEEN fecha_inicio AND fecha_fin
    AND fecha_final BETWEEN fecha_inicio AND fecha_fin
    AND description LIKE '%CM%'
    and Level_0='INTERNET MINORISTA'
    and level_1='CUOTA MENSUAL RESIDENCIAL'
    and level_2='INTERNET FIBRA CM'
    -- AND (alta = 1 OR base.alta_cambio_cm = 1))
    AND (alta = 1 OR alta_cambio_cm = 1)
    and baja_cambio_tarifa =1
    and phone_nm not in (select distinct phone_nm from `mm-commissions-reporting.GS.B2B_NETLLAR_surf` where 1=1 )
    -- and phone_nm ='960515617'
-- and base.num_contrato ='CTV25-908-00081'
-- and Empresa like '908-%'
    group by all


  )

  
  SELECT
    base.* except (glob_dim_1_code, glob_dim_2_code),d.*except(phone_nm),
    case 
      when base.Empresa =objetivo.Empresa and objetivo.COMISIONA_FIBRA ='NO' and cast(objetivo.id_mes as string) = mes_string THEN 0 
      when base.id_comisionista ='CL908-000001' then 85
      when base.id_comisionista ='CL908-000007' then 60
      when base.empresa =importe.empresa and base.Level_3 like '%CONV%'             then importe.fibra_3p
      when base.empresa =importe.empresa                                            then importe.fibra_2p
    ELSE 0
    end as comision,
    importe.agrupacion_canal


    -- except(fecha_inicio, fecha_fin),
    -- CAST(base.fecha_inicio AS DATE) AS fecha_inicio,
    -- CAST(base.fecha_fin AS DATE) AS fecha_fin
  FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_copia` base
  -- INNER JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_cabecera_contrato_20260103` cab
    -- ON base.num_contrato = cab.num_contrato
  left JOIN (
      SELECT
        phone_nm,
        service_type,
        bundle_type,
        fecha_activacion,
        tariff_id,
        tariff_ds,
        PARSE_DATE('%Y%m%d', CAST(deactivation_date AS STRING)) AS deactivation_date,
        ROW_NUMBER() OVER (PARTITION BY phone_nm ORDER BY fecha_activacion DESC) AS orden_fecha
      FROM `mm-datamart-kd.SERVICES.ventas_base_emysim`
      WHERE brand_ds = 'OPERADORES'
        AND comm_brand_ds = 'MARBLANCA'
        AND fecha_activacion IS NOT NULL
        --AND phone_nm = 824915579
      QUALIFY orden_fecha = 1
      ORDER BY phone_nm
 
        --QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm, activation_date) = 1
  ) d
    ON base.phone_nm = CAST(d.phone_nm AS STRING)
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    on base.empresa = importe.empresa
    LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
     on base.empresa = objetivo.empresa
    WHERE 1=1
    -- AND b.empresa LIKE '07- alicante5'
    AND base.fecha_ini BETWEEN fecha_inicio AND fecha_fin  ---el mes que comisionamos
    AND (base.fecha_final = '9999-12-31' OR base.fecha_final > fecha_fin)
    AND base.description LIKE '%CM%'
    and base.Level_0='INTERNET MINORISTA'
    and base.level_1='CUOTA MENSUAL RESIDENCIAL'
    and base.level_2='INTERNET FIBRA CM'
    AND (base.alta = 1 OR base.alta_cambio_cm = 1)
    -- AND base.cli_asociado IS NOT NULL
    --AND base.id_comisionista IN ('CL908-000001', 'CL908-000007')
    and base.phone_nm not in (select distinct phone_nm from `mm-commissions-reporting.GS.B2B_NETLLAR_surf` where 1=1 )
   
    group by all
 
 union all -- cambios de tarifa
 SELECT
    base.* except (glob_dim_1_code, glob_dim_2_code),d.*except(phone_nm),
    case 
  when base.Empresa =objetivo.Empresa and objetivo.COMISIONA_FIBRA ='NO' and cast(objetivo.id_mes as string) = mes_string THEN 0 
  when base.id_comisionista ='CL908-000001' then 85
  when base.id_comisionista ='CL908-000007' then 60
  when base.empresa =importe.empresa and base.Level_3 like '%CONV%'             then importe.fibra_3p
  when base.empresa =importe.empresa                                            then importe.fibra_2p
ELSE 0
end as comision,
importe.agrupacion_canal
  FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_copia` base
  -- INNER JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_cabecera_contrato_20260103` cab
    -- ON base.num_contrato = cab.num_contrato
  left JOIN (
      SELECT
        phone_nm,
        service_type,
        bundle_type,
        fecha_activacion,
        tariff_id,
        tariff_ds,
        PARSE_DATE('%Y%m%d', CAST(deactivation_date AS STRING)) AS deactivation_date,
        ROW_NUMBER() OVER (PARTITION BY phone_nm ORDER BY fecha_activacion DESC) AS orden_fecha
      FROM `mm-datamart-kd.SERVICES.ventas_base_emysim`
      WHERE brand_ds = 'OPERADORES'
        AND comm_brand_ds = 'MARBLANCA'
        AND fecha_activacion IS NOT NULL
        
        --AND phone_nm = 824915579
      QUALIFY orden_fecha = 1
      ORDER BY phone_nm
 
        --QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm, activation_date) = 1
  ) d
    ON base.phone_nm = CAST(d.phone_nm AS STRING)
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    on base.empresa = importe.empresa 
    inner join num_contrato cont
    on base.num_contrato = cont.num_contrato
    inner join num_linea linea
    on base.phone_nm = linea.phone_nm
    LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
     on base.empresa = objetivo.empresa
    where base.phone_nm not in (select distinct phone_nm from `mm-commissions-reporting.GS.B2B_NETLLAR_surf` where 1=1 )
    -- AND b.empresa LIKE '07- alicante5'
    AND base.fecha_ini BETWEEN fecha_inicio AND fecha_inicio_mes_siguiente  --Tenemos que poner el dia del mes siguiente
    AND (base.fecha_final = '9999-12-31' OR base.fecha_final > fecha_fin)
    AND base.description LIKE '%CM%'
    and base.Level_0='INTERNET MINORISTA'
    and base.level_1='CUOTA MENSUAL RESIDENCIAL'
    and base.level_2='INTERNET FIBRA CM'
    AND (base.alta_cambio_tarifa = 1)
    
-- and base.phone_nm ='960515617' ----eeeoooo


--     and base.num_contrato in(
--       select distinct num_contrato FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601`
--     WHERE 1=1
--     -- AND b.empresa LIKE '07- alicante5'
--     AND base.fecha_inicio BETWEEN fecha_inicio AND fecha_inicio_mes_siguiente
--     -- AND (base.fecha_fin = '9999-12-31' OR base.fecha_fin > '2025-07-31')
--     AND description LIKE '%CM%'
--     and Level_0='INTERNET MINORISTA'
--     and level_1='CUOTA MENSUAL RESIDENCIAL'
--     and level_2='INTERNET FIBRA CM'
--     AND (baja = 1 or baja_cambio_tarifa = 1)
   
--      )
--    and base.phone_nm in (
--     ----filtro linea nueva dado de baj por cambio de tarifa
--     select distinct phone_nm from `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601` where 1=1  
--    AND fecha_inicio BETWEEN fecha_inicio AND fecha_fin
--     AND fecha_fin BETWEEN fecha_inicio AND fecha_fin
--     AND description LIKE '%CM%'
--     and Level_0='INTERNET MINORISTA'
--     and level_1='CUOTA MENSUAL RESIDENCIAL'
--     and level_2='INTERNET FIBRA CM'
--     -- AND (alta = 1 OR base.alta_cambio_cm = 1))
--     AND (alta = 1 OR alta_cambio_cm = 1)
--     and baja_cambio_tarifa =1
--    and phone_nm not in (select distinct phone_nm from `mm-commissions-reporting.GS.B2B_NETLLAR_surf` where 1=1 )
--     -- and phone_nm ='960515617'
-- -- and base.num_contrato ='CTV25-908-00081'
-- -- and Empresa like '908-%'
--     group by all)
 );


 --paso 4 comisionr movil
 CREATE or replace TABLE  `mm-commissions-reporting.TEMP.nnss_base_movil_202601_copia` as (
    SELECT
    base.* except (glob_dim_1_code, glob_dim_2_code),d.*except(phone_nm),
case 
  when base.Empresa =objetivo.Empresa and objetivo.COMISIONA_MOVIL ='NO' and cast(objetivo.id_mes as string) = mes_string THEN 0 
  when base.id_comisionista ='CL908-000001' AND cast(base.PVP as float64) < 10 then 25
  when base.id_comisionista ='CL908-000001' AND cast(base.PVP as float64) > 10 then 35
  when base.id_comisionista ='CL908-000007' AND cast(base.PVP as float64) > 10 then 25
  when base.id_comisionista ='CL908-000007' AND cast(base.PVP as float64) > 10 then 35
  when base.empresa =importe.empresa AND cast(base.PVP as float64) > 10        then importe.movil_menos_10
  when base.empresa =importe.empresa AND cast(base.PVP as float64) < 10        then importe.movil_mayor_10
ELSE 0
end as comision,
importe.agrupacion_canal



    -- except(fecha_inicio, fecha_fin),
    -- CAST(base.fecha_inicio AS DATE) AS fecha_inicio,
    -- CAST(base.fecha_fin AS DATE) AS fecha_fin
  FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_copia` base
  -- INNER JOIN `mm-dwh-prod.00_SANDBOX_NNS.bi_cabecera_contrato_20260103` cab
    -- ON base.num_contrato = cab.num_contrato
  left JOIN (
      SELECT
        phone_nm,
        service_type,
        bundle_type,
        fecha_activacion,
        tariff_id,
        tariff_ds,
        PARSE_DATE('%Y%m%d', CAST(deactivation_date AS STRING)) AS deactivation_date,
        ROW_NUMBER() OVER (PARTITION BY phone_nm ORDER BY fecha_activacion DESC) AS orden_fecha
      FROM `mm-datamart-kd.SERVICES.ventas_base_emysim`
      WHERE brand_ds = 'OPERADORES'
        AND comm_brand_ds = 'MARBLANCA'
        AND fecha_activacion IS NOT NULL
        --AND phone_nm = 824915579
      QUALIFY orden_fecha = 1
      ORDER BY phone_nm
 
        --QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm, activation_date) = 1
  ) d
    ON base.phone_nm = CAST(d.phone_nm AS STRING)
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
   on base.empresa = importe.empresa 
       LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
     on base.empresa = objetivo.empresa
  WHERE base.num_contrato not in (select distinct num_contrato from `mm-commissions-reporting.TEMP.nnss_base_202601_copia` where 1=1)
    -- AND b.empresa LIKE '07- alicante5'
    AND base.fecha_ini BETWEEN fecha_inicio AND fecha_fin
    AND (base.fecha_final = '9999-12-31' OR base.fecha_final > fecha_fin)
    AND base.description LIKE '%CM%'
    AND Level_0  ='TELEFONIA MÓVIL'
    AND LEVEL_1 ='PLANES Y TARIFAS'
    AND Level_2 ='MOVIL TARIFA CM'
    AND Level_3 NOT IN (
'MÓVIL PAGO POR USO CM0123',
'MÓVIL PAGO POR USO CM0422',
'FIXED WIRELESS CM0422',
'FIXED WIRELESS DOUBLE CM0422',
'MÓVIL SUSPENSIÓN TEMPORAL CM1222')
    AND UPPER(description) not like '%ADIC%'
    AND (base.alta = 1 OR base.alta_cambio_cm = 1)
    group by all
 );

    ---unir para insert

    CREATE or replace TABLE  `mm-commissions-reporting.TEMP.nnss_base_comisiones_202601_copia` as (
    select * from  `mm-commissions-reporting.TEMP.nnss_base_movil_202601_copia` where comision >0 and id_comisionista is not null
    union all
    select * from  `mm-commissions-reporting.TEMP.nnss_base_202601_copia` where comision >0 and id_comisionista is not null
    );

    CREATE or replace TABLE  `mm-commissions-reporting.TEMP.comisiones_nss_202601_copia` as (
    select
      prefijo || '_'|| mes_string || ROW_NUMBER() OVER() AS commission_id,
      'calculado' as estado, 
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      base.agrupacion_canal,
      CASE WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
          WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NTCLI'
          WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'HICLI'
          WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'OCE'
        ELSE NULL
      END AS canal, 
      case 
      when  Level_2 = 'INTERNET FIBRA CM'   then  'A - Fibra CM' 
      when  level_2 = 'MOVIL TARIFA CM'     then   'A - Servicio Movil CM'
      ELSE NULL END AS concepto, -- solo hay upfront?
      'UPF1' AS tipo_concepto, -- solo hay upfront?
      1 AS unidades,
      base.comision,
      --pvp
      base.id_comisionista,  
      base.id_comisionista as distribuidor, -- DUDA
      base.id_comisionista as sfid_id,  
      base.Empresa as seller, 
      dealers.nombre_comercio, 
      dealers.razon_social, 
      dealers.documento as cif,  
      dealers.zona_fiscal,  
      dealers.cond_pago,
      CASE WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
          WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NETLLAR'
          WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'HITS'
          WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'OCEANS'
        ELSE NULL
      END AS marca,  
      CASE WHEN Level_2 = 'INTERNET FIBRA CM' THEN 'INTERNET'
          WHEN level_2 = 'MOVIL TARIFA CM' THEN 'MOBILE'
          ELSE NULL
          END AS service_type, 
      base.phone_nm AS phone_nm, 
      base.no as tariff_id,  
      base.description as tariff_ds, 
      concat(base.num_contrato, base.num_linea) as service_id, 
      base.num_contrato as account_id, 
      base.cliente as customer_id,  
      CAST(NULL AS STRING) AS line_type_ds,
      CASE WHEN Level_2 = 'INTERNET FIBRA CM' and base.Level_3 like '%CONV%' THEN 'FMC'
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
      CASE WHEN Level_2 = 'INTERNET FIBRA CM' THEN '61'
          WHEN level_2 = 'MOVIL TARIFA CM' THEN '20'
          ELSE NULL
        END AS cod_tipo_contrato,  
      '999' AS cod_producto, 
      '30' AS cod_canal,
      CAST(NULL AS STRING) AS campaign_code, 
      CAST(NULL AS STRING) AS serial_number, 
      CAST(NULL AS FLOAT64) AS tax_base, 
      CAST(NULL AS STRING) AS claim_code, 
      CAST(NULL AS STRING) AS process_code, 
      CAST(NULL AS STRING) AS comments, 
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

    from `mm-commissions-reporting.TEMP.nnss_base_comisiones_202601_copia` base
    left join `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    on base.id_comisionista = dealers.id_comisionista
    );


    -- Actualización tabla transacciones --

-- call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
-- (
--   prefijo,
--   mes_int,
--   canales_pr,
--   'TEMP.comisiones_nss',
--   'ACTUALIZAR'
-- );

END