BEGIN

  -- CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0105_CargarCrmPorCatalogov5`(20260601,20260630);

  DECLARE DESDE_0M_DT, DESDE_DT, HASTA_DT DATE;
  --- LOCAL
  --DECLARE DESDE, HASTA INT64; SET DESDE=20260601; SET DESDE=20260630;
  
  -- Conversión de fechas
  SET DESDE_DT = PARSE_DATE('%Y%m%d', CAST(DESDE AS STRING));
  SET HASTA_DT = PARSE_DATE('%Y%m%d', CAST(HASTA AS STRING));
  SET DESDE_0M_DT = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(HASTA AS STRING)), MONTH);

  --- PASO 1: GENERO EVENTOS DE DISTINTOS CRMS 

  -- CALL `mm-commissions-reporting.KRT_MIG_PWC.audit_compare_tables`('mm-commissions-reporting', 'KRT_CAPTACION', 'LOG_0105_VENTAS_CAPTACION_T','mm-commissions-reporting', 'KRT_CAPTACION', 'LOG_0105_VENTAS_CAPTACION_TCNET_DES');

  --- PASO 1.1: EVENTOS TCNET
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_TCNET_DES` 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_TCNET` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  with param_bloque as (
    select distinct 
    "CATALOGO" as tipo_identificacion_ds,
    "TELECABLE" as marca_ds,
    categoria_servicio_ds,
    tecnologia_detalle_ds, 
    '' as  campo_filtrado,
    REGEXP_REPLACE(concepto_ds, r'[^0-9]', ''),
    case when  categoria_servicio_ds="BANDA ANCHA"  THEN 
            CASE 
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 1 AND 2  THEN 601 
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 10 AND 100 THEN 0
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 101 AND 300 THEN 101
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 301 AND 500 THEN 301
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 501 AND 600 THEN 501                            
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 601 AND 999 THEN 601              
                ELSE 0
            END
  
  
         Else  0  
    end as valor_minimo, 

    case when  categoria_servicio_ds="BANDA ANCHA"  THEN 
            CASE 
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 1 AND 2  THEN 999999 
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 10 AND 100 THEN 100
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 101 AND 300 THEN 300
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 301 AND 500 THEN 500
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 501 AND 600 THEN 600                            
                WHEN SAFE_CAST(REGEXP_REPLACE(concepto_ds, r'[^0-9]', '') AS INT64) BETWEEN 601 AND 999 THEN 999              
                ELSE 0
            END
         Else 0  
    end as valor_maximo, 

    detalle_servicio_ds,
    catalogo_id, 
    "TCNET" as sistema_ds, 
    concepto_ds, 
    0 as adicional_lg,
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
    --from `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION`
    WHERE grid BETWEEN 1 AND 4 
    and categoria_servicio_ds!="MOVILES POSTPAGO"
    and marca_ds="TELECABLE"
    order by 3,4,8
  ), param_catalogo_orig as(  
  select distinct 
    tipo_identificacion_ds,
    marca_ds,
    categoria_servicio_ds,
    tecnologia_detalle_ds, 
    campo_filtrado,
    valor_minimo,
    valor_maximo,
    detalle_servicio_ds,
    catalogo_id, 
    sistema_ds, 
    concepto_ds, 
    adicional_lg
    from `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS`
    WHERE tipo_identificacion_ds="CATALOGO"
    and marca_ds="TELECABLE"
    and sistema_ds="TCNET"
  ), param_catalogo as (
    select 
      tipo_identificacion_ds,
      marca_ds,
      categoria_servicio_ds,
      tecnologia_detalle_ds, 
      campo_filtrado,
      valor_minimo,
      valor_maximo,
      detalle_servicio_ds,
      catalogo_id, 
      sistema_ds, 
      concepto_ds, 
      adicional_lg
    from param_catalogo_orig
    UNION DISTINCT
    select 
      tipo_identificacion_ds,
      marca_ds,
      categoria_servicio_ds,
      tecnologia_detalle_ds, 
      campo_filtrado,
      valor_minimo,
      valor_maximo,
      detalle_servicio_ds,
      catalogo_id, 
      sistema_ds, 
      concepto_ds, 
      adicional_lg
    from param_bloque
  )

  SELECT
    DISTINCT catalogo.marca_ds,
    CAST(p.swCustomerId AS INT64) cliente_id,
    p.swInstProdId as servicio_id, -- Alias añadido por consistencia con las tablas posteriores
    cat.swReleaseName NombreProducto,
    catalogo.concepto_ds,
    CAST(FORMAT_DATE('%Y%m%d', DATE(p.swDateInstalled)) AS INT64) FECHA_RFB_ID,
    CAST(FORMAT_DATE('%Y%m%d', DATE(p.swDateCreated)) AS INT64) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT,
    p.swDateCreated FECHA_VENTA_NETA_DT,
    ca1.canal_agrupado1_ds canal_alta_ds ,
    sc.subcanal_ds subcanal_ds,
    ca2.canal_agrupado2_ds tipo_canal_alta_ds,
    canal.swCOInterno nombre_distribuidor_alta_ds,
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') agente_alta_id,
    p.swCreatedBy agente_creador_id,
    catalogo.categoria_servicio_ds categoria_servicio_ds,
    c.swNIE cif_nif,
    UPPER(c.swSegmento) segmento_ds,
    UPPER(c.swSubsegmento) subsegmento_ds,
    p.swMarcaCartera marca_cartera_ds,
    c.swDateCreated2 Antiguedad_Cliente,    
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(ca.swVerticalFocus), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') equipo_ds,
    q.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0 portabilidad_in_lg,
    0 gb,
    '' expediente_id,
    '' expediente_padre_id, 
    p.swAgreementId as agreement_id,
    '' AS campo_vacio_1, 
    NULL AS campo_nulo_1, 
    '' AS campo_vacio_2, 
    NULL AS campo_nulo_2, 
    catalogo_id, 
    5 as grid 
  FROM
    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
  -- INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
  INNER JOIN param_catalogo catalogo
    ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64)
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'TCNET'
    AND adicional_lg = 0
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_prod_cat` cat
    ON p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c
    ON p.swCustomerId = c.swCustomerId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca
    ON p.swChnlPartnerId = ca.swChnlPartnerId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` canal
    ON canal.swChnlPartnerId = ca.swChnlPartnerCtralId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe
    ON p.swPedId = pe.swPersonalId
  LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` tc
    ON tc.canal_id = p.swChnlPartnerId
    AND tc.agente_alta_id = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` ca1
    ON tc.canal_agrupado1_id = ca1.canal_agrupado1_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` ca2
    ON tc.canal_agrupado2_id = ca2.canal_agrupado2_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
    ON tc.subcanal_id = sc.subcanal_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_direcciones` d
    ON p.swInstProdId = d.swObjectId
    AND d.swObjectType IN ('INSTALLED', 'ASOCIADOS')
    AND d.swType = 'Dirección de Instalación'
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_direcciones` d2
    ON p.swCustomerId = d2.swobjectId
    AND d2.swObjectType = 'CUSTOMER'
    AND d2.swType = 'Domicilio Habitual'
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_territorio` Q
    ON SUBSTR(IFNULL(d.swZip, d2.swZip),1,2) = Q.cod_prov_id
    AND catalogo.marca_ds = Q.marca_ds
  WHERE
    (DATE_TRUNC(DATE(p.swDateInstalled), DAY) BETWEEN DESDE_DT AND HASTA_DT
     OR DATE_TRUNC(DATE(p.swDateCreated), DAY) BETWEEN DESDE_DT AND HASTA_DT)
    AND (p.swProdOrigId IS NULL
      OR EXISTS (
        SELECT 1 FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p2
        WHERE p2.swInstProdId = p.swMasterInstProdId
          AND (DATE_TRUNC(DATE(p2.swDateInstalled), DAY) BETWEEN DESDE_DT AND HASTA_DT
               OR DATE_TRUNC(DATE(p2.swDateCreated), DAY) BETWEEN DESDE_DT AND HASTA_DT)
      )
    )
    AND (p.swFechaDesinstalacion IS NULL OR DATE_TRUNC(DATE(p.swFechaDesinstalacion), DAY) > HASTA_DT )
    AND TRIM(c.swSegmento) IN ('SOHO', 'Residencial', 'PYME')
    AND p.swCreatedBy NOT IN ('AltaMasiva', 'MIGRAMASHFC_FTTH')
    AND p.swCreatedBy NOT LIKE '%@%';




  --- PASO 1.2: EVENTOS EKTNET
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_EKTNET` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS   
  SELECT
    DISTINCT
    CASE UPPER(TRIM(mm.mmMarcaDesc))
      WHEN 'EUSKALTEL' THEN 'EUSKALTEL'
      WHEN 'VIRGIN TELCO' THEN 'VIRGIN'
      WHEN 'RACCTEL+' THEN 'RACC'
      WHEN 'TELECABLE' THEN 'TELECABLE'
      WHEN 'SIMPLE' THEN 'SIMPLE'      
    END AS marca_ds,
    CAST(p.swCustomerId AS INT64) cliente_id,
    p.swInstProdId as servicio_id,
    IFNULL(cc.swCaractValor, cat.swReleaseName) AS NombreProducto,
    IFNULL(t.concepto_ds, catalogo.concepto_ds) AS concepto_ds,
    CAST(FORMAT_DATE('%Y%m%d', DATE(p.swDateInstalled)) AS INT64) FECHA_RFB_ID,
    CAST(FORMAT_DATE('%Y%m%d', DATE(p.swDateCreated)) AS INT64) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT,
    p.swDateCreated FECHA_VENTA_NETA_DT,
    c1.canal_agrupado1_ds canal_alta_ds,
    sc.subcanal_ds subcanal_ds,
    c2.canal_agrupado2_ds tipo_canal_alta_ds,
    `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(ca.swName) nombre_distribuidor_alta_ds,
    `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(pe.swNombre) agente_alta_id,
    p.swCreatedBy agente_creador_id,
    catalogo.categoria_servicio_ds categoria_servicio_ds,
    c.swNIE cif_nif,
    UPPER(c.swSegmento) segmento_ds,
    UPPER(c.swSegmento) subsegmento_ds,
    p.swMarcaCartera marca_cartera_ds,
    c.swDateCreated2 antiguedadCliente,    
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(ca.swVerticalFocus), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U') equipo_ds,
    q.territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0 portabilidad_in_lg,
    0 gb,
    '' expediente_id,
    '' expediente_padre_id, 
    p.swAgreementId AS agreement_id,
    '' AS campo_vacio_1, 
    NULL AS campo_nulo_1, 
    '' AS campo_vacio_2, 
    NULL AS campo_nulo_2, 
    catalogo_id, 
    5 as grid 
  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c
    ON p.swCustomerId = c.swCustomerId
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm
    ON c.mmMarcaId = mm.mmMarcaId
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo
    ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64)
    AND tipo_identificacion_ds IN ('CATALOGO')
    AND Sistema_ds = 'EKTNET'
    AND adicional_lg = 0
    AND catalogo.marca_ds = CASE UPPER(TRIM(mm.mmMarcaDesc)) WHEN 'EUSKALTEL' THEN 'EUSKALTEL' WHEN 'VIRGIN TELCO' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'TELECABLE' THEN 'TELECABLE' WHEN 'SIMPLE' THEN 'SIMPLE' END
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat
    ON p.swProdReleaseId = cat.swProdReleaseId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe
    ON pe.swPersonalId = p.swProviderGrpId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca
    ON ca.swChnlPartnerId = p.swChnlPartnerId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` trc
    ON trc.canal_id = p.swChnlPartnerId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc
    ON p.swInstProdId = cc.swInstProdId
    AND cc.swCaractName = 'Modelo'
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_TERMINALES` t
    ON cc.swCaractValor = t.modelo_ds
    AND CASE UPPER(TRIM(mm.mmMarcaDesc)) WHEN 'EUSKALTEL' THEN 'EUSKALTEL' WHEN 'VIRGIN TELCO' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'TELECABLE' THEN 'TELECABLE' WHEN 'SIMPLE' THEN 'SIMPLE' END = t.marca_ds
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1
    ON trc.canal_agrupado1_id = c1.canal_agrupado1_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2
    ON trc.canal_agrupado2_id = c2.canal_agrupado2_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc
    ON trc.subcanal_id = sc.subcanal_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cicl
    ON c.swParentId = cicl.swCustomerId
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_direcciones` d
    ON p.swInstProdId = d.swObjectId
    AND d.swObjectType IN ('INSTALLED', 'ASOCIADOS')
    AND d.swType='Dirección de Instalación'
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_direcciones` d2
    ON p.swCustomerId = d2.swobjectId
    AND d2.swObjectType = 'CUSTOMER'
    AND d2.swType = 'Domicilio Habitual'
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_territorio` Q
    ON SUBSTR(IFNULL(d.swZip, d2.swZip),1,2) = Q.cod_prov_id
    AND catalogo.marca_ds = Q.marca_ds
  WHERE
    (DATE_TRUNC(DATE(p.swDateInstalled), DAY) BETWEEN DESDE_DT AND HASTA_DT 
     OR DATE_TRUNC(DATE(p.swDateCreated), DAY) BETWEEN DESDE_DT AND HASTA_DT)
    AND (p.swProdOrigId IS NULL
      OR EXISTS (
        SELECT 1 FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p2
        WHERE p2.swInstProdId = p.swMasterInstProdId
          AND (DATE_TRUNC(DATE(p2.swDateInstalled), DAY) BETWEEN DESDE_0M_DT AND HASTA_DT 
               OR DATE_TRUNC(DATE(p2.swDateCreated), DAY) BETWEEN DESDE_0M_DT AND HASTA_DT)
      )
    )
    AND (p.swFechaDesinstalacion IS NULL OR DATE_TRUNC(DATE(p.swFechaDesinstalacion), DAY) > HASTA_DT )
    AND p.swCreatedBy NOT IN ('AltaMasiva', 'MIGRAMASHFC_FTTH')
    AND p.swCreatedBy NOT LIKE '%@%';


  --- PASO 1.3: EVENTOS SIEBEL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_SIEBEL` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT DISTINCT 
    pr.codigo_empresa_bi marca_ds,
    CAST(p.idcliente AS int64) cliente_id,
    CAST(pr.IDINTERNO AS string) as servicio_id,
    pr.descripcion NombreProducto,
    catalogo.concepto_ds,
    CASE WHEN p.estado ='5' THEN CAST(FORMAT_DATE('%Y%m%d', DATE(p.LAST_UPD)) AS INT64) ELSE NULL END FECHA_RFB_ID,
    CAST(FORMAT_DATE('%Y%m%d', DATE(p.CREATED)) AS INT64) FECHA_VENTA_NETA_ID,
    CASE WHEN p.estado ='5' THEN CAST(p.last_upd AS timestamp) ELSE NULL END fecha_rfb_dt,
    CAST(p.created AS timestamp) FECHA_VENTA_NETA_DT,
    c.canal_agrupado1_ds canal_alta_ds,
    c.subcanal_ds subcanal_ds,
    c.canal_agrupado2_ds tipo_canal_alta_ds,
    c.distribuidor_ds nombre_distribuidor_alta_ds,
    emp.attrib_07 agente_alta_id,
    emp.attrib_07 agente_creador_id,
    catalogo.categoria_servicio_ds categoria_servicio_ds,
    ci.cif_nif,
    ci.segmento_ds segmento_ds,
    ci.subsegmento_ds subsegmento_ds,
    CASE
      WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
      WHEN (DATE(cli_x.fecha_ultimo_cambio) > DATE(exp.created) AND cli_x.es_cartera='Y') THEN 'CAPTACION'
      ELSE CASE
             WHEN cli_x.es_cartera='Y' AND (est_cli.clasificacion_ds NOT IN ('SOMO', 'INACTIVO')) THEN 'CARTERA'
             WHEN cli_x.es_cartera='Y' AND est_cli.clasificacion_ds='SOMO' AND exp.X_R_SUBTIPO2='MOVIL' THEN 'CARTERA'
             ELSE 'CAPTACION'
           END
    END AS marca_cartera_ds, 
    CAST(cli_x.fecha_ultimo_cambio AS timestamp) Antiguedad_Cliente,
    c.equipo_ds equipo_ds,
    CASE WHEN m.codprov IN (15, 27, 32, 36) OR m.codprov IS NULL THEN 'BAU' ELSE 'EXPANSION' END territorio_ds,
    catalogo.tecnologia_detalle_ds,
    0 portabilidad_in_lg,
    0 gb,
    p.IDEXPEDIENTE expediente_id,
    exp.row_id expediente_padre_id,
    NULL AS agreement_id,
    '' AS campo_vacio_1,
    NULL AS campo_nulo_1,
    '' AS campo_vacio_2,
    NULL AS campo_nulo_2,
    catalogo_id,
    5 AS grid
  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr ON p.idproductonew=pr.idproducto 
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x ON exp_x.row_id=p.idcontrato
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp ON exp.row_id=exp_x.row_id
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp ON exp.owner_emp_id=emp.row_id
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x ON cli_x.row_id=exp.CST_OU_ID
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo 
    ON catalogo.adicional_lg = 0 AND catalogo.tipo_identificacion_ds = 'CATALOGO' AND catalogo.marca_ds = 'R' AND pr.CODIGO = catalogo.catalogo_id
  INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c ON CAST(c.agente_venta_id AS string) = emp.attrib_07
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci ON ci.cliente_id = CAST(p.idcliente AS int64)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_smc_tm_huecos` h ON pr.idseco = CAST(h.id AS string)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_smc_tm_municipio` m ON h.codmun = m.codmun
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli
    ON CAST(p.idcliente AS INT64)=est_cli.cliente_id AND est_cli.marca_ds='R'
    AND EXTRACT(DATE FROM desde_dt) < EXTRACT(DATE FROM exp.created)
    AND EXTRACT(DATE FROM hasta_dt) >= EXTRACT(DATE FROM exp.created)     
  WHERE 
    ((DATE(p.last_upd) BETWEEN DESDE_DT AND HASTA_DT) OR (DATE(p.CREATED) BETWEEN DESDE_DT AND HASTA_DT))
    AND pr.accion='Alta'
    AND ci.marca_ds = 'R'
    AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos', 'Colaborador')
    -- Se integra la condición de borrado (paso 1.3.1 original) directamente aquí para optimizar:
    AND DATE(p.created) >= DATE_TRUNC(DATE_SUB(DESDE_DT, INTERVAL 4 MONTH), MONTH);

  --- PASO 3: INTEGRO LOS EVENTOS DE TODAS LAS MARCAS
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DESC` AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_EKTNET`
  UNION ALL 
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_TCNET`
  UNION ALL
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_SIEBEL`;


  --- PASO 4: CREO TABLAS DE LOG Y CALCULO INCREMENTAL
  -- Identificamos registros duplicados (existentes) usando un LEFT JOIN en lugar de WHERE EXISTS para mejor partición
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DUP` AS
  SELECT d.* FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DESC` d
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` p
    ON d.marca_ds = p.marca_ds AND d.cliente_id = p.cliente_id AND d.servicio_id = p.servicio_id;

  -- Identificamos registros nuevos (incrementales)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_INCR` AS
  SELECT d.* FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_DESC` d
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.LOG_0104_VENTAS_CAPTACION` p
    ON d.marca_ds = p.marca_ds AND d.cliente_id = p.cliente_id AND d.servicio_id = p.servicio_id
  WHERE p.cliente_id IS NULL;

  -- Reemplazamos la tabla consolidada LOG (Paso redundante en el original, pero mantenido para la estructura de logs esperada)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_INCR`; 

  --- PASO 5: INSERTO EVENTOS EN TABLA VENTAS CAPTACION
  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0105_VENTAS_CAPTACION_INCR`;

END