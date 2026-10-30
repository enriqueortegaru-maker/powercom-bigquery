BEGIN 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxMARCAxDIA` AS
    SELECT f.dia_dt as fecha_dt, f.dia_id as dia_id, s.marca_ds,  count(distinct s.servicio_id||s.marca_ds) naccba
    from `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA` f
    left join  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s 
    on f.dia_id between fecha_operacion_alta_id and fecha_baja_id
    where f.dia_id >=CAST(FORMAT_DATE("%Y%m%d",date_trunc(CURRENT_DATE(),year))AS INT64)
        and f.dia_dt <=current_date()
        and s.visibilidad_lg = 1	
        and s.tipo_servicio_ds='BANDA ANCHA'
        and s.segmento_ds in ('SOHO', 'RESIDENCIAL','PYME')
    group by 1,2,3
    order by 1,2,3;
END