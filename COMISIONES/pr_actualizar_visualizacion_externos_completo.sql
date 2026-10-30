BEGIN

--CALL `mm-commissions-reporting.COMISIONES.pr_actualizar_visualizacion_externos_completo`();

/*********************************************************************
-- PARA CAMBIAR pr_actualizar_visualizacion_externos_completo       --
-- SUSTITUYE A pr_actualizar_visualizacion_externos_completo_jun_26 --
*********************************************************************/

CALL `mm-commissions-reporting.COMISIONES.pr_emails_acceso_trazabilidad`(); --USAR EN CUALQUIER CASO, ES MAS RÁPIDO QUE LA VISTA

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

  --Realizamos cambios


  --CAMBIO 1 --v_emails_acceso_trazabilidad
  -- UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  -- SET
  --     tra.emails_acceso_trazabilidad = b.emails_acceso_trazabilidad
  --   , tra.modificado = CURRENT_TIMESTAMP()
  -- FROM (
  --   SELECT * FROM `mm-commissions-reporting.TEMP.cambios_acceso_trazabilidad`  --Comprobar que no sean iguales para no actualizar lo que no hace falta
  -- ) b
  -- WHERE tra.agrupacion_canal = b.agrupacion_canal
  --   AND tra.cif = b.cif;

  -- actualizo la query porque no esta compelta 14/09/2026
   UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  SET
      tra.emails_acceso_trazabilidad = b.emails_acceso_trazabilidad
    , tra.modificado = CURRENT_TIMESTAMP()
  FROM (
    SELECT  cif, agrupacion_canal, array_agg (
    distinct trim(email)
) as emails_acceso_trazabilidad FROM `mm-commissions-reporting.TEMP.cambios_acceso_trazabilidad`
group by all  --Comprobar que no sean iguales para no actualizar lo que no hace falta
  ) b
  WHERE tra.agrupacion_canal = b.agrupacion_canal
    AND tra.cif = b.cif ;

  --CAMBIO 2 --nex_optico_sfid_filter 'No Exclusivo'
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  SET 
      tra.emails_acceso_trazabilidad = b.emails_acceso_trazabilidad
    , tra.modificado = CURRENT_TIMESTAMP()
  FROM (
    SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
      UNNEST([TRIM(usuario_google), TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam)
            , TRIM(mail_distribuidor), TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)]
      ) emails_accesso_trazabilidad
    WHERE cif_pdv NOT IN ('52887070L')
      AND comisiona
    GROUP BY 1,2,3
  ) b
  WHERE tra.agrupacion_canal = b.agrupacion_canal
    AND tra.cif = b.cif
    AND tra.seller = b.sfid
--    AND tra.cif NOT IN ('B70186184','B75728329')  --CIF de TECALIS CONSULTA 4 LA INCLUIMOS QUITANDO ESTE FILTRO
    AND SUBSTR(tra.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
    AND TO_JSON_STRING(tra.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad);  --Comprobar que no sean iguales para no actualizar lo que no hace falta


  --CAMBIO 3 --REPETIDO DE CAMBIO 2 EXCEPTO QUE FILTRAMOS POR SFID_ID Y NO POR SELLER.
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  SET 
      tra.emails_acceso_trazabilidad = b.emails_acceso_trazabilidad
    , tra.modificado = CURRENT_TIMESTAMP()
  FROM (
    SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
      UNNEST([TRIM(usuario_google), TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam)
            , TRIM(mail_distribuidor), TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)]
      ) emails_accesso_trazabilidad
    WHERE cif_pdv NOT IN ('52887070L')
      AND comisiona
    GROUP BY 1,2,3
  ) b
  WHERE tra.agrupacion_canal = b.agrupacion_canal
    AND tra.cif = b.cif
    AND tra.sfid_id = b.sfid
--    AND tra.cif NOT IN ('B70186184','B75728329')  --CIF de TECALIS CONSULTA 5 LA INCLUIMOS QUITANDO ESTE FILTRO
    AND SUBSTR(tra.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
    AND TO_JSON_STRING(tra.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad);  --Comprobar que no sean iguales para no actualizar lo que no hace falta

  --CAMBIO 4
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
  SET emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
  modificado = CURRENT_TIMESTAMP()
  FROM (
  SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
  FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
  UNNEST([TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam), TRIM(mail_distribuidor), TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)])emails_accesso_trazabilidad
  WHERE cif_pdv NOT IN ('52887070L')
        AND comisiona
  GROUP BY 1,2,3
  ) b
  where a.agrupacion_canal = b.agrupacion_canal
  and a.cif IN ('B70186184')
  and a.sfid_id = b.sfid
  AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
  AND TO_JSON_STRING(a.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad);  --Comprobar que no sean iguales para no actualizar lo que no hace falta

  --CAMBIO 5
  -- UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  -- SET emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
  -- modificado = CURRENT_TIMESTAMP()
  -- FROM (
  --   SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
  --   FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
  --   UNNEST([TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam), TRIM(mail_distribuidor), TRIM(mail_distribuidor_2)
  --         , TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)])emails_accesso_trazabilidad
  --   WHERE cif_pdv NOT IN ('52887070L')
  --         AND comisiona
  --   GROUP BY 1,2,3
  -- ) b
  -- where tra.agrupacion_canal = b.agrupacion_canal
  -- and tra.cif IN ('B70186184')
  -- and tra.seller = b.sfid
  -- AND SUBSTR(tra.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
  -- AND tra.emails_acceso_trazabilidad IS NULL OR TO_JSON_STRING(tra.emails_acceso_trazabilidad) != TO_JSON_STRING(b.emails_acceso_trazabilidad);  --Comprobar que no sean iguales para no actualizar lo que no hace falta
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
SET
  emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
  modificado = CURRENT_TIMESTAMP()
FROM (

  SELECT
    cif_pdv AS cif,
    sfid,
    'No Exclusivo' AS agrupacion_canal,
    ARRAY_AGG(
      DISTINCT emails_accesso_trazabilidad
      IGNORE NULLS
    ) AS emails_acceso_trazabilidad
  FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
  UNNEST([
    TRIM(mail_manager),
    TRIM(mail_coordinador),
    TRIM(mail_specialist),
    TRIM(mail_gpv),
    TRIM(mail_kam),
    TRIM(mail_distribuidor),
    TRIM(mail_distribuidor_2),
    TRIM(mail_distribuidor_3),
    TRIM(mail_distribuidor_4)
  ]) emails_accesso_trazabilidad
  WHERE cif_pdv != '52887070L'
    AND comisiona
  GROUP BY
    cif_pdv,
    sfid

) b
WHERE tra.agrupacion_canal = b.agrupacion_canal
  AND tra.cif = b.cif
  AND tra.seller = b.sfid
  AND tra.cif = 'B70186184'                     -- quitar cuando valides
  AND SUBSTR(tra.concepto, 1, 1) NOT IN ('F','H','G','Y')
  AND (
        tra.emails_acceso_trazabilidad IS NULL
        OR TO_JSON_STRING(tra.emails_acceso_trazabilidad)
           != TO_JSON_STRING(b.emails_acceso_trazabilidad)
      );
  

  --CAMBIO 6
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
  SET   emails_acceso_trazabilidad = CAST(NULL AS ARRAY<STRING>)
      , modificado = CURRENT_TIMESTAMP()
  FROM (
    SELECT numero_documento
    FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`
    WHERE NOT comisiona
    QUALIFY ROW_NUMBER() OVER (PARTITION BY numero_documento) = 1
  ) b
  WHERE a.agrupacion_canal = 'No Exclusivo'
    AND a.cif = b.numero_documento
    AND a.emails_acceso_trazabilidad IS NOT NULL;  --CAMBIO PARA QUE ACTUALICE LOS QUE NO SON NULL Y LO NECESITEN COMO NULL

  --CAMBIO 7
  -- UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  -- SET emails_acceso_trazabilidad = b.emails,
  -- modificado = CURRENT_TIMESTAMP()
  -- FROM (
  --     SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
  --     FROM (
  --           SELECT TRANSACCIONES.cif, emails
  --           FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
  --           INNER JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
  --                     ON TRANSACCIONES.cif = MASTER.documento
  --           GROUP BY 1,2
  --           UNION ALL
  --           SELECT documento, emails FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`, UNNEST(SPLIT(emails, ',')) AS emails
  --           )
  --     GROUP BY 1
  --     ) b
  -- WHERE tra.agrupacion_canal IN ('No Exclusivo')
  --   AND tra.cif = b.cif
  --   AND tra.email_transacciones IS NULL OR TO_JSON_STRING(tra.email_transacciones) != TO_JSON_STRING(b.email);  --Comprobar que no sean iguales para no actualizar lo que no hace falta

    UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
SET
  emails_acceso_trazabilidad = b.emails,
  modificado = CURRENT_TIMESTAMP()
FROM (
    SELECT
        cif,
        ARRAY_AGG(DISTINCT emails IGNORE NULLS) AS emails
    FROM (
        SELECT
            t.cif,
            emails
        FROM `mm-commissions-reporting.COMISIONES.transacciones` t
        CROSS JOIN UNNEST(t.emails_acceso_trazabilidad) emails
        INNER JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` m
            ON t.cif = m.documento
        GROUP BY 1,2

        UNION ALL

        SELECT
            documento AS cif,
            emails
        FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`
        CROSS JOIN UNNEST(SPLIT(emails, ',')) emails
    )
    GROUP BY cif
) b
WHERE tra.agrupacion_canal = 'No Exclusivo'
  AND tra.cif = b.cif
  AND (
        tra.emails_acceso_trazabilidad IS NULL
        OR TO_JSON_STRING(tra.emails_acceso_trazabilidad)
           != TO_JSON_STRING(b.emails)
      );

  --CAMBIO 8 --ACCESO_TRAZA_MP
  -- UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
  -- SET 
  --     tra.emails_acceso_trazabilidad = b.emails
  --   , tra.modificado = CURRENT_TIMESTAMP()
  -- FROM (
  --     SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
  --     FROM (
  --           SELECT TRANSACCIONES.cif, emails
  --           FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
  --           INNER JOIN `mm-commissions-reporting.GS.ACCESO_TRAZA_MP` MP
  --                     ON TRANSACCIONES.cif = MP.cif
  --           GROUP BY 1,2
  --           UNION ALL
  --           SELECT cif, emails FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_MP`, UNNEST(SPLIT(emails, ',')) AS emails
  --           )
  --     GROUP BY 1
  --     ) b
  -- WHERE tra.cif = b.cif
  --   AND TO_JSON_STRING(emails_acceso_trazabilidad) != TO_JSON_STRING(email);
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` tra
SET
    emails_acceso_trazabilidad = b.emails,
    modificado = CURRENT_TIMESTAMP()
FROM (
    SELECT
        cif,
        ARRAY_AGG(DISTINCT emails IGNORE NULLS) AS emails
    FROM (
        SELECT
            t.cif,
            emails
        FROM `mm-commissions-reporting.COMISIONES.transacciones` t
        CROSS JOIN UNNEST(t.emails_acceso_trazabilidad) emails
        INNER JOIN `mm-commissions-reporting.GS.ACCESO_TRAZA_MP` mp
            ON t.cif = mp.cif
        GROUP BY 1,2

        UNION ALL

        SELECT
            cif,
            emails
        FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_MP`
        CROSS JOIN UNNEST(SPLIT(emails, ',')) emails
    )
    GROUP BY cif
) b
WHERE tra.cif = b.cif
  AND (
        tra.emails_acceso_trazabilidad IS NULL
        OR TO_JSON_STRING(tra.emails_acceso_trazabilidad)
           != TO_JSON_STRING(b.emails)
      );

  --CAMBIO 9 --phfinanzas@asesormasmovil
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
  SET 
      emails_acceso_trazabilidad = ['phfinanzas@asesormasmovil.es']
    , modificado = CURRENT_TIMESTAMP()
  WHERE cif = 'B81846206'
    AND TO_JSON_STRING(emails_acceso_trazabilidad) != TO_JSON_STRING(['phfinanzas@asesormasmovil.es']);  --Comprobar que no sean iguales para no actualizar lo que no hace falta

  --CAMBIO 10 --Exclusivo --enrique.ortegaru@masmovil.com
  UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
  SET 
      emails_acceso_trazabilidad = ['enrique.ortegaru@masmovil.com']
    , modificado = CURRENT_TIMESTAMP()
  WHERE agrupacion_canal = 'Exclusivo'
    AND TO_JSON_STRING(emails_acceso_trazabilidad) != TO_JSON_STRING(['enrique.ortegaru@masmovil.com']);  --Comprobar que no sean iguales para no actualizar lo que no hace falta

END