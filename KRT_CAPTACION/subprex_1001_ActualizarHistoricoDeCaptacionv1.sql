BEGIN
	DECLARE vMES_COMISION_ID INT64;

	DECLARE vMES_COMISION_DT DATE;
--  VARIABLES LOCALES	
--  DECLARE vMES_COMISION_ID, DESDE,HASTA, VERSION_FL INT64; SET DESDE=20230401;SET HASTA=20230430;SET VERSION_FL=7;
	SET	vMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 
	SET vMES_COMISION_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month);

--	SELECT DESDE, HASTA, vMES_COMISION_ID, vMES_COMISION_DT;



	--- PASO 1.0 ACTUALIZO ACC_CAPTACION_HISTORICO 

		DELETE
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.ACC_CAPTACION_HISTORICO` AS h
		WHERE
			h.mes_comision_dt=vMES_COMISION_DT
			and h.VERSION=VERSION_FL;


		if version_fl <6 then
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_1001_ACC_CAPTACION_HISTORICO_ADD` AS 
			SELECT 
				vMES_COMISION_DT as mes_comision_dt, mes_comision_id, VERSION_FL as version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS as concepto_ds,  FECHA_RFB_ID as fecha_rfb_id,  FECHA_VENTA_NETA_ID as fecha_venta_neta_id,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, CAST(NULL  AS STRING) AS  expediente_padre_id, NULL AS  contrato_id, CAST(NULL  AS STRING) AS  tipo_pedido_ds, NULL AS  pedido_id, CAST(NULL  AS STRING) AS  tipo_producto_pedido_re_ds, NULL AS  visibilidad_pedido_lg, CAST(NULL  AS STRING) AS  catalogo_id, NULL AS  grid,  desc_mm,  clase_mm, CAST(NULL  AS STRING) AS  pedido,  PLAYS AS  nplays, NULL AS  nplays_rfb, CAST(NULL  AS STRING) AS  cat_plays, CAST(NULL  AS STRING) AS  cat_plays_rfb, NULL AS  nplays_p, NULL AS  nplays_rfb_p, CAST(NULL  AS STRING) AS  cat_plays_p, CAST(NULL  AS STRING) AS  cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable
			FROM
				`mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS c; 
		end if;

		if version_fl >=6 then
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_1001_ACC_CAPTACION_HISTORICO_ADD` AS 
			SELECT 
				vMES_COMISION_DT as mes_comision_dt, mes_comision_id, VERSION_FL as version, marca_ds,  Cliente_id,  servicio_id,  detalle_servicio_ds,  CONCEPTO_DS as concepto_ds,  FECHA_RFB_ID as fecha_rfb_id,  FECHA_VENTA_NETA_ID as fecha_venta_neta_id,  fecha_rfb_dt,  fecha_venta_neta_dt,  canal_alta_ds,  subcanal_ds,  tipo_canal_alta_ds,  nombre_distribuidor_alta_ds,  agente_alta_id,  agente_creador_id,  categoria_servicio_ds,  cif_nif,  segmento_ds,  subsegmento_ds,  marca_cartera_ds,  Antiguedad_Cliente,  equipo_ds,  territorio_ds,  tecnologia_detalle_ds,  portabilidad_in_lg,  gb,  expediente_id, expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id,tipo_producto_pedido_re_ds, visibilidad_pedido_lg, catalogo_id, grid,  desc_mm,  clase_mm, pedido,  nplays, nplays_rfb, cat_plays, cat_plays_rfb, nplays_p, nplays_rfb_p, cat_plays_p, cat_plays_rfb_p,  clave,  marco_retributivo_ds,  flag_marca_cartera,  grupo_rappel_ds,  orden_sap,  importe,  decomisionable
			FROM
				`mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS c; 
		end if;


		INSERT INTO
			`mm-commissions-reporting.KRT_CAPTACION.ACC_CAPTACION_HISTORICO`
		SELECT 
			c.* 
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.LOG_1001_ACC_CAPTACION_HISTORICO_ADD` AS c; 
			


	--- PASO 2.0 ACTUALIZO ACC_CLAWBACK_HISTORICO 


			--- CLAWBACK
		DELETE
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.ACC_CLAWBACK_HISTORICO` AS h
		WHERE
			h.mes_decomision_id=vMES_COMISION_ID
			and h.VERSION=VERSION_FL;

		INSERT INTO
			`mm-commissions-reporting.KRT_CAPTACION.ACC_CLAWBACK_HISTORICO`
		SELECT
			DISTINCT * , version_fl
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`;




  --- PASO 3.0: ACTUALIZO HISTORICO DE DECOMISIONES PUBLICADAS EN MESES PREVIOS
		DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
		WHERE mes_decomision_id=vMES_COMISION_ID;

		INSERT  INTO `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
		SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_PUBLICADAS_MESES_PREVIOS`;



--- PASO 4.0: ACTUALIZO HISTORICO DE DECOMISIONES DUPLICADAS EN MES DE COMISION
    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_DUPLICADAS_MES_DECOMISION_HISTORICO` AS
    --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_DUPLICADAS_MES_DECOMISION`;


    DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_DUPLICADAS_MES_DECOMISION_HISTORICO`
    WHERE mes_decomision_id=vMES_COMISION_ID;

    INSERT  INTO `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_DUPLICADAS_MES_DECOMISION_HISTORICO`
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_DUPLICADAS_MES_DECOMISION`;


  --- PASO 5.0:ACTUALIZO HISTORICO DE COMISIONES DUPLICADAS EN MESES PREVIOS
    DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    WHERE mes_comision_id=vMES_COMISION_ID;

    INSERT  INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_PREVIOS`;



--- PASO 6.0: ACTUALIZO HISTORICO DE COMISIONES DUPLICADAS EN MES DE COMISION
    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DUPLICADAS_MES_COMISION_HISTORICO` AS
    --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_DUPLICADAS_MES_COMISION`;

    DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DUPLICADAS_MES_COMISION_HISTORICO`
    WHERE mes_comision_id=vMES_COMISION_ID;

    INSERT  INTO `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DUPLICADAS_MES_COMISION_HISTORICO`
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_DUPLICADAS_MES_COMISION`;






END