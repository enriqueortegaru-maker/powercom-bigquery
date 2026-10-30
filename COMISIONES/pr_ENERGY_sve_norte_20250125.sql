begin

     declare prefijo, mes_string string;

     set mes_string = cast(id_mes_pr as string);
     
     set prefijo = 'NENRG_';


     --call COMISIONES.pr_ENERGY_sve_norte_desarrollo(202412,NULL)
     create or replace table TEMP.ENERGY_sve_norte as 

     select
     id_mes_pr as id_mes,
     prefijo||'BNSVE_' ||mes_string||'_'||b.agrupacion_canal||'_'||row_number () over ()  as commission_id,
     B.agrupacion_canal,
     B.canaln as canal,
     cast(null as string)  as cod_canal,
     'B - SVE' as concepto,
     'CSEN' as tipo_concepto,
     1 as unidades,
     -- case
     
     --      when agrupacion_canal =  'WEB' and b.canaln = 'WEB DISTRIBUIDOR' THEN 20               --Canal DOL
     --      when agrupacion_canal =  'PUNTO DE VENTA' and b.canaln = 'PUNTO DE VENTA' THEN 15      --​Tiendas: Residencial y Empresa
     --      when agrupacion_canal =  'TASK FORCE' and b.canaln IN('STANDS','TASK FORCE') THEN 30   --​Stands y task: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and b.canaln = 'AGENTE VENTAS CARTERA' THEN 10       --Tvtas cartera: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and b.canaln IN ('EROSKI','BBDD DISTRIBUIDOR','BBDD OPERADOR') THEN 10 --Tvtas captacion: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and b.canaln = 'AGENTE VENTAS CARTERA' THEN 10    --INB/WEB cartera: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and b.canaln IN ('AGENTE VENTAS CAPTACION','INBOUND','WEB OPERADOR') THEN 10  --INB/WEB captacion: Residencial y Empresa
     
               
     -- END AS COMISION,

     c.comision  as comision, 
     B.id_comisionista,
     B.distribuidor,
     B.id_comisionista as sfid_id,
     UPPER(split(author_id, "@")[offset(0)])  as seller,
     B.nombre_comercio,
     B.razon_social,
     B.cif,
     B.zona_fiscal,
     upper(tenant_code) as marca,
     'ENERGY' as service_type,
     CAST(NULL as string) as phone_nm,
     CAST(NULL AS STRING) AS tariff_id,
     initial_lucera_tariff_name as tariff_ds,
     CAST(NULL AS STRING) AS service_id,
     cups_code as account_id,
     CAST(NULL AS STRING) AS customer_id,
     CAST(NULL AS STRING) AS line_type_ds,
     CAST(NULL AS STRING) AS bundle_type,
     CAST(NULL AS STRING) AS technology_ds,
     CAST(NULL AS STRING) AS billing_type_ds,
     activation_date as sale_date,
     activation_date,
     A.churn_date as deactivation_date,
     cast (null as string) as order_id,
     cast (null as string) as order_type_agg,
     '10' as cod_segmento,
     '99' as cod_tipo_contrato,
     '014' as cod_producto,
     CASE WHEN tenant_code ='energygo' THEN '16'
          WHEN tenant_code ='masmovil' THEN '17'
          WHEN tenant_code ='pepe' THEN '19'
          END AS cod_marca,
     cast (null as string) as claim_code,
     '' AS campaign_code,
     cups_code as serial_number,
     cast ( null as float64 ) tax_base,
     cast (null as string) as process_code,
     cast (null as string) as comments,
     'C_MANUAL' as facturador,
     'calculado' as estado
     FROM `mm-new-business-reporting.ENERGY.SVE`  A
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` B
     ON A.sfid_id = B.sfid_id  
     left join `mm-commissions-reporting.GS.krt_importe_energia` c
     on b.canaln = c.CANAL and b.agrupacion_canal =c.AGRUPACION_CANAL AND C.CONCEPTO ='B - SVE'

     WHERE
     A.sfid_id is not null
     and  A.product = 'SVE'
     and DATE_TRUNC(DATE(A.activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     and tenant_code ='euskaltel'
     and A.churn_date is null
     and A.state = 'activa'

     QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1

     UNION ALL

     select
     id_mes_pr as id_mes,
     prefijo||mes_string||'_'||b.agrupacion_canal||'_'||row_number () over ()  as commission_id,
     B.agrupacion_canal,
     B.canaln as canal,
     cast(null as string)  as cod_canal,
     'B - SVE' as concepto,
     'CSEN' as tipo_concepto,
     1 as unidades,
     -- case
     
     --      when agrupacion_canal =  'WEB' and b.canaln = 'WEB DISTRIBUIDOR' THEN 20               --Canal DOL
     --      when agrupacion_canal =  'PUNTO DE VENTA' and b.canaln = 'PUNTO DE VENTA' THEN 15      --​Tiendas: Residencial y Empresa
     --      when agrupacion_canal =  'TASK FORCE' and b.canaln IN('STANDS','TASK FORCE') THEN 30   --​Stands y task: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and b.canaln = 'AGENTE VENTAS CARTERA' THEN 10       --Tvtas cartera: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and b.canaln IN ('EROSKI','BBDD DISTRIBUIDOR','BBDD OPERADOR') THEN 10 --Tvtas captacion: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and b.canaln = 'AGENTE VENTAS CARTERA' THEN 10    --INB/WEB cartera: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and b.canaln IN ('AGENTE VENTAS CAPTACION','INBOUND','WEB OPERADOR') THEN 10  --INB/WEB captacion: Residencial y Empresa
     
               
     -- END AS COMISION,

     c.comision  as comision, 
     B.id_comisionista,
     B.distribuidor,
     B.id_comisionista as sfid_id,
     UPPER(split(author_id, "@")[offset(0)])  as seller,
     B.nombre_comercio,
     B.razon_social,
     B.cif,
     B.zona_fiscal,
     upper(tenant_code) as marca,
     'ENERGY' as service_type,
     CAST(NULL as string) as phone_nm,
     CAST(NULL AS STRING) AS tariff_id,
     initial_lucera_tariff_name as tariff_ds,
     CAST(NULL AS STRING) AS service_id,
     cups_code as account_id,
     CAST(NULL AS STRING) AS customer_id,
     CAST(NULL AS STRING) AS line_type_ds,
     CAST(NULL AS STRING) AS bundle_type,
     CAST(NULL AS STRING) AS technology_ds,
     CAST(NULL AS STRING) AS billing_type_ds,
     activation_date as sale_date,
     activation_date,
     A.churn_date as deactivation_date,
     cast (null as string) as order_id,
     cast (null as string) as order_type_agg,
     '10' as cod_segmento,
     '99' as cod_tipo_contrato,
     '014' as cod_producto,
     CASE WHEN tenant_code ='energygo' THEN '16'
          WHEN tenant_code ='masmovil' THEN '17'
          WHEN tenant_code ='pepe' THEN '19'
          END AS cod_marca,
     cast (null as string) as claim_code,
     '' AS campaign_code,
     cups_code as serial_number,
     cast ( null as float64 ) tax_base,
     cast (null as string) as process_code,
     cast (null as string) as comments,
     'C_MANUAL' as facturador,
     'calculado' as estado
     FROM `mm-new-business-reporting.ENERGY.SVE`  A
     LEFT JOIN (
     SELECT 
     distinct 
     id_mes_pr,
     channel_ds as agrupacion_canal,
     CAST(sfid_id AS STRING) sfid_id,
     vertical_focus as id_comisionista,
     vertical_focus as nombre_comercio,  
     distributor as distribuidor,
     distributor as razon_social,  
     subchannel_ds as canaln,
     `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`('R', distributor)as cif,
     'PEN' as zona_fiscal 
     FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_CANALES_R` c

     ) B
     ON A.sfid_id = B.sfid_id  
     left join `mm-commissions-reporting.GS.krt_importe_energia` c
     on b.canaln = c.CANAL and b.agrupacion_canal =c.AGRUPACION_CANAL AND C.CONCEPTO ='B - SVE'

     WHERE
     A.sfid_id is not null
     and  A.product = 'SVE'
     and DATE_TRUNC(DATE(A.activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     and UPPER(TRIM(tenant_code)) ='R'
     and A.churn_date is null
     and A.state = 'activa'

     QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1; 

end