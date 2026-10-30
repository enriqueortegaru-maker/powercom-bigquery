BEGIN


	---- PASO 1.0: IDENTIFICO DULICIDADES POR METODO TRADICIONAL
	CREATE OR REPLACE TABLE
		`mm-commissions-reporting.KRT_CARTERA.LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA` AS
	SELECT a.*
	FROM
	  `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` a
	WHERE
	  EXISTS (
	  SELECT
	    *
	  FROM
			--`mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` b
	    `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` b
	  WHERE a.marca_ds = b.marca_ds		
			AND a.dni_cif=b.cif_nif
			AND a.canal=b.canal_alta_ds
			AND a.subcanal=b.subcanal_ds
			AND a.nombre_distribuidor=b.nombre_distribuidor_alta_ds			
			AND a.TipoProducto=b.categoria_servicio_ds
	    AND ABS(a.IdProducto- b.servicio_id) <=20
	    );



	--- PASO 1.1: BORRO REGISTROS DE TABLA DESCUBIERTOS POR METODO TRADICIONAL
	DELETE
	FROM
	  `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` a
	WHERE
	  EXISTS (
	  SELECT
	    *
	  FROM
	    `mm-commissions-reporting.KRT_CARTERA.LOG_0202_COMISIONES_TIENDAS_CAPTACION_Y_CARTERA` b
	  WHERE a.marca_ds = b.marca_ds
			AND a.dni_cif=b.dni_cif
			AND a.canal=b.canal
			AND a.subcanal=b.subcanal
			AND a.nombre_distribuidor=b.nombre_distribuidor
			AND a.TipoProducto=b.TipoProducto
	    AND a.IdProducto = b.IdProducto
	);



	--- PASO 2: Creo LOG
	CREATE OR REPLACE TABLE
		`mm-commissions-reporting.KRT_CARTERA.LOG_0202_MARCO_RETRIBUTIVO_TIENDASxCANAL` AS

	SELECT * 
	FROM 
			`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`;

  END