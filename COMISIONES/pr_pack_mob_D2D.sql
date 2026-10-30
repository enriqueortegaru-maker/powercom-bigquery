BEGIN

DECLARE prefijo, mes_string, canales STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'PACK';

SET canales_pr =  COALESCE(canales_pr, ['D2D','D2N', 'DEM']);



/*
CALL COMISIONES.pr_pack_mob_D2D (202406,['D2D','D2N','DEM']);
*/




CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cont_pack` as (

  SELECT sfid_id, customer_id,count(phone_nm) as total

    FROM `mm-commissions-reporting.COMISIONES.transacciones` 

    WHERE concepto = 'A - Servicio Movil Pospago'
      AND canal IN UNNEST (canales_pr)
      AND CAST (id_mes AS STRING) = mes_string
      AND line_type_ds = 'ADDITIONAL'
      AND cod_segmento = '12'
      AND bundle_type = 'FMC'

    GROUP BY 1,2

)

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pack_base` AS(

  SELECT 
  'RPD2'||'_'||mes_string||'_'||TRANSACCIONES.CANAL||'_'||'PACK'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE 
    WHEN TRANSACCIONES.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(id_mes AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(id_mes AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE TRANSACCIONES.mes_liquidado 
    END AS mes_liquidado,
    CASE 
    WHEN TRANSACCIONES.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  TRANSACCIONES.agrupacion_canal,
  TRANSACCIONES.canal,
  CASE 
    WHEN PACK.total >= 25 then 'A - Servicio Movil PACK25' 
    WHEN PACK.total >= 15 then 'A - Servicio Movil PACK15'
    WHEN PACK.total >= 5 then 'A - Servicio Movil PACK5'
    ELSE NULL
  END AS concepto,
  TRANSACCIONES.tipo_concepto,
  TRANSACCIONES.unidades,
  
CASE

 
  ---- MARCA MASMOVIL (D2D) ----

  -- 25 O MÁS ADICIONALES 
      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 25
        AND (TRANSACCIONES.tariff_ds LIKE '%80%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%80GB%') THEN 41

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 25 
        AND (TRANSACCIONES.tariff_ds LIKE '%35%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%35GB%') THEN 38
      
      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 25 
        AND (TRANSACCIONES.tariff_ds LIKE '%30%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%30GB%') THEN 38

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 25
        AND (TRANSACCIONES.tariff_ds LIKE '%20%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%20GB%') THEN 20

  -- 15 O MÁS ADICIONALES 
      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 15
        AND (TRANSACCIONES.tariff_ds LIKE '%80%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%80GB%') THEN 36

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 15 
        AND (TRANSACCIONES.tariff_ds LIKE '%35%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%35GB%') THEN 33

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 15 
        AND (TRANSACCIONES.tariff_ds LIKE '%30%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%30GB%') THEN 33

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 15
        AND (TRANSACCIONES.tariff_ds LIKE '%20%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%20GB%') THEN 15

  -- 5 O MÁS ADICIONALES 

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 5
        AND (TRANSACCIONES.tariff_ds LIKE '%80%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%80GB%') THEN 31

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 5 
        AND (TRANSACCIONES.tariff_ds LIKE '%35%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%35GB%') THEN 23

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 5 
        AND (TRANSACCIONES.tariff_ds LIKE '%30%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%30GB%') THEN 23

      WHEN  TRANSACCIONES.marca = 'MASMOVIL'
        AND TRANSACCIONES.canal in ('D2D')
        AND PACK.total >= 5
        AND (TRANSACCIONES.tariff_ds LIKE '%20%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%20GB%') THEN 10

  ---- YOIGO CANAL DEM Y D2N----

  -- 15 O MÁS ADICIONALES 
      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal IN ('D2N','DEM')
        AND PACK.total >= 15
        AND (TRANSACCIONES.tariff_ds LIKE '%INFINITA%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%INFINITAGB%') THEN 40

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal IN ('D2N','DEM')
        AND PACK.total >= 15 
        AND (TRANSACCIONES.tariff_ds LIKE '%60%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%60GB%') THEN 45

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal IN ('D2N','DEM')
        AND PACK.total >= 15 
        AND (TRANSACCIONES.tariff_ds LIKE '%55%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%55GB%') THEN 45

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal ='DEM'
        AND PACK.total >= 15
        AND (TRANSACCIONES.tariff_ds LIKE '%30%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%30GB%') THEN 50

  -- 5 O MÁS ADICIONALES

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal  IN ('D2N','DEM')
        AND PACK.total >= 5
        AND (TRANSACCIONES.tariff_ds LIKE '%INFINITA%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%INFINITAGB%') THEN 25

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal  IN ('D2N','DEM')
        AND PACK.total >= 5 
        AND (TRANSACCIONES.tariff_ds LIKE '%60%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%60GB%') THEN 30

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal  IN ('D2N','DEM')
        AND PACK.total >= 5 
        AND (TRANSACCIONES.tariff_ds LIKE '%55%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%55GB%') THEN 30

      WHEN  TRANSACCIONES.marca = 'YOIGO'
        AND TRANSACCIONES.canal IN ('D2N','DEM')
        AND PACK.total >= 5
        AND (TRANSACCIONES.tariff_ds LIKE '%25%' OR UPPER(TRANSACCIONES.tariff_ds) LIKE '%25GB%') THEN 35
    ELSE 0
  END AS comision,
  TRANSACCIONES.id_comisionista,
  TRANSACCIONES.distribuidor,
  TRANSACCIONES.sfid_id,
  TRANSACCIONES.seller,
  TRANSACCIONES.nombre_comercio,
  TRANSACCIONES.razon_social,
  TRANSACCIONES.cif,
  TRANSACCIONES.zona_fiscal,
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
  TRANSACCIONES.claim_code,
  TRANSACCIONES.campaign_code,
  'PACK_ADICIONAL_'||TRANSACCIONES.CANAL||'_'||mes_string AS process_code, 
  TRANSACCIONES.comments,
  TRANSACCIONES.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  TRANSACCIONES.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  TRANSACCIONES.creado,
  TRANSACCIONES.modificado,
  '' AS id_factura_drive,
  '' AS emails_acceso_trazabilidad


FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
 LEFT JOIN `mm-commissions-reporting.TEMP.cont_pack` PACK
 ON PACK.customer_id = TRANSACCIONES.customer_id --AND PACK.sfid_id = TRANSACCIONES.sfid_id

WHERE TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
AND TRANSACCIONES.canal IN UNNEST (canales_pr)
AND CAST(TRANSACCIONES.id_mes AS STRING) = mes_string
AND TRANSACCIONES.line_type_ds = 'ADDITIONAL'
AND TRANSACCIONES.cod_segmento = '12'
AND TRANSACCIONES.bundle_type = 'FMC'
)
;


--- CLAWBACKS---
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pack_clawback` AS(

  SELECT 
  'RPD2'||'_'||mes_string||'_'||TRANSACCIONES.CANAL||'_'||'PACKCLAW'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE 
    WHEN TCLAWB.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE TCLAWB.mes_liquidado 
    END AS mes_liquidado,
    CASE 
    WHEN TCLAWB.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  TRANSACCIONES.agrupacion_canal,
  TRANSACCIONES.canal,
  CASE 
    WHEN TRANSACCIONES.concepto = 'A - Servicio Movil PACK25' THEN 'E - Clawback Servicio Movil PACK25'
    WHEN TRANSACCIONES.concepto = 'A - Servicio Movil PACK15' THEN 'E - Clawback Servicio Movil PACK15'
    WHEN TRANSACCIONES.concepto = 'A - Servicio Movil PACK5' THEN 'E - Clawback Servicio Movil PACK5'
    ELSE NULL
  END AS concepto,
  TRANSACCIONES.tipo_concepto,
  TRANSACCIONES.unidades,
  TRANSACCIONES.comision * -1 as comision,
  TRANSACCIONES.id_comisionista,
  TRANSACCIONES.distribuidor,
  TRANSACCIONES.sfid_id,
  TRANSACCIONES.seller,
  TRANSACCIONES.nombre_comercio,
  TRANSACCIONES.razon_social,
  TRANSACCIONES.cif,
  TRANSACCIONES.zona_fiscal,
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
  TRANSACCIONES.claim_code,
  TRANSACCIONES.campaign_code,
  'PACK_ADICIONAL_CLAWBACK_'||TRANSACCIONES.CANAL||'_'||mes_string AS process_code, 
  TRANSACCIONES.comments,
  TRANSACCIONES.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  TRANSACCIONES.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  TRANSACCIONES.creado,
  TRANSACCIONES.modificado,
  '' AS id_factura_drive,
  '' AS emails_acceso_trazabilidad


FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TCLAWB
  ON TRANSACCIONES.service_id = TCLAWB.service_id

WHERE TRANSACCIONES.concepto like 'A - Servicio Movil PACK%'
AND TCLAWB.canal IN UNNEST (canales_pr)
AND CAST(TCLAWB.id_mes AS STRING) = mes_string
AND TCLAWB.concepto = 'E - Clawback Servicio Movil Pospago'

)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pack_final` AS (

    SELECT * FROM `mm-commissions-reporting.TEMP.pack_base`
    WHERE comision > 0

  UNION ALL

    SELECT * FROM `mm-commissions-reporting.TEMP.pack_clawback` 
    where comision < 0
)
;
------------------------- INSERT TABLA RAPPEL FIJO --------------------------------
--   INSERT INTO `mm-commissions-reporting.RappelD2D.Rappel_Fijo` (

--    SELECT *
--    FROM `mm-commissions-reporting.TEMP.pack_final`
   
--    )
-- ;
END