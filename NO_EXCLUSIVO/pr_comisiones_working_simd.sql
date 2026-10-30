BEGIN


--declare mes_pr DATE;
declare clave string;
--set mes_pr = '2023-01-01';
SET clave = 'SIMD';


-- CALL `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_simd`(DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH), MONTH));

CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_simd` AS


SELECT
      clave || '_NOEX_' || FORMAT_DATE('%Y%m', mes_pr) || '_' || ROW_NUMBER () OVER() AS id_registro
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
     ,concepto AS descripcion_concepto
     ,1 AS uds
  
     ,2.00 AS importe_base

     ,'EUR' AS moneda
     ,'C' AS via_pago
     ,'Z001' AS cond_pago
     ,'29' AS cod_canal
     ,'999' AS cod_producto
     ,'99' AS cod_tipo_contrato

     ,CASE
          WHEN UPPER(operator_imsi) = 'MASMOVIL'  THEN '05'
          WHEN UPPER(operator_imsi) = 'PEPEPHONE' THEN '06'
          WHEN UPPER(operator_imsi) = 'GUUK'      THEN '13'
          WHEN UPPER(operator_imsi) = 'LLAMAYA'   THEN '04'
          WHEN UPPER(operator_imsi) = 'YOIGO'     THEN '01'
          ELSE '99'
      END AS cod_marca

     ,'999' AS cod_operador
     
     ,CASE
          WHEN UPPER(operator_imsi) = 'GUUK'    THEN '12'
          WHEN UPPER(operator_imsi) = 'LLAMAYA' THEN '12'
          WHEN UPPER(operator_imsi) = 'MASMOVIL' THEN '12'
          ELSE '12'
      END AS cod_segmento
   
     ,'C_MANUAL' AS facturador
     ,'B - SVA' AS clasificacion_concepto
     ,'MP' AS canal
     ,CAST(service_id AS STRING) AS subscription_id
     ,'DUSI' AS product_type
     ,'MO' as bundle_type
     , CAST(msisdn AS STRING) as msisdn
     ,min_fecha_alta AS fecha_activacion
     ,CAST(NULL AS DATE) AS fecha_baja
     ,'' AS account_id
     ,CAST(customer_id AS STRING) AS customer_id
     ,sfid_id AS sale_dealer
     ,user_store AS tienda
     ,distribuidor
     ,mes_pr AS fecha
     ,'Otros servicios' AS agrupacion_cod_tipo_contrato
     
     ,CASE
         WHEN UPPER(operator_imsi) = 'GUUK'    THEN 'Residencial'
         WHEN UPPER(operator_imsi) = 'LLAMAYA' THEN 'Residencial'
         WHEN UPPER(operator_imsi) = 'MASMOVIL' THEN 'Residencial'
         ELSE 'Residencial'
         END AS segmento
      
     ,VENDORS.vendor_name AS razon_social
     ,vendor_name AS nombre_comercio
       ,CASE
         WHEN UPPER(operator_imsi) = 'GUUK'    THEN 'GUUK'
         WHEN UPPER(operator_imsi) = 'LLAMAYA' THEN 'LLAMAYA'
         WHEN UPPER(operator_imsi) = 'RESIDENCIAL - MASMOVIL' THEN 'MASMOVIL'
         END AS marca
     --,UPPER(operator_imsi) AS marca
     ,'' AS order_id
     ,'' AS product_id
     ,CAST(NULL AS STRING) AS product
     ,user_store AS user_id,
     cast(null as string) campaign_code,
     cast(null as string) claim_code,
     cast(null as string) process_code,
     cast(null as string) comments,


FROM `mm-datamart-kd.SERVICES.personal_icc_base` icc


INNER JOIN `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` DEALERS
          ON icc.sfid_id = DEALERS.sfid

LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` CONCEPTS
         ON 'B - Duplicado SIM' = CONCEPTS.concepto

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

WHERE DATE_TRUNC(min_fecha_alta, month) = mes_pr
      AND (operator_imsi LIKE '%MASMOVIL' OR operator_imsi LIKE 'LLAMAYA' OR operator_imsi LIKE 'GUUK')
      AND (sfid_id LIKE 'MPRRR%' )

;


CALL `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
 clave
,'NO_EXCLUSIVO.comisiones_working_simd'
,'NO_EXCLUSIVO.comisiones_working'
)
;


END