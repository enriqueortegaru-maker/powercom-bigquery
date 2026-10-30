BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['DO','WA'];
END IF;



-- CALL COMISIONES.pr_retencion (202512, ['DO']);


CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.RETE_INBOUND_DESCUENTOS` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS (SELECT
  * EXCEPT (init_datetime_detail),
  CASE WHEN EXTRACT(YEAR FROM init_date_ts) = EXTRACT(YEAR FROM end_date_ts) AND EXTRACT(MONTH FROM init_date_ts) = EXTRACT(MONTH FROM end_date_ts) THEN "YES" ELSE "NO" END AS desc_baja_mismo_mes,
  ROW_NUMBER() OVER (PARTITION BY data_source_ds, customer_id, init_date_ts ORDER BY phone_nm DESC, init_date_ts ASC, init_datetime_detail DESC, end_date_ts ASC) AS repeticiones_por_cliente,
FROM (
  SELECT
    *
  FROM(
    
  SELECT
    campaign.data_source_ds,
    campaign.brand_ds,
    campaign.account_id,
    campaign.service_id,
    campaign.customer_id,
    campaign.phone_nm,
    campaign.subchannel_ds,
    campaign.sfid_id,
    campaign.seller AS user_store,
    campaign.seller,
    CAST(campaign.campaign_id AS STRING) AS campaign_id,
    campaignname,
    DATE(campaign.init_date_ts) AS init_date_ts,
    DATETIME(campaign.init_date_ts) AS init_datetime_detail,
    DATE(campaign.end_date_ts) AS end_date_ts,
    campaign.service_type,
    tarifa.tariff_id,
    tarifa.tariff_ds,
    campaign.account_nr AS contract_id,
  FROM
    `mm-datamart-kd.SERVICES.campaign_base_emysim` AS campaign
  LEFT JOIN (
    SELECT
      activation_date,
      COALESCE(deactivation_date,DATE("9999-12-31")) AS deactivation_date,
      phone_nm,
      tariff_id,
      tariff_ds,
    FROM
      `mm-datamart-kd.SERVICES.service_base_net`
    WHERE
      brand_ds = "YOIGO"
    QUALIFY
      ROW_NUMBER() OVER (PARTITION BY phone_nm, activation_date ORDER BY COALESCE(deactivation_date,DATE("9999-12-31")) DESC ) = 1

  ) AS tarifa
  ON
    DATE(campaign.init_date_ts) >= tarifa.activation_date
    AND DATE(campaign.init_date_ts) < tarifa.deactivation_date
    AND campaign.phone_nm = tarifa.phone_nm
  WHERE
	campaign.brand_ds = "YOIGO"
    AND (
      (
        campaign.sfid_id = "RONL010"
        AND campaign.init_date_ts >= "2023-12-14"
      )
      OR (
        campaign.sfid_id = "RONL006"
        AND campaign.init_date_ts >= "2024-05-20"
      )
      OR (
        campaign.sfid_id = "DONL001"
        AND campaign.init_date_ts >= "2024-03-01"
      )
      OR (
        campaign.sfid_id = "DONL002"
        AND campaign.init_date_ts >= "2024-04-08"
      )
      OR (
        campaign.sfid_id = "DONL010"
        AND campaign.init_date_ts >= "2024-04-08"
      )
      OR (
        campaign.sfid_id = "DONL011"
        AND campaign.init_date_ts >= "2024-04-08"
      )
      OR (
        campaign.sfid_id = "DONL024"
        AND campaign.init_date_ts >= "2024-04-08"
      )
      OR (
        campaign.sfid_id = "DONL004"
        AND campaign.init_date_ts >= "2025-04-14"
      )
      OR (
        campaign.sfid_id = "DONL020"
        AND campaign.init_date_ts >= "2025-04-14"
      )
    )
    AND campaign.init_date_ts >= "2023-12-14"
    AND campaign.service_type IN ("INTERNET","MOBILE","FIX")
    AND campaign.campaign_id IN (866,867,970,947,948, 1939)

  UNION ALL

  SELECT
    discount.data_source_ds,
    discount.brand_ds,
    CAST (NULL AS STRING) AS account_id,
    discount.service_id,
    discount.customer_id,
    discount.phone_nm,
    CAST (NULL AS STRING) AS subchannel_ds,
    REPLACE(discount.sfid,"VISTA_","") AS sfid_id,
    REPLACE(discount.sfid,"VISTA_","") AS user_store,
    REPLACE(discount.sfid,"VISTA_","") AS seller,
    discount.bill_code AS campaign_id,
    discount_ds AS campaignname,
    discount.init_date AS init_date_ts,
    DATETIME(discount.init_date) AS init_datetime_detail,
    discount.end_date AS end_date_ts,
    CAST (NULL AS STRING) AS service_type,
    tarifa.tariff_id,
    tarifa.tariff_ds,
    CAST (NULL AS STRING) AS contract_id,
  FROM
    `mm-datamart-kd.SERVICES.discount_base_qvantel` AS discount
  LEFT JOIN (
    SELECT
      activation_date,
      COALESCE(deactivation_date,DATE("9999-12-31")) AS deactivation_date,
      phone_nm,
      tariff_id,
      tariff_ds,
    FROM
      `mm-datamart-kd.SERVICES.service_base_net`
    WHERE
      brand_ds = "YOIGO"
    QUALIFY
      ROW_NUMBER() OVER (PARTITION BY phone_nm, activation_date ORDER BY COALESCE(deactivation_date,DATE("9999-12-31")) DESC ) = 1

  ) AS tarifa
  ON
    DATE(discount.init_date) >= tarifa.activation_date
    AND DATE(discount.init_date) < tarifa.deactivation_date
    AND discount.phone_nm = tarifa.phone_nm
  WHERE
      discount.sfid LIKE ("VISTA_1W%")
      AND discount.brand_ds = "YOIGO"
      AND discount.init_date >= "2023-12-14"
      --AND discount.service_type IN ("INTERNET","MOBILE")
      --AND discount. IN (866,867)
  )
  QUALIFY
  ROW_NUMBER() OVER (PARTITION BY data_source_ds, phone_nm, init_date_ts, campaign_id ORDER BY service_type DESC, init_datetime_detail DESC, end_date_ts DESC) = 1
))
  
;

CREATE OR REPLACE TABLE  `mm-commissions-reporting.TEMP.RETENCION` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS (
SELECT 

 'RTEN'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,'D - Camp. PRE Retencion' AS concepto 
     ,'CAMR' AS tipo_concepto
     ,1 AS unidades
     ,CASE WHEN tariff_ds LIKE '%+%' AND DEALER.CANAL = 'WA' THEN 40
           WHEN tariff_ds NOT LIKE '%+%' AND DEALER.CANAL = 'WA' THEN 20
           WHEN tariff_ds LIKE '%+%' AND DEALER.CANAL = 'DO' THEN DO_RAPPEL.camp_pre_retencion
       ELSE 0 END AS comision
     ,DESCUENTOS.sfid_id AS id_comisionista
     ,DEALER.distribuidor
     ,DESCUENTOS.sfid_id
     ,DESCUENTOS.sfid_id AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,brand_ds AS marca
     ,service_type
     ,CAST (phone_nm AS STRING) AS phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id 
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,init_date_ts AS sale_date
     ,init_date_ts AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca
     ,'20' AS cod_tipo_contrato
     ,'042'AS cod_producto
     ,CASE WHEN DEALER.CANAL = 'DO' THEN '15'
           WHEN DEALER.CANAL = 'WA' THEN '14' END AS cod_canal
     ,CAST (NULL AS STRING) AS campaign_code
     ,CAST (NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad 

FROM  `mm-commissions-reporting.TEMP.RETE_INBOUND_DESCUENTOS` DESCUENTOS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
 ON DESCUENTOS.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.GS.MARCO_RAPPEL_DO` DO_RAPPEL
  ON DESCUENTOS.sfid_id = DO_RAPPEL.id_comisionista
   AND DO_RAPPEL.id_mes = id_mes_pr 
   AND DO_RAPPEL.camp_pre_retencion > 0

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE  DATE_TRUNC(DESCUENTOS.init_date_ts, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND repeticiones_por_cliente = 1
AND end_date_ts >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 1 YEAR)
AND tariff_ds NOT LIKE '%CONV%'
and DEALER.canal = canal_pr
)
;

DELETE FROM  `mm-commissions-reporting.TEMP.RETENCION` WHERE COMISION = 0

;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('RTEN', id_mes_pr, canales_pr, 'TEMP.RETENCION', 'ACTUALIZAR');

END