BEGIN


  --- PASO 1: Identificar comisiones de agente migración masiva

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_MIGRACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
  where CONTAINS_SUBSTR(agente_creador_id,'MIGR')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIG_')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIG ')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGR')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGTV')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGFT')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGBA')
  OR CONTAINS_SUBSTR(agente_creador_id,'MIGTF')
  OR  CONTAINS_SUBSTR(agente_creador_id,'REPO')
  OR  CONTAINS_SUBSTR(agente_creador_id,'MASIV')
  OR ENDS_WITH(agente_creador_id,'MIG')
  OR ENDS_WITH(agente_creador_id,'MIG1');


  --- PASO 2: Identificar comisiones de agente automatización de procesos usuario - producto
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_AGENTE_AUTOMATIZACION`  AS 
  SELECT * 
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
  where agente_creador_id='TASCA';


  --- PASO 3: Borrar comisiones de agente migración masiva

  DELETE
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_MIGRACION` b
    where b.marca_ds=v.marca_ds
    and b.idFijo=v.idFijo
    and b.idProducto=v.idProducto
    and b.agente_creador_id=v.agente_creador_id
  );

  --- PASO 4: Borrar comisiones de agente automatización
  DELETE
  FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` v
  WHERE EXISTS (
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES_AGENTE_AUTOMATIZACION` b
    where b.marca_ds=v.marca_ds
    and b.idFijo=v.idFijo
    and b.idProducto=v.idProducto
    and b.agente_creador_id=v.agente_creador_id
  );


  --- PASO 5: Identificar comisiones de alta + migración por agente de migración masiva

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015010_SVAS_MIGRADOS_AGENTES_MIG` AS
      SELECT cand.marca_ds, cand.Cliente_id, p.swInstProdId as servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, 
          (EXTRACT(YEAR FROM p.swDateInstalled)*10000 + EXTRACT(MONTH FROM p.swDateInstalled) * 100 + EXTRACT(DAY FROM p.swDateInstalled)) FECHA_RFB_ID, 
    (EXTRACT(YEAR FROM p.swDateCreated)*10000 + EXTRACT(MONTH FROM p.swDateCreated) * 100 + EXTRACT(DAY FROM p.swDateCreated)) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT, p.swDateCreated FECHA_VENTA_NETA_DT,  cand.canal_alta_ds, cand.subcanal_ds, cand.tipo_canal_alta_ds, cand.nombre_distribuidor_alta_ds, 
    `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(pe.swNombre) as agente_alta_id, p.swCreatedBy as agente_creador_id, cand.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, cand.marca_cartera_ds, cand.Antiguedad_Cliente, cand.equipo_ds, cand.territorio_ds, cand.tecnologia_detalle_ds, cand.portabilidad_in_lg, cand.gb, cand.expediente_id, cand.expediente_padre_id, cand.contrato_id, cand.tipo_pedido_ds, cand.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, (SAFE_NEGATE(cand.grid)) -20 as grid, cand.desc_mm, cand.clase_mm, cand.pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p, 
      from   `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION` cand
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` pr on pr.swInstProdId=cand.servicio_Id
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on p.swInstProdId=pr.swProdOrigId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca ON ca.swChnlPartnerId = p.swChnlPartnerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` pe ON pe.swPersonalId=p.swProviderGrpId

      --on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
      where (CONTAINS_SUBSTR(cand.clase_mm, 'B - ' ) and CONTAINS_SUBSTR(cand.desc_mm,'television') and NOT CONTAINS_SUBSTR(cand.desc_mm,'acceso'))
--      and CONTAINS_SUBSTR(s.operacion_alta_ds,"alta") -- así nos aseguramos que el registro proviene de una alta
      AND (p.swProdOrigId IS NULL
            OR EXISTS (SELECT 1 FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p2
                       WHERE p2.swInstProdId = p.swMasterInstProdId 
                       and (EXTRACT(YEAR FROM p2.swDateInstalled)*10000 + EXTRACT(MONTH FROM p2.swDateInstalled) * 100 + EXTRACT(DAY FROM p2.swDateInstalled)) BETWEEN desde AND hasta
                       )
          )
      --and cand.fecha_rfb_id>=desde
      --and cand.fecha_rfb_id<=hasta
      and (EXTRACT(YEAR FROM p.swDateInstalled)*10000 + EXTRACT(MONTH FROM p.swDateInstalled) * 100 + EXTRACT(DAY FROM p.swDateInstalled))  BETWEEN desde AND hasta
      AND (p.swFechaDesinstalacion IS NULL OR ( (EXTRACT(YEAR FROM p.swFechaDesinstalacion)*10000 + EXTRACT(MONTH FROM p.swFechaDesinstalacion) * 100 + EXTRACT(DAY FROM p.swFechaDesinstalacion))>hasta));


      INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_015010_SVAS_MIGRADOS_AGENTES_MIG`
      SELECT cand.marca_ds, cand.Cliente_id, cand.servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, 
          (EXTRACT(YEAR FROM p.swDateInstalled)*10000 + EXTRACT(MONTH FROM p.swDateInstalled) * 100 + EXTRACT(DAY FROM p.swDateInstalled)) FECHA_RFB_ID, 
    (EXTRACT(YEAR FROM p.swDateCreated)*10000 + EXTRACT(MONTH FROM p.swDateCreated) * 100 + EXTRACT(DAY FROM p.swDateCreated)) FECHA_VENTA_NETA_ID,
    p.swDateInstalled fecha_RFB_DT, p.swDateCreated FECHA_VENTA_NETA_DT, c1.canal_agrupado1_ds as canal_alta_ds, sc.subcanal_ds as subcanal_ds, c2.canal_agrupado2_ds as tipo_canal_alta_ds, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(ca.swName) as nombre_distribuidor_alta_ds, 
    `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_cleaning_string`(pe.swNombre) as agente_alta_id, p.swCreatedBy as agente_creador_id, cand.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, p.swMarcaCartera as marcaCartera, cand.Antiguedad_Cliente, cand.equipo_ds, cand.territorio_ds, cand.tecnologia_detalle_ds, cand.portabilidad_in_lg, cand.gb, cand.expediente_id, cand.expediente_padre_id, cand.contrato_id, cand.tipo_pedido_ds, cand.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, (SAFE_NEGATE(cand.grid)) -20 as grid, cand.desc_mm, cand.clase_mm, cand.pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p, 
      from   `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION` cand
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` pr on pr.swInstProdId=cand.servicio_Id
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p on p.swInstProdId=pr.swProdOrigId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` ca ON ca.swChnlPartnerId = p.swChnlPartnerId
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` pe ON p.swPedId = pe.swPersonalId
      LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` tc ON tc.canal_id = p.swChnlPartnerId AND tc.agente_alta_id = REPLACE(REPLACE( REPLACE( REPLACE( REPLACE( REPLACE(UPPER(pe.swNombre), 'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'Ü','U')       
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1 ON trc.canal_agrupado1_id = c1.canal_agrupado1_id
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2 ON trc.canal_agrupado2_id = c2.canal_agrupado2_id
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc ON trc.subcanal_id = sc.subcanal_id
      --on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
      where marca_ds in('TELECABLE')
      and (CONTAINS_SUBSTR(cand.clase_mm, 'B - ' ) and CONTAINS_SUBSTR(cand.desc_mm,'television') and NOT CONTAINS_SUBSTR(cand.desc_mm,'acceso'))
--      and CONTAINS_SUBSTR(s.operacion_alta_ds,"alta") -- así nos aseguramos que el registro proviene de una alta
      AND (p.swProdOrigId IS NULL
            OR EXISTS (SELECT 1 FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p2
                       WHERE p2.swInstProdId = p.swMasterInstProdId 
                       and (EXTRACT(YEAR FROM p2.swDateInstalled)*10000 + EXTRACT(MONTH FROM p2.swDateInstalled) * 100 + EXTRACT(DAY FROM p2.swDateInstalled)) BETWEEN desde AND hasta
                       )
          )

      --and cand.fecha_rfb_id>=desde
      --and cand.fecha_rfb_id<=hasta
      and (EXTRACT(YEAR FROM p.swDateInstalled)*10000 + EXTRACT(MONTH FROM p.swDateInstalled) * 100 + EXTRACT(DAY FROM p.swDateInstalled)) Between desde and hasta
      AND (p.swFechaDesinstalacion IS NULL OR ( (EXTRACT(YEAR FROM p.swFechaDesinstalacion)*10000 + EXTRACT(MONTH FROM p.swFechaDesinstalacion) * 100 + EXTRACT(DAY FROM p.swFechaDesinstalacion))>hasta))
      order by 1,2,3;

  --- PASO 6: Identificar comisiones de cambio + migración por agente de migración masiva

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
  --AS SELECT * except (agente_creador_id) FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

  
  
  --- PASO 7: Volcado comisiones 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0403_COMISIONES`
  AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;


END