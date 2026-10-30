BEGIN


  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`	AS select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_CAPTACION`;


  ---- PASO O: Eliminar potenciales duplicidades de ventas por duplicidades de servicios_id causados por combinaciones múltiples de valores
	----				 En campos meramente informativos como tipo_pedido_ds pedido_ds, tipo_producto_pedido_re_ds o visbilidad_pedido_lg

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_VENTAS_CAPTACION_DUPLICADAS_POR_TIPO_PEDIDO_NA`	AS 
	with dup as (
		select  marca_ds, servicio_id, pedido_id, count(cliente_id) as nserv, count(distinct if(tipo_pedido_ds='NA',servicio_id,NULL) ) nnulo,count(distinct if(tipo_pedido_ds!='NA',servicio_id,NULL) ) nnonulo 
		FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
		where (CONTAINS_SUBSTR(clase_mm,"A - Servicio base") or CONTAINS_SUBSTR(clase_mm,"B - Television acceso"))  
		--where grid<5
		and servicio_id>0
		group by 1,2,3
		having count(cliente_id)>1
	) select distinct s.*, nnulo, nnonulo 
	from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` as s
	inner join dup
	on s.marca_ds=dup.marca_ds and s.servicio_id=dup.servicio_id and s.tipo_pedido_ds='NA' and dup.nnonulo=1
	order by 1,2;

	delete from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
	where exists(
			select 1 
			from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_VENTAS_CAPTACION_DUPLICADAS_POR_TIPO_PEDIDO_NA` p
			where p.marca_ds=v.marca_ds and p.cliente_id=v.cliente_id and p.servicio_id=v.servicio_id and p.detalle_servicio_ds=v.detalle_servicio_ds and p.tipo_pedido_ds=v.tipo_pedido_ds
	);




  ---- PASO 1: Crear el pedido id normalizado
	----				En campo pedido se escribe:
	----						Marca R: Valor de campo expediente_padre_id
	----						Marca no R: Valor de campo pedido_id si éste es superior a 0.

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`	AS 
	SELECT * , case when marca_ds!="R" and pedido_id>0  then cast(pedido_id as STRING)  when marca_ds="R"	then expediente_padre_id END pedido
	FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;


		--select count(servicio_id) from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where pedido is not null and pedido_id<0;

	--- PASO 2: Corregir valor registrado en campo pedido_id para aquellos servicios que registan el valor -999999999 en el campo pedido_id 
	---					Se actualiza el pedidos_id del servicio, con el pedido_id de otras ventas realizadas al cliente que cumplan las siguientes condiciones:
	---							Registran la misma fecha_venta_neta_dt que el producto sin pedido_id informado. 
	---							Todas las ventas con esa fecha_venta_neta_dt están asociadas a un único pedido (excluyendo el valor -9999999999)
	

			----- PASO 2.1: Corregir identificación de pedido en ventas de servicios con pedido_id=-999999999, en clientes a los que se les hayan vendido 
			--							varios servicios en la misma fecha_venta_neta_dt.
			--
						-- PASO 2.1.1. Se identifican ventas con pedido_id=-999999999, que pueden relacionarse con múltiples pedidos de ventas que registran 
						--							la misma fecha_venta_neta_dt. Estas ventas se registran en la tabla LOG_0110_PEDIDOS_NULOS_MULTIPLES_CANDIDATOS  .
						--
						--							Registra casos en el que un cliente 
						--									Registra al menos una venta con pedido_id=-999999999
						--									Registra múltiples ventas de servicios a un cliente con la misma fecha y hora (fecha_venta_net_dt), pero con distintos pedido_id


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_VENTAS_MULTIPLES_PEDIDOS_MISMA_FV` AS 
	with dup as (
		-- Servicios sin pedido_id me cruzan con mas de un pedido
		select marca_ds,cliente_id, servicio_id, count(pedido_id) as nped
		from  (
			with snp as ( 
				select distinct marca_ds, cliente_id, categoria_servicio_ds, servicio_id, fecha_venta_neta_dt, fecha_rfb_dt, pedido_id 
				from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
				where pedido_id=-999999999
				order by 1,2,3
			) select distinct v.marca_ds, v.cliente_id, v.pedido_id, snp.servicio_id,snp.fecha_venta_neta_dt as fecha_vs, v.fecha_venta_neta_dt as fecha_vv from snp
			inner join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v  
			on snp.marca_ds=v.marca_ds and snp.cliente_id=v.cliente_id and snp.fecha_venta_neta_dt=v.fecha_venta_neta_dt 
			where v.pedido_id>0
			and v.grid<5 --- Solo se consideran servicios principales
			order by 1,2,3
		)		
		group by 1,2,3
		having count(pedido_id)>1)
	select v.* from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 
	inner join dup d 
	on d.marca_ds=v.marca_ds and d.cliente_id=v.cliente_id and d.servicio_id=v.servicio_id;


						-- PASO 2.1.2. Se actualiza el id de pedido en 
						--								Servicios vendidos a un cliente con pedido_id=-999999999 
						--										El cliente registra otras ventas con la misma fecha_venta_neta_dt que la venta del servicio asociada al pedido_id=-999999999
						--										Todas las otras ventas registran la misma fecha_venta_neta_dt 
						--

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` AS 
		with pob as (
			with snp as ( 
				select distinct marca_ds, cliente_id, categoria_servicio_ds, servicio_id, fecha_venta_neta_dt, fecha_rfb_dt, pedido_id 
				from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
				where pedido_id=-999999999
				order by 1,2,3
			) select distinct v.marca_ds, v.cliente_id, v.pedido_id, snp.servicio_id,snp.fecha_venta_neta_dt as fecha_vs, v.fecha_venta_neta_dt as fecha_vv from snp
			inner join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v  
			on snp.marca_ds=v.marca_ds and snp.cliente_id=v.cliente_id and snp.fecha_venta_neta_dt=v.fecha_venta_neta_dt 
			where v.pedido_id>0
			and v.grid<5 --- Solo se consideran servicios principales
			order by 1,2,3
		) select v.*, CAST(p.pedido_id AS STRING) as pedido_nuevo_valor, 'fvn_dt unico' as criterio, 1 as fase
		from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		inner join pob p
		on v.marca_ds=p.marca_ds
		and v.cliente_id=p.cliente_id
		--and v.fecha_venta_neta_dt=p.fecha_vv
		and v.servicio_id=p.servicio_id
		where not exists(
			select 1 
			from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_VENTAS_MULTIPLES_PEDIDOS_MISMA_FV`  pm
			WHERE v.marca_ds=pm.marca_ds
			and v.cliente_id=pm.cliente_id
		--and v.fecha_venta_neta_dt=p.fecha_vv
			and v.servicio_id=pm.servicio_id
		);

		-- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` 
		--select count(distinct servicio_id) from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` where contains_substr(pedido,"-999999") and grid <5;
		--select marca_ds, count(distinct servicio_id) from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` where contains_substr(pedido,"-999999") and grid <5 group by 1;


		-- Actualización de pedido en ventas que pueden asociarse a un único pedido

  UPDATE  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  SET pedido = pedido_nuevo_valor--TRIM(cast (pedido_nuevo_valor as string)) --TRIM(cast (p.pedido_id as string))
	from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` p
	WHERE v.marca_ds=p.marca_ds
	and v.cliente_id=p.cliente_id
	--and v.fecha_venta_neta_dt=p.fecha_vv
	and v.servicio_id=p.servicio_id;

		--select count(servicio_id) from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where pedido is not null and pedido_id<0;
		--select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where CONTAINS_SUBSTR(pedido,'-999999' );		





			----- PASO 2.3: Corregir identificación de pedido en ventas de servicios con pedido_id=-999999999,
			--							 en clientes a los que un distribuidor les hayan vendido varios servicios en mes de comisionado o previo
			--							CONDICIONES:
			--									Venta con pedido_id -99999999999 se relaciona con otras ventas realizadas por el distribuidor en el mismo canal y subcanal
			--

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_LIST_CRUCE_RESTO_VENTAS_CLIENTE` AS 
	with clm as (
	   	select distinct marca_ds,cliente_id,
			canal_alta_ds, subcanal_ds, 
			nombre_distribuidor_alta_ds 
	   	from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
	   	--where pedido_id=-999999999 
			where pedido is null 
			and grid<5
	)
	select v.marca_ds,v.cliente_id, 
	v.canal_alta_ds, v.subcanal_ds, 
	v.nombre_distribuidor_alta_ds,
	v.cif_nif, v.pedido,
	count(distinct v.categoria_servicio_ds) as nplays_v,
	count(distinct if(v.fecha_rfb_id is not null ,v.categoria_servicio_ds,NULL)) as nplays_a,      
	count(v.servicio_id) as nserv,
	from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` as v 
	inner join clm as c 
	on c.marca_ds=v.marca_ds and c.cliente_id=v.Cliente_id
	where v.categoria_servicio_ds in ('FIJA','BANDA ANCHA','TELEVISION','MOVILES POSTPAGO') 
	--and s.marca_ds="TELECABLE" --and s.pedido_id!=-999999999  and s.pedido_id is not null 
	--and s.pedido is not null 
	and v.grid<5 --- Solo se consideran servicios principales
	--and s.marca_ds='R' 
	   --and marca_ds="R"
	group by 1,2,3,4,5,6,7
	--having count(distinct s.categoria_servicio_ds)>1
	   --having count(distinct categoria_servicio_ds) != count(distinct if(fecha_rfb_id is not null ,categoria_servicio_ds,NULL))
	order by 1,2,3,4,5,6,7;



	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE` AS 
		with ventas as (
          with clor as (
              SELECT cat, o1 as orden 
              FROM UNNEST(['BANDA ANCHA','FIJA','TELEVISION','MOVILES POSTPAGO']) cat 
              WITH OFFSET o1
          ) select v.*, clor.orden from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
          inner join clor 
          on clor.cat=v.categoria_servicio_ds
    ) select --v.* ,
      v.marca_ds, v.cliente_id, v.cif_nif,
			v.canal_alta_ds, v.subcanal_ds, 
			v.nombre_distribuidor_alta_ds,
      count(distinct v.pedido) as np,
     max(v.pedido) as ped_max,
      min(v.pedido) as ped_min,
      count(distinct fecha_venta_neta_id) as n_fv,
      count(distinct fecha_rfb_id) as n_fr,
      max(fecha_venta_neta_id) as fv_max,
      min(fecha_venta_neta_id) as fv_min,    
      max(fecha_rfb_id) as fr_max,
      min(fecha_rfb_id) as fr_min,
			DATE_DIFF(max(extract(DATE FROM fecha_venta_neta_dt)), min(extract(DATE FROM fecha_venta_neta_dt)), DAY) as dif_fv,
			DATE_DIFF(max(extract(DATE FROM fecha_rfb_dt)), min(extract(DATE FROM fecha_rfb_dt)), DAY) as dif_fr,			
		from ventas as v
    inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_LIST_CRUCE_RESTO_VENTAS_CLIENTE` as p
		on p.marca_ds=v.marca_ds and p.cliente_id=v.Cliente_id and p.canal_alta_ds=v.canal_alta_ds and p.subcanal_ds=v.subcanal_ds and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds   
		where v.desc_mm not in ('B - Television contenido','B - Fijo','B - Alarma','B - Terminales')
		--and v.marca_ds='TELECABLE'
		and v.grid<5 --- Solo se consideran servicios principales
    group by 1,2,3,4,5,6		
		order by v.marca_ds asc, v.cliente_id asc, v.canal_alta_ds asc, v.subcanal_ds asc, v.nombre_distribuidor_alta_ds asc;	

	
		-- 	Identifico casos que se pueden asociar a un único pedido
		INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` 
		with pob as (
			select v.*
			from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v  
			inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE` as p
			on p.marca_ds=v.marca_ds and p.cliente_id=v.Cliente_id and p.canal_alta_ds=v.canal_alta_ds and p.subcanal_ds=v.subcanal_ds and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
			where p.np=1
			and v.grid<5
			--and v.cliente_id=7598465
			order by v.marca_ds, v.cliente_id, v.categoria_servicio_ds
		) select distinct pp.*, CAST(pnp.pedido AS STRING) as pedido_nuevo_valor, 'pedido_id unico' as criterio, 10 as fase
		from (select * from pob where pedido is not null) as pnp
		inner join (select * from pob where pedido is null) as pp
		on pp.marca_ds=pnp.marca_ds and pp.cliente_id=pnp.cliente_id and pp.canal_alta_ds=pnp.canal_alta_ds and pp.subcanal_ds=pnp.subcanal_ds and pp.nombre_distribuidor_alta_ds=pnp.nombre_distribuidor_alta_ds;

		--select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` v where fase=10 and CONTAINS_SUBSTR(pedido_nuevo_valor,'-999999' );		
		--select count(distinct servicio_id) from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` where contains_substr(pedido,"-999999") and grid <5;
		--select marca_ds, count(distinct servicio_id) from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` where contains_substr(pedido,"-999999") and grid <5 group by 1;


		-- Actualización de pedido en ventas que pueden asociarse a un único pedido

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET pedido = p.pedido_nuevo_valor
		from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` p
		WHERE v.marca_ds=p.marca_ds
		and v.cliente_id=p.cliente_id
		and p.canal_alta_ds=v.canal_alta_ds and p.subcanal_ds=v.subcanal_ds and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
		--and v.fecha_venta_neta_dt=p.fecha_vv
		and v.servicio_id=p.servicio_id
		and p.fase=10;

	--select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where CONTAINS_SUBSTR(pedido,'-999999' );		

	----- Actualización de pedido en ventas que pueden asociarse a dos o mas pedidos. 
	-----		El criuterio empleado se bas a en que la actualización del pedido se realiza en base a otras ventas realizadas a ese mismo cliente por el mismo distribuidor, y en el mismo canal en el que se realió la venta sin id pedido informado
	
		INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` 
				with cand as (					
					with c as (
						with pob as (
							SELECT *
							from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE`
							where np>1
						) select  v.marca_ds, v.cliente_id,v.canal_alta_ds, v.subcanal_ds, v.nombre_distribuidor_alta_ds, v.pedido, v.fecha_venta_neta_dt,pob.np, count(distinct categoria_servicio_ds) as ncat, ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ) as cat , 
						--count(distinct categoria_servicio_ds) + case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"BANDA") THEN 40 ELSE 0 END as peso
						count(distinct categoria_servicio_ds)*(case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"BANDA") THEN 40  ELSE 0 END +  case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"MOVILES") THEN 30 ELSE 0 END +  case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"FIJA" ) OR CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"FIJA" ) THEN 20 ELSE 0 END) as peso
						from  pob 
						inner join `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 					
						on pob.marca_ds=v.marca_ds and pob.cliente_id=v.cliente_id and  pob.canal_alta_ds=v.canal_alta_ds and pob.subcanal_ds=v.subcanal_ds and pob.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
						where v.grid<5
						group by 1,2,3,4,5,6,7,8
						order by 1,2,3,4,5,6
					) select distinct pnul.marca_ds, pinf.cliente_id, pnul.canal_alta_ds, pnul.subcanal_ds, pnul.nombre_distribuidor_alta_ds, pinf.pedido,
					 pinf.ncat as ncat_inf, pinf.cat as cat_pinf, pnul.ncat as ncat_nul, pnul.cat as cat_nul, 
					 pinf.fecha_venta_neta_dt as fvinf,	pnul.fecha_venta_neta_dt as fvnul,
					date_diff(pinf.fecha_venta_neta_dt,	pnul.fecha_venta_neta_dt,MINUTE) as difinf_nul,pinf.peso+pnul.peso as peso,
					ROW_NUMBER() OVER(PARTITION BY pinf.marca_ds, pinf.cliente_id,pinf.canal_alta_ds, pinf.subcanal_ds, pinf.nombre_distribuidor_alta_ds  
					ORDER BY (pinf.peso + pnul.peso) desc, ABS(date_diff(pinf.fecha_venta_neta_dt,	pnul.fecha_venta_neta_dt,MINUTE)) asc, pinf.ncat desc ) as orden
					from (select marca_ds, cliente_id, pedido, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, ncat, fecha_venta_neta_dt,  cat, peso 
					from c
					where pedido is null) as pnul
					left join (select marca_ds, cliente_id, pedido,canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, ncat, fecha_venta_neta_dt, cat, peso 
					from c
					where pedido is not null) as pinf
					on pnul.marca_ds=pinf.marca_ds and pnul.cliente_id=pinf.cliente_id and pnul.canal_alta_ds=pinf.canal_alta_ds and pnul.subcanal_ds=pinf.subcanal_ds and pnul.nombre_distribuidor_alta_ds=pinf.nombre_distribuidor_alta_ds
					where not (contains_substr(pinf.cat,"BANDA") and contains_substr(pnul.cat,"BANDA"))
					and  not (contains_substr(pinf.cat,"FIJA") and contains_substr(pnul.cat,"FIJA"))
					and  not (contains_substr(pinf.cat,"TELEVISION") and contains_substr(pnul.cat,"TELEVISION"))
					--and orden=1					
					order by cliente_id asc, orden
				)  select distinct v.*, CAST(c.pedido AS STRING) as pedido_nuevo_valor, 'pedido_id multiple' as criterio, 11 as fase
				from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 	
				inner join cand c
				on c.marca_ds= v.marca_ds and c.cliente_id=v.cliente_id and c.canal_alta_ds=v.canal_alta_ds and c.subcanal_ds=v.subcanal_ds and c.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
				where c.orden=1 
				and c.pedido is not null
				and v.pedido is null
				and v.grid<5;

			-- Actualización de pedido en ventas que pueden asociarse a varios pedidos

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET pedido = p.pedido_nuevo_valor
		from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` p
		WHERE v.marca_ds=p.marca_ds
		and v.cliente_id=p.cliente_id
		and p.canal_alta_ds=v.canal_alta_ds and p.subcanal_ds=v.subcanal_ds and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
		--and v.fecha_venta_neta_dt=p.fecha_vv
		and v.servicio_id=p.servicio_id
		and p.fase=11;



	
 		--Select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE` where cliente_id=7599727;

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CLIENTES_PENDIENTES` AS 
		SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_LIST_CRUCE_RESTO_VENTAS_CLIENTE` v
		where pedido is null
		and not exists(
			select 1
			from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` a
			where a.marca_ds=v.marca_ds
			and a.cliente_id=v.cliente_id
			--and a.servicio_id=v.servicio_id
			and a.canal_alta_ds=v.canal_alta_ds
			and a.subcanal_ds=v.subcanal_ds
			and a.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
		);




			----- PASO 2.4: Corregir identificación de pedido en ventas de servicios con pedido_id=-999999999,
			--							 en clientes a los que un distribuidor les hayan vendido varios servicios en mes de comisionado o previo
			--							CONDICIONES:
			--									Venta con pedido_id -99999999999 se relaciona con otras ventas realizadas por el distribuidor sin tener en cuenta canal ni subcanal
			--

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_LIST_CRUCE_RESTO_VENTAS_CLIENTE_POR_DISTRIBUIDOR` AS 
	with clm as (
	   	select distinct marca_ds,cliente_id,
			nombre_distribuidor_alta_ds 
	   	from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
	   	--where pedido_id=-999999999 
			where pedido is null 
			and grid<5
	)
	select v.marca_ds,v.cliente_id, 
	v.nombre_distribuidor_alta_ds,
	v.cif_nif, v.pedido,
	count(distinct v.categoria_servicio_ds) as nplays_v,
	count(distinct if(v.fecha_rfb_id is not null ,v.categoria_servicio_ds,NULL)) as nplays_a,      
	count(v.servicio_id) as nserv,
	from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` as v 
	inner join clm as c 
	on c.marca_ds=v.marca_ds and c.cliente_id=v.Cliente_id
	where v.categoria_servicio_ds in ('FIJA','BANDA ANCHA','TELEVISION','MOVILES POSTPAGO') 
	--and s.marca_ds="TELECABLE" --and s.pedido_id!=-999999999  and s.pedido_id is not null 
	--and s.pedido is not null 
	and v.grid<5 --- Solo se consideran servicios principales
	--and v.cliente_id=7602298	
	--and s.marca_ds='R' 
	   --and marca_ds="R"
	group by 1,2,3,4,5
	--having count(distinct s.categoria_servicio_ds)>1
	   --having count(distinct categoria_servicio_ds) != count(distinct if(fecha_rfb_id is not null ,categoria_servicio_ds,NULL))
	order by 1,2,3,4,5;



	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE_POR_DISTRIBUIDOR` AS 
		with ventas as (
          with clor as (
              SELECT cat, o1 as orden 
              FROM UNNEST(['BANDA ANCHA','FIJA','TELEVISION','MOVILES POSTPAGO']) cat 
              WITH OFFSET o1
          ) select v.*, clor.orden from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
          inner join clor 
          on clor.cat=v.categoria_servicio_ds
    ) select --v.* ,
      v.marca_ds, v.cliente_id, v.cif_nif,
			v.nombre_distribuidor_alta_ds,
      count(distinct v.pedido) as np,
     max(v.pedido) as ped_max,
      min(v.pedido) as ped_min,
      count(distinct fecha_venta_neta_id) as n_fv,
      count(distinct fecha_rfb_id) as n_fr,
      max(fecha_venta_neta_id) as fv_max,
      min(fecha_venta_neta_id) as fv_min,    
      max(fecha_rfb_id) as fr_max,
      min(fecha_rfb_id) as fr_min,
			DATE_DIFF(max(extract(DATE FROM fecha_venta_neta_dt)), min(extract(DATE FROM fecha_venta_neta_dt)), DAY) as dif_fv,
			DATE_DIFF(max(extract(DATE FROM fecha_rfb_dt)), min(extract(DATE FROM fecha_rfb_dt)), DAY) as dif_fr,			
		from ventas as v
    inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_LIST_CRUCE_RESTO_VENTAS_CLIENTE_POR_DISTRIBUIDOR` as p
		on p.marca_ds=v.marca_ds and p.cliente_id=v.Cliente_id and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds   
		where v.desc_mm not in ('B - Television contenido','B - Fijo','B - Alarma','B - Terminales')
		--and v.marca_ds='TELECABLE'
		and v.grid<5 --- Solo se consideran servicios principales
		--and v.cliente_id=7602298
    group by 1,2,3,4
		order by v.marca_ds asc, v.cliente_id asc, v.nombre_distribuidor_alta_ds asc;	

	
		-- 	Identifico casos que se pueden asociar a un único pedido
		INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` 
		with pob as (
			select v.*
			from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v  
			inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE_POR_DISTRIBUIDOR` as p
			on p.marca_ds=v.marca_ds and p.cliente_id=v.Cliente_id and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
			where p.np=1
			and v.grid<5
			--and v.cliente_id=7602298
			order by v.marca_ds, v.cliente_id, v.categoria_servicio_ds
		) select distinct pp.*, CAST(pnp.pedido AS STRING) as pedido_nuevo_valor, 'pedido_id unico' as criterio, 20 as fase
		from (select * from pob where pedido is not null) as pnp
		inner join (select * from pob where pedido is null) as pp
		on pp.marca_ds=pnp.marca_ds and pp.cliente_id=pnp.cliente_id and pp.nombre_distribuidor_alta_ds=pnp.nombre_distribuidor_alta_ds;

		--select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` v where fase=10 and CONTAINS_SUBSTR(pedido_nuevo_valor,'-999999' );		
		--select count(distinct servicio_id) from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` where contains_substr(pedido,"-999999") and grid <5;
		--select marca_ds, count(distinct servicio_id) from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` where contains_substr(pedido,"-999999") and grid <5 group by 1;


		-- Actualización de pedido en ventas que pueden asociarse a un único pedido

  UPDATE  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  SET pedido = p.pedido_nuevo_valor
	from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` p
	WHERE v.marca_ds=p.marca_ds
	and v.cliente_id=p.cliente_id
	and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
	--and v.fecha_venta_neta_dt=p.fecha_vv
	and v.servicio_id=p.servicio_id
	and p.fase=20;

	--select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where cliente_id=7602298;		
	--select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` v where cliente_id=7602298;		
	--select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where CONTAINS_SUBSTR(pedido,'-999999' );		

	----- Actualización de pedido en ventas que pueden asociarse a dos o mas pedidos. 
	-----		El criuterio empleado se bas a en que la actualización del pedido se realiza en base a otras ventas realizadas a ese mismo cliente por el mismo distribuidor sin id pedido informado
	
		INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` 
				with cand as (					
					with c as (
						with pob as (
							SELECT *
							from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE_POR_DISTRIBUIDOR`
							where np>1
						) select  v.marca_ds, v.cliente_id, v.nombre_distribuidor_alta_ds, v.pedido, v.fecha_venta_neta_dt,pob.np, count(distinct categoria_servicio_ds) as ncat, ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ) as cat , 
						--count(distinct categoria_servicio_ds) + case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"BANDA") THEN 40 ELSE 0 END as peso
						count(distinct categoria_servicio_ds)*(case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"BANDA") THEN 40  ELSE 0 END +  case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"MOVILES") THEN 30 ELSE 0 END +  case when CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"FIJA" ) OR CONTAINS_SUBSTR(ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ),"FIJA" ) THEN 20 ELSE 0 END) as peso
						from  pob 
						inner join `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 					
						on pob.marca_ds=v.marca_ds and pob.cliente_id=v.cliente_id and pob.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
						where v.grid<5
						group by 1,2,3,4,5,6
						order by 1,2,3,4,5,6
					) select distinct pnul.marca_ds, pinf.cliente_id, pnul.nombre_distribuidor_alta_ds, pinf.pedido,
					 pinf.ncat as ncat_inf, pinf.cat as cat_pinf, pnul.ncat as ncat_nul, pnul.cat as cat_nul, 
					 pinf.fecha_venta_neta_dt as fvinf,	pnul.fecha_venta_neta_dt as fvnul,
					date_diff(pinf.fecha_venta_neta_dt,	pnul.fecha_venta_neta_dt,MINUTE) as difinf_nul,pinf.peso+pnul.peso as peso,
					ROW_NUMBER() OVER(PARTITION BY pinf.marca_ds, pinf.cliente_id, pinf.nombre_distribuidor_alta_ds  
					ORDER BY (pinf.peso + pnul.peso) desc, ABS(date_diff(pinf.fecha_venta_neta_dt,	pnul.fecha_venta_neta_dt,MINUTE)) asc, pinf.ncat desc ) as orden
					from (select marca_ds, cliente_id, pedido, nombre_distribuidor_alta_ds, ncat, fecha_venta_neta_dt,  cat, peso 
					from c
					where pedido is null) as pnul
					left join (select marca_ds, cliente_id, pedido, nombre_distribuidor_alta_ds, ncat, fecha_venta_neta_dt, cat, peso 
					from c
					where pedido is not null) as pinf
					on pnul.marca_ds=pinf.marca_ds and pnul.cliente_id=pinf.cliente_id and pnul.nombre_distribuidor_alta_ds=pinf.nombre_distribuidor_alta_ds
					where not (contains_substr(pinf.cat,"BANDA") and contains_substr(pnul.cat,"BANDA"))
					and  not (contains_substr(pinf.cat,"FIJA") and contains_substr(pnul.cat,"FIJA"))
					and  not (contains_substr(pinf.cat,"TELEVISION") and contains_substr(pnul.cat,"TELEVISION"))
					--and orden=1					
					order by cliente_id asc, orden
				)  select distinct v.*, CAST(c.pedido AS STRING) as pedido_nuevo_valor, 'pedido_id multiple' as criterio, 21 as fase
				from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 	
				inner join cand c
				on c.marca_ds= v.marca_ds and c.cliente_id=v.cliente_id and c.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
				where c.orden=1 
				and c.pedido is not null
				and v.pedido is null
				and v.grid<5;


				-- Actualización de pedido en ventas que pueden asociarse a varios pedidos

			UPDATE  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
			SET pedido = p.pedido_nuevo_valor
			from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` p
			WHERE v.marca_ds=p.marca_ds
			and v.cliente_id=p.cliente_id
			and p.canal_alta_ds=v.canal_alta_ds and p.subcanal_ds=v.subcanal_ds and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
			--and v.fecha_venta_neta_dt=p.fecha_vv
			and v.servicio_id=p.servicio_id
			and p.fase=21;


 		--Select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CONT_CRUCE_RESTO_VENTAS_CLIENTE` where cliente_id=7599727;

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_CLIENTES_PENDIENTES` AS 
		SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_LIST_CRUCE_RESTO_VENTAS_CLIENTE_POR_DISTRIBUIDOR` v
		where pedido is null
		--AND cliente_id=7602298
		and not exists(
			select 1
			from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` a
			where a.marca_ds=v.marca_ds
			and a.cliente_id=v.cliente_id
			--and a.servicio_id=v.servicio_id
			and a.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
		);



	--- PASO 3: Crear el pedido id normalizado para moviles de Telecable
	---					
	---							
	
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_CONT_PEDIDO_TELECABLE` AS 
		with paqM as (		
		 	with clm as (
			   	select distinct marca_ds,cliente_id 
			   	from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
			   	where categoria_servicio_ds='MOVILES POSTPAGO'
			   	and marca_ds='TELECABLE'
		  )
			select s.marca_ds,s.cliente_id, s.cif_nif, s.pedido,
			count(distinct s.categoria_servicio_ds) as nplays_v,
			count(distinct if(s.fecha_rfb_id is not null ,s.categoria_servicio_ds,NULL)) as nplays_a,      
			count(s.servicio_id) as nserv,
			from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` as s 
			inner join clm as c 
			on c.marca_ds=s.marca_ds and c.cliente_id=s.Cliente_id
			where s.categoria_servicio_ds in ('FIJA','BANDA ANCHA','TELEVISION','MOVILES POSTPAGO') 
			and s.marca_ds="TELECABLE" --and s.pedido_id!=-999999999  and s.pedido_id is not null 
			and s.pedido is not null 
			and s.grid<5 --- Solo se consideran servicios principales
			--and s.marca_ds='R' 
		    --and marca_ds="R"
			group by 1,2,3,4
			having count(distinct s.categoria_servicio_ds)>1
		    --having count(distinct categoria_servicio_ds) != count(distinct if(fecha_rfb_id is not null ,categoria_servicio_ds,NULL))
			order by 1,2
		), ventas as (
          with clor as (
              SELECT cat, o1 as orden 
              FROM UNNEST(['BANDA ANCHA','FIJA','TELEVISION','MOVILES POSTPAGO']) cat 
              WITH OFFSET o1
          ) select v.*, clor.orden from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
          inner join clor 
          on clor.cat=v.categoria_servicio_ds
    ) select --v.* ,
      v.marca_ds, v.cliente_id, v.cif_nif,
      count( distinct if(categoria_servicio_ds="MOVILES POSTPAGO", v.pedido, NULL ) ) as np_ektnet,
      count( distinct if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), v.pedido, NULL ) ) as np_tcnet, 

      max(if(categoria_servicio_ds="MOVILES POSTPAGO", v.pedido, NULL )) as ped_max_ektnet,
      max(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), v.pedido, NULL )) as ped_max_tcnet, 
      min(if(categoria_servicio_ds="MOVILES POSTPAGO", v.pedido, NULL )) as ped_min_ektnet,
      min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), v.pedido, NULL )) as ped_min_tcnet, 

      count( distinct if(categoria_servicio_ds="MOVILES POSTPAGO", fecha_venta_neta_id, NULL ) ) as n_fv_ektnet,
      count( distinct if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), fecha_venta_neta_id, NULL ) ) as n_fv_tcnet, 
      count( distinct if(categoria_servicio_ds="MOVILES POSTPAGO", fecha_rfb_id, NULL ) ) as n_frfb_ektnet,
      count( distinct if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), fecha_rfb_id, NULL ) ) as n_frfb_tcnet, 			

      max(if(categoria_servicio_ds="MOVILES POSTPAGO", fecha_venta_neta_id, NULL )) as fv_max_ektnet,
      max(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), fecha_venta_neta_id, NULL )) as fv_max_tcnet, 
      min(if(categoria_servicio_ds="MOVILES POSTPAGO", fecha_venta_neta_id, NULL )) as fv_min_ektnet,
      min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), fecha_venta_neta_id, NULL )) as fv_min_tcnet,

      max(if(categoria_servicio_ds="MOVILES POSTPAGO", fecha_rfb_id, NULL )) as fr_max_ektnet,
      max(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), fecha_rfb_id, NULL )) as fr_max_tcnet, 
      min(if(categoria_servicio_ds="MOVILES POSTPAGO", fecha_rfb_id, NULL )) as fr_min_ektnet,
      min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), fecha_rfb_id, NULL )) as fr_min_tcnet,

			DATE_DIFF(max(if(categoria_servicio_ds  in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_venta_neta_dt), NULL )), min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_venta_neta_dt), NULL )), DAY) as dif_fv_tcnet,

			DATE_DIFF(max(if(categoria_servicio_ds="MOVILES POSTPAGO", extract(DATE FROM fecha_venta_neta_dt), NULL )), min(if(categoria_servicio_ds in ("MOVILES POSTPAGO"), extract(DATE FROM fecha_venta_neta_dt), NULL )), DAY) as dif_fv_ektnet,

			DATE_DIFF(min(if(categoria_servicio_ds="MOVILES POSTPAGO", extract(DATE FROM fecha_venta_neta_dt), NULL )), min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_venta_neta_dt), NULL )), DAY) as dif_fvmin_ektnet_tcnet,
			DATE_DIFF(max(if(categoria_servicio_ds="MOVILES POSTPAGO", extract(DATE FROM fecha_venta_neta_dt), NULL )), max(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_venta_neta_dt), NULL )), DAY) as dif_fvmax_ektnet_tcnet,


			DATE_DIFF(max(if(categoria_servicio_ds  in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_rfb_dt), NULL )), min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_rfb_dt), NULL )), DAY) as dif_fr_tcnet,

			DATE_DIFF(max(if(categoria_servicio_ds="MOVILES POSTPAGO", extract(DATE FROM fecha_rfb_dt), NULL )), min(if(categoria_servicio_ds in ("MOVILES POSTPAGO"), extract(DATE FROM fecha_rfb_dt), NULL )), DAY) as dif_fr_ektnet,

			DATE_DIFF(min(if(categoria_servicio_ds="MOVILES POSTPAGO", extract(DATE FROM fecha_rfb_dt), NULL )), min(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_rfb_dt), NULL )), DAY) as dif_frmin_ektnet_tcnet,
			DATE_DIFF(max(if(categoria_servicio_ds="MOVILES POSTPAGO", extract(DATE FROM fecha_rfb_dt), NULL )), max(if(categoria_servicio_ds in ("BANDA ANCHA","FIJA","TELEVISION"), extract(DATE FROM fecha_rfb_dt), NULL )), DAY) as dif_frmax_ektnet_tcnet
		from ventas as v
    inner join paqm p
		on p.marca_ds=v.marca_ds and p.cliente_id=v.Cliente_id    
		where v.desc_mm not in ('B - Television contenido','B - Fijo','B - Alarma','B - Terminales')
		and v.marca_ds='TELECABLE'
		and v.grid<5 --- Solo se consideran servicios principales
    group by 1,2,3		
		order by v.marca_ds asc, v.cliente_id asc;	


		-- Caso 1: Solo 1 Pedido en TcNEt y EktNet 		
		UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET pedido= CAST(p.ped_max_tcnet AS STRING) 
		from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_CONT_PEDIDO_TELECABLE` p 
		where np_ektnet=1 and np_tcnet=1
		and p.marca_ds=v.marca_ds 
		and p.cliente_id=v.cliente_id
		and v.marca_ds="TELECABLE"
		and v.categoria_servicio_ds="MOVILES POSTPAGO";
		
		-- Caso 2: Solo 1 Pedido en TcNet y varios en EktNet
			--Todos los `pedidos de Ektnet se relacionan con el pedido de TcNet 		
		UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET pedido= CAST(p.ped_max_tcnet AS STRING) 
		from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_CONT_PEDIDO_TELECABLE` p 
		where np_ektnet> 1 and np_tcnet=1
		and p.marca_ds=v.marca_ds 
		and p.cliente_id=v.cliente_id
		and v.marca_ds="TELECABLE"
		and v.categoria_servicio_ds="MOVILES POSTPAGO";
		
		-- Varios Pedidos en TcNet y un pedido en EktNet
			--El pedido de Ektnet se relaciona con el pedido de TcNet con feha de venta más cercana 		


	--select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  where marca_ds='TELECABLE' and cliente_id=1817859-- and pedido='1971740';
		-- Caso 3: Varios pedidos en TcNet y sólo uno en EktNet
		--		Criterio de actualización :
		--		Los móviles se asignan al pedido de tcnet cuyas ventas netas sean temporalmente más próximas al pedido de ektnet.
		--		Priorizando las ventas que se realizan en ektnet despúes de la formalización de la venta en ektnet.
		--		En el caso que dos pedidos de un cliente tengan una misma fecha de venta, se prioriza la asignación al pedido con mayor número de plays. 

		UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET v.pedido= p.pedido 
		from (
					with c as (
						--- Listado de clientes con indicadores relevantes de número de plays y fechas de venta de pedidos en tcnet y ektnet
						with pob as (
							SELECT * 
							from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_CONT_PEDIDO_TELECABLE` 
							where np_ektnet=1 and np_tcnet>1
						) select  v.marca_ds, v.cliente_id, v.pedido, v.fecha_venta_neta_dt, v.nombre_distribuidor_alta_ds,pob.np_ektnet, count(distinct categoria_servicio_ds) as np_tcnet, ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ) as cat 
						from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
						inner join pob 
						on pob.marca_ds=v.marca_ds and pob.cliente_id=v.cliente_id
						group by 1,2,3,4,5,6
						order by v.marca_ds, v.cliente_id
					) select distinct r.marca_ds, r.cliente_id, r.pedido, m.fecha_venta_neta_dt as fvm,	r.fecha_venta_neta_dt as fvr, r.np_tcnet,date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE) as difvmvr, r.cat, 
					ROW_NUMBER() OVER(PARTITION BY r.marca_ds, r.cliente_id ORDER BY CASE WHEN date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE) >0 THEN  date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE) ELSE 99999999 END  asc, r.np_tcnet desc ) as orden
					from (select marca_ds, cliente_id, pedido,nombre_distribuidor_alta_ds,np_tcnet, fecha_venta_neta_dt, cat 
					from c
					where cat!="MOVILES POSTPAGO") as r
					left join (select marca_ds, cliente_id, pedido,nombre_distribuidor_alta_ds,np_tcnet, fecha_venta_neta_dt,cat 
					from c
					where cat="MOVILES POSTPAGO") as m
					on m.marca_ds=r.marca_ds and m.cliente_id=r.cliente_id
					where r.pedido is not null
					order by cliente_id asc, ABS(date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE)) asc --and TRIM(m.nombre_distribuidor_alta_ds)=TRIM(r.nombre_distribuidor_alta_ds);
		) p
		WHERE v.marca_ds=p.marca_ds
		and v.cliente_id=p.cliente_id
		and v.marca_ds="TELECABLE"
		and v.categoria_servicio_ds="MOVILES POSTPAGO"		
		and p.orden=1;



	--select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  where marca_ds='TELECABLE' and cliente_id=1861167-- and pedido='1971740';
		-- Caso 4: Varios pedidos en TcNet y varios pedidos en EktNet
		--		Criterio de actualización :
		--		Los móviles se asignan al pedido de tcnet cuyas ventas netas sean temporalmente más próximas al pedido de ektnet.
		--		Priorizando las ventas que se realizan en ektnet despúes de la formalización de la venta en ektnet.
		--		En el caso que dos pedidos de un cliente tengan una misma fecha de venta, se prioriza la asignación al pedido con mayor número de plays. 

		UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET v.pedido= p.pedido_r 
		from (
					with c as (
						with pob as (
							SELECT * 
							from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_CONT_PEDIDO_TELECABLE` 
							where np_ektnet>1 and np_tcnet>1
						) select  v.marca_ds, v.cliente_id, v.pedido, v.fecha_venta_neta_dt, v.nombre_distribuidor_alta_ds,pob.np_ektnet, count(distinct categoria_servicio_ds) as np_tcnet, ARRAY_TO_STRING(ARRAY_AGG(distinct categoria_servicio_ds),"," ) as cat 
						from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
						inner join pob 
						on pob.marca_ds=v.marca_ds and pob.cliente_id=v.cliente_id
						group by 1,2,3,4,5,6
						order by v.marca_ds, v.cliente_id
					) select distinct r.marca_ds, r.cliente_id,m.pedido as pedido_m, r.pedido as pedido_r, m.fecha_venta_neta_dt as fvm,	r.fecha_venta_neta_dt as fvr, r.np_tcnet,date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE) as difvmvr, r.cat, 
					ROW_NUMBER() OVER(PARTITION BY r.marca_ds, r.cliente_id, m.pedido ORDER BY m.pedido, CASE WHEN date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE) >0 THEN  date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE) ELSE 99999999 END  asc, r.np_tcnet desc ) as orden
					from (select marca_ds, cliente_id, pedido,nombre_distribuidor_alta_ds,np_tcnet, fecha_venta_neta_dt, cat 
					from c
					where cat!="MOVILES POSTPAGO") as r
					left join (select marca_ds, cliente_id, pedido,nombre_distribuidor_alta_ds,np_tcnet, fecha_venta_neta_dt,cat 
					from c
					where cat="MOVILES POSTPAGO") as m
					on m.marca_ds=r.marca_ds and m.cliente_id=r.cliente_id
					where r.pedido is not null
					order by cliente_id asc, m.pedido, ABS(date_diff(m.fecha_venta_neta_dt,	r.fecha_venta_neta_dt,MINUTE)) asc --and TRIM(m.nombre_distribuidor_alta_ds)=TRIM(r.nombre_distribuidor_alta_ds);
		) p
		WHERE v.marca_ds=p.marca_ds
		and v.cliente_id=p.cliente_id
		and v.pedido=p.pedido_m
		and v.marca_ds="TELECABLE"
		and v.categoria_servicio_ds="MOVILES POSTPAGO"
		and p.orden=1;



  ---- PASO 3: Gestionar pedido id normalizado para casos en los que el id pedido informado de un servicio sea nulo

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PEDIDO_NULO` AS 
	  select * from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v where pedido is null and (clase_mm='A - Servicio base' or desc_mm="B - Television acceso");


		INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` 
		select distinct v.*, "666" as pedido_nuevo_valor, 'pedido_id no relacionado' as criterio, 50 as fase
		from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 	
		where v.pedido is null
		and v.grid<5;


		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
		SET pedido = p.pedido_nuevo_valor
		from `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_PED_NULL_ACTUALIZADOS` p
		WHERE v.marca_ds=p.marca_ds
		and v.cliente_id=p.cliente_id
		and p.canal_alta_ds=v.canal_alta_ds and p.subcanal_ds=v.subcanal_ds and p.nombre_distribuidor_alta_ds=v.nombre_distribuidor_alta_ds
		--and v.fecha_venta_neta_dt=p.fecha_vv
		and v.servicio_id=p.servicio_id
		and p.fase=50;


  ---- PASO 4: Generar log

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_VENTAS_CAPTACION`	AS 
		SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;

END