BEGIN

  DECLARE
    DESDE_DT,
    HASTA_DT date;
  SET
    DESDE_DT = parse_date ('%Y%m%d',
      CAST ( DESDE AS string) );
  SET
    HASTA_DT = parse_date ('%Y%m%d',
      CAST ( HASTA AS string) );

-- PASO 1: INSERTO REGISTROS 

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
  SELECT
    DISTINCT --a.row_id,
    'R',
    CAST(cli.ou_num AS INT64) cliente_id,
    tmp.servicio_id,
    'Descuento plataforma cancelación' NombreProducto,
    'Descuento plataforma cancelación' concepto_ds,
    (EXTRACT(YEAR FROM TODO_ACTL_END_DT)*10000 + EXTRACT(MONTH FROM TODO_ACTL_END_DT) * 100 + EXTRACT(DAY FROM TODO_ACTL_END_DT)) FECHA_RFB_ID,
    (EXTRACT(YEAR FROM TODO_ACTL_START_DT)*10000 + EXTRACT(MONTH FROM TODO_ACTL_START_DT) * 100 + EXTRACT(DAY FROM TODO_ACTL_START_DT)) FECHA_VENTA_NETA_ID,
    CAST(TODO_ACTL_START_DT as TIMESTAMP) fecha_RFB_DT,
    CAST(TODO_ACTL_END_DT as TIMESTAMP) FECHA_VENTA_NETA_DT,
    tmp.canal_alta_ds,
    tmp.subcanal_ds,
    tmp.tipo_canal_alta_ds,
    tmp.nombre_distribuidor_alta_ds,
    tmp.agente_alta_id,
    tmp.agente_creador_id,
    tmp.categoria_servicio_ds,
    tmp.cif_nif,
    UPPER(tmp.segmento_ds),
    UPPER(tmp.subsegmento_ds),
    tmp.marca_cartera_ds,
    tmp.Antiguedad_Cliente,
    tmp.equipo_ds,
    tmp.territorio_ds,
    tmp.tecnologia_detalle_ds,
    0,
    0,
    ''
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_evt_act` a --
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_evt_act_x` ax
  ON
    a.row_id = ax.row_id
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_USUARIOS` u
  ON
    a.OWNER_LOGIN = u.usuario_ds
    AND u.marca_ds = 'R'
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
  ON
    exp.row_id = a.SRA_SR_ID
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli
  ON
    cli.row_id=exp.CST_OU_ID
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
  ON
    tmp.cliente_id = CAST(cli.ou_num AS int64)
    AND tmp.categoria_servicio_ds = 'BANDA ANCHA'
    AND tmp.tipo_canal_alta_ds = 'NO PRESENCIAL'
  WHERE
    EVT_STAT_CD = 'CERRADO'
    AND TODO_CD = 'PETICION ANULACION'
    AND a.X_R_GRUPO_ASIGNADO = 'PLAT_CANCELACION_R'
    AND a.X_R_RESULTADO = 'RECUPERADO'
    AND TODO_ACTL_END_DT BETWEEN DESDE_DT
    AND HASTA_DT;

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0163_SERVICIOS_CAPTACION_INCR` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM  
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0162_SERVICIOS_CAPTACION`;

END