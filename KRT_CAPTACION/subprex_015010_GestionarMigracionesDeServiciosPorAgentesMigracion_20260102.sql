BEGIN

    --DECLARE DESDE,HASTA INT64;
    --SET DESDE=20230301;
    --SET HASTA=20230322;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015010_SERV_BASICOS_MIGRADOS_AGENTES_MIG` AS    
      select distinct s.marca_ds, s.Cliente_id, cand.servicio_id, s.detalle_servicio_ds, cand.CONCEPTO_DS, s.FECHA_RFB_ID, s.FECHA_VENTA_NETA_ID, s.fecha_rfb_dt, s.fecha_venta_neta_dt, s.canal_alta_ds, s.subcanal_ds, s.tipo_canal_alta_ds, s.nombre_distribuidor_alta_ds, s.agente_alta_id, s.agente_creador_id, s.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, s.marca_cartera_ds, cand.Antiguedad_Cliente, s.equipo_ds, s.territorio_ds, s.tecnologia_detalle_ds, s.portabilidad_in_lg, s.gb, s.expediente_id, s.expediente_padre_id, s.contrato_id, cand.tipo_pedido_ds, s.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, (SAFE_NEGATE(cand.grid)) -20 as grid, cand.desc_mm, cand.clase_mm, case when cand.marca_ds!='R'Then s.expediente_padre_id else cast(s.pedido_id as string) end as pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p
    --case when cand.pedido_id=s.pedido_id then 1 else 0 end, 
    --case when cand.pedido_id!=s.pedido_id and cand.pedido_id<0 then s.pedido_id else cand.pedido_id end 
      from   `mm-commissions-reporting.KRT_CAPTACION.VENTAS_AGENTE_MIGRACION` cand
      inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
      on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
      where (CONTAINS_SUBSTR(cand.clase_mm, 'A - ' ) or CONTAINS_SUBSTR(cand.desc_mm,'acceso'))
      and CONTAINS_SUBSTR(s.operacion_alta_ds,"alta") -- así nos aseguramos que el registro proviene de una alta
      and s.fecha_rfb_id>=desde
      --and s.fecha_rfb_id<=hasta;
      and cand.fecha_rfb_id<=hasta;



    --- SVAS

    --- GEKT

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015010_SVAS_MIGRADOS_AGENTES_MIG` AS
      SELECT cand.marca_ds, cand.Cliente_id, cand.servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, 
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
--      AND (p.swFechaDesinstalacion IS NULL OR ( (EXTRACT(YEAR FROM p.swFechaDesinstalacion)*10000 + EXTRACT(MONTH FROM p.swFechaDesinstalacion) * 100 + EXTRACT(DAY FROM p.swFechaDesinstalacion))>hasta));
      AND (cand.fecha_rfb_id between desde and hasta);

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
      LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_t_30_maestro_canal` trc ON trc.canal_id = p.swChnlPartnerId
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
      --AND (p.swFechaDesinstalacion IS NULL OR ( (EXTRACT(YEAR FROM p.swFechaDesinstalacion)*10000 + EXTRACT(MONTH FROM p.swFechaDesinstalacion) * 100 + EXTRACT(DAY FROM p.swFechaDesinstalacion))>hasta))
      AND (cand.fecha_rfb_id between desde and hasta)      
      order by 1,2,3;


END