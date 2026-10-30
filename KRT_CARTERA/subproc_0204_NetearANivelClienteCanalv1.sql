BEGIN


	--- PASO 0: ELIMINO COMISIONES DE IMPORTE  NEGATIVO DE VENTAS REALIZADAS POR DISTRIBUIDORES PARAMETRIZADOS

		CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.LOG_0204_COMISIONES_IMPORTE_NEGATIVO_DISTRIBUIDORES_PARAMETRIZADOS` AS
				select distinct v.marca_ds, v.canal, v.subcanal, v.nombre_distribuidor,v.idFijo, v.idProducto,v.importe
				from `mm-commissions-reporting.KRT_CARTERA.PARAM_ESTATICO_EXCLUSION_DISTRIBUIDORES_NATEO` e
				inner join `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` v
				on e.marca_ds=v.Marca_ds
				and case when trim(upper(e.canal))='X'  Then 1=1  else trim(upper(e.canal))=trim(upper(v.canal)) end
				and case when trim(upper(e.subcanal))='X'  Then 1=1  else trim(upper(e.subcanal))=trim(upper(v.subcanal)) end				
				and case when trim(upper(e.nombre_distribuidor))='X'  Then 1=1  else trim(upper(e.nombre_distribuidor))=trim(upper(v.nombre_distribuidor)) end
				and v.importe<0
				order by 1,2,3,4,5;

		DELETE FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` v
		where exists (
			select 1 
			from `mm-commissions-reporting.KRT_CARTERA.LOG_0204_COMISIONES_IMPORTE_NEGATIVO_DISTRIBUIDORES_PARAMETRIZADOS` n
			where e.marca_ds=v.Marca_ds and trim(upper(e.canal))=trim(upper(n.canal)) and trim(upper(e.subcanal))=trim(upper(n.subcanal)) and trim(upper(e.nombre_dsitribuidor))=trim(upper(n.nombre_distribuidor)) 
			and e.idFijo=n.idFijo and e.idProducto=n.idProducto			
		);



	--- PASO 1: LOG DE SERVICIOS QUE SE NATEAN

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0204_CLIENTES_NETEANxDISTRIBUIDOR` AS
	SELECT	marca_ds,	IdFijo,	nombre_distribuidor,	canal,	subcanal,	SUM(coalesce(importe,	0)) as importeac
	FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS`
	WHERE	marco_retributivo NOT IN ('N/A','MR Outbound')
	GROUP BY 1,2,3,4,	5
	HAVING SUM(coalsce(importe,	0)) < 0;

	CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.LOG_0204_SERVICIOS_NETEANxDISTRIBUIDOR` AS
	with pob as (
			SELECT *
			FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0204_CLIENTES_NETEANxDISTRIBUIDOR`
	) select distinct v.marca_ds, v.IdFijo,v.canal, v.subcanal, v.nombre_distribuidor, v.NombreProductoOrigen, v.NombreProducto, v.importe, p.importeac
	from `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` v
	inner join pob p
	on p.marca_ds=v.marca_ds and  p.IdFijo=v.IdFijo and p.canal=v.canal and p.subcanal=v.subcanal and p.nombre_distribuidor=v.nombre_distribuidor
	order by 1,2,3,4,5,6;



	--- PASO 2: ACTUALIZACION DE IMPORTE

	UPDATE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` k
	SET k.importe = 0
	FROM (
		SELECT IdFijo,nombre_distribuidor, canal,	subcanal, SUM(ifnull(importe,	0))
		FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS`
		WHERE	marco_retributivo NOT IN ('N/A','MR Outbound')
		GROUP BY 1,	2, 3,	4
		HAVING SUM(ifnull(importe, 0)) < 0) a
	WHERE a.idfijo = k.idfijo
		AND a.nombre_distribuidor = k.nombre_distribuidor
		AND a.canal = k.canal
		AND a.subcanal = k.subcanal
		AND k.tvt_ups_virgin = 'N';


	--- PASO 3: LOG DE VENTAS TRAS NATEO

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0204_VENTAS_TIENDAS` AS
	SELECT *	FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS`;

END