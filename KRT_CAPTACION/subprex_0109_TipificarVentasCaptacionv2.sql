BEGIN

    -- PASO 1: AÑADIR desc_mm 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS 
  SELECT  v.*, `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_comisiones`(v.categoria_servicio_ds, v.concepto_ds, v.portabilidad_in_lg, grid) as desc_mm
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v;



    -- PASO 2: AÑADIR clase_mm
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS 
  SELECT  v.*, `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(v.desc_mm) as clase_mm
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v;


    -- PASO 3: VOLCAR Log 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_CAPTACION`	AS 
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;


END