BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'FACT';

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo);

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES`));


/*
CALL COMISIONES.pr_fact_preliqui(202608, ['ENK','EML','EYG'], 'DAILY');
*/


-- IF EXISTS (SELECT 1 FROM `mm-commissions-reporting.TEMP.fact_preliqui`) THEN DROP TABLE `mm-commissions-reporting.TEMP.fact_preliqui`;

-- END IF;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.fact_preliqui`
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


 --- A - CAMBIO DE TITULARIDAD --- 'ECI', 'EDB', 'EML', 'EYG','ENX'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG','ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- A - CAMBIO DE TITULARIDAD
(
SELECT
      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,VENTAS.agrupacion_canal
     ,canal
     ,1 AS unidades
     ,id_comisionista
     ,distribuidor
     ,CAMBIO.sfid_id
     ,seller
     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
     ,cond_pago
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,billing_type_ds
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,order_id
     ,order_type_agg
     ,cod_segmento
     ,cod_marca
     ,cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS proceso_sap
     ,CAST(NULL AS STRING) AS id_registro
     ,CAST(NULL AS STRING) AS invoice_id
     ,sociedad
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
     ,'A - Cambio de Titularidad' AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,15.00 AS comision
     ,cod_producto
     ,cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

INNER JOIN `mm-commissions-reporting.TEMP.cambio_titular` CAMBIO
          ON VENTAS.contract_id = CAMBIO.order_contract_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
         ON VENTAS.agrupacion_canal = DEALER.agrupacion_canal AND CAMBIO.sfid_id = DEALER.sfid_id

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE CAST(SUBSTR(REPLACE(CAST(VENTAS.activation_date AS STRING), '-', ''), 1, 6) AS INT64) = id_mes_pr
      AND DEALER.canal = canal_pr
      AND DEALER.canal IN ('ECI', 'EDB', 'EML', 'EYG','ENX')
      -- AND order_type_agg = 'HLR'
      AND VENTAS.service_type != 'FIX'

QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id, marca) = 1
)
;

END IF;


 --- A - SERVICIO MOVIL POSPAGO (TARIFAS MAX PEPEPHONE)--- 'EDB', 'EML', 'EYG','ENX'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('EDB', 'EML', 'EYG','ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- A - SERVICIO MOVIL POSPAGO (TARIFAS MAX PEPEPHONE)
(
SELECT
      CALCULO.* EXCEPT(concepto,tipo_concepto,facturador,comision,cod_producto,cod_tipo_contrato)
      ,'calculado' AS estado
      ,concepto
      ,tipo_concepto
      ,facturador
      ,'Tarifa MAX Pepephone' AS comments
      ,comision
      ,cod_producto
      ,cod_tipo_contrato 
      
FROM (
      -- Upfront -- 
      SELECT 
          mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,unidades
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
          ,cond_pago
          ,marca
          ,service_type
          ,phone_nm
          ,tariff_id
          ,tariff_ds
          ,service_id
          ,TRANSACCIONES.account_id
          ,customer_id
          ,line_type_ds
          ,bundle_type
          ,technology_ds
          ,billing_type_ds
          ,sale_date
          ,TRANSACCIONES.activation_date
          ,deactivation_date
          ,order_id
          ,order_type_agg
          ,cod_segmento
          ,cod_marca
          ,cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
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
          ,concepto
          ,tipo_concepto
          ,facturador
          ,`mm-commissions-reporting.COMISIONES.f_calculo_streaming_pepe`(TRANSACCIONES.activation_date, TRANSACCIONES.canal, STREAMING.max, STREAMING.netflix, STREAMING.prime, TRANSACCIONES.tariff_ds, TRANSACCIONES.comision, TRUE, FALSE) as comision
          ,cod_producto
          ,cod_tipo_contrato

      FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES
      LEFT JOIN (SELECT
                              account_id
                              ,comm_brand_ds
                              ,DATE_TRUNC(activation_date, MONTH) AS activation_date
                              
                              ,SUM(CASE WHEN service_type = 'MAX' THEN 1 ELSE 0 END) AS max
                              
                              ,SUM(CASE WHEN service_type = 'NETFLIX' THEN 1 ELSE 0 END) AS netflix
                              
                              ,SUM(CASE WHEN service_type = 'AMAZON PRIME' THEN 1 ELSE 0 END) AS prime
                              
                              FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
                              
                              WHERE DATE_TRUNC(activation_date, MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
                              AND comm_brand_ds = 'PEPEPHONE'
                              AND service_type IN ('MAX','NETFLIX','AMAZON PRIME')
                              
                              GROUP BY 1,2,3) STREAMING
      
                  ON TRANSACCIONES.account_id = STREAMING.account_id AND TRANSACCIONES.marca = STREAMING.comm_brand_ds
      
      WHERE TRANSACCIONES.id_mes = id_mes_pr
            AND TRANSACCIONES.agrupacion_canal = 'Exclusivo'
            AND TRANSACCIONES.service_type IN ('MOBILE')
            AND TRANSACCIONES.marca = 'PEPEPHONE'
            AND TRANSACCIONES.line_type_ds = 'MAIN'
            AND TRANSACCIONES.concepto LIKE 'A - Servicio%'
      ) CALCULO
WHERE CALCULO.comision <> 0

)
;

END IF;

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('PH')) THEN

INSERT INTO TEMP.fact_preliqui --- A - Portabilidad PH (Excluye marcas intragrupo)
(
SELECT
      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,1 AS unidades
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.distribuidor
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.seller
     ,TRANSACCIONES.nombre_comercio
     ,TRANSACCIONES.razon_social
     ,TRANSACCIONES.cif
     ,TRANSACCIONES.zona_fiscal
     ,'' AS cond_pago
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST (NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS proceso_sap
     ,CAST(NULL AS STRING) AS id_registro
     ,CAST(NULL AS STRING) AS invoice_id
     ,TRANSACCIONES.sociedad
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
     ,CASE
          WHEN TRANSACCIONES.service_type = 'INTERNET'         THEN 'A - Portabilidad Fijo'
          WHEN TRANSACCIONES.service_type = 'MOBILE'           THEN 'A - Portabilidad Movil Pospago'
      END AS concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,25.00 AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.activaciones` TRANSACCIONES

LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA
  ON TRANSACCIONES.phone_nm = CAST(INTRA.phone_nm AS STRING)
  AND TRANSACCIONES.account_id = INTRA.account_id
  AND TRANSACCIONES.customer_id = INTRA.customer_id

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = 'PH'
      AND TRANSACCIONES.service_type IN ('INTERNET','MOBILE')
      AND TRANSACCIONES.order_type_agg = 'PORTABILIDAD'
      AND CONCEPTOS.concepto IN ('A - Portabilidad Movil Pospago','A - Portabilidad Fijo')
      AND TRANSACCIONES.marca = 'MASMOVIL'
      AND TRANSACCIONES.tariff_id NOT IN ('333')
      AND INTRA.operador_donante_unificado NOT IN ('ALTERNA','EMBOU','EUSKALTEL','GUUK','JAZZTEL','MASMOVIL','ORANGE','PEPEPHONE','R','SIMYO','TELECABLE','YOIGO')

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY id_mes) = 1
)
;


END IF;


--- B - DEVOLUCION SIM y B - DEVOLUCION SIM YOIGO --- 'ECI', 'EDB', 'EML', 'ENX' 'EYG', 'GUUK', 'MP', 'PH'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML','ENX','EYG', 'GUUK', 'MP', 'PH')) THEN

INSERT INTO TEMP.fact_preliqui --- B - DEVOLUCION SIM y B - DEVOLUCION SIM YOIGO
(
SELECT
      TRANSACCIONES.* EXCEPT(cod_producto, cod_tipo_contrato)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN TRANSACCIONES.canal = 'PH' AND TRANSACCIONES.marca IN ('YOIGO')
               THEN CASE WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo' THEN 1.21 ELSE 0 END

          ELSE CASE
                   WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo' AND CANARIAS.matricula IS NOT NULL  THEN 1.07
                   WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo'                                     THEN 1.21
                   ELSE 1.00
               END
      END AS comision
     
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM (
     (
     SELECT
           mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,1 as unidades
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
          ,cond_pago
          ,marca
          ,service_type
          ,phone_nm
          ,tariff_id
          ,tariff_ds
          ,service_id
          ,account_id
          ,customer_id
          ,line_type_ds
          ,bundle_type
          ,technology_ds
          ,billing_type_ds
          ,sale_date
          ,activation_date
          ,deactivation_date
          ,order_id
          ,order_type_agg
          ,cod_segmento
          ,cod_marca
          ,cod_tipo_contrato
          ,cod_producto
          ,cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
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
     FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
     WHERE id_mes = id_mes_pr
           AND estado IN ('calculado', 'validado')
           AND canal IN ('ECI', 'EDB', 'EML', 'ENX', 'EYG', 'GUUK', 'MP','PH')
           AND ((canal = 'PH' AND marca = 'YOIGO') 
               OR(canal IN ('ECI', 'EDB', 'EML', 'ENX', 'EYG', 'GUUK', 'MP') 
               AND marca IN ('YOIGO', 'MASMOVIL','LLAMAYA', 'GUUK')))
           AND marca IN ('YOIGO', 'MASMOVIL', 'LLAMAYA','GUUK')
           AND concepto = 'A - Servicio Movil Pospago'
     )

     UNION ALL
     
     (
     SELECT
           PARSE_DATE('%Y%m', CAST(id_mes AS STRING)) AS mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,1 as unidades
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
          ,TRANSACCIONES.cond_pago
          ,ACTIVACIONES.marca
          ,service_type
          ,ACTIVACIONES.phone_nm
          ,tariff_id
          ,tariff_ds
          ,ACTIVACIONES.service_id
          ,account_id
          ,customer_id
          ,line_type_ds
          ,bundle_type
          ,technology_ds
          ,billing_type_ds
          ,sale_date
          ,activation_date
          ,deactivation_date
          ,order_id
          ,order_type_agg
          ,cod_segmento
          ,cod_marca
          ,cod_tipo_contrato
          ,cod_producto
          ,cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
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
     FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
 
     LEFT JOIN (
               SELECT service_id, phone_nm, marca, cond_pago
               FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
               WHERE canal IN ('ECI', 'EDB', 'EML', 'ENX', 'EYG') AND concepto IN ('A - Servicio Movil Pospago', 'B - Devolucion SIM', 'B - Devolucion SIM Yoigo') GROUP BY 1,2,3,4
               ) TRANSACCIONES
              ON ACTIVACIONES.service_id = TRANSACCIONES.service_id AND ACTIVACIONES.phone_nm = TRANSACCIONES.phone_nm AND ACTIVACIONES.marca = TRANSACCIONES.marca

     WHERE id_mes = id_mes_pr
           AND TRANSACCIONES.service_id IS NULL
           AND (
                (ACTIVACIONES.canal IN ('ECI', 'EML', 'EYG') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','2313','7126','7127'))
               OR
                (ACTIVACIONES.canal IN ('EDB') AND ACTIVACIONES.tariff_id IN ('8205', 'CONT28', 'CONT29'))
               )
           AND ACTIVACIONES.marca IN ('YOIGO', 'MASMOVIL', 'LLAMAYA','GUUK')
           AND ACTIVACIONES.order_type_agg != 'MIGRACION CONTRATO' -- 20250414 JOHANNA
     )
     ) TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TRANSACCIONES.marca = 'YOIGO' THEN 'B - Devolucion SIM Yoigo' ELSE 'B - Devolucion SIM' END = CONCEPTOS.concepto

LEFT JOIN mm-commissions-reporting.GS.exclusivo_canarias CANARIAS
        ON TRANSACCIONES.seller = CANARIAS.MATRICULA

WHERE TRANSACCIONES.canal = canal_pr
AND TRANSACCIONES.zona_fiscal != 'MEL' -- 20250425 JOHANNA
      AND CASE
              WHEN TRANSACCIONES.canal = 'PH' AND TRANSACCIONES.marca IN ('YOIGO')
                   THEN CASE WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo' THEN 1.21 ELSE 0.00 END
  
              ELSE CASE
                       WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo' AND CANARIAS.matricula IS NOT NULL  THEN 1.07
                       WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo'                                     THEN 1.21
                       ELSE 1.00
                   END
          END > 0.00
)
;

END IF;


--- B - DEVOLUCION SIM (TICNOVA) --- 'CA'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('CA')) THEN

INSERT INTO TEMP.fact_preliqui --- B - DEVOLUCION SIM (TICNOVA)
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,1 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TRANSACCIONES.marca = 'YOIGO' THEN 'B - Devolucion SIM Yoigo' ELSE 'B - Devolucion SIM' END = CONCEPTOS.concepto

LEFT JOIN mm-commissions-reporting.GS.exclusivo_canarias CANARIAS
        ON TRANSACCIONES.seller = CANARIAS.MATRICULA

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('CA')
      AND TRANSACCIONES.marca IN ('YOIGO', 'MASMOVIL', 'LLAMAYA','GUUK')
      AND TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
      AND TRANSACCIONES.nombre_comercio = 'TICNOVA'
)
;

END IF;


--- B - DEVOLUCION SIM MULTISIM y B - DEVOLUCION SIM YOIGO MULTISIM --- 'EML','EYG'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('EML','EYG','ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- B - DEVOLUCION SIM MULTISIM y B - DEVOLUCION SIM YOIGO MULTISIM
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo Multisim' AND CANARIAS.matricula IS NOT NULL THEN 1.07
          WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo Multisim'                                    THEN 1.21
          ELSE 1.00
      END AS comision
     
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TRANSACCIONES.marca = 'YOIGO' THEN 'B - Devolucion SIM Yoigo Multisim' ELSE 'B - Devolucion SIM Multisim' END = CONCEPTOS.concepto

LEFT JOIN mm-commissions-reporting.GS.exclusivo_canarias CANARIAS
        ON TRANSACCIONES.seller = CANARIAS.MATRICULA

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('EML','EYG','ENX')
      AND TRANSACCIONES.marca IN ('YOIGO', 'MASMOVIL', 'LLAMAYA','GUUK')
      AND TRANSACCIONES.concepto = 'B - Multisim'
)
;

END IF;


--- D - ACELERADOR PORTA D --- 'CA', 'MI', 'MP', 'MR'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('CA', 'MI', 'MP', 'MR')) THEN

INSERT INTO TEMP.fact_preliqui --- D - ACELERADOR PORTA D
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN TRANSACCIONES.concepto IN ('A - Servicio Fijo')          THEN 20.00
          WHEN TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago') THEN 10.00
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base` VENTAS
          ON TRANSACCIONES.marca = VENTAS.brand_ds AND TRANSACCIONES.service_type = VENTAS.service_type AND TRANSACCIONES.service_id = VENTAS.service_id
             AND VENTAS.order_type_agg IN ('PORTABILIDAD', 'STC')

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT_IN
         ON VENTAS.port_in_operator_ds = PORT_IN.operador

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('CA', 'MI', 'MP', 'MR')
      AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'A - Servicio Fijo')
      AND TRANSACCIONES.sfid_id <> 'CADENA16'
      AND TRANSACCIONES.order_type_agg = 'PORTABILIDAD'
      AND CONCEPTOS.concepto = 'D - Acelerador Porta D'
      AND PORT_IN.marca_unificada LIKE '%DIGI%'
)
;

END IF;


--- D - EXTRA POR ACTIVACION, D - MULTIPLICADOR y D - RAPPEL --- 'CIN', 'DON', 'OUN', 'XIN', 'XON', 'XSN' 
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('CIN', 'DON', 'OUN', 'XIN', 'XON', 'XSN')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRA POR ACTIVACION, D - MULTIPLICADOR y D - RAPPEL
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN CONCEPTOS.concepto = 'D - Extra por activacion' AND TRANSACCIONES.concepto = 'A - Servicio Fijo'
          THEN EXTRA.extra_activacion

          WHEN CONCEPTOS.concepto = 'D - Multiplicador'
               AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia')
          THEN (EXTRA.multiplicador - 1) * TRANSACCIONES.comision

          WHEN CONCEPTOS.concepto = 'D - Rappel'
          THEN EXTRA.rappel * TRANSACCIONES.comision / 100
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.GS.TLV_NEGOCIOS_EXTRACOMISIONES` EXTRA
          ON TRANSACCIONES.id_comisionista = EXTRA.id_comisionista AND TRANSACCIONES.id_mes = CAST(EXTRA.mes AS INT64)

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('CIN', 'DON', 'OUN', 'XIN', 'XON', 'XSN')
      AND (
          TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia')
          OR
          (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND line_type_ds IN ('MAIN', 'ADDITIONAL'))
          )
      AND CONCEPTOS.concepto IN ('D - Extra por activacion', 'D - Multiplicador', 'D - Rappel')
      AND CASE
              WHEN CONCEPTOS.concepto = 'D - Extra por activacion' AND TRANSACCIONES.concepto = 'A - Servicio Fijo'
              THEN EXTRA.extra_activacion
    
              WHEN CONCEPTOS.concepto = 'D - Multiplicador'
                   AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia')
              THEN (EXTRA.multiplicador - 1) * TRANSACCIONES.comision
    
              WHEN CONCEPTOS.concepto = 'D - Rappel'
              THEN EXTRA.rappel * TRANSACCIONES.comision / 100
          END > 0.00
)
;

END IF;


--- D - EXTRACOMISION BONO D2D
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN

INSERT INTO TEMP.fact_preliqui 
(
     SELECT
          PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
          ,id_mes_pr AS id_mes
          ,DEALER.agrupacion_canal
          ,DEALER.canal
          ,1 as unidades
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,BONO.sfid_id
          ,BONO.sfid_id AS seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,DEALER.cond_pago
          ,BONO.brand_ds AS marca
          ,BONO.service_type
          ,CAST(BONO.phone_nm AS STRING) AS phone_nm
          ,BONO.bono_id AS tariff_id
          ,BONO.bono_name AS tariff_ds
          ,BONO.service_id
          ,BONO.account_id
          ,BONO.customer_id
          ,VENTAS.line_type_ds
          ,VENTAS.bundle_type
          ,VENTAS.technology_ds
          ,VENTAS.billing_type_ds
          ,DATE(BONO.init_date_ts) AS sale_date
          ,DATE(BONO.init_date_ts) AS activation_date
          ,CAST (NULL AS DATE ) AS deactivation_date
          ,VENTAS.order_id
          ,VENTAS.order_type_agg
          ,'12' AS cod_segmento
          ,`mm-commissions-reporting.COMISIONES.f_cod_marca`(BONO.brand_ds, 'MOBILE') AS cod_marca
          ,'22' AS cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,'X001' AS sociedad
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
          ,'D - Extracomision Bono' AS concepto
          ,'UPFR' AS tipo_concepto
          ,'C_MANUAL' AS facturador
          ,CAST(NULL AS STRING) AS comments
          ,30.00 AS comision
          ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`('MOBILE', BONO.brand_ds, VENTAS.order_type_agg, '','61' ) AS cod_producto
          ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(VENTAS.billing_type_ds, BONO.service_type, VENTAS.bundle_type, VENTAS.technology_ds, BONO.brand_ds, VENTAS.line_type_ds) AS cod_tipo_contrato

FROM `mm-datamart-kd.SERVICES.bonos_base_emysim` BONO

LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
ON BONO.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON BONO.service_id = VENTAS.service_id
  AND CAST(BONO.phone_nm AS STRING) = VENTAS.phone_nm 

WHERE FORMAT_TIMESTAMP('%Y%m', init_date_ts) = mes_string
AND DEALER.agrupacion_canal = 'D2D'
AND DEALER.comisiona IS TRUE
AND BONO.bono_id IN ('789','8145','788','8146','8133')
);

END IF;


--- D - EXTRACOMISION RENUEVO LINEA PPAL. --- 'XS'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('XS','XO','XI','XOF','WA')) THEN


INSERT INTO TEMP.fact_preliqui 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,5.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT serial_number
          FROM `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
          WHERE RENUEVOS.activation_date <= COALESCE(RENUEVOS.deactivation_date, '9999-12-31')
                AND COALESCE(RENUEVOS.deactivation_date, '9999-12-31') >= DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 2 MONTH)
                AND financed_type = 'PAGO FINANCIADO'
                AND COALESCE(RENUEVOS.financed_end_date, '9999-12-31') > DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 2 MONTH)
                AND serial_number IS NOT NULL
          QUALIFY ROW_NUMBER() OVER (
                                    PARTITION BY phone_nm, brand_ds
                                    ORDER BY RENUEVOS.activation_date ASC,
                                             RENUEVOS.deactivation_date ASC,
                                             RENUEVOS.original_cost_price DESC,
                                             RENUEVOS.serial_number ASC
                                    ) > 1
          ) MULTI
         ON TRANSACCIONES.serial_number = MULTI.serial_number

   LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
   ON DEVICES.serial_number = TRANSACCIONES.serial_number 
    AND CAST(DEVICES.phone_nm AS STRING) = TRANSACCIONES.phone_nm


CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND  TRANSACCIONES.canal IN ('XS','XOF','XO','XI','WA')
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND (TRANSACCIONES.campaign_code IN ('Blindaje','Camp. piloto','Multiproducto Television','Multiproducto Terminales','Multiproducto Generica') OR CANAL IN ('WA','XI'))
      AND TRANSACCIONES.concepto IN ('B - Renuevo')
      AND TRANSACCIONES.bundle_type = 'FMC'
      AND TRANSACCIONES.service_type = 'MOBILE'
      AND TRANSACCIONES.line_type_ds = 'MAIN'
      AND CONCEPTOS.concepto = 'D - Extracomision Renuevo Linea Principal'
      AND DEVICES.is_financed_desc = 'SI'
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.serial_number) = 1

)
;

END IF;

--- D - EXTRACOMISION COMERCIAL RENUEVO --- 'ECI', 'EDB', 'EML', 'EYG', 'ENX'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION COMERCIAL RENUEVO
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN CATEGORIZACION.categoria = 'Plus MASlife'     THEN 5
          WHEN CATEGORIZACION.categoria = 'Plus MASlife +'   THEN 15
          WHEN CATEGORIZACION.categoria = 'Plus MASlife ++'  THEN 20
          WHEN CATEGORIZACION.categoria = 'Plus MASlife +++' THEN 25
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

LEFT JOIN `mm-commissions-reporting.GS.exclusivo_categorizacion_renuevos` CATEGORIZACION
         ON (TRANSACCIONES.sfid_id = CATEGORIZACION.matricula OR TRANSACCIONES.seller = CATEGORIZACION.matricula)
            AND CATEGORIZACION.mes = id_mes_pr

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')
      AND TRANSACCIONES.concepto = 'B - Renuevo'
      AND TRANSACCIONES.campaign_code = '1'
      AND CONCEPTOS.concepto = 'D - Extracomision Comercial renuevo'
      AND CATEGORIZACION.matricula IS NOT NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.serial_number) = 1
)
;

END IF;


--- D - EXTRACOMISION FIJO A LO PEPE --- 'ECI', 'EDB', 'EML', 'EYG', 'ENX'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION FIJO A LO PEPE
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,15.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')
      AND TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
      AND TRANSACCIONES.bundle_type = 'MO'
      AND TRANSACCIONES.tariff_id = 'FIJOALOPEPE1'
      AND CONCEPTOS.concepto IN ('D - Extracomision fijo a lo Pepe')
)
;

END IF;


--- D - Extracomision Plan Impulso (EXTRACOMISION SEMESTRAL SELECTRA) --- 'DO' 
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DO' )) THEN

INSERT INTO TEMP.fact_preliqui 
(
SELECT

      PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,1 AS unidades
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.distribuidor
     ,TRANSACCIONES.sfid_id
     ,TRANSACCIONES.seller
     ,TRANSACCIONES.nombre_comercio
     ,TRANSACCIONES.razon_social
     ,TRANSACCIONES.cif
     ,TRANSACCIONES.zona_fiscal
     ,TRANSACCIONES.cond_pago
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,TRANSACCIONES.claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS proceso_sap
     ,CAST(NULL AS STRING) AS id_registro
     ,CAST(NULL AS STRING) AS invoice_id
     ,TRANSACCIONES.sociedad
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
     ,28 AS comision
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON VENTAS.service_id = TRANSACCIONES.service_id AND VENTAS.phone_nm = TRANSACCIONES.phone_nm

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE  TRANSACCIONES.id_mes BETWEEN 202501 AND 202506
AND TRANSACCIONES.CANAL = 'DO'
AND TRANSACCIONES.CONCEPTO in ('A - Servicio Fijo', 'Z - Servicio Fijo')
AND TRANSACCIONES.CIF = 'B86793239'
AND VENTAS.activation_date < '9999-12-01'
AND VENTAS.deactivation_date > DATE_ADD(VENTAS.activation_date, INTERVAL 31 DAY)
AND CONCEPTOS.concepto = 'D - Extracomision Plan Impulso'

);

END IF;


--- D - Extracomision Objetivo (TLV - NEGOCIOS)
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ( 'CIN', 'DON', 'OUN', 'XIN', 'XSN')) THEN
INSERT INTO TEMP.fact_preliqui 
(
SELECT 
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
    
     ,CASE
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND OBJETIVOS.objetivo_alcanzado = 110          THEN 25
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND OBJETIVOS.objetivo_alcanzado = 115          THEN 35
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND OBJETIVOS.objetivo_alcanzado = 125          THEN 50

          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND OBJETIVOS.objetivo_alcanzado = 110 THEN 10
          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND OBJETIVOS.objetivo_alcanzado = 115 THEN 15
          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND OBJETIVOS.objetivo_alcanzado = 125 THEN 20
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato
FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.GS.OBJETIVOS_TLVN` OBJETIVOS 
ON TRANSACCIONES.sfid_id = OBJETIVOS.sfid_id 
  AND OBJETIVOS.id_mes = id_mes_pr

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.CONCEPTO IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
AND TRANSACCIONES.canal = canal_pr
AND TRANSACCIONES.id_mes = id_mes_pr
AND OBJETIVOS.sfid_id IS NOT NULL
AND CONCEPTOS.concepto = 'D - Extracomision Objetivo'

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.marca, TRANSACCIONES.service_type) = 1
)

;
END IF
;


 --- D - EXTRACOMISION PORTA VOD --- 'CA', 'CIN', 'D2D', 'D2N', 'DEM', 'DON', 'EML', 'EYG', 'MI' ,'MR', 'OUN', 'XIN', 'XSN'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ( 'CIN', 'DON', 'OUN', 'XIN', 'XSN')) THEN
-- IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('CA', 'D2D', 'D2N', 'DEM', 'EML', 'EYG', 'MI' ,'MR')) THEN
INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION PORTA VOD 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
    
     ,CASE
          WHEN D2D.id_comisionista IS NOT NULL THEN
            CASE
                WHEN D2D.ventas BETWEEN 1  AND 24 THEN 5.00
                WHEN D2D.ventas BETWEEN 25 AND 50 THEN 10.00
                WHEN D2D.ventas BETWEEN 51 AND 80 THEN 15.00
                WHEN D2D.ventas BETWEEN 81 AND 120 THEN 20.00
                WHEN D2D.ventas >= 121 THEN 25.00
            END

          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
               AND COALESCE(CAST(REPLACE(EML.consecucion_pospago,'%','') AS FLOAT64), CAST(REPLACE(EYG.consecucion_pospago,'%','') AS FLOAT64), 0) >= 105
          THEN 15.00

          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
               AND COALESCE(CAST(REPLACE(TLVN.consecucion_pospago,'%','') AS FLOAT64), 0) >= 105
          THEN 10.00

          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
               AND TRANSACCIONES.canal IN ('CA', 'MI' ,'MR')
               AND COALESCE(PVP.tariff_fee, 0.00) > 3.00
          THEN 15.00
          
          WHEN TRANSACCIONES.concepto IN ('A - Servicio Fijo')
               AND COALESCE(CAST(REPLACE(EML.consecucion_ftth_adsl,'%','') AS FLOAT64), CAST(REPLACE(EYG.consecucion_ftth_adsl,'%','') AS FLOAT64), 0) >= 105
          THEN 30.00
          
          WHEN TRANSACCIONES.concepto IN ('A - Servicio Fijo')
               AND COALESCE(CAST(REPLACE(TLVN.consecucion_ftth_adsl,'%','') AS FLOAT64), 0) >= 105
          THEN 25.00
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
 
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_base` VENTAS
         ON TRANSACCIONES.marca = VENTAS.brand_ds AND TRANSACCIONES.service_type = VENTAS.service_type AND TRANSACCIONES.service_id = VENTAS.service_id
            AND VENTAS.order_type_agg IN ('PORTABILIDAD', 'STC')

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

LEFT JOIN (
          SELECT ACT.id_comisionista, COUNT(*) AS ventas
          FROM `mm-commissions-reporting.COMISIONES.activaciones` ACT
          LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT
              ON Act.portability_operator_donor = PORT.operador
          WHERE ACT.id_mes = id_mes_pr AND ACT.agrupacion_canal = 'D2D' AND ACT.order_type_agg = 'PORTABILIDAD' AND ACT.service_type != 'FIX' AND PORT.GRUPO_EMPRESA1 LIKE '%VODAFONE%'
          GROUP BY 1
          ) D2D
         ON TRANSACCIONES.id_comisionista = D2D.id_comisionista
     
LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_eml` EML
        ON (TRANSACCIONES.sfid_id = EML.id_comisionista OR TRANSACCIONES.seller = EML.id_comisionista)
           AND EML.id_mes = id_mes_pr
     
LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_eyg` EYG
         ON (TRANSACCIONES.sfid_id = EYG.id_comisionista OR TRANSACCIONES.seller = EYG.id_comisionista)
            AND EYG.id_mes = id_mes_pr

LEFT JOIN `mm-commissions-reporting.GS.tlvn_rappel` TLVN
         ON TRANSACCIONES.id_comisionista = TLVN.id_comisionista
            AND TLVN.id_mes = id_mes_pr
 
LEFT JOIN `mm-sales-reporting.SPREADSHEETS.port_in_operadores_unificado` PORT_IN
         ON VENTAS.port_in_operator_ds = PORT_IN.operador

LEFT JOIN (
          SELECT *
          FROM `mm-datamart-kd.SERVICES.mascatalogue_product_base`
          QUALIFY ROW_NUMBER() OVER (PARTITION BY tariff_id, brand_ds ORDER BY COALESCE(end_date, '9999-12-31') DESC) = 1
          ) PVP
         ON TRANSACCIONES.tariff_id = PVP.tariff_id AND TRANSACCIONES.marca = PVP.brand_ds
     
WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'A - Servicio Fijo')
      AND TRANSACCIONES.deactivation_date = '9999-12-31'
      AND CONCEPTOS.concepto IN ('D - Extracomision Porta Vod')
      AND (
          (
           TRANSACCIONES.canal IN ('CA', 'D2D', 'D2N', 'DEM', 'EML', 'EYG', 'MI' ,'MR')
           AND TRANSACCIONES.order_type_agg = 'PORTABILIDAD'
           AND VENTAS.service_id IS NOT NULL
           AND PORT_IN.grupo_empresa1 LIKE '%VODAFONE%'
          )
          OR
          (
          TRANSACCIONES.canal IN ('CIN', 'DON', 'OUN', 'XIN', 'XSN')
          )
          )

      AND CASE
              WHEN D2D.id_comisionista IS NOT NULL THEN
                CASE
                    WHEN D2D.ventas BETWEEN 1  AND 24 THEN 5.00
                    WHEN D2D.ventas BETWEEN 25 AND 50 THEN 10.00
                    WHEN D2D.ventas BETWEEN 51 AND 80 THEN 15.00
                    WHEN D2D.ventas BETWEEN 81 AND 120 THEN 20.00
                    WHEN D2D.ventas >= 121 THEN 25.00
                END

              WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
                   AND COALESCE(CAST(REPLACE(EML.consecucion_pospago,'%','') AS FLOAT64), CAST(REPLACE(EYG.consecucion_pospago,'%','') AS FLOAT64), 0) >=105
              THEN 15.00
    
              WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
                   AND COALESCE(CAST(REPLACE(TLVN.consecucion_pospago,'%','') AS FLOAT64), 0) >=105
              THEN 10.00

              WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
                   AND TRANSACCIONES.canal IN ('CA', 'MI' ,'MR')
                   AND COALESCE(PVP.tariff_fee, 0.00) > 3.00
              THEN 15.00
          
              WHEN TRANSACCIONES.concepto IN ('A - Servicio Fijo')
                   AND COALESCE(CAST(REPLACE(EML.consecucion_ftth_adsl,'%','') AS FLOAT64), CAST(REPLACE(EYG.consecucion_ftth_adsl,'%','') AS FLOAT64), 0) >=105
              THEN 30.00
              
              WHEN TRANSACCIONES.concepto IN ('A - Servicio Fijo')
                   AND COALESCE(CAST(REPLACE(TLVN.consecucion_ftth_adsl,'%','') AS FLOAT64), 0) >=105
              THEN 25.00
          END > 0.00

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.commission_id ORDER BY id_mes) = 1
)
;

END IF;


---- Extra por Portabilidad Movil D2D// Sólo para moviles en tarifas PRO, incluidas convergentes, diferenciado por marca y con penalización
---- A partir de Febrero también para fijos pro y residenciales, sin penalizacion por interco
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ( 'D2D', 'D2N', 'DEM')) THEN
INSERT INTO TEMP.fact_preliqui
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
     ---Movil
          WHEN D2D.id_comisionista IS NOT NULL AND ACTIVACIONES.service_type = 'MOBILE' AND PORT_IN.MARCA_UNIFICADA = 'MOVISTAR' THEN 40.0
          WHEN D2D.id_comisionista IS NOT NULL AND ACTIVACIONES.service_type = 'MOBILE' AND PORT_IN.GRUPO_EMPRESA1 IN ('GRUPO MASMOVIL','ORANGE')AND PORT_IN.MARCA_UNIFICADA NOT IN('CABLEMOVIL') THEN -15.0
          WHEN D2D.id_comisionista IS NOT NULL AND ACTIVACIONES.service_type = 'MOBILE' AND PORT_IN.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') AND PORT_IN.MARCA_UNIFICADA NOT IN('MOVISTAR', 'CABLEMOVIL') AND PORT_IN.MARCA_UNIFICADA IS NOT NULL THEN 30.0
          WHEN D2D.id_comisionista IS NOT NULL  AND ACTIVACIONES.service_type = 'MOBILE' AND  PORT_IN.MARCA_UNIFICADA IS NULL AND VENTAS.port_in_operator_ds in ('FINETWORK','AVATEL MOVIL, S.L. UNIPERSONAL','FIBRITEL','SILBÖ','PTV TELECOM 5G','SILBO FS') THEN 30.0
      ---Fijo
          WHEN D2D.id_comisionista IS NOT NULL AND ACTIVACIONES.service_type = 'FIX' AND PORT_IN.GRUPO_EMPRESA1 NOT IN ('GRUPO MASMOVIL','ORANGE') AND PORT_IN.MARCA_UNIFICADA NOT IN('CABLEMOVIL') AND PORT_IN.MARCA_UNIFICADA IS NOT NULL THEN 40.0
          WHEN D2D.id_comisionista IS NOT NULL  AND ACTIVACIONES.service_type = 'FIX' AND  PORT_IN.MARCA_UNIFICADA IS NULL AND VENTAS.port_in_operator_ds in ('FINETWORK','AVATEL MOVIL, S.L. UNIPERSONAL','FIBRITEL','SILBÖ','PTV TELECOM 5G','SILBO FS') THEN 40.0
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
          )
      AND  CASE 
            WHEN ACTIVACIONES.service_type IN ('MOBILE') THEN ACTIVACIONES.tariff_ds LIKE '%PRO%'
            WHEN ACTIVACIONES.service_type IN ('FIX') THEN ACTIVACIONES.bundle_type = 'FMC'
            END
QUALIFY ROW_NUMBER() OVER (PARTITION BY ACTIVACIONES.service_id ORDER BY id_mes) = 1
)
;


END IF;


--- D - Documentacion Entregada // P - Documentacion Auditada --- 'D2D','D2N','DEM'

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D', 'D2N', 'DEM')) THEN

INSERT INTO TEMP.fact_preliqui 
(
  SELECT
    PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,activaciones.agrupacion_canal
     ,activaciones.canal
     ,1 AS unidades
     ,activaciones.id_comisionista
     ,activaciones.distribuidor
     ,activaciones.sfid_id
     ,activaciones.seller
     ,activaciones.nombre_comercio
     ,activaciones.razon_social
     ,activaciones.cif
     ,activaciones.zona_fiscal
     ,'Z020'AS cond_pago
     ,activaciones.marca
     ,activaciones.service_type
     ,activaciones.phone_nm
     ,activaciones.tariff_id
     ,activaciones.tariff_ds
     ,activaciones.service_id
     ,activaciones.account_id
     ,activaciones.customer_id
     ,activaciones.line_type_ds
     ,activaciones.bundle_type
     ,activaciones.technology_ds
     ,activaciones.billing_type_ds
     ,activaciones.sale_date
     ,activaciones.activation_date
     ,activaciones.deactivation_date
     ,activaciones.order_id
     ,activaciones.order_type_agg
     ,activaciones.cod_segmento
     ,activaciones.cod_marca
     ,activaciones.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,activaciones.claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS proceso_sap
     ,CAST(NULL AS STRING) AS id_registro
     ,CAST(NULL AS STRING) AS invoice_id
     ,activaciones.sociedad
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
     ,'D - Documentacion Entregada' AS concepto
     ,'UPFR' AS tipo_concepto
     ,'C_MANUAL' AS facturador
     ,doc.contract_id AS comments
     ,60.0  AS comision
     ,activaciones.cod_producto
     ,activaciones.cod_tipo_contrato

  FROM `mm-commissions-reporting.COMISIONES.activaciones` activaciones

  LEFT JOIN `mm-commissions-reporting.TEMP.control_doc` doc
    ON activaciones.phone_nm = CAST(doc.msisdn AS STRING) 

  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` ventas
    ON doc.contract_id = ventas.contract_id
    AND activaciones.activation_date = ventas.activation_date

  WHERE activaciones.agrupacion_canal = 'D2D'

    AND ventas.contract_id IS NOT NULL
    AND doc.flag_ultimo_estado = 1
    AND activaciones.id_mes = id_mes_pr
    AND activaciones.service_type in ('MOBILE','INTERNET')
    AND doc.estado = 'Completa'
    AND activaciones.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
    AND ((activaciones.cod_segmento = '10' AND activaciones.tariff_ds LIKE '%PRO%')OR (activaciones.cod_segmento = '12'))
    QUALIFY ROW_NUMBER() OVER(PARTITION BY activaciones.customer_id, activaciones.cif ORDER BY 
    CASE  WHEN activaciones.service_type = 'INTERNET' THEN 1 ELSE 2 END) = 1
)
;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.penalizacion_ventas_auditadas` AS (
WITH lineas_computables AS (
  SELECT 
  *
  ,TRUNC(lineas * porcentaje_penalizadas) AS lineas_penalizadas
  FROM(
  SELECT 
    fact.cif
    ,count(*)as lineas
    ,CASE 
      WHEN porc.porcentaje IS NOT NULL THEN(1.00 - porc.porcentaje) 
      -- WHEN porc.porcentaje IS NULL THEN 0.40 --Ya no se penaliza al resto del canal
    END AS porcentaje_penalizadas
  FROM TEMP.fact fact
  LEFT JOIN `mm-commissions-reporting.GS.D2D_DOCUMENTACION_ENTREGADA` porc 
    ON fact.cif = porc.cif
    AND id_mes_pr = porc.id_mes
    AND porc.porcentaje is not null --Nos quitamos quien no tenga penalizacion
  WHERE fact.concepto = 'D - Documentacion Entregada'
  GROUP BY ALL)
),

 lineas_ordenadas AS (
  SELECT
    *
    ,ROW_NUMBER() OVER(PARTITION BY cif ORDER BY activation_date ASC) AS orden
  FROM TEMP.fact fact
  WHERE fact.concepto = 'D - Documentacion Entregada'

)

  SELECT 
  lineas_ordenadas.* EXCEPT(concepto,comision,orden)
  ,-lineas_ordenadas.comision AS comision
  ,'P - Documentacion Auditada' AS concepto
  FROM lineas_ordenadas
  LEFT JOIN lineas_computables
    ON lineas_ordenadas.cif = lineas_computables.cif
  WHERE lineas_ordenadas.orden <= lineas_computables.lineas_penalizadas

);
INSERT INTO TEMP.fact_preliqui (
      SELECT 
       mes_liquidado
,id_mes
,agrupacion_canal
,canal
,unidades
,id_comisionista
,distribuidor
,sfid_id
,seller
,nombre_comercio
,razon_social
,cif
,zona_fiscal
,cond_pago
,marca
,service_type
,phone_nm
,tariff_id
,tariff_ds
,service_id
,account_id
,customer_id
,line_type_ds
,bundle_type
,technology_ds
,billing_type_ds
,sale_date
,activation_date
,deactivation_date
,order_id
,order_type_agg
,cod_segmento
,cod_marca
,cod_canal
,campaign_code
,serial_number
,tax_base
,claim_code
, process_code
, proceso_sap
, id_registro
, invoice_id
,sociedad
, bp
, cuenta_contable
, centro_coste
, documento_sap
, documento_sap_posicion
, fecha_contabilizacion
,creado
, modificado
, id_factura_drive
, emails_acceso_trazabilidad
,estado
,concepto
,tipo_concepto
,facturador
,comments
,comision
,cod_producto
,cod_tipo_contrato

      FROM `mm-commissions-reporting.TEMP.penalizacion_ventas_auditadas`

)

;
END IF;


--- D - EXTRACOMISION SEGMENTACION --- 'ECI', 'EML', 'EYG','ENX', 'PH'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EML', 'EYG', 'ENX' ,'PH','DO','DOT')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION SEGMENTACION 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE WHEN CANAL = 'DO' THEN 5.00
           ELSE 20.00 END AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND (
           (
           TRANSACCIONES.canal IN ('ECI', 'EML', 'EYG', 'ENX')
           AND TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
           AND TRANSACCIONES.cod_segmento = '12'
           AND TRANSACCIONES.tariff_id NOT IN ('CONT28', 'CONT29')
           )
          OR
           (
           TRANSACCIONES.canal IN ('PH')
           AND TRANSACCIONES.marca = 'YOIGO'
           AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago' , 'A - Servicio Fijo')
           AND TRANSACCIONES.cod_segmento = '12'
           AND TRANSACCIONES.tariff_id NOT IN ('CONT28','CONT29','8145','8187','8205','8212')
           )
           OR
           (
           TRANSACCIONES.canal IN ('DO','DOT')
           AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago')
           AND TRANSACCIONES.tariff_ds LIKE '%PRO%'
           AND TRANSACCIONES.MARCA IN ('YOIGO','MASMOVIL')
           )
          )
      AND CONCEPTOS.concepto = 'D - Extracomision Segmentacion'
)
;

END IF;


--- D - EXTRACOMISION TARIFAS PRO --- 'PH'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('PH')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION TARIFAS PRO
(

WITH ventas AS
(
SELECT seller, COUNT(*) AS ventas
from `mm-commissions-reporting.COMISIONES.transacciones`
WHERE id_mes = id_mes_pr AND canal = 'PH' AND estado IN ('calculado', 'validado')
      AND marca = 'YOIGO' AND concepto IN ('A - Servicio Fijo') AND bundle_type = 'FMC'
      AND tariff_ds LIKE '%PRO' AND (deactivation_date IS NULL OR deactivation_date >= DATE_ADD(COMISIONES.f_mes_int(id_mes_pr), INTERVAL 1 month))
GROUP BY 1
)

SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND VENTAS.ventas BETWEEN 1 AND 4                     THEN 40.00
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND VENTAS.ventas BETWEEN 5 AND 14                    THEN 70.00
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo' AND VENTAS.ventas >= 15                               THEN 120.00
          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.comision = 63.00           THEN 10.00
          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.comision IN (77.00, 82.00) THEN 20.00
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN ventas VENTAS
         ON TRANSACCIONES.seller = VENTAS.seller

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('PH')
      AND TRANSACCIONES.marca = 'YOIGO'
      AND (
           (TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago'))
           OR
           (TRANSACCIONES.concepto IN ('A - Servicio Fijo') AND VENTAS.ventas > 1)
          )
      AND TRANSACCIONES.tariff_ds LIKE '%PRO%'
      AND CONCEPTOS.concepto IN ('D - Extracomision tarifas PRO')
)
;

END IF;


--- D - EXTRACOMISION TERMINAL [QVANTEL] --- 'ECI', 'EDB', 'EML', 'EYG', 'ENX'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION TERMINAL [QVANTEL]
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,25.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

INNER JOIN `mm-datamart-kd.DEVICES.device_base_qvantel` DEVICES
          ON TRANSACCIONES.marca = 'YOIGO' AND TRANSACCIONES.order_id = CAST(DEVICES.order_id AS STRING) AND order_status_ds = 'DELIVERED'

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')
      AND TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
      AND CONCEPTOS.concepto = 'D - Extracomision terminal'
)
;

END IF;



--- D - EXTRACOMISION TERMINAL [MYSIM] --- 'ECI', 'EDB', 'EML', 'EYG', 'ENX'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG', 'ENX')) THEN

INSERT INTO TEMP.fact_preliqui --- D - EXTRACOMISION TERMINAL [MYSIM]
(
SELECT
      TRANSACCIONES.* EXCEPT(cod_producto, cod_tipo_contrato)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,25.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM (
     (
      SELECT
           mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,1 as unidades
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
          ,cond_pago
          ,marca
          ,service_type
          ,phone_nm
          ,tariff_id
          ,tariff_ds
          ,service_id
          ,account_id
          ,customer_id
          ,line_type_ds
          ,bundle_type
          ,technology_ds
          ,billing_type_ds
          ,sale_date
          ,activation_date
          ,deactivation_date
          ,order_id
          ,order_type_agg
          ,cod_segmento
          ,cod_marca
          ,cod_tipo_contrato
          ,cod_producto
          ,cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
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
      FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES
      WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('EDB', 'EML', 'EYG', 'ENX')
      AND TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'
     )

     UNION ALL

     (
      SELECT
           PARSE_DATE('%Y%m', CAST(id_mes AS STRING)) AS mes_liquidado
          ,id_mes
          ,agrupacion_canal
          ,canal
          ,1 as unidades
          ,id_comisionista
          ,distribuidor
          ,sfid_id
          ,seller
          ,nombre_comercio
          ,razon_social
          ,cif
          ,zona_fiscal
          ,TRANSACCIONES.cond_pago
          ,ACTIVACIONES.marca
          ,service_type
          ,ACTIVACIONES.phone_nm
          ,tariff_id
          ,tariff_ds
          ,ACTIVACIONES.service_id
          ,account_id
          ,customer_id
          ,line_type_ds
          ,bundle_type
          ,technology_ds
          ,billing_type_ds
          ,sale_date
          ,activation_date
          ,deactivation_date
          ,order_id
          ,order_type_agg
          ,cod_segmento
          ,cod_marca
          ,cod_tipo_contrato
          ,cod_producto
          ,cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
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
     FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
     LEFT JOIN (
               SELECT service_id, phone_nm, marca, cond_pago
               FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
               WHERE canal IN ('EDB', 'EML', 'ENX', 'EYG') AND concepto IN ('A - Servicio Movil Pospago', 'D - Extracomision terminal') GROUP BY 1,2,3,4
               ) TRANSACCIONES
              ON ACTIVACIONES.service_id = TRANSACCIONES.service_id AND ACTIVACIONES.phone_nm = TRANSACCIONES.phone_nm AND ACTIVACIONES.marca = TRANSACCIONES.marca

     WHERE id_mes = id_mes_pr
           AND TRANSACCIONES.service_id IS NULL
           AND (
                (ACTIVACIONES.canal IN ('EML', 'ENX', 'EYG') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','2313','7126','7127'))
               OR
                (ACTIVACIONES.canal IN ('EDB') AND ACTIVACIONES.tariff_id IN ('8205', 'CONT28', 'CONT29'))
               )
           AND ACTIVACIONES.order_type_agg != 'MIGRACION CONTRATO'
     )
    ) TRANSACCIONES

INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
          ON TRANSACCIONES.marca = DEVICES.brand_ds AND TRANSACCIONES.service_id = CAST(DEVICES.service_id AS STRING)
             AND DEVICES.sell_type ='VENTA'
             AND DEVICES.terminal_status_ds IN ('USADO', 'FINANCIACION EN CURSO')
             AND COALESCE(DEVICES.device_type_ds ,'ROUTER') NOT IN ('ROUTER', 'Hotspotwifi')

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
AND TRANSACCIONES.canal = canal_pr
AND CONCEPTOS.concepto = 'D - Extracomision terminal'
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.marca, TRANSACCIONES.service_type) = 1
)
;

END IF;


--- F - ACCION CONVERGENCIA y F - ACCION POSPAGO --- 'CA', 'MI', 'MP', 'MR', 'NR', 'PH'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('CA', 'MI', 'MP', 'MR', 'NR', 'PH')) THEN

INSERT INTO TEMP.fact_preliqui --- F - ACCION CONVERGENCIA y F - ACCION POSPAGO
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE WHEN CONCEPTOS.concepto = 'F - Accion Convergencia' THEN OBJETIVOS.multiplicador_internet ELSE OBJETIVOS.multiplicador_pospago END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_OBJETIVOS_MASTER` OBJETIVOS
          ON TRANSACCIONES.id_comisionista = OBJETIVOS.id_comisionista AND TRANSACCIONES.id_mes = CAST(OBJETIVOS.mes AS INT64)

CROSS JOIN UNNEST(canales_pr) canal_pr

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE
                 WHEN TRANSACCIONES.concepto = 'F - Servicio Movil Pospago' THEN 'F - Accion Pospago'
                 WHEN TRANSACCIONES.concepto = 'F - Servicio Fijo'          THEN 'F - Accion Convergencia'
             END = CONCEPTOS.concepto

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('CA', 'MI', 'MP', 'MR', 'NR', 'PH')
      AND TRANSACCIONES.concepto IN ('F - Servicio Fijo', 'F - Servicio Movil Pospago')
      AND COALESCE(CASE WHEN CONCEPTOS.concepto = 'F - Accion Convergencia' THEN OBJETIVOS.multiplicador_internet ELSE OBJETIVOS.multiplicador_pospago END, 0.00) <> 0.00
)
;

END IF;


CREATE OR REPLACE TABLE TEMP.fact_preliqui AS
(
SELECT
      *
     ,prefijo || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM TEMP.fact_preliqui
WHERE comision IS NOT NULL
)
;


-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo` (prefijo, id_mes_pr, canales_pr , 'TEMP.fact_preliqui' , modo);


END