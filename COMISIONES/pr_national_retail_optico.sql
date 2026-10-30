BEGIN


DECLARE err, sql STRING;


/*
CALL `mm-commissions-reporting.COMISIONES.pr_national_retail_optico`(202609);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.national_retail_optico_cif_clean`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS
(
SELECT
      * EXCEPT (NIF, cif_distribuidor, cif_cabecera)
     ,TRIM(NIF) AS cif_pdv

     ,TRIM(cif_distribuidor) AS cif_master

     ,TRIM(cif_cabecera) AS cif_gpv

FROM `mm-sales-reporting.optico.optico_noexclusivo_26N`
WHERE (
      (CCC_Jazztel NOT IN ('NNCC00000T','DEMOPDVCCC') OR CCC_Jazztel IS NULL)
  AND (USUARIO_SIMYO NOT IN ('PdV_Or_demo_pdv','PdV_Or_') OR USUARIO_SIMYO IS NULL)
)
AND fecha_optico = (
    SELECT MAX(fecha_optico)
    FROM `mm-sales-reporting.optico.optico_noexclusivo_26N`
    WHERE fecha_optico >= PARSE_DATE('%Y%m', CAST(mes_int AS STRING))
      AND fecha_optico < DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)
)
)

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.national_retail_optico_sfid_list` AS (
  SELECT 
  CASE WHEN distribuidor = 'THE PHONE HOUSE' THEN sfid_thp
   ELSE sfid_distribuidor END AS sfid_pago
  ,sfid_distribuidor AS sfid
  ,'ORANGE' AS origin_system
  ,'NEX' AS origin_google_sheet 

  FROM `mm-commissions-reporting.TEMP.national_retail_optico_cif_clean`


  UNION DISTINCT

  SELECT 
  CASE WHEN distribuidor = 'THE PHONE HOUSE' THEN sfid_thp
   ELSE sfid_distribuidor END AS sfid_pago
  ,CCC_Jazztel AS sfid
  ,'JAZZTEL' AS origin_system
  ,'NEX' AS origin_google_sheet 

  FROM  `mm-commissions-reporting.TEMP.national_retail_optico_cif_clean`


  UNION DISTINCT 

  SELECT
  CASE WHEN distribuidor = 'THE PHONE HOUSE' THEN sfid_thp
   ELSE sfid_distribuidor END AS sfid_pago
  ,REPLACE(ccc_jazztel2, 'T','') AS sfid
  ,'JAZZTEL' AS origin_system
  ,'NEX' AS origin_google_sheet 

  FROM  `mm-commissions-reporting.TEMP.national_retail_optico_cif_clean`
  WHERE ccc_jazztel2 IS NOT NULL


  UNION DISTINCT

  SELECT  
  CASE WHEN distribuidor = 'THE PHONE HOUSE' THEN sfid_thp
   ELSE sfid_distribuidor END AS sfid_pago
  ,USUARIO_SIMYO AS sfid
  ,'SIMYO' AS origin_system
  ,'NEX' AS origin_google_sheet 

  FROM  `mm-commissions-reporting.TEMP.national_retail_optico_cif_clean`


)

;


-- Duplicate Check --

SET err = (
  WITH duplicates AS
  (
  SELECT
        sfid
       ,origin_system
       ,COUNT(DISTINCT sfid_pago)
  FROM `mm-commissions-reporting.TEMP.national_retail_optico_sfid_list`
  WHERE sfid IS NOT NULL
        AND sfid NOT IN ('#N/A')
  GROUP BY 1,2
  HAVING COUNT(DISTINCT sfid_pago) > 1
  )
  
  SELECT STRING_AGG(sfid)
  FROM duplicates
);

IF err IS NOT NULL THEN RAISE USING MESSAGE = 'Existen sfid de national retail con conflicto de sfid unico: ' || err; END IF;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.national_retail_optico_sfid_filter`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)) AS(
SELECT
     CASE WHEN CLEAN.distribuidor = 'GRUPO CARREFOUR'  THEN 'CFR_NR'
          WHEN CLEAN.distribuidor = 'FNAC'             THEN 'FNAC_NR'
          WHEN CLEAN.Distribuidor = 'GRUPO MEDIA MARKT'THEN 'MKT_NR'
          WHEN CLEAN.Distribuidor = 'THE PHONE HOUSE'  THEN 'THP_NR'
     END AS canal
     ,LIST.sfid
     ,CLEAN.sfid_distribuidor AS sfid_unico
     ,CAST(CLEAN.ID_Empresa AS STRING) AS id_empresa
     ,UPPER(REPLACE(REPLACE(CLEAN.cif_pdv, '-', ''), ' ', '')) AS cif_pdv
     ,UPPER(REPLACE(REPLACE(CLEAN.cif_master, '-', ''), ' ', '')) AS cif_master
     ,UPPER(REPLACE(REPLACE(CLEAN.cif_gpv, '-', ''), ' ', '')) AS cif_gpv
     ,sfid_distribuidor
     ,CASE WHEN CLEAN.Distribuidor = 'AVORIS' THEN 'AVORIS' ELSE CLEAN.codigo_distribuidor END AS distribuidor
     ,CLEAN.panzer
     ,CLEAN.channel
     ,CLEAN.subchannel
     ,CLEAN.Marco_Retributivo AS marco_retributivo
     ,CLEAN.estado
     ,CLEAN.provincia
     ,UPPER(REPLACE(REPLACE(CLEAN.cif_pdv, '-', ''), ' ', '')) AS numero_documento
     ,UPPER(CLEAN.Empresa) AS razon_social
     ,UPPER(CLEAN.Punto_de_venta) AS nombre_comercial_pdv
     ,fecha_baja
     ,CASE
        WHEN SUBSTR(LPAD(CAST(CLEAN.codigo_postal AS STRING), 5, '0'), 1, 2) IN ('35','38') THEN 'CAN'
        WHEN SUBSTR(LPAD(CAST(CLEAN.codigo_postal AS STRING), 5, '0'), 1, 2) = '51' THEN 'CEU'
        WHEN SUBSTR(LPAD(CAST(CLEAN.codigo_postal AS STRING), 5, '0'), 1, 2) = '52' THEN 'MEL'
        ELSE 'PEN'
     END AS zona_fiscal

     ,CASE
          WHEN (
          COALESCE(CLEAN.estado, 'X') <> 'DESACTIVADO'
          OR COALESCE(
               CLEAN.fecha_baja,
               DATE '9999-12-31'
               ) > PARSE_DATE('%Y%m', CAST(mes_int AS STRING)))
               AND CLEAN.cif_pdv NOT IN ('B70186184')
               AND (
                    UPPER(REPLACE(TRIM(CLEAN.usuario_google_pdv), ' ', ''))   LIKE '%@MASMOVIL.COM'
                   OR UPPER(REPLACE(TRIM(CLEAN.usuario_google_pdv), ' ', '')) LIKE '%@MASORANGE.ES'
                   OR UPPER(REPLACE(TRIM(CLEAN.usuario_google_pdv), ' ', '')) LIKE '%@ASESORMASMOVIL.ES'
                   )
          THEN LOWER(TRIM(REPLACE(TRIM(CLEAN.usuario_google_pdv), ' ', '')))
          WHEN CLEAN.Distribuidor = 'AVORIS'  THEN 'avorisdataventas@asesormasmovil.es'
          ELSE CAST(NULL AS STRING)
      END AS usuario_google
     
     ,CASE
          WHEN (
                UPPER(CLEAN.mail_manager)   LIKE '%@MASMOVIL.COM'
               OR UPPER(CLEAN.mail_manager) LIKE '%@MASORANGE.ES'
               OR UPPER(CLEAN.mail_manager) LIKE '%@ASESORMASMOVIL.ES'
               )
          THEN TRIM(CLEAN.mail_manager)
      END AS mail_manager

     ,CASE
          WHEN (
                UPPER(CLEAN.mail_coordinador)   LIKE '%@MASMOVIL.COM'
               OR UPPER(CLEAN.mail_coordinador) LIKE '%@MASORANGE.ES'
               OR UPPER(CLEAN.mail_coordinador) LIKE '%@ASESORMASMOVIL.ES'
               )
          THEN TRIM(CLEAN.mail_coordinador)
      END AS mail_coordinador

     ,CASE
          WHEN (
                UPPER(CLEAN.mail_specialist)   LIKE '%@MASMOVIL.COM'
               OR UPPER(CLEAN.mail_specialist) LIKE '%@MASORANGE.ES'
               OR UPPER(CLEAN.mail_specialist) LIKE '%@ASESORMASMOVIL.ES'
               )
          THEN TRIM(CLEAN.mail_specialist)
      END AS mail_specialist

     ,CASE
          WHEN (
                UPPER(CLEAN.mail_gpv)   LIKE '%@MASMOVIL.COM'
               OR UPPER(CLEAN.mail_gpv) LIKE '%@MASORANGE.ES'
               OR UPPER(CLEAN.mail_gpv) LIKE '%@ASESORMASMOVIL.ES'
               )
               AND UPPER(CLEAN.mail_gpv) NOT LIKE '%GPV%'
          THEN TRIM(CLEAN.mail_gpv)
      END AS mail_gpv
     
     ,CAST  (NULL AS STRING ) AS mail_kam

     ,CAST  (NULL AS STRING ) AS mail_distribuidor

     ,CAST  (NULL AS STRING ) AS mail_distribuidor_2

     ,CASE
          WHEN (
                UPPER(CLEAN.usuario_google1)   LIKE '%@MASMOVIL.COM'
               OR UPPER(CLEAN.usuario_google1) LIKE '%@MASORANGE.ES'
               OR UPPER(CLEAN.usuario_google1) LIKE '%@ASESORMASMOVIL.ES'
               )
          THEN TRIM(CLEAN.usuario_google1)
      END AS mail_distribuidor_3

     ,CASE
          WHEN (
                UPPER(CLEAN.usuario_google2)   LIKE '%@MASMOVIL.COM'
               OR UPPER(CLEAN.usuario_google2) LIKE '%@MASORANGE.ES'
               OR UPPER(CLEAN.usuario_google2) LIKE '%@ASESORMASMOVIL.ES'
               )
          THEN TRIM(CLEAN.usuario_google2)
      END AS mail_distribuidor_4
     ,CASE
  WHEN COALESCE(CLEAN.estado, 'X') <> 'DESACTIVADO'
    OR COALESCE(
         CLEAN.fecha_baja,
         DATE '9999-12-31'
       ) > PARSE_DATE('%Y%m', CAST(mes_int AS STRING))
  THEN TRUE ELSE FALSE
END AS comisiona

FROM `mm-commissions-reporting.TEMP.national_retail_optico_cif_clean` CLEAN

INNER JOIN `mm-commissions-reporting.TEMP.national_retail_optico_sfid_list` LIST
          ON CLEAN.sfid_distribuidor = LIST.sfid_pago AND LIST.sfid IS NOT NULL

WHERE LIST.sfid NOT IN ('PARALIZADO','SOLICITADO')
      AND LIST.sfid NOT LIKE 'MP%'

      AND CLEAN.subchannel = 'NATIONAL RETAIL'
      AND Distribuidor IN ('FNAC','GRUPO CARREFOUR','GRUPO MEDIA MARKT','THE PHONE HOUSE')

QUALIFY ROW_NUMBER() OVER (PARTITION BY LIST.sfid) = 1)
;

INSERT INTO `mm-commissions-reporting.COMISIONES.dealer`
(
id_mes, agrupacion_canal, sfid, id_comisionista, distribuidor,
canal, comisiona, nombre_comercio, razon_social, documento,
zona_fiscal, comentarios, cif_gpv, cond_pago, creado_por, creado
)

SELECT
      mes_int
     ,'NATIONAL RETAIL' AS agrupacion_canal
     ,OPTICO.sfid
     -- ,COALESCE(PDV_MASTER.id_comisionista, OPTICO.sfid) AS id_comisionista
     ,OPTICO.sfid_unico AS id_comisionista
     ,CAST(NULL AS STRING) AS distribuidor

     ,OPTICO.canal

     ,OPTICO.comisiona
     ,OPTICO.nombre_comercial_pdv AS nombre_comercio
     ,OPTICO.razon_social
     -- ,COALESCE(PDV_MASTER.cif, OPTICO.cif_pdv) AS cif
     -- INCLUIMOS CIF TECALIS PARA LOS PDVS DE ALTERNATIVO
     -- ,CASE 
     --      WHEN UPPER(OPTICO.marco_retributivo) LIKE 'ALTERNATIVO%'    THEN 'B75728329'
     --      ELSE COALESCE(PDV_MASTER.cif, OPTICO.cif_pdv) 
     --      END AS cif
     ,OPTICO.cif_pdv AS CIF
     -- ,COALESCE(PDV_MASTER.zona_fiscal, OPTICO.zona_fiscal) AS zona_fiscal
     ,OPTICO.zona_fiscal

     ,CAST (NULL AS STRING) AS comentarios
     
     ,OPTICO.cif_gpv
     ,'Z020' AS cond_pago
      
     ,SESSION_USER()
     ,CURRENT_TIMESTAMP()

FROM `mm-commissions-reporting.TEMP.national_retail_optico_sfid_filter` OPTICO


;

END