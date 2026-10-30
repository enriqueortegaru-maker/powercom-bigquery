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



  --- PASO 1: Inserto registros en tabla SERVICIOS_CAPTACION

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`

  SELECT
    DISTINCT catalogo.marca_ds,
    CAST(p.swCustomerId AS INT64) cliente_id,
    p.swInstProdId,
    cat.swReleaseName NombreProducto,
    catalogo.concepto_ds,
    (EXTRACT(YEAR
      FROM
        p.swDateInstalled)*10000 + EXTRACT(MONTH
      FROM
        p.swDateInstalled) * 100 + EXTRACT(DAY
      FROM
        p.swDateInstalled)) FECHA_RFB_ID,
    (EXTRACT(YEAR
      FROM
        p.swDateCreated)*10000 + EXTRACT(MONTH
      FROM
        p.swDateCreated) * 100 + EXTRACT(DAY
      FROM
        p.swDateCreated)) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT,
    p.swDateCreated FECHA_VENTA_NETA_DT,
    tmp.canal_alta_ds canal_alta_ds,
    tmp.subcanal_ds subcanal_ds,
    tmp.tipo_canal_alta_ds tipo_canal_alta_ds,
    tmp.nombre_distribuidor_alta_ds nombre_distribuidor_alta_ds,
    pe.swNombre agente_alta_id,
    p.swCreatedBy agente_creador_id,
    catalogo.categoria_servicio_ds,
    c.swNIE cif_nif,
    UPPER(c.swSegmento) segmento_ds,
    UPPER(c.swSubsegmento) subsegmento_ds,
    p.swMarcaCartera marca_cartera_ds,
    c.swAntiguedad Antiguedad_Cliente,
    tmp.equipo_ds,
    tmp.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0 portabilidad_in_lg,
    0 gb,
    '' expediente_id
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
  ON
    CAST(p.swProdReleaseId AS string) = catalogo.catalogo_id
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'TCNET'
    AND adicional_lg = 1
  INNER JOIN
  --  `mm-commissions-reporting.KRT_CAPTACION.servicios_crm_catalogo` tmp
      `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp  
  ON
    tmp.cliente_id = p.swCustomerId
    AND tmp.categoria_servicio_ds = catalogo.categoria_servicio_ds
    AND tmp.marca_ds = catalogo.marca_ds
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_prod_cat` cat
  ON
    p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c
  ON
    p.swCustomerId = c.swCustomerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe
  ON
    p.swPedId = pe.swPersonalId
  WHERE
    DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
    AND HASTA_DT
    AND (p.swProdOrigId IS NULL
      OR EXISTS (
      SELECT
        1
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p2
      WHERE
        p2.swInstProdId = p.swMasterInstProdId
        AND DATE_TRUNC(CAST (p2.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
        AND HASTA_DT))
    AND (p.swFechaDesinstalacion IS NULL
      OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
    AND c.swSegmento IN ('SOHO',
      'Residencial',
      'PYME')
    AND p.swCreatedBy NOT IN ('AltaMasiva',
      'MIGRAMASHFC_FTTH')
  UNION ALL
  SELECT
    DISTINCT catalogo.marca_ds,
    CAST(p.swCustomerId AS INT64) cliente_id,
    p.swInstProdId,
    cat.swReleaseName NombreProducto,
    catalogo.concepto_ds,
    (EXTRACT(YEAR
      FROM
        p.swDateInstalled)*10000 + EXTRACT(MONTH
      FROM
        p.swDateInstalled) * 100 + EXTRACT(DAY
      FROM
        p.swDateInstalled)) FECHA_RFB_ID,
    (EXTRACT(YEAR
      FROM
        p.swDateCreated)*10000 + EXTRACT(MONTH
      FROM
        p.swDateCreated) * 100 + EXTRACT(DAY
      FROM
        p.swDateCreated)) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT,
    p.swDateCreated FECHA_VENTA_NETA_DT,
    c1.canal_agrupado1_ds,
    sc.subcanal_ds,
    c2.canal_agrupado2_ds,
    `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(ca.swName),
    `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(pe.swNombre),
    p.swCreatedBy,
    catalogo.categoria_servicio_ds,
    c.swNIE cif_nif,
    UPPER(c.swSegmento),
    UPPER(c.swSegmento),
    p.swMarcaCartera,
    tmp.Antiguedad_Cliente,
    REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(ca.swVerticalFocus), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'),
    tmp.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0,
    0,
    ''
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
  ON
    CAST(p.swProdReleaseId AS string) = catalogo.catalogo_id
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'EKTNET'
    AND adicional_lg = 1
  INNER JOIN
--    `mm-commissions-reporting.KRT_CAPTACION.servicios_crm_catalogo` tmp
      `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
  ON
    tmp.cliente_id = p.swCustomerId
    AND tmp.categoria_servicio_ds = catalogo.categoria_servicio_ds
    AND tmp.marca_ds = catalogo.marca_ds
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
  ON
    p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c
  ON
    p.swCustomerId = c.swCustomerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
  ON
    ca.swChnlPartnerId = p.swChnlPartnerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
  ON
    pe.swPersonalId=p.swProviderGrpId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` trc
  ON
    trc.canal_id = p.swChnlPartnerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1
  ON
    trc.canal_agrupado1_id = c1.canal_agrupado1_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2
  ON
    trc.canal_agrupado2_id = c2.canal_agrupado2_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
  ON
    trc.subcanal_id = sc.subcanal_id
  WHERE
    DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
    AND HASTA_DT
    AND (p.swProdOrigId IS NULL
      OR EXISTS (
      SELECT
        1
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p2
      WHERE
        p2.swInstProdId = p.swMasterInstProdId
        AND DATE_TRUNC(CAST (p2.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
        AND HASTA_DT))
    AND (p.swFechaDesinstalacion IS NULL
      OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
    AND p.swCreatedBy NOT IN ('AltaMasiva',
      'MIGRAMASHFC_FTTH')
  UNION ALL
  SELECT
    pr.codigo_empresa_bi marca_ds,
    CAST(p.idcliente AS int64) cliente_id,
    CAST(pr.IDINTERNO AS int64),
    pr.descripcion,
    catalogo.concepto_ds,
    (EXTRACT(YEAR
      FROM
        p.LAST_UPD)*10000 + EXTRACT(MONTH
      FROM
        p.LAST_UPD) * 100 + EXTRACT(DAY
      FROM
        p.LAST_UPD)) FECHA_RFB_ID,
    (EXTRACT(YEAR
      FROM
        p.CREATED)*10000 + EXTRACT(MONTH
      FROM
        p.CREATED) * 100 + EXTRACT(DAY
      FROM
        p.CREATED)) FECHA_VENTA_NETA_ID,
    CAST(p.last_upd AS timestamp) fecha_rfb_dt,
    CAST(p.created AS timestamp) fecha_venta_id,
    c.canal_agrupado1_ds,
    c.subcanal_ds,
    c.canal_agrupado2_ds,
    c.distribuidor_ds,
    emp.attrib_07 agente,
    emp.attrib_07 agente,
    catalogo.categoria_servicio_ds,
    ci.cif_nif,
    ci.segmento_ds,
    ci.subsegmento_ds,
    CASE
      WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
      WHEN (CAST(cli_x.fecha_ultimo_cambio AS date)>p.created
      AND cli_x.es_cartera='Y') THEN 'CAPTACION'
    ELSE
    CASE
      WHEN cli_x.es_cartera = 'Y' THEN 'CARTERA'
    ELSE
    'CAPTACION'
  END
  END
    es_cartera_corregido,
    CAST(cli_x.fecha_ultimo_cambio AS timestamp),
    c.equipo_ds,
    CASE
      WHEN m.codprov IN (15, 27, 32, 36) OR m.codprov IS NULL THEN 'BAU'
    ELSE
    'EXPANSION'
  END
    ,
    catalogo.tecnologia_detalle_ds,
    0,
    0,
    exp.row_id
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr
  ON
    p.idproductonew=pr.idproducto
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x
  ON
    exp_x.row_id=p.idcontrato
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
  ON
    exp.row_id=exp_x.row_id
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
  ON
    exp.owner_emp_id=emp.row_id
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x
  ON
    cli_x.row_id=exp.CST_OU_ID
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
  ON
    catalogo.adicional_lg = 1
    AND catalogo.tipo_identificacion_ds = 'CATALOGO'
    AND catalogo.marca_ds = 'R'
    AND pr.CODIGO = catalogo.catalogo_id
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` c
  ON
    CAST(c.codigo_comercial AS string) = emp.attrib_07
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci
  ON
    ci.cliente_id = CAST(p.idcliente AS int64)
  INNER JOIN
  --  `mm-commissions-reporting.KRT_CAPTACION.servicios_crm_catalogo`  tmp
      `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
  ON
    tmp.cliente_id = CAST(p.idcliente AS int64)
    AND tmp.categoria_servicio_ds = catalogo.categoria_servicio_ds
    AND tmp.marca_ds = catalogo.marca_ds
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_smc_tm_huecos` h
  ON
    pr.idseco = CAST(h.id AS string)
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_smc_tm_municipio` m
  ON
    h.codmun = m.codmun
  WHERE
    DATE_TRUNC(CAST (p.last_upd AS DATE), DAY) >=DESDE_DT
    AND DATE_TRUNC(CAST (p.last_upd AS DATE), DAY) <= HASTA_DT
    AND pr.accion='Alta'
    AND ci.marca_ds = 'R'
    AND p.estado ='5'
    AND cli_x.attrib_43 IN ('Residencial',
      'Microempresa',
      'Ambos',
      'Colaborador');


-- PASO 2: INSERTO REGISTROS EN FICHERO DE LOG

  -- Log de fichero completo
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0106_SERVICIOS_CAPTACION` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`; 

  -- Log de incremento
  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0106_SERVICIOS_CAPTACION_INCR` AS
  SELECT 
    * 
  FROM 
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` 
  EXCEPT DISTINCT
  SELECT
    * 
  FROM  
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_SERVICIOS_CAPTACION`;


END