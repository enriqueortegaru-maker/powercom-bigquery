BEGIN


		--	PASO 1: Listado de terminales vendidos por distribuidor en canal retención
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_TERMINALES` AS
		select distinct marca_ds, canal, subcanal,nombre_distribuidor,tipoMovimiento, concepto_ds, NombreProducto,IdFijo,  IdProducto, importe
		from 	`mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` 
		where canal="RETENCION" 
		and  contains_substr(TipoProducto,"terminal");


		--	PASO 2: Listado de seguros móviles vendidos por distribuidor en canal retención
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_SEGUROS` AS
		select distinct marca_ds, canal, subcanal,nombre_distribuidor,tipoMovimiento, concepto_ds, NombreProducto, IdFijo, IdProducto, importe
		from `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` 
		where canal="RETENCION" 
		and (contains_substr(TipoProducto,"Nuevos Negocios") or contains_substr(TipoProducto,"Seguro"))
		and contains_substr(tipoMovimiento,"Alta") and not contains_substr(tipoMovimiento,"cambio") 
		and contains_substr(concepto_ds,"seguro") 
		and (contains_substr(concepto_ds,"movil") or contains_substr(concepto_ds, " mob"));


		--	PASO 3: Listado de clientes a los que se les vende un terminal y un seguro móvil, segmentado por distribuidor
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_CLIENTES_SEGURO_y_TERMINAL` AS		
		select distinct marca_ds, canal, subcanal,nombre_distribuidor,IdFijo
		from  `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_SEGUROS`
		inner join  `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_TERMINALES` using(marca_ds, canal, subcanal,nombre_distribuidor,IdFijo);



		--	PASO 4: Calcula el ratio de ventas de seguro móvil por terminal, segmentado por distribuidor 	
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_IMPORTExDISTRIBUIDOR` AS
		with r as (
			with t as (
				select marca_ds, canal, subcanal,nombre_distribuidor, count(distinct IdProducto) as nt 
				from 	`mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_TERMINALES` 
				group by 1,2,3,4
			), syt as (
				select s.marca_ds, s.canal, s.subcanal,s.nombre_distribuidor, count(distinct s.IdProducto) as ns 
				from `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_SEGUROS` s
				inner join `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_CLIENTES_SEGURO_y_TERMINAL` sxt
				using(marca_ds, canal, subcanal,nombre_distribuidor,IdFijo)
				group by 1,2,3,4
			), s as (
				select s.marca_ds, s.canal, s.subcanal,s.nombre_distribuidor, count(distinct s.IdProducto) as ns 
				from `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_SEGUROS` s						
				group by 1,2,3,4
			) select t.marca_ds, t.canal, t.subcanal, t.nombre_distribuidor, t.nt, syt.ns, SAFE_DIVIDE(syt.ns,nt) as ratio, s.ns as ns_tot, SAFE_DIVIDE(s.ns,nt) as ratio_tot,
			s.ns-syt.ns as ns_not,
			SAFE_DIVIDE(s.ns-syt.ns, s.ns) as pct_ns_not,			 
			from t 
			left join syt using(marca_ds, canal, subcanal, nombre_distribuidor)			
			left join s using(marca_ds, canal, subcanal, nombre_distribuidor)
		) select *, case when ratio <0.2 then 2
						 when ratio <0.4 then 3
						 when ratio <0.6 then 5
						 when ratio >=0.6 then 6						 
		end as unitario				 
		from r;		
		

		UPDATE `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_SEGUROS` v 
		SET v.importe=u.unitario
		FROM `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_IMPORTExDISTRIBUIDOR` u 
		WHERE u.marca_ds=v.marca_ds
		and u.canal=v.canal
		and u.subcanal=v.subcanal
		and u.nombre_distribuidor=v.nombre_distribuidor;



		UPDATE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` v 
		SET v.importe=u.importe
		FROM `mm-commissions-reporting.KRT_CARTERA.LOG_020310_ATTACH_SEGURO_MOVIL_SEGUROxIMPORTE_SEGUROS` u 
		WHERE u.marca_ds=v.marca_ds
		and u.canal=v.canal
		and u.subcanal=v.subcanal
		and u.nombre_distribuidor=v.nombre_distribuidor
		and u.idFijo=v.IdFijo
		and u.idProducto=v.idProducto;
		
	
  END