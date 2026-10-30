BEGIN

  DECLARE sql, prefijo, mes_string STRING;
  DECLARE fecha_inicio DATE;
  DECLARE fecha_fin DATE;
  DECLARE fecha_inicio_mes_siguiente DATE;

  SET mes_string = CAST(mes_int AS STRING);
  SET prefijo = '2RPAD';
  SET canales_pr = [ 'NASH', 'OCE', 'NTCLI', 'HICLI'];

  -- Fechas dinámicas
  SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
  SET fecha_fin = DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 DAY);
  SET fecha_inicio_mes_siguiente = DATE_ADD(fecha_inicio, INTERVAL 1 MONTH);

-- call `mm-commissions-reporting.COMISIONES.pr_nss_v2`(202601,['NASH', 'OCE', 'NTCLI', 'HICLI']);


-- AGOSTO


---PASO 1
 
CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_idcomisionista_202601_v2`
 AS (
  SELECT a.empresa, b.ID_COMISIONISTA,a.no AS cliente
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_customer_*` a
  LEFT JOIN `mm-commissions-reporting.GS.DELEGACION_NNS` b
  ON a.empresa = b.empresa AND COALESCE(a.delegacion,a.empresa) = COALESCE(b.ID_DELEGACION,b.EMPRESA)
  WHERE 1=1
  AND ID_COMISIONISTA IS NOT NULL
  QUALIFY ROW_NUMBER () over (PARTITION BY  a.no ORDER BY last_date_mod DESC) = 1
)
;
 
--PASO 2 crear tabla ventas
 
CREATE or REPLACE  TABLE  `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_v2`
 as (
  SELECT a.* EXCEPT(fecha_inicio, fecha_fin, cliente,referencia_externa ,glob_dim_1_code, glob_dim_2_code),
  CAST(a.fecha_inicio AS DATE) AS fecha_ini,
  CASE
    WHEN (CAST(a.fecha_fin AS DATE) = '1753-01-01' OR CAST(a.fecha_fin AS DATE) > DATE_SUB(DATE_ADD(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH), INTERVAL 1 MONTH), INTERVAL 1 DAY))  
    THEN '9999-12-31'
    ELSE CAST(a.fecha_fin AS DATE)
  END AS fecha_final,
  c.id_comisionista AS id_comisionista,
  b.cliente,
  COALESCE(a.cli_asociado,a.referencia_externa) as phone_nm,
  item.*
 
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20260203` a
  inner join `mm-dwh-prod.00_SANDBOX_NNS.bi_cabecera_contrato_20260203` b
    ON a.num_contrato = b.num_contrato
   LEFT JOIN `mm-commissions-reporting.TEMP.nnss_idcomisionista_202601_v2` c
   ON a.empresa = c.empresa and b.cliente =c.cliente  
   left join `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20260203` item
  ON a.producto = item.no
 
 )
;
 

 
--paso 3 comisionr fijo
 CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_base_202601_v2` as (
  
  WITH num_contrato AS (

    select distinct num_contrato FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_v2`
    WHERE 1=1
    AND fecha_ini BETWEEN fecha_inicio AND fecha_fin
    AND description LIKE '%CM%'
    AND  level_0 = 'INTERNET MINORISTA'
    and level_1='CUOTA MENSUAL RESIDENCIAL'
    and level_2='INTERNET FIBRA CM'
    AND (baja = 1 or baja_cambio_tarifa = 1)


  ),

 num_linea AS (

    select distinct phone_nm from `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_v2` 
    where 1=1  
    AND fecha_ini BETWEEN fecha_inicio AND fecha_fin
    AND fecha_final BETWEEN fecha_inicio AND fecha_fin
    AND description LIKE '%CM%'
    AND level_0 = 'INTERNET MINORISTA'
    and level_1='CUOTA MENSUAL RESIDENCIAL'
    and level_2='INTERNET FIBRA CM'
    AND (alta = 1 OR alta_cambio_cm = 1)
    and baja_cambio_tarifa =1
    and phone_nm not in (select distinct phone_nm from `mm-commissions-reporting.GS.B2B_NETLLAR_surf` where 1=1 )
    group by all


  )

  
  SELECT
    base.* except (glob_dim_1_code, glob_dim_2_code),d.*except(phone_nm),
    case 
      --when base.Empresa =objetivo.Empresa and objetivo.COMISIONA_FIBRA ='NO' and cast(objetivo.id_mes as string) = mes_string THEN 0 
      when base.id_comisionista ='CL908-000001' then 85
      when base.id_comisionista ='CL908-000007' then 60
      when base.id_comisionista ='CL900-010938' then 85
      when base.Jerarquia_Paquete in ('4+3+2', '2+4+3')                             then importe.fibra_3p
      when base.empresa =importe.empresa and base.Level_3 like '%CONV%'             then importe.fibra_3p
      when base.empresa =importe.empresa                                            then importe.fibra_2p
    ELSE 0
    END AS comision,
    importe.agrupacion_canal

  FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_v2` base
  LEFT JOIN (
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
      QUALIFY orden_fecha = 1
      ORDER BY phone_nm
 
        --QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm, activation_date) = 1
  ) d
    ON base.phone_nm = CAST(d.phone_nm AS STRING)
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    on base.empresa = importe.empresa
    --LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
    --on base.empresa = objetivo.empresa --AND cast(objetivo.id_mes as string) = mes_string 
    WHERE 1=1
      AND base.description LIKE '%CM%'
      AND level_0 = 'INTERNET MINORISTA'
      AND level_1='CUOTA MENSUAL RESIDENCIAL'
      AND level_2='INTERNET FIBRA CM'
      AND (base.alta = 1 OR base.alta_cambio_cm = 1)
      AND base.phone_nm not in (select distinct phone_nm from `mm-commissions-reporting.GS.B2B_NETLLAR_surf` where 1=1 )
   
    GROUP BY ALL
 
 UNION ALL -- cambios de tarifa

 SELECT
    base.* EXCEPT (glob_dim_1_code, glob_dim_2_code),d.*EXCEPT(phone_nm),
    CASE 
      --WHEN base.Empresa =objetivo.Empresa AND objetivo.COMISIONA_FIBRA ='NO' AND CAST(objetivo.id_mes AS STRING) = mes_string THEN 0 
      WHEN base.id_comisionista ='CL900-010938' THEN 85
      WHEN base.id_comisionista ='CL900-030494' THEN 85       
      WHEN base.id_comisionista ='CL908-000001' THEN 85
      WHEN base.id_comisionista ='CL908-000007' THEN 60
      WHEN base.Jerarquia_Paquete IN ('4+3+2', '2+4+3')                             THEN importe.fibra_3p
      WHEN base.empresa =importe.empresa AND base.Level_3 LIKE '%CONV%'             THEN importe.fibra_3p
      WHEN base.empresa =importe.empresa                                            THEN importe.fibra_2p
      ELSE 0
    END AS comision,
    importe.agrupacion_canal
  FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_v2` base
  LEFT JOIN (
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
      WHERE 1 = 1
        AND brand_ds = 'OPERADORES'
        AND comm_brand_ds = 'MARBLANCA'
        AND fecha_activacion IS NOT NULL
      QUALIFY orden_fecha = 1
      ORDER BY phone_nm
   ) d
  ON base.phone_nm = CAST(d.phone_nm AS STRING)
  LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
  ON base.empresa = importe.empresa 
  INNER JOIN num_contrato cont
  ON base.num_contrato = cont.num_contrato
  INNER JOIN num_linea linea
  ON base.phone_nm = linea.phone_nm
  --LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
  --ON base.empresa = objetivo.empresa --AND CAST(objetivo.id_mes AS STRING) = mes_string 
   WHERE 1 = 1
    AND base.phone_nm NOT IN (SELECT DISTINCT phone_nm FROM `mm-commissions-reporting.GS.B2B_NETLLAR_surf`)
    AND base.description LIKE '%CM%'
    AND level_0 = 'INTERNET MINORISTA'
    AND level_1='CUOTA MENSUAL RESIDENCIAL'
    AND level_2='INTERNET FIBRA CM'
    AND (base.alta_cambio_tarifa = 1)
 );

 


 --paso 4 comisionr movil
  CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_base_movil_202601_v2` as (
    SELECT
      base.* EXCEPT (glob_dim_1_code, glob_dim_2_code),d.*EXCEPT(phone_nm),
      CASE 
        --WHEN base.Empresa =objetivo.Empresa and objetivo.COMISIONA_MOVIL ='NO' AND CAST(objetivo.id_mes AS STRING) = mes_string THEN 0 
        WHEN base.id_comisionista ='CL908-000001' AND CAST(base.PVP AS FLOAT64) < 10 THEN 25
        WHEN base.id_comisionista ='CL908-000001' AND CAST(base.PVP AS FLOAT64) > 10 THEN 35
        WHEN base.id_comisionista ='CL908-000007' AND CAST(base.PVP AS FLOAT64) > 10 THEN 25
        WHEN base.id_comisionista ='CL908-000007' AND CAST(base.PVP AS FLOAT64) > 10 THEN 35
        WHEN base.empresa =importe.empresa AND CAST(base.PVP AS FLOAT64) > 10 THEN importe.movil_menos_10
        WHEN base.empresa =importe.empresa AND CAST(base.PVP AS FLOAT64) < 10 THEN importe.movil_mayor_10
        ELSE 0
      END AS comision,
      importe.agrupacion_canal

    FROM `mm-commissions-reporting.TEMP.nnss_lineas_idcomisionista_202601_v2` base
 
    LEFT JOIN (
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
      QUALIFY orden_fecha = 1
      ORDER BY phone_nm
 
  ) d
    ON base.phone_nm = CAST(d.phone_nm AS STRING)
    LEFT JOIN `mm-commissions-reporting.GS.B2B_NETLLAR_COMISIONES` importe
    ON base.empresa = importe.empresa 
    --LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
    --ON base.empresa = objetivo.empresa AND CAST(objetivo.id_mes AS STRING) = mes_string 
    WHERE base.num_contrato NOT IN (SELECT DISTINCT num_contrato FROM `mm-commissions-reporting.TEMP.nnss_base_202601_v2` WHERE 1=1)
    AND base.description LIKE '%CM%'
    AND Level_0  ='TELEFONIA MÓVIL'
    AND LEVEL_1 ='PLANES Y TARIFAS'
    AND Level_2 ='MOVIL TARIFA CM'
    AND Level_3 NOT IN ('MÓVIL PAGO POR USO CM0123', 'MÓVIL PAGO POR USO CM0422', 'FIXED WIRELESS CM0422', 'FIXED WIRELESS DOUBLE CM0422', 'MÓVIL SUSPENSIÓN TEMPORAL CM1222')
    AND UPPER(description) NOT LIKE '%ADIC%'
    AND (base.alta = 1 OR base.alta_cambio_cm = 1)
    GROUP BY ALL
 );

    ---unir para insert

    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.nnss_base_comisiones_202601_v2` AS (
    SELECT * FROM  `mm-commissions-reporting.TEMP.nnss_base_movil_202601_v2` WHERE comision >0 AND id_comisionista IS NOT NULL
    UNION ALL
    SELECT * FROM  `mm-commissions-reporting.TEMP.nnss_base_202601_v2` WHERE comision >0 and id_comisionista IS NOT NULL
    );

    
    
    
    -- UPFRONT
    
    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.upfronts_nss_202601_v2` as (
    SELECT
      'calculado' AS estado, 
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
        WHEN Level_0 = 'INTERNET MINORISTA' THEN 'A - Servicio base fibra' 
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN 'A - Servicio base movil'
        ELSE NULL 
      END AS concepto,
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'UPF1'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'UPFN'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'UPFH'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'UPF1'
        ELSE NULL
      END AS tipo_concepto,
      1 AS unidades,
      base.comision,
      base.id_comisionista,  
      base.id_comisionista as distribuidor,
      base.id_comisionista as sfid_id,  
      base.Empresa as seller, 
      dealers.nombre_comercio, 
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
        WHEN Level_0 = 'INTERNET MINORISTA' THEN 'INTERNET'
        WHEN Level_0 = 'TELEFONIA MÓVIL' THEN 'MOBILE'
        ELSE 'INTERNET'
      END AS service_type, 
      base.phone_nm AS phone_nm, 
      base.no AS tariff_id,  
      base.description AS tariff_ds, 
      CONCAT(base.num_contrato, base.num_linea) AS service_id, 
      base.num_contrato AS account_id, 
      base.cliente AS customer_id,  
      CAST(NULL AS STRING) AS line_type_ds,
      CASE 
        WHEN Level_2 = 'INTERNET FIBRA CM' AND base.Jerarquia_Paquete in ('4+3+2', '2+4+3') THEN 'FMC'  
        WHEN Level_2 = 'INTERNET FIBRA CM' AND base.Level_3 LIKE '%CONV%' THEN 'FMC'
        WHEN Level_2 = 'INTERNET FIBRA CM' AND base.Level_3 NOT LIKE '%CONV%' THEN '2P'
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
         WHEN Level_0 = 'INTERNET MINORISTA' THEN '61'
        WHEN Level_0 = 'TELEFONIA MÓVIL' THEN '20'
        ELSE '61'
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

    FROM `mm-commissions-reporting.TEMP.nnss_base_comisiones_202601_v2` base
    LEFT JOIN `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    on base.id_comisionista = dealers.id_comisionista
    WHERE 1= 1
      AND base.fecha_ini BETWEEN fecha_inicio AND fecha_fin
      AND base.fecha_final = '9999-12-31'
      AND dealers.comisiona = TRUE
     

      -- EXTRACOMISION
      
      UNION ALL

      SELECT
        'calculado' AS estado, 
        DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, 
        CAST(mes_string AS INT64) AS id_mes,
        base.agrupacion_canal,
        'NTCLI' AS canal,
        'D - Extracomision Fibra' AS concepto,
        'UPFN' AS tipo_concepto,
        1 AS unidades,
        55 AS comision,
        base.id_comisionista,  
        base.id_comisionista AS distribuidor,
        base.id_comisionista AS sfid_id,  
        base.Empresa AS seller, 
        dealers.nombre_comercio, 
        dealers.razon_social, 
        dealers.documento AS cif,  
        dealers.zona_fiscal,  
        dealers.cond_pago,
        'NETLLAR' AS marca,
        'INTERNET' AS service_type,
        base.phone_nm,
        base.no AS tariff_id,
        base.description AS tariff_ds,
        CONCAT(base.num_contrato, base.num_linea) AS service_id,
        base.num_contrato AS account_id,
        base.cliente AS customer_id,
        CAST(NULL AS STRING) AS line_type_ds,
        '2P' AS bundle_type,
        CAST(NULL AS STRING) AS technology_ds,
        CAST(NULL AS STRING) AS billing_type_ds,
        base.fecha_ini AS sale_date,
        base.fecha_ini AS activation_date,
        base.fecha_final AS deactivation_date,
        CAST(NULL AS STRING) AS order_id,
        CAST(NULL AS STRING) AS order_type_agg,
        '42' AS cod_segmento,
        '05' AS cod_marca,
        '61' AS cod_tipo_contrato,
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

      FROM `mm-commissions-reporting.TEMP.nnss_base_202601_v2` base
      LEFT JOIN `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
        ON base.id_comisionista = dealers.id_comisionista
      WHERE base.fecha_ini BETWEEN fecha_inicio AND fecha_fin
        AND base.fecha_final = '9999-12-31'
        AND dealers.comisiona = TRUE
        AND base.agrupacion_canal = 'B2B - Netllar' and base.Empresa != '34- lavall'

    )
    ;



    CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.clawback_nss_202601_v2` as (
    select
      'calculado' as estado, 
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      base.agrupacion_canal,
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NTCLI'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'HICLI'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'OCE'
        ELSE NULL
      END AS canal, 
      CASE 
      WHEN  Level_0 = 'INTERNET MINORISTA'   then  'E - Servicio base fibra' 
      WHEN  level_0 = 'TELEFONIA MÓVIL'     then   'E - Servicio base movil'
      ELSE NULL END AS concepto, 
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'UPF1'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'UPFN'
        WHEN base.agrupacion_canal = 'B2B - Hits' THEN 'UPFH'
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'UPFN'
        ELSE NULL
      END AS tipo_concepto, 
      -1 AS unidades,
      CASE 
        WHEN Level_2 = 'INTERNET FIBRA CM' AND DATE_DIFF(base.fecha_final, base.fecha_ini, DAY) < 92 THEN -120
        WHEN Level_2 = 'INTERNET FIBRA CM' AND DATE_DIFF(base.fecha_final, base.fecha_ini, DAY) >= 92 THEN -60
        WHEN level_2 = 'MOVIL TARIFA CM' AND DATE_DIFF(base.fecha_final, base.fecha_ini, DAY) < 92 THEN base.comision * (-1)
        ELSE 0
      END AS comision,
      base.id_comisionista,  
      base.id_comisionista as distribuidor, 
      base.id_comisionista as sfid_id,  
      base.Empresa as seller, 
      dealers.nombre_comercio, 
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
        ELSE 'INTERNET'
      END AS service_type, 
      base.phone_nm AS phone_nm, 
      base.no AS tariff_id,  
      base.description AS tariff_ds, 
      CONCAT(base.num_contrato, base.num_linea) AS service_id, 
      base.num_contrato AS account_id, 
      base.cliente AS customer_id,  
      CAST(NULL AS STRING) AS line_type_ds,
      CASE 
        WHEN Level_2 = 'INTERNET FIBRA CM' and base.Jerarquia_Paquete IN ('4+3+2', '2+4+3')    THEN 'FMC'  
        WHEN Level_2 = 'INTERNET FIBRA CM' and base.Level_3 LIKE '%CONV%' THEN 'FMC'
        WHEN Level_2 = 'INTERNET FIBRA CM' and base.Level_3 NOT LIKE '%CONV%' THEN '2P'
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
        WHEN level_0 = 'INTERNET MINORISTA' THEN '61'
        WHEN level_0 = 'TELEFONIA MÓVIL' THEN '20'
        ELSE '61'
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

    from `mm-commissions-reporting.TEMP.nnss_base_comisiones_202601_v2` base
    left join `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    on base.id_comisionista = dealers.id_comisionista
    WHERE base.fecha_ini < fecha_inicio 
    AND base.fecha_final BETWEEN fecha_inicio AND fecha_fin
    AND dealers.comisiona = TRUE
    AND DATE_DIFF(base.fecha_final, base.fecha_ini, DAY) < 183 
    -- AND NOT (
    --     base.empresa = '900- HITSMOBILE'
    --     AND base.salesperson_code LIKE '%TELEVENTA-01%'
    --   )
    );


  -- UNIMOS UPFRONT Y CLAWBACK


   CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.upfr_cbsr_nss_202601_v2` as (
    select * from  `mm-commissions-reporting.TEMP.upfronts_nss_202601_v2` 
    union all
    select * from  `mm-commissions-reporting.TEMP.clawback_nss_202601_v2` 
    );



   CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.comisiones_nss_202601_v2` as (
    SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
    FROM `mm-commissions-reporting.TEMP.upfr_cbsr_nss_202601_v2`

  )
    
;



 INSERT INTO `mm-commissions-reporting.TEMP.comisiones_nss_202601_v2` (
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
    prefijo || '_H'|| mes_string || ROW_NUMBER() OVER() AS commission_id, 
    estado, 
    mes_liquidado, 
    id_mes, 
    agrupacion_canal, 
    canal, 
    CASE 
      WHEN concepto ='A - Servicio base fibra' THEN 'H - Servicio base fibra'
      WHEN concepto ='A - Servicio base movil' THEN 'H - Servicio base movil'
    END AS concepto,
    tipo_concepto, 
    unidades,
    CASE 
      WHEN concepto ='A - Servicio base fibra' THEN 20
      WHEN concepto ='A - Servicio base movil' THEN 10
    END AS comision,
    'CL900-019431' as id_comisionista,
    'CL900-019431' as distribuidor,
    'CL900-019431' as sfid_id,
    seller,
    nombre_comercio,
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
  FROM `mm-commissions-reporting.TEMP.comisiones_nss_202601_v2`
  WHERE id_comisionista IN ('CL900-000327','CL900-014509')
    AND concepto IN ('A - Servicio base fibra','A - Servicio base movil');

    --comisionar netllar 55 upfront

  

-- -- EXTRACOMISION

--  INSERT INTO `mm-commissions-reporting.TEMP.comisiones_nss_202601_v2` (
--   commission_id,
--   estado,
--   mes_liquidado,
--   id_mes,
--   agrupacion_canal,
--   canal,
--   concepto,
--   tipo_concepto,
--   unidades,
--   comision,
--   id_comisionista,
--   distribuidor,
--   sfid_id,
--   seller,
--   nombre_comercio,
--   razon_social,
--   cif,
--   zona_fiscal,
--   cond_pago,
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
-- )
--   SELECT
--   prefijo || '_E'|| mes_string || ROW_NUMBER() OVER() AS commission_id, 
--   estado, 
--   mes_liquidado, 
--   id_mes, 
--   agrupacion_canal, 
--   canal, 
--   CASE 
--     WHEN concepto ='A - Servicio base fibra' THEN 'D - Extracomision Fibra'
--     WHEN concepto ='A - Servicio base movil' THEN 'D - Extracomision Movil'
--   END AS concepto,
--   tipo_concepto, 
--   unidades,
--   CASE 
--     WHEN concepto ='A - Servicio base fibra' THEN 55
--     WHEN concepto ='A - Servicio base movil' THEN 10
--   END AS comision,
--   id_comisionista,
--   distribuidor,
--   sfid_id,
--   seller,
--   nombre_comercio,
--   razon_social,
--   cif,
--   zona_fiscal,
--   cond_pago,
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
-- FROM `mm-commissions-reporting.TEMP.comisiones_nss_202601_v2`
-- INNER JOIN (
--   SELECT empresa
--   FROM `mm-commissions-reporting.GS.OBJETIVO_NETLLAR`
--   WHERE CAST(id_mes AS STRING) = '202601_v2' AND COMISIONA_FIBRA = 'SI'
-- ) objetivo_fibra
-- ON base.empresa = objetivo_fibra.empresa
-- WHERE agrupacion_canal IN ('B2B - Netllar')
--AND concepto IN ('A - Servicio base fibra')
--and id_comisionista not in  ('CL001-000027')
  --,'A - Servicio Movil CM');




    -- Actualización tabla transacciones --
    

-- call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
-- (
--   prefijo,
--   mes_int,
--   canales_pr,
--   'TEMP.comisiones_nss_202601_v2',
--   'ACTUALIZAR'
-- );

END