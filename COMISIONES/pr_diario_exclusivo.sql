BEGIN

DECLARE mes_ant INT64;

SET mes_pr = (SELECT CAST(FORMAT_DATE('%Y%m', CURRENT_DATE()) AS INT64));

IF canales_pr IS NULL THEN SET canales_pr = ['EML', 'EYG', 'ENX', 'ENK'];
END IF;

SET mes_liquidado = (SELECT DATE_TRUNC(CURRENT_DATE(), MONTH));
SET mes_ini = (SELECT DATE_TRUNC(CURRENT_DATE(), MONTH));
SET mes_fin = (SELECT LAST_DAY(DATE_TRUNC(CURRENT_DATE(), MONTH)));

-- SET mes_liquidado = (SELECT PARSE_DATE('%Y%m%d',CONCAT(CAST(valor AS STRING),'01')) FROM `mm-commissions-reporting.GS.PARAMETROS` WHERE parametro ='mes_actual');
-- SET mes_ini = (SELECT PARSE_DATE('%Y%m%d',CONCAT(CAST(valor AS STRING),'01')) FROM `mm-commissions-reporting.GS.PARAMETROS` WHERE parametro ='mes_actual');
-- SET mes_fin = (SELECT LAST_DAY(PARSE_DATE('%Y%m%d',CONCAT(CAST(valor AS STRING),'01'))) FROM `mm-commissions-reporting.GS.PARAMETROS` WHERE parametro ='mes_actual');

-- SET mes_ant = CAST(SUBSTR(CAST(DATE_SUB(mes_liquidado, INTERVAL 1 MONTH) AS STRING),1,4)||SUBSTR(CAST(DATE_SUB(mes_liquidado, INTERVAL 1 MONTH) AS STRING),6,2)AS INT64); -- n-1
SET mes_ant = CAST(FORMAT_DATE('%Y%m',DATE_SUB(mes_liquidado, INTERVAL 1 MONTH)) AS INT64); -- n-1

/*
CALL COMISIONES.pr_diario_exclusivo(202609, NULL, '2026-09-01', '2026-09-01', '2026-09-30');
*/



/* ACTUALIZAR ACTIVACIONES */
call `mm-commissions-reporting.COMISIONES.pr_activaciones`(mes_pr);

/* UPDATE TARIFAS CON TRAMO_1 0 O NULL */
CALL COMISIONES.pr_tarifas_exclusivo(mes_pr);

/* CÁLCULO CANALES */
call  COMISIONES.pr_acti_exclusivo (mes_pr, ['EML','EYG','ENX','EDB','ENK'],'DAILY');

/* CÁLCULO TV */
-- CALL COMISIONES.pr_telv (date(mes_liquidado),['EYG', 'EDB', 'EML', 'ENX','ENK']);
CALL COMISIONES.pr_telv_preliqui(DATE(mes_liquidado),['ENK','EML','EYG'],'DAILY');

/* CÁLCULO CALIDAD */
-- ****** ojo antes de lanzar modificar la fecha linea 49 un mes menos del mes en curso.******
-- CALL `mm-commissions-reporting.COMISIONES.pr_cald_exnew`(mes_pr, ['EML','ENX','ENK']);

/*  CÁLCULO AIRTIME - CARTERA 3% Y CARTERA POSPAGO - 3% pdv, 4% distri, 2% bymovil */
-- CALL COMISIONES.pr_cartx(mes_pr);

/* CÁLCULO CARTERA RENUEVO */
-- CALL COMISIONES.pr_carnv(mes_pr,['ENK']);

/* CÁLCULO PLATAFORMAS (STRE) */
-- CALL COMISIONES.pr_stream(mes_pr, ['EML', 'EYG','ENK']);
CALL COMISIONES.pr_stream_preliqui(mes_pr, ['EML', 'EYG','ENK'],'DAILY');

/* CARTERA MP (CALMP) */
-- CALL `mm-commissions-reporting.COMISIONES.pr_calmp`(mes_pr, ['MP']);

/* CÁLCULO CENTRALITAS (CND2) */
-- CALL COMISIONES.pr_centralitas (mes_pr, ['EML','EDB','ENK']);
CALL COMISIONES.pr_centralitas_preliqui (mes_pr, ['EML','ENK'],'DAILY');

/* CÁLCULO ENTREGA EN TIENDA --> A PARTIR DE LIQUI ABRIL 2025 */ 
-- CALL `mm-commissions-reporting.COMISIONES.pr_entrega_tienda`('REAL',mes_pr,mes_liquidado,mes_ini,mes_fin);

/* CÁLCULO AYUDA DIGITAL (CIBER) */
-- CALL COMISIONES.pr_ciberayuda (mes_pr,  ['EML', 'EYG', 'ENK']);
CALL COMISIONES.pr_ciberayuda_preliqui (mes_pr,  ['EML', 'EYG', 'ENK'],'DAILY');

-- ************************************* DEPENDENCIAS *********************************************************

/* CÁLCULO RENUEVOS */
-- CALL COMISIONES.pr_renuevos(mes_pr, ['EYG', 'EDB', 'EML', 'ENX','ENK']);
CALL COMISIONES.pr_renuevos_preliqui(mes_pr, ['EYG', 'EML', 'ENK'],'DAILY');

/* CÁLCULO EXTRACOMISION TERMINAL CAPTA (DCEX) */
CALL COMISIONES.pr_dispositivos_capta_exc(mes_pr,['ENK'],'DAILY');

/* CÁLCULO EXTRACOM DISPOSITIVO FINANCIADO (FINX) */ -- *****DEPENDE DE LO CALCULADO EN RENV*****
-- CALL COMISIONES.pr_financiaciones_exc_nva_categ(mes_pr, ['ENK'], 'DAILY');

/* CÁLCULO ALARMAS */
CALL COMISIONES.pr_alarmas_preliqui (mes_pr, ['ENK','EML'], 'DAILY');

/* CÁLCULO ENERGÍA */
CALL COMISIONES.pr_energia_preliqui (mes_pr, ['ENK','EML'],'DAILY');

/* CÁLCULO GAS */
CALL COMISIONES.pr_gas_preliqui (mes_pr,['ENK','EML'], 'DAILY');

/* CÁLCULO SEGUROS */
CALL COMISIONES.pr_sva_seguros_preliqui (mes_pr,['ENK','EML'], 'DAILY');

/* CÁLCULO SVE */
CALL COMISIONES.pr_SVE_preliqui (mes_pr, ['ENK','EML'], 'DAILY');

/* CÁLCULO SVG */
CALL COMISIONES.pr_SVG_preliqui (mes_pr, ['ENK','EML'], 'DAILY');

/* CÁLCULO REPARTOS */
-- CALL `mm-commissions-reporting.COMISIONES.pr_reex`(mes_pr);

-- ****** REVISAR ZONAS FISCALES ANTES DE LANZAR FACT **********

/* CÁLCULO FACT y EXEX */
-- call COMISIONES.pr_fact (mes_pr, ['EYG', 'EDB', 'EML', 'ENX']);
CALL COMISIONES.pr_fact_preliqui(mes_pr, ['EYG', 'EML'], 'DAILY');
call COMISIONES.pr_extracomisiones_exclusivo (mes_pr, ['ENK'], 'DAILY');

/* CÁLCULO PORTABILIDADES INTERMARCA */ ----------- SIEMPRE DEBE IR DESPUÉS DE EXEX PARA CALCULAR TODO LO QUE SE PODRÁ DECOMISIONAR EN CASO DE PENALIZABLES
-- CALL `mm-commissions-reporting.COMISIONES.pr_pnter`(mes_pr, ['ENK']);

/* CÁLCULO RAPPELS */ 
-- CALL `mm-commissions-reporting.COMISIONES.pr_exrp`(mes_pr);

/* CÁLCULO CESE NEGOCIO (CESE) */
-- CALL COMISIONES.pr_cese_negocio(mes_pr);

-- ************************************************************************************************************

/* CÁLCULO PENALIZACIONES */
-- CALL `mm-commissions-reporting.COMISIONES.pr_pintr`(mes_pr, ['EDB', 'EML', 'EYG','ENX']);

/* CÁLCULO TRY & BUY */
-- CALL COMISIONES.pr_tbex_prueba(mes_pr, NULL, NULL, 0);

/* CÁLCULO CLAWBACKS */
-- call `mm-commissions-reporting.COMISIONES.pr_cbsr` (mes_pr, ['EYG', 'EDB', 'EML', 'ENX','ENK']);
CALL `mm-commissions-reporting.COMISIONES.pr_cbsr_preliqui`(mes_pr, ['EYG', 'EML', 'ENK'],'DAILY');

-- ************************************************************************************************************

/* ACTUALIZACIÓN DATASTUDIO */
-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('mensual');


/****************************************  INFORME   ***********************************/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.preliquidacion_exclusivo` AS 

-- UPFR_PURO TABLA PRELIQUIDACION_TRANSACCIONES MES_PR
SELECT
      TRANSACCIONES.invoice_id
     ,TRANSACCIONES.marca
     
     ,CASE
          WHEN TRANSACCIONES.concepto = 'A - Portabilidad Prepago'                 THEN 'A - Portabilidad Prepago'
          WHEN TRANSACCIONES.concepto = 'E - Renuevo'                              THEN 'E - Clawback Renuevo'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Fijo'                        THEN 'F - Gestion Canal Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Movil Pospago'               THEN 'F - Gestion Canal Servicio Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Movil Prepago'               THEN 'F - Gestion Canal Servicio Movil Prepago'
          WHEN TRANSACCIONES.concepto = 'F - Netflix'                              THEN 'F - Extracomision Netflix'
          WHEN TRANSACCIONES.concepto = 'H - Renuevo'                              THEN 'H - Clawback Gestion Canal Renuevo'
          WHEN TRANSACCIONES.concepto = 'Y - Servicio Fijo'                        THEN 'Y - Ajustes Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'Y - Servicio Movil Pospago'               THEN 'Y - Ajustes Servicio Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'Z - Ajuste Gestion Canal Movil Pospago'   THEN 'Y - Ajuste Gestion Canal Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'Z - Ajuste Gestion Canal Servicio Fijo'   THEN 'Y - Ajuste Gestion Canal Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'H - Clawback Gestion Canal Multisim'      THEN 'H - Clawback Multisim'
          WHEN TRANSACCIONES.concepto = 'Y - Clawback Gestion Canal Servicio Fijo' THEN 'Y - Clawback Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'Y - Clawback Servicio Movil Pospago'      THEN 'Y - Clawback Gestion Canal Servicio Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'Z - Clawback Portabilidad Movil Pospago'  THEN 'Z - Clawback Portabilidad movil'
          WHEN TRANSACCIONES.concepto = 'E - Clawback Extracomision Netflix'       THEN 'E - Clawback Netflix'
          WHEN TRANSACCIONES.concepto = 'H - Clawback Gestion Canal'               THEN 'H - Clawback Gestion de canal alarmas'

          ELSE TRANSACCIONES.concepto
      END concepto
    
     ,TRANSACCIONES.unidades AS unidades
     ,ROUND(TRANSACCIONES.comision, 2) AS comision
     ,CAST(NULL AS STRING) AS imei
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,IF(TRANSACCIONES.deactivation_date = '9999-12-31', NULL, TRANSACCIONES.deactivation_date) AS deactivation_date
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.account_id AS account_id
     ,VENTAS_BASE.contract_id AS contrato
     ,CAST(ICC.iccid AS STRING) AS icc
     ,CAST(NULL AS FLOAT64) AS purchprice
     ,CASE WHEN TRANSACCIONES.comments = 'Penalizacion - Portabilidades Intermarca' THEN 'Portabilidades Intermarca'
           ELSE TRANSACCIONES.claim_code
      END AS claim_code
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,CAST(NULL AS STRING) AS handset
     ,TRANSACCIONES.order_type_agg
     ,CAST(NULL AS STRING) AS referencia_terminal
     ,CAST(NULL AS STRING) AS model_description
     ,CAST(NULL AS STRING) AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     ,TRANSACCIONES.zona_fiscal

     ,CASE
          WHEN TRANSACCIONES.cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN TRANSACCIONES.cod_segmento = '10' THEN 'RESIDENCIAL'
          ELSE VENTAS_BASE.segment_ds
      END AS segment_ds
      
     ,TRANSACCIONES.seller
     ,CAST(NULL AS STRING) AS end_user_price
     ,TRANSACCIONES.billing_type_ds AS billing_type_ds

     ,CASE
          WHEN VENTAS_BASE.sfid_id like 'GENMIG%'          THEN 'MIGRACION'||'-'||VENTAS_BASE.subchannel_ds
          WHEN UPPER(VENTAS_BASE.comments) = 'RETRAMITADA' THEN 'RETRAMITADA'
          WHEN TRANSACCIONES.claim_code IS NOT NULL        THEN COALESCE(VENTAS_BASE.subchannel_ds)||'-'||TRANSACCIONES.claim_code
          ELSE COALESCE(VENTAS_BASE.subchannel_ds, 'MIGRACION')
      END AS order_channel

     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,CAST(NULL AS STRING) AS cups
     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,TRANSACCIONES.service_type
     ,REGEXP_REPLACE(NORMALIZE(VENTAS_BASE.port_in_operator_ds, NFD), r"\pM", '') AS portability_operator_donor
     ,TRANSACCIONES.commission_id
     ,'UPFR_PURO'AS proc_traza
     ,TRANSACCIONES.CANAL as canal
     ,'27' as cod_canal
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_marca
     ,'999' as operador
     , TRANSACCIONES.cod_segmento
     , TRANSACCIONES.tipo_concepto
     , TRANSACCIONES.id_mes AS mes_liquidado


FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT *
          FROM `mm-commissions-reporting.COMISIONES.v_ventas_base`
          QUALIFY RANK() OVER (PARTITION BY phone_nm, brand_ds, sale_date, activation_date, order_type_agg ORDER BY COALESCE(deactivation_date, '9999-12-31') DESC) = 1
          ) VENTAS_BASE
         ON IF(TRANSACCIONES.marca = 'PEPEPHONE', TRANSACCIONES.service_id = VENTAS_BASE.service_id, TRANSACCIONES.phone_nm = CAST(VENTAS_BASE.phone_nm AS STRING))
            AND TRANSACCIONES.account_id = VENTAS_BASE.account_id -- NEW
            AND TRANSACCIONES.customer_id = VENTAS_BASE.customer_id -- NEW
            AND TRANSACCIONES.service_type = VENTAS_BASE.service_type
            AND TRANSACCIONES.marca = VENTAS_BASE.brand_ds
            AND TRANSACCIONES.sale_date = VENTAS_BASE.sale_date
            AND TRANSACCIONES.activation_date = VENTAS_BASE.activation_date
            AND TRANSACCIONES.order_type_agg = VENTAS_BASE.order_type_agg
            AND VENTAS_BASE.activation_date IS NOT NULL

LEFT JOIN (
          SELECT *
          FROM `mm-datamart-kd.SERVICES.personal_icc_base`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, msisdn) = 1
          ) ICC
         ON TRANSACCIONES.service_id = ICC.service_id
            AND TRANSACCIONES.phone_nm = CAST(ICC.msisdn AS STRING)

WHERE TRANSACCIONES.id_mes = mes_pr
      AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND TRANSACCIONES.comision <> 0
      AND TRANSACCIONES.estado <> 'rechazado'
      AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
          IN (
              'Cambio de Titularidad'
             ,'Clawback Cambio de Titularidad'
             ,'Clawback Multisim'
             ,'Clawback Portabilidad Fijo'
             ,'Clawback Portabilidad Movil Pospago'
             ,'Clawback Servicio Fijo'
             ,'Clawback Servicio Fijo 2da Vivienda'
             ,'Clawback Servicio Fijo Cambio de Domicilio'
             ,'Clawback Servicio Fijo Cambio de Tecnologia'
             ,'Clawback Servicio Movil Pospago'
             ,'Multisim'
             ,'Penalizacion Fraude'
             ,'Penalizacion por Duplicado'
             ,'Portabilidad Fijo'
             ,'Portabilidad Movil Pospago'
             ,'Primera Recarga'
             ,'Servicio Fijo'
             ,'Servicio Fijo 2da Vivienda'
             ,'Servicio Fijo Cambio de Domicilio'
             ,'Servicio Fijo Cambio de Tecnologia'
             ,'Servicio Movil Pospago'
             ,'Servicio Movil Prepago'            
             )




UNION ALL


-- UPFR_PURO TABLA TRANSACCIONES MES_ANT
SELECT
      TRANSACCIONES.invoice_id
     ,TRANSACCIONES.marca
     
     ,CASE
          WHEN TRANSACCIONES.concepto = 'A - Portabilidad Prepago'                 THEN 'A - Portabilidad Prepago'
          WHEN TRANSACCIONES.concepto = 'E - Renuevo'                              THEN 'E - Clawback Renuevo'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Fijo'                        THEN 'F - Gestion Canal Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Movil Pospago'               THEN 'F - Gestion Canal Servicio Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Movil Prepago'               THEN 'F - Gestion Canal Servicio Movil Prepago'
          WHEN TRANSACCIONES.concepto = 'F - Netflix'                              THEN 'F - Extracomision Netflix'
          WHEN TRANSACCIONES.concepto = 'H - Renuevo'                              THEN 'H - Clawback Gestion Canal Renuevo'
          WHEN TRANSACCIONES.concepto = 'Y - Servicio Fijo'                        THEN 'Y - Ajustes Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'Y - Servicio Movil Pospago'               THEN 'Y - Ajustes Servicio Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'Z - Ajuste Gestion Canal Movil Pospago'   THEN 'Y - Ajuste Gestion Canal Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'Z - Ajuste Gestion Canal Servicio Fijo'   THEN 'Y - Ajuste Gestion Canal Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'H - Clawback Gestion Canal Multisim'      THEN 'H - Clawback Multisim'
          WHEN TRANSACCIONES.concepto = 'Y - Clawback Gestion Canal Servicio Fijo' THEN 'Y - Clawback Servicio Fijo'
          WHEN TRANSACCIONES.concepto = 'Y - Clawback Servicio Movil Pospago'      THEN 'Y - Clawback Gestion Canal Servicio Movil Pospago'
          WHEN TRANSACCIONES.concepto = 'Z - Clawback Portabilidad Movil Pospago'  THEN 'Z - Clawback Portabilidad movil'
          WHEN TRANSACCIONES.concepto = 'E - Clawback Extracomision Netflix'       THEN 'E - Clawback Netflix'
          WHEN TRANSACCIONES.concepto = 'H - Clawback Gestion Canal'               THEN 'H - Clawback Gestion de canal alarmas'

          ELSE TRANSACCIONES.concepto
      END concepto
    
     ,TRANSACCIONES.unidades AS unidades
     ,ROUND(TRANSACCIONES.comision, 2) AS comision
     ,CAST(NULL AS STRING) AS imei
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,IF(TRANSACCIONES.deactivation_date = '9999-12-31', NULL, TRANSACCIONES.deactivation_date) AS deactivation_date
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.account_id AS account_id
     ,VENTAS_BASE.contract_id AS contrato
     ,CAST(ICC.iccid AS STRING) AS icc
     ,CAST(NULL AS FLOAT64) AS purchprice
     ,CASE WHEN TRANSACCIONES.comments = 'Penalizacion - Portabilidades Intermarca' THEN 'Portabilidades Intermarca'
           ELSE TRANSACCIONES.claim_code
      END AS claim_code
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,CAST(NULL AS STRING) AS handset
     ,TRANSACCIONES.order_type_agg
     ,CAST(NULL AS STRING) AS referencia_terminal
     ,CAST(NULL AS STRING) AS model_description
     ,CAST(NULL AS STRING) AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     ,TRANSACCIONES.zona_fiscal

     ,CASE
          WHEN TRANSACCIONES.cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN TRANSACCIONES.cod_segmento = '10' THEN 'RESIDENCIAL'
          ELSE VENTAS_BASE.segment_ds
      END AS segment_ds
      
     ,TRANSACCIONES.seller
     ,CAST(NULL AS STRING) AS end_user_price
     ,TRANSACCIONES.billing_type_ds AS billing_type_ds

     ,CASE
          WHEN VENTAS_BASE.sfid_id like 'GENMIG%'          THEN 'MIGRACION'||'-'||VENTAS_BASE.subchannel_ds
          WHEN UPPER(VENTAS_BASE.comments) = 'RETRAMITADA' THEN 'RETRAMITADA'
          WHEN TRANSACCIONES.claim_code IS NOT NULL        THEN COALESCE(VENTAS_BASE.subchannel_ds)||'-'||TRANSACCIONES.claim_code
          ELSE COALESCE(VENTAS_BASE.subchannel_ds, 'MIGRACION')
      END AS order_channel

     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,CAST(NULL AS STRING) AS cups
     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,TRANSACCIONES.service_type
     ,REGEXP_REPLACE(NORMALIZE(VENTAS_BASE.port_in_operator_ds, NFD), r"\pM", '') AS portability_operator_donor
     ,TRANSACCIONES.commission_id
     ,'UPFR_PURO'AS proc_traza
     ,TRANSACCIONES.CANAL as canal
     ,'27' as cod_canal
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_marca
     ,'999' as operador
     , TRANSACCIONES.cod_segmento
     , TRANSACCIONES.tipo_concepto
     , TRANSACCIONES.id_mes AS mes_liquidado


FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT *
          FROM `mm-commissions-reporting.COMISIONES.v_ventas_base`
          QUALIFY RANK() OVER (PARTITION BY phone_nm, brand_ds, sale_date, activation_date, order_type_agg ORDER BY COALESCE(deactivation_date, '9999-12-31') DESC) = 1
          ) VENTAS_BASE
         ON IF(TRANSACCIONES.marca = 'PEPEPHONE', TRANSACCIONES.service_id = VENTAS_BASE.service_id, TRANSACCIONES.phone_nm = CAST(VENTAS_BASE.phone_nm AS STRING))
            AND TRANSACCIONES.account_id = VENTAS_BASE.account_id -- NEW
            AND TRANSACCIONES.customer_id = VENTAS_BASE.customer_id -- NEW
            AND TRANSACCIONES.service_type = VENTAS_BASE.service_type
            AND TRANSACCIONES.marca = VENTAS_BASE.brand_ds
            AND TRANSACCIONES.sale_date = VENTAS_BASE.sale_date
            AND TRANSACCIONES.activation_date = VENTAS_BASE.activation_date
            AND TRANSACCIONES.order_type_agg = VENTAS_BASE.order_type_agg
            AND VENTAS_BASE.activation_date IS NOT NULL

LEFT JOIN (
          SELECT *
          FROM `mm-datamart-kd.SERVICES.personal_icc_base`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, msisdn) = 1
          ) ICC
         ON TRANSACCIONES.service_id = ICC.service_id
            AND TRANSACCIONES.phone_nm = CAST(ICC.msisdn AS STRING)

WHERE TRANSACCIONES.id_mes = mes_ant
      AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND TRANSACCIONES.comision <> 0
      AND TRANSACCIONES.estado <> 'rechazado'
      AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
          IN (
              'Cambio de Titularidad'
             ,'Clawback Cambio de Titularidad'
             ,'Clawback Multisim'
             ,'Clawback Portabilidad Fijo'
             ,'Clawback Portabilidad Movil Pospago'
             ,'Clawback Servicio Fijo'
             ,'Clawback Servicio Fijo 2da Vivienda'
             ,'Clawback Servicio Fijo Cambio de Domicilio'
             ,'Clawback Servicio Fijo Cambio de Tecnologia'
             ,'Clawback Servicio Movil Pospago'
             ,'Multisim'
             ,'Penalizacion Fraude'
             ,'Penalizacion por Duplicado'
             ,'Portabilidad Fijo'
             ,'Portabilidad Movil Pospago'
             ,'Primera Recarga'
             ,'Servicio Fijo'
             ,'Servicio Fijo 2da Vivienda'
             ,'Servicio Fijo Cambio de Domicilio'
             ,'Servicio Fijo Cambio de Tecnologia'
             ,'Servicio Movil Pospago'
             ,'Servicio Movil Prepago'            
             )




UNION ALL


-- CARTERA_DETALLADA
SELECT
      TRANSACCIONES.invoice_id
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.concepto
     ,TRANSACCIONES.unidades
     ,CAST(comision AS NUMERIC) AS comision
     ,CAST(NULL AS STRING) AS imei
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.phone_nm
     ,VENTAS_BASE.account_id
     ,VENTAS_BASE.contract_id AS contrato
     ,CAST(ICC.iccid AS STRING) AS icc
     ,CAST(NULL AS FLOAT64) AS purchprice
     ,TRANSACCIONES.claim_code
     ,COALESCE(TRANSACCIONES.tariff_id, VENTAS_BASE.tariff_id) AS tariff_id
     ,COALESCE(TRANSACCIONES.tariff_ds, VENTAS_BASE.tariff_ds) AS tariff_ds
     ,CAST(NULL AS STRING) AS handset
     ,TRANSACCIONES.order_type_agg
     ,CAST(NULL AS STRING) AS referencia_terminal
     ,CAST(NULL AS STRING) AS model_description
     ,CAST(NULL AS STRING) AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     
     ,CASE WHEN TRANSACCIONES.seller IN ('BY414400', 'BY314400','LB152006','LM114400') THEN 'MEL' ELSE TRANSACCIONES.zona_fiscal END AS zona_fiscal

     ,CASE
          WHEN TRANSACCIONES.cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN TRANSACCIONES.cod_segmento = '10' THEN 'RESIDENCIAL'
          ELSE VENTAS_BASE.segment_ds
      END AS segment_ds
      
     ,TRANSACCIONES.seller
     ,CAST(NULL AS STRING) AS end_user_price
     ,TRANSACCIONES.billing_type_ds
     ,CASE
          WHEN VENTAS_BASE.sfid_id like 'GENMIG%'          THEN 'MIGRACION'||'-'||VENTAS_BASE.subchannel_ds
          WHEN UPPER(VENTAS_BASE.comments) = 'RETRAMITADA' THEN 'RETRAMITADA'
          WHEN TRANSACCIONES.claim_code IS NOT NULL        THEN COALESCE(VENTAS_BASE.subchannel_ds)||'-'||TRANSACCIONES.claim_code
          ELSE COALESCE(VENTAS_BASE.subchannel_ds, 'MIGRACION')
      END AS order_channel

     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,CAST(NULL AS STRING) AS cups
     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,TRANSACCIONES.service_type
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,TRANSACCIONES.commission_id
     ,'CARTERA_DETALLADA'AS proc_traza
     ,TRANSACCIONES.CANAL as canal
     ,'27' as cod_canal
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_marca
     ,'999' as operador
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_mes AS mes_liquidado


FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base_net` VENTAS_BASE
         ON TRANSACCIONES.phone_nm = CAST(VENTAS_BASE.phone_nm AS STRING)
            AND TRANSACCIONES.marca = VENTAS_BASE.comm_brand_ds
            AND TRANSACCIONES.billing_type_ds = VENTAS_BASE.billing_type_ds
            AND VENTAS_BASE.activation_date IS NOT NULL

LEFT JOIN (
          SELECT *
          FROM `mm-datamart-kd.SERVICES.personal_icc_base`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, msisdn) = 1
          ) ICC
         ON TRANSACCIONES.service_id = ICC.service_id
            AND TRANSACCIONES.phone_nm = CAST(ICC.msisdn AS STRING)

WHERE TRANSACCIONES.id_mes IN (mes_pr, mes_ant)
      AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND TRANSACCIONES.comision <> 0
      AND TRANSACCIONES.estado <> 'rechazado'
      AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
          IN (
              'Bonus 3 meses'
             ,'Bonus 6 meses'
             ,'Recarga Sucesiva'
             )

QUALIFY RANK() OVER (
                    PARTITION BY TRANSACCIONES.commission_id
                    ORDER BY CASE WHEN TRANSACCIONES.service_id = VENTAS_BASE.service_id THEN 1 ELSE 2 END ASC,
                             CASE WHEN TRANSACCIONES.activation_date = VENTAS_BASE.activation_date THEN 1 ELSE 2 END ASC,
                             CASE WHEN TRANSACCIONES.sale_date = VENTAS_BASE.order_day_id THEN 1 ELSE 2 END ASC,
                             CASE WHEN TRANSACCIONES.activation_date < VENTAS_BASE.activation_date THEN COALESCE(VENTAS_BASE.deactivation_date, '9999-12-31') END ASC,
                             CASE WHEN TRANSACCIONES.activation_date > VENTAS_BASE.activation_date THEN COALESCE(VENTAS_BASE.deactivation_date, '9999-12-31') END DESC
                            ,VENTAS_BASE.sfid_id DESC -- TEMPORAL
                    ) = 1




UNION ALL

-- SVA_EXTRACOM_DETALLADO TABLA PRELIQUIDACION_TRANSACCIONES MES_PR
SELECT 
      TRANSACCIONES.invoice_id
     ,TRANSACCIONES.marca

     ,CASE
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'MASMOVIL' THEN 'B - Devolucion SIM MM y LLY'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'LLAMAYA'  THEN 'B - Devolucion SIM MM y LLY'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'GUUK'     THEN 'B - Devolucion SIM GUUK'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'YOIGO'    THEN 'B - Devolucion SIM YOIGO'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'LEBARA'   THEN 'B - Devolucion SIM LEBARA'
          WHEN TRANSACCIONES.concepto = 'E - Clawback Netflix'                                    THEN 'E - Clawback Extracomision Netflix'
          WHEN TRANSACCIONES.concepto = 'Y - Netflix'                                             THEN 'Y - Extracomision Netflix'
          WHEN TRANSACCIONES.concepto = 'Z - Netflix'                                             THEN 'Z - Extracomision Netflix'
          ELSE TRANSACCIONES.concepto
      END AS concepto
     
     ,TRANSACCIONES.unidades AS unidades
     ,ROUND(TRANSACCIONES.comision, 2) AS comision
     ,TRANSACCIONES.serial_number AS imei
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,IF(TRANSACCIONES.deactivation_date = '9999-12-31', NULL, TRANSACCIONES.deactivation_date) AS deactivation_date
     ,TRANSACCIONES.phone_nm

     ,CASE
          WHEN TRANSACCIONES.concepto IN (
                                         'B - Entrega en tienda'
                                         ,'D - Dispositivo Financiado'
                                         )
               OR (UPPER(TRANSACCIONES.concepto) LIKE '%DEVOLUCION%SIM%' AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%MULTISIM%')
          THEN CAST(NULL AS STRING)
          ELSE TRANSACCIONES.account_id
      END AS account_id
      
     ,CASE 
          WHEN TRANSACCIONES.concepto = 'B - Entrega en tienda'           THEN TRANSACCIONES.account_id
          WHEN TRANSACCIONES.concepto = 'F - Entrega en tienda'           THEN TRANSACCIONES.account_id
          WHEN TRANSACCIONES.concepto LIKE '%Reparacion Terminal (Anovo)' THEN TERMINALES.contract_id
          WHEN TRANSACCIONES.commission_id LIKE 'SEG%'                    THEN TRANSACCIONES.customer_id
          ELSE RENUEVOS.order_id
      END AS contrato

     ,CASE
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%DEVOLUCION%SIM%' AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%MULTISIM%'
          THEN CAST(ICC.iccid AS STRING)
      END AS icc

     ,CAST(NULL AS FLOAT64) AS purchprice

     ,CASE 
          WHEN TRANSACCIONES.commission_id LIKE '%REEX%' AND TRANSACCIONES.claim_code IS NULL THEN TRANSACCIONES.comments
          ELSE TRANSACCIONES.claim_code 
      END AS claim_code

     ,CASE WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' THEN CAST(NULL AS STRING) ELSE TRANSACCIONES.tariff_id END AS tariff_id
     
     ,CASE WHEN TRANSACCIONES.concepto = 'D - Extracomision Terminal Renuevo'                                        THEN TRANSACCIONES.comments 
           WHEN TRANSACCIONES.concepto = 'D - Extracomision terminal' AND TRANSACCIONES.billing_type_ds = 'POSTPAID' THEN TRANSACCIONES.comments 
           ELSE TRANSACCIONES.tariff_ds END AS tariff_ds
  
     ,CASE WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' THEN 'YES' END AS handset

     ,TRANSACCIONES.order_type_agg

     ,CASE
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN LEFT(TRANSACCIONES.tariff_id,40)
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%EXTRACOMISION OBJETIVO TERMINALES' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN RENUEVOS.product_code
          ELSE CAST(NULL AS STRING)
      END AS referencia_terminal
      
     ,CASE
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN RENUEVOS.terminal_name
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%EXTRACOMISION OBJETIVO TERMINALES' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN RENUEVOS.terminal_name
          ELSE CAST(NULL AS STRING)
      END AS model_description

     ,CAST(NULL AS STRING) AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     
     ,TRANSACCIONES.zona_fiscal AS zona_fiscal

     ,CASE
          WHEN TRANSACCIONES.cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN TRANSACCIONES.cod_segmento = '10' THEN 'RESIDENCIAL'
      END AS segment_ds

     ,TRANSACCIONES.seller
     ,CAST(NULL AS STRING) AS end_user_price
     ,TRANSACCIONES.billing_type_ds AS billing_type_ds
     ,CAST(NULL AS STRING) AS order_channel
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type

     ,CASE
          WHEN TRANSACCIONES.concepto IN (
                                          'B - Energia'
                                         ,'B - Gas'
                                         ,'B - SVG'
                                         ,'B - SVE'
                                         ,'D - Extracomision energia'
                                         ,'D - Extracomision SVG'
                                         ,'D - Multiplicador energia'
                                         ,'D - Multiplicador gas'
                                         )
          THEN TRANSACCIONES.account_id
          ELSE CAST(NULL AS STRING)
      END AS cups

     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,CAST(NULL AS STRING) AS service_type
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,TRANSACCIONES.commission_id
     ,'SVA_EXTRACOM_DETALLADO'AS proc_traza
     ,TRANSACCIONES.CANAL as canal
     ,'27' as cod_canal
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_marca
     ,'999' as operador
     , TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_mes AS mes_liquidado


FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT *
          -- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos`
          FROM `mm-commissions-reporting.TEMP.device_base`
          QUALIFY RANK() OVER (
                              PARTITION BY serial_number
                              ORDER BY activation_date DESC,
                                       COALESCE(deactivation_date, '9999-12-31') DESC,
                                       CASE WHEN line_type_ds = 'MAIN' THEN 1 ELSE 2 END ASC,
                                       order_id DESC
                              ) = 1
          ) RENUEVOS
         ON TRANSACCIONES.serial_number = RENUEVOS.serial_number


LEFT JOIN `mm-commissions-reporting.TERMINALES.TERMINALES` TERMINALES
         ON TRANSACCIONES.commission_id = TERMINALES.commission_id

LEFT JOIN (
          SELECT *
          FROM `mm-datamart-kd.SERVICES.personal_icc_base`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, msisdn) = 1
          ) ICC
         ON TRANSACCIONES.service_id = ICC.service_id
            AND TRANSACCIONES.phone_nm = CAST(ICC.msisdn AS STRING)

WHERE TRANSACCIONES.id_mes = mes_pr
      AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND TRANSACCIONES.comision <> 0
      AND TRANSACCIONES.estado <> 'rechazado'
      AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
          IN (
              '2 Recarga Extra Com Tarjeta Lebara'
             ,'Activacion Sims Bono'
             ,'Alarmas'
             ,'Amazon Prime'
             ,'Ayuda Digital'
             ,'Centralitas Base'
             ,'Ciberseguridad'
             ,'Clawback Amazon Prime'
             ,'Clawback Ayuda Digital'
             ,'Clawback Centralitas Base'
             ,'Clawback Ciberseguridad'
             ,'Clawback Disney'
             ,'Clawback Dispositivo Financiado'
             ,'Clawback Extracomision Renuevo Linea Principal'
             ,'Clawback Extracomision Segmentacion'
             ,'Clawback Extracomision terminal'
             ,'Clawback Extracomision Terminal Renuevo'
             ,'Clawback Max'
             ,'Clawback Netflix'
             ,'Clawback Renuevo'
             ,'Clawback Television'
             ,'Clawback Television Premium'
             ,'Devolucion SIM'
             ,'Devolucion SIM Yoigo'
             ,'Devolucion SIM multisim'
             ,'Devolucion SIM Multisim'
             ,'Devolucion sim YOIGO multisim'
             ,'Devolucion SIM Yoigo Multisim'
             ,'Disney'
             ,'Dispositivo Financiado'
             ,'Duplicado SIM'
             ,'Energia'
             ,'Entrega en tienda'
             ,'Extracomision Incentivo Renuevo'
             ,'Extracomision Renuevo Linea Principal'
             ,'Extracomision Segmentacion'
             ,'Extracomision Tactica Renuevo'
             ,'Extracomision terminal'
             ,'Extracomision Terminal Renuevo'
             ,'Gas'
             ,'Max'
             ,'Netflix' 
             ,'Renuevo'
             ,'Seguro Movil'
             ,'Seguro Global Multimedia'
             ,'Seguro Rotura Pantalla'
             ,'SVE'
             ,'SVG'
             ,'Television'
             ,'Television Premium'
             )




UNION ALL

-- SVA_EXTRACOM_DETALLADO TABLA TRANSACCIONES MES_ANT
SELECT 
      TRANSACCIONES.invoice_id
     ,TRANSACCIONES.marca

     ,CASE
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'MASMOVIL' THEN 'B - Devolucion SIM MM y LLY'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'LLAMAYA'  THEN 'B - Devolucion SIM MM y LLY'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'GUUK'     THEN 'B - Devolucion SIM GUUK'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'YOIGO'    THEN 'B - Devolucion SIM YOIGO'
          WHEN TRANSACCIONES.concepto = 'B - Devolucion SIM' AND TRANSACCIONES.marca = 'LEBARA'   THEN 'B - Devolucion SIM LEBARA'
          WHEN TRANSACCIONES.concepto = 'E - Clawback Netflix'                                    THEN 'E - Clawback Extracomision Netflix'
          WHEN TRANSACCIONES.concepto = 'Y - Netflix'                                             THEN 'Y - Extracomision Netflix'
          WHEN TRANSACCIONES.concepto = 'Z - Netflix'                                             THEN 'Z - Extracomision Netflix'
          ELSE TRANSACCIONES.concepto
      END AS concepto
     
     ,TRANSACCIONES.unidades AS unidades
     ,ROUND(TRANSACCIONES.comision, 2) AS comision
     ,TRANSACCIONES.serial_number AS imei
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,IF(TRANSACCIONES.deactivation_date = '9999-12-31', NULL, TRANSACCIONES.deactivation_date) AS deactivation_date
     ,TRANSACCIONES.phone_nm

     ,CASE
          WHEN TRANSACCIONES.concepto IN (
                                         'B - Entrega en tienda'
                                         ,'D - Dispositivo Financiado'
                                         )
               OR (UPPER(TRANSACCIONES.concepto) LIKE '%DEVOLUCION%SIM%' AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%MULTISIM%')
          THEN CAST(NULL AS STRING)
          ELSE TRANSACCIONES.account_id
      END AS account_id
      
     ,CASE 
          WHEN TRANSACCIONES.concepto = 'B - Entrega en tienda'           THEN TRANSACCIONES.account_id
          WHEN TRANSACCIONES.concepto = 'F - Entrega en tienda'           THEN TRANSACCIONES.account_id
          WHEN TRANSACCIONES.concepto LIKE '%Reparacion Terminal (Anovo)' THEN TERMINALES.contract_id
          WHEN TRANSACCIONES.commission_id LIKE 'SEG%'                    THEN TRANSACCIONES.customer_id
          ELSE RENUEVOS.order_id
      END AS contrato

     ,CASE
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%DEVOLUCION%SIM%' AND UPPER(TRANSACCIONES.concepto) NOT LIKE '%MULTISIM%'
          THEN CAST(ICC.iccid AS STRING)
      END AS icc

     ,CAST(NULL AS FLOAT64) AS purchprice

     ,CASE 
          WHEN TRANSACCIONES.commission_id LIKE '%REEX%' AND TRANSACCIONES.claim_code IS NULL THEN TRANSACCIONES.comments
          ELSE TRANSACCIONES.claim_code 
      END AS claim_code

     ,CASE WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' THEN CAST(NULL AS STRING) ELSE TRANSACCIONES.tariff_id END AS tariff_id
     
     ,CASE WHEN TRANSACCIONES.concepto = 'D - Extracomision Terminal Renuevo'                                        THEN TRANSACCIONES.comments 
           WHEN TRANSACCIONES.concepto = 'D - Extracomision terminal' AND TRANSACCIONES.billing_type_ds = 'POSTPAID' THEN TRANSACCIONES.comments 
           ELSE TRANSACCIONES.tariff_ds END AS tariff_ds
  
     ,CASE WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' THEN 'YES' END AS handset

     ,TRANSACCIONES.order_type_agg

     ,CASE
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN LEFT(TRANSACCIONES.tariff_id,40)
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%EXTRACOMISION OBJETIVO TERMINALES' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN RENUEVOS.product_code
          ELSE CAST(NULL AS STRING)
      END AS referencia_terminal
      
     ,CASE
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUEVO%' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN RENUEVOS.terminal_name
          WHEN UPPER(TRANSACCIONES.concepto) LIKE '%EXTRACOMISION OBJETIVO TERMINALES' AND SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('Z', 'Y') THEN RENUEVOS.terminal_name
          ELSE CAST(NULL AS STRING)
      END AS model_description

     ,CAST(NULL AS STRING) AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     
     ,TRANSACCIONES.zona_fiscal AS zona_fiscal

     ,CASE
          WHEN TRANSACCIONES.cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN TRANSACCIONES.cod_segmento = '10' THEN 'RESIDENCIAL'
      END AS segment_ds

     ,TRANSACCIONES.seller
     ,CAST(NULL AS STRING) AS end_user_price
     ,TRANSACCIONES.billing_type_ds AS billing_type_ds
     ,CAST(NULL AS STRING) AS order_channel
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type

     ,CASE
          WHEN TRANSACCIONES.concepto IN (
                                          'B - Energia'
                                         ,'B - Gas'
                                         ,'B - SVG'
                                         ,'B - SVE'
                                         ,'D - Extracomision energia'
                                         ,'D - Extracomision SVG'
                                         ,'D - Multiplicador energia'
                                         ,'D - Multiplicador gas'
                                         )
          THEN TRANSACCIONES.account_id
          ELSE CAST(NULL AS STRING)
      END AS cups

     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,CAST(NULL AS STRING) AS service_type
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,TRANSACCIONES.commission_id
     ,'SVA_EXTRACOM_DETALLADO'AS proc_traza
     ,TRANSACCIONES.CANAL as canal
     ,'27' as cod_canal
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_marca
     ,'999' as operador
     , TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_mes AS mes_liquidado


FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT *
          -- FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos`
          FROM `mm-commissions-reporting.TEMP.device_base`
          QUALIFY RANK() OVER (
                              PARTITION BY serial_number
                              ORDER BY activation_date DESC,
                                       COALESCE(deactivation_date, '9999-12-31') DESC,
                                       CASE WHEN line_type_ds = 'MAIN' THEN 1 ELSE 2 END ASC,
                                       order_id DESC
                              ) = 1
          ) RENUEVOS
         ON TRANSACCIONES.serial_number = RENUEVOS.serial_number


LEFT JOIN `mm-commissions-reporting.TERMINALES.TERMINALES` TERMINALES
         ON TRANSACCIONES.commission_id = TERMINALES.commission_id

LEFT JOIN (
          SELECT *
          FROM `mm-datamart-kd.SERVICES.personal_icc_base`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, msisdn) = 1
          ) ICC
         ON TRANSACCIONES.service_id = ICC.service_id
            AND TRANSACCIONES.phone_nm = CAST(ICC.msisdn AS STRING)

WHERE TRANSACCIONES.id_mes = mes_ant
      AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND TRANSACCIONES.comision <> 0
      AND TRANSACCIONES.estado <> 'rechazado'
      AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
          IN (
              '2 Recarga Extra Com Tarjeta Lebara'
             ,'Activacion Sims Bono'
             ,'Amazon Prime'
             ,'Ayuda Digital'
             ,'Centralitas Base'
             ,'Ciberseguridad'
             ,'Clawback Amazon Prime'
             ,'Clawback Ayuda Digital'
             ,'Clawback Centralitas Base'
             ,'Clawback Ciberseguridad'
             ,'Clawback Disney'
             ,'Clawback Dispositivo Financiado'
             ,'Clawback Extracomision Renuevo Linea Principal'
             ,'Clawback Extracomision Segmentacion'
             ,'Clawback Extracomision terminal'
             ,'Clawback Extracomision Terminal Renuevo'
             ,'Clawback Max'
             ,'Clawback Netflix'
             ,'Clawback Renuevo'
             ,'Clawback Television'
             ,'Clawback Television Premium'
             ,'Devolucion SIM'
             ,'Devolucion SIM Yoigo'
             ,'Devolucion SIM multisim'
             ,'Devolucion SIM Multisim'
             ,'Devolucion sim YOIGO multisim'
             ,'Devolucion SIM Yoigo Multisim'
             ,'Disney'
             ,'Dispositivo Financiado'
             ,'Duplicado SIM'
             ,'Entrega en tienda'
             ,'Extracomision Incentivo Renuevo'
             ,'Extracomision Renuevo Linea Principal'
             ,'Extracomision Segmentacion'
             ,'Extracomision Tactica Renuevo'
             ,'Extracomision terminal'
             ,'Extracomision Terminal Renuevo'
             ,'Max'
             ,'Netflix' 
             ,'Renuevo'
             ,'Television'
             ,'Television Premium'
             )




UNION ALL

-- TERMINALES MES_PR
SELECT 
      invoice_id
     ,marca
     
     ,CASE
          WHEN concepto = 'X - Subsidio Captacion Negativo' THEN 'X - Subsidio Terminal Captacion'
          WHEN concepto = 'X - Subsidio Renuevo Negativo'   THEN 'X - Subsidio Terminal Renuevo'
          ELSE concepto
      END AS concepto
     
     ,unidades
     ,comision
     ,imei
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,phone_nm
     ,account_id
     ,contract_id AS contrato
     ,IMEI AS icc
     ,PURCH_PRICE AS purch_price
     ,claim_code
     ,tariff_id
     ,tariff_ds
     ,'YES' AS handset
     ,order_type_agg
     ,PRODUCT_CODE AS referencia_terminal
     ,TERMINAL_NAME AS model_description
     ,AFTER_SALE AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     ,zona_fiscal
     
     ,CASE
          WHEN cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN cod_segmento = '10' THEN 'RESIDENCIAL'
          ELSE CAST(NULL AS STRING)
      END AS segment_ds
    
     ,seller 
     ,CAST(end_user_price AS STRING) AS end_user_price
     ,billing_type_ds
     ,CAST(NULL AS STRING) AS order_channel
     ,line_type_ds
     ,bundle_type
     ,CAST(NULL AS STRING) AS cups
     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,service_type
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,commission_id
     ,'TERMINALES' AS proc_traza
     ,canal
     ,cod_canal
     ,cod_producto
     ,cod_tipo_contrato
     ,cod_marca
     ,'999' as operador
     ,cod_segmento
     ,tipo_concepto
     ,id_mes AS mes_liquidado

FROM `mm-commissions-reporting.TERMINALES.TERMINALES`  

WHERE id_mes = mes_pr
      AND agrupacion_canal = 'Exclusivo'
      AND process_code = 'DIARIO'
      AND comision <> 0
;




-- TERMINALES N-1

IF EXISTS (SELECT *
           FROM `mm-commissions-reporting.TERMINALES.TERMINALES`
           WHERE process_code = 'REAL'
           AND id_mes = mes_ant) THEN


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_preliquidacion_exclusivo` AS

SELECT 
      TRANSACCIONES.invoice_id
     ,TRANSACCIONES.marca
     
     ,CASE
          WHEN TRANSACCIONES.concepto = 'X - Subsidio Captacion Negativo' THEN 'X - Subsidio Terminal Captacion'
          WHEN TRANSACCIONES.concepto = 'X - Subsidio Renuevo Negativo'   THEN 'X - Subsidio Terminal Renuevo'
          ELSE TRANSACCIONES.concepto
      END AS concepto
     
     ,TRANSACCIONES.unidades
     ,TRANSACCIONES.comision
     ,TRANSACCIONES.serial_number AS imei
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.account_id
     ,TERMINALES.contract_id
     ,CAST(NULL AS STRING) AS icc
     ,TERMINALES.purch_price
     ,TRANSACCIONES.claim_code
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,'YES' AS handset
     ,TRANSACCIONES.order_type_agg
     ,TERMINALES.product_code AS referencia_terminal
     ,TERMINALES.terminal_name AS model_description
     ,TERMINALES.after_sale AS after_sale_description
     ,CAST(NULL AS STRING) AS donor_type
     ,TRANSACCIONES.zona_fiscal
     
     ,CASE
          WHEN TRANSACCIONES.cod_segmento = '12' THEN 'NEGOCIOS'
          WHEN TRANSACCIONES.cod_segmento = '10' THEN 'RESIDENCIAL'
      END AS segment_ds
      
     ,TRANSACCIONES.seller AS sfid  --Modificado OCT/24 Javier González
     ,CAST(TERMINALES.end_user_price AS STRING) AS end_user_price
     ,TRANSACCIONES.billing_type_ds
     ,CAST(NULL AS STRING) AS order_channel
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,CAST(NULL AS STRING) AS cups
     ,CAST(NULL AS STRING) AS operation
     ,CAST(NULL AS STRING) AS nombre_cliente
     ,CAST(NULL AS STRING) AS numero_seguros
     ,CAST(NULL AS STRING) AS fecha_prepago
     ,CAST(NULL AS STRING) AS first_toup
     ,CAST(NULL AS STRING) AS second_toup
     ,CAST(NULL AS STRING) AS third_toup
     ,TRANSACCIONES.service_type
     ,CAST(NULL AS STRING) AS portability_operator_donor
     ,TRANSACCIONES.commission_id
     ,'TERMINALES' AS proc_traza
     ,TRANSACCIONES.CANAL as canal
     ,'27' as cod_canal
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_marca
     ,'999' as operador
     , TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_mes AS mes_liquidado

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TERMINALES.TERMINALES` TERMINALES
        ON  TRANSACCIONES.serial_number = TERMINALES.imei
        AND TRANSACCIONES.concepto = TERMINALES.concepto  --Modificado OCT/24 Javier González para no coger reparaciones, DOAs, etc.

WHERE TRANSACCIONES.id_mes = mes_ant
      AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND TRANSACCIONES.comision <> 0
      AND (TRANSACCIONES.concepto LIKE 'T%' OR TRANSACCIONES.concepto LIKE 'X%')

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.commission_id ORDER BY ABS(TRANSACCIONES.id_mes - TERMINALES.id_mes) ASC) = 1
;
END IF;



IF NOT EXISTS (SELECT *
               FROM `mm-commissions-reporting.TERMINALES.TERMINALES`
               WHERE process_code = 'REAL'
               AND id_mes = mes_ant) THEN

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminales_preliquidacion_exclusivo` AS

SELECT * 
FROM `mm-commissions-reporting.TEMP.preliq_exc_terminales_n-1_no_calculados`
;
END IF;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.preliquidacion_exclusivo` AS 

SELECT *
FROM `mm-commissions-reporting.TEMP.preliquidacion_exclusivo`

UNION ALL

SELECT *
FROM `mm-commissions-reporting.TEMP.terminales_preliquidacion_exclusivo`
;


-- VALIDACIÓN DUPLICADOS
ASSERT NOT EXISTS
(
SELECT DISTINCT commission_id
FROM `mm-commissions-reporting.TEMP.preliquidacion_exclusivo`
WHERE commission_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY commission_id) > 1
) AS 'Hay duplicados en la extracción'
;

-- VALIDACIÓN DISTRIBUIDORES CANARIAS
ASSERT NOT EXISTS
(
SELECT REVISADO.seller
FROM `mm-commissions-reporting.TEMP.preliquidacion_exclusivo` REVISADO
LEFT JOIN `mm-commissions-reporting.GS.exclusivo_canarias` CANARIAS
         ON REVISADO.seller = CANARIAS.matricula
WHERE CANARIAS.matricula IS NOT NULL AND REVISADO.zona_fiscal <> 'CAN'
GROUP BY 1
) AS 'Hay SFIDs de Canarias con la zona_fiscal equivocada'
;

-- VALIDACIÓN CONCEPTOS
-- ASSERT NOT EXISTS
-- (
-- SELECT TRANSACCIONES.concepto
-- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
-- LEFT JOIN `mm-commissions-reporting.TEMP.preliquidacion_exclusivo` REVISADO
--          ON SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto)) = SUBSTR(REVISADO.concepto, 5, LENGTH(REVISADO.concepto))
-- WHERE TRANSACCIONES.id_mes IN (mes_pr,mes_ant) AND TRANSACCIONES.agrupacion_canal = 'Exclusivo' AND REVISADO.concepto IS NULL AND TRANSACCIONES.comision <> 0 AND TRANSACCIONES.estado <> 'rechazado'
--       AND SUBSTR(TRANSACCIONES.concepto, 5, LENGTH(TRANSACCIONES.concepto))
--           NOT IN (
--                   'Devolucion SIM'
--                  ,'Otros'
--                  ,'Rappel Fijo'
--                  ,'Subsidio Captacion Negativo'
--                  ,'Subsidio Renuevo Negativo'
--                  ,'Penalizacion por Duplicado'
--                  ,'Rappel Negocios'
--                  ,'Apoyo Cese Negocio'
--                  ,'Gestion Canal'
--                  ,'Cartera'
--                  ,'Clawback Netflix'
--                  )
-- GROUP BY 1
-- ) AS 'Hay conceptos que no están contemplados en la extracción'
-- ;

END