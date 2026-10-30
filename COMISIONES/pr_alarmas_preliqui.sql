BEGIN

DECLARE prefijo,mes_string STRING;

DECLARE Y_atakam,Y_madison,M_madison,M_bemore, OSP_Orange_alarmas INT64;

SET Y_atakam = 21232;

-- SET Y_madison = 0; (EN SEPTIEMBRE DEJARON DE VENDER)

SET M_madison = 22816;

--SET M_bemore = 12800;

SET OSP_Orange_alarmas = 36800; --- CAMPAÑA OUT ALARMAS ORANGE QUE SE PAGA POR PRECIO HORA SOLO EN ALARMAS

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'ALRM';

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo);

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','D2D','D2N','DO','OU','ENK','EML','EYG','WA','XI','XO','XOF','XS','CIN'];

END IF;


-- CALL COMISIONES.pr_alarmas_preliqui (202608, ['ALTN'], 'DAILY');


---- B - Alarmas

CREATE OR REPLACE TABLE TEMP.alarmas_activaciones_preliqui AS (
  SELECT
  'ALRMB'||'_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
  ,'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,DEALER.agrupacion_canal
  ,DEALER.canal
  ,'B - Alarmas' AS concepto
  ,'ALRM' AS tipo_concepto
  ,1 AS unidades
  ,CASE


     -- D2D

     WHEN DEALER.canal IN ('D2N','D2D','DEM')             THEN 400


     -- Exclusivo  

     WHEN DEALER.canal IN ('EML','EYG')                          THEN 150
     WHEN DEALER.canal IN ('ENK') 
          AND VENTAS.request_date < '2026-04-20' 
          AND SVA.sva_modality = 'ALARMA ADT'                    THEN 150
     WHEN DEALER.canal IN ('ENK') 
          AND VENTAS.request_date >= '2026-04-20' 
          AND SVA.sva_modality = 'ALARMA VERISURE'               THEN 200

     -- No Exclusivo  

     WHEN DEALER.canal IN ('ALTN')                               THEN 150
     WHEN DEALER.canal = 'PH'                                    THEN 125
  
     -- TLV - DO

     WHEN DEALER.canal = 'DO'                                     THEN 270

     -- TLV - OU

     WHEN DEALER.canal = 'OU' and DEALER.sfid_id = "TLVOU001"     THEN 240

     -- TLV - Cross-sell IN

     WHEN DEALER.canal IN ('XI','XO','XOF')                        THEN 50

     -- TLV / TLVN - Inbound Captacion

     WHEN DEALER.canal = 'CIN' and DEALER.sfid_id in ('TLVNI001', 'TLVNO006', 'TLVNO005')   THEN 50
     WHEN DEALER.canal = 'WA'                                                               THEN 50
     WHEN DEALER.canal = 'DON'                                                              THEN 50
     WHEN DEALER.canal = 'OSPNIN'                                                           THEN 50

     WHEN DEALER.canal = 'XSO' AND TLV_CROSS_SELL.campaign IN ('MULTIPRODUCTO GENERICA','MULTIPRODUCTO TERMINAL','XSELLING ORANGE') THEN 60
     WHEN DEALER.canal = 'XSO' AND VENTAS.sfid_id ='19140646'  
          THEN ROUND (OSP_Orange_alarmas/(SELECT COUNT(sfid_id) 
                                 FROM `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
                                 WHERE DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
                                 AND VENTAS.sfid_id ='19140646' ),2)
     -- TLV - Cross-sell OUT
    -- MM Madison
     WHEN DEALER.canal = 'XS' AND VENTAS.canal2 = 'OUTBOUND CARTERA'  AND LOWER(VENTAS.seller) LIKE '%_al%' AND VENTAS.sfid_id IN ('CARIN008','CAROUT016') 
          THEN ROUND (M_madison/(SELECT COUNT(sfid_id) 
                                 FROM `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
                                 WHERE DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
                                 AND canal2 = 'OUTBOUND CARTERA'  AND LOWER(seller) LIKE '%_al%' AND sfid_id IN ('CARIN008','CAROUT016')),2)

    -- MM Bemore
    WHEN DEALER.canal = 'XS' AND VENTAS.canal2 = 'OUTBOUND CARTERA'  AND LOWER(VENTAS.seller) LIKE '%_al%' AND VENTAS.sfid_id IN ('CAROUT010','CAROUT023') 
          THEN ROUND (M_bemore/(SELECT COUNT(sfid_id) 
                                 FROM `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
                                 WHERE DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
                                 AND canal2 = 'OUTBOUND CARTERA'  AND LOWER(seller) LIKE '%_al%' AND sfid_id IN ('CAROUT010','CAROUT023')),2)
    
    -- Yoigo Madison
    WHEN DEALER.canal = 'XS' AND VENTAS.canal2 = 'OUTBOUND CARTERA'  AND VENTAS.sfid_id IN ('CARIN008','CAROUT016') AND VENTAS.brand_ds = 'YOIGO'
          THEN ROUND (Y_madison/(SELECT COUNT(sfid_id) 
                                 FROM `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
                                 WHERE DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
                                 AND canal2 = 'OUTBOUND CARTERA'  AND sfid_id IN ('CARIN008','CAROUT016') AND brand_ds = 'YOIGO'),2)
    
    -- Yoigo Atakam
    WHEN DEALER.canal = 'XS' AND VENTAS.canal2 = 'OUTBOUND CARTERA'  AND VENTAS.sfid_id IN ('CAROUT008','CAROUT027')
      THEN ROUND (Y_atakam/(SELECT COUNT(sfid_id) 
                              FROM `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
                              WHERE DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
                              AND canal2 = 'OUTBOUND CARTERA'  AND sfid_id IN ('CAROUT008','CAROUT027')),2)

    END AS comision

  ,DEALER.id_comisionista
  ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
  ,DEALER.sfid_id
  ,UPPER(SPLIT(VENTAS.seller, "@")[OFFSET(0)]) AS seller
  ,DEALER.nombre_comercio
  ,DEALER.razon_social
  ,DEALER.cif
  ,DEALER.zona_fiscal
  ,VENTAS.brand_ds AS marca
  ,'SECURITY' AS service_type
  ,CAST(VENTAS.phone_nm AS STRING) AS phone_nm
  ,CAST(NULL AS STRING) AS tariff_id
  ,VENTAS.kit AS tariff_ds
  ,VENTAS.service_id
  ,VENTAS.installation_contract AS account_id
  ,VENTAS.customer_id
  ,CAST(NULL AS STRING) AS line_type_ds
  ,CAST(NULL AS STRING) AS bundle_type
  ,CAST(NULL AS STRING) AS technology_ds
  ,CAST(NULL AS STRING) AS billing_type_ds
  ,VENTAS.request_date AS sale_date
  ,VENTAS.installation_date AS activation_date
  ,VENTAS.fecha_baja_contrato AS deactivation_date
  ,CAST(NULL AS STRING) AS order_id
  ,CAST(NULL AS STRING) AS order_type_agg
  ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(VENTAS.segment_ds,VENTAS.brand_ds) AS cod_segmento
  ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(VENTAS.brand_ds) AS cod_marca
  ,'99' AS cod_tipo_contrato
  ,'012' AS cod_producto
  ,AGRUPACION.codigo_canal_sap AS cod_canal
  ,TLV_CROSS_SELL.campaign AS campaign_code
  ,CAST (NULL AS STRING) AS serial_number
  ,CAST(NULL AS FLOAT64) AS tax_base
  ,CAST(NULL AS STRING) AS claim_code
  ,CAST(NULL AS STRING) AS process_code
  ,CAST(NULL AS STRING) AS comments
  ,'C_MANUAL' AS facturador
  ,`mm-commissions-reporting.COMISIONES.f_sociedad`(COALESCE(SVA.brand_ds,'PEPEPHONE')) AS sociedad 

FROM  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` VENTAS

LEFT JOIN `mm-soho-reporting.TEMPORALES_SOHO.sva_unificado` SVA
        ON SVA.contract_id = VENTAS.installation_contract
        AND SVA.sva_modality IN ('ALARMA ADT','ALARMA VERISURE')

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(SVA.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND SVA.master_channel_ds = AGRUPACION.master_channel_ds
            AND SVA.channel_ds = AGRUPACION.channel_ds
            AND SVA.subchannel_ds = AGRUPACION.subchannel_ds
            AND SVA.brand_ds = AGRUPACION.comm_brand_ds

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (
            REPLACE(VENTAS.sfid_id, 'LB', '') = DEALER.sfid_id
            OR UPPER(SPLIT(VENTAS.seller, '@')[0]) = DEALER.sfid_id
            OR VENTAS.user_store = DEALER.sfid_id
            OR VENTAS.sfid_id || '-' || VENTAS.seller = REPLACE(DEALER.sfid_id, ' ', '')
            )
            AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista 
         AND DEALER.canal = TLV_CROSS_SELL.canal

         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DEALER.canal = canal_pr
AND DATE_TRUNC(DATE(VENTAS.installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
AND DEALER.sfid_id IS NOT NULL
AND (
    VENTAS.brand_ds IN ('MASMOVIL','YOIGO')
    OR (
        DEALER.CANAL IN ('ALTN','DO','WA','XI','XO','OSPNIN')
        AND VENTAS.brand_ds IN ('MASMOVIL','YOIGO','ORANGE','JAZZTEL','SIMYO')
    )
)
QUALIFY ROW_NUMBER() OVER (PARTITION BY VENTAS.installation_contract ORDER BY DEALER.sfid_id, VENTAS.request_date  DESC) = 1)
;


--- FACTOR SEGMENTACIÓN LIGA (SOLO D2D) ---

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN
UPDATE `mm-commissions-reporting.TEMP.alarmas_activaciones_preliqui` v
SET comision = v.comision * f.porcentaje
FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
WHERE v.cif = f.cif
  AND f.id_mes = id_mes_pr
  AND v.activation_date >= '2026-07-01'
  AND v.estado = 'calculado'
  AND v.canal IN ('D2D','D2N','DEM');
END IF;


CREATE OR REPLACE TABLE TEMP.alarmas_gestion_canal_preliqui AS (SELECT
     'ALRMF'||'_'|| mes_string ||'_'|| ACTIVACIONES.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,ACTIVACIONES.estado
     ,ACTIVACIONES.mes_liquidado
     ,ACTIVACIONES.id_mes
     ,ACTIVACIONES.agrupacion_canal
     ,ACTIVACIONES.canal
     ,REPLACE(ACTIVACIONES.concepto, 'B - ', 'F - Gestion Canal ') AS concepto
     ,ACTIVACIONES.tipo_concepto
     ,ACTIVACIONES.unidades

     ,case 

     -- Exclusivo  
     -- when ACTIVACIONES.canal = 'EML' THEN 5
     -- when ACTIVACIONES.canal = 'EYG' THEN 5
     -- when ACTIVACIONES.canal = 'ENX' THEN 5

     -- No Exclusivo  
    
     when ACTIVACIONES.canal = 'ALTN' THEN 50
    
     end as comision

     ,COALESCE(MASTER.id_comisionista, ACTIVACIONES.id_comisionista) AS id_comisionista
     ,ACTIVACIONES.distribuidor
     ,ACTIVACIONES.sfid_id
     ,ACTIVACIONES.seller
     ,COALESCE(MASTER.nombre_comercio, ACTIVACIONES.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, ACTIVACIONES.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, ACTIVACIONES.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, ACTIVACIONES.zona_fiscal) AS zona_fiscal
     ,ACTIVACIONES.marca
     ,ACTIVACIONES.service_type
     ,ACTIVACIONES.phone_nm
     ,ACTIVACIONES.tariff_id
     ,ACTIVACIONES.tariff_ds
     ,ACTIVACIONES.service_id
     ,ACTIVACIONES.account_id
     ,ACTIVACIONES.customer_id
     ,ACTIVACIONES.line_type_ds
     ,ACTIVACIONES.bundle_type
     ,ACTIVACIONES.technology_ds
     ,ACTIVACIONES.billing_type_ds
     ,ACTIVACIONES.sale_date
     ,ACTIVACIONES.activation_date
     ,ACTIVACIONES.deactivation_date
     ,ACTIVACIONES.order_id
     ,ACTIVACIONES.order_type_agg
     ,ACTIVACIONES.cod_segmento
     ,ACTIVACIONES.cod_marca
     ,ACTIVACIONES.cod_tipo_contrato
     ,ACTIVACIONES.cod_producto
     ,ACTIVACIONES.cod_canal
     ,ACTIVACIONES.campaign_code
     ,ACTIVACIONES.serial_number
     ,ACTIVACIONES.tax_base
     ,ACTIVACIONES.claim_code
     ,ACTIVACIONES.process_code
     ,ACTIVACIONES.comments
     ,ACTIVACIONES.facturador
     ,ACTIVACIONES.sociedad
FROM `mm-commissions-reporting.TEMP.alarmas_activaciones_preliqui` ACTIVACIONES

  LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
    ON ACTIVACIONES.distribuidor = MASTER.id_comisionista

WHERE ACTIVACIONES.canal IN ('ALTN')
    AND ACTIVACIONES.distribuidor IS NOT NULL

)
;

--------------------------------
---- D - Rappel alarma (Xsell)
--------------------------------

-- CREATE OR REPLACE TABLE TEMP.rappel_alarmas_preliqui AS (SELECT
--      'ALRMD'||'_'|| mes_string ||'_'|| canal ||'_'||ROW_NUMBER () OVER () AS commission_id
--      ,estado
--      ,mes_liquidado
--      ,id_mes
--      ,agrupacion_canal
--      ,canal
--      ,'D - Rappel alarma' AS concepto
--      ,tipo_concepto
--      ,unidades

--      ,CASE
 
--       WHEN sfid_id = 'CAROUT016'       AND marca = 'MASMOVIL'  THEN 70 -- MM Madison
     
--       --WHEN sfid_id = 'CAROUT023'       AND marca = 'MASMOVIL'  THEN 100  -- MM Bemore
 
--       WHEN sfid_id = 'CAROUT027'       AND marca = 'YOIGO'     THEN 90 -- Yoigo Atakam
      
--       WHEN sfid_id = '19140646'                                THEN 100 ---CAMPAÑA ALARMAS ORANGE XSO
          
--      END AS comision

--      ,id_comisionista
--      ,distribuidor
--      ,sfid_id
--      ,seller
--      ,nombre_comercio
--      ,razon_social
--      ,cif
--      ,zona_fiscal
--      ,marca
--      ,service_type
--      ,phone_nm
--      ,tariff_id
--      ,tariff_ds
--      ,service_id
--      ,account_id
--      ,customer_id
--      ,line_type_ds
--      ,bundle_type
--      ,technology_ds
--      ,billing_type_ds
--      ,sale_date
--      ,activation_date
--      ,deactivation_date
--      ,order_id
--      ,order_type_agg
--      ,cod_segmento
--      ,cod_marca
--      ,cod_tipo_contrato
--      ,cod_producto
--      ,cod_canal
--      ,campaign_code
--      ,serial_number
--      ,tax_base
--      ,claim_code
--      ,process_code
--      ,comments
--      ,facturador
--      ,sociedad
-- FROM `mm-commissions-reporting.TEMP.alarmas_activaciones_preliqui`
-- WHERE CANAL IN ('XS','XSO')
-- )

-- ;

-- ------------------------------------------------
-- -- D - Incentivo Tactico Alarmas (Exclusivo)
-- ------------------------------------------------

-- CREATE OR REPLACE TABLE TEMP.incentivo_tactico_alarmas_preliqui AS

-- SELECT 
--      'ALRMC'||'_'|| mes_string ||'_'|| ACTIVACIONES.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
--      ,ACTIVACIONES.estado
--      ,ACTIVACIONES.mes_liquidado
--      ,ACTIVACIONES.id_mes
--      ,ACTIVACIONES.agrupacion_canal
--      ,ACTIVACIONES.canal
--      ,'D - Incentivo Tactico Alarmas' AS concepto
--      ,ACTIVACIONES.tipo_concepto
--      ,ACTIVACIONES.unidades
--      ,INCENTIVO.importe_alarmas AS comision
--      ,ACTIVACIONES.id_comisionista
--      ,ACTIVACIONES.distribuidor
--      ,ACTIVACIONES.sfid_id
--      ,ACTIVACIONES.seller
--      ,ACTIVACIONES.nombre_comercio
--      ,ACTIVACIONES.razon_social
--      ,ACTIVACIONES.cif
--      ,ACTIVACIONES.zona_fiscal
--      ,ACTIVACIONES.marca
--      ,ACTIVACIONES.service_type
--      ,ACTIVACIONES.phone_nm
--      ,ACTIVACIONES.tariff_id
--      ,ACTIVACIONES.tariff_ds
--      ,ACTIVACIONES.service_id
--      ,ACTIVACIONES.account_id
--      ,ACTIVACIONES.customer_id
--      ,ACTIVACIONES.line_type_ds
--      ,ACTIVACIONES.bundle_type
--      ,ACTIVACIONES.technology_ds
--      ,ACTIVACIONES.billing_type_ds
--      ,ACTIVACIONES.sale_date
--      ,ACTIVACIONES.activation_date
--      ,ACTIVACIONES.deactivation_date
--      ,ACTIVACIONES.order_id
--      ,ACTIVACIONES.order_type_agg
--      ,ACTIVACIONES.cod_segmento
--      ,ACTIVACIONES.cod_marca
--      ,ACTIVACIONES.cod_tipo_contrato
--      ,ACTIVACIONES.cod_producto
--      ,ACTIVACIONES.cod_canal
--      ,ACTIVACIONES.campaign_code
--      ,ACTIVACIONES.serial_number
--      ,ACTIVACIONES.tax_base
--      ,ACTIVACIONES.claim_code
--      ,ACTIVACIONES.process_code
--      ,ACTIVACIONES.comments
--      ,ACTIVACIONES.facturador
--      ,ACTIVACIONES.sociedad

-- FROM `mm-commissions-reporting.TEMP.alarmas_activaciones_preliqui` ACTIVACIONES

-- LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` INCENTIVO 
--      ON INCENTIVO.id_comisionista = ACTIVACIONES.seller
--      AND INCENTIVO.id_mes = id_mes_pr

-- WHERE ACTIVACIONES.canal = 'ENK'
--      AND INCENTIVO.id_comisionista IS NOT NULL
--      AND INCENTIVO.importe_alarmas > 0
-- GROUP BY ALL
-- HAVING comision > 0.0  

-- ;

------ CLAWBACK -----
 
CREATE OR REPLACE TABLE TEMP.alarmas_clawback_preliqui AS (
  SELECT
  'ALRME'||'_'|| mes_string ||'_'|| TRANSACCIONES.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
  ,'calculado' AS estado
  ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
  ,id_mes_pr AS id_mes
  ,TRANSACCIONES.agrupacion_canal
  ,TRANSACCIONES.canal
  ,CASE WHEN TRANSACCIONES.concepto = 'B - Alarmas'               THEN 'E - Clawback Alarmas' 
        WHEN TRANSACCIONES.concepto = 'F - Gestion Canal Alarmas' THEN 'H - Clawback Gestion de canal alarmas' 
        WHEN TRANSACCIONES.concepto = 'D - Rappel alarma'         THEN 'E - Clawback Rappel alarma' 
     END AS concepto
  ,'ALRM' AS tipo_concepto
  ,1 AS unidades
  ,CASE WHEN TRANSACCIONES.canal in ('D2D','DEM','D2N','DO') THEN TRANSACCIONES.comision *-1 -- EN D2D y DO, clawback del 100%
        ELSE`mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF (VENTAS.fecha_baja_contrato, VENTAS.installation_date, DAY), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision 
   END AS comision
  ,TRANSACCIONES.id_comisionista
  ,TRANSACCIONES.distribuidor
  ,TRANSACCIONES.sfid_id
  ,TRANSACCIONES.seller
  ,TRANSACCIONES.nombre_comercio
  ,TRANSACCIONES.razon_social
  ,TRANSACCIONES.cif
  ,TRANSACCIONES.zona_fiscal
  ,TRANSACCIONES.marca
  ,TRANSACCIONES.service_type
  ,TRANSACCIONES.phone_nm
  ,TRANSACCIONES.tariff_id
  ,TRANSACCIONES.tariff_ds
  ,TRANSACCIONES.service_id
  ,TRANSACCIONES.account_id
  ,TRANSACCIONES.customer_id
  ,TRANSACCIONES.line_type_ds
  ,TRANSACCIONES.bundle_type
  ,TRANSACCIONES.technology_ds
  ,TRANSACCIONES.billing_type_ds
  ,TRANSACCIONES.sale_date
  ,TRANSACCIONES.activation_date
  ,VENTAS.fecha_baja_contrato AS deactivation_date
  ,TRANSACCIONES.order_id
  ,TRANSACCIONES.order_type_agg
  ,TRANSACCIONES.cod_segmento
  ,TRANSACCIONES.cod_marca
  ,TRANSACCIONES.cod_tipo_contrato
  ,TRANSACCIONES.cod_producto
  ,TRANSACCIONES.cod_canal
  ,TRANSACCIONES.campaign_code
  ,CAST (NULL AS STRING) AS serial_number
  ,CAST(NULL AS FLOAT64) AS tax_base
  ,CAST(NULL AS STRING) AS claim_code
  ,CAST(NULL AS STRING) AS process_code
  ,CAST(NULL AS STRING) AS comments
  ,'C_MANUAL' AS facturador
  ,TRANSACCIONES.sociedad 


FROM (
     SELECT * EXCEPT (proceso_sap,id_registro,invoice_id,bp,cuenta_contable,centro_coste,documento_sap,documento_sap_posicion,fecha_contabilizacion,creado,modificado,id_factura_drive,emails_acceso_trazabilidad, cond_pago)
     FROM `mm-commissions-reporting.COMISIONES.transacciones`
     WHERE concepto IN ('B - Alarmas','F - Gestion Canal Alarmas','D - Rappel alarma')

     UNION ALL

     SELECT * 
     FROM `mm-commissions-reporting.TEMP.alarmas_activaciones_preliqui`

     UNION ALL

     SELECT * 
     FROM `mm-commissions-reporting.TEMP.alarmas_gestion_canal_preliqui`
     )TRANSACCIONES

LEFT JOIN  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` VENTAS
     ON TRANSACCIONES.phone_nm = VENTAS.phone_nm 
     AND TRANSACCIONES.account_id = VENTAS.installation_contract
         
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE TRANSACCIONES.canal = canal_pr
     AND DATE_TRUNC(DATE(VENTAS.fecha_baja_contrato), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     AND DATE_DIFF (VENTAS.fecha_baja_contrato, VENTAS.installation_date, DAY)< 180 

QUALIFY ROW_NUMBER() OVER (PARTITION BY VENTAS.installation_contract ORDER BY TRANSACCIONES.sfid_id, VENTAS.request_date  DESC) = 1)


;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('ALRMB', id_mes_pr, canales_pr, 'TEMP.alarmas_activaciones_preliqui', modo);

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('ALRMF', id_mes_pr, canales_pr, 'TEMP.alarmas_gestion_canal_preliqui', modo);

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('ALRMD', id_mes_pr, canales_pr, 'TEMP.rappel_alarmas_preliqui', modo);

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('ALRMC', id_mes_pr, canales_pr, 'TEMP.incentivo_tactico_alarmas_preliqui', modo);

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('ALRME', id_mes_pr, canales_pr, 'TEMP.alarmas_clawback_preliqui', modo);

END