BEGIN

    declare  DESDE_DT,HASTA_DT,DESDE_3M_DT  date;    
    --DECLARE DESDE, HASTA INT64; SET DESDE=20231001;SET HASTA=20231031;    
    set HASTA_DT = parse_date ('%Y%m%d', cast ( HASTA as string) );
    set DESDE_DT = parse_date ('%Y%m%d', cast ( DESDE as string) );
    set DESDE_3M_DT=DATE_SUB(DESDE_DT, INTERVAL 3 MONTH);


    --- PASO 1: CREO LOG COMPLETO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0304_CAMPANA` AS
    SELECT * EXCEPT (orden)
    FROM (
      SELECT DISTINCT
        CASE mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' END  marca_ds,
        param.campana_id, CI_CUSTOMER_ACTIVITY.CA_CUSTOMER_ID,'FICTICIO' REALIZADO_POR, CI_CUSTOMER_ACTIVITY.CA_DESC,
        CA_CREATED_TIMESTAMP, CA_CHANGED_TIMESTAMP, CA_PROCESSED_TIMESTAMP,
        ROW_NUMBER() OVER (PARTITION BY CI_CUSTOMER_ACTIVITY.CA_CUSTOMER_ID ORDER BY param.campana_id DESC) orden
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` CI_CLIENTE,
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_customer_activity` CI_CUSTOMER_ACTIVITY,
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m,
        `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` PARAM
      WHERE
        ( CI_CLIENTE.swCustomerId=CI_CUSTOMER_ACTIVITY.CA_CUSTOMER_ID )
        AND CAST(CI_CUSTOMER_ACTIVITY.CA_CREATED_TIMESTAMP AS date) BETWEEN DESDE_3M_DT AND HASTA_DT
        AND m.mmMarcaId = CI_CLIENTE.mmMarcaId
        AND CASE mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' END = param.marca_Ds
        AND CI_CUSTOMER_ACTIVITY.CA_DESC LIKE CONCAT(CONCAT(campana_id,'_'),'%') 
    )
   WHERE orden = 1;


END