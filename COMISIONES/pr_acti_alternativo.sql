BEGIN

DECLARE sql, prefijo, mes_string string;

SET mes_string = CAST(id_mes_pr as string);

SET prefijo = 'ACTINX';

SET canales_pr = COALESCE (canales_pr, 
(SELECT ARRAY_AGG (canal) FROM `mm-commissions-reporting.GS.CANALES` WHERE agrupacion_canal = 'No Exclusivo')
);

IF id_mes_pr IS NULL THEN
  SET id_mes_pr = CAST(FORMAT_DATE('%Y%m', CURRENT_DATE()) AS INT64);
  SET mes_string = CAST(id_mes_pr as string);
END IF;

/*
call  COMISIONES.pr_acti_alternativo (NULL, ['ALTN']);
*/


/* Generates KPIs to facilitate commission calculations */
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activationes_kpi_alternativo` AS
(
SELECT * 
FROM `mm-commissions-reporting.COMISIONES.activaciones` a
CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE a.canal = canal_pr
)
;


-- Actualizar tarifas en el maestro --

INSERT INTO COMISIONES.tarifas_alternativo 
SELECT DISTINCT
 a.canal,
 a.id_mes,
 a.marca,
 a.service_type,
 a.tariff_id, 
 a.tariff_ds,
 CASE WHEN a.service_type = 'MOBILE' THEN a.line_type_ds ELSE CAST(NULL AS STRING) END AS line_type_ds,
 CASE WHEN a.service_type = 'MOBILE' THEN a.bundle_type  ELSE CAST(NULL AS STRING) END AS bundle_type,
 COALESCE(b.comision, CAST(NULL AS FLOAT64)) AS comision,
 b.portabilidad,
 b.gestion_canal,
 b.portabilidad_gestion_canal,
 'ACTI',
 CURRENT_TIMESTAMP(),

FROM `mm-commissions-reporting.COMISIONES.activaciones` a

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas_alternativo` b 
      ON a.marca = b.marca 
       AND a.service_type = b.service_type 
       AND a.tariff_id = b.tariff_id 
       AND a.tariff_ds = b.tariff_ds
       AND a.id_mes = b.id_mes 
       AND a.canal = b.canal
            AND (a.service_type = 'INTERNET' OR a.bundle_type = b.bundle_type)
            AND (a.service_type = 'INTERNET' OR a.line_type_ds = b.line_type_ds)


CROSS JOIN UNNEST (canales_pr) as canal_pr

WHERE a.canal = canal_pr
AND b.canal IS NULL
AND a.service_type IN ('MOBILE', 'INTERNET')
AND a.id_mes = id_mes_pr

;

---------------------------------------

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_conceptos_alternativo` AS

WITH tarifas_tramos AS(
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type,
 comision,
 portabilidad,
 gestion_canal,
 portabilidad_gestion_canal

FROM `mm-commissions-reporting.COMISIONES.v_tarifas_alternativo`

WHERE id_mes = id_mes_pr
),
marco AS
(

-- Servicio fijo y movil --
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 CAST (NULL AS STRING) AS bundle_type,
 'A - Servicio Fijo' AS concepto,
 'UPFR' AS tipo_concepto,
 comision

FROM tarifas_tramos a

CROSS JOIN UNNEST (canales_pr) canal_pr

WHERE canal = canal_pr
AND service_type ='INTERNET' 
AND a.comision IS NOT NULL

UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type,
 'A - Servicio Movil Pospago' AS concepto,
 'UPFR' AS tipo_concepto,
 comision

FROM tarifas_tramos a

CROSS JOIN UNNEST (canales_pr) canal_pr

WHERE canal = canal_pr
AND (service_type in ('MOBILE') AND  COALESCE(line_type_ds,'a') != 'MULTISIM')
AND a.comision IS NOT NULL


-- Servicio Multisim --
UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type,
 'B - Multisim' as concepto,
 'UPFR' AS tipo_concepto,
 comision

FROM tarifas_tramos a

CROSS JOIN UNNEST (canales_pr) canal_pr
WHERE canal = canal_pr
AND line_type_ds = 'MULTISIM' 
AND a.comision IS NOT NULL

-- Portabilidad --
UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type,
 CASE WHEN service_type = 'MOBILE' then 'A - Portabilidad Movil Pospago' ELSE 'A - Portabilidad Fijo' END as concepto, 
 'UPFR' AS tipo_concepto,
 portabilidad AS comision

FROM tarifas_tramos a

CROSS JOIN UNNEST (canales_pr) canal_pr

WHERE canal = canal_pr
AND a.portabilidad IS NOT NULL

-- Gestion de canal --
UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type, 
 CASE
       WHEN service_type = 'MOBILE' AND a.line_type_ds <> 'MULTISIM'  THEN 'F - Servicio Movil Pospago'
       WHEN service_type <> 'MOBILE'                                  THEN 'F - Servicio Fijo'
 END AS concepto,
 
 'UPFR' AS tipo_concepto,
 gestion_canal as comision

FROM tarifas_tramos a

CROSS JOIN UNNEST (canales_pr) canal_pr

WHERE canal = canal_pr
AND a.gestion_canal IS NOT NULL

-- Portabilidad gestion canal--
UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type,
'F - Portabilidad Movil Pospago' AS concepto, 
 'UPFR' AS tipo_concepto,
 portabilidad_gestion_canal AS comision

FROM tarifas_tramos 

CROSS JOIN UNNEST (canales_pr) canal_pr
WHERE canal = canal_pr
AND (service_type in ('MOBILE') AND  COALESCE(line_type_ds,'a') != 'MULTISIM')
AND portabilidad_gestion_canal IS NOT NULL


-- Gestion de canal GPV 
UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 CAST (NULL AS STRING) AS bundle_type,
 'G - Servicio Fijo' AS concepto,
 'UPFR' AS tipo_concepto,
 gestion_canal AS comision

FROM tarifas_tramos 

CROSS JOIN UNNEST (canales_pr) canal_pr

WHERE canal = canal_pr
AND service_type ='INTERNET' 
AND gestion_canal IS NOT NULL

UNION ALL
SELECT
 canal,
 marca,
 service_type,
 tariff_id,
 tariff_ds,
 line_type_ds,
 bundle_type,
 'G - Servicio Movil Pospago' AS concepto,
 'UPFR' AS tipo_concepto,
 gestion_canal AS comision

FROM tarifas_tramos a

CROSS JOIN UNNEST (canales_pr) canal_pr


WHERE canal = canal_pr
AND (service_type in ('MOBILE') AND  COALESCE(line_type_ds,'a') != 'MULTISIM')
AND gestion_canal IS NOT NULL


-- Portabilidad gestion canal GPV--
UNION ALL
SELECT
canal,
marca,
service_type,
tariff_id,
tariff_ds,
line_type_ds,
bundle_type,
'G - Portabilidad Movil Pospago' AS concepto, 
'UPFR' AS tipo_concepto,
portabilidad_gestion_canal AS comision

FROM tarifas_tramos 

CROSS JOIN UNNEST (canales_pr) canal_pr

WHERE canal = canal_pr
AND (service_type in ('MOBILE') AND  COALESCE(line_type_ds,'a') != 'MULTISIM')
AND portabilidad_gestion_canal IS NOT NULL


)
select *
from marco
qualify row_number ()  over (partition by canal, marca, service_type, tariff_id, tariff_ds, line_type_ds, concepto, bundle_type ) = 1
;

--- Calcular tabla de comisiones ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_alternativo` AS (
SELECT
 prefijo||'_'||mes_string||'_'||a.canal||'_'||ROW_NUMBER () OVER () AS commission_id,
 'calculado' AS estado,
 id_mes_pr id_mes,
 b.agrupacion_canal,
 b.canal,
 CASE WHEN b.billing_type_ds = 'PREPAID' THEN REPLACE (concepto, 'Pospago', 'Prepago') ELSE CONCEPTO END as concepto,
 tipo_concepto,
 1 AS unidades,
 comision,

 CASE 
      WHEN SUBSTR (concepto,1,1) IN ('F','H') AND b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista 
      WHEN SUBSTR (concepto,1,1) ='G'         AND b.agrupacion_canal = 'No Exclusivo' THEN G.id_comisionista 
  ELSE b.id_comisionista END AS id_comisionista,

 CASE 
      WHEN SUBSTR (concepto,1,1) IN ('F','H') AND b.agrupacion_canal = 'No Exclusivo' THEN m.id_comisionista 
      WHEN SUBSTR (concepto,1,1) ='G'         AND b.agrupacion_canal = 'No Exclusivo' THEN G.id_comisionista 
  ELSE COALESCE (distribuidor,b.id_comisionista) END AS distribuidor,
 sfid_id,
 seller,
 CASE 
      WHEN SUBSTR (concepto,1,1) IN ('F','H') AND b.agrupacion_canal = 'No Exclusivo' THEN m.nombre_comercio 
      WHEN SUBSTR (concepto,1,1) ='G'                                                 THEN G.nombre_comercio 
  ELSE b.nombre_comercio END AS nombre_comercio,

 CASE 
      WHEN SUBSTR (concepto,1,1) IN ('F','H') AND b.agrupacion_canal = 'No Exclusivo' THEN m.razon_social 
      WHEN SUBSTR (concepto,1,1) ='G'                                                 THEN G.razon_social 
  ELSE b.razon_social END AS razon_social,
 CASE 
      WHEN SUBSTR (concepto,1,1) IN ('F','H') AND b.agrupacion_canal = 'No Exclusivo' THEN m.cif 
      WHEN substr (concepto,1,1) ='G'                                                 THEN G.cif 
  ELSE b.cif END AS cif,
 CASE 
      WHEN SUBSTR (concepto,1,1) IN ('F','H') AND b.agrupacion_canal = 'No Exclusivo' THEN m.zona_fiscal 
      WHEN SUBSTR (concepto,1,1) ='G'                                                 THEN G.zona_fiscal 
  ELSE b.zona_fiscal END AS zona_fiscal,

 b.marca,
 b.service_type,
 phone_nm,
 b.tariff_id,
 b.tariff_ds,
 b.service_id,
 account_id,
 customer_id,
 a.line_type_ds,
 b.bundle_type,
 technology_ds,
 billing_type_ds,
 sale_date,
 activation_date,
 deactivation_date,
 COALESCE(b.sfid_digo,order_id) AS order_id,
 order_type_agg,
 cod_segmento,
 cod_marca,
 cod_tipo_contrato,
 cod_producto,
 COALESCE (d.cod_canal, b.cod_canal) AS cod_canal,
 b.campaign_code,
 CAST (NULL AS STRING) AS serial_number,
 CAST (NULL AS FLOAT64) AS tax_base,
 CAST (NULL AS STRING) AS claim_code,
 CAST (NULL AS STRING) AS process_code,
 comments,
 'C_MANUAL' as facturador

FROM   `mm-commissions-reporting.TEMP.acti_conceptos_alternativo`  a
INNER JOIN `mm-commissions-reporting.TEMP.activationes_kpi_alternativo` b
         ON a.canal = b.canal AND a.marca = b.marca AND a.service_type = b.service_type AND a.tariff_id = b.tariff_id AND a.tariff_ds = b.tariff_ds
            -- AND a.bundle_type = b.bundle_type 
             AND (a.service_type = 'INTERNET' OR a.bundle_type = b.bundle_type)


INNER JOIN `mm-commissions-reporting.GS.CANALES` d 
ON a.canal = d.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m 
ON b.distribuidor = m.id_comisionista

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` G 
ON b.cif_gpv = g.cif


CROSS JOIN UNNEST(canales_pr) as canal_pr
WHERE 1=1
 AND b.canal = canal_pr
 AND b.id_mes = id_mes_pr
 AND b.comisionamiento = 'Comisiona'
 AND case WHEN a.service_type = 'MOBILE' then a.line_type_ds ELSE 'FIX' END = case WHEN b.service_type = 'MOBILE' then b.line_type_ds ELSE 'FIX' END
 AND CASE
   WHEN concepto IN ('F - Portabilidad Movil Pospago', 'F - Portabilidad Fijo','A - Portabilidad Movil Pospago', 'A - Portabilidad Fijo' ,'G - Portabilidad Movil Pospago', 'G - Portabilidad Fijo') THEN 'PORTABILIDAD'
   WHEN concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago','B - Multisim','F - Servicio Fijo', 'F - Servicio Movil Pospago','F - Multisim','G - Servicio Fijo', 'G - Servicio Movil Pospago')
        AND b.order_type_agg IN ('ALTA NUEVA', 'PORTABILIDAD','STC', 'MULTISIM') THEN b.order_type_agg
   END = b.order_type_agg
 
 AND (NOT (COALESCE (b.distribuidor,'NA') NOT IN (SELECT id_comisionista FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` ) AND SUBSTR(a.concepto,1,1) = 'F') OR b.distribuidor = 'BYMOVIL')
 AND NOT (b.cif_gpv IS NULL AND SUBSTR(a.concepto,1,1) = 'G')
 AND b.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD','STC','MULTISIM','HLR')
 AND b.cif IS NOT NULL
)

;


ASSERT NOT EXISTS (
  SELECT *
  FROM `mm-commissions-reporting.TEMP.acti_comisiones_alternativo`
  QUALIFY COUNT(*) OVER (PARTITION BY phone_nm, service_id, marca, service_type, concepto) > 1

); -- Hay duplicados en ACTI!


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_final_alternativo` AS ( 
SELECT *
FROM `mm-commissions-reporting.TEMP.acti_comisiones_alternativo`
WHERE comision IS NOT NULL
      AND comision != 0
      AND cif IS NOT NULL
)
          
;

--- Insertar tabla final ----

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.acti_comisiones_final_alternativo'  , 'ACTUALIZAR');

CALL `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`(FALSE);

CALL `mm-commissions-reporting.COMISIONES.pr_check_ventas_base_prueba`(FALSE);


END