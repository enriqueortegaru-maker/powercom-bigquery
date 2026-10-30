BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'REWA';


-- CALL `mm-commissions-reporting.COMISIONES.pr_rewa`(202503);


ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.sfid_id
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_rewa`
     WHERE id_mes = mes_int
     GROUP BY 1,2,3,4,5,6,7,8
     ) REPARTOS
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON REPARTOS.sfid_id = DEALER.sfid_id
            AND DEALER.id_mes = mes_int AND DEALER.agrupacion_canal = 'TLV - Web' --AND comisiona
WHERE DEALER.sfid_id IS NULL AND REPARTOS.importe <> 0
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_campaigns` AS

/*
1. FEB 2024: AHORA MISMO SE ESTÁN FILTRANDO LOS DESCUENTOS DE 30% Y 40% QUE SON LOS QUE INFORMARON A CARLOS LEÓN LUJÁN QUE ENTRABAN EN LA CAMPAÑA DE WEB. SFIDS: RONL010 (MYSIM) Y 1W (QVANTEL)
2. A PARTIR DEL 01/03/24 ENTRA DONL001
*/
SELECT * EXCEPT(repeticiones_por_cliente)
FROM (
  SELECT
  *,
  ROW_NUMBER() OVER (PARTITION BY data_source_ds, customer_id, init_date_ts ORDER BY phone_nm DESC, init_date_ts ASC, end_date_ts ASC) AS repeticiones_por_cliente,
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
    DATE(campaign.end_date_ts) AS end_date_ts,
    campaign.service_type,
    tarifa.tariff_id,
    tarifa.tariff_ds,
    campaign.account_nr AS contract_id,
    tarifa.segment_ds
  FROM
    `mm-datamart-kd.SERVICES.campaign_base_emysim` AS campaign
  LEFT JOIN (
    SELECT
      activation_date,
      COALESCE(deactivation_date,DATE("9999-12-31")) AS deactivation_date,
      phone_nm,
      tariff_id,
      tariff_ds,
      segment_ds
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
      campaign.sfid_id = "RONL010"
      AND campaign.brand_ds = "YOIGO"
      AND DATE(campaign.init_date_ts) >= PARSE_DATE('%Y%m',mes_string)
      AND campaign.service_type IN ("INTERNET","MOBILE","FIX")
      AND campaign.campaign_id IN (866,867,970,947,948)

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
    discount.end_date AS end_date_ts,
    CAST (NULL AS STRING) AS service_type,
    tarifa.tariff_id,
    tarifa.tariff_ds,
    CAST (NULL AS STRING) AS contract_id,
    tarifa.segment_ds
  FROM
    `mm-datamart-kd.SERVICES.discount_base_qvantel` AS discount
  LEFT JOIN (
    SELECT
      activation_date,
      COALESCE(deactivation_date,DATE("9999-12-31")) AS deactivation_date,
      phone_nm,
      tariff_id,
      tariff_ds,
      segment_ds
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
      AND discount.init_date >= PARSE_DATE('%Y%m',mes_string)
  )
  QUALIFY
  ROW_NUMBER() OVER (PARTITION BY data_source_ds, phone_nm, init_date_ts, campaign_id ORDER BY service_type DESC, end_date_ts DESC) = 1
)
)
WHERE repeticiones_por_cliente = 1

;

-- ****************************************************************************
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_repartos` AS

WITH reparto_X001_10 AS
(
SELECT
      concepto
     ,tipo_concepto
     ,'10' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_10) AS arr
     ,SPLIT(marca) AS arr2
     ,SPLIT(campaign_id) AS arr3
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_rewa`
     GROUP BY 1,2,3,4,5,6,7,8
     )
WHERE id_mes = mes_int
)
,

reparto_X001_12 AS
(
SELECT
      concepto
     ,tipo_concepto
     ,'12' AS cod_segmento
     ,'X001' AS sociedad
     ,SPLIT(reparto_X001_12) AS arr
     ,SPLIT(marca) AS arr2
     ,SPLIT(campaign_id) AS arr3
FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_rewa`
     GROUP BY 1,2,3,4,5,6,7,8
     )
WHERE id_mes = mes_int
)

     SELECT DISTINCT
          concepto
          ,tipo_concepto
          ,cod_segmento
          ,sociedad
          ,cod_tipo_contrato
          ,marca
          ,campaign_id
     FROM reparto_X001_10, UNNEST(arr) cod_tipo_contrato, UNNEST(arr2) marca LEFT JOIN UNNEST(arr3) campaign_id
     UNION DISTINCT
     SELECT DISTINCT
          concepto
          ,tipo_concepto
          ,cod_segmento
          ,sociedad
          ,cod_tipo_contrato
          ,marca
          ,campaign_id
     FROM reparto_X001_12, UNNEST(arr) cod_tipo_contrato, UNNEST(arr2) marca LEFT JOIN UNNEST(arr3) campaign_id

;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_base_comisiones` AS

SELECT
      REPARTOS.concepto
     ,mes_int AS id_mes
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,RAPPEL.sfid_id
     ,CAMPS.campaign_id
     ,ACTIVACIONES.* EXCEPT(id_mes, sfid_id)
     
FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES

LEFT JOIN `mm-commissions-reporting.TEMP.rewa_campaigns` CAMPS
     ON ACTIVACIONES.phone_nm = CAST(CAMPS.phone_nm AS STRING) AND ACTIVACIONES.marca = CAMPS.brand_ds

INNER JOIN `mm-commissions-reporting.TEMP.rewa_repartos` REPARTOS
          ON ACTIVACIONES.cod_segmento = REPARTOS.cod_segmento
             AND ACTIVACIONES.sociedad = REPARTOS.sociedad AND ACTIVACIONES.cod_tipo_contrato = REPARTOS.cod_tipo_contrato AND ACTIVACIONES.marca = REPARTOS.marca AND COALESCE(CAMPS.campaign_id,'0') = COALESCE(REPARTOS.campaign_id,'0')

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_rewa`
           GROUP BY 1,2,3,4,5,6,7,8
           ) RAPPEL
          ON (ACTIVACIONES.sfid_id = RAPPEL.sfid_id OR ACTIVACIONES.id_comisionista = RAPPEL.sfid_id) AND REPARTOS.concepto = RAPPEL.concepto AND RAPPEL.id_mes = mes_int AND RAPPEL.importe <> 0 

WHERE ACTIVACIONES.id_mes = mes_int
AND ACTIVACIONES.service_type IN ('INTERNET','MOBILE')
     --  AND comisionamiento = 'Comisiona'


QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, service_type, REPARTOS.concepto) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_unitario` AS

SELECT
      BASE.sfid_id
     ,BASE.concepto
     ,RAPPEL.importe
     ,COUNT(1) AS eventos

FROM `mm-commissions-reporting.TEMP.rewa_base_comisiones` BASE

INNER JOIN (
           SELECT * EXCEPT(importe), SUM(importe) importe
           FROM `mm-commissions-reporting.COMISIONES.v_rewa`
           GROUP BY 1,2,3,4,5,6,7,8
           ) RAPPEL
          ON BASE.sfid_id = RAPPEL.sfid_id
             AND BASE.concepto = RAPPEL.concepto AND BASE.id_mes = RAPPEL.id_mes

WHERE RAPPEL.importe <> 0
          
GROUP BY 1,2,3
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_calculo` AS

SELECT
      prefijo||'_'||mes_string||'_'||BASE.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,BASE.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,(ROUND((UNITARIO.importe / UNITARIO.eventos),2)) AS comision

     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,BASE.sfid_id
     ,BASE.seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,BASE.marca
     ,BASE.service_type
     ,BASE.phone_nm
     ,BASE.tariff_id
     ,BASE.tariff_ds
     ,BASE.service_id
     ,BASE.account_id
     ,BASE.customer_id
     ,BASE.line_type_ds
     ,BASE.bundle_type
     ,BASE.technology_ds
     ,BASE.billing_type_ds
     ,BASE.sale_date
     ,BASE.activation_date
     ,BASE.deactivation_date
     ,BASE.order_id
     ,BASE.order_type_agg
     ,BASE.cod_segmento
     ,BASE.cod_marca
     ,BASE.cod_tipo_contrato
     ,BASE.cod_producto
     ,BASE.cod_canal
     ,BASE.claim_code
     ,CAST(NULL AS STRING) AS campaign_code
     ,CAST(NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM `mm-commissions-reporting.TEMP.rewa_base_comisiones` BASE

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON BASE.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (BASE.sfid_id = DEALER.sfid_id OR BASE.id_comisionista = DEALER.id_comisionista) AND DEALER.agrupacion_canal = 'TLV - Web' AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.TEMP.rewa_unitario` UNITARIO
         ON BASE.sfid_id = UNITARIO.sfid_id AND BASE.concepto = UNITARIO.concepto
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_correccion` AS

SELECT
      CALCULO.commission_id
     ,CALCULO.estado
     ,CALCULO.mes_liquidado
     ,CALCULO.id_mes
     ,CALCULO.agrupacion_canal
     ,CALCULO.canal
     ,CALCULO.concepto
     ,CALCULO.tipo_concepto
     ,CALCULO.unidades
     ,(UNITARIO.importe - CALCULO.comision) AS comision
     ,CALCULO.* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * EXCEPT(comision)
            ,SUM(comision) OVER (PARTITION BY sfid_id, concepto) AS comision
     FROM `mm-commissions-reporting.TEMP.rewa_calculo`
     QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id, concepto) = 1
     ) CALCULO

LEFT JOIN `mm-commissions-reporting.TEMP.rewa_unitario` UNITARIO
         ON CALCULO.sfid_id = UNITARIO.sfid_id AND CALCULO.concepto = UNITARIO.concepto

WHERE ROUND((UNITARIO.importe - CALCULO.comision), 2) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_cruzado` AS

SELECT
      commission_id
     ,estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
     ,concepto
     ,tipo_concepto
     ,unidades
     ,ROUND(SUM(comision) OVER (PARTITION BY concepto, service_id, marca, service_type),2) AS comision
     ,* EXCEPT(commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades, comision)

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.rewa_calculo`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.rewa_correccion`
     )
     
QUALIFY ROW_NUMBER() OVER (PARTITION BY concepto, service_id, marca, service_type) = 1
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa_no_cruzado` AS
SELECT
      prefijo||'_'||mes_string||'_'||DEALER.canal||'_'||row_number () over () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(mes_int AS STRING)) AS mes_liquidado
     ,mes_int AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,RAPPEL.concepto
     ,CONCEPTOS.tipo_concepto
     ,CAST(NULL AS INT64) AS unidades
     ,RAPPEL.importe AS comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,DEALER.sfid_id AS sfid_id
     ,COALESCE(RAPPEL.sfid_id, DEALER.sfid_id) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,'LLAMAYA' AS marca 

     ,CASE WHEN COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') = '61' AND RAPPEL.tipo_concepto <> 'CURE' THEN 'INTERNET'
           ELSE 'MOBILE'
      END AS service_type

     ,CAST(NULL AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,CAST(NULL AS STRING) AS tariff_ds
     ,CAST(NULL AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,CAST(NULL AS DATE) AS sale_date
     ,CAST(NULL AS DATE) AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,'04' AS cod_marca 
     ,COALESCE(SPLIT(RAPPEL.reparto_X001_10)[OFFSET(0)], SPLIT(RAPPEL.reparto_X001_12)[OFFSET(0)], '61') AS cod_tipo_contrato
     ,'040' AS cod_producto 
     ,'14' AS cod_canal
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS campaign_code
     ,CAST(NULL AS STRING) AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad

FROM (
     SELECT * EXCEPT(importe), SUM(importe) importe
     FROM `mm-commissions-reporting.COMISIONES.v_rewa`
     GROUP BY 1,2,3,4,5,6,7,8
     ) RAPPEL

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON RAPPEL.concepto = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON  RAPPEL.sfid_id = DEALER.sfid_id AND DEALER.id_mes = mes_int

LEFT JOIN `mm-commissions-reporting.TEMP.rewa_unitario` UNITARIO
         ON RAPPEL.sfid_id = UNITARIO.sfid_id AND RAPPEL.concepto = UNITARIO.concepto

WHERE RAPPEL.id_mes = mes_int AND UNITARIO.sfid_id IS NULL AND RAPPEL.importe <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rewa` AS

SELECT
      * EXCEPT(commission_id)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over () AS commission_id

FROM (
     SELECT * FROM `mm-commissions-reporting.TEMP.rewa_cruzado`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.TEMP.rewa_no_cruzado`
     )
;


ASSERT NOT EXISTS 
(
SELECT REPARTO.sfid_id
FROM (SELECT sfid_id, SUM(comision) comision FROM `mm-commissions-reporting.TEMP.rewa` GROUP BY 1) REPARTO
LEFT JOIN (SELECT sfid_id, SUM(importe) importe FROM `mm-commissions-reporting.COMISIONES.v_rewa` WHERE id_mes = mes_int GROUP BY 1) GS
         ON REPARTO.sfid_id = GS.sfid_id
WHERE ROUND(REPARTO.comision - GS.importe,2) <> 0
);


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (
                                                                prefijo,
                                                                mes_int,
                                                                (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.rewa WHERE canal IS NOT NULL),
                                                                'TEMP.rewa',
                                                                'ACTUALIZAR'
                                                                )
;


END