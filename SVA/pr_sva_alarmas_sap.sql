BEGIN

-- CALL `mm-commissions-reporting.SVA.pr_sva_alarmas_sap`('2022-11-01')

DECLARE table_name, qry, month_name STRING;


CREATE OR REPLACE TEMPORARY TABLE alarmas_sap AS

SELECT
      'SVA_alarmas'|| FORMAT_DATE('%Y%m%d', mes_pr)|| '_' || ROW_NUMBER() OVER() AS id_registro
     ,sociedad
     ,id_comisionista
     ,tipo_comisionista
     ,CIF
     ,zona_fiscal
     ,tipo_concepto
     ,descripcion_concepto
     ,SUM(uds) AS uds
     ,SUM(importe_base) AS importe_base
     ,moneda
     ,via_pago
     ,cond_pago
     ,cod_canal
     ,cod_producto
     ,cod_tipo_contrato
     ,cod_marca
     ,cod_operador
     ,cod_segmento
     ,facturador
     ,ARRAY_AGG (
                STRUCT (
                       id_registro AS id_registro_interno
                      ,clasificacion_concepto
                      ,canal
                      ,subscription_id
                      ,product_type
                      ,bundle_type
                      ,msisdn
                      ,fecha_activacion
                      ,fecha_baja
                      --,account_id
              
                      ,customer_id
                      ,sfid_unico
                      ,tienda
                      ,distribuidor
                      ,fecha
                      ,agrupacion_cod_tipo_contrato
                      ,segmento
                      ,razon_social
                      ,nombre_comercio
                      ,order_id
                      ,Product_Id
                      ,Product
                      ,user_id
                      ,marca
                      ,uds
                      ,importe_base
                       )
                ) AS trazabilidad

FROM `mm-commissions-reporting.SVA.sva_alarmas_2*`
WHERE PARSE_DATE('%Y%m%d', '2' || _table_suffix) = mes_pr --AND canal IN ('BY', 'DX', 'KH', 'LB', 'LM', 'LY', 'MD', 'TA')
GROUP BY 2,3,4,5,6,7,8,11,12,13,14,15,16,17,18,19,20
;


SET month_name = REPLACE(CAST(mes_pr AS STRING), '-', '');
SET table_name = CONCAT('`mm-commissions-reporting.SVA.sva_alarmas_sap_', month_name, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || table_name || ' AS SELECT * FROM ' || 'alarmas_sap';
EXECUTE IMMEDIATE qry;


END