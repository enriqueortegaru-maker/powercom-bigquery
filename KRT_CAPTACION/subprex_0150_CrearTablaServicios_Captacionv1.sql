BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS
  select distinct * --except(expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg,catalogo_id, grid, desc_mm, clase_mm)
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
  where fecha_rfb_id is not null
  and fecha_rfb_id>=desde and fecha_rfb_id<=hasta;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0150_SERVICIOS_CAPTACION` AS
  SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION`;

END