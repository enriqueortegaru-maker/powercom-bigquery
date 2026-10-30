BEGIN

DECLARE prefijo STRING;
DECLARE canales_pr ARRAY<STRING>;


IF canales_pr IS NULL THEN SET canales_pr = ['EML','ENX','EYG','ENK'];

END IF;

SET prefijo = 'CESE';

/*
CALL COMISIONES.pr_cese_negocio(202507);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cese_negocio` AS

SELECT
prefijo||'_'||CAST(a.id_mes AS STRING)||'_'||ROW_NUMBER() OVER()||'_comisiones' AS commission_id
,'calculado' AS estado
,PARSE_DATE('%Y%m', CAST(a.id_mes AS STRING)) AS mes_liquidado
,a.id_mes
,b.agrupacion_canal
,b.canal
,'Z - Apoyo Cese Negocio' AS concepto
,'ASPC' AS tipo_concepto
,CAST(null AS INT64) AS unidades
,a.importe AS comision
,b.id_comisionista
,b.distribuidor
,b.sfid_id
,a.seller
,b.nombre_comercio
,b.razon_social
,b.cif
,b.zona_fiscal
,b.cond_pago
,'ORANGE' AS marca
,'MOBILE' AS service_type
,CAST(null AS STRING) AS phone_nm
,CAST(null AS STRING) AS tariff_id
,CAST(null AS STRING) AS tariff_ds
,CAST(null AS STRING) AS service_id
,CAST(null AS STRING) AS account_id
,CAST(null AS STRING) AS customer_id
,CAST(null AS STRING) AS line_type_ds
,CAST(null AS STRING) AS bundle_type
,CAST(null AS STRING) AS technology_ds
,CAST(null AS STRING) AS billing_type_ds
,CAST(null AS DATE) AS sale_date
,CAST(null AS DATE) AS activation_date
,CAST(null AS DATE) AS deactivation_date
,CAST(null AS STRING) AS order_id
,CAST(null AS STRING) AS order_type_agg
,'99' AS cod_segmento
,'05' AS cod_marca
,'99' AS cod_tipo_contrato
,'999' AS cod_producto
,'27' AS cod_canal
,CAST(null AS STRING) AS campaign_code
,CAST(null AS STRING) AS serial_number
,CAST(null AS FLOAT64) AS tax_base
,'Ayuda Tiendas' AS claim_code
,'Ayuda Tiendas' AS process_code
,CAST(null AS STRING) AS comments
,'C_MANUAL' as facturador
,'8000' AS sociedad
,CURRENT_TIMESTAMP () as creado
FROM `mm-commissions-reporting.GS.CESE_NEGOCIO_EXCLUSIVO` a
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` b
    ON a.seller = b.id_comisionista AND a.id_mes = b.id_mes
CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE a.importe IS NOT NULL
AND a.id_mes = id_mes_pr
AND b.canal = canal_pr;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr , 'TEMP.cese_negocio' , 'ACTUALIZAR');


-- Update sociedad a 8000 --
UPDATE `mm-commissions-reporting.COMISIONES.transacciones`
SET sociedad = '8000'
WHERE id_mes = id_mes_pr
AND agrupacion_canal = 'Exclusivo'
AND estado = 'calculado'
AND commission_id LIKE 'CESE_%';


END