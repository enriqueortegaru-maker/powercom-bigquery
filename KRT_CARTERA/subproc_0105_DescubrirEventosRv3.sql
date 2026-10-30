BEGIN

    DECLARE DESDE DATE;
    DECLARE HASTA DATE;
    -- VAR LOCAL
    --DECLARE DESDE_INT INT64;DECLARE HASTA_INT INT64;SET DESDE_INT=20240501;SET HASTA_INT=20240531;    
    --- FIN VAR LOCAL
    SET DESDE = parse_date ('%Y%m%d', CAST ( DESDE_INT AS string));
    SET HASTA =  parse_date ('%Y%m%d', CAST ( HASTA_INT AS string));

    --SELECT DESDE_INT, DESDE, HASTA_INT, HASTA;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0104_EVENTOS_CARTERA`;



    --- PASO 1:IDENTIFICO POBLACION DE EVENTOS DE CARTERA EN R         
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE` as 
      select pr.codigo_empresa_bi marca_ds, cast(p.idcliente as int64) cliente_id, coalesce(cast(pr.IDINTERNO as int64), cast(REGEXP_REPLACE(pr.idexterno,'[^0-9 ]','') as int64), 
      row_number()over (partition by p.idcliente)) ID,p.idcontrato,p.idexpediente,pr_origen.accion accionentidadanterior, pr_origen.codigo entidadanterior, pr_origen.descripcion descripcionentidadanterior, pr.accion accionentidad, 
      pr.codigo entidadnueva, pr.descripcion descripcionentidadnueva,
      case when p.estado='5' then (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) else null end FECHA_RFB_ID ,
      (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
      case when p.estado='5' then cast(p.last_upd as timestamp) else null end fecha_rfb_dt, cast(p.created as timestamp) fecha_venta_id,
      c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') agente_venta, 
      ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,
	  	   
	  case  when cli_x.es_cartera IS NULL then 'CAPTACION' 
		    when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='Y') then 'CAPTACION' 
		    else  
				case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' 
					 when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' 
                     else 'CAPTACION' 
                 end 
	  end es_cartera,			
	  	  
	  c.equipo_ds, 
      case p.estado
      when '1' then 'En configuración'
      when '2' then 'Enviando a provisión'
      when '3' then 'En provisión'
      when '4' then 'Enviando a facturación'
      when '5' then 'Finalizado'
      when '6' then 'Cancelado'
      end estado_proceso,case when p.estado='5' then format_date('%Y%m',p.LAST_UPD) else null end periodorfb, 
      format_date('%Y%m',exp.CREATED) AS periodoventa,case when pr.accion='Baja' then 'Baja' when pr_origen.accion='Baja' then 'Modificacion' else 'Alta' end accion, 
      mst_pro.concepto, concepto_origen,cli_x.fecha_ultimo_cambio, cast(ID_ORIGEN as int64) ID_ORIGEN,
      pr_origen.tipoProducto as TipoProductoOrigen,
      pr_origen.tipo_movimiento as subTipoProductoOrigen,
      case  when pr.accion = 'Alta' and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
            when pr.accion = 'Alta' and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
            when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
            when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
            end tipo_movimiento,
      mst_pro.tipoProducto as TipoProducto,
      mst_pro.tipo_movimiento as subTipoProducto,
      pr.idold,
      pr_origen.tipoentidad as tipoentidad_origen,              
      pr.tipoentidad,
      case when pr.tipoentidad=pr_origen.tipoentidad then 1 else 0 end as bmismaentidad,
      case when pr.idold=pr_origen.row_id then 1 else 0 end as bencadenado,
      51 as grid
      from 
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x,
      `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c,
      `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p 
      left join (
            select pr_old.idproducto,pr_old.accion,pr_old.codigo, pr_old.descripcion, mst_pro_old.tipoProducto,--mst_pro_old.valor
            mst_pro_old.tipo_movimiento,pr_old.idInterno,
            mst_pro_old.concepto concepto_origen, pr_old.IDINTERNO ID_ORIGEN, pr_old.row_id, pr_old.tipoentidad 
            from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old,`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old,`mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro_old  
            where p_old.IDPRODUCTOOLD=pr_old.idproducto 
            and mst_pro_old.marca_ds='R'
            and pr_old.codigo=mst_pro_old.idProdCat
            and cast(p_old.LAST_UPD as date) >= desde and cast(p_old.LAST_UPD as date) <= hasta
      ) as pr_origen on p.idproductoold=pr_origen.idproducto and pr_origen.tipo_movimiento = mst_pro.tipo_movimiento and pr_origen.tipoProducto = mst_pro.tipoProducto  and pr_origen.idProducto <> p.idProductoNew 
      left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on  cast(p.idcliente as int64) =est_cli.cliente_id and est_cli.marca_ds='R' and date(desde_dt)<=date(exp.created) and date(hasta_dt)>=date(exp.created)
      where p.idproductonew=pr.idproducto
      and (pr.idInterno <> pr_Origen.idInterno or pr_Origen.idInterno is null)
      and exp.owner_emp_id=emp.row_id
      and cli_x.row_id=exp.CST_OU_ID
      and exp.row_id=exp_x.row_id
      and exp_x.row_id=p.idcontrato
      and cast(p.LAST_UPD as date) >= desde and cast(p.LAST_UPD as date) <= hasta
      and c.agente_venta_id = cast(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') as int64)
      and mst_pro.marca_ds='R'
      and mst_pro.tipoProducto<>'terminal'
      and pr.codigo=mst_pro.IdProdCat
      and (contains_substr(pr.accion,'alta') or contains_substr(pr.accion,'modifica')) 
      and ci.marca_ds = 'R'
      and ci.cliente_id = cast(p.idcliente as int64)
      and ((p.vigente='Y' and p.estado in ('2','3','4')) or (p.estado ='5') or (p.estado ='6'))
      and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
      and exp.SR_SUBTYPE_CD<>'TRASLADO'
      and exp.X_R_SUBTIPO2<>'TRASLADO'
      and p.operacion not in ('SUSTITUCION TERMINAL DOA','BAJA')
      and not contains_substr(p.operacion,'TEMPORAL')
      and not contains_substr(p.operacion,'MOROSO')
      and not exists (
            select p2.idproductonew
            from    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2, 
                    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2, 
                    `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
            where pra2.identidad=pr2.row_id
            and pr2.idproducto=p2.idproductonew
            and p2.idproductonew=p.idproductonew
            and pra2.atributo='Atajo' and pra2.valor in ('SI','SÍ','si','sí') 
      )
      and not(contains_substr(pr.tipoentidad,'PROMOCION'))


      union all
              --- datos de R
              --- equipamiento móvil  

      select pr.codigo_empresa_bi marca_ds, cast(p.idcliente as int64) cliente_id, cast(pr.IDINTERNO as int64) ID,p.idcontrato,p.idexpediente,"" accionentidadanterior, "" entidadanterior, "" descripcionentidadanterior,  pr.accion accionentidad, pr.codigo entidadnueva, pr.descripcion descripcionentidadnueva, --aux_terminales.valor,
        case when p.estado='5' then (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) else null end FECHA_RFB_ID,
        (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
        case when p.estado='5' then cast(p.last_upd as timestamp) else null end fecha_rfb_dt, cast(p.created as timestamp) fecha_venta_id,
        c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') agente_venta, 
        ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,
		
		/*
		case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else
        case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' else 'CAPTACION' end end es_cartera,  
		*/
		
		case  when cli_x.es_cartera IS NULL then 'CAPTACION' 
		    when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='Y') then 'CAPTACION' 
		    else  
				case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' 
					 when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' 
                     else 'CAPTACION' 
                 end 
		end es_cartera,			
		
		
		c.equipo_ds,            
            case p.estado
            when '1' then 'En configuración'
            when '2' then 'Enviando a provisión'
            when '3' then 'En provisión'
            when '4' then 'Enviando a facturación'
            when '5' then 'Finalizado'
            when '6' then 'Cancelado'
            end estado_proceso, case when p.estado='5' then format_date('%Y%m',p.LAST_UPD) else null end periodorfb, 
            format_date('%Y%m',exp.CREATED) AS periodoventa,case when pr.accion='Baja' then 'Baja' else 'Alta' end accion, 
            --case when pr.accion='Baja' then -aux_terminales.valor else aux_terminales.valor end total, 
            --case when pr.accion='Baja' then 'Negativa' else 'Positiva' end resultado
            mst_pro.concepto, "" concepto_origen,cli_x.fecha_ultimo_cambio, null ,
            pr_origen.tipoProducto,
            pr_origen.tipo_movimiento,
            case when pr.accion = 'Alta' then concat('Alta ', mst_pro.tipo_movimiento) when pr.accion in ('Modificación', 'Modificacion') then concat('Cambio ', mst_pro.tipo_movimiento) end tipo_movimiento,
            mst_pro.tipoProducto,
            mst_pro.tipo_movimiento,
            NULL,
            NULL,              
            pr.tipoentidad,
            NULL,
            NULL,
            52 as grid
      from
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x,
      `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c,
      `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci,
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p 
      left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on cast(p.idcliente as int64) =est_cli.cliente_id and est_cli.marca_ds='R' and date(desde_dt)<=date(exp.created) and date(hasta_dt)>date(exp.created)
        --left join `mm-datamart-kd.ZZ_CVM.Maestro_AuxiliarTerminales_KRTV` aux_terminales on aux_terminales.marca='R' and aux_terminales.sistema='R' and date(p.created) between aux_terminales.Vigente_Desde and aux_terminales.Vigente_Hasta and pr.codigomodelo=aux_terminales.Codigo
      left join (
                  select pr_old.idproducto,pr_old.accion,pr_old.codigo, pr_old.descripcion, mst_pro_old.tipoProducto,--mst_pro_old.valor
                  mst_pro_old.tipo_movimiento,pr_old.idInterno,
                  mst_pro_old.concepto concepto_origen, pr_old.IDINTERNO ID_ORIGEN, pr_old.row_id, pr_old.tipoentidad 
                  from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old,`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old,`mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro_old  
                  where-- pr_old.accion in ('Baja','Modificacion','Modificación')
                  --and 
                  p_old.IDPRODUCTOOLD=pr_old.idproducto 
                  and mst_pro_old.marca_ds='R'
                  and pr_old.codigo=mst_pro_old.idProdCat
                  and cast(p_old.LAST_UPD as date) >= desde and cast(p_old.LAST_UPD as date) <= hasta
      ) as pr_origen on p.idproductoold=pr_origen.idproducto /*and pr_origen.accion='Baja'*/ and pr_origen.tipo_movimiento = mst_pro.tipo_movimiento and pr_origen.tipoProducto = mst_pro.tipoProducto  and pr_origen.idProducto <> p.idProductoNew /*and pr.codigo <> pr_origen.codigo*/
      where p.idproductonew=pr.idproducto
      and exp.owner_emp_id=emp.row_id
      and cli_x.row_id=exp.CST_OU_ID
      and exp.row_id=exp_x.row_id
      and exp_x.row_id=p.idcontrato
      and p.LAST_UPD >= desde and cast(p.LAST_UPD as date) <= hasta
      and c.agente_venta_id = cast(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') as int64)
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
      --AÑADIDO
      and not contains_substr(p.operacion,'TEMPORAL')
      and not contains_substr(p.operacion,'MOROSO')
      --FIN AÑADIDO
      and not exists (select p2.idproductonew
                        from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2, `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2, `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2
                        where pra2.identidad=pr2.row_id
                        and pr2.idproducto=p2.idproductonew
                        and p2.idproductonew=p.idproductonew
                        and pra2.atributo='Atajo' and pra2.valor in ('SI','SÍ','si','sí') 
      )

union all
      ---datos de R
      --- productos como bonos o marcadores que no llevan proceso de provisión y se dan de alta directamente desde siebel hasta singleview sin pasar por voa  
      select 'R' as marca_ds, cast(cli.ou_num as int64), sgvpromo.idproducto, sgvpromo.idexpediente as idcontrato,sgvpromo.idexpediente as idexpediente, "" as accionentidadanterior,"" promoanterior,"" as descripcionproductoanterior,--0 as valoranterior,
              'Alta' as accionentidad, sgvpromo.codigopromo promonueva, mst_pro.nombreProducto as descripcionentidadnueva,--mst_pro.valor,
              (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_RFB_ID,
              (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
              cast (sgvpromo.FECEFECTIVA as timestamp) fecha_rfb_dt,  cast (exp.CREATED as timestamp) fecha_venta_id,
              c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') agente_venta,
              ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,

			  /*
              case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast (exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else case when cli_x.es_cartera = 'Y' then 'CARTERA' else 'CAPTACION' end end es_cartera,
			 */

			  case  when cli_x.es_cartera IS NULL then 'CAPTACION' 
					when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='Y') then 'CAPTACION' 
					else  
						case when cli_x.es_cartera = 'Y' /*and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')*/  then 'CARTERA' 
							 /*when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' */ 
						else 'CAPTACION' 
						end 
			  end es_cartera,			
			  
              c.equipo_ds,'Finalizado' as estado,format_date('%Y%m',exp.CREATED) AS periodorfb, format_date('%Y%m',exp.CREATED) AS periodoventa, 'Alta' accion,
              /*mst_pro.valor total, 'Positiva' resultado*/
              mst_pro.concepto, "" concepto_origen,cli_x.fecha_ultimo_cambio, null, 
              mst_pro2.tipoProducto,
              mst_pro2.tipo_movimiento ,
              concat('Alta ', mst_pro.tipo_movimiento) tipo_movimiento,
              mst_pro.tipoProducto,
              mst_pro.tipo_movimiento,             
              NULL,
              NULL,              
              "PROMOCION",
              NULL,
              NULL,
              53 as grid
      from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo 
      left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp on sgvpromo.idexpediente=exp.row_id 
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp on exp.owner_emp_id=emp.row_id  
      inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c on   c.agente_venta_id = cast(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') as int64)
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli on cli.row_id=exp.CST_OU_ID
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x on cli.row_id=cli_x.row_id
      inner join `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci on ci.cliente_id = cast(cli.ou_num as int64) and ci.marca_ds = 'R'
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x on exp.row_id=exp_x.row_id
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro on mst_pro.marca_ds='R' and sgvpromo.codigopromo=mst_pro.IdProdCat  and mst_pro.tipoProducto in ('SVA') 
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo2 on sgvpromo.idproducto=sgvpromo2.idproducto and DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)-1=DATE_TRUNC(cast (sgvpromo2.FECEXPIRACION as DATE), DAY)      
      left join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro2 on mst_pro2.marca_ds='R'and sgvpromo2.codigopromo=mst_pro2.idProdCat and mst_pro2.tipoProducto in ('SVA') 
      --left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on  cast(p.idcliente as int64) =est_cli.cliente_id  and est_cli.marca_ds='R'  and date(desde_dt)<=date(exp.created)  and date(hasta_dt)>=date(exp.created)	  
      where DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY) >= desde and DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)  <= hasta
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
            c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') agente_venta,
            ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds,  exp_x.attrib_35 medio_conocimiento,
			
			/*
            case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast (exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else case when cli_x.es_cartera = 'Y' then 'CARTERA' else 'CAPTACION' end end es_cartera,
			*/
			
			case  when cli_x.es_cartera IS NULL then 'CAPTACION' 
					when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='Y') then 'CAPTACION' 
					else  
						case when cli_x.es_cartera = 'Y' /*and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')*/  then 'CARTERA' 
							 /*when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' */ 
						else 'CAPTACION' 
						end 
			end es_cartera,			
			
			c.equipo_ds,'Finalizado' as estado,format_date('%Y%m',exp.CREATED) AS periodorfb, format_date('%Y%m',exp.CREATED) AS periodoventa, 'Modificacion' accion,
            /*mst_pro.valor-mst_pro2.valor total, case when mst_pro.valor>mst_pro2.valor then 'Positiva' when mst_pro.valor<mst_pro2.valor then 'Negativa' else 'Nula' end resultado*/
            mst_pro.concepto, mst_pro2.concepto concepto_origen,cli_x.fecha_ultimo_cambio, cast(sgvpromo2.idproducto as int64),
            mst_pro2.tipoProducto,
            mst_pro2.tipo_movimiento,
            concat('Cambio ', mst_pro.tipo_movimiento) tipo_movimiento,
            mst_pro.tipoProducto,
            mst_pro.tipo_movimiento,
            NULL,
            NULL,              
            "PROMOCION",
            NULL,
            NULL,              
            54 as grid
      from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo 
      left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp on sgvpromo.idexpediente=exp.row_id 
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp on exp.owner_emp_id=emp.row_id  
      inner join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c on   c.agente_venta_id = cast(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') as int64)
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cli on cli.row_id=exp.CST_OU_ID
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x on cli.row_id=cli_x.row_id
      inner join `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci on ci.cliente_id = cast(cli.ou_num as int64) and ci.marca_ds = 'R'
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x on exp.row_id=exp_x.row_id
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro on mst_pro.marca_Ds='R'and sgvpromo.codigopromo=mst_pro.idProdCat and mst_pro.tipoProducto in ('Móvil') 
      inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` sgvpromo2 on sgvpromo.idproducto=sgvpromo2.idproducto and DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)-1=DATE_TRUNC(cast (sgvpromo2.FECEXPIRACION as DATE), DAY)      
      --left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on  cast(p.idcliente as int64) =est_cli.cliente_id  and est_cli.marca_ds='R'  and date(desde_dt)<=date(exp.created)  and date(hasta_dt)>=date(exp.created)	  
      left join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` mst_pro2 on mst_pro2.marca_ds='R'and sgvpromo2.codigopromo=mst_pro2.idProdCat and mst_pro2.tipoProducto in ('Móvil') 
      where DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY) >= desde and DATE_TRUNC(cast (sgvpromo.FECEFECTIVA as DATE), DAY)  <= hasta
      and sgvpromo.codigopromo is not null
      and exp.sr_type_cd='CONTRATO'
      and sgvpromo.codigocargo is not null
      and sgvpromo2.codigocargo is not null
      and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
      and not exists (select p.idcontrato from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
                              inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr on p.idproductonew = pr.idProducto
                              where p.idcontrato=sgvpromo.idexpediente and sgvpromo.codigoPromo = pr.codigo and pr.accion = 'Alta'
      )

      union all
        ----- ADICIONAL 
        ----    Resuelve identificadores de producto asociados a promociones

      select distinct pr.codigo_empresa_bi marca_ds, cast(p.idcliente as int64) cliente_id, trpr.idproducto as ID,
            p.idcontrato,p.idexpediente,pr_origen.accion accionentidadanterior, pr_origen.codigo entidadanterior, pr_origen.descripcion descripcionentidadanterior,  pr.accion accionentidad, pr.codigo entidadnueva, pr.descripcion descripcionentidadnueva,
            /*case when pr.accion='Baja' then -mst_pro.valor else mst_pro.valor end valor,*/
            case when p.estado='5' then (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) else null end FECHA_RFB_ID ,
            (EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
            case when p.estado='5' then cast(p.last_upd as timestamp) else null end fecha_rfb_dt, cast(p.created as timestamp) fecha_venta_id,
            c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') agente_venta, 
            ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,
			/*	
            case  when cli_x.es_cartera IS NULL then 'CAPTACION' 
                  when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' 
                  else  case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' 
                      when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' 
                      else 'CAPTACION' 
                  end 
            end es_cartera,  
			*/
			
  		   case  when cli_x.es_cartera IS NULL then 'CAPTACION' 
				when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='Y') then 'CAPTACION' 
				else  
					case when cli_x.es_cartera = 'Y' and (est_cli.clasificacion_ds<>'SOMO' and est_cli.clasificacion_ds<>'INACTIVO')  then 'CARTERA' 
						 when cli_x.es_cartera = 'Y' and est_cli.clasificacion_ds='SOMO' and exp.X_R_SUBTIPO2="MOVIL" then 'CARTERA' 
						 else 'CAPTACION' 
					 end 
		   end es_cartera,			
			
            c.equipo_ds, 
            case p.estado
              when '1' then 'En configuración'
              when '2' then 'Enviando a provisión'
              when '3' then 'En provisión'
              when '4' then 'Enviando a facturación'
              when '5' then 'Finalizado'
              when '6' then 'Cancelado'
            end estado_proceso,case when p.estado='5' then format_date('%Y%m',p.LAST_UPD) else null end periodorfb, 
            format_date('%Y%m',exp.CREATED) AS periodoventa,case when pr.accion='Baja' then 'Baja' when pr_origen.accion='Baja' then 'Modificacion' else 'Alta' end accion, 
              /*case when pr.accion='Baja' then -mst_pro.valor else mst_pro.valor-ifnull(pr_origen.valor,0) end total, 
              case when pr.accion='Baja' then 'Negativa' when mst_pro.valor>ifnull(pr_origen.valor,0) then 'Positiva' when mst_pro.valor<ifnull(pr_origen.valor,0) then 'Negativa' else 'Nula' end resultado*/
            mst_pro.concepto, concepto_origen,cli_x.fecha_ultimo_cambio, cast(ID_ORIGEN as int64) ID_ORIGEN,
            pr_origen.tipoProducto,
            pr_origen.tipo_movimiento,
            case  when pr.accion = 'Alta' and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
                  when pr.accion = 'Alta' and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
                  when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
                  when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
            end tipo_movimiento,
            mst_pro.tipoProducto,
            mst_pro.tipo_movimiento,
            pr.idold,
            pr_origen.tipoentidad,              
            pr.tipoentidad,
            case when pr.tipoentidad=pr_origen.tipoentidad then 1 else 0 end as bmismaentidad,
            case when pr.idold=pr_origen.row_id then 1 else 0 end as bencadenado,
            55 as grid
            /*, pr.tipoentidad, trsrv.idservicio, trsrv.idproducto  */
        from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr                  on pr.idproducto=p.idproductonew
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x               on exp_x.row_id=p.idcontrato
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp                   on exp.sr_num=exp_x.row_id
        inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro                       on mst_pro.IdProdCat=pr.codigo
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp                 on emp.row_id=exp.owner_emp_id
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x                on cli_x.row_id=exp.CST_OU_ID
        left join `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c  on c.agente_venta_id = cast(REGEXP_EXTRACT(emp.attrib_07, r'[0-9]+') as int64)
        left join `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci         on ci.cliente_id = cast(p.idcliente as int64)
        left join
              (select pr_old.idproducto,pr_old.accion,pr_old.codigo, pr_old.descripcion, mst_pro_old.tipoProducto,--mst_pro_old.valor
               mst_pro_old.tipo_movimiento,pr_old.idInterno,
              mst_pro_old.concepto concepto_origen, pr_old.IDINTERNO ID_ORIGEN, pr_old.row_id, pr_old.tipoentidad 
              from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old 
              inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old on p_old.IDPRODUCTOOLD=pr_old.idproducto 
              inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro_old      on mst_pro_old.idProdCat=pr_old.codigo  
              where mst_pro_old.marca_ds='R'
              and cast(p_old.LAST_UPD as date) >= desde and cast(p_old.LAST_UPD as date) <= hasta
              --and pr_old.accion in ('Baja','Modificacion','Modificación')
              ) as pr_origen
        on p.idproductoold=pr_origen.idproducto and pr_origen.tipo_movimiento = mst_pro.tipo_movimiento and pr_origen.tipoProducto = mst_pro.tipoProducto and pr_origen.idProducto <> p.idProductoNew--and pr_origen.accion='Baja' --and pr.codigo <> pr_origen.codigo
        left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on  cast(p.idcliente as int64) =est_cli.cliente_id  and est_cli.marca_ds='R'  and date(desde_dt)<=date(exp.created)  and date(hasta_dt)>=date(exp.created)
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` trpr   on trpr.idexpediente=p.idexpediente
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_servicio` trsrv  on CAST(trsrv.idproducto  AS STRING)=p.idproductonew
        where mst_pro.marca_ds='R'
        and mst_pro.tipoProducto<>'terminal'
        and exp.SR_SUBTYPE_CD<>'TRASLADO'
        and exp.X_R_SUBTIPO2<>'TRASLADO'       
        and (pr.idInterno <> pr_Origen.idInterno or pr_Origen.idInterno is null)
        and pr.accion in ('Alta','Modificacion','Modificación')
        and p.operacion not in ('SUSTITUCION TERMINAL DOA','BAJA')
        --AÑADIDO
        and not contains_substr(p.operacion,'TEMPORAL')
        and not contains_substr(p.operacion,'MOROSO')
        --FIN AÑADIDO        
        and cast(p.LAST_UPD as date) >= desde and cast(p.LAST_UPD as date) <= hasta
        and ((p.vigente='Y' and p.estado in ('2','3','4')) or (p.estado ='5') or (p.estado ='6'))
        and ci.marca_ds = 'R'        
        and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')
        and not exists (
            select p2.idproductonew
            from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2 
            inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2 on pr2.idproducto=p2.idproductonew             
            inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2  on pra2.identidad=pr2.row_id
            where p2.idproductonew=p.idproductonew
            and pra2.atributo='Atajo' and pra2.valor in ('SI','SÍ','si','sí')        
        ) and contains_substr(pr.tipoentidad,'PROMOCION');


      --- PASO 2:EXCLUYO CAMBIOS ENTRE DISTINTAS ENTIDADES         
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE_EXCLUIDOS` as 
      SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE`             
      WHERE bmismaentidad=0 and contains_substr(tipo_movimiento,'cambio');

      DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE` where bmismaentidad=0 and contains_substr(tipo_movimiento,'cambio');


      --- PASO 3:FORMATEOR EVENTOS PARA INTEGRARLOS EN TABLA EVENTOS     
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` as 
      select distinct marca_ds, entidadNueva IdCatalogo, descripcionentidadnueva NombreProducto, distribuidor_ds nombre_distribuidor,  
      canal_agrupado1_ds Canal,  subcanal_ds subcanal,  agente_venta agente, cliente_id IdFijo, cast(fecha_ultimo_cambio as date) Antiguedad, 
      cif_nif DNI_CIF,  es_cartera Marca_Cartera, cast(FECHA_RFB_DT as Date) Fecha_Activacion, CAST(fecha_venta_id as Date) Fecha_Creacion, segmento_ds Segmento, subsegmento_ds Subsegmento,
      entidadanterior, ID_ORIGEN IdProductoOrigen, descripcionentidadanterior NombreProductoOrigen, 
      /* AÑADIDO */
      TipoProducto,
      subTipoProducto,
      /* FIN AÑADIDO */
      Tipo_Movimiento, 
      /* AÑADIDO */
      TipoProductoOrigen,
      subTipoProductoOrigen,
      /* FIN AÑADIDO */
      cast(ID as int64) IdProducto, idcontrato Contrato, 
      agente_venta UsuarioCreador,agente_venta agente_creador_id, concepto concepto_ds, concepto_origen concepto_origen_ds, medio_conocimiento, grid  
      from `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_FUENTE`   
      where accion in ('Alta','Modificación','Modificacion') and estado_proceso = 'Finalizado' and  upper(segmento_ds) in ('RESIDENCIAL','SOHO');



   --- PASO 4 ELIMINO EVENTOS DE PROMOCIONES CON MISMO ORIGEN Y DESTINO

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_PROMOS_MISMO_CAT_ORyDEST` as 
      SELECT *  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` where grid=54 and UPPER(TRIM(IdCatalogo))=UPPER((entidadAnterior));  

      CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` AS 
      SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` e
      EXCEPT DISTINCT 
            SELECT *
            FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_PROMOS_MISMO_CAT_ORyDEST`;
      

   --- PASO 5·: ELIMINO EVENTOS DE R CON FECHA DE VENTA CON MAS DE 4 MESES DE ANTIGUEDAD

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_VENTAS_CAPTACION_R_FV_INCONSISTENTE`  AS 
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` WHERE Fecha_Creacion< DATE_TRUNC(DATE_SUB(DESDE, interval 4 month),MONTH);

	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` c
	WHERE exists (
	  SELECT 1 
	  from `mm-commissions-reporting.KRT_CARTERA.LOG_0105_VENTAS_CAPTACION_R_FV_INCONSISTENTE` v
	  where v.idFijo=c.idFijo and v.idProducto=c.idProducto and c.Fecha_Creacion=v.Fecha_Creacion
	);

      DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR` c
      where c.idProducto is null and  Fecha_Creacion< DATE_TRUNC(DATE_SUB(DESDE, interval 4 month),MONTH);


      -----------------------------------------------------
      ---
      ---   PARCHE INCLUIDO 20250207
      ---

      --- PASO 6: IDENTIFICO CATALOGOS CON CARACTERES NO VISIBLES EN DESCRIPCION
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_CATALOGO_CARACTER_NO_VISIBLE` AS
	SELECT distinct NombreProducto
      ,count(idProducto) over(partition by NombreProducto) as npr
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`
	where regexp_contains(NombreProducto, r'[\x00-\x1f\xc2\xa0]')
	order by 1 asc;

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_CATALOGO_ORIGEN_CARACTER_NO_VISIBLE` AS
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

      ---
      ---   FIN PARCHE INCLUIDO
      ---
      -----------------------------------------------------




      --- PASO 6: INSERTO REGISTROS EN TABLA EVENTOS


      insert into `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
      SELECT distinct * except(grid) FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA_INCR`;  


      --- PASO 7: ELIMINO DUPLICADOS
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS
      SELECT distinct * from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;



      --- PASO 8: CREO TABLA DE LOG
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA` AS
      SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


END