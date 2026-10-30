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

  INSERT INTO
    `mm-commissions-reporting.KRT_CAPTACION_MM.EVENTOS_CAPTACION`
  SELECT
    DISTINCT
    CASE mm.mmMarcaDesc
      WHEN 'Euskaltel' THEN 'EUSKALTEL'
      WHEN 'Virgin Telco' THEN 'VIRGIN'
      WHEN 'RACCTEL+' THEN 'RACC'
      WHEN 'Telecable' THEN 'TELECABLE'
  END
    ,
    CAST(p.swCustomerId AS INT64) cliente_id,
    p.swInstProdId,
    CASE
      WHEN cc.swCaractValor IS NOT NULL THEN swCaractValor
    ELSE
    cat.swReleaseName
  END
    NombreProducto,
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
    CASE
      WHEN mm.mmMarcaDesc = 'Telecable' THEN CASE
      WHEN ABS(DATE_DIFF(CAST(cicl.swAntiguedad AS DATE), CAST(p.swDateInstalled AS DATE), DAY)) <= 15 THEN 'CAPTACION'
    ELSE
    CASE
      WHEN cicl.swAntiguedad IS NULL AND ABS(DATE_DIFF(CAST(pActivos.FechaActivacion AS DATE), CAST(p.swDateInstalled AS DATE), DAY)) <= 15 THEN 'CAPTACION'
    ELSE
    'CARTERA'
  END
  END
    ELSE
    p.swMarcaCartera
  END
    swMarcaCartera,
    CAST('1900-01-01' AS timestamp) antiguedadCliente,
    REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(ca.swVerticalFocus), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'),
    q.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0,
    0,
    CASE
      WHEN p.swProdOrigId IS NULL THEN 'NO'
    ELSE
    'SI'
  END
    ,
    catalogo.multiplicador
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CATALOGO` catalogo
  ON
    p.swProdReleaseId = catalogo.catalogo_id
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'EKTNET'
    AND adicional_lg = 0
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c
  ON
    p.swCustomerId = c.swCustomerId
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm
  ON
    c.mmMarcaId = mm.mmMarcaId --
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
  ON
    tmp.cliente_id = p.swCustomerId
    AND tmp.categoria_servicio_ds = catalogo.categoria_servicio_ds
    AND tmp.marca_ds = catalogo.marca_ds
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
  ON
    p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
  ON
    pe.swPersonalId=p.swProviderGrpId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
  ON
    ca.swChnlPartnerId = p.swChnlPartnerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` trc
  ON
    trc.canal_id = p.swChnlPartnerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc
  ON
    p.swInstProdId = cc.swInstProdId
    AND cc.swCaractName = 'Modelo'
  LEFT JOIN (
    SELECT
      swCustomerId,
      MIN(swDateInstalled) FechaActivacion
    FROM
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
    WHERE
      swStatus = 'Activo'
      OR (DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) >= DESDE_DT
        AND DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT)
    GROUP BY
      1) pActivos
  ON
    pActivos.swCustomerId = c.swCustomerId
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
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cicl
  ON
    c.swParentId = cicl.swCustomerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_direcciones` d
  ON
    p.swInstProdId=d.swObjectId
    AND d.swObjectType IN ('INSTALLED',
      'ASOCIADOS')
    AND d.swType='Dirección de Instalación'
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_direcciones` d2
  ON
    p.swCustomerId = d2.swobjectId
    AND d2.swObjectType = 'CUSTOMER'
    AND d2.swType = 'Domicilio Habitual'
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_territorio` Q
  ON
    SUBSTR(IFNULL(d.swZip,d2.swZip),1,2)=Q.cod_prov_id
    AND catalogo.marca_ds=Q.marca_ds
  WHERE
    DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT
    AND HASTA_DT
    AND (p.swFechaDesinstalacion IS NULL
      OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
    AND p.swCreatedBy NOT IN ('AltaMasiva',
      'MIGRAMASHFC_FTTH')
    AND p.swCreatedBy NOT LIKE '%@%';

END