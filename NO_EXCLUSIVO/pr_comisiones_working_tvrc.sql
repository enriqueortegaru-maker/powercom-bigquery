BEGIN

DECLARE mes_ejecucion DATE;
DECLARE clave STRING;

SET clave = 'TVRC';
SET mes_ejecucion = DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH), MONTH);

-- CALL `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_tvrc`(DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -2 MONTH), MONTH));

CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_tvrc` AS

SELECT
      clave || '_NOEX_' || FORMAT_DATE('%Y%m', mes_ejecucion) || '_' || ROW_NUMBER () OVER() AS id_registro
     ,'X001' AS sociedad

     ,COALESCE(CIF.codigo, CASE comisionista
                                WHEN 'CIF PDV'    THEN DEALERS.sfid_unico
                                WHEN 'CIF MASTER' THEN DEALERS.distribuidor
                                WHEN 'CIF GPV'    THEN
                                     CASE 
                                         WHEN DEALERS.cif_gpv = 'B87430658' THEN 'MASTER01'
                                         WHEN DEALERS.cif_gpv = 'B94153343' THEN 'MASTER02'
                                         WHEN DEALERS.cif_gpv = 'B30898027' THEN 'MASTER03'
                                         WHEN DEALERS.cif_gpv = 'B14628440' THEN 'MASTER07'
                                         WHEN DEALERS.cif_gpv = 'E23773369' THEN 'MASTER08'
                                         WHEN DEALERS.cif_gpv = 'B90202623' THEN 'MASTER10'
                                         WHEN DEALERS.cif_gpv = 'B76754894' THEN 'MASTER12'
                                         WHEN DEALERS.cif_gpv = 'B26563676' THEN 'MASTER14'
                                         WHEN DEALERS.cif_gpv = 'B40643389' THEN 'MASTER18'
                                         WHEN DEALERS.cif_gpv = 'B52554821' THEN 'MASTER20'
                                     END 
                           END
              ) AS id_comisionista

     ,'DEA' AS tipo_comisionista

     ,CASE CONCEPTS.comisionista
           WHEN 'CIF PDV'    THEN DEALERS.cif_pdv
           WHEN 'CIF MASTER' THEN DEALERS.cif_master
           WHEN 'CIF GPV'    THEN DEALERS.cif_gpv    
           ELSE UPPER(comisionista)
      END AS CIF
  
     ,COALESCE(zona_fiscal, 'PEN') AS zona_fiscal
     ,tipo_concepto
     ,REPLACE(concepto,'B - ', 'R - ') AS descripcion_concepto
     ,1 AS uds
  
     ,CASE WHEN premium = 1 THEN 35.00 ELSE 15.00 END AS importe_base

     ,'EUR' AS moneda
     ,'C' AS via_pago
     ,'Z001' AS cond_pago
     ,'29' AS cod_canal
     ,'999' AS cod_producto
     ,'99' AS cod_tipo_contrato

     ,CASE
          WHEN UPPER(brand_ds) = 'MASMOVIL'  THEN '05'
          WHEN UPPER(brand_ds) = 'PEPEPHONE' THEN '06'
          WHEN UPPER(brand_ds) = 'GUUK'      THEN '13'
          WHEN UPPER(brand_ds) = 'LLAMAYA'   THEN '04'
          WHEN UPPER(brand_ds) = 'YOIGO'     THEN '01'
          ELSE '99'
      END AS cod_marca

     ,'999' AS cod_operador
     
     ,CASE
          WHEN UPPER(brand_ds) = 'GUUK'    THEN '10'
          WHEN UPPER(brand_ds) = 'LLAMAYA' THEN '10'
          WHEN segment_ds = 'RESIDENCIAL'  THEN '10'
          WHEN segment_ds = 'SOHO'         THEN '12'
          WHEN segment_ds = 'BUSINESS'     THEN '12'
          ELSE '10'
      END AS cod_segmento
   
     ,'C_MANUAL' AS facturador
     ,'R - Recalculo periodo anterior' AS clasificacion_concepto
     ,`mm-commissions-reporting.SANDBOX.f_clasificacion_canales_detalle`(channel_segment_ds, channel_ds, DEALERS.subchannel, SALES.sfid_id, SALES.seller) AS canal
     ,CAST(service_id AS STRING) AS subscription_id
     ,'TV' AS product_type

     ,COALESCE(CASE WHEN bundle_type = 'DESC' THEN 'FMC' ELSE bundle_type END, 'FMC') as bundle_type

     ,CAST(phone_nm AS STRING) AS msisdn
     ,activation_date AS fecha_activacion
     ,CAST(NULL AS DATE) AS fecha_baja
     ,account_id
     ,CAST(customer_id AS STRING) AS customer_id
     ,sfid_id AS sale_dealer
     ,user_store AS tienda
     ,distribuidor
     ,mes_ejecucion AS fecha
     ,'Otros servicios' AS agrupacion_cod_tipo_contrato
     
     ,CASE
          WHEN UPPER(brand_ds) = 'GUUK'    THEN 'Residencial'
          WHEN UPPER(brand_ds) = 'LLAMAYA' THEN 'Residencial'
          WHEN segment_ds = 'RESIDENCIAL'  THEN 'Residencial'
          WHEN segment_ds = 'SOHO'         THEN 'Negocios'
          WHEN segment_ds = 'BUSINESS'     THEN 'Negocios'
          ELSE 'Residencial'
      END AS segmento
      
     ,VENDORS.vendor_name AS razon_social
     ,vendor_name AS nombre_comercio
     ,UPPER(brand_ds) AS marca
     ,CAST(order_id AS STRING) AS order_id
     ,tariff_ds AS product_id
     ,CAST(NULL AS STRING) AS product
     ,user_store AS user_id
     ,CAST(NULL AS STRING) campaign_code
     ,CAST(NULL AS STRING) claim_code
     ,CAST(NULL AS STRING) process_code
     ,CAST(NULL AS STRING) comments

FROM (
     SELECT TV.*
     FROM `mm-commissions-reporting.SANDBOX.v_servicio_television` TV
     LEFT JOIN (
               SELECT *
               FROM `mm-commissions-reporting.REPORTED.comisiones_no_exclusivo_*`
               WHERE DATE_TRUNC(PARSE_DATE('%Y%m%d', _table_suffix), MONTH) = mes_pr
                     AND descripcion_concepto LIKE 'B%Television%'
               ) REPORTED
              ON TV.phone_nm = REPORTED.msisdn
              
     WHERE DATE_TRUNC(TV.activation_date, MONTH) = mes_pr
           AND (TV.deactivation_date IS NULL OR TV.deactivation_date = '9999-12-31')
           AND TV.comisiona LIKE 'Comisiona%'
           AND TV.master_channel_ds IN ('NO EXCLUSIVO')
           AND REPORTED.msisdn IS NULL
     ) SALES

INNER JOIN `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` DEALERS
          ON CASE WHEN LENGTH(SALES.user_store) > 4 AND SALES.user_store <> 'C00001' THEN SALES.user_store
                  WHEN LENGTH(SALES.user_store) = 4 AND SALES.sfid_id <> 'MMS' THEN SALES.sfid_id || '-' || SALES.user_store
                  WHEN SALES.sfid_id = 'MMS' THEN SALES.user_store
                  ELSE SALES.sfid_id
             END = DEALERS.sfid

LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` CONCEPTS
         ON CASE WHEN SALES.premium = 1 THEN 'B - Television Premium'
                 ELSE 'B - Television'
            END = CONCEPTS.concepto

LEFT JOIN `mm-commissions-reporting.SAP.vendor_list` VENDORS
         ON CASE comisionista WHEN 'CIF PDV' THEN DEALERS.cif_pdv
                              WHEN 'CIF MASTER' then DEALERS.cif_master
                              WHEN 'CIF GPV' then DEALERS.cif_gpv
                              ELSE comisionista
            END = VENDORS.tax_code
         
LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.v_detalle_cif` CIF
         ON CASE comisionista WHEN 'CIF PDV' THEN DEALERS.cif_pdv
                              WHEN 'CIF MASTER' then DEALERS.cif_master
                              WHEN 'CIF GPV' then DEALERS.cif_gpv
                              ELSE comisionista
            END = CIF.cif

WHERE comisiona LIKE 'Comi%'
      AND `mm-commissions-reporting.SANDBOX.f_clasificacion_canales`(channel_segment_ds , channel_ds , subchannel_ds) = 'No Exclusivo'
;


CALL `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
 clave
,'NO_EXCLUSIVO.comisiones_working_tvrc'
,'NO_EXCLUSIVO.comisiones_working'
)
;


END