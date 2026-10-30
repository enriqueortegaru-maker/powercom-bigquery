BEGIN

DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'CABCAMP2'; 

SET canales_pr = ['CM','CALT'];

-- call `mm-commissions-reporting.COMISIONES.pr_arca_campanas_reg_cambio_tarifas`(202608,['CM','CALT'])

--Generación de tabla mensual de campañas historificada

CALL `mm-commissions-reporting.B2B.pr_campanas_base_general`(mes_int, ['CM','CALT']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CABCAMP2_DEALERS`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 

    dealers AS (
      SELECT * EXCEPT (nombre_comercio,zona_fiscal),
        UPPER(nombre_comercio) AS nombre_comercio,
        IF(zona_fiscal = '#N/A','PEN',zona_fiscal) AS zona_fiscal
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL`
      WHERE comisiona IS TRUE AND check_duplicados = '1'
    )

    SELECT *
    FROM dealers
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CABCAMP2_B_CARTERA`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH
 
    base_campana AS (
      SELECT a.*except(activation_date),b.activation_date, b.deactivation_date_act -- Cambiar fecha de activacion 
      FROM `mm-commissions-reporting.B2B.upfronts_base_arca_*` a
      --Cruzamos con la tabla que contiene la información del origen de la linea, si es primera linea, migracion, etc.
      LEFT JOIN (
        SELECT phone_nm, activation_date,deactivation_date AS deactivation_date_act, --first_activation_flag,grupo, primera_activacion
        -- FROM `mm-commissions-reporting.B2B.tipo_activacion_service`
        FROM `mm-commissions-reporting.TEMP.services_base_net_agrupado_CM`
      ) b 
        ON CONCAT(CAST(a.phone_nm AS STRING),'-',a.activation_date) = CONCAT(CAST(b.phone_nm AS STRING),'-',b.activation_date)
      WHERE 1=1
        AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
        AND (deactivation_date IS NULL OR deactivation_date = '9999-12-31'
            OR deactivation_date > DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH))
        -- AND NOT ((first_activation_flag = 'CAMBIO TARIFA' AND primera_activacion < (PARSE_DATE('%Y%m',mes_string))) 
        --   OR first_activation_flag = 'INTERCO' 
        --   OR first_activation_flag = 'MIGRACION MISMO GRUPO')
    )

    SELECT *
    FROM base_campana
    WHERE deactivation_date_act IS NULL OR deactivation_date_act >= DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CABCAMP2_CLAWBACK`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH

    base_clawback_general AS (

      --Transacciones
      SELECT a.* EXCEPT(deactivation_date,emails_acceso_trazabilidad),
        h.deactivation_date,
        b.comision_UPFR
      FROM `mm-commissions-reporting.COMISIONES.transacciones` a
      JOIN (
        SELECT service_id,phone_nm,activation_date,deactivation_date
        -- FROM `mm-datamart-kd.SERVICES.service_base_net` 
        FROM `mm-commissions-reporting.TEMP.services_base_net_agrupado_CM` -- Tabla de services pero agrupando los servicios por si son cambios de tarifa
        WHERE comm_brand_ds = 'CABLEMOVIL' 
      )h 
        ON SAFE_CAST(h.phone_nm AS STRING) = a.phone_nm 
          AND a.activation_date = h.activation_date
          
      --Agrupamos para determinar si hay importe pendiente por dar de baja. Si es igual a 0 no tiene que salir.
      LEFT JOIN (
        SELECT phone_nm, activation_date,SUM(comision) AS comision_UPFR
        FROM `mm-commissions-reporting.COMISIONES.transacciones`
        WHERE canal IN ('CM','CALT')
          AND tipo_concepto = 'UPFR'
        GROUP BY ALL
      )b 
        ON a.phone_nm = b.phone_nm 
        AND a.activation_date = b.activation_date

      -- JOIN (-- Cruce con el excel de campañas para solo calcular el clawback de las que estén ahí
      --   SELECT DISTINCT DEALER, categorizacion
      --   FROM base_campana_ini
      -- ) b ON a.customer_id = b.DEALER

      WHERE 1=1
        AND a.marca = 'CABLEMOVIL' 
        AND a.estado != 'calculado'
        AND a.tipo_concepto = 'UPFR'
        AND CAST(id_mes AS STRING) < mes_string
        --AND a.comision > 0
        -- Filtro con service para calcular las lineas que están desactivadas 
        AND h.deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m', mes_string),MONTH) AND LAST_DAY(PARSE_DATE('%Y%m', mes_string))
        AND DATE_DIFF(h.deactivation_date,h.activation_date, DAY) <= DATE_DIFF (LAST_DAY(PARSE_DATE('%Y%m', mes_string)), DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 11 MONTH), MONTH), DAY)
        --(LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)),DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), MONTH), DAY) DAY)
        AND a.concepto NOT LIKE '%2860' --Quitamos el cálculo del clawback de TMOVIL porque lo compró EXCOM y sus condiciones van por altas netas
    ),

    base_clawback_general_agrupado AS (
      SELECT
        TRANSACCIONES.agrupacion_canal,
        TRANSACCIONES.canal,
        IF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(concepto, 'D - ', 'E - '),'A - ', 'E - '),'C - ', 'E - '),'R - ','E - '),'Z - ','E - ') NOT LIKE 'E - %',CONCAT('E - ', concepto),REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(concepto, 'D - ', 'E - '),'C - ', 'E - '),'A - ', 'E - '),'R - ','E - '),'Z - ','E - ')) AS concepto,
        TRANSACCIONES.tipo_concepto,
        TRANSACCIONES.id_comisionista,
        TRANSACCIONES.nombre_comercio,
        TRANSACCIONES.razon_social,
        TRANSACCIONES.cif,
        TRANSACCIONES.zona_fiscal,
        TRANSACCIONES.cond_pago,
        TRANSACCIONES.marca,
        TRANSACCIONES.service_type,
        TRANSACCIONES.phone_nm,
        TRANSACCIONES.service_id,
        TRANSACCIONES.account_id,
        TRANSACCIONES.customer_id,
        TRANSACCIONES.billing_type_ds,
        TRANSACCIONES.sale_date,
        TRANSACCIONES.activation_date,
        TRANSACCIONES.deactivation_date,
        TRANSACCIONES.cod_segmento,
        TRANSACCIONES.cod_marca,
        TRANSACCIONES.cod_tipo_contrato,
        TRANSACCIONES.cod_producto,
        TRANSACCIONES.cod_canal,
        TRANSACCIONES.sociedad,
        MAX(TRANSACCIONES.bundle_type) AS bundle_type,
        MAX(TRANSACCIONES.campaign_code) AS campaign_code,
        MAX(TRANSACCIONES.line_type_ds) AS line_type_ds,
        MAX(TRANSACCIONES.order_id) AS order_id,
        MAX(TRANSACCIONES.order_type_agg) AS order_type_agg,
        MAX(TRANSACCIONES.serial_number) AS serial_number,
        MAX(TRANSACCIONES.tariff_ds) AS tariff_ds,
        MAX(TRANSACCIONES.tariff_id) AS tariff_id,
        MAX(TRANSACCIONES.tax_base) AS tax_base,
        MAX(TRANSACCIONES.technology_ds) AS technology_ds,
        MAX(TRANSACCIONES.comments) AS comments,
        SUM(TRANSACCIONES.comision) AS comision,
        REPLACE(REPLACE(TO_JSON_STRING(ARRAY_AGG(TRANSACCIONES.commission_id)), '[', ''), ']', '') AS process_code,
        COUNT(DISTINCT TRANSACCIONES.commission_id) AS commission_id_count,  
        comision_UPFR
      FROM base_clawback_general TRANSACCIONES
      WHERE 1=1
        AND comision_UPFR != 0
      GROUP BY ALL
    ),


    clawback_general_f AS (
      SELECT a.*,
        i.FECHA_PRORRATEO AS FECHA_PRORRATEO,
        ((EXTRACT(YEAR FROM a.deactivation_date) - EXTRACT(YEAR FROM  a.activation_date)) * 12 * 30 +
          (EXTRACT(MONTH FROM  a.deactivation_date) - EXTRACT(MONTH FROM  a.activation_date)) * 30 +
          (EXTRACT(DAY FROM  a.deactivation_date) - EXTRACT(DAY FROM  a.activation_date))) AS dias_mod,--Tomamos como media 30 días por cada mes 
        j.CLAWBACK_N_MESES * 30 AS CLAWBACK_N_MESES, --Transformamos los meses en días
        COALESCE(i.comentario,j.comentario,'BAJA DEL MES')AS comentario,
      FROM base_clawback_general_agrupado a
      LEFT JOIN(
        SELECT DISTINCT --OK
          DEALER,
          categorizacion,
          MSISDN,
          INCENTIVO_POR_ALTA,
          FECHA_PRORRATEO,
          CLAWBACK_PRORRATEADO,
          'BAJA PRORRATEADA' AS comentario
        --FROM `mm-commissions-reporting.TEMP.CABCAMP2_CAMPANAS` gs_campana_f
        FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_CM_*` gs_campana_f
        WHERE CLAWBACK_PRORRATEADO IS TRUE AND FECHA_PRORRATEO IS NOT NULL AND CLAWBACK IS TRUE
      ) i 
        ON a.concepto = i.categorizacion 
          AND i.MSISDN = a.phone_nm 
          AND ROUND(a.comision,2) = i.INCENTIVO_POR_ALTA 
          AND a.id_comisionista = i.DEALER
      LEFT JOIN (
          SELECT DISTINCT --OK
            categorizacion,
            DEALER,
            INCENTIVO_POR_ALTA,
            CLAWBACK_N_MESES,
            'BAJA N MESES' AS comentario
          -- FROM `mm-commissions-reporting.TEMP.CABCAMP2_CAMPANAS` gs_campana_f
          FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_CM_*` gs_campana_f
          WHERE CLAWBACK_N_MESES IS NOT NULL AND CLAWBACK IS TRUE
      ) j 
        ON a.concepto = j.CATEGORIZACION 
          AND a.id_comisionista = j.DEALER 
          AND a.comision = j.INCENTIVO_POR_ALTA
    ),

    clawback_n_meses AS (

      SELECT a.* EXCEPT(comision),
        a.comision AS comision_upfront,
        a.comision * -1 AS comision,
      FROM clawback_general_f a
      WHERE 1=1
        AND dias_mod <= CLAWBACK_N_MESES
        AND deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
        AND comentario = 'BAJA N MESES'
    ),

    clawback_del_mes AS (
      SELECT a.* EXCEPT(comision),
        a.comision AS comision_upfront,
        -1*a.comision AS comision
      FROM clawback_general_f a
      WHERE 1=1
        AND a.deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
        -- BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
        AND DATE_DIFF(a.deactivation_date,a.activation_date, DAY) <= DATE_DIFF (LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH)),DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 11 MONTH), MONTH), DAY)
        -- DATE_DIFF(deactivation_date,activation_date, DAY) <= DATE_DIFF (LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)),DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), MONTH), DAY)
      AND a.comentario = 'BAJA DEL MES'
    ),

    base_clawback_campana AS (
      SELECT *
      FROM clawback_del_mes
      UNION ALL
      SELECT *
      FROM clawback_N_meses
    )

    SELECT *
    FROM base_clawback_campana
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CABCAMP2_CARTERA_F`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH

    b_campanas AS(
      SELECT 
        'calculado' as estado,
        DATE_TRUNC(PARSE_DATE('%Y%m', mes_string),MONTH) as mes_liquidado, --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
        CAST(mes_string AS INT64) AS id_mes,
        CASE
            WHEN dealers.CANAL = 'CALT' THEN 'B2B - Cablemovil Alterna'
            ELSE 'B2B - Cablemovil'
          END AS agrupacion_canal,
        dealers.canal AS canal,
        CASE 
          WHEN base_campana.activation_date BETWEEN gs_campana_f.DESDE AND gs_campana_f.HASTA THEN CONCAT('D - ',REGEXP_REPLACE(INITCAP(gs_campana_f.CATEGORIZACION), r'\bId\b', 'ID'))
          ELSE 'No cruza'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        1 AS unidades,
        CASE
          WHEN gs_campana_f.PVP_BOOLEAN IS TRUE THEN `mm-commissions-reporting.CABLEOPERADORES.f_calculo_camp_N_PVP_CM`(gs_campana_f.DESDE, gs_campana_f.HASTA,gs_campana_f.TIPO_LINEA, CAST(base_campana.phone_nm AS STRING) ,gs_campana_f.INCENTIVO_POR_ALTA, base_campana.activation_date,base_campana.bundle_type, base_campana.tariff_ds, dealers.id_comisionista, base_campana.tariff_id, gs_campana_f.PVP_desde , gs_campana_f.PVP_hasta , base_campana.PVP_ARPU, base_campana.document_type,base_campana.operator_donor, gs_campana_f.OPERADORES_DONANTES, base_campana.group_donor)
          WHEN gs_campana_f.N_ACTIVACIONES_DESDE IS NOT NULL THEN `mm-commissions-reporting.CABLEOPERADORES.f_calculo_camp_N_activaciones_CM`(gs_campana_f.DESDE, gs_campana_f.HASTA,gs_campana_f.TIPO_LINEA, CAST(base_campana.phone_nm AS STRING) ,gs_campana_f.INCENTIVO_POR_ALTA, base_campana.activation_date,base_campana.bundle_type, base_campana.tariff_ds, dealers.id_comisionista, base_campana.tariff_id, gs_campana_f.n_activaciones_desde , gs_campana_f.n_activaciones_hasta, base_campana.document_type, b.tres_p,b.mobile_MO,b.AM,base_campana.operator_donor, gs_campana_f.OPERADORES_DONANTES)
          ELSE `mm-commissions-reporting.CABLEOPERADORES.f_calculo_campanas_CM`(gs_campana_f.DESDE, gs_campana_f.HASTA,gs_campana_f.TIPO_LINEA, CAST(base_campana.phone_nm AS STRING) ,gs_campana_f.INCENTIVO_POR_ALTA, base_campana.activation_date,base_campana.bundle_type, base_campana.tariff_ds, dealers.id_comisionista, base_campana.tariff_id, base_campana.document_type,base_campana.operator_donor, gs_campana_f.OPERADORES_DONANTES)
        END AS comision,
        base_campana.CLIENTE             AS id_comisionista,
        base_campana.CLIENTE             AS distribuidor,
        base_campana.CLIENTE             AS sfid_id,
        base_campana.CLIENTE             AS seller,
        dealers.nombre_comercio  AS nombre_comercio,
        dealers.nombre_comercio  AS razon_social,
        --UPPER(COALESCE(ventas_pers_mobile.CIF, ventas_pers_fibra.CIF, dealers.documento)) AS cif,
        dealers.documento AS cif,
        dealers.zona_fiscal      AS zona_fiscal,
        CAST(NULL AS STRING)     AS cond_pago,
        'CABLEMOVIL'             AS marca,
        base_campana.service_type        AS service_type,
        CAST(base_campana.phone_nm AS STRING)  AS phone_nm,
        base_campana.tariff_id           AS tariff_id,
        base_campana.tariff_ds           AS tariff_ds,
        base_campana.service_id          AS service_id,
        base_campana.account_id          AS account_id,
        base_campana.CLIENTE             AS customer_id,
        base_campana.line_type_ds        AS line_type_ds,
        base_campana.bundle_type         AS bundle_type,
        base_campana.service_type        AS technology_ds,
        CAST(NULL AS STRING)     AS billing_type_ds,
        base_campana.activation_date     AS sale_date,
        base_campana.activation_date     AS activation_date,
        IF(base_campana.deactivation_date IS NULL,'9999-12-31',base_campana.deactivation_date) AS deactivation_date,
        base_campana.account_id          AS order_id,
        CAST(NULL AS STRING)     AS order_type_agg,
        '42'                     AS cod_segmento,
        '05'                     AS cod_marca,
        CASE 
          --WHEN UPPER(base_campana.billing_Tier_2) = 'CUOTA MANTENIMIENTO LINEA' THEN '20'
          WHEN base_campana.service_type = 'FIX' THEN '61' 
          WHEN base_campana.service_type LIKE 'MOBILE' AND base_campana.bundle_type  = 'FMC' THEN '61' 
          ELSE '20'
        END                      AS cod_tipo_contrato,
        '30'                     AS cod_canal,
        '022'                    AS cod_producto,
        gs_campana_f.concepto    AS campaign_code,
        CAST(NULL AS STRING)     AS serial_number,
        CAST(NULL AS INT64)      AS tax_base,
        CAST(NULL AS STRING)     AS claim_code,
        CAST(NULL AS STRING)     AS process_code,
        CASE
          WHEN dealers.AUTO = 'NO' THEN 'No Autofactura'
          ELSE 'Autofactura'
        END AS comments,
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
        CAST(NULL AS STRING)     AS emails_acceso_trazabilidad,
        base_campana.PVP_ARPU
      FROM `mm-commissions-reporting.TEMP.CABCAMP2_B_CARTERA` base_campana 
      JOIN `mm-commissions-reporting.TEMP.CABCAMP2_DEALERS` dealers ON dealers.id_comisionista = base_campana.cliente
      -- JOIN `mm-commissions-reporting.TEMP.CABCAMP2_CAMPANAS` gs_campana_f ON gs_campana_f.dealer = base_campana.CLIENTE
      JOIN (
  SELECT *,
    -- Con esta función contamos cuántas reglas específicas (que no sean NULL) existen por cada distribuidor, rango de fechas y tipo de línea
    COUNTIF(OPERADORES_DONANTES IS NOT NULL) OVER(PARTITION BY dealer, DESDE, HASTA, TIPO_LINEA) AS tiene_reglas_especificas
  FROM (
    SELECT 
      dealer,
      DESDE,
      HASTA,
      TIPO_LINEA,
      OPERADORES_DONANTES,
      MAX(OPERADORES_MASORANGE) AS OPERADORES_MASORANGE,
      MAX(INCENTIVO_POR_ALTA) AS INCENTIVO_POR_ALTA,
      MAX(CATEGORIZACION) AS CATEGORIZACION,
      MAX(CONCEPTO) AS concepto,
      MAX(PVP_BOOLEAN) AS PVP_BOOLEAN,
      MAX(PVP_DESDE) AS PVP_desde,
      MAX(PVP_HASTA) AS PVP_hasta,
      MAX(N_ACTIVACIONES_DESDE) AS N_ACTIVACIONES_DESDE,
      MAX(N_ACTIVACIONES_HASTA) AS N_ACTIVACIONES_HASTA,
    FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_CM_*`
    WHERE _TABLE_SUFFIX = CONCAT(mes_string,'01')
    GROUP BY 
      dealer, 
      DESDE, 
      HASTA, 
      TIPO_LINEA, 
      OPERADORES_DONANTES
  )
) gs_campana_f 
  ON gs_campana_f.dealer = base_campana.CLIENTE 
  AND base_campana.activation_date BETWEEN gs_campana_f.DESDE AND gs_campana_f.HASTA
  
  -- 2. CRUCE ESTRICTO DE TECNOLOGÍA (TIPO_LINEA)
  AND (
    (gs_campana_f.TIPO_LINEA = 'AM' AND base_campana.bundle_type IN ('MO','FMC')) OR
    (gs_campana_f.TIPO_LINEA = 'MO' AND base_campana.bundle_type = 'MO') OR
    (gs_campana_f.TIPO_LINEA = 'MO EMPRESAS (CIF)' AND base_campana.bundle_type = 'MO' AND base_campana.document_type = 'CIF')
  )
  
  -- 3. CRUCE DE OPERADOR DONANTE SIN SUBQUERIES
  AND (
    -- Si coincide con el donante específico de la línea
    gs_campana_f.OPERADORES_DONANTES = base_campana.group_donor
    OR (
      -- O si la campaña es de tipo "comodín" (NULL) y para este distribuidor y tecnología NO se crearon reglas para operadores específicos
      gs_campana_f.OPERADORES_DONANTES IS NULL 
      AND gs_campana_f.tiene_reglas_especificas = 0
    )
  )
      LEFT JOIN (
  SELECT DISTINCT 
    CLIENTE,
    DESDE,
    HASTA,
    SUM(IF(bundle_type = 'FMC', 1,0)) AS tres_P,
    SUM(IF(bundle_type = 'MO', 1,0)) AS mobile_MO,
    SUM(IF(bundle_type IN ('MO','FMC'), 1,0)) AS AM,
  FROM `mm-commissions-reporting.TEMP.CABCAMP2_B_CARTERA` base_campana
  LEFT JOIN (
    SELECT DISTINCT 
      dealer, 
      OPERADORES_MASORANGE,
      desde,
      hasta,
      fecha_campana 
    FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_CM_*` gs_campana_f
    WHERE _TABLE_SUFFIX = CONCAT(mes_string,'01')
  ) gs_campana_f ON gs_campana_f.dealer = base_campana.CLIENTE
  WHERE 1=1
    AND activation_date BETWEEN DESDE AND HASTA
    AND fecha_campana = LAST_DAY(PARSE_DATE('%Y%m', mes_string))
    AND NOT (group_donor IN ('MASORANGE','GRUPO MASMOVIL','ORANGE') AND OPERADORES_MASORANGE IS TRUE)
  GROUP BY ALL
) b ON base_campana.CLIENTE = b.CLIENTE AND base_campana.activation_date BETWEEN b.DESDE AND b.HASTA

WHERE 1=1
  AND NOT (group_donor IN ('MASORANGE','GRUPO MASMOVIL','ORANGE') AND gs_campana_f.OPERADORES_MASORANGE IS TRUE)
    )

    SELECT *
    FROM b_campanas
    WHERE comision != 0
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CABCAMP2_CLAWBACK_F`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH

    b_clawback_campanas AS(

      SELECT 
        'calculado' as estado,
        DATE_TRUNC(PARSE_DATE('%Y%m', mes_string),MONTH) as mes_liquidado, --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
        CAST(mes_string AS INT64) AS id_mes,
        agrupacion_canal,
        a.canal,
        a.concepto,
        tipo_concepto,
        -1 AS unidades,
        comision AS comision,
        a.id_comisionista,
        a.id_comisionista AS distribuidor,
        a.id_comisionista AS sfid_id,
        a.id_comisionista AS seller,
        a.nombre_comercio,
        a.razon_social,
        a.cif,
        a.zona_fiscal,
        dealers.cond_pago     AS cond_pago,
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
        cod_canal,
        cod_producto,
        campaign_code,
        CAST(NULL AS STRING)     AS serial_number,
        tax_base,
        CAST(NULL AS STRING)     AS claim_code,
        process_code,
        CASE
          WHEN dealers.AUTO = 'NO' THEN 'No Autofactura'
          ELSE 'Autofactura'
        END AS comments,
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
        CAST(NULL AS STRING)     AS emails_acceso_trazabilidad,
      FROM `mm-commissions-reporting.TEMP.CABCAMP2_CLAWBACK` a --b_clawback_campanas
      JOIN `mm-commissions-reporting.TEMP.CABCAMP2_DEALERS` dealers 
        ON dealers.id_comisionista = a.id_comisionista
    )

    SELECT *
    FROM b_clawback_campanas
    WHERE comision != 0
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_campanas_arca` AS

  WITH

    final AS (

      SELECT 
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
      FROM `mm-commissions-reporting.TEMP.CABCAMP2_CARTERA_F` b_campanas

      -- UNION ALL

      -- SELECT 
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
      -- FROM `mm-commissions-reporting.TEMP.CABCAMP2_CLAWBACK_F` b_clawback_campanas
    )


    SELECT 
      prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
      final.*
    FROM final
  ;
  
-- Actualización tabla final --

-- call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
-- (
--   prefijo,
--   mes_int,
--   canales_pr,
--   'TEMP.comisiones_campanas_arca',
--   'ACTUALIZAR'
-- );

--Valicaciones--

--Se hacen automáticas cuando se lanza la liqui desde el googlesheet
-- CALL `mm-commissions-reporting.COMISIONES.pr_validaciones_B2BC`(mes_int, canales_pr)
-- ;

END