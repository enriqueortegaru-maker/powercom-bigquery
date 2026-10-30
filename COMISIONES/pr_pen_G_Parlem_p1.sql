BEGIN

DECLARE sql STRING;
DECLARE prefijo STRING;
DECLARE mes_string STRING;
DECLARE canales_str STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 
      CASE 
        WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x = 'MB')  THEN 'PARMB'
        WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x = 'CM')  THEN 'PARCA'
        WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x = 'PAR') THEN 'PARPA'
        ELSE NULL
      END
;

SET canales_str = ARRAY_TO_STRING(canales_pr, ',');


-- call `mm-commissions-reporting.COMISIONES.pr_pen_G_Parlem_p1`(202601,['PAR'])

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_CP_GRUPO_PARLEM`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT 
      * EXCEPT(emails_acceso_trazabilidad,comision,tax_base)
     ,CASE
          WHEN canal = 'PAR' THEN REGEXP_EXTRACT(IF(REGEXP_CONTAINS(claim_code, r'[A-Za-z]'),NULL,campaign_code), r'^(\d+)')
      END AS zip_code
      
     ,SAFE_DIVIDE(comision,(CAST(REGEXP_EXTRACT(concepto, r'\(([\d.]+)%\)') AS FLOAT64)/100)) AS tax_base
     ,IF((CAST(REGEXP_EXTRACT(concepto, r'\(([\d.]+)%\)') AS FLOAT64)/100) = 0, 0, comision) AS comision

FROM `mm-commissions-reporting.COMISIONES.transacciones`

WHERE 1=1
      AND id_mes >= 202301
      AND concepto LIKE 'C - Gesti%'
      AND id_comisionista IN (
          'C09-00402',--APROOP TELECOM S.L
          'F00692',--APROOP TELECOM SLU
          --
          'Octel',
          'C09-00062-0055',--OCTEL TELECOM & TECH SOCIEDAD LIMITADA UNIPERSONAL
          --        
          'F46463',--Parlem Telecom Companyia De Telecomunicacions SA
          --
          '201007'--NETLLAR S.L.
          ) 
      AND id_mes = mes_int
      AND canal IN UNNEST(SPLIT(canales_str, ',')) 
      AND NOT (
           commission_id LIKE 'PARPA%'
        OR commission_id LIKE 'PARMB%'
        OR commission_id LIKE 'PARCA%'
        )
)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CP_GRUPO_PARLEM`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 20 DAY)) AS (
WITH base_zip AS (
  SELECT
        zip_code_transacciones
      ,zip_code_xena
      ,fix_base_gescal
      ,fix_base_no_date_gescal
      ,XENA_PV_CLIENTES_NO_DATE.postal AS zip_code_xena_no_date
      ,OCTEL_HISTORICO.cp AS zip_code_octel
      ,VOICE_USERS.zipcode AS zip_code_voice_users
      ,VOICE_USERS_NO_DATE.zipcode AS zip_code_voice_users_no_date
      ,BASE.* EXCEPT(zip_code_xena, zip_code_transacciones, fix_base_gescal, fix_base_no_date_gescal)

  FROM (
      SELECT
            COALESCE
            (
              zip_code_xena
            ,LAG(zip_code_xena) OVER (PARTITION BY id_comisionista, phone_nm, marca, activation_date ORDER BY id_mes)
            ,LEAD(zip_code_xena) OVER (PARTITION BY id_comisionista, phone_nm, marca, activation_date ORDER BY id_mes)
            ,MAX(zip_code_xena) OVER (PARTITION BY id_comisionista, phone_nm, marca)
            ) AS zip_code_xena

            ,fix_base_gescal
            ,fix_base_no_date_gescal
            ,zip_code_transacciones
            ,* EXCEPT(zip_code_xena, fix_base_gescal, fix_base_no_date_gescal, zip_code_transacciones)

      FROM (
            SELECT
                  XENA_PV_CLIENTES.postal AS zip_code_xena
                ,FIX_BASE.gescal AS fix_base_gescal
                ,FIX_BASE_NO_DATE.gescal AS fix_base_no_date_gescal
                ,BASE.zip_code AS zip_code_transacciones
                ,BASE.* EXCEPT(zip_code)
            
            FROM `mm-commissions-reporting.TEMP.base_CP_GRUPO_PARLEM` BASE --1781250
            
            LEFT JOIN (
                      SELECT
                            SERVICE_BASE_NET.*
                          ,XENA_PV_CLIENTES.id_cliente_fact
                          ,XENA_PV_CLIENTES.postal
            
                      FROM `mm-datamart-kd.SERVICES.service_base_net` SERVICE_BASE_NET
                      
                      INNER JOIN `mm-datamart-kd.PERSONAL_INFO.clean_xena_pv_clientes` XENA_PV_CLIENTES
                                ON SERVICE_BASE_NET.account_id = XENA_PV_CLIENTES.id_cliente
                                  AND SERVICE_BASE_NET.data_source_ds = 'XENA'
                                  AND XENA_PV_CLIENTES.id_empresa = '05'
                      ) XENA_PV_CLIENTES
                    ON BASE.id_comisionista = XENA_PV_CLIENTES.id_cliente_fact
                        AND BASE.phone_nm = CAST(XENA_PV_CLIENTES.phone_nm AS STRING)
                        AND BASE.marca = XENA_PV_CLIENTES.comm_brand_ds
                        AND PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))
                              BETWEEN XENA_PV_CLIENTES.activation_date AND COALESCE(XENA_PV_CLIENTES.deactivation_date, '9999-12-31')
            
            LEFT JOIN (
                      SELECT
                            BASE.commission_id
                          ,FIX_BASE.gescal
            
                      FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` INFORME
                          
                      INNER JOIN `mm-commissions-reporting.TEMP.base_CP_GRUPO_PARLEM` BASE
                                ON CAST(INFORME.phone_nm AS STRING) = BASE.phone_nm
                                  AND INFORME.brand_ds = BASE.marca
                                  AND INFORME.activation_date = BASE.activation_date
                                  AND INFORME.service_type = 'BROADBAND'
            
                      LEFT JOIN `mm-datamart-kd.ACCESS_PROVISION.provision_base` PROVISION_BASE
                              ON INFORME.order_fix_id = PROVISION_BASE.workorder_id
                      
                      LEFT JOIN (
                                SELECT *
                                FROM `mm-datamart-kd.ACCESS_PROVISION.fix_base_net`
                                WHERE technology = 'FTTH'
                                QUALIFY ROW_NUMBER() OVER (
                                                          PARTITION BY
                                                            COALESCE(iua_last, 'iua_last'),
                                                            COALESCE(adminnumber_last, 'adminnumber_last'),
                                                            start_id,
                                                            workorderserviceid
                                                          ORDER BY movement_date ASC
                                                          ) = 1
                                ) FIX_BASE
                              ON COALESCE(PROVISION_BASE.adsl_administrative, PROVISION_BASE.ftth_iua)
                                  =
                                  COALESCE(FIX_BASE.adminnumber_last, FIX_BASE.iua_last)
            
                      
                      QUALIFY ROW_NUMBER() OVER (
                                                PARTITION BY BASE.commission_id
                                                ORDER BY CASE
                                                            WHEN DATE(FIX_BASE.start_id) < PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))
                                                            THEN 1
                                                            ELSE 2
                                                        END ASC,
                                                        ABS(DATE_DIFF(DATE(FIX_BASE.start_id), PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING)), DAY)) ASC
                                                ) = 1
                      ) FIX_BASE
                    ON BASE.commission_id = FIX_BASE.commission_id

            LEFT JOIN (
                      SELECT
                            BASE.commission_id
                          ,FIX_BASE.gescal
                      FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS_BASE_TELCO
                          
                      INNER JOIN `mm-commissions-reporting.TEMP.base_CP_GRUPO_PARLEM` BASE
                                ON CAST(VENTAS_BASE_TELCO.phone_nm AS STRING) = BASE.phone_nm
                      
                      LEFT JOIN `mm-datamart-kd.ACCESS_PROVISION.provision_base` PROVISION_BASE
                              ON VENTAS_BASE_TELCO.order_fix_id = PROVISION_BASE.workorder_id
                                          
                      LEFT JOIN (
                                SELECT *
                                FROM `mm-datamart-kd.ACCESS_PROVISION.fix_base_net`
                                WHERE technology = 'FTTH'
                                QUALIFY ROW_NUMBER() OVER (
                                                          PARTITION BY
                                                            COALESCE(iua_last, 'iua_last'),
                                                            COALESCE(adminnumber_last, 'adminnumber_last'),
                                                            start_id,
                                                            workorderserviceid
                                                          ORDER BY movement_date ASC
                                                          ) = 1
                                ) FIX_BASE
                              ON COALESCE(PROVISION_BASE.adsl_administrative, PROVISION_BASE.ftth_iua)
                                  =
                                  COALESCE(FIX_BASE.adminnumber_last, FIX_BASE.iua_last)
                      
                      WHERE VENTAS_BASE_TELCO.brand_ds = 'OPERADORES' AND VENTAS_BASE_TELCO.service_type = 'BROADBAND'
                                
                      QUALIFY ROW_NUMBER() OVER (
                                                PARTITION BY BASE.commission_id
                                                ORDER BY CASE
                                                            WHEN DATE(FIX_BASE.start_id) < PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))
                                                            THEN 1
                                                            ELSE 2
                                                        END ASC,
                                                        ABS(DATE_DIFF(DATE(FIX_BASE.start_id), PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING)), DAY)) ASC
                                                ) = 1
                      ) FIX_BASE_NO_DATE
                    ON BASE.commission_id = FIX_BASE_NO_DATE.commission_id
            
            QUALIFY RANK() OVER (
                                PARTITION BY BASE.commission_id
                                ORDER BY CASE
                                            WHEN XENA_PV_CLIENTES.activation_date <= PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING))
                                            THEN 1
                                            ELSE 2
                                        END ASC,
                                        ABS(DATE_DIFF(XENA_PV_CLIENTES.activation_date, PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING)), MONTH)) ASC,
                                        XENA_PV_CLIENTES.net_order ASC
                                ) = 1
            )
      ) BASE

  LEFT JOIN (
            SELECT
                  SERVICE_BASE_NET.*
                ,XENA_PV_CLIENTES.id_cliente_fact
                ,XENA_PV_CLIENTES.postal

            FROM `mm-datamart-kd.SERVICES.service_base_net` SERVICE_BASE_NET
            
            INNER JOIN `mm-datamart-kd.PERSONAL_INFO.clean_xena_pv_clientes` XENA_PV_CLIENTES
                      ON SERVICE_BASE_NET.account_id = XENA_PV_CLIENTES.id_cliente
                        AND SERVICE_BASE_NET.data_source_ds = 'XENA'
                        AND XENA_PV_CLIENTES.id_empresa = '05'
            ) XENA_PV_CLIENTES_NO_DATE
          ON BASE.id_comisionista = XENA_PV_CLIENTES_NO_DATE.id_cliente_fact
              AND BASE.phone_nm = CAST(XENA_PV_CLIENTES_NO_DATE.phone_nm AS STRING)
              AND BASE.marca = XENA_PV_CLIENTES_NO_DATE.comm_brand_ds

  LEFT JOIN (
            SELECT * 
            FROM `mm-commissions-reporting.TEMP.cartera_octel_codigoPostal_comisiones`
            QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm) = 1
            ) OCTEL_HISTORICO
          ON BASE.phone_nm = OCTEL_HISTORICO.phone_nm

  LEFT JOIN (
            SELECT *
            FROM (
                SELECT
                      BASE.commission_id
                      ,VOICE_USERS.zipcode
                      ,SUM(VOICE_USERS.count) AS count
      
                FROM (
                      SELECT data_day,comm_brand_ds,msisdn,zipcode,count(*) AS count
                      FROM `mm-datamart-kd.PREMEDIACION.voice_users`
                      WHERE type = 'OUT'
                          AND data_day BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) AND DATE_SUB(CURRENT_DATE(), INTERVAL 4 MONTH)
                      GROUP BY ALL) VOICE_USERS
                
                INNER JOIN `mm-commissions-reporting.TEMP.base_CP_GRUPO_PARLEM` BASE
                          ON VOICE_USERS.msisdn = BASE.phone_nm
                              AND VOICE_USERS.comm_brand_ds = BASE.marca
                              AND VOICE_USERS.data_day > DATE_SUB(PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING)), INTERVAL 3 MONTH)
                              AND VOICE_USERS.data_day < DATE_ADD(PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING)), INTERVAL 3 MONTH)
                              AND COALESCE(VOICE_USERS.zipcode, 'DESC') != 'DESC'
                              AND BASE.service_type = 'MOBILE'
      
                GROUP BY 1,2
                )
            QUALIFY ROW_NUMBER() OVER (PARTITION BY commission_id ORDER BY count DESC) = 1
            ) VOICE_USERS
          ON BASE.commission_id = VOICE_USERS.commission_id

  LEFT JOIN (
            SELECT *
            FROM (
                SELECT
                      BASE.commission_id
                      ,VOICE_USERS.zipcode
                      ,SUM(VOICE_USERS.count) AS count
      
                FROM (SELECT comm_brand_ds,msisdn,zipcode,count(*) AS count
                      FROM `mm-datamart-kd.PREMEDIACION.voice_users`
                      WHERE type = 'OUT'
                          AND data_day BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) AND DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
                      GROUP BY ALL) VOICE_USERS
                
                INNER JOIN `mm-commissions-reporting.TEMP.base_CP_GRUPO_PARLEM` BASE
                          ON VOICE_USERS.msisdn = BASE.phone_nm
                              AND COALESCE(VOICE_USERS.zipcode, 'DESC') != 'DESC'
                              AND BASE.service_type = 'MOBILE'
      
                GROUP BY 1,2
                )
            QUALIFY ROW_NUMBER() OVER (PARTITION BY commission_id ORDER BY count DESC) = 1
            ) VOICE_USERS_NO_DATE
          ON BASE.commission_id = VOICE_USERS_NO_DATE.commission_id

  /*
  WHERE zip_code_transacciones IS NULL
        AND zip_code_xena IS NULL
        AND fix_base_gescal IS NULL
        AND fix_base_no_date_gescal IS NULL
        AND XENA_PV_CLIENTES_NO_DATE.postal IS NULL
        AND OCTEL_HISTORICO.cp IS NULL
        AND VOICE_USERS.zipcode IS NULL
        AND VOICE_USERS_NO_DATE.zipcode IS NULL
  */

  QUALIFY RANK() OVER (
                      PARTITION BY BASE.commission_id
                      ORDER BY ABS(DATE_DIFF(DATE(XENA_PV_CLIENTES_NO_DATE.activation_date), PARSE_DATE('%Y%m', CAST(BASE.id_mes AS STRING)), DAY)) ASC,
                      XENA_PV_CLIENTES_NO_DATE.net_order ASC
                      ) = 1
  ),


  cruce AS (
    SELECT * EXCEPT(zip_code_transacciones,zip_code_xena,fix_base_gescal,fix_base_no_date_gescal,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date),
      IF(zip_code_transacciones = 'NULL',NULL,zip_code_transacciones) AS zip_code_transacciones,
      IF(zip_code_xena = 'NULL',NULL,zip_code_xena) AS zip_code_xena,
      IF(fix_base_gescal = 'NULL',NULL,CONCAT(LEFT(fix_base_gescal,2),'000')) AS fix_base_gescal,
      IF(fix_base_no_date_gescal = 'NULL',NULL,CONCAT(LEFT(fix_base_no_date_gescal,2),'000')) AS fix_base_no_date_gescal,
      IF(zip_code_xena_no_date = 'NULL',NULL,zip_code_xena_no_date) AS zip_code_xena_no_date,
      IF(zip_code_octel = 'NULL',NULL,zip_code_octel) AS zip_code_octel,
      IF(zip_code_voice_users = 'NULL',NULL,zip_code_voice_users) AS zip_code_voice_users,
      IF(zip_code_voice_users_no_date = 'NULL',NULL,zip_code_voice_users_no_date) AS zip_code_voice_users_no_date
    FROM base_zip
  ),

  cruce_listo AS (
    SELECT a.* EXCEPT(zip_code_transacciones,zip_code_xena,fix_base_gescal,fix_base_no_date_gescal,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date),
      b.zip_code_transacciones,
      c.zip_code_xena,
      d.fix_base_gescal,
      e.fix_base_no_date_gescal,
      f.zip_code_xena_no_date,
      g.zip_code_octel,
      h.zip_code_voice_users,
      i.zip_code_voice_users_no_date
    FROM cruce a
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, zip_code_transacciones
      FROM cruce
      WHERE zip_code_transacciones IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )b ON a.id_comisionista = b.id_comisionista AND a.phone_nm = b.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, zip_code_xena
      FROM cruce
      WHERE zip_code_xena IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )c ON a.id_comisionista = c.id_comisionista AND a.phone_nm = c.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, fix_base_gescal
      FROM cruce
      WHERE fix_base_gescal IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )d ON a.id_comisionista = d.id_comisionista AND a.phone_nm = d.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, fix_base_no_date_gescal
      FROM cruce
      WHERE fix_base_no_date_gescal IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )e ON a.id_comisionista = e.id_comisionista AND a.phone_nm = e.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, zip_code_xena_no_date
      FROM cruce
      WHERE zip_code_xena_no_date IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )f ON a.id_comisionista = f.id_comisionista AND a.phone_nm = f.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, zip_code_octel
      FROM cruce
      WHERE zip_code_octel IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )g ON a.id_comisionista = g.id_comisionista AND a.phone_nm = g.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, zip_code_voice_users
      FROM cruce
      WHERE zip_code_voice_users IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )h ON a.id_comisionista = h.id_comisionista AND a.phone_nm = h.phone_nm
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, zip_code_voice_users_no_date
      FROM cruce
      WHERE zip_code_voice_users_no_date IS NOT NULL
      QUALIFY ROW_NUMBER()OVER(PARTITION BY phone_nm,id_comisionista ORDER BY activation_date ASC) = 1
    )i ON a.id_comisionista = i.id_comisionista AND a.phone_nm = i.phone_nm
  ),

  cruce_zip_todos AS (
    SELECT *
    FROM cruce_listo
    WHERE 1=1
  ), 

  base_parlem AS (
    SELECT * EXCEPT(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones),
      CASE
        WHEN phone_nm LIKE '9%' OR phone_nm LIKE '8%' THEN COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones)
        ELSE COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones) 
      END AS zip_code,
    FROM cruce_zip_todos
    WHERE id_comisionista = 'F46463' --Parlem Telecom Companyia De Telecomunicacions SA
  ),

  base_marblanca AS (
    SELECT * EXCEPT(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones),
      CASE 
        WHEN id_comisionista IN ('C09-00402') AND id_mes >= 202411 THEN COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones)
        ELSE COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones)
      END AS zip_code
    FROM cruce_zip_todos
    WHERE id_comisionista IN (
      'C09-00402',--APROOP TELECOM S.L
      'C09-00062-0055'--OCTEL TELECOM & TECH SOCIEDAD LIMITADA UNIPERSONAL
    )
  ),

  base_cablemovil AS ( 
    SELECT * EXCEPT(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones),
      CASE
        WHEN id_comisionista IN ('F00692','201007') AND id_mes >= 202411 THEN COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones)
        ELSE COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_octel,zip_code_voice_users,zip_code_voice_users_no_date,zip_code_transacciones)
      END AS zip_code
    FROM cruce_zip_todos
    WHERE id_comisionista IN (
      'F00692',--APROOP TELECOM SLU
      '201007'--NETLLAR S.L.
    )
  ),

  total AS (--UNIMOS TODAS LAS EXTRACCIONES POR CANAL/MARCA
    SELECT *
    FROM base_parlem
    UNION ALL
    SELECT *
    FROM base_marblanca
    UNION ALL
    SELECT *
    FROM base_cablemovil
  ),

  total_2 AS (
    SELECT *
    FROM total
  ),

  total_3 AS (
    SELECT * EXCEPT(zip_code),
      CASE
        WHEN LENGTH(zip_code) = 3 THEN CONCAT('0',zip_code)
        ELSE zip_code
      END AS zip_code,
      ROW_NUMBER() OVER(ORDER BY phone_nm,id_mes ASC) AS n_linea
    FROM total_2
  )

  SELECT *
  FROM total_3
)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CP_GRUPO_PARLEM_DEF` AS

WITH 

  base_f AS (
    SELECT *
    FROM `mm-commissions-reporting.TEMP.CP_GRUPO_PARLEM`
    WHERE
       NOT (zip_code LIKE '03%' --ALICANTE
      OR zip_code LIKE '07%' --ISLAS BALEARES
      OR zip_code LIKE '08%' --BARCELONA
      OR zip_code LIKE '12%' --CASTELLON 
      OR zip_code LIKE '17%' --GIRONA
      OR zip_code LIKE '25%' --LLEIDA
      OR zip_code LIKE '43%' --TARRAGONA
      OR zip_code LIKE '46%' --VALENCIA      
       )
  ),

  final as (
    SELECT 
     'calculado' as estado,
      mes_liquidado, 
      id_mes, 
      agrupacion_canal,
      canal,
      CASE
          WHEN service_type = 'MOBILE' THEN 'C - Gestion Cartera Penalizacion Territorio (10%)'
          WHEN service_type = 'INTERNET' THEN 'C - Gestion Cartera Penalizacion Territorio (5%)'
          ELSE 'No cruza'
     END  AS concepto,
      'AIRT' AS tipo_concepto,
      -1 AS  unidades,
      CASE
          WHEN service_type = 'MOBILE' THEN tax_base*-0.10
          WHEN service_type = 'INTERNET' THEN tax_base*-0.05
          ELSE 0
      END AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social, 
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
      cod_canal,
      cod_producto,
      CONCAT('cod_postal: ',zip_code)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      tax_base,
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
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM base_f
  )

  SELECT 
     prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
     *
  FROM final
  WHERE 1=1
    --Aplica para lineas activadas a partir de 202301
    AND (activation_date >= '2023-01-01' 
      OR activation_date IS NULL)
    AND canal IN UNNEST(SPLIT(canales_str, ',')) 
  ;

  -- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.CP_GRUPO_PARLEM_DEF',
  'ACTUALIZAR'
);



END