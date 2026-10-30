BEGIN

DECLARE clave STRING;

SET clave = 'TVCB';

-- CALL `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_tvcb`(DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL -1 MONTH), MONTH));

CREATE OR REPLACE TABLE `mm-commissions-reporting.EXCLUSIVO.comisiones_working_tvcb` AS

WITH comisiones AS
(
SELECT
      descripcion_concepto
     ,sociedad
     ,id_comisionista
     ,tipo_comisionista
     ,cif
     ,zona_fiscal
     ,tipo_concepto
     ,via_pago
     ,cond_pago
     ,cod_canal
     ,cod_producto
     ,cod_tipo_contrato
     ,cod_marca
     ,cod_operador
     ,cod_segmento
     ,facturador
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
     ,razon_social
     ,nombre_comercio
     ,marca
     ,order_id
     ,product_id
     ,product
     ,user_id
     ,SUM(uds) AS uds
     ,SUM(importe_base) AS importe_base
FROM (
     SELECT * FROM `mm-commissions-reporting.EXCLUSIVO.comisiones_working_telv`
     UNION ALL
     SELECT * FROM `mm-commissions-reporting.EXCLUSIVO.comisiones_working_tvgc`
     )
WHERE descripcion_concepto IN ('B - Television', 'B - Television Premium', 'F - Gestion Canal Television', 'F - Gestion Canal Television Premium')
      AND importe_base > 0
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38

UNION ALL

SELECT
      descripcion_concepto
     ,sociedad
     ,id_comisionista
     ,tipo_comisionista
     ,cif
     ,zona_fiscal
     ,tipo_concepto
     ,via_pago
     ,cond_pago
     ,cod_canal
     ,cod_producto
     ,cod_tipo_contrato
     ,cod_marca
     ,cod_operador
     ,cod_segmento
     ,facturador
     ,canal
     ,subscription_id
     ,product_type
     ,bundle_type
     ,msisdn
     ,fecha_activacion
     ,fecha_baja
     ,account_id
     ,customer_id
     ,sfid_unico
     ,tienda
     ,distribuidor
     ,fecha
     ,agrupacion_cod_tipo_contrato
     ,segmento
     ,razon_social
     ,nombre_comercio
     ,marca
     ,order_id
     ,product_id
     ,product
     ,user_id
     ,SUM(uds) AS uds
     ,SUM(importe_base) AS importe_base
FROM `mm-commissions-reporting.REPORTED.comisiones_exclusivo_*`
WHERE descripcion_concepto IN ('B - Television', 'B - Television Premium', 'F - Gestion Canal Television', 'F - Gestion Canal Television Premium')
      AND fecha >= DATE_ADD(mes_pr, INTERVAL -6 MONTH)
      AND importe_base > 0
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38
)
,

servicios AS
(
SELECT service_id, brand_ds, MAX(deactivation_date) AS deactivation_date
FROM `mm-commissions-reporting.SANDBOX.v_servicio_television`
WHERE DATE_TRUNC(deactivation_date, MONTH) = mes_pr
GROUP BY 1,2
)

SELECT
      clave || '_EXC_' || FORMAT_DATE('%Y%m', mes_pr) || '_' || ROW_NUMBER () OVER() AS id_registro
     ,sociedad
     ,id_comisionista
     ,tipo_comisionista
     ,cif
     ,zona_fiscal
     ,tipo_concepto

     ,CASE COMMISSIONS.descripcion_concepto
           WHEN 'B - Television'                        THEN 'E - Clawback Television'
           WHEN 'B - Television Premium'                THEN 'E - Clawback Television Premium'
           WHEN 'F - Gestion Canal Television'          THEN 'H - Clawback Gestion Canal Television'
           WHEN 'F - Gestion Canal Television Premium'  THEN 'H - Clawback Gestion Canal Television Premium'
      END AS descripcion_concepto

     ,uds

     ,CASE WHEN DATE_DIFF(deactivation_date, fecha_activacion, DAY) <= 60              THEN -importe_base
           WHEN DATE_DIFF(deactivation_date, fecha_activacion, DAY) BETWEEN 61 AND 120 THEN -importe_base * .75
           ELSE -importe_base * .5
      END AS importe_base
      
     ,'EUR' AS moneda
     ,via_pago
     ,cond_pago
     ,cod_canal
     ,cod_producto
     ,cod_tipo_contrato
     ,cod_marca
     ,cod_operador
     ,cod_segmento
     ,'C_MANUAL' AS facturador

     ,CASE COMMISSIONS.descripcion_concepto
           WHEN 'B - Television'                        THEN 'E - Clawback'
           WHEN 'B - Television Premium'                THEN 'E - Clawback'
           WHEN 'F - Gestion Canal Television'          THEN 'H - Clawback gestión de canal'
           WHEN 'F - Gestion Canal Television Premium'  THEN 'H - Clawback gestión de canal'
      END AS clasificacion_concepto

     ,canal
     ,subscription_id
     ,product_type

     ,CASE WHEN bundle_type = 'DESC' THEN 'FMC' ELSE bundle_type END AS bundle_type

     ,msisdn
     ,fecha_activacion
     ,deactivation_date AS fecha_baja
     ,account_id
     ,customer_id
     ,sale_dealer
     ,tienda
     ,distribuidor
     ,mes_pr AS fecha
     ,agrupacion_cod_tipo_contrato
     ,segmento
     ,razon_social
     ,nombre_comercio
     ,marca
     ,order_id
     ,product_id
     ,product
     ,user_id
     ,CAST(NULL AS STRING) campaign_code
     ,CAST(NULL AS STRING) claim_code
     ,CAST(NULL AS STRING) process_code
     ,CAST(NULL AS STRING) comments

FROM comisiones COMMISSIONS

INNER JOIN servicios SERVICES
         ON COMMISSIONS.subscription_id = SERVICES.service_id AND UPPER(COMMISSIONS.marca) = SERVICES.brand_ds

WHERE DATE_DIFF(deactivation_date, fecha_activacion, MONTH) <= 6
;


CALL `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
 clave
,'EXCLUSIVO.comisiones_working_tvcb'
,'EXCLUSIVO.comisiones_working'
);


END