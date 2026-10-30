BEGIN

DECLARE sql, prefijo, mes_string string;

SET mes_string = CAST(id_mes_pr as string);

SET prefijo = 'ACTIOUT';

IF canales_pr IS NULL THEN 
  SET canales_pr = ['OSPNOUN','OSPNXSN','XSO','OUOP','OUOCC'];

END IF;

IF id_mes_pr IS NULL THEN
  SET id_mes_pr = CAST(FORMAT_DATE('%Y%m', CURRENT_DATE()) AS INT64);
  SET mes_string = CAST(id_mes_pr as string);
END IF;

/*
call  COMISIONES.pr_acti_outbound_osp (202609, ['OSPNOUN','OSPNXSN']);
*/



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_comisiones_outbound_OSP` AS (

--- LINEAS ADICIONALES + XSELLING JAZZTEL ---

SELECT 
    -- prefijo || '_' || mes_string || '_' || b.canal || '_' ||ROW_NUMBER() OVER () AS commission_id
    'calculado' AS estado
    ,id_mes_pr AS id_mes
    ,DEALER.agrupacion_canal
    ,DEALER.canal
    ,CASE WHEN VENTAS.service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          WHEN VENTAS.service_type = 'INTERNET' THEN 'A - Servicio Fijo'
    END AS concepto
    ,'UPFR' AS tipo_concepto
    ,1 AS unidades
    ,CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO AS comision
    ,DEALER.id_comisionista
    ,DEALER.distribuidor
    ,VENTAS.sfid_id
    ,VENTAS.seller
    ,DEALER.nombre_comercio
    ,DEALER.razon_social
    ,DEALER.cif
    ,DEALER.zona_fiscal
    ,VENTAS.marca
    ,VENTAS.service_type
    ,VENTAS.phone_nm
    ,VENTAS.tariff_id
    ,VENTAS.tariff_ds
    ,VENTAS.service_id
    ,VENTAS.account_id
    ,VENTAS.customer_id
    ,VENTAS.line_type_ds
    ,VENTAS.bundle_type
    ,VENTAS.technology_ds
    ,VENTAS.billing_type_ds
    ,VENTAS.sale_date
    ,VENTAS.activation_date
    ,COALESCE(VENTAS.deactivation_date, VENTAS.cancellation_day_id) AS deactivation_date
    ,VENTAS.order_id
    ,VENTAS.order_type_agg
    ,cod_segmento
    ,cod_marca
    ,cod_tipo_contrato
    ,cod_producto
    ,VENTAS.cod_canal
    ,CAMP.campaign AS campaign_code
    ,CAST(NULL AS STRING) AS serial_number
    ,CAST(NULL AS FLOAT64) AS tax_base
    ,CAST(NULL AS STRING) AS claim_code
    ,CAST(NULL AS STRING) AS process_code
    ,VENTAS.comments
    ,'C_MANUAL' AS facturador
    , PONDERACIONES.ESTADO AS ESTADO_LINEA
    , PONDERACIONES.cancellation_day_id
    

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON VENTAS.sfid_id = DEALER.id_comisionista
 OR VENTAS.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista

  
LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
-- LEFT JOIN `mm-commissions-reporting.TEMP.ventas_base_outbound_ponderaciones` PONDERACIONES
ON VENTAS.phone_nm = CAST(PONDERACIONES.PHONE_NM AS STRING)
 AND VENTAS.service_id = PONDERACIONES.SERVICE_ID

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON PONDERACIONES.MARCA_CANAL = UNITARIO.MARCA
 AND DEALER.ID_COMISIONISTA = UNITARIO.SFID
 AND UNITARIO.MES = id_mes_pr

WHERE CAMP.campaign IN (
'CROSS SELLING_MV',
'CROSS SELLING',
'LINEAS ADICIONALES',
'CROSELLING_SEGUNDA RESIDENCIA'
)

AND VENTAS.service_type IN ( 'MOBILE','INTERNET')
AND VENTAS.MARCA IN ('JAZZTEL','SIMYO')
AND PONDERACIONES.service_type IN ('MOBILE','BROADBAND')
AND PONDERACIONES.PRODUCTO = 'VENTA NETA'
-- AND VENTAS.sale_date BETWEEN '2026-08-01' AND '2026-08-31'
AND CAST(FORMAT_DATE('%Y%m', VENTAS.sale_date) AS INT64) = id_mes_pr

UNION ALL

--- COLD CALLING CONTROLADO FIJO VN JAZZTEL Y SIMYO ---

SELECT 
    -- prefijo || '_' || mes_string || '_' || b.canal || '_' ||ROW_NUMBER() OVER () AS commission_id
    'calculado' AS estado
    ,id_mes_pr AS id_mes
    ,DEALER.agrupacion_canal
    ,DEALER.canal
    ,CASE WHEN VENTAS.service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          WHEN VENTAS.service_type = 'INTERNET' THEN 'A - Servicio Fijo'
    END AS concepto
    ,'UPFR' AS tipo_concepto
    ,1 AS unidades
    ,CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO AS comision
    ,DEALER.id_comisionista
    ,DEALER.distribuidor
    ,VENTAS.sfid_id
    ,VENTAS.seller
    ,DEALER.nombre_comercio
    ,DEALER.razon_social
    ,DEALER.cif
    ,DEALER.zona_fiscal
    ,VENTAS.marca
    ,VENTAS.service_type
    ,VENTAS.phone_nm
    ,VENTAS.tariff_id
    ,VENTAS.tariff_ds
    ,VENTAS.service_id
    ,VENTAS.account_id
    ,VENTAS.customer_id
    ,VENTAS.line_type_ds
    ,VENTAS.bundle_type
    ,VENTAS.technology_ds
    ,VENTAS.billing_type_ds
    ,VENTAS.sale_date
    ,VENTAS.activation_date
    ,COALESCE(VENTAS.deactivation_date, VENTAS.cancellation_day_id) AS deactivation_date
    ,VENTAS.order_id
    ,VENTAS.order_type_agg
    ,cod_segmento
    ,cod_marca
    ,cod_tipo_contrato
    ,cod_producto
    ,VENTAS.cod_canal
    ,CAMP.campaign AS campaign_code
    ,CAST(NULL AS STRING) AS serial_number
    ,CAST(NULL AS FLOAT64) AS tax_base
    ,CAST(NULL AS STRING) AS claim_code
    ,CAST(NULL AS STRING) AS process_code
    ,VENTAS.comments
    ,'C_MANUAL' AS facturador
    , PONDERACIONES.ESTADO AS ESTADO_LINEA
    , PONDERACIONES.cancellation_day_id

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON VENTAS.sfid_id = DEALER.id_comisionista
 OR VENTAS.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista

  
LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
-- LEFT JOIN `mm-commissions-reporting.TEMP.ventas_base_outbound_ponderaciones` PONDERACIONES
ON VENTAS.phone_nm = CAST(PONDERACIONES.PHONE_NM AS STRING)
 AND VENTAS.service_id = PONDERACIONES.SERVICE_ID

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON PONDERACIONES.MARCA_CANAL = UNITARIO.MARCA
 AND DEALER.ID_COMISIONISTA = UNITARIO.SFID
 AND UNITARIO.MES = id_mes_pr

WHERE CAMP.campaign IN (
'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
'COLD CALLING CONTROLADO OFFSHORE',
'COLD CALLING CONTROLADO',
'COLD CALLING CONTROLADO TEMPL',
'COLD CALLING CONTROLADO CRECIMIENTOS',
'COLD CALLING CONTROLADO JE ',
'COLD CALLING CONTROLADO PL_EX'

)

AND VENTAS.service_type IN ( 'INTERNET')
AND VENTAS.MARCA IN ('JAZZTEL','SIMYO')
AND PONDERACIONES.service_type IN ('BROADBAND')
AND PONDERACIONES.PRODUCTO = 'VENTA NETA'
-- AND VENTAS.sale_date BETWEEN '2026-08-01' AND '2026-08-31'
AND CAST(FORMAT_DATE('%Y%m', VENTAS.sale_date) AS INT64) = id_mes_pr


UNION ALL
--- COLD CALLING CONTROLADO FIJO RFB ORANGE Y MOVIL RFB JAZZTEL Y SIMYO ---

SELECT 
    -- prefijo || '_' || mes_string || '_' || b.canal || '_' ||ROW_NUMBER() OVER () AS commission_id
    'calculado' AS estado
    ,id_mes_pr AS id_mes
    ,DEALER.agrupacion_canal
    ,DEALER.canal
    ,CASE WHEN VENTAS.service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          WHEN VENTAS.service_type = 'INTERNET' THEN 'A - Servicio Fijo'
    END AS concepto
    ,'UPFR' AS tipo_concepto
    ,1 AS unidades
    ,CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO AS comision
    ,DEALER.id_comisionista
    ,DEALER.distribuidor
    ,VENTAS.sfid_id
    ,VENTAS.seller
    ,DEALER.nombre_comercio
    ,DEALER.razon_social
    ,DEALER.cif
    ,DEALER.zona_fiscal
    ,VENTAS.marca
    ,VENTAS.service_type
    ,VENTAS.phone_nm
    ,VENTAS.tariff_id
    ,VENTAS.tariff_ds
    ,VENTAS.service_id
    ,VENTAS.account_id
    ,VENTAS.customer_id
    ,VENTAS.line_type_ds
    ,VENTAS.bundle_type
    ,VENTAS.technology_ds
    ,VENTAS.billing_type_ds
    ,VENTAS.sale_date
    ,VENTAS.activation_date
    ,COALESCE(VENTAS.deactivation_date, VENTAS.cancellation_day_id) AS deactivation_date
    ,VENTAS.order_id
    ,VENTAS.order_type_agg
    ,cod_segmento
    ,cod_marca
    ,cod_tipo_contrato
    ,cod_producto
    ,VENTAS.cod_canal
    ,CAMP.campaign AS campaign_code
    ,CAST(NULL AS STRING) AS serial_number
    ,CAST(NULL AS FLOAT64) AS tax_base
    ,CAST(NULL AS STRING) AS claim_code
    ,CAST(NULL AS STRING) AS process_code
    ,VENTAS.comments
    ,'C_MANUAL' AS facturador
    , PONDERACIONES.ESTADO AS ESTADO_LINEA
    , PONDERACIONES.cancellation_day_id

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON VENTAS.sfid_id = DEALER.id_comisionista
 OR VENTAS.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista

  
LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
-- LEFT JOIN `mm-commissions-reporting.TEMP.ventas_base_outbound_ponderaciones` PONDERACIONES
ON VENTAS.phone_nm = CAST(PONDERACIONES.PHONE_NM AS STRING)
 AND VENTAS.service_id = PONDERACIONES.SERVICE_ID

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON  UNITARIO.MARCA = 'JAZZTEL'
 AND DEALER.ID_COMISIONISTA = UNITARIO.SFID
 AND UNITARIO.MES = id_mes_pr

WHERE CAMP.campaign IN (
'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
'COLD CALLING CONTROLADO OFFSHORE',
'COLD CALLING CONTROLADO',
'COLD CALLING CONTROLADO TEMPL',
'COLD CALLING CONTROLADO CRECIMIENTOS',
'COLD CALLING CONTROLADO JE ',
'COLD CALLING CONTROLADO PL_EX'

)

AND (
    (
        VENTAS.service_type = 'INTERNET'
        AND VENTAS.MARCA = 'ORANGE'
    )
    OR
    (
        VENTAS.service_type = 'MOBILE'
        AND VENTAS.MARCA IN ('JAZZTEL', 'SIMYO', 'ORANGE')
    )
)

AND (
    (
        PONDERACIONES.MARCA = 'ORANGE'
        AND PONDERACIONES.service_type = 'BROADBAND'
    )
    OR
    (
        PONDERACIONES.MARCA IN ('JAZZTEL', 'SIMYO', 'ORANGE')
        AND PONDERACIONES.service_type = 'MOBILE'
    )
)
-- AND PONDERACIONES.PRODUCTO = 'RFB'
-- AND VENTAS.activation_date BETWEEN '2026-08-01' AND '2026-08-31'
AND CAST(FORMAT_DATE('%Y%m', VENTAS.activation_date) AS INT64) = id_mes_pr



UNION ALL

--- POSPAGO FIJO ORANGE VENTA NETA ---

SELECT 
    -- prefijo || '_' || mes_string || '_' || b.canal || '_' ||ROW_NUMBER() OVER () AS commission_id
    'calculado' AS estado
    ,id_mes_pr AS id_mes
    ,DEALER.agrupacion_canal
    ,DEALER.canal
    ,CASE WHEN VENTAS.service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          WHEN VENTAS.service_type = 'INTERNET' THEN 'A - Servicio Fijo'
    END AS concepto
    ,'UPFR' AS tipo_concepto
    ,1 AS unidades
    ,CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO AS comision
    ,DEALER.id_comisionista
    ,DEALER.distribuidor
    ,VENTAS.sfid_id
    ,VENTAS.seller
    ,DEALER.nombre_comercio
    ,DEALER.razon_social
    ,DEALER.cif
    ,DEALER.zona_fiscal
    ,VENTAS.marca
    ,VENTAS.service_type
    ,VENTAS.phone_nm
    ,VENTAS.tariff_id
    ,VENTAS.tariff_ds
    ,VENTAS.service_id
    ,VENTAS.account_id
    ,VENTAS.customer_id
    ,VENTAS.line_type_ds
    ,VENTAS.bundle_type
    ,VENTAS.technology_ds
    ,VENTAS.billing_type_ds
    ,VENTAS.sale_date
    ,VENTAS.activation_date
    ,COALESCE(VENTAS.deactivation_date, VENTAS.cancellation_day_id) AS deactivation_date
    ,VENTAS.order_id
    ,VENTAS.order_type_agg
    ,cod_segmento
    ,cod_marca
    ,cod_tipo_contrato
    ,cod_producto
    ,VENTAS.cod_canal
    ,CAMP.campaign AS campaign_code
    ,CAST(NULL AS STRING) AS serial_number
    ,CAST(NULL AS FLOAT64) AS tax_base
    ,CAST(NULL AS STRING) AS claim_code
    ,CAST(NULL AS STRING) AS process_code
    ,VENTAS.comments
    ,'C_MANUAL' AS facturador
    , PONDERACIONES.ESTADO AS ESTADO_LINEA
    , PONDERACIONES.cancellation_day_id

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON VENTAS.sfid_id = DEALER.id_comisionista
 OR VENTAS.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista

  
LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
-- LEFT JOIN `mm-commissions-reporting.TEMP.ventas_base_outbound_ponderaciones` PONDERACIONES
ON VENTAS.phone_nm = CAST(PONDERACIONES.PHONE_NM AS STRING)
 AND VENTAS.service_id = PONDERACIONES.SERVICE_ID

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON PONDERACIONES.MARCA_CANAL = UNITARIO.MARCA
 AND DEALER.ID_COMISIONISTA = UNITARIO.SFID
 AND UNITARIO.MES = id_mes_pr

WHERE CAMP.campaign IN (
'COLD CALLING CAPTA SOHO',
'COLD CALLING CARTERA SOHO',
'COLD CALLING CAPTA RES',
'COLD CALLING CAPTA RES T EXTERNOS',
'COLD CALLING CAPTA RES NEW',
'COLD CALLING CAPTACION IA'


)

AND VENTAS.service_type IN ( 'INTERNET')
AND VENTAS.MARCA IN ('ORANGE')
AND PONDERACIONES.service_type IN ('BROADBAND')
AND PONDERACIONES.PRODUCTO = 'VENTA NETA'
-- AND VENTAS.sale_date BETWEEN '2026-08-01' AND '2026-08-31'
AND CAST(FORMAT_DATE('%Y%m', VENTAS.sale_date) AS INT64) = id_mes_pr



UNION ALL
--- POSPAGO MOVIL ORANGE RFB ---

SELECT 
    -- prefijo || '_' || mes_string || '_' || b.canal || '_' ||ROW_NUMBER() OVER () AS commission_id
    'calculado' AS estado
    ,id_mes_pr AS id_mes
    ,DEALER.agrupacion_canal
    ,DEALER.canal
    ,CASE WHEN VENTAS.service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
          WHEN VENTAS.service_type = 'INTERNET' THEN 'A - Servicio Fijo'
    END AS concepto
    ,'UPFR' AS tipo_concepto
    ,1 AS unidades
    ,CASE WHEN PONDERACIONES.DE_PRODUCTO_MR LIKE '%CON_TERMINAL%' THEN (CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO)/1.5 * 1
    ELSE CAST(REPLACE(PONDERACIONES.PONDERACION,',','.')AS FLOAT64) * UNITARIO.UNITARIO
    END AS comision ---CORREGIMOS CASOS ORANGE CON TERMINAL, YA QUE EL DISPOSITIVO DEBE ABONARSE EN CONCEPTO D - Dispositivo Captacion en 0.5 pts 
    ,DEALER.id_comisionista
    ,DEALER.distribuidor
    ,VENTAS.sfid_id
    ,VENTAS.seller
    ,DEALER.nombre_comercio
    ,DEALER.razon_social
    ,DEALER.cif
    ,DEALER.zona_fiscal
    ,VENTAS.marca
    ,VENTAS.service_type
    ,VENTAS.phone_nm
    ,VENTAS.tariff_id
    ,VENTAS.tariff_ds
    ,VENTAS.service_id
    ,VENTAS.account_id
    ,VENTAS.customer_id
    ,VENTAS.line_type_ds
    ,VENTAS.bundle_type
    ,VENTAS.technology_ds
    ,VENTAS.billing_type_ds
    ,VENTAS.sale_date
    ,VENTAS.activation_date
    ,COALESCE(VENTAS.deactivation_date, VENTAS.cancellation_day_id) AS deactivation_date
    ,VENTAS.order_id
    ,VENTAS.order_type_agg
    ,cod_segmento
    ,cod_marca
    ,cod_tipo_contrato
    ,cod_producto
    ,VENTAS.cod_canal
    ,CAMP.campaign AS campaign_code
    ,CAST(NULL AS STRING) AS serial_number
    ,CAST(NULL AS FLOAT64) AS tax_base
    ,CAST(NULL AS STRING) AS claim_code
    ,CAST(NULL AS STRING) AS process_code
    ,VENTAS.comments
    ,'C_MANUAL' AS facturador
    , PONDERACIONES.ESTADO AS ESTADO_LINEA
    , PONDERACIONES.cancellation_day_id

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON VENTAS.sfid_id = DEALER.id_comisionista
 OR VENTAS.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` CAMP
ON DEALER.id_comisionista = CAMP.id_comisionista

  
LEFT JOIN `mm-sales-reporting.SPEEDUP.query_seguimiento_campaigns_outbound_ponderaciones` PONDERACIONES
-- LEFT JOIN `mm-commissions-reporting.TEMP.ventas_base_outbound_ponderaciones` PONDERACIONES
ON VENTAS.phone_nm = CAST(PONDERACIONES.PHONE_NM AS STRING)
 AND VENTAS.service_id = PONDERACIONES.SERVICE_ID

LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIO
ON PONDERACIONES.MARCA_CANAL = UNITARIO.MARCA
 AND DEALER.ID_COMISIONISTA = UNITARIO.SFID
 AND UNITARIO.MES = id_mes_pr

WHERE CAMP.campaign IN (
'COLD CALLING CAPTA SOHO',
'COLD CALLING CARTERA SOHO',
'COLD CALLING CAPTA RES',
'COLD CALLING CAPTA RES T EXTERNOS',
'COLD CALLING CAPTA RES NEW',
'COLD CALLING CAPTACION IA'


)

AND VENTAS.service_type IN ( 'MOBILE')
AND VENTAS.MARCA IN ('ORANGE')
AND PONDERACIONES.service_type IN ('MOBILE')
AND PONDERACIONES.PRODUCTO = 'RFB'
-- AND VENTAS.activation_date BETWEEN '2026-08-01' AND '2026-08-31'
AND CAST(FORMAT_DATE('%Y%m', VENTAS.activation_Date) AS INT64) = id_mes_pr



)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_comisiones_final_outbound_OSP` AS (
SELECT  'ACTIOUT' || '_' || id_mes_pr || '_' ||canal || '_' ||ROW_NUMBER() OVER () AS commission_id
,* 
FROM `mm-commissions-reporting.TEMP.base_comisiones_outbound_OSP`
WHERE COMISION IS NOT NULL
  AND COMISION > 0
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY
    canal,
    marca,
    service_type,
    concepto,
    tariff_id,
    tariff_ds,
    phone_nm,
    service_id
) = 1
)
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('ACTIOUT', 202609, ['OSPNXSN','OSPNOUN'], 'TEMP.base_comisiones_final_outbound_OSP', 'ACTUALIZAR');

-- CALL `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`(FALSE);

-- CALL `mm-commissions-reporting.COMISIONES.pr_check_ventas_base_prueba`(FALSE);

END