BEGIN

--Procedimiento para el cálculo de la penalización trimestral aplicable al GRUPO PARLEM

--Este procedimiento tiene como objetivo calcular la penalización trimestral que afecta al GRUPO PARLEM, basada en la comparación de su cuota de mercado en la venta de líneas móviles y fibra a nivel nacional.

--La metodología consiste en contrastar la cuota de mercado del Grupo con el límite establecido por la Comisión Nacional de los Mercados y la Competencia (CNMC), incrementado en un 5%, junto con la información interna de la empresa.

--Si el Grupo supera el umbral de cuota de mercado fijado por la CNMC, se aplicará una penalización indefinida sobre el porcentaje excedente de líneas. La identificación de las líneas sujetas a penalización se realizará considerando las más antiguas dadas de alta en el trimestre, sin tomar en cuenta su importe.


--La query conectada a una API en Python que extrae la información en bruto. La dirección del Python es: https://colab.research.google.com/drive/1Tn-h7lqwRG6jQyqHGxmat2r-5ekT6Rb2?usp=sharing



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CNMC_GLOBAL` AS 

WITH 
  agrupado_operador AS (
    SELECT operador,
      SUM(`2020T1`) `2020T1`,
      SUM(`2020T2`) `2020T2`,
      SUM(`2020T3`) `2020T3`,
      SUM(`2020T4`) `2020T4`,
      SUM(`2021T1`) `2021T1`,
      SUM(`2021T2`) `2021T2`,
      SUM(`2021T3`) `2021T3`,
      SUM(`2021T4`) `2021T4`,
      SUM(`2022T1`) `2022T1`,
      SUM(`2022T2`) `2022T2`,
      SUM(`2022T3`) `2022T3`,
      SUM(`2022T4`) `2022T4`,
      SUM(`2023T1`) `2023T1`,
      SUM(`2023T2`) `2023T2`,
      SUM(`2023T3`) `2023T3`,
      SUM(`2023T4`) `2023T4`,
      SUM(`2024T1`) `2024T1`,
      SUM(`2024T2`) `2024T2`,
      SUM(`2024T3`) `2024T3`,
      SUM(`2024T4`) `2024T4`,
    FROM `mm-commissions-reporting.GS.market_share_CNMC` PIVOT (SUM(lineas_o_accesos_por_operador) FOR trimestre IN ("2020T1","2020T2","2020T3","2020T4","2021T1","2021T2","2021T3","2021T4","2022T1","2022T2","2022T3","2022T4","2023T1","2023T2","2023T3","2023T4","2024T1","2024T2","2024T3","2024T4") )
    WHERE segmento = 'Residencial'
      AND servicio = 'Banda ancha fija minorista'
      AND operador IS NOT NULL
    GROUP BY ALL
  ),

  agrupado_movil_post AS (
    SELECT operador,
      SUM(`2020T1`) `2020T1`,
      SUM(`2020T2`) `2020T2`,
      SUM(`2020T3`) `2020T3`,
      SUM(`2020T4`) `2020T4`,
      SUM(`2021T1`) `2021T1`,
      SUM(`2021T2`) `2021T2`,
      SUM(`2021T3`) `2021T3`,
      SUM(`2021T4`) `2021T4`,
      SUM(`2022T1`) `2022T1`,
      SUM(`2022T2`) `2022T2`,
      SUM(`2022T3`) `2022T3`,
      SUM(`2022T4`) `2022T4`,
      SUM(`2023T1`) `2023T1`,
      SUM(`2023T2`) `2023T2`,
      SUM(`2023T3`) `2023T3`,
      SUM(`2023T4`) `2023T4`,
      SUM(`2024T1`) `2024T1`,
      SUM(`2024T2`) `2024T2`,
      SUM(`2024T3`) `2024T3`,
      SUM(`2024T4`) `2024T4`,
    FROM `mm-commissions-reporting.GS.market_share_CNMC` PIVOT (SUM(lineas_o_accesos_por_operador) FOR trimestre IN ("2020T1","2020T2","2020T3","2020T4","2021T1","2021T2","2021T3","2021T4","2022T1","2022T2","2022T3","2022T4","2023T1","2023T2","2023T3","2023T4","2024T1","2024T2","2024T3","2024T4") )
    WHERE tipo_de_linea = 'Líneas de voz'
      AND tipo_de_contrato = 'Pospago'
      AND servicio = 'Telefonía móvil'
      AND segmento = 'Residencial'
      AND operador IS NOT NULL
    GROUP BY ALL
  ),

  agrupado_movil_pre AS (
    SELECT operador,
      SUM(`2020T1`) `2020T1`,
      SUM(`2020T2`) `2020T2`,
      SUM(`2020T3`) `2020T3`,
      SUM(`2020T4`) `2020T4`,
      SUM(`2021T1`) `2021T1`,
      SUM(`2021T2`) `2021T2`,
      SUM(`2021T3`) `2021T3`,
      SUM(`2021T4`) `2021T4`,
      SUM(`2022T1`) `2022T1`,
      SUM(`2022T2`) `2022T2`,
      SUM(`2022T3`) `2022T3`,
      SUM(`2022T4`) `2022T4`,
      SUM(`2023T1`) `2023T1`,
      SUM(`2023T2`) `2023T2`,
      SUM(`2023T3`) `2023T3`,
      SUM(`2023T4`) `2023T4`,
      SUM(`2024T1`) `2024T1`,
      SUM(`2024T2`) `2024T2`,
      SUM(`2024T3`) `2024T3`,
      SUM(`2024T4`) `2024T4`,
    FROM `mm-commissions-reporting.GS.market_share_CNMC` PIVOT (SUM(lineas_o_accesos_por_operador) FOR trimestre IN ("2020T1","2020T2","2020T3","2020T4","2021T1","2021T2","2021T3","2021T4","2022T1","2022T2","2022T3","2022T4","2023T1","2023T2","2023T3","2023T4","2024T1","2024T2","2024T3","2024T4") )
    WHERE tipo_de_linea = 'Líneas de voz'
      AND tipo_de_contrato = 'Prepago'
      AND servicio = 'Telefonía móvil'
      AND segmento = 'Residencial'
      AND operador IS NOT NULL
    GROUP BY ALL
  ),

  porc_BA AS (
    SELECT 
    'GENERAL' AS agrupacion,
    UPPER(CASE 
      WHEN operador = 'Movistar' THEN 'TELEFONICA'
      WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN 'MASORANGE' 
      ELSE operador
    END) AS operador, 
    trimestre, 
    SUM(
      CASE 
        WHEN operador IN ('Grupo MASMOVIL') AND trimestre <= '2024T1' THEN lineas_o_accesos_por_operador
        WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN lineas_o_accesos_por_operador 
        ELSE lineas_o_accesos_por_operador
      END
    ) AS total_grupo,
    SUM(SUM(lineas_o_accesos_por_operador)) OVER (PARTITION BY trimestre) AS total_trimestre,
    SUM(
      CASE 
        WHEN operador IN ('Grupo MASMOVIL') AND trimestre <= '2024T1' THEN lineas_o_accesos_por_operador
        WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN lineas_o_accesos_por_operador 
        ELSE lineas_o_accesos_por_operador 
      END
    )*100 / SUM(SUM(lineas_o_accesos_por_operador)) OVER (PARTITION BY trimestre) AS proporcion
    FROM `mm-commissions-reporting.GS.market_share_CNMC`
    WHERE segmento = 'Residencial'
      AND servicio = 'Banda ancha fija minorista'
      AND operador IS NOT NULL
    GROUP BY trimestre, operador
  ),

  porc_PRE AS (
    SELECT
    'MOVIL PREPAGO' AS agrupacion, 
    UPPER(CASE 
      WHEN operador = 'Movistar' THEN 'TELEFONICA'
      WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN 'MASORANGE' 
      ELSE operador
    END) AS operador, 
    trimestre, 
    SUM(
      CASE 
        WHEN operador IN ('Grupo MASMOVIL') AND trimestre <= '2024T1' THEN lineas_o_accesos_por_operador
        WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN lineas_o_accesos_por_operador 
        ELSE lineas_o_accesos_por_operador 
      END
    ) AS total_grupo,
    SUM(SUM(lineas_o_accesos_por_operador)) OVER (PARTITION BY trimestre) AS total_trimestre,
    SUM(
      CASE 
        WHEN operador IN ('Grupo MASMOVIL') AND trimestre <= '2024T1' THEN lineas_o_accesos_por_operador
        WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN lineas_o_accesos_por_operador 
        ELSE lineas_o_accesos_por_operador
      END
    )*100 / SUM(SUM(lineas_o_accesos_por_operador)) OVER (PARTITION BY trimestre) AS proporcion
    FROM `mm-commissions-reporting.GS.market_share_CNMC`
    WHERE tipo_de_linea = 'Líneas de voz'
      AND tipo_de_contrato = 'Prepago'
      AND servicio = 'Telefonía móvil'
      AND segmento = 'Residencial'
      AND operador IS NOT NULL
    GROUP BY trimestre, operador
  ),

  porc_POST AS (
    SELECT 
    'MOVIL POSTPAGO' AS agrupacion,
    UPPER(CASE 
      WHEN operador = 'Movistar' THEN 'TELEFONICA'
      WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN 'MASORANGE' 
      ELSE operador
    END) AS operador, 
    trimestre, 
    SUM(
      CASE 
        WHEN operador IN ('Grupo MASMOVIL') AND trimestre <= '2024T1' THEN lineas_o_accesos_por_operador
        WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN lineas_o_accesos_por_operador 
        ELSE lineas_o_accesos_por_operador
      END
    ) AS total_grupo,
    SUM(SUM(lineas_o_accesos_por_operador)) OVER (PARTITION BY trimestre) AS total_trimestre,
    SUM(
      CASE 
        WHEN operador IN ('Grupo MASMOVIL') AND trimestre <= '2024T1' THEN lineas_o_accesos_por_operador
        WHEN operador IN ('Grupo MASMOVIL', 'Orange') AND trimestre >= '2024T2' THEN lineas_o_accesos_por_operador 
        ELSE lineas_o_accesos_por_operador
      END
    )*100 / SUM(SUM(lineas_o_accesos_por_operador)) OVER (PARTITION BY trimestre) AS proporcion
    FROM `mm-commissions-reporting.GS.market_share_CNMC`
    WHERE tipo_de_linea = 'Líneas de voz'
      AND tipo_de_contrato = 'Pospago'
      AND servicio = 'Telefonía móvil'
      AND segmento = 'Residencial'
      AND operador IS NOT NULL
    GROUP BY trimestre, operador
  )

  SELECT *
  FROM porc_POST

  UNION ALL

  SELECT *
  FROM porc_PRE

  UNION ALL

  SELECT *
  FROM porc_BA
;

--CREAMOS LA TABLA QUE CONTIENE EL PORCENTAJE DEL GRUPO PARLEM POR CÓDIGO POSTAL

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.GRUPO_PARLEM_CNMC` AS 


  WITH 
    dealers AS (
      SELECT id_comisionista, 
        documento,
        nombre_comercio
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL`

      UNION ALL

      SELECT id_comisionista,
        documento,
        nombre_comercio
      FROM `mm-commissions-reporting.GS.DEALERS_MARBLANCA`
    ),

    base_old AS (
      
      --CABLEMOVIL Y PARLEM

      SELECT 
        CASE
          WHEN comm_brand_ds = 'PARLEM' THEN 'F46463'
          ELSE d.id_comisionista
        END AS id_comisionista,
        a.sfid_id,
        a.phone_nm,
        CASE
          WHEN a.service_type = 'FIX' THEN 'INTERNET'
          ELSE a.service_type
        END AS service_type,
        a.activation_date
      FROM `mm-datamart-kd.SERVICES.service_base_net` a
      LEFT JOIN dealers d ON d.id_comisionista = a.customer_id
      LEFT JOIN (
        SELECT id_cliente_fact, id_cliente, b.service_id, b.phone_nm, postal
        FROM `mm-datamart-kd.PERSONAL_INFO.clean_xena_pv_clientes` a
        LEFT JOIN (
          SELECT DISTINCT account_id,service_id, phone_nm
          FROM `mm-datamart-kd.SERVICES.service_base_net`
        ) b ON a.id_cliente = b.account_id 
        WHERE id_empresa = '05' --AND phone_nm = 607633207
        QUALIFY ROW_NUMBER() OVER(PARTITION BY b.service_id) = 1
      )c ON a.customer_id = c.id_cliente_fact AND a.phone_nm = c.phone_nm 
      WHERE a.comm_brand_ds IN ('CABLEMOVIL','NETLLAR','PARLEM')
        AND kpi_gross_add = 1
        --AND activation_reason_ds != 'migracion marca'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY d.id_comisionista, phone_nm ORDER BY activation_date ASC) = 1
    
      UNION ALL

      --MARBLANCA

      SELECT 
        CASE 
          WHEN a.comm_brand_ds = 'MARBLANCA' AND CONCAT(current_sfid_id,'-',current_user_store) IN ('C09-00062-0055','C09-00062-0004','C09-00062-0005','C09-00062-0006','C09-00062-0013') THEN 'Octel'
          ELSE dealers.id_comisionista
        END AS id_comisionista,
        CAST(NULL AS STRING) AS sfid_id,
        a.phone_nm,
        IF(a.service_type IN ('FIX','BROADBAND'), 'INTERNET',a.service_type) AS service_type, 
        a.activation_date,
      FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` a
      JOIN dealers ON a.current_sfid_id = dealers.id_comisionista
      WHERE comm_brand_ds = 'MARBLANCA'
        AND activation_date IS NOT NULL
        AND a.phone_nm IS NOT NULL
      QUALIFY ROW_NUMBER() OVER(PARTITION BY CASE WHEN a.comm_brand_ds = 'MARBLANCA' AND CONCAT(current_sfid_id,'-',current_user_store) IN ('C09-00062-0055','C09-00062-0004','C09-00062-0005','C09-00062-0006','C09-00062-0013') THEN 'Octel' ELSE dealers.id_comisionista END , phone_nm ORDER BY activation_date ASC) = 1
    ),

    cruce AS (
      SELECT a.* EXCEPT(zip_code_xena,fix_base_gescal,fix_base_no_date_gescal,zip_code_xena_no_date,zip_code_voice_users,zip_code_voice_users_no_date,VENTAS_BASE_TELCO_ZIP,service_type),
        IF(zip_code_xena = 'NULL',NULL,zip_code_xena) AS zip_code_xena,
        IF(fix_base_gescal = 'NULL',NULL,CONCAT(LEFT(fix_base_gescal,2),'000')) AS fix_base_gescal,
        IF(fix_base_no_date_gescal = 'NULL',NULL,CONCAT(LEFT(fix_base_no_date_gescal,2),'000')) AS fix_base_no_date_gescal,
        IF(zip_code_xena_no_date = 'NULL',NULL,zip_code_xena_no_date) AS zip_code_xena_no_date,
        IF(zip_code_voice_users = 'NULL',NULL,zip_code_voice_users) AS zip_code_voice_users,
        IF(zip_code_voice_users_no_date = 'NULL',NULL,zip_code_voice_users_no_date) AS zip_code_voice_users_no_date,
        IF(VENTAS_BASE_TELCO_ZIP = 'NULL',NULL,VENTAS_BASE_TELCO_ZIP) AS VENTAS_BASE_TELCO_ZIP,
        CASE
            WHEN comm_brand_ds = 'MARBLANCA' AND CONCAT(current_sfid_id,'-',current_user_store) IN ('C09-00062-0055','C09-00062-0004','C09-00062-0005','C09-00062-0006','C09-00062-0013') THEN 'Octel'
            WHEN comm_brand_ds = 'PARLEM' THEN 'F46463'
            WHEN sfid_id = '201007055' THEN 'Octel'
            ELSE d.id_comisionista
          END AS id_comisionista,
          IF(a.service_type IN ('FIX','BROADBAND'), 'INTERNET',a.service_type) AS service_type
      FROM `mm-commissions-reporting.TEMP.BASE_LINEAS_GRUPO_PARLEM_CNMC` a
      LEFT JOIN dealers d ON ((d.id_comisionista = a.customer_id) OR  d.id_comisionista = a.current_sfid_id)
  ),

  cruce_listo AS (
    SELECT a.* EXCEPT(zip_code_xena,fix_base_gescal,fix_base_no_date_gescal,zip_code_xena_no_date,zip_code_voice_users,zip_code_voice_users_no_date,VENTAS_BASE_TELCO_ZIP),
      b.VENTAS_BASE_TELCO_ZIP,
      c.zip_code_xena,
      d.fix_base_gescal,
      e.fix_base_no_date_gescal,
      f.zip_code_xena_no_date,
      h.zip_code_voice_users,
      i.zip_code_voice_users_no_date
    FROM cruce a
    LEFT JOIN (
      SELECT id_comisionista, phone_nm, VENTAS_BASE_TELCO_ZIP
      FROM cruce
      WHERE VENTAS_BASE_TELCO_ZIP IS NOT NULL
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

    base_1 AS (
      
      --CABLEMOVIL Y PARLEM

      SELECT 
        a.*,
        COALESCE(fix_base_gescal,fix_base_no_date_gescal,zip_code_xena,zip_code_xena_no_date,zip_code_voice_users,zip_code_voice_users_no_date,VENTAS_BASE_TELCO_ZIP) AS zip_code
      FROM base_old a
      LEFT JOIN cruce_listo b ON a.phone_nm = b.phone_nm AND a.activation_date = b.activation_date
      WHERE 1=1
    ),

    base_2 AS(
      SELECT a.* EXCEPT(id_comisionista),
        CASE
          WHEN sfid_id = '201007055' THEN 'Octel'
          ELSE id_comisionista
        END AS id_comisionista
      FROM base_1 a
      -- JOIN (
      --   SELECT DISTINCT phone_nm
      --   FROM `mm-datamart-kd.BILLING.billing_detail_net`
      -- ) b ON a.phone_nm = b.phone_nm
      WHERE 1=1
        AND id_comisionista IN (
            'C09-00402',--APROOP TELECOM S.L
            'F00692',--APROOP TELECOM SLU
            --
            'Octel',
            'C09-00062-0055',--OCTEL TELECOM & TECH SOCIEDAD LIMITADA UNIPERSONAL
            --
            'C09-00186',--TELECOMUNICACIONS GARROTXA SL
            '216348',--TELECOMUNICACIONS GARROTXA SL
            --
            'C09-00216',--WICAT COMUNICACIONS SL
            '216242',--WICAT COMUNICACIONS SL
            --
            'C09-00463',--Xarxes Esteses de Comunicacions SL
            'F00764',--XEC (Wicat)
            'F00765',--XEC (Garrotxa)
            'F00679',--XARXES DE TELECOMUNICACIONS ALTERNATIVES SL
            'F00763',--XARXES ESTESES DE COMUNICACIONS SL
            --
            'C09-00193',--TOXO TELECOMUNICACIONES S.L
            'F46758',--TOXO TELECOMUNICACIONES SL
            --
            'F46463',--Parlem Telecom Companyia De Telecomunicacions SA
            --
            '201007'--NETLLAR S.L.
            --'C09-00062'--NETLLAR S.L.
          ) --
      QUALIFY ROW_NUMBER() OVER(PARTITION BY id_comisionista, phone_nm ORDER BY activation_date ASC) = 1
    ),

    base AS (
      SELECT *
      FROM base_2
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date ASC) = 1
    )
    ,

    base_empresas AS (
      SELECT 
        id_comisionista,
        service_type,
        -- CASE
        --   WHEN COALESCE(grupo_operador_donante_unificado,group_donor) IS NULL THEN 'ALTA NUEVA'
        --   ELSE COALESCE(grupo_operador_donante_unificado,group_donor) 
        -- END 
        COALESCE(grupo_operador_donante_unificado,group_donor) AS origen,
        CONCAT(EXTRACT(YEAR FROM base.activation_date),'T',EXTRACT(QUARTER FROM base.activation_date)) AS trimestre, 
        SUM(
          CASE
            WHEN NOT (zip_code LIKE '08%' --BARCELONA
              OR zip_code LIKE '46%' --VALENCIA
              OR zip_code LIKE '03%' --ALICANTE
              OR zip_code LIKE '12%' --CASTELLON 
              OR zip_code LIKE '17%' --GIRONA
              OR zip_code LIKE '25%' --LLEIDA
              OR zip_code LIKE '43%' --TARRAGONA
              OR zip_code LIKE '07%' --ISLAS BALEARES
            ) THEN 1 
            ELSE 0 
          END) AS total_activaciones_IRU, 
        COUNT(*) AS total_activaciones
      FROM base
      LEFT JOIN (
          SELECT grupo_operador_donante_unificado, phone_nm, activation_date
          FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
          WHERE grupo_operador_donante_unificado IS NOT NULL
          GROUP BY ALL
          QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm ORDER BY activation_date DESC, grupo_operador_donante_unificado DESC) = 1
      ) f ON base.phone_nm = f.phone_nm AND base.activation_date = f.activation_date
      LEFT JOIN (
          SELECT msisdn,CAST(vc_date AS DATE) AS activation_date, 
            CASE
              WHEN group_donor = 'GRUPO VODAFONE' THEN 'VODAFONE'
              WHEN group_donor = 'GRUPO ORANGE'  THEN 'ORANGE'
              WHEN group_donor = 'GRUPO TELEFONICA'THEN 'TELEFONICA'
              WHEN group_donor = 'GRUPO AVATEL' THEN 'GRUPO MASMOVIL'
              ELSE group_donor
            END AS group_donor
          FROM `mm-datamart-kd.PORTABILITY.portability_mobile_base` 
          WHERE group_donor IS NOT NULL
      ) g ON base.phone_nm = g.msisdn AND base.activation_date BETWEEN DATE_SUB(g.activation_date, INTERVAL 2 DAY) AND DATE_ADD(g.activation_date, INTERVAL 2 DAY) 
      GROUP BY ALL
    ),

    base_empresas_null AS (
      SELECT *
      FROM base_empresas
      WHERE origen IS NOT NULL
    ),

    base_agrupado AS (
      SELECT 
        id_comisionista,
        origen, 
        trimestre,
        service_type, 
        SUM(total_activaciones_IRU) AS total_activaciones_IRU, 
        SUM(total_activaciones) AS total_activaciones,
        (SUM(total_activaciones) - SUM(total_activaciones_IRU)) AS Activaciones_sin_IRU,
      FROM base_empresas_null
      GROUP BY ALL
    ),

    base_ope_grup AS (
      SELECT t1.*, 
        t2.total_lineas_codigo,
        t9.total_lineas_trimestre,
        IFNULL(t3.total_operador_MASORANGE,0)     AS total_operador_MASORANGE,
        IFNULL(T4.total_operador_ORANGE,0)        AS total_operador_ORANGE,
        IFNULL(T5.total_operador_GRUPOMASMOVIL,0) AS total_operador_GRUPOMASMOVIL,
        IFNULL(T6.total_grupo_MASORANGE,0)        AS total_grupo_MASORANGE,
        IFNULL(T7.total_grupo_ORANGE,0)           AS total_grupo_ORANGE,
        IFNULL(T8.total_grupo_GRUPOMASMOVIL,0)    AS total_grupo_GRUPOMASMOVIL
      FROM base_agrupado t1
      LEFT JOIN (
        SELECT id_comisionista, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_lineas_codigo
        FROM base_agrupado
        GROUP BY ALL) t2 ON t2.id_comisionista = t1.id_comisionista
          AND t2.service_type = t1.service_type
          AND t2.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT id_comisionista,
          origen, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_operador_MASORANGE,
        FROM base_agrupado
        WHERE origen IN ('MASORANGE')
        GROUP BY ALL) t3 ON t3.id_comisionista = t1.id_comisionista
          AND t3.service_type = t1.service_type
          AND t3.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT id_comisionista,
          origen, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_operador_ORANGE,
        FROM base_agrupado
        WHERE origen IN ('ORANGE')
        GROUP BY ALL) t4 ON t4.id_comisionista = t1.id_comisionista
          AND t4.service_type = t1.service_type
          AND t4.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT id_comisionista,
          origen, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_operador_GRUPOMASMOVIL
        FROM base_agrupado
        WHERE origen IN ('GRUPO MASMOVIL')
        GROUP BY ALL) t5 ON t5.id_comisionista = t1.id_comisionista
          AND t5.service_type = t1.service_type
          AND t5.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT 
          origen, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_grupo_MASORANGE
        FROM base_agrupado
        WHERE origen IN ('MASORANGE')
        GROUP BY ALL) t6 ON t6.service_type = t1.service_type
          AND t6.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT 
          origen, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_grupo_ORANGE
        FROM base_agrupado
        WHERE origen IN ('ORANGE')
        GROUP BY ALL) t7 ON t7.service_type = t1.service_type
          AND t7.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT 
          origen, 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_grupo_GRUPOMASMOVIL
        FROM base_agrupado
        WHERE origen IN ('GRUPO MASMOVIL')
        GROUP BY ALL) t8 ON t8.service_type = t1.service_type
          AND t8.trimestre = t1.trimestre
      LEFT JOIN (
        SELECT 
          trimestre,
          service_type, 
          SUM(activaciones_sin_IRU) AS total_lineas_trimestre
        FROM base_agrupado
        GROUP BY ALL) t9 ON t9.service_type = t1.service_type
          AND t9.trimestre = t1.trimestre
      GROUP BY ALL
    ),
      
    base_total_ope_grup AS (
      SELECT *,
        SUM(total_operador_MASORANGE + total_operador_ORANGE + total_operador_GRUPOMASMOVIL) AS total_operadores,
        SUM(total_grupo_MASORANGE + total_grupo_ORANGE + total_grupo_GRUPOMASMOVIL) AS total_grupos
      FROM base_ope_grup
      GROUP BY ALL
    ),

    total_agrupado AS (
      SELECT 
        id_comisionista,
        origen,
        trimestre,
        service_type,
        total_activaciones_IRU,
        total_activaciones,
        Activaciones_sin_IRU,
        total_lineas_codigo,
        total_operador_MASORANGE,
        total_operador_ORANGE,
        total_operador_GRUPOMASMOVIL,
        total_operadores,
        IFNULL(SAFE_DIVIDE(total_operadores,total_lineas_codigo),0)*100 AS por_operador,
        total_lineas_trimestre,
        total_grupo_MASORANGE,
        total_grupo_ORANGE,
        total_grupo_GRUPOMASMOVIL,
        total_grupos,
        IFNULL(SAFE_DIVIDE(total_grupos,total_lineas_trimestre),0)*100 AS por_grupo_MM
      FROM base_total_ope_grup
      ORDER BY 3 DESC, 1 DESC,2 ASC ,4 DESC
    ),

    CNMC AS (
      SELECT a.*,
        proporcion+5 AS prop_CNMC
      FROM total_agrupado a
      LEFT JOIN (
        SELECT *
        FROM `mm-commissions-reporting.TEMP.CNMC_GLOBAL`
        WHERE 1=1
          AND agrupacion = 'GENERAL'
          AND operador IN ('GRUPO MASMOVIL','MASORANGE')
        --QUALIFY ROW_NUMBER() OVER(ORDER BY trimestre DESC) = 1
      ) b ON a.origen = b.operador AND a.trimestre = b.trimestre
    ),
  
    porcentaje_penalizar AS (
      SELECT a.*,
        CASE
          WHEN por_grupo_MM > prop_CNMC  THEN ABS(por_grupo_MM - prop_CNMC) -- INTERVALO CORRECTO >
          ELSE 0
        END AS por_lineas_penalizar_grupo,
      total_lineas_a_penalizar
      FROM CNMC a
      --Cruzamos con la tabla original para determinar el número total de lineas a penalizar
      LEFT JOIN (
        SELECT origen,trimestre, service_type, SUM(Activaciones_sin_IRU) AS total_lineas_a_penalizar
        FROM CNMC
        WHERE por_grupo_MM > prop_CNMC
        GROUP BY ALL
      ) b ON a.trimestre = b.trimestre AND a.service_type = b.service_type AND a.origen = b.origen
    ),

    proporcion AS (
      SELECT *,
        SAFE_DIVIDE(Activaciones_sin_IRU,total_lineas_a_penalizar)*por_lineas_penalizar_grupo AS prop_n_lineas_penalizar
        --SAFE_DIVIDE(total_lineas_codigo,total_lineas_trimestre)*por_lineas_penalizar_grupo AS prop_n_lineas_penalizar
      FROM porcentaje_penalizar 
    )

    SELECT *
    FROM proporcion
  ;


--CREAMOS UNA TABLA QUE VA A CONTENER EL HISTÓRICO DE TELÉFONOS QUE VA A ESTAR PENALIZADOS POR TODA SU VIDA. 
--Una vez esté el procedimiento hecho hay que insertar la información en la tabla en vez de crear y reemplazar. Poner una columna de trimestre para evitar duplicidad en la información.

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.DETALLE_MOVILES_P_GRUPO_PARLEM_CNMC` AS 

--APLICAMOS Y EXTRAEMOS LA INFORMACIÓN BRUTA DE TRANSACCIONES

WITH  

  g_parlem_CNMC AS (
    SELECT 
      id_comisionista, 
      origen,
      a.trimestre,
      service_type,
      por_operador,
      por_grupo_MM,
      prop_CNMC,
      por_lineas_penalizar_grupo,
      prop_n_lineas_penalizar
    FROM `mm-commissions-reporting.TEMP.GRUPO_PARLEM_CNMC` a
  ),

  transacciones AS (
    SELECT
      a.id_comisionista,
      a.service_type,
      phone_nm,
      activation_date,
      por_lineas_penalizar_grupo,
      prop_n_lineas_penalizar,
      --Creamos la columna de activation_trimestre para identificar el trimestre que pertenece una linea según su fecha de activación
      CONCAT(
            SUBSTR(CAST(activation_date AS STRING), 1, 4), 'T', 
            CAST(CEIL(CAST(SUBSTR(CAST(activation_date AS STRING), 6, 2) AS INT64) / 3.0) AS STRING)
        ) AS activation_trimestre
    FROM `mm-commissions-reporting.COMISIONES.transacciones` a
    LEFT JOIN (
      SELECT *
      FROM g_parlem_CNMC
    )b ON a.id_comisionista = b.id_comisionista AND a.service_type = b.service_type AND b.trimestre = CONCAT(EXTRACT(YEAR FROM a.activation_date),'T',EXTRACT(QUARTER FROM a.activation_date))
    WHERE 1=1
       AND a.id_comisionista IN (
          'C09-00402',--APROOP TELECOM S.L
          'F00692',--APROOP TELECOM SLU
          --
          'Octel',
          'C09-00062-0055',--OCTEL TELECOM & TECH SOCIEDAD LIMITADA UNIPERSONAL
          --
          'F46463',--Parlem Telecom Companyia De Telecomunicacions SA
          --
          '201007'--NETLLAR S.L.
          ) --
    GROUP BY ALL
  ),

  --Nos quedamos con la última activación por teléfono y por trimestre evitando cambios de tarifa, etc

  ultima_act AS (
    SELECT *
    FROM transacciones
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id_comisionista,phone_nm,activation_trimestre ORDER BY activation_date DESC) = 1  
  ), 

  -- Filtramos solo aquellos registros cuyo trimestre de activación coincida con su trimestre de aparición
  filtrado AS (
    
    SELECT *,
      CONCAT(
          SUBSTR(CAST(activation_date AS STRING), 1, 4), 'T', 
          CAST(CEIL(CAST(SUBSTR(CAST(activation_date AS STRING), 6, 2) AS INT64) / 3.0) AS STRING)
      ) AS trimestre_actual
    FROM ultima_act
    WHERE activation_trimestre = CONCAT(
            SUBSTR(CAST(activation_date AS STRING), 1, 4), 'T', 
            CAST(CEIL(CAST(SUBSTR(CAST(activation_date AS STRING), 6, 2) AS INT64) / 3.0) AS STRING)
        )
  ),
  --Enumeramos cada linea según el trimestre y su fecha de activación
  n_penalizacion AS  (
    SELECT *,
      DENSE_RANK() OVER (PARTITION BY id_comisionista, trimestre_actual,service_type ORDER BY trimestre_actual,activation_date,phone_nm ASC) AS n_linea
    FROM filtrado
    WHERE 1=1
      --AND id_comisionista = 'F46463'
    GROUP BY ALL
    --ORDER BY id_comisionista,trimestre_actual ASC,service_type,activation_date ASC,n_linea,phone_nm
  ),

    --Contamos el número máximo de lineas por trimestre
  contar AS (
    SELECT id_comisionista,
      trimestre_actual,
      service_type,
      MAX(n_linea) max_lineas_distintas,
    FROM n_penalizacion
    GROUP BY ALL
  ),
  --Cruzamos el dato anterior con nuestra tabla original
  n_penalizacion_2 AS(
    SELECT a.*,
      max_lineas_distintas
    FROM n_penalizacion a
    LEFT JOIN (
      SELECT *
      FROM contar
    )b ON a.id_comisionista = b.id_comisionista AND a.trimestre_actual = b.trimestre_actual  AND a.service_type = b.service_type
  ),

  n_penalizacion_3 AS (
    SELECT *,
      ROUND(max_lineas_distintas *(prop_n_lineas_penalizar/100),0) AS n_lineas_penalizar,
      CAST(max_lineas_distintas - (ROUND(max_lineas_distintas *(prop_n_lineas_penalizar/100),0)-1) AS INT64) AS min_lineas
    FROM n_penalizacion_2
    WHERE por_lineas_penalizar_grupo !=0
  )

  SELECT 
    id_comisionista, 
      phone_nm,  
      service_type,
      activation_date,
      trimestre_actual,
      n_linea,
      max_lineas_distintas,
      por_lineas_penalizar_grupo,
      prop_n_lineas_penalizar,
      n_lineas_penalizar,
      min_lineas,
  FROM n_penalizacion_3
  WHERE trimestre_actual >= '2023T1'
  --WHERE id_comisionista = 'F46463' AND trimestre_actual = '2024T3' 
  AND n_linea BETWEEN min_lineas AND max_lineas_distintas
  GROUP BY ALL
  ORDER BY id_comisionista,trimestre_actual ASC,service_type,activation_date ASC,n_linea,phone_nm
;

--CREAMOS TABLA DE PENALIZACION FINAL PARA SUBIR A TRANSACCIONES

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PENALIZACION_GRUPO_PARLEM_CNMC_DEF` AS 

WITH 

  transacciones AS (
    SELECT a.* EXCEPT(comision,tax_base,emails_acceso_trazabilidad),
      a.comision,
      CASE
          WHEN CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64) IS NULL THEN 0
          WHEN CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64) > 0 THEN a.comision/(CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64)/100)
          ELSE 0
        END AS tax_base
    FROM `mm-commissions-reporting.COMISIONES.transacciones` a
    JOIN (
      SELECT *
      FROM `mm-commissions-reporting.TEMP.DETALLE_MOVILES_P_GRUPO_PARLEM_CNMC`
      --WHERE phone_nm = '602217459'
      ) b ON a.phone_nm = CAST(b.phone_nm AS STRING) AND a.id_comisionista = b.id_comisionista AND a.service_type = b.service_type AND a.activation_date = b. activation_date
    WHERE 1=1
      AND a.id_comisionista IN (
          'C09-00402',--APROOP TELECOM S.L
          'F00692',--APROOP TELECOM SLU
          --
          'Octel',
          'C09-00062-0055',--OCTEL TELECOM & TECH SOCIEDAD LIMITADA UNIPERSONAL
          --
          'F46463',--Parlem Telecom Companyia De Telecomunicacions SA
          --
          '201007'--NETLLAR S.L.
          ) --
      AND estado != 'calculado'
      AND UPPER(concepto) NOT LIKE 'PENALIZACION'
      AND tipo_concepto = 'AIRT'

      UNION ALL

      SELECT a.* EXCEPT(comision,tax_base,emails_acceso_trazabilidad),
        b.comision,
        tax_base
      FROM `mm-commissions-reporting.COMISIONES.transacciones` a
      --Realizamos una agregación por distribuidor y telefono para no duplicar lineas que estén dadas de baja y quedarnos con las que en realidad están activas/ultimos registros en upfront
      JOIN (
        SELECT a.id_comisionista, a.phone_nm,a.tipo_concepto,a.service_type,a.activation_date, SUM(comision) AS comision
        FROM `mm-commissions-reporting.COMISIONES.transacciones` a
        JOIN (
              SELECT *
              FROM `mm-commissions-reporting.TEMP.DETALLE_MOVILES_P_GRUPO_PARLEM_CNMC`
              --WHERE phone_nm = '602217459'
              ) b ON a.phone_nm = CAST(b.phone_nm AS STRING) AND a.id_comisionista = b.id_comisionista AND a.service_type = b.service_type AND a.activation_date = b. activation_date
        WHERE 1=1
          AND a.id_comisionista IN (
              'C09-00402',--APROOP TELECOM S.L
              'F00692',--APROOP TELECOM SLU
              --
              'Octel',
              'C09-00062-0055',--OCTEL TELECOM & TECH SOCIEDAD LIMITADA UNIPERSONAL
              --
              'F46463',--Parlem Telecom Companyia De Telecomunicacions SA
              --
              '201007'--NETLLAR S.L.
              ) --
          AND estado != 'calculado'
          AND UPPER(concepto) NOT LIKE 'PENALIZACION'
          AND tipo_concepto = 'UPFR'
        GROUP BY ALL
        )b ON a.phone_nm = b.phone_nm AND a.id_comisionista = b.id_comisionista AND a.service_type = b.service_type AND a.activation_date = b. activation_date AND a.tipo_concepto = b.tipo_concepto 
      WHERE b.comision > 0
        AND a.estado != 'calculado'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY a.phone_nm, a.id_comisionista ORDER BY a.activation_date DESC) = 1
  ), --SELECT * FROM transacciones WHERE phone_nm = '931305452',

  cartera AS (
    SELECT a.* EXCEPT(concepto,comision),
      'C - Penalizacion Portabilidades Grupo Market Share (10%)' AS concepto,
      tax_base*-0.10 AS comision_minorada
    FROM transacciones a
    WHERE 1=1
      AND tipo_concepto = 'AIRT'
  ),

  upfront AS (
    SELECT a.* EXCEPT(concepto,comision),
      'E - Penalizacion Market Share' AS concepto,
      -1*comision AS comision_minorada,
    FROM transacciones a
    WHERE 1=1
      AND tipo_concepto = 'UPFR'
  ),

  total AS (
    SELECT *
    FROM cartera

    UNION ALL

    SELECT *
    FROM upfront
  ),

  final AS (
    SELECT 
     'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AS mes_liquidado, 
      FORMAT_DATE('%Y%m',(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))) AS id_mes, 
      agrupacion_canal,
      canal,
      concepto,
      tipo_concepto,
      CASE
        WHEN tipo_concepto = 'AIRT' THEN 1
        WHEN tipo_concepto = 'UPFR' THEN -1
      END AS  unidades,
      --comision,
      comision_minorada AS comision,
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
      id_mes                   AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      tax_base,
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
      FROM total
      WHERE activation_date >= '2023-10-01'
  )

SELECT *
FROM final
;
END