BEGIN

DECLARE clave STRING;

SET clave = 'TVGC';

-- CALL `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_tvgc`(DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH), MONTH));

CREATE OR REPLACE TABLE `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_tvgc` AS

SELECT
      'TVGC_NOEX_' || FORMAT_DATE('%Y%m', mes_pr) || '_' || ROW_NUMBER () OVER() AS id_registro
     ,'X001' AS sociedad
     ,CONCEPTS.codigo id_comisionista
     ,'DEA' AS tipo_comisionista
     ,CONCEPTS.cif AS cif
     ,CONCEPTS.zona_fiscal
     ,tipo_concepto
     ,'F - Gestion de canal TV' AS descripcion_concepto
     ,1 AS uds
     ,2.00 AS importe_base
     ,'EUR' AS moneda
     ,'C' AS via_pago
     ,'Z001' AS cond_pago
     ,'29' AS cod_canal
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
     ,distribuidor
     ,fecha
     ,agrupacion_cod_tipo_contrato
     ,segmento
     ,CONCEPTS.razon_social
     ,CONCEPTS.nombre AS nombre_comercio
     ,marca
     ,order_id
     ,product_id
     ,product
     ,user_id
     ,CAST(NULL AS STRING) campaign_code
     ,CAST(NULL AS STRING) claim_code
     ,CAST(NULL AS STRING) process_code
     ,CAST(NULL AS STRING) comments

FROM `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_telv` TV

INNER JOIN `mm-commissions-reporting.NO_EXCLUSIVO.MASTER` CONCEPTS
          ON TV.distribuidor = CONCEPTS.nombre

WHERE descripcion_concepto IN ('B - Television', 'B - Television Premium') AND TV.canal IN ('MI', 'CA', 'NR')
;


CALL `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
clave
,'NO_EXCLUSIVO.comisiones_working_tvgc'
,'NO_EXCLUSIVO.comisiones_working'
);


END