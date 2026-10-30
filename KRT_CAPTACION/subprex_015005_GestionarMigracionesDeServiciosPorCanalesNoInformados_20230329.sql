BEGIN

  ----------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------
  ---
  --- PASO 2: INSERTA EN SERVICIOS CAPTACION  LOS SERVICIOS PROCEDENTES DE MIGRACIONES EN EL MISMO MES
  ----


    --INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`
    --  select cand.marca_ds, cand.Cliente_id, cand.servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, cand.FECHA_RFB_ID, cand.FECHA_VENTA_NETA_ID, cand.fecha_rfb_dt, cand.fecha_venta_neta_dt,s. canal_alta_ds, s.subcanal_ds, s.tipo_canal_alta_ds, s.nombre_distribuidor_alta_ds, s.agente_alta_id, s.agente_creador_id, cand.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, cand.marca_cartera_ds, cand.Antiguedad_Cliente, s.equipo_ds, cand.territorio_ds, cand.tecnologia_detalle_ds, cand.portabilidad_in_lg, cand.gb, s.expediente_id, s.expediente_padre_id, s.contrato_id, cand.tipo_pedido_ds, cand.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, SAFE_NEGATE(cand.grid) as grid, cand.desc_mm, cand.clase_mm, cand.pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p
    -- from `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_SERVICIOS_CAPTACION` cand
    -- left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
    --  on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
    --  where (cand.canal_alta_ds is null or cand.canal_alta_ds in('DESCONOCIDO','OTROS', 'RETENCION')) and cand.grid<5
      --and s.categoria_servicio_ds="BANDA ANCHA"
      --and s.marca_ds="EUSKALTEL"
    --  and s.fecha_rfb_id>=desde
    --  and s.fecha_rfb_id<=hasta;
  

    ---DECLARE DESDE,HASTA INT64;
    ---SET DESDE=20230201;
    ---SET HASTA=20230222;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_INICIAL` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`;
  
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_FINAL` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`;

   
    --- PASO 2.1: IDENTIFICO SERVICIOS MIGRADOS A CANALES NO INFORMADOS 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_NO_INF` AS 
    select distinct cand.* 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_INICIAL` cand
    left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
    on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
    where (cand.canal_alta_ds is null or cand.canal_alta_ds in('DESCONOCIDO','OTROS', 'RETENCION')) and cand.grid<5
      --and s.categoria_servicio_ds="BANDA ANCHA"
      --and s.marca_ds="EUSKALTEL"
    and s.fecha_rfb_id>=desde
    and s.fecha_rfb_id<=hasta;

    --- PASO 2.2: BORRO DE LA TABLA DE SERVICIOS, AQUELLOS MIGRADOS A CANALES NO INFORMADOS 
    DELETE 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_FINAL` s
    where exists(
      select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_NO_INF`c
      where c.marca_ds=s.marca_ds
      and c.cliente_id=s.cliente_id
      and c.categoria_servicio_ds=s.categoria_servicio_ds
      and c.servicio_id=s.servicio_id 
    ); 


    --- PASO 2.3: CREO UNA TABLA CON LOS SERVICIOS 
    --                MIGRADOS A CANALES NO INFORMADOS
    --                PROCEDENTES DE UNA MIGRACION
    --                EN LA QUE EL TRAMO PROCEDENTE ERA UN ALTA  
    --                SOBRESCRIBIENDO LOS DATOS DE CANAL_ALTA_DS, SUBCANAL_DS, NOMBRE_DISTRIBUIDOR, EQUIPO_DS, EXPEDIENTE_ID, EXPEDIENTE_PADRE_ID, CONTRATO_ID, S_PEDIDO_ID, PEDIDO 

    --DECLARE DESDE,HASTA INT64;
    --SET DESDE=20230201;
    --SET HASTA=20230222;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_INF` AS 
    --INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`

    --DECLARE DESDE,HASTA INT64;
    --SET DESDE=20230201;
    --SET HASTA=20230227;
      select distinct cand.marca_ds, cand.Cliente_id, cand.servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, cand.FECHA_RFB_ID, cand.FECHA_VENTA_NETA_ID, cand.fecha_rfb_dt, cand.fecha_venta_neta_dt, s.canal_alta_ds, s.subcanal_ds, s.tipo_canal_alta_ds, s.nombre_distribuidor_alta_ds, s.agente_alta_id, s.agente_creador_id, cand.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, cand.marca_cartera_ds, cand.Antiguedad_Cliente, s.equipo_ds, cand.territorio_ds, cand.tecnologia_detalle_ds, cand.portabilidad_in_lg, cand.gb, s.expediente_id, s.expediente_padre_id, s.contrato_id, cand.tipo_pedido_ds, s.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, SAFE_NEGATE(cand.grid) as grid, cand.desc_mm, cand.clase_mm, case when cand.marca_ds!='R'Then s.expediente_padre_id else cast(s.pedido_id as string) end as pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p, 
    --case when cand.pedido_id=s.pedido_id then 1 else 0 end, 
    --case when cand.pedido_id!=s.pedido_id and cand.pedido_id<0 then s.pedido_id else cand.pedido_id end 
      from  `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_NO_INF` cand
      left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
      on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
      where (cand.canal_alta_ds is null or cand.canal_alta_ds in('DESCONOCIDO','OTROS', 'RETENCION')) and cand.grid<5
      --and s.categoria_servicio_ds="BANDA ANCHA"
      --and s.marca_ds="EUSKALTEL"
      and s.agente_creador_id!="MIGRAMASHFC_FTTH"
      and CONTAINS_SUBSTR(s.operacion_alta_ds,"alta") -- así nos aseguramos que el registro proviene de una alta
      and s.fecha_rfb_id>=desde
      and s.fecha_rfb_id<=hasta
      order by 1,2,3;

--- PASO 2.4: CREO UNA TABLA CON LOS SERVICIOS 
    --                MIGRADOS A CANALES NO INFORMADOS
    --                PROCEDENTES DE UNA MIGRACION
    --                EN LA QUE EL TRAMO PROCEDENTE NO ERA UN ALTA  

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_INF_NO_ALTA` AS 
    --INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`

    ---DECLARE DESDE,HASTA INT64;
    --SET DESDE=20230201;
    --SET HASTA=20230228;
      select distinct cand.marca_ds, cand.Cliente_id, cand.servicio_id, cand.detalle_servicio_ds, cand.CONCEPTO_DS, cand.FECHA_RFB_ID, cand.FECHA_VENTA_NETA_ID, cand.fecha_rfb_dt, cand.fecha_venta_neta_dt, cand.canal_alta_ds, cand.subcanal_ds, cand.tipo_canal_alta_ds, cand.nombre_distribuidor_alta_ds, cand.agente_alta_id, cand.agente_creador_id, cand.categoria_servicio_ds, cand.cif_nif, cand.segmento_ds, cand.subsegmento_ds, cand.marca_cartera_ds, cand.Antiguedad_Cliente, cand.equipo_ds, cand.territorio_ds, cand.tecnologia_detalle_ds, cand.portabilidad_in_lg, cand.gb, cand.expediente_id, cand.expediente_padre_id, cand.contrato_id, cand.tipo_pedido_ds, cand.pedido_id, cand.tipo_producto_pedido_re_ds, cand.visibilidad_pedido_lg, cand.catalogo_id, cand.grid, cand.desc_mm, cand.clase_mm, cand.pedido, cand.nplays, cand.nplays_rfb, cand.cat_plays, cand.cat_plays_rfb, cand.nplays_p, cand.nplays_rfb_p, cand.cat_plays_p, cand.cat_plays_rfb_p, 
    --case when cand.pedido_id=s.pedido_id then 1 else 0 end, 
    --case when cand.pedido_id!=s.pedido_id and cand.pedido_id<0 then s.pedido_id else cand.pedido_id end 
      from  `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_NO_INF` cand
      left join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
      on s.marca_ds=cand.marca_ds and s.cliente_id=cand.cliente_id and s.categoria_servicio_ds=cand.categoria_servicio_ds and s.servicio_id_destino=cand.servicio_id
      where (cand.canal_alta_ds is null or cand.canal_alta_ds in('DESCONOCIDO','OTROS', 'RETENCION')) and cand.grid<5
      --and s.categoria_servicio_ds="BANDA ANCHA"
      --and s.marca_ds="EUSKALTEL"
      and s.agente_creador_id!="MIGRAMASHFC_FTTH"
      and NOT CONTAINS_SUBSTR(s.operacion_alta_ds,"alta") -- así nos aseguramos que el registro proviene de una alta
      and s.fecha_rfb_id>=desde
      and s.fecha_rfb_id<=hasta
      order by 1,2,3;




--- PASO 2.5: INSERTO EN TABLA SERVICIOS_CAPTACION_FINAL LOS SERVICIOS RECREADOS 

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_FINAL`
    select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_MIGRADOS_CAN_INF`;

--- PASO 2.6: REEMPLAZO LA TABLA SERVICIOS_CAPTACION CON LOS DATOS DE LA TABLA SERVICIOS_CAPTACION_FINAL 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS
    SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_015000_SERVICIOS_CAPTACION_FINAL`;


END