BEGIN

	--- PASO 1: CREACION TABLA SAP_FACTURA_APUNTES_EN_PROCESO
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_INV_ORDENES_COMSIONES` --partition by mes_factura_dt CLUSTER BY marca_ds, nombre_acreedor, orden_sap 
	AS 
	SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_inv_ordenes_sap_de_comisiones`();

END