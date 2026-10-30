begin

--- call COMISIONES.pr_cargar_prepago_simyo ('20260401');

create or replace table TEMP.informacion_prepago_simyo as
select *
from
  (select
  -- 'PRP_SIMYO_'||prefijo_tabla||'_'||id_registro||'_'||row_number () over () as commission_id,
  prefijo_tabla||'_'||id_registro as commission_id,
  'calculado' as estado,
  cast(substr(prefijo_tabla,1,6) as int64) as id_mes,
  
  'No Exclusivo' as agrupacion_canal,
  'ALTN' as canal,
  case
    when a.cif ='B39688197' and a.descripcion ='C - Segunda Recarga' then 'C - Bonus 3 meses'
    when a.cif ='B39688197' and a.descripcion ='C - Tercera Recarga' then 'C - Bonus 6 meses'
    when a.descripcion = 'D - Extracomision Terminal' then 'D - Extracomision terminal'
    when a.descripcion = 'D – Extracomision Prepago' then 'D - Extracomision Prepago'
    else d.concepto end as concepto,
 
  d.tipo_concepto as tipo_concepto,
  1 as unidades,
  coalesce ( b.comision, a.importe) as comision,
  id_comisionista,
  a.id_comisionista as distribuidor,
  codigo_unico as sfid_id, 
  codigo_tienda as seller, 
  c.vendor_name as nombre_comercio,
  c.vendor_name as razon_social,
  a.cif,  
  a.zona_fiscal, 
  
  case cod_marca
  when '01' then 'YOIGO'
  when '14' then 'LYCAMOBILE'
  when '11' then 'LEBARA'
  when '04' then 'LLAMAYA'
  when '05'then 'MASMOVIL'
  when '36' then 'SIMYO'
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
  '29' as cod_canal,
  cast( cod_marca  as string) as cod_marca,
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
  FROM `mm-prepaid-reporting.COMISIONES.MM_PREPAID_COMMISSIONS_SIMYO_*` a,
  unnest(detalle_trazabilidad_activacion) b
  left join `mm-commissions-reporting.SAP.vendor_list` c on a.cif = c.tax_code
  left join `mm-commissions-reporting.GS.PREPAGO_CONCEPTOS`  d on REPLACE(a.descripcion, ' ', '') = REPLACE(d.concepto_etnico, ' ', '') AND REPLACE(a.descripcion, '–', '-') = REPLACE(d.concepto_etnico, '–', '-') 
  where _table_suffix = prefijo_tabla
  and a.id_comisionista not in ('PFLYC0006', 'EUR0', 'TEST01')
  )
where comision <> 0.0
and commission_id is not null
and canal is not null

;
CREATE OR REPLACE TABLE  TEMP.informacion_prepago_simyo_final AS (

--- COMISIONES PDV
SELECT 
commission_id	,
estado	,
PREPAGO.id_mes	,
PREPAGO.agrupacion_canal	,
PREPAGO.canal	,
concepto	,
tipo_concepto	,
unidades	,
comision	,
PREPAGO.id_comisionista	,
DEALER.distribuidor	,
PREPAGO.sfid_id	,
PREPAGO.seller	,
DEALER.nombre_comercio	,
DEALER.razon_social	,
PREPAGO.cif	,
'PEN' AS zona_fiscal	,
marca	,
service_type	,
phone_nm	,
tariff_id	,
tariff_ds	,
service_id	,
account_id	,
customer_id	,
line_type_ds	,
bundle_type	,
technology_ds	,
billing_type_ds	,
sale_date	,
activation_date	,
DEactivation_date	,
order_id	,
order_type_agg	,
cod_segmento	,
cod_tipo_contrato	,
cod_producto	,
cod_canal	,
cod_marca	,
claim_code	,
process_code	,
campaign_code	,
serial_number	,
tax_base	,
comments	,
facturador	,


FROM `mm-commissions-reporting.TEMP.informacion_prepago_simyo` PREPAGO
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON PREPAGO.id_comisionista = DEALER.sfid_id

WHERE DEALER.CANAL = 'ALTN'
AND PREPAGO.concepto LIKE 'C -%'
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY commission_id, concepto ORDER BY comision DESC) = 1

UNION ALL


SELECT 
commission_id	,
estado	,
PREPAGO.id_mes	,
PREPAGO.agrupacion_canal	,
PREPAGO.canal	,
concepto	,
tipo_concepto	,
unidades	,
comision	,
MASTER.id_comisionista	,
MASTER.id_comisionista AS distribuidor	,
PREPAGO_SFID.sfid_id	,
PREPAGO_SFID.sfid_id AS seller	,
MASTER.nombre_comercio	,
MASTER.razon_social	,
MASTER.cif	,
MASTER.zona_fiscal	,
marca	,
service_type	,
phone_nm	,
tariff_id	,
tariff_ds	,
PREPAGO.service_id	,
account_id	,
customer_id	,
line_type_ds	,
bundle_type	,
technology_ds	,
billing_type_ds	,
sale_date	,
activation_date	,
deactivation_date	,
order_id	,
order_type_agg	,
cod_segmento	,
cod_tipo_contrato	,
cod_producto	,
cod_canal	,
cod_marca	,
claim_code	,
process_code	,
campaign_code	,
serial_number	,
tax_base	,
comments	,
facturador	,


FROM `mm-commissions-reporting.TEMP.informacion_prepago_simyo` PREPAGO
LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
ON PREPAGO.cif = MASTER.cif

LEFT JOIN (SELECT DISTINCT sfid_id, service_id FROM `mm-commissions-reporting.TEMP.informacion_prepago_simyo` WHERE CONCEPTO LIKE 'C -%') PREPAGO_SFID
ON PREPAGO.service_id = PREPAGO_SFID.service_id

WHERE CONCEPTO LIKE 'F -%'
AND MASTER.id_comisionista IS NOT NULL

)
;
--- AÑADIMOS COMISIONES DE GPV ---
INSERT INTO TEMP.informacion_prepago_simyo_final
SELECT 
commission_id 	,
estado	,
PREPAGO.id_mes	,
PREPAGO.agrupacion_canal	,
PREPAGO.canal	,
REPLACE (concepto,'F -','G -') AS concepto	,
tipo_concepto	,
unidades	,
comision	,
MASTER.id_comisionista	,
MASTER.id_comisionista AS distribuidor	,
PREPAGO.sfid_id	,
PREPAGO.seller	,
MASTER.nombre_comercio	,
MASTER.razon_social	,
MASTER.cif	,
'PEN' AS zona_fiscal	,
marca	,
service_type	,
phone_nm	,
tariff_id	,
tariff_ds	,
service_id	,
account_id	,
customer_id	,
line_type_ds	,
bundle_type	,
technology_ds	,
billing_type_ds	,
sale_date	,
activation_date	,
DEactivation_date	,
order_id	,
order_type_agg	,
cod_segmento	,
cod_tipo_contrato	,
cod_producto	,
cod_canal	,
cod_marca	,
claim_code	,
process_code	,
campaign_code	,
serial_number	,
tax_base	,
comments	,
facturador	,


FROM `mm-commissions-reporting.TEMP.informacion_prepago_simyo_final` PREPAGO
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON PREPAGO.sfid_id = DEALER.sfid_id

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
ON DEALER.cif_gpv = MASTER.cif

WHERE DEALER.CANAL = 'ALTN'
AND DEALER.cif_gpv IS NOT NULL
AND PREPAGO.concepto IN ('F - Primera Recarga','F - Recargas Sucesivas')

;

CREATE OR REPLACE TABLE  TEMP.informacion_prepago_simyo_final AS (
  SELECT
  'PRP_SIMYO_'||commission_id||'_'||row_number () over () as commission_id,
  *
  EXCEPT (commission_id)
  FROM TEMP.informacion_prepago_simyo_final)
  
;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('PRP_SIMYO_', cast(substr(prefijo_tabla,1,6) as int64), (select array_agg(DISTINCT canal) from TEMP.informacion_prepago_simyo_final), 'TEMP.informacion_prepago_simyo_final', 'ACTUALIZAR');

end