BEGIN

  
  declare param_hasta_dt date;
  --declare desde, hasta int64;   
  --SET desde=20221101;
  --SET hasta=20221124;
  set param_hasta_dt = parse_date ('%Y%m%d', cast ( HASTA as string) );


-- PASO 1: IDENTIFICO REGISTROS A ANALIZAR

  CREATE OR REPLACE TABLE`mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` AS
  With sfm as (
      SELECT distinct s.marca_ds,s.Cliente_id,s.servicio_id, s.categoria_servicio_ds, s.detalle_servicio_ds, s.CONCEPTO_DS,s.gb,s.portabilidad_in_lg,npv.NPLAYS, ROW_NUMBER() OVER (PARTITION BY s.cliente_id, s.marca_ds ORDER BY s.gb DESC, s.servicio_id) orden
      FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s 
      inner join ( select distinct marca_ds,cliente_id,servicio_id,clase_mm, desc_mm from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`) v
      on v.marca_ds=s.marca_ds and v.cliente_id=s.cliente_id and v.servicio_id=s.servicio_id and CONTAINS_SUBSTR(v.clase_mm,'A - Servicio base')
      inner join `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` npv
      on npv.marca_ds=s.marca_ds and npv.cliente_id= s.Cliente_id 
      WHERE s.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
      and s.fecha_rfb_id>=desde 
      and s.fecha_rfb_id<=hasta
      order by s.marca_ds, s.cliente_id, orden
      --- ÑAPA TEMPORAL AÑADIDA EL 2022-11-30 
      --AND TRIM(detalle_servicio_ds) not in ('K-ayuda PRO','módulo pro 2021','C.M. TELECABLE T-AYUD@ PRO')
      --- HAY QUE CAMBIAR PARA QUE FILTRADO SOLO SEA EN BASE A SERVICIOS BASE
  )
  --- Servicios de captacion de categorias fijo y movil postpago, enriquecidos con identificativo segmentado por marca_ds y cliente_id  
  --- Y cruzado con tramos de servicio 
  select DISTINCT sfm.*, tr.clasificacion_ds, tr.desde_dt, tr.hasta_dt  
  from sfm 
  inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` as tr
  on sfm.marca_ds=tr.marca_ds and sfm.cliente_id=tr.cliente_id
  WHERE CAST(tr.desde_dt AS date) <= param_hasta_dt
  AND CAST(tr.hasta_dt AS date) > param_hasta_dt 
  order by gb desc, servicio_id; 
  


-- PASO 2: EJECUTO ACTUALIZACION DE REGISTROS

UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv

  SET
    serv.concepto_ds = CONCAT(CASE WHEN serv.categoria_servicio_ds = 'MOVILES POSTPAGO' THEN CASE WHEN sfmxtr.orden = 1 THEN 'Primera linea ' ELSE 'Linea adicional ' END ELSE '' END
      , CASE WHEN serv.categoria_servicio_ds = 'MOVILES POSTPAGO' AND sfmxtr.clasificacion_ds = 'SOMO' THEN 'SOMO ' ELSE  ''  END
      , serv.concepto_ds,
      CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad'  END
    )
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` as sfmxtr
  WHERE serv.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
  AND serv.servicio_id =sfmxtr.servicio_id
  AND serv.marca_ds=sfmxtr.marca_ds
  AND serv.cliente_id=sfmxtr.cliente_id
  AND NOT(serv.marca_ds="TELECABLE" AND serv.cliente_id IN (1683235,1660064) AND serv.servicio_id IN (32014121,32050688));



-- PASO 3: VERIFICO QUE LA TIPIFICACION DE UN CLIENTE SOMO ES CORRECTA O INCORRECTA EN BASE A LAS VENTAS EN CURSO.
---        ACTUALIZO LOS REGISTROS DE SERVICIOS_CAPTACION,y elimino marca SOMO a servicios qeu cumplen: 
---           Servicio captacion con categoria_servicio_ds = 'MOVILES POSTPAGO'
---           Servicio captacion con concepto_ds contiene cadena 'SOMO '
---           PLAYS>1  
---        QUE CRUZAN CON VENTAS y NPLAYS por 
---            marca_ds, cliente_id y servicio_id    
---         Y CUYA VENTA REGISTRA UN NPLAY>1

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_CAPTACION_UPD_CL_SOMO_PLMAS1` AS
  SELECT serv.*, vc.NPLAYS
  from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv
  INNER JOIN(
        select v.marca_ds, v.cliente_id, v.servicio_id, c.NPLAYS
        from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` as v
        inner join `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` as c 
        on c.marca_ds=v.marca_ds and c.cliente_id=v.cliente_id
        WHERE v.categoria_servicio_ds='MOVILES POSTPAGO'
        order by 1,2,3
  ) vc
  on serv.marca_ds=vc.marca_ds
  and serv.cliente_id=vc.cliente_id
  and serv.servicio_id=vc.servicio_id 
  where serv.categoria_servicio_ds='MOVILES POSTPAGO'
  and CONTAINS_SUBSTR(serv.concepto_ds,'SOMO ') 
  and vc.NPLAYS>1;


  UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv

    SET
      serv.concepto_ds = REPLACE(serv.concepto_ds, 'SOMO ','')
    FROM (
          select v.marca_ds, v.cliente_id, v.servicio_id, c.NPLAYS
          from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` as v
          inner join `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` as c 
          on c.marca_ds=v.marca_ds and c.cliente_id=v.cliente_id
          WHERE v.categoria_servicio_ds='MOVILES POSTPAGO'
          order by 1,2,3
    ) vc
    where serv.categoria_servicio_ds='MOVILES POSTPAGO'
    and CONTAINS_SUBSTR(serv.concepto_ds,'SOMO ') 
    and vc.NPLAYS>1
    and serv.marca_ds=vc.marca_ds
    and serv.cliente_id=vc.cliente_id
    and serv.servicio_id=vc.servicio_id;



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
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM  
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_SERVICIOS_CAPTACION`;



END