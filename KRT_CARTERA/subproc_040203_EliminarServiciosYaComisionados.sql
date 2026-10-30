BEGIN

		--LOCAL
		--DECLARE VDESDE INT64;SET VDESDE=20250901;


	---- IDENTIFICO SERVICIOS QUE YA COMISIONARON EN CAPTACION EN MES FACTURADO
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_CAPTACION_MES_ACTUAL` 
	OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
	select distinct *
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` cr
	where exists (
		select 1 
		from  `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` cp
		where cp.desde=vdesde and cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
	--  from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` cp
	--  where cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
	) and cr.canal!="B2B";

	
	---- IDENTIFICO SERVICIOS QUE YA COMISIONARON EN CAPTACION EN MESES PREVIOS FACTURADO
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_CAPTACION_MESES_PREVIOS` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS	
	select distinct *
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` cr	
	where exists(
		select 1 
		from  `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_FACTURADO` cp
		where cp.desde<vdesde and cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
		--where DATE_DIFF(cr.mes_factura_dt, cp.mes_factura_dt, DAY) >0 and cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
	--  from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` cp
	--  where cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
	) and cr.canal!="B2B";
	--and contains_substr(TipoMovimiento,'alta');
	--and TRIM(UPPER(TipoMovimiento)) like 'ALTA%' ;


	---- IDENTIFICO SERVICIOS QUE YA COMISIONARON EN CAPTACION EN MESES PREVIOS FACTURADO
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_CARTERA_MESES_PREVIOS`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS	
	select distinct *
	from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` cr	
	where exists(
		select 1 
		from  `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` cp
		where cp.desde<vdesde and cp.marca_ds=cr.marca_ds and cp.idFijo=cr.idFijo and cp.idProducto=cr.idProducto
		--where DATE_DIFF(cr.mes_factura_dt, cp.mes_factura_dt, DAY) >0 and cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
	--  from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` cp
	--  where cp.marca_ds=cr.marca_ds and cp.Cliente_id=cr.idFijo and cp.servicio_id=cr.idProducto
	) and cr.canal!="B2B";


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_BORRAR`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS	
		(select marca_ds, idFijo, idProducto from `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_CAPTACION_MES_ACTUAL`
		union all
		select marca_ds, idFijo, idProducto from `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_CAPTACION_MESES_PREVIOS` );


	---- BORRO SERVICIOS QUE YA HAN SIDO COMISIONADOS EN CAPTACION
	
	DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c 
	WHERE EXISTS (
		select 1
		from `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES_BORRAR`	 b
		where b.marca_ds=c.marca_ds and b.idFijo=c.idFijo and b.idProducto=c.idProducto
	);



	--- CREO LOG

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040203_COMISIONES`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS		
	SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

END