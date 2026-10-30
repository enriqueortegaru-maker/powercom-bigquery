BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_osp_maestros`()

--Tabla que contiene los Precios de Cesion de SAP actualizados
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.osp_maestro_device`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)) AS
    SELECT *, CONCAT('20', _TABLE_SUFFIX) AS tabla_origen FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_device_20*`
    QUALIFY RANK () OVER (PARTITION BY DEVICE_MASTER_KEY, SAP_CODE_ID ORDER BY _TABLE_SUFFIX DESC) = 1
;

--Tabla que contiene los Maestros de los SFIDs de SIEBEL 7
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.osp_maestro_sfid`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)) AS
  SELECT * FROM (
    SELECT *, CONCAT('2026', _TABLE_SUFFIX) AS tabla_origen FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_sfid_2026*`
    -- UNION ALL
    -- SELECT *, CONCAT('2027', _TABLE_SUFFIX) AS tabla_origen FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_sfid_2027*`
  )
  QUALIFY RANK () OVER (PARTITION BY SFID_ID, SFID_CHANNEL_TYPE_DES ORDER BY tabla_origen DESC) = 1
;

END