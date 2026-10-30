BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'EXEX';

SET modo = IF(modo IS NULL, 'ACTUALIZAR', modo); 

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES` WHERE agrupacion_canal = 'Exclusivo'));


/*
CALL COMISIONES.pr_extracomisiones_exclusivo_nva_categ(202603, ['ENK'], NULL);
*/


DROP TABLE TEMP.extracomisiones_exclusivo_nva_categ;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.extracomisiones_exclusivo_nva_categ`
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



 --- A - CAMBIO DE TITULARIDAD --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- A - CAMBIO DE TITULARIDAD
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

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON VENTAS.agrupacion_canal = DEALER.agrupacion_canal AND CAMBIO.sfid_id = DEALER.sfid_id

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE CAST(SUBSTR(REPLACE(CAST(VENTAS.activation_date AS STRING), '-', ''), 1, 6) AS INT64) = id_mes_pr
      AND DEALER.canal = canal_pr
      AND DEALER.canal IN ('ENK')
      AND VENTAS.service_type != 'FIX'
      AND VENTAS.billing_type_ds != 'PREPAID'

QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id, marca) = 1
)
;

END IF;




 --- A - PORTABILIDAD (Excluye marcas intragrupo) --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- A - PORTABILIDAD FUERA GRUPO +O
(
SELECT
      TRANSACCIONES.* EXCEPT(cod_producto, cod_tipo_contrato)
     ,'calculado' AS estado
     ,CASE
          WHEN TRANSACCIONES.service_type IN ('INTERNET')  THEN 'A - Portabilidad Fijo'
          WHEN TRANSACCIONES.service_type IN ('MOBILE')    THEN 'A - Portabilidad Movil Pospago'
      END AS concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,40.00 AS comision

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
          ,campaign_code
          ,serial_number
          ,tax_base
          ,claim_code
          ,process_code
          ,proceso_sap
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
     
     -- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

     WHERE TRANSACCIONES.id_mes = id_mes_pr
          AND TRANSACCIONES.estado IN ('calculado', 'validado')
          AND TRANSACCIONES.canal = 'ENK'
          AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'A - Servicio Fijo', 'A - Servicio Fijo 2da Vivienda')
          AND TRANSACCIONES.order_type_agg = 'PORTABILIDAD'
     )
      
     UNION ALL

     (
     SELECT
           PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
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
          ,'Z005' AS cond_pago
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
          ,CAST(NULL AS STRING) AS campaign_code
          ,CAST(NULL AS STRING) AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING) AS claim_code
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

     FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
 
     LEFT JOIN (
               SELECT service_id, phone_nm, marca, cond_pago
               -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
               FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
               WHERE canal IN ('ENK') AND concepto IN ('A - Servicio Movil Pospago','A - Servicio Fijo','A - Servicio Fijo 2da Vivienda','A - Portabilidad Movil Pospago','A - Portabilidad Fijo') GROUP BY 1,2,3,4
               ) TRANSACCIONES
              ON ACTIVACIONES.service_id = TRANSACCIONES.service_id AND ACTIVACIONES.phone_nm = TRANSACCIONES.phone_nm AND ACTIVACIONES.marca = TRANSACCIONES.marca

     WHERE id_mes = id_mes_pr
           AND TRANSACCIONES.service_id IS NULL
           AND (
               (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','7176','7127','7169'))
               OR
               (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id = '2313' AND ACTIVACIONES.marca = 'GUUK')
               )
           AND ACTIVACIONES.order_type_agg = 'PORTABILIDAD'
     )
     ) TRANSACCIONES

LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA
     ON TRANSACCIONES.phone_nm = CAST(INTRA.phone_nm AS STRING)
     AND TRANSACCIONES.account_id = INTRA.account_id
     AND TRANSACCIONES.customer_id = INTRA.customer_id

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.canal = canal_pr
     AND TRANSACCIONES.order_type_agg = 'PORTABILIDAD'
     AND CONCEPTOS.concepto IN ('A - Portabilidad Movil Pospago','A - Portabilidad Fijo')
     -- AND TRANSACCIONES.marca = 'MASMOVIL'
     AND INTRA.operador_donante_unificado NOT IN ('EMBOU','EUSKALTEL','GUUK','JAZZTEL','MASMOVIL','ORANGE','PEPEPHONE','R','SIMYO','TELECABLE','YOIGO')

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY id_mes) = 1
)
;


END IF;




--- B - DEVOLUCION SIM y B - DEVOLUCION SIM YOIGO --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- B - DEVOLUCION SIM y B - DEVOLUCION SIM YOIGO
(
SELECT
      TRANSACCIONES.* EXCEPT(cod_producto, cod_tipo_contrato)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments

     ,CASE
          WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo' AND CANARIAS.matricula IS NOT NULL  THEN 1.07
          WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo'                                     THEN 1.21
          ELSE 1.00
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
     -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
     FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
     WHERE id_mes = id_mes_pr
           AND estado IN ('calculado', 'validado')
           AND canal IN ('ENK')
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
               -- FROM `mm-commissions-reporting.COMISIONES.transacciones`
               FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones`
               WHERE canal IN ('ENK') AND concepto IN ('A - Servicio Movil Pospago', 'B - Devolucion SIM', 'B - Devolucion SIM Yoigo') GROUP BY 1,2,3,4
               ) TRANSACCIONES
              ON ACTIVACIONES.service_id = TRANSACCIONES.service_id AND ACTIVACIONES.phone_nm = TRANSACCIONES.phone_nm AND ACTIVACIONES.marca = TRANSACCIONES.marca

     WHERE id_mes = id_mes_pr
           AND TRANSACCIONES.service_id IS NULL
           AND (
                ACTIVACIONES.canal IN ('ENK') 
                AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','2313','7126','7127')
               )
           AND ACTIVACIONES.marca IN ('YOIGO', 'MASMOVIL', 'LLAMAYA','GUUK')
           AND ACTIVACIONES.order_type_agg != 'MIGRACION CONTRATO'
     )
     ) TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TRANSACCIONES.marca = 'YOIGO' THEN 'B - Devolucion SIM Yoigo' ELSE 'B - Devolucion SIM' END = CONCEPTOS.concepto

LEFT JOIN mm-commissions-reporting.GS.exclusivo_canarias CANARIAS
        ON TRANSACCIONES.seller = CANARIAS.MATRICULA

WHERE TRANSACCIONES.canal = canal_pr
AND TRANSACCIONES.zona_fiscal != 'MEL' 
      AND CASE
              WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo' AND CANARIAS.matricula IS NOT NULL  THEN 1.07
              WHEN CONCEPTOS.concepto = 'B - Devolucion SIM Yoigo'                                     THEN 1.21
              ELSE 1.00
          END > 0.00
)
;

END IF;




--- B - DEVOLUCION SIM MULTISIM y B - DEVOLUCION SIM YOIGO MULTISIM --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- B - DEVOLUCION SIM MULTISIM y B - DEVOLUCION SIM YOIGO MULTISIM
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

-- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TRANSACCIONES.marca = 'YOIGO' THEN 'B - Devolucion SIM Yoigo Multisim' ELSE 'B - Devolucion SIM Multisim' END = CONCEPTOS.concepto

LEFT JOIN mm-commissions-reporting.GS.exclusivo_canarias CANARIAS
        ON TRANSACCIONES.seller = CANARIAS.MATRICULA

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('ENK')
      AND TRANSACCIONES.marca IN ('YOIGO', 'MASMOVIL')
      AND TRANSACCIONES.concepto = 'B - Multisim'
      AND TRANSACCIONES.zona_fiscal != 'MEL'
)
;

END IF;




--- D - EXTRACOMISION SEGMENTACION --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- D - EXTRACOMISION SEGMENTACION 
(
SELECT
      TRANSACCIONES.* EXCEPT(cod_producto, cod_tipo_contrato)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,20.00 AS comision
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
          ,campaign_code
          ,serial_number
          ,tax_base
          ,claim_code
          ,process_code
          ,proceso_sap
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
     
     -- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

     WHERE TRANSACCIONES.id_mes = id_mes_pr
          AND TRANSACCIONES.estado IN ('calculado', 'validado')
          AND TRANSACCIONES.canal = 'ENK'
          AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago')
     )
      
     -- UNION ALL

     -- (
     -- SELECT
     --       PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     --      ,id_mes
     --      ,agrupacion_canal
     --      ,canal
     --      ,1 as unidades
     --      ,id_comisionista
     --      ,distribuidor
     --      ,sfid_id
     --      ,seller
     --      ,nombre_comercio
     --      ,razon_social
     --      ,cif
     --      ,zona_fiscal
     --      ,'Z005' AS cond_pago
     --      ,ACTIVACIONES.marca
     --      ,service_type
     --      ,ACTIVACIONES.phone_nm
     --      ,tariff_id
     --      ,tariff_ds
     --      ,ACTIVACIONES.service_id
     --      ,account_id
     --      ,customer_id
     --      ,line_type_ds
     --      ,bundle_type
     --      ,technology_ds
     --      ,billing_type_ds
     --      ,sale_date
     --      ,activation_date
     --      ,deactivation_date
     --      ,order_id
     --      ,order_type_agg
     --      ,cod_segmento
     --      ,cod_marca
     --      ,cod_tipo_contrato
     --      ,cod_producto
     --      ,cod_canal
     --      ,CAST(NULL AS STRING) AS campaign_code
     --      ,CAST(NULL AS STRING) AS serial_number
     --      ,CAST(NULL AS FLOAT64) AS tax_base
     --      ,CAST(NULL AS STRING) AS claim_code
     --      ,CAST(NULL AS STRING) AS process_code
     --      ,CAST(NULL AS STRING) AS proceso_sap
     --      ,CAST(NULL AS STRING) AS id_registro
     --      ,CAST(NULL AS STRING) AS invoice_id
     --      ,sociedad
     --      ,CAST(NULL AS STRING) AS bp
     --      ,CAST(NULL AS STRING) AS cuenta_contable
     --      ,CAST(NULL AS STRING) AS centro_coste
     --      ,CAST(NULL AS STRING) AS documento_sap
     --      ,CAST(NULL AS STRING) AS documento_sap_posicion
     --      ,CAST(NULL AS STRING) AS fecha_contabilizacion
     --      ,CAST(NULL AS TIMESTAMP) AS creado
     --      ,CAST(NULL AS TIMESTAMP) AS modificado
     --      ,CAST(NULL AS STRING) AS id_factura_drive
     --      ,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad

     -- FROM `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
 
     -- LEFT JOIN (
     --           SELECT service_id, phone_nm, marca, cond_pago, commission_id
     --           FROM `mm-commissions-reporting.COMISIONES.transacciones`
     --           WHERE canal IN ('ENK') AND concepto IN ('A - Servicio Movil Pospago','A - Portabilidad Movil Pospago') GROUP BY 1,2,3,4,5
     --           ) TRANSACCIONES
     --          ON ACTIVACIONES.service_id = TRANSACCIONES.service_id AND ACTIVACIONES.phone_nm = TRANSACCIONES.phone_nm AND ACTIVACIONES.marca = TRANSACCIONES.marca
     
     -- LEFT JOIN (
     --           SELECT service_id, phone_nm, marca, cond_pago, commission_id
     --           FROM `mm-commissions-reporting.COMISIONES.transacciones`
     --           WHERE canal IN ('ENK') AND concepto IN ('D - Extracomision Segmentacion') GROUP BY 1,2,3,4,5
     --           ) SEGMENTACIONES_CALCULADAS
     --          ON ACTIVACIONES.service_id = TRANSACCIONES.service_id AND ACTIVACIONES.phone_nm = TRANSACCIONES.phone_nm AND ACTIVACIONES.marca = TRANSACCIONES.marca

     -- WHERE id_mes = id_mes_pr
     --       AND ACTIVACIONES.seller = TRANSACCIONES.seller 
     --       AND SEGMENTACIONES_CALCULADAS.commission_id IS NULL           
     --       AND ACTIVACIONES.service_type = 'MOBILE'
     --       AND (
     --           (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id IN ('8205', '8145','8212', 'CONT28', 'CONT29','7126','7127','7169'))
     --           OR
     --           (ACTIVACIONES.canal IN ('ENK') AND ACTIVACIONES.tariff_id = '2313' AND ACTIVACIONES.marca = 'GUUK')
     --           )
     -- )
     ) TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
     ON TRANSACCIONES.seller = DEALER.id_comisionista AND DEALER.comisiona

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.canal = canal_pr
      AND DEALER.id_mes = id_mes_pr
      AND (
           TRANSACCIONES.canal IN ('ENK')
           AND TRANSACCIONES.cod_segmento = '12'
          )
      AND CONCEPTOS.concepto = 'D - Extracomision Segmentacion'

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY id_mes) = 1
)
;

END IF;




--- D - EXTRACOMISION RENUEVO LINEA PPAL. --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- D - EXTRACOMISION RENUEVO LINEA PPAL. 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE
          WHEN TRANSACCIONES.bundle_type = 'FMC' THEN 15.00
          ELSE 0.00
      END AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

-- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

LEFT JOIN `mm-datamart-kd.DEVICES.device_base_mysim` RENUEVOS
     ON TRANSACCIONES.serial_number = RENUEVOS.serial_number 
          AND TRANSACCIONES.phone_nm = CAST(RENUEVOS.phone_nm AS STRING)
          AND TRANSACCIONES.order_id = CAST(RENUEVOS.id_subscription_terminal AS STRING)
          AND TRANSACCIONES.marca = RENUEVOS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON TRANSACCIONES.serial_number = MULTI.serial_number 
          AND TRANSACCIONES.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND TRANSACCIONES.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND TRANSACCIONES.marca = MULTI.brand_ds

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND (
           TRANSACCIONES.canal IN ('ENK')
           AND TRANSACCIONES.concepto IN ('B - Renuevo')
           AND TRANSACCIONES.bundle_type = 'FMC'
           AND TRANSACCIONES.service_type = 'MOBILE'
           AND TRANSACCIONES.line_type_ds = 'MAIN'
           AND TRANSACCIONES.campaign_code = '1'
          )
     --  AND RENUEVOS.is_financed_desc = 'SI' -- 20251001 CAMBIO DE MR quitando la excepción a Pagos Únicos
     --  AND RENUEVOS.flag_pay_penalty = 'SI' -- 20251001 CAMBIO DE MR quitando la excepción a Pagos Únicos
      AND RENUEVOS.sell_terminal_origin_ds = 'RENUEVO'
      AND MULTI.multidispositivo = 'PRIMARIO'
      AND CONCEPTOS.concepto = 'D - Extracomision Renuevo Linea Principal'
     --  SI DA ERROR CRUZAR CON V_SERVICIO_RENUEVOS Y SACAR DE ESA VISTA LOS CAMPOS LINE_TYPE_DS Y BUNDLE_TYPE
     -- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_servicio_renuevos` RENUEVOS
     --        ON TRANSACCIONES.serial_number = RENUEVOS.serial_number 
     --             AND TRANSACCIONES.service_id = RENUEVOS.service_id
     --             AND TRANSACCIONES.order_id = CAST(RENUEVOS.order_id AS STRING)
)
;

END IF;




--- D - EXTRACOMISION TÁCTICA RENUEVO --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- D - EXTRACOMISION TÁCTICA RENUEVO 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,12.00 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

-- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.device_base` RENUEVOS
     ON TRANSACCIONES.serial_number = RENUEVOS.serial_number 
          AND TRANSACCIONES.phone_nm = RENUEVOS.phone_nm
          AND TRANSACCIONES.order_id = CAST(RENUEVOS.id_subscription_terminal AS STRING)
          AND TRANSACCIONES.marca = RENUEVOS.brand_ds

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON TRANSACCIONES.serial_number = MULTI.serial_number 
          AND TRANSACCIONES.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND TRANSACCIONES.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND TRANSACCIONES.marca = MULTI.brand_ds

LEFT JOIN `mm-commissions-reporting.GS.exclusivo_rappel_enk` SEGMENTACION
     ON (TRANSACCIONES.sfid_id = SEGMENTACION.id_comisionista OR TRANSACCIONES.seller = SEGMENTACION.id_comisionista)
          AND SEGMENTACION.id_mes = id_mes_pr

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND (
           TRANSACCIONES.canal IN ('ENK')
           AND TRANSACCIONES.concepto IN ('B - Renuevo')
           AND TRANSACCIONES.campaign_code = '1'
          )
      AND SEGMENTACION.categorizacion = 'RODIO'
      AND RENUEVOS.sell_type = 'RENUEVO'
      AND MULTI.multidispositivo = 'PRIMARIO'
      AND CONCEPTOS.concepto = 'D - Extracomision Tactica Renuevo'

QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, marca ORDER BY RENUEVOS.order_date, deactivation_date, RENUEVOS.original_cost_price DESC, serial_number, RENUEVOS.id_subscription_terminal) = 1

)
;

END IF;




--- D - EXTRACOMISION TERMINAL RENUEVO --- 'ENK'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ENK')) THEN

INSERT INTO TEMP.extracomisiones_exclusivo_nva_categ --- D - EXTRACOMISION TERMINAL RENUEVO
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CASE 
          WHEN DEVICES.total_pay_value_without_vat < 40    THEN 'GAMA A'
          WHEN DEVICES.total_pay_value_without_vat < 350   THEN 'GAMA B'
          WHEN DEVICES.total_pay_value_without_vat < 600   THEN 'GAMA C'
          WHEN DEVICES.total_pay_value_without_vat < 1000  THEN 'GAMA D'
          WHEN DEVICES.total_pay_value_without_vat >= 1000 THEN 'GAMA E'
      END AS comments

     ,CASE
          -- RENUEVOS PRIMARIOS FINANCIADOS
          WHEN MULTI.multidispositivo = 'PRIMARIO' AND DEVICES.is_financed_desc = 'SI' THEN
               CASE 
                    WHEN DEVICES.total_pay_value_without_vat < 40                   THEN 0.0
                    WHEN DEVICES.total_pay_value_without_vat < 350                  THEN 5.0
                    WHEN DEVICES.total_pay_value_without_vat < 600                  THEN 15.0
                    WHEN DEVICES.total_pay_value_without_vat BETWEEN 600 AND 999.99 THEN 25.0
                    WHEN DEVICES.total_pay_value_without_vat >= 1000                THEN 40.0
               END
          
          -- RENUEVOS MULTIDISPOSITIVO FINANCIADOS
          WHEN MULTI.multidispositivo = 'SECUNDARIO' AND DEVICES.is_financed_desc = 'SI' THEN
               CASE 
                    WHEN DEVICES.total_pay_value_without_vat < 40                   THEN 0.0
                    WHEN DEVICES.total_pay_value_without_vat < 350                  THEN 5.0
                    WHEN DEVICES.total_pay_value_without_vat < 600                  THEN 15.0
                    WHEN DEVICES.total_pay_value_without_vat BETWEEN 600 AND 999.99 THEN 25.0
                    WHEN DEVICES.total_pay_value_without_vat >= 1000                THEN 40.0
               END
          
          -- RENUEVOS PAGO ÚNICO
          WHEN DEVICES.is_financed_desc = 'NO' THEN
               CASE 
                    WHEN DEVICES.total_pay_value_without_vat < 40                   THEN 0.0
                    WHEN DEVICES.total_pay_value_without_vat < 350                  THEN 5.0
                    WHEN DEVICES.total_pay_value_without_vat < 600                  THEN 15.0
                    WHEN DEVICES.total_pay_value_without_vat BETWEEN 600 AND 999.99 THEN 25.0
                    WHEN DEVICES.total_pay_value_without_vat >= 1000                THEN 40.0
               END
      END AS comision

     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato

-- FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
FROM `mm-commissions-reporting.COMISIONES.preliquidacion_transacciones` TRANSACCIONES

INNER JOIN `mm-datamart-kd.DEVICES.device_base_mysim` DEVICES
          ON TRANSACCIONES.serial_number = DEVICES.serial_number AND TRANSACCIONES.phone_nm = CAST(DEVICES.phone_nm AS STRING) AND TRANSACCIONES.marca = DEVICES.brand_ds AND TRANSACCIONES.order_id = CAST(DEVICES.id_subscription_terminal AS STRING)
          -- AND TRANSACCIONES.service_id = CAST(DEVICES.service_id AS STRING)
          --    AND DEVICES.sell_type ='POSVENTA'
             AND DEVICES.sell_terminal_origin_ds = 'RENUEVO'
             AND DEVICES.terminal_status_ds IN UNNEST(`mm-commissions-reporting.COMISIONES.f_terminal_status`())
          --    AND COALESCE(DEVICES.device_type_ds ,'ROUTER') NOT IN ('ROUTER', 'Hotspotwifi')

LEFT JOIN `mm-commissions-reporting.TEMP.multidispositivos_final` MULTI
     ON TRANSACCIONES.serial_number = MULTI.serial_number 
          AND TRANSACCIONES.phone_nm = CAST(MULTI.phone_nm AS STRING)
          AND TRANSACCIONES.order_id = CAST(MULTI.id_subscription_terminal AS STRING)
          AND TRANSACCIONES.marca = MULTI.brand_ds

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN ('ENK')
      AND TRANSACCIONES.concepto = 'B - Renuevo'
      AND TRANSACCIONES.billing_type_ds = 'POSTPAID'
      AND MULTI.sell_type = 'RENUEVO'
      AND CONCEPTOS.concepto = 'D - Extracomision Terminal Renuevo'
GROUP BY ALL
HAVING comision <> 0.00

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.serial_number) = 1
)
;

END IF;


CREATE OR REPLACE TABLE TEMP.extracomisiones_exclusivo_nva_categ AS
(
SELECT
      * 
     ,prefijo || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM TEMP.extracomisiones_exclusivo_nva_categ
WHERE comision IS NOT NULL
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo` (prefijo, id_mes_pr, canales_pr , 'TEMP.extracomisiones_exclusivo_nva_categ' , modo);

END