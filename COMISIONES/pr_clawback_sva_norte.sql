begin


declare id_mes_claw int64;
declare prefijo string;
set id_mes_claw = id_mes_pr;
set prefijo = 'CLAWBN_';

--call`COMISIONES.clawback_sva_norte`(202409);

create or replace table TEMP.CLAWB_SVA_NORTE AS (

    select id_mes,	commission_id,	canal,	agrupacion_canal,	cod_canal,	concepto,	tipo_concepto,	unidades,	comision,	id_comisionista,	distribuidor,	sfid_id,	seller,	nombre_comercio,	razon_social,	cif	,zona_fiscal,	marca,	service_type,	phone_nm,	tariff_id,	tariff_ds,	service_id,	account_id,	customer_id,	line_type_ds,	bundle_type,	technology_ds,	billing_type_ds,	sale_date,	activation_date,	deactivation_date,	order_id,	order_type_agg,	cod_segmento,	cod_tipo_contrato,	cod_producto,	cod_marca,	claim_code,	campaign_code,	serial_number,tax_base,	process_code,	comments,	facturador,	estado
    from (







select A.* EXCEPT(id_mes,commission_id,concepto,comision,deactivation_date,estado),
id_mes_claw as id_mes,
prefijo||'C_luz'||id_mes_claw||'_'||A.canal||'_'||row_number () OVER () AS commission_id,
case when A.concepto = 'B - Energia' then 'E - Clawback energia' end as concepto,
case
    
    WHEN DATE_TRUNC(DATE(B.churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (B.churn_date, A.activation_date, DAY)<= 60 THEN (comision * -1)

    WHEN DATE_TRUNC(DATE(B.churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (B.churn_date, A.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1

    WHEN DATE_TRUNC(DATE(B.churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (B.churn_date, A.activation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1 
    ELSE 0
END as comision ,
B.churn_date as deactivation_date,
'calculado' as estado
from `mm-commissions-reporting.COMISIONES.historico_sva_krt`A 
inner join `mm-datamart-kd.ENERGY.lucera_polissas_electricity`B
on  A.account_id = B.cups_code
where DATE_TRUNC(DATE(B.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and concepto = 'B - Energia' and DATE_DIFF (B.churn_date, A.activation_date, DAY)< 181

UNION ALL

select A.* EXCEPT(id_mes,commission_id,concepto,comision,deactivation_date,estado),
id_mes_claw as id_mes,
prefijo||'C_gas'||id_mes_claw||'_'||A.canal||'_'||row_number () OVER () AS commission_id,
case when A.concepto = 'B - Gas' then 'E - Clawback gas' end as concepto,
case
    
    WHEN DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (churn_date, A.activation_date, DAY)<= 60 THEN (comision * -1)

    WHEN DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (churn_date, A.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1

    WHEN DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (churn_date, A.activation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1 
    ELSE 0
END as comision ,
B.churn_date as deactivation_date,
'calculado' as estado
from `mm-commissions-reporting.COMISIONES.historico_sva_krt`A 
inner join `mm-datamart-kd.ENERGY.lucera_polissas_gas` B
on  A.account_id = B.cups_code
where DATE_TRUNC(DATE(B.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and concepto = 'B - Gas' and DATE_DIFF (churn_date, A.activation_date, DAY)< 181


UNION ALL

select A.* EXCEPT(id_mes,commission_id,concepto,comision,deactivation_date,estado),
id_mes_claw as id_mes,
prefijo||'C_sve'||id_mes_claw||'_'||A.canal||'_'||row_number () OVER () AS commission_id,
case when A.concepto = 'B - SVE' then 'E - Clawback sve' end as concepto,
case
    
    WHEN DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (churn_date, A.activation_date, DAY)<= 60 THEN (comision * -1)

    WHEN DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (churn_date, A.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1

    WHEN DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (churn_date, A.activation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1 
    ELSE 0
END as comision ,
B.churn_date as deactivation_date,
'calculado' as estado
from `mm-commissions-reporting.COMISIONES.historico_sva_krt`A 
inner join `mm-new-business-reporting.ENERGY.SVE`B
on  A.account_id = B.cups_code
where DATE_TRUNC(DATE(B.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and concepto = 'B - SVE' and DATE_DIFF (churn_date, B.activation_date, DAY)< 181


UNION ALL

select A.* EXCEPT(id_mes,commission_id,concepto,comision,deactivation_date,estado),
id_mes_claw as id_mes,
prefijo||'C_'||id_mes_claw||'_'||A.canal||'_'||row_number () OVER () AS commission_id,
case when A.concepto = 'B - SVG' then 'E - Clawback svg' end as concepto,
case
    
    WHEN DATE_TRUNC(DATE(B.data_fi), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (B.data_fi, A.activation_date, DAY)<= 60 THEN (comision * -1)

    WHEN DATE_TRUNC(DATE(B.data_fi), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (B.data_fi, A.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1

    WHEN DATE_TRUNC(DATE(B.data_fi), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and  marca = 'EUSKALTEL' AND DATE_DIFF (B.data_fi, A.activation_date, DAY) BETWEEN 121 AND 180 THEN (comision * 0.5) * -1 
    ELSE 0
END as comision ,
B.data_fi as deactivation_date,
'calculado' as estado
from `mm-commissions-reporting.COMISIONES.historico_sva_krt`A 
inner join (select *,date_diff(data_fi,data_inici,DAY) from  `mm-new-business-reporting.ENERGY.ganancia_neta_energia` X
INNER JOIN
  `mm-datamart-kd.ENERGY.lucera_gas_additional_services` Z
ON
  X.id = Z.polissa_id
  where tenant_code = 'euskaltel_svg' and DATE_TRUNC(DATE(data_fi), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) 
 QUALIFY  ROW_NUMBER() OVER (PARTITION BY X.id ORDER BY X.sfid_id DESC ) = 1  )B
on  A.account_id = B.cups_code 
where tenant_code = 'euskaltel_svg' and DATE_TRUNC(DATE(B.data_fi), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) and concepto = 'B - SVG' and DATE_DIFF (B.data_fi, A.activation_date, DAY)< 181

))
;
end