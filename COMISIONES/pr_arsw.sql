BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARSW';

SET canales_pr = ['SW'];

-- call `mm-commissions-reporting.COMISIONES.pr_arsw`(202505,['SW']);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_arsw` AS 

    
    SELECT DISTINCT 
      a.* EXCEPT (service_type,segment_ds),
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      b.first_territory_ds, 
      CASE 
        WHEN a.service_type IN ('FIX','INTERNET') AND c.bundle_type = 'FMC' AND c.tariff_ds NOT LIKE '%+%' THEN '2P'
        WHEN a.service_type IN ('FIX','INTERNET') AND c.bundle_type = '2P' AND c.tariff_ds LIKE '%+%'      THEN 'FMC'
        WHEN a.service_type NOT IN ('FIX','INTERNET')AND c.bundle_type IS NOT NULL THEN c.bundle_type
        WHEN c.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND COALESCE(c.tariff_ds, a.billing_tier_1) LIKE '%+%'           THEN  'FMC'
        WHEN c.bundle_type IS NULL AND a.service_type IN ('FIX','INTERNET') AND COALESCE(c.tariff_ds, a.billing_tier_1) NOT LIKE '%+%'       THEN  '2P'
        WHEN c.bundle_type IS NULL AND a.service_type = 'MOBILE' AND COALESCE(c.tariff_ds, a.billing_tier_1) LIKE '%CONV%'                   THEN  'FMC'
        WHEN c.bundle_type IS NULL AND a.service_type = 'MOBILE' AND COALESCE(c.tariff_ds, a.billing_tier_1) NOT LIKE '%CONV%'               THEN  'MO'
      ELSE c.bundle_type
      END AS TIPO_PAQUETE, 
      'Sweno' AS CLIENTE,
      c.tariff_ds,
      c.tariff_id, 
      c.zip_code,
      IF(a.service_type = 'MOBILE' AND c.line_type_ds = 'MAIN' AND c.bundle_type != d.bundle_type, d.sell_tariff_ds, d.tariff_ds) AS TARIFA_PAQUETE,
      IF(a.service_type = 'MOBILE' AND c.line_type_ds = 'MAIN' AND c.bundle_type != d.bundle_type, d.sell_tariff_id, d.tariff_id) AS ID_TARIFA_PAQUETE,
      d.first_territory_ds AS FIRST_TERRITORY_PAQUETE,
      c.order_type_agg,
      c.technology_ds,
      CASE
        WHEN c.bundle_type = 'MO' THEN 'NA'
        WHEN a.service_type = 'MOBILE' AND c.line_type_ds = 'MAIN' AND c.bundle_type != 'MO' AND d.tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        WHEN a.service_type IN('FIX','INTERNET') AND c.tariff_ds LIKE '%INDIRECTA%' THEN 'INDIRECTA'
        ELSE 'PROPIA'
      END AS TIPO_FIBRA,
      c.line_type_ds,
      c.activation_date,
      CASE
        WHEN c.deactivation_date > DATE_TRUNC(CURRENT_DATE(), MONTH) THEN NULL
        ELSE c.deactivation_date
      END AS deactivation_date,
      c.order_day_id,
      c.order_id,
      c.seller,
      c.sfid_id,
      c.segment_ds as segmento,
      IF(c.segment_ds = 'BUSINESS','Negocios', c.segment_ds) AS segment_ds
    FROM `mm-datamart-kd.BILLING.billing_detail_net` a 
    LEFT JOIN `mm-datamart-kd.SERVICES.service_base_net` b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm
    JOIN (
      SELECT DISTINCT a.service_id, a.phone_nm, account_id, customer_id, bundle_type, tariff_ds,tariff_id, activation_date, deactivation_date, segment_ds,order_type_agg, technology_ds, line_type_ds, b.MAX_DATE AS order_day_id, order_id, seller, zip_code, CONCAT(current_sfid_id,'-',current_user_store) AS sfid_id
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      JOIN (
        SELECT
          phone_nm,
          service_id,
          MAX(activation_date) AS MAX_DATE
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE activation_date <= last_day(date_sub(current_date(),INTERVAL 1 month)) AND activation_date IS NOT NULL 
        GROUP BY ALL
      ) b ON a.phone_nm = b.phone_nm AND a.service_id = b.service_id AND a.activation_date = b.MAX_DATE
      WHERE comm_brand_ds = 'SWENO' AND activation_date IS NOT NULL
    ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND LAST_DAY(a.init_date) >= LAST_DAY(c.order_day_id) AND (LAST_DAY(a.end_date) <= LAST_DAY(c.deactivation_date) OR c.deactivation_date IS NULL)
    LEFT JOIN (
      SELECT DISTINCT 
        a.account_id,
        sell_bundle_type,
        bundle_type,
        sell_tariff_ds, 
        sell_tariff_id, 
        tariff_ds,
        order_day_id,
        tariff_id,
        activation_date,
        first_territory_ds,
        IF(deactivation_date = '9999-12-31', NULL, deactivation_date) AS deactivation_date
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      LEFT JOIN (
        SELECT DISTINCT 
          first_territory_ds,
          a.account_id,
          a.phone_nm
        FROM `mm-datamart-kd.SERVICES.service_base_net` a
        JOIN(
          SELECT DISTINCT 
            MAX(activation_date) AS MAX_DATE,
            account_id,
            phone_nm
          FROM `mm-datamart-kd.SERVICES.service_base_net` 
          WHERE service_type = 'FIX'
          GROUP BY ALL
        ) b ON a.activation_date = b.MAX_DATE AND a.account_id = b.account_id AND a.phone_nm = b.phone_nm
        WHERE service_type = 'FIX'
      )b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm
      WHERE 
        a.service_type = 'FIX' 
        AND a.activation_date IS NOT NULL 
        AND a.activation_date <= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) --OR a.activation_date IS NULL)  
        AND a.comm_brand_ds = 'SWENO' 
        AND (LAST_DAY(a.deactivation_date) >= LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) OR a.deactivation_date IS NULL)
    ) d ON c.account_id = d.account_id AND a.service_type = 'MOBILE'
      WHERE a.comm_brand_ds = 'SWENO'
        AND a.service_type != 'TV'
        AND a.invoice_date = DATE_TRUNC(CURRENT_DATE(),MONTH)--Si quieres lanzar junio va 2023-07-01
        AND NOT(billing_tier_1 LIKE '%TV%'
          OR billing_tier_1 LIKE '%CORTE DE SERVICIO%'
          OR billing_tier_1 LIKE '%VISITA TECNICO%'
          OR billing_tier_1 LIKE '%SIM%'
          OR billing_tier_1 LIKE '%7%'
          OR billing_tier_1 LIKE '%OPIT%'
        )  
  ;

  ASSERT NOT EXISTS((--Si se modifica hay que actualizarlo también en App Script

    SELECT DISTINCT a.tariff_id, a.tariff_ds 
    FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
    LEFT JOIN `mm-commissions-reporting.TEMP.comisiones_base_arsw`b ON a.tariff_id = b.tariff_id
    LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_SWENO` c ON a.tariff_id = c.tariff_id
    WHERE a.comm_brand_ds = 'SWENO' AND (b.tariff_id IS NULL OR c.tariff_id IS NULL) AND a.activation_date > DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)

  )) AS 'Faltan tarifas por definir'
  ;

  ASSERT NOT EXISTS(--ASSERT agregado a App Script
    SELECT DISTINCT comm_brand_ds, sfid_id
    FROM `mm-commissions-reporting.TEMP.comisiones_base_arsw`a
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_SWENO` b ON a.sfid_id = b.id_comisionista
    WHERE 1=1
      AND b.id_comisionista IS NULL
    GROUP BY 1,2, b.id_comisionista
    ORDER BY 2
  ) AS 'Falta añadir nuevos distribuidores.'

  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arsw` AS

  WITH 
  
  base_upfront_act AS (
    
    SELECT DISTINCT 
      a.* EXCEPT (service_type, segment_ds,sfid_id),
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      'Sweno' AS CLIENTE,
      c.bundle_type AS TIPO_PAQUETE,
      c.order_day_id,
      c.order_type_agg,
      c.order_id,
      c.seller,
      c.sfid_id,
      IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds
    FROM  `mm-datamart-kd.SERVICES.service_base_net` a
    JOIN (
      SELECT DISTINCT a.service_id, a.phone_nm, account_id, customer_id, bundle_type, tariff_ds,tariff_id, activation_date, deactivation_date, segment_ds,order_type_agg, technology_ds, line_type_ds, b.MAX_DATE AS order_day_id, order_id, seller, CONCAT(current_sfid_id,'-',current_user_store) AS sfid_id, 
      CASE 
      WHEN service_type IN ('INTERNET','FIX') THEN 'INTERNET'
      ELSE service_type
      END AS service_type,
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      JOIN (
        SELECT
          phone_nm,
          service_id,
          MAX(activation_date) AS MAX_DATE
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE activation_date <= last_day(date_sub(current_date(),INTERVAL 1 month)) AND activation_date IS NOT NULL 
        GROUP BY ALL
      ) b ON a.phone_nm = b.phone_nm AND a.service_id = b.service_id AND a.activation_date = b.MAX_DATE
      WHERE comm_brand_ds = 'SWENO' AND activation_date IS NOT NULL 
     ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND a.service_id = c.service_id
    WHERE a.comm_brand_ds = 'SWENO'  
      AND a.kpi_gross_add = 1 
    --Ejemplos: activation '2023-05-01' AND '2023-05-31'// deactivation '2023-06-01'
      AND(a.activation_date BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))) 
      AND (a.deactivation_date IS NULL OR a.deactivation_date >= DATE_TRUNC(CURRENT_DATE(), MONTH))
      AND a.service_type = 'FIX'
  ),

  base_clawback_camp AS (
    
    SELECT DISTINCT 
      a.* EXCEPT (service_type, segment_ds,sfid_id),
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      'Sweno' AS CLIENTE,
      c.bundle_type AS TIPO_PAQUETE,
      c.order_day_id,
      c.order_type_agg,
      c.order_id,
      c.seller,
      c.sfid_id,
      IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds,
      c.bundle_type AS bundle_type_tr,
      a.tariff_id AS tariff_id_tr,
      a.tariff_ds AS tariff_ds_tr,
      d.importe AS comision
    FROM  `mm-datamart-kd.SERVICES.service_base_net` a
    JOIN (
      SELECT DISTINCT a.service_id, a.phone_nm, account_id, customer_id, bundle_type, tariff_ds,tariff_id, activation_date, deactivation_date, segment_ds,order_type_agg, technology_ds, line_type_ds, b.MAX_DATE AS order_day_id, order_id, seller, CONCAT(current_sfid_id,'-',current_user_store) AS sfid_id, 
      CASE 
      WHEN service_type IN ('INTERNET','FIX') THEN 'INTERNET'
      ELSE service_type
      END AS service_type,
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      JOIN (
        SELECT
          phone_nm,
          service_id,
          MAX(activation_date) AS MAX_DATE
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE activation_date <= last_day(date_sub(current_date(),INTERVAL 1 month)) AND activation_date IS NOT NULL 
        GROUP BY ALL
      ) b ON a.phone_nm = b.phone_nm AND a.service_id = b.service_id AND a.activation_date = b.MAX_DATE
      WHERE comm_brand_ds = 'SWENO' AND activation_date IS NOT NULL 
     ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND a.service_id = c.service_id
     --Realizamos el cruce con Transacciones para filtrar de las activaciones previas solo por los números que se han pagado
     LEFT JOIN (SELECT *
           FROM `mm-commissions-reporting.GS.HIST_UPFRONT_SWENO` 
        ) d ON d.MSISDN = a.phone_nm-- AND d.Suscription_id = a.service_id
    WHERE a.comm_brand_ds = 'SWENO'  
      AND LAST_DAY(a.deactivation_date) = LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))
      AND DATE_DIFF(a.deactivation_date, a.activation_date, DAY) < 365
      AND d.MSISDN IS NOT NULL
    
    UNION ALL

    SELECT DISTINCT 
      a.* EXCEPT (service_type, segment_ds,sfid_id),
      IF(a.service_type = 'FIX', 'INTERNET',a.service_type) AS service_type, 
      'Sweno' AS CLIENTE,
      c.bundle_type AS TIPO_PAQUETE,
      c.order_day_id,
      c.order_type_agg,
      c.order_id,
      c.seller,
      c.sfid_id,
      IF(a.segment_ds = 'BUSINESS','Negocios', a.segment_ds) AS segment_ds,
      d.bundle_type AS bundle_type_tr,
      d.tariff_id AS tariff_id_tr,
      d.tariff_ds AS tariff_ds_tr,
      d.comision
    FROM  `mm-datamart-kd.SERVICES.service_base_net` a
    JOIN (
      SELECT DISTINCT a.service_id, a.phone_nm, account_id, customer_id, bundle_type, tariff_ds,tariff_id, activation_date, deactivation_date, segment_ds,order_type_agg, technology_ds, line_type_ds, b.MAX_DATE AS order_day_id, order_id, seller, CONCAT(current_sfid_id,'-',current_user_store) AS sfid_id, 
      CASE 
      WHEN service_type IN ('INTERNET','FIX') THEN 'INTERNET'
      ELSE service_type
      END AS service_type,
      FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
      JOIN (
        SELECT
          phone_nm,
          service_id,
          MAX(activation_date) AS MAX_DATE
        FROM `mm-datamart-kd.SERVICES.ventas_base_net`
        WHERE activation_date <= last_day(date_sub(current_date(),INTERVAL 1 month)) AND activation_date IS NOT NULL 
        GROUP BY ALL
      ) b ON a.phone_nm = b.phone_nm AND a.service_id = b.service_id AND a.activation_date = b.MAX_DATE
      WHERE comm_brand_ds = 'SWENO' AND activation_date IS NOT NULL 
     ) c ON a.phone_nm = c.phone_nm AND a.account_id = c.account_id AND a.service_id = c.service_id
     --Realizamos el cruce con Transacciones para filtrar de las activaciones previas solo por los números que se han pagado
     JOIN (SELECT concepto,
                tariff_id,
                tariff_ds,
                bundle_type,
                service_id,
                phone_nm,
                comision
                FROM `mm-commissions-reporting.COMISIONES.transacciones` 
                WHERE marca = 'SWENO' AND concepto = 'D - Clawback' AND comision > 0
              ) d ON SAFE_CAST(d.phone_nm AS FLOAT64) = a.phone_nm AND d.service_id = a.service_id
    WHERE a.comm_brand_ds = 'SWENO'  
    AND LAST_DAY(a.deactivation_date) = LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))
    AND DATE_DIFF(a.deactivation_date, a.activation_date, DAY) < 365
    AND d.phone_nm IS NOT NULL 
  ),

  base_1 AS (
    SELECT *,
     ROW_NUMBER() OVER (PARTITION BY phone_nm ORDER BY phone_nm) AS NumeroFila 
    FROM `mm-commissions-reporting.TEMP.comisiones_base_arsw` AS base
  ),

  tabla_reclam_ago_23 AS (--Usaremos esta tabla para agregar las líneas de reclamaciones hechas el agosto 23
    SELECT 
      DATE_TRUNC(DATE_ADD(PARSE_DATE('%d/%m/%Y', fecha_registro),INTERVAL 1 MONTH), MONTH) AS fecha_billing,
      PARSE_DATE('%d/%m/%Y', fecha_registro) AS fecha_registro,
      concepto,
      diferencia as importe,
      msisdn
    FROM `mm-commissions-reporting.GS.reclamaciones_sweno`
  ),

  col AS (
    SELECT DISTINCT tariff_id, tariff_ds, cuota, cuota_bts, service_type, line_type, tipo_fibra, upfront
    FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_SWENO`
  ),

  dealer AS (
    SELECT * EXCEPT (nombre_comercio,zona_fiscal),
      UPPER(nombre_comercio) AS nombre_comercio,
      IF(zona_fiscal = '#N/A','PEN',zona_fiscal) AS zona_fiscal
    FROM `mm-commissions-reporting.GS.DEALERS_SWENO`
    WHERE comisiona IS TRUE AND check_duplicados = '1'
  ),

  b AS(
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - SWENO' AS agrupacion_canal,
      'SW' AS canal,
      base.billing_tier_1,
      base.id_tarifa_paquete,
      base.tarifa_paquete,
      CASE 
        WHEN base.TIPO_PAQUETE = 'MO'  THEN CONCAT('C - Gestion Cartera Movil ','(',Cuota,'%)')
        WHEN base.TIPO_PAQUETE = 'FMC' THEN CONCAT('C - Gestion Cartera 3P ','(',Cuota,'%)')
        WHEN base.TIPO_PAQUETE = '2P'  THEN CONCAT('C - Gestion Cartera 2P ','(',Cuota,'%)')
        ELSE 'C - Gestion Cartera Resto'
      END    AS concepto,
      'AIRT' AS tipo_concepto,
      CAST(mes_string AS INT64) AS unidades,
      base.imp_without_tax AS imp_base,
      CASE 
        WHEN col.cuota IS NULL THEN 0
        ELSE base.imp_without_tax*cuota/100
      END AS comision,
      base.sfid_id        AS id_comisionista,
      base.sfid_id        AS distribuidor,
      base.sfid_id        AS sfid_id,
      base.seller         AS seller,
      'EL CORTE INGLES SA'  AS nombre_comercio,
      'EL CORTE INGLES SA'  AS razon_social, 
      CAST(NULL AS STRING)    AS cond_pago,
      'A28017895' AS cif,
      dealer.zona_fiscal AS zona_fiscal,

      'SWENO'                   AS marca,
      base.service_type       AS service_type,
      CAST(base.phone_nm AS STRING)           AS phone_nm,
      base.tariff_id     AS tariff_id,
      base.tariff_ds     AS tariff_ds,
      base.service_id         AS service_id,
      base.account_id         AS account_id,
      base.customer_id        AS customer_id,
      base.line_type_ds       AS line_type_ds,
      base.TIPO_PAQUETE       AS bundle_type,
      base.technology_ds      AS technology_ds,
      base.billing_type_ds    AS billing_type_ds,
      base.order_day_id       AS sale_date,
      base.activation_date    AS activation_date,
      IF(base.deactivation_date IS NULL,'9999-12-31',base.deactivation_date)  AS deactivation_date,
      CAST(base.order_id AS STRING)           AS order_id,
      base.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '20'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base.billing_type_ds, col.service_type, base.TIPO_PAQUETE, base.technology_ds ,base.line_type_ds , base.brand_ds)       AS cod_tipo_contrato,
      CASE 
        WHEN col.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      '30'                     AS cod_canal,
      base.billing_tier_1      AS campaign_code,
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
    FROM `mm-commissions-reporting.TEMP.comisiones_base_arsw` AS base
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN col ON 
      CASE
        WHEN base.service_type = 'MOBILE' AND base.line_type_ds = 'MAIN' AND base.TIPO_PAQUETE = 'FMC' THEN base.ID_TARIFA_PAQUETE 
        ELSE base.tariff_id
      END = col.tariff_id
      AND col.service_type = base.service_type
      AND col.line_type = base.line_type_ds
      AND col.tipo_fibra = base.TIPO_FIBRA
    LEFT JOIN dealer ON base.sfid_id = dealer.id_comisionista
      
  ),

  upfront AS(

    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - SWENO' AS agrupacion_canal,
      'SW' AS canal,
      'A - Upfront' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(mes_string AS INT64) AS unidades,
      CASE
        WHEN col.upfront IS NULL OR col.tariff_ds LIKE 'ECI%' THEN 0
        ELSE col.upfront
      END AS comision, 
      --IF(col.upfront IS NULL, 0, col.upfront) AS comision,
      base_upfront_act.sfid_id      AS id_comisionista,
      base_upfront_act.sfid_id        AS distribuidor,
      base_upfront_act.sfid_id        AS sfid_id,
      base_upfront_act.seller         AS seller,
      'EL CORTE INGLES SA'  AS nombre_comercio,
      'EL CORTE INGLES SA'  AS razon_social, 
      CAST(NULL AS STRING)    AS cond_pago,
      'A28017895' AS cif,
      dealer.zona_fiscal AS zona_fiscal,
      'SWENO'                   AS marca,
      base_upfront_act.service_type       AS service_type,
      CAST(base_upfront_act.phone_nm AS STRING)           AS phone_nm,
      base_upfront_act.tariff_id     AS tariff_id,
      base_upfront_act.tariff_ds     AS tariff_ds,
      base_upfront_act.service_id         AS service_id,
      base_upfront_act.account_id         AS account_id,
      base_upfront_act.customer_id        AS customer_id,
      base_upfront_act.line_type_ds       AS line_type_ds,
      base_upfront_act.TIPO_PAQUETE       AS bundle_type,
      base_upfront_act.technology_ds      AS technology_ds,
      base_upfront_act.billing_type_ds    AS billing_type_ds,
      base_upfront_act.order_day_id       AS sale_date,
      base_upfront_act.activation_date    AS activation_date,
      IF(base_upfront_act.deactivation_date IS NULL,'9999-12-31',base_upfront_act.deactivation_date)  AS deactivation_date,
      CAST(base_upfront_act.order_id AS STRING)           AS order_id,
      base_upfront_act.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '20'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront_act.billing_type_ds, base_upfront_act.service_type, base_upfront_act.TIPO_PAQUETE, base_upfront_act.technology_ds ,base_upfront_act.line_type_ds , base_upfront_act.brand_ds)       AS cod_tipo_contrato,
      CASE 
        WHEN base_upfront_act.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                      AS cod_producto,
      '30'                     AS cod_canal,
      CAST(NULL AS STRING)     AS campaign_code,
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
    FROM base_upfront_act
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront_act.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN col ON col.tariff_id = base_upfront_act.tariff_id 
    LEFT JOIN dealer ON base_upfront_act.sfid_id = dealer.id_comisionista
    
  ), 

  apoyo_ECI AS(

    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - SWENO' AS agrupacion_canal,
      'SW' AS canal,
      'D - APOYO ECI' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(mes_string AS INT64) AS unidades,
      -50 comision,
      base_upfront_act.sfid_id      AS id_comisionista,
      base_upfront_act.sfid_id        AS distribuidor,
      base_upfront_act.sfid_id        AS sfid_id,
      base_upfront_act.seller         AS seller,
      dealer.nombre_comercio AS nombre_comercio,
      dealer.razon_social AS razon_social, 
      CAST(NULL AS STRING)    AS cond_pago,
      dealer.documento AS cif,
      dealer.zona_fiscal AS zona_fiscal,
      'SWENO'                   AS marca,
      base_upfront_act.service_type       AS service_type,
      CAST(base_upfront_act.phone_nm AS STRING)           AS phone_nm,
      base_upfront_act.tariff_id     AS tariff_id,
      base_upfront_act.tariff_ds     AS tariff_ds,
      base_upfront_act.service_id         AS service_id,
      base_upfront_act.account_id         AS account_id,
      base_upfront_act.customer_id        AS customer_id,
      base_upfront_act.line_type_ds       AS line_type_ds,
      base_upfront_act.TIPO_PAQUETE       AS bundle_type,
      base_upfront_act.technology_ds      AS technology_ds,
      base_upfront_act.billing_type_ds    AS billing_type_ds,
      base_upfront_act.order_day_id       AS sale_date,
      base_upfront_act.activation_date    AS activation_date,
      IF(base_upfront_act.deactivation_date IS NULL,'9999-12-31',base_upfront_act.deactivation_date)  AS deactivation_date,
      CAST(base_upfront_act.order_id AS STRING)           AS order_id,
      base_upfront_act.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '20'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront_act.billing_type_ds, base_upfront_act.service_type, base_upfront_act.TIPO_PAQUETE, base_upfront_act.technology_ds ,base_upfront_act.line_type_ds , base_upfront_act.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_upfront_act.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
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
    FROM base_upfront_act
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront_act.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN col ON col.tariff_id = base_upfront_act.tariff_id 
    LEFT JOIN dealer ON base_upfront_act.sfid_id = dealer.id_comisionista

  ), 

  clawback AS(

    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes, 
      'B2B - SWENO' AS agrupacion_canal,
      'SW' AS canal,
      'D - Clawback' AS concepto,
      'UPFR' AS tipo_concepto,
      CAST(mes_string AS INT64) AS unidades,
      CASE
        WHEN date_diff(base_clawback_camp.deactivation_date,base_clawback_camp.activation_date, DAY) <= 180 THEN base_clawback_camp.comision*-1
        ELSE base_clawback_camp.comision*-1/2
      END AS comision,
      base_clawback_camp.sfid_id        AS id_comisionista,
      base_clawback_camp.sfid_id        AS distribuidor,
      base_clawback_camp.sfid_id        AS sfid_id,
      base_clawback_camp.seller         AS seller,
     dealer.nombre_comercio AS nombre_comercio,
      dealer.razon_social AS razon_social, 
      CAST(NULL AS STRING)    AS cond_pago,
      dealer.documento AS cif,
      dealer.zona_fiscal AS zona_fiscal,
      'SWENO'                   AS marca,
      base_clawback_camp.service_type       AS service_type,
      CAST(base_clawback_camp.phone_nm AS STRING)           AS phone_nm,
      base_clawback_camp.tariff_id_tr       AS tariff_id,
      base_clawback_camp.tariff_ds_tr       AS tariff_ds,
      base_clawback_camp.service_id         AS service_id,
      base_clawback_camp.account_id         AS account_id,
      base_clawback_camp.customer_id        AS customer_id,
      base_clawback_camp.line_type_ds       AS line_type_ds,
      base_clawback_camp.bundle_type_tr     AS bundle_type,
      base_clawback_camp.technology_ds      AS technology_ds,
      base_clawback_camp.billing_type_ds    AS billing_type_ds,
      base_clawback_camp.order_day_id       AS sale_date,
      base_clawback_camp.activation_date    AS activation_date,
      base_clawback_camp.deactivation_date  AS deactivation_date,
      CAST(base_clawback_camp.order_id AS STRING)           AS order_id,
      base_clawback_camp.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '20'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_clawback_camp.billing_type_ds, base_clawback_camp.service_type, base_clawback_camp.TIPO_PAQUETE, base_clawback_camp.technology_ds ,base_clawback_camp.line_type_ds , base_clawback_camp.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN base_clawback_camp.service_type IN ('INTERNET', 'FIX') THEN '041'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
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
    FROM base_clawback_camp
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_clawback_camp.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN col ON col.tariff_id = base_clawback_camp.tariff_id 
    LEFT JOIN dealer ON base_clawback_camp.sfid_id = dealer.id_comisionista
  
  ),

  final AS (

    SELECT DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1      AS unidades,
      SUM(comision) AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cond_pago,
      cif,
      zona_fiscal,
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
      claim_code,
      campaign_code,
      serial_number,
      SUM(ROUND(imp_base,2)) AS tax_base,
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
    GROUP BY ALL

    UNION ALL

    SELECT DISTINCT
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        1     AS unidades,
        SUM(comision) AS comision,
        id_comisionista,
        distribuidor,
        sfid_id,
        seller,
        nombre_comercio,
        razon_social,
        cond_pago,
        cif,
        zona_fiscal,
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
        claim_code,
        campaign_code,
        serial_number,
        tax_base,
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
      FROM upfront
      GROUP BY ALL

      UNION ALL

      SELECT DISTINCT
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      -1 AS unidades,
      SUM(comision) AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cond_pago,
      cif,
      zona_fiscal,
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
      claim_code,
      campaign_code,
      serial_number,
      tax_base,
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
    FROM apoyo_ECI
    GROUP BY ALL

    UNION ALL

    SELECT DISTINCT
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        -1 AS unidades,
        SUM(comision) AS comision,
        id_comisionista,
        distribuidor,
        sfid_id,
        seller,
        nombre_comercio,
        razon_social,
        cond_pago,
        cif,
        zona_fiscal,
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
        claim_code,
        campaign_code,
        serial_number,
        tax_base,
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
      FROM clawback
      GROUP BY ALL
    
  )

    SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
    FROM final
    WHERE comision != 0; 

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arsw',
  'ACTUALIZAR'
);

END