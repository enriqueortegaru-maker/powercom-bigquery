BEGIN

-- call `mm-commissions-reporting.KRT_CAPTACION.subprex_0103_CargarServiciosPorVelocidad_NoRv5_DESARROLLO`(20250401,20250531)

DECLARE
  DESDE_0M_DT DATE; 
DECLARE
  DESDE_0M INT64;

/*
DECLARE
  DESDE,
  HASTA INT64;
SET
  DESDE=20250401;
SET
  HASTA=20250531; 
*/

SET
  DESDE_0M_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( HASTA AS string)),month); ---  
SET
  DESDE_0M=CAST(FORMAT_DATE("%Y%m%d",DESDE_0M_DT) AS INT64); ---


--PASO 1: DESCUBRO VENTAS


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB` AS
--with pob as (
  with smovprep as (
    SELECT
      *
    FROM
      `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
    WHERE
      categoria_servicio_ds = 'MOVILES PREPAGO'
  )

  SELECT
    DISTINCT S.marca_ds,
    s.Cliente_id,
    CAST(S.servicio_id AS int64) servicio_id,
    S.detalle_servicio_ds,
    C.CONCEPTO_DS,
    S.FECHA_RFB_ID,
    S.FECHA_VENTA_NETA_ID,
    s.fecha_rfb_dt,
    s.fecha_venta_neta_dt,
    S.canal_alta_ds,
    S.subcanal_ds,
    S.tipo_canal_alta_ds,
    S.nombre_distribuidor_alta_ds,
    s.agente_alta_id,
    s.agente_creador_id,
    s.categoria_servicio_ds,
    cl.cif_nif,
    s.segmento_ds,
    cl.subsegmento_ds,
    CASE
      WHEN s.marca_ds NOT IN ('R') THEN S.marca_cartera_ds
      ELSE CASE
        WHEN ABS(DATE_DIFF(CAST(s.fecha_rfb_dt AS DATE), CAST(rfb.fecha_alta_dt AS DATE), DAY))> 15 THEN 'CARTERA'      
        ELSE 'CAPTACION'
      END
  END
    marca_cartera_ds,
    rfb.fecha_alta_dt as Antiguedad_Cliente,
    s.equipo_ds,
    s.territorio_ds,
    s.tecnologia_detalle_ds,
    s.portabilidad_in_lg,
    CASE
      WHEN s.categoria_servicio_ds = 'BANDA ANCHA' THEN s.velocidad_mb
      ELSE s.gb
  END
    gb,
    s.expediente_id,
    s.expediente_padre_id,
    s.contrato_id,
    s.tipo_pedido_ds,
    s.pedido_id,
    s.tipo_producto_pedido_re_ds,
    s.visibilidad_pedido_lg,
    s.catalogo_id,
  
  /*AÑADIDOS DEBUG*/
    s.servicio_id_original,
    s.servicio_id_origen,
    s.servicio_id_destino,
    s.fecha_rfs_dt,
    s.fecha_baja_dt,
    s.fecha_baja_id,
    s.operacion_alta_ds,
    s.operacion_baja_ds,  
    s.estado_hoy_ds,
    s.estado_crm_ds,
    CASE When coalesce(s.servicio_id_origen,-666 ) < 0   THEN "ALTA" ELSE "MIGRACION" END as tipo,
    DATE_DIFF(CAST(S.fecha_rfs_dt AS DATE), CAST(S.fecha_venta_neta_dt AS DATE), DAY) as ndays_inst_venta,
    DATE_DIFF(CAST(S.fecha_rfs_dt AS DATE), CAST(S.fecha_venta_neta_dt AS DATE), MONTH) as nmonths_inst_venta,    
    DATE_DIFF(CAST(S.fecha_rfb_dt AS DATE), CAST(S.fecha_rfs_dt AS DATE), DAY) as ndays_act_inst,
    DATE_DIFF(CAST(S.fecha_rfb_dt AS DATE), CAST(S.fecha_rfs_dt AS DATE), MONTH) as nmonths_act_inst,    
    DATE_DIFF(DATE_TRUNC(CAST(S.fecha_rfb_dt AS DATE),month),DESDE_0M_DT,MONTH) as ind_rfb_month,
  /*FIN AÑADIDOS DEBUG*/

  FROM
    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` C
  ON
    TRIM(UPPER(C.MARCA_DS)) = TRIM(UPPER(S.MARCA_DS))
    AND TRIM(UPPER(C.CATEGORIA_SERVICIO_DS)) = TRIM(UPPER(S.CATEGORIA_SERVICIO_DS))
    AND TRIM(UPPER(C.tipo_identificacion_ds)) = 'BLOQUE'
    AND
    CASE
      WHEN TRIM(UPPER(campo_filtrado)) = 'VELOCIDAD_MB' THEN S.VELOCIDAD_MB BETWEEN C.VALOR_MINIMO AND C.VALOR_MAXIMO
      WHEN TRIM(UPPER(campo_filtrado)) = 'GB' THEN S.GB BETWEEN C.VALOR_MINIMO
    AND C.VALOR_MAXIMO
  END
    AND adicional_lg = 0
    AND TRIM(UPPER(c.tecnologia_detalle_ds)) = TRIM(UPPER(s.tecnologia_detalle_ds))
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cl
  ON
    s.marca_ds = cl.marca_ds
    AND s.cliente_id = cl.cliente_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` rfb
  ON
    rfb.cliente_id = s.cliente_id
    AND rfb.marca_ds = s.marca_ds
    AND rfb.desde_id <= s.fecha_rfb_id
    AND rfb.hasta_id > s.fecha_rfb_id
  LEFT JOIN smovprep
  ON
    s.servicio_id_origen = smovprep.servicio_id
  WHERE
    s.marca_ds <> 'R'
    AND ( 
          ( s.fecha_rfb_id BETWEEN DESDE AND HASTA 
            AND ABS(DATE_DIFF(CAST(S.fecha_rfs_dt AS DATE), CAST(S.fecha_rfb_dt AS DATE), MONTH))<=2
          )
          OR 
          (s.FECHA_VENTA_NETA_ID BETWEEN DESDE AND HASTA) 
        ) /*AND s.fecha_rfb_id BETWEEN DESDE AND HASTA*/
    AND UPPER(s.agente_creador_id) <> 'MIGRAMASHFC_FTTH'
    AND ( (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO',
          'PYME')
        AND s.marca_ds NOT IN ('TELECABLE',
          'R'))
      OR (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO')
        AND s.marca_ds IN ('TELECABLE',
          'R')) )
    AND S.fecha_cancelacion_id > HASTA
    --AND (S.fecha_baja_id > HASTA /*OR S.SERVICIO_ID_DESTINO > 0 */ )
;    
--);

  --- Altas sin migración en periodo 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB_ALTA_NO_MIG` AS
  select distinct s.* 
  except(
    servicio_id_original,
    servicio_id_origen,
    servicio_id_destino,
    fecha_rfs_dt,
    fecha_baja_dt,
    fecha_baja_id,
    operacion_alta_ds,
    operacion_baja_ds,  
    estado_hoy_ds,
    estado_crm_ds,
    tipo,
    ndays_inst_venta,
    nmonths_inst_venta,    
    ndays_act_inst,
    nmonths_act_inst,    
    ind_rfb_month   
  ),
  CAST(3  AS INT64) as grid
  from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB` as s
  where tipo="ALTA"
  and coalesce(s.servicio_id_origen,-666 ) <0
  and coalesce(s.servicio_id_destino,-666 ) <0
  and fecha_baja_id > HASTA; 


  --- Altas con migración en periodo  ... En desarrollo 
  --- Mantiene de destino los atributos que caracterizan el servicio
  ---   servicio_id
  ---   detalle_servicio_ds
  ---   concepto_ds
  ---   tecnologia_detalle
  ---   gb  
  ---   catalogo 
  --- Mantiene de origen los atributos de la venta (canalizacion), del cliente (marca cartera) y del pedido
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB_ALTA_SI_MIG` AS
  SELECT
    DISTINCT s.marca_ds,
    s.Cliente_id,
    s.servicio_id,
    s.detalle_servicio_ds,
    s.CONCEPTO_DS,
    cand.FECHA_RFB_ID,
    cand.FECHA_VENTA_NETA_ID,
    cand.fecha_rfb_dt,
    cand.fecha_venta_neta_dt,
    cand.canal_alta_ds,
    cand.subcanal_ds,
    cand.tipo_canal_alta_ds,
    cand.nombre_distribuidor_alta_ds,
    cand.agente_alta_id,
    cand.agente_creador_id,
    cand.categoria_servicio_ds,
    cand.cif_nif,
    cand.segmento_ds,
    cand.subsegmento_ds,
    cand.marca_cartera_ds,
    cand.Antiguedad_Cliente,
    cand.equipo_ds,
    s.territorio_ds,
    s.tecnologia_detalle_ds,
    cand.portabilidad_in_lg,
    s.gb,
    cand.expediente_id,
    cand.expediente_padre_id,
    cand.contrato_id,
    cand.tipo_pedido_ds,
    cand.pedido_id,
    cand.tipo_producto_pedido_re_ds,
    cand.visibilidad_pedido_lg,
    s.catalogo_id,
    CAST(-103  AS INT64) as grid,
    
     /*DEBUG
    cand.tipo as tipo_or,
    cand.fecha_venta_neta_dt as fecha_venta_neta_dt_or,   
    cand.fecha_rfb_dt as fecha_rfb_dt_or,
    cand.fecha_baja_dt as fecha_baja_dt_or, 
    cand.servicio_id_origen as servicio_id_origen_or,   
    cand.servicio_id_original as servicio_id_original_or,

    s.tipo as tipo_dest,
    s.fecha_venta_neta_dt as fecha_venta_neta_dt_dest,        
    s.fecha_rfb_dt as fecha_rfb_dt_dest,    
    s.fecha_baja_dt as fecha_baja_dt_dest,
    s.servicio_id_origen as servicio_id_origen_dest ,   
    s.servicio_id_original as servicio_id_original_dest,    
     FIN DEBUG*/
    
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB` AS s
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB` AS cand
     on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds     
     and s.servicio_id=cand.servicio_id_destino 
     and date_trunc(s.fecha_rfb_dt,MONTH)=date_trunc(cand.fecha_rfb_dt,MONTH)
  WHERE
    --s.tipo="ALTA"
    coalesce(s.servicio_id_origen,-666 ) >0
    and coalesce(s.servicio_id_destino,-666 ) <0
    and coalesce(cand.servicio_id_origen,-666 ) <0
    and coalesce(cand.servicio_id_destino,-666 ) >0    
    and s.fecha_baja_id > HASTA; 
    

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_INCR_NEW` AS
  with s as (
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB_ALTA_NO_MIG` where servicio_id is not null
    UNION ALL 
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_POB_ALTA_SI_MIG` where servicio_id is not null
  ) select *
  from s
  WHERE NOT EXISTS (
    SELECT
    1
    FROM
    `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` T
    WHERE
    T.SERVICIO_ID = S.SERVICIO_ID
    AND T.MARCA_DS = S.MARCA_DS 
  );    
    

    -- PASO 2: INSERTO EN TABLA VENTAS_CAPTACION -- Log de fichero completo

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  SELECT
    *
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION_INCR_NEW` ;
    
    

    -- PASO 3: CREO FICHERO CON LOG DE SALIDA -- Log de fichero completo
    
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0103_VENTAS_CAPTACION` AS
  SELECT
    *
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;
    

END