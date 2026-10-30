BEGIN

INSERT INTO `mm-commissions-reporting.TERMINALES.TERMINALES` (

SELECT
CLAIM_CODE_PR||'_'|| -- PONEMOS CLAIM_CODE A INSERTAR
CAST((EXTRACT(YEAR FROM current_date())||EXTRACT(MONTH FROM current_date())) AS INTEGER)||'_'|| -- INCLUIMOS ID_MES DONDE SE LIQUIDARÁ
extract(day from CURRENT_DATETIME())||' - '||SUBSTR((CAST(CURRENT_TIME() AS STRING)),1,13)||'_'|| -- AÑADIMOS DÍA Y HORA DE INSERCIÓN POR SI EN UN MISMO CLAIM SE INSERTA EN DISTINTOS DÍAS Y MOMENTOS.
row_number () over () AS commission_id,
'calculado' as estado,
  --DATE_ADD(DATE_ADD(LAST_DAY(current_date()), INTERVAL 1 DAY),INTERVAL -1 MONTH) AS mes_liquidado,
CAST(mes_liquidado AS DATE) AS mes_liquidado, --tomo el del GS. El procedimiento será actualizarlo antes de ejecutar
  -- CAST((EXTRACT(YEAR FROM current_date())||EXTRACT(MONTH FROM current_date())) AS INTEGER) as id_mes, 
  --CAST(SUBSTR(CAST(current_date() AS STRING),1,4)||SUBSTR(CAST(current_date() AS STRING),6,2) AS INT64) as id_mes,
CAST(id_mes AS INT64) as id_mes, --tomo el del GS. El procedimiento será actualizarlo antes de ejecutar
agrupacion_canal,
canal,
IF(CONCEPTO LIKE 'T%',REPLACE(CONCEPTO,'T - ','X - '),CONCEPTO)concepto,
tipo_concepto,
unidades,
CAST(comision AS FLOAT64) AS COMISION,
id_comisionista,
distribuidor,
sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
zona_fiscal,
marca,
service_type,
CAST(phone_nm AS STRING) AS PHONE_NM,
tariff_id,
tariff_ds,
CAST(service_id AS STRING) AS service_id ,
CAST(account_id AS STRING) AS account_id,
CAST(customer_id AS STRING) AS customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
cast(null as date) AS DEACTIVATION_DATE,
CAST(order_id AS STRING) AS order_id,
order_type_agg,
CAST(cod_segmento AS STRING) AS cod_segmento,
if(CAST(cod_marca AS STRING) NOT LIKE '0%','0'||CAST(cod_marca AS STRING),CAST(cod_marca AS STRING))  AS cod_marca,
CAST(cod_tipo_contrato AS STRING) AS cod_tipo_contrato,
if(CAST(cod_producto AS STRING) NOT LIKE '0%','0'||CAST(cod_producto AS STRING),CAST(cod_producto AS STRING))  AS cod_producto,
CAST(cod_canal AS STRING) AS cod_canal,
CLAIM_CODE_PR AS claim_code,
campaign_code,
'AJUS_MANUAL' AS process_code,
comments,
'C_IFS' as facturador,  --facturador,  --Modificado el 2025/12/10. Antes tomaba el que tuviera en la GS la transaccion original.
CAST(NULL AS STRING) AS proceso_sap,
CAST(NULL AS STRING) AS id_registro,
CAST(NULL AS STRING) AS invoice_id,
'X001' AS sociedad,
CAST(NULL AS STRING) AS bp,
CAST(NULL AS STRING) AS cuenta_contable,
CAST(NULL AS STRING) AS centro_coste,
CAST(NULL AS STRING) AS documento_sap,
CAST(NULL AS STRING) documento_sap_posicion,
CAST(NULL AS STRING) AS fecha_contabilizacion,
CURRENT_TIMESTAMP() AS creado,
CURRENT_TIMESTAMP() AS modificado,
CAST(NULL AS STRING) AS id_factura_drive,
[''] AS emails_acceso_trazabilidad,
CAST(IMEI AS STRING) AS IMEI,
CAST(DUPLICATED_IMEI AS STRING) AS DUPLICATED_IMEI,
AFTER_SALE,
PRODUCT_CODE,
TERMINAL_NAME,
CONTRACT_ID,
PURCH_PRICE,
CAST(NET_SUBSIDY AS FLOAT64) AS NET_SUBSIDY,
END_USER_PRICE,
CAST(COSTE_DEVICE AS FLOAT64) AS COSTE_DEVICE,
OFFER_SEGMENT,
INSTALLMENT_ID,
FINANCIADO

FROM
`mm-commissions-reporting.GS.AJUST_MAN_TERMINALES`
where
commission_id is not null
  );

  END