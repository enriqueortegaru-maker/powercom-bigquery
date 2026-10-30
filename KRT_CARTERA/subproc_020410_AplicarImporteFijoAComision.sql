BEGIN

	--- PASO 1: POBLACION DE SERVICIOS  A LOS QUE SE APLICA IMPORTE FIJO

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020410_VENTAS_TIENDAS_IMPORTE_FIJO` AS 
		select distinct c.*, p.importe as impfijo
		from `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` c 
	--	from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` c 
			inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on cat.marca_ds=c.marca_ds and cat.IdProdCat=c.IdCatalogo    
		inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO` p on p.marca_ds=c.marca_ds    
			and case when p.canal!='X' THEN  p.canal= c.canal ELSE 1=1 END
			and case when p.subcanal!='X' THEN  p.subcanal= c.subcanal ELSE 1=1 END
			and case when p.nombre_distribuidor!='X' THEN  p.nombre_distribuidor= c.nombre_distribuidor ELSE 1=1 END    
			and case when p.marco_retributivo!='X' THEN  p.marco_retributivo= c.marco_retributivo ELSE 1=1 END      
			and case when p.tipoproducto!='X' THEN  p.tipoproducto= cat.tipoproducto ELSE 1=1 END
			and case when p.claseproducto!='X' THEN  p.claseproducto= cat.tipo_movimiento ELSE 1=1 END
		--where not starts_with(tipomovimiento,"alta") and not starts_with(tipomovimiento,"traslado")			
		where UPPER(TRIM(tipomovimiento)) not like "ALTA %" and UPPER(TRIM(tipomovimiento)) not like "TRASLADO %" and UPPER(TRIM(tipomovimiento)) != "RAPPEL"
		and c.importe>0;



	--- PASO 2: SE ACTUALIZA EL IMPORTE DE COMISION

/*	with d as (
		select marca_ds, idproducto, count(idfijo) as nc
		from `mm-commissions-reporting.KRT_CARTERA.LOG_020410_VENTAS_TIENDAS_IMPORTE_FIJO`
		group by 1,2
		having count(idfijo)>1
	) select * 
	from `mm-commissions-reporting.KRT_CARTERA.LOG_020410_VENTAS_TIENDAS_IMPORTE_FIJO` c
	inner join d using(marca_ds, idproducto)
	order by marca_ds, idproducto;
*/

	UPDATE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` v
	SET v.importe=p.impfijo
	FROM (
			select distinct marca_ds, idFijo,idProducto, idproductoOrigen, tipomovimiento, canal, subcanal,marco_retributivo, concepto_ds, impfijo
			from `mm-commissions-reporting.KRT_CARTERA.LOG_020410_VENTAS_TIENDAS_IMPORTE_FIJO` 
	)p
	where v.marca_ds=p.marca_ds
	and v.idFijo=p.idFijo
	and v.idProducto=p.idProducto
	and v.idProductoOrigen=p.idProductoOrigen
	and v.tipomovimiento=p.tipomovimiento
	and v.canal=p.Canal
	and v.subcanal=p.subcanal
	and v.marco_retributivo=p.marco_retributivo
	--and v.concepto_origen_ds=p.concepto_origen_ds
	and v.concepto_ds=p.concepto_ds
	and v.idproducto >1000;



	--- PASO 3: SE VUELCA LOG
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_020410_VENTAS_TIENDAS` AS 
	SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS`;


END