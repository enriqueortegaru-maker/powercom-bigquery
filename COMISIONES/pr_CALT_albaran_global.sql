BEGIN

DECLARE inicio_mes, fin_mes DATE;
DECLARE prefijo STRING;
DECLARE canales_pr ARRAY<STRING>;

SET prefijo = 'ARAB';

SET canales_pr = ['ALT'];

SET inicio_mes = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), MONTH);
SET fin_mes = LAST_DAY(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)));

--Procedimiento que crea la tabla global historificada de las transacciones de ALTERNA. El origen de los datos viene dado por un fichero excel que se desgarga en el siguiente 
-- link: https://yoigo1-my.sharepoint.com/personal/diego_campo_masmovil_com/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdiego%5Fcampo%5Fmasmovil%5Fcom%2FDocuments%2FWholesale%2FCableoperadores%2F1%5FOPERADORES%2FAlterna%2FAdquisici%C3%B3n%20Cartera%2F06%5FIMO%2F03%2E%20Cierre%20Menusal&ga=1
-- Y se sube con el siguiente Python https://colab.research.google.com/drive/1Rsf4kGOl1IWe7wPF5qC--vaB4E2bYsKo#scrollTo=hOHlEcdkm7iC

-- CALL `mm-commissions-reporting.COMISIONES.pr_CALT_albaran_global`(202509)

-- ALBARAN GLOBAL 

  DELETE `mm-commissions-reporting.B2B.CALT_albaran_global` 
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_albaran_global` 

    --CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.CALT_albaran_global`  AS

    SELECT 
      CAST(FORMAT_DATE('%Y%m',(DATE_SUB(PARSE_DATE('%Y-%m',ciclo), INTERVAL 1 MONTH))) AS INT64) AS id_mes,
      DATE_SUB(PARSE_DATE('%Y-%m',ciclo), INTERVAL 1 MONTH)                                      AS fecha_mes,
      PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_inicio, 1, 10))                                        AS fecha_inicio,
      PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_fin, 1, 10))                                           AS fecha_fin,
      CAST(id_marca AS STRING)                                                                   AS id_marca,
      IF(id_marca = '9999' OR id_marca = '177','BUTIK','DEALERS')                                AS cat_marca,
      CAST(UPPER(nombre_marca) AS STRING)                                                        AS nombre_marca,
      CAST(id_dealer AS STRING)                                                                  AS id_dealer,
      CAST(nombre_dealer AS STRING)                                                              AS nombre_dealer,
      REGEXP_REPLACE(id_shop, r'\.0$', '')                                                       AS id_shop,
      CAST(nombre_shop AS STRING)                                                                AS nombre_shop,
      CAST(id_account_manager AS STRING)                                                         AS id_account_manager,
      CAST(nombre_account_manager AS STRING)                                                     AS nombre_account_manager,
      CAST(venta_online AS STRING)                                                               AS venta_online,
      CAST(tipo_documento AS STRING)                                                             AS tipo_documento,
      CAST(documento AS STRING)                                                                  AS documento,
      CAST(cliente AS STRING)                                                                    AS cliente,
      CAST(id_externo_cliente AS STRING)                                                         AS id_externo_cliente,
      CAST(tipo_contrato AS STRING)                                                              AS tipo_contrato,
      CAST(tipo_paquete AS STRING)                                                               AS tipo_paquete,
      IF(UPPER(tipo_paquete) LIKE '%P%','CONV','OM')                                             AS grupo,
      CAST(tecnologia AS STRING)                                                                 AS tecnologia,
      CAST(tipo_linea AS STRING)                                                                 AS tipo_linea,
      CAST(linea AS STRING)                                                                      AS linea,
      CAST(tipo_producto AS STRING)                                                              AS tipo_producto,
      CAST(CTO_TLF AS STRING)                                                                    AS parque_ID,
      CAST(producto AS STRING)                                                                   AS producto,
      CAST(RESUMEN_N1 AS STRING)                                                                 AS RESUMEN_N1,
      CAST(RESUMEN_N2 AS STRING)                                                                 AS RESUMEN_N2,
      CAST(RESUMEN_N3 AS STRING)                                                                 AS RESUMEN_N3,
      CAST(RESUMEN_N4 AS STRING)                                                                 AS RESUMEN_N4,
      CAST(tipo_cargo AS STRING)                                                                 AS tipo_cargo,
      PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_alta, 1, 10))                                          AS fecha_alta,
      PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_baja, 1, 10))                                          AS fecha_baja,
      CASE
        WHEN tipo_cargo LIKE '%Cuota%' THEN
          CASE
            WHEN PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_alta, 1, 10))    >= inicio_mes AND PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_alta, 1, 10))    <=  fin_mes THEN 1
            ELSE 0
          END
        ELSE 0
      END                                                                                        AS alta,
      CASE
        WHEN tipo_cargo LIKE '%Cuota%' THEN 
          CASE
            WHEN PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_baja, 1, 10))   >= inicio_mes AND PARSE_DATE('%Y-%m-%d', SUBSTR(fecha_baja, 1, 10))   <= fin_mes THEN -1
            ELSE 0
          END
        ELSE 0
      END                                                                                        AS baja, 
      CAST(minutos AS FLOAT64)                                                                   AS minutos,
      CAST(megabytes AS FLOAT64)                                                                 AS megabytes,
      CAST(sms AS FLOAT64)                                                                       AS sms,
      CAST(tipo_impuesto AS STRING)                                                              AS tipo_impuesto,
      CAST(valor_impuesto AS FLOAT64)                                                            AS valor_impuesto,
      CAST(importe_neto AS FLOAT64)                                                              AS importe_neto,
      CAST(impuestos AS FLOAT64)                                                                 AS impuestos,
      CAST(importe_total AS FLOAT64)                                                             AS importe_total,
      CAST(iban_cliente AS STRING)                                                               AS iban_cliente,
      CAST(customerDataContactPhone AS STRING)                                                   AS customerDataContactPhone,
      CAST(email_cliente AS STRING)                                                              AS email_cliente,
      CAST(direccion_cliente AS STRING)                                                          AS direccion_cliente,
      CAST(direccion_tipo_via AS STRING)                                                         AS direccion_tipo_via,
      CAST(direccion_nombre_via AS STRING)                                                       AS direccion_nombre_via,
      CAST(direccion_numero_via AS STRING)                                                       AS direccion_numero_via,
      CAST(direccion_info_adicional AS STRING)                                                   AS direccion_info_adicional,
      CAST(direccion_municipio AS STRING)                                                        AS direccion_municipio,
      CAST(direccion_provincia AS STRING)                                                        AS direccion_provincia,
      CAST(invoiceId AS STRING)                                                                  AS invoiceId,
      CAST(coste_cesion AS FLOAT64)                                                              AS coste_cesion,
      CAST(externalTransactionId AS STRING)                                                      AS externalTransactionId,
      CAST(externalTransactionLineId AS STRING)                                                  AS externalTransactionLineId,
      CAST(externalIntegralTransactionId AS STRING)                                              AS externalIntegralTransactionId,
      CAST(externalIntegralTransactionAlias AS STRING)                                           AS externalIntegralTransactionAlias,
      CAST(externalSepaId AS STRING)                                                             AS externalSepaId,
      CAST(invoiceDataFiscalId AS STRING)                                                        AS invoiceDataFiscalId,
      CAST(invoiceDataName AS STRING)                                                            AS invoiceDataName,
      CAST(invoiceDataSurname1 AS STRING)                                                        AS invoiceDataSurname1,
      CAST(invoiceDataSurname2 AS STRING)                                                        AS invoiceDataSurname2,
      CAST(invoiceDataCompanyName AS STRING)                                                     AS invoiceDataCompanyName,
      CAST(invoiceDataFiscalIdType AS STRING)                                                    AS invoiceDataFiscalIdType,
      CAST(invoiceDataEmail AS STRING)                                                           AS invoiceDataEmail,
      CAST(invoiceDataContactPhone AS STRING)                                                    AS invoiceDataContactPhone,
      CAST(direccion_facturacion_tipo_via AS STRING)                                             AS direccion_facturacion_tipo_via,
      CAST(direccion_facturacion_nombre_via AS STRING)                                           AS direccion_facturacion_nombre_via,
      CAST(direccion_facturacion_numero_via AS STRING)                                           AS direccion_facturacion_numero_via,
      CAST(direccion_facturacion_info_adicional AS STRING)                                       AS direccion_facturacion_info_adicional,
      CAST(direccion_facturacion_municipio AS STRING)                                            AS direccion_facturacion_municipio,
      CAST(direccion_facturacion_provincia AS STRING)                                            AS direccion_facturacion_provincia,
      CAST(direccion_facturacion AS STRING)                                                      AS direccion_facturacion,
      CAST(contractId AS STRING)                                                                 AS contractId,
      CAST(subscriptionId AS STRING)                                                             AS subscriptionId,
      CAST(bundleId AS STRING)                                                                   AS bundleId,
      CAST(subscriptionBundleId AS STRING)                                                       AS subscriptionBundleId,
      CAST(productInstanceId AS STRING)                                                          AS productInstanceId,
      CAST(invoiceNumber AS STRING)                                                              AS invoiceNumber,
      CAST(codigo_postal AS STRING)                                                              AS codigo_postal,
      CAST(sesiones AS STRING)                                                                   AS sesiones,
      CAST(PVPR AS FLOAT64)                                                                      AS PVPR,
      CAST(Ratio_periodo AS FLOAT64)                                                             AS Ratio_periodo,
      CAST(Ratio_dealer AS FLOAT64)                                                              AS Ratio_dealer,
      CAST(Facturacion_para_escalado AS FLOAT64)                                                 AS Facturacion_para_escalado,
      CAST(IUA AS STRING)                                                                        AS IUA,
      CAST(MIGRADO AS STRING)                                                                    AS MIGRADO,
    FROM `mm-commissions-reporting.TEMP.CALT_albaran_global_row`
    WHERE CAST(FORMAT_DATE('%Y%m',(DATE_SUB(PARSE_DATE('%Y-%m',ciclo), INTERVAL 1 MONTH))) AS INT64) = mes_int
;

-- CARGA TEC DS

  DELETE `mm-commissions-reporting.B2B.CALT_albaran_global_tec_DS` 
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_albaran_global_tec_DS` 

    -- CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.CALT_albaran_global_tec_DS`  AS
   
    WITH base AS (
      SELECT 
        id_mes,
        fecha_mes,
        cat_marca,
        tecnologia,
        COUNT(DISTINCT linea) AS linea,
        CASE 
          WHEN cat_marca = 'BUTIK' THEN SUM(importe_neto)
          ELSE SUM(Facturacion_para_escalado) 
          END AS escalado,
        CASE
          WHEN cat_marca = 'BUTIK' THEN 0
          ELSE SUM(coste_cesion) 
        END AS PVP_dealer,
        FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
        WHERE id_mes = mes_int
        GROUP BY ALL
      )

      SELECT *,
      CASE
          WHEN cat_marca = 'BUTIK' THEN 0
          ELSE escalado - PVP_dealer
      END AS airtime,
      CASE
          WHEN cat_marca = 'BUTIK' THEN 0
          ELSE 1-(PVP_dealer/escalado)
      END AS porc_airtime,
      SAFE_DIVIDE(SUM(escalado),LINEA) AS ARPU
      FROM base
      GROUP BY ALL
    
; 
  
-- CARGA IMP DS

  DELETE `mm-commissions-reporting.B2B.CALT_albaran_global_imp_DS` 
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_albaran_global_imp_DS`

  -- CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.CALT_albaran_global_imp_DS`  AS
   
  WITH base AS (
    SELECT 
      id_mes,
      fecha_mes,
      cat_marca,
      RESUMEN_N4,
      tipo_impuesto,
      valor_impuesto,
      COUNT(DISTINCT linea) AS linea,
      CASE 
        WHEN cat_marca = 'BUTIK' THEN SUM(importe_neto)
        ELSE SUM(Facturacion_para_escalado) 
        END AS escalado,
      CASE
        WHEN cat_marca = 'BUTIK' THEN 0
        ELSE SUM(coste_cesion) 
      END AS PVP_dealer,
      FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
      WHERE id_mes = mes_int
      GROUP BY ALL
    )

    SELECT *,
    CASE
        WHEN cat_marca = 'BUTIK' THEN 0
        ELSE escalado - PVP_dealer
    END AS airtime,
    CASE
        WHEN cat_marca = 'BUTIK' THEN 0
        ELSE 1-(PVP_dealer/escalado)
    END AS porc_airtime,
    SAFE_DIVIDE(SUM(escalado),LINEA) AS ARPU
    FROM base
    GROUP BY ALL
;

-- CARGA RESUMEN FACTURACIÓN DS

  DELETE `mm-commissions-reporting.B2B.CALT_albaran_global_resumFact_DS` 
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.CALT_albaran_global_resumFact_DS`

  -- CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.CALT_albaran_global_resumFact_DS`  AS
   
  WITH base AS (
    SELECT 
      id_mes,
      fecha_mes,
      cat_marca,
      RESUMEN_N4 AS tipo,
      tecnologia,
      CASE 
        WHEN cat_marca = 'BUTIK' THEN SUM(importe_neto)
        ELSE SUM(Facturacion_para_escalado) 
        END AS escalado,
      CASE
        WHEN cat_marca = 'BUTIK' THEN 0
        ELSE SUM(coste_cesion) 
      END AS PVP_dealer,
      FROM `mm-commissions-reporting.B2B.CALT_albaran_global`
      WHERE id_mes = mes_int
      GROUP BY ALL
    )

    SELECT *,
    CASE
        WHEN cat_marca = 'BUTIK' THEN 0
        ELSE escalado - PVP_dealer
    END AS airtime
    FROM base
    GROUP BY ALL
;

--SUBIDA TRANSACCIONES

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALT_albaran_global_transacciones`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

  WITH 
  
    tr AS (  
      SELECT 
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), MONTH) 
                                                       AS mes_liquidado, 
      mes_int                                          AS id_mes, 
      'B2B - Alterna'                                  AS agrupacion_canal,
      'ALT'                                            AS canal,
      CASE
        WHEN tipo = 'MOVIL' THEN 'C - Comisiones cartera Movil' 
        WHEN tipo = 'FIBRA' THEN 'C - Comisiones cartera Fibra' 
        ELSE NULL
      END                                              AS concepto,
      'AIRT'                                           AS tipo_concepto,
      1                                                AS unidades,
      SUM(airtime)                                     AS comision,
      'F40411'                                         AS id_comisionista,
      'F40411'                                         AS distribuidor,
      'F40411'                                         AS sfid_id,
      'F40411'                                         AS seller,
      'THE TELECOM BOUTIQUE, S.L.'                     AS nombre_comercio,
      'THE TELECOM BOUTIQUE, S.L.'                     AS razon_social, 
      'B87522652'                                      AS cif,
      'PEN'                                            AS zona_fiscal,
      'ALTERNA'                                        AS marca,
      CASE
        WHEN tipo = 'FIBRA' THEN 'INTERNET'
        WHEN tipo = 'MOVIL' THEN 'MOBILE'
        ELSE NULL
      END                                              AS service_type,
      CAST(NULL AS STRING)                             AS phone_nm,
      CAST(NULL AS STRING)                             AS tariff_id,
      CAST(NULL AS STRING)                             AS tariff_ds,
      CAST(NULL AS STRING)                             AS service_id,
      CAST(NULL AS STRING)                             AS account_id,
      CAST(NULL AS STRING)                             AS customer_id,
      CAST(NULL AS STRING)                             AS line_type_ds,
      CAST(NULL AS STRING)                             AS bundle_type,
      CAST(NULL AS STRING)                             AS technology_ds,
      CAST(NULL AS STRING)                             AS billing_type_ds,
      CAST(NULL AS DATE)                               AS init_date,
      CAST(NULL AS DATE)                               AS end_date,
      CAST(NULL AS DATE)                               AS sale_date,
      CAST(NULL AS DATE)                               AS activation_date,
      CAST(NULL AS DATE)                               AS deactivation_date,
      CAST(NULL AS STRING)                             AS order_id,
      CAST(NULL AS STRING)                             AS order_type_agg,
      '42'                                             AS cod_segmento,
      '09'                                             AS cod_marca,
      CASE 
        WHEN tipo = 'MOVIL' THEN '20'
        WHEN tipo = 'FIBRA' THEN '61'   
        ELSE NULL   
      END                                              AS cod_tipo_contrato,
      '30'                                             AS cod_canal,
      CASE 
        WHEN tipo = 'FIBRA' THEN '041'   
        ELSE '039'   
      END                                              AS cod_producto,
      CAST(NULL AS STRING)                             AS campaign_code,
      CAST(NULL AS STRING)                             AS serial_number,
      CAST(NULL AS FLOAT64)                            AS tax_base,
      CAST(NULL AS STRING)                             AS claim_code,
      CAST(NULL AS STRING)                             AS process_code,
      CAST(NULL AS STRING)                             AS comments,
      'C_MANUAL'                                       AS facturador,
      CAST(NULL AS STRING)                             AS proceso_sap,
      CAST(NULL AS STRING)                             AS id_registro,
      CAST(NULL AS STRING)                             AS invoice_id,
      'X001'                                           AS sociedad,
      CAST(NULL AS STRING)                             AS bp,
      CAST(NULL AS STRING)                             AS cuenta_contable,
      CAST(NULL AS STRING)                             AS centro_coste,
      CAST(NULL AS STRING)                             AS documento_sap,
      CAST(NULL AS STRING)                             AS documento_sap_posicion,
      CAST(NULL AS STRING)                             AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)                          AS creado,
      CAST(NULL AS TIMESTAMP)                          AS modificado,
      CAST(NULL AS STRING)                             AS id_factura_drive,
      CAST(NULL AS STRING)                             AS emails_acceso_trazabilidad
    FROM `mm-commissions-reporting.B2B.CALT_albaran_global_resumFact_DS`
    WHERE 1=1
      AND id_mes = mes_int
      AND cat_marca = 'DEALERS'
    GROUP BY ALL
    )
    
  SELECT
    prefijo||'_'||mes_int||'_'||canal||'_'||row_number () over() AS commission_id, 
    *
  FROM tr
  ;

  call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
  (
    prefijo,
    mes_int,
    canales_pr,
    'TEMP.CALT_albaran_global_transacciones',
    'ACTUALIZAR'
  )
;

-- CALCULO PROCEDIMIENTO DE SUBTABLAS

CALL `mm-commissions-reporting.COMISIONES.pr_CALT_albaran_procesado`(mes_int)

;
END