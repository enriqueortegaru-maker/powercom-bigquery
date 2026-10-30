BEGIN

  ---LOCAL
  --DECLARE DESDE, HASTA INT64; SET DESDE=20230601;SET HASTA=20230630;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION` AS

  ---  PASO 1: Creo tabla SERVICIOS_CAPTACION

  WITH servicioMovilPrepago as  (
    SELECT *
    FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
    WHERE categoria_servicio_ds = 'MOVILES PREPAGO'
  )
  SELECT DISTINCT serv.marca_ds,  serv.Cliente_id, CAST(serv.servicio_id AS int64) servicio_id, serv.detalle_servicio_ds, cat.CONCEPTO_DS,
    serv.FECHA_RFB_ID,serv.FECHA_VENTA_NETA_ID, serv.fecha_rfb_dt, serv.fecha_venta_neta_dt, serv.canal_alta_ds, serv.subcanal_ds, serv.tipo_canal_alta_ds,
    serv.nombre_distribuidor_alta_ds, serv.agente_alta_id, serv.agente_creador_id,serv.categoria_servicio_ds, cl.cif_nif, serv.segmento_ds, cl.subsegmento_ds,
    CASE WHEN serv.marca_ds NOT IN ('R') THEN serv.marca_cartera_ds
         ELSE
            CASE WHEN ABS(DATE_DIFF(CAST(serv.fecha_rfb_dt AS DATE), CAST(rfb.fecha_alta_dt AS DATE), DAY))> 15 THEN 'CARTERA'
                 ELSE 'CAPTACION'
            END
    END  marca_cartera_ds,
    rfb.fecha_alta_dt Antiguedad_Cliente, 
    serv.equipo_ds, serv.territorio_ds, serv.tecnologia_detalle_ds, serv.portabilidad_in_lg,
    CASE WHEN serv.categoria_servicio_ds = 'BANDA ANCHA' THEN serv.velocidad_mb ELSE serv.gb END gb,
    serv.expediente_id,serv.expediente_padre_id, serv.contrato_id, serv.tipo_pedido_ds, serv.pedido_id, serv.tipo_producto_pedido_re_ds, serv.visibilidad_pedido_lg
  FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` serv
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS` cat ON cat.tipo_identificacion_ds = 'DETALLE_SERVICIO' AND cat.MARCA_DS = serv.MARCA_DS AND cat.CATEGORIA_SERVICIO_DS = serv.CATEGORIA_SERVICIO_DS AND serv.DETALLE_SERVICIO_DS = cat.DETALLE_SERVICIO_DS AND adicional_lg = 0
  INNER JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cl ON serv.marca_ds = cl.marca_ds AND serv.cliente_id = cl.cliente_id
  -- PDTE PROBAR LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cl
  LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` rfb ON rfb.marca_ds = serv.marca_ds AND rfb.cliente_id = serv.cliente_id AND rfb.desde_id <= serv.fecha_rfb_id AND rfb.hasta_id > serv.fecha_rfb_id
  LEFT JOIN servicioMovilPrepago as smovprep ON serv.servicio_id_origen = smovprep.servicio_id
  WHERE serv.fecha_rfb_id BETWEEN DESDE AND HASTA
  AND (UPPER(serv.agente_creador_id) NOT IN ('MIGRAMASHFC_FTTH', 'EKT_MIGRA_202206','REPO_JUNIO_2022'))
  AND serv.marca_ds <> 'R'
  AND (serv.servicio_id_origen < 0
          OR (serv.agente_creador_id = 'MIGRACIONTMK'
                AND EXISTS (
                            SELECT *
                            FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` smovprep
                            WHERE smovprep.marca_ds = 'TELECABLE'
                              AND smovprep.sistema_ds = 'SGI'
                              AND smovprep.servicio_id = serv.servicio_id_origen
                              AND smovprep.fecha_rfb_id BETWEEN DESDE AND HASTA
                            )
              )
          OR EXISTS (
                      SELECT 1 FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` smovprep
                      WHERE smovprep.cliente_id = serv.cliente_id
                        AND smovprep.marca_ds = serv.marca_ds
                        AND smovprep.servicio_id = serv.servicio_id_original
                        AND smovprep.fecha_rfb_id BETWEEN DESDE  AND HASTA 
                     )
          OR (serv.categoria_servicio_ds = 'MOVILES POSTPAGO' AND smovprep.categoria_servicio_ds = 'MOVILES PREPAGO') 
    )
    AND ((serv.segmento_ds IN ('RESIDENCIAL', 'SOHO', 'PYME') AND serv.marca_ds NOT IN ('TELECABLE','R'))  OR (serv.segmento_ds IN ('RESIDENCIAL', 'SOHO') AND serv.marca_ds IN ('TELECABLE', 'R')))
    AND serv.fecha_cancelacion_id > HASTA AND (serv.fecha_baja_id > HASTA /*PARCHE 20221005 OR serv.SERVICIO_ID_DESTINO > 0 FIN PARCHE*/ )
    AND ABS(DATE_DIFF(CAST(serv.fecha_rfs_dt AS DATE), CAST(serv.fecha_rfb_dt AS DATE), MONTH))<=2;


  ---  PASO 2: Vuelco registros en tabla de log `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS
  SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0101_SERVICIOS_CAPTACION` WHERE cif_nif is not null;    

  ----CONTROL DE VERSIONES:
  --
  --    V1: 20220620: Se realiza Volcado a tabla LOG_0101_SERVICIOS_CAPTACION de los servicios de captación de todas las marcas menos R
  --    V2: 20220628: Se modifica denominación de tablas y subqueries y se modifica condición para excluir servicios ligados a migraciones de servicio o reposiciones 
     

END