begin

     declare prefijo, mes_string string;
     --- LOCAL
     --declare id_mes_pr INT64;declare canales_pr ARRAY<STRING>;set id_mes_pr=202501;set canales_pr=NULL;

     set mes_string = cast(id_mes_pr as string);

     set prefijo = 'NENRG_';


     --call COMISIONES.pr_energy_gas_norte(202501, null);

     CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_GAS_norte` 
     OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) as      
     select 
     id_mes_pr as id_mes,
     prefijo||'BNGAS_'||mes_string||'_'||b.agrupacion_canal||'_'||row_number () over () as commission_id,
     C.marco_energia,
     B.agrupacion_canal,
     B.canaln as canal,
     cast(null as string) as cod_canal,
     B.agrupacion_canal as canal_ds,
     B.canaln as subcanal_ds,
     (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Gas')) as concepto,
     'CSEN' as tipo_concepto,
     1 as unidades,

     -- case 
     --      when agrupacion_canal =  'WEB' and B.canaln = 'WEB DISTRIBUIDOR' THEN 90               --Canal DOL
     --      when agrupacion_canal =  'PUNTO DE VENTA' and B.canaln = 'PUNTO DE VENTA' THEN 40      --Tiendas: Residencial y Empresa
     --      when agrupacion_canal =  'TASK FORCE' and B.canaln IN('STANDS','TASK FORCE') THEN 90   --Stands y task: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and B.canaln = 'AGENTE VENTAS CARTERA' THEN 33       --Tvtas cartera: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and B.canaln IN ('EROSKI','BBDD DISTRIBUIDOR','BBDD OPERADOR') THEN 33 --Tvtas captacion: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and B.canaln = 'AGENTE VENTAS CARTERA' THEN 15    --INB/WEB cartera: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and B.canaln IN ('AGENTE VENTAS CAPTACION','INBOUND','WEB OPERADOR') THEN 15  --INB/WEB captacion: Residencial y Empresa

          
     

                    
     -- END AS COMISION,

     c.comision  as comision,
     b.id_comisionista,
     b.distribuidor,
     b.id_comisionista as sfid_id,
     upper(split(author_id, "@")[offset(0)])  as seller,
     b.nombre_comercio,
     b.razon_social,
     b.cif,
     b.zona_fiscal,

     'EUSKALTEL' as marca,
     'ENERGY' as service_type,
     cast(phone as string) as phone_nm,
     CAST(NULL AS STRING) AS tariff_id,
     initial_lucera_tariff_name as tariff_ds,
     cast(id as string) AS service_id,
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
     CASE WHEN tenant_code ='energygo' THEN '16'
          WHEN tenant_code ='masmovil' THEN '17' 
          WHEN tenant_code ='pepe' THEN '19'
          END AS cod_marca,
     cast (null as string) as claim_code,
     cast (null as string) as campaign_code,
     cups_code as serial_number,
     cast ( null as float64 ) tax_base,
     cast (null as string) as process_code,
     cast (null as string) as comments,
     'C_MANUAL' as facturador,
     'calculado' as estado
     from `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt`B 
     ON A.sfid_id = B.sfid_id  

/*     left join `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` c
     on b.canaln = c.CANAL and b.agrupacion_canal =c.AGRUPACION_CANAL AND C.CONCEPTO ='B - Gas'
*/

     LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_CANALES` CANAL
          ON UPPER(TRIM(CANAL.agrupacion_canal))=UPPER(TRIM(b.agrupacion_canal)) and UPPER(TRIM(CANAL.canal))=UPPER(TRIM(b.subcanal_gekt))
     LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` c
          ON UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(c.marco_energia)) AND contains_substr(c.concepto,'B - Gas')

     WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     and tenant_code ='euskaltel'
     and A.sfid_id is not null
     and state = 'activa'
     and channel_ds not in ('PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
     QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1

     UNION ALL 

     select 
     id_mes_pr as id_mes,
     prefijo||'RNGAS_'||mes_string||'_'||b.agrupacion_canal||'_'||row_number () over () as commission_id,
     C.marco_energia,     
     B.agrupacion_canal,
     B.canaln as canal,
     cast(null as string) as cod_canal,
     B.agrupacion_canal as canal_ds,
     B.canaln as subcanal_ds,
     (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Gas')) as concepto,
     'CSEN' as tipo_concepto,
     1 as unidades,

     -- case 
     --      when agrupacion_canal =  'WEB' and B.canaln = 'WEB DISTRIBUIDOR' THEN 90               --Canal DOL
     --      when agrupacion_canal =  'PUNTO DE VENTA' and B.canaln = 'PUNTO DE VENTA' THEN 40      --​Tiendas: Residencial y Empresa
     --      when agrupacion_canal =  'TASK FORCE' and B.canaln IN('STANDS','TASK FORCE') THEN 90   --​Stands y task: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and B.canaln = 'AGENTE VENTAS CARTERA' THEN 33       --Tvtas cartera: Residencial y Empresa
     --      when agrupacion_canal =  'TELEVENTA' and B.canaln IN ('EROSKI','BBDD DISTRIBUIDOR','BBDD OPERADOR') THEN 33 --Tvtas captacion: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and B.canaln = 'AGENTE VENTAS CARTERA' THEN 15    --INB/WEB cartera: Residencial y Empresa
     --      when agrupacion_canal IN  ('WEB', 'INBOUND') and B.canaln IN ('AGENTE VENTAS CAPTACION','INBOUND','WEB OPERADOR') THEN 15  --INB/WEB captacion: Residencial y Empresa
               
     -- END AS COMISION,

     c.comision  as comision,
     b.id_comisionista,
     b.distribuidor,
     --- PARCHE 20250612
     --b.id_comisionista as sfid_id,
     b.sfid_id,
     --- FIN PARCHE
     upper(split(author_id, "@")[offset(0)])  as seller,
     b.nombre_comercio,
     b.razon_social,
     b.cif,
     b.zona_fiscal,

     'R' as marca,
     'ENERGY' as service_type,
     cast(phone as string) as phone_nm,
     CAST(NULL AS STRING) AS tariff_id,
     initial_lucera_tariff_name as tariff_ds,
     cast(id as string) AS service_id,
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
     CASE WHEN tenant_code ='energygo' THEN '16'
          WHEN tenant_code ='masmovil' THEN '17' 
          WHEN tenant_code ='pepe' THEN '19'
          END AS cod_marca,
     cast (null as string) as claim_code,
     cast (null as string) as campaign_code,
     cups_code as serial_number,
     cast ( null as float64 ) tax_base,
     cast (null as string) as process_code,
     cast (null as string) as comments,
     'C_MANUAL' as facturador,
     'calculado' as estado
     from `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
     LEFT JOIN 
     (
          SELECT 
          distinct 
          id_mes_pr,
          channel_ds as agrupacion_canal,
          subchannel_ds as subcanal_gekt,
          CAST(sfid_id AS STRING) sfid_id,
          vertical_focus_ds as id_comisionista,
          vertical_focus_ds as nombre_comercio,  
          distributor_ds as distribuidor,
          distributor_ds as razon_social,  
          subchannel_ds as canaln,
          `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`('R', distributor_ds)as cif,
          'PEN' as zona_fiscal 
          FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL` c
     )

     B 
     ON A.sfid_id = B.sfid_id  
/*     
     left join `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` c
     on b.canaln = c.CANAL and b.agrupacion_canal =c.AGRUPACION_CANAL AND C.CONCEPTO ='B - Gas'
*/


     LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_CANALES` CANAL
          ON UPPER(TRIM(CANAL.agrupacion_canal))=UPPER(TRIM(b.agrupacion_canal)) and UPPER(TRIM(CANAL.canal))=UPPER(TRIM(b.subcanal_gekt))
     LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` c
          ON UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(c.marco_energia)) AND contains_substr(c.concepto,'B - Gas')


     WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     and UPPER(TRIM(tenant_code)) ='R'
     and A.sfid_id is not null
     and state = 'activa'
     and channel_ds not in ('PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
     QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1;


end