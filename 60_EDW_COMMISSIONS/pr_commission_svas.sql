BEGIN


-- CALCULA LAS COMISIONES DE LOS DISTINTOS SVAS --


/*
CALL `mm-commissions-reporting.60_EDW_COMMISSIONS.pr_commission_svas`(202411, NULL, NULL, NULL);
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE meses ARRAY <DATE>;
DECLARE s INT64 DEFAULT 0;
DECLARE mes_string, sva, qry STRING;


/* Si solo se indica la variable de "mes_inicio", el procedimiento se ejecutará para solo un mes. Si se indica la variable de "mes_fin", el procedimiento se ejecutará para el rango de meses entre "mes_inicio" y "mes_fin" */

IF mes_fin IS NULL THEN SET meses = ARRAY(SELECT PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)));
ELSE SET meses = GENERATE_DATE_ARRAY(PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)), PARSE_DATE('%Y%m', CAST(mes_fin AS STRING)), INTERVAL 1 MONTH);
END IF;


/* Si la variable "canales_pr" viene a nulo, se cogerán todos los canales de la Google Sheet de Control */

SET canales_pr = COALESCE(canales_pr, (SELECT ARRAY_AGG(canal) FROM `mm-commissions-reporting.GS.CANALES`));


/* Si la variable de "svas_pr" viene a nulo, se utilizarán los valores predeterminados */
IF ARRAY_LENGTH(svas_pr) IS NULL THEN SET svas_pr = ['ALARMAS'];
END IF;


DROP TABLE `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.commission_svas`;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.40_INTEGRATION_COMMISSIONS.commission_svas`
(
 commission_id     STRING
,estado            STRING
,mes_liquidado     DATE
,id_mes            INT64
,agrupacion_canal  STRING
,canal             STRING
,concepto          STRING
,tipo_concepto     STRING
,unidades          INT64
,comision          FLOAT64
,id_comisionista   STRING
,distribuidor      STRING
,sfid_id           STRING
,seller            STRING
,nombre_comercio   STRING
,razon_social      STRING
,cif               STRING
,zona_fiscal       STRING
,marca             STRING
,service_type      STRING
,phone_nm          STRING
,tariff_id         STRING
,tariff_ds         STRING
,service_id        STRING
,account_id        STRING
,customer_id       STRING
,line_type_ds      STRING
,bundle_type       STRING
,technology_ds     STRING
,billing_type_ds   STRING
,sale_date         DATE
,activation_date   DATE
,deactivation_date DATE
,order_id          STRING
,order_type_agg    STRING
,cod_segmento      STRING
,cod_marca         STRING
,cod_tipo_contrato STRING
,cod_producto      STRING
,cod_canal         STRING
,campaign_code     STRING
,serial_number     STRING
,tax_base          FLOAT64
,claim_code        STRING
,process_code      STRING
,comments          STRING
,facturador        STRING
,sociedad          STRING
)
;


 --- ALARMAS --- 'D2D','D2N', 'DEM, 'EML', 'EYG', 'MI', 'MR', 'PH', 'XI', 'XO', 'XS'
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ECI', 'EDB', 'EML', 'EYG')) THEN

INSERT INTO TEMP.fact --- A - CAMBIO DE TITULARIDAD
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

FROM `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS

INNER JOIN `mm-commissions-reporting.TEMP.cambio_titular` CAMBIO
          ON VENTAS.contract_id = CAMBIO.order_contract_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON VENTAS.agrupacion_canal = DEALER.agrupacion_canal AND CAMBIO.sfid_id = DEALER.sfid_id

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE CAST(SUBSTR(REPLACE(CAST(VENTAS.activation_date AS STRING), '-', ''), 1, 6) AS INT64) = id_mes_pr
      AND DEALER.canal = canal_pr
      AND DEALER.canal IN ('ECI', 'EDB', 'EML', 'EYG')
      --AND order_type_agg = 'HLR'
      AND VENTAS.service_type != 'FIX'

QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id, marca) = 1
)
;

END IF;


END