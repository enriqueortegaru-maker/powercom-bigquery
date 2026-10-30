BEGIN
  --declare desde,hasta INT64;
  --SET desde=20220901;
  --SET hasta=20220930;

-- PASO 1: IDENTIFICO LOS SERVICIOS BASICOS A ANALIZAR

  CREATE OR REPLACE TABLE`mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` AS
  
    SELECT distinct s.marca_ds,s.Cliente_id,s.servicio_id, s.categoria_servicio_ds, s.detalle_servicio_ds, s.CONCEPTO_DS,s.gb,s.portabilidad_in_lg,npv.NPLAYS, ROW_NUMBER() OVER (PARTITION BY s.cliente_id, s.marca_ds ORDER BY s.gb DESC, s.servicio_id) orden
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s 
    inner join ( select distinct marca_ds,cliente_id,servicio_id,clase_mm, desc_mm from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`) v
    on v.marca_ds=s.marca_ds and v.cliente_id=s.cliente_id and v.servicio_id=s.servicio_id and CONTAINS_SUBSTR(v.clase_mm,'A - Servicio base')
    inner join `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` npv
    on npv.marca_ds=s.marca_ds and npv.cliente_id= s.Cliente_id 
    WHERE s.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
    and s.fecha_rfb_id>=desde 
    and s.fecha_rfb_id<=hasta
    order by s.marca_ds, s.cliente_id, orden;
    --- ÑAPA TEMPORAL AÑADIDA EL 2022-11-30 
    --AND TRIM(detalle_servicio_ds) not in ('K-ayuda PRO','módulo pro 2021','C.M. TELECABLE T-AYUD@ PRO')
    --- HAY QUE CAMBIAR PARA QUE FILTRADO SOLO SEA EN BASE A SERVICIOS BASE
  
  
  
-- PASO 2: EJECUTO ACTUALIZACION DE REGISTROS

  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` serv

  SET
    serv.concepto_ds = CONCAT(CASE WHEN serv.categoria_servicio_ds = 'MOVILES POSTPAGO' THEN CASE WHEN sfmxtr.orden = 1 THEN 'Primera linea ' ELSE 'Linea adicional ' END ELSE '' END
      , CASE WHEN serv.categoria_servicio_ds = 'MOVILES POSTPAGO' AND sfmxtr.NPLAYS = 1 THEN 'SOMO ' ELSE  ''  END
      , serv.concepto_ds,
      CASE  WHEN serv.portabilidad_in_lg = 1 THEN ' con portabilidad' ELSE ' sin portabilidad'  END
    )
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` as sfmxtr
  WHERE serv.categoria_servicio_ds IN ('FIJA','MOVILES POSTPAGO')
  AND serv.servicio_id =sfmxtr.servicio_id
  AND serv.marca_ds=sfmxtr.marca_ds
  AND serv.cliente_id=sfmxtr.cliente_id;
  --AND NOT(serv.marca_ds="TELECABLE" AND serv.cliente_id IN (1683235,1660064) AND serv.servicio_id IN (32014121,32050688));

-- PASO 2: INSERTO REGISTROS EN FICHERO DE LOG

--with d as (
--select sfmxtr.marca_ds, sfmxtr.cliente_id, sfmxtr.servicio_id, count(sfmxtr.orden) as nreg
--FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` as sfmxtr
--group by 1,2,3
--having nreg>1)
--select s.*
--FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0151_SERVICIOS_FMxTR` as s
--inner join d
--on d.marca_ds=s.marca_ds and d.cliente_id=s.Cliente_id and d.servicio_id=s.servicio_id ;

--select * from `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s where servicio_id=127065049;

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