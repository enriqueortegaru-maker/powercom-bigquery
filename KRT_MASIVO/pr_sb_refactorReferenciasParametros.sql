BEGIN
  DECLARE v_scope ARRAY<STRING> DEFAULT [
    'pr_sb_creaTablaComisiones',
    'pr_fl_calcula_rappel',
    'f_vt_comisiones_en_proceso',
    'f_vt_audit_catalogos_no_parametrizados'
  ];
  DECLARE v_ddls ARRAY<STRING>;
  DECLARE i INT64 DEFAULT 0;

  SET v_ddls = (
    SELECT ARRAY_AGG(
      REPLACE(
        REPLACE(
          CASE
            WHEN STARTS_WITH(ddl, 'CREATE TABLE FUNCTION')
              THEN 'CREATE OR REPLACE TABLE FUNCTION' || SUBSTR(ddl, LENGTH('CREATE TABLE FUNCTION') + 1)
            WHEN STARTS_WITH(ddl, 'CREATE PROCEDURE')
              THEN 'CREATE OR REPLACE PROCEDURE'      || SUBSTR(ddl, LENGTH('CREATE PROCEDURE') + 1)
            WHEN STARTS_WITH(ddl, 'CREATE FUNCTION')
              THEN 'CREATE OR REPLACE FUNCTION'       || SUBSTR(ddl, LENGTH('CREATE FUNCTION') + 1)
            ELSE ddl
          END,
          '`mm-commissions-reporting.GS.PARAM_KRT_MAS',
          '`mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS'),
        '`mm-commissions-reporting`.GS.PARAM_KRT_MAS',
        '`mm-commissions-reporting`.KRT_MASIVO.PARAM_KRT_MAS')
      ORDER BY routine_name)
    FROM `mm-commissions-reporting.KRT_MASIVO.INFORMATION_SCHEMA.ROUTINES`
    WHERE routine_name IN UNNEST(v_scope)
      AND CONTAINS_SUBSTR(routine_definition, 'PARAM_KRT_MAS')
  );

  WHILE i < ARRAY_LENGTH(v_ddls) DO
    EXECUTE IMMEDIATE v_ddls[OFFSET(i)];
    SET i = i + 1;
  END WHILE;
END