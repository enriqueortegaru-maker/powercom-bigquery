BEGIN

  DECLARE sql, prefijo, mes_string STRING;
  DECLARE fecha_inicio DATE;
  DECLARE fecha_fin DATE;
  DECLARE fecha_inicio_mes_siguiente DATE;

  SET mes_string = CAST(mes_int AS STRING);
  SET prefijo = '2RPAD';
  SET canales_pr = [ 'NASH', 'OCE', 'NTCLI'];

  -- Fechas dinámicas
  SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
  SET fecha_fin = DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 DAY);
  SET fecha_inicio_mes_siguiente = DATE_ADD(fecha_inicio, INTERVAL 1 MONTH);

  
  -- call `mm-commissions-reporting.COMISIONES.pr_nss_regu_cuenca`(202510,['NTCLI']);
  
  ---PASO 1
 
CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.regu_cuenca_idcomisionista_202608`
 AS (
  SELECT a.empresa, b.ID_COMISIONISTA,a.no AS cliente
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_customer_*` a
  LEFT JOIN `mm-commissions-reporting.GS.DELEGACION_NNS` b
  ON a.empresa = b.empresa AND COALESCE(a.delegacion,a.empresa) = COALESCE(b.ID_DELEGACION, b.EMPRESA)
  WHERE 1=1
  AND ID_COMISIONISTA IS NOT NULL
  AND a.empresa <> '900- HITSMOBILE'
  AND NOT (a.empresa = '74- NetllarGlobal' AND a.no NOT LIKE '%CL034-M%') -- LAVALL
  QUALIFY ROW_NUMBER () over (PARTITION BY  a.no ORDER BY last_date_mod DESC) = 1
)
  ;
  
  CREATE or REPLACE  TABLE  `mm-commissions-reporting.TEMP.regu_cuenca_lineas_idcomisionista` AS 
  
  
  SELECT a.* EXCEPT(fecha_inicio, fecha_fin, cliente,referencia_externa ,glob_dim_1_code, glob_dim_2_code),
  CAST(a.fecha_inicio AS DATE) AS fecha_ini,
  CASE
    WHEN CAST(a.fecha_fin AS DATE) = '1753-01-01' OR CAST(a.fecha_fin AS DATE) > '2026-08-31'  
    THEN '9999-12-31'
    ELSE CAST(a.fecha_fin AS DATE)
  END AS fecha_final,
  c.id_comisionista,
  b.cliente,
  COALESCE(a.cli_asociado,a.referencia_externa) as phone_nm,
  item.*
 
  FROM `mm-dwh-prod.00_SANDBOX_NNS.bi_lineas_contrato_20260906` a
  inner join `mm-dwh-prod.00_SANDBOX_NNS.bi_cabecera_contrato_20260906` b
    ON a.num_contrato = b.num_contrato
    LEFT JOIN `mm-commissions-reporting.TEMP.regu_cuenca_idcomisionista_202608` c
   ON a.empresa = c.empresa and b.cliente =c.cliente 
   left join `mm-dwh-prod.00_SANDBOX_NNS.bi_item_20260906` item
  ON a.producto = item.no
  WHERE COALESCE(a.cli_asociado,a.referencia_externa) in (
'621626412',
'606648942',
'675655890',
'646642233',
'624377914',
'692887756',
'642825397',
'722896301',
'610389431',
'637538737',
'651055968',
'722436206',
'693850895',
'651036286',
'622002930',
'622745707',
'663926653',
'633610437',
'623129741',
'642692429',
'633560559',
'633545029',
'611099588',
'623311730',
'667733656',
'609846064',
'628939607',
'689015856',
'608821448',
'661790219',
'613299165',
'699909877',
'669171196',
'642125782',
'692721751',
'691253215',
'669775340',
'639956363',
'675912487',
'698978612',
'624561026',
'623598175',
'642659211',
'654094804',
'622510691',
'687848151',
'675118847',
'618279414',
'605320872',
'622518633',
'664675162',
'690671949',
'667615945',
'692674951',
'667649024',
'669769291',
'602587146',
'622196703',
'604183297',
'722637261',
'722735821',
'633226991',
'722583093',
'722462978',
'639905953',
'661599789',
'669735725',
'622836650',
'633780621',
'624956966',
'665904473',
'600018858',
'629551794',
'603948454',
'659375107',
'671544945',
'615648358',
'628622239',
'607751827',
'615352173',
'633290417',
'633753284',
'610699013',
'697720193',
'643544812',
'643115759',
'622782576',
'661620608',
'647041377',
'622621932',
'690026037',
'620224460',
'633916720',
'622850763',
'652201005',
'633919615',
'633407092',
'699944757',
'686766351',
'633939327',
'722214988',
'695527814',
'722326087',
'633861903',
'722476967',
'622259718',
'601555908',
'644019756',
'609255152',
'602460172',
'659049106',
'670590916',
'622323724',
'654996723',
'620260134',
'677698755',
'626321778',
'670852315',
'682738621',
'603858277',
'642189975',
'697395996',
'637787299',
'695154580',
'642969268',
'605204145',
'657174840',
'667272379',
'623424464',
'622040697',
'615369440',
'687554907',
'697622760',
'667741834',
'686209761',
'619199898',
'605923284',
'675422951',
'604465868',
'615273334',
'625698781',
'682379712',
'661653452',
'653167000',
'653884121',
'659337127',
'620260131',
'627917202',
'656909095',
'629338280',
'624864823',
'653464556',
'642372120',
'676872468',
'626018160',
'625767444',
'678834545',
'642195679',
'669991929',
'646487753',
'698910557',
'722849640',
'694281099',
'722151984',
'650516281',
'653736156',
'650386459',
'698900685',
'629126160',
'665501873',
'628344983',
'642288625',
'630929083',
'619390073',
'687938573',
'692668437',
'665213819',
'673678085'

  );



 --paso 4 comisionr movil
  CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.altas_base_regu_cuenca` as (
    SELECT
      base.* EXCEPT (glob_dim_1_code, glob_dim_2_code),d.*EXCEPT(phone_nm),
      CASE 
        --WHEN base.Empresa =objetivo.Empresa and objetivo.COMISIONA_MOVIL ='NO' AND CAST(objetivo.id_mes AS STRING) = mes_string THEN 0 
        WHEN base.empresa =importe.empresa AND CAST(base.PVP AS FLOAT64) > 10 THEN importe.movil_menos_10
        WHEN base.empresa =importe.empresa AND CAST(base.PVP AS FLOAT64) < 10 THEN importe.movil_mayor_10
        ELSE 0
      END AS comision,
      importe.agrupacion_canal

    FROM `mm-commissions-reporting.TEMP.regu_cuenca_lineas_idcomisionista` base
 
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
    -- LEFT JOIN  `mm-commissions-reporting.GS.OBJETIVO_NETLLAR` objetivo
    -- ON base.empresa = objetivo.empresa AND CAST(objetivo.id_mes AS STRING) = mes_string 
    WHERE 1 = 1
    --base.num_contrato NOT IN (SELECT DISTINCT num_contrato FROM `mm-commissions-reporting.TEMP.nnss_base_202608` WHERE 1=1 AND bundle_type = '3P')
    AND base.description LIKE '%CM%'
    AND Level_0  ='TELEFONIA MÓVIL'
    AND LEVEL_1 ='PLANES Y TARIFAS'
    AND Level_2 ='MOVIL TARIFA CM'
    AND Level_3 NOT IN ('MÓVIL PAGO POR USO CM0123', 'MÓVIL PAGO POR USO CM0422', 'FIXED WIRELESS CM0422', 'FIXED WIRELESS DOUBLE CM0422', 'MÓVIL SUSPENSIÓN TEMPORAL CM1222')
    AND UPPER(description) NOT LIKE '%ADIC%'
    AND (base.alta = 1 OR base.alta_cambio_cm = 1)
    GROUP BY ALL
 );


    

    
    -- UPFRONT
    
    CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.upfronts_regu_cuenca_v2` as (
    SELECT
     'calculado' as estado, 
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      base.agrupacion_canal,
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NTCLI'
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
        WHEN base.agrupacion_canal = 'B2B - Oceans' THEN 'UPFN'
        ELSE NULL
      END AS tipo_concepto,
      1 AS unidades,
      base.comision,
      base.id_comisionista,  
      base.id_comisionista as distribuidor,
      base.id_comisionista as sfid_id,  
      CASE 
        WHEN base.empresa = '74- NetllarGlobal' THEN '34- lavall' 
        ELSE base.Empresa 
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
      base.id_comisionista AS customer_id,  
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

    FROM `mm-commissions-reporting.TEMP.altas_base_regu_cuenca` base
    LEFT JOIN `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    on base.id_comisionista = dealers.id_comisionista
    WHERE 1= 1
      AND base.fecha_ini BETWEEN fecha_inicio AND fecha_fin
      AND base.fecha_final = '9999-12-31'
      AND dealers.comisiona = TRUE
      AND base.agrupacion_canal <> 'B2B - Populoos' 
    )
    
    ;


 CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.clawback_regu_cuenca` as (
    select
      'calculado' as estado, 
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      base.agrupacion_canal,
      CASE 
        WHEN base.agrupacion_canal = 'B2B - Nash' THEN 'NASH'
        WHEN base.agrupacion_canal = 'B2B - Netllar' THEN 'NTCLI'
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
      CASE 
        WHEN base.empresa = '74- NetllarGlobal' THEN '34- lavall' 
        ELSE base.Empresa 
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
      base.id_comisionista AS customer_id,  
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

    from `mm-commissions-reporting.TEMP.altas_base_regu_cuenca` base
    left join `mm-commissions-reporting.GS.NETLLAR_DEALERS` dealers
    on base.id_comisionista = dealers.id_comisionista
    WHERE base.fecha_ini < fecha_inicio 
    AND base.fecha_final BETWEEN fecha_inicio AND fecha_fin
    AND dealers.comisiona = TRUE
    AND DATE_DIFF(base.fecha_final, base.fecha_ini, DAY) < 183 
    AND baja_cambio_tarifa = 0
    AND base.agrupacion_canal <> 'B2B - Populoos' 

    -- AND NOT (
    --     base.empresa = '900- HITSMOBILE'
    --     AND base.salesperson_code LIKE '%TELEVENTA-01%'
    --   )
    );


  -- UNIMOS UPFRONT Y CLAWBACK


   --CREATE or REPLACE TABLE  `mm-commissions-reporting.TEMP.comisiones_regu_cuenca` as (


    INSERT INTO `mm-commissions-reporting.TEMP.comisiones_regu_cuenca`
    select * from  `mm-commissions-reporting.TEMP.upfronts_regu_cuenca_v2` 
    union all
    select * from  `mm-commissions-reporting.TEMP.clawback_regu_cuenca` where comision <> 0

   --)
    ;


END