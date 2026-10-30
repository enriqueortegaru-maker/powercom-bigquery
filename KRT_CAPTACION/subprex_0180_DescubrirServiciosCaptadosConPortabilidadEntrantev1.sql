BEGIN
  -- TABLA SALIDA
  --    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO`

  ---PASO 1 CREO TABLA CON POBLACION DE PORTABILIDADES FIJAS 
  --LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20230901;SET HASTA=20230930;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_FIJA_ENTRANTE` AS
  SELECT * FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_120_portabilidad_fijo` f
  WHERE EXISTS(
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s
      WHERE s.servicio_id = f.servicio_receptor_id 
      and (contains_substr(agrup_operador_receptor_ds,"EUSKALTEL") or contains_substr(agrup_operador_receptor_ds,"CABLE"))
      and fecha_ventana_cambio_id between desde and hasta
  ) order by fecha_ventana_cambio_dt desc;


---PASO 2 CREO TABLA CON POBLACION DE PORTABILIDADES MOVILES 
  --LOCAL DECLARE DESDE, HASTA INT64; SET DESDE=20230901;SET HASTA=20230930;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_MOVIL_ENTRANTE` AS
  SELECT * FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_130_portabilidad_movil` f
  WHERE EXISTS(
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` s
      WHERE s.servicio_id = f.servicio_receptor_id 
      and (contains_substr(agrup_operador_receptor_ds,"EUSKALTEL") or contains_substr(agrup_operador_receptor_ds,"CABLE"))
      and fecha_ventana_cambio_id between desde and hasta
  ) order by fecha_ventana_cambio_dt desc;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION_PORTABILIDAD_FIJA` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_FIJA_ENTRANTE` f;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION_PORTABILIDAD_MOVIL` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_MOVIL_ENTRANTE` f;

END