BEGIN

/*******************************
-- UTILIZADO HASTA JUNIO/2026 --
*******************************/

-- CALL `mm-commissions-reporting.COMISIONES.pr_actualizar_visualizacion_externos_jun_26`();

DECLARE mes_actual DATE;
DECLARE mes_anterior INT64;

SET mes_actual = DATE_TRUNC(CURRENT_DATE(), MONTH);
SET mes_anterior =SAFE_CAST(SUBSTRING(CAST((mes_actual-1) AS STRING),1,4)||  SUBSTRING(CAST((mes_actual-1) AS STRING),6,2) AS INT64) ;

--CASO GENERAL
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
SELECT cif, agrupacion_canal, ARRAY_AGG (
    distinct TRIM(email)
) AS emails_acceso_trazabilidad
FROM `mm-commissions-reporting.COMISIONES.v_emails_acceso_trazabilidad` 
WHERE email IS NOT NULL
      AND cif NOT IN ('52887070L')
GROUP BY 1,2
) b
WHERE a.agrupacion_canal = b.agrupacion_canal
AND a.cif = b.cif
AND a.id_mes >= mes_anterior
;

--OPTICO NO EXCLUSIVO - Agrupacion canal + CIF + seller
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
UNNEST([TRIM(usuario_google), TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam), TRIM(mail_distribuidor), TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)]) emails_accesso_trazabilidad
WHERE cif_pdv NOT IN ('52887070L')
      AND comisiona
GROUP BY 1,2,3
) b
WHERE a.agrupacion_canal = b.agrupacion_canal
AND a.cif = b.cif
AND a.seller = b.sfid
AND a.cif NOT IN ('B70186184','B75728329')
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
AND a.id_mes >= mes_anterior
;

--OPTICO NO EXCLUSIVO - Agrupacion canal + CIF + sfid_id
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
SELECT cif_pdv AS cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) AS emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
UNNEST([TRIM(usuario_google), TRIM(mail_manager), TRIM(mail_coordinador), TRIM(mail_specialist), TRIM(mail_gpv), TRIM(mail_kam), TRIM(mail_distribuidor), TRIM(mail_distribuidor_2), TRIM(mail_distribuidor_3), TRIM(mail_distribuidor_4)])emails_accesso_trazabilidad
WHERE cif_pdv NOT IN ('52887070L')
      AND comisiona
GROUP BY 1,2,3
) b
WHERE a.agrupacion_canal = b.agrupacion_canal
AND a.cif = b.cif
AND a.sfid_id = b.sfid
AND a.cif NOT IN ('B70186184','B75728329')
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
AND a.id_mes >= mes_anterior
;

/*
--  Excluir acceso pdv No Exclusivo  --Tecalis por sfid_id
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
WHERE a.agrupacion_canal = b.agrupacion_canal
AND a.cif IN ('B70186184','B75728329')  --CIF de Tecalis
AND a.sfid_id = b.sfid
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
AND a.id_mes >= mes_anterior
;
*/
/*
--Tecalis por seller
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
WHERE a.agrupacion_canal = b.agrupacion_canal
AND a.cif IN ('B70186184','B75728329')
AND a.seller = b.sfid
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
AND a.id_mes >= mes_anterior
;
*/
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
--AND a.emails_acceso_trazabilidad IS NULL
AND a.id_mes >= mes_anterior
;

--Accesos de los Masters
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = b.emails,
modificado = CURRENT_TIMESTAMP()
FROM (
     SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
     FROM (
          SELECT TRANSACCIONES.cif, MASTER.emails
          FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
          INNER JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
                    ON TRANSACCIONES.cif = MASTER.documento
          GROUP BY 1,2
          UNION ALL
          SELECT documento, emails FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`, UNNEST(SPLIT(emails, ',')) AS emails
          )
     GROUP BY 1
     ) b
WHERE a.agrupacion_canal IN ('No Exclusivo')
AND a.cif = b.cif
AND a.id_mes >= mes_anterior
;

--Accesos MP
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = b.emails,
modificado = CURRENT_TIMESTAMP()
FROM (
     SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
     FROM (
          SELECT TRANSACCIONES.cif, emails
          FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
          INNER JOIN `mm-commissions-reporting.GS.ACCESO_TRAZA_MP` MP
                    ON TRANSACCIONES.cif = MP.cif
          GROUP BY 1,2
          UNION ALL
          SELECT cif, emails FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_MP`, UNNEST(SPLIT(emails, ',')) AS emails
          )
     GROUP BY 1
     ) b
WHERE  a.cif = b.cif
AND a.id_mes >= mes_anterior
AND a.canal = 'MP'

;

--Permisos de PH
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = ['phfinanzas@asesormasmovil.es'],
modificado = CURRENT_TIMESTAMP()
WHERE cif = 'B81846206'
AND a.id_mes >= mes_anterior
;

--Permisos de Exclusivo
UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = ['enrique.ortegaru@masmovil.com'],
modificado = CURRENT_TIMESTAMP()
WHERE agrupacion_canal ='Exclusivo'
AND a.id_mes >= mes_anterior
;

END