BEGIN

	-------IMPORTANTE -> CARTERA SIGUE APUNTANDO A TABLAS EN PROCESO

	DECLARE vmes_factura_id INT64;
	DECLARE vmes_factura_dt DATE;
	--DECLARE DESDE INT64;SET DESDE=20250201;
	SET vmes_factura_id=CAST(SAFE_DIVIDE(DESDE,100) AS INT64);
	SET vmes_factura_dt= parse_date ('%Y%m', CAST (vmes_factura_id AS string));
  --select vmes_factura_dt, vmes_factura_id;


	----- PENDIENTE RESOLVER CASO EN QUE EN EL MISMO MES HAY REGISTROS DE DOS VERSIONES EN HISTORICO_FACTURADO
	------ O NE SU DEFCTO ASEGURAR QUE EN HISTORICO FACTURADO SOLO HAY REGISTROS DE VERSION EN PRODUCCION

	--- PASO 1: CREACION TABLA SAP_FACTURA_APUNTES_EN_PROCESO
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO` --partition by mes_factura_dt CLUSTER BY marca_ds, nombre_acreedor, orden_sap 
	AS 
	select * from `mm-commissions-reporting.KRT_SAP.f_vt_factura_apuntes_desde_tr_en_proceso`(desde);

	--- PASO 2: CREACION TABLA SAP_FACTURA_APUNTES_PUBLICADOS_EN_PROCESO
--	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_PUBLICADOS_EN_PROCESO` AS 
--	SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_factura_apuntes_publicados_en_proceso`(desde);

	--- PASO 3: ACTUALIZO TABLA SAP_FACTURA_APUNTES
	DELETE FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` where mes_factura_dt=PARSE_DATE("%Y%m%d", CAST(DESDE AS STRING));	
	INSERT INTO `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`  
	SELECT * FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_EN_PROCESO`;

	--- PASO 4: ACTUALIZO TABLA SAP_FACTURA_APUNTES_PUBLICADOS
--	DELETE FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_PUBLICADOS` where mes_factura_dt=PARSE_DATE("%Y%m%d", CAST(DESDE AS STRING));
--	INSERT INTO `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_PUBLICADOS`  
--	SELECT * FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES_PUBLICADOS_EN_PROCESO`;


END