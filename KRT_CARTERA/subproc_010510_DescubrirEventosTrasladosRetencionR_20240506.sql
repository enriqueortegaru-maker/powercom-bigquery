BEGIN


	DECLARE DESDE DATE;
	DECLARE DESDE_1M DATE;	
	DECLARE HASTA DATE;
	-- VAR LOCAL
	--DECLARE DESDE_INT INT64;DECLARE HASTA_INT INT64;SET DESDE_INT=20240401;SET HASTA_INT=20240430;	
	--- FIN VAR LOCAL
	--SET DESDE = parse_date ('%Y%m%d', CAST ( DESDE_INT AS string));
	--SET DESDE_1M=FORMAT_DATE("%Y%m%d",date_sub(parse_date ('%Y%m%d', CAST ( DESDE_INT AS string)), interval 1 month));	
	SET DESDE = parse_date ('%Y%m%d', CAST ( DESDE_INT AS string));	
	SET DESDE_1M=date_sub(parse_date ('%Y%m%d', CAST ( DESDE_INT AS string)), interval 1 month);		
	SET HASTA = parse_date ('%Y%m%d', CAST ( HASTA_INT AS string));


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_010510_EVENTOS_CARTERA_TRASLADOS_RETENCION_R` as 
	select distinct marca_ds, entidadNueva IdCatalogo, descripcionentidadnueva NombreProducto, distribuidor_ds nombre_distribuidor,  
	canal_agrupado1_ds Canal,  subcanal_ds subcanal,  agente_venta agente, cliente_id IdFijo, cast(fecha_ultimo_cambio as date) Antiguedad, 
	cif_nif DNI_CIF,  es_cartera Marca_Cartera, cast(FECHA_RFB_DT as Date) Fecha_Activacion, CAST(fecha_venta_id as Date) Fecha_Creacion, segmento_ds Segmento, subsegmento_ds Subsegmento,
	entidadanterior idCatalogoOrigen, ID_ORIGEN IdProductoOrigen, descripcionentidadanterior NombreProductoOrigen, 
	TipoProductoOrigen,
	Tipo_Movimiento_Origen as subTipoProductoOrigen,
	Tipo_Movimiento,  
	TipoProducto,
	Tipo_Movimiento as subTipoProducto,
	cast(ID as int64) IdProducto,	
	idcontrato Contrato, 
	agente_venta UsuarioCreador,agente_venta agente_creador_id, "Traslado" concepto_ds, concepto_origen concepto_origen_ds, medio_conocimiento, grid,
	SR_TYPE_CD,
	SR_SUBTYPE_CD,
	X_R_SUBTIPO2,
	operacion
	from (
		select pr.codigo_empresa_bi marca_ds, cast(p.idcliente as int64) cliente_id, coalesce(cast(pr.IDINTERNO as int64), cast(pr.idexterno as int64), 
		row_number()over (partition by p.idcliente)) ID,p.idcontrato,p.idexpediente,pr_origen.accion accionentidadanterior, pr_origen.codigo entidadanterior, 
    pr_origen.descripcion descripcionentidadanterior,  
		pr_origen.tipoProducto as TipoProductoOrigen,
		pr_origen.Tipo_Movimiento as Tipo_Movimiento_Origen,
		pr.accion accionentidad, pr.codigo entidadnueva, pr.descripcion descripcionentidadnueva,-- case when pr.accion='Baja' then -mst_pro.valor else mst_pro.valor end valor,


		case when p.estado='5' then (EXTRACT(YEAR FROM p.LAST_UPD)*10000 + EXTRACT(MONTH FROM p.LAST_UPD) * 100 + EXTRACT(DAY FROM p.LAST_UPD)) else null end FECHA_RFB_ID ,
		(EXTRACT(YEAR FROM exp.CREATED)*10000 + EXTRACT(MONTH FROM exp.CREATED) * 100 + EXTRACT(DAY FROM exp.CREATED)) FECHA_VENTA_NETA_ID,
		case when p.estado='5' then cast(p.last_upd as timestamp) else null end fecha_rfb_dt, cast(p.created as timestamp) fecha_venta_id,
		c.canal_agrupado1_ds, c.subcanal_ds, c.canal_agrupado2_ds, c.distribuidor_ds, emp.attrib_07 agente_venta, 
		ci.cif_nif, ci.segmento_ds, ci.subsegmento_ds, exp_x.attrib_35 medio_conocimiento,
		case when cli_x.es_cartera IS NULL then 'CAPTACION' when (cast(cli_x.fecha_ultimo_cambio as date)>cast(exp.created as date) and cli_x.es_cartera='CARTERA') then 'CAPTACION' else
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
			  case when pr.accion = 'Alta' and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
				  when pr.accion = 'Alta' and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
				  when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is not null then concat('Cambio ', mst_pro.tipo_movimiento) 
				  when pr.accion in ('Modificación', 'Modificacion') and pr_origen.tipoProducto is null then concat('Alta ', mst_pro.tipo_movimiento) 
				  end tipo_movimiento,
			  56 as grid,
			  exp.SR_TYPE_CD,
			  exp.SR_SUBTYPE_CD,
			  exp.X_R_SUBTIPO2,
			  exp.SR_STAT_ID,
			  p.operacion

		from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` exp		
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x` emp on emp.row_id=exp.owner_emp_id		
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req_x` exp_x on exp_x.row_id=exp.row_id
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext_x` cli_x on cli_x.row_id=exp.CST_OU_ID
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p on p.idcontrato=exp_x.row_id 
		left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr on pr.idproducto=p.idproductonew
		left join `dw-cloud-euskaltel-prod-283409.D10_CLEANING_EXTERNAL.clean_tr_r_30_maestro_canal` c on  c.agente_venta_id = cast(emp.attrib_07 as int64)	   
		left join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro on mst_pro.IdProdCat=pr.codigo 
		left join `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` ci on ci.cliente_id = cast(p.idcliente as int64) 
		left join
              (select pr_old.idproducto,pr_old.accion,pr_old.codigo, pr_old.descripcion, mst_pro_old.tipoProducto,--mst_pro_old.valor
               mst_pro_old.tipo_movimiento,pr_old.idInterno,
              mst_pro_old.concepto concepto_origen, pr_old.IDINTERNO ID_ORIGEN
              from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p_old,`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr_old,`mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  mst_pro_old  
              where-- pr_old.accion in ('Baja','Modificacion','Modificación')
              --and 
              p_old.IDPRODUCTOOLD=pr_old.idproducto 
              and mst_pro_old.marca_ds='R'
              and pr_old.codigo=mst_pro_old.idProdCat
              and cast(p_old.LAST_UPD as date) >= desde and cast(p_old.LAST_UPD as date) <= hasta
              ) as pr_origen
		on p.idproductoold=pr_origen.idproducto --and pr_origen.accion='Baja' 
		and pr_origen.tipo_movimiento = mst_pro.tipo_movimiento and pr_origen.tipoProducto = mst_pro.tipoProducto
		and pr_origen.idProducto <> p.idProductoNew
			--and pr.codigo <> pr_origen.codigo
		left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio` est_cli on  cast(p.idcliente as int64) =est_cli.cliente_id  and est_cli.marca_ds='R' and date(desde_dt)<=date(exp.created)  and date(hasta_dt)>=date(exp.created)
		where ((contains_substr(exp.SR_SUBTYPE_CD, 'TRASLADO') and (contains_substr(exp.X_R_SUBTIPO2,'NUMERO'))) or (contains_substr(exp.X_R_SUBTIPO2,'TRASLADO')  and ((contains_substr(exp.SR_SUBTYPE_CD, 'ALTA') or contains_substr(exp.SR_SUBTYPE_CD, 'REESTRUCTURACION') ))))
		and (pr.idInterno <> pr_Origen.idInterno or pr_Origen.idInterno is null)
		and cast(exp.CREATED as date) >= desde_1m and cast(exp.CREATED as date) <= hasta 
		and cast(p.LAST_UPD as date) >= desde and cast(p.LAST_UPD as date) <= hasta
		and mst_pro.marca_ds='R'
		and mst_pro.tipoProducto<>'terminal'
		and pr.accion in ('Alta','Modificacion','Modificación') 
		and ci.marca_ds = 'R'
		and ((p.vigente='Y' and p.estado in ('2','3','4')) or (p.estado ='5') or (p.estado ='6'))
		and cli_x.attrib_43 in ('Residencial','Microempresa','Ambos','Colaborador')       
		and p.operacion not in ('SUSTITUCION TERMINAL DOA','BAJA')
		and not exists (
			select p2.idproductonew
			from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto_atributo` pra2
			inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` pr2 on pr2.row_id=pra2.identidad
			inner join`dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` p2 on p2.idproductonew=pr2.idproducto
			where p2.idproductonew=p.idproductonew
			and pra2.atributo='Atajo' and pra2.valor in ('SI','SÍ','si','sí')
		)
		and contains_substr(mst_pro.tipo_movimiento,"fijos BA")
		and contains_substr(c.canal_agrupado1_ds,"retencion")
    ); 


	UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_010510_EVENTOS_CARTERA_TRASLADOS_RETENCION_R`
	SET Tipo_Movimiento= REPLACE(Tipo_Movimiento, "Alta ", "Traslado ") 
	where contains_substr(Tipo_Movimiento, "Alta ");


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_010510_EVENTOS_CARTERA_TRASLADOS_RETENCION_R_ACTIVOS` AS
	SELECT *
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_010510_EVENTOS_CARTERA_TRASLADOS_RETENCION_R`  
	WHERE Fecha_Activacion is not null;

	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
	SELECT distinct * except(grid, SR_TYPE_CD, SR_SUBTYPE_CD, X_R_SUBTIPO2, operacion) 
	FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_010510_EVENTOS_CARTERA_TRASLADOS_RETENCION_R_ACTIVOS` ;  

END