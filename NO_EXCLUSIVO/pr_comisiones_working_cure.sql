BEGIN

declare clave string;

set clave = 'CURE';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_cure` (date_trunc(date_add (current_date (), interval -1 month), month));


CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_cure` AS

SELECT
      'CURE_NOEX_' || FORMAT_DATE('%Y%m', mes_pr) || '_' || ROW_NUMBER () OVER() AS id_registro
     ,'X001' AS sociedad

     ,COALESCE(CIF.codigo, CASE comisionista
                                WHEN 'CIF PDV' THEN DEALERS.sfid_unico
                                WHEN 'CIF MASTER' THEN DEALERS.distribuidor
                                WHEN 'CIF GPV' THEN
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
  
     ,COALESCE(zona_fiscal,'PEN') AS zona_fiscal
     ,tipo_concepto
     ,concepto AS descripcion_concepto
     ,1 as uds
     
     ,CASE
          WHEN subchannel_ds = 'MASPROXIMO' THEN 25.00
      END AS importe_base

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
          ELSE '10' END AS cod_segmento
     
     ,'C_MANUAL' AS facturador
     ,'B - SVA' AS clasificacion_concepto

     ,`mm-commissions-reporting.SANDBOX.f_clasificacion_canales_detalle`(channel_segment_ds, channel_ds, DEALERS.subchannel, SALES.sfid_id, SALES.seller) AS canal
      
     ,CAST(service_id AS STRING) AS subscription_id
     ,'MOBILE' AS product_type
     ,bundle_type
     ,CAST(phone_nm AS STRING) AS msisdn
     ,activation_date AS fecha_activacion
     ,CAST(NULL AS DATE) AS fecha_baja
     ,account_id
     ,CAST(customer_id AS STRING) AS customer_id
     ,sfid_id AS sale_dealer
     ,user_store as tienda
     ,distribuidor
     ,mes_pr AS fecha
  
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
     ,product_id
     ,product
     ,user_store AS user_id
     ,cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,

FROM `mm-commissions-reporting.SANDBOX.v_servicio_renuevos` SALES

INNER JOIN `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` DEALERS
          ON CASE WHEN LENGTH(SALES.user_store) > 4 THEN SALES.user_store
                  WHEN LENGTH(SALES.user_store) = 4 AND SALES.sfid_id <> 'MMS' THEN SALES.sfid_id || '-' || SALES.user_store
                  WHEN SALES.sfid_id = 'MMS' THEN SALES.user_store
                  ELSE SALES.sfid_id
             END = DEALERS.sfid

LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` CONCEPTS
         ON 'B - Renuevo' = CONCEPTS.concepto

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

WHERE DATE_TRUNC(SALES.order_date, month) = mes_pr
      AND comisiona LIKE 'Comi%'
      AND SALES.channel_segment_ds = 'RESIDENCIAL'
      AND`mm-commissions-reporting.SANDBOX.f_clasificacion_canales`(channel_segment_ds , channel_ds , subchannel_ds) = 'No Exclusivo'
;


call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_cure',
  'NO_EXCLUSIVO.comisiones_working'
);


END