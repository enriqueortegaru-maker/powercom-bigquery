BEGIN

DECLARE prefijo string;

SET prefijo = 'LEAD';


--call `mm-commissions-reporting.COMISIONES.pr_leads_ceres`(202501);
--call `mm-commissions-reporting.COMISIONES.pr_validar_agrupacion_canal`(null, 'ALRM', 125612.80)


-- Maestro sfids y sellers --

CREATE OR REPLACE TABLE TEMP.dealers_ceres AS

WITH DEALER AS (
SELECT DISTINCT masdealer_code, mysim_society
FROM `mm-mas-dealers-prod.ZZ_DEALERS.MAP_DEALERS_MYSIM_IAM` 
WHERE subchannel = 'OUTBOUND CARTERA'
AND mysim_society LIKE 'CAR%'  
AND masdealer_code LIKE '%_CE'
ORDER BY 1
)

SELECT a.mysim_society, a.masdealer_code, b.* EXCEPT(sfid_id)
FROM DEALER a
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` b
     ON a.mysim_society = b.sfid_id 
ORDER BY a.masdealer_code, b.id_mes DESC
;

-- Cálculo Lead Cita --

CREATE OR REPLACE TABLE TEMP.leads_ceres AS 

WITH calculo_leads AS (

SELECT 
id_mes_pr AS id_mes,
prefijo||'_'||CAST(id_mes_pr AS STRING)||'_'||CAST(b.canal AS STRING)||'_'||ROW_NUMBER() OVER() AS commission_id,
C.agrupacion_canal,
b.canal,
'B - Lead Camp.' AS concepto,
'OTRS' AS tipo_concepto,
1 AS unidades,
CASE WHEN tipo_cita = 'CERRADA' AND f_realizada = 'Si' THEN 25.0
     WHEN tipo_cita = 'CERRADA' AND f_realizada = 'No' THEN 5.0
     WHEN tipo_cita = 'ABIERTA' AND f_realizada = 'Si' THEN 10.0 
END AS comision,
b.id_comisionista, 
b.distribuidor,
b.id_comisionista AS sfid_id,
UPPER(SPLIT(a.cct_email,'@')[OFFSET(0)]) AS seller,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,
a.brand_Ds AS marca, 
'INTERNET' AS service_type,
CAST (null AS STRING) AS phone_nm,
CAST (null AS STRING) AS tariff_id,
CAST (null AS STRING) AS tariff_ds,
CAST (null AS STRING) AS service_id,
CAST (null AS STRING) AS account_id,
a.cct_customerid AS customer_id,
CAST (null AS STRING) AS line_type_ds,
CAST (null AS STRING) AS bundle_type,
CAST (null AS STRING) AS technology_ds,
CAST (null AS STRING) AS billing_type_ds,
DATE(a.cct_timestamp) AS sale_date,
a.cct_fecha AS activation_date,
CAST (null AS DATE) AS deactivation_date,
CAST (null AS STRING) AS order_id,
CAST (null AS STRING) AS order_type_agg,
'10' AS cod_segmento,
'61' AS cod_tipo_contrato,
'039' AS cod_producto,
CASE WHEN A.brand_ds ='YOIGO' THEN '01'
     WHEN A.brand_ds ='MASMOVIL' THEN '05'
     ELSE '01' END AS cod_marca,
C.COD_CANAL,
CAST (null AS STRING) AS claim_code,
'Camp. piloto' AS campaign_code,
CAST (null AS STRING) AS serial_number,
CAST (null AS FLOAT64) AS tax_base,
CAST (null AS STRING) AS process_code,
CAST (null AS STRING) AS comments,
'C_MANUAL' AS facturador,
'calculado' AS estado
FROM `mm-prepaid-reporting.Analisis_DG.CER_base_citas` a
INNER JOIN `mm-commissions-reporting.TEMP.dealers_ceres` b 
     ON SPLIT(a.cct_email,'@')[OFFSET(0)] = LOWER(b.masdealer_code) AND b.id_mes = id_mes_pr
INNER JOIN `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
WHERE a.filtermail = 'dragos.goia@masmovil.com' 
AND DATE_TRUNC (DATE(a.cct_timestamp), MONTH) = COMISIONES.f_mes_int ( id_mes_pr )
AND ((tipo_cita="CERRADA") OR ((tipo_cita="ABIERTA") AND (f_realizada) ="Si"))

QUALIFY ROW_NUMBER () OVER (PARTITION BY customer_id, SPLIT(a.cct_email,'@')[OFFSET(0)] ORDER BY cct_timestamp DESC, b.cif NULLS LAST) = 1
)

SELECT *
FROM calculo_leads
WHERE comision > 0.0
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, (select array_agg(distinct canal) from TEMP.leads_ceres) , 'TEMP.leads_ceres' , 'ACTUALIZAR');

END