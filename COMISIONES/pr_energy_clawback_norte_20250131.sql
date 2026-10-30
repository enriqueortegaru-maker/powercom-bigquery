BEGIN


DECLARE prefijo, mes_string STRING;
--- LOCAL
--DECLARE id_mes_pr INT64; SET id_mes_pr=202412;
SET mes_string = CAST(id_mes_pr AS STRING);
SET prefijo = 'NENRL_';



--CALL COMISIONES.pr_energy_clawback_norte(202501);
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_clawback_deactivation_date`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(


with TRANSACCIONES as (
      --- ACTIVACIONES EN SEIS MESES PREVIOS
     SELECT
           commission_id
          ,estado
          ,mes_liquidado
          ,id_mes
          ,canal_gekt as agrupacion_canal
          ,subcanal as canal
          ,concepto
          ,tipo_concepto
          ,unidades
          ,comision
          ,id_comisionista
          ,distribuidor
          ,sfid_id
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
          ,cod_tipo_contrato
          ,cod_producto
          ,cod_canal
          ,campaign_code
          ,serial_number
          ,tax_base
          ,claim_code
          ,process_code
          ,comments
          ,facturador
          ,sociedad
     
     FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
     WHERE (contains_substr(concepto, '- Gas') or  contains_substr(concepto, '- Electricidad') or contains_substr(concepto, '- SVE') or contains_substr(concepto, '- SVG'))
     AND marca IN ('EUSKALTEL','R')
     AND estado ='facturado' or estado = 'publicado'
     AND DATE_DIFF(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)),activation_date, DAY) >0
     --AND activation_date>=date_sub(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), interval 7 month);
     AND activation_date>=date_sub(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), interval 180 day)
/*     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.enrgn_activations`
*/
) , DEACTIVATIONS as (

    select "B - Gas" as  concepto, cups_code, activation_date, churn_date, TRIM(UPPER(tenant_code)) as marca, CAST(id AS STRING) id 
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_gas`
    where (contains_substr(tenant_code, 'euskaltel') or Upper(TRIM(tenant_code))="R")
    --and churn_date>='2024-11-01'
    AND DATE_TRUNC(churn_date, MONTH)=PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    and FORMAT_DATE("%Y%m", churn_date) = FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and FORMAT_DATE("%Y%m", activation_date)<FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and DATE_DIFF(churn_date, activation_date, DAY)<=180
    UNION ALL 
    select "B - Electricidad" as concepto, cups_code, activation_date, churn_date, TRIM(UPPER(tenant_code)) as marca, CAST(id AS STRING) id 
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity`
    where (contains_substr(tenant_code, 'euskaltel') or Upper(TRIM(tenant_code))="R")
    --and churn_date>='2024-11-01'
    AND DATE_TRUNC(churn_date, MONTH)=PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    and FORMAT_DATE("%Y%m", churn_date) = FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and FORMAT_DATE("%Y%m", activation_date)<FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and DATE_DIFF(churn_date, activation_date, DAY)<=180
    UNION ALL 
    select "B - SVE" as concepto, cups_code, activation_date, churn_date, TRIM(UPPER(tenant_code)) as marca, CAST(NULL AS STRING)
    FROM  `mm-new-business-reporting.ENERGY.SVE`
    where (contains_substr(tenant_code, 'euskaltel') or Upper(TRIM(tenant_code))="R")
    --and churn_date>='2024-11-01'
    AND DATE_TRUNC(churn_date, MONTH)=PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    and FORMAT_DATE("%Y%m", churn_date) = FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and FORMAT_DATE("%Y%m", activation_date)<FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and DATE_DIFF(churn_date, activation_date, DAY)<=180
    UNION ALL 
    select "B - SVG" as concepto, cups_code, data_inici as activation_date, data_fi as churn_date, SPLIT(TRIM(UPPER(a.tenant_code)),'_')[0] as marca, CAST(NULL AS STRING)
    FROM `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
    INNER JOIN `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
    ON A.id = B.polissa_id
    where (contains_substr(a.tenant_code, 'euskaltel') or Upper(TRIM(a.tenant_code))="r" or Upper(TRIM(a.tenant_code))="r_svg")
    --and churn_date>='2024-11-01'
    AND DATE_TRUNC(data_fi, MONTH)=PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    and FORMAT_DATE("%Y%m", data_fi) = FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and FORMAT_DATE("%Y%m", data_inici)<FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)))
    and DATE_DIFF(data_fi, data_inici, DAY)<=180
)

SELECT distinct 
      TRANSACCIONES.* EXCEPT(deactivation_date),
      DEACTIVATIONS.churn_date AS deactivation_date,
/*      TRANSACCIONES.activation_date as tr_act,      
      TRANSACCIONES.deactivation_date as tr_deact,
      DEACTIVATIONS.activation_date as de_act,      
      DEACTIVATIONS.churn_date as de_deact,
      TRANSACCIONES.concepto as tr_concep,
      DEACTIVATIONS.concepto as de_concep,
      TRANSACCIONES.marca as tr_marca,
      DEACTIVATIONS.marca as de_marca     
*/
FROM  TRANSACCIONES
INNER JOIN  DEACTIVATIONS
ON (DEACTIVATIONS.cups_Code like concat('%',CAST(service_id AS STRING),'%')  
    OR CASE WHEN DEACTIVATIONS.concepto in ("B - Electricidad","B - Gas") then DEACTIVATIONS.id=TRANSACCIONES.service_id END
)
and UPPER(TRIM(SPLIT(TRANSACCIONES.concepto,"-")[1]))=UPPER(TRIM(SPLIT(DEACTIVATIONS.concepto,"-")[1]))
where TRANSACCIONES.service_id !='0'
---AND TRANSACCIONES.activation_date = DEACTIVATIONS.activation_date
)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_CLAWBACK_norte`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(

select 
id_mes as mes_comision_id,
id_mes_pr as mes_decomision_id,
'NENRGNE' || '_' || mes_string || '_' ||  coalesce(agrupacion_canal,'NOINF') || '_' || ROW_NUMBER() OVER() AS commission_id,
--commission_id,
agrupacion_canal,
canal,
COD_CANAL,
agrupacion_canal as canal_ds,
canal as subcanal_ds,
concepto,
tipo_concepto,
unidades,
`mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(deactivation_date, activation_date, comision) as COMISION,
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
phone_nm,
tariff_id,
tariff_ds,
service_id,
account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
deactivation_date,
order_id,
order_type_agg,
cod_segmento,
cod_tipo_contrato,
cod_producto,
cod_marca,
claim_code,
campaign_code,
serial_number,
tax_base,
process_code,
comments,
facturador,
'calculado' estado,
from  `mm-commissions-reporting.TEMP.enrgn_clawback_deactivation_date` 
);


/*

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_clawback_summation`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(


SELECT
      TRANSACCIONES.agrupacion_canal
     ,TRANSACCIONES.canal
     ,CASE WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'G', 'Q', 'S', 'Y') THEN 'H - Clawback ' ELSE 'E - Clawback ' END || SUBSTR(TRANSACCIONES.concepto, 5) AS concepto
     ,TRANSACCIONES.tipo_concepto
     ,TRANSACCIONES.id_comisionista
     ,TRANSACCIONES.marca
     ,TRANSACCIONES.service_type
     ,TRANSACCIONES.phone_nm
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_canal
     ,TRANSACCIONES.sociedad
     ,MAX(TRANSACCIONES.bundle_type) AS bundle_type
     ,MAX(TRANSACCIONES.campaign_code) AS campaign_code
     ,MAX(TRANSACCIONES.line_type_ds) AS line_type_ds
     ,MAX(TRANSACCIONES.order_id) AS order_id
     ,MAX(TRANSACCIONES.order_type_agg) AS order_type_agg
     ,MAX(TRANSACCIONES.serial_number) AS serial_number
     ,MAX(TRANSACCIONES.tariff_ds) AS tariff_ds
     ,MAX(TRANSACCIONES.tariff_id) AS tariff_id
     ,MAX(TRANSACCIONES.tax_base) AS tax_base
     ,MAX(TRANSACCIONES.technology_ds) AS technology_ds
     ,MAX(TRANSACCIONES.comments) AS comments
     ,SUM(TRANSACCIONES.comision) AS comision
     ,ARRAY_AGG(TRANSACCIONES.commission_id) AS commission_id
     
FROM `mm-commissions-reporting.TEMP.enrgn_clawback_deactivation_date` TRANSACCIONES
    
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_clawback_dealer`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      TRANSACCIONES.* EXCEPT(
                            canal,
                            comision,
                            commission_id,
                            id_comisionista
                            )
     
     ,'NENRGNE' || '_' || mes_string || '_' || COALESCE(DEALER.canaln, TRANSACCIONES.canal) || '_' || ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,COMISIONES.f_mes_int(id_mes_pr) AS mes_liquidado
     ,id_mes_pr as id_mes
     ,1 AS unidades

     ,COALESCE(DEALER.canaln, TRANSACCIONES.canal) AS canal

     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback` (
        DATE_DIFF(TRANSACCIONES.deactivation_date, TRANSACCIONES.activation_date, DAY) + 1
       ,COALESCE(DEALER.canaln, TRANSACCIONES.canal)
       ,TRANSACCIONES.tariff_ds
      )
      * TRANSACCIONES.comision AS comision
     
     ,DEALER.id_comisionista
     ,DEALER.nombre_comercio AS nombre_comercio
     ,DEALER.razon_social AS razon_social
     ,DEALER.cif AS cif
     ,DEALER.zona_fiscal AS zona_fiscal
     ,DEALER.distribuidor
     ,CAST(NULL AS STRING) AS claim_code
     ,REPLACE(REPLACE(TO_JSON_STRING(commission_id), '[', ''), ']', '') AS process_code
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.enrgn_clawback_summation` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.sfid_id --AND DEALER.id_mes = id_mes_pr

WHERE DEALER.id_comisionista IS NOT NULL
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_clawback`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      CLWB.*
     ,DEALER_DETAIL.sfid_id
     ,DEALER_DETAIL.seller

FROM `mm-commissions-reporting.TEMP.enrgn_clawback_dealer` CLWB

LEFT JOIN (
          SELECT DEALER.commission_id, TRANSACCIONES.sfid_id, TRANSACCIONES.seller
          FROM (
               SELECT DEALER.commission_id, process_code
               FROM `mm-commissions-reporting.TEMP.enrgn_clawback_dealer` DEALER
               GROUP BY 1,2
               ) DEALER, UNNEST(SPLIT(DEALER.process_code, ',')) ENRG
          LEFT JOIN `mm-commissions-reporting.TEMP.enrgn_clawback_deactivation_date` TRANSACCIONES
                   ON REPLACE(ENRG, '"', '') = TRANSACCIONES.commission_id
          QUALIFY ROW_NUMBER() OVER (PARTITION BY DEALER.commission_id ORDER BY TRANSACCIONES.concepto ASC) = 1 
          ) DEALER_DETAIL
         ON CLWB.commission_id = DEALER_DETAIL.commission_id

QUALIFY SUM(comision) OVER (PARTITION BY CLWB.commission_id) < 0
)
;

/*
--- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('NENRGNB', id_mes_pr, canales_pr, 'TEMP.enrgn_activations', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('NENRGNE', id_mes_pr, canales_pr, 'TEMP.enrgn_clawback', 'ACTUALIZAR');
*/


/*

select 
id_mes_pr as id_mes,
prefijo||'RNEN_'||mes_string||'_'||b.canaln||'_'||row_number () over ()  as commission_id,
 b.agrupacion_canal as canal,
 b.canaln as agrupacion_canal,
cast(null as string) as cod_canal,
case when initial_lucera_tariff_name like '%Batman%' then 'D - Energia Batman' 
ELSE 'D - Energia' end as concepto,
'CSEN' as tipo_concepto,
1 as unidades,
CASE 
     when a.master_channel_ds =c.agrupacion_canal and a.channel_ds =c.canal and a.sfid_id = c.sfid_id 
               THEN ROUND(c.importe/(select count(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  
      where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and a.master_channel_ds =  c.agrupacion_canal and a.channel_ds = c.canal and a.sfid_id = c.sfid_id),2) else d.comision 
              
 END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
upper(split(author_id, "@")[offset(0)])  as seller,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,
'Euskaltel' as marca,
'ENERGY' as service_type,
cast(phone as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
initial_lucera_tariff_name as tariff_ds,
CAST(id AS STRING) AS service_id,
cups_code as account_id,
CAST(NULL AS STRING) AS customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
signup_date as sale_date,
activation_date,
churn_date as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'014' as cod_producto,
cast(null as string) AS cod_marca,
cast (null as string) as claim_code,
cast(null as string) as campaign_code,
cups_code as serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` A
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt`B 
ON A.sfid_id = B.sfid_id 
left join `mm-commissions-reporting.GS.krt_reparto_energia` c
on A.sfid_id =c.sfid_id and a.master_channel_ds =c.agrupacion_canal and a.channel_ds =c.canal and c.concepto in ('D - Energia','D - Energia Batman')
left join `mm-commissions-reporting.GS.krt_importe_energia` d
on b.agrupacion_canal =d.agrupacion_canal and b.canaln =d.canal and d.concepto in ('D - Energia','D - Energia Batman') 

WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
and tenant_code in ('euskaltel') 
and channel_ds not in ('PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
and state= 'activa'
and A.sfid_id is not null
and churn_date is null
QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 ;
*/

END