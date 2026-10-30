BEGIN

DECLARE meses ARRAY<STRING>;

SET meses = (
  SELECT SPLIT(valor, ',') 
  FROM `mm-commissions-reporting.GS.PARAMETROS`
  WHERE parametro = 'meses_validacion_tarifas'
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.check_ventas_base_prueba` as (

WITH ventas AS
(
  SELECT *,
  UPPER(comisionamiento) LIKE 'COMISIONA%' AS comisiona_venta

  FROM `mm-commissions-reporting.COMISIONES.activaciones`

  WHERE id_mes IN (SELECT CAST(m as int64) mes FROM UNNEST(meses) m)
   AND order_type_agg in ('ALTA NUEVA','PORTABILIDAD','STC','CAMBIO DOMICILIO','CAMBIO TECNOLOGIA')
)
,

comisiones AS
(
  SELECT *, TRUE AS comisionado

  from `mm-commissions-reporting.COMISIONES.transacciones`

  WHERE id_mes IN (SELECT CAST(m as int64) mes FROM UNNEST(meses) m)
   AND concepto IN ('A - Servicio Fijo',
                    'A - Servicio Movil Pospago',
                    'A - Servicio Movil Prepago',
                    'A - Servicio Fijo Cambio de Domicilio', 
                    'A - Servicio Fijo Cambio de Tecnologia',
                    'B - Multisim')
   AND comision > 0

)

SELECT
  VENTAS.id_mes,
  VENTAS.marca,
  VENTAS.service_id,
  VENTAS.service_type,
  COMISIONES.concepto,
---- CASOS QUE NO COMISIONAN 
  CASE 
   WHEN NOT VENTAS.comisiona_venta AND COMISIONES.comisionado IS NULL THEN comisionamiento
  --  WHEN NOT VENTAS.comisiona_venta AND COMISIONES.comisionado THEN 'No comisiona - Comisionado'
   WHEN VENTAS.canal IS NULL THEN 'No Cruza Dealer' 
   WHEN VENTAS.sfid_id IN ('CAROUT004','CAROUT006','CAROUT020','CAROUT021','CAROUT022','CAROUT032','CAROUT033','CAROUT034') THEN 'No Comisiona - Periodo'
   WHEN VENTAS.canal ='XI' AND VENTAS.marca ='YOIGO' AND VENTAS.tariff_ds LIKE '%CONV%' THEN 'No Comisiona - Cabecera Yoigo'
   WHEN VENTAS.agrupacion_canal ='D2D' AND VENTAS.tariff_ds LIKE '%CONV%' THEN 'No Comisiona - Cabecera'
   WHEN VENTAS.canal IN ('ALTN','ALTNC','ALTNH') AND VENTAS.order_type_agg in ('CAMBIO DOMICILIO','CAMBIO TECNOLOGIA') THEN 'No Comisiona - Traslado/Migracion'
-- COMISIONA

   WHEN COMISIONES.comisionado                                                  THEN 'Comisiona - OK'
   WHEN TARIFAS.tramo_1 IS NULL                                                 THEN 'Comisiona - Tarifa no creada'
   WHEN TARIFAS.tramo_1 = 0                                                     THEN 'No Comisiona - Tarifa configurada a importe 0'
   WHEN e.plantilla_activaciones = 'Con tramos' AND d.marca IS NULL             THEN 'Comisiona - Tramo no creado'
   WHEN VENTAS.canal IN ('ALTN','ALTNC','ALTNH') AND TARIFAS_ALTERNATIVO.comision IS NULL    THEN 'Comisiona - Tarifa no creada'

--- Traslado/Migracion

   WHEN VENTAS.order_type_agg = 'CAMBIO DOMICILIO'  AND TARIFAS.traslados = 0   THEN 'Comisiona - Traslado importe 0'
   WHEN VENTAS.order_type_agg = 'CAMBIO TECNOLOGIA' AND TARIFAS.migraciones = 0 THEN 'Comisiona - Migracion importe 0'
  ELSE 'Comisiona - no calculado' END AS comisionamiento,
  
  CASE  WHEN UPPER(comisionamiento) LIKE 'COMISIONA%' THEN 1
        WHEN UPPER(comisionamiento) LIKE 'NO COMISIONA%' THEN 0
        WHEN COMISIONES.unidades = 1 THEN 1
        ELSE 0 END AS comisiona,
        
  COALESCE ( VENTAS.agrupacion_canal, VENTAS.agrupacion_canal_ventas_base ) AS agrupacion_canal,
  VENTAS.canal,
  COALESCE ( COMISIONES.unidades , 0) AS comisionado,
  VENTAS.tariff_id,
  VENTAS.tariff_ds,
  VENTAS.sfid_id,
  VENTAS.seller,
  VENTAS.order_type_agg,
  VENTAS.campaign_code,
  VENTAS.bundle_type,
  VENTAS.line_type_ds

FROM ventas VENTAS

FULL OUTER JOIN comisiones COMISIONES
USING
  (id_mes,
  marca,
  service_id,
  service_type)

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas` TARIFAS 
  ON VENTAS.canal = TARIFAS.canal 
   AND VENTAS.id_mes=TARIFAS.id_mes
   AND VENTAS.marca=TARIFAS.marca
   AND VENTAS.service_type=TARIFAS.service_type 
   AND VENTAS.tariff_id=TARIFAS.tariff_id
   AND VENTAS.TARIFF_DS = TARIFAS.tariff_ds
   AND (VENTAS.canal IN ('XS','XSO') AND VENTAS.campaign_code = TARIFAS.campaign_code)
   AND CASE WHEN VENTAS.service_type = 'MOBILE' THEN VENTAS.line_type_ds ELSE 'FIX' END = CASE WHEN TARIFAS.service_type = 'MOBILE' THEN TARIFAS.line_type_ds ELSE 'FIX' END



LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas_alternativo`  TARIFAS_ALTERNATIVO
  ON VENTAS.canal = TARIFAS_ALTERNATIVO.canal 
   AND VENTAS.id_mes=TARIFAS_ALTERNATIVO.id_mes
   AND VENTAS.marca=TARIFAS_ALTERNATIVO.marca
   AND VENTAS.service_type=TARIFAS_ALTERNATIVO.service_type 
   AND VENTAS.tariff_id = TARIFAS_ALTERNATIVO.tariff_id
   AND CASE WHEN VENTAS.service_type = 'MOBILE' THEN VENTAS.line_type_ds ELSE 'FIX' END = CASE WHEN TARIFAS_ALTERNATIVO.service_type = 'MOBILE' THEN TARIFAS_ALTERNATIVO.line_type_ds ELSE 'FIX' END

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` d 
  ON VENTAS.id_mes=CAST(d.mes AS INT64) 
   AND VENTAS.marca=d.marca 
   AND VENTAS.canal=d.canal 
   AND VENTAS.id_comisionista = d.id_comisionista
  --  AND VENTAS.TARIFF_DS = d.tariff_ds


LEFT JOIN `mm-commissions-reporting.GS.CANALES` e 
  ON VENTAS.canal = e.canal


)
;
END