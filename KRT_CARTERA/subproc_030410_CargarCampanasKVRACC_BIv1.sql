BEGIN

    declare  DESDE_DT,HASTA_DT,DESDE_3M_DT,DESDE_6M_DT  date;    
    --LOCAL
    --DECLARE DESDE, HASTA INT64; SET DESDE=20240901;SET HASTA=20240930;    
    set HASTA_DT = parse_date ('%Y%m%d', cast ( HASTA as string) );
    set DESDE_DT = parse_date ('%Y%m%d', cast ( DESDE as string) );
    set DESDE_3M_DT=DATE_SUB(DESDE_DT, INTERVAL 3 MONTH);
    set DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);


  --- PASO 1: CREO LOG DE CAMPANAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI` AS
    SELECT
      DISTINCT brand AS marca_ds,
      CAST(NULL AS STRING) AS campana_id,
      SAFE_CAST(customer_id AS INT64) as CA_CUSTOMER_ID,
      'FICTICIO' as REALIZADO_POR,
      CONCAT(TRIM(subcampaign),
             " ",
             TRIM(channel),
             " MASIVO ",
             TRIM(brand)
        ) AS CA_DESC,
/*      CASE
        WHEN EXTRACT(DAY FROM target_date)<22 THEN SAFE_CAST(anomes AS numeric)
        ELSE EXTRACT(YEAR FROM DATE_ADD(target_date,INTERVAL 1 MONTH))*100+EXTRACT(MONTH FROM DATE_ADD(target_date,INTERVAL 1 MONTH) )  
      END  AS periodo,
      CASE
        WHEN platform LIKE 'V3%' THEN 'V3'
        WHEN platform LIKE '%IBERMATICA%' THEN 'IBERMATICA'
        ELSE 'OTROS'
      END      AS proveedor*/
    FROM
      bi-data-science-pilots.ZZ_SHARED_DATA.Datos_campana_CVM
    WHERE
      (contains_substr(brand,'VIRGIN') or contains_substr(brand,'RACC')  or contains_substr(brand,'EUSKALTEL'))
      /*
      AND ( (campaign IN ('TERMINALES','UPGRADE','XSELL') AND TARGET_DATE>=DESDE_3M_DT)
            ---OR ( subcampaign LIKE '%Migraciones Huella Eficiente%' AND target_date>=DESDE_6M_DT)
      )*/
      AND TARGET_DATE>=DESDE_3M_DT;


    --- PASO 2: INSERTO REGISTROS EN TABLA CAMPANA

    IF (select coalesce(count(*)) FROM `mm-commissions-reporting.KRT_CARTERA.CAMPANA` where marca_ds in("EUSKALTEL","RACC","VIRGIN")) =0 
        THEN  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI_INCR` AS
              SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI`;
    ELSE 
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI_INCR` AS
        SELECT distinct * 
        FROM `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI` d
        WHERE NOT EXISTS (
            select 1 
            from `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c
            where c.marca_ds=d.marca_ds and c.CLIENTE_ID=d.CA_CUSTOMER_ID
        );

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI_LEGACY` AS
        SELECT distinct * 
        FROM `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI` d
        WHERE EXISTS (
            select 1 
            from `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c
            where c.marca_ds=d.marca_ds and c.CLIENTE_ID=d.CA_CUSTOMER_ID
        );


    END IF;

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.CAMPANA` SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_030410_CAMPANA_BI_INCR` ;

  END