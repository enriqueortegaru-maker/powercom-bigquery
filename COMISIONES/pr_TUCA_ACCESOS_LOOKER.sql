BEGIN

--CALL`mm-commissions-reporting.COMISIONES.pr_TUCA_ACCESOS_LOOKER`()

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TUCA_ACCESOS_LOOKER` AS

  -- Agrupamos los sfid por email y los concatenamos en un solo campo
WITH accesos AS (
  SELECT DISTINCT 
    acceso_looker,
    id_comisionista
  FROM `mm-commissions-reporting.GS.DEALERS_TUCA`,
  UNNEST(SPLIT(REGEXP_REPLACE(acceso_looker, r', ', ','))) AS acceso_looker
  WHERE 1=1
    AND acceso_looker IS NOT NULL 
    AND id_comisionista IS NOT NULL
    
  UNION DISTINCT

  SELECT DISTINCT 
    UPPER(acceso_looker) AS acceso_looker,
    id_comisionista
  FROM `mm-commissions-reporting.GS.DEALERS_TUCA`,
  UNNEST(SPLIT(REGEXP_REPLACE(acceso_looker, r', ', ','))) AS acceso_looker
  WHERE 1=1
    AND acceso_looker IS NOT NULL 
    AND id_comisionista IS NOT NULL

  UNION DISTINCT

  SELECT DISTINCT 
    CASE
      WHEN acceso_looker LIKE '%@asesormasmovil.es' 
        THEN CONCAT(UPPER(REGEXP_EXTRACT(acceso_looker, r'^[a-zA-Z0-9_.+-]+')),SUBSTR(acceso_looker,-18)) 
      WHEN acceso_looker LIKE '%@masmovil.com' 
        THEN CONCAT(UPPER(REGEXP_EXTRACT(acceso_looker, r'^[a-zA-Z0-9_.+-]+')),SUBSTR(acceso_looker,-13))  
      WHEN acceso_looker LIKE '%@asesormasorange.es' 
        THEN CONCAT(UPPER(REGEXP_EXTRACT(acceso_looker, r'^[a-zA-Z0-9_.+-]+')),SUBSTR(acceso_looker,-19))  
    END AS acceso_looker,  
    id_comisionista
  FROM `mm-commissions-reporting.GS.DEALERS_TUCA`,
  UNNEST(SPLIT(REGEXP_REPLACE(acceso_looker, r', ', ','))) AS acceso_looker
  WHERE 1=1
    AND acceso_looker IS NOT NULL 
    AND id_comisionista IS NOT NULL
  
  UNION DISTINCT 

  SELECT DISTINCT 
    acceso_looker,
    id_comisionista
  FROM `mm-commissions-reporting.GS.DEALERS_TUCA`,
  UNNEST(SPLIT(REGEXP_REPLACE(acceso_looker_vista_general, r', ', ','))) AS acceso_looker
  WHERE 1=1
    AND acceso_looker_vista_general IS NOT NULL 
    AND id_comisionista IS NOT NULL
    
  UNION DISTINCT

  SELECT DISTINCT 
    UPPER(acceso_looker) AS acceso_looker,
    id_comisionista
  FROM `mm-commissions-reporting.GS.DEALERS_TUCA`,
  UNNEST(SPLIT(REGEXP_REPLACE(acceso_looker_vista_general, r', ', ','))) AS acceso_looker
  WHERE 1=1
    AND acceso_looker_vista_general IS NOT NULL 
    AND id_comisionista IS NOT NULL

  UNION DISTINCT

  SELECT DISTINCT 
    CASE
      WHEN acceso_looker LIKE '%@asesormasmovil.es' 
        THEN CONCAT(UPPER(REGEXP_EXTRACT(acceso_looker, r'^[a-zA-Z0-9_.+-]+')),SUBSTR(acceso_looker,-18))  
      WHEN acceso_looker LIKE '%@masmovil.com' 
        THEN CONCAT(UPPER(REGEXP_EXTRACT(acceso_looker, r'^[a-zA-Z0-9_.+-]+')),SUBSTR(acceso_looker,-13))  
      WHEN acceso_looker LIKE '%@asesormasorange.es' 
        THEN CONCAT(UPPER(REGEXP_EXTRACT(acceso_looker, r'^[a-zA-Z0-9_.+-]+')),SUBSTR(acceso_looker,-19))
    END AS acceso_looker,  
    id_comisionista
  FROM `mm-commissions-reporting.GS.DEALERS_TUCA`,
  UNNEST(SPLIT(REGEXP_REPLACE(acceso_looker_vista_general, r', ', ','))) AS acceso_looker
  WHERE 1=1
    AND acceso_looker_vista_general IS NOT NULL 
    AND id_comisionista IS NOT NULL
  
  
)

  SELECT DISTINCT
    acceso_looker,
    STRING_AGG(DISTINCT CONCAT('_',id_comisionista,'_'), ';') AS id_comisionista_filter
  FROM accesos
  WHERE 1=1
    AND acceso_looker IS NOT NULL 
    AND id_comisionista IS NOT NULL
  GROUP BY acceso_looker
  ;

  END