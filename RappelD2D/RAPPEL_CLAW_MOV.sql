BEGIN


insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(
with 

fixes as (
  select 
  sfid_id, 
    CUSTOMER_ID  
  
  from `mm-datamart-kd.SERVICES.ventas_base_net`
  
  where 
  SUBSTR(sfid_id,1,3) = V_CANAL 
  and flag_order = 'YES' 
  and service_type ='FIX' 
  --and brand_ds = 'MASMOVIL' 
  and segment_ds = 'SOHO' 
  and activation_date is not null
  ),

mobiles as (
  select 
  *
  
  from `mm-datamart-kd.SERVICES.ventas_base_net`

  where 
    SUBSTR(sfid_id,1,3) = CASE WHEN V_CANAL = 'EDB' THEN 'DBL' ELSE V_CANAL END 
  and flag_order = 'YES' 
  and service_type ='MOBILE' 
  AND billing_type_ds = 'POSTPAID' 
  --and brand_ds = 'MASMOVIL' 
  and segment_ds = 'SOHO' 
  and sell_line_type_ds = 'ADDITIONAL'
  and order_type_agg in ('PORTABILIDAD','ALTA NUEVA','MULTISIM')
  and real_deactivation_date between MES_INI and MES_FINAL


  ),

union_table as (
  SELECT 
  mobiles.*
  FROM fixes 
    inner join mobiles on fixes.CUSTOMER_ID = mobiles.CUSTOMER_ID and fixes.sfid_id = mobiles.sfid_id
    
  ),

n_mob as (
    select 
    customer_id, 
    count(distinct phone_nm) as n_mobiles 
    
    from union_table 
    
    group by 1
    
    ),

df_mob as (select 
  u.*, 
  n_mobiles,
    `mm-commissions-reporting.RappelD2D.CONF_IMPOR_PACK` (n_mobiles, SFID_ID, BRAND_DS, sell_tariff_ds) pago_lineas_mob

  from union_table u
    left join n_mob 
    on u.customer_id = n_mob.customer_id 
    
  order by account_id, sell_tariff_id

  ),
resultado as (
  select 
  'RPD2'||'_'||MES_1||'_'||substr(sfid_id,1,3)||'_'||'CLAW_PACK'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
  CASE WHEN substr(sfid_id,1,3) IN ('D2N','DEM','EDB') THEN DATE_ADD(MES_INI,INTERVAL 1 MONTH)  
    ELSE MES_INI END AS mes_liquidado,
  CASE WHEN substr(sfid_id,1,3) IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE cast(MES_1 as INTEGER) END AS id_mes,
  'D2D' as agrupacion_canal,
  substr(sfid_id,1,3) as canal,
  case 
    when q.n_mobiles >= 25 then 'E - Clawback Servicio Movil PACK25' 
    when q.n_mobiles >= 15 then 'E - Clawback Servicio Movil PACK15'
    when q.n_mobiles >= 5 then 'E - Clawback Servicio Movil PACK5'
    end
  as concepto,
  'UPFR' AS tipo_concepto,
  1 AS unidades,
  pago_lineas_mob * -1 AS comision,
  SFID_ID AS id_comisionista,
  SFID_ID AS distribuidor,
  sfid_id,
  seller,
  b.nombre_comercio AS nombre_comercio,
  b.razon_social AS razon_social,
  b.cif AS  cif,
  b.zona_fiscal AS zona_fiscal,
  brand_ds as marca,
  service_type,
  cast(phone_nm as string),
  tariff_id,
  tariff_ds,
  service_id,
  account_id,
  customer_id,
  line_type_ds,
  bundle_type,
  technology_ds,
  billing_type_ds,
  order_day_id as sale_date,
  activation_date,
  real_deactivation_date AS deactivation_date,
  cast(order_id as string),
  order_type_agg,
  case segment_ds
  when 'RESIDENCIAL' then '10'
  when 'SOHO' then '12'
  when 'BUSINESS' then '30'
  else '99'
  end as cod_segmento,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca` (BRAND_DS) AS cod_marca,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato` (billing_type_ds,SERVICE_TYPE,bundle_type,technology_ds,line_type_ds,BRAND_DS) AS cod_tipo_contrato,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto` (service_type,brand_ds,order_type_agg) cod_producto,
  `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal` (channel_ds,subchannel_ds)cod_canal,
  '' AS claim_code,
  '' AS campaign_code,
  'CLAWBACK_PACK_ADICIONAL_'||substr(sfid_id,1,3)||'_'||MES_1 AS process_code,
  '' AS comments,
  'C_MANUAL' AS facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  'X001' AS sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  CURRENT_TIMESTAMP() AS creado,
  CURRENT_TIMESTAMP() AS modificado,
  '' AS id_factura_drive,
  '' AS emails_acceso_trazabilidad

 

  from df_mob q
    inner join (SELECT  distinct B.ID_COMISIONISTA,b.nombre_comercio,b.razon_social,b.cif,b.zona_fiscal   FROM `mm-commissions-reporting.COMISIONES.activaciones` b) b 
    ON Q.SFID_ID  = b.ID_COMISIONISTA


  )

select * from resultado where concepto is not null and comision <> 0 and activation_date >= DATE_SUB(MES_INI,INTERVAL 5 MONTH )

);

END