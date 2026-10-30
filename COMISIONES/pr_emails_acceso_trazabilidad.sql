BEGIN

--CALL `mm-commissions-reporting.COMISIONES.pr_emails_acceso_trazabilidad`();

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.emails_acceso_trazabilidad`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.b2b_cablemovil_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT TRAZA.* EXCEPT(emails), email
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_D2D` TRAZA, UNNEST(SPLIT(emails)) AS email
    INNER JOIN (SELECT documento FROM `mm-commissions-reporting.GS.d2d_dealers` WHERE comisiona) DEALERS
              ON TRAZA.cif = DEALERS.documento

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.tlv_do_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_TLV_OUTBOUND`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_TLV_CROSS_SELL`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_TLV_NEGOCIOS`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.tlv_web_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.guuk_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.telecable_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email
    WHERE agrupacion_canal IS NOT NULL





    /*
    SELECT * EXCEPT(rank)
    FROM (
    SELECT 'No Exclusivo', documento, razon_social, email, 1 AS rank
    FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails), 2 AS rank
    FROM `mm-commissions-reporting.COMISIONES.dm_no_exclusivo_emails_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email
    )


    qualify rank() over (partition by documento, email ORDER BY rank) = 1

    UNION ALL*/

    UNION ALL

    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    LOWER(a.pp_pdvEmail_Hero) AS email,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    WHERE pp_pdvEmail_Hero IS NOT NULL AND pp_pdvEmail_Hero LIKE '%@%'
    UNION ALL
    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    LOWER(a.pp_gpvMail) AS email,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    WHERE pp_gpvMail IS NOT NULL AND pp_gpvMail LIKE '%@%'
    UNION ALL
    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    BDE_CV,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
    ON format("%05d", cast(b.cp AS int64))=c.cp
    WHERE bde_cv LIKE '%@%'
    UNION ALL
    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    DSM_CR,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
    ON format("%05d", cast(b.cp AS int64))=c.cp
    WHERE dsm_cr LIKE '%@%'
    UNION ALL
    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    email_bde,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
    ON format("%05d", cast(b.cp AS int64))=c.cp
    WHERE email_bde LIKE '%@%'
    UNION ALL
    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    email_dsm,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
    ON format("%05d", cast(b.cp AS int64))=c.cp
    WHERE email_dsm LIKE '%@%'
    UNION ALL
    SELECT
    'Etnico' AS agrupacion_canal,
    b.CIF,
    b.razon_social,
    pp_distribuidormail,
    FROM `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
    INNER JOIN `mm-prepaid-reporting.SANDBOX.dealers_navision` b ON a.pp_sfid1 = b.cod_cliente
    left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
    ON format("%05d", cast(b.cp AS int64))=c.cp
    WHERE pp_distribuidormail LIKE '%@%'

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_NETLLAR`, UNNEST(SPLIT(emails)) AS email

    UNION ALL

    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_MARBLANCA`, UNNEST(SPLIT(emails)) AS email

    UNION ALL
    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.ACCESO_TRAZA_POPULOOS` , UNNEST(SPLIT(emails)) AS email

    UNION ALL
    SELECT * EXCEPT(emails)
    FROM `mm-commissions-reporting.GS.b2b_parlem_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

  ;

END