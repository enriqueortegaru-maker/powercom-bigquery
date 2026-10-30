BEGIN

-- NUEVA BASE

DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARPA';

--CÁLCULO DE LA CARTERA Y UPFRONT 
-- call `mm-commissions-reporting.COMISIONES.pr_arpa`(202608,['PAR']);


--CÁLCULO DEL CLAWBACK POR EL CBSR
-- call `mm-commissions-reporting.COMISIONES.pr_cbsr`(202604, ['PAR']);

CALL `mm-commissions-reporting.COMISIONES.pr_clawback_parlem_deactivations`();

-------------------------------------------------------------------------------VALIDACIONES----------------------------------------------------------------------------------------

  --🔸 Validador 1: verificamos que estan todas las tarifas

  ASSERT NOT EXISTS ((--Si se modifica hay que actualizarlo también en App Script

    SELECT a.tariff_id, a.tariff_ds,
    FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` a
    LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_PAR` c ON a.tariff_id = c.tariff_id
    WHERE a.comm_brand_ds = 'PARLEM' 
      AND c.tariff_id IS NULL
      AND (a.deactivation_date IS NULL OR a.deactivation_date = '9999-12-31')
      AND a.activation_date IS NOT NULL
      AND a.activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH), MONTH)
      AND a.tariff_id IS NOT NULL
      AND a.tariff_ds != 'TARIFA FIX'
    GROUP BY ALL

    UNION ALL

    SELECT DISTINCT a.tariff_id, a.tariff_ds,
    FROM `mm-commissions-reporting.B2B.comisiones_base_arpa_*` a
    LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_PAR` c ON a.tariff_id = c.tariff_id
    WHERE 1=1 
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND a.comm_brand_ds = 'PARLEM' 
      AND c.tariff_id IS NULL  
      AND (a.deactivation_date IS NULL OR a.deactivation_date = '9999-12-31')
      AND a.activation_date IS NOT NULL
      AND a.activation_date <= last_day(PARSE_DATE('%Y%m',mes_string)) -- LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH), MONTH)
      AND a.tariff_id IS NOT NULL
      AND a.tariff_ds != 'TARIFA FIX'
    GROUP BY ALL

  )) AS 'Faltan tarifas por definir'
  ;

  --🔸 Validador 2: verificamos que estan todos los dealers

  ASSERT NOT EXISTS(--Si se modifica hay que actualizarlo también en App Script

    SELECT DISTINCT a.sfid_id
    FROM `mm-commissions-reporting.B2B.comisiones_base_arpa_*` a
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_PARLEM` b ON a.sfid_id = b.id_comisionista
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND a.comm_brand_ds = 'PARLEM' 
      AND b.id_comisionista IS NULL 
      AND a.activation_date >= DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
      AND a.sfid_id != 'NULL'

  ) AS 'Faltan dealers por definir'
  ;
-- -----------------------------------------------------------------------------FIN VALIDACIONES--------------------------------------------------------------------------------------


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arpa` AS

WITH

  base_cartera AS (

    SELECT *
    FROM `mm-commissions-reporting.B2B.comisiones_base_arpa_*`
    WHERE _TABLE_SUFFIX = CONCAT(mes_string,'01')

  ),

  base_upfront AS (

    SELECT a.*
    FROM `mm-commissions-reporting.B2B.upfronts_base_arpa_*` a
    --Cruzamos con la tabla que contiene la información del origen de la linea, si es primera linea, migracion, etc.
      LEFT JOIN (
        SELECT phone_nm, activation_date, first_activation_flag,grupo
        FROM `mm-commissions-reporting.B2B.tipo_activacion_service`
      ) b ON CONCAT(CAST(a.phone_nm AS STRING),'-',a.activation_date) = CONCAT(CAST(b.phone_nm AS STRING),'-',b.activation_date) 
    WHERE 1=1 
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND first_activation_flag NOT IN ('CAMBIO TARIFA','INTERCO','MIGRACION MISMO GRUPO')
  ),

  dealers AS (

    SELECT *
    FROM `mm-commissions-reporting.GS.DEALERS_PARLEM`
    WHERE comisiona IS TRUE
  ),
  
  dt AS (

    SELECT DISTINCT a.tariff_id, 
      a.tariff_ds, 
      a.tipo_paquete, 
      a.cuota,a.cuota_bts, 
      a.porcentaje_extra_consumo, 
      a.porcentaje_cartera_voz_y_datos AS Por_comision, 
      a.service_type, 
      line_type,tipo_fibra, 
      campana_activaciones_3P
    FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_PAR` a 
    WHERE marca = 'PARLEM'
  ),
  
  b AS(

    SELECT 
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) 
      CAST(mes_string AS INT64) AS id_mes, 
      'B2B - Parlem'  AS agrupacion_canal,
      dealers.canal   AS canal,
      base.billing_tier_1,
      base.imp_without_tax,
      CASE
        --WHEN base.billing_tier_1 LIKE 'CONSUM%' OR base.billing_tier_1 LIKE 'BONO%' THEN 'C - Extraconsumo (36%)'
        WHEN (base.billing_tier_1 LIKE 'CONSUM%' OR base.billing_tier_1 LIKE 'BONO%') AND base.TIPO_PAQUETE IN ('FMC', 'MO') THEN 'C - Extraconsumo (36%)'
        WHEN (base.billing_tier_1 LIKE 'CONSUM%' OR base.billing_tier_1 LIKE 'BONO%') AND base.TIPO_PAQUETE IN ('2P') THEN 'C - Extraconsumo (38%)'
        WHEN base.TIPO_PAQUETE = 'MO' THEN (
          CASE
            WHEN dt.por_comision IS NULL     THEN CONCAT('C - Gestion Cartera Movil ','(',0,'%)')
            WHEN dt.por_comision IS NOT NULL THEN CONCAT('C - Gestion Cartera Movil ','(',dt.por_comision,'%)')
            ELSE 'C - Gestion Cartera Resto (0%)'
          END
        )
        WHEN base.TIPO_PAQUETE = 'FMC' THEN (
          CASE
            WHEN base.service_type = 'MOBILE' AND dt.por_comision IS NULL THEN CONCAT('C - Gestion Cartera 3P ','(',0,'%)')
            WHEN base.service_type = 'MOBILE' AND base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' AND first_territory_ds = 'BITSTREAM' THEN CONCAT('C - Gestion Cartera 3P ','(',cuota_bts,'%)')
            WHEN base.service_type = 'MOBILE' AND base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' AND (first_territory_ds != 'BITSTREAM' OR first_territory_ds IS NULL) THEN CONCAT('C - Gestion Cartera 3P ','(',cuota,'%)')
            WHEN base.service_type = 'MOBILE'                                                   THEN CONCAT('C - Gestion Cartera 3P ','(',dt.por_comision,'%)')
            WHEN Cuota IS NULL                                                                  THEN CONCAT('C - Gestion Cartera 3P ','(',0,'%)')
            WHEN first_territory_ds LIKE 'BST%' AND base.service_type IN ('FIX','INTERNET')     THEN CONCAT('C - Gestion Cartera 3P ','(',cuota_bts,'%)')
            WHEN (first_territory_ds NOT LIKE 'BST%' OR first_territory_ds IS NULL) AND base.service_type IN ('FIX','INTERNET') THEN CONCAT('C - Gestion Cartera 3P ','(',Cuota,'%)')
            ELSE 'C - Gestion Cartera Resto (0%)'
          END
        )
        WHEN base.TIPO_PAQUETE = '2P' THEN (
          CASE
            WHEN Cuota IS NULL                                                                  THEN CONCAT('C - Gestion Cartera 2P ','(',0,'%)')
            WHEN first_territory_ds LIKE 'BST%' AND base.service_type IN ('FIX','INTERNET')     THEN CONCAT('C - Gestion Cartera 2P ','(',cuota_bts,'%)')
            WHEN (first_territory_ds NOT LIKE 'BST%' OR first_territory_ds IS NULL) AND base.service_type IN ('FIX','INTERNET') THEN CONCAT('C - Gestion Cartera 2P ','(',Cuota,'%)')
            ELSE 'C - Gestion Cartera Resto (0%)'
          END          
        )
        ELSE 'C - Gestion Cartera Resto (0%)'
      END AS concepto,
      'AIRT' AS tipo_concepto,
      1 AS unidades,
      CASE
        --WHEN base.billing_tier_1 LIKE 'CONSUM%' OR base.billing_tier_1 LIKE 'BONO%' THEN base.imp_without_tax*0.36
        WHEN (base.billing_tier_1 LIKE 'CONSUM%' OR base.billing_tier_1 LIKE 'BONO%') AND base.TIPO_PAQUETE IN ('FMC', 'MO') THEN base.imp_without_tax*0.36
        WHEN (base.billing_tier_1 LIKE 'CONSUM%' OR base.billing_tier_1 LIKE 'BONO%') AND base.TIPO_PAQUETE IN ('2P') THEN base.imp_without_tax*0.38
        WHEN base.service_type = 'MOBILE' THEN (
          CASE
            WHEN dt.por_comision IS NULL                                                                                                                   THEN 0
            WHEN base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' AND first_territory_ds = 'BITSTREAM'                                             THEN base.imp_without_tax*cuota_bts/100
            WHEN base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' AND (first_territory_ds != 'BITSTREAM' OR first_territory_ds IS NULL) THEN base.imp_without_tax*cuota/100
            WHEN (base.line_type_ds != 'MAIN' AND base.TIPO_PAQUETE = 'FMC') OR base.TIPO_PAQUETE != 'FMC'                                                 THEN base.imp_without_tax*dt.por_comision/100
            ELSE 0
          END
        )
        WHEN base.service_type IN ('FIX','INTERNET') THEN (
          CASE
            WHEN Cuota IS NULL                                                      THEN 0
            WHEN first_territory_ds = 'BITSTREAM'                                   THEN base.imp_without_tax*Cuota_BTS/100
            WHEN (first_territory_ds != 'BITSTREAM' OR first_territory_ds IS NULL)  THEN base.imp_without_tax*Cuota/100
            ELSE 0
          END
        )
        ELSE 0
      END AS comision,
      base.CLIENTE            AS id_comisionista,
      base.sfid_id            AS distribuidor,
      base.sfid_id            AS sfid_id,
      base.seller             AS seller,
      dealers.nombre_comercio AS nombre_comercio,
      dealers.nombre_comercio AS razon_social, 
      dealers.documento       AS cif,
      dealers.zona_fiscal     AS zona_fiscal,
      CAST (NULL AS STRING)   AS cond_pago,
      base.zip_code           AS zip_code,
      'PARLEM'                AS marca,
      base.service_type       AS service_type,
      CAST(base.phone_nm      AS STRING)           AS phone_nm,
      base.tariff_id          AS tariff_id,
      base.tariff_ds          AS tariff_ds,
      base.service_id         AS service_id,
      base.account_id         AS account_id,
      base.customer_id        AS customer_id,
      base.line_type_ds       AS line_type_ds,
      base.TIPO_PAQUETE       AS bundle_type,
      base.technology_ds      AS technology_ds,
      base.billing_type_ds    AS billing_type_ds,
      base.order_day_id       AS sale_date,
      base.activation_date    AS activation_date,
      base.deactivation_date  AS deactivation_date,
      CAST(base.order_id AS STRING)           AS order_id,
      base.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base.billing_type_ds, base.service_type, base.TIPO_PAQUETE, base.technology_ds ,base.line_type_ds , base.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      CONCAT(zip_code,"/",billing_tier_1)      AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      base.imp_without_tax     AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
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
    FROM base_cartera base
    LEFT JOIN dealers ON base.sfid_id = dealers.id_comisionista 
    LEFT JOIN dt ON 
      CASE
        WHEN base.service_type = 'MOBILE' AND base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' THEN base.ID_TARIFA_PAQUETE
        ELSE base.tariff_id
    END = dt.tariff_id
      AND base.tipo_paquete = dt.tipo_paquete
      AND dt.service_type = base.service_type
      AND dt.line_type = base.line_type_ds
      AND dt.tipo_fibra = base.TIPO_FIBRA
  
  ),

  extracomision_act_3p AS (

    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)  
      CAST(mes_string AS INT64) AS id_mes,
      'B2B - Parlem' AS agrupacion_canal,
      dealers.canal   AS canal,
      'D - EXTRA CAMPANA ID:1354'  AS concepto,
      'UPFR' AS tipo_concepto,
      1 AS  unidades,
      100 AS comision,
      tabla_upfront.CLIENTE           AS id_comisionista,
      tabla_upfront.sfid_id           AS distribuidor,
      tabla_upfront.sfid_id           AS sfid_id,
      tabla_upfront.seller            AS seller,
      dealers.nombre_comercio         AS nombre_comercio,
      dealers.nombre_comercio         AS razon_social, 
      dealers.documento               AS cif,
      dealers.zona_fiscal             AS zona_fiscal,
      CAST(NULL AS STRING)            AS cond_pago,
      CAST(NULL AS STRING)            AS zip_code,
      'PARLEM'                        AS marca,
      tabla_upfront.service_type      AS service_type,
      CAST(tabla_upfront.phone_nm AS STRING)           AS phone_nm,
      tabla_upfront.tariff_id         AS tariff_id,
      tabla_upfront.tariff_ds         AS tariff_ds,
      tabla_upfront.service_id        AS service_id,
      tabla_upfront.account_id        AS account_id,
      tabla_upfront.customer_id       AS customer_id,
      tabla_upfront.line_type_ds      AS line_type_ds,
      tabla_upfront.TIPO_PAQUETE      AS bundle_type,
      tabla_upfront.technology_ds     AS technology_ds,
      tabla_upfront.billing_type_ds   AS billing_type_ds,
      tabla_upfront.order_day_id      AS sale_date,
      tabla_upfront.activation_date   AS activation_date,
      tabla_upfront.deactivation_date AS deactivation_date,
      CAST(tabla_upfront.order_id AS STRING)           AS order_id,
      tabla_upfront.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (tabla_upfront.billing_type_ds, tabla_upfront.service_type, tabla_upfront.TIPO_PAQUETE, tabla_upfront.technology_ds ,tabla_upfront.line_type_ds , tabla_upfront.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN tabla_upfront.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      tabla_upfront.zip_code   AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
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
    FROM base_upfront tabla_upfront
    LEFT JOIN dealers ON  tabla_upfront.sfid_id = dealers.id_comisionista
    LEFT JOIN dt ON tabla_upfront.tariff_id = dt.tariff_id
  ),

  extracomision_cp AS (

    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) 
      CAST(mes_string AS INT64) AS id_mes, 
      'B2B - Parlem'    AS agrupacion_canal,
      dealers.canal     AS canal,
      'D - Campaña Iru' AS concepto,
      'AIRT' AS tipo_concepto,
      1 AS unidades,
      CASE
        WHEN activation_date < DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH) -- Caso 1: Alta antes del mes y sin baja antes de fin de mes → comisión completa
         AND (deactivation_date IS NULL OR deactivation_date > LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH))) 
         THEN 12
        
        WHEN activation_date >= DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH)   -- Caso 2: Alta dentro del mes y sin baja antes de fin de mes → proporcional desde alta
         AND (deactivation_date IS NULL OR deactivation_date > LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH)))
        THEN ROUND(12 * (DATE_DIFF(LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH)), activation_date, DAY) + 1)
        / EXTRACT(DAY FROM LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH))), 2)

        WHEN activation_date < DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH) -- Caso 3: Alta antes del mes y baja dentro del mes → proporcional hasta baja
         AND deactivation_date <= LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH))
        THEN ROUND(12 * (DATE_DIFF(deactivation_date, DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH), DAY) + 1)
        / EXTRACT(DAY FROM LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH))), 2)

    
        ELSE ROUND(12 * (DATE_DIFF(deactivation_date, activation_date, DAY) + 1) -- Caso 4: Alta y baja dentro del mes → proporcional entre fechas
          / EXTRACT(DAY FROM LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m', mes_string), MONTH))), 2)
      END AS comision,

      base.CLIENTE            AS id_comisionista,
      base.sfid_id            AS distribuidor,
      base.sfid_id            AS sfid_id,
      base.seller             AS seller,
      dealers.nombre_comercio AS nombre_comercio,
      dealers.nombre_comercio AS razon_social, 
      dealers.documento       AS cif,
      dealers.zona_fiscal     AS zona_fiscal,
      CAST(NULL AS STRING)    AS cond_pago,
      CAST(NULL AS INT64)           AS zip_code, --base.zip_code
      'PARLEM'                AS marca,
      base.service_type       AS service_type,
      CAST(base.phone_nm      AS STRING)           AS phone_nm,
      base.tariff_id          AS tariff_id,
      base.tariff_ds          AS tariff_ds,
      base.service_id         AS service_id,
      base.account_id         AS account_id,
      base.customer_id        AS customer_id,
      base.line_type_ds       AS line_type_ds,
      base.TIPO_PAQUETE       AS bundle_type,
      base.technology_ds      AS technology_ds,
      base.billing_type_ds    AS billing_type_ds,
      base.order_day_id       AS sale_date,
      base.activation_date    AS activation_date,
      base.deactivation_date  AS deactivation_date,
      CAST(base.order_id AS STRING)           AS order_id,
      base.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base.billing_type_ds, base.service_type, base.TIPO_PAQUETE, base.technology_ds ,base.line_type_ds , base.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      base.zip_code            AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
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
    FROM base_cartera base
    LEFT JOIN dealers ON  base.sfid_id = dealers.id_comisionista
    WHERE 
      tariff_ds LIKE 'FIBRA%' 
      AND tariff_ds NOT LIKE '%INDIRECTA%' 
      AND zip_code IN (('08720'),('17300'),('17190'),('08330'),('43491'),('43813'),('43800'),('17220'),('43549'),('08560'),('08470'),('08476'),('25300'),('25350'),('25351'),('25352'),('25353'),('25354'),('25360'),('08530'),('08600'),('08611'),('08350'),('43540'),('43548'),('25230'),('08360'),('08570'),('08770'),('17251'),('17252'),('17244'),('08295'),('43530'),('25200'),('25213'),('25214'),('25218'),('08358'),('17240'),('08650'),('43330'),('08510'),('43550'),('43558'),('43559'),('25110'),('25400'),('08670'),('08671'),('08269'),('43740'),('43560'),('43470'),('17460'),('25310'),('08395'),('17840'),('25250'),('25262'),('43460'),('08680'),('25110'),('25123'),('17450'),('08672'),('08692'),('17404'),('17400'),('08512'),('25430'),('25126'),('25730'),('25736'),('25737'),('25738'),('25739'),('25660'),('25124'),('43895'),('08660'),('08508'),('43770'),('08199'),('08298'),('08961'),('25125'),('25120'),('25121'),('43340'),('08188'),('08506'),('08572'),('08776'),('43711'),('43712'),('25170'),('25220'),('25141'),('08231'),('08571'),('17462'),('08691'),('43870'),('17330'),('23500'),('08799'),('08604'),('22002')) 
    QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm) = 1

  ),

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
      comision AS comision,
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
    FROM b


    UNION ALL

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
    FROM extracomision_act_3p

    UNION ALL

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
    FROM extracomision_cp
  )

  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
  FROM final
  WHERE comision <> 0
;


--Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arpa',
  'ACTUALIZAR'
);

-- Procedimiento de Validaciones
-- call `mm-commissions-reporting.COMISIONES.pr_validaciones_B2BC`(mes_int, canales_pr)

END