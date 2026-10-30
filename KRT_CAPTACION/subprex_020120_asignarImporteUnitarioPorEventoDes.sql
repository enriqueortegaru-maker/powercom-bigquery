BEGIN

  --DECLARE DESDE, HASTA INT64; SET DESDE=20240301;SET HASTA=20240331;

    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_020110_MARCO_RETRIBUTIVOxCANAL` ;    



  -- PASO 1: CREO UNITARIOS CON IMPORTE CALCULADO SOBRE TRAMOS 2.

  --DECLARE DESDE, HASTA INT64; SET DESDE=20240301;SET HASTA=20240331;    
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL_TRAMO_2` AS
  with marcoConTramos as (
        SELECT marca_ds, marco_retributivo_ds, fecha_venta_umbral  
        from `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_TRAMOS_MARCO` 
        where fecha_venta_umbral between DESDE and HASTA
  )
  SELECT a.*, c.marco_retributivo_ds, c.flag_marca_cartera, c.grupo_rappel_ds, CASE WHEN a.segmento_ds = 'RESIDENCIAL' THEN c.orden_sap_residencial ELSE c.orden_sap_soho END orden_sap, 
  --- Pendiente case en base a fecha_venta_neta
  --coalesce(mr.importe_t2,mr.importe)/(CASE WHEN a.concepto_ds = 'Descuento plataforma cancelación' THEN COUNT(servicio_id) OVER (PARTITION BY cliente_id, a.concepto_ds) ELSE 1 END) importe
  mr.importe_t2/(CASE WHEN a.concepto_ds = 'Descuento plataforma cancelación' THEN COUNT(servicio_id) OVER (PARTITION BY cliente_id, a.concepto_ds) ELSE 1 END) importe
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_020110_MARCO_RETRIBUTIVOxCANAL`   a
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c  ON c.clave = a.clave
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` MR  ON TRIM(c.marco_retributivo_ds) = TRIM(mr.marco_retributivo_ds) AND TRIM(a.concepto_ds) = TRIM(mr.concepto_ds) AND TRIM(mr.marca_ds) = TRIM(c.marca_ds) and mr.importe_t2!=0  
  INNER JOIN marcoConTramos m on TRIM(m.marca_ds)=TRIM(a.marca_ds) and TRIM(c.marco_retributivo_ds)=TRIM(m.marco_retributivo_ds) and m.fecha_venta_umbral < a.FECHA_VENTA_NETA_ID; 
  

  -- PASO 2: CREO UNITARIOS CON IMPORTE CALCULADO SOBRE TRAMOS 1.

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL_TRAMO_1` AS
  --DECLARE DESDE, HASTA INT64; SET DESDE=20240301;SET HASTA=20240331; 
  SELECT a.*, c.marco_retributivo_ds, c.flag_marca_cartera, c.grupo_rappel_ds, CASE WHEN a.segmento_ds = 'RESIDENCIAL' THEN c.orden_sap_residencial ELSE c.orden_sap_soho END orden_sap, 
  mr.importe /(CASE WHEN a.concepto_ds = 'Descuento plataforma cancelación' THEN COUNT(servicio_id) OVER (PARTITION BY cliente_id, a.concepto_ds) ELSE 1 END) importe
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_020110_MARCO_RETRIBUTIVOxCANAL`   a
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c  ON c.clave = a.clave
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` MR  ON TRIM(c.marco_retributivo_ds) = TRIM(mr.marco_retributivo_ds) AND TRIM(a.concepto_ds) = TRIM(mr.concepto_ds) AND TRIM(mr.marca_ds) = TRIM(c.marca_ds)
  WHERE NOT EXISTS(
    select 1 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL_TRAMO_2` m
    where TRIM(m.marca_ds)=TRIM(a.marca_ds)  and a.cliente_id=m.cliente_id and TRIM(a.categoria_servicio_ds)=TRIM(m.categoria_Servicio_ds) and TRIM(a.detalle_servicio_ds)=TRIM(m.detalle_Servicio_ds) and a.servicio_id=m.servicio_id and TRIM(a.concepto_ds)=TRIM(m.concepto_ds)
  );


  --- PASO 3: INTEGRO UNITARIOS TRAMOS

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL` AS
  (SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL_TRAMO_1`)  
  UNION ALL    
  (SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL_TRAMO_2`);


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL_NO_CRUZADOS` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_020110_MARCO_RETRIBUTIVOxCANAL` a 
  WHERE NOT EXISTS(
    SELECT 1 
    from  `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL` m 
    where TRIM(m.marca_ds)=TRIM(a.marca_ds)  and a.cliente_id=m.cliente_id 
    and TRIM(a.categoria_servicio_ds)=TRIM(m.categoria_Servicio_ds) and TRIM(a.detalle_servicio_ds)=TRIM(m.detalle_Servicio_ds) 
    and a.servicio_id=m.servicio_id and a.concepto_ds=m.concepto_ds

  );

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` AS
  --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_020120_MARCO_RETRIBUTIVOxCANAL`;

end