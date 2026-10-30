BEGIN

--CALL `mm-commissions-reporting.CONTROL.pr_validacion_emails_acceso`();


/*
  --01.-CONTROL
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_CONTROL_ACCESO_DS`
  (
    email STRING
  )
  OPTIONS(
    sheet_range="ACCESO_DS",
    skip_leading_rows=2,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1cg2Xle61gMY_jXo0lOPi-v0fBnO3xp43LSsawJvuIx0/edit?gid=227978329#gid=227978329"]
  );

  --02.-B2B_CABLEMOVIL
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Cablemovil_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO_TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/15qi-HYATIXAOntopClrvYeRlR45zX3qIxVnnpxbzt_I/edit?gid=979994927#gid=979994927"]
  );

  --03.-B2B_HITS
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Hits_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1YGzWy14piPGjNZE3jHFGyFAOFsXEJ50mzHcngPo18uE/edit?gid=979994927#gid=979994927"]
  );

  --04.-B2B_JOI
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Joi_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1iy4kJQzptUjwO-ekn0XC9BPf-ChfWzNE5U-U2oT8Vdo/edit?gid=979994927#gid=979994927"]
  );

  --05.-B2B_MARBLANCA
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Marblanca_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1juMTvcT23QDamIWSu3u4-LTcuFXaTDLzl11oFXhkRkQ/edit?gid=979994927#gid=979994927"]
  );

  --06.-B2B_NASH
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Nash_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1T1lYevUZ9mUPGbTWvXTZicD8oMVnphxGe0FK_LeM6zw/edit?gid=979994927#gid=979994927"]
  );

  --07.-B2B_NETLLAR
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Netllar_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/18oDxCX3c1LjQJzkhgRGUrcuj8fYsjp0xBd7Y9yItuoo/edit?gid=979994927#gid=979994927"]
  );

   --08.-B2B_PARLEM
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Parlem_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO_TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1ZQS0O-hlcJV6Y8MrWn0XFE4z8PKaDwt7ZYFb2PKtnO4/edit?gid=979994927#gid=979994927"]
  );

   --09.-B2B_POPULOOS
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Populoos_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO_TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/12FMPXN21dr0WUczXuitr0cariT4XT6EGFk3iFiCJUA0/edit?gid=979994927#gid=979994927"]
  );

   --10.-B2B_SWENO
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_B2B_Sweno_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1EqTg0A3IQK3xmCXvgKSLUMgJv7-20nD_LyExGqoEYb0/edit?gid=979994927#gid=979994927"]
  );

   --11.-D2D
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_D2D_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1D9ovmWiqBKttE0NPkeMlk4gTO2FPRRW-mr6dAqATCqo/edit?gid=599002150#gid=599002150"]
  );

   --11.-EXCLUSIVO MP
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_Exclusivo_MP_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD MP",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1V0EUgZwCpDSreEf0rKbbJxyHQill9t2vELhm-UXDZfg/edit?gid=753901990#gid=753901990"]
  );

   --12.-TLV CROSS SELL
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_TLV_Cross_Sell_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/18aU1-5LNW4ttpFF5QzKOWxYPQan0o3UksOAvzCkUKRw/edit?gid=1834626617#gid=1834626617"]
  );

   --13.-TLV DO
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_TLV_DO_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO_TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1s_avfLQjmW2t5n6X65cPK9wJGRqBbCVx-pCIEEFg6Bs/edit?gid=419583224#gid=419583224"]
  );

   --14.-TLV NEGOCIOS
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_TLV_Negocios_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1_iwHxWNfjWSm_D6EvqnB9Lu78bwX2MOfo3fuOgvxG9Y/edit?gid=714987403#gid=714987403"]
  );

   --15.-TLV OUTBOUND
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_TLV_Outbound_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1GVqX8lyFB5LbjemWw-3qoaBItYcdq6r38ojpIshfvsQ/edit?gid=979994927#gid=979994927"]
  );

   --16.-TLV WEB
  CREATE OR REPLACE EXTERNAL TABLE `mm-commissions-reporting.TEMP.gs_TLV_Web_ACCESO_TRAZA`
  (
    agrupacion_canal STRING,
    cif STRING,
    vendor_name STRING,
    emails STRING
  )
  OPTIONS(
    sheet_range="ACCESO_TRAZABILIDAD",
    skip_leading_rows=1,
    FORMAT="GOOGLE_SHEETS",
    uris=["https://docs.google.com/spreadsheets/d/1E9w_mDkMfsyWw9Rzv5Wnbk1vCa1v0p2A9fk00o7CnC0/edit?gid=1583650741#gid=1583650741"]
  );
*/

  --RESULTADO
  SELECT *
  FROM (
    SELECT CONTROL.email AS email_CONTROL
         , email_b2b_cablemovil.email AS email_B2B_Cablemovil
         , email_b2b_hits.email AS email_B2B_Hits
         , email_b2b_joi.email AS email_B2B_Joi
         , email_b2b_marblanca.email AS email_B2B_Marblanca
         , email_b2b_nash.email AS email_B2B_Nash
         , email_b2b_netllar.email AS email_B2B_Netllar
         , email_b2b_parlem.email AS email_B2B_Parlem
         , email_b2b_populoos.email AS email_B2B_Populoos
         , email_b2b_sweno.email AS email_B2B_Sweno
         , email_D2D.email AS email_D2D
         , email_Exc_MP.email AS email_Exc_MP
         , email_TLV_Cross_Sell.email AS email_TLV_Cross_Sell
         , email_TLV_DO.email AS email_TLV_DO
         , email_TLV_Negocios.email AS email_TLV_Negocios
         , email_TLV_Outbound.email AS email_TLV_Outbound
         , email_TLV_Web.email AS email_TLV_Web

    FROM `mm-commissions-reporting.TEMP.gs_CONTROL_ACCESO_DS` AS CONTROL
      
      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Cablemovil_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_cablemovil
      ON  CONTROL.email = email_b2b_cablemovil.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Hits_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_hits
      ON  CONTROL.email = email_b2b_hits.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Joi_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_joi
      ON  CONTROL.email = email_b2b_joi.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Marblanca_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_marblanca
      ON  CONTROL.email = email_b2b_marblanca.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Nash_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_nash
      ON  CONTROL.email = email_b2b_nash.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Netllar_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_netllar
      ON  CONTROL.email = email_b2b_netllar.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Parlem_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_parlem
      ON  CONTROL.email = email_b2b_parlem.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Populoos_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_populoos
      ON  CONTROL.email = email_b2b_populoos.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_B2B_Sweno_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_b2b_sweno
      ON  CONTROL.email = email_b2b_sweno.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_D2D_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_D2D
      ON  CONTROL.email = email_D2D.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_Exclusivo_MP_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_Exc_MP
      ON  CONTROL.email = email_Exc_MP.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_TLV_Cross_Sell_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_TLV_Cross_Sell
      ON  CONTROL.email = email_TLV_Cross_Sell.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_TLV_DO_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_TLV_DO
      ON  CONTROL.email = email_TLV_DO.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_TLV_Negocios_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_TLV_Negocios
      ON  CONTROL.email = email_TLV_Negocios.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_TLV_Outbound_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_TLV_Outbound
      ON  CONTROL.email = email_TLV_Outbound.email

      LEFT JOIN (
        SELECT DISTINCT email
        FROM `mm-commissions-reporting.TEMP.gs_TLV_Web_ACCESO_TRAZA`, UNNEST(SPLIT(emails, ',')) AS email
      ) email_TLV_Web
      ON  CONTROL.email = email_TLV_Web.email

--    WHERE CONTROL.email LIKE '%renata%'
  )
  WHERE email_B2B_Cablemovil IS NOT NULL
    OR email_B2B_Hits IS NOT NULL
    OR email_B2B_Joi IS NOT NULL
    OR email_B2B_Marblanca IS NOT NULL
    OR email_B2B_Nash IS NOT NULL
    OR email_B2B_Netllar IS NOT NULL
    OR email_B2B_Parlem IS NOT NULL
    OR email_B2B_Populoos IS NOT NULL
    OR email_B2B_Sweno IS NOT NULL
    OR email_D2D IS NOT NULL
    OR email_Exc_MP IS NOT NULL
    OR email_TLV_Cross_Sell IS NOT NULL
    OR email_TLV_DO IS NOT NULL
    OR email_TLV_Negocios IS NOT NULL
    OR email_TLV_Outbound IS NOT NULL
    OR email_TLV_Web IS NOT NULL
  ORDER BY 2 DESC;


END