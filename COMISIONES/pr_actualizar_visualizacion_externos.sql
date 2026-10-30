BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_actualizar_visualizacion_externos`();

/************************************************************
-- PARA CAMBIAR pr_actualizar_visualizacion_externos       --
-- SUSTITUYE A pr_actualizar_visualizacion_externos_jun_26 --
************************************************************/

DECLARE mes_actual DATE;
DECLARE mes_anterior INT64;

SET mes_actual = DATE_TRUNC(CURRENT_DATE(), MONTH);
SET mes_anterior =SAFE_CAST(SUBSTRING(CAST((mes_actual-1) AS STRING),1,4)||  SUBSTRING(CAST((mes_actual-1) AS STRING),6,2) AS INT64) ;


  --Detectamos cambios a realizar
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cambios_acceso_trazabilidad`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 5 DAY)) AS
      SELECT *
      FROM (  
        SELECT tabla_acceso.cif, tabla_acceso.agrupacion_canal, tabla_acceso.email, tra.email AS email_transacciones
        FROM (
          SELECT DISTINCT
              cif,
              agrupacion_canal,
              TRIM(email) AS email
          FROM
              `mm-commissions-reporting.TEMP.emails_acceso_trazabilidad`  --CAMBIAMOS LA VISTA POR UNA TABLA TEMPORAL
          WHERE
              email IS NOT NULL
              AND cif NOT IN ('52887070L')
        ) tabla_acceso
          LEFT JOIN (
              SELECT DISTINCT
                  cif
                , agrupacion_canal
                , TRIM(email) AS email
              FROM `mm-commissions-reporting.COMISIONES.transacciones` t
              LEFT JOIN UNNEST(t.emails_acceso_trazabilidad) AS email
              WHERE id_mes >= mes_anterior
          ) tra
            ON  tra.cif = tabla_acceso.cif
            /* 20260915 Ainhoa: Se añade cruce para considerar y actualizar también
               las transacciones con el campo email vacío o NULL, que anteriormente no se estaban contemplando.*/
            AND (
                  tra.email = tabla_acceso.email
                  OR tra.email IS NULL
                ) 
            AND tra.agrupacion_canal = tabla_acceso.agrupacion_canal
        WHERE tabla_acceso.email IS NOT NULL
          AND tabla_acceso.email NOT IN ('',' ')
      )
      WHERE email_transacciones IS NULL OR TO_JSON_STRING(email_transacciones) != TO_JSON_STRING(email);


      --CASO GENERAL
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET a.emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
          a.modificado = CURRENT_TIMESTAMP()
      FROM (
            SELECT   cif
                   , agrupacion_canal
                   , ARRAY_AGG (distinct TRIM(email)) AS emails_acceso_trazabilidad
            FROM `mm-commissions-reporting.TEMP.cambios_acceso_trazabilidad` cat
            WHERE cat.email IS NOT NULL
              AND cat.cif NOT IN ('52887070L')
            GROUP BY 1,2
      ) b
      WHERE a.agrupacion_canal = b.agrupacion_canal
        AND a.cif = b.cif
        AND a.id_mes >= mes_anterior
        AND (a.emails_acceso_trazabilidad IS NULL OR TO_JSON_STRING(a.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad));

      --OPTICO NO EXCLUSIVO - Agrupacion canal + CIF + seller
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET   emails_acceso_trazabilidad = b.emails_acceso_trazabilidad
          , a.modificado = CURRENT_TIMESTAMP()
      FROM (
            SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
            FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
            UNNEST([TRIM(usuario_google), TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam), TRIM(mail_distribuidor)
                    , TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)]) emails_accesso_trazabilidad
            WHERE cif_pdv NOT IN ('52887070L')
                  AND comisiona
            GROUP BY 1,2,3
      ) b
      WHERE a.agrupacion_canal = b.agrupacion_canal
        AND a.cif = b.cif
        AND a.seller = b.sfid
        --AND a.cif NOT IN ('B70186184','B75728329')  --CIF de TECALIS CONSULTA 4 LA INCLUIMOS QUITANDO ESTE FILTRO
        AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
        AND a.id_mes >= mes_anterior
        AND (a.emails_acceso_trazabilidad IS NULL OR TO_JSON_STRING(a.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad));

      --OPTICO NO EXCLUSIVO - Agrupacion canal + CIF + sfid_id
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET   emails_acceso_trazabilidad = b.emails_acceso_trazabilidad
          , a.modificado = CURRENT_TIMESTAMP()
      FROM (
            SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
            FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
            UNNEST([TRIM(usuario_google), TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam), TRIM(mail_distribuidor)
                    , TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)]) emails_accesso_trazabilidad
            WHERE cif_pdv NOT IN ('52887070L')
                  AND comisiona
            GROUP BY 1,2,3
      ) b
      WHERE a.agrupacion_canal = b.agrupacion_canal
        AND a.cif = b.cif
        AND a.sfid_id = b.sfid
        --AND a.cif NOT IN ('B70186184','B75728329')  --CIF de TECALIS CONSULTA 5 LA INCLUIMOS QUITANDO ESTE FILTRO
        AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
        AND a.id_mes >= mes_anterior
        AND (a.emails_acceso_trazabilidad IS NULL OR TO_JSON_STRING(a.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad));


      --Borrar permisos si no corresponden en No Exclusivo
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET emails_acceso_trazabilidad = CAST(NULL AS ARRAY<STRING>),
      modificado = CURRENT_TIMESTAMP()
      FROM (
            SELECT numero_documento
            FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`
            WHERE NOT comisiona
            QUALIFY ROW_NUMBER() OVER (PARTITION BY numero_documento) = 1
      ) b
      WHERE a.agrupacion_canal = 'No Exclusivo'
        AND a.cif = b.numero_documento
        AND a.emails_acceso_trazabilidad IS NOT NULL
        AND a.id_mes >= mes_anterior
      ;

      --Accesos de los Masters
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET a.emails_acceso_trazabilidad = b.emails
          , a.modificado = CURRENT_TIMESTAMP()
      FROM (
            SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
            FROM (
                  SELECT TRANSACCIONES.cif, MASTER.emails
                  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
                  INNER JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
                    ON TRANSACCIONES.cif = MASTER.documento
                  WHERE TRANSACCIONES.id_mes >= mes_anterior
                  GROUP BY 1,2
                  
                  UNION ALL
                  
                  SELECT documento, emails FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`, UNNEST(SPLIT(emails, ',')) AS emails
            )
            GROUP BY 1
      ) b
      WHERE a.agrupacion_canal IN ('No Exclusivo')
        AND a.cif = b.cif
        AND a.id_mes >= mes_anterior
        AND (a.emails_acceso_trazabilidad IS NULL OR TO_JSON_STRING(a.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails));

      --Accesos MP
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET   a.emails_acceso_trazabilidad = b.emails
          , a.modificado = CURRENT_TIMESTAMP()
      FROM (
            SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
            FROM (
                  SELECT TRANSACCIONES.cif, emails
                  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
                  INNER JOIN `mm-commissions-reporting.GS.ACCESO_TRAZA_MP` MP
                    ON TRANSACCIONES.cif = MP.cif
                  WHERE TRANSACCIONES.id_mes >= mes_anterior
                  GROUP BY 1,2
                  UNION ALL
                  SELECT cif, emails FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_MP`, UNNEST(SPLIT(emails, ',')) AS emails
                  )
            GROUP BY 1
      ) b
      WHERE a.cif = b.cif
        AND a.id_mes >= mes_anterior
        AND a.canal = 'MP'
        AND (a.emails_acceso_trazabilidad IS NULL OR TO_JSON_STRING(a.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails));


      -- --Permisos de PH
      -- UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      -- SET   a.emails_acceso_trazabilidad = ['phfinanzas@asesormasmovil.es']
      --   , a.modificado = CURRENT_TIMESTAMP()
      -- WHERE cif = 'B81846206'
      --   AND a.id_mes >= mes_anterior
      --   AND a.emails_acceso_trazabilidad != ['phfinanzas@asesormasmovil.es'];


        --modfificado de ph

        
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET
    a.emails_acceso_trazabilidad = ['phfinanzas@asesormasmovil.es'],
    a.modificado = CURRENT_TIMESTAMP()
WHERE cif = 'B81846206'
  AND a.id_mes >= mes_anterior
  AND (
        a.emails_acceso_trazabilidad IS NULL
        OR TO_JSON_STRING(a.emails_acceso_trazabilidad)
           != TO_JSON_STRING(['phfinanzas@asesormasmovil.es'])
      );

-- Permisos de Avoris (AVO)
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET
    a.emails_acceso_trazabilidad = [
        'jmaria.sole@masorange.es',
        'avorisdataventas@asesormasmovil.es',
        'catalina.jariego@masorange.es'],
    a.modificado = CURRENT_TIMESTAMP()
WHERE a.canal = 'AVO'
  AND a.agrupacion_canal = 'No Exclusivo'
  AND a.id_mes >= mes_anterior
  AND (
        a.emails_acceso_trazabilidad IS NULL
        OR TO_JSON_STRING(a.emails_acceso_trazabilidad)
           != TO_JSON_STRING([
               'jmaria.sole@masorange.es',
               'avorisdataventas@asesormasmovil.es',
               'catalina.jariego@masorange.es'
           ])
      );



      --Permisos de Exclusivo
      UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
      SET a.emails_acceso_trazabilidad = ['enrique.ortegaru@masmovil.com']
          , a.modificado = CURRENT_TIMESTAMP()
      WHERE agrupacion_canal ='Exclusivo'
        AND a.id_mes >= mes_anterior
        -- AND a.emails_acceso_trazabilidad != ['enrique.ortegaru@masmovil.com'];
          AND (
        a.emails_acceso_trazabilidad IS NULL
        OR TO_JSON_STRING(a.emails_acceso_trazabilidad)
           != TO_JSON_STRING(['enrique.ortegaru@masmovil.com'])
      );

END