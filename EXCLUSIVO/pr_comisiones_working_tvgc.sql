BEGIN

DECLARE clave string;

SET clave = 'TVGC';

-- CALL `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_tvgc`(DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH), MONTH));

CREATE OR REPLACE TABLE `mm-commissions-reporting.EXCLUSIVO.comisiones_working_tvgc` AS

SELECT
      clave || '_EXC_' || FORMAT_DATE('%Y%m', mes_pr) || '_' || ROW_NUMBER () OVER() AS id_registro
     ,'X001' AS sociedad
     ,DEALERS.billing_dealer AS id_comisionista
     ,'DEA' AS tipo_comisionista
     ,DEALERS.documento AS cif
     ,DEALERS.zona_fiscal
     ,tipo_concepto
     ,CASE WHEN descripcion_concepto = 'B - Television' THEN 'F - Gestion Canal Television' ELSE 'F - Gestion Canal Television Premium' END AS descripcion_concepto
     ,1 AS uds

     ,CASE WHEN descripcion_concepto LIKE '%Premium%' THEN 4.00 ELSE 2.00 END AS importe_base

     ,'EUR' AS moneda
     ,'C' AS via_pago
     ,'Z001' AS cond_pago
     ,'27' AS cod_canal
     ,'999' AS cod_producto
     ,'99' AS cod_tipo_contrato
     ,cod_marca
     ,'999' AS cod_operador
     ,cod_segmento
     ,'C_MANUAL' AS facturador
     ,'F - Gestión de canal' AS clasificacion_concepto
     ,canal
     ,subscription_id
     ,product_type
     ,bundle_type
     ,msisdn
     ,fecha_activacion
     ,fecha_baja
     ,account_id
     ,customer_id
     ,sale_dealer
     ,tienda
     ,TV.distribuidor
     ,fecha
     ,agrupacion_cod_tipo_contrato
     ,segmento
     ,DEALERS.razon_social
     ,DEALERS.nombre AS nombre_comercio
     ,marca
     ,order_id
     ,product_id
     ,product
     ,user_id
     ,CAST(NULL AS STRING) campaign_code
     ,CAST(NULL AS STRING) claim_code
     ,CAST(NULL AS STRING) process_code
     ,CAST(NULL AS STRING) comments

FROM `mm-commissions-reporting.EXCLUSIVO.comisiones_working_telv` TV

INNER JOIN `mm-commissions-reporting.EXCLUSIVO.DEALERS` DEALERS
          ON TV.distribuidor = DEALERS.billing_dealer

WHERE descripcion_concepto IN ('B - Television', 'B - Television Premium')
;


CALL `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
clave
,'EXCLUSIVO.comisiones_working_tvgc'
,'EXCLUSIVO.comisiones_working'
);


END