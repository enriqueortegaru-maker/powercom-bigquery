BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['D2D','D2N','DEM'];
END IF;




-- CALL COMISIONES.pr_seg_mov_d2d (202509,['D2D','D2N','DEM']);


----- ACTIVACIONES -----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.seguros_moviles_d2d` AS (
     SELECT
      'SEGR'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,'B - Seguro Movil' as concepto
     ,'CSMO' AS tipo_concepto
     ,1 AS unidades
     ,4 * VENTAS.premium_net as comision
     ,DEALER.id_comisionista
     ,DEALER.distribuidor
     ,VENTAS.sfid_id
     ,VENTAS.user_store AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,VENTAS.brand_ds AS marca
     ,'INSURANCE' AS service_type
     ,CAST(VENTAS.phone_nm  AS STRING) AS phone_nm
     ,CAST (NULL AS STRING) AS tariff_id
     ,VENTAS.model AS tariff_ds
     ,VENTAS.service_id
     ,VENTAS.policy_number AS account_id 
     ,VENTAS.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,DATE(VENTAS.sold_datetime) AS sale_date
     ,DATE(VENTAS.activated_datetime) AS activation_date
     ,DATE(VENTAS.terminated_datetime) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'009' AS cod_producto
     ,AGRUPACION.codigo_canal_sap AS cod_canal
     ,CAST(NULL AS STRING) AS campaign_code
     ,VENTAS.imei AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(VENTAS.brand_ds) AS sociedad 

FROM `mm-datamart-kd.DATA_TEAM.bibeseguros_subscriptions` VENTAS
LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION

         ON COALESCE(VENTAS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND VENTAS.master_channel_ds = AGRUPACION.master_channel_ds
            AND VENTAS.channel_ds = AGRUPACION.channel_ds
            AND VENTAS.subchannel_ds = AGRUPACION.subchannel_ds
            AND VENTAS.brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            UPPER(SPLIT(VENTAS.seller, '@')[0]) = DEALER.sfid_id
            OR VENTAS.user_store = DEALER.sfid_id
            OR SPLIT(VENTAS.seller, '-')[OFFSET(0)] = DEALER.sfid_id
            )
            AND DEALER.id_mes = id_mes_pr


         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(VENTAS.activated_datetime, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND VENTAS.service = '1. SEGURO MOVIL'
AND DEALER.comisiona = true
AND DEALER.canal = canal_pr
AND AGRUPACION.codigo_canal_sap IS NOT NULL
AND VENTAS.terminated_datetime IS NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY  VENTAS.service_id ORDER BY VENTAS.sold_datetime DESC ) =  1 
)
;

--- Insertar tabla final ----
-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('SEGR', id_mes_pr, canales_pr, 'TEMP.seguros_moviles_d2d', 'ACTUALIZAR');



END