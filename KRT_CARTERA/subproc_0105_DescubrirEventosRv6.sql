BEGIN

  --Call `mm-commissions-reporting.KRT_CARTERA.subproc_0105_DescubrirEventosRv4`(20250801, 20250831)

  DECLARE DESDE DATE;
  DECLARE HASTA DATE;

  -- VAR LOCAL
  --DECLARE DESDE_INT INT64;DECLARE HASTA_INT INT64;SET DESDE_INT=20251001;SET HASTA_INT=20251031;    


  SET DESDE = PARSE_DATE('%Y%m%d', CAST(DESDE_INT AS STRING));
  SET HASTA = PARSE_DATE('%Y%m%d', CAST(HASTA_INT AS STRING));

  --- 20251107 Se introduce condición para modificar el valor del campo TipoMovimiento
  ---   Se incluye en la lógica las variables relativas a entidad anterior y entidad nueva. 
  ---   Hasta la fecha se consideraban cambios a aquellos casos en los que el flujo es de alta y el dato de producto origen está informado
  ---   Ahora 
  ---         se consideran  cambios a aquellos casos en los que el flujo es de alta, el dato de producto origen está informado y el catálogo del producto origen y destino es distinto
  ---         se consideran  altas  a aquellos casos en los que el flujo es de alta, el dato de producto origen está informado y el catálogo del producto origen y destino son el mismo
  ---   De este modo, en contingencia, se aplica este cambio. Se va a mejorar incluyendo un control adicional, basado en el estado del flujo previo, y que su estado no sea "Finalizado"

  ---   Cambio introducido en linea 111

  -- =========================================================
  -- CTE 1: Eventos de producto no terminal
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR51` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    SELECT
        pr.codigo_empresa_bi AS marca_ds,
        CAST(p.idcliente AS INT64) AS cliente_id,
        COALESCE(CAST(pr.IDINTERNO AS INT64),
                 CAST(REGEXP_REPLACE(pr.idexterno,'[^0-9 ]','') AS INT64),
                 ROW_NUMBER() OVER (PARTITION BY p.idcliente)) AS ID,
        p.idcontrato,
        p.idexpediente,
        pr_origen.accion AS accionentidadanterior,
        pr_origen.codigo AS entidadanterior,
        pr_origen.descripcion AS descripcionentidadanterior,
        pr.accion AS accionentidad,
        pr.codigo AS entidadnueva,
        pr.descripcion AS descripcionentidadnueva,
        CASE WHEN p.estado='5'
             THEN (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD))
             ELSE NULL END AS FECHA_RFB_ID,
        (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_VENTA_NETA_ID,
        CASE WHEN p.estado='5' THEN CAST(p.last_upd AS TIMESTAMP) ELSE NULL END AS fecha_rfb_dt,
        CAST(p.created AS TIMESTAMP) AS fecha_venta_id,
        c.canal_agrupado1_ds,
        c.subcanal_ds,
        c.canal_agrupado2_ds,
        c.distribuidor_ds,
        REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS agente_venta,
        ci.cif_nif,
        ci.segmento_ds,
        ci.subsegmento_ds,
        exp_x.attrib_35 AS medio_conocimiento,
        
        CASE      
          --- Si el cliente no tiene informado marca_cartera es captación
          WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
          --- Si la fecha del último cambio de tramo del cliente es posterior a la creación del contrato, y la variable es_cartera tiene valor "Y" entonces es captación
          WHEN (CAST(cli_x.fecha_ultimo_cambio AS DATE) > CAST(exp.created AS DATE) AND cli_x.es_cartera='Y') THEN 'CAPTACION'
          --- Si la fecha del último cambio de tramo del cliente es anterior o la variable es_cartera toma un valor distinto a "Y"m entonces:
          ELSE CASE
                --- Si la variable es_cartera toma el valor 'Y' y la clasificación del tramo es distinto de "SOMO  e "INACTIVO" (es decir, sólo puede ser "SF") entonces se considera cartera
                 WHEN cli_x.es_cartera='Y' AND (est_cli.clasificacion_ds<>'SOMO' AND est_cli.clasificacion_ds<>'INACTIVO') THEN 'CARTERA' 
                --- Si la variable es_cartera toma el valor 'Y' y la clasificación del tramo es "SOMO  y el subtipo del expediente es "MOVIL" entonces se considera cartera                 
                 WHEN cli_x.es_cartera='Y' AND est_cli.clasificacion_ds='SOMO'   AND exp.X_R_SUBTIPO2='MOVIL' THEN 'CARTERA'
                 --- En caso contrario se considera captación 
                 ELSE 'CAPTACION'
               END
        END AS es_cartera,
       --`mm-commissions-reporting.KRT_CARTERA.f_ctx_crea_marca_cartera_producto`(pr.codigo_empresa_bi, CAST(p.idcliente AS INT64), CASE WHEN p.estado='5' THEN EXTRACT( DATE FROM p.last_upd) ELSE NULL END) AS es_cartera,
        /*
        CASE
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO' and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'                   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO' THEN 'CARTERA'            
        END AS es_cartera,
        */
        c.equipo_ds,
        CASE p.estado
          WHEN '1' THEN 'En configuración'
          WHEN '2' THEN 'Enviando a provisión'
          WHEN '3' THEN 'En provisión'
          WHEN '4' THEN 'Enviando a facturación'
          WHEN '5' THEN 'Finalizado'
          WHEN '6' THEN 'Cancelado'
        END AS estado_proceso,
        CASE WHEN p.estado='5' THEN FORMAT_DATE('%Y%m', p.LAST_UPD) ELSE NULL END AS periodorfb,
        FORMAT_DATE('%Y%m', exp.CREATED) AS periodoventa,
        CASE WHEN pr.accion='Baja' THEN 'Baja'
             WHEN pr_origen.accion='Baja' THEN 'Modificacion'
             ELSE 'Alta' END AS accion,
        mst_pro.concepto,
        concepto_origen,
        cli_x.fecha_ultimo_cambio,
        CAST(ID_ORIGEN AS INT64) AS ID_ORIGEN,
        pr_origen.tipoProducto AS TipoProductoOrigen,
        pr_origen.tipo_movimiento AS subTipoProductoOrigen,
        CASE
          WHEN pr.accion='Alta' AND pr_origen.tipoProducto IS NULL THEN CONCAT('Alta ', mst_pro.tipo_movimiento)
          --- MODIFICACION v6
          -- WHEN pr.accion='Alta' AND pr_origen.tipoProducto IS NOT NULL THEN CONCAT('Cambio ', mst_pro.tipo_movimiento)
          WHEN pr.accion='Alta' AND pr_origen.tipoProducto IS NOT NULL AND UPPER(TRIM(pr_origen.codigo))!=UPPER(TRIM(pr.codigo)) THEN CONCAT('Cambio ', mst_pro.tipo_movimiento)
          WHEN pr.accion='Alta' AND pr_origen.tipoProducto IS NOT NULL AND UPPER(TRIM(pr_origen.codigo))=UPPER(TRIM(pr.codigo)) THEN CONCAT('Alta ', mst_pro.tipo_movimiento)          
          --- FIN MODIFICACION v6
          WHEN pr.accion IN ('Modificación','Modificacion') AND pr_origen.tipoProducto IS NOT NULL THEN CONCAT('Cambio ', mst_pro.tipo_movimiento)
          WHEN pr.accion IN ('Modificación','Modificacion') AND pr_origen.tipoProducto IS NULL THEN CONCAT('Alta ', mst_pro.tipo_movimiento)
        END AS tipo_movimiento,
        mst_pro.tipoProducto AS TipoProducto,
        mst_pro.tipo_movimiento AS subTipoProducto,
        pr.idold,
        pr_origen.tipoentidad AS tipoentidad_origen,
        pr.tipoentidad,
        CASE WHEN pr.tipoentidad=pr_origen.tipoentidad THEN 1 ELSE 0 END AS bmismaentidad,
        CASE WHEN pr.idold=pr_origen.row_id THEN 1 ELSE 0 END AS bencadenado,
        51 AS grid
    FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro
    JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr
      ON pr.codigo=mst_pro.IdProdCat
    JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
      ON p.idproductonew=pr.idproducto
    JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x
      ON exp_x.row_id=p.idcontrato
    JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
      ON exp.row_id=exp_x.row_id
    JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
      ON exp.owner_emp_id=emp.row_id
    JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
      ON c.agente_venta_id = CAST(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS INT64)
    JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci
      ON ci.cliente_id = CAST(p.idcliente AS INT64) AND ci.marca_ds='R'
    JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x
      ON cli_x.row_id=exp.CST_OU_ID

     --- Tramo de creación de expediente (Tramo que finaliza al activar el servicio). 
     ---    Fecha de creación de contrato
     ---        Igual o posterior a fecha de inicio de tramo  
     ---        Igual o anterior  a fecha de fin de tramo

    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli
      ON CAST(p.idcliente AS INT64)=est_cli.cliente_id AND est_cli.marca_ds='R'
     --AND DATE(desde_dt) <= DATE(exp.created) 
      AND DATE(desde_dt) < DATE(exp.created)      
      AND DATE(hasta_dt) >= DATE(exp.created)
 
    /*
     --- Tramo pre (Tramo que finaliza al activar el servicio). 
     ---    Fecha de activación 
     ---        Posterior a fecha de inicio de tramo  
     ---        Igual a fecha de fin de tramo

    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pre
      ON cli_tramo_pre.marca_ds = pr.codigo_empresa_bi
     AND cli_tramo_pre.cliente_id = CAST(p.idcliente AS INT64)
     AND EXTRACT(DATE FROM cli_tramo_pre.desde_dt) <  EXTRACT(DATE FROM p.last_upd)
     AND EXTRACT(DATE FROM cli_tramo_pre.hasta_dt) >= EXTRACT(DATE FROM p.last_upd)

     --- Tramo pos.
     --- Tramo pos (Tramo que comienza al activar el servicio).  
     ---    Fecha de activación 
     ---        Igual    a fecha de inicio de tramo      
     ---        Anterior a fecha de fin de tramo


    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pos
      ON cli_tramo_pos.marca_ds = pr.codigo_empresa_bi
     AND cli_tramo_pos.cliente_id = CAST(p.idcliente AS INT64)
     AND EXTRACT(DATE FROM cli_tramo_pos.desde_dt) <=  EXTRACT(DATE FROM p.last_upd)
     AND EXTRACT(DATE FROM cli_tramo_pos.hasta_dt) > EXTRACT(DATE FROM p.last_upd)

    */

    LEFT JOIN (
          SELECT
            pr_old.idproducto,
            pr_old.accion,
            pr_old.codigo,
            pr_old.descripcion,
            mst_pro_old.tipoProducto,
            mst_pro_old.tipo_movimiento,
            pr_old.idInterno,
            mst_pro_old.concepto AS concepto_origen,
            pr_old.IDINTERNO AS ID_ORIGEN,
            pr_old.row_id,
            pr_old.tipoentidad
          FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old
          JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old
            ON p_old.IDPRODUCTOOLD=pr_old.idproducto
          JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro_old
            ON mst_pro_old.marca_ds='R' AND pr_old.codigo=mst_pro_old.idProdCat
          WHERE CAST(p_old.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA
    ) pr_origen
      ON p.idproductoold=pr_origen.idproducto
     AND pr_origen.tipo_movimiento = mst_pro.tipo_movimiento
     AND pr_origen.tipoProducto    = mst_pro.tipoProducto
     AND pr_origen.idProducto     <> p.idProductoNew
    WHERE mst_pro.marca_ds='R'
      AND UPPER(TRIM(mst_pro.tipoProducto)) not in ('TERMINAL',"DISPOSITIVO")
      AND (CONTAINS_SUBSTR(pr.accion,'alta') OR CONTAINS_SUBSTR(pr.accion,'modifica'))
      AND ((p.vigente='Y' AND p.estado IN ('2','3','4')) OR p.estado IN ('5','6'))
      AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos','Colaborador')
      AND exp.SR_SUBTYPE_CD<>'TRASLADO'
      AND exp.X_R_SUBTIPO2<>'TRASLADO'
      AND p.operacion NOT IN ('SUSTITUCION TERMINAL DOA','BAJA')
      AND NOT CONTAINS_SUBSTR(p.operacion,'TEMPORAL')
      AND NOT CONTAINS_SUBSTR(p.operacion,'MOROSO')    

      ---================================================
      --- VERSION 10
      --- ELIMINO 
      --- AND CAST(p.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA 
      --- INSERTO
      AND ((CAST(p.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA) OR (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED) BETWEEN DESDE_INT AND HASTA_INT))
      ---================================================

      AND (pr.idInterno <> pr_Origen.idInterno OR pr_Origen.idInterno IS NULL)
      AND NOT EXISTS (
        SELECT 1
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2
        JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2
          ON pra2.identidad=pr2.row_id
        JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
          ON pr2.idproducto=p2.idproductonew
        WHERE p2.idproductonew=p.idproductonew
          AND pra2.atributo='Atajo'
          AND pra2.valor IN ('SI','SÍ','si','sí')
      )
      AND NOT (CONTAINS_SUBSTR(pr.tipoentidad,'PROMOCION'));

  -- =========================================================
  -- CTE 2: Eventos de equipamietno movil (terminal = Alta) 
  -- =========================================================


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR52` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    SELECT
      pr.codigo_empresa_bi AS marca_ds,
      CAST(p.idcliente AS INT64) AS cliente_id,
      CAST(pr.IDINTERNO AS INT64) AS ID,
      p.idcontrato,
      p.idexpediente,
      "" AS accionentidadanterior,
      "" AS entidadanterior,
      "" AS descripcionentidadanterior,
      pr.accion AS accionentidad,
      pr.codigo AS entidadnueva,
      pr.descripcion AS descripcionentidadnueva,
      CASE WHEN p.estado='5'
           THEN (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD))
           ELSE NULL END AS FECHA_RFB_ID,
      (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_VENTA_NETA_ID,
      CASE WHEN p.estado='5' THEN CAST(p.last_upd AS TIMESTAMP) ELSE NULL END AS fecha_rfb_dt,
      CAST(p.created AS TIMESTAMP) AS fecha_venta_id,
      c.canal_agrupado1_ds,
      c.subcanal_ds,
      c.canal_agrupado2_ds,
      c.distribuidor_ds,
      REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS agente_venta,
      ci.cif_nif,
      ci.segmento_ds,
      ci.subsegmento_ds,
      exp_x.attrib_35 AS medio_conocimiento,
      
      CASE
        WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
        WHEN (CAST(cli_x.fecha_ultimo_cambio AS DATE) > CAST(exp.created AS DATE) AND cli_x.es_cartera='Y') THEN 'CAPTACION'
        ELSE CASE
               WHEN cli_x.es_cartera='Y' AND (est_cli.clasificacion_ds<>'SOMO' AND est_cli.clasificacion_ds<>'INACTIVO') THEN 'CARTERA'
               WHEN cli_x.es_cartera='Y' AND est_cli.clasificacion_ds='SOMO' AND exp.X_R_SUBTIPO2='MOVIL' THEN 'CARTERA'
               ELSE 'CAPTACION'
             END
      END  AS es_cartera,
      
      --`mm-commissions-reporting.KRT_CARTERA.f_ctx_crea_marca_cartera_producto`(pr.codigo_empresa_bi, CAST(p.idcliente AS INT64), CASE WHEN p.estado='5' THEN EXTRACT(DATE FROM p.last_upd) ELSE NULL END)  
      --AS es_cartera,

      /*  
        CASE
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO' and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'                   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO' THEN 'CARTERA'            
        END AS es_cartera,
      */
      c.equipo_ds,
      CASE p.estado
        WHEN '1' THEN 'En configuración'
        WHEN '2' THEN 'Enviando a provisión'
        WHEN '3' THEN 'En provisión'
        WHEN '4' THEN 'Enviando a facturación'
        WHEN '5' THEN 'Finalizado'
        WHEN '6' THEN 'Cancelado'
      END AS estado_proceso,
      CASE WHEN p.estado='5' THEN FORMAT_DATE('%Y%m', p.LAST_UPD) ELSE NULL END AS periodorfb,
      FORMAT_DATE('%Y%m', exp.CREATED) AS periodoventa,
      CASE WHEN pr.accion='Baja' THEN 'Baja' ELSE 'Alta' END AS accion,
      mst_pro.concepto,
      "" AS concepto_origen,
      cli_x.fecha_ultimo_cambio,
      NULL AS ID_ORIGEN,
      pr_origen.tipoProducto  AS TipoProductoOrigen,
      pr_origen.tipo_movimiento  AS subTipoProductoOrigen,
      CASE
        WHEN pr.accion='Alta' THEN CONCAT('Alta ', mst_pro.tipo_movimiento)
        WHEN pr.accion IN ('Modificación','Modificacion') THEN CONCAT('Cambio ', mst_pro.tipo_movimiento)
      END AS tipo_movimiento,
      mst_pro.tipoProducto,
      mst_pro.tipo_movimiento AS subTipoProducto,
      CAST(NULL AS STRING) as idold,
      CAST(NULL AS STRING) as tipoentidad_origen,
      pr.tipoentidad,
      NULL as bmismaentidad,
      NULL as bencadenado,
      52 AS grid
  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr
    ON pr.codigo=mst_pro.IdProdCat
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
    ON p.idproductonew=pr.idproducto
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x
    ON exp_x.row_id=p.idcontrato
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
    ON exp.row_id=exp_x.row_id
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
    ON exp.owner_emp_id=emp.row_id
  JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
    ON c.agente_venta_id = CAST(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS INT64)
  JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci
    ON ci.cliente_id = CAST(p.idcliente AS INT64) AND ci.marca_ds='R'
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x
    ON cli_x.row_id=exp.CST_OU_ID
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli
    ON CAST(p.idcliente AS INT64)=est_cli.cliente_id AND est_cli.marca_ds='R'
   --AND DATE(desde_dt) <= DATE(exp.created) 
    --AND DATE(hasta_dt) > DATE(exp.created)
    AND DATE(desde_dt) <  DATE(exp.created)   
    AND DATE(hasta_dt) >= DATE(exp.created)

  /* 
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pre
    ON cli_tramo_pre.marca_ds = pr.codigo_empresa_bi
    AND cli_tramo_pre.cliente_id = CAST(p.idcliente AS INT64)
    AND EXTRACT(DATE FROM cli_tramo_pre.desde_dt) < EXTRACT(DATE FROM p.last_upd)
    AND EXTRACT(DATE FROM cli_tramo_pre.hasta_dt) >= EXTRACT(DATE FROM p.last_upd)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pos
    ON cli_tramo_pos.marca_ds = pr.codigo_empresa_bi
    AND cli_tramo_pos.cliente_id = CAST(p.idcliente AS INT64)
    AND EXTRACT(DATE FROM cli_tramo_pos.desde_dt) <=  EXTRACT(DATE FROM p.last_upd)
    AND EXTRACT(DATE FROM cli_tramo_pos.hasta_dt) > EXTRACT(DATE FROM p.last_upd)
  */

  LEFT JOIN (
        SELECT
          pr_old.idproducto,
          pr_old.accion,
          pr_old.codigo,
          pr_old.descripcion,
          mst_pro_old.tipoProducto,
          mst_pro_old.tipo_movimiento,
          pr_old.idInterno,
          mst_pro_old.concepto AS concepto_origen,
          pr_old.IDINTERNO AS ID_ORIGEN,
          pr_old.row_id,
          pr_old.tipoentidad
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old
        JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old
          ON p_old.IDPRODUCTOOLD=pr_old.idproducto
        JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro_old
          ON mst_pro_old.marca_ds='R' AND pr_old.codigo=mst_pro_old.idProdCat
        WHERE CAST(p_old.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA
  ) pr_origen
    ON p.idproductoold=pr_origen.idproducto
   AND pr_origen.tipo_movimiento = mst_pro.tipo_movimiento
   AND pr_origen.tipoProducto    = mst_pro.tipoProducto
   AND pr_origen.idProducto     <> p.idProductoNew
  WHERE mst_pro.marca_ds='R'
    AND UPPER(TRIM(mst_pro.tipoProducto)) in ('TERMINAL',"DISPOSITIVO")
    AND pr.accion='Alta'
    AND ((p.vigente='Y' AND p.estado IN ('2','3','4')) OR p.estado IN ('5','6'))
    AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos','Colaborador')
    AND exp.SR_SUBTYPE_CD<>'TRASLADO'
    AND exp.X_R_SUBTIPO2<>'TRASLADO'
    AND p.operacion NOT IN ('SUSTITUCION TERMINAL DOA','BAJA')
    AND NOT CONTAINS_SUBSTR(p.operacion,'TEMPORAL')
    AND NOT CONTAINS_SUBSTR(p.operacion,'MOROSO')

    ---================================================
    --- VERSION 10
    --- ELIMINO 
    --- AND CAST(p.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA 
    --- INSERTO
    AND ((CAST(p.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA) OR (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED) BETWEEN DESDE_INT AND HASTA_INT))
    ---================================================

    AND NOT EXISTS (
      SELECT 1
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2
      JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2
        ON pra2.identidad=pr2.row_id
      JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
        ON pr2.idproducto=p2.idproductonew
      WHERE p2.idproductonew=p.idproductonew
        AND pra2.atributo='Atajo'
        AND pra2.valor IN ('SI','SÍ','si','sí')
    );


  -- =========================================================
  -- CTE 3: Promos Sva (alta directa SV)
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR53` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    SELECT
    'R' AS marca_ds,
    CAST(cli.ou_num AS INT64) AS cliente_id,
    CAST(sgvpromo.idproducto AS INT64) AS ID,
    sgvpromo.idexpediente AS idcontrato,
    sgvpromo.idexpediente AS idexpediente,
    "" AS accionentidadanterior,
    "" AS entidadanterior,
    "" AS descripcionentidadanterior,
    'Alta' AS accionentidad,
    sgvpromo.codigopromo AS entidadnueva,
    mst_pro.nombreProducto AS descripcionentidadnueva,
    (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_RFB_ID,
    (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_VENTA_NETA_ID,
    CAST(sgvpromo.FECEFECTIVA AS TIMESTAMP) AS fecha_rfb_dt,
    CAST(exp.CREATED AS TIMESTAMP) AS fecha_venta_id,
    c.canal_agrupado1_ds,
    c.subcanal_ds,
    c.canal_agrupado2_ds,
    c.distribuidor_ds,
    REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS agente_venta,
    ci.cif_nif,
    ci.segmento_ds,
    ci.subsegmento_ds,
    exp_x.attrib_35 AS medio_conocimiento,
    CASE
      WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
      WHEN (CAST(cli_x.fecha_ultimo_cambio AS DATE) > CAST(exp.created AS DATE) AND cli_x.es_cartera='Y') THEN 'CAPTACION'
      ELSE CASE WHEN cli_x.es_cartera='Y' THEN 'CARTERA' ELSE 'CAPTACION' END
    END AS es_cartera, 


    --`mm-commissions-reporting.KRT_CARTERA.f_ctx_crea_marca_cartera_producto`('R', CAST(cli.ou_num AS INT64) , CASE WHEN p.estado='5' THEN EXTRACT(DATE FROM sgvpromo.FECEFECTIVA) ELSE NULL END)    
    --AS es_cartera,
    /*
        CASE
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO' and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'                   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO' THEN 'CARTERA'            
        END AS es_cartera,
    */
    c.equipo_ds,
    'Finalizado' AS estado_proceso,
    FORMAT_DATE('%Y%m', exp.CREATED) AS periodorfb,
    FORMAT_DATE('%Y%m', exp.CREATED) AS periodoventa,
    'Alta' AS accion,
    mst_pro.concepto,
    "" AS concepto_origen,
    cli_x.fecha_ultimo_cambio,
    NULL AS ID_ORIGEN,
    mst_pro2.tipoProducto AS TipoProductoOrigen,
    mst_pro2.tipo_movimiento AS subTipoProductoOrigen,
    CONCAT('Alta ', mst_pro.tipo_movimiento) AS tipo_movimiento,
    mst_pro.tipoProducto AS TipoProducto,
    mst_pro.tipo_movimiento AS subTipoProducto,
    CAST(NULL AS STRING) AS idold,
    CAST(NULL AS STRING) AS tipoentidad_origen,
    'PROMOCION' AS tipoentidad,
    NULL AS bmismaentidad,
    NULL AS bencadenado,
    53 AS grid
  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo
  LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
    ON sgvpromo.idexpediente=exp.row_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
    ON exp.owner_emp_id=emp.row_id
  JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
    ON c.agente_venta_id = CAST(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS INT64)
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli
    ON cli.row_id=exp.CST_OU_ID
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x
    ON cli.row_id=cli_x.row_id
  JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci
    ON ci.cliente_id = CAST(cli.ou_num AS INT64) AND ci.marca_ds='R'
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x
    ON exp.row_id=exp_x.row_id
  JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro
    ON mst_pro.marca_ds='R' AND sgvpromo.codigopromo=mst_pro.IdProdCat AND mst_pro.tipoProducto IN ('SVA')
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo2
    ON sgvpromo.idproducto=sgvpromo2.idproducto
   AND DATE_TRUNC(CAST(sgvpromo.FECEFECTIVA AS DATE), DAY)-1 = DATE_TRUNC(CAST(sgvpromo2.FECEXPIRACION AS DATE), DAY)
  LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro2
    ON mst_pro2.marca_ds='R' AND sgvpromo2.codigopromo=mst_pro2.idProdCat AND mst_pro2.tipoProducto IN ('SVA')
  /*  
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pre
      ON cli_tramo_pre.marca_ds = 'R'
     AND cli_tramo_pre.cliente_id = CAST(cli.ou_num AS INT64)
     AND EXTRACT(DATE FROM cli_tramo_pre.desde_dt) < EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
     AND EXTRACT(DATE FROM cli_tramo_pre.hasta_dt) >= EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pos
      ON cli_tramo_pos.marca_ds = 'R'
     AND cli_tramo_pos.cliente_id = CAST(cli.ou_num AS INT64)
     AND EXTRACT(DATE FROM cli_tramo_pos.desde_dt) <=  EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
     AND EXTRACT(DATE FROM cli_tramo_pos.hasta_dt) > EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
  */

  ---================================================
  --- VERSION 10
  --- ELIMINO 
  --- WHERE DATE_TRUNC(CAST(sgvpromo.FECEFECTIVA AS DATE), DAY) BETWEEN DESDE AND HASTA
  --- INSERTO
  WHERE ((DATE_TRUNC(CAST(sgvpromo.FECEFECTIVA AS DATE), DAY) BETWEEN DESDE AND HASTA) OR (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED) BETWEEN DESDE_INT AND HASTA_INT))
  ---================================================

    AND sgvpromo.codigopromo IS NOT NULL
    AND exp.sr_type_cd='CONTRATO'
    AND sgvpromo.codigocargo IS NOT NULL
    AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos','Colaborador')
    AND NOT EXISTS (
      SELECT 1
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
      WHERE p.idcontrato=sgvpromo.idexpediente
    );



  -- =========================================================
  -- CTE 4: Cambios de tarifa móvil (sin VOA)
  -- =========================================================
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR54` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS  
    SELECT
    'R' AS marca_ds,
    CAST(cli.ou_num AS INT64) AS cliente_id,
    CAST(sgvpromo.idproducto AS INT64) AS ID,
    sgvpromo.idexpediente AS idcontrato,
    sgvpromo.idexpediente AS idexpediente,
    'Baja' AS accionentidadanterior,
    sgvpromo2.codigopromo AS entidadanterior,
    mst_pro2.nombreProducto AS descripcionentidadanterior,
    'Alta' AS accionentidad,
    sgvpromo.codigopromo AS entidadnueva,
    mst_pro.nombreProducto AS descripcionentidadnueva,
    (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_RFB_ID,
    (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_VENTA_NETA_ID,
    CAST(sgvpromo.FECEFECTIVA AS TIMESTAMP) AS fecha_rfb_dt,
    CAST(exp.CREATED AS TIMESTAMP) AS fecha_venta_id,
    c.canal_agrupado1_ds,
    c.subcanal_ds,
    c.canal_agrupado2_ds,
    c.distribuidor_ds,
    REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS agente_venta,
    ci.cif_nif,
    ci.segmento_ds,
    ci.subsegmento_ds,
    exp_x.attrib_35 AS medio_conocimiento,
    
    CASE
      WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
      WHEN (CAST(cli_x.fecha_ultimo_cambio AS DATE) > CAST(exp.created AS DATE) AND cli_x.es_cartera='Y') THEN 'CAPTACION'
      ELSE CASE WHEN cli_x.es_cartera='Y' THEN 'CARTERA' ELSE 'CAPTACION' END
    END  AS es_cartera,
    --`mm-commissions-reporting.KRT_CARTERA.f_ctx_crea_marca_cartera_producto`('R', CAST(cli.ou_num AS INT64) , CASE WHEN p.estado='5' THEN EXTRACT(DATE FROM sgvpromo.FECEFECTIVA) ELSE NULL END)    
    --AS es_cartera,
    /*
    CASE
        WHEN cli_tramo_pre.clasificacion_ds = 'SF' THEN 'CARTERA'
        WHEN (cli_tramo_pre.clasificacion_ds = 'POSPAGO') and cli_tramo_pos.clasificacion_ds = 'SF' THEN 'CAPTACION'
        WHEN (cli_tramo_pre.clasificacion_ds = 'POSPAGO') and cli_tramo_pos.clasificacion_ds != 'SF' THEN 'CARTERA'
        WHEN (cli_tramo_pre.clasificacion_ds = 'INACTIVO' OR cli_tramo_pre.clasificacion_ds = 'SOMO' ) and cli_tramo_pos.clasificacion_ds = 'SF' THEN 'CAPTACION'
        WHEN (cli_tramo_pre.clasificacion_ds = 'INACTIVO' OR cli_tramo_pre.clasificacion_ds = 'SOMO' ) and cli_tramo_pos.clasificacion_ds != 'SF' THEN 'CARTERA'                  
        ELSE 'CARTERA'
    END AS es_cartera,
    */
    /*
        CASE
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO' and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'                   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO' THEN 'CARTERA'            
        END AS es_cartera,
    */
    c.equipo_ds,
    'Finalizado' AS estado_proceso,
    FORMAT_DATE('%Y%m', exp.CREATED) AS periodorfb,
    FORMAT_DATE('%Y%m', exp.CREATED) AS periodoventa,
    'Modificacion' AS accion,
    mst_pro.concepto,
    mst_pro2.concepto AS concepto_origen,
    cli_x.fecha_ultimo_cambio,
    CAST(sgvpromo2.idproducto AS INT64) AS ID_ORIGEN,
    mst_pro2.tipoProducto AS TipoProductoOrigen,
    mst_pro2.tipo_movimiento AS subTipoProductoOrigen,
    CONCAT('Cambio ', mst_pro.tipo_movimiento) AS tipo_movimiento,
    mst_pro.tipoProducto AS TipoProducto,
    mst_pro.tipo_movimiento AS subTipoProducto,
    CAST(NULL AS STRING) AS idold,
    CAST(NULL AS STRING) AS tipoentidad_origen,
    'PROMOCION' AS tipoentidad,
    NULL AS bmismaentidad,
    NULL AS bencadenado,
    54 AS grid
  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo
  LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
    ON sgvpromo.idexpediente=exp.row_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
    ON exp.owner_emp_id=emp.row_id
  JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
    ON c.agente_venta_id = CAST(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS INT64)
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli
    ON cli.row_id=exp.CST_OU_ID
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x
    ON cli.row_id=cli_x.row_id
  JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci
    ON ci.cliente_id = CAST(cli.ou_num AS INT64) AND ci.marca_ds='R'
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x
    ON exp.row_id=exp_x.row_id
  JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro
    ON mst_pro.marca_Ds='R' AND sgvpromo.codigopromo=mst_pro.idProdCat AND mst_pro.tipoProducto IN ('Móvil')
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo2
    ON sgvpromo.idproducto=sgvpromo2.idproducto
   AND DATE_TRUNC(CAST(sgvpromo.FECEFECTIVA AS DATE), DAY)-1 = DATE_TRUNC(CAST(sgvpromo2.FECEXPIRACION AS DATE), DAY)
  LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro2  
    ON mst_pro2.marca_ds='R' AND sgvpromo2.codigopromo=mst_pro2.idProdCat AND mst_pro2.tipoProducto IN ('Móvil')
  
  /*
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pre
      ON cli_tramo_pre.marca_ds = 'R'
     AND cli_tramo_pre.cliente_id = CAST(cli.ou_num AS INT64)
     AND EXTRACT(DATE FROM cli_tramo_pre.desde_dt) < EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
     AND EXTRACT(DATE FROM cli_tramo_pre.hasta_dt) >= EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pos
      ON cli_tramo_pos.marca_ds = 'R'
     AND cli_tramo_pos.cliente_id = CAST(cli.ou_num AS INT64)
     AND EXTRACT(DATE FROM cli_tramo_pos.desde_dt) <=  EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
     AND EXTRACT(DATE FROM cli_tramo_pos.hasta_dt) > EXTRACT(DATE FROM sgvpromo.FECEFECTIVA)
  */


  ---================================================
  --- VERSION 10
  --- ELIMINO 
  --- WHERE DATE_TRUNC(CAST(sgvpromo.FECEFECTIVA AS DATE), DAY) BETWEEN DESDE AND HASTA
  --- INSERTO
  WHERE ((DATE_TRUNC(CAST(sgvpromo.FECEFECTIVA AS DATE), DAY) BETWEEN DESDE AND HASTA) OR (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED) BETWEEN DESDE_INT AND HASTA_INT))
  ---================================================


    AND sgvpromo.codigopromo IS NOT NULL
    AND exp.sr_type_cd='CONTRATO'
    AND sgvpromo.codigocargo IS NOT NULL
    AND sgvpromo2.codigocargo IS NOT NULL
    AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos','Colaborador')
    AND NOT EXISTS (
      SELECT 1
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
      JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr
        ON p.idproductonew = pr.idProducto
      WHERE p.idcontrato=sgvpromo.idexpediente
        AND sgvpromo.codigoPromo = pr.codigo
        AND pr.accion = 'Alta'
    );



  -- =========================================================
  -- CTE 5: Identificadores de producto asociados a promos
  -- =========================================================
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR55` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS  
    SELECT DISTINCT
      pr.codigo_empresa_bi AS marca_ds,
      CAST(p.idcliente AS INT64) AS cliente_id,
      CAST(trpr.idproducto AS INT64) AS ID,
      p.idcontrato,
      p.idexpediente,
      pr_origen.accion AS accionentidadanterior,
      pr_origen.codigo AS entidadanterior,
      pr_origen.descripcion AS descripcionentidadanterior,
      pr.accion AS accionentidad,
      pr.codigo AS entidadnueva,
      pr.descripcion AS descripcionentidadnueva,
      CASE WHEN p.estado='5'
           THEN (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD))
           ELSE NULL END AS FECHA_RFB_ID,
      (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) AS FECHA_VENTA_NETA_ID,
      CASE WHEN p.estado='5' THEN CAST(p.last_upd AS TIMESTAMP) ELSE NULL END AS fecha_rfb_dt,
      CAST(p.created AS TIMESTAMP) AS fecha_venta_id,
      c.canal_agrupado1_ds,
      c.subcanal_ds,
      c.canal_agrupado2_ds,
      c.distribuidor_ds,
      REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS agente_venta,
      ci.cif_nif,
      ci.segmento_ds,
      ci.subsegmento_ds,
      exp_x.attrib_35 AS medio_conocimiento,
      
      CASE
        WHEN cli_x.es_cartera IS NULL THEN 'CAPTACION'
        WHEN (CAST(cli_x.fecha_ultimo_cambio AS DATE) > CAST(exp.created AS DATE) AND cli_x.es_cartera='Y') THEN 'CAPTACION'
        ELSE CASE
               WHEN cli_x.es_cartera='Y' AND (est_cli.clasificacion_ds<>'SOMO' AND est_cli.clasificacion_ds<>'INACTIVO') THEN 'CARTERA'
               WHEN cli_x.es_cartera='Y' AND est_cli.clasificacion_ds='SOMO'   AND exp.X_R_SUBTIPO2='MOVIL' THEN 'CARTERA'
               ELSE 'CAPTACION'
             END
      END  AS es_cartera, 

      --`mm-commissions-reporting.KRT_CARTERA.f_ctx_crea_marca_cartera_producto`(pr.codigo_empresa_bi, CAST(p.idcliente AS INT64), CASE WHEN p.estado='5' THEN EXTRACT(DATE FROM p.last_upd) ELSE NULL END) 
      --AS es_cartera,

      /*CASE
         WHEN cli_tramo_pre.clasificacion_ds = 'SF' THEN 'CARTERA'
         ELSE 'CAPTACION'
      END AS es_cartera,
      */

      /*
        CASE
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SF'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO' and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo<16 THEN 'CAPTACION'                   
           WHEN cli_tramo_pos.clasificacion_ds = 'SF' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO'  and cli_tramo_pre.clasificacion_pre_ds = 'INACTIVO'  and cli_tramo_pre.dias_tramo>=16 THEN 'CARTERA'
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'INACTIVO' THEN 'CAPTACION'           
           WHEN cli_tramo_pos.clasificacion_ds = 'SOMO' and cli_tramo_pos.clasificacion_pre_ds = 'SOMO' THEN 'CARTERA'            
        END AS es_cartera,
      */
      c.equipo_ds,
      CASE p.estado
        WHEN '1' THEN 'En configuración'
        WHEN '2' THEN 'Enviando a provisión'
        WHEN '3' THEN 'En provisión'
        WHEN '4' THEN 'Enviando a facturación'
        WHEN '5' THEN 'Finalizado'
        WHEN '6' THEN 'Cancelado'
      END AS estado_proceso,
      CASE WHEN p.estado='5' THEN FORMAT_DATE('%Y%m', p.LAST_UPD) ELSE NULL END AS periodorfb,
      FORMAT_DATE('%Y%m', exp.CREATED) AS periodoventa,
      CASE WHEN pr.accion='Baja' THEN 'Baja'
           WHEN pr_origen.accion='Baja' THEN 'Modificacion'
           ELSE 'Alta' END AS accion,
      mst_pro.concepto,
      concepto_origen,
      cli_x.fecha_ultimo_cambio,
      CAST(ID_ORIGEN AS INT64) AS ID_ORIGEN,
      pr_origen.tipoProducto AS TipoProductoOrigen,
      pr_origen.tipo_movimiento AS subTipoProductoOrigen,
      CASE
        WHEN pr.accion='Alta' AND pr_origen.tipoProducto IS NULL THEN CONCAT('Alta ', mst_pro.tipo_movimiento)
        WHEN pr.accion='Alta' AND pr_origen.tipoProducto IS NOT NULL THEN CONCAT('Cambio ', mst_pro.tipo_movimiento)
        WHEN pr.accion IN ('Modificación','Modificacion') AND pr_origen.tipoProducto IS NOT NULL THEN CONCAT('Cambio ', mst_pro.tipo_movimiento)
        WHEN pr.accion IN ('Modificación','Modificacion') AND pr_origen.tipoProducto IS NULL THEN CONCAT('Alta ', mst_pro.tipo_movimiento)
      END AS tipo_movimiento,
      mst_pro.tipoProducto AS TipoProducto,
      mst_pro.tipo_movimiento AS subTipoProducto,
      pr.idold,
      pr_origen.tipoentidad AS tipoentidad_origen,
      pr.tipoentidad,
      CASE WHEN pr.tipoentidad=pr_origen.tipoentidad THEN 1 ELSE 0 END AS bmismaentidad,
      CASE WHEN pr.idold=pr_origen.row_id THEN 1 ELSE 0 END AS bencadenado,
      55 AS grid
  FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr
    ON pr.idproducto=p.idproductonew
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x
    ON exp_x.row_id=p.idcontrato
  JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp
    ON exp.sr_num=exp_x.row_id
  JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro
    ON mst_pro.IdProdCat=pr.codigo
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp
    ON emp.row_id=exp.owner_emp_id
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x
    ON cli_x.row_id=exp.CST_OU_ID
  LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
    ON c.agente_venta_id = CAST(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') AS INT64)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci
    ON ci.cliente_id = CAST(p.idcliente AS INT64)
  LEFT JOIN (
        SELECT
          pr_old.idproducto,
          pr_old.accion,
          pr_old.codigo,
          pr_old.descripcion,
          mst_pro_old.tipoProducto,
          mst_pro_old.tipo_movimiento,
          pr_old.idInterno,
          mst_pro_old.concepto AS concepto_origen,
          pr_old.IDINTERNO AS ID_ORIGEN,
          pr_old.row_id,
          pr_old.tipoentidad
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old
        JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old
          ON p_old.IDPRODUCTOOLD=pr_old.idproducto
        JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro_old
          ON mst_pro_old.idProdCat=pr_old.codigo
        WHERE mst_pro_old.marca_ds='R'
          AND CAST(p_old.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA
  ) pr_origen
    ON p.idproductoold=pr_origen.idproducto
   AND pr_origen.tipo_movimiento = mst_pro.tipo_movimiento
   AND pr_origen.tipoProducto    = mst_pro.tipoProducto
   AND pr_origen.idProducto     <> p.idProductoNew
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli
    ON CAST(p.idcliente AS INT64)=est_cli.cliente_id
   AND est_cli.marca_ds='R'
   --AND DATE(desde_dt)<=DATE(exp.created)
   AND DATE(desde_dt) < DATE(exp.created)   
   AND DATE(hasta_dt)>= DATE(exp.created)
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` trpr
    ON trpr.idexpediente=p.idexpediente
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_servicio` trsrv
    ON CAST(trsrv.idproducto AS STRING)=p.idproductonew

  /*
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pre
    ON cli_tramo_pre.marca_ds = pr.codigo_empresa_bi
    AND cli_tramo_pre.cliente_id = CAST(p.idcliente AS INT64)
    AND EXTRACT(DATE FROM cli_tramo_pre.desde_dt) < EXTRACT(DATE FROM p.last_upd)
    AND EXTRACT(DATE FROM cli_tramo_pre.hasta_dt) >= EXTRACT(DATE FROM p.last_upd)   
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` cli_tramo_pos
    ON cli_tramo_pos.marca_ds = pr.codigo_empresa_bi
    AND cli_tramo_pos.cliente_id = CAST(p.idcliente AS INT64)
    AND EXTRACT(DATE FROM cli_tramo_pos.desde_dt) <=  EXTRACT(DATE FROM p.last_upd)
    AND EXTRACT(DATE FROM cli_tramo_pos.hasta_dt) > EXTRACT(DATE FROM p.last_upd)
  */
    
  WHERE mst_pro.marca_ds='R'
    AND mst_pro.tipoProducto<>'terminal'
    AND exp.SR_SUBTYPE_CD<>'TRASLADO'
    AND exp.X_R_SUBTIPO2<>'TRASLADO'
    AND (pr.idInterno <> pr_Origen.idInterno OR pr_Origen.idInterno IS NULL)
    AND pr.accion IN ('Alta','Modificacion','Modificación')
    AND p.operacion NOT IN ('SUSTITUCION TERMINAL DOA','BAJA')
    AND NOT CONTAINS_SUBSTR(p.operacion,'TEMPORAL')
    AND NOT CONTAINS_SUBSTR(p.operacion,'MOROSO')
    
    ---================================================
    --- VERSION 10
    --- ELIMINO 
    --- AND CAST(p.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA 
    --- INSERTO
    AND ((CAST(p.LAST_UPD AS DATE) BETWEEN DESDE AND HASTA) OR (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED) BETWEEN DESDE_INT AND HASTA_INT))
    ---================================================

    AND ((p.vigente='Y' AND p.estado IN ('2','3','4')) OR p.estado IN ('5','6'))
    AND ci.marca_ds='R'
    AND cli_x.attrib_43 IN ('Residencial','Microempresa','Ambos','Colaborador')
    AND NOT EXISTS (
      SELECT 1
      FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
      JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2
        ON pr2.idproducto=p2.idproductonew
      JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2
        ON pra2.identidad=pr2.row_id
      WHERE p2.idproductonew=p.idproductonew
        AND pra2.atributo='Atajo'
        AND pra2.valor IN ('SI','SÍ','si','sí')
    )
    AND CONTAINS_SUBSTR(pr.tipoentidad,'PROMOCION');


  -- =========================================================
  -- CTE 6: Crear tabla que integra eventos descubiertos 
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  with eventos_integrados as (
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR51`
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR52`
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR53`
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR54`
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_GR55`
  ) 
  select distinct *      
  from eventos_integrados;


  -- =========================================================
  -- CTE 7: Excluir cambios entre distintas entidades - Paso 2
  -- =========================================================

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_EXCLUIDOS` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) as 
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE`             
    WHERE bmismaentidad=0 and contains_substr(tipo_movimiento,'cambio');

    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE` where bmismaentidad=0 and contains_substr(tipo_movimiento,'cambio');


  -- =========================================================
  -- CTE 8: Crear tabla incremental - Paso 3
  -- =========================================================


     CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` 
     OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) as 
     select distinct 
      marca_ds,
      entidadNueva IdCatalogo, 
      descripcionentidadnueva NombreProducto, 
      distribuidor_ds nombre_distribuidor,  
      equipo_ds as equipo,
      canal_agrupado1_ds Canal,  
      subcanal_ds subcanal,  
      agente_venta agente, 
      cliente_id IdFijo, 
      cast(fecha_ultimo_cambio as date) Antiguedad, 
      cif_nif DNI_CIF,  
      es_cartera Marca_Cartera, 
      cast(FECHA_RFB_DT as Date) Fecha_Activacion, 
      CAST(fecha_venta_id as Date) Fecha_Creacion, 
      segmento_ds Segmento, 
      subsegmento_ds Subsegmento,
      entidadanterior, 
      ID_ORIGEN IdProductoOrigen, 
      descripcionentidadanterior NombreProductoOrigen, 
      /* AÑADIDO */
      TipoProducto,
      subTipoProducto,
      /* FIN AÑADIDO */
      Tipo_Movimiento, 
      /* AÑADIDO */
      TipoProductoOrigen,
      subTipoProductoOrigen,
      /* FIN AÑADIDO */
      cast(ID as int64) IdProducto, 
      idcontrato Contrato, 
      agente_venta UsuarioCreador,
      agente_venta agente_creador_id, 
      concepto concepto_ds, 
      concepto_origen concepto_origen_ds, 
      medio_conocimiento, 
      grid  
     from `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE`   
     where accion in ('Alta','Modificación','Modificacion') 
     and estado_proceso = 'Finalizado' 
     --and  upper(segmento_ds) in ('RESIDENCIAL','SOHO');
     AND UPPER(segmento_ds) IN ('RESIDENCIAL','MICROEMPRESA','AMBOS','COLABORADOR', 'SOHO') 

     --==============================================================================
     -- AÑADIDO VENTAS CANCELADAS NO COMPLETADAS - UN REGISTRO POR VENTA
     --=============================================================================

     UNION ALL
     ( 
       with p as ( 
           select distinct 
            marca_ds,
            entidadNueva IdCatalogo, 
            descripcionentidadnueva NombreProducto, 
            distribuidor_ds nombre_distribuidor,  
            equipo_ds as equipo,
            canal_agrupado1_ds Canal,  
            subcanal_ds subcanal,  
            agente_venta agente, 
            cliente_id IdFijo, 
            cast(fecha_ultimo_cambio as date) Antiguedad, 
            cif_nif DNI_CIF,  
            es_cartera Marca_Cartera, 
            --cast(FECHA_RFB_DT as Date) Fecha_Activacion, 
            --CAST(fecha_venta_id as Date) Fecha_Creacion, 
            CAST(NULL As Date) Fecha_Activacion,
            min(cast(fecha_venta_id as Date))over(partition by marca_ds, cliente_id, accionentidad, tipoentidad, entidadnueva) Fecha_Creacion, 
            segmento_ds Segmento, 
            subsegmento_ds Subsegmento,
            entidadanterior, 
            ID_ORIGEN IdProductoOrigen, 
            descripcionentidadanterior NombreProductoOrigen, 
            /* AÑADIDO */
            TipoProducto,
            subTipoProducto,
            /* FIN AÑADIDO */
            Tipo_Movimiento, 
            /* AÑADIDO */
            TipoProductoOrigen,
            subTipoProductoOrigen,
            /* FIN AÑADIDO */
            --cast(ID as int64) IdProducto, 
            --idcontrato Contrato, 
            min(cast(ID as int64))over(partition by marca_ds, cliente_id, accionentidad, tipoentidad, entidadnueva)  IdProducto,           
            min(idcontrato)over(partition by marca_ds, cliente_id, accionentidad, tipoentidad, entidadnueva) Contrato,
            agente_venta UsuarioCreador,
            agente_venta agente_creador_id, 
            concepto concepto_ds, 
            concepto_origen concepto_origen_ds, 
            medio_conocimiento, 
            grid,
            estado_proceso  
           from `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE`   
           where accion in ('Alta') 
           --and cliente_id=400527404
           --and  upper(segmento_ds) in ('RESIDENCIAL','SOHO');
           AND UPPER(segmento_ds) IN ('RESIDENCIAL','MICROEMPRESA','AMBOS','COLABORADOR', 'SOHO')
           QUALIFY count(distinct estado_proceso ) over(partition by marca_ds, cliente_id, accionentidad, tipoentidad, entidadnueva)=1 
        ) select * except(estado_proceso)
        from p
        where estado_proceso="Cancelado"
      ) ; 

      
    --===================================================================
    --
    --===================================================================


  -- =========================================================
  -- CTE 8: Eliminar eventos de promociones mismo origen y destino - Paso 4
  -- =========================================================

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_PROMOS_MISMO_CAT_ORyDEST` 
      OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) as 
      SELECT *  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` where grid=54 and UPPER(TRIM(IdCatalogo))=UPPER((entidadAnterior));  

      CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` 
      OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
      SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` e
      EXCEPT DISTINCT 
            SELECT *
            FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_PROMOS_MISMO_CAT_ORyDEST`;



  -- =========================================================
  -- CTE 9: Eliminar eventos con fecha con antiguedad superior a 4 meses - Paso 5
  -- =========================================================


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_VENTAS_CAPTACION_R_FV_INCONSISTENTE`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` WHERE Fecha_Creacion< DATE_TRUNC(DATE_SUB(DESDE, interval 4 month),MONTH);

  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` c
  WHERE exists (
    SELECT 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0105_VENTAS_CAPTACION_R_FV_INCONSISTENTE` v
    where v.idFijo=c.idFijo and v.idProducto=c.idProducto and c.Fecha_Creacion=v.Fecha_Creacion
  );

  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` c
  where c.idProducto is null and  Fecha_Creacion< DATE_TRUNC(DATE_SUB(DESDE, interval 4 month),MONTH);


  -- =========================================================
  -- CTE 10: Corregir nombre de catálogos con caráctereno visibles 
  -- =========================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_CATALOGO_CARACTER_NO_VISIBLE`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT distinct NombreProducto
      ,count(idProducto) over(partition by NombreProducto) as npr
  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`
  where regexp_contains(NombreProducto, r'[\x00-\x1f\xc2\xa0]')
  order by 1 asc;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_CATALOGO_ORIGEN_CARACTER_NO_VISIBLE` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT distinct NombreProductoOrigen
      ,count(idProducto) over(partition by NombreProductoOrigen) as npr
  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`
  where regexp_contains(NombreProductoOrigen, r'[\x00-\x1f\xc2\xa0]')
  order by 1 asc;

  UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`
  SET NombreProducto=regexp_replace(regexp_replace(NombreProducto, r'[\x00-\x1f]',''),r'\xa0',' ')
  where regexp_contains(NombreProducto, r'[\x00-\x1f\xc2\xa0]');

  UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`
  SET NombreProductoOrigen=regexp_replace(regexp_replace(NombreProducto, r'[\x00-\x1f]',''),r'\xa0',' ')
  where regexp_contains(NombreProductoOrigen, r'[\x00-\x1f\xc2\xa0]');



  -- ==========================================================
  -- OUT 1: Insertar registros en tabla eventos
  -- ==========================================================


  insert into `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
  SELECT distinct * except(grid) FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`;  


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS
  SELECT distinct * from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;



    --- PASO 8: CREO TABLA DE LOG
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;

END