BEGIN

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.union_emails_acceso_trazabilidad` AS 

      SELECT * EXCEPT(emails)
      FROM `mm-commissions-reporting.GS.b2b_cablemovil_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

      UNION ALL

      select TRAZA.* except(emails), email
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_D2D` TRAZA, unnest(split(emails)) as email
      INNER JOIN (SELECT documento FROM `mm-commissions-reporting.GS.d2d_dealers` WHERE comisiona) DEALERS
            ON TRAZA.cif = DEALERS.documento

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.tlv_do_acceso_trazabilidad`, unnest(split(emails)) as email

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_TLV_OUTBOUND`, unnest(split(emails)) as email

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_TLV_CROSS_SELL`, unnest(split(emails)) as email

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_TLV_NEGOCIOS`, unnest(split(emails)) as email

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.tlv_web_acceso_trazabilidad`, unnest(split(emails)) as email

      UNION ALL

      SELECT * EXCEPT(emails)
      FROM `mm-commissions-reporting.GS.guuk_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email

      UNION ALL

      SELECT * EXCEPT(emails)
      FROM `mm-commissions-reporting.GS.telecable_acceso_trazabilidad`, UNNEST(SPLIT(emails)) AS email
      WHERE agrupacion_canal IS NOT NULL


      /*
      select * except(rank)
      from (
      select 'No Exclusivo', documento, razon_social, email, 1 as rank
      from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`, unnest(split(emails)) as email

      union all

      select * except(emails), 2 as rank
      from `mm-commissions-reporting.COMISIONES.dm_no_exclusivo_emails_acceso_trazabilidad`, unnest(split(emails)) as email
      )


      qualify rank() over (partition by documento, email ORDER BY rank) = 1

      union all*/

      UNION ALL

      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      lower(a.pp_pdvEmail_Hero) as email,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      where pp_pdvEmail_Hero is not null and pp_pdvEmail_Hero LIKE '%@%'
      union all
      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      lower(a.pp_gpvMail) as email,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      where pp_gpvMail is not null and pp_gpvMail LIKE '%@%'
      union all
      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      BDE_CV,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
      on format("%05d", cast(b.cp as int64))=c.cp
      where bde_cv LIKE '%@%'
      union all
      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      DSM_CR,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
      on format("%05d", cast(b.cp as int64))=c.cp
      where dsm_cr LIKE '%@%'
      union all
      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      email_bde,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
      on format("%05d", cast(b.cp as int64))=c.cp
      where email_bde LIKE '%@%'
      union all
      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      email_dsm,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
      on format("%05d", cast(b.cp as int64))=c.cp
      where email_dsm LIKE '%@%'
      union all
      select
      'Etnico' as agrupacion_canal,
      b.CIF,
      b.razon_social,
      pp_distribuidormail,
      from `mm-prepaid-reporting.Analisis_DG.ZZGS_pp_optico` a
      inner join `mm-prepaid-reporting.SANDBOX.dealers_navision` b on a.pp_sfid1 = b.cod_cliente
      left join `mm-prepaid-reporting.MASTER.v_ultima_asignacion_comerciales` c
      on format("%05d", cast(b.cp as int64))=c.cp
      where pp_distribuidormail LIKE '%@%'

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_NETLLAR`, unnest(split(emails)) as email

      union all

      select * except(emails)
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_MARBLANCA`, unnest(split(emails)) as email

      union all
      select * except(emails)
      from `mm-commissions-reporting.GS.ACCESO_TRAZA_POPULOOS` , unnest(split(emails)) as email

      union all
      select * except(emails)
      from `mm-commissions-reporting.GS.b2b_parlem_acceso_trazabilidad`, unnest(split(emails)) as email

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.emails_acceso_trazabilidad` AS 

      SELECT cif, agrupacion_canal, array_agg (
      DISTINCT TRIM(email)
      ) AS emails_acceso_trazabilidad
      FROM `mm-commissions-reporting.TEMP.union_emails_acceso_trazabilidad` 
      WHERE 1=1
            AND email IS NOT NULL
            AND cif NOT IN ('52887070L')
      GROUP BY 1,2
;
END