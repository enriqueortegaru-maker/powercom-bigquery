begin

declare sql , prefijo , mes_string string;

declare canales_pr ARRAY <STRING> DEFAULT ['OU','OUOV'];
DECLARE fecha_mes DATE;
DECLARE fecha_inicio DATE;
DECLARE fecha_fin DATE;

set prefijo = 'OURP';

set mes_string = cast(mes_int as string);

SET fecha_mes = PARSE_DATE('%Y%m', CAST(mes_int AS STRING));
-- SET fecha_inicio = DATE_SUB(fecha_mes, INTERVAL 3 MONTH);
-- SET fecha_fin = DATE_SUB(fecha_mes, INTERVAL 1 DAY);
SET fecha_inicio = DATE_SUB(DATE_TRUNC(fecha_mes, MONTH), INTERVAL 4 MONTH);

SET fecha_fin = DATE_SUB(DATE_TRUNC(fecha_mes, MONTH), INTERVAL 1 MONTH) - 1;


-- call `mm-commissions-reporting.COMISIONES.pr_ourp` (202609);

CREATE OR REPLACE TABLE
  `mm-commissions-reporting.TEMP.ourp` AS
SELECT
  a.* EXCEPT (concepto,
    comision,
    commission_id,
    mes_liquidado,
    facturador,
    tipo_concepto,
    comments,
    id_mes),
 
  CAST(null AS STRING) AS commission_id,

  CASE
    WHEN c.concepto = 'D - Rappel'   
      and bundle_type = 'FMC'                                 then b.rappel
    WHEN a.activation_date < '2024-02-01' 
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and c.concepto = 'D - Incentivo 3p fibra directa'       then b.incentivo_3p_fibra_directa
    WHEN a.activation_date BETWEEN '2024-02-01' AND '2024-04-30' 
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and a.marca != 'YOIGO'
      and c.concepto = 'D - Incentivo 3p fibra directa'       then b.incentivo_3p_fibra_directa
    WHEN a.activation_date >= '2024-05-01' 
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and a.bundle_type = 'FMC'
      and c.concepto = 'D - Incentivo 3p fibra directa'       then b.incentivo_3p_fibra_directa
  end  AS comision,

  c.concepto,

  c.tipo_concepto,

  COMISIONES.f_mes_int (mes_int) AS mes_liquidado,
  mes_int AS id_mes, 
  'C_MANUAL' AS facturador,

  cast (null as string ) as comments

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` a
INNER JOIN
  `mm-commissions-reporting.GS.MARCO_RAPPEL_OU` b
ON
  a.id_comisionista=b.id_comisionista
  AND b.mes = mes_int
  AND A.MARCA=B.MARCA
CROSS JOIN
  `mm-commissions-reporting.GS.CONCEPTOS` c
WHERE
  a.canal = 'OU'
  AND c.proceso like '%OURP%'
  AND a.concepto = 'A - Servicio Fijo'
  AND a.id_mes = mes_int
  and
  CASE
    WHEN c.concepto = 'D - Rappel'   
      and bundle_type = 'FMC'                                 then b.rappel
    WHEN a.activation_date < '2024-02-01' 
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and c.concepto = 'D - Incentivo 3p fibra directa'       then b.incentivo_3p_fibra_directa
    WHEN a.activation_date BETWEEN '2024-02-01' AND '2024-04-30'  
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and a.marca != 'YOIGO'
      and c.concepto = 'D - Incentivo 3p fibra directa'       then b.incentivo_3p_fibra_directa
    WHEN a.activation_date >= '2024-05-01' 
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and a.bundle_type = 'FMC'
      and c.concepto = 'D - Incentivo 3p fibra directa'       then b.incentivo_3p_fibra_directa
      
  end > 0
;
--- PLAN IMPULSA (TRIMESTRAL)---
INSERT INTO `mm-commissions-reporting.TEMP.ourp` (
SELECT 
'calculado' AS estado,
TRANSACCIONES.agrupacion_canal,
TRANSACCIONES.canal,
TRANSACCIONES.unidades,
TRANSACCIONES.id_comisionista,
TRANSACCIONES.distribuidor,
TRANSACCIONES.sfid_id,
TRANSACCIONES.seller,
DEALER.nombre_comercio,
DEALER.razon_social,
DEALER.cif,
DEALER.zona_fiscal,
DEALER.cond_pago,
TRANSACCIONES.marca,
TRANSACCIONES.service_type,
TRANSACCIONES.phone_nm,
TRANSACCIONES.tariff_id,
TRANSACCIONES.tariff_ds,
TRANSACCIONES.service_id,
TRANSACCIONES.account_id,
TRANSACCIONES.customer_id,
TRANSACCIONES.line_type_ds,
TRANSACCIONES.bundle_type,
TRANSACCIONES.technology_ds,
TRANSACCIONES.billing_type_ds,
TRANSACCIONES.sale_date,
TRANSACCIONES.activation_date,
TRANSACCIONES.deactivation_date,
TRANSACCIONES.order_id,
TRANSACCIONES.order_type_agg,
TRANSACCIONES.cod_segmento,
TRANSACCIONES.cod_marca,
TRANSACCIONES.cod_tipo_contrato,
TRANSACCIONES.cod_producto,
TRANSACCIONES.cod_canal,
TRANSACCIONES.campaign_code,
TRANSACCIONES.serial_number,
TRANSACCIONES.tax_base,
TRANSACCIONES.claim_code,
TRANSACCIONES.process_code,
TRANSACCIONES.proceso_sap,
TRANSACCIONES.id_registro,
TRANSACCIONES.invoice_id,
TRANSACCIONES.sociedad,
TRANSACCIONES.bp,
TRANSACCIONES.cuenta_contable,
TRANSACCIONES.centro_coste,
TRANSACCIONES.documento_sap,
TRANSACCIONES.documento_sap_posicion,
TRANSACCIONES.fecha_contabilizacion,
TRANSACCIONES.creado,
TRANSACCIONES.modificado,
TRANSACCIONES.id_factura_drive,
TRANSACCIONES.emails_acceso_trazabilidad,
CAST(NULL AS STRING) AS commission_id,
  RAPPEL.plan_impulsa AS comision,

  'D - Plan Impulso' AS concepto,
TRANSACCIONES.tipo_concepto,

  COMISIONES.f_mes_int (mes_int) AS mes_liquidado,
  mes_int AS id_mes, 
'C_MANUAL' AS facturador,
TRANSACCIONES.comments


FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON TRANSACCIONES.service_id = VENTAS.service_id
 AND TRANSACCIONES.phone_nm = VENTAS.phone_nm
 AND TRANSACCIONES.account_id = VENTAS.account_id

LEFT JOIN `mm-commissions-reporting.GS.MARCO_RAPPEL_OU` RAPPEL
ON TRANSACCIONES.id_comisionista = RAPPEL.id_comisionista
 AND TRANSACCIONES.marca = RAPPEL.marca
 AND RAPPEL.mes = mes_int

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista
AND DEALER.id_mes = mes_int

WHERE TRANSACCIONES.canal = 'OU'
AND TRANSACCIONES.activation_date BETWEEN fecha_inicio AND fecha_fin
AND CONCEPTO IN ('A - Servicio Fijo','Z - Servicio Fijo')
AND DATE_DIFF(VENTAS.deactivation_date, VENTAS.activation_date, DAY) > 31
QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.SERVICE_ID
                          ORDER BY TRANSACCIONES.ACTIVATION_DATE ASC
                          ) = 1)
;
--- Rappel Orange ---
INSERT INTO `mm-commissions-reporting.TEMP.ourp` (
SELECT 
'calculado' AS estado,
TRANSACCIONES.agrupacion_canal,
TRANSACCIONES.canal,
TRANSACCIONES.unidades,
TRANSACCIONES.id_comisionista,
TRANSACCIONES.distribuidor,
TRANSACCIONES.sfid_id,
TRANSACCIONES.seller,
DEALER.nombre_comercio,
DEALER.razon_social,
DEALER.cif,
DEALER.zona_fiscal,
DEALER.cond_pago,
TRANSACCIONES.marca,
TRANSACCIONES.service_type,
TRANSACCIONES.phone_nm,
TRANSACCIONES.tariff_id,
TRANSACCIONES.tariff_ds,
TRANSACCIONES.service_id,
TRANSACCIONES.account_id,
TRANSACCIONES.customer_id,
TRANSACCIONES.line_type_ds,
TRANSACCIONES.bundle_type,
TRANSACCIONES.technology_ds,
TRANSACCIONES.billing_type_ds,
TRANSACCIONES.sale_date,
TRANSACCIONES.activation_date,
TRANSACCIONES.deactivation_date,
TRANSACCIONES.order_id,
TRANSACCIONES.order_type_agg,
TRANSACCIONES.cod_segmento,
TRANSACCIONES.cod_marca,
TRANSACCIONES.cod_tipo_contrato,
TRANSACCIONES.cod_producto,
TRANSACCIONES.cod_canal,
TRANSACCIONES.campaign_code,
TRANSACCIONES.serial_number,
TRANSACCIONES.tax_base,
TRANSACCIONES.claim_code,
TRANSACCIONES.process_code,
TRANSACCIONES.proceso_sap,
TRANSACCIONES.id_registro,
TRANSACCIONES.invoice_id,
TRANSACCIONES.sociedad,
TRANSACCIONES.bp,
TRANSACCIONES.cuenta_contable,
TRANSACCIONES.centro_coste,
TRANSACCIONES.documento_sap,
TRANSACCIONES.documento_sap_posicion,
TRANSACCIONES.fecha_contabilizacion,
TRANSACCIONES.creado,
TRANSACCIONES.modificado,
TRANSACCIONES.id_factura_drive,
TRANSACCIONES.emails_acceso_trazabilidad,
CAST(NULL AS STRING) AS commission_id,
  CASE WHEN TRANSACCIONES.comision in (145,140,135)       THEN RAPPEL.rappel * 1.25
       WHEN TRANSACCIONES.comision in (125,105,70,50)     THEN RAPPEL.rappel * 1.00
       WHEN TRANSACCIONES.comision in (85,45)             THEN RAPPEL.rappel * 0.70
  END AS comision,

  'D - Rappel' AS concepto,
TRANSACCIONES.tipo_concepto,

  COMISIONES.f_mes_int (mes_int) AS mes_liquidado,
  mes_int AS id_mes, 
'C_MANUAL' AS facturador,
TRANSACCIONES.comments


FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON TRANSACCIONES.service_id = VENTAS.service_id
 AND TRANSACCIONES.phone_nm = VENTAS.phone_nm
 AND TRANSACCIONES.account_id = VENTAS.account_id

LEFT JOIN `mm-commissions-reporting.GS.MARCO_RAPPEL_OU` RAPPEL
ON TRANSACCIONES.id_comisionista = RAPPEL.id_comisionista
 AND TRANSACCIONES.marca = RAPPEL.marca
 AND RAPPEL.mes = mes_int

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista
AND DEALER.id_mes = mes_int

WHERE TRANSACCIONES.canal = 'OUOV'
AND TRANSACCIONES.concepto = 'A - Servicio Fijo'
AND TRANSACCIONES.id_mes = mes_int
QUALIFY ROW_NUMBER() OVER (
                          PARTITION BY TRANSACCIONES.SERVICE_ID
                          ORDER BY TRANSACCIONES.ACTIVATION_DATE ASC
                          ) = 1)
;

DELETE 
FROM `mm-commissions-reporting.TEMP.ourp`
WHERE COMISION IS NULL OR COMISION = 0
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ourp` AS

SELECT 
  * EXCEPT(commission_id)
  ,prefijo||'_'||mes_string||'_'||canal||'_'||row_number () OVER () AS commission_id

FROM `mm-commissions-reporting.TEMP.ourp`

;

-- Inserta tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, canales_pr , 'TEMP.ourp' , 'ACTUALIZAR');

end