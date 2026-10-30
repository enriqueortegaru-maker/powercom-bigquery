BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre STRING;
DECLARE mes_siguiente DATE;
-- DECLARE mes DATE;

-- SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); 
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET mes_siguiente = DATE_ADD(mes, INTERVAL 1 MONTH);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','upfronts_base_arca_revisado_', mes_liqui, '');

-- CALL `mm-commissions-reporting.B2B.pr_upfronts_base_arca_revisado`('2026-10-01')

-- `mm-commissions-reporting.B2B.upfronts_base_arca_revisado_20260801`

-- IF NOT EXISTS(-- Cuidado que si se cambia pr_arca_campanas hay que cambiar el prefijo aqui
--     SELECT *
--     FROM `mm-commissions-reporting.COMISIONES.transacciones`
--     WHERE canal IN ('CM','CALT')
--       AND id_mes = CAST(mes_string AS INT64)
--       AND (commission_id LIKE 'CABCAMP2%' AND commission_id LIKE CONCAT("CABCAMP2_",CAST(mes_string AS INT64),"_%"))
--       AND mes_liquidado = mes
--     GROUP BY ALL
--     ) THEN
IF 1=1 THEN


--COMENTO TODAS LAS TABLAS PARA RELANZAR PORQUE COMO NO TIENEN FILTRO DE FECHA SON TODAS IGUALES



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.bonos_base_xena_comsiones_revisado` 
  CLUSTER BY phone_nm, service_id, customer_id, account_id
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS
  
    SELECT 
      customer_id,
      account_id,
      COALESCE(service_id, CONCAT(phone_nm, LEFT(account_id, 6))) AS service_id,
      CAST(phone_nm AS INT64) AS phone_nm,
      bono_id,
      bono_name
    FROM `mm-datamart-kd.SERVICES.bonos_base_xena` a
    INNER JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` b ON a.customer_id = b.id_comisionista
    WHERE 1=1
      AND init_date BETWEEN FORMAT_DATE('%Y%m%d', DATE_TRUNC(mes, MONTH)) AND FORMAT_DATE('%Y%m%d', LAST_DAY(mes, MONTH))
      AND end_date > FORMAT_DATE('%Y%m%d', LAST_DAY(mes, MONTH))
      AND brand_ds IN ("OPERADORES", "EURONA")
      AND bono_id NOT IN (
        "B0393",
        "B0594",
        "B0590",
        "B0631",
        "B0642",
        "B0684",
        "B0688",
        "B0679",
        "B0728",
        "B0759",
        "B0772"
      )
      AND bono_producto IN (
        "CMPOSTCOMPAVANZA",
        "CMPOSTCOMPPREMIUM",
        "CMPOSTILIMITCOMP",
        "CMPOSTILIMITCOMP3P",
        "CMPOSTILIMITCOMP3PV2",
        "CMPOSTILIMITCOMP3PV4",
        "CMPOSTILIMITCOMPEVO",
        "CMPOSTILIMITCOMPEVOV2",
        "CMPOSTILIMITCOMPMP",
        "CMPOSTILIMITCOMPMPV2",
        "CMPOSTILIMITCOMPPLUS",
        "CMPOSTILIMITCOMPPRO",
        "CMPOSTILIMITCOMPTOP",
        "CMPOSTILIMITCOMPTOPV2"
      )
      AND bono_name NOT LIKE "%ADICIONAL%"
       --AND init_date = FORMAT_DATE('%Y%m%d',mes)
       --AND end_date > FORMAT_DATE('%Y%m%d',mes)
;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Maestro_BI_XENA_bonos_cartera_comisiones_revisado` 
--   OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS
--     SELECT 
--       id_producto_2,
--       id_bono,
--       tipo_paquete AS tipo_paquete2,
--       pvp_sin_iva,
--       concatenado,
--     FROM `mm-b2b-reporting.MAESTROS.Maestro_BI_XENA_bonos_cartera`
-- ;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maestro_paquete_mysim_comisiones_revisado` 
--   OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS
--     SELECT 
--       MARCA AS marca2,
--       id_paquete,
--       tipo_paquete AS tipo_paquete2,
--       precio_sin_iva AS precio__sin_iva,
--       concatenado,
--     FROM `mm-b2b-reporting.MAESTROS.maestro_paquete_mysim`
-- ;

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.Maestro_tariff_mysim_comisiones_revisado` 
--   OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS
--     SELECT 
--       comm_brand_ds,
--       tariff_id,
--       tipo_paquete AS tipo_paquete2,
--       pvp_sin_iva,
--       concatenado,
--     FROM `mm-b2b-reporting.MAESTROS.Maestro_tariff_mysim`
-- ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.upfronts_base_arca_revisado` AS

  WITH
    --Se inicia desde service porque hay veces que hay lineas que no tienen importe de facturación pero si cumplen con el upfront
    
    base AS (
      SELECT services.* EXCEPT(customer_id,activation_date,deactivation_date, tariff_id, tariff_ds),
        services.customer_id AS cliente,
        CASE
            WHEN (services.tariff_ds LIKE '%3P%' OR services.tariff_ds LIKE '%CONV%')  THEN 'FMC' 
            ELSE 'MO'
          END AS bundle_type,
        services.activation_date,
        CASE
          WHEN services.deactivation_date > LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH)) THEN '9999-12-31' -- no se si es la mejor forma
          ELSE services.deactivation_date
        END AS deactivation_date,
        services.tariff_id AS tariff_id_service,
        services.tariff_ds AS tariff_ds_service,
        CASE WHEN services.tariff_id IN ('CMPOSTILIMITCOMP') THEN bonos.bono_id ELSE services.tariff_id END AS tariff_id,
        CASE WHEN services.tariff_ds IN ('CMPOSTILIMITCOMP') THEN bonos.bono_name ELSE services.tariff_ds END AS tariff_ds,
      -- FROM `mm-datamart-kd.SERVICES.service_base_net` services
      FROM `mm-commissions-reporting.TEMP.services_base_net_agrupado_CM` services
      
      LEFT JOIN `mm-commissions-reporting.TEMP.bonos_base_xena_comsiones_revisado` bonos

        ON services.phone_nm = bonos.phone_nm
        AND services.service_id = bonos.service_id
        AND services.customer_id = bonos.customer_id
      AND services.account_id = bonos.account_id
      WHERE 1=1
        AND services.comm_brand_ds = 'CABLEMOVIL'
        AND services.activation_date < DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH),MONTH)
        
    ),

    base_campana AS (
      SELECT 
        mes_string AS id_mes,
        base.* EXCEPT(tariff_id),
        base.tariff_id AS tariff_id,
        master_xena.id_producto_2, --maestro.id_producto_2,
        e.document_type,
        CASE 
          WHEN REGEXP_CONTAINS(upper(base.tariff_id_service),'COMP') THEN COALESCE(master_xena.pvp_sin_iva, precio__sin_iva, tariff_mysim.pvp_sin_iva)/2.6
          WHEN REGEXP_CONTAINS(upper(base.tariff_id_service),'DUO') AND TIPO_LINEA = 'EXTRA' THEN 0
          ELSE COALESCE(master_xena.pvp_sin_iva, precio__sin_iva, tariff_mysim.pvp_sin_iva) 
        END AS PVP_ARPU,
        --maestro.pvp_sin_iva,
        -- COALESCE(IF(AGRUPACION_OPERADORES = 'GRUPO MM','GRUPO MASMOVIL',AGRUPACION_OPERADORES),group_donor,NULL ) AS group_donor,
        group_donor,
        portas.operator_donor,
        portas.operator_donor_marca,
        e.zip_code

      FROM base

      --MAESTRO TARIFAS XENA
      LEFT JOIN `mm-commissions-reporting.TEMP.Maestro_BI_XENA_bonos_cartera_comisiones_revisado`  master_xena 
        ON base.tariff_id IN UNNEST([master_xena.id_bono, master_xena.id_producto_2])

      --MAESTRO BUNDLE MYSIM
      LEFT JOIN `mm-commissions-reporting.TEMP.maestro_paquete_mysim_comisiones_revisado` maestro_paquete_mysim 
        ON base.tariff_id = maestro_paquete_mysim.id_paquete 

      --MAESTRO TARIFF MYSIM
      LEFT JOIN `mm-commissions-reporting.TEMP.Maestro_tariff_mysim_comisiones_revisado` tariff_mysim 
        ON base.tariff_id = tariff_mysim.tariff_id

      LEFT JOIN `mm-b2b-reporting.SERVICES.altas_migras_portas_mensual` origen 
        ON base.phone_nm = origen.MSISDN 
        AND DATE_TRUNC(base.activation_date, MONTH) = origen.PERIODO

      LEFT JOIN (
        SELECT msisdn,customer_id_receiver,account_id_receiver,service_id_receiver,CAST(vc_date AS DATE) AS activation_date, 
          CASE
            WHEN group_donor = 'GRUPO VODAFONE' THEN 'VODAFONE'
            WHEN group_donor = 'GRUPO ORANGE'  THEN 'ORANGE'
            WHEN group_donor = 'GRUPO TELEFONICA'THEN 'TELEFONICA'
            -- WHEN group_donor = 'GRUPO AVATEL' THEN 'GRUPO MASMOVIL' --Aberracion
            -- WHEN group_donor = 'GRUPO AVATEL' THEN 'AVATEL'
            ELSE group_donor
          END AS group_donor,
          CASE
            WHEN operator_donor LIKE '%YOIGO%' THEN comm_brand_ds_donor
            ELSE operator_donor
          END AS operator_donor_marca, --Lo llamo asi para poder comparar con el de portas directamente, cuando el codigo este bien BORRAR lo de abajo y dejar este
          CASE
            WHEN operator_donor LIKE '%PTV%' OR UPPER(operator_donor) LIKE '%PROCONO%' THEN 'PTV'
            WHEN operator_donor LIKE '%AIRE%' THEN 'AIRE NETWORKS'
            WHEN operator_donor LIKE '%DIGI SPAIN%' THEN 'DIGI SPAIN' 
            ELSE operator_donor
          END AS operator_donor

        FROM `mm-datamart-kd.PORTABILITY.portability_mobile_base` 

        WHERE 1=1
          AND transfer_date IS NOT NULL --Las que tienen transfer_date son portas
          AND group_receiver = 'GRUPO MASMOVIL'
          and comm_brand_ds_receiver = 'CABLEMOVIL'
          AND CAST(transfer_date AS DATE) > DATE_TRUNC(DATE_SUB(CURRENT_DATE,INTERVAL 2 YEAR),YEAR)
          AND CAST(transfer_date AS DATE) < mes_siguiente
          AND customer_id_receiver IS NOT NULL
        
        QUALIFY ROW_NUMBER() OVER(PARTITION BY msisdn, customer_id_receiver,account_id_receiver,service_id_receiver ORDER BY activation_date DESC) = 1 --No se si habría que añadirle algun campo como el activation_date
      ) portas
         ON base.phone_nm = portas.msisdn 
         AND portas.service_id_receiver = base.service_id 
         AND portas.customer_id_receiver = base.cliente 
        --  AND portas.account_id_receiver = base.account_id  --Hay cambios de tarifa donde se cambia el account y ya no cuadra.
         AND CAST(portas.activation_date AS DATE) = base.activation_date
        --AND base.activation_date BETWEEN DATE_SUB(portas.activation_date, INTERVAL 15 DAY) AND DATE_ADD(portas.activation_date, INTERVAL 15 DAY)
      
      LEFT JOIN (
        SELECT document_type, original_document_type, phone_nm, account_id, zip_code
        FROM `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` 
        WHERE 1=1
          AND account_id IS NOT NULL
        GROUP BY ALL
        ) e 
          ON base.account_id = e.account_id 
      
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, account_id ORDER BY activation_date DESC, PVP_ARPU DESC) = 1
        --No te tienen en cuentas las las altas netas
    )

    --PARA LOS CAMBIOS DE TARIFA REALIZAMOS EL FIRST_VALUE para quedarnos con el primer valor siempre y cuando esté NULL 
    --NO le veo sentido a esta parte

    -- SELECT * EXCEPT(group_donor,operator_donor),
    --   COALESCE(
    --     CASE
    --       WHEN group_donor IS NULL THEN FIRST_VALUE(group_donor) OVER(PARTITION BY phone_nm, cliente ORDER BY activation_date ASC)
    --       ELSE group_donor
    --     END, 'N/A') AS group_donor,
    --   COALESCE(
    --     CASE
    --       WHEN operator_donor IS NULL THEN FIRST_VALUE(operator_donor) OVER(PARTITION BY phone_nm, cliente ORDER BY activation_date ASC)
    --       ELSE operator_donor
    --     END, 'N/A') AS operator_donor
    -- FROM base_campana


    SELECT * 
    FROM base_campana
  ;

    --Montamos la query de creación de la tabla diaria /
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.upfronts_base_arca_revisado`';
  EXECUTE IMMEDIATE qry;
END IF;

  --Caso especial en el que la facturación se ha hecho PERO, quedó un cablero por subir su información a billing
  --Hay que agregar este left a la ultima consulta de base_inicial y modificar en vez de un CREATE OR REPLACE TABLE A UN INSERT TABLE
    -- LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` a ON tabla_nombre.CLIENTE = b.id_comisionista
    -- WHERE canal = 'MB'
    --   AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AS INT64)
    --   AND tabla_nombre.CLIENTE IS NULL;

END