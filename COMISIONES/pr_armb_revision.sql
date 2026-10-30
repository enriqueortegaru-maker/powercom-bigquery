BEGIN

 
DECLARE sql, prefijo, mes_string,canales_str STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARMB';

SET canales_pr = ['MB','MBA'];

SET canales_str = ARRAY_TO_STRING(canales_pr, ',');

--  call `mm-commissions-reporting.COMISIONES.pr_armb_revision`(202606,['MB','MBA']);


  --🔸 Validador 1: verificamos que todos los current_sfid_id tienen C09%

  ASSERT NOT EXISTS(

    SELECT DISTINCT a.current_sfid_id
    FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` a
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND current_sfid_id NOT LIKE 'C09%'

  ) AS 'El current_sfid_id no está definido como C09'
  ;

  --🔸 Validador 2: tarifas faltantes, se verifica tanto en la liquidación del mes como en en ventas

  ASSERT NOT EXISTS(--Si se modifica hay que actualizarlo también en App Script

  WITH tarifas_faltantes AS (
    SELECT DISTINCT a.tariff_id, a.tariff_ds
    FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` a
    LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB` c ON a.tariff_id = c.tariff_id
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND c.tariff_id IS NULL
      AND a.tariff_id IS NOT NULL

    UNION ALL

    SELECT DISTINCT a.tariff_id, a.tariff_ds,
    FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
    LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB` c ON a.tariff_id = c.tariff_id
    JOIN (--JOIN PARA QUEDARNOS SOLO  CON LOS NÚMEROS QUE SALEN EN BILLING
      SELECT phone_nm
      FROM `mm-datamart-kd.BILLING.billing_detail_net`
      WHERE invoice_date = DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH) -- DATE_TRUNC(CURRENT_DATE, MONTH)
    )d ON a.phone_nm = d.phone_nm
    WHERE 1=1
      AND a.comm_brand_ds = 'MARBLANCA' 
      AND (c.tariff_id IS NULL) 
      AND (a.deactivation_date IS NULL OR a.deactivation_date = '9999-12-31')
      AND a.activation_date IS NOT NULL
      AND a.tariff_id IS NOT NULL 
    )

    SELECT DISTINCT *
    FROM tarifas_faltantes
  ) AS 'Faltan tarifas por definir'
  ;

  --🔸 Validador 3: distribuidores faltantes.

  ASSERT NOT EXISTS(--Si se modifica hay que actualizarlo también en App Script

    SELECT DISTINCT a.current_sfid_id
    FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` a
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA` b ON a.current_sfid_id = b.id_comisionista
    WHERE 1=1
      AND a._TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND a.comm_brand_ds = 'MARBLANCA' 
      AND b.id_comisionista IS NULL 
      --AND a.activation_date > DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
      AND a.current_sfid_id != 'NULL'

  ) AS 'Faltan distribuidores por definir'
  ;

  -- 🔸 Validador 4: mismo número de tarifas distintas en ambas tablas
  
  ASSERT NOT EXISTS (--Si se modifica hay que actualizarlo también en App Script
    SELECT 1
    FROM UNNEST([1]) AS dummy
    WHERE (
      (SELECT COUNT(DISTINCT tariff_id)
      FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB`)
      <>
      (SELECT COUNT(DISTINCT tariff_id)
      FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MARB_IP_CVE`)
    )
  ) AS 'No hay el mismo número de tarifas';


   -- 🔸 Validador 5: para cada tarifa, el número de comisionistas debe ser igual al total de comisionistas existentes

  ASSERT NOT EXISTS (--Si se modifica hay que actualizarlo también en App Script
    WITH operadores_totales AS (
      SELECT COUNT(DISTINCT cod_tipo_comisionista) AS total_comisionistas
      FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB`
      WHERE cod_tipo_comisionista IS NOT NULL
      UNION ALL
      SELECT COUNT(DISTINCT cod_tipo_comisionista)
      FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MARB_IP_CVE`
      WHERE cod_tipo_comisionista IS NOT NULL
    ),
    total_unificado AS (
      SELECT MAX(total_comisionistas) AS total_comisionistas
      FROM operadores_totales
    ),
    tarifas_base AS (
      SELECT 
        tariff_id,
        COUNT(cod_tipo_comisionista) AS n_tarifas
      FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB`
      WHERE tariff_id IS NOT NULL
      GROUP BY tariff_id

      UNION ALL

      SELECT 
        tariff_id,
        COUNT(cod_tipo_comisionista) AS n_tarifas
      FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MARB_IP_CVE`
      WHERE tariff_id IS NOT NULL
      GROUP BY tariff_id
    )

    SELECT *
    FROM tarifas_base t
    CROSS JOIN total_unificado u
    WHERE t.n_tarifas <> u.total_comisionistas

  ) AS 'No hay el mismo numero de líneas por tarifa';

  -- -- 🔸 Validador 6: verificamos que todas las tarias están dadas de alta en el maestro de mysim

  -- ASSERT NOT EXISTS(

  --   SELECT DISTINCT id_paquete, nombre_paquete
  --   FROM `mm-commissions-reporting.TEMP.upfronts_base_armb` a
  --   LEFT JOIN `mm-b2b-reporting.MAESTROS.maestro_paquete_mysim` b ON a.tariff_id = b.id_paquete
  --   WHERE b.id_paquete IS NULL

  -- ) AS 'Faltan tarifas por dar de alta en la tabla maestro_paquete_mysim';

-----------------------------------------------------------------------------FIN VALIDACIONES--------------------------------------------------------------------------------------
  -- Ejecución del procedimiento de campañas especiales CROSSELLING

    -- call `mm-commissions-reporting.B2B.campMB_MO_FMC`(mes_int);

  -- Ejecución del procedimiento de comisión especial de TUCA por Gescales

    -- call `mm-commissions-reporting.B2B.pr_armb_TUCA_G37`(mes_int);

  -- Ejecución procedimiento historificacion de las campañas del mes correspondiente

    -- call `mm-commissions-reporting.B2B.pr_campanas_base_general`(mes_int, canales_pr);

  -- COMENZAMOS EL CÁLCULO DE LA CARTERA
  
  -- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision` AS (

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_cartera` AS (

   SELECT * 
    FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` a
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.B2B.TUCA_G37_COMISION` t
        WHERE
          (t.g37 = a.gescal OR (t.g37 IS NULL AND a.gescal IS NULL))
          AND t.current_sfid_id = a.current_sfid_id
          AND t.activation_date = a.activation_date
      )
      
  ); -- base_cartera 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_cartera_tuca` AS (

   SELECT * 
    FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` a
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.B2B.TUCA_G37_COMISION` t
        WHERE
          (t.g37 = a.gescal OR (t.g37 IS NULL AND a.gescal IS NULL))
          AND t.current_sfid_id = a.current_sfid_id
          AND t.activation_date = a.activation_date
      )
      -- AND CONCAT(gescal,'/',current_sfid_id,'/',activation_date) IN (
      --   SELECT CONCAT(g37,'/',current_sfid_id,'/',activation_date) 
      --   FROM `mm-commissions-reporting.B2B.TUCA_G37_COMISION`
      -- )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
  ); -- base_cartera_tuca
  
 CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront_org` AS (
    SELECT a.*, b.deactivation_date_act
    FROM `mm-commissions-reporting.B2B.upfronts_base_armb_*` a
    --Cruzamos con la tabla que contiene la información del origen de la linea, si es primera linea, migracion, etc.
      LEFT JOIN (
        SELECT phone_nm, activation_date,deactivation_date AS deactivation_date_act, first_activation_flag,grupo
        FROM `mm-commissions-reporting.B2B.tipo_activacion_service`
      ) b ON CONCAT(CAST(a.phone_nm AS STRING),'-',a.activation_date) = CONCAT(CAST(b.phone_nm AS STRING),'-',b.activation_date) 
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND a.phone_nm NOT IN (
        SELECT DISTINCT phone_nm 
        FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_cartera_tuca`
      )
      AND first_activation_flag NOT IN ('CAMBIO TARIFA','INTERCO','MIGRACION MISMO GRUPO')
  ); -- base_upfront_org,

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront_1354`  AS (

    SELECT *
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront_org`
    WHERE deactivation_date_act IS NULL
  ); --base_upfront_org

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront` AS (

    SELECT a.*
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront_org` a
    INNER JOIN ( 
        SELECT DISTINCT phone_nm, customer_id, billing_tier_1
        FROM `mm-datamart-kd.BILLING.billing_detail_net` 
        WHERE billing_tier_1 = 'COSTE DE ALTA' AND comm_brand_ds = 'MARBLANCA' AND service_type in ('FIX', 'BROADBAND') AND data_month_id = mes_int -- Añadimos el cruce por mes (15/07/26)
        GROUP BY ALL
      ) g ON a.customer_id = g.customer_id AND a.phone_nm = g.phone_nm
    WHERE deactivation_date_act > last_day(PARSE_DATE('%Y%m',mes_string)) -- para coger bajas del primer día del mes siguiente 
      or deactivation_date_act is null
  ); --base_upfront

 CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_campanas`  AS (--Campañas del mes
    SELECT *
    FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_MB_*`
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
  ); --campanas

 CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision_campanas_MO_FMC`  AS (--Campañas del mes
    SELECT * EXCEPT(MSISDN,TIPO_PAQUETE, DESDE,HASTA),
      MSISDN AS MSISDN_MO_FMC
    FROM `mm-commissions-reporting.TEMP.HIST_CAMPANA_MO_FMC`
    WHERE PERIODO_LIQ = DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  );--campanas_MO_FMC
create or replace table `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_clawback`  AS (
WITH
  --Inicio clawback
  base_clawback_g AS (
    SELECT a.* EXCEPT(concepto,activation_date,deactivation_date,comision,phone_nm,emails_acceso_trazabilidad),
      a.phone_nm,
      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(h.concepto, 'D - ', ''),'A - ', ''),'R - ',''),'Z - ',''),'E -','') AS concepto,
      a.activation_date,
      COALESCE(b.deactivation_date,c.deactivation_date) AS deactivation_date,
      h.comision,
    FROM `mm-commissions-reporting.COMISIONES.transacciones` a
    LEFT JOIN(
      SELECT 
        phone_nm,
        service_id,
        activation_date,
        COALESCE(deactivation_date,'9999-12-31') AS deactivation_date
      FROM `mm-datamart-kd.SERVICES.ventas_base_net`
      WHERE service_type = 'FIX'
        AND comm_brand_ds = 'MARBLANCA'
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,activation_date,service_id) = 1
    ) b ON a.phone_nm = CAST(b.phone_nm AS STRING) AND (a.activation_date = b.activation_date OR (a.activation_date != b.activation_date AND a.service_id = b.service_id))
    LEFT JOIN(
      SELECT 
        phone_nm,
        service_id,
        activation_date,
        COALESCE(deactivation_date,'9999-12-31') AS deactivation_date
      FROM `mm-datamart-kd.SERVICES.service_base_net`
      WHERE service_type = 'FIX'
        AND comm_brand_ds = 'MARBLANCA'
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,activation_date,service_id) = 1
    ) c ON a.phone_nm = CAST(c.phone_nm AS STRING) AND (a.activation_date = c.activation_date OR (a.activation_date != c.activation_date AND a.service_id = c.service_id))
    JOIN (
        SELECT 
          marca,
          service_id,
          tipo_concepto,
          id_comisionista,
          activation_date,
          phone_nm,
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(concepto, 'D - ', ''),'A - ', ''),'R - ',''),'Z - ',''),'E - ','') AS concepto,
          SUM(comision) AS comision
        FROM (
          SELECT * 
          FROM `mm-commissions-reporting.COMISIONES.transacciones` 
          WHERE estado != 'calculado'
        ) a
        WHERE 1=1
          AND a.marca = 'MARBLANCA' 
          AND a.tipo_concepto = 'UPFR' 
          AND a.concepto NOT LIKE ('%Clawback%') 
          AND a.concepto != 'RETROACCION EXTRA SID:1766' --Retrotracciones negativas que se quedan en negativo. No en clawback
          --AND phone_nm = '865539768'
          --AND a.comision > 0
        GROUP BY ALL
      ) h ON h.phone_nm = a.phone_nm AND h.tipo_concepto = a.tipo_concepto AND h.concepto = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.concepto, 'D - ', ''),'A - ', ''),'R - ',''),'Z - ',''),'E - ','')AND a.id_comisionista = h.id_comisionista  AND h.comision != 0 AND (a.activation_date = h.activation_date OR (a.activation_date != h.activation_date AND a.service_id = h.service_id))
    WHERE a.canal IN UNNEST(SPLIT(canales_str, ',')) 
      AND a.estado NOT IN ('calculado','rechazado')
      AND a.tipo_concepto = 'UPFR'
      --Quitamos las FDZ Y 3268, 3628 que no tienen que tener clawback
      AND NOT (a.concepto LIKE '%FDZ%'
        OR a.concepto LIKE '%3286%'
        OR a.concepto LIKE '%3628%'
        OR a.concepto LIKE '%4527%'
      )
  ),

  base_clawback_general AS ( --Desarrollo para determinar los meses para el clawback especial de Servicio Base según maestro de tarifas y cod_tipo_comisionista
    SELECT a.*,
      ROUND((i.clawback)*30.41,0) AS meses_maestro_serv
    FROM base_clawback_g a
    LEFT JOIN (
        SELECT 
          id_comisionista,
          tariff_id,
          tariff_ds,
          cod_tipo_comisionista,
          upfront,
          clawback
        FROM  `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB` a 
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA` b ON b.canal = a.cod_tipo_comisionista
      ) i ON i.id_comisionista = a.id_comisionista AND i.tariff_id = a.tariff_id AND a.concepto = 'Servicio base'
  ),

  --Realizamos el cruce con los distintos clawbacks

  clawback_general_f AS (

    SELECT a.*,
      i.FECHA_PRORRATEO AS FECHA_PRORRATEO,
      DATE_DIFF(a.deactivation_date, a.activation_date,DAY) AS dias_mod,--Dif de fechas por días
      ROUND(j.CLAWBACK_N_MESES*30.41,0) AS CLAWBACK_N_MESES, --Transformamos los meses en días
      COALESCE(i.comentario,j.comentario,'BAJA DEL MES')AS comentario,
    FROM base_clawback_general a
    LEFT JOIN(
      SELECT DISTINCT --OK
        DEALER,
        categorizacion,
        MSISDN,
        INCENTIVO_POR_ALTA,
        FECHA_PRORRATEO,
        CLAWBACK_PRORRATEADO,
        'BAJA PRORRATEADA' AS comentario
      FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_MB_*` --base_campana_f
      WHERE CLAWBACK_PRORRATEADO IS TRUE AND FECHA_PRORRATEO IS NOT NULL
    ) i ON a.concepto = i.categorizacion AND i.MSISDN = a.phone_nm AND ROUND(a.comision,2) = i.INCENTIVO_POR_ALTA AND a.id_comisionista = i.DEALER
    LEFT JOIN (
        SELECT DISTINCT --OK
          categorizacion,
          DEALER,
          INCENTIVO_POR_ALTA,
          CLAWBACK_N_MESES,
          'BAJA N MESES' AS comentario
        FROM `mm-commissions-reporting.B2B.EXTRA_CAMPANA_MB_*` --base_campana_f
        WHERE CLAWBACK_N_MESES IS NOT NULL
    ) j ON a.concepto = j.CATEGORIZACION AND a.id_comisionista = j.DEALER AND a.comision = j.INCENTIVO_POR_ALTA
  ),

  clawback_prorrateado AS (
    SELECT a.* EXCEPT(comision,comentario),
      a.comision AS comision_upfront,
      -(a.comision - ((a.comision / 12) * DATE_DIFF(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH),FECHA_PRORRATEO,MONTH))) AS comision, 
      comentario
      -- DATE_DIFF(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH),FECHA_PRORRATEO,MONTH)))
    FROM clawback_general_f a
    WHERE 1=1
      AND deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
      -- BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      AND DATE_DIFF(
        FECHA_PRORRATEO,  
        DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH),  -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
        MONTH
      ) <= DATE_DIFF(
        LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH)),  -- LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH))
        DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 11 MONTH), MONTH),  -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), MONTH)
        MONTH)
      AND comentario = 'BAJA PRORRATEADA'
  ),

  clawback_N_meses AS (
    SELECT a.* EXCEPT(comision,comentario),
      a.comision AS comision_upfront,
      a.comision * -1 AS comision,
      comentario
    FROM clawback_general_f a
    WHERE 1=1
      AND dias_mod <= CLAWBACK_N_MESES  
      AND deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
      AND comentario = 'BAJA N MESES'
      --AND phone_nm = '960435957'
  ),

  clawback_del_mes_camp AS (
    SELECT a.* EXCEPT(comision,comentario),
      a.comision AS comision_upfront,
      -1*a.comision AS comision,
      'BAJA DEL MES CAMP' AS comentario
    FROM clawback_general_f a
    WHERE 1=1
      AND a.deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
      -- BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      AND DATE_DIFF(a.deactivation_date,a.activation_date, DAY) <= 365 --DATE_DIFF (LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH)),DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 11 MONTH), MONTH), DAY)
      -- DATE_DIFF(deactivation_date,activation_date, DAY) <= DATE_DIFF (LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)),DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), MONTH), DAY)
    AND a.comentario = 'BAJA DEL MES'
    AND a.concepto != 'Servicio base'
    
  ),

  clawback_del_mes_serv AS (
    SELECT a.* EXCEPT(comision,comentario),
      a.comision AS comision_upfront,
      -1*a.comision AS comision,
      'BAJA DEL MES SERV' AS comentario
    FROM clawback_general_f a
    WHERE 1=1
      AND a.deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
      -- BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      AND dias_mod <= meses_maestro_serv
      -- AND DATE_DIFF(a.deactivation_date,a.activation_date, DAY) <= DATE_DIFF (LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH)),DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 11 MONTH), MONTH), DAY)
      -- DATE_DIFF(deactivation_date,activation_date, DAY) <= DATE_DIFF (LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)),DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), MONTH), DAY)
    AND a.comentario = 'BAJA DEL MES'
    AND a.concepto = 'Servicio base'
  ),

  clawback_total AS (
    SELECT *
    FROM clawback_prorrateado
    UNION ALL
    SELECT *
    FROM clawback_del_mes_camp
    UNION ALL
    SELECT *
    FROM clawback_del_mes_serv
    UNION ALL
    SELECT *
    FROM clawback_N_meses
  )

  
    SELECT *
    FROM clawback_total
    WHERE 1=1
    --Realizamos el Qualify porque al tener conceptos con A/D/E por un lado y por el otro agrupados sin letras se duplican y la idea es que quede uno en la suma por concepto.
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id_comisionista, phone_nm,concepto)= 1
  ); --base_clawback

   -- AND a.deactivation_date BETWEEN  DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
  --     AND DATE_DIFF(a.deactivation_date,a.activation_date, DAY) <= DATE_DIFF (LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)),DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), MONTH), DAY)
  -- ),
  --Fin clawback general
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_armb_revision` AS (

WITH

  col AS ( 

    SELECT DISTINCT tariff_id,tariff_ds, cod_tipo_comisionista, cuota, cuota_bts, service_type,line_type, upfront,upfront_bst
    FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB`
  ),

  ip_cve AS (
    SELECT DISTINCT * 
    FROM `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MARB_IP_CVE`
  ),

  extra_menos_75 AS (
    SELECT * EXCEPT(activation_date),
      activation_date AS activation_date_75,
      ROW_NUMBER() OVER(PARTITION BY current_sfid_id ORDER BY activation_date ASC) AS orden
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront` base_upfront 
    WHERE activation_date >= '2024-01-01'
      AND TIPO_PAQUETE = '2P' 
      AND current_sfid_id = 'C09-00014'
  ), 
  
  maestro_pvp AS (
    SELECT DISTINCT id_paquete, nombre_paquete,precio_sin_iva AS precio__sin_iva
    FROM `mm-b2b-reporting.MAESTROS.maestro_paquete_mysim` 
    --FROM `mm-b2b-reporting.MAESTROS.Maestro_bundle_mysim`
    WHERE marca = 'MARBLANCA'
  ),

  dealers AS ( 
    
    SELECT 
      id_comisionista, 
      canal, 
      razon_social, 
      documento,
      zona_fiscal,
      no_autofactura,
      Cambiar_comision,
    	cliente_a_comision,
      canal_cambio,
      nombre_comercio_cambio,
      documento_cambio,
      zona_fiscal_cambio,
      Email
    FROM `mm-commissions-reporting.GS.DEALERS_MARBLANCA` s
    WHERE comisiona = true

  ),

  max_orden AS (
    SELECT current_sfid_id, MAX(orden_cartera) AS orden_cartera_final
    FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` base
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
      AND current_sfid_id = 'C09-00422'
    GROUP BY 1
  ),

  traspaso_cartera_octel AS (
    SELECT *
    FROM `mm-commissions-reporting.TEMP.traspaso_cartera_octel`
  ),
      
  b AS ( --Diferencia 60 mil real por efectividad del cálculo
    SELECT 
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'B2B - Marblanca Alterna'
        ELSE 'B2B - Marblanca' 
      END AS agrupacion_canal,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'MBA'
        ELSE 'MB' 
      END AS canal,
      base.billing_tier_1,
      CASE  
        WHEN base.TIPO_PAQUETE = 'MO'  THEN CONCAT('C - Gestion Cartera Movil ','(',
          CASE
            WHEN base.billing_tier_1 LIKE '%CONSUMO%' AND COALESCE(dealers.canal,dealers_2.canal) = 'PARLEM' THEN 38
            WHEN octel.phone_nm IS NOT NULL AND octel.porcentaje_cartera IS NOT NULL THEN octel.porcentaje_cartera
            WHEN (base.billing_tier_1 LIKE '%IP FIJA%' OR base.billing_tier_1 LIKE '%CONSUMO%' OR base.billing_tier_1 LIKE '%BONO EXTRA%' OR base.billing_tier_1 LIKE '%DESCUENTO%') THEN ip_cve.cuota 
            WHEN (base.tariff_ds LIKE 'TARIFA%' AND base.TIPO_PAQUETE = 'MO') OR base.TIPO_PAQUETE = 'MO' THEN 25
            WHEN base.first_territory_ds LIKE 'BST%' THEN  col.cuota_bts
            WHEN col.cuota IS NULL THEN  0
            ELSE col.cuota 
          END ,'%)')
        WHEN base.TIPO_PAQUETE = 'FMC' THEN CONCAT('C - Gestion Cartera 3P ','(',
          CASE
            WHEN base.billing_tier_1 LIKE '%CONSUMO%' AND COALESCE(dealers.canal,dealers_2.canal) = 'PARLEM' THEN 38
            WHEN octel.phone_nm IS NOT NULL AND octel.porcentaje_cartera IS NOT NULL THEN octel.porcentaje_cartera
            WHEN (base.billing_tier_1 LIKE '%IP FIJA%' OR base.billing_tier_1 LIKE '%CONSUMO%' OR base.billing_tier_1 LIKE '%BONO EXTRA%' OR base.billing_tier_1 LIKE '%DESCUENTO%') THEN ip_cve.cuota 
            WHEN (base.first_territory_ds LIKE 'BST%'AND col.cuota_bts IS NOT NULL) THEN col.cuota_bts
            WHEN col.cuota IS NULL THEN 0
            ELSE col.cuota
          END,'%)')
        WHEN base.TIPO_PAQUETE = '2P'  THEN CONCAT('C - Gestion Cartera 2P ','(', 
          CASE
            WHEN base.billing_tier_1 LIKE '%CONSUMO%' AND COALESCE(dealers.canal,dealers_2.canal) = 'PARLEM' THEN 38
            WHEN octel.phone_nm IS NOT NULL AND octel.porcentaje_cartera IS NOT NULL THEN octel.porcentaje_cartera
            WHEN (base.billing_tier_1 LIKE '%IP FIJA%' OR base.billing_tier_1 LIKE '%CONSUMO%' OR base.billing_tier_1 LIKE '%BONO EXTRA%' OR base.billing_tier_1 LIKE '%DESCUENTO%') THEN ip_cve.cuota 
            WHEN CAST(base.current_sfid_id AS STRING) = 'C09-00422' THEN
              CASE
                WHEN base.tariff_ds LIKE '%INDIRECTA%' THEN
                  CASE
                    WHEN base.tariff_ds LIKE '%300%' THEN 15
                    WHEN base.tariff_ds LIKE '%600%' OR base.tariff_ds LIKE '%1GB%' THEN 20
                  END
                ELSE
                  CASE
                    WHEN max_orden.orden_cartera_final <= 5000                 THEN 25
                    WHEN max_orden.orden_cartera_final BETWEEN 5001 AND 10000  THEN 27
                    WHEN max_orden.orden_cartera_final BETWEEN 10001 AND 12500 THEN 29
                    WHEN max_orden.orden_cartera_final > 12500                 THEN 30
                    ELSE 0
                  END
              END
            WHEN base.first_territory_ds LIKE 'BST%' AND col.cuota_bts IS NOT NULL THEN col.cuota_bts
            WHEN col.cuota IS NULL THEN  0
            ELSE col.cuota
          END ,'%)')
        ELSE 'C - Gestion Cartera Resto'
      END    AS concepto,
      'AIRT' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      base.imp_without_tax AS imp_base,
      CASE  
        WHEN base.billing_tier_1 LIKE '%CONSUMO%' AND COALESCE(dealers.canal,dealers_2.canal) = 'PARLEM' THEN imp_without_tax*38/100
        WHEN octel.phone_nm IS NOT NULL AND octel.porcentaje_cartera IS NOT NULL THEN base.imp_without_tax*octel.porcentaje_cartera/100
        WHEN (base.billing_tier_1 LIKE '%IP FIJA%' OR base.billing_tier_1 LIKE '%CONSUMO%' OR base.billing_tier_1 LIKE '%BONO EXTRA%' OR base.billing_tier_1 LIKE '%DESCUENTO%')  THEN base.imp_without_tax*ip_cve.cuota/100
        WHEN CAST(base.current_sfid_id AS STRING) = 'C09-00422' THEN
              CASE
                WHEN base.tariff_ds LIKE '%INDIRECTA%' THEN
                  CASE
                    WHEN base.tariff_ds LIKE '%300%' THEN base.imp_without_tax*0.15
                    WHEN base.tariff_ds LIKE '%600%' OR base.tariff_ds LIKE '%1GB%' THEN base.imp_without_tax*0.20
                  END
                ELSE
                  CASE
                    WHEN max_orden.orden_cartera_final <= 5000                 THEN base.imp_without_tax*0.25
                    WHEN max_orden.orden_cartera_final BETWEEN 5001 AND 10000  THEN base.imp_without_tax*0.27
                    WHEN max_orden.orden_cartera_final BETWEEN 10001 AND 12500 THEN base.imp_without_tax*0.29
                    WHEN max_orden.orden_cartera_final > 12500                 THEN base.imp_without_tax*0.30
                    ELSE 0
                  END
              END
        WHEN col.cuota IS NULL THEN 0
        WHEN base.first_territory_ds LIKE 'BST%' THEN base.imp_without_tax*col.cuota_bts/100
        ELSE base.imp_without_tax*col.cuota/100
      END AS comision,
      COALESCE(dealers.cambiar_comision, dealers_2.cambiar_comision) AS cambiar_comision,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS id_comisionista,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS distribuidor,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS sfid_id,
      CASE
        WHEN base.current_sfid_id = current_user_store THEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision)
        WHEN base.current_sfid_id = SUBSTR(current_user_store, 1,9) THEN current_user_store
        ELSE CONCAT(COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision), '-', current_user_store) 
      END AS seller,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS nombre_comercio,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS razon_social,
      COALESCE(dealers.documento, dealers_2.documento_cambio) AS cif,
      COALESCE(dealers.zona_fiscal, dealers_2.zona_fiscal_cambio) AS zona_fiscal,
      CAST(NULL AS STRING)    AS cond_pago,
      'MARBLANCA'             AS marca,
      base.service_type       AS service_type,
      CAST(base.phone_nm AS STRING)           AS phone_nm,
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
      IF(base.deactivation_date IS NULL, '9999-12-31',base.deactivation_date)  AS deactivation_date,
      CAST(base.order_id AS STRING)           AS order_id,
      base.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base.billing_type_ds, base.service_type, base.TIPO_PAQUETE, base.technology_ds ,base.line_type_ds , base.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN col.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      base.billing_tier_1     AS campaign_code,
      CAST(NULL AS STRING)    AS serial_number,
      CAST(NULL AS FLOAT64)   AS tax_base,
      CAST(NULL AS STRING)    AS claim_code,
      base.invoice_id         AS process_code,
      CASE
        WHEN COALESCE(dealers.no_autofactura, dealers_2.no_autofactura) = 1 THEN 'No autofactura'
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
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_cartera`base
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 0) dealers ON base.current_sfid_id = dealers.id_comisionista 
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 1) dealers_2 ON base.current_sfid_id = dealers_2.id_comisionista 
    LEFT JOIN col ON col.tariff_id = base.tariff_id 
      AND col.service_type = base.service_type
      AND col.line_type = base.line_type_ds
      AND COALESCE(dealers.canal, dealers_2.canal) = col.cod_tipo_comisionista
    LEFT JOIN max_orden ON max_orden.current_sfid_id = base.current_sfid_id
    LEFT JOIN ip_cve ON  ip_cve.tariff_id = base.tariff_id
      AND ip_cve.service_type = base.service_type
      AND ip_cve.line_type = base.line_type_ds
      AND COALESCE(dealers.canal, dealers_2.canal) = ip_cve.cod_tipo_comisionista
    --Agregamos la cartera de las lineas antiguas de octel para que se comisionen por el porcentaje viejo
    LEFT JOIN traspaso_cartera_octel octel ON CAST(octel.phone_nm AS INT64) = base.phone_nm AND octel.tariff_id = base.tariff_id AND base.current_sfid_id = octel.id_comisionista_mb
  ),

  cartera_tuca AS (

    SELECT 
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'B2B - Marblanca Alterna'
        ELSE 'B2B - Marblanca' 
      END AS agrupacion_canal,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'MBA'
        ELSE 'MB' 
      END AS canal,
      base.billing_tier_1,
      'C - Gestion Cartera Gescal' AS concepto,
      'AIRT' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades,
      base.imp_without_tax AS imp_base,
      precio__sin_iva - 7 AS comision,
      -- CASE
      --   WHEN deactivation_date != '9999-12-31' THEN  ((precio__sin_iva - 7)/DATE_DIFF(deactivation_date, DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH),DAY))
      --   ELSE (precio__sin_iva - 7)
      -- END AS comision,
      COALESCE(dealers.cambiar_comision, dealers_2.cambiar_comision) AS cambiar_comision,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS id_comisionista,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS distribuidor,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS sfid_id,
      CASE
        WHEN base.current_sfid_id = current_user_store THEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision)
        ELSE CONCAT(COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision), '-', current_user_store) 
      END AS seller,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS nombre_comercio,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS razon_social,
      COALESCE(dealers.documento, dealers_2.documento_cambio) AS cif,
      COALESCE(dealers.zona_fiscal, dealers_2.zona_fiscal_cambio) AS zona_fiscal,
      CAST(NULL AS STRING)    AS cond_pago,
      'MARBLANCA'             AS marca,
      base.service_type       AS service_type,
      CAST(base.phone_nm AS STRING)           AS phone_nm,
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
      IF(base.deactivation_date IS NULL, '9999-12-31',base.deactivation_date)  AS deactivation_date,
      CAST(base.order_id AS STRING)           AS order_id,
      base.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base.billing_type_ds, base.service_type, base.TIPO_PAQUETE, base.technology_ds ,base.line_type_ds , base.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN col.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)    AS campaign_code,
      CAST(NULL AS STRING)    AS serial_number,
      maestro_pvp.precio__sin_iva   AS tax_base,
      -- CASE
      --   WHEN deactivation_date != '9999-12-31' THEN  ((precio__sin_iva/DATE_DIFF(deactivation_date, DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH),DAY))
      --   ELSE precio__sin_iva
      -- END AS tax_base,
      CAST(NULL AS STRING)    AS claim_code,
      CAST(NULL AS STRING)    AS process_code,
      CASE
        WHEN COALESCE(dealers.no_autofactura, dealers_2.no_autofactura) = 1 THEN 'No autofactura'
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
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_cartera_tuca` base
    LEFT JOIN maestro_pvp ON base.tariff_id = maestro_pvp.id_paquete
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 0) dealers 
      ON base.current_sfid_id = dealers.id_comisionista 
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 1) dealers_2 
      ON base.current_sfid_id = dealers_2.id_comisionista
    LEFT JOIN col ON col.tariff_id = base.tariff_id 
      AND col.service_type = base.service_type
      AND col.line_type = base.line_type_ds
      AND COALESCE(dealers.canal, dealers_2.canal) = col.cod_tipo_comisionista 

  ),

  upfront_act_org AS ( --Cuadrado al 99%
    SELECT 
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'B2B - Marblanca Alterna'
        ELSE 'B2B - Marblanca' 
      END AS agrupacion_canal,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'MBA'
        ELSE 'MB' 
      END AS canal,
      'A - Servicio base' AS concepto,
      'UPFR' AS tipo_concepto,
      1 AS unidades,
      CASE 
        --WHEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) = 'C09-00422' THEN 100
        WHEN col.cuota IS NULL THEN 0
        WHEN base_upfront.first_territory_ds LIKE 'BST%' THEN upfront_bst
        ELSE upfront
      END AS comision,
      COALESCE(dealers.cambiar_comision, dealers_2.cambiar_comision) AS cambiar_comision,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS id_comisionista,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS distribuidor,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS sfid_id,
      CASE
        WHEN current_sfid_id = current_user_store THEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision)
        WHEN base_upfront.current_sfid_id = SUBSTR(current_user_store, 1,9) THEN current_user_store
        ELSE CONCAT(COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision), '-', current_user_store) 
      END AS seller,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS nombre_comercio,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS razon_social,
      COALESCE(dealers.documento, dealers_2.documento_cambio) AS cif,
      COALESCE(dealers.zona_fiscal, dealers_2.zona_fiscal_cambio) AS zona_fiscal,
      CAST(NULL AS STRING)            AS cond_pago,
      'MARBLANCA'                     AS marca,
      base_upfront.service_type       AS service_type,
      CAST(base_upfront.phone_nm AS STRING)           AS phone_nm,
      base_upfront.tariff_id          AS tariff_id,
      base_upfront.tariff_ds          AS tariff_ds,
      base_upfront.service_id         AS service_id,
      base_upfront.account_id         AS account_id,
      base_upfront.customer_id        AS customer_id,
      base_upfront.line_type_ds       AS line_type_ds,
      base_upfront.TIPO_PAQUETE       AS bundle_type,
      base_upfront.technology_ds      AS technology_ds,
      base_upfront.billing_type_ds    AS billing_type_ds,
      base_upfront.order_day_id       AS sale_date,
      base_upfront.activation_date    AS activation_date,
      IF(base_upfront.deactivation_date IS NULL,'9999-12-31',base_upfront.deactivation_date)  AS deactivation_date,
      CAST(base_upfront.order_id AS STRING)           AS order_id,
      base_upfront.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront.billing_type_ds, base_upfront.service_type, base_upfront.TIPO_PAQUETE, base_upfront.technology_ds ,base_upfront.line_type_ds , base_upfront.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN col.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)    AS campaign_code,
      CAST(NULL AS STRING)    AS serial_number,
      CAST(NULL AS FLOAT64)   AS tax_base,
      CAST(NULL AS STRING)    AS claim_code,
      CAST(NULL AS STRING)    AS process_code,
      CASE
        WHEN COALESCE(dealers.no_autofactura, dealers_2.no_autofactura) = 1 THEN 'No autofactura'
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
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront`  base_upfront
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 0) dealers ON base_upfront.current_sfid_id = dealers.id_comisionista 
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 1) dealers_2 ON base_upfront.current_sfid_id = dealers_2.id_comisionista 
    LEFT JOIN col ON col.tariff_id = base_upfront.tariff_id 
      AND col.service_type = base_upfront.service_type
      AND col.line_type = base_upfront.line_type_ds
      AND COALESCE(dealers.canal, dealers_2.canal) = col.cod_tipo_comisionista
    --CALCULO ÚNICO DE LAS LINEAS UPFRONT DEL MES CORRESPONDIENTE
    WHERE 1=1
      AND activation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
  ),

  upfront_act AS (
    SELECT upfront_act_org.*
    FROM upfront_act_org
    WHERE 1=1
      --Quitamos las altas de servicio base de los cableros de alterna por la migracion errónea
      AND id_comisionista NOT IN (
        SELECT c.id_comisionista
        FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA`  c ON a.cif = c.documento
        WHERE c.id_comisionista IS NOT NULL
      )
      -- AND COALESCE(dealers.canal,dealers_2.canal) NOT LIKE 'ALT%' --Quitamos las altas de servicio base de los cableros de alterna por la migracion errónea
  ),

  serv_base_alt AS ( 
    SELECT upfront_act_org.*
    FROM upfront_act_org
      --Realizanos el JOIN con las altas de los cableros de alterna DEL MES
    JOIN (
      SELECT * 
      FROM `mm-commissions-reporting.B2B.agrupado_alta_real_armb_*`
      WHERE 1=1
        AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
    ) b ON CAST(b.phone_nm AS STRING) = upfront_act_org.phone_nm AND b.activation_date = upfront_act_org.activation_date AND b.current_sfid_id = upfront_act_org.id_comisionista
    WHERE 1=1
      --Agregamos altas de servicio base de los cableros de alterna por la migracion errónea que se hayan comisionado
      AND id_comisionista IN (
        SELECT c.id_comisionista
        FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA`  c ON a.cif = c.documento
        WHERE c.id_comisionista IS NOT NULL
      )
      -- AND COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' --Agregamos altas de servicio base de los cableros de alterna por la migracion errónea que se hayan comisionado como COSTE DE ALTA
  ),

   upfront_extra_org AS (--Cuadrado al 99%
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
      CAST(mes_string AS INT64) as id_mes,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'B2B - Marblanca Alterna'
        ELSE 'B2B - Marblanca' 
      END AS agrupacion_canal,
      CASE
        WHEN COALESCE(dealers.canal,dealers_2.canal) LIKE 'ALT%' THEN 'MBA'
        ELSE 'MB' 
      END AS canal,
      CASE
        WHEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) IN ('C09-00402','C09-00463','C09-00193') AND base_upfront_1354.TIPO_PAQUETE = 'FMC' AND base_upfront_1354.activation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH)) 
        -- BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
        THEN 'D - EXTRA CAMPANA ID:1354'  
        WHEN campanas.DESDE = '9999-12-31' THEN CONCAT('D - ',campanas.CATEGORIZACION)
        WHEN base_upfront_1354.activation_date BETWEEN campanas.DESDE AND campanas.HASTA THEN CONCAT('D - ',campanas.CATEGORIZACION)
        ELSE 'No cruza'
      END AS concepto,
      'UPFR' AS tipo_concepto,
      '1' AS unidades,
      CASE
        WHEN PVP_BOOLEAN IS TRUE 
        THEN `mm-commissions-reporting.B2B.f_calculo_camp_N_PVP_MB`(campanas.DESDE,campanas.HASTA, base_upfront_1354.TIPO_PAQUETE, campanas.TIPO_LINEA, CAST(base_upfront_1354.phone_nm AS STRING), INCENTIVO_POR_ALTA, activation_date,duplicados, base_upfront_1354.tariff_ds, dealers.id_comisionista, base_upfront_1354.tariff_id, n_activaciones_desde, n_activaciones_hasta, PVP_desde, PVP_hasta,precio__sin_iva, campanas_MO_FMC.MSISDN_MO_FMC,campanas_MO_FMC.FECHA_ACTIVACION_MOVIL_ASOCIADO, base_upfront_1354.document_type, b.tres_P,b.doss_P,b.tres_P_DIR,b.tres_P_IND,b.tres_P_300,b.tres_P_600,b.tres_P_1gb,b.tres_P_CMP,b.tres_P_resto,b.tres_P_300_DIR,b.tres_P_600_DIR,b.tres_P_1gb_DIR, b.tres_P_300_IND, b.tres_P_600_IND, b.tres_P_1gb_IND, b.EMPRESAS_CIF_2P, b.EMPRESAS_NIE_2P, b.EMPRESAS_CIF_3P)
        WHEN n_activaciones_desde IS NOT NULL 
        THEN `mm-commissions-reporting.CABLEOPERADORES.f_calculo_camp_N_activaciones_MB`(campanas.DESDE,campanas.HASTA, base_upfront_1354.TIPO_PAQUETE, campanas.TIPO_LINEA, CAST(base_upfront_1354.phone_nm AS STRING), INCENTIVO_POR_ALTA, activation_date,duplicados, base_upfront_1354.tariff_ds, dealers.id_comisionista, base_upfront_1354.tariff_id, n_activaciones_desde, n_activaciones_hasta, tres_P,doss_P)
        WHEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) IN ('C09-00402','C09-00463','C09-00193') AND base_upfront_1354.TIPO_PAQUETE = 'FMC' AND base_upfront_1354.activation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH)) THEN 100
        ELSE
      `mm-commissions-reporting.CABLEOPERADORES.f_calculo_campanas_MB`(campanas.DESDE,campanas.HASTA, base_upfront_1354.TIPO_PAQUETE,campanas.TIPO_LINEA, campanas.MSISDN, CAST(base_upfront_1354.phone_nm AS STRING), campanas.duplicados ,campanas.INCENTIVO_POR_ALTA, base_upfront_1354.activation_date, base_upfront_1354.tariff_ds, campanas.concepto, dealers.id_comisionista, base_upfront_1354.tariff_id, extra_menos_75.orden, extra_menos_75.activation_date_75,base_upfront_1354.document_type, campanas_MO_FMC.MSISDN_MO_FMC, campanas_MO_FMC.FECHA_ACTIVACION_MOVIL_ASOCIADO) 
      END AS comision,
      COALESCE(dealers.cambiar_comision, dealers_2.cambiar_comision)  AS cambiar_comision,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS id_comisionista,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS distribuidor,
      COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision) AS sfid_id,
      CASE
        WHEN base_upfront_1354.current_sfid_id = base_upfront_1354.current_user_store THEN COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision)
        WHEN base_upfront_1354.current_sfid_id = SUBSTR(base_upfront_1354.current_user_store, 1,9) THEN base_upfront_1354.current_user_store
        ELSE CONCAT(COALESCE(dealers.id_comisionista, dealers_2.cliente_a_comision), '-', base_upfront_1354.current_user_store) 
      END AS seller,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS nombre_comercio,
      COALESCE(dealers.razon_social, dealers_2.nombre_comercio_cambio) AS razon_social,
      COALESCE(dealers.documento, dealers_2.documento_cambio)          AS cif,
      COALESCE(dealers.zona_fiscal, dealers_2.zona_fiscal_cambio)      AS zona_fiscal,
      CAST(NULL AS STRING)            AS cond_pago,
      'MARBLANCA'                     AS marca,
      base_upfront_1354.service_type       AS service_type,
      CAST(base_upfront_1354.phone_nm AS STRING)           AS phone_nm,
      base_upfront_1354.tariff_id          AS tariff_id,
      base_upfront_1354.tariff_ds          AS tariff_ds,
      base_upfront_1354.service_id         AS service_id,
      base_upfront_1354.account_id         AS account_id,
      base_upfront_1354.customer_id        AS customer_id,
      base_upfront_1354.line_type_ds       AS line_type_ds,
      base_upfront_1354.TIPO_PAQUETE       AS bundle_type,
      base_upfront_1354.technology_ds      AS technology_ds,
      base_upfront_1354.billing_type_ds    AS billing_type_ds,
      base_upfront_1354.order_day_id       AS sale_date,
      base_upfront_1354.activation_date    AS activation_date,
      IF(base_upfront_1354.deactivation_date IS NULL,'9999-12-31',base_upfront_1354.deactivation_date)  AS deactivation_date,
      CAST(base_upfront_1354.order_id AS STRING)           AS order_id,
      base_upfront_1354.order_type_agg     AS order_type_agg,
      '42'                    AS cod_segmento,
      '09'                    AS cod_marca,
      `mm-commissions-reporting.CABLEOPERADORES.f_codigo_tipo_contrato` (base_upfront_1354.billing_type_ds, base_upfront_1354.service_type, base_upfront_1354.TIPO_PAQUETE, base_upfront_1354.technology_ds ,base_upfront_1354.line_type_ds , base_upfront_1354.brand_ds)       AS cod_tipo_contrato,
      '30'                    AS cod_canal,
      CASE 
        WHEN col.service_type IN ('INTERNET', 'FIX') THEN '039'   
        WHEN base_upfront_1354.order_type_agg = 'PORTABILIDAD' THEN '040'
        ELSE '039'   
      END                     AS cod_producto,
      CAST(NULL AS STRING)    AS campaign_code,
      CAST(NULL AS STRING)    AS serial_number,
      CAST(NULL AS FLOAT64)   AS tax_base,
      CAST(NULL AS STRING)    AS claim_code,
      CAST(NULL AS STRING)    AS process_code,
      CASE
        WHEN COALESCE(dealers.no_autofactura, dealers_2.no_autofactura) = 1 THEN 'No autofactura'
        ELSE 'Autofactura'
      END                      AS comments,
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
      campanas.* EXCEPT(id_mes,agrupacion_canal ,concepto,tariff_id, categorizacion),
      maestro_pvp.*,
      b.* EXCEPT(DESDE,HASTA)
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront_1354` base_upfront_1354  --CAMBIADO A BASE_UPFRONT_1354
    LEFT JOIN (
      SELECT 
        cuenta_cliente,
        document_number,
        customer_id_xena,
        provincia,
        segmento
      FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
      ) b2b_xena ON base_upfront_1354.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN `mm-commissions-reporting.TEMP.comisiones_armb_revision_campanas` campanas ON campanas.dealer = base_upfront_1354.current_sfid_id
    LEFT JOIN extra_menos_75 ON extra_menos_75.phone_nm = base_upfront_1354.phone_nm
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 0) dealers ON base_upfront_1354.current_sfid_id = dealers.id_comisionista 
    LEFT JOIN (
      SELECT *
      FROM dealers
      WHERE cambiar_comision = 1) dealers_2 ON base_upfront_1354.current_sfid_id = dealers_2.id_comisionista 
    LEFT JOIN col ON col.tariff_id = base_upfront_1354.tariff_id 
      AND col.service_type = base_upfront_1354.service_type
      AND col.line_type = base_upfront_1354.line_type_ds
      AND COALESCE(dealers.canal, dealers_2.canal) = col.cod_tipo_comisionista  
    --Cruce para sacar las cantidades de lineas vendidas
    LEFT JOIN (
      SELECT DISTINCT 
        categorizacion,
        DESDE,
        HASTA,
        SUM(IF(TIPO_PAQUETE = '2P', 1,0)) AS doss_P,
        SUM(IF(TIPO_PAQUETE = 'FMC', 1,0)) AS tres_P,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND tariff_ds NOT LIKE '%INDIRECTA%', 1,0)) AS tres_P_DIR,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND tariff_ds LIKE '%INDIRECTA%', 1,0)) AS tres_P_IND,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND tariff_ds LIKE '%300%',1,0)) AS tres_P_300,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND tariff_ds LIKE '%600%',1,0)) AS tres_P_600,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND (tariff_ds LIKE '%1 GB%'OR tariff_ds LIKE '%1GB%'),1,0)) AS tres_P_1gb,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND tariff_ds LIKE '%COMPARTIDAS%',1,0)) AS tres_P_CMP,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND tariff_ds NOT LIKE '%COMPARTIDAS%',1,0)) AS tres_P_resto,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND (tariff_ds LIKE '%300%' AND tariff_ds NOT LIKE '%INDIRECTA%'),1,0)) AS tres_P_300_DIR,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND (tariff_ds LIKE '%600%' AND tariff_ds NOT LIKE '%INDIRECTA%'),1,0)) AS tres_P_600_DIR,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND ((tariff_ds LIKE '%1GB%' OR tariff_ds LIKE '%1 GB%')AND tariff_ds NOT LIKE '%INDIRECTA%'),1,0)) AS tres_P_1gb_DIR,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND (tariff_ds LIKE '%300%' AND tariff_ds LIKE '%INDIRECTA%'),1,0)) AS tres_P_300_IND,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND (tariff_ds LIKE '%600%' AND tariff_ds LIKE '%INDIRECTA%'),1,0)) AS tres_P_600_IND,
        SUM(IF(TIPO_PAQUETE = 'FMC' AND ((tariff_ds LIKE '%1GB%' OR tariff_ds LIKE '%1 GB%')AND tariff_ds LIKE '%INDIRECTA%'),1,0)) AS tres_P_1gb_IND,
        SUM(IF(TIPO_PAQUETE = '2P' AND document_type = 'CIF',1,0)) AS EMPRESAS_CIF_2P,
        SUM(IF(TIPO_PAQUETE = '2P' AND document_type = 'NIE',1,0)) AS EMPRESAS_NIE_2P,
        SUM(IF(TIPO_PAQUETE = '2P' AND document_type = 'CIF',1,0)) AS EMPRESAS_CIF_3P
      FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_base_upfront_1354` base_upfront_1354
      LEFT JOIN (
        SELECT DISTINCT 
          dealer,
          categorizacion,
          OPERADORES_MASORANGE,
          desde,
          hasta,
          fecha_campana 
        FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_campanas`
      ) campanas ON campanas.dealer = base_upfront_1354.current_sfid_id
      WHERE activation_date BETWEEN DESDE AND HASTA
        AND fecha_campana = last_day(PARSE_DATE('%Y%m',mes_string)) -- last_day(date_sub(current_date(),INTERVAL 1 month))
        AND NOT(grupo_operador_donante_unificado IN ('MASORANGE','GRUPO MASMOVIL','ORANGE')AND OPERADORES_MASORANGE IS TRUE)
      GROUP BY ALL
    ) b ON campanas.categorizacion = b.categorizacion AND base_upfront_1354.activation_date BETWEEN b.DESDE AND b.HASTA
    --Cruce para saber el PVP de las tarifas
    LEFT JOIN maestro_pvp ON base_upfront_1354.tariff_id = maestro_pvp.id_paquete
    --Cruce para las campañas 3P MO - FMC
    LEFT JOIN `mm-commissions-reporting.TEMP.comisiones_armb_revision_campanas_MO_FMC` campanas_MO_FMC ON base_upfront_1354.phone_nm = campanas_MO_FMC.MSISDN_MO_FMC AND base_upfront_1354.tariff_id = campanas_MO_FMC.TARIFA_ID AND base_upfront_1354.current_sfid_id = campanas_MO_FMC.id_comisionista_MB
    AND base_upfront_1354.activation_date = campanas_MO_FMC.FECHA_ACT_FIBRA
    --EXCLUIMOS ALTAS DEL GRUPO +O
    WHERE 1=1
      AND NOT(base_upfront_1354.grupo_operador_donante_unificado IN ('MASORANGE','GRUPO MASMOVIL','ORANGE')
        AND OPERADORES_MASORANGE IS TRUE)
      AND precio__sin_iva >= 1
  ),

  upfront_extra AS (
    SELECT upfront_extra_org.*
    FROM upfront_extra_org
    WHERE 1=1
      --Quitamos las altas de servicio base de los cableros de alterna por la migracion errónea
      AND id_comisionista NOT IN (
        SELECT c.id_comisionista
        FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA`  c ON a.cif = c.documento
        WHERE c.id_comisionista IS NOT NULL
      )
  ),

  upfront_extra_alt AS (--No filtramos el JOIN por fecha porque pueden ser fechas anteriores al mes en curso.
    SELECT upfront_extra_org.*
    FROM upfront_extra_org
    JOIN `mm-commissions-reporting.B2B.agrupado_alta_real_armb_*` b ON CAST(b.phone_nm AS STRING) = upfront_extra_org.phone_nm AND b.activation_date = upfront_extra_org.activation_date AND b.current_sfid_id = upfront_extra_org.id_comisionista
    WHERE 1=1
      --Agregamos altas de servicio base de los cableros de alterna por la migracion errónea que se hayan comisionado
      AND id_comisionista IN (
        SELECT c.id_comisionista
        FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
        LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA`  c ON a.cif = c.documento
        WHERE c.id_comisionista IS NOT NULL
      )
  ),

  

  one_off AS (
    SELECT DISTINCT
      'calculado' AS estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64)AS id_mes,
      CASE
        WHEN dealers.canal LIKE 'ALT%' THEN 'B2B - Marblanca Alterna'
        ELSE 'B2B - Marblanca' 
      END AS agrupacion_canal,
      CASE
        WHEN dealers.canal LIKE 'ALT%' THEN 'MBA'
        ELSE 'MB' 
      END AS canal,
      CONCAT('D - ',campanas.CATEGORIZACION)           AS concepto,
      'UPFR'                   AS tipo_concepto,
      1                        AS unidades,
      CAST(INCENTIVO_TOTAL AS FLOAT64)          AS comision,
      DEALER                   AS id_comisionista,
      DEALER                   AS distribuidor,
      DEALER                   AS sfid_id,
      DEALER                   AS seller,
      dealers.razon_social     AS nombre_comercio,
      dealers.razon_social     AS razon_social,
      dealers.documento        AS cif,
      dealers.zona_fiscal      AS zona_fiscal,
      CAST(NULL AS STRING)     AS cond_pago,
      'MARBLANCA'              AS marca,
      CAST(NULL AS STRING)     AS service_type,
      CAST(NULL AS STRING)     AS phone_nm,
      CAST(NULL AS STRING)     AS tariff_id,
      CAST(NULL AS STRING)     AS tariff_ds,
      CAST(NULL AS STRING)     AS service_id,
      CAST(NULL AS STRING)     AS account_id,
      CAST(NULL AS STRING)     AS customer_id,
      CAST(NULL AS STRING)     AS line_type_ds,
      CASE
        WHEN campanas.TIPO_LINEA = '3P' THEN 'FMC'
        WHEN campanas.TIPO_LINEA = '2P SALVO ADSL Y FTTH 50' THEN '2P'
      END AS bundle_type,
      CAST(NULL AS STRING)     AS technology_ds,
      CAST(NULL AS STRING)     AS billing_type_ds,
      CAST(NULL AS DATE)       AS sale_date,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS activation_date,
      --DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH), MONTH)    AS activation_date,
      CAST(NULL AS DATE)       AS deactivation_date,
      CAST(NULL AS STRING)     AS order_id,
      CAST(NULL AS STRING)     AS order_type_agg,
      '42'                     AS cod_segmento,
      '09'                     AS cod_marca,
      '61'                     AS cod_tipo_contrato,
      '30'                     AS cod_canal,
      '039'                    AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      'Autofactura'            AS comments,
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
    FROM `mm-commissions-reporting.TEMP.comisiones_armb_revision_campanas` campanas 
    LEFT JOIN dealers ON campanas.DEALER = dealers.id_comisionista  
    WHERE INCENTIVO_TOTAL != '0'    
  ),

  
  
  final AS (

    SELECT --SIN DISTINCT
    'b1' as origen,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
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
      imp_base  AS tax_base,
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

    SELECT --SIN DISTINCT
      'b2' as origen,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
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
    FROM cartera_tuca

    UNION ALL

    SELECT --SIN DISTINCT
    'b3' as origen,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
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
    FROM serv_base_alt

    UNION ALL

    SELECT DISTINCT
    'b4' as origen,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
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
    FROM upfront_act
    WHERE    
    --Grupo PARLEM - TOXO,... No comisionan en A
      NOT (id_comisionista IN ('C09-00402','C09-00463','C09-00193'))

    UNION ALL


    SELECT DISTINCT
      'b5' as origen,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
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
    FROM upfront_extra 

    UNION ALL


    SELECT DISTINCT
      'b6' as origen,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      1 AS unidades,
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
    FROM upfront_extra_alt
    
    
    UNION ALL

    SELECT DISTINCT
      'b7' as origen,
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
    FROM one_off
    GROUP BY ALL
    
  )

  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
  FROM final
  WHERE 1 = 1
    AND comision != 0
    --No tienen que comisionar por Mariola 2023-12-31
   AND id_comisionista != 'C09-00041'
   AND NOT (id_comisionista = 'C09-00062-0055' AND tipo_concepto = 'AIRT')
  --  AND tipo_concepto = 'AIRT'
  --  AND canal = 'MBA'
  --  AND id_comisionista = 'C09-00302'
  );


END