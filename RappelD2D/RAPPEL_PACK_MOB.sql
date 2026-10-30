BEGIN

insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(
with 

df_mob as (select 
  u.*, 
  n_mob.ADICIONALES,
  `mm-commissions-reporting.RappelD2D.CONF_IMPOR_PACK` (n_mob.ADICIONALES, U.SFID_ID, U.BRAND_DS, U.sell_tariff_ds) pago_lineas_mob

  from `mm-commissions-reporting.RappelD2D.V_PACK_MOB` U

    left join `mm-commissions-reporting.RappelD2D.V_CUST_ADIC` n_mob
    on u.CUSTOMER_ID = n_mob.CUSTOMER_ID AND U.sfid_id = n_mob.ID_COMISIONISTA

  WHERE
  (SUBSTR(U.sfid_id,1,3) = V_CANAL OR SUBSTR(U.current_sfid_id,1,3) = V_CANAL ) 
  AND U.activation_date between MES_INI and MES_FINAL

  order by account_id, sell_tariff_id

  ),

resultado as (
  select 
  'RPD2'||'_'||MES_1||'_'||substr(sfid_id,1,3)||'_'||'PACK'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
      CASE WHEN substr(sfid_id,1,3) IN ('D2N','DEM') THEN DATE_ADD(MES_INI,INTERVAL 1 MONTH)  
    ELSE MES_INI END AS mes_liquidado,
    CASE WHEN substr(sfid_id,1,3) IN ('D2N','DEM') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE cast(MES_1 as INTEGER) END AS id_mes,
  'D2D' as agrupacion_canal,
  substr(sfid_id,1,3) as canal,
  case 
    when q.ADICIONALES >= 25 then 'A - Servicio Movil PACK25' 
    when q.ADICIONALES >= 15 then 'A - Servicio Movil PACK15'
    when q.ADICIONALES >= 5 then 'A - Servicio Movil PACK5'
    end
  as concepto,
  'UPFR' AS tipo_concepto,
  1 AS unidades,
  pago_lineas_mob AS comision,
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
  deactivation_date,
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
  'PACK_ADICIONAL_'||substr(sfid_id,1,3)||'_'||MES_1 AS process_code,
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

select * from resultado where concepto is not null and comision <> 0

);

end