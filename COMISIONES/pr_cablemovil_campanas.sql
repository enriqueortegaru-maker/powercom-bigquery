BEGIN


-- CALL `mm-commissions-reporting.COMISIONES.pr_cablemovil_campanas`(202603, 1);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cablemovil_campanas`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

SELECT
      'CABCAMP' || '_' || CAST(periodo AS STRING) || '_' || CAST(GLOBAL_CIERRES.id_mes AS STRING) || '_' || 'CM' || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(GLOBAL_CIERRES.id_mes AS STRING)) AS mes_liquidado
     ,GLOBAL_CIERRES.id_mes
     ,'B2B - Cablemovil' AS agrupacion_canal
     ,'CM' AS canal
     ,'D - Camp. Cable ' || GLOBAL_CIERRES.subcampana AS concepto
     ,GLOBAL_CIERRES.tipo_concepto

     ,CASE
          WHEN GLOBAL_CIERRES.tipo_campana = 'EOP'        THEN CAST(GLOBAL_CIERRES.eop AS INT64)
          WHEN GLOBAL_CIERRES.tipo_campana = 'ESPECIALES' THEN 1
          WHEN GLOBAL_CIERRES.tipo_campana = 'ONE-OFF'    THEN 1
          WHEN GLOBAL_CIERRES.tipo_campana = 'VOLUMEN'    THEN CAST(GLOBAL_CIERRES.netas AS INT64)
          ELSE CAST(GLOBAL_CIERRES.netas AS INT64)
      END AS unidades

     /*,CASE
          WHEN GLOBAL_CIERRES.observaciones LIKE '%ALCANZA%' THEN GLOBAL_CIERRES.comision
          WHEN GLOBAL_CIERRES.tipo_campana = 'EOP'     THEN GLOBAL_CIERRES.eop * GLOBAL_CIERRES.escalon
          WHEN GLOBAL_CIERRES.tipo_campana = 'VOLUMEN' THEN (CAST(GLOBAL_CIERRES.netas AS INT64) * GLOBAL_CIERRES.escalon)
          ELSE GLOBAL_CIERRES.comision
      END AS comision*/

     ,GLOBAL_CIERRES.comision

     ,MAESTRO.id_comisionista AS id_comisionista
     ,CAST(NULL AS STRING) AS distribuidor
     ,MAESTRO.id_comisionista AS sfid_id
     ,MAESTRO.id_comisionista AS seller
     ,MAESTRO.nombre_comercio AS nombre_comercio
     ,MAESTRO.razon_social AS razon_social
     ,MAESTRO.documento AS cif
     ,MAESTRO.zona_fiscal AS zona_fiscal
     ,'CABLEMOVIL' AS marca
     ,'MOBILE' AS service_type
     ,CAST(NULL AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,CAST(NULL AS STRING) AS tariff_ds
     ,CAST(NULL AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,CAST(NULL AS DATE) AS sale_date
     ,CAST(GLOBAL_CIERRES.FECHA AS DATE) AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'42' AS cod_segmento
     ,'05' AS cod_marca
     ,'20' AS cod_tipo_contrato
     ,'022' AS cod_producto
     ,'30' AS cod_canal

     ,CASE
          WHEN GLOBAL_CIERRES.tipo_campana = 'EOP'                                       THEN CAST(GLOBAL_CIERRES.escalon AS STRING)
          WHEN GLOBAL_CIERRES.tipo_campana = 'FACTURACION'                               THEN CAST(GLOBAL_CIERRES.escalon AS STRING)
          WHEN GLOBAL_CIERRES.tipo_campana = 'VOLUMEN' AND GLOBAL_CIERRES.tipo_2 = 'PVP' THEN  'PVP > '|| GLOBAL_CIERRES.desde_pvp
      END AS claim_code

     ,GLOBAL_CIERRES.subcampana || ' ' || GLOBAL_CIERRES.campaign_code AS campaign_code

     ,CAST(NULL AS STRING) AS serial_number

     ,CASE
          WHEN GLOBAL_CIERRES.tipo_campana IN ('FACTURACION') THEN GLOBAL_CIERRES.total 
          WHEN GLOBAL_CIERRES.tipo_campana IN ('VOLUMEN')     THEN GLOBAL_CIERRES.escalon
      END AS tax_base

     ,CAST(NULL AS STRING) AS process_code

     ,GLOBAL_CIERRES.observaciones AS comments

     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad
     ,CURRENT_TIMESTAMP () AS creado
FROM `mm-commissions-reporting.GS.global_cierres` GLOBAL_CIERRES

LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` MAESTRO
         ON GLOBAL_CIERRES.sfid_id = MAESTRO.id_comisionista

LEFT JOIN (
          SELECT id_comisionista, concepto, activation_date, comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE id_mes = mes_int
                AND agrupacion_canal = 'B2B - Cablemovil'
                AND commission_id LIKE 'CABCAMP%'
                AND SUBSTR(commission_id, 9, 1) <> CAST(periodo AS STRING)
          GROUP BY 1,2,3,4
          ) TRANSACCIONES
         ON MAESTRO.id_comisionista = TRANSACCIONES.id_comisionista AND 'D - Camp. Cable ' || GLOBAL_CIERRES.subcampana = TRANSACCIONES.concepto
            AND CAST(GLOBAL_CIERRES.FECHA AS DATE) = TRANSACCIONES.activation_date
            AND CAST(GLOBAL_CIERRES.comision AS STRING) = CAST(TRANSACCIONES.comision AS STRING)
            
WHERE GLOBAL_CIERRES.id_mes = mes_int
      AND GLOBAL_CIERRES.facturado IS NULL
      AND TRANSACCIONES.concepto IS NULL

-- union all

-- SELECT
--       'CABCAMPB' || '_' || CAST(GLOBAL_CIERRES.id_mes AS STRING) || '_' || 'CM' || '_' || ROW_NUMBER() OVER () AS commission_id
--      ,'calculado' AS estado
--      ,PARSE_DATE('%Y%m', CAST(GLOBAL_CIERRES.id_mes AS STRING)) AS mes_liquidado
--      ,GLOBAL_CIERRES.id_mes
--      ,'B2B - Cablemovil' AS agrupacion_canal
--      ,'CM' AS canal
--      ,'D - Camp. Cable ' || GLOBAL_CIERRES.subcampana AS concepto
--      ,GLOBAL_CIERRES.tipo_concepto

--      ,CASE
--            WHEN GLOBAL_CIERRES.tipo_campana = 'VOLUMEN' THEN CAST((cast (GLOBAL_CIERRES.bajas AS INT64) *-1) AS INT64)
       
--       END AS unidades

--      ,CASE WHEN GLOBAL_CIERRES.tipo_campana = 'EOP'     THEN GLOBAL_CIERRES.eop * GLOBAL_CIERRES.escalon
--            WHEN GLOBAL_CIERRES.tipo_campana = 'VOLUMEN' THEN (CAST(GLOBAL_CIERRES.bajas AS INT64)* -1 * GLOBAL_CIERRES.escalon )
--            ELSE GLOBAL_CIERRES.comision
--       END AS comision

--      ,MAESTRO.customer_id_xena AS id_comisionista
--      ,CAST(NULL AS STRING) AS distribuidor
--      ,MAESTRO.customer_id_xena AS sfid_id
--      ,MAESTRO.customer_id_xena AS seller
--      ,MAESTRO.cliente AS nombre_comercio
--      ,MAESTRO.cliente AS razon_social
--      ,MAESTRO.document_number AS cif
--      ,'PEN' AS zona_fiscal
--      ,'CABLEMOVIL' AS marca
--      ,'MOBILE' AS service_type
--      ,CAST(NULL AS STRING) AS phone_nm
--      ,CAST(NULL AS STRING) AS tariff_id
--      ,CAST(NULL AS STRING) AS tariff_ds
--      ,CAST(NULL AS STRING) AS service_id
--      ,CAST(NULL AS STRING) AS account_id
--      ,CAST(NULL AS STRING) AS customer_id
--      ,CAST(NULL AS STRING) AS line_type_ds
--      ,CAST(NULL AS STRING) AS bundle_type
--      ,CAST(NULL AS STRING) AS technology_ds
--      ,'POSTPAID' AS billing_type_ds
--      ,CAST(NULL AS DATE) AS sale_date
--      ,CAST(GLOBAL_CIERRES.FECHA AS DATE) AS activation_date
--      ,CAST(NULL AS DATE) AS deactivation_date
--      ,CAST(NULL AS STRING) AS order_id
--      ,CAST(NULL AS STRING) AS order_type_agg
--      ,'42' AS cod_segmento
--      ,'05' AS cod_marca
--      ,'20' AS cod_tipo_contrato
--      ,'022' AS cod_producto
--      ,'30' AS cod_canal
--      ,CAST(NULL AS STRING) AS claim_code
--      ,GLOBAL_CIERRES.subcampana || ' ' || GLOBAL_CIERRES.campaign_code AS campaign_code
--      ,CAST(NULL AS STRING) AS serial_number

--      ,CASE WHEN GLOBAL_CIERRES.tipo_campana IN ('FACTURACION') THEN GLOBAL_CIERRES.total 
--            WHEN GLOBAL_CIERRES.tipo_campana IN ('VOLUMEN') THEN GLOBAL_CIERRES.escalon
--      END AS tax_base

--      ,CAST(NULL AS STRING) AS process_code
--      ,CASE WHEN GLOBAL_CIERRES.tipo_campana = 'VOLUMEN' THEN GLOBAL_CIERRES.total || ' Total netas' END AS comments
--      ,'C_MANUAL' AS facturador
--      ,'X001' AS sociedad
--      ,CURRENT_TIMESTAMP () AS creado
-- FROM `mm-commissions-reporting.GS.global_cierres` GLOBAL_CIERRES

-- LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.Maestro_B2B` MAESTRO
--          ON GLOBAL_CIERRES.sfid_id = MAESTRO.customer_id_xena


-- WHERE GLOBAL_CIERRES.id_mes = mes_int
-- and GLOBAL_CIERRES.tipo_campana = 'VOLUMEN'
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CABCAMP' || '_' || CAST(periodo AS STRING), mes_int, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.cablemovil_campanas), 'TEMP.cablemovil_campanas', 'ACTUALIZAR');


END