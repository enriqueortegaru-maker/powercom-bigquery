BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'FACT_OSP';

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES`));

/*
CALL COMISIONES.pr_fact_osp(202609, ['OSPNXSN']);
*/

DROP TABLE TEMP.fact_osp;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.fact_osp`
(
 mes_liquidado               DATE
,id_mes                      INT64
,agrupacion_canal            STRING
,canal                       STRING
,unidades                    INT64
,id_comisionista             STRING
,distribuidor                STRING
,sfid_id                     STRING
,seller                      STRING
,nombre_comercio             STRING
,razon_social                STRING
,cif                         STRING
,zona_fiscal                 STRING
,cond_pago                   STRING
,marca                       STRING
,service_type                STRING
,phone_nm                    STRING
,tariff_id                   STRING
,tariff_ds                   STRING
,service_id                  STRING
,account_id                  STRING
,customer_id                 STRING
,line_type_ds                STRING
,bundle_type                 STRING
,technology_ds               STRING
,billing_type_ds             STRING
,sale_date                   DATE
,activation_date             DATE
,deactivation_date           DATE
,order_id                    STRING
,order_type_agg              STRING
,cod_segmento                STRING
,cod_marca                   STRING
,cod_canal                   STRING
,campaign_code               STRING
,serial_number               STRING
,tax_base                    FLOAT64
,claim_code                  STRING
,process_code                STRING
,proceso_sap                 STRING
,id_registro                 STRING
,invoice_id                  STRING
,sociedad                    STRING
,bp                          STRING
,cuenta_contable             STRING
,centro_coste                STRING
,documento_sap               STRING
,documento_sap_posicion      STRING
,fecha_contabilizacion       STRING
,creado                      TIMESTAMP
,modificado                  TIMESTAMP
,id_factura_drive            STRING
,emails_acceso_trazabilidad  ARRAY<STRING>
,estado                      STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comments                    STRING
,comision                    FLOAT64
,cod_producto                STRING
,cod_tipo_contrato           STRING
)
;

----- D - OTT --- 'TLV - DO'

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DO','WA','XI')) THEN
INSERT INTO TEMP.fact_osp
(

SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto,tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,'D - OTT'  AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE WHEN CANAL = 'DO'         THEN CASE
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige 1%' THEN 5.00
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige 2%' THEN 10.0
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige 3%' THEN 15.0
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige todo%' THEN 20.0
                              END
            WHEN CANAL IN('WA','XI') THEN CASE
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige 1%' THEN 2.00
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige 2%' THEN 4.0
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige 3%' THEN 6.0
                                    WHEN TRANSACCIONES.tariff_ds like '%Elige todo%' THEN 8.0
                              END
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato
     

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto in ('A - Servicio Movil Pospago')
      AND TRANSACCIONES.tariff_ds like '%Sin Límites%Elige%'
      AND TRANSACCIONES.marca = 'ORANGE'
      AND TRANSACCIONES.sale_date < '2026-07-20' --- ANTES DE LEGO


QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY TRANSACCIONES.order_type_agg desc) = 1
) 
;

END IF;

--- EXTRACOMISION EMPRESA D - Extracomision Segmentacion
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('OSPNXSN','XSO')) THEN
INSERT INTO TEMP.fact_osp
(

SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto,tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,'D - Extracomision Segmentacion'  AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE WHEN CANAL IN ('OSPNXSN','XSO') AND CAMPAIGN_CODE IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE') THEN 5
      ELSE 0
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato
     

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto in ('A - Servicio Movil Pospago')
      AND TRANSACCIONES.cod_segmento!='10'
      AND TRANSACCIONES.marca = 'ORANGE'



QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY TRANSACCIONES.order_type_agg desc) = 1
) 
;

END IF;


--- OTT SIMYO NETFLIX ---
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DOT')) THEN
INSERT INTO TEMP.fact_osp
(
SELECT 

    PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
   ,id_mes_pr AS id_mes
   ,DEALER.agrupacion_canal
   ,DEALER.canal
   ,1 AS unidades
   ,DEALER.id_comisionista
   ,DEALER.distribuidor
   ,DEALER.sfid_id
   ,OTT.agent_id AS seller
   ,DEALER.nombre_comercio
   ,DEALER.razon_social
   ,DEALER.cif
   ,DEALER.zona_fiscal
   ,DEALER.cond_pago
   ,OTT.brand_ds AS marca
   ,OTT.service_type
   ,CAST(OTT.phone_nm AS STRING) AS phone_nm
   ,OTT.product_offer_id AS tariff_id
   ,OTT.product_offer_ds AS tariff_ds
   ,OTT.provider_reference AS service_id
   ,VENTAS.account_id
   ,VENTAS.customer_id
   ,VENTAS.line_type_ds
   ,VENTAS.bundle_type
   ,VENTAS.technology_ds
   ,'POSTPAID' AS billing_type_ds
   ,OTT.order_date AS sale_date
   ,OTT.activation_date
   ,VENTAS.deactivation_date
   ,CAST(VENTAS.order_id AS STRING) AS order_id
   ,VENTAS.order_type_agg

   ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`
      (VENTAS.segment_ds, VENTAS.brand_ds) AS cod_segmento

   ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`
      (VENTAS.brand_ds) AS cod_marca

   ,AGRUPACION.codigo_canal_sap AS cod_canal
   ,TLV_CROSS_SELL.campaign AS campaign_code
   ,VENTAS.service_id AS serial_number

   ,CAST(NULL AS FLOAT64) AS tax_base
   ,CAST(NULL AS STRING) AS claim_code
   ,CAST(NULL AS STRING) AS process_code

   ,CAST(NULL AS STRING) AS proceso_sap
   ,CAST(NULL AS STRING) AS id_registro
   ,CAST(NULL AS STRING) AS invoice_id

   ,`mm-commissions-reporting.COMISIONES.f_sociedad`
      (VENTAS.brand_ds) AS sociedad

   ,CAST(NULL AS STRING) AS bp
   ,CAST(NULL AS STRING) AS cuenta_contable
   ,CAST(NULL AS STRING) AS centro_coste
   ,CAST(NULL AS STRING) AS documento_sap
   ,CAST(NULL AS STRING) AS documento_sap_posicion
   ,CAST(NULL AS STRING) AS fecha_contabilizacion

   ,CURRENT_TIMESTAMP() AS creado
   ,CURRENT_TIMESTAMP() AS modificado

   ,CAST(NULL AS STRING) AS id_factura_drive
   ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad

   ,'calculado' AS estado
   ,CONCEPTOS.concepto
   ,CONCEPTOS.tipo_concepto
   ,'C_MANUAL' AS facturador
   ,CAST(NULL AS STRING) AS comments

   ,5.00 AS comision

   ,'006' AS cod_producto

   ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`
      (
       'POSTPAID',
       VENTAS.service_type,
       VENTAS.bundle_type,
       VENTAS.technology_ds,
       VENTAS.brand_ds,
       VENTAS.line_type_ds
      ) AS cod_tipo_contrato
FROM `mm-datamart-kd.TV.service_ott_base_mo` OTT
LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON OTT.brand_ds = VENTAS.marca
 AND OTT.customer_id = VENTAS.customer_id
 AND OTT.account_id = VENTAS.account_id
 AND CAST(OTT.phone_nm AS STRING) = VENTAS.phone_nm

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON OTT.service_type = CONCEPTOS.service_type AND CONCEPTOS.proceso = 'STRE' AND SUBSTR(CONCEPTOS.concepto,1,1) = 'B'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON OTT.sfid_id = DEALER.sfid_id
            AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
         ON DEALER.id_comisionista = TLV_CROSS_SELL.id_comisionista AND DEALER.canal = TLV_CROSS_SELL.canal


LEFT JOIN (SELECT * FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal`, UNNEST(SPLIT(agrupaciones_canal, ',')) agrupacion_canal) AGRUPACION
         ON COALESCE(VENTAS.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
            AND VENTAS.master_channel_ds = AGRUPACION.master_channel_ds
            AND VENTAS.channel_ds = AGRUPACION.channel_ds
            AND VENTAS.subchannel_ds = AGRUPACION.subchannel_ds
            AND VENTAS.brand_ds = AGRUPACION.comm_brand_ds


CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE DATE_TRUNC(OTT.activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      AND OTT.brand_ds = 'SIMYO'
      AND OTT.service_type = 'NETFLIX'
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
)
;

END IF;
/*DESDE JUL26 NO APLICA*/
----- D - Extracomision Fijo --- DOT 
/*
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DOT')) THEN
INSERT INTO TEMP.fact_osp
(

SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto,tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,'D - Extracomision Fijo'  AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
--      ,CASE WHEN TRANSACCIONES.tariff_ds like '%Elige 1%' THEN 10.0
--       WHEN TRANSACCIONES.tariff_ds like '%Elige 2%' THEN 20.0
--       WHEN TRANSACCIONES.tariff_ds like '%Elige 3%' THEN 30.0
--       WHEN TRANSACCIONES.tariff_ds like '%Elige todo%' THEN 40.0
      -- END AS comision
     ,DOT.tramo_2 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato
     

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas` DOT
ON TRANSACCIONES.tariff_id = DOT.tariff_id
 AND TRANSACCIONES.tariff_ds = DOT.tariff_ds
 AND DOT.id_mes = id_mes_pr

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      -- AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto in ('A - Servicio Fijo')
      AND TRANSACCIONES.marca = 'SIMYO'
      AND TRANSACCIONES.canal ='DOT'


QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY TRANSACCIONES.order_type_agg desc) = 1
) 
;
END IF;
*/

--- D - EXTRACOMISION RENUEVO LINEA PRINCIPAL
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('XI','WA','XSO','OSPNXSN')) THEN


INSERT INTO TEMP.fact_osp 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,5.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES


--    LEFT JOIN `mm-datamart-kd.SERVICES.devices_base_osp` DEVICES
--    ON DEVICES.serial_number = TRANSACCIONES.serial_number 
--     AND CAST(DEVICES.phone_nm AS STRING) = TRANSACCIONES.phone_nm


CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND  TRANSACCIONES.canal = canal_pr
      -- AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto IN ('B - Renuevo')
      -- AND TRANSACCIONES.bundle_type = 'FMC'
      AND TRANSACCIONES.comments = 'Primario'
      AND TRANSACCIONES.technology_ds = 'MOVIL'
      AND TRANSACCIONES.line_type_ds = 'MAIN'
      AND CONCEPTOS.concepto = 'D - Extracomision Renuevo Linea Principal'
      -- AND DEVICES.is_financed_desc = 'SI'
      AND ((CANAL IN ('XSO','OSPNXSN') AND CAMPAIGN_CODE IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA','XSELLING ORANGE')) OR CANAL NOT IN ('XSO','OSPNXSN'))
      AND TRANSACCIONES.serial_number NOT IN (
            SELECT serial_number
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE id_mes = id_mes_pr
            AND canal = canal_pr
            AND concepto = 'E - Renuevo'
      )

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.customer_id, TRANSACCIONES.account_id ORDER BY TRANSACCIONES.comision DESC) = 1

)
;



END IF;


--- ALTA SIM A - Alta SIM (MKT_NR)
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('MKT_NR')) THEN
INSERT INTO TEMP.fact_osp
(

SELECT
    PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
   ,id_mes_pr AS id_mes
   ,TRANSACCIONES.agrupacion_canal
   ,TRANSACCIONES.canal
   ,1 AS unidades
   ,TRANSACCIONES.id_comisionista
   ,TRANSACCIONES.distribuidor
   ,TRANSACCIONES.sfid_id
   ,TRANSACCIONES.seller
   ,TRANSACCIONES.nombre_comercio
   ,TRANSACCIONES.razon_social
   ,TRANSACCIONES.cif
   ,TRANSACCIONES.zona_fiscal
   ,'' AS cond_pago
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
   ,TRANSACCIONES.deactivation_date
   ,TRANSACCIONES.order_id
   ,TRANSACCIONES.order_type_agg

   ,TRANSACCIONES.cod_segmento
   ,TRANSACCIONES.cod_marca
   ,TRANSACCIONES.cod_canal
   ,TRANSACCIONES.campaign_code
   ,CAST(NULL AS STRING) AS  serial_number

   ,CAST(NULL AS FLOAT64) AS tax_base
   ,CAST(NULL AS STRING) AS claim_code
   ,CAST(NULL AS STRING) AS process_code

   ,CAST(NULL AS STRING) AS proceso_sap
   ,CAST(NULL AS STRING) AS id_registro
   ,CAST(NULL AS STRING) AS invoice_id

   ,TRANSACCIONES.sociedad

   ,CAST(NULL AS STRING) AS bp
   ,CAST(NULL AS STRING) AS cuenta_contable
   ,CAST(NULL AS STRING) AS centro_coste
   ,CAST(NULL AS STRING) AS documento_sap
   ,CAST(NULL AS STRING) AS documento_sap_posicion
   ,CAST(NULL AS STRING) AS fecha_contabilizacion

   ,CURRENT_TIMESTAMP() AS creado
   ,CURRENT_TIMESTAMP() AS modificado

   ,CAST(NULL AS STRING) AS id_factura_drive
   ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad

     ,'calculado' AS estado
     ,'A - Alta SIM'  AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,4 AS comision

     ,TRANSACCIONES.cod_producto 
     ,TRANSACCIONES.cod_tipo_contrato
     

FROM `mm-commissions-reporting.COMISIONES.activaciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.service_type = 'MOBILE'
      AND TRANSACCIONES.marca = 'SIMYO'



QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY TRANSACCIONES.order_type_agg desc) = 1
) 
;
END IF;

----- B - Bono -- JAZZTEL

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('WA','XI','XSO')) THEN
INSERT INTO TEMP.fact_osp
(

SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto,tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,'B - Bono'  AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE WHEN CANAL = 'XI' THEN 3.00
           WHEN CANAL = 'WA' THEN 5.00
           WHEN CANAL = 'XSO' AND CAMPAIGN_CODE IN ('MULTIPRODUCTO TERMINAL','MULTIPRODUCTO GENERICA')THEN 5.00
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato
     

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.jzz_2102_ventas` JZZ
  ON TRANSACCIONES.order_id = CAST(JZZ.ID_RELACION AS STRING)

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto in ('A - Servicio Fijo')
      AND TRANSACCIONES.marca = 'JAZZTEL'
      AND TRANSACCIONES.bundle_type = '2P'
      AND JZZ.DE_TIPO_BONO_FIJO = 'LLAMADAS A FIJOS Y MOVILES'


QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY TRANSACCIONES.order_type_agg desc) = 1
) 
;

END IF;



CREATE OR REPLACE TABLE TEMP.fact_osp AS
(
SELECT
      *
     ,prefijo || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM TEMP.fact_osp
WHERE comision IS NOT NULL
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr , 'TEMP.fact_osp' , 'ACTUALIZAR');





END