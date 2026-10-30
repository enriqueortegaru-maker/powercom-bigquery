begin

/***************************************
-- Versión utilizada hasta junio/2026 --
***************************************/

-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_visualizacion_externos_completo_jun_26`();

/* CONSULTA 1 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
select cif, agrupacion_canal, array_agg (
    distinct trim(email)
) as emails_acceso_trazabilidad
from `mm-commissions-reporting.COMISIONES.v_emails_acceso_trazabilidad` 
where email is not null
      and cif not in ('52887070L')
group by 1,2
) b
where a.agrupacion_canal = b.agrupacion_canal
and a.cif = b.cif
;

/* CONSULTA 2 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
select cif_pdv as cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) as emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
UNNEST([trim(usuario_google), trim(mail_manager), trim(mail_coordinador), trim(mail_specialist), trim(mail_gpv), trim(mail_kam), trim(mail_distribuidor), trim(mail_distribuidor_2), trim(mail_distribuidor_3), trim(mail_distribuidor_4)]) emails_accesso_trazabilidad
WHERE cif_pdv not in ('52887070L')
      AND comisiona
GROUP BY 1,2,3
) b
where a.agrupacion_canal = b.agrupacion_canal
and a.cif = b.cif
and a.seller = b.sfid
AND a.cif NOT IN ('B70186184')
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
;

/* CONSULTA 3 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
select cif_pdv as cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) as emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
UNNEST([trim(usuario_google), trim(mail_manager), trim(mail_coordinador), trim(mail_specialist), trim(mail_gpv), trim(mail_kam), trim(mail_distribuidor), trim(mail_distribuidor_2), trim(mail_distribuidor_3), trim(mail_distribuidor_4)])emails_accesso_trazabilidad
WHERE cif_pdv not in ('52887070L')
      AND comisiona
GROUP BY 1,2,3
) b
where a.agrupacion_canal = b.agrupacion_canal
and a.cif = b.cif
and a.sfid_id = b.sfid
AND a.cif NOT IN ('B70186184')
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
;

/* CONSULTA 4 */
/*  Excluir acceso pdv No Exclusivo */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
select cif_pdv as cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) as emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
UNNEST([trim(mail_manager), trim(mail_coordinador), trim(mail_specialist), trim(mail_gpv), trim(mail_kam), trim(mail_distribuidor), trim(mail_distribuidor_2), trim(mail_distribuidor_3), trim(mail_distribuidor_4)])emails_accesso_trazabilidad
WHERE cif_pdv not in ('52887070L')
      AND comisiona
GROUP BY 1,2,3
) b
where a.agrupacion_canal = b.agrupacion_canal
and a.cif IN ('B70186184')
and a.sfid_id = b.sfid
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
;

/* CONSULTA 5 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails_acceso_trazabilidad,
modificado = CURRENT_TIMESTAMP()
FROM (
select cif_pdv as cif, sfid, 'No Exclusivo' AS agrupacion_canal, ARRAY_AGG(DISTINCT emails_accesso_trazabilidad IGNORE NULLS) as emails_acceso_trazabilidad
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`,
UNNEST([trim(mail_manager), trim(mail_coordinador), trim(mail_specialist), trim(mail_gpv), trim(mail_kam), trim(mail_distribuidor), trim(mail_distribuidor_2), trim(mail_distribuidor_3), trim(mail_distribuidor_4)])emails_accesso_trazabilidad
WHERE cif_pdv not in ('52887070L')
      AND comisiona
GROUP BY 1,2,3
) b
where a.agrupacion_canal = b.agrupacion_canal
and a.cif IN ('B70186184')
and a.seller = b.sfid
AND SUBSTR(a.concepto,1,1) NOT IN ('F', 'H', 'G', 'Y')
;

/* CONSULTA 6 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
SET emails_acceso_trazabilidad = CAST(NULL AS ARRAY<STRING>),
modificado = CURRENT_TIMESTAMP()
FROM (
SELECT numero_documento
FROM `mm-commissions-reporting.TEMP.nex_optico_sfid_filter`
WHERE NOT comisiona
QUALIFY ROW_NUMBER() OVER (PARTITION BY numero_documento) = 1
) b
WHERE a.agrupacion_canal = 'No Exclusivo'
and a.cif = b.numero_documento
and a.emails_acceso_trazabilidad IS NULL
;

/* CONSULTA 7 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails,
modificado = CURRENT_TIMESTAMP()
FROM (
     SELECT cif, ARRAY_AGG(DISTINCT emails IGNORE NULLS) emails
     FROM (
          SELECT TRANSACCIONES.cif, emails
          FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES, UNNEST(emails_acceso_trazabilidad) emails
          INNER JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
                    ON TRANSACCIONES.cif = MASTER.documento
          GROUP BY 1,2
          UNION ALL
          SELECT documento, emails FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`, UNNEST(SPLIT(emails, ',')) AS emails
          )
     GROUP BY 1
     ) b
where a.agrupacion_canal IN ('No Exclusivo')
and a.cif = b.cif
;

/* CONSULTA 8 */
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = b.emails,
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
where a.cif = b.cif
;


update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = ['phfinanzas@asesormasmovil.es'],
modificado = CURRENT_TIMESTAMP()
where cif = 'B81846206'
;
update `mm-commissions-reporting.COMISIONES.transacciones` a
set emails_acceso_trazabilidad = ['enrique.ortegaru@masmovil.com'],
modificado = CURRENT_TIMESTAMP()
where agrupacion_canal ='Exclusivo'
;



end