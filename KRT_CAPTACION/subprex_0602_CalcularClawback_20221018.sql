BEGIN

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` AS


  -- Tablas entrada
  --  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
  --  `dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_COMISIONAMIENTO_CAPTACION`
  --  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` 
  --  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
  --  D80_ARQ



  --  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`


  WITH
    b AS (
    SELECT
      b.servicio_id,
      b.servicio_id_original,
      marca_ds,
      fecha_baja_dt,
      fecha_baja_id,
      motivo_baja_agrup_ds,
      motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` b
    WHERE
      b.fecha_baja_id BETWEEN DESDE_BAJA
      AND HASTA_BAJA
      AND operacion_baja_ds IN ('BAJA',
        'BAJA DOWNGRADE'))
  SELECT
    DISTINCT a.marca_ds,
    a.Cliente_id,
    a.servicio_id,
    a.detalle_servicio_ds,
    a.CONCEPTO_DS,
    a.FECHA_RFB_ID,
    a.FECHA_VENTA_NETA_ID,
    a.fecha_rfb_dt,
    a.fecha_venta_neta_dt,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.tipo_canal_alta_ds,
    a.nombre_distribuidor_alta_ds,
    a.agente_alta_id,
    a.agente_creador_id,
    a.categoria_servicio_ds,
    a.cif_nif,
    a.segmento_ds,
    a.subsegmento_ds,
    a.marca_cartera_ds,
    a.Antiguedad_Cliente,
    a.equipo_ds,
    a.territorio_ds,
    a.clave,
    a.marco_retributivo_ds,
    a.flag_marca_cartera,
    a.grupo_rappel_ds,
    a.orden_sap,
    a.importe *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe,
    a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM
    b
  INNER JOIN
   `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON
    a.servicio_id = b.servicio_id
    AND a.marca_ds = b.marca_ds
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c
  ON
    a.marca_ds = c.marca_ds
    AND a.nombre_distribuidor_alta_ds = c.nombre_distribuidor_ds
    AND a.canal_alta_ds = c.canal_ds
    AND
    CASE
      WHEN UPPER(c.subcanal_ds) <> 'X' THEN a.subcanal_ds = c.subcanal_ds
    ELSE
    1=1
  END
    AND
    CASE
      WHEN UPPER(c.equipo_ds) <> 'X' THEN a.equipo_ds = c.equipo_ds
    ELSE
    1 = 1
  END
  WHERE
    DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0
    AND 180
    AND a.decomisionable = 'S';
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  WITH
    b AS (
    SELECT
      b.servicio_id,
      b.servicio_id_original,
      marca_ds,
      b.fecha_baja_dt,
      b.fecha_baja_id,
      motivo_baja_agrup_ds,
      motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` b
    WHERE
      b.fecha_baja_id BETWEEN DESDE_BAJA
      AND HASTA_BAJA
      AND operacion_baja_ds IN ('BAJA',
        'BAJA DOWNGRADE'))
  SELECT
    DISTINCT a.marca_ds,
    a.Cliente_id,
    a.servicio_id,
    a.detalle_servicio_ds,
    a.CONCEPTO_DS,
    a.FECHA_RFB_ID,
    a.FECHA_VENTA_NETA_ID,
    a.fecha_rfb_dt,
    a.fecha_venta_neta_dt,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.tipo_canal_alta_ds,
    a.nombre_distribuidor_alta_ds,
    a.agente_alta_id,
    a.agente_creador_id,
    a.categoria_servicio_ds,
    a.cif_nif,
    a.segmento_ds,
    a.subsegmento_ds,
    a.marca_cartera_ds,
    a.Antiguedad_Cliente,
    a.equipo_ds,
    a.territorio_ds,
    a.clave,
    a.marco_retributivo_ds,
    a.flag_marca_cartera,
    a.grupo_rappel_ds,
    a.orden_sap,
    a.importe *
    CASE
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0 AND 60 THEN 1
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 60
    AND 120 THEN 0.75
      WHEN DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 120 AND 180 THEN 0.5
  END
    importe,
    a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM
    b
  INNER JOIN
   `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON
    a.servicio_id = b.servicio_id_original
    AND a.marca_ds = b.marca_ds
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
  ON
    a.marca_ds = ca.marca_ds
    AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds
    AND a.canal_alta_ds = ca.canal_ds
    AND
    CASE
      WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds
    ELSE
    1=1
  END
    AND
    CASE
      WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds
    ELSE
    1 = 1
  END
  LEFT JOIN (
    SELECT
      marca_ds,
      servicio_id,
      cliente_id
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`) c
  ON
    a.servicio_id = c.servicio_id
    AND a.marca_Ds = c.marca_Ds
  WHERE
    DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0
    AND 180
    AND a.decomisionable = 'S'
    AND c.cliente_id IS NULL;
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT
    DISTINCT a.marca_ds,
    a.Cliente_id,
    a.servicio_id,
    a.detalle_servicio_ds,
    a.CONCEPTO_DS,
    a.FECHA_RFB_ID,
    a.FECHA_VENTA_NETA_ID,
    a.fecha_rfb_dt,
    a.fecha_venta_neta_dt,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.tipo_canal_alta_ds,
    a.nombre_distribuidor_alta_ds,
    a.agente_alta_id,
    a.agente_creador_id,
    a.categoria_servicio_ds,
    a.cif_nif,
    a.segmento_ds,
    a.subsegmento_ds,
    a.marca_cartera_ds,
    a.Antiguedad_Cliente,
    a.equipo_ds,
    a.territorio_ds,
    a.clave,
    a.marco_retributivo_ds,
    a.flag_marca_cartera,
    a.grupo_rappel_ds,
    a.orden_sap,
    a.importe * 0.75,
    a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM (
    SELECT
      b.swInstProdId,
      ifnull(b.swMasterInstProdId,
        0) swMasterInstProdId,
      swFechaDesinstalacion fecha_baja_dt,
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id,
      b.swNombreCausaGral motivo_baja_agrup_ds,
      b.swCausaBaja motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` b
    WHERE
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA
      AND HASTA_BAJA
      AND b.swCopiaProdId IS NULL ) b
  INNER JOIN
   `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON
    a.servicio_id = b.swInstProdId
    AND a.marca_ds IN ('EUSKALTEL',
      'RACC',
      'VIRGIN')
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
  ON
    a.marca_ds = ca.marca_ds
    AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds
    AND a.canal_alta_ds = ca.canal_ds
    AND
    CASE
      WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds
    ELSE
    1=1
  END
    AND
    CASE
      WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds
    ELSE
    1 = 1
  END
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  ON
    a.servicio_id = c.servicio_id
    AND a.marca_ds = c.marca_ds
  WHERE
    DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0
    AND 180
    AND c.cliente_id IS NULL
    AND a.decomisionable = 'S';
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT
    DISTINCT a.marca_ds,
    a.Cliente_id,
    a.servicio_id,
    a.detalle_servicio_ds,
    a.CONCEPTO_DS,
    a.FECHA_RFB_ID,
    a.FECHA_VENTA_NETA_ID,
    a.fecha_rfb_dt,
    a.fecha_venta_neta_dt,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.tipo_canal_alta_ds,
    a.nombre_distribuidor_alta_ds,
    a.agente_alta_id,
    a.agente_creador_id,
    a.categoria_servicio_ds,
    a.cif_nif,
    a.segmento_ds,
    a.subsegmento_ds,
    a.marca_cartera_ds,
    a.Antiguedad_Cliente,
    a.equipo_ds,
    a.territorio_ds,
    a.clave,
    a.marco_retributivo_ds,
    a.flag_marca_cartera,
    a.grupo_rappel_ds,
    a.orden_sap,
    a.importe * 0.75,
    a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM (
    SELECT
      b.swInstProdId,
      ifnull(b.swMasterInstProdId,
        0) swMasterInstProdId,
      swFechaDesinstalacion fecha_baja_dt,
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id,
      b.swNombreCausaGral motivo_baja_agrup_ds,
      b.swCausaBaja motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` b
    WHERE
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA
      AND HASTA_BAJA
      AND b.swCopiaProdId IS NULL ) b
  INNER JOIN
   `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON
    a.servicio_id = b.swMasterInstProdId
    AND a.marca_ds IN ('EUSKALTEL',
      'RACC',
      'VIRGIN')
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
  ON
    a.marca_ds = ca.marca_ds
    AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds
    AND a.canal_alta_ds = ca.canal_ds
    AND
    CASE
      WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds
    ELSE
    1=1
  END
    AND
    CASE
      WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds
    ELSE
    1 = 1
  END
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  ON
    a.servicio_id = c.servicio_id
    AND a.marca_ds = c.marca_ds
  WHERE
    DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0
    AND 180
    AND c.cliente_id IS NULL
    AND a.decomisionable = 'S';
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT
    DISTINCT a.marca_ds,
    a.Cliente_id,
    a.servicio_id,
    a.detalle_servicio_ds,
    a.CONCEPTO_DS,
    a.FECHA_RFB_ID,
    a.FECHA_VENTA_NETA_ID,
    a.fecha_rfb_dt,
    a.fecha_venta_neta_dt,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.tipo_canal_alta_ds,
    a.nombre_distribuidor_alta_ds,
    a.agente_alta_id,
    a.agente_creador_id,
    a.categoria_servicio_ds,
    a.cif_nif,
    a.segmento_ds,
    a.subsegmento_ds,
    a.marca_cartera_ds,
    a.Antiguedad_Cliente,
    a.equipo_ds,
    a.territorio_ds,
    a.clave,
    a.marco_retributivo_ds,
    a.flag_marca_cartera,
    a.grupo_rappel_ds,
    a.orden_sap,
    a.importe * 0.75,
    a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM (
    SELECT
      b.swInstProdId,
      ifnull(b.swMasterInstProdId,
        0) swMasterInstProdId,
      swFechaDesinstalacion fecha_baja_dt,
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id,
      b.swNombreCausaGral motivo_baja_agrup_ds,
      b.swCausaBaja motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` b
    WHERE
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA
      AND HASTA_BAJA
      AND b.swCopiaProdId IS NULL
      AND swCausaBaja<> 'Modificación' ) b
  INNER JOIN
   `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON
    a.servicio_id = b.swInstProdId
    AND a.marca_ds IN ('TELECABLE')
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
  ON
    a.marca_ds = ca.marca_ds
    AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds
    AND a.canal_alta_ds = ca.canal_ds
    AND
    CASE
      WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds
    ELSE
    1=1
  END
    AND
    CASE
      WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds
    ELSE
    1 = 1
  END
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  ON
    a.servicio_id = c.servicio_id
    AND a.marca_ds = c.marca_ds
  WHERE
    DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0
    AND 180
    AND c.cliente_id IS NULL
    AND a.decomisionable = 'S';
  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT
    DISTINCT a.marca_ds,
    a.Cliente_id,
    a.servicio_id,
    a.detalle_servicio_ds,
    a.CONCEPTO_DS,
    a.FECHA_RFB_ID,
    a.FECHA_VENTA_NETA_ID,
    a.fecha_rfb_dt,
    a.fecha_venta_neta_dt,
    a.canal_alta_ds,
    a.subcanal_ds,
    a.tipo_canal_alta_ds,
    a.nombre_distribuidor_alta_ds,
    a.agente_alta_id,
    a.agente_creador_id,
    a.categoria_servicio_ds,
    a.cif_nif,
    a.segmento_ds,
    a.subsegmento_ds,
    a.marca_cartera_ds,
    a.Antiguedad_Cliente,
    a.equipo_ds,
    a.territorio_ds,
    a.clave,
    a.marco_retributivo_ds,
    a.flag_marca_cartera,
    a.grupo_rappel_ds,
    a.orden_sap,
    a.importe * 0.75,
    a.decomisionable,
    b.fecha_baja_dt,
    b.fecha_baja_id,
    b.motivo_baja_agrup_ds,
    b.motivo_baja_ds
  FROM (
    SELECT
      b.swInstProdId,
      ifnull(b.swMasterInstProdId,
        0) swMasterInstProdId,
      swFechaDesinstalacion fecha_baja_dt,
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id,
      b.swNombreCausaGral motivo_baja_agrup_ds,
      b.swCausaBaja motivo_baja_ds
    FROM
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` b
    WHERE
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA
      AND HASTA_BAJA
      AND b.swCopiaProdId IS NULL ) b
  INNER JOIN
   `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON
    a.servicio_id = b.swMasterInstProdId
    AND a.marca_ds IN ('TELECABLE')
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
  ON
    a.marca_ds = ca.marca_ds
    AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds
    AND a.canal_alta_ds = ca.canal_ds
    AND
    CASE
      WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds
    ELSE
    1=1
  END
    AND
    CASE
      WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds
    ELSE
    1 = 1
  END
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  ON
    a.servicio_id = c.servicio_id
    AND a.marca_ds = c.marca_ds
  WHERE
    DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0
    AND 180
    AND c.cliente_id IS NULL
    AND a.decomisionable = 'S';

END