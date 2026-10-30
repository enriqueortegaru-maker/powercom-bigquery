BEGIN

  DECLARE vStrFlujo string;
  DECLARE vStrDataSet string;  
  DECLARE vStrInformationSchemaPath string;
  DECLARE vQUERY_STR string;  
  DECLARE vSpecific_catalog, vSpecific_schema, vSpecific_name STRING;
  ---LOCAL
  --DECLARE vTipo string; DECLARE vfl int64;SET vTipo="CAPTACION"; SET vfl=20;
  SET vSpecific_catalog="mm-commissions-reporting";
  SET vSpecific_schema=(SELECT CASE when UPPER(TRIM(VTIPO))="CAPTACION" THEN "KRT_CAPTACION" when UPPER(TRIM(VTIPO))="CARTERA" THEN "KRT_CARTERA" END);
  SET vSpecific_name=( SELECT CASE when UPPER(TRIM(VTIPO))="CAPTACION" THEN concat("prex_flujoDeCaptacionv",CAST(vfl AS INT64)) 
              when UPPER(TRIM(VTIPO))="CARTERA" THEN concat("pr_flujoDeCartera",CAST(vfl AS INT64)) 
         END);
  SET vStrInformationSchemaPath=(SELECT concat("`mm-commissions-reporting.KRT_",UPPER(TRIM(vTIPO)),'.INFORMATION_SCHEMA.ROUTINES`') as informationSchemaPath);  


  SELECT vSpecific_catalog, vSpecific_schema, vSpecific_name,vStrInformationSchemaPath;
  --SET VQUERY_STR=Concat("SELECT ddl FROM ",vStrInformationSchemaPath, " WHERE routine_type='PROCEDURE' and specific_catalog=",vSpecific_catalog," and Specific_schema=",vSpecific_schema, " and Specific_name=",vSpecific_name ); 
  --EXECUTE INMEDIATE VQUERY_STR;

  If contains_substr(vSpecific_schema,"CAPTACION") THEN 

    SELECT
      routine_type,
      routine_name,
      routine_definition,
      REGEXP_EXTRACT_ALL(
        routine_definition,
        --r'(?m)^[ \t]*call.*$'
        r'(?m)^\s*(call.*)$'
      ) AS called_procedures
    FROM
    `mm-commissions-reporting.KRT_CAPTACION.INFORMATION_SCHEMA.ROUTINES`
    WHERE
      routine_type = 'PROCEDURE'
      AND routine_name = vSpecific_name
      AND routine_definition IS NOT NULL;
  

  elseif contains_substr(vSpecific_schema,"CARTERA") THEN 


    SELECT
      routime_type,
      routine_name,
      routine_definition,
      REGEXP_EXTRACT_ALL(
        routine_definition,
        --r'(?m)^[ \t]*call.*$'
        r'(?m)^\s*(call.*)$'
      ) AS called_procedures
    FROM
    `mm-commissions-reporting.KRT_CARTERA.INFORMATION_SCHEMA.ROUTINES`
    WHERE
      routine_type = 'PROCEDURE'
      AND routine_name = vSpecific_name
      AND routine_definition IS NOT NULL;



  end IF; 

END