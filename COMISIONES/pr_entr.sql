begin
 
declare prefijo string;
declare id_mes_pr INT64;
declare canales_pr ARRAY <STRING>;

set prefijo = 'ENTRE';
 
set id_mes_pr = CAST(SUBSTR(fecha_report,1,6) AS INT64);
--set id_mes_pr = 202402;
 
set canales_pr =  coalesce (canales_pr, (select array_agg (canal) from `mm-commissions-reporting.GS.CANALES`));

--CALL COMISIONES.pr_entr('20240322')

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.entr` as 

select
    prefijo || '_' || SUBSTR(fecha_report,1,6) || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
    ,*
from (

  select
      'calculado' as estado
      , concat(substr(order_rowversion,1,8),'01') as mes_liquidado
      , id_mes_pr as id_mes
--       , concat(substr(order_rowversion,1,4),substr(order_rowversion,6,2)) as id_mes 
--       ,'2023-12-01' as mes_liquidado
--       ,202312 as id_mes
      , DEALER.agrupacion_canal
      , DEALER.canal
      , 'B - Entrega en tienda' as concepto
      , 'CURE' as tipo_concepto 
      , 1 as unidades
      , 5.00 as comision
      , DEALER.id_comisionista
      , DEALER.distribuidor
      , addon5 as sfid_id
      , addon5 as seller
      , DEALER.nombre_comercio
      , DEALER.razon_social
      , DEALER.cif
      , case when zone_id = 'D' then 'CAN'
             else 'PEN' END as zona_fiscal
      , 'YOIGO' as marca
      , 'MOBILE' as service_type 
      , msisdn as phone_nm
      , contract_type as tariff_id
      , contract_type_name as tariff_ds
      , subscription_id as service_id
      , contract_id as account_id 
      , end_cust_no as customer_id
      , 'MAIN' as line_type_ds 
      , case when contract_type like 'CONTDSL%' then 'FMC'
             when contract_type like 'CONTFH%' then 'FMC'
             else 'MO' end as bundle_type
      , case when contract_type like 'CONTDSL%' then 'ADSL'
             when contract_type like 'CONTFH%' then 'FTTH'
             else 'MOBILE' end as technology_ds
      , case when contract_category = 'CONT' then 'POSTPAID'
             when contract_category = 'TARJ' then 'PREPAID'
             else contract_category end as billing_type_ds
      , CAST(substr(sales_date,1,10) AS DATE) as sale_date
      , CAST(substr(sales_date,1,10) AS DATE) as activation_date
      , CAST('9999-12-31' AS DATE) as deactivation_date
      , tms_order_no as order_id
      , case when mnp = '1' then 'PORTABILIDAD'
             when mnp = '0' then 'ALTA NUEVA'
             else mnp end as order_type_agg
      , case cus_kategory 
            when '10' then '10'
            when '11' then '10'
            when '13' then '10'
            when '20' then '30'
            when '23' then '30'
            when '42' then '12'
            when '43' then '12'
            else '10' end as cod_segmento
      , '01' as cod_marca
   -- , 'TBD' as cod_tipo_contrato --falta definir qué son
      , case
            when contract_category = 'TARJ' then '10'
--        WHEN upper(contract_type) like '%CONTDSL%' and upper(contract_type_name) not like '%+%' THEN '62'
            when upper(contract_type) like '%CONTDSL%' then '60'

--        WHEN upper(contract_type) like '%CONTFH%' and upper(contract_type_name) not like '%+%' and upper(contract_type_name) not like '% CON%' and upper(contract_type_name) not like '% SINF%' THEN '63'
            when upper(contract_type) like '%CONTFH%' then '61'
            else '20' end as cod_tipo_contrato
      , case when mnp = '1' then '040'
             else '039' end as cod_producto 
      , case when dealer.agrupacion_canal = 'Exclusivo' then '27' end as cod_canal
      , CAST(null as string)  as campaign_code
      , CAST(null as string)  as serial_number
      , CAST(null as float64) as tax_base
      , CAST(NULL AS STRING)  AS claim_code
      , 'Entrega en tienda'||'-'||id_mes_pr as process_code
      , CAST(null as string) as comments
      , 'C_MANUAL' as facturador
      , 'X001' as sociedad
      , 'X0SL' as centro_coste
  
  from `mm-datamart-kd.COMMISSIONS.customer_care_ifs_direct_channel`  a
  left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
           on (
              a.addon5 = DEALER.sfid_id 
              or (substr(a.addon5,1,2) = DEALER.sfid_id)
              or a.addon5 || '-' || a.addon5 = replace(DEALER.sfid_id , ' ', '')
              )
              and DEALER.agrupacion_canal = 'Exclusivo'
  
  where order_type = 'POS'
    and logistic_status = 'DELIVERED'
    and cost_type = 'LOGISTICO'
    and order_objstate = 'Invoiced'
      -------------------------------------
      -- INTRODUCIR EL DÍA QUE SE REPORTÓ -
      -------------------------------------
    and SUBSTR(objversion,1,8) =  fecha_report
    and SUBSTR(cost_objversion,1,8) =  fecha_report
    and SUBSTR(order_objversion,1,8) =  fecha_report
      ---------------
      -- HASTA AQUÍ -
      ---------------
  group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46

UNION ALL

select
      'calculado' as estado
      , concat(substr(order_rowversion,1,8),'01') as mes_liquidado
      , id_mes_pr as id_mes
--       , concat(substr(order_rowversion,1,4),substr(order_rowversion,6,2)) as id_mes 
--       ,'2023-12-01' as mes_liquidado
--       ,202312 as id_mes
      , DEALER.agrupacion_canal
      , DEALER.canal
      , 'F - Entrega en tienda' as concepto
      , 'CURE' as tipo_concepto 
      , 1 as unidades
      , 1.00 as comision
      , DEALER.id_comisionista
      , DEALER.distribuidor
      , addon5 as sfid_id
      , addon5 as seller
      , DEALER.nombre_comercio
      , DEALER.razon_social
      , DEALER.cif
      , case when zone_id = 'D' then 'CAN'
             else 'PEN' END as zona_fiscal
      , 'YOIGO' as marca
      , 'MOBILE' as service_type 
      , msisdn as phone_nm
      , contract_type as tariff_id
      , contract_type_name as tariff_ds
      , subscription_id as service_id
      , contract_id as account_id 
      , end_cust_no as customer_id
      , 'MAIN' as line_type_ds 
      , case when contract_type like 'CONTDSL%' then 'FMC'
             when contract_type like 'CONTFH%' then 'FMC'
             else 'MO' end as bundle_type
      , case when contract_type like 'CONTDSL%' then 'ADSL'
             when contract_type like 'CONTFH%' then 'FTTH'
             else 'MOBILE' end as technology_ds
      , case when contract_category = 'CONT' then 'POSTPAID'
             when contract_category = 'TARJ' then 'PREPAID'
             else contract_category end as billing_type_ds
      , CAST(substr(sales_date,1,10) AS DATE) as sale_date
      , CAST(substr(sales_date,1,10) AS DATE) as activation_date
      , CAST('9999-12-31' AS DATE) as deactivation_date
      , tms_order_no as order_id
      , case when mnp = '1' then 'PORTABILIDAD'
             when mnp = '0' then 'ALTA NUEVA'
             else mnp end as order_type_agg
      , case cus_kategory 
            when '10' then '10'
            when '11' then '10'
            when '13' then '10'
            when '20' then '30'
            when '23' then '30'
            when '42' then '12'
            when '43' then '12'
            else '10' end as cod_segmento
      , '01' as cod_marca
   -- , 'TBD' as cod_tipo_contrato --falta definir qué son
      , case
            when contract_category = 'TARJ' then '10'
--        WHEN upper(contract_type) like '%CONTDSL%' and upper(contract_type_name) not like '%+%' THEN '62'
            when upper(contract_type) like '%CONTDSL%' then '60'

--        WHEN upper(contract_type) like '%CONTFH%' and upper(contract_type_name) not like '%+%' and upper(contract_type_name) not like '% CON%' and upper(contract_type_name) not like '% SINF%' THEN '63'
            when upper(contract_type) like '%CONTFH%' then '61'
            else '20' end as cod_tipo_contrato
      , case when mnp = '1' then '040'
             else '039' end as cod_producto 
      , case when dealer.agrupacion_canal = 'Exclusivo' then '27' end as cod_canal
      , CAST(null as string)  as campaign_code
      , CAST(null as string)  as serial_number
      , CAST(null as float64) as tax_base
      , CAST(NULL AS STRING)  AS claim_code
      , 'Entrega en tienda'||'-'||id_mes_pr as process_code
      , CAST(null as string) as comments
      , 'C_MANUAL' as facturador
      , 'X001' as sociedad
      , 'X0SL' as centro_coste
  
  from `mm-datamart-kd.COMMISSIONS.customer_care_ifs_direct_channel`  a
  left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
           on (
              a.addon5 = DEALER.sfid_id 
              or (substr(a.addon5,1,2) = DEALER.sfid_id)
              or a.addon5 || '-' || a.addon5 = replace(DEALER.sfid_id , ' ', '')
              )
              and DEALER.agrupacion_canal = 'Exclusivo'
  
  where order_type = 'POS'
    and logistic_status = 'DELIVERED'
    and cost_type = 'LOGISTICO'
    and order_objstate = 'Invoiced'
      -------------------------------------
      -- INTRODUCIR EL DÍA QUE SE REPORTÓ -
      -------------------------------------
    and SUBSTR(objversion,1,8) = fecha_report
    and SUBSTR(cost_objversion,1,8) = fecha_report
    and SUBSTR(order_objversion,1,8) = fecha_report
      ---------------
      -- HASTA AQUÍ -
      ---------------
  group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46

  );

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, canales_pr, 'TEMP.entr', 'ACTUALIZAR');

END