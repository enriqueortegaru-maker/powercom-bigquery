BEGIN

    declare DESDE_0M_DT, DESDE_DT, HASTA_DT date;
    --LOCAL
    --declare DESDE, HASTA INT64; SET DESDE=20230701; SET HASTA=20230731;
    set DESDE_DT = parse_date ('%Y%m%d', cast ( DESDE as string) );
    set HASTA_DT = parse_date ('%Y%m%d', cast ( HASTA as string) );
    SET DESDE_0M_DT=date_trunc(parse_date('%Y%m%d', CAST ( HASTA AS string)),month) ;


    /*PASO 1 - DESCUBRO PROMOCIONES INSTANCIADAS SOBRE TODAS LAS HUELLAS PARAMETRIZADAS*/
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0108_PROMOCIONES` AS 
    SELECT
      pr.codigo_empresa_bi marca_ds, CAST(p.idcliente AS int64) cliente_id, CAST(pr.IDINTERNO AS int64) servicio_id, pr.descripcion detalle_Servicio_ds, 
      --CONCAT("Promocion por concepto: ", catalogo.concepto_ds) CONCEPTO_DS,
      catalogo.concepto_ds CONCEPTO_DS,
      CASE WHEN p.estado ='5' THEN (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) ELSE NULL END FECHA_RFB_ID,
      (EXTRACT(YEAR FROM p.CREATED)*10000 + EXTRACT(MONTH FROM p.CREATED) * 100 + EXTRACT(DAY FROM p.CREATED)) FECHA_VENTA_NETA_ID,
      CASE WHEN p.estado ='5' THEN CAST(p.last_upd AS timestamp) ELSE NULL END fecha_rfb_dt, 
      CAST(p.created AS timestamp) fecha_venta_id, c.canal_agrupado1_ds canal_alta_ds, c.subcanal_ds, c.canal_agrupado2_ds tipo_canal_alta_ds,
      c.distribuidor_ds nombre_distribuidor_alta_ds, emp.attrib_07 agente_alta_id , emp.attrib_07 agente_creador_id, catalogo.categoria_servicio_ds, ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds,
      CASE WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION' WHEN (CAST(cli_x.fecha_ultimo_cambio AS date)>p.created AND cli_x.es_cartera='Y') THEN 'CAPTACION'
        ELSE CASE  WHEN cli_x.es_cartera = 'Y' THEN 'CARTERA'  ELSE 'CAPTACION'END
      END marca_cartera_ds,
      CAST(cli_x.fecha_ultimo_cambio AS timestamp) Antiguedad_Cliente, c.equipo_ds, CASE WHEN m.codprov IN (15, 27, 32, 36) OR m.codprov IS NULL THEN 'BAU' ELSE 'EXPANSION' END territorio_ds,
      catalogo.tecnologia_detalle_ds, 0 portabilidad_in_lg, 0 gb, 
      /*exp.row_id, pr.IDCONTRATO,NULL,'',NULL,'',NULL,catalogo_id, 5 as grid*/ 
      p.IDEXPEDIENTE expediente_id, exp.row_id expediente_padre_id, NULL contrato_id,''tipo_pedido_ds
 ,NULL pedido_id ,''tipo_producto_pedido_re_ds,NULL visibilidad_pedido_lg,catalogo_id, 8 as grid 
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr ON p.idproductonew=pr.idproducto 
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x ON exp_x.row_id=p.idcontrato
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp  ON exp.row_id=exp_x.row_id
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp ON exp.owner_emp_id=emp.row_id
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x ON cli_x.row_id=exp.CST_OU_ID
    INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo 
    ON catalogo.adicional_lg = 0 AND catalogo.tipo_identificacion_ds = 'PROMOCION'  AND catalogo.marca_ds = 'R' AND pr.CODIGO = catalogo.catalogo_id
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



    /* PASO 2 - APLICO PROMOCIONES A SERVICIOS DESCUBIERTOS */
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0108_VENTAS_CAPTACION_INCR` AS 
    select v.marca_ds, v.cliente_id, v.servicio_id, p.* except (marca_ds, cliente_id, servicio_id)
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0108_PROMOCIONES` p
    inner join `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
    on p.marca_ds=v.marca_ds and p.cliente_id=v.cliente_id and p.categoria_servicio_ds=v.categoria_servicio_ds and p.tecnologia_detalle_ds=v.tecnologia_detalle_ds and p.expediente_padre_id=v.expediente_padre_id and p.expediente_id=v.expediente_id
    where v.grid<5;



    /* PASO 3 - INSERTO EN VENTAS_CAPTACION */
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0108_VENTAS_CAPTACION_INCR`;



    /* PASO 4 - GENERO LOG DE VENTAS CAPTACION */
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0108_VENTAS_CAPTACION` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;


END