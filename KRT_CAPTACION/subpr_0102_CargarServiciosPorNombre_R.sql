BEGIN

  -- TABLA SALIDA
  --    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`  

  -- PASO 1: INSERTO REGISTROS EN SERVICIOS CAPTACION

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`

  -- TABLA ENTRADA
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`   
  --  `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS`
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` 
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` 
  --  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` 
  --  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` 
  --  `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` 

  SELECT
    DISTINCT S.marca_ds,
    s.Cliente_id,
    CAST(servicio_id AS int64) servicio_id,
    S.detalle_servicio_ds,
    C.CONCEPTO_DS,
    S.FECHA_RFB_ID,
    S.FECHA_VENTA_NETA_ID,
    s.fecha_rfb_dt,
    s.fecha_venta_neta_dt,
    ifnull(cn.canal_agrupado1_ds,
      ifnull(cnPadre.canal_agrupado1_ds,
        S.canal_alta_ds)),
    ifnull(cn.subcanal_ds,
      ifnull(cnPadre.subcanal_ds,
        S.subcanal_ds)),
    ifnull(cn.canal_agrupado2_ds,
      ifnull(cnPadre.canal_agrupado2_ds,
        S.tipo_canal_alta_ds)),
    ifnull(cn.distribuidor_ds,
      ifnull(cnPadre.distribuidor_ds,
        S.nombre_distribuidor_alta_ds)),
    ifnull(emp.attrib_07,
      ifnull(empPadre.attrib_07,
        s.agente_alta_id)),
    ifnull(emp.attrib_07,
      ifnull(empPadre.attrib_07,
        s.agente_creador_id)),
    s.categoria_servicio_ds,
    cl.cif_nif,
    s.segmento_ds,
    cl.subsegmento_ds,
    CASE
      WHEN s.marca_ds NOT IN ('R') THEN S.marca_cartera_ds
    ELSE
    CASE
      WHEN ABS(DATE_DIFF(CAST(s.fecha_rfb_dt AS DATE), CAST(rfb.fecha_alta_dt AS DATE), DAY))> 15 THEN 'CARTERA'
    ELSE
    'CAPTACION'
  END
  END
    marca_cartera_ds,
    rfb.fecha_alta_dt Antiguedad_Cliente,
    s.equipo_ds,
    s.territorio_ds,
    s.tecnologia_detalle_ds,
    s.portabilidad_in_lg,
    CASE
      WHEN s.categoria_servicio_ds = 'BANDA ANCHA' THEN s.velocidad_mb
    ELSE
    s.gb
  END
    gb,
    s.expediente_id
  FROM
    `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS` C
  ON
    S.DETALLE_SERVICIO_DS = C.DETALLE_SERVICIO_DS
    AND C.MARCA_DS = S.MARCA_DS
    AND C.CATEGORIA_SERVICIO_DS = S.CATEGORIA_SERVICIO_DS
    AND C.tipo_identificacion_ds = 'DETALLE_SERVICIO'
    AND adicional_lg = 0
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
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
  ON
    s.expediente_id = exp.row_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` expPadre
  ON
    exp.PAR_SR_ID = expPadre.row_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
  ON
    exp.owner_emp_id=emp.row_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` empPadre
  ON
    expPadre.owner_emp_id=empPadre.row_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` cn
  ON
    CAST(cn.codigo_comercial AS string) = emp.attrib_07
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` cnPadre
  ON
    CAST(cnPadre.codigo_comercial AS string) = empPadre.attrib_07
  WHERE
    fecha_rfb_id BETWEEN DESDE
    AND HASTA
    AND UPPER(agente_creador_id) <> 'MIGRAMASHFC_FTTH'
    AND s.marca_ds = 'R'
    AND (servicio_id_origen < 0
      OR (agente_creador_id = 'MIGRACIONTMK'
        AND EXISTS (
        SELECT
          *
        FROM
          `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s2
        WHERE
          s2.marca_ds = 'TELECABLE'
          AND s2.sistema_ds = 'SGI'
          AND s2.servicio_id = s.servicio_id_origen
          AND s2.fecha_rfb_id BETWEEN DESDE
          AND HASTA))
      OR EXISTS (
      SELECT
        1
      FROM
        `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s2
      WHERE
        s2.cliente_id = s.cliente_id
        AND s2.marca_ds = s.marca_ds
        AND s2.servicio_id = s.servicio_id_original
        AND s2.fecha_rfb_id BETWEEN DESDE
        AND HASTA ) )
    AND ((s.segmento_ds IN ('RESIDENCIAL',
          'SOHO',
          'PYME')
        AND s.marca_ds NOT IN ('TELECABLE',
          'R'))
      OR (s.segmento_ds IN ('RESIDENCIAL',
          'SOHO')
        AND s.marca_ds IN ('TELECABLE',
          'R')))
    AND fecha_cancelacion_id > HASTA
    AND (fecha_baja_id > HASTA
      OR SERVICIO_ID_DESTINO > 0)
    AND ABS(DATE_DIFF(CAST(fecha_rfs_dt AS DATE), CAST(fecha_rfb_dt AS DATE), MONTH))<=2;


-- PASO 2: INSERTO REGISTROS EN FICHERO DE LOG

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0102_SERVICIOS_CAPTACION` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`; 

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0102_SERVICIOS_CAPTACION_INCR` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION`;


END