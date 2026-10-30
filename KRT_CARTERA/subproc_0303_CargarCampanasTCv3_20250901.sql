BEGIN

    --- V4: Introduce condicion de que feha de inicio de campaña es igual o anterior fecha fin de periodo de comisionado

    declare  DESDE_DT,HASTA_DT, DESDE_2M_DT  date; 
    --declare desde, hasta int64; set desde=20250101; set hasta=20250130;          
    set HASTA_DT = parse_date ('%Y%m%d', cast ( HASTA as string) );
    set DESDE_DT = parse_date ('%Y%m%d', cast ( DESDE as string) );
    set DESDE_2M_DT=DATE_SUB(DESDE_DT, INTERVAL 2 MONTH);    


    --- PASO 1: CREO TABLA CAMPANA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.CAMPANA` AS
    SELECT
      * EXCEPT (orden)
    FROM (
      SELECT
        DISTINCT 'TELECABLE' marca_ds,
        CAST(cc.swCampaignId AS STRING) ID_CAMPANA,
        cc.swCustomerId CLIENTE_ID,
        cc.swRealizadaPor REALIZADO_POR,
        c.swCampaignNombre NOMBRE_CAMPANA,
        c.swCampaignTipo TIPO_CAMPANA,
        EXTRACT(DATE FROM swCampaignFechaInicio) FECHA_INICIO_DT,
        EXTRACT(DATE FROM swCampaignFechaFin) FECHA_FIN_DT,        
        ROW_NUMBER() OVER (PARTITION BY cc.swCustomerId ORDER BY cc.swCampaignId DESC) orden
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_tc_campaign_clientes` cc
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_tc_campaign` c  ON  cc.swCampaignId = c.swCampaignId
      INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` PARAM  ON  PARAM.campana_id = CAST(c.swCampaignId AS STRING)  AND marca_ds = 'TELECABLE'
      --WHERE DATE_TRUNC( CAST( swFechaFinalizacion AS DATE), DAY) BETWEEN DESDE_2M_DT  AND HASTA_DT AND cc.swSubestado IN ('    CONTRATADO','CONTRATADO') AND cc.swEstado IN ('Finalizada',' Finalizada')
      and contains_substr(cc.swEstado,'finalizad')
      and contains_substr(cc.swSubestado,'contratad')      
      AND EXTRACT(DATE FROM swCampaignFechaInicio) >= DESDE_2M_DT
      AND EXTRACT(DATE FROM COALESCE(swCampaignFechaFin,'2099-12-31')) >= DESDE_DT      
      )

    WHERE orden = 1;


    --- PASO 2: CREO LOG 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0303_CAMPANA` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.CAMPANA`;      


  END