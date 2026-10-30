BEGIN

DECLARE mes INT64;

SET mes =  CAST(FORMAT_DATE('%Y%m',DATE_TRUNC(CURRENT_DATE(), MONTH)) AS INT64);

--Procedimiento que calcula las provisiones del canal B2BC. 
--Primero se extrae la información, se procesa según sea el tipo de concepto AIRT o UPRF. Y luego al final se junta.

-- DS: https://lookerstudio.google.com/reporting/e5ba7e77-9497-421c-8557-0d2d127e6e4c/page/p_18x66dr1fd


--Actualizamos las tablas de dealers de TUCA y AVATEL
  CALL `mm-commissions-reporting.COMISIONES.pr_dealers_TUCA_CM_MB`();

  CALL `mm-commissions-reporting.COMISIONES.pr_dealers_AVATEL_CM_MB`();

-- CALL `mm-commissions-reporting.COMISIONES.pr_prov_visualizacion_b2b`()

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_copia_transacciones`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS  


  -- base AS (  
  SELECT 
      a.* EXCEPT(tipo_concepto,claim_code,unidades,bundle_type,cif,id_comisionista, nombre_comercio,estado),
      id_comisionista,
      cif,
      IF(bundle_type IS NULL, 'desc',bundle_type) AS bundle_type,
      CASE
        WHEN a.tipo_concepto LIKE 'AIR%' THEN 'AIRT'
        WHEN a.tipo_concepto LIKE 'UPF%' THEN 'UPFR'
        ELSE a.tipo_concepto
      END AS tipo_concepto,
      CASE WHEN a.unidades IS NULL THEN 1 WHEN a.unidades = 0 THEN 1 ELSE a.unidades END AS unidades,
      CASE
        WHEN agrupacion_canal IN ('B2B - Netllar','B2B - Hits') AND id_mes < 202403 THEN (
          CASE
            WHEN comments LIKE '%Abono%' THEN -CAST(REPLACE(REGEXP_EXTRACT(comments, r'[\d,]+\.\d+'), ',', '') AS FLOAT64)
            ELSE CAST(REPLACE(REGEXP_EXTRACT(comments, r'[\d,]+\.\d+'), ',', '') AS FLOAT64)
          END)
        WHEN agrupacion_canal IN ('B2B - Netllar','B2B - Hits','B2B - Nash') AND id_mes >= 202403 THEN tax_base
        WHEN id_mes >= 202501 AND tax_base IS NOT NULL THEN tax_base
        WHEN CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64) IS NULL THEN 0
        WHEN CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64) > 0 THEN a.comision/(CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64)/100)
        ELSE 0
      END AS facturado,
      CASE
        WHEN agrupacion_canal IN ('B2B - Netllar','B2B - Hits','B2B - Nash') AND id_mes < 202403 THEN comision/(
          CASE
            WHEN comments LIKE '%Abono%' THEN -CAST(REPLACE(REGEXP_EXTRACT(comments, r'[\d,]+\.\d+'), ',', '') AS FLOAT64)
            ELSE CAST(REPLACE(REGEXP_EXTRACT(comments, r'[\d,]+\.\d+'), ',', '') AS FLOAT64)
          END)
        WHEN agrupacion_canal IN ('B2B - Netllar','B2B - Hits','B2B - Nash') AND id_mes >= 202403 THEN comision/tax_base
        WHEN CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64) IS NULL THEN NULL
        ELSE CAST(REGEXP_EXTRACT(a.concepto, r'\(([\d.]+)%\)') AS FLOAT64)/100.0
      END AS porcentaje,
      claim_code,
    FROM `mm-commissions-reporting.COMISIONES.transacciones` a
    -- FROM base_previa a
    WHERE a.agrupacion_canal NOT IN ('D2D','No Exclusivo','TLV - Cross-sell','TLV - Outbound','D2D','Etnico','Exclusivo','Guuk','No Exclusivo','TLV - Cross-sell',
    'TLV - DO','TLV - Negocios','TLV - Outbound','TLV - Web')
      AND (concepto NOT LIKE '%Innova%')
      AND comision != 0
      AND UPPER(estado) IN ("FACTURADO", "PUBLICADO", "CONFIRMADO" , 'FACTURADO_IFS')
      AND (cuenta_contable LIKE '%12' OR cuenta_contable LIKE '%13' OR cuenta_contable IS NULL)
      --AND marca = 'SVINT'
      -- AND id_comisionista = 'C09-00443'
      -- AND tipo_concepto = 'UPFR'

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_transacciones_detalle`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 
    facturas_agrupadas AS (SELECT 
      id_mes,
      id_comisionista,
      CASE
          WHEN concepto LIKE 'C -%' THEN 'Cartera'
          WHEN concepto LIKE 'E -%' THEN 'Clawback'
          WHEN concepto LIKE 'D -%' OR concepto LIKE 'A -%'  THEN 'Altas'
          WHEN concepto LIKE 'Z -%' OR concepto LIKE 'R -%' THEN 'Ajustes'
          WHEN concepto LIKE 'T -%' THEN 'Terminales'
          ELSE NULL
        END AS concepto_agrupado,
      tipo_concepto,
      invoice_id,
      CASE
        WHEN tipo_concepto = 'AIRT' THEN SUM(facturado)
        WHEN tipo_concepto = 'UPFR' THEN SUM(comision)
        ELSE 0
      END AS importe_factura
    FROM `mm-commissions-reporting.TEMP.B2B_prov_copia_transacciones`
    GROUP BY 1,2,3,4,5,tipo_concepto
  )

  SELECT
    id_mes,
    id_comisionista,
    tipo_concepto,
    SUM(importe_factura) AS importe_base_total,
    ARRAY_AGG(
      STRUCT(
        invoice_id,
        concepto_agrupado,
        importe_factura
      )
    ) AS facturas
  FROM facturas_agrupadas
  GROUP BY id_mes, id_comisionista, tipo_concepto
  ORDER BY id_mes, id_comisionista

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_agrupado`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS  

  WITH 

    maestro_grupo AS (
      SELECT 
        id_comisionista,
        canal,
        comisiona,
        nombre_comercio,
        razon_social,
        documento,
        zona_fiscal,
        b2b_xena.GERENTE_CUENTA,
        b2b_xena.CUENTA_CLIENTE,
        b2b_xena.GRUPO,
        b2b_xena.PROVINCIA,
        b2b_xena.SEGMENTO
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` base
      LEFT JOIN (
            SELECT 
              GERENTE_CUENTA,
              cuenta_cliente,
              customer_id_xena,
              grupo,
              provincia,
              segmento,
              document_number
            FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B`
          ) b2b_xena ON base.id_comisionista = b2b_xena.customer_id_xena
      WHERE id_comisionista IS NOT NULL

      UNION ALL

      SELECT 
        DISTINCT
        id_comisionista,
        canal,
        comisiona,
        nombre_comercio,
        razon_social,
        documento,
        zona_fiscal,
        IF(b2b_marblanca.GERENTE_CUENTA IS NULL, 'Por definir',b2b_marblanca.GERENTE_CUENTA),
        IF(b2b_marblanca.CUENTA_CLIENTE IS NULL, 'Por definir',b2b_marblanca.CUENTA_CLIENTE),
        IF(b2b_marblanca.GRUPO IS NULL, 'Por definir',b2b_marblanca.GRUPO),
        IF(b2b_marblanca.PROVINCIA IS NULL, 'Por definir',b2b_marblanca.PROVINCIA),
        IF(b2b_marblanca.SEGMENTO IS NULL, 'Por definir',b2b_marblanca.SEGMENTO),
      FROM `mm-commissions-reporting.GS.DEALERS_MARBLANCA` base_2
      LEFT JOIN (
        SELECT 
          usuario AS codigo_mysim,
          codigo_xena,
          document_number,
          gerente_cuenta,
          grupo,
          cuenta_cliente,
          a.provincia,
          a.segmento,
        FROM `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B` a
        LEFT JOIN `mm-b2b-reporting.MAESTROS.datos_clientes_fibra`b ON a.customer_id_xena = b.codigo_xena
        WHERE usuario IS NOT NULL
      ) b2b_marblanca ON base_2.id_comisionista = b2b_marblanca.codigo_mysim
    ),

    tuca AS (
      SELECT id_comisionista 
      FROM `mm-commissions-reporting.B2B.DEALERS_TUCA_CM_MB`
      WHERE agrupacion_canal = 'B2B - Cablemovil' --Marblanca va por el porcentaje normal y no se agrupa en la agrupación de tuca cablemovil.
    ),

    avatel AS (
      SELECT id_comisionista 
      FROM `mm-commissions-reporting.B2B.DEALERS_AVATEL_CM_MB`
    ),

    agrupado AS (
      SELECT  
        base.id_mes,
        PARSE_DATE('%Y%m', CAST(base.id_mes AS STRING)) AS mes_liquidado,
        CASE
          WHEN base.marca = 'SVINT' THEN "Svint"
          WHEN UPPER(cuenta_cliente) LIKE "%SVINT%" AND base.agrupacion_canal = 'B2B - Cablemovil' THEN "B2B - Svint"
          WHEN UPPER(cuenta_cliente) LIKE "%SVINT%" AND base.agrupacion_canal = 'B2B - Marblanca'  THEN "B2B - Svint"
          --WHEN UPPER(cuenta_cliente) LIKE "%SVINT%" THEN "B2B - Svint"
          WHEN UPPER(cuenta_cliente) LIKE "%EMBOU%" THEN "B2B - Embou"
          WHEN UPPER(cuenta_cliente) LIKE "%AHIMAS%" THEN "B2B - Populoos"
          WHEN UPPER(cuenta_cliente) LIKE "%ONLYCABLE%" THEN "B2B - Onlycable"
          WHEN base.id_comisionista IN ('C09-00009','C09-00008',"F10968","F10973","F10961","F33987","F34028","F10967","F10971","F46100","F40288","F10965","F10964","216496","F10974","F10966","F10978","F10980","F43594","F91832","F45631","F45389") THEN 'B2B - Populoos'
          WHEN avatel.id_comisionista IS NOT NULL THEN "B2B - Avatel"
          WHEN tuca.id_comisionista IS NOT NULL THEN 'B2B - Tuca'
          WHEN base.id_comisionista = 'C09-00508' THEN 'B2B - Ez easy telecom'
          WHEN base.id_comisionista = 'C09-00422' THEN 'B2B - PTV'
          WHEN base.id_comisionista IN ('F00692','C09-00402') THEN 'B2B - Aproop'
          ELSE base.agrupacion_canal
        END AS agrupacion_canal,
        base.sociedad,
        CASE
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "ACUTEL" THEN "Acutel"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "ADAMO" THEN "Adamo"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "AVATEL" THEN "Avatel"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "AVANZA" THEN "Avanza"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "GRUPO GOD" THEN "Grupo God"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "EXCOM" THEN "Excom"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "FIBRANET" THEN "Fibranet"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "LEVANTE" THEN "Levante"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "TELE-CLARO" THEN "Tele-Claro"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "ETICOM" THEN "Eticom"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "VOZTELECOM" THEN "Voztelecom"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "ONSICOM" THEN "Onsicom"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "IBERWIX" THEN "Iberwix"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "TECNOCOLOR" THEN "Tecnocolor"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "TUCA" THEN "Tuca"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "VIVAMOVIL" THEN "Vivamovil"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "EURONA" THEN "Eurona"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") AND UPPER(CUENTA_CLIENTE) = "IZARKOM" THEN "Izarkom"
          WHEN (SEGMENTO = "Cableoperador" OR SEGMENTO = "GGCC") THEN "Otros CO/GGCC"
          WHEN (SEGMENTO = "Marca Blanca" OR SEGMENTO = "Marcas Blancas") AND UPPER(CUENTA_CLIENTE) = "ALE MOBILE" THEN "Ale Mobile"
          WHEN (SEGMENTO = "Marca Blanca" OR SEGMENTO = "Marcas Blancas") AND UPPER(CUENTA_CLIENTE) = "ALTERNA" THEN "Alterna"
          WHEN (SEGMENTO = "Marca Blanca" OR SEGMENTO = "Marcas Blancas") AND UPPER(CUENTA_CLIENTE) = "JOI" THEN "Joi"
          WHEN (SEGMENTO = "Marca Blanca" OR SEGMENTO = "Marcas Blancas") AND UPPER(CUENTA_CLIENTE) = "PARLEM" THEN "Parlem"
          WHEN (SEGMENTO = "Marca Blanca" OR SEGMENTO = "Marcas Blancas") AND UPPER(CUENTA_CLIENTE) = "SWENO" THEN "Sweno"
          WHEN SEGMENTO = "Marcas Propias" AND UPPER(CUENTA_CLIENTE) = "COMLOCAL" THEN "Comlocal"
          WHEN SEGMENTO = "Marcas Propias" AND UPPER(CUENTA_CLIENTE) = "EMBOU" THEN "Embou"
          WHEN SEGMENTO = "Marcas Propias" AND UPPER(CUENTA_CLIENTE) = "HITS MOBILE" THEN "Hits Mobile"
          WHEN SEGMENTO = "Marcas Propias" AND UPPER(CUENTA_CLIENTE) = "NETLLAR" THEN "Netllar"
          WHEN SEGMENTO = "Marcas Propias" AND UPPER(CUENTA_CLIENTE) = "ONLYCABLE" THEN "Onlycable"
          WHEN SEGMENTO = "Marcas Propias" AND UPPER(CUENTA_CLIENTE) = "POPULOOS" THEN "Populoos"
          ELSE NULL
        END AS cuentas_principales,
        CASE
          WHEN base.marca = "ALTERNA" THEN "Renata de las Heras"
          WHEN base.marca = "PARLEM" OR base.marca = "SWENO" OR UPPER(base.canal) LIKE "OCT" THEN "Serena Miguel"
          WHEN base.marca = "JOI" THEN "Angel Olea"
          WHEN UPPER(base.canal) LIKE "%JSM%" THEN "Angel Osuna"
          ELSE d.GERENTE_CUENTA
        END AS GERENTE_CUENTA,
        CASE 
          WHEN base.marca = "ALTERNA" THEN "ALTERNA"
          WHEN base.marca = "PARLEM" THEN "PARLEM"
          WHEN base.marca = "SWENO" THEN "SWENO"
          WHEN UPPER(base.canal) LIKE "%OCT%" THEN "OCT" 
          WHEN base.marca = "JOI" THEN "JOI"
          WHEN UPPER(base.canal) LIKE "%JSM%" THEN "JUNTOS SOMOS MAS"
          ELSE d.CUENTA_CLIENTE
        END AS CUENTA_CLIENTE,
        d.GRUPO,
        CASE
          WHEN base.marca = "ALTERNA" THEN "Marcas Blancas"
          WHEN base.marca = "PARLEM" OR base.marca = "SWENO" OR UPPER(base.canal) LIKE "%OCT%" THEN "Marcas Blancas"
          WHEN base.marca = "JOI" THEN "Marcas Blancas"
          WHEN UPPER(base.canal) LIKE "%JSM%" THEN "Marcas Propias"
          ELSE d.SEGMENTO
        END AS SEGMENTO,
        d.PROVINCIA,
        base.cif,
        base.id_comisionista,
        base.bundle_type,
        base.tipo_concepto,
        cod_producto,
        cod_tipo_contrato,
        cod_segmento,
        cod_canal,
        cod_marca,
        concepto,
        activation_date,
        deactivation_date,
        unidades,
        facturado,
        porcentaje,
        comision
      FROM `mm-commissions-reporting.TEMP.B2B_prov_copia_transacciones` base
      LEFT JOIN maestro_grupo d ON base.cif = d.documento AND base.id_comisionista = d.id_comisionista
      LEFT JOIN tuca ON base.id_comisionista = tuca.id_comisionista
      LEFT JOIN avatel ON base.id_comisionista = avatel.id_comisionista
      WHERE 1=1
        AND (base.marca IN ("ALTERNA", "PARLEM", "JOI", "SWENO", "ADAMO", "CABLEMOVIL", "MARBLANCA", "NETLLAR", "HITS", "SVINT") OR UPPER(base.canal) LIKE "JSM" OR UPPER(base.canal) LIKE "OCT")
        -- AND base.tipo_concepto = 'AIRT'
        -- AND (base.concepto NOT LIKE 'R -%' OR base.concepto NOT LIKE  'Z -%' OR base.concepto NOT LIKE  'E -%')
      -- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,base.deactivation_date,base.concepto
    )

    SELECT *
    FROM agrupado

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS  


  -- agrupado_AIRT AS (
    SELECT * EXCEPT(unidades,concepto,activation_date,deactivation_date,facturado,porcentaje,comision),
      0 AS unidades_upfr_serv,
      0 AS  unidades_upfr_camp,
      SUM(unidades) AS unidades,
      ROUND(SUM(comision)/IF(SUM(unidades) = 0,1,SUM(unidades)),2) AS unitario,
      ROUND(SUM(facturado),2) AS facturado,
      IF(CAST(ROUND(AVG(porcentaje)*100,2)AS FLOAT64) IS NULL,0,CAST(ROUND(AVG(porcentaje)*100,2)AS FLOAT64)) AS porcentaje,
      ROUND(SUM(comision),2) AS comision
    FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado` agrupado
    WHERE 1=1
      AND tipo_concepto = 'AIRT'
    GROUP BY ALL
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_agrupado_UPFR`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS  

  -- agrupado_UPFR AS (
        SELECT * EXCEPT(unidades,concepto,activation_date,deactivation_date,facturado,porcentaje,comision),
        CASE
          WHEN concepto LIKE 'A -%' THEN SUM(unidades) 
          ELSE 0
        END AS unidades_upfr_serv,
        CASE
          WHEN concepto LIKE 'D -%' THEN SUM(unidades) 
          ELSE 0
        END AS unidades_upfr_camp,
        0 AS unidades,
        CASE --Solo tenemos en en el unitario las altas de A - Servicio base
          WHEN concepto LIKE 'A -%' THEN SUM(comision)  / SUM(unidades) 
          ELSE 0
        END AS unitario,
        0 AS facturado,
        0 AS porcentaje,
        CASE
          WHEN (concepto LIKE 'A -%' OR concepto LIKE 'D -%') THEN SUM(comision) 
          ELSE 0
        END AS comision
        FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado` agrupado
        WHERE 1=1
          AND tipo_concepto = 'UPFR'
          AND (deactivation_date IS NULL OR deactivation_date = '9999-12-31')
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,concepto
  -- ), --SELECT * FROM agrupado_UPFR WHERE id_comisionista = 'C09-00088' and tipo_concepto = 'UPFR' AND ID_MES = 202510
;
  

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT_ESP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS  

  --  Sacamos la provision de los especiales del mes

  WITH 
    esp AS  (
      SELECT 
        CAST(b.id_mes AS INT64) AS id_mes,
        PARSE_DATE('%Y%m', CAST(b.id_mes AS STRING)) AS mes_liquidado,
        a.* EXCEPT(id_mes,unidades,unitario,facturado,porcentaje,comision,mes_liquidado),
        (a.comision*((b.porcentaje/100)+1)) as provision, 
        b.porcentaje AS porcentaje_prov
      FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT` a --agrupado_AIRT 
      LEFT JOIN `mm-commissions-reporting.GS.PORCENTAJE_PROVISIONES_B2B` b ON 
                a.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE_TRUNC(DATE(PARSE_DATE('%Y%m', CAST(CAST(b.id_mes AS INT64) AS STRING))), MONTH), INTERVAL 1 MONTH)) AS INT64) 
                AND a.id_comisionista = b.id_comisionista AND a.agrupacion_canal = b.agrupacion_canal
      WHERE  b.porcentaje IS NOT NULL
    ), 

    esp_final AS (
      SELECT 
        b.* EXCEPT(provision,porcentaje_prov),
        IF(unidades   IS NULL,0,unidades)   AS unidades,
        IF(unitario   IS NULL,0,unitario)   AS unitario,
        IF(facturado  IS NULL,0,facturado)  AS facturado,
        IF(porcentaje IS NULL,0,porcentaje) AS porcentaje,
        IF(comision   IS NULL,0,comision)   AS comision,
        provision,
        porcentaje_prov
      FROM esp b
      LEFT JOIN  `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT` c --agrupado_AIRT  
      ON b.id_mes = c.id_mes 
      AND b.id_comisionista = c.id_comisionista AND b.agrupacion_canal = c.agrupacion_canal AND b.bundle_type = c.bundle_type AND b.cod_producto = c.cod_producto AND b.cod_tipo_contrato = c.cod_tipo_contrato AND b.cod_segmento = c.cod_segmento AND b.cod_canal = c.cod_canal AND b.cod_marca = c.cod_marca AND b.tipo_concepto = c.tipo_concepto AND b.cif = c.cif AND b.sociedad = c.sociedad 
    )

    SELECT *
    FROM esp_final

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT_NO_ESP`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  --  Sacamos la provision de los no especiales del mes

  WITH
    n_esp AS  (
      SELECT 
        CAST(b.id_mes AS INT64) AS id_mes,
        PARSE_DATE('%Y%m', CAST(b.id_mes AS STRING)) AS mes_liquidado,
        a.* EXCEPT(id_mes,unidades,unitario,facturado,porcentaje,comision,mes_liquidado),
        (a.comision*((b.porcentaje/100)+1)) as provision, 
        b.porcentaje AS porcentaje_prov
      FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT` a --agrupado_AIRT 
      LEFT JOIN (
        SELECT * 
        FROM `mm-commissions-reporting.GS.PORCENTAJE_PROVISIONES_B2B`
        WHERE id_comisionista IS NULL
      ) b ON a.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE_TRUNC(DATE(PARSE_DATE('%Y%m', CAST(CAST(b.id_mes AS INT64) AS STRING))), MONTH), INTERVAL 1 MONTH)) AS INT64) 
                AND a.agrupacion_canal = b.agrupacion_canal
      WHERE  b.porcentaje IS NOT NULL
    ), 

    n_esp_final AS (
      SELECT  
        b.* EXCEPT(provision,porcentaje_prov),
        IF(unidades   IS NULL,0,unidades)   AS unidades,
        IF(unitario   IS NULL,0,unitario)   AS unitario,
        IF(facturado  IS NULL,0,facturado)  AS facturado,
        IF(porcentaje IS NULL,0,porcentaje) AS porcentaje,
        IF(comision   IS NULL,0,comision)   AS comision,
        provision,
        porcentaje_prov
      FROM n_esp b
      LEFT JOIN `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT` c --agrupado_AIRT  
      ON b.id_mes = c.id_mes AND b.id_comisionista = c.id_comisionista AND b.agrupacion_canal = c.agrupacion_canal AND b.bundle_type = c.bundle_type AND b.cod_producto = c.cod_producto AND b.cod_tipo_contrato = c.cod_tipo_contrato AND b.cod_segmento = c.cod_segmento AND b.cod_canal = c.cod_canal AND b.cod_marca = c.cod_marca AND b.tipo_concepto = c.tipo_concepto AND b.cif = c.cif AND b.sociedad = c.sociedad
      LEFT JOIN (
        SELECT DISTINCT id_mes, id_comisionista 
        FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT_ESP` --esp_final
      ) d  ON b.id_mes = d.id_mes AND b.id_comisionista = d.id_comisionista
      WHERE d.id_comisionista IS NULL
    )

    SELECT *
    FROM n_esp_final

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_final`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH
    unir_tablas AS (
      SELECT *
      FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT_NO_ESP` --esp_final

      UNION ALL

      SELECT *
      FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT_ESP` --n_esp_final
      
      UNION ALL 

      --Agregamos las líneas que no tienen porcentaje de provisión
      SELECT a.*,CAST(NULL AS FLOAT64) AS provision, CAST(NULL AS FLOAT64) AS porcentaje_prov
      FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT` a --agrupado_AIRT 
      LEFT JOIN (SELECT DISTINCT id_mes FROM `mm-commissions-reporting.GS.PORCENTAJE_PROVISIONES_B2B`) b ON a.id_mes = b.id_mes 
      WHERE b.id_mes IS NULL
    ),

    faltantes AS (

      SELECT a.*
      FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_AIRT` a --agrupado_AIRT 
      LEFT JOIN unir_tablas b ON CONCAT(a.id_mes,'-',a.id_comisionista,'-',a.comision) = CONCAT(b.id_mes,'-',b.id_comisionista,'-',b.comision)
      WHERE b.id_mes IS NULL 
    ),

    final AS (
      SELECT *
      FROM unir_tablas
      
      UNION ALL

      SELECT *,
      0 AS provision,
      0 AS porcentaje_prov
      FROM faltantes
    ),

  --Unimos la query final de AIRTIME con la UPFRONT
  final_v2 AS (
    SELECT 
      b.* EXCEPT (agrupacion_canal,unidades, unitario,unidades_upfr_serv, unidades_upfr_camp, facturado,porcentaje,comision,provision,porcentaje_prov),
        b.unidades,
        b.unitario,
        0 AS unidades_upfr_serv,
        0 AS unidades_upfr_camp,
        b.facturado,
        b.porcentaje,
        b.comision,
        b.provision,
        b.porcentaje_prov,
      CASE 
        WHEN b.agrupacion_canal = 'Nash' THEN 'Populoos'
        ELSE b.agrupacion_canal
      END AS agrupacion_canal,
      c.provision AS pre_provision,
    FROM final b
    LEFT JOIN (SELECT * FROM final) c ON b.id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(c.mes_liquidado, INTERVAL 1 MONTH)) AS INT64) AND b.id_comisionista = c.id_comisionista AND b.agrupacion_canal = c.agrupacion_canal AND b.bundle_type = c.bundle_type AND b.cod_producto = c.cod_producto AND b.cod_tipo_contrato = c.cod_tipo_contrato AND b.cod_segmento = c.cod_segmento AND b.cod_canal = c.cod_canal AND b.cod_marca = c.cod_marca AND b.tipo_concepto = c.tipo_concepto AND b.cif = c.cif AND b.sociedad = c.sociedad 

    UNION ALL

    SELECT * EXCEPT(agrupacion_canal,unidades_upfr_serv,unidades_upfr_camp,unidades, unitario,facturado,porcentaje,comision),
      unidades,
      unitario,
      unidades_upfr_serv,
      unidades_upfr_camp,
      0 AS facturado,
      0 AS porcentaje,
      comision,
      0 AS provision,
      0 AS porcentaje_prov,
      agrupacion_canal,
      0 AS pre_provision
    FROM `mm-commissions-reporting.TEMP.B2B_prov_agrupado_UPFR` --agrupado_UPFR
  )

  SELECT a.*,
  FROM final_v2 a
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_prov_final_v2`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  SELECT a.*, b.facturas
  FROM `mm-commissions-reporting.TEMP.B2B_prov_final` a
  LEFT JOIN `mm-commissions-reporting.TEMP.B2B_prov_transacciones_detalle` b ON a.id_mes = b.id_mes AND a.id_comisionista = b.id_comisionista AND a.tipo_concepto = b.tipo_concepto
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.visualizacion_transacciones_prov_b2b` AS
  
  --Provision del mes 
  SELECT 
    id_mes		,	
    mes_liquidado		,	
    sociedad		,	
    cuentas_principales		,	
    GERENTE_CUENTA		,	
    CUENTA_CLIENTE		,	
    GRUPO		,	
    SEGMENTO		,	
    PROVINCIA		,	
    cif		,	
    id_comisionista		,	
    bundle_type		,	
    tipo_concepto		,	
    cod_producto		,	
    cod_tipo_contrato		,	
    cod_segmento		,	
    cod_canal		,	
    cod_marca		,	
    unidades		,	
    unitario		,	
    unidades_upfr_serv		,	
    unidades_upfr_camp		,	
    facturado		,	
    porcentaje		,	
    comision		,	
    provision		,	
    porcentaje_prov		,	
    agrupacion_canal		,	
    pre_provision		,	
    CAST(NULL AS STRING) AS invoice_id		,	
    CAST(NULL AS STRING) AS concepto_agrupado		,	
    CAST(NULL AS FLOAT64) AS importe_factura		,	
  FROM `mm-commissions-reporting.TEMP.B2B_prov_final_v2`
  WHERE id_mes = mes
  
  UNION ALL
  
  --Provision de meses anteriores
  SELECT 
    id_mes		,	
    mes_liquidado		,	
    sociedad		,	
    cuentas_principales		,	
    GERENTE_CUENTA		,	
    CUENTA_CLIENTE		,	
    GRUPO		,	
    SEGMENTO		,	
    PROVINCIA		,	
    cif		,	
    id_comisionista		,	
    bundle_type		,	
    tipo_concepto		,	
    cod_producto		,	
    cod_tipo_contrato		,	
    cod_segmento		,	
    cod_canal		,	
    cod_marca		,	
    unidades		,	
    unitario		,	
    unidades_upfr_serv		,	
    unidades_upfr_camp		,	
    CASE 
      WHEN ROW_NUMBER() OVER (
            PARTITION BY id_mes, id_comisionista,tipo_concepto,bundle_type,cod_tipo_contrato,cod_producto
          ) = 1 THEN facturado
      ELSE 0
    END AS facturado		,	
    CASE 
        WHEN ROW_NUMBER() OVER (
              PARTITION BY id_mes, id_comisionista,tipo_concepto, bundle_type,cod_tipo_contrato,cod_producto
            ) = 1 THEN porcentaje
        ELSE 0
      END AS porcentaje		,	
    CASE 
        WHEN ROW_NUMBER() OVER (
              PARTITION BY id_mes, id_comisionista,tipo_concepto, bundle_type,cod_tipo_contrato,cod_producto
            ) = 1 THEN comision
        ELSE 0
      END AS comision		,	
    CASE 
        WHEN ROW_NUMBER() OVER (
              PARTITION BY id_mes, id_comisionista,tipo_concepto, bundle_type,cod_tipo_contrato,cod_producto
            ) = 1 THEN provision
        ELSE 0
      END AS provision		,	
    CASE 
        WHEN ROW_NUMBER() OVER (
              PARTITION BY id_mes, id_comisionista,tipo_concepto, bundle_type,cod_tipo_contrato,cod_producto
            ) = 1 THEN porcentaje_prov
        ELSE 0
      END AS porcentaje_prov		,	
    agrupacion_canal		,	
    CASE 
        WHEN ROW_NUMBER() OVER (
              PARTITION BY id_mes, id_comisionista,tipo_concepto, bundle_type,cod_tipo_contrato,cod_producto
            ) = 1 THEN pre_provision
        ELSE 0
      END AS pre_provision		,	
    f.invoice_id		,	
    f.concepto_agrupado		,	
    f.importe_factura		,	
  FROM `mm-commissions-reporting.TEMP.B2B_prov_final_v2`,
  UNNEST(facturas) AS f
;
END