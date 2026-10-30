begin

set modo = IF(modo IS NULL, 'ACTUALIZAR', modo);

--- call COMISIONES.pr_prepago_diario_exclusivo ('20260901', 'DAILY');

create or replace table TEMP.daily_prepago as
select *
from
  (select
  'PREP_CANAL_'||sufijo_tabla||'_'||id_registro||'_'||row_number () over () as commission_id,
  'calculado' as estado,
  cast(substr(sufijo_tabla,1,6) as int64) as id_mes,
 
  case
    when a.id_comisionista = e.id_comisionista then 'Exclusivo'
    -- when substr(a.id_comisionista ,1,2) in ('AX','BY','DX','MD','TA','KH','LM','LX','LB','DB','LY','NY','MY','ML','MB','ME') then 'Exclusivo'
    -- when substr(a.id_comisionista ,1,2) in ('MK','PH') then 'No Exclusivo'
    end as agrupacion_canal,
  
  e.canal,
  
  case
    when a.cif ='B39688197' and a.descripcion ='C - Segunda Recarga' then 'C - Bonus 3 meses'
    when a.cif ='B39688197' and a.descripcion ='C - Tercera Recarga' then 'C - Bonus 6 meses'
    when a.descripcion = 'D - Extracomision Terminal' then 'D - Extracomision terminal'
    when a.descripcion = 'D – Extracomision Prepago' then 'D - Extracomision Prepago'
    else a.descripcion 
  end as concepto,

  a.concepto as tipo_concepto,
  1 as unidades,
  coalesce ( b.comision, a.importe) as comision,
  split (a.id_comisionista,'-')[SAFE_OFFSET(0)] as id_comisionista,
  a.id_comisionista as distribuidor,
  
  -- case
  --   when codigo_unico like 'LB-%' then split(codigo_unico,'-')[SAFE_OFFSET(1)]
  --   else codigo_unico
  -- end as sfid_id, -- 20250416 JOHANNA: AGREGUÉ CASE PARA EVITAR SFIDS DEL TIPO LB-XXXXX
  
  -- case
  --   when codigo_tienda like 'LB-%' then split(codigo_tienda,'-')[SAFE_OFFSET(1)]
  --   else codigo_tienda
  -- end as seller, -- 20250416 JOHANNA: AGREGUÉ CASE PARA EVITAR SELLERS DEL TIPO LB-XXXXX

  a.id_comisionista as sfid_id,
  a.id_comisionista as seller,
  e.nombre_comercio,
  e.razon_social,
  e.documento as cif, 
  e.zona_fiscal, 
  
  case cod_marca
  when 1 then 'YOIGO'
  when 14 then 'LYCAMOBILE'
  when 11 then 'LEBARA'
  when 4 then 'LLAMAYA'
  when 5 then 'MASMOVIL'
  END AS marca,
  
  'MOBILE' as service_type,
  b.msisdn as phone_nm,
  cast (null as string) as tariff_id,
  cast (null as string) as tariff_ds,
  b.service_id,
  cast(null as string) as account_id,
  cast (null as string) as customer_id,
  'MAIN' as line_type_ds,
  'MO' as bundle_type,
  'MOBILE' as technology_ds,
  'PREPAID' as billing_type_ds,
  sim_registration_date as sale_date,
  sim_activation_date as activation_date,
  CAST (NULL AS DATE) as deactivation_date,
  cast (null as string) as order_id,
  'ALTA NUEVA' as order_type_agg,
  segmento as cod_segmento,
  tipo_contrato as cod_tipo_contrato,
  producto as cod_producto,
  '27' as cod_canal,
  cast( cod_marca  as string format '00') as cod_marca,
  cast (null as string) as claim_code,
  'DAILY PREPAGO' as process_code,
  cast (null as string) as campaign_code,
  b.iccid as serial_number,
  cast (null as float64) as tax_base,
  
  CASE
      WHEN a.descripcion = 'D - Extracomision Terminal' THEN b.comments
      ELSE 'Importe recarga: '|| cast(importe_recarga as string) 
  END AS comments ,

  'C_MANUAL' as facturador
  FROM `mm-commissions-reporting.PREPAGO.PREPAID_DAILY_COMMISSIONS_CANAL_*` a,
  unnest(detalle_trazabilidad_activacion) b
  
  left join `mm-commissions-reporting.SAP.vendor_list` c 
      on a.cif = c.tax_code
  
  -- left join `mm-commissions-reporting.GS.PREPAGO_CONCEPTOS`  d 
  --     on REPLACE(a.descripcion, ' ', '') = REPLACE(d.concepto_etnico, ' ', '') 
  --        AND REPLACE(a.descripcion, '–', '-') = REPLACE(d.concepto_etnico, '–', '-') 
  
  left join `mm-commissions-reporting.GS.exclusivo_dealers` e 
      on e.id_comisionista = a.id_comisionista --case when codigo_tienda like 'LB-%' then split(codigo_tienda,'-')[SAFE_OFFSET(1)] else codigo_tienda end 
        and e.comisiona = TRUE
  
  where _table_suffix = sufijo_tabla
  and a.id_comisionista not in ('PFLYC0006', 'EUR0', 'TEST01')
  )
where comision <> 0.0
and commission_id is not null
and canal is not null
--and a.cif ='B39688197'
--AND COD_MARCA = 1
 ;

-- select distinct canal from TEMP.informacion_prepago;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones_modo`('PREP_CANAL' , cast(substr(sufijo_tabla,1,6) as int64), (select array_agg(DISTINCT canal) from TEMP.daily_prepago), 'TEMP.daily_prepago', modo);


end