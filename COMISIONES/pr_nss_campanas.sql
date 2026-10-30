BEGIN

-- call `mm-commissions-reporting.COMISIONES.pr_nss_campanas`(202609, ['NASH', 'NTCLI', 'HICLI', 'OCE'])

DECLARE sql, prefijo, mes_string STRING;
DECLARE fecha_inicio DATE;
DECLARE fecha_fin DATE;
DECLARE fecha_inicio_mes_siguiente DATE;

SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'NSSCAMP';
SET canales_pr = [ 'NASH', 'OCE', 'NTCLI', 'HICLI'];

-- Fechas dinámicas del mes actual de liquidación
SET fecha_inicio = DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH);
SET fecha_fin = DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 DAY);
SET fecha_inicio_mes_siguiente = DATE_ADD(fecha_inicio, INTERVAL 1 MONTH);

-- Generación de tabla mensual de campaña
CALL `mm-commissions-reporting.B2B.pr_campanas_base_general`(mes_int, ['NASH', 'NTCLI', 'HICLI', 'OCE']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.NNSCAMP_B_CARTERA`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)) AS
  SELECT *
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE concepto like 'A%' 
    AND canal IN ('NTCLI', 'HICLI');

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.NNSCAMP_CARTERA_F`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)) AS

  -- ==========================================
  -- BLOQUE 1: CAMPAÑAS MENSUALES ESTÁNDAR
  -- ==========================================
  WITH campanas_mensuales AS (
    SELECT 
      'calculado' AS estado, base_campana.mes_liquidado, base_campana.id_mes, base_campana.agrupacion_canal, 
      base_campana.canal, base_campana.id_comisionista, base_campana.sfid_id, base_campana.seller, 
      base_campana.nombre_comercio, base_campana.cif, base_campana.zona_fiscal, base_campana.marca, 
      base_campana.service_type, base_campana.phone_nm, base_campana.tariff_id, base_campana.tariff_ds, 
      base_campana.service_id, base_campana.account_id, base_campana.customer_id, base_campana.line_type_ds, 
      base_campana.bundle_type, base_campana.deactivation_date, base_campana.comments, base_campana.activation_date,
      gs_campana_f.concepto AS campaign_code,
      gs_campana_f.CATEGORIZACION,
      gs_campana_f.DESDE,
      gs_campana_f.HASTA,
      `mm-commissions-reporting.CABLEOPERADORES.f_calculo_camp_N_PVP_NNS`(
        gs_campana_f.DESDE, gs_campana_f.HASTA, CAST(base_campana.phone_nm AS STRING), gs_campana_f.INCENTIVO_POR_ALTA, 
        base_campana.activation_date, base_campana.id_comisionista, base_campana.bundle_type, 
        b_mes.tres_P_mes, b_mes.dos_P_mes, b_mes.MO_mes, 
        gs_campana_f.N_ACTIVACIONES_DESDE, gs_campana_f.N_ACTIVACIONES_HASTA
      ) AS comision_calculada
    FROM `mm-commissions-reporting.TEMP.NNSCAMP_B_CARTERA` base_campana
    JOIN (
      SELECT * FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_NNS_*`
      WHERE _TABLE_SUFFIX = CONCAT(mes_string,'01') AND EXTRACT(MONTH FROM DESDE) = EXTRACT(MONTH FROM HASTA)
    ) gs_campana_f ON gs_campana_f.dealer = base_campana.id_comisionista AND LEFT(gs_campana_f.tipo_linea,1) = LEFT(base_campana.bundle_type,1) -- PARA COGER MA Y MO DE LA MISMA MANERA
    LEFT JOIN (
      SELECT 
        id_comisionista,
        SUM(IF(bundle_type = 'FMC', 1, 0)) AS tres_P_mes,
        SUM(IF(bundle_type = 'MO', 1, 0))  AS MO_mes,
        SUM(IF(bundle_type = '2P', 1, 0))  AS dos_P_mes
      FROM `mm-commissions-reporting.TEMP.NNSCAMP_B_CARTERA`
      WHERE unidades > 0 AND id_mes = mes_int
      GROUP BY id_comisionista
    ) b_mes ON base_campana.id_comisionista = b_mes.id_comisionista
    WHERE base_campana.id_mes = mes_int
      AND base_campana.activation_date BETWEEN gs_campana_f.DESDE AND gs_campana_f.HASTA
      AND (
        (base_campana.bundle_type = 'MO'  AND b_mes.MO_mes  BETWEEN gs_campana_f.N_ACTIVACIONES_DESDE AND gs_campana_f.N_ACTIVACIONES_HASTA) OR
        (base_campana.bundle_type = '2P'  AND b_mes.dos_P_mes BETWEEN gs_campana_f.N_ACTIVACIONES_DESDE AND gs_campana_f.N_ACTIVACIONES_HASTA) OR
        (base_campana.bundle_type = 'FMC' AND b_mes.tres_P_mes BETWEEN gs_campana_f.N_ACTIVACIONES_DESDE AND gs_campana_f.N_ACTIVACIONES_HASTA)
      )
  ),

  -- ==========================================
  -- BLOQUE 2: CAMPAÑAS TRIMESTRALES (Validación estricta de objetivos mínimos)
  -- ==========================================
  campanas_trimestrales AS (
    SELECT 
      'calculado' AS estado, base_campana.mes_liquidado, base_campana.id_mes, base_campana.agrupacion_canal, 
      base_campana.canal, base_campana.id_comisionista, base_campana.sfid_id, base_campana.seller, 
      base_campana.nombre_comercio, base_campana.cif, base_campana.zona_fiscal, base_campana.marca, 
      base_campana.service_type, base_campana.phone_nm, base_campana.tariff_id, base_campana.tariff_ds, 
      base_campana.service_id, base_campana.account_id, base_campana.customer_id, base_campana.line_type_ds, 
      base_campana.bundle_type, base_campana.deactivation_date, base_campana.comments, base_campana.activation_date,
      gs_campana_f.concepto AS campaign_code,
      gs_campana_f.CATEGORIZACION,
      gs_campana_f.DESDE,
      gs_campana_f.HASTA,
      `mm-commissions-reporting.CABLEOPERADORES.f_calculo_camp_N_PVP_NNS`(
        gs_campana_f.DESDE, gs_campana_f.HASTA, CAST(base_campana.phone_nm AS STRING), gs_campana_f.INCENTIVO_POR_ALTA, 
        base_campana.activation_date, base_campana.id_comisionista, base_campana.bundle_type, 
        b_trim.tres_P_trimestre, b_trim.dos_P_trimestre, b_trim.MO_trimestre, 
        gs_campana_f.N_ACTIVACIONES_DESDE, gs_campana_f.N_ACTIVACIONES_HASTA
      ) AS comision_calculada
    FROM `mm-commissions-reporting.TEMP.NNSCAMP_B_CARTERA` base_campana
    JOIN (
      SELECT * FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_NNS_*`
      WHERE _TABLE_SUFFIX = CONCAT(mes_string,'01') AND EXTRACT(MONTH FROM DESDE) != EXTRACT(MONTH FROM HASTA)
    ) gs_campana_f ON gs_campana_f.dealer = base_campana.id_comisionista AND LEFT(gs_campana_f.tipo_linea,1) = LEFT(base_campana.bundle_type,1)
    
    LEFT JOIN (
      SELECT 
        hist.id_comisionista,
        camp.DESDE,
        camp.HASTA,
        SUM(IF(hist.bundle_type = 'FMC', 1, 0)) AS tres_P_trimestre,
        SUM(IF(hist.bundle_type = 'MO', 1, 0))  AS MO_trimestre,
        SUM(IF(hist.bundle_type = '2P', 1, 0))  AS dos_P_trimestre
      FROM `mm-commissions-reporting.COMISIONES.transacciones` hist
      CROSS JOIN (
        SELECT DISTINCT dealer, DESDE, HASTA 
        FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_NNS_*`
        WHERE _TABLE_SUFFIX = CONCAT(CAST(mes_int AS STRING),'01') AND EXTRACT(MONTH FROM DESDE) != EXTRACT(MONTH FROM HASTA)
      ) camp
      WHERE hist.id_comisionista = camp.dealer
        AND (hist.concepto like 'A%' OR (hist.concepto like 'Z%' AND hist.comision > 0 AND hist.tipo_concepto LIKE 'UP%' ))
        AND hist.canal IN ('NTCLI', 'HICLI')
        AND hist.unidades > 0 
        AND hist.activation_date BETWEEN camp.DESDE AND camp.HASTA
      GROUP BY hist.id_comisionista, camp.DESDE, camp.HASTA
    ) b_trim ON base_campana.id_comisionista = b_trim.id_comisionista 
            AND gs_campana_f.DESDE = b_trim.DESDE 
            AND gs_campana_f.HASTA = b_trim.HASTA

    -- Filtro de control: Si el total acumulado no llega al objetivo mínimo (ej: 66 de 120), se tumba la línea entera
    WHERE base_campana.activation_date BETWEEN gs_campana_f.DESDE AND gs_campana_f.HASTA
      AND (
        (base_campana.bundle_type = 'MO'  AND b_trim.MO_trimestre  BETWEEN gs_campana_f.N_ACTIVACIONES_DESDE AND gs_campana_f.N_ACTIVACIONES_HASTA) OR
        (base_campana.bundle_type = '2P'  AND b_trim.dos_P_trimestre BETWEEN gs_campana_f.N_ACTIVACIONES_DESDE AND gs_campana_f.N_ACTIVACIONES_HASTA) OR
        (base_campana.bundle_type = 'FMC' AND b_trim.tres_P_trimestre BETWEEN gs_campana_f.N_ACTIVACIONES_DESDE AND gs_campana_f.N_ACTIVACIONES_HASTA)
      )
  ),




  -- ==========================================
  -- UNIÓN DE CÁLCULOS
  -- ==========================================
  union_campanas AS (
    SELECT * FROM campanas_mensuales
    UNION ALL
    SELECT * FROM campanas_trimestrales
  )

  SELECT 
    'calculado'AS estado,
    union_campanas.mes_liquidado,
    mes_int AS id_mes,
    union_campanas.agrupacion_canal,
    union_campanas.canal,
    CASE 
      WHEN union_campanas.activation_date BETWEEN union_campanas.DESDE AND union_campanas.HASTA THEN UPPER(CONCAT('D - ',REGEXP_REPLACE(INITCAP(union_campanas.CATEGORIZACION), r'\bId\b', 'ID')))
      ELSE 'No cruza'
    END AS concepto,
    CASE 
      WHEN union_campanas.agrupacion_canal = 'B2B - Nash' THEN 'UPF1'
      WHEN union_campanas.agrupacion_canal = 'B2B - Netllar' THEN 'UPFN'
      WHEN union_campanas.agrupacion_canal = 'B2B - Oceans' THEN 'UPFN'
      WHEN union_campanas.agrupacion_canal = 'B2B - Hits' THEN 'UPFH'
      ELSE NULL
    END AS tipo_concepto,
    1 AS unidades,
    union_campanas.comision_calculada AS comision,
    union_campanas.id_comisionista,
    union_campanas.id_comisionista AS distribuidor,
    union_campanas.sfid_id,
    union_campanas.seller,
    union_campanas.nombre_comercio,
    union_campanas.nombre_comercio AS razon_social,
    union_campanas.cif,
    union_campanas.zona_fiscal,
    CAST(NULL AS STRING) AS cond_pago,
    union_campanas.marca,
    union_campanas.service_type,
    CAST(union_campanas.phone_nm AS STRING) AS phone_nm,
    union_campanas.tariff_id,
    union_campanas.tariff_ds,
    union_campanas.service_id,
    union_campanas.account_id,
    union_campanas.customer_id,
    union_campanas.line_type_ds,
    union_campanas.bundle_type,
    union_campanas.service_type AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    union_campanas.activation_date AS sale_date,
    union_campanas.activation_date AS activation_date,
    IF(union_campanas.deactivation_date IS NULL,'9999-12-31',union_campanas.deactivation_date) AS deactivation_date,
    union_campanas.account_id AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '42' AS cod_segmento,
    '05' AS cod_marca,
    CASE WHEN union_campanas.bundle_type IN ('2P', 'FMC') THEN '61' ELSE '20' END AS cod_tipo_contrato,
    '30' AS cod_canal,
    '022' AS cod_producto,
    union_campanas.campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS INT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    union_campanas.comments,
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
    CAST(NULL AS STRING) AS emails_acceso_trazabilidad
  FROM union_campanas
  WHERE union_campanas.comision_calculada > 0; -- <-- Limpieza final: Si no genera dinero por no llegar a objetivos, va fuera de la tabla.




  -- ==========================================
  -- BLOQUE 3: CLAWBACKS
  -- ==========================================


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.NNSCAMP_clawback` AS

  -- Nuestra base será todas aquellas líneas que se les ha pagado campaña en los últimos 12 meses.
  -- Después cruzamos con nuestra base de clawback, donde se encuentran todas las líneas con fecha baja el mes en curso
  
  WITH base_clawback AS (

    SELECT *
    FROM `mm-commissions-reporting.COMISIONES.transacciones` 
    WHERE 1 = 1
      AND canal IN ('NTCLI', 'HICLI') 
      AND (concepto LIKE 'D%' or concepto LIKE '%Camp%' or concepto LIKE 'Z%')
      AND estado = 'facturado'
      AND concepto <> 'D - Extracomision Fibra' AND concepto <> 'Z - Extracomision Fibra' AND concepto NOT LIKE 'Z - Servicio%' AND concepto NOT LIKE 'Z - Gestion%'
      AND mes_liquidado >=  DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 YEAR)

    
  ),

  bajas_hits AS (

    SELECT b.*, a.fecha_ini, a.fecha_final
    FROM `mm-commissions-reporting.TEMP.hits_base_comisiones` a
    INNER JOIN base_clawback b
    ON a.id_comisionista = b.id_comisionista AND a.phone_nm = b.phone_nm
    WHERE fecha_ini >=  DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 YEAR)

    QUALIFY ROW_NUMBER () OVER (PARTITION BY a.phone_nm, b.concepto ORDER BY a.fecha_final DESC) = 1

      
  ),

  bajas_netllar AS (

    SELECT b.*, a.fecha_ini, a.fecha_final
    FROM `mm-commissions-reporting.TEMP.nnss_base_comisiones` a
    INNER JOIN base_clawback b
    ON a.id_comisionista = b.id_comisionista AND a.phone_nm = b.phone_nm
    WHERE fecha_ini >=  DATE_SUB(DATE_ADD(fecha_inicio, INTERVAL 1 MONTH), INTERVAL 1 YEAR)

    QUALIFY ROW_NUMBER () OVER (PARTITION BY a.phone_nm, b.concepto ORDER BY a.fecha_final DESC) = 1

  ),

  bajas_total AS (

    SELECT * FROM bajas_hits 
    WHERE fecha_final BETWEEN fecha_inicio AND fecha_fin

    UNION ALL

    SELECT * FROM bajas_netllar 
    WHERE fecha_final BETWEEN fecha_inicio AND fecha_fin
  )
  
  

  SELECT 
    'calculado'AS estado,
    fecha_inicio AS mes_liquidado,
    mes_int AS id_mes,
    agrupacion_canal,
    canal,
    REGEXP_REPLACE(concepto, r'^[DZ] - ', 'E - ') AS concepto,  
    tipo_concepto,
    -1 AS unidades,
    -1* a.comision as comision,
    id_comisionista,
    id_comisionista AS distribuidor,
    sfid_id,
    seller,
    nombre_comercio,
    nombre_comercio AS razon_social,
    cif,
    zona_fiscal,
    CAST(NULL AS STRING) AS cond_pago,
    marca,
    service_type,
    CAST(a.phone_nm AS STRING) AS phone_nm,
    tariff_id,
    tariff_ds,
    service_id,
    account_id,
    customer_id,
    line_type_ds,
    bundle_type,
    service_type AS technology_ds,
    CAST(NULL AS STRING) AS billing_type_ds,
    activation_date AS sale_date,
    activation_date,
    fecha_final AS deactivation_date,
    account_id AS order_id,
    CAST(NULL AS STRING) AS order_type_agg,
    '42' AS cod_segmento,
    '05' AS cod_marca,
    CASE WHEN a.bundle_type IN ('2P', 'FMC') THEN '61' ELSE '20' END AS cod_tipo_contrato,
    '30' AS cod_canal,
    '022' AS cod_producto,
    campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS INT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    comments,
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
    CAST(NULL AS STRING) AS emails_acceso_trazabilidad
  FROM bajas_total a
 ;



-- Vuelco de datos a la tabla temporal definitiva
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.COMISIONES_CAMPANAS_NNS` AS
  WITH final AS (
    SELECT * FROM `mm-commissions-reporting.TEMP.NNSCAMP_CARTERA_F`

      UNION ALL

    SELECT * FROM `mm-commissions-reporting.TEMP.NNSCAMP_clawback`
  )
  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    final.*
  FROM final;


  -- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.COMISIONES_CAMPANAS_NNS',
  'ACTUALIZAR'
);

--Valicaciones--

--Se hacen automáticas cuando se lanza la liqui desde el googlesheet
-- CALL `mm-commissions-reporting.COMISIONES.pr_validaciones_B2BC`(mes_int, canales_pr)
-- ;


END