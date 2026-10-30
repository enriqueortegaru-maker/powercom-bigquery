begin

--- call COMISIONES.pr_cargar_prepago_canal ('20260902');

create or replace table TEMP.informacion_prepago as
select *
from
  (select
  '2PREP_CANAL_'||prefijo_tabla||'_'||id_registro||'_'||row_number () over () as commission_id,
  'calculado' as estado,
  cast(substr(prefijo_tabla,1,6) as int64) as id_mes,
  -- case
  --   when a.id_comisionista = 'C02142' then 'No Exclusivo'
  --   when substr(a.id_comisionista ,1,2) in ('AX','BY','DX','MD','TA','KH','LM','LX','LB','DB','LY','NY','MY','ML','MB','ME') then 'Exclusivo'
  --   when substr(a.id_comisionista ,1,2) in ('MK','PH') then 'No Exclusivo'

  --   end as agrupacion_canal,
    case 
      when a.id_comisionista = e.id_comisionista then 'Exclusivo'
      else 'No Exclusivo'
  end as agrupacion_canal,
  -- case
  --   when substr(a.id_comisionista ,1,2) in ('AX','BY','DX','MD','TA','KH','LM','LX','LB','DB','LY','NY','MY','ML','MB','ME') then e.canal
  --   when a.id_comisionista = 'C02142' then 'ALTNH'
  --   -- when substr(a.id_comisionista ,1,2) in ('LB','LM','LY','ML') then 'EML'
  --     -- when substr(a.id_comisionista ,1,2) in ('AX', 'DX', 'BY', 'TA','MD','KH','EU','TU') then 'EYG'
  --     -- when substr(a.id_comisionista ,1,2) in ('MY','MB') then 'ENX'
  --   when substr(a.id_comisionista ,1,2) in ('MP') then 'MP'
  --   when substr(a.id_comisionista ,1,2) in ('PH') then 'PH'
  --   when substr(a.id_comisionista ,1,3) in ('MKT') then 'NR'
  -- end as canal,
  case
    when a.id_comisionista = e.id_comisionista then e.canal
    when a.id_comisionista = 'C02142' then 'ALTNH'
    when substr(a.id_comisionista ,1,2) in ('MP') then 'MP'
    when substr(a.id_comisionista ,1,2) in ('PH') then 'PH'
    when substr(a.id_comisionista ,1,3) in ('MKT') then 'NR'
  end as canal,

  case
    when a.cif ='B39688197' and a.descripcion ='C - Segunda Recarga' then 'C - Bonus 3 meses'
    when a.cif ='B39688197' and a.descripcion ='C - Tercera Recarga' then 'C - Bonus 6 meses'
    when a.descripcion = 'D - Extracomision Terminal' then 
        case 
            when a.descripcion = 'D - Extracomision Terminal' and f.sell_type = 'RENUEVO' then 'D - Extracomision Terminal Renuevo' 
            else 'D - Extracomision terminal'
        end
    when a.descripcion = 'D – Extracomision Prepago' then 'D - Extracomision Prepago'
    else d.concepto end as concepto,
    
  d.tipo_concepto as tipo_concepto,
  1 as unidades,
  coalesce ( b.comision, a.importe) as comision,
  split (a.id_comisionista,'-')[SAFE_OFFSET(0)] as id_comisionista,
  a.id_comisionista as distribuidor,
  
  case
    when codigo_unico like 'LB-%' then split(codigo_unico,'-')[SAFE_OFFSET(1)]
    else codigo_unico
  end as sfid_id, -- 20250416 JOHANNA: AGREGUÉ CASE PARA EVITAR SFIDS DEL TIPO LB-XXXXX
  
  case
    when codigo_tienda like 'LB-%' then split(codigo_tienda,'-')[SAFE_OFFSET(1)]
    else codigo_tienda
  end as seller, -- 20250416 JOHANNA: AGREGUÉ CASE PARA EVITAR SELLERS DEL TIPO LB-XXXXX
  
  case 
      when a.id_comisionista like 'PH%' then 'THE PHONE HOUSE SPAIN, S.L.U.'
      else c.vendor_name 
  end as nombre_comercio,
  
  case 
      when a.id_comisionista like 'PH%' then 'THE PHONE HOUSE SPAIN, S.L.U.'
      else c.vendor_name 
  end as razon_social,
  
  case 
      when a.id_comisionista = e.id_comisionista then e.documento 
      when a.id_comisionista like 'PH%' and a.cif is null then 'B81846206' 
      else a.cif 
  end as cif, -- 20250704 JOHANNA: AGREGUÉ JOIN CON SELLERS DE GS EXCLUSIVO
  
  case when a.id_comisionista = e.id_comisionista then e.zona_fiscal else a.zona_fiscal end as zona_fiscal, -- 20250704 JOHANNA: AGREGUÉ JOIN CON SELLERS DE GS EXCLUSIVO PARAQUE SALGAN CORRECTAMENTE LAS ZONAS FISCALES DE EXCLUSIVO
  
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
  CAST (NULL AS DATE) as DEactivation_date,
  cast (null as string) as order_id,
  'ALTA NUEVA' as order_type_agg,
  segmento cod_segmento,
  tipo_contrato as cod_tipo_contrato,
  producto as cod_producto,
  e.canal as cod_canal,
  cast( cod_marca  as string format '00') as cod_marca,
  cast (null as string) as claim_code,
  'PREPAGO' as process_code,
  cast (null as string) as campaign_code,
  b.iccid as serial_number,
  cast (null as float64) as tax_base,
  
  CASE
      WHEN a.descripcion = 'D - Extracomision Terminal' THEN b.comments
      ELSE 'Importe recarga: '|| cast(importe_recarga as string) 
  END AS comments ,

  'C_MANUAL' as facturador
  FROM `mm-commissions-reporting.PREPAGO.MM_PREPAID_COMMISSIONS_CANAL_*` a,
  unnest(detalle_trazabilidad_activacion) b
  left join `mm-commissions-reporting.SAP.vendor_list` c on a.cif = c.tax_code
  left join `mm-commissions-reporting.GS.PREPAGO_CONCEPTOS`  d on REPLACE(a.descripcion, ' ', '') = REPLACE(d.concepto_etnico, ' ', '') AND REPLACE(a.descripcion, '–', '-') = REPLACE(d.concepto_etnico, '–', '-') 
  left join `mm-commissions-reporting.GS.exclusivo_dealers` e on e.id_comisionista = case when codigo_tienda like 'LB-%' then split(codigo_tienda,'-')[SAFE_OFFSET(1)] else codigo_tienda
  end and e.comisiona = TRUE
  left join `mm-commissions-reporting.TEMP.multidispositivos_final` f on b.iccid = f.serial_number and b.sim_activation_date = f.order_date and b.msisdn = f.phone_nm
  where _table_suffix = prefijo_tabla
  and a.id_comisionista not in ('PFLYC0006', 'EUR0', 'TEST01')
  )
where comision <> 0.0
and commission_id is not null
and canal is not null
and concepto != 'B - Renuevo'
and not (concepto like '%Devolucion%'
         and id_comisionista in ('BY314400','BY414400','LB152006','LM114400')
        ) -- No existen Devoluciones de SIM en Melilla
--and a.cif ='B39688197'
--AND COD_MARCA = 1
 ;

-- select distinct canal from TEMP.informacion_prepago;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('2PREP_CANAL' , cast(substr(prefijo_tabla,1,6) as int64), (select array_agg(DISTINCT canal) from TEMP.informacion_prepago), 'TEMP.informacion_prepago', 'ACTUALIZAR');


end