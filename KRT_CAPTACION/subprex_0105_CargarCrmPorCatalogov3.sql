BEGIN

  declare DESDE_0M_DT, DESDE_DT, HASTA_DT date;
  --LOCAL
  --declare DESDE, HASTA INT64; SET DESDE=20231201; SET HASTA=20231231;
  set DESDE_DT = parse_date ('%Y%m%d', cast ( DESDE as string) );
  set HASTA_DT = parse_date ('%Y%m%d', cast ( HASTA as string) );
  SET DESDE_0M_DT=date_trunc(parse_date('%Y%m%d', CAST ( HASTA AS string)),month) ;


  
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION`;

  --- PASO 1: GENERO EVENTOS DE DISTINTAS MARCAS 

  --- PASO 1.1: EVENTOS T

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_T` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` WHERE 0=1;
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_T`
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
    ca1.canal_agrupado1_ds canal_alta_ds ,
    sc.subcanal_ds subcanal_ds,
    ca2.canal_agrupado2_ds tipo_canal_alta_ds,
    canal.swCOInterno nombre_distribuidor_alta_ds,
    REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') agente_alta_id,
    p.swCreatedBy agente_creador_id,
    catalogo.categoria_servicio_ds categoria_servicio_ds,
    c.swNIE cif_nif,
    UPPER(c.swSegmento) segmento_ds,
    UPPER(c.swSubsegmento) subsegmento_ds,
    p.swMarcaCartera marca_cartera_ds,
    c.swDateCreated2 Antiguedad_Cliente,    
--    c.swAntiguedad Antiguedad_Cliente,
    REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(ca.swVerticalFocus), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') equipo_ds,
    q.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0 portabilidad_in_lg,
    0 gb,
    '' expediente_id,'' expediente_padre_id, p.swAgreementId,'',NULL,'',NULL,catalogo_id, 5 as grid 
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
  ON
    p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64)
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'TCNET'
    AND adicional_lg = 0
    --inner join D90_FINANCIERO.AG_COMISIONAMIENTO_CAPTACION_TMP_1 tmp on tmp.cliente_id = p.swCustomerId and tmp.categoria_servicio_ds = catalogo.categoria_servicio_ds  and tmp.marca_ds = catalogo.marca_ds
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_prod_cat` cat
  ON
    p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c
  ON
    p.swCustomerId = c.swCustomerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca
  ON
    p.swChnlPartnerId = ca.swChnlPartnerId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` canal
  ON
    canal.swChnlPartnerId = ca.swChnlPartnerCtralId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe
  ON
    p.swPedId = pe.swPersonalId
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_t_30_maestro_canal` tc
  ON
    tc.canal_id = p.swChnlPartnerId
    AND tc.agente_alta_id = REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` ca1
  ON
    tc.canal_agrupado1_id = ca1.canal_agrupado1_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` ca2
  ON
    tc.canal_agrupado2_id = ca2.canal_agrupado2_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
  ON
    tc.subcanal_id = sc.subcanal_id
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_direcciones` d
  ON
    p.swInstProdId=d.swObjectId
    AND d.swObjectType IN ('INSTALLED',
      'ASOCIADOS')
    AND d.swType='Dirección de Instalación'
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_direcciones` d2
  ON
    p.swCustomerId = d2.swobjectId
    AND d2.swObjectType = 'CUSTOMER'
    AND d2.swType = 'Domicilio Habitual'
  LEFT JOIN
    `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_territorio` Q
  ON
    SUBSTR(ifnull(d.swZip,
        d2.swZip),1,2)=Q.cod_prov_id
    AND catalogo.marca_ds=Q.marca_ds
  WHERE
    (    (DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT) 
      OR (DATE_TRUNC(CAST (p.swDateCreated AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT) 
    )
    AND (p.swProdOrigId IS NULL
      OR EXISTS (
      SELECT
        1
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p2
      WHERE
        p2.swInstProdId = p.swMasterInstProdId
        AND (    (DATE_TRUNC(CAST (p2.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT) 
              OR (DATE_TRUNC(CAST (p2.swDateCreated AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT) 
            )
        --AND DATE_TRUNC(CAST (p2.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT
      )
    )
    AND (p.swFechaDesinstalacion IS NULL OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
    AND TRIM(c.swSegmento) IN ('SOHO',
      'Residencial',
      'PYME')
    AND p.swCreatedBy NOT IN ('AltaMasiva',
      'MIGRAMASHFC_FTTH')
    AND p.swCreatedBy NOT LIKE '%@%';



  --- PASO 1.2: EVENTOS K, VIRGIN Y RACC

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_KVRACC` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` WHERE 0=1;
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_KVRACC` 
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
    CASE
      WHEN t.concepto_ds IS NOT NULL THEN t.concepto_ds
    ELSE
    catalogo.concepto_ds
  END
    concepto_ds,
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
    p.swMarcaCartera swMarcaCartera,
    --CAST('1900-01-01' AS timestamp) antiguedadCliente,
    c.swDateCreated2 antiguedadCliente,    
    REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(ca.swVerticalFocus), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U'),
    q.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0,
    0,
    '','', p.swAgreementId,'',NULL,'',NULL,catalogo_id, 5 as grid 
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c
  ON
    p.swCustomerId = c.swCustomerId
  INNER JOIN
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm
  ON
    c.mmMarcaId = mm.mmMarcaId
  INNER JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
  ON
    p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64)
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'EKTNET'
    AND adicional_lg = 0
    and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END
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
--  LEFT JOIN (
--    SELECT
--      swCustomerId,
--      MIN(swDateInstalled) FechaActivacion
--    FROM
--      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`
--    WHERE
--      swStatus = 'Activo'
--      OR (DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) >= DESDE_DT
--        AND DATE_TRUNC(CAST (swFechaDesinstalacion AS DATE), DAY) <= HASTA_DT)
--    GROUP BY
--      1) pActivos
--  ON
--    pActivos.swCustomerId = c.swCustomerId
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.PARAM_TERMINALES` t
  ON
    cc.swCaractValor = t.modelo_ds
    AND
    CASE mm.mmMarcaDesc
      WHEN 'Euskaltel' THEN 'EUSKALTEL'
      WHEN 'Virgin Telco' THEN 'VIRGIN'
      WHEN 'RACCTEL+' THEN 'RACC'
      WHEN 'Telecable' THEN 'TELECABLE'
  END
    = t.marca_ds
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
    SUBSTR(ifnull(d.swZip,
        d2.swZip),1,2)=Q.cod_prov_id
    AND catalogo.marca_ds=Q.marca_ds
  WHERE
    (    (DATE_TRUNC(CAST (p.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT) 
      OR (DATE_TRUNC(CAST (p.swDateCreated AS DATE), DAY) BETWEEN DESDE_DT  AND HASTA_DT) 
    )
    AND (p.swProdOrigId IS NULL
      OR EXISTS (
      SELECT
        1
      FROM
        `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p2
      WHERE
        p2.swInstProdId = p.swMasterInstProdId
        AND (    (DATE_TRUNC(CAST (p2.swDateInstalled AS DATE), DAY) BETWEEN DESDE_0M_DT  AND HASTA_DT) 
              OR (DATE_TRUNC(CAST (p2.swDateCreated AS DATE), DAY) BETWEEN DESDE_0M_DT  AND HASTA_DT) 
            )
        --AND DATE_TRUNC(CAST (p2.swDateInstalled AS DATE), DAY) BETWEEN DESDE_DT AND HASTA_DT
        )
      )
    AND (p.swFechaDesinstalacion IS NULL
      OR DATE_TRUNC(CAST (p.swFechaDesinstalacion AS DATE), DAY) > HASTA_DT )
    AND p.swCreatedBy NOT IN ('AltaMasiva',
      'MIGRAMASHFC_FTTH')
    AND p.swCreatedBy NOT LIKE '%@%';


  --- PASO 1.3·: EVENTOS R

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` WHERE 0=1;
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R`
  SELECT
    pr.codigo_empresa_bi marca_ds, CAST(p.idcliente AS int64) cliente_id, CAST(pr.IDINTERNO AS int64), pr.descripcion, catalogo.concepto_ds,
    CASE WHEN p.estado ='5' THEN (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) ELSE NULL END FECHA_RFB_ID,
    (EXTRACT(YEAR FROM p.CREATED)*10000 + EXTRACT(MONTH FROM p.CREATED) * 100 + EXTRACT(DAY FROM p.CREATED)) FECHA_VENTA_NETA_ID,
    CASE WHEN p.estado ='5' THEN CAST(p.last_upd AS timestamp) ELSE NULL END fecha_rfb_dt, 
    CAST(p.created AS timestamp) fecha_venta_id, c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds,
    c.distribuidor_ds, emp.attrib_07 agente, emp.attrib_07 agente, catalogo.categoria_servicio_ds, ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds,
    CASE WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION' WHEN (CAST(cli_x.fecha_ultimo_cambio AS date)>p.created AND cli_x.es_cartera='Y') THEN 'CAPTACION'
      ELSE CASE  WHEN cli_x.es_cartera = 'Y' THEN 'CARTERA'  ELSE 'CAPTACION'END
    END es_cartera_corregido,
    CAST(cli_x.fecha_ultimo_cambio AS timestamp), c.equipo_ds, CASE WHEN m.codprov IN (15, 27, 32, 36) OR m.codprov IS NULL THEN 'BAU' ELSE 'EXPANSION' END,
    catalogo.tecnologia_detalle_ds, 0, 0, 
    /*exp.row_id, pr.IDCONTRATO,NULL,'',NULL,'',NULL,catalogo_id, 5 as grid*/ 
    p.IDEXPEDIENTE,exp.row_id, NULL,'',NULL,'',NULL,catalogo_id, 5 as grid 
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr ON p.idproductonew=pr.idproducto 
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x ON exp_x.row_id=p.idcontrato
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp  ON exp.row_id=exp_x.row_id
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp ON exp.owner_emp_id=emp.row_id
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x ON cli_x.row_id=exp.CST_OU_ID
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo 
  ON catalogo.adicional_lg = 0 AND catalogo.tipo_identificacion_ds = 'CATALOGO'  AND catalogo.marca_ds = 'R' AND pr.CODIGO = catalogo.catalogo_id
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_r_30_maestro_canal` c ON CAST(c.codigo_comercial AS string) = emp.attrib_07
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci ON ci.cliente_id = CAST(p.idcliente AS int64)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_smc_tm_huecos` h ON pr.idseco = CAST(h.id AS string)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_smc_tm_municipio` m ON h.codmun = m.codmun
  WHERE (    (DATE_TRUNC(CAST (p.last_upd AS DATE), DAY) >=DESDE_DT AND DATE_TRUNC(CAST (p.last_upd AS DATE), DAY) <= HASTA_DT)
      OR DATE_TRUNC(CAST (p.CREATED AS DATE), DAY) >=DESDE_DT AND DATE_TRUNC(CAST (p.CREATED AS DATE), DAY) <= HASTA_DT    
    )
    --AND p.estado ='5'
    AND pr.accion='Alta'
    AND ci.marca_ds = 'R'
    AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos', 'Colaborador') ;



  --- PASO 1.3.1·: ELIMINO EVENTOS DE R CON FECHA DE VENTA CON MAS DE 4 MESES DE ANTIGUEDAD

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R_FV_INCONSISTENTE`  AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R` WHERE EXTRACT(DATE FROM fecha_venta_neta_dt)< DATE_TRUNC(DATE_SUB(DESDE_DT, interval 4 month),MONTH);

  DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R` c
  WHERE exists (
          SELECT 1 
          from `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R_FV_INCONSISTENTE` v
          where v.cliente_id=c.cliente_id and v.servicio_id=c.servicio_id and c.fecha_venta_neta_dt=v.fecha_venta_neta_dt
  );


-- PASO 3: INTEGRO LOS EVENTOS DE TODAS LAS MARCAS

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DESC` AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_KVRACC`
  UNION ALL 
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_T`
  UNION ALL
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_R`;


-- PASO 4: CREO TABLAS DE LOG
  -- Log de fichero 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_INCR` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DESC` d
  WHERE NOT EXISTS (
              SELECT 1 FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` p
              where d.marca_ds=p.marca_ds and d.cliente_id=p.cliente_id and d.servicio_id=p.servicio_id
  ); 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DUP` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DESC` d
  WHERE EXISTS (
              SELECT 1 FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` p
              where d.marca_ds=p.marca_ds and d.cliente_id=p.cliente_id and d.servicio_id=p.servicio_id
  ); 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_INCR`; 



-- PASO 5: INSERTO EVENTOS EN TABLA VENTAS CAPTACION
  INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_INCR`;



END