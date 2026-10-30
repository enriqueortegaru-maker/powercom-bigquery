BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'FACT';

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES`));


/*
CALL COMISIONES.pr_fact_prueba(202602, ['D2D','D2N','DEM']);
*/


DROP TABLE TEMP.fact_prueba;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.fact_prueba`
(
 mes_liquidado               DATE
,id_mes                      INT64
,agrupacion_canal            STRING
,canal                       STRING
,unidades                    INT64
,id_comisionista             STRING
,distribuidor                STRING
,sfid_id                     STRING
,seller                      STRING
,nombre_comercio             STRING
,razon_social                STRING
,cif                         STRING
,zona_fiscal                 STRING
,cond_pago                   STRING
,marca                       STRING
,service_type                STRING
,phone_nm                    STRING
,tariff_id                   STRING
,tariff_ds                   STRING
,service_id                  STRING
,account_id                  STRING
,customer_id                 STRING
,line_type_ds                STRING
,bundle_type                 STRING
,technology_ds               STRING
,billing_type_ds             STRING
,sale_date                   DATE
,activation_date             DATE
,deactivation_date           DATE
,order_id                    STRING
,order_type_agg              STRING
,cod_segmento                STRING
,cod_marca                   STRING
,cod_canal                   STRING
,campaign_code               STRING
,serial_number               STRING
,tax_base                    FLOAT64
,claim_code                  STRING
,process_code                STRING
,proceso_sap                 STRING
,id_registro                 STRING
,invoice_id                  STRING
,sociedad                    STRING
,bp                          STRING
,cuenta_contable             STRING
,centro_coste                STRING
,documento_sap               STRING
,documento_sap_posicion      STRING
,fecha_contabilizacion       STRING
,creado                      TIMESTAMP
,modificado                  TIMESTAMP
,id_factura_drive            STRING
,emails_acceso_trazabilidad  ARRAY<STRING>
,estado                      STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comments                    STRING
,comision                    FLOAT64
,cod_producto                STRING
,cod_tipo_contrato           STRING
)
;




--- D - EXTRACOMISION PORTABILIDAD D2D  ----- (D2D INCLUYENDO LAS TARIFAS CONV)---- INCENTIVO ATTACH MOVILES//Enero y febrero de 2026 no hay incentivos
/*
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ( 'D2D', 'D2N', 'DEM')) THEN
INSERT INTO TEMP.fact 
(
SELECT

      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,ACTIVACIONES.agrupacion_canal
     ,ACTIVACIONES.canal
     ,1 AS unidades
     ,ACTIVACIONES.id_comisionista
     ,ACTIVACIONES.distribuidor
     ,ACTIVACIONES.sfid_id
     ,ACTIVACIONES.seller
     ,ACTIVACIONES.nombre_comercio
     ,ACTIVACIONES.razon_social
     ,ACTIVACIONES.cif
     ,ACTIVACIONES.zona_fiscal
     ,DEALER.cond_pago
     ,ACTIVACIONES.marca
     ,ACTIVACIONES.service_type
     ,ACTIVACIONES.phone_nm
     ,ACTIVACIONES.tariff_id
     ,ACTIVACIONES.tariff_ds
     ,ACTIVACIONES.service_id
     ,ACTIVACIONES.account_id
     ,ACTIVACIONES.customer_id
     ,ACTIVACIONES.line_type_ds
     ,ACTIVACIONES.bundle_type
     ,ACTIVACIONES.technology_ds
     ,ACTIVACIONES.billing_type_ds
     ,ACTIVACIONES.sale_date
     ,ACTIVACIONES.activation_date
     ,ACTIVACIONES.deactivation_date
     ,ACTIVACIONES.order_id
     ,ACTIVACIONES.order_type_agg
     ,ACTIVACIONES.cod_segmento
     ,ACTIVACIONES.cod_marca
     ,ACTIVACIONES.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,ACTIVACIONES.claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS proceso_sap
     ,CAST(NULL AS STRING) AS id_registro
     ,CAST(NULL AS STRING) AS invoice_id
     ,ACTIVACIONES.sociedad
     ,CAST(NULL AS STRING) AS bp
     ,CAST(NULL AS STRING) AS cuenta_contable
     ,CAST(NULL AS STRING) AS centro_coste
     ,CAST(NULL AS STRING) AS documento_sap
     ,CAST(NULL AS STRING) AS documento_sap_posicion
     ,CAST(NULL AS STRING) AS fecha_contabilizacion
     ,CAST(NULL AS TIMESTAMP) AS creado
     ,CAST(NULL AS TIMESTAMP) AS modificado
     ,CAST(NULL AS STRING) AS id_factura_drive
     ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
--      ,CASE
--           WHEN D2D.id_comisionista IS NOT NULL THEN
--             CASE
--                 WHEN D2D.ventas BETWEEN 1   AND 49  THEN 5.00
--                 WHEN D2D.ventas BETWEEN 50  AND 100 THEN 10.00
--                 WHEN D2D.ventas BETWEEN 101 AND 160 THEN 15.00
--                 WHEN D2D.ventas BETWEEN 161 AND 240 THEN 20.00
--                 WHEN D2D.ventas >= 241 THEN 25.00
--             END

--       END AS comision 
      ,50.0 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, ACTIVACIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, ACTIVACIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
 
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base` VENTAS
         ON ACTIVACIONES.marca = VENTAS.brand_ds AND ACTIVACIONES.service_type = VENTAS.service_type AND ACTIVACIONES.service_id = VENTAS.service_id
            AND VENTAS.order_type_agg IN ('PORTABILIDAD', 'STC')

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
ON ACTIVACIONES.id_comisionista = DEALER.sfid_id AND DEALER.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.D2D_ATTACH_TERMINALES` ATTACH
ON ATTACH.CIF = DEALER.cif AND ATTACH.ID_MES = id_mes_pr

CROSS JOIN UNNEST(canales_pr) canal_pr 

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

LEFT JOIN (
          SELECT ACT.id_comisionista, COUNT(*) AS ventas
          FROM `mm-commissions-reporting.COMISIONES.activaciones` ACT
          LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT
              ON Act.portability_operator_donor = PORT.operador
          WHERE ACT.id_mes = id_mes_pr AND ACT.agrupacion_canal = 'D2D' AND ACT.order_type_agg = 'PORTABILIDAD' AND ACT.service_type != 'FIX' AND (PORT.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') OR PORT.GRUPO_EMPRESA1 IS NULL)
          GROUP BY 1
          ) D2D
         ON ACTIVACIONES.id_comisionista = D2D.id_comisionista


 
LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT_IN
         ON VENTAS.port_in_operator_ds = PORT_IN.operador

     
WHERE ACTIVACIONES.id_mes = id_mes_pr
      AND ACTIVACIONES.canal = canal_pr
      AND DEALER.comisiona IS TRUE
     --  AND ACTIVACIONES.deactivation_date = '9999-12-31'
      AND CONCEPTOS.concepto IN ('D - Incentivo Extracomision Portabilidad')
      AND ACTIVACIONES.service_type IN ('MOBILE','INTERNET')
      AND (
           ACTIVACIONES.canal IN ( 'D2D', 'D2N', 'DEM')
           AND ACTIVACIONES.order_type_agg = 'PORTABILIDAD'
           AND VENTAS.service_id IS NOT NULL
           AND (PORT_IN.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') OR PORT_IN.GRUPO_EMPRESA1 IS NULL)
          )
      AND ATTACH.CIF IS NOT NULL
      
      -- AND CASE
      --         WHEN D2D.id_comisionista IS NOT NULL THEN
      --           CASE
      --               WHEN D2D.ventas BETWEEN 1  AND 24 THEN 5.00
      --               WHEN D2D.ventas BETWEEN 25 AND 50 THEN 10.00
      --               WHEN D2D.ventas BETWEEN 51 AND 80 THEN 15.00
      --               WHEN D2D.ventas BETWEEN 81 AND 120 THEN 20.00
      --               WHEN D2D.ventas >= 121 THEN 25.00
      --           END

      --     END > 0.00 
      AND D2D.ventas >= 1

QUALIFY ROW_NUMBER() OVER (PARTITION BY ACTIVACIONES.service_id ORDER BY id_mes) = 1
)
;

END IF;

*/
---- Extra por Portabilidad Movil D2D// Sólo para moviles en tarifas PRO, incluidas convergentes, diferenciado por marca y con penalización
---- A partir de Febrero también fijos PRO
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ( 'D2D', 'D2N', 'DEM')) THEN
INSERT INTO TEMP.fact_prueba
(
SELECT

      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,ACTIVACIONES.agrupacion_canal
     ,ACTIVACIONES.canal
     ,1 AS unidades
     ,ACTIVACIONES.id_comisionista
     ,ACTIVACIONES.distribuidor
     ,ACTIVACIONES.sfid_id
     ,ACTIVACIONES.seller
     ,ACTIVACIONES.nombre_comercio
     ,ACTIVACIONES.razon_social
     ,ACTIVACIONES.cif
     ,ACTIVACIONES.zona_fiscal
     ,DEALER.cond_pago
     ,ACTIVACIONES.marca
     ,ACTIVACIONES.service_type
     ,ACTIVACIONES.phone_nm
     ,ACTIVACIONES.tariff_id
     ,ACTIVACIONES.tariff_ds
     ,ACTIVACIONES.service_id
     ,ACTIVACIONES.account_id
     ,ACTIVACIONES.customer_id
     ,ACTIVACIONES.line_type_ds
     ,ACTIVACIONES.bundle_type
     ,ACTIVACIONES.technology_ds
     ,ACTIVACIONES.billing_type_ds
     ,ACTIVACIONES.sale_date
     ,ACTIVACIONES.activation_date
     ,ACTIVACIONES.deactivation_date
     ,ACTIVACIONES.order_id
     ,ACTIVACIONES.order_type_agg
     ,ACTIVACIONES.cod_segmento
     ,ACTIVACIONES.cod_marca
     ,ACTIVACIONES.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,ACTIVACIONES.claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS proceso_sap
     ,CAST(NULL AS STRING) AS id_registro
     ,CAST(NULL AS STRING) AS invoice_id
     ,ACTIVACIONES.sociedad
     ,CAST(NULL AS STRING) AS bp
     ,CAST(NULL AS STRING) AS cuenta_contable
     ,CAST(NULL AS STRING) AS centro_coste
     ,CAST(NULL AS STRING) AS documento_sap
     ,CAST(NULL AS STRING) AS documento_sap_posicion
     ,CAST(NULL AS STRING) AS fecha_contabilizacion
     ,CAST(NULL AS TIMESTAMP) AS creado
     ,CAST(NULL AS TIMESTAMP) AS modificado
     ,CAST(NULL AS STRING) AS id_factura_drive
     ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE
          WHEN D2D.id_comisionista IS NOT NULL AND PORT_IN.MARCA_UNIFICADA = 'MOVISTAR' THEN 40.0
          WHEN D2D.id_comisionista IS NOT NULL AND PORT_IN.GRUPO_EMPRESA1 IN ('GRUPO MASMOVIL','ORANGE')AND PORT_IN.MARCA_UNIFICADA NOT IN('CABLEMOVIL') THEN -15.0
          WHEN D2D.id_comisionista IS NOT NULL AND PORT_IN.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') AND PORT_IN.MARCA_UNIFICADA NOT IN('MOVISTAR', 'CABLEMOVIL') AND PORT_IN.MARCA_UNIFICADA IS NOT NULL THEN 30.0
          WHEN D2D.id_comisionista IS NOT NULL AND PORT_IN.MARCA_UNIFICADA IS NULL AND VENTAS.port_in_operator_ds in ('FINETWORK','AVATEL MOVIL, S.L. UNIPERSONAL','FIBRITEL','SILBÖ','PTV TELECOM 5G','SILBO FS') THEN 30.0 
          WHEN D2D.id_comisionista IS NOT NULL AND PORT_IN.MARCA_UNIFICADA IS NULL AND VENTAS.port_in_operator_ds = 'AVATEL MOVIL, S.L. UNIPERSONAL' THEN 30.0
      END AS comision
     ,COALESCE(CONCEPTOS.cod_producto, ACTIVACIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, ACTIVACIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
 
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base` VENTAS
         ON ACTIVACIONES.marca = VENTAS.brand_ds AND ACTIVACIONES.service_type = VENTAS.service_type AND ACTIVACIONES.service_id = VENTAS.service_id
            AND VENTAS.order_type_agg IN ('PORTABILIDAD', 'STC')

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
ON ACTIVACIONES.id_comisionista = DEALER.sfid_id AND DEALER.id_mes = id_mes_pr

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

LEFT JOIN (
          SELECT ACT.id_comisionista, COUNT(*) AS ventas
          FROM `mm-commissions-reporting.COMISIONES.activaciones` ACT
          LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT
              ON Act.portability_operator_donor = PORT.operador
          WHERE ACT.id_mes = id_mes_pr AND ACT.agrupacion_canal = 'D2D' AND ACT.order_type_agg = 'PORTABILIDAD' AND ACT.service_type != 'FIX' --AND PORT.GRUPO_EMPRESA1 IS NULL
          --(PORT.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') OR PORT.GRUPO_EMPRESA1 IS NULL)
          GROUP BY 1
          ) D2D
         ON ACTIVACIONES.id_comisionista = D2D.id_comisionista


 
LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT_IN
         ON VENTAS.port_in_operator_ds = PORT_IN.operador

     
WHERE ACTIVACIONES.id_mes = id_mes_pr
      AND ACTIVACIONES.canal = canal_pr
     --  AND ACTIVACIONES.deactivation_date = '9999-12-31'
      AND CONCEPTOS.concepto IN ('D - Extracomision Portabilidad')
      AND ACTIVACIONES.service_type IN ('MOBILE','FIX')
      AND (
           ACTIVACIONES.canal IN ( 'D2D', 'D2N', 'DEM')
           AND ACTIVACIONES.order_type_agg = 'PORTABILIDAD'
           AND VENTAS.service_id IS NOT NULL
      --      AND (PORT_IN.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') OR PORT_IN.GRUPO_EMPRESA1 IS NULL)
          )
      AND  CASE 
            WHEN ACTIVACIONES.service_type IN ('MOBILE') THEN ACTIVACIONES.tariff_ds LIKE '%PRO%'
            WHEN ACTIVACIONES.service_type IN ('FIX') THEN ACTIVACIONES.bundle_type = 'FMC'
            END
QUALIFY ROW_NUMBER() OVER (PARTITION BY ACTIVACIONES.service_id ORDER BY id_mes) = 1
)
;

END IF;


-- --- D - EXTRACOMISION TARIFAS PRO --- 'PH'
-- IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('PH')) THEN

-- INSERT INTO TEMP.fact --- D - EXTRACOMISION TARIFAS PRO
-- (

-- WITH ventas AS
-- (
-- SELECT seller, COUNT(*) AS ventas
-- from `mm-commissions-reporting.COMISIONES.transacciones`
-- WHERE id_mes = id_mes_pr AND canal = 'PH' AND estado IN ('calculado', 'validado')
--       AND marca = 'YOIGO' AND concepto IN ('A - Servicio Fijo') AND bundle_type = 'FMC'
--       AND tariff_ds LIKE '%PRO' AND (deactivation_date IS NULL OR deactivation_date >= DATE_ADD(COMISIONES.f_mes_int(id_mes_pr), INTERVAL 1 month))
-- GROUP BY 1
-- )

-- SELECT
--       TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
--      ,'calculado' AS estado
--      ,CONCEPTOS.concepto
--      ,CONCEPTOS.tipo_concepto
--      ,'C_MANUAL' AS facturador
--      ,CAST(NULL AS STRING) AS comments

--      ,CASE
--           WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND VENTAS.ventas BETWEEN 1 AND 4                     THEN 40.00
--           WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND VENTAS.ventas BETWEEN 5 AND 14                    THEN 70.00
--           WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND VENTAS.ventas >= 15                               THEN 120.00
--           WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.comision = 63.00           THEN 10.00
--           WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.comision IN (77.00, 82.00) THEN 20.00
--       END AS comision

--      ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
--      ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

-- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

-- LEFT JOIN ventas VENTAS
--          ON TRANSACCIONES.seller = VENTAS.seller

-- CROSS JOIN UNNEST(canales_pr) canal_pr

-- CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

-- WHERE TRANSACCIONES.id_mes = id_mes_pr
--       AND TRANSACCIONES.canal = canal_pr
--       AND TRANSACCIONES.estado IN ('calculado', 'validado')
--       AND TRANSACCIONES.canal IN ('PH')
--       AND TRANSACCIONES.marca = 'YOIGO'
--       AND (
--            (TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago'))
--            OR
--            (TRANSACCIONES.concepto IN ('A - Servicio Fijo') AND VENTAS.ventas > 1)
--           )
--       AND TRANSACCIONES.tariff_ds LIKE '%PRO%'
--       AND CONCEPTOS.concepto IN ('D - Extracomision tarifas PRO')
-- )
-- ;

-- END IF;



CREATE OR REPLACE TABLE TEMP.fact_prueba AS
(
SELECT
      *
     ,prefijo || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM TEMP.fact_prueba
WHERE comision IS NOT NULL
)
;


-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr , 'TEMP.fact' , 'ACTUALIZAR');


END