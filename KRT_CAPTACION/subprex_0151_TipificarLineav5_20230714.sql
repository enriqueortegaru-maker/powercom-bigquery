BEGIN

  
  declare param_hasta_dt date;
  --VARIABLES LOCALES
  --declare desde, hasta int64;   
  --SET desde=20230501;
  --SET hasta=20230531;
  set param_hasta_dt = parse_date ('%Y%m%d', cast ( HASTA as string) );


--- PASO 0.1: IDENTIFICO DUPLICADOS 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_DUPLICADOS_SERVICIOS_CAPTACION` as 
  with dup as (
    select marca_ds, cliente_id, servicio_id, count(grid) as nreg
    from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
    group by 1,2,3
    having count(grid) > 1
  )select s.*
  from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s
  inner join dup d on d.marca_ds=s.marca_ds and d.cliente_id=s.cliente_id and d.servicio_id=s.servicio_id
  order by s.marca_ds, s.cliente_id,s.servicio_id; 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REVISAR_DUPLICADOS_SERVICIOS_CAPTACION` as 
  select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_DUPLICADOS_SERVICIOS_CAPTACION`; 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_REGISTRO_SERVICIOS_CAPTACION_NO DUPLICADO` as 
  select s.*, row_number() over(partition by s.marca_ds, s.cliente_id, s.servicio_id ORDER BY s.marca_ds, s.cliente_id, s.servicio_id) as nreg
  from `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_DUPLICADOS_SERVICIOS_CAPTACION` s 
  qualify nreg=1;



--- PASO 0.2: REEMPLAZO DUPLICADOS

DELETE from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s 
where exists (
  select 1 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_DUPLICADOS_SERVICIOS_CAPTACION` d where d.marca_ds=s.marca_ds and d.cliente_id=s.cliente_id and d.servicio_id=s.servicio_id
);

INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
SELECT * except(nreg) FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_REGISTRO_SERVICIOS_CAPTACION_NO DUPLICADO`;




-- PASO 1: IDENTIFICO POBLACION DE SERVICIOS A ANALIZAR
  --- Servicios de captacion de categorias fijo y movil postpago, enriquecidos con identificativo segmentado por marca_ds y cliente_id  

  CREATE OR REPLACE TABLE`mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` AS
  With sfm as (
      SELECT distinct s.marca_ds,s.Cliente_id,s.pedido, s.servicio_id, s.categoria_servicio_ds, s.detalle_servicio_ds, s.CONCEPTO_DS,s.gb,s.portabilidad_in_lg,s.NPLAYS_p, s.cat_plays_p,s.fecha_rfb_dt, ROW_NUMBER() OVER (PARTITION BY s.marca_ds, s.cliente_id, s.pedido ORDER BY s.gb DESC, s.servicio_id) orden
      FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s 
      WHERE s.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
      and ((s.clase_mm='A - Servicio base') or grid=6)
      and s.fecha_rfb_id>=desde 
      and s.fecha_rfb_id<=hasta
      order by s.marca_ds, s.cliente_id, orden
      --- ÑAPA TEMPORAL AÑADIDA EL 2022-11-30 
      --AND TRIM(detalle_servicio_ds) not in ('K-ayuda PRO','módulo pro 2021','C.M. TELECABLE T-AYUD@ PRO')
      --- HAY QUE CAMBIAR PARA QUE FILTRADO SOLO SEA EN BASE A SERVICIOS BASE
  )
  select DISTINCT sfm.*, tr.clasificacion_pre_ds, tr.clasificacion_ds, tr.clasificacion_detalle_ds, tr.desde_dt, tr.hasta_dt  
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





-- PASO 3: EJECUTO TIPIFICACION DE SERVICIOS DE MOVIL

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_CONCEPTOS_MOVILES_UPD` AS 
  SELECT sfmxtr.marca_ds, sfmxtr.cliente_id, sfmxtr.categoria_servicio_ds, sfmxtr.servicio_id, sfmxtr.pedido, sfmxtr.NPLAYS_P, sfmxtr.cat_PLAYS_P, sfmxtr.clasificacion_pre_ds, sfmxtr.clasificacion_ds,sfmxtr.desde_dt,sfmxtr.fecha_rfb_dt, sfmxtr.orden,sfmxtr.concepto_ds, 
     CONCAT(CASE WHEN sfmxtr.orden = 1 THEN 'Primera linea ' ELSE 'Linea adicional 'END,
      CASE WHEN sfmxtr.clasificacion_ds = 'SOMO' AND serv.NPLAYS_P=1 THEN 'SOMO ' ELSE  ''  END,
      sfmxtr.concepto_ds,
      CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad' END
      ) cl1,
     CONCAT(CASE WHEN CONTAINS_SUBSTR(sfmxtr.cat_plays_p,"BA") THEN CASE WHEN sfmxtr.orden = 1 THEN 'Primera linea ' ELSE 'Linea adicional 'END
                 ELSE 
                      CASE sfmxtr.clasificacion_ds
                          WHEN 'SOMO' THEN
                            CASE WHEN DATE_DIFF(sfmxtr.fecha_rfb_dt,sfmxtr.desde_dt,DAY)=0 THEN CASE WHEN (sfmxtr.orden = 1 AND sfmxtr.clasificacion_pre_ds !='SOMO') THEN 'Primera linea ' ELSE 'Linea adicional 'END
                            ELSE 
                                CASE WHEN DATE_DIFF(sfmxtr.fecha_rfb_dt,sfmxtr.desde_dt,DAY)>0 THEN 'Linea adicional ' 
                                    ELSE  CASE WHEN DATE_DIFF(sfmxtr.fecha_rfb_dt,sfmxtr.desde_dt,DAY)<0  THEN 
                                              CASE sfmxtr.clasificacion_pre_ds
                                                    WHEN 'SOMO'  THEN 'Linea adicional '
                                                    ELSE 'Primera linea ' 
                                              END   
                                          END  
                                END
                            END 
                          ELSE 'Linea adicional '
                      END
                 END,
      CASE WHEN sfmxtr.clasificacion_ds = 'SOMO' AND serv.NPLAYS=1  AND serv.cat_PLAYS="MOVIL" THEN 'SOMO ' ELSE  ''  END,
      sfmxtr.concepto_ds,
      CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad' END
      ) nuevo_concepto_ds
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR`as sfmxtr
  inner join `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv
  ON serv.marca_ds=sfmxtr.marca_ds 
  AND serv.cliente_id=sfmxtr.cliente_id  
  AND serv.servicio_id =sfmxtr.servicio_id
  AND serv.pedido =sfmxtr.pedido 
  AND serv.categoria_servicio_ds='MOVILES POSTPAGO'
  --AND sfmxtr.clasificacion_ds = 'SOMO'
  --and NOT CONTAINS_SUBSTR(sfmxtr.cat_plays_p,'BA')
  --and DATE_DIFF(sfmxtr.fecha_rfb_dt,sfmxtr.desde_dt,DAY)<0 
  order by 1,2,3,4,5,6,7,8,9,10,11,12;


  --- PASO 3: ELIMINO LOS NUEVOS CONCEPTOS DE LOS SERVICIOS DE DE AQUELLOS CATALOGOS DE PRODUCTOS QUE NO DEBEN SER RETIPIFICADOS
  DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_CONCEPTOS_MOVILES_UPD` s
  WHERE EXISTS (
    select 1
    from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` sc 
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXCLUSION_TIPIFICACION_LINEA_MOVIL` e on e.marca_ds=sc.marca_ds  and e.catalogo_id=sc.catalogo_id
    where s.marca_ds=sc.marca_ds  and s.cliente_id=sc.cliente_id and s.servicio_id =sc.servicio_id and s.pedido =sc.pedido 
  );



  --- PASO 4: ACTUALIZO LOS CONCEPTOS DE LOS SERVICIOS MOVILES 

UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv
  SET
    serv.concepto_ds = sm.nuevo_concepto_ds
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_CONCEPTOS_MOVILES_UPD` as sm
  WHERE serv.marca_ds=sm.marca_ds 
  AND serv.cliente_id=sm.cliente_id  
  AND serv.categoria_servicio_ds =sm.categoria_servicio_ds  
  AND serv.servicio_id =sm.servicio_id
  AND serv.pedido =sm.pedido; 
  --AND NOT(serv.marca_ds="TELECABLE" AND serv.cliente_id IN (1683235,1660064) AND serv.servicio_id IN (32014121,32050688));


-- PASO 5: INSERTO REGISTROS EN FICHERO DE LOG

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
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_015020_SERVICIOS_CAPTACION_FINAL` l
    where l.marca_ds=s.marca_ds 
    and l.cliente_id=s.cliente_id
    and l.pedido=s.pedido         
    and l.servicio_id=s.servicio_id
    and COALESCE(l.concepto_ds,'NULO')!=COALESCE(s.concepto_ds,'NULO')
  );



END