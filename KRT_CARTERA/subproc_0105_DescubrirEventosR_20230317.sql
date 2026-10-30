BEGIN

  DECLARE
    DESDE_DT,
    HASTA_DT date;
    --DECLARE DESDE, HASTA INT64;  
    --SET DESDE=20230201;
    --SET HASTA=20230209;
  SET
    HASTA_DT = parse_date ('%Y%m%d',
      CAST ( HASTA AS string) );
  SET
    DESDE_DT = parse_date ('%Y%m%d',
      CAST ( DESDE AS string) );


  insert into `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
      select distinct marca_ds, entidadNueva IdCatalogo, descripcionentidadnueva NombreProducto, distribuidor_ds nombre_distribuidor,  
  canal_agrupado1_ds Canal,  subcanal_ds subcanal,  agente_venta agente, cliente_id IdFijo, cast(fecha_ultimo_cambio as date) Antiguedad, 
  cif_nif DNI_CIF,  es_cartera Marca_Cartera, cast(FECHA_RFB_DT as Date) Fecha_Activacion, CAST(fecha_venta_id as Date) Fecha_Creacion, segmento_ds Segmento, subsegmento_ds Subsegmento,
      entidadanterior, ID_ORIGEN IdProductoOrigen, descripcionentidadanterior NombreProductoOrigen, Tipo_Movimiento, cast(ID as int64) IdProducto, idcontrato Contrato, agente_venta UsuarioCreador, concepto concepto_ds, concepto_origen concepto_origen_ds, medio_conocimiento  from (
                select pr.codigo_empresa_bi marca_ds, cast(p.idcliente as int64) cliente_id, coalesce(cast(pr.IDINTERNO as int64), cast(pr.idexterno as int64), row_number()over (partition by p.idcliente)) ID,p.idcontrato,p.idexpediente,pr_origen.accion accionentidadanterior, pr_origen.codigo entidadanterior, pr_origen.descripcion descripcionentidadanterior,  pr.accion accionentidad, pr.codigo entidadnueva, pr.descripcion descripcionentidadnueva,-- case when pr.accion='Baja' then -mst_pro.valor else mst_pro.valor end valor,
          case when p.estado='5' then (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) else null end FECHA_RFB_ID ,
          (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
          case when p.estado='5' then cast(p.last_upd as timestamp) else null end fecha_rfb_dt, cast(p.created as timestamp) fecha_venta_id,
          c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, emp.attrib_07 agente_venta, 
          ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else
          case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' else 'CAPTACION' end end es_cartera,  c.equipo_ds, 
                case p.estado
                when '1' then 'En configuración'
                when '2' then 'Enviando a provisión'
                when '3' then 'En provisión'
                when '4' then 'Enviando a facturación'
                when '5' then 'Finalizado'
                when '6' then 'Cancelado'
                end estado_proceso,mst_pro.tipoProducto,case when p.estado='5' then format_date('%Y%m',p.LAST_UPD) else null end periodorfb, 
                format_date('%Y%m',exp.CREATED) AS periodoventa,case when pr.accion='Baja' then 'Baja' when pr_origen.accion='Baja' then 'Modificacion' else 'Alta' end accion, 
                --case when pr.accion='Baja' then -mst_pro.valor else mst_pro.valor-ifnull(pr_origen.valor,0) end total, 
                --case when pr.accion='Baja' then 'Negativa' when mst_pro.valor>ifnull(pr_origen.valor,0) then 'Positiva' when mst_pro.valor<ifnull(pr_origen.valor,0) then 'Negativa' else 'Nula' end resultado
                mst_pro.concepto, concepto_origen,cli_x.fecha_ultimo_cambio, cast(ID_ORIGEN as int64) ID_ORIGEN,
                --case when pr.accion = 'Alta' or pr_origen.idProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
                --    when pr.accion in ('Modificación', 'Modificacion') and pr_origen.idProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) end tipo_movimiento
                case when pr.accion = 'Alta' and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
                  when pr.accion = 'Alta' and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
                  when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
                  when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
                  end tipo_movimiento --- , pr_origen.tipoProducto tipo_producto_old 
                  --campo incluido en query traspasada el 20230315, pero que Alonso aclara finalmente que se debe eliminar
          from
          `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x,
          `dw-cloud-euskaltel-prod-283409.D10_CLEANING_EXTERNAL.clean_tr_r_30_maestro_canal` c,
          `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p left join
                (select pr_old.idproducto,pr_old.accion,pr_old.codigo, pr_old.descripcion, mst_pro_old.tipoProducto,--mst_pro_old.valor
                --mst_pro_old.tipo_movimiento,
                mst_pro_old.tipo_movimiento,pr_old.row_id,
                mst_pro_old.concepto concepto_origen, pr_old.IDINTERNO ID_ORIGEN
                from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old,`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old,`mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro_old  
                --where pr_old.accion='Baja'
                where pr_old.accion in ('Baja','Modificacion','Modificación')
                and p_old.IDPRODUCTOOLD=pr_old.idproducto 
                and mst_pro_old.marca_ds='R'
                and pr_old.codigo=mst_pro_old.idProdCat
                and p_old.LAST_UPD >= desde_dt and p_old.LAST_UPD <= hasta_dt
                ) as pr_origen
          --on p.idproductoold=pr_origen.idproducto and pr_origen.accion='Baja' and pr_origen.tipoProducto=mst_pro.tipoProducto
          on p.idproductoold=pr_origen.idproducto --and pr_origen.accion='Baja' 
          and pr_origen.tipoProducto=mst_pro.tipoProducto
          and pr_origen.tipo_movimiento = mst_pro.tipo_movimiento and pr_origen.tipoProducto = mst_pro.tipoProducto
          and pr.idOld <> pr_Origen.row_id
          and pr.codigo <> pr_origen.codigo
          left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on cast(p.idcliente as int64) =est_cli.cliente_id and est_cli.marca_ds='R' and date(desde_dt)<=date(exp.created) and date(hasta_dt)>date(exp.created)
          where p.idproductonew=pr.idproducto
          and exp.owner_emp_id=emp.row_id
          and cli_x.row_id=exp.CST_OU_ID
          and exp.row_id=exp_x.row_id
          and exp_x.row_id=p.idcontrato
          and CAST(FORMAT_DATE("%Y%m%d",p.LAST_UPD) AS INT64) >= desde and  CAST(FORMAT_DATE("%Y%m%d",p.LAST_UPD) AS INT64) <= hasta
          and c.agente_venta_id = cast(emp.attrib_07 as int64)
          and mst_pro.marca_ds='R'
          and mst_pro.tipoProducto<>'terminal'
          and pr.codigo=mst_pro.IdProdCat
          --and pr.accion in ('Alta','Baja','Modificación') 
          and pr.accion in ('Alta','Modificacion')
          and ci.marca_ds = 'R'
          and ci.cliente_id = cast(p.idcliente as int64)
                and ((p.vigente='Y' and p.estado in ('2','3','4')) or (p.estado ='5') or (p.estado ='6'))
          and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
          and exp.SR_SUBTYPE_CD<>'TRASLADO'
          and exp.X_R_SUBTIPO2<>'TRASLADO'
          and p.operacion not in ('SUSTITUCION TERMINAL DOA','BAJA')
          and not exists (select p2.idproductonew
          from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2, `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2, `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
          where pra2.identidad=pr2.row_id
          and pr2.idproducto=p2.idproductonew
          and p2.idproductonew=p.idproductonew
          and pra2.atributo='Atajo' and pra2.valor in ('SI','SÍ','si','sí') )

  union all
                --- datos de R
                --- equipamiento móvil  

                select pr.codigo_empresa_bi marca_ds, cast(p.idcliente as int64) cliente_id, cast(pr.IDINTERNO as int64) ID,p.idcontrato,p.idexpediente,"" accionentidadanterior, "" entidadanterior, "" descripcionentidadanterior,  pr.accion accionentidad, pr.codigo entidadnueva, pr.descripcion descripcionentidadnueva, --aux_terminales.valor,
          case when p.estado='5' then (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) else null end FECHA_RFB_ID,
          (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
          case when p.estado='5' then cast(p.last_upd as timestamp) else null end fecha_rfb_dt, cast(p.created as timestamp) fecha_venta_id,
          c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, emp.attrib_07 agente_venta, 
          ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else
          case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' else 'CAPTACION' end end es_cartera,  c.equipo_ds,            
                case p.estado
                when '1' then 'En configuración'
                when '2' then 'Enviando a provisión'
                when '3' then 'En provisión'
                when '4' then 'Enviando a facturación'
                when '5' then 'Finalizado'
                when '6' then 'Cancelado'
                end estado_proceso,mst_pro.tipoProducto, case when p.estado='5' then format_date('%Y%m',p.LAST_UPD) else null end periodorfb, 
                format_date('%Y%m',exp.CREATED) AS periodoventa,case when pr.accion='Baja' then 'Baja' else 'Alta' end accion, 
                --case when pr.accion='Baja' then -aux_terminales.valor else aux_terminales.valor end total, 
                --case when pr.accion='Baja' then 'Negativa' else 'Positiva' end resultado
                mst_pro.concepto, "" concepto_origen,cli_x.fecha_ultimo_cambio, null ,
                case when pr.accion = 'Alta' then concat('Alta ', mst_pro.tipo_movimiento) when pr.accion in ('Modificación', 'Modificacion') then concat('Cambio ', mst_pro.tipo_movimiento) end tipo_movimiento
          from
          `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x,
          `dw-cloud-euskaltel-prod-283409.D10_CLEANING_EXTERNAL.clean_tr_r_30_maestro_canal` c,
          `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci,
          `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p 
          left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on cast(p.idcliente as int64) =est_cli.cliente_id and est_cli.marca_ds='R' and date(desde_dt)<=date(exp.created) and date(hasta_dt)>date(exp.created)
          --left join `mm-datamart-kd.ZZ_CVM.Maestro_AuxiliarTerminales_KRTV` aux_terminales on aux_terminales.marca='R' and aux_terminales.sistema='R' and date(p.created) between aux_terminales.Vigente_Desde and aux_terminales.Vigente_Hasta and pr.codigomodelo=aux_terminales.Codigo
          where p.idproductonew=pr.idproducto
          and exp.owner_emp_id=emp.row_id
          and cli_x.row_id=exp.CST_OU_ID
          and exp.row_id=exp_x.row_id
          and exp_x.row_id=p.idcontrato
          and CAST(FORMAT_DATE("%Y%m%d",p.LAST_UPD) AS INT64) >= desde and  CAST(FORMAT_DATE("%Y%m%d",p.LAST_UPD) AS INT64) <= hasta          
          --and p.LAST_UPD >= desde and p.LAST_UPD <= hasta
          and c.agente_venta_id = cast(emp.attrib_07 as int64)
          and mst_pro.marca_ds='R'
          and mst_pro.tipoProducto='terminal'
          and pr.codigo=mst_pro.IdProdCat
          and pr.accion ='Alta'
          and ci.marca_ds = 'R'
          and ci.cliente_id = cast(p.idcliente as int64)
                and ((p.vigente='Y' and p.estado in ('2','3','4')) or (p.estado ='5') or (p.estado ='6'))
          and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
          and exp.SR_SUBTYPE_CD<>'TRASLADO'
          and exp.X_R_SUBTIPO2<>'TRASLADO'
          and p.operacion not in ('SUSTITUCION TERMINAL DOA','BAJA')
          and not exists (select p2.idproductonew
          from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2, `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2, `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
          where pra2.identidad=pr2.row_id
          and pr2.idproducto=p2.idproductonew
          and p2.idproductonew=p.idproductonew
          and pra2.atributo='Atajo' and pra2.valor in ('SI','SÍ','si','sí') )

  union all
  ---datos de R
  --- productos como bonos o marcadores que no llevan proceso de provisión y se dan de alta directamente desde siebel hasta singleview sin pasar por voa  
                select 'R' as marca_ds, cast(cli.ou_num as int64), sgvpromo.idproducto, sgvpromo.idexpediente as idcontrato,sgvpromo.idexpediente as idexpediente, "" as accionentidadanterior,"" promoanterior,"" as descripcionproductoanterior,--0 as valoranterior,
                'Alta' as accionentidad, sgvpromo.codigopromo promonueva, mst_pro.nombreProducto as descripcionentidadnueva,--mst_pro.valor,
                (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_RFB_ID,
                (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
                cast (sgvpromo.FECEFECTIVA as timestamp) fecha_rfb_dt,  cast (exp.CREATED as timestamp) fecha_venta_id,
                c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, emp.attrib_07 agente_venta,
                ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast (exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else case when cli_x.es_cartera = 'Y' then 'CARTERA' else 'CAPTACION' end end es_cartera,  c.equipo_ds,'Finalizado' as estado,mst_pro.tipoProducto,format_date('%Y%m',exp.CREATED) AS periodorfb, format_date('%Y%m',exp.CREATED) AS periodoventa, 'Alta' accion,--mst_pro.valor total, 'Positiva' resultado
                mst_pro.concepto, "" concepto_origen,cli_x.fecha_ultimo_cambio, null, 
                concat('Alta ', mst_pro.tipo_movimiento) tipo_movimiento
                from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo 
                left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp on sgvpromo.idexpediente=exp.row_id 
                left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp on exp.owner_emp_id=emp.row_id  
                inner join `dw-cloud-euskaltel-prod-283409.D10_CLEANING_EXTERNAL.clean_tr_r_30_maestro_canal` c on   c.agente_venta_id = cast(emp.attrib_07 as int64)
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli on cli.row_id=exp.CST_OU_ID
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x on cli.row_id=cli_x.row_id
                inner join `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci on ci.cliente_id = cast(cli.ou_num as int64) and ci.marca_ds = 'R'
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x on exp.row_id=exp_x.row_id
                inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro on mst_pro.marca_ds='R'
                and sgvpromo.codigopromo=mst_pro.IdProdCat 
                and mst_pro.tipoProducto in ('SVA') 
                where CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)) AS INT64) >= desde and CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)) AS INT64)  <= hasta
                and sgvpromo.codigopromo is not null
                and exp.sr_type_cd='CONTRATO'
                and sgvpromo.codigocargo is not null
                and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
                and not exists (select idcontrato from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p where p.idcontrato=sgvpromo.idexpediente)

  union all
  ---datos de R
  --- cambios de tarifa móvil que no llevan proceso de provisión y se dan de alta directamente desde siebel hasta singleview sin pasar por voa 
                select 'R' as marca_ds, cast(cli.ou_num as int64), sgvpromo.idproducto, sgvpromo.idexpediente as idcontrato,sgvpromo.idexpediente as idexpediente, "Baja" as accionentidadanterior,sgvpromo2.codigopromo promoanterior,mst_pro2.nombreProducto as descripcionproductoanterior, 'Alta' as accionentidad, sgvpromo.codigopromo promonueva, mst_pro.nombreProducto as descripcionentidadnueva,
                (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_RFB_ID,
                (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
                cast (sgvpromo.FECEFECTIVA as timestamp) fecha_rfb_dt,  cast (exp.CREATED as timestamp) fecha_venta_id,
                c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, emp.attrib_07 agente_venta,
                ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds,  exp_x.attrib_35 medio_conocimiento,case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast (exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else case when cli_x.es_cartera = 'Y' then 'CARTERA' else 'CAPTACION' end end es_cartera, c.equipo_ds,'Finalizado' as estado,mst_pro.tipoProducto,format_date('%Y%m',exp.CREATED) AS periodorfb, format_date('%Y%m',exp.CREATED) AS periodoventa, 'Modificacion' accion,--mst_pro.valor-mst_pro2.valor total, case when mst_pro.valor>mst_pro2.valor then 'Positiva' when mst_pro.valor<mst_pro2.valor then 'Negativa' else 'Nula' end resultado
                mst_pro.concepto, mst_pro2.concepto concepto_origen,cli_x.fecha_ultimo_cambio, cast(sgvpromo2.idproducto as int64),
                concat('Cambio ', mst_pro.tipo_movimiento) tipo_movimiento
                from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo 
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo2 on sgvpromo.idproducto=sgvpromo2.idproducto and DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)-1=DATE_TRUNC(cast (sgvpromo2.FECEXPIRACION as DATE), DAY)
                left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp on sgvpromo.idexpediente=exp.row_id 
                left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp on exp.owner_emp_id=emp.row_id  
                inner join `dw-cloud-euskaltel-prod-283409.D10_CLEANING_EXTERNAL.clean_tr_r_30_maestro_canal` c on   c.agente_venta_id = cast(emp.attrib_07 as int64)
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli on cli.row_id=exp.CST_OU_ID
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x on cli.row_id=cli_x.row_id
                inner join `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci on ci.cliente_id = cast(cli.ou_num as int64) and ci.marca_ds = 'R'
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x on exp.row_id=exp_x.row_id
                inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro on mst_pro.marca_Ds='R' 
                    and sgvpromo.codigopromo=mst_pro.idProdCat
                    and mst_pro.tipoProducto in ('Móvil') 
                left join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro2 on mst_pro2.marca_ds='R'
                    and sgvpromo2.codigopromo=mst_pro2.idProdCat
                    and mst_pro2.tipoProducto in ('Móvil') 
  where CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)) AS INT64) >= desde and CAST(FORMAT_DATE("%Y%m%d",DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)) AS INT64)  <= hasta
                and sgvpromo.codigopromo is not null
                and exp.sr_type_cd='CONTRATO'
                and sgvpromo.codigocargo is not null
                and sgvpromo2.codigocargo is not null
                and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
                and not exists (select p.idcontrato from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
                inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr on p.idproductonew = pr.idProducto
                where p.idcontrato=sgvpromo.idexpediente and sgvpromo.codigoPromo = pr.codigo and pr.accion = 'Alta')



  --) where accion in ('Alta','Modificación') and estado_proceso = 'Finalizado' and 
  ) where accion in ('Alta','Modificación','Modificacion') and estado_proceso = 'Finalizado' and 
  upper(segmento_ds) in ('RESIDENCIAL','SOHO');

    --- PASO 2 CREO TABLA DE LOG
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA` AS
    SELECT
      *
    FROM
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` AS
    SELECT *
    FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` f5
    WHERE NOT EXISTS(
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0104_EVENTOS_CARTERA` f4
      WHERE f5.marca_ds=f4.marca_ds
      and f5.idfijo=f4.idfijo
      and f5.Idproducto=f4.Idproducto
      and f5.TipoMovimiento=f4.TipoMovimiento
    );



END