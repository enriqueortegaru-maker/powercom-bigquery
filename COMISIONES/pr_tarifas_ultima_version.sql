begin

-- call `mm-commissions-reporting.COMISIONES.pr_tarifas_ultima_version`(202608)

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.tarifas_ultima_version` AS

select
id_mes
,canal
,marca
,service_type
,tariff_id
,tariff_ds
,line_type_ds
,pvp
,coalesce (tramo_1,0) as tramo_1
,coalesce (tramo_2,0) as tramo_2
,coalesce (tramo_3,0) as tramo_3
,coalesce (tramo_4,0) as tramo_4
,coalesce (tramo_5,0) as tramo_5
,coalesce (migraciones,0) migraciones
,coalesce (traslados,0) traslados
,coalesce (gestion_canal,0) gestion_canal
,coalesce (cuota,0) cuota
,coalesce (consumo,0) consumo
,CASE WHEN CANAL IN('XS','XSO','OSPNIN','OUNO','OSPNXSN') THEN campaign_code ELSE CAST(NULL AS STRING) END AS campaign_code
,creado_por
,creado
from `mm-commissions-reporting.COMISIONES.tarifas`
qualify row_number () over (partition by canal, id_mes, marca, service_type, tariff_id, tariff_ds, line_type_ds, campaign_code order by creado desc) = 1 ;

end