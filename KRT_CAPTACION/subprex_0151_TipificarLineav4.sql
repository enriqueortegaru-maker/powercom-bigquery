BEGIN

  
  declare param_hasta_dt date;
--  declare desde, hasta int64;   
--  SET desde=20230201;
--  SET hasta=20230208;
  set param_hasta_dt = parse_date ('%Y%m%d', cast ( HASTA as string) );


-- PASO 1: IDENTIFICO POBLACION DE SERVICIOS A ANALIZAR
  --- Servicios de captacion de categorias fijo y movil postpago, enriquecidos con identificativo segmentado por marca_ds y cliente_id  

  CREATE OR REPLACE TABLE`mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` AS
  With sfm as (
      SELECT distinct s.marca_ds,s.Cliente_id,s.servicio_id, s.categoria_servicio_ds, s.detalle_servicio_ds, s.CONCEPTO_DS,s.gb,s.portabilidad_in_lg,s.NPLAYS, ROW_NUMBER() OVER (PARTITION BY s.cliente_id, s.marca_ds ORDER BY s.gb DESC, s.servicio_id) orden
      FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s 
      WHERE s.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
      and s.clase_mm='A - Servicio base'
      and s.fecha_rfb_id>=desde 
      and s.fecha_rfb_id<=hasta
      order by s.marca_ds, s.cliente_id, orden
      --- ÑAPA TEMPORAL AÑADIDA EL 2022-11-30 
      --AND TRIM(detalle_servicio_ds) not in ('K-ayuda PRO','módulo pro 2021','C.M. TELECABLE T-AYUD@ PRO')
      --- HAY QUE CAMBIAR PARA QUE FILTRADO SOLO SEA EN BASE A SERVICIOS BASE
  )
  select DISTINCT sfm.*, tr.clasificacion_ds, tr.desde_dt, tr.hasta_dt  
  from sfm 
  inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` as tr
  on sfm.marca_ds=tr.marca_ds and sfm.cliente_id=tr.cliente_id
  WHERE CAST(tr.desde_dt AS date) <= param_hasta_dt
  AND CAST(tr.hasta_dt AS date) > param_hasta_dt 
  order by gb desc, servicio_id; 
  


-- PASO 2: EJECUTO TIPIFICACION DE SERVICIOS DE FIJA

UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv
  SET serv.concepto_ds = CONCAT(serv.concepto_ds,CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad'  END)
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` as sfmxtr
  WHERE serv.marca_ds=sfmxtr.marca_ds
  AND serv.cliente_id=sfmxtr.cliente_id 
  AND serv.servicio_id =sfmxtr.servicio_id  
  AND serv.categoria_servicio_ds='FIJA';





-- PASO 2: EJECUTO TIPIFICACION DE SERVICIOS DE MOVIL

UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv
  SET
    serv.concepto_ds = CONCAT(CASE WHEN sfmxtr.orden = 1 THEN 'Primera linea ' ELSE 'Linea adicional 'END,
      CASE WHEN sfmxtr.clasificacion_ds = 'SOMO' AND serv.NPLAYS=1 THEN 'SOMO ' ELSE  ''  END,
      serv.concepto_ds,
      CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad' END
    )
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` as sfmxtr
  WHERE serv.marca_ds=sfmxtr.marca_ds 
  AND serv.cliente_id=sfmxtr.cliente_id  
  AND serv.servicio_id =sfmxtr.servicio_id
  AND serv.categoria_servicio_ds='MOVILES POSTPAGO';
  --AND NOT(serv.marca_ds="TELECABLE" AND serv.cliente_id IN (1683235,1660064) AND serv.servicio_id IN (32014121,32050688));


-- PASO 4: INSERTO REGISTROS EN FICHERO DE LOG

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_CAPTACION` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`; 

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_CAPTACION_UPD` AS
  SELECT 
    s.* 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_SERVICIOS_CAPTACION` l
    where l.marca_ds=s.marca_ds 
    and l.cliente_id=s.cliente_id
    and l.servicio_id=s.servicio_id
    and COALESCE(l.concepto_ds,'NULO')!=COALESCE(s.concepto_ds,'NULO')
  );



END