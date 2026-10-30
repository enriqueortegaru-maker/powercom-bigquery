BEGIN

  DECLARE prefijo, mes_string STRING;
  SET mes_string = CAST(id_mes_pr AS STRING);
  SET prefijo    = 'NENRG_';


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_activations`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  (
    WITH
    lucera_filtered AS (
      SELECT
        cups_code, phone, id, sfid_id, signup_date, activation_date, churn_date,
        initial_lucera_tariff_name, affiliate_code, author_id
      FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity`
      WHERE churn_date IS NULL
        AND DATE_TRUNC(DATE(activation_date), MONTH) = PARSE_DATE('%Y%m', mes_string)
        AND sfid_id IS NOT NULL
    ),

    

    sfid_lookup AS (
      SELECT * FROM (
        SELECT
          crm,
          marca_ds,
          mo.sfid               AS sfid_id,
          'mo'                  AS src,
          mo.N1                 AS agrupacion_canal,
          mo.N2                 AS canal,
          mo.bp                 AS id_comisionista,
          mo.nombre_acreedor_ds AS distribuidor,
          mo.nombre_acreedor_ds AS nombre_comercio,
          mo.razon_social,
          mo.CIF,
          equipo.descripcion
        FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`
        WHERE mo.sfid IS NOT NULL
        UNION ALL
        SELECT
          crm,
          marca_ds,
          ct.sfid,
          'ct',
          ct.canal_ds,
          ct.subcanal_ds,
          mo.bp,                
          ct.distribuidor_ds,
          ct.distribuidor_ds,   
          mo.razon_social,      
          mo.CIF,
          equipo.descripcion
        FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`
        WHERE ct.sfid IS NOT NULL
      )
      QUALIFY ROW_NUMBER() OVER (
        PARTITION BY sfid_id
        ORDER BY CASE src WHEN 'mo' THEN 1 ELSE 2 END
      ) = 1
    ),

    conceptos_enrgn AS (
      SELECT c.* EXCEPT(proceso), proceso
      FROM `mm-commissions-reporting.KRT_MASIVO.CONCEPTOS` c,
           UNNEST(SPLIT(c.proceso, ',')) proceso
      WHERE proceso = 'ENRGN'
        AND SUBSTR(c.concepto, 1, 1) = 'B'
    )

    SELECT
      prefijo || 'BNEN_' || mes_string || '_' || sl.canal || '_' ||
        ROW_NUMBER() OVER (PARTITION BY sl.canal ORDER BY lf.cups_code)   AS commission_id,
      'calculado'                                                           AS estado,
      PARSE_DATE('%Y%m', mes_string)                                        AS mes_liquidado,
      id_mes_pr                                                             AS id_mes,
      IMPORTE.marco_energia,
      sl.agrupacion_canal,
      sl.canal,
      c.concepto,
      c.tipo_concepto,
      1                                                                     AS unidades,
      IMPORTE.comision,
      sl.id_comisionista,
      COALESCE(sl.distribuidor, CAST(sl.id_comisionista AS STRING))        AS distribuidor,
      lf.sfid_id,
      UPPER(SPLIT(lf.author_id, '@')[OFFSET(0)])                          AS seller,
      sl.descripcion,
      sl.nombre_comercio,                                                   
      sl.razon_social,
      sl.CIF                                                                AS cif,
      'PEN'                                                                 AS zona_fiscal,
      sl.crm                                                                AS crm,
      sl.marca_ds                                                           AS marca,
      'ENERGY'                                                              AS service_type,
      CAST(lf.phone AS STRING)                                             AS phone_nm,
      CAST(NULL AS STRING)                                                  AS tariff_id,
      lf.initial_lucera_tariff_name                                        AS tariff_ds,
      CAST(lf.id AS STRING)                                                AS service_id,
      CAST(NULL AS STRING)                                                  AS account_id,
      CAST(NULL AS STRING)                                                  AS customer_id,
      CAST(NULL AS STRING)                                                  AS line_type_ds,
      CAST(NULL AS STRING)                                                  AS bundle_type,
      CAST(NULL AS STRING)                                                  AS technology_ds,
      CAST(NULL AS STRING)                                                  AS billing_type_ds,
      lf.signup_date                                                        AS sale_date,
      lf.activation_date,
      lf.churn_date                                                         AS deactivation_date,
      CAST(NULL AS STRING)                                                  AS order_id,
      CAST(NULL AS STRING)                                                  AS order_type_agg,
      '10'                                                                  AS cod_segmento,
      CAST(NULL AS STRING)                                                  AS cod_marca,
      '99'                                                                  AS cod_tipo_contrato,
      '014'                                                                 AS cod_producto,
      CAST(NULL AS STRING)                                                  AS cod_canal,
      CAST(NULL AS STRING)                                                  AS campaign_code,
      lf.cups_code                                                          AS serial_number,
      CAST(NULL AS FLOAT64)                                                 AS tax_base,
      CAST(NULL AS STRING)                                                  AS claim_code,
      CAST(NULL AS STRING)                                                  AS process_code,
      CAST(NULL AS STRING)                                                  AS comments,
      'C_MANUAL'                                                            AS facturador,
      `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(sl.marca_ds)    AS sociedad,
    FROM lucera_filtered lf

    INNER JOIN sfid_lookup sl ON lf.sfid_id = sl.sfid_id
    LEFT JOIN conceptos_enrgn c
      ON CASE
           WHEN (lf.initial_lucera_tariff_name LIKE '%Batman%'
                 OR CONTAINS_SUBSTR(lf.affiliate_code, 'batman'))
           THEN 'B - Energia Batman'
           ELSE 'B - Energia'
         END = c.concepto
    LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_CANALES` CANAL
      ON  UPPER(TRIM(CANAL.agrupacion_canal)) = UPPER(TRIM(sl.agrupacion_canal))  
      AND UPPER(TRIM(CANAL.canal))            = UPPER(TRIM(sl.canal))
    LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_MARCO` IMPORTE
      ON  UPPER(TRIM(CANAL.marco_energia))    = UPPER(TRIM(IMPORTE.marco_energia))
      AND UPPER(TRIM(c.concepto))             = UPPER(TRIM(IMPORTE.concepto))
      AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
      AND IMPORTE.duplicado = 1
    WHERE IMPORTE.comision IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY lf.cups_code ORDER BY lf.sfid_id DESC) = 1
  );



  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT
    id_mes,
    commission_id,
    marco_energia,
    agrupacion_canal,
    canal,
    cod_canal,
    agrupacion_canal  AS canal_ds,
    canal             AS subcanal_ds,
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
    crm,
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
    cod_tipo_contrato,
    cod_producto,
    cod_marca,
    claim_code,
    campaign_code,
    serial_number,
    tax_base,
    process_code,
    comments,
    facturador,
    sociedad,        
    estado
  FROM `mm-commissions-reporting.TEMP.enrgn_activations`;


  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_LUZ_reparto_norte`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  WITH

  
  rep AS (
    SELECT
      a.agrupacion_canal,
      a.canal,
      a.distribuidor,
      a.sfid_id,
      CASE
        WHEN UPPER(TRIM(r.sfid_id)) = 'X'
        THEN COUNT(a.service_id) OVER (PARTITION BY a.agrupacion_canal, a.canal, a.distribuidor, a.sfid_id)
        ELSE COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
      END AS nprxsfid,
      SAFE_DIVIDE(
        AVG(r.importe) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor),
        COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
      ) AS impxpr,
      SAFE_MULTIPLY(
        CASE
          WHEN UPPER(TRIM(r.sfid_id)) = 'X'
          THEN COUNT(a.service_id) OVER (PARTITION BY a.agrupacion_canal, a.canal, a.distribuidor, a.sfid_id)
          ELSE COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
        END,
        SAFE_DIVIDE(
          AVG(r.importe) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor),
          COUNT(a.service_id) OVER (PARTITION BY r.agrupacion_canal, r.canal, r.distribuidor)
        )
      ) AS impacxsfid
    FROM `mm-commissions-reporting.TEMP.enrgn_activations` a
    INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_ENERGIA_REPARTO` r
      ON  a.agrupacion_canal = r.agrupacion_canal
      AND a.canal            = r.canal
      AND (UPPER(TRIM(r.distribuidor)) = 'X' OR UPPER(TRIM(r.distribuidor)) = UPPER(TRIM(a.distribuidor)))
      AND (UPPER(TRIM(r.sfid_id))     = 'X' OR r.sfid_id = a.sfid_id)
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY a.agrupacion_canal, a.canal, a.distribuidor, a.sfid_id
      ORDER BY
        CASE WHEN UPPER(TRIM(r.sfid_id))     = 'X' THEN 2 ELSE 1 END,  
        CASE WHEN UPPER(TRIM(r.distribuidor)) = 'X' THEN 2 ELSE 1 END  
    ) = 1
  )

  SELECT
    a.id_mes,
    prefijo || 'RPEN_' || mes_string || '_' || a.canal || '_' ||
      ROW_NUMBER() OVER (PARTITION BY a.canal ORDER BY a.agrupacion_canal, a.distribuidor, a.sfid_id, a.service_id) AS commission_id,
    a.marco_energia,
    a.agrupacion_canal,
    a.canal,
    a.cod_canal,
    a.agrupacion_canal AS canal_ds,
    a.canal            AS subcanal_ds,
    'D - Extra'        AS concepto,
    a.tipo_concepto,
    a.unidades,
    ROUND(r.impxpr, 4) AS comision,
    a.id_comisionista,
    a.distribuidor,
    a.sfid_id,
    a.seller,
    a.nombre_comercio,
    a.razon_social,
    a.cif,
    a.zona_fiscal,
    a.crm,
    a.marca,
    a.service_type,
    a.phone_nm,
    a.tariff_id,
    a.tariff_ds,
    a.service_id,
    a.account_id,
    a.customer_id,
    a.line_type_ds,
    a.bundle_type,
    a.technology_ds,
    a.billing_type_ds,
    a.sale_date,
    a.activation_date,
    a.deactivation_date,
    a.order_id,
    a.order_type_agg,
    a.cod_segmento,
    a.cod_tipo_contrato,
    a.cod_producto,
    a.cod_marca,
    a.claim_code,
    a.campaign_code,
    a.serial_number,
    a.tax_base,
    a.process_code,
    a.comments,
    a.facturador,
    a.sociedad,                       
    a.estado
  FROM `mm-commissions-reporting.TEMP.enrgn_activations` a
  INNER JOIN rep r
    ON  a.agrupacion_canal = r.agrupacion_canal
    AND a.canal            = r.canal
    AND a.distribuidor     = r.distribuidor
    AND a.sfid_id          = r.sfid_id;

END