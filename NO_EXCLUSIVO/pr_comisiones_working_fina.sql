BEGIN


--declare mes_pr DATE;
declare clave string;
--set mes_pr = '2023-01-01';
SET clave = 'FINA';


-- CALL `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_fina`(DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH), MONTH));

CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_fina` AS


SELECT
      clave || '_NOEX_' || FORMAT_DATE('%Y%m', mes_pr) || '_' || ROW_NUMBER () OVER() AS id_registro
      --clave || '_NOEX_' || '_' || ROW_NUMBER () OVER() AS id_registro
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
  
     ,15.00 AS importe_base

     ,'EUR' AS moneda
     ,'C' AS via_pago
     ,'Z001' AS cond_pago
     ,'29' AS cod_canal
     ,'999' AS cod_producto
     ,'99' AS cod_tipo_contrato

     ,'01' cod_marca
     ,'999' AS cod_operador
     
    ,case 
    when segment_ds = 'RESIDENCIAL'   then '10'
    when segment_ds = 'SOHO'   then '12'
    else '10'
    end as cod_segmento
   
     ,'C_MANUAL' AS facturador
     ,'B - SVA' AS clasificacion_concepto
     ,'MP' AS canal
     ,CAST(service_id AS STRING) AS subscription_id
     ,'MOBILE' AS product_type
     ,'MO' as bundle_type
     , CAST(phone_nm AS STRING) as msisdn
     ,DATE(permanence_init_date) AS fecha_activacion
     ,CAST(NULL AS DATE) AS fecha_baja
     ,'' AS account_id
     ,CAST(customer_id AS STRING) AS customer_id
     ,sfid_id AS sale_dealer
     ,sfid_id AS tienda
     ,distribuidor
     ,mes_pr AS fecha
     ,'Otros servicios' AS agrupacion_cod_tipo_contrato
     
     ,CASE
         WHEN UPPER(segment_ds) = 'RESIDENCIAL'    THEN 'Residencial'
         WHEN UPPER(segment_ds) = 'SOHO' THEN 'Negocios'
        ELSE 'Residencial'
         END AS segmento
      
     ,VENDORS.vendor_name AS razon_social
     ,vendor_name AS nombre_comercio

     ,'YOIGO' AS marca
     ,CAST(order_id AS STRING) AS order_id
     ,product_code AS product_id
     ,product_ds AS product
     ,sfid_id AS user_id,
     cast(null as string) campaign_code,
     cast(null as string) claim_code,
     cast(null as string) process_code,
     financed_type as comments,


FROM `mm-datamart-kd.SERVICES.devices_base_qvantel` icc


INNER JOIN `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto` DEALERS
          ON icc.sfid_id = DEALERS.sfid

LEFT JOIN `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` CONCEPTS
         ON 'B - Financiacion terminales' = CONCEPTS.concepto

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

--WHERE DATE_TRUNC(activation_date, month) = mes_pr
where device_type_ds = 'PHONE'
AND (sfid_id like  'MP%'
or sfid_id LIKE  'MR%' 
or sfid_id LIKE 'MP%')
AND DATE(permanence_init_date) between '2022-12-01' and  '2022-12-31'
AND order_status_ds = 'DELIVERED' 
and financed_type ='PAGO FINANCIADO'

;

CALL `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
 clave
,'NO_EXCLUSIVO.comisiones_working_fina'
,'NO_EXCLUSIVO.comisiones_working'
)
;


END