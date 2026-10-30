BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_device_base_dealer`();

  CALL `mm-commissions-reporting.TERMINALES.pr_device_base`();
--  CALL `mm-commissions-reporting.TERMINALES.pr_device_base_test`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.device_base_dealer`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  SELECT DEVICE.* --EXCEPT (RANK_BASE)
  FROM `mm-commissions-reporting.TEMP.device_base` DEVICE
  --FROM `mm-commissions-reporting.TEMP.device_base_test` DEVICE

    LEFT JOIN TEMP.devices_base_qvantel RFM_YOIGO
            ON CAST(DEVICE.phone_nm AS STRING) = CAST(RFM_YOIGO.phone_nm AS STRING)
                AND DATE(DEVICE.order_date) = RFM_YOIGO.sell_date
                AND DEVICE.serial_number = RFM_YOIGO.serial
                AND DEVICE.brand_ds = 'YOIGO'

    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER 
            ON  (COALESCE(RFM_YOIGO.sfid_id, IF(LENGTH(DEVICE.sfid_id) = 2,NULL,DEVICE.sfid_id)) = DEALER.sfid_id 
                    OR IF(LENGTH(DEVICE.user_store) = 2,NULL,UPPER(DEVICE.user_store)) = DEALER.sfid_id 
                    OR IF(LENGTH(DEVICE.seller) = 2,NULL,UPPER(SPLIT(DEVICE.seller, "@")[OFFSET(0)])) = DEALER.sfid_id )

  WHERE (SUBSTR(COALESCE(DEALER.sfid_id, RFM_YOIGO.sfid_id, DEVICE.sfid_id), 1, 2) IN ('PH','TP')
          OR COALESCE(DEALER.sfid_id, RFM_YOIGO.sfid_id, DEVICE.sfid_id) IN (SELECT DISTINCT id_comisionista FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_sellers_mm_exclusivo`))
        AND UPPER(DEVICE.terminal_name) NOT LIKE '%SMART TV%'
        AND UPPER(DEVICE.terminal_name) NOT LIKE '%TCL GOOGLE TV%'
        AND UPPER(DEVICE.terminal_name) NOT LIKE '%XIAOMI TV'
        AND UPPER(DEVICE.terminal_name) NOT LIKE '%XIAOMI TV A%'
        AND UPPER(DEVICE.terminal_name) NOT LIKE '%XIAOMI GOOGLE TV%'
        AND UPPER(DEVICE.terminal_name) NOT LIKE '%TCL ANDROID TV%'

  QUALIFY RANK () OVER (
                PARTITION BY DEVICE.service_id, DEVICE.product_code, DEVICE.serial_number
                ORDER BY DEALER.id_mes DESC  --Tomamos la última actualización
                ) = 1

  ;

END