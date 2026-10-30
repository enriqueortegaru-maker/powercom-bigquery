BEGIN

  --LOCAL
  --DECLARE DESDE INT64; SET DESDE=20241101;

  --- PASO 1: COMISIONES A ACTUALIZAR
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0808_COMISIONES_ACTUALIZADAS` AS
  --DECLARE DESDE INT64; SET DESDE=20241101;
  with ca as (
    SELECT * except(vmarca)
    FROM `mm-commissions-reporting.GS.TRADUCTOR_KRT_CANALES` 
    CROSS JOIN UNNEST(split(vmarca,'/')) as marca
    where tipo_gekt="CAPTACION"
  ) 
  select c.*
  from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
  inner join ca on c.marca_ds=ca.marca   
  and c.canal_alta_ds=ca.canal_gekt 
  and c.subcanal_ds=ca.subcanal_gekt
  and (c.marco_retributivo_ds is null or length(c.marco_retributivo_ds) <2)
  and EXTRACT( DATE FROM c.fecha_rfb_dt)>= parse_date('%Y%m%d', cast(desde AS STRING))
  and EXTRACT( DATE FROM c.fecha_rfb_dt)<= ca.ffin_dt; -- parse_date('%Y%m%d', cast(hasta AS STRING))
  --and c.fecha_calc_dt='2024-11-07'


  --- PASO 2: ACTUALIZACION DE COMISIONES
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`  c
  SET c.marco_retributivo_ds=ca.marco_gekt
  FROM (
    SELECT * except(vmarca)
    FROM `mm-commissions-reporting.GS.TRADUCTOR_KRT_CANALES` 
    CROSS JOIN UNNEST(split(vmarca,'/')) as marca
    where tipo_gekt="CAPTACION"
  ) ca
  where c.marca_ds=ca.marca 
  and c.canal_alta_ds=ca.canal_gekt 
  and c.subcanal_ds=ca.subcanal_gekt
  and (c.marco_retributivo_ds is null or length(c.marco_retributivo_ds) <2)
  and EXTRACT( DATE FROM c.fecha_rfb_dt)>= parse_date('%Y%m%d', cast(desde AS STRING))
  and EXTRACT( DATE FROM c.fecha_rfb_dt)<= ca.ffin_dt; -- parse_date('%Y%m%d', cast(hasta AS STRING))
  --and c.fecha_calc_dt='2024-11-07'

END